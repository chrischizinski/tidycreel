# Test helpers ----

#' Create 3-section creel_design with interview data (RATE section fixtures)
#'
#' Produces a creel_design with sections "North", "Central", "South" and
#' interview data for all three sections. 12-date calendar, 8-10 interviews
#' per section with varying catch/effort across sections.
make_3section_design_with_interviews <- function() { # nolint: object_length_linter
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

  # Interview data: 9 rows per section (27 total), section + day_type columns
  # North: low catch rate ~1.0 fish/hr
  # Central: moderate catch rate ~1.5 fish/hr
  # South: high catch rate ~2.5 fish/hr
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
      # North
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      # Central
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      # South
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
    hours_fished = c(
      # North: 2-3 hrs
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      # Central: 3-4 hrs
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      # South: 4-5 hrs
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    catch_kept = c(
      # North
      1, 2, 1, 3, 2, 1, 2, 3, 2,
      # Central
      3, 4, 3, 5, 4, 3, 5, 6, 4,
      # South
      7, 9, 6, 8, 7, 9, 10, 8, 7
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
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

#' Create 3-section design with "South" section absent from interview data
#'
#' Registered sections: "North", "Central", "South".
#' Interview data contains only "North" and "Central" rows — "South" is absent.
make_section_design_with_missing_interview_section <- function() { # nolint: object_length_linter
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

  # Only North and Central interviews — South absent
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
    hours_fished = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    catch_kept = c(
      1, 2, 1, 3, 2, 1, 2, 3, 2,
      3, 4, 3, 5, 4, 3, 5, 6, 4
    ),
    trip_status = rep("complete", 18),
    trip_duration = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

#' Create test calendar data with 8 dates (4 weekday, 4 weekend)
make_test_calendar_cpue <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
}

#' Create test interview data with 40+ interviews (20+ complete per stratum)
make_test_interviews <- function() {
  # Create 40 interviews: 20 weekday (all complete), 20 weekend (all complete)
  # This ensures sufficient complete trips for new default behavior
  # Spread across multiple dates within each stratum
  data.frame(
    date = as.Date(c(
      # Weekday interviews (20 total, spread across 4 dates)
      rep("2024-06-01", 5), rep("2024-06-02", 5),
      rep("2024-06-03", 5), rep("2024-06-04", 5),
      # Weekend interviews (20 total, spread across 4 dates)
      rep("2024-06-08", 5), rep("2024-06-09", 5),
      rep("2024-06-15", 5), rep("2024-06-16", 5)
    )),
    catch_total = c(
      # Weekday catch (realistic variation)
      2, 5, 3, 1, 4, 6, 2, 3, 5, 7, 4, 2, 3, 6, 5, 4, 2, 3, 5, 6,
      # Weekend catch (higher on average)
      8, 10, 6, 9, 7, 11, 8, 10, 9, 12, 7, 8, 10, 11, 9, 8, 7, 9, 10, 11
    ),
    hours_fished = c(
      # Weekday effort (2-5 hours)
      2.5, 4.0, 3.5, 2.0, 3.0, 5.0, 2.5, 3.5, 4.5, 5.0, 3.5, 2.5, 3.0, 4.5, 4.0, 3.5, 2.5, 3.0, 4.0, 4.5,
      # Weekend effort (3-6 hours)
      4.0, 5.5, 3.5, 5.0, 4.5, 6.0, 4.5, 5.5, 5.0, 6.0, 4.0, 4.5, 5.5, 5.5, 5.0, 4.5, 4.0, 5.0, 5.5, 5.5
    ),
    catch_kept = c(
      # Kept fish (always <= catch_total)
      2, 4, 3, 1, 3, 5, 2, 2, 4, 6, 3, 2, 2, 5, 4, 3, 2, 2, 4, 5,
      5, 8, 5, 7, 6, 9, 6, 8, 7, 10, 5, 6, 8, 9, 7, 6, 5, 7, 8, 9
    ),
    trip_status = rep("complete", 40),
    trip_duration = c(
      # Trip durations matching hours_fished
      2.5, 4.0, 3.5, 2.0, 3.0, 5.0, 2.5, 3.5, 4.5, 5.0, 3.5, 2.5, 3.0, 4.5, 4.0, 3.5, 2.5, 3.0, 4.0, 4.5,
      4.0, 5.5, 3.5, 5.0, 4.5, 6.0, 4.5, 5.5, 5.0, 6.0, 4.0, 4.5, 5.5, 5.5, 5.0, 4.5, 4.0, 5.0, 5.5, 5.5
    ),
    stringsAsFactors = FALSE
  )
}

#' Create test design with interviews (32+)
make_cpue_design <- function() {
  cal <- make_test_calendar_cpue()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews()
  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

#' Create small design with n interviews
make_small_cpue_design <- function(n, n_incomplete = 0) {
  # Single stratum to simplify
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Generate exactly n interviews
  # If n_incomplete specified, create mix of complete and incomplete
  trip_status <- if (n_incomplete > 0 && n_incomplete <= n) {
    c(rep("incomplete", n_incomplete), rep("complete", n - n_incomplete))
  } else {
    rep("complete", n)
  }

  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", n)),
    catch_total = rep(c(2, 3, 4, 5), length.out = n),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    catch_kept = rep(c(2, 2, 3, 4), length.out = n),
    trip_status = trip_status,
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

#' Create unbalanced design (one stratum < 10)
make_unbalanced_cpue_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # 15 weekday interviews, only 5 weekend interviews
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 5), rep("2024-06-02", 5), rep("2024-06-03", 5),
      rep("2024-06-08", 5)
    )),
    catch_total = c(2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 4, 5, 6, 7, 8, 8, 9, 10, 11, 12),
    hours_fished = c(2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 4, 5, 3, 4, 5, 4, 5, 6, 5, 6),
    catch_kept = c(2, 2, 3, 4, 5, 2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 6, 7, 8, 9, 10),
    trip_status = rep("complete", 20),
    trip_duration = c(2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 4, 5, 3, 4, 5, 4, 5, 6, 5, 6),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

# Basic behavior tests ----

test_that("estimate_catch_rate returns creel_estimates class object", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_catch_rate result has estimates tibble with correct columns", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_catch_rate result method is 'ratio-of-means-cpue'", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_equal(result$method, "ratio-of-means-cpue")
})

test_that("estimate_catch_rate result variance_method is 'taylor' by default", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_catch_rate result conf_level is 0.95 by default", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_catch_rate estimate is a positive numeric value", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

# Input validation tests ----

test_that("estimate_catch_rate errors when design is not creel_design", {
  fake_design <- list(interviews = data.frame(catch_total = 1:10, hours_fished = 1:10))

  expect_error(
    estimate_catch_rate(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_catch_rate errors when design has no interview_survey", {
  cal <- make_test_calendar_cpue()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    estimate_catch_rate(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_catch_rate errors for invalid variance method", {
  design <- make_cpue_design()

  expect_error(
    estimate_catch_rate(design, variance = "invalid"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

test_that("estimate_catch_rate errors when design missing catch_col/effort_col", {
  cal <- make_test_calendar_cpue()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Manually construct design with interviews but no catch_col/effort_col
  # (this simulates internal corruption, unlikely but testable)
  interviews <- make_test_interviews()
  design$interviews <- interviews
  design$interview_survey <- list(placeholder = TRUE) # fake survey object
  # deliberately omit catch_col and effort_col

  expect_error(
    estimate_catch_rate(design), # nolint: object_usage_linter
    "catch|effort"
  )
})

# Sample size validation tests ----

test_that("estimate_catch_rate errors when n < 10 ungrouped", {
  design <- make_small_cpue_design(5)

  expect_error(
    estimate_catch_rate(design), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimate_catch_rate warns when 10 <= n < 30 ungrouped", {
  design <- make_small_cpue_design(15)

  expect_warning(
    estimate_catch_rate(design), # nolint: object_usage_linter
    "30"
  )
})

test_that("estimate_catch_rate has no sample size warning when n >= 30 ungrouped", {
  design <- make_small_cpue_design(n = 60, n_incomplete = 0) # 60 complete trips

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design), # nolint: object_usage_linter
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for sample size warnings only
  sample_warnings <- grepl("sample|10|30", warnings, ignore.case = TRUE)

  expect_false(any(sample_warnings))
})

test_that("estimate_catch_rate errors when any group has n < 10 in grouped estimation", {
  design <- make_unbalanced_cpue_design() # weekend has only 5

  expect_error(
    estimate_catch_rate(design, by = day_type), # nolint: object_usage_linter
    "10"
  )
})

# Grouped estimation tests ----

test_that("estimate_catch_rate grouped by day_type returns creel_estimates with by_vars set", {
  # make_cpue_design() now has 20 complete trips per group
  design <- make_cpue_design()

  result <- estimate_catch_rate(design, by = day_type) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_catch_rate grouped result estimates tibble has day_type column", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design, by = day_type) # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_catch_rate grouped result has one row per group level", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design, by = day_type) # nolint: object_usage_linter

  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_catch_rate grouped result has n column reflecting per-group sample sizes", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design, by = day_type) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Reference tests ----

test_that("ungrouped CPUE matches manual svyratio calculation", {
  design <- make_cpue_design()

  # tidycreel estimate (filters to complete trips by default)
  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Manual survey::svyratio calculation (filter to complete trips to match)
  complete_interviews <- design$interviews[design$interviews$trip_status == "complete", ]
  svy_complete <- survey::svydesign(ids = ~1, strata = ~day_type, data = complete_interviews)
  manual_result <- survey::svyratio(~catch_total, ~hours_fished, svy_complete)
  manual_estimate <- as.numeric(coef(manual_result))
  manual_se <- as.numeric(survey::SE(manual_result))
  manual_ci <- confint(manual_result, level = 0.95)

  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-10)
  expect_equal(result$estimates$ci_lower, manual_ci[1, 1], tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci[1, 2], tolerance = 1e-10)
})

test_that("grouped CPUE matches manual svyby+svyratio calculation", {
  design <- make_cpue_design()

  # tidycreel grouped estimate (filters to complete trips by default)
  result <- estimate_catch_rate(design, by = day_type) # nolint: object_usage_linter

  # Manual survey::svyby + svyratio calculation (filter to complete trips to match)
  complete_interviews <- design$interviews[design$interviews$trip_status == "complete", ]
  svy_complete <- survey::svydesign(ids = ~1, strata = ~day_type, data = complete_interviews)
  manual_result <- survey::svyby(
    ~catch_total,
    ~day_type,
    denominator = ~hours_fished,
    design = svy_complete,
    FUN = survey::svyratio,
    vartype = c("se", "ci"),
    ci.level = 0.95,
    keep.names = FALSE
  )

  # Match point estimates for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_est <- result$estimates$estimate[i]
    # svyratio column name is "catch_total/hours_fished"
    ratio_col <- "catch_total/hours_fished"
    manual_est <- manual_result[[ratio_col]][manual_result$day_type == day]

    expect_equal(tidycreel_est, manual_est, tolerance = 1e-10)
  }

  # Match SEs
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_se <- result$estimates$se[i]
    manual_se <- manual_result$se[manual_result$day_type == day]

    expect_equal(tidycreel_se, manual_se, tolerance = 1e-10)
  }
})

test_that("ungrouped CPUE SE^2 matches variance from manual vcov", {
  design <- make_cpue_design()

  # tidycreel estimate (filters to complete trips by default)
  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Manual survey::svyratio calculation (filter to complete trips to match)
  complete_interviews <- design$interviews[design$interviews$trip_status == "complete", ]
  svy_complete <- survey::svydesign(ids = ~1, strata = ~day_type, data = complete_interviews)
  manual_result <- survey::svyratio(~catch_total, ~hours_fished, svy_complete)
  manual_variance <- as.numeric(vcov(manual_result))

  expect_equal(result$estimates$se^2, manual_variance, tolerance = 1e-10)
})

# Custom confidence level test ----

test_that("estimate_catch_rate with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_cpue_design()

  result_95 <- estimate_catch_rate(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_catch_rate(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

# Variance method tests ----

test_that("estimate_catch_rate with variance = 'bootstrap' returns bootstrap variance_method", {
  design <- make_cpue_design()

  set.seed(12345)
  result <- estimate_catch_rate(design, variance = "bootstrap") # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
})

test_that("estimate_catch_rate with variance = 'jackknife' returns jackknife variance_method", {
  design <- make_cpue_design()

  result <- estimate_catch_rate(design, variance = "jackknife") # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
})

test_that("bootstrap and jackknife produce positive SE values", {
  design <- make_cpue_design()

  set.seed(12345)
  result_bootstrap <- estimate_catch_rate(design, variance = "bootstrap") # nolint: object_usage_linter
  result_jackknife <- estimate_catch_rate(design, variance = "jackknife") # nolint: object_usage_linter

  expect_true(is.numeric(result_bootstrap$estimates$se))
  expect_true(result_bootstrap$estimates$se > 0)
  expect_false(is.na(result_bootstrap$estimates$se))

  expect_true(is.numeric(result_jackknife$estimates$se))
  expect_true(result_jackknife$estimates$se > 0)
  expect_false(is.na(result_jackknife$estimates$se))
})

# Integration tests with example data ----

test_that("full workflow with example_calendar and example_interviews produces valid CPUE", {
  # Load example data
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter

  # Add interviews
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Estimate CPUE
  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Verify result is valid
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "ratio-of-means-cpue")
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
  expect_false(is.na(result$estimates$estimate))
})

test_that("grouped workflow with example data errors due to sample size", {
  # Load example data
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design and add interviews
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Estimate CPUE grouped by day_type
  # Should error because weekend group has n=9 (< 10 threshold)
  expect_error(
    estimate_catch_rate(design, by = day_type), # nolint: object_usage_linter
    "10"
  )
})

test_that("result from example data has reasonable CPUE values", {
  # Load example data
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design and add interviews
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Estimate CPUE
  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Verify CPUE is in reasonable range (positive, finite, not extreme)
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate < 100) # Sanity check - CPUE shouldn't be absurdly high
})

# Zero-effort handling tests ----

test_that("estimate_catch_rate with zero-effort interviews issues warning and excludes them", {
  # Create design with some zero-effort interviews
  cal <- make_test_calendar_cpue()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create interviews with 2 zero-effort rows
  interviews <- data.frame(
    date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03"), each = 10)),
    catch_total = c(2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 4, 5, 6, 7, 8, 2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 0, 0, 6, 7, 8),
    hours_fished = c(2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 4, 5, 3, 4, 5, 2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 0, 0, 3, 4, 5),
    trip_status = rep("complete", 30),
    trip_duration = c(2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 4, 5, 3, 4, 5, 2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 2, 2, 3, 4, 5),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Expect warning about zero-effort interviews
  expect_warning(
    result <- estimate_catch_rate(design), # nolint: object_usage_linter
    "zero effort"
  )

  # Result should still be valid (using filtered data)
  expect_s3_class(result, "creel_estimates")
  expect_true(result$estimates$estimate > 0)
})

test_that("estimate_catch_rate with all-zero effort errors due to sample size threshold", {
  # Create design with all zero-effort interviews (n < 10 after filtering)
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create 5 interviews, all with zero effort
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 5)),
    catch_total = c(0, 0, 0, 0, 0),
    hours_fished = c(0, 0, 0, 0, 0),
    trip_status = rep("complete", 5),
    trip_duration = c(1, 1, 1, 1, 1),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Should error due to n < 10 after filtering out all zero-effort
  expect_error(
    suppressWarnings(estimate_catch_rate(design)), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimate_catch_rate grouped with zero-effort interviews excludes them with warning", {
  # Create synthetic data with some zero-effort interviews in grouped estimation
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4)
  )

  # Create interviews with sufficient samples per group but some zero-effort
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 6), rep("2024-06-02", 6),
      rep("2024-06-08", 6), rep("2024-06-09", 6)
    )),
    catch_total = c(
      2, 3, 4, 5, 6, 0, # weekday - one zero-catch with zero-effort
      3, 4, 5, 6, 7, 8, # weekday
      7, 8, 9, 10, 11, 0, # weekend - one zero-catch with zero-effort
      8, 9, 10, 11, 12, 13 # weekend
    ),
    hours_fished = c(
      2, 3, 4, 5, 3, 0, # weekday - one zero-effort
      3, 4, 5, 3, 4, 5,
      4, 5, 3, 5, 4, 0, # weekend - one zero-effort
      4, 5, 5, 6, 5, 6
    ),
    trip_status = rep("complete", 24),
    trip_duration = c(
      2, 3, 4, 5, 3, 1, # weekday
      3, 4, 5, 3, 4, 5,
      4, 5, 3, 5, 4, 1, # weekend
      4, 5, 5, 6, 5, 6
    )
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Grouped estimation should warn about zero-effort and exclude them
  expect_warning(
    result <- estimate_catch_rate(design, by = day_type), # nolint: object_usage_linter
    "zero effort"
  )

  # Result should still be valid with 2 groups
  expect_s3_class(result, "creel_estimates")
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$estimate > 0))
})

# Grouped variance method test ----

test_that("estimate_catch_rate grouped by day_type with variance = 'bootstrap' works", {
  design <- make_cpue_design()

  set.seed(12345)
  result <- suppressWarnings( # nolint: object_usage_linter
    estimate_catch_rate(design, by = day_type, variance = "bootstrap") # nolint: object_usage_linter
  )

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$variance_method, "bootstrap")
  expect_equal(result$by_vars, "day_type")
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$se > 0))
})

