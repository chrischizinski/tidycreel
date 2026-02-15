# Test helpers ----

#' Create test design for validation testing
#' Creates balanced design with both complete and incomplete trips
make_validation_design <- function(n_complete = 50, n_incomplete = 50, cpue_diff = 0) {
  # Calendar with sufficient dates
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create interviews: n_complete complete + n_incomplete incomplete
  # cpue_diff controls difference between complete and incomplete CPUE
  # cpue_diff = 0 means identical CPUE
  n_total <- n_complete + n_incomplete

  # Complete trips: CPUE ~ 2.0 (catch ~ 6, effort ~ 3)
  complete_catch <- rep(c(5, 6, 7, 6, 5), length.out = n_complete)
  complete_effort <- rep(c(2.5, 3.0, 3.5, 3.0, 2.5), length.out = n_complete)

  # Incomplete trips: CPUE adjusted by cpue_diff
  # cpue_diff = 0 -> CPUE ~ 2.0 (same as complete)
  # cpue_diff = 0.5 -> CPUE ~ 2.5 (different from complete)
  target_incomplete_cpue <- 2.0 + cpue_diff
  incomplete_effort <- rep(c(2.0, 2.5, 3.0, 2.5, 2.0), length.out = n_incomplete)
  incomplete_catch <- round(incomplete_effort * target_incomplete_cpue)

  # Combine complete and incomplete trips
  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), length.out = n_total)),
    catch_total = c(complete_catch, incomplete_catch),
    hours_fished = c(complete_effort, incomplete_effort),
    trip_status = c(rep("complete", n_complete), rep("incomplete", n_incomplete)),
    trip_duration = c(complete_effort, incomplete_effort), # Duration matches effort
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

#' Create grouped validation design
make_grouped_validation_design <- function(group_a_diff = 0, group_b_diff = 0) {
  # Calendar with two groups
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    location = rep(c("site_a", "site_b"), times = 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create 30 complete + 30 incomplete per location
  # Site A: cpue_diff = group_a_diff
  # Site B: cpue_diff = group_b_diff

  # Site A complete: CPUE ~ 2.0
  site_a_complete_catch <- rep(c(5, 6, 7, 6, 5), length.out = 30)
  site_a_complete_effort <- rep(c(2.5, 3.0, 3.5, 3.0, 2.5), length.out = 30)

  # Site A incomplete: CPUE adjusted by group_a_diff
  target_a_incomplete_cpue <- 2.0 + group_a_diff
  site_a_incomplete_effort <- rep(c(2.0, 2.5, 3.0, 2.5, 2.0), length.out = 30)
  site_a_incomplete_catch <- round(site_a_incomplete_effort * target_a_incomplete_cpue)

  # Site B complete: CPUE ~ 2.0
  site_b_complete_catch <- rep(c(5, 6, 7, 6, 5), length.out = 30)
  site_b_complete_effort <- rep(c(2.5, 3.0, 3.5, 3.0, 2.5), length.out = 30)

  # Site B incomplete: CPUE adjusted by group_b_diff
  target_b_incomplete_cpue <- 2.0 + group_b_diff
  site_b_incomplete_effort <- rep(c(2.0, 2.5, 3.0, 2.5, 2.0), length.out = 30)
  site_b_incomplete_catch <- round(site_b_incomplete_effort * target_b_incomplete_cpue)

  # Combine all
  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), length.out = 120)),
    location = rep(c("site_a", "site_b"), each = 60),
    catch_total = c(
      site_a_complete_catch, site_a_incomplete_catch,
      site_b_complete_catch, site_b_incomplete_catch
    ),
    hours_fished = c(
      site_a_complete_effort, site_a_incomplete_effort,
      site_b_complete_effort, site_b_incomplete_effort
    ),
    trip_status = rep(c(rep("complete", 30), rep("incomplete", 30)), times = 2),
    trip_duration = c(
      site_a_complete_effort, site_a_incomplete_effort,
      site_b_complete_effort, site_b_incomplete_effort
    ),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

# Basic functionality tests ----

test_that("validate_incomplete_trips returns creel_tost_validation S3 object", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  expect_s3_class(result, "creel_tost_validation")
  expect_type(result, "list")
})

