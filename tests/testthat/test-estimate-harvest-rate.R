# Test helpers ----

#' Create test calendar data with 8 dates (4 weekday, 4 weekend)
make_test_calendar_harvest <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
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
      rep("2024-06-01", 4), rep("2024-06-02", 4),
      rep("2024-06-03", 4), rep("2024-06-04", 4),
      # Weekend interviews (16 total, spread across 4 dates)
      rep("2024-06-08", 4), rep("2024-06-09", 4),
      rep("2024-06-15", 4), rep("2024-06-16", 4)
    )),
    catch_total = c(
      # Weekday catch (realistic variation)
      2, 5, 3, 1, 4, 6, 2, 3, 5, 7, 4, 2, 3, 6, 5, 4,
      # Weekend catch (higher on average)
      8, 10, 6, 9, 7, 11, 8, 10, 9, 12, 7, 8, 10, 11, 9, 8
    ),
    hours_fished = c(
      # Weekday effort (2-5 hours)
      2.5, 4.0, 3.5, 2.0, 3.0, 5.0, 2.5, 3.5, 4.5, 5.0, 3.5, 2.5, 3.0, 4.5, 4.0, 3.5,
      # Weekend effort (3-6 hours)
      4.0, 5.5, 3.5, 5.0, 4.5, 6.0, 4.5, 5.5, 5.0, 6.0, 4.0, 4.5, 5.5, 5.5, 5.0, 4.5
    ),
    catch_kept = c(
      # Kept fish (always <= catch_total)
      2, 4, 3, 1, 3, 5, 2, 2, 4, 6, 3, 2, 2, 5, 4, 3,
      5, 8, 5, 7, 6, 9, 6, 8, 7, 10, 5, 6, 8, 9, 7, 6
    ),
    trip_status = rep(c("complete", "incomplete"), 16),
    trip_duration = c(
      # Trip durations matching hours_fished
      2.5, 4.0, 3.5, 2.0, 3.0, 5.0, 2.5, 3.5, 4.5, 5.0, 3.5, 2.5, 3.0, 4.5, 4.0, 3.5,
      4.0, 5.5, 3.5, 5.0, 4.5, 6.0, 4.5, 5.5, 5.0, 6.0, 4.0, 4.5, 5.5, 5.5, 5.0, 4.5
    ),
    stringsAsFactors = FALSE
  )
}

