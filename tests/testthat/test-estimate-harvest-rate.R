# Test helpers ----

#' Create 3-section creel_design with interview data (RATE section fixtures)
#'
#' Sections: "North", "Central", "South". All three sections have interview data.
#' Duplicated from test-estimate-catch-rate.R for self-contained test file.
make_3section_design_with_interviews <- function() {
  # nolint: object_length_linter
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-07",
      "2024-06-10",
      "2024-06-08",
      "2024-06-09",
      "2024-06-14",
      "2024-06-15",
      "2024-06-16",
      "2024-06-21"
    )),
    day_type = c(
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend",
      "weekend",
      "weekend",
      "weekend"
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
      20,
      22,
      18,
      25,
      15,
      24,
      21,
      26,
      23,
      28,
      20,
      27,
      35,
      38,
      32,
      42,
      30,
      45,
      37,
      44,
      40,
      48,
      35,
      46,
      8,
      10,
      5,
      12,
      6,
      11,
      7,
      9,
      6,
      13,
      8,
      10
    ),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-07",
      "2024-06-10",
      "2024-06-07",
      "2024-06-08",
      "2024-06-09",
      "2024-06-14",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-10",
      "2024-06-10",
      "2024-06-08",
      "2024-06-09",
      "2024-06-21",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-07",
      "2024-06-07",
      "2024-06-08",
      "2024-06-09",
      "2024-06-14"
    )),
    day_type = c(
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend"
    ),
    section = rep(c("North", "Central", "South"), each = 9),
    catch_total = c(
      2,
      3,
      2,
      4,
      3,
      2,
      3,
      4,
      3,
      5,
      6,
      5,
      7,
      6,
      5,
      7,
      8,
      6,
      10,
      12,
      9,
      11,
      10,
      12,
      13,
      11,
      10
    ),
    hours_fished = c(
      2.0,
      3.0,
      2.5,
      3.0,
      2.0,
      2.5,
      3.0,
      3.5,
      3.0,
      3.5,
      4.0,
      3.5,
      4.5,
      4.0,
      3.5,
      4.5,
      5.0,
      4.0,
      4.0,
      5.0,
      4.0,
      4.5,
      4.0,
      5.0,
      5.0,
      4.5,
      4.0
    ),
    catch_kept = c(
      1,
      2,
      1,
      3,
      2,
      1,
      2,
      3,
      2,
      3,
      4,
      3,
      5,
      4,
      3,
      5,
      6,
      4,
      7,
      9,
      6,
      8,
      7,
      9,
      10,
      8,
      7
    ),
    trip_status = rep("complete", 27),
    trip_duration = c(
      2.0,
      3.0,
      2.5,
      3.0,
      2.0,
      2.5,
      3.0,
      3.5,
      3.0,
      3.5,
      4.0,
      3.5,
      4.5,
      4.0,
      3.5,
      4.5,
      5.0,
      4.0,
      4.0,
      5.0,
      4.0,
      4.5,
      4.0,
      5.0,
      5.0,
      4.5,
      4.0
    ),
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews(
    # nolint: object_usage_linter
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status,
    trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

#' Create 3-section design with "South" absent from interview data
#'
#' Duplicated from test-estimate-catch-rate.R for self-contained test file.
make_section_design_with_missing_interview_section <- function() {
  # nolint: object_length_linter
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-07",
      "2024-06-10",
      "2024-06-08",
      "2024-06-09",
      "2024-06-14",
      "2024-06-15",
      "2024-06-16",
      "2024-06-21"
    )),
    day_type = c(
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend",
      "weekend",
      "weekend",
      "weekend"
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
      20,
      22,
      18,
      25,
      15,
      24,
      21,
      26,
      23,
      28,
      20,
      27,
      35,
      38,
      32,
      42,
      30,
      45,
      37,
      44,
      40,
      48,
      35,
      46,
      8,
      10,
      5,
      12,
      6,
      11,
      7,
      9,
      6,
      13,
      8,
      10
    ),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-07",
      "2024-06-10",
      "2024-06-07",
      "2024-06-08",
      "2024-06-09",
      "2024-06-14",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-10",
      "2024-06-10",
      "2024-06-08",
      "2024-06-09",
      "2024-06-21"
    )),
    day_type = c(
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend",
      "weekend"
    ),
    section = rep(c("North", "Central"), each = 9),
    catch_total = c(
      2,
      3,
      2,
      4,
      3,
      2,
      3,
      4,
      3,
      5,
      6,
      5,
      7,
      6,
      5,
      7,
      8,
      6
    ),
    hours_fished = c(
      2.0,
      3.0,
      2.5,
      3.0,
      2.0,
      2.5,
      3.0,
      3.5,
      3.0,
      3.5,
      4.0,
      3.5,
      4.5,
      4.0,
      3.5,
      4.5,
      5.0,
      4.0
    ),
    catch_kept = c(
      1,
      2,
      1,
      3,
      2,
      1,
      2,
      3,
      2,
      3,
      4,
      3,
      5,
      4,
      3,
      5,
      6,
      4
    ),
    trip_status = rep("complete", 18),
    trip_duration = c(
      2.0,
      3.0,
      2.5,
      3.0,
      2.0,
      2.5,
      3.0,
      3.5,
      3.0,
      3.5,
      4.0,
      3.5,
      4.5,
      4.0,
      3.5,
      4.5,
      5.0,
      4.0
    ),
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews(
    # nolint: object_usage_linter
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status,
    trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

#' Create test calendar data with 8 dates (4 weekday, 4 weekend)
make_test_calendar_harvest <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
}

