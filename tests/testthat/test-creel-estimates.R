# Tests for creel_estimates S3 class

# Test data fixtures ----
test_estimates_df <- function() {
  data.frame(
    estimate = 1234.5,
    se = 123.4,
    ci_lower = 987.6,
    ci_upper = 1481.4,
    n = 120L,
    stringsAsFactors = FALSE
  )
}

# Constructor tests ----
test_that("new_creel_estimates() creates creel_estimates S3 object", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(est_df)

  expect_s3_class(result, "creel_estimates")
  expect_type(result, "list")
  expect_named(result, c("estimates", "method", "variance_method", "design", "conf_level", "by_vars"))
})

test_that("new_creel_estimates() uses correct defaults", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(est_df)

  expect_equal(result$method, "total")
  expect_equal(result$variance_method, "taylor")
  expect_equal(result$conf_level, 0.95)
  expect_null(result$by_vars)
})

test_that("new_creel_estimates() stores estimates data frame correctly", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(est_df)

  expect_identical(result$estimates, est_df)
  expect_s3_class(result$estimates, "data.frame")
})

test_that("new_creel_estimates() has NULL design when not provided", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(est_df)

  expect_null(result$design)
})

test_that("new_creel_estimates() accepts custom parameters", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(
    est_df,
    method = "mean",
    variance_method = "bootstrap",
    conf_level = 0.90
  )

  expect_equal(result$method, "mean")
  expect_equal(result$variance_method, "bootstrap")
  expect_equal(result$conf_level, 0.90)
})

# Format and print tests ----
test_that("format.creel_estimates() returns character vector", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(est_df)

  formatted <- format(result)
  expect_type(formatted, "character")
  expect_true(length(formatted) > 0)
})

test_that("print.creel_estimates() returns invisibly", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(est_df)

  expect_invisible(print(result))
})

test_that("format.creel_estimates() contains method and variance info", {
  est_df <- test_estimates_df()
  result <- new_creel_estimates(
    est_df,
    method = "total",
    variance_method = "taylor"
  )

  formatted <- format(result)
  formatted_text <- paste(formatted, collapse = "\n")

  expect_match(formatted_text, "total", ignore.case = TRUE)
  expect_match(formatted_text, "taylor", ignore.case = TRUE)
  expect_match(formatted_text, "95%", ignore.case = FALSE)
})

# Input validation tests ----
test_that("new_creel_estimates() rejects non-data.frame estimates", {
  expect_error(
    new_creel_estimates(list(a = 1)),
    "data.frame"
  )

  expect_error(
    new_creel_estimates(matrix(1:4, nrow = 2)),
    "data.frame"
  )
})

test_that("new_creel_estimates() rejects non-character method", {
  est_df <- test_estimates_df()

  expect_error(
    new_creel_estimates(est_df, method = 123),
    "character"
  )
})

test_that("new_creel_estimates() rejects non-numeric conf_level", {
  est_df <- test_estimates_df()

  expect_error(
    new_creel_estimates(est_df, conf_level = "0.95"),
    "numeric"
  )
})

# MOR S3 class tests ----

# Helper to create design with incomplete trips for MOR testing
make_mor_test_design <- function(n_incomplete = 30, n_complete = 0) {
  n <- n_incomplete + n_complete
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  trip_status <- c(rep("incomplete", n_incomplete), rep("complete", n_complete))

  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", n)),
    catch_total = rep(c(2, 3, 4, 5), length.out = n),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    catch_kept = rep(c(2, 2, 3, 4), length.out = n),
    trip_status = trip_status,
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

test_that("creel_estimates_mor has correct class structure", {
  # Create MOR result
  design <- make_mor_test_design(n_incomplete = 30)
  result <- suppressWarnings(estimate_catch_rate(design, estimator = "mor")) # nolint: object_usage_linter

  # Verify class inheritance
  expect_s3_class(result, "creel_estimates_mor")
  expect_s3_class(result, "creel_estimates")

  # Verify class order (mor before creel_estimates for dispatch)
  expect_equal(class(result)[1], "creel_estimates_mor")
  expect_equal(class(result)[2], "creel_estimates")
})

test_that("creel_estimates_mor contains trip count metadata", {
  design <- make_mor_test_design(n_incomplete = 25, n_complete = 15)
  result <- suppressWarnings(estimate_catch_rate(design, estimator = "mor")) # nolint: object_usage_linter

  # After Phase 17, estimator="mor" auto-switches to use_trips="incomplete"
  # So we filter to incomplete trips first, then n_total = n_incomplete
  expect_equal(result$n_incomplete, 25)
  expect_equal(result$n_total, 25)
})

test_that("creel_estimates_mor print shows diagnostic banner", {
  design <- make_mor_test_design(n_incomplete = 30)
  result <- suppressWarnings(estimate_catch_rate(design, estimator = "mor")) # nolint: object_usage_linter

  output <- capture.output(print(result))
  output_text <- paste(output, collapse = "\n")

  # Check for banner elements
  expect_match(output_text, "DIAGNOSTIC.*MOR Estimator", ignore.case = TRUE)
  expect_match(output_text, "Incomplete Trips", ignore.case = TRUE)
  expect_match(output_text, "Complete trips preferred", ignore.case = TRUE)
  expect_match(output_text, "validate_incomplete_trips", ignore.case = TRUE)
})

test_that("creel_estimates_mor print includes trip counts", {
  design <- make_mor_test_design(n_incomplete = 25, n_complete = 15)
  result <- suppressWarnings(estimate_catch_rate(design, estimator = "mor")) # nolint: object_usage_linter

  output <- capture.output(print(result))
  output_text <- paste(output, collapse = "\n")

  # After Phase 17, auto-switch to incomplete trips means n_total = n_incomplete
  expect_match(output_text, "25.*25", perl = TRUE) # n_incomplete of n_total
})
