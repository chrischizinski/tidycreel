# Tests for autoplot.creel_schedule() — SCHED-PLOT-01 through SCHED-PLOT-04

skip_if_not_installed("ggplot2")

# ---- Shared fixtures ----

make_one_month_sched <- function() {
  suppressWarnings(
    generate_schedule(
      start_date = "2024-06-01",
      end_date = "2024-06-30",
      n_periods = 1,
      sampling_rate = c(weekday = 0.5, weekend = 1.0),
      seed = 1
    )
  )
}

make_two_month_sched <- function() {
  suppressWarnings(
    generate_schedule(
      start_date = "2024-06-01",
      end_date = "2024-07-31",
      n_periods = 1,
      sampling_rate = c(weekday = 0.3, weekend = 0.6),
      seed = 42
    )
  )
}

# ---- SCHED-PLOT-01: return type ----

test_that("autoplot() returns a ggplot for single-month schedule", {
  sched <- make_one_month_sched()
  result <- ggplot2::autoplot(sched)
  expect_s3_class(result, "ggplot")
})

test_that("autoplot() returns a ggplot for multi-month schedule", {
  sched <- make_two_month_sched()
  result <- ggplot2::autoplot(sched)
  expect_s3_class(result, "ggplot")
})

# ---- SCHED-PLOT-02: renders without error ----

test_that("autoplot.creel_schedule() renders via ggplot_build without error", {
  sched <- make_one_month_sched()
  p <- ggplot2::autoplot(sched)
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot.creel_schedule() multi-month renders without error", {
  sched <- make_two_month_sched()
  p <- ggplot2::autoplot(sched)
  expect_no_error(ggplot2::ggplot_build(p))
})

# ---- SCHED-PLOT-03: title argument ----

test_that("autoplot.creel_schedule() accepts title argument", {
  sched <- make_one_month_sched()
  expect_no_error(ggplot2::autoplot(sched, title = "My Survey"))
})

test_that("autoplot.creel_schedule() title appears in plot labels", {
  sched <- make_one_month_sched()
  p <- ggplot2::autoplot(sched, title = "Lake X Schedule")
  expect_equal(p$labels$title, "Lake X Schedule")
})

# ---- SCHED-PLOT-04: plot contains data ----

test_that("autoplot.creel_schedule() plot data has rows", {
  sched <- make_one_month_sched()
  p <- ggplot2::autoplot(sched)
  built <- ggplot2::ggplot_build(p)
  expect_true(nrow(built$data[[1L]]) > 0L)
})

# ---- circuit_id enhancement --------------------------------------------------

test_that("SCHED-PLOT-CIRC-01: schedule with circuit_id returns ggplot", {
  sched <- new_creel_schedule(data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    circuit_id = c("C1", "C2", "C1", "C2"),
    stringsAsFactors = FALSE
  ))
  p <- autoplot(sched)
  expect_s3_class(p, "ggplot")
})

test_that("SCHED-PLOT-CIRC-02: circuit_id schedule fill_group uses circuit values", {
  sched <- new_creel_schedule(data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    circuit_id = c("C1", "C2", "C1", "C2"),
    stringsAsFactors = FALSE
  ))
  p <- autoplot(sched)
  # fill_group on sampled days should be circuit IDs, not weekday/weekend
  sampled_fills <- p$data$fill_group[p$data$sampled]
  expect_true(all(sampled_fills %in% c("C1", "C2")))
  expect_false(any(sampled_fills %in% c("weekday", "weekend")))
})

test_that("SCHED-PLOT-CIRC-03: schedule without circuit_id still uses day_type fill", {
  sched <- new_creel_schedule(data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  ))
  p <- autoplot(sched)
  sampled_fills <- p$data$fill_group[p$data$sampled]
  expect_true(all(sampled_fills %in% c("weekday", "weekend")))
})