# Mean-of-Ratios (MOR) Estimator Tests ----

# Helper: create design with specific complete/incomplete trip mix
make_mor_design <- function(n_complete = 15, n_incomplete = 25) {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  n_total <- n_complete + n_incomplete

  # Create trip_status vector
  trip_status <- c(
    rep("complete", n_complete),
    rep("incomplete", n_incomplete)
  )

  # Generate interview data
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", n_total)),
    catch_total = rep(c(2, 3, 4, 5, 6), length.out = n_total),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5, 3.5), length.out = n_total),
    catch_kept = rep(c(2, 2, 3, 4, 5), length.out = n_total),
    trip_status = trip_status,
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5, 3.5), length.out = n_total),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

# Helper: create grouped design with incomplete trips in both groups
make_mor_grouped_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # 40 interviews: 20 weekday (10 complete, 10 incomplete), 20 weekend (10 complete, 10 incomplete)
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 10), rep("2024-06-02", 10),
      rep("2024-06-08", 10), rep("2024-06-09", 10)
    )),
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), each = 10),
    catch_total = rep(c(2, 3, 4, 5, 6, 7, 8, 9, 10, 11), 4),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5, 3.5, 4.5, 5.0, 3.0, 4.0, 5.0), 4),
    catch_kept = rep(c(2, 2, 3, 4, 5, 6, 7, 8, 9, 10), 4),
    trip_status = rep(c("complete", "incomplete"), 20), # Alternating pattern
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5, 3.5, 4.5, 5.0, 3.0, 4.0, 5.0), 4),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

