# GH #582: angler trips from aerial effort.
#
# Trips = effort / mean trip length, with the delta method (Powell 2007).
# Aerial effort is angler-hours like ground effort, but it was refused: the
# effort guard admitted "total" and "total-sections" only, and pooled aerial
# effort is tagged "aerial_total" ("aerial_glmm_total" on the GLMM path).
#
# Grouped aerial effort was already admitted (it is tagged "total"), and there
# the summed .overall row was wrong. Each group's SE carries the shared
# visibility and angler-ratio term E_h * se / value, and the .overall row added
# the rows in quadrature, so that term entered as sum(T_h^2) * rel instead of
# T^2 * rel: the trap of #150, on this fixture an SE of 110.8 against 121.8.

atr_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

atr_design <- function(v = 0.8, v_se = 0.05, a = 0.9, a_se = 0.03) {
  cal <- data.frame(
    date = as.Date("2024-07-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2)
  )
  d <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = v, visibility_se = v_se,
    angler_ratio = a, angler_ratio_se = a_se, h_open = 14
  )
  s <- cal[c(1, 2, 5, 3, 4, 8), ]
  d <- add_counts(d, data.frame(s, n_anglers = c(22L, 18L, 30L, 45L, 38L, 51L))) # nolint: object_usage_linter
  # Weekend trips run 1.5 h longer, so the strata have different mean trip
  # lengths and the .overall row is not the pooled E / L.
  iv <- data.frame(
    interview_id = 1:30,
    date = rep(s$date, each = 5),
    day_type = rep(s$day_type, each = 5),
    trip_status = "complete",
    hours_fished = rep(c(2.5, 3, 1.5, 4, 2, 3.5, 1, 2.5, 3, 4.5), 3),
    dur = rep(c(3, 4, 2, 5, 2.5, 4, 1.5, 3, 3.5, 5), 3) + rep(c(0, 1.5), each = 15),
    walleye = rep(0:2, 10)
  )
  add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = walleye, effort = hours_fished, trip_status = trip_status,
    trip_duration = dur, n_anglers = 1
  )
}

atr_rel <- (0.05 / 0.8)^2 + (0.03 / 0.9)^2

test_that("#582: pooled aerial effort gives trips, with the calibration SE carried through", {
  d <- atr_quiet(atr_design())
  e <- atr_quiet(estimate_effort(d)) # nolint: object_usage_linter
  expect_identical(e$method, "aerial_total")
  t <- atr_quiet(estimate_angler_trips(e, d))$estimates # nolint: object_usage_linter

  # Trip length from the interview design: days are PSUs (GH #689).
  ref <- survey::svymean(~dur, suppressWarnings(survey::svydesign(ids = ~date, strata = ~day_type, data = d$interviews)))
  L <- as.numeric(coef(ref))
  se_L <- as.numeric(survey::SE(ref))
  E <- e$estimates$estimate
  expect_equal(t$estimate, E / L)
  expect_equal(t$se^2, e$estimates$se^2 / L^2 + E^2 * se_L^2 / L^4)

  # The a and v terms reach the trips SE: same point estimate, and the
  # variance moves by exactly the shared term on the trips scale.
  d0 <- atr_quiet(atr_design(v_se = 0, a_se = 0))
  t0 <- atr_quiet(estimate_angler_trips(atr_quiet(estimate_effort(d0)), d0))$estimates # nolint: object_usage_linter
  expect_equal(t$estimate, t0$estimate)
  expect_equal(t$se^2, t0$se^2 + t$estimate^2 * atr_rel)
})

test_that("#582: the shared a and v term enters the .overall trips row once", {
  d1 <- atr_quiet(atr_design())
  d0 <- atr_quiet(atr_design(v_se = 0, a_se = 0))
  t1 <- atr_quiet(estimate_angler_trips(atr_quiet(estimate_effort(d1, by = day_type)), d1))$estimates # nolint: object_usage_linter
  t0 <- atr_quiet(estimate_angler_trips(atr_quiet(estimate_effort(d0, by = day_type)), d0))$estimates # nolint: object_usage_linter
  rows1 <- t1[t1$day_type != ".overall", ]
  rows0 <- t0[t0$day_type != ".overall", ]
  ov1 <- t1[t1$day_type == ".overall", ]
  ov0 <- t0[t0$day_type == ".overall", ]

  # Each stratum row is its own reported quantity and carries the term itself.
  expect_equal(nrow(rows1), 2L)
  expect_equal(rows1$se^2, rows0$se^2 + rows1$estimate^2 * atr_rel)
  # The total carries it once, on the total: T^2 * rel.
  expect_equal(ov1$estimate, sum(rows1$estimate))
  expect_equal(ov1$se^2, ov0$se^2 + ov1$estimate^2 * atr_rel)
  # The mutant this pins: rows summed in quadrature give sum(T_h^2) * rel,
  # which is strictly smaller with two positive strata.
  quadrature <- sqrt(sum(rows1$se^2))
  expect_gt(ov1$se, quadrature * 1.05)
})

