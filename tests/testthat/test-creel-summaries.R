# Tests for summarize_*() functions — Phase 31 (USUM-01 through USUM-08)

# --- Shared fixtures -----------------------------------------------------------

make_design_with_extended_interviews <- function() { # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  # Inject one refusal for USUM-01 coverage (example_interviews has all refused=FALSE)
  example_interviews$refused[1] <- TRUE
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings( # nolint: object_usage_linter
    add_interviews(d, example_interviews, # nolint: object_usage_linter
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

make_design_with_catch <- function() {
  data(example_catch, package = "tidycreel")
  d <- make_design_with_extended_interviews()
  add_catch(d, example_catch, # nolint: object_usage_linter
    catch_uid     = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species       = species, # nolint: object_usage_linter
    count         = count, # nolint: object_usage_linter
    catch_type    = catch_type # nolint: object_usage_linter
  )
}

# --- summarize_refusals() — USUM-01 -------------------------------------------

test_that("summarize_refusals() returns a data.frame with correct classes", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_s3_class(result, "data.frame")
  expect_s3_class(result, "creel_summary_refusals")
})

test_that("summarize_refusals() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_true(all(c("month", "participation", "N", "percent") %in% names(result)))
})

test_that("summarize_refusals() N is integer and percent is numeric", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_true(is.integer(result$N))
  expect_true(is.numeric(result$percent))
})

test_that("summarize_refusals() includes both 'accepted' and 'refused' rows", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_true("accepted" %in% result$participation)
  expect_true("refused" %in% result$participation)
})

test_that("summarize_refusals() percent sums to 100 within each month", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  for (m in unique(result$month)) {
    month_sum <- sum(result$percent[result$month == m])
    expect_equal(month_sum, 100, tolerance = 0.5)
  }
})

test_that("summarize_refusals() errors when refused_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_refusals(d2), regexp = "refused")
})

# --- summarize_by_day_type() — USUM-02 ----------------------------------------

test_that("summarize_by_day_type() returns creel_summary_day_type", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  expect_s3_class(result, "creel_summary_day_type")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_day_type() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  expect_true(all(c("month", "day_type", "N", "percent") %in% names(result)))
})

test_that("summarize_by_day_type() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_day_type() percent sums to ~100 within each month", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  for (m in unique(result$month)) {
    month_sum <- sum(result$percent[result$month == m])
    expect_equal(month_sum, 100, tolerance = 0.5)
  }
})

test_that("summarize_by_day_type() works without optional Phase 28 fields", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_no_error(summarize_by_day_type(d2))
})

# --- summarize_by_angler_type() — USUM-03 -------------------------------------

test_that("summarize_by_angler_type() returns creel_summary_angler_type", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_s3_class(result, "creel_summary_angler_type")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_angler_type() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_true(all(c("month", "angler_type", "N", "percent") %in% names(result)))
})

test_that("summarize_by_angler_type() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_angler_type() angler_type values match source data", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_true(all(result$angler_type %in% c("bank", "boat")))
})

test_that("summarize_by_angler_type() errors when angler_type_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_angler_type(d2), regexp = "angler_type")
})

# --- summarize_by_method() — USUM-04 ------------------------------------------

test_that("summarize_by_method() returns creel_summary_method", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_s3_class(result, "creel_summary_method")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_method() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_true(all(c("month", "method", "N", "percent") %in% names(result)))
})

test_that("summarize_by_method() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_method() method values match source data", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_true(all(result$method %in% c("bait", "artificial", "fly")))
})

test_that("summarize_by_method() errors when angler_method_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_method(d2), regexp = "angler_method")
})

# --- summarize_by_species_sought() — USUM-05 ----------------------------------

test_that("summarize_by_species_sought() returns creel_summary_species_sought", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_s3_class(result, "creel_summary_species_sought")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_species_sought() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_true(all(c("month", "species", "N", "percent") %in% names(result)))
})

test_that("summarize_by_species_sought() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_species_sought() species values match source data", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_true(all(result$species %in% c("walleye", "bass", "panfish")))
})

test_that("summarize_by_species_sought() errors when species_sought_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_species_sought(d2), regexp = "species_sought")
})

# --- summarize_successful_parties() — USUM-06 ---------------------------------

test_that("summarize_successful_parties() returns creel_summary_successful_parties", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_s3_class(result, "creel_summary_successful_parties")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_successful_parties() has correct columns", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_true(
    all(c("angler_type", "species_sought", "N_successful", "N_total", "percent") %in% names(result))
  )
})

test_that("summarize_successful_parties() N_successful and N_total are integer", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_true(is.integer(result$N_successful))
  expect_true(is.integer(result$N_total))
})

test_that("summarize_successful_parties() N_successful <= N_total for all rows", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_true(all(result$N_successful <= result$N_total))
})

test_that("summarize_successful_parties() errors when catch is not attached", {
  d <- make_design_with_extended_interviews()
  expect_error(summarize_successful_parties(d), regexp = "catch")
})

test_that("summarize_successful_parties() errors when angler_type_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_successful_parties(d2), regexp = "angler_type")
})

# --- summarize_by_trip_length() — USUM-07 -------------------------------------

test_that("summarize_by_trip_length() returns creel_summary_trip_length", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_s3_class(result, "creel_summary_trip_length")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_trip_length() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true(all(c("trip_length_bin", "N", "percent") %in% names(result)))
})

test_that("summarize_by_trip_length() trip_length_bin is an ordered factor", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true(is.ordered(result$trip_length_bin))
})

test_that("summarize_by_trip_length() bin levels span '[0,1)' through '10+' (11 levels)", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true("[0,1)" %in% levels(result$trip_length_bin))
  expect_true("10+" %in% levels(result$trip_length_bin))
  expect_equal(length(levels(result$trip_length_bin)), 11L)
})

test_that("summarize_by_trip_length() N is integer and percent is numeric", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true(is.integer(result$N))
  expect_true(is.numeric(result$percent))
})

test_that("summarize_by_trip_length() errors when trip_duration_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_trip_length(d2), regexp = "trip_duration")
})

# --- Cross-function guard tests — USUM-08 -------------------------------------

test_that("summarize_refusals() errors when design is not creel_design", {
  expect_error(summarize_refusals(list()), regexp = "creel_design")
})

test_that("summarize_by_day_type() errors when interviews not attached", {
  data(example_calendar, package = "tidycreel")
  d_bare <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(summarize_by_day_type(d_bare), regexp = "interview")
})

test_that("all seven functions return 'data.frame' as part of their class vector", {
  d_full <- make_design_with_catch()
  results <- list(
    summarize_refusals(d_full),
    summarize_by_day_type(d_full),
    summarize_by_angler_type(d_full),
    summarize_by_method(d_full),
    summarize_by_species_sought(d_full),
    summarize_successful_parties(d_full),
    summarize_by_trip_length(d_full)
  )
  for (result in results) {
    expect_true("data.frame" %in% class(result))
  }
})
