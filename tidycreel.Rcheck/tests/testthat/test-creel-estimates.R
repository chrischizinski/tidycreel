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