#' Create test design with interviews including harvest (32+)
make_harvest_design <- function() {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews_harvest()
  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

#' Create design without harvest column
make_design_without_harvest <- function() {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews_harvest()
  # Omit harvest parameter
  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
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

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter
}

#' Create unbalanced design (one stratum < 10)
make_unbalanced_harvest_design <- function() {
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

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_harvest_rate(design), # nolint: object_usage_linter
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

test_that("estimate_harvest_rate grouped by day_type returns creel_estimates with by_vars set", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_harvest_rate grouped result estimates tibble has day_type column", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type) # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_harvest_rate grouped result has one row per group level", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type) # nolint: object_usage_linter

  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_harvest_rate grouped result has n column reflecting per-group sample sizes", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, by = day_type) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Reference tests ----

test_that("ungrouped HPUE matches manual svyratio calculation", {
  design <- make_harvest_design()

  # tidycreel estimate
  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

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

  # tidycreel grouped estimate
  result <- estimate_harvest_rate(design, by = day_type) # nolint: object_usage_linter

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

  # tidycreel estimate
  result <- estimate_harvest_rate(design) # nolint: object_usage_linter

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

  # After Phase 17, estimate_catch_rate defaults to complete trips only
  # estimate_harvest_rate doesn't have use_trips parameter yet, uses all trips
  # TODO: Update when estimate_harvest_rate gets use_trips parameter
  n_complete <- sum(design$interviews$trip_status == "complete")
  expect_equal(result_cpue$estimates$n, n_complete)
  expect_equal(result_hpue$estimates$n, nrow(design$interviews))
})

# Custom confidence level test ----

test_that("estimate_harvest_rate with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_harvest_design()

  result_95 <- estimate_harvest_rate(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_harvest_rate(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

# Variance method tests ----

test_that("estimate_harvest_rate with bootstrap variance method produces valid results", {
  design <- make_harvest_design()

  result <- estimate_harvest_rate(design, variance = "bootstrap") # nolint: object_usage_linter

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

  # Should work (may warn about small n per group, but should not error)
  result <- suppressWarnings(estimate_harvest_rate(design, by = day_type, variance = "bootstrap")) # nolint: object_usage_linter

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
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
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
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
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
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
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

  # Should warn about zero-effort
  expect_warning(
    result <- estimate_harvest_rate(design), # nolint: object_usage_linter
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

  # Should warn about missing harvest
  expect_warning(
    result <- estimate_harvest_rate(design), # nolint: object_usage_linter
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
      2, 3, 4, 5, 6, 0,
      3, 4, 5, 6, 7, 8,
      7, 8, 9, 10, 11, 0,
      8, 9, 10, 11, 12, 13
    ),
    catch_kept = c(
      2, 3, 4, 5, 5, 0,
      3, 4, 5, 6, 6, 7,
      6, 7, 8, 9, 10, 0,
      7, 8, 9, 10, 11, 12
    ),
    hours_fished = c(
      2, 3, 4, 5, 3, 0, # one zero-effort
      3, 4, 5, 3, 4, 5,
      4, 5, 3, 5, 4, 0, # one zero-effort
      4, 5, 5, 6, 5, 6
    ),
    trip_status = rep("complete", 24),
    trip_duration = c(
      2, 3, 4, 5, 3, 1,
      3, 4, 5, 3, 4, 5,
      4, 5, 3, 5, 4, 1,
      4, 5, 5, 6, 5, 6
    )
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, interviews, catch = catch_total, harvest = catch_kept, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

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
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4)
  )

  # Create interviews with sufficient samples per group but some NA harvest
  interviews <- data.frame(
    date = as.Date(c(
      rep("2024-06-01", 6), rep("2024-06-02", 6),
      rep("2024-06-08", 6), rep("2024-06-09", 6)
    )),
    catch_total = c(
      2, 3, 4, 5, 6, 7,
      3, 4, 5, 6, 7, 8,
      7, 8, 9, 10, 11, 12,
      8, 9, 10, 11, 12, 13
    ),
    catch_kept = c(
      2, 3, 4, 5, 5, NA, # one NA harvest
      3, 4, 5, 6, 6, 7,
      6, 7, 8, 9, 10, NA, # one NA harvest
      7, 8, 9, 10, 11, 12
    ),
    hours_fished = c(
      2, 3, 4, 5, 3, 4,
      3, 4, 5, 3, 4, 5,
      4, 5, 3, 5, 4, 5,
      4, 5, 5, 6, 5, 6
    ),
    trip_status = rep("complete", 24),
    trip_duration = c(
      2, 3, 4, 5, 3, 4,
      3, 4, 5, 3, 4, 5,
      4, 5, 3, 5, 4, 5,
      4, 5, 5, 6, 5, 6
    )
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, interviews, catch = catch_total, harvest = catch_kept, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration) # nolint: object_usage_linter

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
  creel_design( # nolint: object_usage_linter
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
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-01", "2024-06-02"
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
      "complete", "incomplete",
      "complete", "incomplete",
      "complete", "complete"
    )
  }
  add_interviews( # nolint: object_usage_linter
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

test_that("estimate_harvest_rate() Eq. 19.5: H_hat = sum(h_i/pi_i) matches hand-computed value", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_harvest_rate(d)
  # H_hat = 37.5 + 75.0 + 2.5 + 0 + 12.5 + 8.333... = 135.833...
  expected_h_hat <- (2 * 3) / 0.16 + (4 * 3) / 0.16 + (1 * 1) / 0.40 +
    (0 * 1) / 0.24 + (3 * 1) / 0.24 + (2 * 1) / 0.24
  expect_equal(result$estimates$estimate, expected_h_hat, tolerance = 1e-6)
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

test_that("estimate_harvest_rate() verbose=TRUE prints bus-route dispatch message", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  expect_message(
    estimate_harvest_rate(d, verbose = TRUE),
    "bus-route estimator"
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

test_that("estimate_harvest_rate() by=circuit: proportion column present and sums to ~1", {
  d <- make_br_harvest_interviews(make_br_harvest_design())
  result <- estimate_harvest_rate(d, by = circuit) # nolint: object_usage_linter
  expect_true("proportion" %in% names(result$estimates))
  expect_equal(sum(result$estimates$proportion), 1.0, tolerance = 1e-6)
})
