# Tests for validate_creel_data() ----

# Helpers ---------------------------------------------------------------------
make_counts <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08")),
    day_type = c("weekday", "weekday", "weekend"),
    count = c(10L, 14L, 30L),
    stringsAsFactors = FALSE
  )
}

make_interviews <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    fish_kept = c(2L, 5L),
    species = c("walleye", "bass"),
    stringsAsFactors = FALSE
  )
}

# Input validation ------------------------------------------------------------

test_that("VCDV-01: errors when both counts and interviews are NULL", {
  expect_error(
    validate_creel_data(),
    class = "creel_error_design_validation"
  )
})

test_that("VCDV-02: errors when counts is not a data frame", {
  expect_error(
    validate_creel_data(counts = list(a = 1)),
    class = "creel_error_design_validation"
  )
})

test_that("VCDV-03: errors when interviews is not a data frame", {
  expect_error(
    validate_creel_data(interviews = "bad"),
    class = "creel_error_design_validation"
  )
})

test_that("VCDV-04: errors on invalid na_threshold", {
  expect_error(
    validate_creel_data(counts = make_counts(), na_threshold = 1.5),
    class = "creel_error_design_validation"
  )
})

test_that("VCDV-05: errors on invalid date_range", {
  expect_error(
    validate_creel_data(
      counts     = make_counts(),
      date_range = c("2020-01-01", "2025-01-01")
    ),
    class = "creel_error_design_validation"
  )
})

# Return structure ------------------------------------------------------------

test_that("VCDV-06: returns creel_data_validation object", {
  res <- validate_creel_data(counts = make_counts())
  expect_s3_class(res, "creel_data_validation")
  expect_s3_class(res, "data.frame")
})

test_that("VCDV-07: result has expected columns", {
  res <- validate_creel_data(counts = make_counts())
  expect_named(res, c("table", "column", "check", "status", "detail"))
})

test_that("VCDV-08: status values are restricted to pass/warn/fail", {
  res <- validate_creel_data(
    counts     = make_counts(),
    interviews = make_interviews()
  )
  expect_true(all(res$status %in% c("pass", "warn", "fail")))
})

test_that("VCDV-09: table column identifies source correctly", {
  res <- validate_creel_data(
    counts     = make_counts(),
    interviews = make_interviews()
  )
  expect_true("counts" %in% res$table)
  expect_true("interviews" %in% res$table)
})

# NA rate check ---------------------------------------------------------------

test_that("VCDV-10: high NA rate triggers warn status", {
  df <- data.frame(
    date  = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
    count = c(NA_integer_, NA_integer_, 1L)
  )
  res <- validate_creel_data(counts = df, na_threshold = 0.10)
  na_row <- res[res$column == "count" & res$check == "na_rate", ]
  expect_equal(na_row$status, "warn")
})

test_that("VCDV-11: NA rate below threshold is pass", {
  res <- validate_creel_data(counts = make_counts())
  na_rows <- res[res$check == "na_rate", ]
  expect_true(all(na_rows$status == "pass"))
})

# Date range check ------------------------------------------------------------

test_that("VCDV-12: out-of-range dates trigger warn", {
  df <- data.frame(
    date  = as.Date(c("1900-01-01", "2024-06-01")),
    count = c(5L, 10L)
  )
  res <- validate_creel_data(counts = df)
  date_row <- res[res$column == "date" & res$check == "date_range", ]
  expect_equal(date_row$status, "warn")
})

test_that("VCDV-13: in-range dates are pass", {
  res <- validate_creel_data(counts = make_counts())
  date_rows <- res[res$check == "date_range", ]
  expect_true(all(date_rows$status == "pass"))
})

# Negative values check -------------------------------------------------------

test_that("VCDV-14: negative numeric values trigger warn", {
  df <- data.frame(
    date  = as.Date("2024-06-01"),
    count = -5L
  )
  res <- validate_creel_data(counts = df)
  neg_row <- res[res$column == "count" & res$check == "negative_values", ]
  expect_equal(neg_row$status, "warn")
})

test_that("VCDV-15: non-negative numerics are pass", {
  res <- validate_creel_data(counts = make_counts())
  neg_rows <- res[res$check == "negative_values", ]
  expect_true(all(neg_rows$status == "pass"))
})

# Empty string check ----------------------------------------------------------

test_that("VCDV-16: empty strings in character column trigger warn", {
  df <- data.frame(
    date = as.Date("2024-06-01"),
    species = "",
    stringsAsFactors = FALSE
  )
  res <- validate_creel_data(interviews = df)
  emp_row <- res[res$column == "species" & res$check == "empty_strings", ]
  expect_equal(emp_row$status, "warn")
})

test_that("VCDV-17: non-empty character columns are pass", {
  res <- validate_creel_data(interviews = make_interviews())
  emp_rows <- res[res$check == "empty_strings", ]
  expect_true(all(emp_rows$status == "pass"))
})

# Type check always present ---------------------------------------------------

test_that("VCDV-18: type check present for every column", {
  res <- validate_creel_data(counts = make_counts())
  for (col in names(make_counts())) {
    type_row <- res[res$column == col & res$check == "type", ]
    expect_equal(nrow(type_row), 1L, label = paste0("type check for ", col))
  }
})

# S3 methods ------------------------------------------------------------------

test_that("VCDV-19: print.creel_data_validation returns x invisibly", {
  res <- validate_creel_data(counts = make_counts())
  returned <- suppressMessages(print(res))
  expect_identical(returned, res)
})

test_that("VCDV-20: as.data.frame strips creel_data_validation class", {
  res <- validate_creel_data(counts = make_counts())
  plain <- as.data.frame(res)
  expect_false(inherits(plain, "creel_data_validation"))
  expect_s3_class(plain, "data.frame")
})

# Edge cases ------------------------------------------------------------------

test_that("VCDV-21: counts-only call works (no interviews)", {
  res <- validate_creel_data(counts = make_counts())
  expect_true(all(res$table == "counts"))
})

test_that("VCDV-22: interviews-only call works (no counts)", {
  res <- validate_creel_data(interviews = make_interviews())
  expect_true(all(res$table == "interviews"))
})

test_that("VCDV-23: single-row data frame is handled without error", {
  df <- data.frame(
    date  = as.Date("2024-06-01"),
    count = 5L
  )
  expect_no_error(validate_creel_data(counts = df))
})

test_that("VCDV-24: factor column gets empty_strings check", {
  df <- data.frame(
    date    = as.Date("2024-06-01"),
    species = factor("walleye")
  )
  res <- validate_creel_data(interviews = df)
  expect_true("empty_strings" %in% res$check)
})

test_that("VCDV-25: all-NA column still produces rows", {
  df <- data.frame(
    date  = as.Date(c("2024-06-01", "2024-06-02")),
    count = c(NA_integer_, NA_integer_)
  )
  res <- validate_creel_data(counts = df)
  expect_true(nrow(res) > 0L)
})
