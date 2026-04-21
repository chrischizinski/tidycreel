# Snapshot tests for priority text-output print methods.
# These tests guard against unintentional changes to printed output.
# To update snapshots intentionally: testthat::snapshot_accept("snapshots")

test_that("print.creel_design snapshot", {
  local_reproducible_output(width = 80)
  cal <- data.frame(
    date     = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)
  expect_snapshot(print(design))
})

test_that("print.creel_estimates_mor snapshot", {
  local_reproducible_output(width = 80)
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02",
      "2024-06-03", "2024-06-04"
    )),
    day_type = rep("weekday", 4L)
  )
  design <- creel_design(cal, date = date, strata = day_type)
  # 20 interviews: 10 complete + 10 incomplete (MOR requires >= 10 per filtered set)
  interviews <- data.frame(
    date          = as.Date(rep("2024-06-01", 20L)),
    catch_total   = rep(c(2L, 3L, 4L, 5L, 6L), 4L),
    hours_fished  = rep(c(2.0, 3.0, 4.0, 2.5, 3.5), 4L),
    trip_status   = rep(c("complete", "incomplete"), 10L),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5, 3.5), 4L)
  )
  design_data <- add_interviews(
    design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )
  result <- estimate_catch_rate(design_data,
    use_trips = "incomplete",
    estimator = "mor"
  )
  expect_snapshot(print(result))
})

test_that("print.creel_schedule snapshot", {
  local_reproducible_output(width = 80)
  sched <- generate_schedule(
    start_date    = "2024-06-01",
    end_date      = "2024-06-30",
    n_periods     = 1L,
    sampling_rate = c(weekday = 0.5, weekend = 0.8),
    seed          = 42L
  )
  expect_snapshot(print(sched))
})
