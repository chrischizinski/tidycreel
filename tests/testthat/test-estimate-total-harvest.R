# Test helpers ----

#' Create test design with BOTH counts and interviews (for total harvest)
make_total_harvest_design <- function() {
  # Use example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design with both data sources including harvest
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    effort = hours_fished # nolint: object_usage_linter
  )

  design
}

#' Create test design without harvest column
make_design_no_harvest <- function() { # nolint: object_length_linter
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design but don't specify harvest parameter
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished # nolint: object_usage_linter
    # Note: no harvest parameter
  )

  design
}

# Basic behavior tests ----

test_that("estimate_total_harvest returns creel_estimates class object", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_harvest result has estimates tibble with correct columns", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_total_harvest result method is 'product-total-harvest'", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$method, "product-total-harvest")
})

test_that("estimate_total_harvest result variance_method is 'taylor' by default", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_total_harvest result conf_level is 0.95 by default", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_total_harvest estimate is a positive numeric value", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_total_harvest errors when design is not creel_design", {
  fake_design <- "not a design"

  expect_error(
    estimate_total_harvest(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_total_harvest errors when design has no counts", {
  # Create design with only interviews
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished
  )

  expect_error(
    estimate_total_harvest(design), # nolint: object_usage_linter
    "add_counts"
  )
})

test_that("estimate_total_harvest errors when design has no interviews", {
  # Create design with only counts
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter

  expect_error(
    estimate_total_harvest(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_total_harvest errors when design has no harvest_col", {
  design <- make_design_no_harvest()

  expect_error(
    estimate_total_harvest(design), # nolint: object_usage_linter
    "harvest"
  )
})

test_that("estimate_total_harvest errors for invalid variance method", {
  design <- make_total_harvest_design()

  expect_error(
    estimate_total_harvest(design, variance = "invalid_method"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

# Reference tests ----

test_that("total harvest estimate equals effort * hpue exactly", {
  design <- make_total_harvest_design()

  # Get total harvest estimate
  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  hpue <- estimate_harvest(design) # nolint: object_usage_linter

  # Product should match exactly
  expected <- effort$estimates$estimate * hpue$estimates$estimate

  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
})

test_that("total harvest SE matches manual delta method formula", {
  design <- make_total_harvest_design()

  # Get total harvest estimate
  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  hpue <- estimate_harvest(design) # nolint: object_usage_linter

  # Extract components
  effort_est <- effort$estimates$estimate # nolint: object_name_linter
  hpue_est <- hpue$estimates$estimate # nolint: object_name_linter
  var_effort <- effort$estimates$se^2 # nolint: object_name_linter
  var_hpue <- hpue$estimates$se^2 # nolint: object_name_linter

  # Manual delta method (first-order approximation)
  manual_variance <- (effort_est^2 * var_hpue) + (hpue_est^2 * var_effort)
  manual_se <- sqrt(manual_variance)

  # Allow slightly looser tolerance for SE since svycontrast may include second-order term
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-6)
})

# Grouped estimation tests ----

test_that("estimate_total_harvest grouped by day_type works", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design, by = day_type) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_total_harvest grouped result has correct number of rows", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design, by = day_type) # nolint: object_usage_linter

  # Should have weekday and weekend
  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_total_harvest grouped result n is per-group", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design, by = day_type) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Total harvest vs total catch relationship test ----

test_that("total harvest estimate <= total catch estimate", {
  design <- make_total_harvest_design()

  # Get both estimates
  result_harvest <- estimate_total_harvest(design) # nolint: object_usage_linter
  result_catch <- estimate_total_catch(design) # nolint: object_usage_linter

  # Harvest should be <= catch (kept fish subset of total catch)
  expect_true(result_harvest$estimates$estimate <= result_catch$estimates$estimate)
})