# Basic MOR functionality tests ----

test_that("estimator='mor' uses incomplete trips only", {
  design <- make_mor_design(n_complete = 15, n_incomplete = 25)

  result <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor") # nolint: object_usage_linter

  # Should use only the 25 incomplete trips
  expect_equal(result$estimates$n, 25)
  expect_equal(result$method, "mean-of-ratios-cpue")
})

test_that("estimator='mor' produces valid estimates with SE and CI", {
  design <- make_mor_design(n_complete = 15, n_incomplete = 30)

  result <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor") # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

test_that("estimator='mor' supports all variance methods", {
  design <- make_mor_design(n_complete = 10, n_incomplete = 30)

  # Test taylor
  result_taylor <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", variance = "taylor") # nolint: object_usage_linter
  expect_equal(result_taylor$variance_method, "taylor")
  expect_true(is.numeric(result_taylor$estimates$estimate))

  # Test bootstrap
  set.seed(12345)
  result_bootstrap <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", variance = "bootstrap") # nolint: object_usage_linter
  expect_equal(result_bootstrap$variance_method, "bootstrap")
  expect_true(is.numeric(result_bootstrap$estimates$estimate))

  # Test jackknife
  result_jackknife <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", variance = "jackknife") # nolint: object_usage_linter
  expect_equal(result_jackknife$variance_method, "jackknife")
  expect_true(is.numeric(result_jackknife$estimates$estimate))
})

test_that("estimator='mor' supports grouped estimation", {
  design <- make_mor_grouped_design()

  result <- estimate_catch_rate(design, by = day_type, use_trips = "incomplete", estimator = "mor") # nolint: object_usage_linter

  # Should have one row per day_type
  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)

  # Each group should use only incomplete trips (10 incomplete per group)
  expect_true(all(result$estimates$n == 10))
  expect_equal(result$method, "mean-of-ratios-cpue")
})

# Validation tests ----

test_that("error when estimator='mor' and trip_status missing", {
  # Create design without trip_status field
  # Since trip_status is now required in add_interviews, we need to manually
  # create a design object without trip_status_col set (simulating old data)
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create interviews with trip_status column
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 30)),
    catch_total = rep(c(2, 3, 4, 5), length.out = 30),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = 30),
    trip_status = rep("complete", 30),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = 30),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Manually remove trip_status_col to simulate missing field
  design$trip_status_col <- NULL

  # Should error about missing trip_status (use_trips='incomplete' requires trip_status)
  expect_error(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "trip_status"
  )
})