#' Create test interview data with 32+ interviews (16+ per stratum)
make_test_interviews_harvest <- function() {
  set.seed(42) # Reproducibility
  # Create 32 interviews: 16 weekday, 16 weekend
  # Spread across multiple dates within each stratum
  data.frame(
    date = as.Date(c(
      # Weekday interviews (16 total, spread across 4 dates)
      rep("2024-06-01", 4),
      rep("2024-06-02", 4),
      rep("2024-06-03", 4),
      rep("2024-06-04", 4),
      # Weekend interviews (16 total, spread across 4 dates)
      rep("2024-06-08", 4),
      rep("2024-06-09", 4),
      rep("2024-06-15", 4),
      rep("2024-06-16", 4)
    )),
    catch_total = c(
      # Weekday catch (realistic variation)
      2,
      5,
      3,
      1,
      4,
      6,
      2,
      3,
      5,
      7,
      4,
      2,
      3,
      6,
      5,
      4,
      # Weekend catch (higher on average)
      8,
      10,
      6,
      9,
      7,
      11,
      8,
      10,
      9,
      12,
      7,
      8,
      10,
      11,
      9,
      8
    ),
    hours_fished = c(
      # Weekday effort (2-5 hours)
      2.5,
      4.0,
      3.5,
      2.0,
      3.0,
      5.0,
      2.5,
      3.5,
      4.5,
      5.0,
      3.5,
      2.5,
      3.0,
      4.5,
      4.0,
      3.5,
      # Weekend effort (3-6 hours)
      4.0,
      5.5,
      3.5,
      5.0,
      4.5,
      6.0,
      4.5,
      5.5,
      5.0,
      6.0,
      4.0,
      4.5,
      5.5,
      5.5,
      5.0,
      4.5
    ),
    catch_kept = c(
      # Kept fish (always <= catch_total)
      2,
      4,
      3,
      1,
      3,
      5,
      2,
      2,
      4,
      6,
      3,
      2,
      2,
      5,
      4,
      3,
      5,
      8,
      5,
      7,
      6,
      9,
      6,
      8,
      7,
      10,
      5,
      6,
      8,
      9,
      7,
      6
    ),
    trip_status = rep(c("complete", "incomplete"), 16),
    trip_duration = c(
      # Trip durations matching hours_fished
      2.5,
      4.0,
      3.5,
      2.0,
      3.0,
      5.0,
      2.5,
      3.5,
      4.5,
      5.0,
      3.5,
      2.5,
      3.0,
      4.5,
      4.0,
      3.5,
      4.0,
      5.5,
      3.5,
      5.0,
      4.5,
      6.0,
      4.5,
      5.5,
      5.0,
      6.0,
      4.0,
      4.5,
      5.5,
      5.5,
      5.0,
      4.5
    ),
    stringsAsFactors = FALSE
  )
}

#' Create test design with interviews including harvest (32+)
make_harvest_design <- function() {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews_harvest()
  add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter
}

#' Create design without harvest column
make_design_without_harvest <- function() {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews_harvest()
  # Omit harvest parameter
  add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter
}

#' Create small design with n interviews including harvest
make_small_harvest_design <- function(n) {
  # Single stratum to simplify
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Generate exactly n interviews
  interviews <- data.frame(
    date = as.Date(rep("2024-06-01", n)),
    catch_total = rep(c(2, 3, 4, 5), length.out = n),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    catch_kept = rep(c(2, 2, 3, 4), length.out = n),
    trip_status = rep("complete", n),
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    stringsAsFactors = FALSE
  )

  add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter
}

#' Create unbalanced design (one stratum < 10)
make_unbalanced_harvest_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # 15 weekday interviews, only 5 weekend interviews
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 5),
      rep("2024-06-02", 5),
      rep("2024-06-03", 5),
      rep("2024-06-08", 5)
    )),
    catch_total = c(2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 4, 5, 6, 7, 8, 8, 9, 10, 11, 12),
    hours_fished = c(2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 4, 5, 3, 4, 5, 4, 5, 6, 5, 6),
    catch_kept = c(2, 2, 3, 4, 5, 2, 3, 4, 5, 6, 3, 4, 5, 6, 7, 6, 7, 8, 9, 10),
    trip_status = rep("complete", 20),
    trip_duration = c(2, 3, 4, 5, 3, 3, 4, 5, 3, 4, 4, 5, 3, 4, 5, 4, 5, 6, 5, 6),
    stringsAsFactors = FALSE
  )

  add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter
}

# Basic behavior tests ----

test_that("estimate_harvest_rate returns creel_estimates class object", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_harvest_rate result has estimates tibble with correct columns", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_harvest_rate result method is 'ratio-of-means-hpue'", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  expect_equal(result$method, "ratio-of-means-hpue")
})

