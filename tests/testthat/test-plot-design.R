# Tests for plot_design() ----

# Helper: minimal creel_design with and without counts
make_design_no_counts <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
}

make_design_with_counts <- function() {
  counts <- data.frame(
    date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count    = c(10L, 14L, 30L, 35L)
  )
  d <- make_design_no_counts()
  suppressWarnings(add_counts(d, counts))
}

test_that("PLTD-01: plot_design() without counts returns a ggplot object", {
  d <- make_design_no_counts()
  p <- plot_design(d)
  expect_s3_class(p, "ggplot")
})

test_that("PLTD-02: plot_design() with counts returns a ggplot object", {
  d <- make_design_with_counts()
  p <- suppressWarnings(plot_design(d))
  expect_s3_class(p, "ggplot")
})

test_that("PLTD-03: plot_design() errors on non-creel_design input", {
  expect_error(
    plot_design(list(a = 1)),
    class = "rlang_error"
  )
})

test_that("PLTD-04: plot_design() errors on NULL input", {
  expect_error(
    plot_design(NULL),
    class = "rlang_error"
  )
})

test_that("PLTD-05: title arg overrides default title (no-counts variant)", {
  d <- make_design_no_counts()
  p <- plot_design(d, title = "My Survey")
  expect_equal(p$labels$title, "My Survey")
})

test_that("PLTD-06: title arg overrides default title (with-counts variant)", {
  d <- make_design_with_counts()
  p <- suppressWarnings(plot_design(d, title = "Count Summary"))
  expect_equal(p$labels$title, "Count Summary")
})

test_that("PLTD-07: no-counts plot data has one row per stratum", {
  d <- make_design_no_counts()
  p <- plot_design(d)
  plot_data <- p$data
  expect_equal(nrow(plot_data), 2L)
  expect_setequal(plot_data$stratum, c("weekday", "weekend"))
})

test_that("PLTD-08: no-counts plot n_days matches calendar", {
  d <- make_design_no_counts()
  p <- plot_design(d)
  wday_n <- p$data$n_days[p$data$stratum == "weekday"]
  wend_n <- p$data$n_days[p$data$stratum == "weekend"]
  expect_equal(wday_n, 2L)
  expect_equal(wend_n, 2L)
})