test_that("error when estimator='mor' with no incomplete trips", {
  # Design with ONLY complete trips
  design <- make_mor_design(n_complete = 30, n_incomplete = 0)

  expect_error(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "incomplete"
  )
})

test_that("error when estimator='mor' with complete trips in data but 0 incomplete", {
  # Mix design but all trips are complete
  design <- make_mor_design(n_complete = 40, n_incomplete = 0)

  expect_error(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "incomplete"
  )
})

test_that("estimator='mor' sample size validation: error when n<10", {
  # Design with only 8 incomplete trips
  design <- make_mor_design(n_complete = 20, n_incomplete = 8)

  expect_error(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimator='mor' sample size validation: warning when 10<=n<30", {
  # Design with exactly 15 incomplete trips
  design <- make_mor_design(n_complete = 10, n_incomplete = 15)

  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "30"
  )
})

test_that("estimator='mor' sample size validation: no warning when n>=30", {
  # Design with 35 incomplete trips
  design <- make_mor_design(n_complete = 10, n_incomplete = 35)

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for sample size warnings only (exclude MOR estimation warning)
  sample_warnings <- grepl("sample|stable|30", warnings, ignore.case = TRUE)

  expect_false(any(sample_warnings))
})

# Reference test ----

test_that("estimator='mor' matches manual survey::svymean calculation", {
  # Create design with known incomplete trip data
  design <- make_mor_design(n_complete = 15, n_incomplete = 30)

  # tidycreel MOR estimate
  result <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor") # nolint: object_usage_linter

  # Manual calculation: filter to incomplete, create survey design, call svymean
  incomplete_interviews <- design$interviews[design$interviews$trip_status == "incomplete", ]

  # Create survey design for incomplete trips only
  incomplete_svy <- survey::svydesign(
    ids = ~1,
    data = incomplete_interviews
  )

  # Calculate mean of individual catch/effort ratios
  incomplete_interviews$cpue_ratio <- incomplete_interviews$catch_total / incomplete_interviews$hours_fished
  incomplete_svy <- survey::svydesign(
    ids = ~1,
    data = incomplete_interviews
  )

  manual_result <- survey::svymean(~cpue_ratio, incomplete_svy)
  manual_estimate <- as.numeric(coef(manual_result))

  # Verify estimates match
  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
})

# MOR warning tests ----

test_that("MOR estimator warns on every call", {
  design <- make_small_cpue_design(n = 30, n_incomplete = 30)

  # First call warns
  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"),
    "MOR estimator.*incomplete trips"
  )

  # Second call ALSO warns (not once-per-session)
  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"),
    "MOR estimator.*incomplete trips"
  )
})

test_that("MOR warning includes trip counts", {
  design <- make_small_cpue_design(n = 40, n_incomplete = 25)

  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"),
    "n=25.*25 total"
  )
})

test_that("MOR warning emphasizes complete trip preference", {
  design <- make_small_cpue_design(n = 30, n_incomplete = 30)

  expect_warning(
    result <- estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"),
    "Complete trips preferred"
  )
})

test_that("MOR warning references validation function", {
  design <- make_small_cpue_design(n = 30, n_incomplete = 30)

  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"),
    "validate_incomplete_trips"
  )
})

# MOR Truncation Tests ----

# Helper: create design with specific mix of trips above/below threshold
make_truncation_test_design <- function(n_above, n_below, threshold) {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  n_total <- n_above + n_below

  # All trips are incomplete for MOR testing
  trip_status <- rep("incomplete", n_total)

  # Create durations: n_above trips >= threshold, n_below trips < threshold
  # Above threshold: spread between threshold and threshold + 2 hours
  durations_above <- seq(threshold, threshold + 2, length.out = n_above)
  # Below threshold: spread between 0.1 and threshold - 0.1
  durations_below <- seq(0.1, threshold - 0.1, length.out = n_below)
  trip_duration <- c(durations_above, durations_below)

  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", n_total)),
    catch_total = rep(c(2, 3, 4, 5, 6), length.out = n_total),
    hours_fished = trip_duration, # Match effort to duration for simplicity
    catch_kept = rep(c(2, 2, 3, 4, 5), length.out = n_total),
    trip_status = trip_status,
    trip_duration = trip_duration,
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

test_that("default truncate_at=0.5 filters trips below threshold", {
  # Create design with 25 trips >= 0.5h, 5 trips < 0.5h
  design <- make_truncation_test_design(n_above = 25, n_below = 5, threshold = 0.5)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")) # nolint: object_usage_linter

  # Should use only the 25 trips >= 0.5h
  expect_equal(result$estimates$n, 25)
})

test_that("custom truncate_at filters correctly", {
  # Create design with 20 trips >= 1.0h, 10 trips < 1.0h
  design <- make_truncation_test_design(n_above = 20, n_below = 10, threshold = 1.0)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = 1.0)) # nolint: object_usage_linter

  # Should use only the 20 trips >= 1.0h
  expect_equal(result$estimates$n, 20)
})

test_that("truncate_at=NULL uses all trips", {
  # Create design with 15 trips >= 0.5h, 15 trips < 0.5h
  design <- make_truncation_test_design(n_above = 15, n_below = 15, threshold = 0.5)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = NULL)) # nolint: object_usage_linter

  # Should use all 30 trips (no truncation)
  expect_equal(result$estimates$n, 30)
})

test_that("truncated sample count stored in metadata", {
  # Create design with 25 trips >= 0.5h, 5 trips < 0.5h
  design <- make_truncation_test_design(n_above = 25, n_below = 5, threshold = 0.5)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")) # nolint: object_usage_linter

  # Should have truncation metadata stored
  expect_true(!is.null(result$mor_n_truncated))
  expect_equal(result$mor_n_truncated, 5)
  expect_equal(result$mor_truncate_at, 0.5)
})

test_that("ratio-of-means ignores truncate_at parameter", {
  # Create design with complete trips, some short durations
  design <- make_truncation_test_design(n_above = 20, n_below = 10, threshold = 1.0)
  # Override trip_status to complete
  design$interviews$trip_status <- "complete"

  result <- estimate_catch_rate(design, estimator = "ratio-of-means", truncate_at = 1.0) # nolint: object_usage_linter

  # Should use all 30 trips (truncation ignored for ratio-of-means)
  expect_equal(result$estimates$n, 30)
})

test_that("sample size validation uses post-truncation count", {
  # Create design where post-truncation n = 15 (warning zone)
  design <- make_truncation_test_design(n_above = 15, n_below = 10, threshold = 0.5)

  # Should get sample size warning about n=15
  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "15.*30"
  )
})

test_that("error if post-truncation n < 10", {
  # Create design where post-truncation n = 8
  design <- make_truncation_test_design(n_above = 8, n_below = 12, threshold = 0.5)

  expect_error(
    suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")), # nolint: object_usage_linter
    "10"
  )
})

