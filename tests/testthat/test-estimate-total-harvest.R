# Test helpers ----

#' Create test design with BOTH counts and interviews (for total harvest)
make_total_harvest_design <- function() {
  # Use example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design with both data sources including harvest
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  design
}

#' Create test design without harvest column
make_design_no_harvest <- function() { # nolint: object_length_linter
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design but don't specify harvest parameter
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
    # Note: no harvest parameter
  )

  design
}

make_total_harvest_species_design <- function() {
  # Synthetic data: 10+ interviews per day_type stratum to satisfy n >= 10 check
  set.seed(42)
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-07", "2024-06-10", "2024-06-11", "2024-06-12",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16",
      "2024-06-22", "2024-06-23", "2024-06-29", "2024-06-30"
    )),
    day_type = c(rep("weekday", 8), rep("weekend", 8)),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = c(rep(15, 8), rep(30, 8)),
    stringsAsFactors = FALSE
  )
  # 12 interviews per stratum (24 total), each a completed trip
  iview_dates <- c(
    rep(as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-07", "2024-06-10"
    )), 2),
    rep(as.Date(c(
      "2024-06-08", "2024-06-09", "2024-06-15",
      "2024-06-16", "2024-06-22", "2024-06-23"
    )), 2)
  )
  iview_dtype <- c(rep("weekday", 12), rep("weekend", 12))
  catch_total <- sample(1:5, 24, replace = TRUE)
  interviews <- data.frame(
    date = iview_dates,
    day_type = iview_dtype,
    interview_id = seq_len(24),
    catch_total = catch_total,
    catch_kept = pmin(sample(0:3, 24, replace = TRUE), catch_total),
    hours_fished = runif(24, 0.5, 4),
    trip_status = "complete",
    trip_duration = runif(24, 1, 6),
    stringsAsFactors = FALSE
  )
  # catch data: 2 species per interview
  catch_df <- data.frame(
    interview_id = rep(seq_len(24), 2),
    species = rep(c("bass", "bluegill"), each = 24),
    count = sample(0:3, 48, replace = TRUE),
    catch_type = "caught",
    stringsAsFactors = FALSE
  )
  # Add harvested rows
  catch_h <- catch_df
  catch_h$catch_type <- "harvested"
  catch_h$count <- pmin(catch_h$count, sample(0:2, 48, replace = TRUE))
  catch_df <- rbind(catch_df, catch_h)

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, counts) # nolint: object_usage_linter
  design <- add_interviews(design, interviews, # nolint: object_usage_linter
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )
  design <- add_catch(design, catch_df, # nolint: object_usage_linter
    catch_uid     = interview_id,
    interview_uid = interview_id,
    species       = species,
    count         = count,
    catch_type    = catch_type
  )

  design
}

# Basic behavior tests ----

test_that("estimate_total_harvest returns creel_estimates class object", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_harvest result has estimates tibble with correct columns", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_total_harvest result method is 'product-total-harvest'", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$method, "product-total-harvest")
})

test_that("estimate_total_harvest result variance_method is 'taylor' by default", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_total_harvest result conf_level is 0.95 by default", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_total_harvest defaults effort_target to sampled_days", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_equal(result$effort_target, "sampled_days")
})

test_that("estimate_total_harvest species path accepts target = 'period_total'", {
  design <- make_total_harvest_species_design()

  result <- estimate_total_harvest(design, by = species, target = "period_total") # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$effort_target, "period_total")
  expect_true("species" %in% names(result$estimates))
})

test_that("estimate_total_harvest estimate is a positive numeric value", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_total_harvest errors when design is not creel_design", {
  fake_design <- "not a design"

  expect_error(
    estimate_total_harvest(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_total_harvest errors when design has no counts", {
  # Create design with only interviews
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total,
    harvest = catch_kept,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )

  expect_error(
    estimate_total_harvest(design), # nolint: object_usage_linter
    "add_counts"
  )
})