test_that("estimate_harvest_rate result variance_method is 'taylor' by default", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_harvest_rate result conf_level is 0.95 by default", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_harvest_rate estimate is a positive numeric value", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_harvest_rate errors when design is not creel_design", {
  fake_design <- list(interviews = data.frame(catch_kept = 1:10, hours_fished = 1:10))

  expect_error(
    estimate_harvest_rate(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_harvest_rate errors when design has no interview_survey", {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_harvest_rate errors for invalid variance method", {
  design <- make_harvest_design()

  expect_error(
    estimate_harvest_rate(design, variance = "invalid"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

test_that("estimate_harvest_rate errors when design missing effort_col", {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Manually construct design with interviews but no effort_col
  interviews <- make_test_interviews_harvest()
  design$interviews <- interviews
  design$interview_survey <- list(placeholder = TRUE) # fake survey object
  design$harvest_col <- "catch_kept"
  # deliberately omit effort_col

  expect_error(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "effort"
  )
})

test_that("estimate_harvest_rate errors when design has no harvest_col", {
  design <- make_design_without_harvest()

  expect_error(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "harvest"
  )
})

# Sample size validation tests ----

test_that("estimate_harvest_rate errors when n < 10 ungrouped", {
  design <- make_small_harvest_design(5)

  expect_error(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimate_harvest_rate warns when 10 <= n < 30 ungrouped", {
  design <- make_small_harvest_design(15)

  expect_warning(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "30"
  )
})

test_that("estimate_harvest_rate has no sample size warning when n >= 30 ungrouped", {
  design <- make_harvest_design() # has 32 interviews

  # use_trips = "all" keeps all 32 interviews (default "complete" would filter
  # to the 16 completed trips and trip the 10 <= n < 30 warning this test guards)
  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_harvest_rate(design, use_trips = "all"), # nolint: object_usage_linter
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for sample size warnings only
  sample_warnings <- grepl("sample|10|30", warnings, ignore.case = TRUE)

  expect_false(any(sample_warnings))
})

test_that("estimate_harvest_rate errors when any group has n < 10 in grouped estimation", {
  design <- make_unbalanced_harvest_design() # weekend has only 5

  expect_error(
    estimate_harvest_rate(design, by = day_type), # nolint: object_usage_linter
    "10"
  )
})

# Grouped estimation tests ----
# These tests exercise grouping/variance mechanics, not trip-status filtering.
# make_harvest_design() has 8 completed trips per day_type group, below the
# n >= 10 ratio-estimation floor, so they pass use_trips = "all" to retain all
# 16 interviews per group. The default ("complete") is covered separately below.

test_that("estimate_harvest_rate grouped by day_type returns creel_estimates with by_vars set", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type, use_trips = "all") # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_harvest_rate grouped result estimates tibble has day_type column", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type, use_trips = "all") # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_harvest_rate grouped result has one row per group level", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type, use_trips = "all") # nolint: object_usage_linter

  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_harvest_rate grouped result has n column reflecting per-group sample sizes", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type, use_trips = "all") # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Reference tests ----

test_that("ungrouped HPUE matches manual svyratio calculation", {
  design <- make_harvest_design()

  # tidycreel estimate (use_trips = "all" so the survey object below — which
  # spans all 32 interviews — is the correct manual reference)
  result <- estimate_harvest_rate(design, use_trips = "all") # nolint: object_usage_linter

  # Manual survey::svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyratio(~catch_kept, ~hours_fished, svy)
  manual_estimate <- as.numeric(coef(manual_result))
  manual_se <- as.numeric(survey::SE(manual_result))
  manual_ci <- confint(manual_result, level = 0.95)

  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-10)
  expect_equal(result$estimates$ci_lower, manual_ci[1, 1], tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci[1, 2], tolerance = 1e-10)
})

test_that("grouped HPUE matches manual svyby+svyratio calculation", {
  design <- make_harvest_design()

  # tidycreel grouped estimate (use_trips = "all" to match the all-interview
  # survey object used for the manual reference below)
  result <- estimate_harvest_rate(design, by = day_type, use_trips = "all") # nolint: object_usage_linter

  # Manual survey::svyby + svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyby(
    ~catch_kept,
    ~day_type,
    denominator = ~hours_fished,
    design = svy,
    FUN = survey::svyratio,
    vartype = c("se", "ci"),
    ci.level = 0.95,
    keep.names = FALSE
  )

  # Match point estimates for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_est <- result$estimates$estimate[i]
    # svyratio column name is "catch_kept/hours_fished"
    ratio_col <- "catch_kept/hours_fished"
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

test_that("ungrouped HPUE SE^2 matches variance from manual vcov", {
  design <- make_harvest_design()

  # tidycreel estimate (use_trips = "all" to match the all-interview survey
  # object used for the manual reference below)
  result <- estimate_harvest_rate(design, use_trips = "all") # nolint: object_usage_linter

  # Manual survey::svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyratio(~catch_kept, ~hours_fished, svy)
  manual_variance <- as.numeric(vcov(manual_result))

  expect_equal(result$estimates$se^2, manual_variance, tolerance = 1e-10)
})

# HPUE vs CPUE relationship tests ----

test_that("HPUE estimate <= CPUE estimate (harvest is subset of catch)", {
  design <- make_harvest_design()

  result_hpue <- estimate_harvest_rate(design) # nolint: object_usage_linter
  result_cpue <- estimate_catch_rate(design) # nolint: object_usage_linter

  # HPUE should be <= CPUE since harvest <= catch
  expect_true(result_hpue$estimates$estimate <= result_cpue$estimates$estimate)
})

test_that("HPUE and CPUE use same n (sample size should match)", {
  design <- make_harvest_design()

  result_hpue <- estimate_harvest_rate(design) # nolint: object_usage_linter
  result_cpue <- estimate_catch_rate(design) # nolint: object_usage_linter

  # As of v2.3.0 (#69) estimate_harvest_rate defaults to use_trips = "complete",
  # matching estimate_catch_rate. Both now restrict to completed-trip interviews,
  # so their sample sizes agree.
  n_complete <- sum(design$interviews$trip_status == "complete")
  expect_equal(result_cpue$estimates$n, n_complete)
  expect_equal(result_hpue$estimates$n, n_complete)
})

# Default use_trips tests (v2.3.0 / #69) ----

test_that("RATE-69-harvest: estimate_harvest_rate defaults to use_trips = 'complete'", {
  # Statistical rationale (Hansen & Van Kirk 2010): incomplete-trip HPUE
  # underestimates harvest, so the default must restrict to completed trips.
  # make_harvest_design() has 16 complete + 16 incomplete interviews.
  design <- make_harvest_design()
  n_complete <- sum(design$interviews$trip_status == "complete")

  # Default call must filter to completed trips (announced via cli message) ...
  expect_message(
    result_default <- estimate_harvest_rate(design), # nolint: object_usage_linter
    "complete"
  )
  expect_equal(result_default$estimates$n, n_complete)

  # ... and must equal an explicit use_trips = "complete" call.
  result_complete <- suppressMessages(estimate_harvest_rate(design, use_trips = "complete")) # nolint: object_usage_linter line_length_linter
  expect_equal(result_default$estimates$estimate, result_complete$estimates$estimate)

  # The opt-out (use_trips = "all") uses every interview and differs in n.
  result_all <- suppressMessages(estimate_harvest_rate(design, use_trips = "all")) # nolint: object_usage_linter
  expect_equal(result_all$estimates$n, nrow(design$interviews))
  expect_gt(result_all$estimates$n, result_default$estimates$n)
})

test_that("RATE-69-release: estimate_release_rate defaults to use_trips = 'complete'", {
  # Same default-flip rationale as harvest; release rate must also restrict to
  # completed trips by default.
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(
    design,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )
  design <- add_catch(
    design,
    example_catch, # nolint: object_usage_linter
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )

  has_incomplete <- any(design$interviews$trip_status == "incomplete")
  skip_if_not(has_incomplete, "example data has no incomplete trips to filter")

  n_complete <- sum(design$interviews$trip_status == "complete")
  result_default <- suppressMessages(estimate_release_rate(design)) # nolint: object_usage_linter
  result_complete <- suppressMessages(estimate_release_rate(design, use_trips = "complete")) # nolint: object_usage_linter line_length_linter

  expect_equal(result_default$estimates$n, n_complete)
  expect_equal(result_default$estimates$estimate, result_complete$estimates$estimate)
})

# Custom confidence level test ----

test_that("estimate_harvest_rate with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_harvest_design()

  result_95 <- estimate_harvest_rate(design, conf_level = 0.95, use_trips = "all") # nolint: object_usage_linter
  result_90 <- estimate_harvest_rate(design, conf_level = 0.90, use_trips = "all") # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

# Variance method tests ----

test_that("estimate_harvest_rate with bootstrap variance method produces valid results", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, variance = "bootstrap", use_trips = "all") # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
  expect_true(is.finite(result$estimates$se))
  expect_false(is.na(result$estimates$se))
})

test_that("estimate_harvest_rate with jackknife variance method produces valid results", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, variance = "jackknife") # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
  expect_true(is.finite(result$estimates$se))
  expect_false(is.na(result$estimates$se))
})

test_that("estimate_harvest_rate grouped + bootstrap variance compose correctly", {
  design <- make_harvest_design()

  # use_trips = "all": grouped bootstrap mechanics need >= 10 interviews/group
  # Should work (may warn about small n per group, but should not error)
  result <- suppressWarnings(estimate_harvest_rate(
    design,
    by = day_type,
    variance = "bootstrap",
    use_trips = "all"
  )) # nolint: object_usage_linter object_length_linter line_length_linter

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$variance_method, "bootstrap")
  expect_true(all(result$estimates$se > 0))
  expect_true(all(is.finite(result$estimates$se)))
})

# Integration tests with example data ----

test_that("estimate_harvest_rate works end-to-end with example_calendar and example_interviews", {
  # Load package data
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter

  # Add interviews with harvest = catch_kept
  design <- add_interviews(
    design,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Estimate harvest
  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

  # Verify result structure
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "ratio-of-means-hpue")

  # Verify HPUE estimate is reasonable
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate < 100) # Reasonable range for fish per hour
})

test_that("HPUE <= CPUE with example data (harvest is subset of catch)", {
  # Load package data
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter

  # Add interviews
  design <- add_interviews(
    design,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Estimate both HPUE and CPUE
  result_hpue <- estimate_harvest_rate(design) # nolint: object_usage_linter
  result_cpue <- estimate_catch_rate(design) # nolint: object_usage_linter

  # HPUE should be <= CPUE
  expect_true(result_hpue$estimates$estimate <= result_cpue$estimates$estimate)
})

test_that("grouped harvest estimation with example data handles small groups appropriately", {
  # Load package data
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter

  # Add interviews
  design <- add_interviews(
    design,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  # Check if weekend interviews < 10
  n_weekend <- sum(example_interviews$day_type == "weekend")

  if (n_weekend < 10) {
    # Should error due to small group size
    expect_error(
      estimate_harvest_rate(design, by = day_type), # nolint: object_usage_linter
      "10"
    )
  } else {
    # Should work (possibly with warning if n < 30)
    result <- suppressWarnings(estimate_harvest_rate(design, by = day_type)) # nolint: object_usage_linter
    expect_s3_class(result, "creel_estimates")
  }
})

# Zero-effort handling tests ----

test_that("estimate_harvest_rate filters zero-effort interviews with warning", {
  design <- make_harvest_design()

  # Inject 2 zero-effort interviews (must set .angler_effort, the column used by estimate_harvest_rate)
  design$interviews[[".angler_effort"]][1:2] <- 0

  # use_trips = "all" so the 32-interview arithmetic below (32 - 2 = 30) holds;
  # this test verifies zero-effort filtering, not trip-status filtering
  # Should warn about zero-effort
  expect_warning(
    result <- estimate_harvest_rate(design, use_trips = "all"), # nolint: object_usage_linter
    "zero effort"
  )

  # Result should still be valid (from non-zero-effort data)
  expect_s3_class(result, "creel_estimates")
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))

  # n should reflect filtered data (32 - 2 = 30)
  expect_equal(result$estimates$n, 30)
})

test_that("estimate_harvest_rate with all zero-effort errors on empty data", {
  design <- make_harvest_design()

  # Set all angler effort to zero (the column used by estimate_harvest_rate)
  design$interviews[[".angler_effort"]] <- 0

  # After filtering, n = 0, which should error
  expect_error(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "No valid interviews"
  )
})

# NA harvest handling tests ----

test_that("estimate_harvest_rate filters NA harvest interviews with warning", {
  design <- make_harvest_design()

  # Inject 2 NA harvest values
  design$interviews$catch_kept[1:2] <- NA

  # use_trips = "all" so the 32-interview arithmetic below (32 - 2 = 30) holds;
  # this test verifies NA-harvest filtering, not trip-status filtering
  # Should warn about missing harvest
  expect_warning(
    result <- estimate_harvest_rate(design, use_trips = "all"), # nolint: object_usage_linter
    "missing harvest"
  )

  # Result should still be valid (from non-NA data)
  expect_s3_class(result, "creel_estimates")
  expect_true(result$estimates$estimate >= 0)
  expect_true(is.finite(result$estimates$se))

  # n should reflect filtered data (32 - 2 = 30)
  expect_equal(result$estimates$n, 30)
})

test_that("estimate_harvest_rate with all NA harvest errors on empty data", {
  design <- make_harvest_design()

  # Set all harvest to NA
  design$interviews$catch_kept <- NA

  # After filtering, n = 0, which should error
  expect_error(
    estimate_harvest_rate(design), # nolint: object_usage_linter
    "No valid interviews"
  )
})

test_that("estimate_harvest_rate grouped with zero-effort interviews excludes them with warning", {
  # Create synthetic data with some zero-effort interviews in grouped estimation
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4)
  )

  # Create interviews with sufficient samples per group but some zero-effort
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 6),
      rep("2024-06-02", 6),
      rep("2024-06-08", 6),
      rep("2024-06-09", 6)
    )),
    catch_total = c(
      2,
      3,
      4,
      5,
      6,
      0,
      3,
      4,
      5,
      6,
      7,
      8,
      7,
      8,
      9,
      10,
      11,
      0,
      8,
      9,
      10,
      11,
      12,
      13
    ),
    catch_kept = c(
      2,
      3,
      4,
      5,
      5,
      0,
      3,
      4,
      5,
      6,
      6,
      7,
      6,
      7,
      8,
      9,
      10,
      0,
      7,
      8,
      9,
      10,
      11,
      12
    ),
    hours_fished = c(
      2,
      3,
      4,
      5,
      3,
      0, # one zero-effort
      3,
      4,
      5,
      3,
      4,
      5,
      4,
      5,
      3,
      5,
      4,
      0, # one zero-effort
      4,
      5,
      5,
      6,
      5,
      6
    ),
    trip_status = rep("complete", 24),
    trip_duration = c(
      2,
      3,
      4,
      5,
      3,
      1,
      3,
      4,
      5,
      3,
      4,
      5,
      4,
      5,
      3,
      5,
      4,
      1,
      4,
      5,
      5,
      6,
      5,
      6
    )
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(
    design,
    interviews,
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter

  # Grouped estimation should warn about zero-effort and exclude them
  expect_warning(
    result <- estimate_harvest_rate(design, by = day_type), # nolint: object_usage_linter
    "zero effort"
  )

  # Result should still be valid with 2 groups
  expect_s3_class(result, "creel_estimates")
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$estimate > 0))
})

