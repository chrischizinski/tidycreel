# Test: validate_calendar_schema() ----------------------------------------

test_that("validate_calendar_schema() accepts valid calendar data", {
  # Minimal valid: one Date column, one character column
  valid1 <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  expect_invisible(validate_calendar_schema(valid1))

  # Multiple rows, multiple strata columns
  valid2 <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    stratum = c("A", "B"),
    day_type = c("weekday", "weekend")
  )
  expect_invisible(validate_calendar_schema(valid2))

  # Factor column instead of character
  valid3 <- data.frame(
    date = as.Date("2024-06-01"),
    stratum = factor("A")
  )
  expect_invisible(validate_calendar_schema(valid3))
})

test_that("validate_calendar_schema() rejects non-data-frame input", {
  expect_error(
    validate_calendar_schema("not a data frame"),
    class = "creel_error_schema_validation"
  )
  expect_error(
    validate_calendar_schema(list(date = as.Date("2024-06-01"))),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_calendar_schema() rejects empty data frames", {
  expect_error(
    validate_calendar_schema(data.frame()),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_calendar_schema() rejects data without Date column", {
  no_date <- data.frame(
    x = 1:3,
    day_type = c("weekday", "weekday", "weekend")
  )
  expect_error(
    validate_calendar_schema(no_date),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_calendar_schema() rejects data with character date (not Date class)", {
  char_date <- data.frame(
    date = c("2024-06-01", "2024-06-02"),
    day_type = c("weekday", "weekend")
  )
  expect_error(
    validate_calendar_schema(char_date),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_calendar_schema() rejects data without character/factor column", {
  no_char <- data.frame(
    date = as.Date("2024-06-01"),
    count = 5
  )
  expect_error(
    validate_calendar_schema(no_char),
    class = "creel_error_schema_validation"
  )
})

# Test: validate_count_schema() -------------------------------------------

test_that("validate_count_schema() accepts valid count data", {
  # Minimal valid: one Date column, one numeric column
  valid1 <- data.frame(
    date = as.Date("2024-06-01"),
    count = 5L
  )
  expect_invisible(validate_count_schema(valid1))

  # Multiple numeric columns (integer and double)
  valid2 <- data.frame(
    date = as.Date("2024-06-01"),
    effort = 2.5,
    boats = 3L
  )
  expect_invisible(validate_count_schema(valid2))

  # Multiple rows
  valid3 <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    count = c(5, 10)
  )
  expect_invisible(validate_count_schema(valid3))
})

test_that("validate_count_schema() rejects non-data-frame input", {
  expect_error(
    validate_count_schema("not a data frame"),
    class = "creel_error_schema_validation"
  )
  expect_error(
    validate_count_schema(matrix(1:4, nrow = 2)),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_count_schema() rejects empty data frames", {
  expect_error(
    validate_count_schema(data.frame()),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_count_schema() rejects data without Date column", {
  no_date <- data.frame(
    x = "text",
    count = 5
  )
  expect_error(
    validate_count_schema(no_date),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_count_schema() rejects data without numeric column", {
  no_numeric <- data.frame(
    date = as.Date("2024-06-01"),
    name = "site_a"
  )
  expect_error(
    validate_count_schema(no_numeric),
    class = "creel_error_schema_validation"
  )
})

test_that("validate_count_schema() rejects data with only character columns", {
  only_char <- data.frame(
    x = "text",
    y = "more_text"
  )
  expect_error(
    validate_count_schema(only_char),
    class = "creel_error_schema_validation"
  )
})