test_that("estimate_total_harvest errors when design has no interviews", {
  # Create design with only counts
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter

  expect_error(
    estimate_total_harvest(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_total_harvest errors when design has no harvest_col", {
  design <- make_design_no_harvest()

  expect_error(
    estimate_total_harvest(design), # nolint: object_usage_linter
    "harvest"
  )
})

test_that("estimate_total_harvest errors for invalid variance method", {
  design <- make_total_harvest_design()

  expect_error(
    estimate_total_harvest(design, variance = "invalid_method"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

# Reference tests ----

test_that("total harvest estimate equals effort * hpue exactly", {
  design <- make_total_harvest_design()

  # Get total harvest estimate
  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  hpue <- estimate_harvest_rate(design) # nolint: object_usage_linter

  # Product should match exactly
  expected <- effort$estimates$estimate * hpue$estimates$estimate

  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
})

test_that("total harvest SE matches manual delta method formula", {
  design <- make_total_harvest_design()

  # Get total harvest estimate
  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  hpue <- estimate_harvest_rate(design) # nolint: object_usage_linter

  # Extract components
  effort_est <- effort$estimates$estimate # nolint: object_name_linter
  hpue_est <- hpue$estimates$estimate # nolint: object_name_linter
  var_effort <- effort$estimates$se^2 # nolint: object_name_linter
  var_hpue <- hpue$estimates$se^2 # nolint: object_name_linter

  # Manual delta method (first-order approximation)
  manual_variance <- (effort_est^2 * var_hpue) + (hpue_est^2 * var_effort)
  manual_se <- sqrt(manual_variance)

  # Allow slightly looser tolerance for SE since svycontrast may include second-order term
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-6)
})

# Grouped estimation tests ----

# Create synthetic data helper with larger sample sizes for grouped testing
make_grouped_harvest_design <- function() {
  # Create synthetic calendar with balanced groups (30 days each)
  dates <- seq.Date(as.Date("2024-01-01"), by = "day", length.out = 60)
  calendar <- data.frame(
    date = dates,
    day_type = rep(c("weekday", "weekend"), each = 30)
  )

  # Create synthetic counts (2 per day = 120 total) with day_type
  counts <- data.frame(
    date = rep(dates, each = 2),
    day_type = rep(rep(c("weekday", "weekend"), each = 30), each = 2),
    time = rep(c("AM", "PM"), 60),
    count = rpois(120, lambda = 15)
  )

  # Create synthetic interviews with adequate samples per group (15 per group = 30 total)
  catch <- rpois(30, lambda = 3)
  interviews <- data.frame(
    date = sample(dates, 30, replace = TRUE),
    catch_total = catch,
    catch_kept = pmin(rpois(30, lambda = 2), catch), # Ensure harvest <= catch
    hours_fished = runif(30, min = 1, max = 8),
    trip_status = rep(c("complete", "incomplete"), 15),
    trip_duration = runif(30, min = 1, max = 8)
  )
  # Ensure at least 15 in each group
  interviews$date[1:15] <- sample(dates[1:30], 15, replace = TRUE) # weekday
  interviews$date[16:30] <- sample(dates[31:60], 15, replace = TRUE) # weekend

  # Create design
  design <- creel_design(calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, counts) # nolint: object_usage_linter
  design <- add_interviews(design, interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  design
}

test_that("estimate_total_harvest grouped by day_type works", {
  design <- make_grouped_harvest_design()

  result <- suppressWarnings(estimate_total_harvest(design, by = day_type)) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_total_harvest grouped result has correct number of rows", {
  design <- make_grouped_harvest_design()

  result <- suppressWarnings(estimate_total_harvest(design, by = day_type)) # nolint: object_usage_linter

  # Should have weekday and weekend
  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_total_harvest grouped result n is per-group", {
  design <- make_grouped_harvest_design()

  result <- suppressWarnings(estimate_total_harvest(design, by = day_type)) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Total harvest vs total catch relationship test ----

test_that("total harvest estimate <= total catch estimate", {
  design <- make_total_harvest_design()

  # Get both estimates
  result_harvest <- estimate_total_harvest(design) # nolint: object_usage_linter
  result_catch <- estimate_total_catch(design) # nolint: object_usage_linter

  # Harvest should be <= catch (kept fish subset of total catch)
  expect_true(result_harvest$estimates$estimate <= result_catch$estimates$estimate)
})

# Variance method tests ----

test_that("estimate_total_harvest with bootstrap variance returns correct method", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design, variance = "bootstrap") # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("estimate_total_harvest with jackknife variance returns correct method", {
  design <- make_total_harvest_design()

  result <- estimate_total_harvest(design, variance = "jackknife") # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("estimate_total_harvest grouped with bootstrap works", {
  design <- make_grouped_harvest_design()

  result <- suppressWarnings(estimate_total_harvest(design, by = day_type, variance = "bootstrap")) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$variance_method, "bootstrap")
  expect_true(!is.null(result$by_vars))
  expect_true(all(is.finite(result$estimates$estimate)))
  expect_true(all(result$estimates$estimate > 0))
  expect_true(all(is.finite(result$estimates$se)))
  expect_true(all(result$estimates$se > 0))
})

# Integration with example data ----

test_that("full workflow with example data produces valid total harvest", {
  # Load example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create complete design including harvest
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  # Estimate total harvest
  result <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Verify result structure and validity
  expect_s3_class(result, "creel_estimates")
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
  expect_true(is.finite(result$estimates$se))
})

test_that("total harvest components are consistent", {
  design <- make_total_harvest_design()

  # Estimate all components
  effort_est <- estimate_effort(design) # nolint: object_usage_linter
  hpue_est <- estimate_harvest_rate(design) # nolint: object_usage_linter
  total_harvest_est <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Verify estimate consistency (product of components)
  expected_estimate <- effort_est$estimates$estimate * hpue_est$estimates$estimate
  expect_equal(total_harvest_est$estimates$estimate, expected_estimate, tolerance = 1e-10)

  # Verify variance was propagated (SE should not be zero)
  expect_true(total_harvest_est$estimates$se > 0)
})

# Section dispatch fixtures and stubs (PROD-01, PROD-02) ----

#' Create 3-section creel_design for total harvest section tests
#'
#' Produces a creel_design with sections "North", "Central", "South" and
#' both counts and interview data (including harvest col) for all three
#' sections. 12-date calendar, 9 interviews per section. Data shape is
#' identical to the Phase 40 fixture make_3section_design_with_interviews().
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

  # 27 interviews: 9 per section, with catch and harvest columns
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
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

# PROD-01: Per-section rows for estimate_total_harvest ----

test_that("PROD-01-harvest: estimate_total_harvest on 3-section design returns a tibble with a section column", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_harvest(design) # nolint: object_usage_linter
  ))
  expect_true("section" %in% names(result$estimates))
})

test_that("PROD-01-harvest-rows: estimate_total_harvest returns 3 section rows (aggregate_sections=FALSE)", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_harvest(design, aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 3L)
})

# PROD-02: Lake total row for estimate_total_harvest ----

test_that("PROD-02-harvest-lake: aggregate_sections=TRUE appends .lake_total row (4 rows total for 3-section design)", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_harvest(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 4L)
  expect_true(".lake_total" %in% result$estimates$section)
})

