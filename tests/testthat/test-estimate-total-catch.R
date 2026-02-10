# Test helpers ----

#' Create test design with BOTH counts and interviews (for total catch)
make_total_catch_design <- function() {
  # Use example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design with both data sources
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished # nolint: object_usage_linter
  )

  design
}

#' Create test design with counts only (no interviews)
make_counts_only_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter

  design
}

#' Create test design with interviews only (no counts)
make_interviews_only_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished # nolint: object_usage_linter
  )

  design
}

# Basic behavior tests ----

test_that("estimate_total_catch returns creel_estimates class object", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_catch result has estimates tibble with correct columns", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_total_catch result method is 'product-total-catch'", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_equal(result$method, "product-total-catch")
})

test_that("estimate_total_catch result variance_method is 'taylor' by default", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_total_catch result conf_level is 0.95 by default", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_total_catch estimate is a positive numeric value", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_total_catch errors when design is not creel_design", {
  fake_design <- "not a design"

  expect_error(
    estimate_total_catch(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_total_catch errors when design has no counts", {
  design <- make_interviews_only_design()

  expect_error(
    estimate_total_catch(design), # nolint: object_usage_linter
    "add_counts"
  )
})

test_that("estimate_total_catch errors when design has no interviews", {
  design <- make_counts_only_design()

  expect_error(
    estimate_total_catch(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_total_catch errors for invalid variance method", {
  design <- make_total_catch_design()

  expect_error(
    estimate_total_catch(design, variance = "invalid_method"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

# Delta method correctness - Reference tests ----

test_that("total catch estimate equals effort * cpue exactly", {
  design <- make_total_catch_design()

  # Get total catch estimate
  result <- estimate_total_catch(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  cpue <- estimate_cpue(design) # nolint: object_usage_linter

  # Product should match exactly
  expected <- effort$estimates$estimate * cpue$estimates$estimate

  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
})

test_that("total catch SE matches manual delta method formula", {
  design <- make_total_catch_design()

  # Get total catch estimate
  result <- estimate_total_catch(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  cpue <- estimate_cpue(design) # nolint: object_usage_linter

  # Extract components
  effort_est <- effort$estimates$estimate # nolint: object_name_linter
  cpue_est <- cpue$estimates$estimate # nolint: object_name_linter
  var_effort <- effort$estimates$se^2 # nolint: object_name_linter
  var_cpue <- cpue$estimates$se^2 # nolint: object_name_linter

  # Manual delta method (first-order approximation)
  manual_variance <- (effort_est^2 * var_cpue) + (cpue_est^2 * var_effort)
  manual_se <- sqrt(manual_variance)

  # Allow slightly looser tolerance for SE since svycontrast may include second-order term
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-6)
})

test_that("total catch CI is finite and contains estimate", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_true(is.finite(result$estimates$ci_lower))
  expect_true(is.finite(result$estimates$ci_upper))
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

# Grouped estimation tests ----

test_that("estimate_total_catch grouped by day_type returns creel_estimates with by_vars set", {
  design <- make_total_catch_design()

  # Skip if example data has groups with n < 10 (weekend has only 9 interviews)
  skip_if(
    any(table(design$interviews$day_type) < 10),
    "Example data has groups with n < 10"
  )

  result <- estimate_total_catch(design, by = day_type) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_total_catch grouped result has day_type column", {
  design <- make_total_catch_design()

  # Skip if example data has groups with n < 10
  skip_if(
    any(table(design$interviews$day_type) < 10),
    "Example data has groups with n < 10"
  )

  result <- estimate_total_catch(design, by = day_type) # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_total_catch grouped result has one row per group level", {
  design <- make_total_catch_design()

  # Skip if example data has groups with n < 10
  skip_if(
    any(table(design$interviews$day_type) < 10),
    "Example data has groups with n < 10"
  )

  result <- estimate_total_catch(design, by = day_type) # nolint: object_usage_linter

  # Should have weekday and weekend
  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_total_catch grouped result n reflects per-group interview sample sizes", {
  design <- make_total_catch_design()

  # Skip if example data has groups with n < 10
  skip_if(
    any(table(design$interviews$day_type) < 10),
    "Example data has groups with n < 10"
  )

  result <- estimate_total_catch(design, by = day_type) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Grouping validation tests ----

test_that("estimate_total_catch errors when grouping variable missing from count data", {
  design <- make_total_catch_design()

  # Add a column to interviews that doesn't exist in counts
  design$interviews$species <- rep("bass", nrow(design$interviews))

  expect_error(
    estimate_total_catch(design, by = species), # nolint: object_usage_linter
    "species"
  )
})

test_that("estimate_total_catch errors when grouping variable missing from interview data", {
  design <- make_total_catch_design()

  # Add a column to counts that doesn't exist in interviews
  design$counts$location <- rep("north", nrow(design$counts))

  expect_error(
    estimate_total_catch(design, by = location), # nolint: object_usage_linter
    "location"
  )
})

# Custom confidence level test ----

test_that("estimate_total_catch with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_total_catch_design()

  result_95 <- estimate_total_catch(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_total_catch(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})