test_that("validate_incomplete_trips includes required components", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Required components
  expect_true("overall_test" %in% names(result))
  expect_true("equivalence_threshold" %in% names(result))
  expect_true("passed" %in% names(result))
  expect_true("recommendation" %in% names(result))
  expect_true("metadata" %in% names(result))

  # Metadata should contain sample sizes, estimates, SEs, CIs for both trip types
  expect_true("complete" %in% names(result$metadata))
  expect_true("incomplete" %in% names(result$metadata))
  expect_true("n" %in% names(result$metadata$complete))
  expect_true("estimate" %in% names(result$metadata$complete))
  expect_true("se" %in% names(result$metadata$complete))
})

# TOST test structure tests ----

test_that("validate_incomplete_trips performs TOST with correct structure", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # overall_test should contain TOST results
  expect_true("p_lower" %in% names(result$overall_test))
  expect_true("p_upper" %in% names(result$overall_test))
  expect_true("equivalence_passed" %in% names(result$overall_test))

  # p-values should be numeric and between 0 and 1
  expect_type(result$overall_test$p_lower, "double")
  expect_type(result$overall_test$p_upper, "double")
  expect_gte(result$overall_test$p_lower, 0)
  expect_lte(result$overall_test$p_lower, 1)
  expect_gte(result$overall_test$p_upper, 0)
  expect_lte(result$overall_test$p_upper, 1)

  # equivalence_passed should be logical
  expect_type(result$overall_test$equivalence_passed, "logical")
})

test_that("TOST passes when estimates are identical", {
  # cpue_diff = 0 means complete and incomplete have same CPUE
  design <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 0)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Should pass equivalence (estimates are effectively identical)
  expect_true(result$overall_test$equivalence_passed)
  expect_true(result$passed)
})

test_that("TOST fails when estimates differ substantially", {
  # cpue_diff = 1.0 means incomplete CPUE is 1.0 higher (large difference)
  # With default 20% threshold on CPUE ~ 2.0, threshold is 0.4
  # Difference of 1.0 should fail equivalence
  design <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 1.0)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Should fail equivalence (large difference)
  expect_false(result$overall_test$equivalence_passed)
  expect_false(result$passed)
})

# Package option tests ----

test_that("equivalence threshold respects package option", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  # Set custom threshold
  withr::local_options(tidycreel.equivalence_threshold = 0.15)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Should use 0.15 (15%) threshold
  expect_equal(result$equivalence_threshold, 0.15)
})

test_that("default equivalence threshold is 0.20", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  # Clear any custom option
  withr::local_options(tidycreel.equivalence_threshold = NULL)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Should default to 0.20 (20%)
  expect_equal(result$equivalence_threshold, 0.20)
})

# Grouped estimation tests ----

test_that("validate_incomplete_trips handles grouped estimation", {
  design <- make_grouped_validation_design(group_a_diff = 0, group_b_diff = 0)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished, by = location)

  # Should have group_tests component
  expect_true("group_tests" %in% names(result))

  # group_tests should be a data frame with location column
  expect_s3_class(result$group_tests, "data.frame")
  expect_true("location" %in% names(result$group_tests))

  # Each group should have TOST results
  expect_true("equivalence_passed" %in% names(result$group_tests))
})

test_that("grouped validation requires all groups to pass", {
  # Site A: identical (diff = 0)
  # Site B: different (diff = 1.0)
  design <- make_grouped_validation_design(group_a_diff = 0, group_b_diff = 1.0)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished, by = location)

  # Overall should fail because site_b fails
  expect_false(result$passed)

  # Site A should pass
  site_a_result <- result$group_tests[result$group_tests$location == "site_a", ]
  expect_true(site_a_result$equivalence_passed)

  # Site B should fail
  site_b_result <- result$group_tests[result$group_tests$location == "site_b", ]
  expect_false(site_b_result$equivalence_passed)
})

test_that("grouped validation passes when all groups pass", {
  # Both groups identical
  design <- make_grouped_validation_design(group_a_diff = 0, group_b_diff = 0)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished, by = location)

  # Overall should pass
  expect_true(result$passed)

  # Both groups should pass
  expect_true(all(result$group_tests$equivalence_passed))
})

