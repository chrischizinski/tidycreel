# GH #689: the trip length that estimate_angler_trips() divides effort by.
#
# Trips = effort / mean trip length (Pollock et al. 1994, p. 175). The mean was
# the plain average of every interview's trip_duration, so:
#   - incomplete trips entered with their elapsed time, not a trip length
#     (+16% trips on the example data);
#   - parties counted once whatever their size, so angler-hours were divided by
#     hours per PARTY trip (the #513 analogue);
#   - roving designs were not checked, although a roving clerk meets anglers in
#     proportion to trip length (Pollock et al. 1994 sec. 11.4; Robson 1961);
#   - bus-route interviews ignored their inclusion weights;
#   - the SE treated interviews on one day as independent, and the CI used the
#     interview count as df.
# On the example data with angler-hours effort, trips went 367 -> 291.

tl_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

# The example survey, with counts declared as angler-hours (a period length of
# 1 on counts that are already effort-hours) so the actor is known.
tl_design <- function(n_anglers = TRUE, interview_type = "access") {
  data(example_calendar, envir = environment())
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  cn <- example_counts # nolint: object_usage_linter
  cn$T_d <- 1
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- tl_quiet(add_counts(d, cn, count_col = effort_hours, period_length_col = T_d)) # nolint: object_usage_linter
  args <- list(
    d, example_interviews, # nolint: object_usage_linter
    catch = quote(catch_total), harvest = quote(catch_kept), effort = quote(hours_fished),
    trip_status = quote(trip_status), trip_duration = quote(trip_duration),
    interview_type = interview_type
  )
  if (n_anglers) args$n_anglers <- quote(n_anglers)
  tl_quiet(do.call(add_interviews, args))
}

test_that("#689: angler-hours are divided by hours per angler trip, over complete trips", {
  d <- tl_design()
  e <- tl_quiet(estimate_effort(d)) # nolint: object_usage_linter
  expect_identical(e$unit, "angler-hours")
  t <- tl_quiet(estimate_angler_trips(e, d))$estimates # nolint: object_usage_linter

  iv <- d$interviews
  ok <- iv$trip_status == "complete"
  L_angler <- sum(iv$n_anglers[ok] * iv$trip_duration[ok]) / sum(iv$n_anglers[ok])
  expect_equal(t$estimate, e$estimates$estimate / L_angler)
  expect_equal(t$n, sum(ok))

  # Both defects move the number on this fixture, so each is pinned: the old
  # all-interview party mean, and the complete-trip party mean.
  expect_lt(t$estimate, 0.95 * e$estimates$estimate / mean(iv$trip_duration))
  expect_lt(t$estimate, 0.95 * e$estimates$estimate / mean(iv$trip_duration[ok]))
})

test_that("#689: the SE of trip length comes from the interview design, days as PSUs", {
  d <- tl_design()
  e <- tl_quiet(estimate_effort(d)) # nolint: object_usage_linter
  t <- tl_quiet(estimate_angler_trips(e, d))$estimates # nolint: object_usage_linter

  iv <- d$interviews
  iv$num <- iv$n_anglers * iv$trip_duration
  s <- suppressWarnings(survey::svydesign(ids = ~date, strata = ~day_type, data = iv))
  r <- survey::svyratio(~num, ~n_anglers, subset(s, trip_status == "complete"))
  L <- as.numeric(coef(r))
  se_L <- as.numeric(survey::SE(r))
  E <- e$estimates$estimate
  expect_equal(t$se^2, e$estimates$se^2 / L^2 + E^2 * se_L^2 / L^4)

  # df: the interview design's days less strata, not interviews less one.
  df <- as.numeric(survey::degf(subset(s, trip_status == "complete")))
  expect_lt(df, sum(iv$trip_status == "complete") - 1)
  expect_equal(t$ci_upper - t$estimate, stats::qt(0.975, df) * t$se)
})

test_that("#689: party-hours are divided by hours per party trip, inclusion-weighted on a bus route", {
  d <- build_br_design_for_tests(n_sites = 4, n_days = 8, n_interviews = 40, seed = 689) # nolint: object_usage_linter
  e <- tl_quiet(estimate_effort(d, target = "sampled_days")) # nolint: object_usage_linter
  t <- tl_quiet(estimate_angler_trips(e, d))$estimates # nolint: object_usage_linter

  iv <- d$interviews
  ok <- iv$trip_status == "complete" & !is.na(iv$trip_duration) & iv$trip_duration > 0
  w <- iv$.expansion / iv$.pi_i
  a <- if (identical(e$unit, "angler-hours")) iv$n_anglers else rep(1, nrow(iv))
  L_ht <- sum((w * a * iv$trip_duration)[ok]) / sum((w * a)[ok])
  expect_equal(t$estimate, e$estimates$estimate / L_ht)

  # The weights matter on this fixture: unequal site probabilities.
  L_plain <- sum((a * iv$trip_duration)[ok]) / sum(a[ok])
  expect_gt(abs(L_ht / L_plain - 1), 0.01)
})