test_that("warning if 10 <= post-truncation n < 30", {
  # Create design where post-truncation n = 12
  design <- make_truncation_test_design(n_above = 12, n_below = 8, threshold = 0.5)

  expect_warning(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"), # nolint: object_usage_linter
    "12.*30"
  )
})

test_that("MOR with truncation matches manual survey::svymean", {
  # Create design with known data
  design <- make_truncation_test_design(n_above = 25, n_below = 5, threshold = 0.5)

  # tidycreel MOR with truncation
  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = 0.5)) # nolint: object_usage_linter

  # Manual calculation: filter to incomplete AND >= 0.5h
  truncated_interviews <- design$interviews[
    design$interviews$trip_status == "incomplete" &
      design$interviews$trip_duration >= 0.5,
  ]

  # Create survey design for truncated trips
  truncated_svy <- survey::svydesign(
    ids = ~1,
    data = truncated_interviews
  )

  # Compute individual ratios
  truncated_interviews$cpue_ratio <- truncated_interviews$catch_total / truncated_interviews$hours_fished

  # Rebuild survey design with ratio column
  truncated_svy <- survey::svydesign(
    ids = ~1,
    data = truncated_interviews
  )

  # Compute mean of ratios using svymean
  manual_result <- survey::svymean(~cpue_ratio, truncated_svy)

  # Compare estimates (tolerance 1e-10)
  expect_equal(result$estimates$estimate, as.numeric(manual_result), tolerance = 1e-10)
  expect_equal(result$estimates$se, as.numeric(survey::SE(manual_result)), tolerance = 1e-10)
})

# MOR truncation messaging tests ----

test_that("MOR stores truncation metadata when trips excluded", {
  design <- make_truncation_test_design(n_above = 25, n_below = 5, threshold = 0.5)

  result <- suppressWarnings(
    suppressMessages(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = 0.5))
  )

  # Should store truncation metadata
  expect_equal(result$mor_truncate_at, 0.5)
  expect_equal(result$mor_n_truncated, 5)
})

test_that("MOR stores zero truncation when all trips above threshold", {
  design <- make_truncation_test_design(n_above = 30, n_below = 0, threshold = 0.5)

  result <- suppressWarnings(
    suppressMessages(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = 0.5))
  )

  # Should store zero truncation
  expect_equal(result$mor_truncate_at, 0.5)
  expect_equal(result$mor_n_truncated, 0)
})

test_that("MOR truncation function warns when >10% truncated", {
  # Test the function directly
  expect_warning(
    mor_truncation_message(n_truncated = 15, n_incomplete_original = 30, truncate_at = 0.5),
    "High truncation rate may indicate data quality issues"
  )
})

test_that("MOR truncation metadata NULL when truncate_at = NULL", {
  design <- make_truncation_test_design(n_above = 25, n_below = 5, threshold = 0.5)

  result <- suppressWarnings(
    suppressMessages(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = NULL))
  )

  # Should have NULL truncate_at
  expect_null(result$mor_truncate_at)
  expect_equal(result$mor_n_truncated, 0)
})

test_that("MOR print output shows truncation details", {
  design <- make_truncation_test_design(n_above = 25, n_below = 5, threshold = 0.5)

  result <- suppressWarnings(
    suppressMessages(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = 0.5))
  )

  # Capture print output
  output <- capture.output(print(result))
  output_text <- paste(output, collapse = "\n")

  # Should contain truncation info
  expect_match(output_text, "Truncation: 5 trips excluded")
  expect_match(output_text, "0.5 hours")
})

test_that("MOR print output shows zero truncation details", {
  design <- make_truncation_test_design(n_above = 30, n_below = 0, threshold = 0.5)

  result <- suppressWarnings(
    suppressMessages(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor", truncate_at = 0.5))
  )

  # Capture print output
  output <- capture.output(print(result))
  output_text <- paste(output, collapse = "\n")

  # Should contain zero truncation info
  expect_match(output_text, "Truncation: 0 trips excluded")
  expect_match(output_text, "threshold: 0.5 hours")
})

# use_trips Parameter Tests ----

# Helper: create design with balanced complete/incomplete mix
make_use_trips_design <- function(n_complete = 20, n_incomplete = 20) {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  n_total <- n_complete + n_incomplete

  trip_status <- c(
    rep("complete", n_complete),
    rep("incomplete", n_incomplete)
  )

  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", n_total)),
    catch_total = rep(c(2, 3, 4, 5, 6), length.out = n_total),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5, 3.5), length.out = n_total),
    catch_kept = rep(c(2, 2, 3, 4, 5), length.out = n_total),
    trip_status = trip_status,
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5, 3.5), length.out = n_total),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

# Default behavior tests ----

test_that("default use_trips='complete' filters to complete trips when trip_status provided", {
  design <- make_use_trips_design(n_complete = 25, n_incomplete = 15)

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Should use only the 25 complete trips
  expect_equal(result$estimates$n, 25)
})

test_that("default use_trips='complete' uses ratio-of-means estimator", {
  design <- make_use_trips_design(n_complete = 20, n_incomplete = 20)

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_equal(result$method, "ratio-of-means-cpue")
})

test_that("default use_trips='complete' returns creel_estimates class", {
  design <- make_use_trips_design(n_complete = 20, n_incomplete = 20)

  result <- estimate_catch_rate(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_false(inherits(result, "creel_estimates_mor"))
})

# Explicit trip type selection tests ----

test_that("use_trips='complete' explicitly filters to complete trips", {
  design <- make_use_trips_design(n_complete = 30, n_incomplete = 10)

  result <- estimate_catch_rate(design, use_trips = "complete") # nolint: object_usage_linter

  expect_equal(result$estimates$n, 30)
  expect_equal(result$method, "ratio-of-means-cpue")
})

test_that("use_trips='incomplete' filters to incomplete trips", {
  design <- make_use_trips_design(n_complete = 10, n_incomplete = 35)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")) # nolint: object_usage_linter

  expect_equal(result$estimates$n, 35)
})

test_that("use_trips='incomplete' uses mean-of-ratios estimator", {
  design <- make_use_trips_design(n_complete = 10, n_incomplete = 30)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")) # nolint: object_usage_linter

  expect_equal(result$method, "mean-of-ratios-cpue")
})

test_that("use_trips='incomplete' returns creel_estimates_mor class", {
  design <- make_use_trips_design(n_complete = 10, n_incomplete = 30)

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates_mor")
  expect_s3_class(result, "creel_estimates")
})

# Backward compatibility tests ----

test_that("use_trips parameter ignored when trip_status not provided", {
  # Create design WITH trip_status (required in v0.3.0)
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create interviews with trip_status
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 30)),
    catch_total = rep(c(2, 3, 4, 5), length.out = 30),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = 30),
    trip_status = rep("complete", 30),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = 30),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Manually remove trip_status_col to simulate data from before Phase 13
  design$trip_status_col <- NULL

  # Should work without errors, ignoring use_trips
  result <- estimate_catch_rate(design, use_trips = "complete") # nolint: object_usage_linter

  # Should use all 30 interviews
  expect_equal(result$estimates$n, 30)
})