test_that("estimate_harvest_rate grouped with NA harvest excludes them with warning", {
  # Create synthetic data with some NA harvest interviews in grouped estimation
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4)
  )

  # Create interviews with sufficient samples per group but some NA harvest
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 6),
      rep("2024-06-02", 6),
      rep("2024-06-08", 6),
      rep("2024-06-09", 6)
    )),
    catch_total = c(
      2,
      3,
      4,
      5,
      6,
      7,
      3,
      4,
      5,
      6,
      7,
      8,
      7,
      8,
      9,
      10,
      11,
      12,
      8,
      9,
      10,
      11,
      12,
      13
    ),
    catch_kept = c(
      2,
      3,
      4,
      5,
      5,
      NA, # one NA harvest
      3,
      4,
      5,
      6,
      6,
      7,
      6,
      7,
      8,
      9,
      10,
      NA, # one NA harvest
      7,
      8,
      9,
      10,
      11,
      12
    ),
    hours_fished = c(
      2,
      3,
      4,
      5,
      3,
      4,
      3,
      4,
      5,
      3,
      4,
      5,
      4,
      5,
      3,
      5,
      4,
      5,
      4,
      5,
      5,
      6,
      5,
      6
    ),
    trip_status = rep("complete", 24),
    trip_duration = c(
      2,
      3,
      4,
      5,
      3,
      4,
      3,
      4,
      5,
      3,
      4,
      5,
      4,
      5,
      3,
      5,
      4,
      5,
      4,
      5,
      5,
      6,
      5,
      6
    )
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(
    design,
    interviews,
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  ) # nolint: object_usage_linter

  # Grouped estimation should warn about NA harvest and exclude them
  expect_warning(
    result <- estimate_harvest_rate(design, by = day_type), # nolint: object_usage_linter
    "missing harvest"
  )

  # Result should still be valid with 2 groups
  expect_s3_class(result, "creel_estimates")
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$estimate >= 0))
})

