make_simple_design <- function(n = 30L, seed = 42L) {
  set.seed(seed)
  dates <- seq.Date(as.Date("2024-06-01"), by = "day", length.out = 14L)
  cal   <- data.frame(
    date     = dates,
    day_type = rep(c("weekend", "weekday"), c(2L, 12L))
  )
  ints <- data.frame(
    date         = sample(dates, n, replace = TRUE),
    day_type     = sample(c("weekday", "weekend"), n, replace = TRUE),
    hours_fished = round(rgamma(n, 2.5, 0.7), 2),
    catch_total  = rnbinom(n, mu = 5, size = 0.6),
    trip_status  = "complete"
  )
  creel_design(cal, date = date, strata = day_type) |>
    add_interviews(ints, catch = catch_total, effort = hours_fished,
                   trip_status = trip_status)
}

test_that("regression estimator returns creel_estimates with correct method", {
  d <- make_simple_design()
  r <- estimate_catch_rate(d, estimator = "regression")
  expect_s3_class(r, "creel_estimates")
  expect_equal(r$method, "regression-cpue")
  expect_equal(r$variance_method, "jackknife")
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

  ints   <- d$interviews
  catch  <- as.numeric(ints[[d$catch_col]])
  effort <- as.numeric(ints[[d$angler_effort_col]])
  manual_beta <- sum(catch * effort) / sum(effort^2)

  expect_equal(r$estimates$estimate, manual_beta, tolerance = 1e-9)
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

# ── .ols_slope helper ─────────────────────────────────────────────────────────

test_that(".ols_slope force_origin=TRUE = sum(cy)/sum(f^2)", {
  set.seed(1L)
  c_ <- rnorm(10, 5, 1)
  f_ <- abs(rnorm(10, 3, 0.5))
  beta <- tidycreel:::.ols_slope(c_, f_, TRUE)
  expect_equal(beta, sum(c_ * f_) / sum(f_^2), tolerance = 1e-12)
})

test_that(".ols_slope force_origin=FALSE matches lm coefficient", {
  set.seed(2L)
  c_ <- rnorm(20, 5, 2)
  f_ <- abs(rnorm(20, 3, 1))
  beta <- tidycreel:::.ols_slope(c_, f_, FALSE)
  lm_beta <- coef(lm(c_ ~ f_))[["f_"]]
  expect_equal(beta, lm_beta, tolerance = 1e-10)
})

# ── .jackknife_slope_se helper ────────────────────────────────────────────────

test_that(".jackknife_slope_se returns positive numeric", {
  set.seed(3L)
  c_ <- rnorm(15, 5, 1)
  f_ <- abs(rnorm(15, 3, 0.5))
  se <- tidycreel:::.jackknife_slope_se(c_, f_, TRUE)
  expect_true(is.numeric(se))
  expect_true(se > 0)
})

test_that(".jackknife_slope_se near zero for near-perfect linear data", {
  f_ <- seq(1, 10, length.out = 20)
  c_ <- 2.5 * f_ + rnorm(20, 0, 0.001)
  se <- tidycreel:::.jackknife_slope_se(c_, f_, TRUE)
  expect_true(se < 0.01)
})

# ── compare_cpue_estimators ───────────────────────────────────────────────────

test_that("compare_cpue_estimators returns cpue_comparison tibble", {
  d    <- make_simple_design(n = 40L)
  comp <- compare_cpue_estimators(d)
  expect_s3_class(comp, "cpue_comparison")
  expect_true("cpue_method" %in% names(comp))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(comp)))
})

test_that("compare_cpue_estimators includes rom and regression", {
  d    <- make_simple_design(n = 40L)
  comp <- compare_cpue_estimators(d)
  expect_true("rom" %in% comp$cpue_method)
  expect_true("regression" %in% comp$cpue_method)
})

test_that("compare_cpue_estimators grouped returns group columns", {
  d    <- make_simple_design(n = 60L, seed = 20L)
  comp <- compare_cpue_estimators(d, by = day_type)
  expect_true("day_type" %in% names(comp))
})

test_that("compare_cpue_estimators conf_level validation", {
  d <- make_simple_design()
  expect_error(compare_cpue_estimators(d, conf_level = 0.1))
})

test_that("autoplot.cpue_comparison returns ggplot", {
  skip_if_not_installed("ggplot2")
  d    <- make_simple_design(n = 40L)
  comp <- compare_cpue_estimators(d)
  p    <- autoplot(comp)
  expect_s3_class(p, "ggplot")
})