# Error cases ----

test_that("validate_incomplete_trips errors without trip_status field", {
  # Since trip_status is now required by add_interviews (Phase 13),
  # we can't create a design without it via the normal flow.
  # Instead, test that validate_incomplete_trips checks for trip_status_col
  # by manually creating a design object without it (edge case).

  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4)
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Manually create an invalid design object (simulating old data structure)
  design$interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 20)),
    catch_total = rep(c(5, 6, 7), length.out = 20),
    hours_fished = rep(c(2.5, 3.0, 3.5), length.out = 20)
  )
  design$catch_col <- "catch_total"
  design$effort_col <- "hours_fished"
  # trip_status_col is intentionally NULL

  expect_error(
    validate_incomplete_trips(design, catch = catch_total, effort = hours_fished),
    "trip_status required"
  )
})

test_that("validate_incomplete_trips errors with insufficient complete trips", {
  # Only 5 complete trips (need >= 10)
  design <- make_validation_design(n_complete = 5, n_incomplete = 50)

  expect_error(
    validate_incomplete_trips(design, catch = catch_total, effort = hours_fished),
    "at least 10 complete trips"
  )
})

test_that("validate_incomplete_trips errors with insufficient incomplete trips", {
  # Only 5 incomplete trips (need >= 10)
  design <- make_validation_design(n_complete = 50, n_incomplete = 5)

  expect_error(
    validate_incomplete_trips(design, catch = catch_total, effort = hours_fished),
    "at least 10 incomplete trips"
  )
})

test_that("validate_incomplete_trips errors without catch/effort columns", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  expect_error(
    validate_incomplete_trips(design, catch = nonexistent_col, effort = hours_fished),
    "Catch column not found"
  )

  expect_error(
    validate_incomplete_trips(design, catch = catch_total, effort = nonexistent_col),
    "Effort column not found"
  )
})

# Recommendation text tests ----

test_that("recommendation text reflects test outcome", {
  # Passing case
  design_pass <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 0)
  result_pass <- validate_incomplete_trips(design_pass, catch = catch_total, effort = hours_fished)

  expect_match(result_pass$recommendation, "safe to use incomplete trips", ignore.case = TRUE)

  # Failing case
  design_fail <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 1.0)
  result_fail <- validate_incomplete_trips(design_fail, catch = catch_total, effort = hours_fished)

  expect_match(result_fail$recommendation, "use complete trips only", ignore.case = TRUE)
})

# Metadata completeness tests ----

test_that("metadata includes all required fields", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Complete trip metadata
  expect_true(all(c("n", "estimate", "se", "ci_lower", "ci_upper") %in% names(result$metadata$complete)))

  # Incomplete trip metadata
  expect_true(all(c("n", "estimate", "se", "ci_lower", "ci_upper") %in% names(result$metadata$incomplete)))

  # Sample sizes should be correct
  expect_equal(result$metadata$complete$n, 50)
  expect_equal(result$metadata$incomplete$n, 50)
})

test_that("metadata estimates are numeric and reasonable", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 0)

  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  # Estimates should be numeric
  expect_type(result$metadata$complete$estimate, "double")
  expect_type(result$metadata$incomplete$estimate, "double")

  # SEs should be non-negative (can be 0 for very uniform data)
  expect_gte(result$metadata$complete$se, 0)
  expect_gte(result$metadata$incomplete$se, 0)

  # CI bounds should exist and be numeric
  expect_type(result$metadata$complete$ci_lower, "double")
  expect_type(result$metadata$complete$ci_upper, "double")
  expect_type(result$metadata$incomplete$ci_lower, "double")
  expect_type(result$metadata$incomplete$ci_upper, "double")

  # CI lower should be <= upper (can be equal for zero SE)
  expect_lte(result$metadata$complete$ci_lower, result$metadata$complete$ci_upper)
  expect_lte(result$metadata$incomplete$ci_lower, result$metadata$incomplete$ci_upper)
})

# Test plot_data component ----

test_that("validation object contains plot_data component", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)
  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  expect_true("plot_data" %in% names(result))
  expect_type(result$plot_data, "list")
})