# Bus-route harvest estimation ----
# Helpers defined at section scope per Phase 21-02 / Phase 22-02 convention

make_br_harvest_design <- function() {
  # Three sites A, B, C; one circuit c1
  # p_site: A=0.2, B=0.5, C=0.3 (sums to 1.0)
  # p_period: 0.8 for all sites in circuit c1
  # pi_i = p_site * p_period: A=0.16, B=0.40, C=0.24
  sf <- data.frame(
    site = c("A", "B", "C"),
    circuit = "c1",
    p_site = c(0.2, 0.5, 0.3),
    p_period = 0.8
  )
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = "weekday"
  )
  creel_design(
    # nolint: object_usage_linter
    calendar = cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site, # nolint: object_usage_linter
    circuit = circuit, # nolint: object_usage_linter
    p_site = p_site, # nolint: object_usage_linter
    p_period = p_period # nolint: object_usage_linter
  )
}

make_br_harvest_interviews <- function(design, trip_status_col = FALSE) {
  # Site A: 2 interviews (dates 01, 02), n_counted=6, n_interviewed=2 — expansion=3
  # Site B: 2 interviews (dates 03, 04), n_counted=1, n_interviewed=1 — expansion=1
  # Site C: 2 interviews (dates 01, 02), n_counted=3, n_interviewed=3 — expansion=1
  # harvest per interview: A=2, A=4, B=1, B=0, C=3, C=2
  # h_i (harvest * expansion): A=6, A=12, B=1, B=0, C=3, C=2
  # pi_i: A=0.16, A=0.16, B=0.40, B=0.40, C=0.24, C=0.24
  # h_i/pi_i: A=37.5, A=75.0, B=2.5, B=0, C=12.5, C=8.333...
  # H_hat = sum = 135.833...
  interviews_df <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-01",
      "2024-06-02"
    )),
    site = c("A", "A", "B", "B", "C", "C"),
    circuit = "c1",
    n_counted = c(6L, 6L, 1L, 1L, 3L, 3L),
    n_interviewed = c(2L, 2L, 1L, 1L, 3L, 3L),
    hours_fished = c(2.0, 3.0, 1.5, 0.5, 2.0, 1.5),
    fish_kept = c(2L, 4L, 1L, 0L, 3L, 2L),
    fish_caught = c(3L, 5L, 2L, 1L, 4L, 3L),
    trip_status = rep("complete", 6)
  )
  if (trip_status_col) {
    # Spread incomplete trips across 2 dates to satisfy survey PSU requirement
    interviews_df$trip_status <- c(
      "complete",
      "incomplete",
      "complete",
      "incomplete",
      "complete",
      "complete"
    )
  }
  add_interviews(
    # nolint: object_usage_linter
    design,
    interviews_df,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
}

test_that("estimate_harvest_rate() dispatches to bus-route estimator for bus_route designs", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_harvest_rate(d)
  expect_s3_class(result, "creel_estimates")
})

test_that("Eq. 19.5: H_hat = sum(h_i/pi_i) is what estimate_total_harvest() returns", {
  # This assertion used to be made against estimate_harvest_rate(), which is how
  # a total came to be reported as a rate (GH #107). Eq. 19.5 is a total, so it
  # belongs to the total estimator.
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_total_harvest(d)
  # H_hat = 37.5 + 75.0 + 2.5 + 0 + 12.5 + 8.333... = 135.833...
  expected_h_hat <- (2 * 3) /
    0.16 +
    (4 * 3) / 0.16 +
    (1 * 1) / 0.40 +
    (0 * 1) / 0.24 +
    (3 * 1) / 0.24 +
    (2 * 1) / 0.24
  expect_equal(result$estimates$estimate, expected_h_hat, tolerance = 1e-6)
})

test_that("estimate_harvest_rate() on a bus-route design returns a rate, not a total (GH #107)", {
  # Jones & Pollock give bus-route harvest and effort as HT totals and define no
  # rate estimator. The rate the design supports is the ratio of those totals.
  d <- make_br_harvest_interviews(make_br_harvest_design())
  rate <- estimate_harvest_rate(d)

  expect_identical(rate$method, "ratio-of-means-hpue")

  # Hand-computed: H_hat = 135.8333..., E_hat = 113.3333..., ratio = 1.1985294
  expect_equal(rate$estimates$estimate, 135.83333333 / 113.33333333, tolerance = 1e-6)

  # State the defect directly: the rate must not be the harvest total.
  expect_false(isTRUE(all.equal(rate$estimates$estimate, 135.83333333)))
})

test_that("bus-route HPUE equals total harvest over total effort (GH #107)", {
  # Ties the rate to the two estimators it is built from, so a change to either
  # HT total that is not reflected in the rate fails here.
  d <- make_br_harvest_interviews(make_br_harvest_design())
  rate <- estimate_harvest_rate(d)$estimates$estimate
  h_total <- estimate_total_harvest(d)$estimates$estimate
  e_total <- estimate_effort(d)$estimates$estimate

  expect_equal(rate, h_total / e_total, tolerance = 1e-9)
})

test_that("bus-route HPUE variance accounts for the harvest-effort covariance (GH #107)", {
  # H_hat and E_hat come from the same interviews and are strongly positively
  # correlated. Dividing the point estimates and propagating the SEs as if they
  # were independent overstates the SE by roughly eightfold on this fixture,
  # which is why svyratio does the linearisation over both.
  d <- make_br_harvest_interviews(make_br_harvest_design())
  rate <- estimate_harvest_rate(d)$estimates
  h <- estimate_total_harvest(d)$estimates
  e <- estimate_effort(d)$estimates

  naive_se <- (h$estimate / e$estimate) *
    sqrt((h$se / h$estimate)^2 + (e$se / e$estimate)^2)

  expect_lt(rate$se, naive_se / 2)
  expect_gt(rate$se, 0)
})

