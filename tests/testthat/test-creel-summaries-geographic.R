# Tests for geographic summary functions -- Phase 96 (RPT-03, RPT-04, RPT-05)

# --- Shared fixtures -----------------------------------------------------------

make_boat_composition_design <- function() {
  counts_df <- data.frame(
    date = as.Date(c("2024-05-01", "2024-05-04", "2024-06-01", "2024-06-08")),
    day_type = c("weekday", "weekend", "weekday", "weekend"),
    angler_boats = c(3L, 2L, 4L, 1L),
    non_ang_boats = c(1L, 2L, 1L, 3L),
    count = c(10L, 12L, 9L, 8L)
  )
  cal <- data.frame(
    date = counts_df$date,
    day_type = counts_df$day_type
  )
  d <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_counts(d, counts_df) # nolint: object_usage_linter
  )
}

make_boat_composition_schema <- function(
  ab_col = "angler_boats",
  nb_col = "non_ang_boats"
) {
  creel_schema(
    survey_type = "instantaneous",
    angler_boats_col = ab_col,
    non_ang_boats_col = nb_col
  )
}

# --- summarize_boat_composition() — RPT-03 ------------------------------------

test_that("summarize_boat_composition() returns creel_summary_boat_composition class", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_s3_class(result, "creel_summary_boat_composition")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_boat_composition() has columns month, day_type, n_events, pct_angler_boats", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(all(c("month", "day_type", "n_events", "pct_angler_boats") %in% names(result)))
})

test_that("summarize_boat_composition() n_events is integer, pct_angler_boats is numeric", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(is.integer(result$n_events))
  expect_true(is.numeric(result$pct_angler_boats))
})

test_that("summarize_boat_composition() pct_angler_boats is in [0, 100]", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(all(result$pct_angler_boats >= 0))
  expect_true(all(result$pct_angler_boats <= 100))
})

test_that("summarize_boat_composition() correct pct for known input", {
  # May weekday: AB=3, NB=1 -> 3/(3+1) = 0.75 -> 75.0%
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  may_weekday <- result[result$month == "May" & result$day_type == "weekday", ]
  expect_equal(may_weekday$pct_angler_boats, 75.0)
})

test_that("summarize_boat_composition() aborts when design is not creel_design", {
  s <- make_boat_composition_schema()
  expect_error(
    summarize_boat_composition(list(), s),
    regexp = "creel_design"
  )
})

test_that("summarize_boat_composition() aborts when design$counts is NULL", {
  # Build a design without add_counts()
  cal <- data.frame(
    date = as.Date("2024-05-01"),
    day_type = "weekday"
  )
  d_no_counts <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  s <- make_boat_composition_schema()
  expect_error(
    summarize_boat_composition(d_no_counts, s),
    regexp = "add_counts"
  )
})

test_that("summarize_boat_composition() aborts when schema$angler_boats_col is NULL", {
  d <- make_boat_composition_design()
  s_no_ab <- creel_schema(
    survey_type = "instantaneous",
    non_ang_boats_col = "non_ang_boats"
  )
  expect_error(
    summarize_boat_composition(d, s_no_ab),
    regexp = "angler_boats_col"
  )
})

test_that("summarize_boat_composition() aborts when schema$non_ang_boats_col is NULL", {
  d <- make_boat_composition_design()
  s_no_nb <- creel_schema(
    survey_type = "instantaneous",
    angler_boats_col = "angler_boats"
  )
  expect_error(
    summarize_boat_composition(d, s_no_nb),
    regexp = "non_ang_boats_col"
  )
})

test_that("summarize_boat_composition() result has one row per month x day_type combination", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  # 2 months (May, June) x 2 day types (weekday, weekend) = 4 rows
  expect_equal(nrow(result), 4L)
})

# --- summarize_by_zip() -------------------------------------------------------