test_that("plot_data has correct structure for ungrouped estimation", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)
  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  plot_data <- result$plot_data

  # Required fields for scatter plot
  expect_true("complete_est" %in% names(plot_data))
  expect_true("incomplete_est" %in% names(plot_data))
  expect_true("complete_ci_lower" %in% names(plot_data))
  expect_true("complete_ci_upper" %in% names(plot_data))
  expect_true("incomplete_ci_lower" %in% names(plot_data))
  expect_true("incomplete_ci_upper" %in% names(plot_data))
  expect_true("passed" %in% names(plot_data))

  # All should be length 1 for ungrouped
  expect_length(plot_data$complete_est, 1)
  expect_length(plot_data$incomplete_est, 1)
  expect_length(plot_data$passed, 1)

  # No group labels for ungrouped
  expect_null(plot_data$group_labels)
})

test_that("plot_data has correct structure for grouped estimation", {
  design <- make_grouped_validation_design(group_a_diff = 0, group_b_diff = 0)
  result <- validate_incomplete_trips(design,
    catch = catch_total,
    effort = hours_fished,
    by = location
  )

  plot_data <- result$plot_data

  # Required fields
  expect_true("complete_est" %in% names(plot_data))
  expect_true("incomplete_est" %in% names(plot_data))
  expect_true("complete_ci_lower" %in% names(plot_data))
  expect_true("complete_ci_upper" %in% names(plot_data))
  expect_true("incomplete_ci_lower" %in% names(plot_data))
  expect_true("incomplete_ci_upper" %in% names(plot_data))
  expect_true("passed" %in% names(plot_data))
  expect_true("group_labels" %in% names(plot_data))

  # Should have 2 groups (site_a, site_b)
  expect_length(plot_data$complete_est, 2)
  expect_length(plot_data$incomplete_est, 2)
  expect_length(plot_data$passed, 2)
  expect_length(plot_data$group_labels, 2)

  # Group labels should be character
  expect_type(plot_data$group_labels, "character")
})

test_that("plot_data includes CI bounds for error bars", {
  design <- make_validation_design(n_complete = 50, n_incomplete = 50)
  result <- validate_incomplete_trips(design, catch = catch_total, effort = hours_fished)

  plot_data <- result$plot_data

  # CI bounds should be numeric
  expect_type(plot_data$complete_ci_lower, "double")
  expect_type(plot_data$complete_ci_upper, "double")
  expect_type(plot_data$incomplete_ci_lower, "double")
  expect_type(plot_data$incomplete_ci_upper, "double")

  # Lower <= estimate <= upper (can be equal for very stable estimates)
  expect_lte(plot_data$complete_ci_lower, plot_data$complete_est)
  expect_gte(plot_data$complete_ci_upper, plot_data$complete_est)
  expect_lte(plot_data$incomplete_ci_lower, plot_data$incomplete_est)
  expect_gte(plot_data$incomplete_ci_upper, plot_data$incomplete_est)
})

test_that("plot_data includes passed status for annotation", {
  # Design where validation passes
  design_pass <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 0)
  result_pass <- validate_incomplete_trips(design_pass, catch = catch_total, effort = hours_fished)

  expect_type(result_pass$plot_data$passed, "logical")
  expect_true(result_pass$plot_data$passed)

  # Design where validation fails (large difference)
  design_fail <- make_validation_design(n_complete = 50, n_incomplete = 50, cpue_diff = 1.0)
  result_fail <- validate_incomplete_trips(design_fail, catch = catch_total, effort = hours_fished)

  expect_type(result_fail$plot_data$passed, "logical")
  expect_false(result_fail$plot_data$passed)
})

test_that("plot_data passed status matches per-group results for grouped estimation", {
  # Mixed results: group A passes, group B fails
  design <- make_grouped_validation_design(group_a_diff = 0, group_b_diff = 1.0)
  result <- validate_incomplete_trips(design,
    catch = catch_total,
    effort = hours_fished,
    by = location
  )

  plot_data <- result$plot_data

  # Should have one passed, one failed
  expect_equal(sum(plot_data$passed), 1)
  expect_equal(sum(!plot_data$passed), 1)
})
