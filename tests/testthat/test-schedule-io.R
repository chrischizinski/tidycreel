# ---- SCHED-03: write_schedule() ----

test_that("SCHED-03: write_schedule() produces readable CSV file", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  expect_true(file.exists(tmp))
})

test_that("SCHED-03: CSV write preserves date column as ISO format", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  raw <- read.csv(tmp, stringsAsFactors = FALSE)
  # Date column should be readable as ISO string
  expect_true("date" %in% names(raw))
  parsed <- as.Date(raw$date)
  expect_false(any(is.na(parsed)))
})

test_that("SCHED-03: xlsx export works when writexl installed", {
  skip_if_not_installed("writexl")
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  write_schedule(sched, tmp, format = "xlsx")
  expect_true(file.exists(tmp))
  expect_gt(file.size(tmp), 0L)
})

test_that("SCHED-03: informative error when writexl missing and xlsx requested", {
  skip_if(
    requireNamespace("writexl", quietly = TRUE),
    "writexl is installed; cannot test missing-package error path"
  )
  sched <- generate_schedule(
    "2024-06-01", "2024-06-30",
    n_periods = 1,
    sampling_rate = 0.5,
    seed = 1
  )
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  expect_error(
    write_schedule(sched, tmp, format = "xlsx"),
    regexp = "writexl"
  )
})

test_that("SCHED-03: write_schedule() returns path invisibly", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  result <- write_schedule(sched, tmp)
  expect_identical(result, tmp)
})

# ---- SCHED-04: read_schedule() ----

test_that("SCHED-04: read_schedule() returns creel_schedule object from CSV", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  result <- read_schedule(tmp)
  expect_s3_class(result, "creel_schedule")
})

test_that("SCHED-04: column types correct after read (Date, character, integer)", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  result <- read_schedule(tmp)
  expect_s3_class(result$date, "Date")
  expect_type(result$day_type, "character")
  expect_type(result$period_id, "integer")
})

test_that("SCHED-04: round-trip write -> read -> creel_design() succeeds", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  sched2 <- read_schedule(tmp)
  # creel_design should not error
  expect_no_error(creel_design(sched2, date = date, strata = day_type))
})

test_that("SCHED-04: validation error on bad day_type values after read", {
  # Write a CSV with NA day_type to trigger validation failure
  tmp <- withr::local_tempfile(fileext = ".csv")
  df <- data.frame(
    date = "2024-06-01",
    day_type = NA_character_,
    period_id = 1L,
    stringsAsFactors = FALSE
  )
  utils::write.csv(df, tmp, row.names = FALSE)
  expect_error(read_schedule(tmp), regexp = "day_type")
})

test_that("SCHED-04: read_schedule() handles xlsx files", {
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  write_schedule(sched, tmp, format = "xlsx")
  result <- read_schedule(tmp)
  expect_s3_class(result, "creel_schedule")
  expect_s3_class(result$date, "Date")
  expect_type(result$day_type, "character")
})

test_that("SCHED-04: coercion handles Excel serial-number dates", {
  # Excel serial for 2022-06-01 is 44713
  result <- coerce_to_date(44713)
  expect_s3_class(result, "Date")
  expect_equal(result, as.Date("2022-06-01"))
})

test_that("SCHED-04: coercion handles POSIXct date column", {
  # POSIXct -> Date coercion
  posix_val <- as.POSIXct("2024-06-01 00:00:00", tz = "UTC")
  result <- coerce_to_date(posix_val)
  expect_s3_class(result, "Date")
  expect_equal(result, as.Date("2024-06-01"))
})

test_that("SCHED-04: round-trip for include_all = TRUE schedule (with sampled column)", {
  sched <- generate_schedule(
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42,
    include_all = TRUE
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  result <- read_schedule(tmp)
  expect_s3_class(result, "creel_schedule")
  expect_true("sampled" %in% names(result))
  expect_type(result$sampled, "logical")
})

# Additional validation tests from plan requirements

test_that("SCHED-04: validation error on missing date column", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  df <- data.frame(
    day_type = "weekday",
    period_id = 1L,
    stringsAsFactors = FALSE
  )
  utils::write.csv(df, tmp, row.names = FALSE)
  expect_error(read_schedule(tmp), regexp = "date")
})

test_that("SCHED-04: validation error on period_id = 0", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  df <- data.frame(
    date = "2024-06-01",
    day_type = "weekday",
    period_id = 0L,
    stringsAsFactors = FALSE
  )
  utils::write.csv(df, tmp, row.names = FALSE)
  expect_error(read_schedule(tmp), regexp = "period_id")
})