test_that("#689: roving designs are refused, citing length-of-stay bias", {
  d <- tl_design(interview_type = "roving")
  e <- tl_quiet(estimate_effort(d)) # nolint: object_usage_linter
  expect_error(estimate_angler_trips(e, d), class = "creel_error_roving_trip_length") # nolint: object_usage_linter
  msg <- tryCatch(estimate_angler_trips(e, d), error = conditionMessage) # nolint: object_usage_linter
  expect_match(msg, "Pollock et al. 1994", fixed = TRUE)
  expect_match(msg, "Robson 1961", fixed = TRUE)
  expect_match(msg, "?estimate_angler_trips", fixed = TRUE)
})

test_that("#689: an unknown effort unit with varying party sizes is refused, not guessed", {
  data(example_calendar, envir = environment())
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  d <- tl_quiet(add_counts(creel_design(example_calendar, date = date, strata = day_type), example_counts)) # nolint: object_usage_linter
  d <- tl_quiet(add_interviews( # nolint: object_usage_linter
    d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = n_anglers
  ))
  e <- tl_quiet(estimate_effort(d)) # nolint: object_usage_linter
  expect_true(is.na(e$unit))
  msg <- tryCatch(estimate_angler_trips(e, d), error = function(err) err) # nolint: object_usage_linter
  expect_s3_class(msg, "creel_error_unknown_effort_unit")
  expect_match(conditionMessage(msg), "Pollock et al. 1994, p. 175", fixed = TRUE)
})

test_that("#689: with no complete trip there is no trip length", {
  data(example_calendar, envir = environment())
  data(example_interviews, envir = environment())
  iv <- example_interviews # nolint: object_usage_linter
  iv$trip_status <- "incomplete"
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- tl_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration
  ))
  e <- new_creel_estimates( # nolint: object_usage_linter
    estimates = tibble::tibble(estimate = 100, se = 10, ci_lower = 80, ci_upper = 120, n = 5L),
    method = "total", variance_method = "taylor", design = NULL, conf_level = 0.95, by_vars = NULL
  )
  expect_error(estimate_angler_trips(e, d), class = "creel_error_missing_data") # nolint: object_usage_linter
})

test_that("#689: a numeric grouping column takes the .overall row", {
  # An integer day-type indicator in counts and interviews.
  data(example_calendar, envir = environment())
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  wk_of <- function(dates) as.integer(example_calendar$day_type[match(dates, example_calendar$date)] == "weekend") # nolint: object_usage_linter
  cn <- example_counts # nolint: object_usage_linter
  cn$T_d <- 1
  cn$wk <- wk_of(cn$date)
  iv <- example_interviews # nolint: object_usage_linter
  iv$wk <- wk_of(iv$date)
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- tl_quiet(add_counts(d, cn, count_col = effort_hours, period_length_col = T_d)) # nolint: object_usage_linter
  d <- tl_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, effort = hours_fished, trip_status = trip_status,
    trip_duration = trip_duration, n_anglers = n_anglers
  ))
  g <- tl_quiet(estimate_effort(d, by = wk)) # nolint: object_usage_linter
  expect_type(g$estimates$wk, "integer")
  t <- tl_quiet(estimate_angler_trips(g, d))$estimates # nolint: object_usage_linter
  expect_identical(t$wk, c("0", "1", ".overall"))
  expect_equal(t$estimate[3], sum(t$estimate[1:2]))
})

test_that("#689: trips keep the effort target", {
  d <- tl_design()
  e <- tl_quiet(estimate_effort(d, target = "sampled_days")) # nolint: object_usage_linter
  expect_identical(tl_quiet(estimate_angler_trips(e, d))$effort_target, "sampled_days") # nolint: object_usage_linter
  g <- tl_quiet(estimate_effort(d, by = day_type, target = "sampled_days")) # nolint: object_usage_linter
  expect_identical(tl_quiet(estimate_angler_trips(g, d))$effort_target, "sampled_days") # nolint: object_usage_linter
})

# Review follow-ups ----

tl_iv_design <- function(iv) {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:6,
    day_type = c(rep("weekday", 5), rep("weekend", 2))
  )
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  tl_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch, effort = hours, trip_status = trip_status, trip_duration = duration
  ))
}

