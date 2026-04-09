# Tests for estimate_effort_aerial_glmm()
# Covers GLMM-01 (basic usage), GLMM-02 (output contract), GLMM-03 (guards)

# Shared fixture: aerial creel_design with example_aerial_glmm_counts ----
make_aerial_glmm_design <- function() {
  data("example_aerial_glmm_counts", envir = environment())
  aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")]) # nolint: object_usage_linter
  aerial_cal <- aerial_cal[order(aerial_cal$date), ]
  design <- creel_design( # nolint: object_usage_linter
    aerial_cal,
    date = date,
    strata = day_type, # nolint: object_usage_linter
    survey_type = "aerial",
    h_open = 14
  )
  add_counts(design, example_aerial_glmm_counts) # nolint: object_usage_linter
}

# GLMM-01: Basic usage ----

test_that("estimate_effort_aerial_glmm() returns without error for aerial design", {
  design <- make_aerial_glmm_design()
  expect_no_error(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  )
})

test_that("default Askey formula fits; result$estimates$estimate is finite positive", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  est <- result$estimates$estimate
  expect_true(is.numeric(est))
  expect_true(is.finite(est))
  expect_true(est > 0)
})

test_that("custom formula is accepted without error", {
  design <- make_aerial_glmm_design()
  expect_no_error(
    estimate_effort_aerial_glmm(
      design,
      time_col = time_of_flight,
      formula = n_anglers ~ time_of_flight + (1 | date)
    )
  )
})

test_that("boot = TRUE with nboot = 10 returns valid CIs", {
  design <- make_aerial_glmm_design()
  result <- suppressMessages(
    estimate_effort_aerial_glmm(
      design,
      time_col = time_of_flight,
      boot = TRUE,
      nboot = 10L
    )
  )
  est <- result$estimates$estimate
  ci_lower <- result$estimates$ci_lower
  ci_upper <- result$estimates$ci_upper
  expect_true(ci_lower < est)
  expect_true(ci_upper > est)
})

# GLMM-02: Output contract ----

test_that("result inherits 'creel_estimates'", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimates tibble has required columns", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  required_cols <- c("estimate", "se", "se_between", "se_within", "ci_lower", "ci_upper", "n")
  expect_true(all(required_cols %in% names(result$estimates)))
})

test_that("result$estimates$se_within is NA_real_", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  expect_true(is.na(result$estimates$se_within))
  expect_type(result$estimates$se_within, "double")
})

test_that("result$method is 'aerial_glmm_total'", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  expect_equal(result$method, "aerial_glmm_total")
})

# GLMM-03: Guards ----

test_that("cli_abort() fires when design_type is not 'aerial'", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-10", "2024-06-11", "2024-06-17", "2024-06-18"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
  bad_design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = rep(20, 8),
    time_of_flight = rep(10.0, 8),
    stringsAsFactors = FALSE
  )
  bad_design <- add_counts(bad_design, counts) # nolint: object_usage_linter
  expect_error(
    estimate_effort_aerial_glmm(bad_design, time_col = time_of_flight),
    class = "rlang_error"
  )
})

test_that("rlang::check_installed fires an rlang_error for a non-existent package", {
  # Validates the rlang::check_installed() mechanism used in estimate_effort_aerial_glmm()
  expect_error(
    rlang::check_installed("lme4_notinstalled_package_xyz"),
    class = "rlang_error"
  )
})
