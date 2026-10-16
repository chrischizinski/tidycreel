# Mean-of-ratios weights each party by its size (GH #513).
#
# The roving mean of ratios is derived for anglers: a clerk meets an angler with
# probability proportional to trip length, and the mean of the anglers' own
# rates estimates total catch / total effort (Hoenig et al. 1997). An interview
# is a party, and meeting a party meets all its anglers. Averaging parties with
# equal weight estimates sum(C/n) / sum(L) instead, which leans toward small
# parties' rates whenever the per-angler rate varies with party size. Nothing
# warned and no test failed: every MOR test either had no party size or never
# checked the value against a hand calculation with varying sizes.

# Two parties a day, fishing equally long: one angler catching nothing, three
# anglers catching one fish per angler-hour each. Total catch / total
# angler-hours is 3 / 4 = 0.75 every day; equal party weights give 0.5.
mor_party_fixture <- function(n_anglers = c(1L, 3L), catch = c(0L, 6L), n_days = 6L) {
  dates <- as.Date("2024-06-03") + seq_len(n_days) - 1L
  calendar <- data.frame(date = dates, day_type = "weekday")
  interviews <- data.frame(
    date = rep(dates, each = 2L),
    day_type = "weekday",
    hours_fished = 2,
    n_anglers = rep(n_anglers, times = length(dates)),
    catch_total = rep(catch, times = length(dates)),
    catch_kept = rep(catch, times = length(dates)) %/% 2L,
    trip_status = "incomplete"
  )
  design <- creel_design(calendar, date = date, strata = day_type)
  list(design = design, interviews = interviews)
}

attach_roving <- function(fx, ...) {
  suppressMessages(suppressWarnings(add_interviews(
    fx$design, fx$interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = hours_fished,
    interview_type = "roving", ...
  )))
}

quiet <- function(x) suppressMessages(suppressWarnings(x))

test_that("roving catch rate is total catch over total angler-hours, not the party average", {
  d <- attach_roving(mor_party_fixture(), n_anglers = n_anglers)
  est <- quiet(estimate_catch_rate(d))$estimates$estimate
  # 6 fish over (1 + 3) anglers x 2 h = 8 angler-hours; the equal-weight mean
  # of 0 and 1 is the defect's 0.5.
  expect_equal(est, 0.75)
})

test_that("roving harvest rate is weighted by party size the same way", {
  d <- attach_roving(mor_party_fixture(), n_anglers = n_anglers)
  est <- quiet(estimate_harvest_rate(d))$estimates$estimate
  # kept 0 and 3: 3 / 8
  expect_equal(est, 0.375)
})

test_that("grouped roving rates weight by party size within each group", {
  fx <- mor_party_fixture(n_days = 12L)
  fx$interviews$angler_type <- rep(c("bank", "boat"), length.out = nrow(fx$interviews))
  # Sizes cycle 1, 3, 3, 1 against bank, boat, so each group holds both sizes.
  fx$interviews$n_anglers <- rep(c(1L, 3L, 3L, 1L), length.out = nrow(fx$interviews))
  fx$interviews$catch_total <- ifelse(fx$interviews$n_anglers == 3L, 6L, 0L)
  fx$interviews$catch_kept <- fx$interviews$catch_total %/% 2L
  d <- attach_roving(fx, n_anglers = n_anglers, angler_type = angler_type)
  got <- quiet(estimate_catch_rate(d, by = angler_type))$estimates
  k <- fx$interviews
  r <- k$catch_total / (k$hours_fished * k$n_anglers)
  want <- vapply(split(seq_len(nrow(k)), k$angler_type), function(i) {
    sum(k$n_anglers[i] * r[i]) / sum(k$n_anglers[i])
  }, numeric(1))
  expect_equal(got$estimate, unname(want[got$angler_type]))
  # Both groups hold sizes 1 and 3, so equal weights would give 0.5 in each.
  expect_true(all(abs(got$estimate - 0.5) > 0.1))
})

test_that("without a party size the rate is the plain party-hour mean, as before", {
  d <- attach_roving(mor_party_fixture())
  est <- quiet(estimate_catch_rate(d))$estimates
  k <- mor_party_fixture()$interviews
  expect_equal(est$estimate, mean(k$catch_total / k$hours_fished))
  expect_identical(quiet(estimate_catch_rate(d))$unit, "fish/party-hour")
})

test_that("a constant party size gives the same rate and SE as no weighting", {
  fx <- mor_party_fixture(n_anglers = c(2L, 2L))
  col <- quiet(estimate_catch_rate(attach_roving(fx, n_anglers = n_anglers)))$estimates
  lit <- quiet(estimate_catch_rate(attach_roving(fx, n_anglers = 2)))$estimates
  expect_identical(col$estimate, lit$estimate)
  expect_identical(col$se, lit$se)
})

test_that("party size cancels when the per-angler rate does not depend on it", {
  # Every angler catches 0.5 fish/hour whatever the party: weighting changes
  # nothing, so the fix moves estimates only where the defect biased them.
  d <- attach_roving(mor_party_fixture(catch = c(1L, 3L)), n_anglers = n_anglers)
  expect_equal(quiet(estimate_catch_rate(d))$estimates$estimate, 0.5)
})

test_that("bus-route incomplete-trip rate weights parties by size", {
  d <- build_ht_multispecies_design("bus_route", seed = 513L)
  d$interviews$trip_status <- rep(c("complete", "incomplete"), length.out = nrow(d$interviews))
  got <- quiet(estimate_harvest_rate(d, use_trips = "incomplete"))$estimates$estimate

  k <- d$interviews[d$interviews$trip_status == "incomplete", ]
  k <- k[k[[d$trip_duration_col]] >= 0.5 & k$.angler_effort > 0, ]
  r <- k[[d$harvest_col]] / k$.angler_effort
  w <- k$.expansion / k$.pi_i * k$n_anglers
  expect_true(length(unique(k$n_anglers)) > 1L)
  expect_equal(got, sum(r * w) / sum(w))
  expect_false(isTRUE(all.equal(got, sum(r * w / k$n_anglers) / sum(w / k$n_anglers))))
})

test_that("release rate by mean of ratios weights parties by size", {
  # Release reaches the same MOR internals through the species path, so it is
  # checked on its own: a route that bypassed them would keep equal weights.
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- quiet(add_counts(d, example_counts))
  d <- quiet(add_interviews(d, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = n_anglers
  ))
  d <- quiet(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  got <- quiet(estimate_release_rate(d, estimator = "mor", use_trips = "all", truncate_at = NULL))

  k <- example_interviews
  released <- example_catch[example_catch$catch_type == "released", ]
  rel <- tapply(released$count, released$interview_id, sum)
  k$released <- unname(rel[as.character(k$interview_id)])
  k$released[is.na(k$released)] <- 0
  r <- k$released / (k$hours_fished * k$n_anglers)
  expect_equal(got$estimates$estimate, sum(k$n_anglers * r) / sum(k$n_anglers))
  expect_false(isTRUE(all.equal(got$estimates$estimate, mean(r))))
})
