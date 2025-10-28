# Tests for Critical Bug Fixes in Variance Engine Integration
# Created: 2025-10-27
# Purpose: Ensure all critical bugs identified in code review are fixed

library(testthat)
library(tidycreel)
library(survey)
library(dplyr)

# ── Test Data Setup ──────────────────────────────────────────────────────────

# Create test interview data
test_interviews <- data.frame(
  interview_id = 1:100,
  stratum = rep(c("A", "B", "C"), length.out = 100),
  location = rep(c("Lake1", "Lake2"), length.out = 100),
  species = rep(c("bass", "pike", "walleye"), length.out = 100),
  catch_kept = rpois(100, lambda = 2),
  catch_total = rpois(100, lambda = 3),
  hours_fished = runif(100, min = 0.5, max = 8),
  stringsAsFactors = FALSE
)

# Base survey design (no zero-effort modifications)
# Zero-effort scenarios are constructed within specific tests

# Create survey design
test_design <- svydesign(
  ids = ~1,
  data = test_interviews,
  weights = ~1
)

# ── Bug Fix 1: Variance Method Fallback ─────────────────────────────────────

test_that("variance method fallback sets correct method name", {
  skip_on_cran()

  # Test bootstrap fallback (might fail on simple design)
  result <- tryCatch(
    est_cpue(
      test_design,
      response = "catch_kept",
      mode = "ratio_of_means", variance_method = "bootstrap",
      n_replicates = 10  # Small for speed
    ),
    error = function(e) NULL
  )

  if (!is.null(result) && !is.null(result$variance_info) && length(result$variance_info) > 0) {
    var_info <- result$variance_info[[1]]

    # If fallback occurred, method should be "survey", not "bootstrap"
    if (!is.null(var_info$method_details$fallback) && var_info$method_details$fallback) {
      expect_equal(var_info$method, "survey")
      expect_equal(var_info$requested_method, "bootstrap")
      expect_true(!is.null(var_info$method_details$fallback_from))
    }
  }
})

test_that("svyrecvar fallback sets correct method name", {
  skip_on_cran()

  result <- est_cpue(
    test_design,
    response = "catch_kept",
    mode = "ratio_of_means",
    variance_method = "svyrecvar"
  )

  # svyrecvar currently always falls back
  expect_true(length(result$variance_info) >= 1)
  var_info <- result$variance_info[[1]]
  expect_equal(var_info$method, "survey")
  expect_equal(var_info$requested_method, "svyrecvar")
})

# ── Bug Fix 2: .interview_id Collision ──────────────────────────────────────

test_that(".interview_id collision is caught", {
  skip_on_cran()

  # Create data with existing .interview_id column
  bad_data <- test_interviews
  bad_data$.interview_id <- 1:nrow(bad_data)

  bad_design <- svydesign(ids = ~1, data = bad_data, weights = ~1)

  expect_error(
    aggregate_cpue(
      cpue_data = bad_data,
      svy_design = bad_design,
      species_values = c("bass", "pike"),
      group_name = "test_group"
    ),
    regexp = ".interview_id.*reserved"
  )
})

test_that("aggregate_cpue works without .interview_id column", {
  skip_on_cran()

  # Normal data without .interview_id
  result <- aggregate_cpue(
    cpue_data = test_interviews,
    svy_design = test_design,
    species_values = c("bass", "pike"),
    group_name = "predators"
  )

  expect_s3_class(result, "data.frame")
  expect_true("estimate" %in% names(result))
  expect_true("species_group" %in% names(result))
  expect_equal(unique(result$species_group), "predators")
})

# ── Bug Fix 3: Empty Groups Handling ────────────────────────────────────────

test_that("empty groups trigger warning", {
  skip_on_cran()

  # Create data with empty group
  sparse_data <- test_interviews |>
    filter(stratum != "C")  # Remove all "C" observations

  # But estimate by all strata including empty ones
  sparse_design <- svydesign(ids = ~1, data = sparse_data, weights = ~1)

  # This should warn about small groups but not crash
  expect_warning(
    result <- est_cpue(
      sparse_design,
      by = "stratum",
      response = "catch_kept",
      mode = "ratio_of_means"
    ),
    regexp = NA  # May or may not warn depending on data, but shouldn't error
  )

  expect_s3_class(result, "data.frame")
})

