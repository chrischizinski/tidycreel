# Test print and format methods for creel_tost_validation ----

test_that("format.creel_tost_validation returns character vector", {
  # Create test design
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2)
  )
  design <- creel_design(cal, date = date, strata = day_type)

  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02"), each = 25)),
    catch_total = rpois(50, lambda = 6),
    hours_fished = runif(50, min = 2, max = 4),
    trip_status = rep(c("complete", "incomplete"), each = 25),
    trip_duration = runif(50, min = 2, max = 4)
  )

  design_with_interviews <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  result <- validate_incomplete_trips(design_with_interviews,
    catch = catch_total,
    effort = hours_fished
  )

  formatted <- format(result)
  expect_type(formatted, "character")
  expect_true(length(formatted) > 0)
})

test_that("print method displays plot for ungrouped validation", {
  # Create test design
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2)
  )
  design <- creel_design(cal, date = date, strata = day_type)

  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02"), each = 25)),
    catch_total = rpois(50, lambda = 6),
    hours_fished = runif(50, min = 2, max = 4),
    trip_status = rep(c("complete", "incomplete"), each = 25),
    trip_duration = runif(50, min = 2, max = 4)
  )

  design_with_interviews <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  result <- validate_incomplete_trips(design_with_interviews,
    catch = catch_total,
    effort = hours_fished
  )

  # Print method should work without error
  # It will produce text output and may generate a plot
  expect_invisible(print(result))
})

test_that("print method displays plot for grouped validation", {
  # Create test design with groups
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2),
    location = rep(c("site_a", "site_b"), times = 2)
  )
  design <- creel_design(cal, date = date, strata = day_type)

  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02"), each = 30)),
    location = rep(c("site_a", "site_b"), times = 30),
    catch_total = rpois(60, lambda = 6),
    hours_fished = runif(60, min = 2, max = 4),
    trip_status = rep(c("complete", "incomplete"), each = 30),
    trip_duration = runif(60, min = 2, max = 4)
  )

  design_with_interviews <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  result <- validate_incomplete_trips(design_with_interviews,
    catch = catch_total,
    effort = hours_fished,
    by = location
  )

  # Print method should work without error for grouped data
  expect_invisible(print(result))
})

test_that("formatted output includes overall test results", {
  # Create test design
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2)
  )
  design <- creel_design(cal, date = date, strata = day_type)

  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02"), each = 25)),
    catch_total = rpois(50, lambda = 6),
    hours_fished = runif(50, min = 2, max = 4),
    trip_status = rep(c("complete", "incomplete"), each = 25),
    trip_duration = runif(50, min = 2, max = 4)
  )

  design_with_interviews <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  result <- validate_incomplete_trips(design_with_interviews,
    catch = catch_total,
    effort = hours_fished
  )

  formatted <- format(result)
  output_text <- paste(formatted, collapse = "\n")

  # Should include key test result elements
  expect_true(grepl("TOST", output_text, ignore.case = TRUE))
  expect_true(grepl("Complete trips", output_text, ignore.case = TRUE))
  expect_true(grepl("Incomplete trips", output_text, ignore.case = TRUE))
})

test_that("formatted output includes per-group results if grouped", {
  # Create test design with groups
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2),
    location = rep(c("site_a", "site_b"), times = 2)
  )
  design <- creel_design(cal, date = date, strata = day_type)

  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02"), each = 30)),
    location = rep(c("site_a", "site_b"), times = 30),
    catch_total = rpois(60, lambda = 6),
    hours_fished = runif(60, min = 2, max = 4),
    trip_status = rep(c("complete", "incomplete"), each = 30),
    trip_duration = runif(60, min = 2, max = 4)
  )

  design_with_interviews <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  result <- validate_incomplete_trips(design_with_interviews,
    catch = catch_total,
    effort = hours_fished,
    by = location
  )

  formatted <- format(result)
  output_text <- paste(formatted, collapse = "\n")

  # Should include per-group results section
  expect_true(grepl("Per-Group", output_text, ignore.case = TRUE))
})

test_that("formatted output includes recommendation text", {
  # Create test design
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2)
  )
  design <- creel_design(cal, date = date, strata = day_type)

  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02"), each = 25)),
    catch_total = rpois(50, lambda = 6),
    hours_fished = runif(50, min = 2, max = 4),
    trip_status = rep(c("complete", "incomplete"), each = 25),
    trip_duration = runif(50, min = 2, max = 4)
  )

  design_with_interviews <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  result <- validate_incomplete_trips(design_with_interviews,
    catch = catch_total,
    effort = hours_fished
  )

  formatted <- format(result)
  output_text <- paste(formatted, collapse = "\n")

  # Should include recommendation
  expect_true(grepl("Recommendation", output_text, ignore.case = TRUE))
})