test_that("bus-route HPUE is fish per angler-hour, so it falls as party size rises (GH #106, #107)", {
  # The denominator is angler-effort. Holding harvest fixed and tripling party
  # size triples the effort denominator, so the rate must fall by three. A
  # party-hours denominator would leave it unchanged.
  d1 <- make_br_harvest_interviews(make_br_harvest_design())
  d3 <- d1
  d3$interviews[[d3$n_anglers_col %||% "n_anglers"]] <- 3L
  d3$interviews[[d3$angler_effort_col]] <- d3$interviews[[d3$effort_col]] * 3L

  r1 <- estimate_harvest_rate(d1)$estimates$estimate
  r3 <- estimate_harvest_rate(d3)$estimates$estimate

  expect_equal(r3, r1 / 3, tolerance = 1e-9)
})

test_that("estimate_harvest_rate() site_contributions attribute present with h_i and pi_i columns", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_harvest_rate(d)
  sc <- attr(result, "site_contributions")
  expect_false(is.null(sc))
})

test_that("get_site_contributions() returns tibble from bus-route harvest result", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_harvest_rate(d)
  sc <- get_site_contributions(result)
  expect_s3_class(sc, "tbl_df")
  expect_true("pi_i" %in% names(sc))
})

test_that("estimate_harvest_rate() verbose=TRUE names the bus-route estimator it used", {
  # The message has to say a rate is being computed. Advertising Eq. 19.5 alone
  # described a total, which is what the function used to return (GH #107).
  d <- make_br_harvest_interviews(make_br_harvest_design())
  expect_message(
    estimate_harvest_rate(d, verbose = TRUE),
    "bus-route HPUE"
  )
})

test_that("estimate_harvest_rate() verbose=FALSE produces no dispatch message", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  expect_no_message(suppressWarnings(estimate_harvest_rate(d, verbose = FALSE)))
})

test_that("estimate_harvest_rate() use_trips='complete' returns creel_estimates for bus-route", {
  d <- make_br_harvest_interviews(make_br_harvest_design(), trip_status_col = TRUE)
  result <- estimate_harvest_rate(d, use_trips = "complete")
  expect_s3_class(result, "creel_estimates")
  expect_true(result$estimates$estimate > 0)
})

test_that("estimate_harvest_rate() use_trips='incomplete' returns creel_estimates for bus-route", {
  d <- make_br_harvest_interviews(make_br_harvest_design(), trip_status_col = TRUE)
  result <- estimate_harvest_rate(d, use_trips = "incomplete")
  expect_s3_class(result, "creel_estimates")
  expect_true(result$estimates$estimate >= 0)
})

test_that("estimate_harvest_rate() use_trips='diagnostic' returns creel_estimates_diagnostic", {
  d <- make_br_harvest_interviews(make_br_harvest_design(), trip_status_col = TRUE)
  result <- estimate_harvest_rate(d, use_trips = "diagnostic")
  expect_s3_class(result, "creel_estimates_diagnostic")
})

test_that("estimate_harvest_rate() by=circuit returns a rate per group, with no proportion column (GH #107)", {
  # A share-of-total column is meaningful for a total and meaningless for a
  # rate: group rates are not parts of the overall rate and do not sum to it.
  # It was present only because the rate path returned a total.
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_harvest_rate(d, by = circuit) # nolint: object_usage_linter

  expect_identical(result$method, "ratio-of-means-hpue")
  expect_false("proportion" %in% names(result$estimates))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result$estimates)))
  expect_true(all(result$estimates$estimate > 0))
})

test_that("single-group bus-route HPUE equals the ungrouped rate (GH #107)", {
  # The fixture has one circuit, so grouping by it must not change the number.
  # This catches a grouped path that silently computes something else.
  d <- make_br_harvest_interviews(make_br_harvest_design())
  ungrouped <- estimate_harvest_rate(d)$estimates$estimate
  grouped <- estimate_harvest_rate(d, by = circuit) # nolint: object_usage_linter

  expect_equal(nrow(grouped$estimates), 1L)
  expect_equal(grouped$estimates$estimate, ungrouped, tolerance = 1e-9)
})

# Section dispatch tests (RATE-02a, RATE-03) ----

test_that("RATE-02a: estimate_harvest_rate on 3-section design returns exactly 3 rows", {
  design <- make_3section_design_with_interviews() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, missing_sections = "warn") # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 3L)
  expect_true("section" %in% names(result$estimates))
  expect_false(".lake_total" %in% result$estimates$section)
})

test_that("RATE-03-harvest: missing section produces NA row + cli_warn for estimate_harvest_rate", {
  design <- make_section_design_with_missing_interview_section() # nolint: object_usage_linter
  warns <- character(0)
  result <- withCallingHandlers(
    estimate_harvest_rate(design, missing_sections = "warn"), # nolint: object_usage_linter
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("missing|section|South", warns, ignore.case = TRUE)))
  south_row <- result$estimates[result$estimates$section == "South", ]
  expect_equal(nrow(south_row), 1L)
  expect_false(south_row$data_available)
  expect_true(is.na(south_row$estimate))
})

# Species-level HPUE dispatch ----

test_that("HPUE-SPECIES-01: by=species returns creel_estimates with hpue-species method", {
  design <- suppressMessages(suppressWarnings(
    build_multistrata_multispecies_design_for_tests(
      n_days = 10L,
      n_interviews = 30L,
      n_species = 2L,
      seed = 42L
    )
  ))
  result <- suppressMessages(suppressWarnings(estimate_harvest_rate(design, by = species)))
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "ratio-of-means-hpue-species")
})