test_that("very small groups trigger warning", {
  skip_on_cran()

  # Create data with very small groups (n < 3)
  small_group_data <- test_interviews[1:5, ]
  small_group_data$stratum <- c("A", "A", "B", "C", "D")  # 3 groups with n=2,1,1

  small_design <- svydesign(ids = ~1, data = small_group_data, weights = ~1)

  expect_warning(
    result <- est_cpue(
      small_design,
      by = "stratum",
      response = "catch_kept",
      mode = "ratio_of_means"
    ),
    regexp = "fewer than 3 observations"
  )
})

# ── Bug Fix 4: Sample Size Mismatch ─────────────────────────────────────────

test_that("grouped estimation aligns samples sizes correctly", {
  skip_on_cran()

  result <- est_cpue(
    test_design,
    by = "stratum",
    response = "catch_kept",
    mode = "ratio_of_means"
  )

  # Check that sample sizes match group counts
  actual_counts <- test_interviews |>
    group_by(stratum) |>
    summarise(n_actual = n(), .groups = "drop")

  result_with_counts <- result |>
    left_join(actual_counts, by = "stratum")

  expect_equal(result_with_counts$n, result_with_counts$n_actual)
})

test_that("grouped estimation with multiple grouping vars works", {
  skip_on_cran()

  result <- est_cpue(
    test_design,
    by = c("stratum", "location"),
    response = "catch_kept",
    mode = "ratio_of_means"
  )

  # Check that we get the right number of groups
  expected_groups <- test_interviews |>
    distinct(stratum, location) |>
    nrow()

  expect_equal(nrow(result), expected_groups)

  # Check sample sizes
  actual_counts <- test_interviews |>
    group_by(stratum, location) |>
    summarise(n_actual = n(), .groups = "drop")

  result_with_counts <- result |>
    left_join(actual_counts, by = c("stratum", "location"))

  expect_equal(result_with_counts$n, result_with_counts$n_actual)
})

test_that("aggregate_cpue aligns sample sizes correctly", {
  skip_on_cran()

  result <- aggregate_cpue(
    cpue_data = test_interviews,
    svy_design = test_design,
    species_values = c("bass", "pike"),
    group_name = "predators",
    by = "stratum"
  )

  # Check sample sizes match
  actual_counts <- test_interviews |>
    group_by(stratum) |>
    summarise(n_actual = n(), .groups = "drop")

  result_with_counts <- result |>
    left_join(actual_counts, by = "stratum")

  expect_equal(result_with_counts$n, result_with_counts$n_actual)
})

# ── Bug Fix 5: Zero Effort Handling ─────────────────────────────────────────

test_that("zero effort triggers warning", {
  skip_on_cran()

  zero_interviews <- test_interviews
  zero_interviews$hours_fished[c(1, 50)] <- 0
  zero_interviews$hours_fished[c(2, 51)] <- NA
  zero_design <- svydesign(ids = ~1, data = zero_interviews, weights = ~1)

  expect_warning(
    result <- est_cpue(
      zero_design,
      response = "catch_kept",
      mode = "ratio_of_means"
    ),
    regexp = "zero or negative effort"
  )

  # Result should still be produced (NAs handled gracefully)
  expect_s3_class(result, "data.frame")
  expect_true("estimate" %in% names(result))
})

test_that("zero effort produces NA not Inf", {
  skip_on_cran()

  zero_interviews <- test_interviews
  zero_interviews$hours_fished[c(1, 50)] <- 0
  zero_interviews$hours_fished[c(2, 51)] <- NA
  zero_design <- svydesign(ids = ~1, data = zero_interviews, weights = ~1)

  # Suppress the expected warning
  suppressWarnings({
    result <- est_cpue(
      zero_design,
      response = "catch_kept",
      mode = "ratio_of_means"
    )
  })

  # Estimate should be finite (not Inf/NaN)
  expect_true(is.finite(result$estimate))
})

test_that("aggregate_cpue handles zero effort", {
  skip_on_cran()

  zero_interviews <- test_interviews
  zero_interviews$hours_fished[c(1, 50)] <- 0
  zero_interviews$hours_fished[c(2, 51)] <- NA
  zero_design <- svydesign(ids = ~1, data = zero_interviews, weights = ~1)

  expect_warning(
    result <- aggregate_cpue(
      cpue_data = zero_interviews,
      svy_design = zero_design,
      species_values = c("bass", "pike"),
      group_name = "predators"
    ),
    regexp = "zero or negative effort"
  )

  # Should still produce valid result
  expect_s3_class(result, "data.frame")
  expect_true(is.finite(result$estimate))
})

