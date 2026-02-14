# Test suite for summarize_trips() and trip metadata in example data

# Helper to create design with trip metadata
create_trip_design <- function() {
  data(example_calendar, package = "tidycreel", envir = environment())
  data(example_interviews, package = "tidycreel", envir = environment())

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )
}

# Example data tests ----

test_that("example_interviews has trip_status column", {
  data(example_interviews, package = "tidycreel")
  expect_true("trip_status" %in% names(example_interviews))
})

test_that("example_interviews has trip_duration column", {
  data(example_interviews, package = "tidycreel")
  expect_true("trip_duration" %in% names(example_interviews))
})

test_that("all trip_status values are complete or incomplete", {
  data(example_interviews, package = "tidycreel")
  valid_values <- c("complete", "incomplete")
  expect_true(all(example_interviews$trip_status %in% valid_values))
})

test_that("all trip_duration values are positive numeric", {
  data(example_interviews, package = "tidycreel")
  expect_true(is.numeric(example_interviews$trip_duration))
  expect_true(all(example_interviews$trip_duration > 0))
  expect_false(anyNA(example_interviews$trip_duration))
})

# summarize_trips() happy path tests ----

test_that("summarize_trips returns creel_trip_summary object", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expect_s3_class(result, "creel_trip_summary")
})

test_that("n_total equals number of interviews", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expect_equal(result$n_total, nrow(design$interviews))
})

test_that("n_complete + n_incomplete equals n_total", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expect_equal(result$n_complete + result$n_incomplete, result$n_total)
})

test_that("pct_complete is numeric between 0 and 100", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expect_true(is.numeric(result$pct_complete))
  expect_gte(result$pct_complete, 0)
  expect_lte(result$pct_complete, 100)
})

test_that("duration_stats is a data frame", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expect_s3_class(result$duration_stats, "data.frame")
})

test_that("duration_stats has correct columns", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expected_cols <- c("status", "n", "min", "median", "mean", "max", "sd")
  expect_true(all(expected_cols %in% names(result$duration_stats)))
})

test_that("duration_stats has rows for each trip status present", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  statuses <- unique(design$interviews[[design$trip_status_col]])
  expect_true(all(statuses %in% result$duration_stats$status))
})

test_that("format method produces character output", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  formatted <- format(result)
  expect_true(is.character(formatted))
  expect_gt(length(formatted), 0)
})

test_that("print method works without error", {
  design <- create_trip_design()
  result <- summarize_trips(design)
  expect_silent(capture.output(print(result)))
})

# summarize_trips() error tests ----

test_that("error when design has no interviews", {
  data(example_calendar, package = "tidycreel")
  design <- creel_design(example_calendar, date = date, strata = day_type)

  expect_error(
    summarize_trips(design),
    "No interviews found"
  )
})

test_that("error when design has no trip metadata", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_interviews(design, example_interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Manually remove trip_status_col to simulate design without metadata
  design$trip_status_col <- NULL

  expect_error(
    summarize_trips(design),
    "No trip metadata found"
  )
})

test_that("error when design is not creel_design", {
  fake_design <- list(interviews = data.frame(x = 1))

  expect_error(
    summarize_trips(fake_design),
    "must be a.*creel_design"
  )
})

# Duration statistics accuracy tests ----

test_that("duration statistics are calculated correctly", {
  design <- create_trip_design()
  result <- summarize_trips(design)

  # Check complete trips
  complete_mask <- design$interviews[[design$trip_status_col]] == "complete"
  complete_durations <- design$interviews[[design$trip_duration_col]][complete_mask]

  complete_row <- result$duration_stats[result$duration_stats$status == "complete", ]
  expect_equal(complete_row$min, round(min(complete_durations), 2))
  expect_equal(complete_row$max, round(max(complete_durations), 2))
  expect_equal(complete_row$mean, round(mean(complete_durations), 2))
  expect_equal(complete_row$median, round(median(complete_durations), 2))
})

test_that("percentages sum to approximately 100", {
  design <- create_trip_design()
  result <- summarize_trips(design)

  # Allow for rounding differences
  total_pct <- result$pct_complete + result$pct_incomplete
  expect_gte(total_pct, 99.9)
  expect_lte(total_pct, 100.1)
})
