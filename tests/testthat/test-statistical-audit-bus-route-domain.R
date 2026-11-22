# A bus-route trip filter estimates a domain of every interviewed day (GH #680) ----
#
# The bus-route survey's unit is the interviewed day (br_add_psu_key()). A
# trip filter -- complete trips for a total, one trip type for a rate, the
# short-trip truncation -- keeps a subset of the interviews, and the survey
# was built on that subset alone: a day with no trip of the kind dropped out
# as a sampling unit. The variance was then taken over fewer days than were
# sampled, conditional on the domain having been seen, and a stratum left
# with one such day stopped with "Stratum has only one PSU". The standard
# designs keep every interviewed day (GH #663); the bus-route and ice paths
# now do the same.
#
# The references are computed in base R from the definitions: Horvitz-
# Thompson contributions w = 1 / pi (site A pi = 60 / 180, site B 120 / 180),
# linearisation scores summed by day over every interviewed day, and the
# stratified with-replacement between-day variance.

brd_q <- function(x) suppressWarnings(suppressMessages(x))

# Six days, two sites, one party a visit, alternating complete and incomplete.
# `drop_complete` removes the complete trips of the days given, leaving those
# days with incomplete trips only. `strata` splits the days 3 + 3.
brd_interviews <- function(drop_complete = integer(0), strata = FALSE) {
  days <- as.Date("2024-06-03") + 0:5
  n <- 24L
  iv <- data.frame(
    date = rep(days, each = 4),
    day_type = if (strata) rep(rep(c("weekday", "weekend"), each = 3), each = 4) else "weekday",
    # Not alternating with the trip status, or site would be trip type.
    site = rep(c("A", "A", "B", "B"), length.out = n), circuit = "c",
    hrs = rep(c(2, 3, 1.5, 2.5), length.out = n),
    trip_status = rep(c("complete", "incomplete"), length.out = n),
    n_counted = 1L, n_interviewed = 1L,
    stringsAsFactors = FALSE
  )
  iv$catch_total <- round(iv$hrs * rep(c(0.8, 1.2, 1, 0.9, 1.1, 1.3), each = 4))
  iv[!(iv$date %in% days[drop_complete] & iv$trip_status == "complete"), , drop = FALSE]
}

brd_design <- function(iv, strata = FALSE, date_name = "date", sampled = FALSE) {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:5,
    day_type = if (strata) rep(c("weekday", "weekend"), each = 3) else "weekday",
    worked = TRUE
  )
  sf <- data.frame(site = c("A", "B"), circuit = "c", wait = c(60, 120), ct = 180)
  des <- creel_design(
    cal,
    date = date, strata = day_type, survey_type = "bus_route", # nolint: object_usage_linter
    sampling_frame = sf, site = site, circuit = circuit, # nolint: object_usage_linter
    wait_time = wait, circuit_time = ct, p_period = 1, # nolint: object_usage_linter
    sampled = !!(if (sampled) rlang::sym("worked") else NULL)
  )
  names(iv)[names(iv) == "date"] <- date_name
  brd_q(add_interviews(des, iv, # nolint: object_usage_linter
    effort = hrs, catch = catch_total, trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = hrs, n_counted = n_counted, n_interviewed = n_interviewed, # nolint: object_usage_linter
    n_anglers = 1, date_col = date_name
  ))
}

# Stratified between-day variance of per-day sums of a score, over `days`.
brd_var <- function(z, day, days, day_stratum) {
  s <- tapply(z, factor(as.character(day), levels = as.character(days)), sum)
  s[is.na(s)] <- 0
  v <- 0
  for (h in unique(day_stratum)) {
    k <- day_stratum == h
    n <- sum(k)
    v <- v + n / (n - 1) * sum((s[k] - mean(s[k]))^2)
  }
  v
}

brd_w <- function(iv) ifelse(iv$site == "A", 3, 1.5)

# SE of the complete-trip HT ratio of means over every interviewed day.
brd_rate_se <- function(iv, in_group = rep(TRUE, nrow(iv)), strata = FALSE) {
  days <- as.Date("2024-06-03") + 0:5
  st <- if (strata) rep(c("weekday", "weekend"), each = 3) else rep("weekday", 6)
  w <- brd_w(iv)
  comp <- iv$trip_status == "complete" & in_group
  y <- iv$catch_total
  x <- iv$hrs
  r <- sum(w[comp] * y[comp]) / sum(w[comp] * x[comp])
  z <- ifelse(comp, w * (y - r * x) / sum(w[comp] * x[comp]), 0)
  sqrt(brd_var(z, iv$date, days, st))
}

test_that("BRD-01 (#680): a complete-trip rate keeps a day that had incomplete trips only", {
  iv <- brd_interviews(drop_complete = 6L)
  r <- brd_q(estimate_catch_rate(brd_design(iv))) # nolint: object_usage_linter
  # Six sampled days, not the five that held a complete trip.
  expect_equal(r$estimates$se, brd_rate_se(iv), tolerance = 1e-10)
  # The padded day is not an interview.
  expect_identical(r$estimates$n, sum(iv$trip_status == "complete"))
})

test_that("BRD-02 (#680): grouped rates keep every interviewed day and invent no group", {
  iv <- brd_interviews(drop_complete = 6L)
  r <- brd_q(estimate_catch_rate(brd_design(iv), by = site)) # nolint: object_usage_linter
  expect_setequal(r$estimates$site, c("A", "B"))
  for (s in c("A", "B")) {
    row <- r$estimates$site == s
    expect_equal(r$estimates$se[row], brd_rate_se(iv, iv$site == s), tolerance = 1e-10, info = s)
    expect_identical(r$estimates$n[row], sum(iv$trip_status == "complete" & iv$site == s), info = s)
  }
})

