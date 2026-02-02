# Tests for creel_validation S3 class

# Test data fixtures ----
test_validation_all_pass <- function() {
  data.frame(
    check = c("date_class", "strata_type", "counts_numeric"),
    status = c("pass", "pass", "pass"),
    message = c(
      "Date column is Date class",
      "Strata are character",
      "Counts are numeric"
    ),
    stringsAsFactors = FALSE
  )
}

test_validation_with_fail <- function() {
  data.frame(
    check = c("date_class", "strata_type"),
    status = c("pass", "fail"),
    message = c(
      "Date column is Date class",
      "Strata must be character"
    ),
    stringsAsFactors = FALSE
  )
}

test_validation_with_warn <- function() {
  data.frame(
    check = c("date_class", "strata_type"),
    status = c("pass", "warn"),
    message = c(
      "Date column is Date class",
      "Strata have unusual values"
    ),
    stringsAsFactors = FALSE
  )
}

# Constructor tests ----
test_that("new_creel_validation() creates creel_validation S3 object", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 1L, context = "creel_design creation")

  expect_s3_class(result, "creel_validation")
  expect_type(result, "list")
  expect_named(result, c("results", "tier", "context", "passed"))
})

test_that("new_creel_validation() passed is TRUE when all results pass", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 1L, context = "test")

  expect_true(result$passed)
})

test_that("new_creel_validation() passed is FALSE when any result fails", {
  results_df <- test_validation_with_fail()
  result <- new_creel_validation(results_df, tier = 1L, context = "test")

  expect_false(result$passed)
})

test_that("new_creel_validation() passed is FALSE when any result warns", {
  results_df <- test_validation_with_warn()
  result <- new_creel_validation(results_df, tier = 1L, context = "test")

  expect_false(result$passed)
})

test_that("new_creel_validation() stores tier as integer", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 2L, context = "test")

  expect_equal(result$tier, 2L)
  expect_type(result$tier, "integer")
})

test_that("new_creel_validation() stores results data frame correctly", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 1L, context = "test")

  expect_identical(result$results, results_df)
  expect_s3_class(result$results, "data.frame")
})

test_that("new_creel_validation() stores context correctly", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 1L, context = "effort estimation")

  expect_equal(result$context, "effort estimation")
  expect_type(result$context, "character")
  expect_length(result$context, 1)
})

# Format and print tests ----
test_that("format.creel_validation() returns character vector", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 1L, context = "test")

  formatted <- format(result)
  expect_type(formatted, "character")
  expect_true(length(formatted) > 0)
})

test_that("print.creel_validation() returns invisibly", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(results_df, tier = 1L, context = "test")

  expect_invisible(print(result))
})

test_that("format.creel_validation() contains context and tier info", {
  results_df <- test_validation_all_pass()
  result <- new_creel_validation(
    results_df,
    tier = 2L,
    context = "effort estimation"
  )

  formatted <- format(result)
  formatted_text <- paste(formatted, collapse = "\n")

  expect_match(formatted_text, "effort estimation", ignore.case = FALSE)
  expect_match(formatted_text, "2", fixed = TRUE)
})

# Input validation tests ----
test_that("new_creel_validation() rejects non-data.frame results", {
  expect_error(
    new_creel_validation(list(a = 1), tier = 1L, context = "test"),
    "data.frame"
  )

  expect_error(
    new_creel_validation(matrix(1:4, nrow = 2), tier = 1L, context = "test"),
    "data.frame"
  )
})

test_that("new_creel_validation() rejects non-character context", {
  results_df <- test_validation_all_pass()

  expect_error(
    new_creel_validation(results_df, tier = 1L, context = 123),
    "character"
  )
})