tl_fake_effort <- function(by = NULL, groups = NULL) {
  est <- if (is.null(by)) {
    tibble::tibble(estimate = 600, se = 30, ci_lower = 540, ci_upper = 660, n = 10L)
  } else {
    stats::setNames(
      tibble::tibble(groups, estimate = 300, se = 20, ci_lower = 260, ci_upper = 340, n = 5L),
      c(by, "estimate", "se", "ci_lower", "ci_upper", "n")
    )
  }
  new_creel_estimates( # nolint: object_usage_linter
    estimates = est, method = "total", variance_method = "taylor",
    design = NULL, conf_level = 0.95, by_vars = by
  )
}

tl_two_gear_iv <- function() {
  # Two gears, both fished on every day, so their mean lengths share days.
  data.frame(
    date = rep(as.Date("2024-06-03") + c(0, 1, 2, 5, 6), each = 4),
    day_type = rep(c("weekday", "weekday", "weekday", "weekend", "weekend"), each = 4),
    gear = rep(c("boat", "bank"), 10),
    trip_status = "complete",
    duration = c(2, 1, 2.5, 1.5, 5, 3, 4.5, 3.5, 3, 2, 3.5, 2.5, 6, 4, 5.5, 4.5, 2, 1.5, 2.5, 1),
    hours = 2, catch = 0L
  )
}

test_that("#689: groups sharing days carry the trip-length covariance into .overall", {
  iv <- tl_two_gear_iv()
  d <- tl_iv_design(iv)
  e <- tl_fake_effort("gear", c("bank", "boat"))
  t <- tl_quiet(estimate_angler_trips(e, d))$estimates # nolint: object_usage_linter
  rows <- t[t$gear != ".overall", ]
  ov <- t[t$gear == ".overall", ]

  s <- suppressWarnings(survey::svydesign(ids = ~date, strata = ~day_type, data = iv))
  r <- survey::svyby(~duration, ~gear, s, survey::svymean, covmat = TRUE)
  L <- r$duration[match(rows$gear, r$gear)]
  V <- stats::vcov(r)[match(rows$gear, r$gear), match(rows$gear, r$gear)]
  g <- 300 / L^2
  ref <- sum(20^2 / L^2) + drop(t(g) %*% V %*% g)
  expect_equal(ov$se^2, ref)
  # Both gears' lengths rise and fall with the day, so the covariance is
  # positive and the independent sum understates the total.
  expect_gt(V[1, 2], 0)
  expect_gt(ov$se^2, sum(rows$se^2))
})

test_that("#689: a group with complete trips on one day only has an unknown SE, not zero", {
  iv <- tl_two_gear_iv()
  iv$trip_status[iv$gear == "bank" & iv$date != as.Date("2024-06-03")] <- "incomplete"
  d <- tl_iv_design(iv)
  e <- tl_fake_effort("gear", c("bank", "boat"))
  expect_warning(
    t <- suppressMessages(estimate_angler_trips(e, d))$estimates, # nolint: object_usage_linter
    class = "creel_warning_single_interview_strata"
  )
  expect_true(is.finite(t$estimate[t$gear == "bank"]))
  expect_true(is.na(t$se[t$gear == "bank"]))
  expect_true(is.finite(t$se[t$gear == "boat"]))
  expect_true(is.na(t$se[t$gear == ".overall"]))
})

test_that("#689: an unknown group keeps its own trip length", {
  iv <- tl_two_gear_iv()
  iv$gear[iv$gear == "bank"] <- NA
  d <- tl_iv_design(iv)
  e <- tl_fake_effort("gear", c(NA, "boat"))
  t <- tl_quiet(estimate_angler_trips(e, d))$estimates # nolint: object_usage_linter
  expect_equal(nrow(t), 3L)
  expect_equal(t$estimate[is.na(t$gear)], 300 / mean(iv$duration[is.na(iv$gear)]))
})

test_that("#689: a group with no complete trips is named, not called a key mismatch", {
  iv <- tl_two_gear_iv()
  iv$trip_status[iv$gear == "bank"] <- "incomplete"
  d <- tl_iv_design(iv)
  e <- tl_fake_effort("gear", c("bank", "boat"))
  err <- tryCatch(estimate_angler_trips(e, d), error = function(e) e) # nolint: object_usage_linter
  expect_s3_class(err, "creel_error_missing_data")
  expect_match(conditionMessage(err), "bank")
})

test_that("#689: missing party sizes on angler-hours are refused, not read as constant", {
  d <- tl_design()
  d$interviews$n_anglers[d$interviews$trip_status == "complete"] <- NA
  e <- tl_quiet(estimate_effort(tl_design())) # nolint: object_usage_linter
  expect_error(estimate_angler_trips(e, d), class = "creel_error_missing_data") # nolint: object_usage_linter
})