make_zip_design <- function() {
  # Use example_interviews, inject ii_ZipCode (5 rows, 2 NA) for zip tests
  data(example_interviews, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  ints <- example_interviews
  # Inject ii_ZipCode: cycle through c("68502","68502",NA,"68508",NA) for all rows
  zip_pattern <- c("68502", "68502", NA_character_, "68508", NA_character_)
  ints$ii_ZipCode <- rep_len(zip_pattern, nrow(ints))
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_interviews(
      d,
      ints, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
}

test_that("summarize_by_zip() returns creel_summary_zip class", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_s3_class(result, "creel_summary_zip")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_zip() has columns zip_code, n, pct", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_true(all(c("zip_code", "n", "pct") %in% names(result)))
})

test_that("summarize_by_zip() n is integer, pct is numeric", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_true(is.integer(result$n))
  expect_true(is.numeric(result$pct))
})

test_that("summarize_by_zip() includes Unknown row for NA zips", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_true("Unknown" %in% result$zip_code)
})

test_that("summarize_by_zip() pct sums to 100 (tolerance 0.5)", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_equal(sum(result$pct), 100, tolerance = 0.5)
})

test_that("summarize_by_zip() Unknown row n matches NA count in interviews", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  unk_row <- result[result$zip_code == "Unknown", ]
  # NA count should match what was injected: 2 of every 5 rows are NA
  # Verify Unknown n matches actual NA count in interviews
  n_na <- sum(is.na(d$interviews[["ii_ZipCode"]]))
  expect_equal(unk_row$n, as.integer(n_na))
  # pct = n_na / total_n * 100
  total_n <- nrow(d$interviews)
  expect_equal(unk_row$pct, round(100 * n_na / total_n, 1))
})

test_that("summarize_by_zip() aborts when interviews not attached", {
  cal <- data.frame(
    date = as.Date("2024-05-01"),
    day_type = "weekday"
  )
  d_no_int <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    summarize_by_zip(d_no_int),
    regexp = "add_interviews"
  )
})

test_that("summarize_by_zip() aborts when ii_ZipCode not in interviews", {
  # Use example_interviews (no ii_ZipCode column) with proper column mappings
  data(example_interviews, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
  expect_error(
    summarize_by_zip(d),
    regexp = "ii_ZipCode"
  )
})

# --- summarize_by_county() ----------------------------------------------------

test_that("summarize_by_county() aborts when zipcodeR not installed", {
  skip_if(
    requireNamespace("zipcodeR", quietly = TRUE),
    "zipcodeR is installed — guard fires only when absent"
  )
  # Guard 0 fires before class check, so a plain list is sufficient
  expect_error(
    summarize_by_county(list()),
    regexp = "zipcodeR"
  )
})

test_that("summarize_by_county() returns creel_summary_county", {
  skip_if_not_installed("zipcodeR")
  d <- make_zip_design()
  result <- summarize_by_county(d)
  expect_s3_class(result, "creel_summary_county")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_county() has columns county, n, pct", {
  skip_if_not_installed("zipcodeR")
  d <- make_zip_design()
  result <- summarize_by_county(d)
  expect_true(all(c("county", "n", "pct") %in% names(result)))
})

test_that("summarize_by_county() includes Unknown row for NA zips", {
  skip_if_not_installed("zipcodeR")
  d <- make_zip_design()
  result <- summarize_by_county(d)
  expect_true("Unknown" %in% result$county)
})

test_that("summarize_by_county() aborts when interviews not attached", {
  skip_if_not_installed("zipcodeR")
  data(example_calendar, package = "tidycreel")
  d_no_int <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    summarize_by_county(d_no_int),
    regexp = "add_interviews"
  )
})

test_that("summarize_by_county() aborts when ii_ZipCode not in interviews", {
  skip_if_not_installed("zipcodeR")
  data(example_interviews, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
  expect_error(
    summarize_by_county(d),
    regexp = "ii_ZipCode"
  )
})
