# ---- SCHED-03: write_schedule() ----

test_that("SCHED-03: write_schedule() produces readable CSV file", {
  sched <- generate_schedule(
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-06-30",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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
    "2024-06-01",
    "2024-08-31",
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

test_that("SCHED-IO-01: read_schedule preserves character period_id without NA coercion", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  df <- data.frame(
    date = c("2024-06-01", "2024-06-01"),
    day_type = c("weekday", "weekday"),
    period_id = c("AM", "PM"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(df, tmp, row.names = FALSE)
  # A file without p_period (GH #385) whose days carry the same periods is
  # read as p_period = 1 with a warning.
  expect_warning(result <- read_schedule(tmp), class = "creel_warning_p_period_inferred")
  expect_type(result$period_id, "character")
  expect_equal(result$period_id, c("AM", "PM"))
  expect_false(any(is.na(result$period_id)))
})

test_that("SCHED-IO-02: write_schedule() aborts when file exists and overwrite = FALSE", {
  sched <- generate_schedule(
    start_date = "2024-06-01",
    end_date = "2024-06-07",
    n_periods = 1,
    sampling_rate = c(weekday = 0.5, weekend = 1.0),
    seed = 1L
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  expect_error(write_schedule(sched, tmp), regexp = "already exists")
})

test_that("SCHED-IO-03: write_schedule() overwrites when overwrite = TRUE", {
  sched <- generate_schedule(
    start_date = "2024-06-01",
    end_date = "2024-06-07",
    n_periods = 1,
    sampling_rate = c(weekday = 0.5, weekend = 1.0),
    seed = 1L
  )
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched, tmp)
  expect_no_error(write_schedule(sched, tmp, overwrite = TRUE))
})

test_that("SCHED-04: a count-time schedule round-trips with every column type intact (GH #194)", {
  # read_schedule() reads every column as character and restores types through
  # an allow-list. window_id is added by attach_count_times(), not by
  # generate_schedule(), so the plain round-trip test above never covered it and
  # it came back character. A character window_id silently breaks a join against
  # an integer window_id, an arithmetic comparison, or an identical() check --
  # no error, no warning. Assert the whole object, so any future generator
  # column that escapes the allow-list fails here too.
  sched <- generate_schedule(
    "2024-06-01",
    "2024-06-30",
    n_periods = 4,
    n_days = 8,
    seed = 42
  )
  count_times <- generate_count_times(
    start_time = "06:00",
    end_time = "20:00",
    strategy = "systematic",
    n_windows = 2,
    window_size = 60,
    min_gap = 120,
    seed = 1
  )
  attached <- attach_count_times(sched, count_times)
  expect_type(attached$window_id, "integer")

  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(attached, tmp)
  result <- read_schedule(tmp)

  expect_type(result$window_id, "integer")
  expect_identical(
    vapply(result, function(x) class(x)[1], character(1)),
    vapply(attached, function(x) class(x)[1], character(1))
  )
  expect_identical(result, attached)
})

test_that("SCHED-04: non-numeric window labels survive the round trip as character", {
  # The integer restoration is guarded the same way period_id's is: a schedule
  # labelling its windows "AM"/"PM" must not be coerced to NA integers.
  tmp <- withr::local_tempfile(fileext = ".csv")
  df <- data.frame(
    date = c("2024-06-01", "2024-06-02"),
    day_type = c("weekend", "weekend"),
    period_id = c(1L, 1L),
    window_id = c("AM", "PM"),
    stringsAsFactors = FALSE
  )
  utils::write.csv(df, tmp, row.names = FALSE)
  # A file without p_period (GH #385) whose days carry the same periods is
  # read as p_period = 1 with a warning.
  expect_warning(result <- read_schedule(tmp), class = "creel_warning_p_period_inferred")
  expect_type(result$window_id, "character")
  expect_identical(result$window_id, c("AM", "PM"))
})

# ---- #547: the format follows the file name ----------------------------------
# write_schedule() once took its format from `format` alone, default "csv", so
# write_schedule(x, "f.xlsx") wrote comma-separated text under an .xlsx name:
# Excel would not open it and nothing in R said so.

sched_547 <- function() {
  generate_schedule("2024-06-01", "2024-06-14",
    n_periods = 1, sampling_rate = c(weekday = 0.5, weekend = 0.5), seed = 1
  )
}

is_zip <- function(path) {
  # An xlsx file is a zip archive; CSV text is not.
  identical(readBin(path, "raw", 2L), as.raw(c(0x50, 0x4b)))
}

test_that("#547: write_schedule() takes the format from the extension", {
  skip_if_not_installed("writexl")
  x <- withr::local_tempfile(fileext = ".xlsx")
  write_schedule(sched_547(), x)
  expect_true(is_zip(x))
  x2 <- withr::local_tempfile(fileext = ".XLSX")
  write_schedule(sched_547(), x2)
  expect_true(is_zip(x2))
  csv <- withr::local_tempfile(fileext = ".csv")
  write_schedule(sched_547(), csv)
  expect_false(is_zip(csv))
  expect_s3_class(read_schedule(csv), "creel_schedule")
})

test_that("#547: a format that contradicts the extension is refused, before any file is written", {
  x <- withr::local_tempfile(fileext = ".xlsx")
  expect_error(write_schedule(sched_547(), x, format = "csv"), class = "creel_error_write_format")
  expect_false(file.exists(x))
  csv <- withr::local_tempfile(fileext = ".csv")
  expect_error(write_schedule(sched_547(), csv, format = "xlsx"), class = "creel_error_write_format")
  expect_false(file.exists(csv))
})

test_that("#547: an explicit format still works for a name that implies none", {
  p <- withr::local_tempfile(fileext = ".txt")
  write_schedule(sched_547(), p, format = "csv")
  expect_false(is_zip(p))
  expect_error(write_schedule(sched_547(), withr::local_tempfile(fileext = ".txt")),
               class = "creel_error_write_format")
  # .xls is the legacy binary format, which neither writer produces, so no
  # format is written under that name.
  xls <- withr::local_tempfile(fileext = ".xls")
  for (f in c("auto", "csv", "xlsx")) {
    expect_error(write_schedule(sched_547(), xls, format = f), class = "creel_error_write_format", info = f)
  }
  expect_false(file.exists(xls))
})