test_that("BRD-03 (#680): a stratum with complete trips on one day is estimated, not refused", {
  # Weekend complete trips on its first day only; the other two weekend days
  # were interviewed and held incomplete trips. The subset survey had one PSU
  # in that stratum and stopped.
  iv <- brd_interviews(drop_complete = 5:6, strata = TRUE)
  r <- brd_q(estimate_catch_rate(brd_design(iv, strata = TRUE))) # nolint: object_usage_linter
  expect_equal(r$estimates$se, brd_rate_se(iv, strata = TRUE), tolerance = 1e-10)
})

test_that("BRD-04 (#680): a sampled-day total counts a day without complete trips as a zero day", {
  iv <- brd_interviews(drop_complete = 6L)
  tot <- brd_q(estimate_total_catch(brd_design(iv), target = "sampled_days")) # nolint: object_usage_linter
  comp <- iv$trip_status == "complete"
  contrib <- ifelse(comp, brd_w(iv) * iv$catch_total, 0)
  days <- as.Date("2024-06-03") + 0:5
  expect_equal(tot$estimates$estimate, sum(contrib), tolerance = 1e-10)
  expect_equal(tot$estimates$se, sqrt(brd_var(contrib, iv$date, days, rep("weekday", 6))), tolerance = 1e-10)
  # The same as with the register of sampled days, which already entered an
  # empty worked day as a zero.
  reg <- brd_q(estimate_total_catch( # nolint: object_usage_linter
    brd_design(iv, sampled = TRUE),
    target = "sampled_days"
  ))
  expect_equal(tot$estimates$se, reg$estimates$se, tolerance = 1e-10)
  # Grouped, the padded day reports no group of its own.
  by_site <- brd_q(estimate_total_catch( # nolint: object_usage_linter
    brd_design(iv),
    by = site, target = "sampled_days" # nolint: object_usage_linter
  ))
  expect_setequal(by_site$estimates$site, c("A", "B"))
})

test_that("BRD-05 (#680): the day is the interviews' own date column, whatever it is named", {
  # add_interviews(date_col =) names the interviews' date apart from the
  # calendar's. The day key looked for the calendar's name, found nothing, and
  # fell back to one PSU per interview row.
  iv <- brd_interviews()
  same <- brd_q(estimate_catch_rate(brd_design(iv))) # nolint: object_usage_linter
  renamed <- brd_q(estimate_catch_rate(brd_design(iv, date_name = "fish_day"))) # nolint: object_usage_linter
  expect_equal(renamed$estimates$se, same$estimates$se, tolerance = 1e-12)
  expect_equal(same$estimates$se, brd_rate_se(iv), tolerance = 1e-10)
  tot_same <- brd_q(estimate_total_catch(brd_design(iv), target = "sampled_days")) # nolint: object_usage_linter
  tot_renamed <- brd_q(estimate_total_catch( # nolint: object_usage_linter
    brd_design(iv, date_name = "fish_day"),
    target = "sampled_days"
  ))
  expect_equal(tot_renamed$estimates$se, tot_same$estimates$se, tolerance = 1e-12)
})

test_that("BRD-06 (#680): a domain kept on one day of several is refused, not given SE 0", {
  # Complete trips on day 1 only; days 2-6 were interviewed. The ratio's score
  # sums to 0 on its one day and is 0 on the padded ones: an SE of 0, which
  # the standard designs refuse (GH #663).
  iv <- brd_interviews(drop_complete = 2:6)
  expect_error(
    brd_q(estimate_catch_rate(brd_design(iv))), # nolint: object_usage_linter
    class = "creel_error_single_psu"
  )
})

test_that("BRD-07 (#680): grouping a rate by stratum reports no group of padded days", {
  # The weekend held incomplete trips only: its padded days form no
  # complete-trip group, which would be a 0/0 rate.
  iv <- brd_interviews(drop_complete = 4:6, strata = TRUE)
  r <- brd_q(estimate_catch_rate(brd_design(iv, strata = TRUE), by = day_type)) # nolint: object_usage_linter
  expect_identical(r$estimates$day_type, "weekday")
  expect_true(all(is.finite(r$estimates$estimate)))
})

test_that("BRD-08 (#680): the register's empty days use the interviews' own date column", {
  # With the date renamed and a day with no complete trip, the register path
  # wrote the empty day under the calendar's name and rbind() stopped on the
  # unequal columns.
  iv <- brd_interviews(drop_complete = 6L)
  same <- brd_q(estimate_total_catch( # nolint: object_usage_linter
    brd_design(iv, sampled = TRUE),
    target = "sampled_days"
  ))
  renamed <- brd_q(estimate_total_catch( # nolint: object_usage_linter
    brd_design(iv, date_name = "fish_day", sampled = TRUE),
    target = "sampled_days"
  ))
  expect_equal(renamed$estimates$se, same$estimates$se, tolerance = 1e-12)
})

test_that("BRD-09 (#680): a total grouped by the renamed date keeps the zero day", {
  # A day total of 0 is a day's total, kept when grouping by the day -- under
  # the interviews' own date name as under the calendar's.
  iv <- brd_interviews(drop_complete = 6L)
  same <- brd_q(estimate_total_catch(brd_design(iv), by = date, target = "sampled_days")) # nolint: object_usage_linter
  renamed <- brd_q(estimate_total_catch( # nolint: object_usage_linter
    brd_design(iv, date_name = "fish_day"),
    by = fish_day, target = "sampled_days" # nolint: object_usage_linter
  ))
  expect_identical(nrow(same$estimates), 6L)
  expect_identical(nrow(renamed$estimates), 6L)
  expect_equal(sort(renamed$estimates$estimate), sort(same$estimates$estimate), tolerance = 1e-12)
})
