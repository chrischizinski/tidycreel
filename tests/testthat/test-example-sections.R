# Tests verifying structure and integration of example_sections_* example datasets.

# Dataset structure tests ----

test_that("example_sections_calendar loads with correct structure", {
  data("example_sections_calendar", package = "tidycreel")
  expect_s3_class(example_sections_calendar, "data.frame")
  expect_equal(nrow(example_sections_calendar), 12L)
  expect_true(all(c("date", "day_type") %in% names(example_sections_calendar)))
  expect_s3_class(example_sections_calendar$date, "Date")
})

test_that("example_sections_calendar day_type contains only weekday and weekend", {
  data("example_sections_calendar", package = "tidycreel")
  expect_true(all(example_sections_calendar$day_type %in% c("weekday", "weekend")))
  expect_equal(sum(example_sections_calendar$day_type == "weekday"), 6L)
  expect_equal(sum(example_sections_calendar$day_type == "weekend"), 6L)
})

test_that("example_sections_counts loads with correct structure", {
  data("example_sections_counts", package = "tidycreel")
  expect_s3_class(example_sections_counts, "data.frame")
  expect_equal(nrow(example_sections_counts), 36L)
  expect_true(all(
    c("date", "day_type", "section", "effort_hours") %in%
      names(example_sections_counts)
  ))
})

test_that("example_sections_counts section column has exactly North, Central, South", {
  data("example_sections_counts", package = "tidycreel")
  expect_equal(length(unique(example_sections_counts$section)), 3L)
  expect_setequal(
    unique(example_sections_counts$section),
    c("North", "Central", "South")
  )
})

test_that("example_sections_counts effort shows material variation across sections", {
  data("example_sections_counts", package = "tidycreel")
  north_effort <- mean(
    example_sections_counts$effort_hours[example_sections_counts$section == "North"]
  )
  central_effort <- mean(
    example_sections_counts$effort_hours[example_sections_counts$section == "Central"]
  )
  south_effort <- mean(
    example_sections_counts$effort_hours[example_sections_counts$section == "South"]
  )
  expect_gt(central_effort, north_effort)
  expect_gt(north_effort, south_effort)
})

test_that("example_sections_interviews loads with correct structure", {
  data("example_sections_interviews", package = "tidycreel")
  expect_s3_class(example_sections_interviews, "data.frame")
  expect_equal(nrow(example_sections_interviews), 27L)
  expect_true(all(
    c(
      "date", "section", "catch_total", "catch_kept", "hours_fished",
      "trip_status", "trip_duration"
    ) %in%
      names(example_sections_interviews)
  ))
})

test_that("example_sections_interviews section column has 3 levels with 9 rows each", {
  data("example_sections_interviews", package = "tidycreel")
  expect_equal(length(unique(example_sections_interviews$section)), 3L)
  counts_per_section <- table(example_sections_interviews$section)
  expect_true(all(counts_per_section == 9L))
})

test_that("example_sections_interviews catch_kept never exceeds catch_total", {
  data("example_sections_interviews", package = "tidycreel")
  expect_true(all(
    example_sections_interviews$catch_kept <= example_sections_interviews$catch_total
  ))
})

test_that("example_sections_interviews catch rate shows material variation across sections", {
  data("example_sections_interviews", package = "tidycreel")
  north_catch <- mean(
    example_sections_interviews$catch_total[example_sections_interviews$section == "North"]
  )
  south_catch <- mean(
    example_sections_interviews$catch_total[example_sections_interviews$section == "South"]
  )
  expect_gt(south_catch, north_catch)
})

# Integration tests ----

test_that("creel design built from example_sections datasets succeeds and estimate_effort returns 4 rows", {
  data("example_sections_calendar", package = "tidycreel")
  data("example_sections_counts", package = "tidycreel")
  data("example_sections_interviews", package = "tidycreel")

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )

  design <- creel_design(
    example_sections_calendar, # nolint: object_usage_linter
    date = date, strata = day_type # nolint: object_usage_linter
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter
  design <- suppressWarnings(
    add_counts(design, example_sections_counts) # nolint: object_usage_linter
  )
  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, example_sections_interviews,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  result <- estimate_effort(design)
  expect_equal(nrow(result$estimates), 4L)
  expect_true(".lake_total" %in% result$estimates$section)
})

test_that("estimate_catch_rate on example_sections design returns exactly 3 rows (no .lake_total)", {
  data("example_sections_calendar", package = "tidycreel")
  data("example_sections_counts", package = "tidycreel")
  data("example_sections_interviews", package = "tidycreel")

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )

  design <- creel_design(
    example_sections_calendar, # nolint: object_usage_linter
    date = date, strata = day_type # nolint: object_usage_linter
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter
  design <- suppressWarnings(
    add_counts(design, example_sections_counts) # nolint: object_usage_linter
  )
  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, example_sections_interviews,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  result <- estimate_catch_rate(design)
  expect_equal(nrow(result$estimates), 3L)
  expect_false(".lake_total" %in% result$estimates$section)
})

test_that("estimate_total_catch with aggregate_sections = TRUE returns 4 rows", {
  data("example_sections_calendar", package = "tidycreel")
  data("example_sections_counts", package = "tidycreel")
  data("example_sections_interviews", package = "tidycreel")

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )

  design <- creel_design(
    example_sections_calendar, # nolint: object_usage_linter
    date = date, strata = day_type # nolint: object_usage_linter
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter
  design <- suppressWarnings(
    add_counts(design, example_sections_counts) # nolint: object_usage_linter
  )
  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, example_sections_interviews,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  result <- estimate_total_catch(design, aggregate_sections = TRUE)
  expect_equal(nrow(result$estimates), 4L)
  expect_true(".lake_total" %in% result$estimates$section)
})
