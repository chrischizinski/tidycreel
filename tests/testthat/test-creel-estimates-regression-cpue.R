make_simple_design <- function(n = 30L, seed = 42L) {
  set.seed(seed)
  dates <- seq.Date(as.Date("2024-06-01"), by = "day", length.out = 14L)
  cal <- data.frame(
    date = dates,
    day_type = rep(c("weekend", "weekday"), c(2L, 12L))
  )
  ints <- data.frame(
    # Both weekend days carry interviews, so each stratum spans at least two
    # days -- the variance is between days (GH #665).
    date = c(dates[1:2], sample(dates, n - 2L, replace = TRUE)),
    hours_fished = round(rgamma(n, 2.5, 0.7), 2),
    catch_total = rnbinom(n, mu = 5, size = 0.6),
    trip_status = "complete"
  )
  # Each interview takes its day's stratum from the calendar (GH #449).
  ints$day_type <- cal$day_type[match(ints$date, cal$date)]
  # Counts: across day types a regression rate is each day type's slope
  # weighted by its effort (GH #691).
  creel_design(cal, date = date, strata = day_type) |>
    add_rate_counts() |>
    add_interviews(ints, catch = catch_total, effort = hours_fished, trip_status = trip_status)
}

test_that("regression estimator returns creel_estimates with correct method", {
  d <- make_simple_design()
  r <- estimate_catch_rate(d, estimator = "regression")
  expect_s3_class(r, "creel_estimates")
  expect_equal(r$method, "regression-cpue")
  # The variance that ran is the one asked for, as for every other estimator
  # (GH #665): the slope's SE no longer ignores `variance`.
  expect_equal(r$variance_method, "taylor")
  rb <- estimate_catch_rate(d, estimator = "regression", variance = "jackknife")
  expect_equal(rb$variance_method, "jackknife")
})

test_that("regression estimator estimates data frame has required columns", {
  d <- make_simple_design()
  r <- estimate_catch_rate(d, estimator = "regression")
  expect_named(r$estimates, c("estimate", "se", "ci_lower", "ci_upper", "n"))
})

test_that("regression estimate is numeric and positive for positive catch data", {
  d <- make_simple_design()
  r <- estimate_catch_rate(d, estimator = "regression")
  expect_true(is.numeric(r$estimates$estimate))
  expect_true(r$estimates$estimate > 0)
})

test_that("regression SE > 0", {
  d <- make_simple_design()
  r <- estimate_catch_rate(d, estimator = "regression")
  expect_true(r$estimates$se > 0)
})

test_that("regression CI brackets estimate", {
  d <- make_simple_design()
  r <- estimate_catch_rate(d, estimator = "regression")
  expect_true(r$estimates$ci_lower < r$estimates$estimate)
  expect_true(r$estimates$ci_upper > r$estimates$estimate)
})

test_that("regression force_origin = TRUE vs FALSE produce different estimates", {
  d <- make_simple_design(seed = 7L)
  r1 <- estimate_catch_rate(d, estimator = "regression", force_origin = TRUE)
  r2 <- estimate_catch_rate(d, estimator = "regression", force_origin = FALSE)
  expect_false(isTRUE(all.equal(r1$estimates$estimate, r2$estimates$estimate)))
})

test_that("regression slope matches manual OLS (force_origin = TRUE)", {
  d <- make_simple_design(n = 50L, seed = 3L)
  r <- estimate_catch_rate(d, estimator = "regression", force_origin = TRUE)

  ints <- d$interviews
  catch <- as.numeric(ints[[d$catch_col]])
  effort <- as.numeric(ints[[d$angler_effort_col]])
  # Each day type's own through-origin OLS slope, combined by the day types'
  # effort (GH #691).
  b_h <- tapply(catch * effort, ints$day_type, sum) / tapply(effort^2, ints$day_type, sum)
  E <- suppressWarnings(suppressMessages(estimate_effort(d, by = day_type)))$estimates
  E_h <- stats::setNames(E$estimate, E$day_type)[names(b_h)]
  manual_beta <- sum(E_h * b_h) / sum(E_h)

  expect_equal(r$estimates$estimate, manual_beta, tolerance = 1e-9)
  # Not the single slope over every interview, which weights the day types by
  # their interviews.
  expect_false(isTRUE(all.equal(r$estimates$estimate, sum(catch * effort) / sum(effort^2))))
})

test_that("regression grouped by day_type returns rows per group", {
  d <- make_simple_design(n = 60L, seed = 10L)
  r <- estimate_catch_rate(d, estimator = "regression", by = day_type)
  expect_s3_class(r, "creel_estimates")
  expect_true(nrow(r$estimates) > 1L)
  expect_true("day_type" %in% names(r$estimates))
})

test_that("regression is in valid_estimators (no abort)", {
  d <- make_simple_design()
  expect_no_error(estimate_catch_rate(d, estimator = "regression"))
})

test_that("invalid estimator still aborts", {
  d <- make_simple_design()
  expect_error(estimate_catch_rate(d, estimator = "bad_estimator"))
})


test_that("compare_cpue_estimators includes rom and regression", {
  d <- make_simple_design(n = 40L)
  comp <- compare_cpue_estimators(d)
  expect_true("rom" %in% comp$cpue_method)
  expect_true("regression" %in% comp$cpue_method)
})

test_that("compare_cpue_estimators grouped returns group columns", {
  d <- make_simple_design(n = 60L, seed = 20L)
  comp <- compare_cpue_estimators(d, by = day_type)
  expect_true("day_type" %in% names(comp))
})

test_that("compare_cpue_estimators conf_level validation", {
  d <- make_simple_design()
  expect_error(compare_cpue_estimators(d, conf_level = 0.1))
})

test_that("autoplot.cpue_comparison returns ggplot", {
  skip_if_not_installed("ggplot2")
  d <- make_simple_design(n = 40L)
  comp <- compare_cpue_estimators(d)
  p <- autoplot(comp)
  expect_s3_class(p, "ggplot")
})
