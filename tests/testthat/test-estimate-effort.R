# Test helpers ----

#' Create test calendar data with 4+ rows per stratum
make_test_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
}

#' Create test count data matching test calendar structure
#' Each day_type stratum has at least 4 distinct dates (PSUs)
make_test_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    effort_hours = c(15, 23, 18, 21, 45, 52, 48, 51),
    stringsAsFactors = FALSE
  )
}

#' Create test creel_design with counts already attached
make_test_design_with_counts <- function() {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- make_test_counts()
  add_counts(design, counts) # nolint: object_usage_linter
}

# Basic behavior tests ----

test_that("estimate_effort returns creel_estimates class object", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_effort result has estimates tibble with correct columns", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_effort result has method == 'total'", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_equal(result$method, "total")
})

test_that("estimate_effort result has variance_method == 'taylor'", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_effort result has conf_level == 0.95 by default", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_effort with custom conf_level = 0.90 produces different CI bounds", {
  design <- make_test_design_with_counts()

  result_95 <- estimate_effort(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_effort(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

test_that("estimate_effort errors on non-creel_design input", {
  fake_design <- list(counts = data.frame(effort_hours = 1:10))

  expect_error(
    estimate_effort(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_effort errors when counts not attached", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    estimate_effort(design), # nolint: object_usage_linter
    "add_counts"
  )
})

# Tier 2 validation tests ----

test_that("estimate_effort warns when count data has zero values", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- make_test_counts()
  counts$effort_hours[1] <- 0
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  expect_warning(
    estimate_effort(design2), # nolint: object_usage_linter
    "zero"
  )
})

test_that("estimate_effort warns when count data has negative values", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- make_test_counts()
  counts$effort_hours[1] <- -5
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  expect_warning(
    estimate_effort(design2), # nolint: object_usage_linter
    "negative"
  )
})

test_that("estimate_effort warns when stratum has < 3 observations", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Only 2 observations per stratum
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    effort_hours = c(15, 23, 45, 52)
  )
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  expect_warning(
    estimate_effort(design2), # nolint: object_usage_linter
    "sparse|less than 3|< 3"
  )
})

test_that("estimate_effort produces no warnings when data is clean", {
  design <- make_test_design_with_counts()

  # Should not produce warnings (no suppressWarnings needed)
  expect_no_warning <- function(expr) {
    warnings <- character()
    result <- withCallingHandlers(
      expr,
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
      }
    )

    # Filter out survey package warnings (expected)
    tidycreel_warnings <- grepl("zero|negative|sparse", warnings, ignore.case = TRUE)

    expect_false(any(tidycreel_warnings))
  }

  expect_no_warning(estimate_effort(design)) # nolint: object_usage_linter
})

# Reference tests (TEST-06 and TEST-07) ----

test_that("estimate_effort point estimate matches manual survey::svytotal", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_estimate <- as.numeric(coef(manual_result))

  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
})

test_that("estimate_effort SE matches manual SE() extraction", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_se <- as.numeric(survey::SE(manual_result))

  expect_equal(result$estimates$se, manual_se, tolerance = 1e-10)
})

test_that("estimate_effort CI bounds match manual confint()", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_ci <- confint(manual_result, level = 0.95)

  expect_equal(result$estimates$ci_lower, manual_ci[1, 1], tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci[1, 2], tolerance = 1e-10)
})

test_that("estimate_effort variance matches manual vcov() diagonal", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_variance <- as.numeric(vcov(manual_result))

  # Variance should equal SE^2
  expect_equal(result$estimates$se^2, manual_variance, tolerance = 1e-10)
})