test_that("HPUE-SPECIES-02: by=species result has one row per species with species column", {
  design <- suppressMessages(suppressWarnings(
    build_multistrata_multispecies_design_for_tests(
      n_days = 10L,
      n_interviews = 30L,
      n_species = 3L,
      seed = 7L
    )
  ))
  result <- suppressMessages(suppressWarnings(estimate_harvest_rate(design, by = species)))
  expect_true("species" %in% names(result$estimates))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("HPUE-SPECIES-03: by=c(day_type, species) groups by interview var + species", {
  design <- suppressMessages(suppressWarnings(
    build_multistrata_multispecies_design_for_tests(
      n_days = 10L,
      n_interviews = 40L,
      n_species = 2L,
      seed = 99L
    )
  ))
  result <- suppressMessages(suppressWarnings(
    estimate_harvest_rate(design, by = c(day_type, species))
  ))
  expect_s3_class(result, "creel_estimates")
  expect_true("species" %in% names(result$estimates))
  expect_true("day_type" %in% names(result$estimates))
})

test_that("HPUE-SPECIES-04: all estimate/se/ci columns present in species result", {
  design <- suppressMessages(suppressWarnings(
    build_multistrata_multispecies_design_for_tests(
      n_days = 10L,
      n_interviews = 30L,
      n_species = 2L,
      seed = 42L
    )
  ))
  result <- suppressMessages(suppressWarnings(estimate_harvest_rate(design, by = species)))
  expected_cols <- c("species", "estimate", "se", "ci_lower", "ci_upper")
  expect_true(all(expected_cols %in% names(result$estimates)))
  expect_true(all(is.finite(result$estimates$estimate)))
})

# GH #108 — bus-route incomplete-trip harvest rate (audit findings 4 and 5) ----
#
# The incomplete branch used to compute r_i = harvest / party-hours, divide that
# ratio by the inclusion probability, and sum. Inverse-probability weights apply
# to totals, not to ratios, so the result was neither a rate nor a total: it grew
# linearly with the number of interviews. Hoenig, Jones, Pollock, Robson & Wade
# (1997, Biometrics 53:306-317) give the estimator this trip type supports — a
# mean of the individual angler rates, with short trips truncated.

# Builds an incomplete-trip fixture whose true rate is exactly `rate` fish per
# angler-hour for every angler, so any honest rate estimator must return `rate`.
make_br_incomplete <- function(
  hours = c(2.0, 3.0, 1.5, 2.5),
  rate = 2,
  status = "incomplete",
  reps = 1L,
  n_counted = 3L,
  n_interviewed = 3L
) {
  sf <- data.frame(
    site = c("A", "B", "C"),
    circuit = "c1",
    p_site = c(0.2, 0.5, 0.3),
    p_period = 0.8
  )
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = "weekday"
  )
  design <- creel_design(
    calendar = cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site, # nolint: object_usage_linter
    circuit = circuit, # nolint: object_usage_linter
    p_site = p_site, # nolint: object_usage_linter
    p_period = p_period # nolint: object_usage_linter
  )
  base <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    site = c("A", "A", "B", "C"),
    circuit = "c1",
    n_counted = n_counted,
    n_interviewed = n_interviewed,
    hours_fished = hours,
    fish_kept = hours * rate,
    fish_caught = hours * rate,
    trip_status = status,
    n_anglers = 1L
  )
  iv <- do.call(rbind, replicate(reps, base, simplify = FALSE))
  suppressMessages(add_interviews(
    design,
    iv,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_anglers = n_anglers, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

test_that("bus-route incomplete HPUE does not grow with sample size (GH #108)", {
  # The falsifying property. Sampling the same population harder cannot change
  # the rate it has. The old estimator doubled when the interviews doubled,
  # which alone disqualifies it as a rate regardless of any other defect.
  rates <- vapply(
    c(1L, 2L, 4L),
    function(reps) {
      d <- make_br_incomplete(reps = reps)
      suppressMessages(
        estimate_harvest_rate(d, use_trips = "incomplete")$estimates$estimate
      )
    },
    numeric(1)
  )

  expect_equal(rates[[2]], rates[[1]], tolerance = 1e-9)
  expect_equal(rates[[3]], rates[[1]], tolerance = 1e-9)
})

test_that("bus-route incomplete HPUE recovers a known constant rate (GH #108)", {
  # Every angler in the fixture harvests at exactly 2 fish per angler-hour, so
  # the weighted mean of the per-angler rates is 2 whatever the weights are.
  # The old estimator returned 38.3 on this fixture.
  d <- make_br_incomplete(rate = 2)
  result <- suppressMessages(estimate_harvest_rate(d, use_trips = "incomplete"))

  expect_equal(result$estimates$estimate, 2, tolerance = 1e-9)
  expect_identical(result$method, "mean-of-ratios-hpue")
})

test_that("bus-route incomplete HPUE is a Hajek weighted mean of angler rates (GH #108)", {
  # Hand-computed against the design weights: w_i = .expansion / .pi_i, and the
  # estimate is sum(w_i * r_i) / sum(w_i). Pins the weighting scheme itself, so
  # dropping .expansion (as the old code did) or reverting to sum(r_i / pi_i)
  # fails here rather than silently changing the number.
  d <- make_br_incomplete(hours = c(2.0, 3.0, 1.5, 2.5), rate = 2)
  d$interviews$fish_kept <- c(2, 9, 3, 10) # rates 1, 3, 2, 4 fish/angler-hour

  iv <- d$interviews
  w <- iv$.expansion / iv$.pi_i
  r <- iv$fish_kept / iv[[d$angler_effort_col]]
  expected <- sum(w * r) / sum(w)

  result <- suppressMessages(estimate_harvest_rate(d, use_trips = "incomplete"))
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-9)

  # Not the unweighted mean, and not the old sum(r_i / pi_i).
  expect_false(isTRUE(all.equal(result$estimates$estimate, mean(r))))
  expect_false(isTRUE(all.equal(result$estimates$estimate, sum(r / iv$.pi_i))))
})

test_that("bus-route incomplete HPUE applies the enumeration expansion (GH #108)", {
  # .expansion (n_counted / n_interviewed) is part of the weight. The complete
  # branch has always applied it; the incomplete branch dropped it, so the two
  # were not comparable even setting the ratio-weighting bug aside.
  #
  # Rates here are 1 and 3 at site A, 2 at B, 4 at C. Site C is the fastest, so
  # raising only site C's expansion must pull the weighted mean up, and raising
  # only site A's (mean rate 2, below the overall 2.43) must pull it down.
  d <- make_br_incomplete()
  d$interviews$fish_kept <- c(2, 9, 3, 10)
  base <- suppressMessages(
    estimate_harvest_rate(d, use_trips = "incomplete")$estimates$estimate
  )

  bump <- function(site_id) {
    d2 <- d
    rows <- d2$interviews$site == site_id
    d2$interviews$.expansion[rows] <- d2$interviews$.expansion[rows] * 4
    suppressMessages(
      estimate_harvest_rate(d2, use_trips = "incomplete")$estimates$estimate
    )
  }

  expect_gt(bump("C"), base)
  expect_lt(bump("A"), base)
})

test_that("bus-route incomplete HPUE is fish per angler-hour, not party-hour (GH #106, #108)", {
  # The denominator was the party's elapsed hours, so a party of three reported
  # the same rate as a solo angler catching the same fish. Tripling party size
  # at fixed harvest must divide the rate by three.
  d1 <- make_br_incomplete()
  d3 <- d1
  d3$interviews[[d3$n_anglers_col]] <- 3L
  d3$interviews[[d3$angler_effort_col]] <- d3$interviews[[d3$effort_col]] * 3

  r1 <- suppressMessages(
    estimate_harvest_rate(d1, use_trips = "incomplete")$estimates$estimate
  )
  r3 <- suppressMessages(
    estimate_harvest_rate(d3, use_trips = "incomplete")$estimates$estimate
  )

  expect_equal(r3, r1 / 3, tolerance = 1e-9)
})

test_that("bus-route incomplete HPUE truncates short trips by default (GH #108)", {
  # Hoenig et al. (1997): the mean-of-ratios estimator has infinite asymptotic
  # variance because E(1/L) is infinite as trip length goes to zero. They
  # recommend discarding trips under 30 minutes. The 12-minute trip here carries
  # a wild rate that swamps the estimate when it is retained.
  d <- make_br_incomplete(hours = c(2.0, 3.0, 1.5, 0.2), rate = 2)
  d$interviews$fish_kept <- c(4, 6, 3, 5) # last row is 25 fish/angler-hour

  truncated <- suppressMessages(
    estimate_harvest_rate(d, use_trips = "incomplete", truncate_at = 0.5)
  )
  untruncated <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(d, use_trips = "incomplete", truncate_at = NULL)
  ))

  expect_identical(truncated$estimates$n, 3L)
  expect_equal(truncated$estimates$estimate, 2, tolerance = 1e-9)

  expect_identical(untruncated$estimates$n, 4L)
  expect_gt(untruncated$estimates$estimate, truncated$estimates$estimate)
})