test_that("PROD-02-harvest-sum: .lake_total$estimate equals sum of per-section estimates", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_harvest(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  section_rows <- result$estimates[result$estimates$section != ".lake_total", ]
  lake_row <- result$estimates[result$estimates$section == ".lake_total", ]
  expect_equal(lake_row$estimate, sum(section_rows$estimate), tolerance = 1e-10)
})

test_that("PROD-02-harvest-se: .lake_total$se equals sqrt(sum(se_i^2)) over present section rows", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_harvest(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  section_rows <- result$estimates[result$estimates$section != ".lake_total", ]
  lake_row <- result$estimates[result$estimates$section == ".lake_total", ]
  expected_se <- sqrt(sum(section_rows$se^2))
  expect_equal(lake_row$se, expected_se, tolerance = 1e-10)
})

test_that("PROD-02-harvest-prop: prop_of_lake_total for present sections sums to 1.0", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_harvest(design, aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_true("prop_of_lake_total" %in% names(result$estimates))
  expect_equal(sum(result$estimates$prop_of_lake_total), 1.0, tolerance = 1e-10)
})

# PROD-02-harvest-regression: Non-sectioned designs return identical results (regression guard) ----

test_that("PROD-02-harvest-regression: non-sectioned design returns same result as pre-Phase-41", {
  design_no_sections <- make_total_harvest_design() # nolint: object_usage_linter
  result <- estimate_total_harvest(design_no_sections) # nolint: object_usage_linter
  expect_s3_class(result, "creel_estimates")
  expect_false("section" %in% names(result$estimates))
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

# PROD-01-harvest-missing: Missing section inserts NA row with data_available=FALSE ----

#' Create 3-section harvest design with "South" absent from interview data
#'
#' Registered sections: "North", "Central", "South".
#' Interview data contains only "North" and "Central" rows — "South" absent.
make_3section_harvest_design_missing_south <- function() { # nolint: object_length_linter
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
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

test_that("PROD-01-harvest-missing: missing section inserts NA row with data_available=FALSE for estimate_total_harvest", { # nolint: line_length_linter
  design <- make_3section_harvest_design_missing_south() # nolint: object_usage_linter
  warns <- character(0)
  result <- withCallingHandlers(
    estimate_total_harvest(design, missing_sections = "warn"), # nolint: object_usage_linter
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
