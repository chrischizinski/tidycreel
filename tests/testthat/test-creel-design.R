# Tests for creel_design S3 class

test_that("creel_design() creates valid object with basic inputs", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_s3_class(design, "creel_design")
  expect_equal(design$date_col, "date")
  expect_equal(design$strata_cols, "day_type")
  expect_null(design$site_col)
  expect_equal(design$design_type, "instantaneous")
  expect_identical(design$calendar, cal)
})

test_that("creel_design() accepts multiple strata columns", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
    day_type = c("weekday", "weekend", "weekend"),
    season = c("summer", "summer", "summer")
  )
  design <- creel_design(cal, date = date, strata = c(day_type, season))

  expect_equal(design$strata_cols, c("day_type", "season"))
  expect_length(design$strata_cols, 2)
})

test_that("creel_design() accepts optional site column", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    lake = c("lake_a", "lake_b")
  )
  design <- creel_design(cal, date = date, strata = day_type, site = lake)

  expect_equal(design$site_col, "lake")
})

test_that("creel_design() sets site_col to NULL when site omitted", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_null(design$site_col)
})

test_that("creel_design() accepts tidyselect helpers", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    day_season = c("summer", "summer")
  )
  design <- creel_design(cal, date = date, strata = starts_with("day"))

  expect_equal(design$strata_cols, c("day_type", "day_season"))
})

test_that("creel_design() fails when date column is not Date class", {
  cal <- data.frame(
    date = c("2024-06-01", "2024-06-02"),
    day_type = c("weekday", "weekend")
  )

  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    "must be of class"
  )
})

test_that("creel_design() fails when date column is numeric", {
  cal <- data.frame(
    date = c(1, 2, 3),
    day_type = c("weekday", "weekend", "weekend")
  )

  expect_error(
    creel_design(cal, date = date, strata = day_type),
    "must be of class"
  )
})

test_that("creel_design() fails when date column contains NA values", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", NA, "2024-06-03")),
    day_type = c("weekday", "weekend", "weekend")
  )

  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    "must not contain"
  )
})

test_that("creel_design() fails when strata column is numeric", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c(1, 2)
  )

  expect_error(
    creel_design(cal, date = date, strata = day_type),
    "must be character or factor"
  )
})

test_that("creel_design() fails when selecting non-existent column", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )

  expect_error(
    creel_design(cal, date = nonexistent, strata = day_type)
  )
})

test_that("creel_design() fails when date selector matches multiple columns", {
  cal <- data.frame(
    date1 = as.Date(c("2024-06-01", "2024-06-02")),
    date2 = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )

  expect_error(
    creel_design(cal, date = starts_with("date"), strata = day_type),
    "exactly one column"
  )
})

test_that("format.creel_design() returns character vector", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)
  out <- format(design)

  expect_type(out, "character")
  expect_true(length(out) > 0)
})

test_that("print.creel_design() returns invisibly", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_invisible(print(design))
})

test_that("summary.creel_design() returns invisibly", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_invisible(summary(design))
})

test_that("creel_design() stores original calendar data frame", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_identical(design$calendar, cal)
})

test_that("creel_design() defaults design_type to instantaneous", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_equal(design$design_type, "instantaneous")
})