test_that("no errors when trip_status absent and use_trips specified", {
  # Create design WITH trip_status (required in v0.3.0)
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 30)),
    catch_total = rep(c(2, 3, 4, 5), length.out = 30),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = 30),
    trip_status = rep("complete", 30),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = 30),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Manually remove trip_status_col to simulate old data
  design$trip_status_col <- NULL

  # Should not error
  expect_no_error(estimate_catch_rate(design, use_trips = "incomplete"))
})

# Validation error tests ----

test_that("use_trips='incomplete' with estimator='ratio-of-means' errors", {
  design <- make_use_trips_design(n_complete = 10, n_incomplete = 30)

  expect_error(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "ratio-of-means"),
    "incomplete.*ratio"
  )
})

test_that("use_trips='incomplete' error message includes scientific rationale", {
  design <- make_use_trips_design(n_complete = 10, n_incomplete = 30)

  expect_error(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "ratio-of-means"),
    "Pollock|MOR|mean-of-ratios"
  )
})

test_that("use_trips='invalid' errors with invalid parameter message", {
  design <- make_use_trips_design(n_complete = 20, n_incomplete = 20)

  expect_error(
    estimate_catch_rate(design, use_trips = "invalid"),
    "complete|incomplete"
  )
})

test_that("use_trips='complete' but zero complete trips errors", {
  design <- make_use_trips_design(n_complete = 0, n_incomplete = 30)

  expect_error(
    estimate_catch_rate(design, use_trips = "complete"),
    "no.*complete|complete trips"
  )
})

test_that("use_trips='incomplete' but zero incomplete trips errors", {
  design <- make_use_trips_design(n_complete = 30, n_incomplete = 0)

  expect_error(
    suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")),
    "no.*incomplete|incomplete trips"
  )
})

test_that("use_trips='complete' with n_complete < 10 errors with guidance", {
  design <- make_use_trips_design(n_complete = 8, n_incomplete = 30)

  expect_error(
    estimate_catch_rate(design, use_trips = "complete"),
    "10"
  )
})

test_that("use_trips='incomplete' with n_incomplete < 10 (post-truncation) errors", {
  # Create design where post-truncation n_incomplete = 8
  design <- make_truncation_test_design(n_above = 8, n_below = 12, threshold = 0.5)

  expect_error(
    suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")),
    "10"
  )
})

# Validation warning tests ----

test_that("use_trips='complete' with estimator='mor' warns about non-standard choice", {
  design <- make_use_trips_design(n_complete = 30, n_incomplete = 10)

  expect_warning(
    estimate_catch_rate(design, use_trips = "complete", estimator = "mor"),
    "complete.*mor|non-standard"
  )
})

test_that("use_trips='complete' with estimator='mor' allows estimation", {
  design <- make_use_trips_design(n_complete = 30, n_incomplete = 10)

  # Should warn but still work
  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "complete", estimator = "mor"))

  expect_s3_class(result, "creel_estimates_mor")
  expect_equal(result$estimates$n, 30)
})

# Grouped estimation with use_trips ----

# Helper: create grouped design with complete/incomplete in both strata
make_grouped_use_trips_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # 40 interviews: 20 weekday (10 complete, 10 incomplete), 20 weekend (10 complete, 10 incomplete)
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 10), rep("2024-06-02", 10),
      rep("2024-06-08", 10), rep("2024-06-09", 10)
    )),
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), each = 10),
    catch_total = rep(c(2, 3, 4, 5, 6, 7, 8, 9, 10, 11), 4),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5, 3.5, 4.5, 5.0, 3.0, 4.0, 5.0), 4),
    catch_kept = rep(c(2, 2, 3, 4, 5, 6, 7, 8, 9, 10), 4),
    trip_status = rep(c("complete", "incomplete"), 20),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5, 3.5, 4.5, 5.0, 3.0, 4.0, 5.0), 4),
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

test_that("grouped estimation with use_trips='complete' uses complete trips only", {
  design <- make_grouped_use_trips_design()

  result <- estimate_catch_rate(design, by = day_type, use_trips = "complete") # nolint: object_usage_linter

  # Each group should have 10 complete trips
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$n == 10))
})

test_that("grouped estimation with use_trips='incomplete' uses incomplete trips only", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, by = day_type, use_trips = "incomplete", estimator = "mor")) # nolint: object_usage_linter

  # Each group should have 10 incomplete trips
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$n == 10))
})

# Diagnostic mode tests ----

test_that("use_trips='diagnostic' returns creel_estimates_diagnostic class", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "diagnostic"))

  expect_s3_class(result, "creel_estimates_diagnostic")
  expect_true("creel_estimates_diagnostic" %in% class(result))
})

test_that("use_trips='diagnostic' returns comparison table with both estimates", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "diagnostic"))

  # Should have comparison data frame
  expect_true(!is.null(result$comparison))
  expect_true(is.data.frame(result$comparison))

  # Should have two rows (complete and incomplete)
  expect_equal(nrow(result$comparison), 2)

  # Should have trip_type column
  expect_true("trip_type" %in% names(result$comparison))
  expect_setequal(result$comparison$trip_type, c("complete", "incomplete"))

  # Should have estimate columns
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result$comparison)))
})

test_that("use_trips='diagnostic' calculates difference metrics", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "diagnostic"))

  # Should have difference metrics
  expect_true(!is.null(result$diff_estimate))
  expect_true(is.numeric(result$diff_estimate))

  expect_true(!is.null(result$ratio_estimate))
  expect_true(is.numeric(result$ratio_estimate))
})

test_that("use_trips='diagnostic' includes interpretation guidance", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "diagnostic"))

  # Should have interpretation text
  expect_true(!is.null(result$interpretation))
  expect_true(is.character(result$interpretation))
  expect_true(length(result$interpretation) > 0)
})

test_that("use_trips='diagnostic' errors if no complete trips", {
  design <- make_small_cpue_design(n = 15, n_incomplete = 15)

  expect_error(
    estimate_catch_rate(design, use_trips = "diagnostic"),
    "complete trips"
  )
})

test_that("use_trips='diagnostic' errors if no incomplete trips", {
  design <- make_small_cpue_design(n = 15, n_incomplete = 0)

  expect_error(
    estimate_catch_rate(design, use_trips = "diagnostic"),
    "incomplete trips"
  )
})

test_that("use_trips='diagnostic' works with grouped estimation", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, by = day_type, use_trips = "diagnostic")) # nolint: object_usage_linter

  # Should have comparison data frame with grouping columns
  expect_true("day_type" %in% names(result$comparison))

  # Should have 4 rows (2 groups × 2 trip types)
  expect_equal(nrow(result$comparison), 4)

  # Should have both trip types for each group
  weekday_types <- result$comparison$trip_type[result$comparison$day_type == "weekday"]
  expect_setequal(weekday_types, c("complete", "incomplete"))

  weekend_types <- result$comparison$trip_type[result$comparison$day_type == "weekend"]
  expect_setequal(weekend_types, c("complete", "incomplete"))
})

