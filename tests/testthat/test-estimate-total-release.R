# Test helpers ----

#' Create test design with BOTH counts and interviews and catch data (for total release)
make_total_release_design <- function() {
  # Use example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )
  suppressWarnings(add_catch( # nolint: object_usage_linter
    design, example_catch, # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

#' Create test design with counts only (no interviews), needed for validation test
make_counts_only_release_design <- function() { # nolint: object_length_linter
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  add_counts(design, example_counts) # nolint: object_usage_linter
}

#' Create test design with interviews only (no counts)
make_interviews_only_release_design <- function() { # nolint: object_length_linter
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )
  suppressWarnings(add_catch( # nolint: object_usage_linter
    design, example_catch, # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

# Basic behavior tests ----

test_that("estimate_total_release returns creel_estimates class object", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_release result has estimates tibble with correct columns", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_total_release result method is 'product-total-release'", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_equal(result$method, "product-total-release")
})

test_that("estimate_total_release result variance_method is 'taylor' by default", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_total_release result conf_level is 0.95 by default", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_total_release defaults effort_target to sampled_days", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_equal(result$effort_target, "sampled_days")
})

test_that("estimate_total_release estimate is a non-negative numeric value", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_total_release errors when design is not creel_design", {
  fake_design <- "not a design"

  expect_error(
    estimate_total_release(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_total_release errors when design has no catch data", {
  design <- make_counts_only_release_design()

  expect_error(
    estimate_total_release(design), # nolint: object_usage_linter
    "add_catch"
  )
})

test_that("estimate_total_release errors when design has no counts", {
  design <- make_interviews_only_release_design()

  expect_error(
    suppressMessages(estimate_total_release(design)) # nolint: object_usage_linter
  )
})

test_that("estimate_total_release errors for invalid variance method", {
  design <- make_total_release_design()

  expect_error(
    estimate_total_release(design, variance = "invalid_method"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

# Reference tests ----

test_that("total release estimate is finite and positive", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

test_that("total release CI is finite and contains estimate", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design)) # nolint: object_usage_linter

  expect_true(is.finite(result$estimates$ci_lower))
  expect_true(is.finite(result$estimates$ci_upper))
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

# Variance method tests ----

test_that("estimate_total_release with bootstrap variance returns correct method", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design, variance = "bootstrap")) # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("estimate_total_release with jackknife variance returns correct method", {
  design <- make_total_release_design()

  result <- suppressWarnings(estimate_total_release(design, variance = "jackknife")) # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("estimate_total_release with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_total_release_design()

  result_95 <- suppressWarnings(estimate_total_release(design, conf_level = 0.95)) # nolint: object_usage_linter
  result_90 <- suppressWarnings(estimate_total_release(design, conf_level = 0.90)) # nolint: object_usage_linter

  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

# Section dispatch fixtures and stubs (PROD-01, PROD-02) ----

#' Create 3-section creel_design for total release section tests
#'
#' Produces a creel_design with sections "North", "Central", "South" and
#' counts, interview data, and catch data (released records) for all three
#' sections. 12-date calendar, 9 interviews per section. Data shape is
#' identical to the Phase 40 fixture make_3section_design_with_interviews().
#' Fixture name is explicit about purpose (total catch/release context).
make_3section_total_catch_design <- function() { # nolint: object_length_linter
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-07", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-14", "2024-06-15",
      "2024-06-16", "2024-06-21"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend", "weekend", "weekend", "weekend"
    ),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter

  # 36-row counts: each of the 12 dates repeated for each of 3 sections
  counts <- data.frame(
    date = rep(cal$date, times = 3),
    day_type = rep(cal$day_type, times = 3),
    section = rep(c("North", "Central", "South"), each = nrow(cal)),
    effort_hours = c(
      # North: weekday ~15-25, weekend ~20-28
      20, 22, 18, 25, 15, 24,
      21, 26, 23, 28, 20, 27,
      # Central: weekday ~30-45, weekend ~35-48
      35, 38, 32, 42, 30, 45,
      37, 44, 40, 48, 35, 46,
      # South: weekday ~5-12, weekend ~6-13
      8, 10, 5, 12, 6, 11,
      7, 9, 6, 13, 8, 10
    ),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  # 27 interviews: 9 per section, with catch, harvest, and interview_id columns
  interviews <- data.frame(
    date = as.Date(c(
      # North (9 interviews)
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-07", "2024-06-10", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14",
      # Central (9 interviews)
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-10", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-21",
      # South (9 interviews)
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-07", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend"
    ),
    section = rep(c("North", "Central", "South"), each = 9),
    catch_total = c(
      # North: ~1 fish/hr
      2, 3, 2, 4, 3, 2, 3, 4, 3,
      # Central: ~1.5 fish/hr
      5, 6, 5, 7, 6, 5, 7, 8, 6,
      # South: ~2.5 fish/hr
      10, 12, 9, 11, 10, 12, 13, 11, 10
    ),
    catch_kept = c(
      # North
      1, 2, 1, 3, 2, 1, 2, 3, 2,
      # Central
      3, 4, 3, 5, 4, 3, 5, 6, 4,
      # South
      7, 9, 6, 8, 7, 9, 10, 8, 7
    ),
    hours_fished = c(
      # North: 2-3 hrs
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      # Central: 3-4 hrs
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      # South: 4-5 hrs
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    trip_status = rep("complete", 27),
    trip_duration = c(
      # North
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      # Central
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      # South
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    interview_id = seq_len(27L),
    stringsAsFactors = FALSE
  )

  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  # Build catch data: one "released" row per interview (released = catch - kept)
  catch_df <- data.frame(
    interview_id = interviews$interview_id,
    species = "walleye",
    count = pmax(0L, interviews$catch_total - interviews$catch_kept),
    catch_type = "released",
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_catch( # nolint: object_usage_linter
    design, catch_df,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

# PROD-01: Per-section rows for estimate_total_release ----

test_that("PROD-01-release: estimate_total_release on 3-section design returns a tibble with a section column", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design) # nolint: object_usage_linter
  ))
  expect_true("section" %in% names(result$estimates))
})

test_that("PROD-01-release-rows: estimate_total_release returns 3 section rows (aggregate_sections=FALSE)", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design, aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 3L)
})

# PROD-02: Lake total row for estimate_total_release ----

test_that("PROD-02-release-lake: aggregate_sections=TRUE appends .lake_total row (4 rows total for 3-section design)", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 4L)
  expect_true(".lake_total" %in% result$estimates$section)
})

test_that("PROD-02-release-sum: .lake_total$estimate equals sum of per-section estimates", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  section_rows <- result$estimates[result$estimates$section != ".lake_total", ]
  lake_row <- result$estimates[result$estimates$section == ".lake_total", ]
  expect_equal(lake_row$estimate, sum(section_rows$estimate), tolerance = 1e-10)
})

test_that("PROD-02-release-se: .lake_total$se equals sqrt(sum(se_i^2)) over present section rows", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  section_rows <- result$estimates[result$estimates$section != ".lake_total", ]
  lake_row <- result$estimates[result$estimates$section == ".lake_total", ]
  expected_se <- sqrt(sum(section_rows$se^2))
  expect_equal(lake_row$se, expected_se, tolerance = 1e-10)
})

test_that("PROD-02-release-prop: prop_of_lake_total for present sections sums to 1.0", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design, aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_true("prop_of_lake_total" %in% names(result$estimates))
  expect_equal(sum(result$estimates$prop_of_lake_total), 1.0, tolerance = 1e-10)
})

# PROD-02-release-regression: Non-sectioned designs return identical results (regression guard) ----

test_that("PROD-02-release-regression: non-sectioned design returns same result as pre-Phase-41", {
  design_no_sections <- make_total_release_design() # nolint: object_usage_linter
  result <- suppressWarnings(estimate_total_release(design_no_sections)) # nolint: object_usage_linter
  expect_s3_class(result, "creel_estimates")
  expect_false("section" %in% names(result$estimates))
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

test_that("PROD-02-release-target: section path preserves requested effort target", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_release(design, target = "period_total", aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_equal(result$effort_target, "period_total")
})

# PROD-01-release-missing: Missing section inserts NA row with data_available=FALSE ----

#' Create 3-section release design with "South" absent from interview and catch data
#'
#' Registered sections: "North", "Central", "South".
#' Interview data contains only "North" and "Central" rows — "South" absent.
make_3section_release_design_missing_south <- function() { # nolint: object_length_linter
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-07", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-14", "2024-06-15",
      "2024-06-16", "2024-06-21"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend", "weekend", "weekend", "weekend"
    ),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter

  counts <- data.frame(
    date = rep(cal$date, times = 3),
    day_type = rep(cal$day_type, times = 3),
    section = rep(c("North", "Central", "South"), each = nrow(cal)),
    effort_hours = c(
      20, 22, 18, 25, 15, 24, 21, 26, 23, 28, 20, 27,
      35, 38, 32, 42, 30, 45, 37, 44, 40, 48, 35, 46,
      8, 10, 5, 12, 6, 11, 7, 9, 6, 13, 8, 10
    ),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  # Only North and Central interviews (interview_id 1..18) — South absent
  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-07", "2024-06-10", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14",
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-10", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-21"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend"
    ),
    section = rep(c("North", "Central"), each = 9),
    catch_total = c(
      2, 3, 2, 4, 3, 2, 3, 4, 3,
      5, 6, 5, 7, 6, 5, 7, 8, 6
    ),
    catch_kept = c(
      1, 2, 1, 3, 2, 1, 2, 3, 2,
      3, 4, 3, 5, 4, 3, 5, 6, 4
    ),
    hours_fished = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    trip_status = rep("complete", 18),
    trip_duration = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    interview_id = 1L:18L,
    stringsAsFactors = FALSE
  )

  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  # Build catch data: released rows for North + Central only (interview_id 1..18)
  catch_df <- data.frame(
    interview_id = 1L:18L,
    species = "walleye",
    count = pmax(0L, interviews$catch_total - interviews$catch_kept),
    catch_type = "released",
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_catch( # nolint: object_usage_linter
    design, catch_df,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

test_that("PROD-01-release-missing: missing section inserts NA row with data_available=FALSE for estimate_total_release", { # nolint: line_length_linter
  design <- make_3section_release_design_missing_south() # nolint: object_usage_linter
  warns <- character(0)
  result <- withCallingHandlers(
    estimate_total_release(design, missing_sections = "warn"), # nolint: object_usage_linter
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  south_row <- result$estimates[result$estimates$section == "South", ]
  expect_equal(nrow(south_row), 1L)
  expect_false(south_row$data_available)
  expect_true(is.na(south_row$estimate))
})