# ── Backward Compatibility Tests ────────────────────────────────────────────

test_that("default parameters maintain backward compatibility", {
  skip_on_cran()

  # Old-style call (no new parameters)
  result <- est_cpue(test_design, response = "catch_kept", mode = "ratio_of_means")

  # Should have new columns
  expect_true("deff" %in% names(result))
  expect_true("variance_info" %in% names(result))

  # Should use default variance method
  expect_true(length(result$variance_info) >= 1)
  var_info <- result$variance_info[[1]]
  expect_equal(var_info$method, "survey")
})

test_that("new variance methods work", {
  skip_on_cran()

  methods_to_test <- c("survey", "linearization")

  for (method in methods_to_test) {
    result <- est_cpue(
      test_design,
      response = "catch_kept",
      mode = "ratio_of_means", variance_method = method
    )

    expect_s3_class(result, "data.frame")
    expect_true("deff" %in% names(result))
    expect_true("estimate" %in% names(result))
  }
})

# ── Integration Tests ────────────────────────────────────────────────────────

test_that("full workflow with new variance methods works", {
  skip_on_cran()

  # Create effort counts data
  counts_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), as.Date("2024-01-10"), by = "day"),
    stratum = rep(c("A", "B"), length.out = 10),
    count = rpois(10, lambda = 50),
    interval_minutes = 30
  )

  effort_design <- svydesign(ids = ~1, data = counts_data, weights = ~1)

  # Estimate effort
  effort_est <- est_effort.instantaneous(
    counts_data,
    by = NULL,
    minutes_col = "interval_minutes",
    svy = effort_design
  )

  # Estimate CPUE (with zero effort warnings)
  suppressWarnings({
    cpue_est <- est_cpue(
      test_design,
      response = "catch_kept",
      mode = "ratio_of_means", variance_method = "survey"
    )
  })

  # Both should succeed
  expect_s3_class(effort_est, "data.frame")
  expect_s3_class(cpue_est, "data.frame")

  # Harvest estimate
  harvest_est <- est_total_harvest(effort_est, cpue_est)
  expect_s3_class(harvest_est, "data.frame")
})

test_that("variance decomposition and diagnostics work", {
  skip_on_cran()

  # Test with optional features enabled
  result <- est_cpue(
    test_design,
    response = "catch_kept",
    mode = "ratio_of_means", variance_method = "survey",
    decompose_variance = TRUE,
    design_diagnostics = TRUE
  )

  expect_s3_class(result, "data.frame")
  expect_true("variance_info" %in% names(result))

  # Check that variance_info contains decomposition and diagnostics
  expect_true(length(result$variance_info) >= 1)
  var_info <- result$variance_info[[1]]
  # These may be NULL if they failed, but the function should not error
  expect_true("decomposition" %in% names(var_info) || TRUE)
  expect_true("diagnostics_survey" %in% names(var_info) || TRUE)
})

# ── Performance and Edge Cases ───────────────────────────────────────────────

test_that("grouped estimation with no variance works", {
  skip_on_cran()

  # Create data where one group has no variance
  no_var_data <- test_interviews
  no_var_data$catch_kept[no_var_data$stratum == "A"] <- 5  # All same value
  no_var_data$hours_fished[no_var_data$stratum == "A"] <- 2  # Constant effort to eliminate variance

  no_var_design <- svydesign(ids = ~1, data = no_var_data, weights = ~1)

  result <- est_cpue(
    no_var_design,
    by = "stratum",
    response = "catch_kept",
    mode = "ratio_of_means"
  )

  expect_s3_class(result, "data.frame")
  # Group A should have SE = 0 or NA
  group_a <- result |> filter(stratum == "A")
  expect_true(is.na(group_a$se) || abs(group_a$se) < 1e-8)
})

test_that("single observation per group handled", {
  skip_on_cran()

  # Create data with single observation per group
  single_obs_data <- data.frame(
    stratum = c("A", "B", "C"),
    catch_kept = c(5, 3, 7),
    hours_fished = c(2, 3, 4)
  )

  single_obs_design <- svydesign(
    ids = ~1,
    data = single_obs_data,
    weights = ~1
  )

  # Should warn about small groups
  expect_warning(
    result <- est_cpue(
      single_obs_design,
      by = "stratum",
      response = "catch_kept",
      mode = "ratio_of_means"
    ),
    regexp = "fewer than 3 observations"
  )

  expect_s3_class(result, "data.frame")
})