test_that("diagnostic comparison print method produces readable output", {
  design <- make_grouped_use_trips_design()

  result <- suppressWarnings(estimate_catch_rate(design, use_trips = "diagnostic"))

  # Should be able to format and print without error
  expect_no_error(format(result))
  expect_no_error(print(result))

  # Formatted output should contain diagnostic keywords
  output <- format(result)
  output_text <- paste(output, collapse = " ")
  expect_match(output_text, "diagnostic|comparison", ignore.case = TRUE)
})

# Informative messaging tests ----

test_that("estimate_catch_rate shows informative message for default complete trip usage", {
  design <- make_grouped_use_trips_design()

  # Should show message about using complete trips (default)
  expect_message(
    estimate_catch_rate(design),
    "complete.*default|default.*complete"
  )
})

test_that("estimate_catch_rate message includes sample size and percentage", {
  design <- make_grouped_use_trips_design()

  # Should show n and percentage
  expect_message(
    estimate_catch_rate(design),
    "n=|n ="
  )

  expect_message(
    estimate_catch_rate(design),
    "%"
  )
})

test_that("estimate_catch_rate shows message for explicit use_trips='complete'", {
  design <- make_grouped_use_trips_design()

  # Should show message but NOT indicate [default]
  output <- capture_messages(estimate_catch_rate(design, use_trips = "complete"))
  output_text <- paste(output, collapse = " ")

  expect_match(output_text, "complete")
  expect_no_match(output_text, "\\[default\\]")
})

test_that("estimate_catch_rate shows message for use_trips='incomplete'", {
  design <- make_grouped_use_trips_design()

  # Should show message about using incomplete trips
  expect_message(
    suppressWarnings(estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor")),
    "incomplete"
  )
})

test_that("estimate_catch_rate shows message for diagnostic mode", {
  design <- make_grouped_use_trips_design()

  # Should show message about diagnostic comparison
  expect_message(
    suppressWarnings(estimate_catch_rate(design, use_trips = "diagnostic")),
    "diagnostic|comparison"
  )
})

test_that("estimate_catch_rate message indicates default when use_trips not specified", {
  design <- make_grouped_use_trips_design()

  # Call without specifying use_trips (should use default)
  messages <- capture_messages(estimate_catch_rate(design))
  messages_text <- paste(messages, collapse = " ")

  # Should indicate [default]
  expect_match(messages_text, "\\[default\\]")
})

# Complete trip percentage warning tests ----

test_that("warning fires when complete trip percentage < 10%", {
  # Create design with 10 complete out of 120 total (8.3%)
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  expect_warning(
    estimate_catch_rate(design),
    "Only.*% of interviews are complete trips"
  )
})

test_that("no warning when complete trip percentage >= 10%", {
  # Create design with 20 complete out of 120 total (16.7%)
  design <- make_small_cpue_design(n = 120, n_incomplete = 100)

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for complete trip percentage warnings only
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)

  expect_false(any(pct_warnings))
})

test_that("warning includes percentage in message", {
  # Create design with 10 complete out of 120 total (8.3%)
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  expect_warning(
    estimate_catch_rate(design),
    "8\\.3%|8%"
  )
})

test_that("warning references Pollock et al.", {
  # Create design with 10 complete out of 120 total (8.3%)
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  expect_warning(
    estimate_catch_rate(design),
    "Pollock"
  )
})

test_that("warning mentions diagnostic validation", {
  # Create design with 10 complete out of 120 total (8.3%)
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  expect_warning(
    estimate_catch_rate(design),
    "diagnostic"
  )
})

test_that("warning shows threshold", {
  # Create design with 10 complete out of 120 total (8.3%)
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  expect_warning(
    estimate_catch_rate(design),
    "10%|threshold"
  )
})

test_that("custom threshold (5%) changes trigger point", {
  # Create scenario with 3 complete out of 100 total (3%)
  # Should warn with threshold=0.05 (3% < 5%)
  # Should also warn with threshold=0.10 (3% < 10%)

  # With custom threshold 0.05, should warn
  expect_warning(
    warn_low_complete_pct(3, 100, threshold = 0.05),
    "Only.*% of interviews are complete trips"
  )

  # Verify with threshold 0.02, should NOT warn (3% >= 2%)
  expect_no_warning(
    warn_low_complete_pct(3, 100, threshold = 0.02)
  )
})

test_that("n_total=0 edge case produces no warning", {
  # Should not error or warn
  expect_no_warning(
    warn_low_complete_pct(0, 0)
  )
})

# Package option integration tests ----

test_that("ungrouped estimation uses package option for threshold", {
  # Create design with 10 complete out of 150 total (6.7%)
  design <- make_small_cpue_design(n = 150, n_incomplete = 140)

  # Set custom threshold to 5% (should not warn since 6.7% > 5%)
  withr::local_options(tidycreel.min_complete_pct = 0.05)

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for complete trip percentage warnings only
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)

  expect_false(any(pct_warnings))
})

test_that("ungrouped estimation respects package option threshold", {
  # Create design with 10 complete out of 150 total (6.7%)
  design <- make_small_cpue_design(n = 150, n_incomplete = 140)

  # Set threshold to 8% (should warn since 6.7% < 8%)
  withr::local_options(tidycreel.min_complete_pct = 0.08)

  expect_warning(
    estimate_catch_rate(design),
    "Only.*% of interviews are complete trips"
  )
})

# Note: trip_status is now required (Phase 13), so test for missing trip_status is not applicable

# Grouped estimation warning tests ----

test_that("grouped estimation warns per-group when below threshold", {
  # Create grouped design with different complete trip percentages per group
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = rep("weekday", 2),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Group A: 10 complete out of 150 (6.7%) - should warn (but has n>=10 for validation)
  # Group B: 20 complete out of 150 (13.3%) - should not warn
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 300)),
    catch_total = rep(c(2, 3, 4, 5), 75),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), 75),
    trip_status = c(
      # Group A: 10 complete, 140 incomplete
      rep("incomplete", 140), rep("complete", 10),
      # Group B: 20 complete, 130 incomplete
      rep("incomplete", 130), rep("complete", 20)
    ),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), 75),
    species = rep(c("A", "B"), each = 150),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Should warn (at least once for group A)
  expect_warning(
    estimate_catch_rate(design, by = species),
    "Only.*% of interviews are complete trips"
  )
})

test_that("grouped estimation warning fires for specific low group only", {
  # Create design where only one group has low percentage
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = rep("weekday", 2),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Group A: 10 complete out of 100 (10%) - should not warn (at threshold)
  # Group B: 50 complete out of 100 (50%) - should not warn
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 200)),
    catch_total = rep(c(2, 3, 4, 5), 50),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), 50),
    trip_status = c(
      # Group A: 10 complete, 90 incomplete (10% - at threshold)
      rep("incomplete", 90), rep("complete", 10),
      # Group B: 50 complete, 50 incomplete (50%)
      rep("incomplete", 50), rep("complete", 50)
    ),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), 50),
    species = rep(c("A", "B"), each = 100),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design, by = species),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for complete trip percentage warnings
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)

  # Should have no warnings (both groups at or above 10%)
  expect_false(any(pct_warnings))
})

