# Force reload of package before tests
setup({
  suppressMessages(devtools::load_all())
})

# Robust tests for est_effort()
library(testthat)
library(tidycreel)
library(dplyr)

make_calendar_data <- function() {
  tibble::tibble(
    date = as.Date("2025-08-20"),
    stratum_id = "A",
    day_type = "weekday",
    season = "summer",
    month = "August",
    weekend = FALSE,
    holiday = FALSE,
    shift_block = "morning",
    target_sample = 1,
    actual_sample = 1
  )
}

make_minimal_interviews <- function() {
  tibble::tibble(
    interview_id = c("INT001", "INT002"),
    date = as.Date(c("2025-08-20", "2025-08-20")),
    shift_block = c("morning", "morning"),
    time_start = as.POSIXct(c("2025-08-20 08:00:00", "2025-08-20 08:30:00")),
    time_end = as.POSIXct(c("2025-08-20 08:15:00", "2025-08-20 08:45:00")),
    location = c("Lake_A", "Lake_B"),
    mode = c("boat", "bank"),
    party_size = c(2, 3),
    hours_fished = c(3.5, 2.0),
    target_species = c("walleye", "bass"),
    catch_total = c(5, 3),
    catch_kept = c(2, 1),
    catch_released = c(3, 2),
    weight_total = c(0, 1.2),
    trip_complete = c(TRUE, FALSE),
    effort_expansion = c(1, 1)
  )
}

test_that("est_effort instantaneous handles multiple counts per stratum", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date(rep("2025-08-20", 4)),
    time = c(1, 2, 3, 4),
    count = c(10, 12, 11, 13),
    party_size = c(2, 2, 2, 2),
    stratum = c("A", "A", "A", "A"),
    shift_block = rep("morning", 4)
  )
  result <- est_effort(design, counts, method = "instantaneous")
  expect_true("effort_estimate" %in% names(result))
  expect_equal(nrow(result), 1)
  expect_gt(result$effort_estimate, 0)
})

test_that("est_effort progressive handles intervals and missing intervals", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date(rep("2025-08-20", 3)),
    time = c(1, 2, 4),
    count = c(10, 12, 11),
    party_size = c(2, 2, 2),
    stratum = c("A", "A", "A"),
    shift_block = rep("morning", 3)
  )
  result <- est_effort(design, counts, method = "progressive")
  expect_true("effort_estimate" %in% names(result))
  expect_equal(nrow(result), 1)
  expect_gt(result$effort_estimate, 0)
})

test_that("est_effort returns SE and CI columns", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date(rep("2025-08-20", 3)),
    time = c(1, 2, 3),
    count = c(10, 12, 11),
    party_size = c(2, 2, 2),
    stratum = c("A", "A", "A"),
    shift_block = rep("morning", 3)
  )
  result <- est_effort(design, counts, method = "instantaneous")
  expect_true(all(c("effort_se", "effort_ci_low", "effort_ci_high") %in% names(result)))
})

test_that("est_effort handles missing counts and party_size gracefully", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date(rep("2025-08-20", 3)),
    time = c(1, 2, 3),
    count = c(10, NA, 11),
    party_size = c(2, NA, 2),
    stratum = c("A", "A", "A"),
    shift_block = rep("morning", 3)
  )
  result <- est_effort(design, counts, method = "instantaneous")
  expect_true(!any(is.nan(result$effort_estimate)))
})

test_that("est_effort errors on missing required columns", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date(rep("2025-08-20", 3)),
    time = c(1, 2, 3),
    count = c(10, 12, 11),
    stratum = c("A", "A", "A"),
    shift_block = rep("morning", 3)
    # missing party_size
  )
  expect_error(est_effort(design, counts, method = "instantaneous"))
})

# Edge case: zero counts
test_that("est_effort handles zero counts", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date(rep("2025-08-20", 3)),
    time = c(1, 2, 3),
    count = c(0, 0, 0),
    party_size = c(2, 2, 2),
    stratum = c("A", "A", "A"),
    shift_block = rep("morning", 3)
  )
  result <- est_effort(design, counts, method = "instantaneous")
  expect_equal(result$effort_estimate, 0)
})

# Edge case: single count
test_that("est_effort handles single count per stratum", {
  calendar <- make_calendar_data()
  interviews <- make_minimal_interviews()
  design <- design_access(interviews = interviews, calendar = calendar)
  counts <- tibble(
    date = as.Date("2025-08-20"),
    time = 1,
    count = 10,
    party_size = 2,
    stratum = "A",
    shift_block = "morning"
  )
  result <- est_effort(design, counts, method = "instantaneous")
  expect_equal(nrow(result), 1)
  expect_equal(result$effort_estimate, 10 * 0 / 2) # time_interval is 0
})