test_that("bus-route incomplete HPUE truncates on elapsed hours, not angler-hours (GH #108)", {
  # The instability comes from a short *clock* interval, because it is 1/L that
  # explodes. A party of five fishing 12 minutes supplies a full angler-hour of
  # effort while still being the unstable case, so truncating on angler-effort
  # would let exactly the wrong row through.
  d <- make_br_incomplete(hours = c(2.0, 3.0, 1.5, 0.2), rate = 2)
  d$interviews[[d$n_anglers_col]] <- 5L
  d$interviews[[d$angler_effort_col]] <- d$interviews[[d$effort_col]] * 5

  result <- suppressMessages(estimate_harvest_rate(d, use_trips = "incomplete"))
  expect_identical(result$estimates$n, 3L)
})

test_that("bus-route incomplete HPUE warns when truncation is disabled (GH #108)", {
  # Disabling truncation is allowed but the reported SE then understates the
  # true sampling variability, which the user has to be told.
  d <- make_br_incomplete()
  expect_warning(
    suppressMessages(
      estimate_harvest_rate(d, use_trips = "incomplete", truncate_at = NULL)
    ),
    "infinite asymptotic variance"
  )
})

test_that("bus-route incomplete HPUE rejects a non-positive truncate_at (GH #108)", {
  d <- make_br_incomplete()
  expect_error(
    suppressMessages(
      estimate_harvest_rate(d, use_trips = "incomplete", truncate_at = -1)
    ),
    "must be a positive number of hours"
  )
})

test_that("bus-route incomplete HPUE aborts when truncation empties the sample (GH #108)", {
  # Returning an estimate from zero retained trips would be worse than failing.
  d <- make_br_incomplete(hours = c(0.2, 0.1, 0.15, 0.2))
  expect_error(
    suppressMessages(
      estimate_harvest_rate(d, use_trips = "incomplete", truncate_at = 0.5)
    ),
    "No incomplete trips remain"
  )
})

test_that("bus-route incomplete HPUE by-group returns rates with no proportion column (GH #108)", {
  # As on the complete path: a share-of-total is meaningful for a total and
  # meaningless for a rate.
  d <- make_br_incomplete()
  result <- suppressMessages(
    estimate_harvest_rate(d, by = site, use_trips = "incomplete") # nolint: object_usage_linter
  )

  expect_identical(result$method, "mean-of-ratios-hpue")
  expect_false("proportion" %in% names(result$estimates))
  expect_true(all(abs(result$estimates$estimate - 2) < 1e-9))
})

# GH #108 finding 5 — diagnostic slots ----

make_br_diagnostic <- function(rate = 2) {
  d <- make_br_incomplete(rate = rate, reps = 2L)
  d$interviews$trip_status <- rep(c("incomplete", "complete"), each = 4)
  d
}

test_that("diagnostic slots report the same physical quantity (GH #108)", {
  # The whole purpose of the diagnostic is a side-by-side read of complete
  # against incomplete. It used to put a harvest total in one slot and
  # sum(fish per party-hour / probability) in the other, so the gap looked like
  # enormous incomplete-trip bias when it was a change of units. On a fixture
  # where every angler fishes at 2 fish per angler-hour, both slots must say 2.
  d <- make_br_diagnostic(rate = 2)
  result <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(d, use_trips = "diagnostic")
  ))

  expect_s3_class(result, "creel_estimates_diagnostic")
  expect_identical(result$complete$method, "ratio-of-means-hpue")
  expect_identical(result$incomplete$method, "mean-of-ratios-hpue")
  expect_equal(result$complete$estimates$estimate, 2, tolerance = 1e-9)
  expect_equal(result$incomplete$estimates$estimate, 2, tolerance = 1e-9)
})

test_that("both diagnostic slots respond to party size the same way (GH #108)", {
  # A shared dimension is not just a matching number on one fixture: both slots
  # have to be fish per *angler*-hour, so tripling party size must divide both
  # by three. A slot holding a total would not move at all.
  d1 <- make_br_diagnostic()
  d3 <- d1
  d3$interviews[[d3$n_anglers_col]] <- 3L
  d3$interviews[[d3$angler_effort_col]] <- d3$interviews[[d3$effort_col]] * 3

  g1 <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(d1, use_trips = "diagnostic")
  ))
  g3 <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(d3, use_trips = "diagnostic")
  ))

  for (slot in c("complete", "incomplete")) {
    expect_equal(
      g3[[slot]]$estimates$estimate,
      g1[[slot]]$estimates$estimate / 3,
      tolerance = 1e-9
    )
  }
})

test_that("diagnostic aborts when only one trip type is present (GH #108)", {
  # A one-sided comparison used to fail deep inside survey with
  # "all arguments must have the same length".
  d <- make_br_incomplete(status = "incomplete")
  expect_error(
    suppressMessages(estimate_harvest_rate(d, use_trips = "diagnostic")),
    "needs both complete and incomplete trips"
  )
})

test_that("bus-route verbose names the estimator the trip type actually uses (GH #108)", {
  # The dispatch message advertised the complete-trip ratio of HT totals on
  # every path, including the one that never runs it.
  d <- make_br_diagnostic()
  expect_message(
    suppressWarnings(estimate_harvest_rate(d, use_trips = "incomplete", verbose = TRUE)),
    "mean of ratios"
  )
  expect_message(
    suppressWarnings(estimate_harvest_rate(d, use_trips = "complete", verbose = TRUE)),
    "ratio of HT totals"
  )
})