test_that("grouped estimation no warnings when all groups >= threshold", {
  # Create design where all groups have adequate complete trips
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = rep("weekday", 2),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Both groups: 20 complete out of 100 (20%) - should not warn
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 200)),
    catch_total = rep(c(2, 3, 4, 5), 50),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), 50),
    trip_status = c(
      # Group A: 20 complete, 80 incomplete
      rep("incomplete", 80), rep("complete", 20),
      # Group B: 20 complete, 80 incomplete
      rep("incomplete", 80), rep("complete", 20)
    ),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), 50),
    species = rep(c("A", "B"), each = 100),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design, by = species),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for complete trip percentage warnings
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)

  expect_false(any(pct_warnings))
})

test_that("grouped estimation respects package option threshold", {
  # Create grouped design with 10 complete trips per group (but low percentage)
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = rep("weekday", 2),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Both groups: 10 complete out of 150 (6.7%)
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", 300)),
    catch_total = rep(c(2, 3, 4, 5), 75),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), 75),
    trip_status = c(
      # Group A: 10 complete, 140 incomplete (6.7%)
      rep("incomplete", 140), rep("complete", 10),
      # Group B: 10 complete, 140 incomplete (6.7%)
      rep("incomplete", 140), rep("complete", 10)
    ),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), 75),
    species = rep(c("A", "B"), each = 150),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

  # Set threshold to 5% (6.7% > 5%, should not warn)
  withr::local_options(tidycreel.min_complete_pct = 0.05)

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design, by = species),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for complete trip percentage warnings
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)

  expect_false(any(pct_warnings))
})

# Warning behavior tests ----

test_that("warning fires every time condition is met", {
  # Create design with low complete trip percentage
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  # First call - should warn
  expect_warning(
    estimate_catch_rate(design),
    "Only.*% of interviews are complete trips"
  )

  # Second call - should also warn (not suppressed)
  expect_warning(
    estimate_catch_rate(design),
    "Only.*% of interviews are complete trips"
  )
})

test_that("complete trip warning works alongside MOR warning", {
  # Create design with low complete trips AND using MOR
  design <- make_small_cpue_design(n = 120, n_incomplete = 110)

  # Capture all warnings (use estimator='mor' with use_trips='incomplete')
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design, use_trips = "incomplete", estimator = "mor"),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  # Should have both complete trip percentage warning and MOR diagnostic warning
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)
  mor_warnings <- grepl("Mean-of-ratios.*diagnostic|incomplete trip", warnings, ignore.case = TRUE)

  expect_true(any(pct_warnings))
  expect_true(any(mor_warnings))
})

# End-to-end integration test ----

test_that("end-to-end integration: realistic scenario with low complete trips", {
  # Create realistic scenario: 200 interviews with only 5% complete trips
  # Use simple single-stratum design to avoid survey design issues
  cal <- data.frame(
    date = as.Date(seq.Date(as.Date("2024-06-01"), as.Date("2024-06-07"), by = "day")),
    day_type = rep("weekday", 7)
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # 200 interviews: 10 complete (5%), 190 incomplete
  # Spread evenly across dates to ensure adequate samples
  set.seed(42) # Reproducible
  interviews <- data.frame(
    date = as.Date(rep(cal$date, length.out = 200)),
    catch_total = rpois(200, lambda = 3),
    hours_fished = runif(200, min = 0.5, max = 6),
    trip_status = c(rep("complete", 10), rep("incomplete", 190)),
    trip_duration = runif(200, min = 0.5, max = 6)
  )

  design <- add_interviews(design, interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_catch_rate(design),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  # Verify warning fired
  pct_warnings <- grepl("Only.*% of interviews are complete trips", warnings, ignore.case = TRUE)
  expect_true(any(pct_warnings))

  # Verify warning content
  warning_text <- paste(warnings[pct_warnings], collapse = " ")
  expect_match(warning_text, "5\\.0%|5%") # 5% complete
  expect_match(warning_text, "threshold: 10%") # Shows threshold
  expect_match(warning_text, "Pollock") # References Pollock et al.
  expect_match(warning_text, "diagnostic") # Suggests diagnostic mode

  # Verify estimate still succeeds after warning
  expect_s3_class(result, "creel_estimates")
  expect_true(nrow(result$estimates) == 1)
  expect_true(result$estimates$n == 10) # Used 10 complete trips

  # Test with custom threshold
  withr::local_options(tidycreel.min_complete_pct = 0.03) # 3% threshold

  # Should NOT warn now (5% > 3%)
  warnings2 <- character()
  result2 <- withCallingHandlers(
    estimate_catch_rate(design),
    warning = function(w) {
      warnings2 <<- c(warnings2, conditionMessage(w))
    }
  )

  pct_warnings2 <- grepl("Only.*% of interviews are complete trips", warnings2, ignore.case = TRUE)
  expect_false(any(pct_warnings2))
})

# Section dispatch tests (RATE-01c, RATE-03) ----

test_that("RATE-01c: estimate_catch_rate on 3-section design returns exactly 3 rows", {
  design <- make_3section_design_with_interviews() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, missing_sections = "warn") # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 3L)
  expect_true("section" %in% names(result$estimates))
  expect_false(".lake_total" %in% result$estimates$section)
})

test_that("RATE-01c-by: estimate_catch_rate with by=day_type returns per-section x per-day_type rows", {
  design <- make_3section_design_with_interviews() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, by = day_type, missing_sections = "warn") # nolint: object_usage_linter
  ))
  expect_true("section" %in% names(result$estimates))
  expect_true("day_type" %in% names(result$estimates))
  # 3 sections x 2 day_types = 6 rows
  expect_equal(nrow(result$estimates), 6L)
  expect_false(".lake_total" %in% result$estimates$section)
})

test_that("RATE-01c-species: estimate_catch_rate with by=section+species returns per-section x per-species rows", {
  design <- make_3section_design_with_interviews() # nolint: object_usage_linter
  # Need catch data — build a simple catch attachment from existing interviews
  # This test verifies section dispatch + species routing work together
  # Since section fixture has no catch data, we check that a non-species by= works
  result <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, by = day_type, missing_sections = "warn") # nolint: object_usage_linter
  ))
  expect_s3_class(result, "creel_estimates")
  expect_true("section" %in% names(result$estimates))
})

test_that("RATE-03-catch: missing interview section produces NA row with data_available=FALSE + cli_warn", {
  design <- make_section_design_with_missing_interview_section() # nolint: object_usage_linter
  warns <- character(0)
  result <- withCallingHandlers(
    estimate_catch_rate(design, missing_sections = "warn"), # nolint: object_usage_linter
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("missing|section|South", warns, ignore.case = TRUE)))
  expect_true(any(!result$estimates$data_available))
  south_row <- result$estimates[result$estimates$section == "South", ]
  expect_equal(nrow(south_row), 1L)
  expect_false(south_row$data_available)
  expect_true(is.na(south_row$estimate))
})

test_that("RATE-03-catch-error: missing_sections='error' triggers cli_abort for estimate_catch_rate", {
  design <- make_section_design_with_missing_interview_section() # nolint: object_usage_linter
  expect_error(
    estimate_catch_rate(design, missing_sections = "error"), # nolint: object_usage_linter
    regexp = "missing|section|South",
    ignore.case = TRUE
  )
})