test_that("#582: per-acre density admits aerial effort and rescales it", {
  d <- atr_quiet(atr_design())
  e <- atr_quiet(estimate_effort(d)) # nolint: object_usage_linter
  pa <- estimate_effort_per_acre(e, acres = 250) # nolint: object_usage_linter
  expect_equal(pa$estimates$estimate, e$estimates$estimate / 250)
  expect_equal(pa$estimates$se, e$estimates$se / 250)
  expect_identical(pa$unit, "angler-hours/acre")
})

test_that("#582: an unknown visibility SE leaves the trips SE unknown", {
  # The declared "none" opt-out: v = 1, its SE unknown, so effort's SE is NA.
  d <- atr_quiet(atr_design(v = "none", v_se = NULL))
  t <- atr_quiet(estimate_angler_trips(atr_quiet(estimate_effort(d, by = day_type)), d))$estimates # nolint: object_usage_linter
  expect_true(all(is.finite(t$estimate)))
  expect_true(all(is.na(t$se)))
})

test_that("#582: GLMM aerial trips use the effort rows' full covariance", {
  skip_if_not_installed("lme4")
  data("example_aerial_glmm_counts", envir = environment())
  counts <- example_aerial_glmm_counts # nolint: object_usage_linter
  cal <- unique(counts[, c("date", "day_type")])
  cal <- cal[order(cal$date), ]
  d <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = 0.8, visibility_se = 0.05,
    angler_ratio = 1, angler_ratio_se = 0, h_open = 14
  )
  d <- atr_quiet(add_counts(d, counts, count_col = n_anglers)) # nolint: object_usage_linter
  set.seed(582)
  iv <- data.frame(
    date = rep(cal$date, each = 4),
    day_type = rep(cal$day_type, each = 4),
    trip_status = "complete",
    hours_fished = round(stats::runif(4 * nrow(cal), 1, 5), 1),
    catch = 0L
  )
  iv$dur <- iv$hours_fished + ifelse(iv$day_type == "weekend", 1, 0)
  d <- atr_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch, effort = hours_fished, trip_status = trip_status,
    trip_duration = dur, n_anglers = 1
  ))

  g <- atr_quiet(estimate_effort_aerial_glmm(d, time_col = time_of_flight, by = day_type)) # nolint: object_usage_linter
  expect_identical(g$method, "aerial_glmm_total")
  t <- atr_quiet(estimate_angler_trips(g, d))$estimates # nolint: object_usage_linter
  rows <- t[t$day_type != ".overall", ]
  ov <- t[t$day_type == ".overall", ]

  E <- g$estimates$estimate
  ref <- survey::svyby(
    ~dur, ~day_type, suppressWarnings(survey::svydesign(ids = ~date, strata = ~day_type, data = iv)), survey::svymean
  )
  ref <- ref[match(as.character(g$estimates$day_type), ref$day_type), ]
  L <- ref$dur
  se_L <- as.numeric(survey::SE(ref))
  gvec <- 1 / L
  ref_var <- drop(t(gvec) %*% g$strata_vcov %*% gvec) + sum(E^2 * se_L^2 / L^4)
  expect_equal(ov$se^2, ref_var)
  # The GLMM rows are positively correlated (shared coefficients and v), so
  # treating them as independent would understate the total.
  expect_gt(ov$se^2, sum(rows$se^2))

  # Pooled GLMM effort is admitted too.
  p <- atr_quiet(estimate_effort_aerial_glmm(d, time_col = time_of_flight)) # nolint: object_usage_linter
  expect_true(is.finite(atr_quiet(estimate_angler_trips(p, d))$estimates$estimate))
})

test_that("#582: mean-day GLMM effort is refused, not summed across day types", {
  skip_if_not_installed("lme4")
  # Why: one average weekday plus one average weekend day is neither a daily
  # nor a season figure, and the trips result carries no target label.
  data("example_aerial_glmm_counts", envir = environment())
  counts <- example_aerial_glmm_counts # nolint: object_usage_linter
  cal <- unique(counts[, c("date", "day_type")])
  d <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = "none", angler_ratio = 1, angler_ratio_se = 0, h_open = 14
  )
  d <- atr_quiet(add_counts(d, counts, count_col = n_anglers)) # nolint: object_usage_linter
  iv <- data.frame(
    date = rep(cal$date, each = 3), day_type = rep(cal$day_type, each = 3),
    trip_status = "complete", hours_fished = 2, dur = rep(c(2, 3, 4), nrow(cal)), catch = 0L
  )
  d <- atr_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch, effort = hours_fished, trip_status = trip_status,
    trip_duration = dur, n_anglers = 1
  ))
  g <- atr_quiet(estimate_effort_aerial_glmm( # nolint: object_usage_linter
    d,
    time_col = time_of_flight, by = day_type, target = "mean_day"
  ))
  expect_error(estimate_angler_trips(g, d), class = "creel_error_invalid_input") # nolint: object_usage_linter
})
