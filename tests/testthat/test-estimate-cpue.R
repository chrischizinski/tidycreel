# Test helpers ----

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

#' Create test interview data with 32+ interviews (15+ per stratum)
make_test_interviews <- function() {
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

test_that("estimate_cpue returns creel_estimates class object", {
  design <- make_cpue_design()

  result <- estimate_cpue(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_cpue result has estimates tibble with correct columns", {
  design <- make_cpue_design()

  result <- estimate_cpue(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_cpue result method is 'ratio-of-means-cpue'", {
  design <- make_cpue_design()

  result <- estimate_cpue(design) # nolint: object_usage_linter

  expect_equal(result$method, "ratio-of-means-cpue")
})

test_that("estimate_cpue result variance_method is 'taylor' by default", {
  design <- make_cpue_design()

  result <- estimate_cpue(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_cpue result conf_level is 0.95 by default", {
  design <- make_cpue_design()

  result <- estimate_cpue(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_cpue estimate is a positive numeric value", {
  design <- make_cpue_design()

  result <- estimate_cpue(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

# Input validation tests ----

test_that("estimate_cpue errors when design is not creel_design", {
  fake_design <- list(interviews = data.frame(catch_total = 1:10, hours_fished = 1:10))

  expect_error(
    estimate_cpue(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_cpue errors when design has no interview_survey", {
  cal <- make_test_calendar_cpue()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    estimate_cpue(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_cpue errors for invalid variance method", {
  design <- make_cpue_design()

  expect_error(
    estimate_cpue(design, variance = "invalid"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

test_that("estimate_cpue errors when design missing catch_col/effort_col", {
  cal <- make_test_calendar_cpue()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Manually construct design with interviews but no catch_col/effort_col
  # (this simulates internal corruption, unlikely but testable)
  interviews <- make_test_interviews()
  design$interviews <- interviews
  design$interview_survey <- list(placeholder = TRUE) # fake survey object
  # deliberately omit catch_col and effort_col

  expect_error(
    estimate_cpue(design), # nolint: object_usage_linter
    "catch|effort"
  )
})

# Sample size validation tests ----

test_that("estimate_cpue errors when n < 10 ungrouped", {
  design <- make_small_cpue_design(5)

  expect_error(
    estimate_cpue(design), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimate_cpue warns when 10 <= n < 30 ungrouped", {
  design <- make_small_cpue_design(15)

  expect_warning(
    estimate_cpue(design), # nolint: object_usage_linter
    "30"
  )
})

test_that("estimate_cpue has no sample size warning when n >= 30 ungrouped", {
  design <- make_cpue_design() # has 32 interviews

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_cpue(design), # nolint: object_usage_linter
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for sample size warnings only
  sample_warnings <- grepl("sample|10|30", warnings, ignore.case = TRUE)

  expect_false(any(sample_warnings))
})

test_that("estimate_cpue errors when any group has n < 10 in grouped estimation", {
  design <- make_unbalanced_cpue_design() # weekend has only 5

  expect_error(
    estimate_cpue(design, by = day_type), # nolint: object_usage_linter
    "10"
  )
})

# Grouped estimation tests ----

test_that("estimate_cpue grouped by day_type returns creel_estimates with by_vars set", {
  design <- make_cpue_design()

  result <- estimate_cpue(design, by = day_type) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_cpue grouped result estimates tibble has day_type column", {
  design <- make_cpue_design()

  result <- estimate_cpue(design, by = day_type) # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_cpue grouped result has one row per group level", {
  design <- make_cpue_design()

  result <- estimate_cpue(design, by = day_type) # nolint: object_usage_linter

  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_cpue grouped result has n column reflecting per-group sample sizes", {
  design <- make_cpue_design()

  result <- estimate_cpue(design, by = day_type) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Reference tests ----

test_that("ungrouped CPUE matches manual svyratio calculation", {
  design <- make_cpue_design()

  # tidycreel estimate
  result <- estimate_cpue(design) # nolint: object_usage_linter

  # Manual survey::svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyratio(~catch_total, ~hours_fished, svy)
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

  # tidycreel grouped estimate
  result <- estimate_cpue(design, by = day_type) # nolint: object_usage_linter

  # Manual survey::svyby + svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyby(
    ~catch_total,
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

  # tidycreel estimate
  result <- estimate_cpue(design) # nolint: object_usage_linter

  # Manual survey::svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyratio(~catch_total, ~hours_fished, svy)
  manual_variance <- as.numeric(vcov(manual_result))

  expect_equal(result$estimates$se^2, manual_variance, tolerance = 1e-10)
})

# Custom confidence level test ----

test_that("estimate_cpue with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_cpue_design()

  result_95 <- estimate_cpue(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_cpue(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

# Variance method tests ----

test_that("estimate_cpue with variance = 'bootstrap' returns bootstrap variance_method", {
  design <- make_cpue_design()

  set.seed(12345)
  result <- estimate_cpue(design, variance = "bootstrap") # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
})

test_that("estimate_cpue with variance = 'jackknife' returns jackknife variance_method", {
  design <- make_cpue_design()

  result <- estimate_cpue(design, variance = "jackknife") # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
})

test_that("bootstrap and jackknife produce positive SE values", {
  design <- make_cpue_design()

  set.seed(12345)
  result_bootstrap <- estimate_cpue(design, variance = "bootstrap") # nolint: object_usage_linter
  result_jackknife <- estimate_cpue(design, variance = "jackknife") # nolint: object_usage_linter

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
  result <- estimate_cpue(design) # nolint: object_usage_linter

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
    estimate_cpue(design, by = day_type), # nolint: object_usage_linter
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
  result <- estimate_cpue(design) # nolint: object_usage_linter

  # Verify CPUE is in reasonable range (positive, finite, not extreme)
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate < 100) # Sanity check - CPUE shouldn't be absurdly high
})

# Zero-effort handling tests ----

test_that("estimate_cpue with zero-effort interviews issues warning and excludes them", {
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
    result <- estimate_cpue(design), # nolint: object_usage_linter
    "zero effort"
  )

  # Result should still be valid (using filtered data)
  expect_s3_class(result, "creel_estimates")
  expect_true(result$estimates$estimate > 0)
})

test_that("estimate_cpue with all-zero effort errors due to sample size threshold", {
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
    suppressWarnings(estimate_cpue(design)), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimate_cpue grouped with zero-effort interviews excludes them with warning", {
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
    result <- estimate_cpue(design, by = day_type), # nolint: object_usage_linter
    "zero effort"
  )

  # Result should still be valid with 2 groups
  expect_s3_class(result, "creel_estimates")
  expect_equal(nrow(result$estimates), 2)
  expect_true(all(result$estimates$estimate > 0))
})

# Grouped variance method test ----

test_that("estimate_cpue grouped by day_type with variance = 'bootstrap' works", {
  design <- make_cpue_design()

  set.seed(12345)
  result <- suppressWarnings( # nolint: object_usage_linter
    estimate_cpue(design, by = day_type, variance = "bootstrap") # nolint: object_usage_linter
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

  result <- estimate_cpue(design, estimator = "mor") # nolint: object_usage_linter

  # Should use only the 25 incomplete trips
  expect_equal(result$estimates$n, 25)
  expect_equal(result$method, "mean-of-ratios-cpue")
})

test_that("estimator='mor' produces valid estimates with SE and CI", {
  design <- make_mor_design(n_complete = 15, n_incomplete = 30)

  result <- estimate_cpue(design, estimator = "mor") # nolint: object_usage_linter

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
  result_taylor <- estimate_cpue(design, estimator = "mor", variance = "taylor") # nolint: object_usage_linter
  expect_equal(result_taylor$variance_method, "taylor")
  expect_true(is.numeric(result_taylor$estimates$estimate))

  # Test bootstrap
  set.seed(12345)
  result_bootstrap <- estimate_cpue(design, estimator = "mor", variance = "bootstrap") # nolint: object_usage_linter
  expect_equal(result_bootstrap$variance_method, "bootstrap")
  expect_true(is.numeric(result_bootstrap$estimates$estimate))

  # Test jackknife
  result_jackknife <- estimate_cpue(design, estimator = "mor", variance = "jackknife") # nolint: object_usage_linter
  expect_equal(result_jackknife$variance_method, "jackknife")
  expect_true(is.numeric(result_jackknife$estimates$estimate))
})

test_that("estimator='mor' supports grouped estimation", {
  design <- make_mor_grouped_design()

  result <- estimate_cpue(design, by = day_type, estimator = "mor") # nolint: object_usage_linter

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

  # Should error about missing trip_status
  expect_error(
    estimate_cpue(design, estimator = "mor"), # nolint: object_usage_linter
    "trip_status"
  )
})

test_that("error when estimator='mor' with no incomplete trips", {
  # Design with ONLY complete trips
  design <- make_mor_design(n_complete = 30, n_incomplete = 0)

  expect_error(
    estimate_cpue(design, estimator = "mor"), # nolint: object_usage_linter
    "incomplete"
  )
})

test_that("error when estimator='mor' with complete trips in data but 0 incomplete", {
  # Mix design but all trips are complete
  design <- make_mor_design(n_complete = 40, n_incomplete = 0)

  expect_error(
    estimate_cpue(design, estimator = "mor"), # nolint: object_usage_linter
    "incomplete"
  )
})

test_that("estimator='mor' sample size validation: error when n<10", {
  # Design with only 8 incomplete trips
  design <- make_mor_design(n_complete = 20, n_incomplete = 8)

  expect_error(
    estimate_cpue(design, estimator = "mor"), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimator='mor' sample size validation: warning when 10<=n<30", {
  # Design with exactly 15 incomplete trips
  design <- make_mor_design(n_complete = 10, n_incomplete = 15)

  expect_warning(
    estimate_cpue(design, estimator = "mor"), # nolint: object_usage_linter
    "30"
  )
})

test_that("estimator='mor' sample size validation: no warning when n>=30", {
  # Design with 35 incomplete trips
  design <- make_mor_design(n_complete = 10, n_incomplete = 35)

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_cpue(design, estimator = "mor"), # nolint: object_usage_linter
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for sample size warnings only
  sample_warnings <- grepl("sample|10|30", warnings, ignore.case = TRUE)

  expect_false(any(sample_warnings))
})

# Reference test ----

test_that("estimator='mor' matches manual survey::svymean calculation", {
  # Create design with known incomplete trip data
  design <- make_mor_design(n_complete = 15, n_incomplete = 30)

  # tidycreel MOR estimate
  result <- estimate_cpue(design, estimator = "mor") # nolint: object_usage_linter

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
    estimate_cpue(design, estimator = "mor"),
    "MOR estimator.*incomplete trips"
  )

  # Second call ALSO warns (not once-per-session)
  expect_warning(
    estimate_cpue(design, estimator = "mor"),
    "MOR estimator.*incomplete trips"
  )
})

test_that("MOR warning includes trip counts", {
  design <- make_small_cpue_design(n = 40, n_incomplete = 25)

  expect_warning(
    estimate_cpue(design, estimator = "mor"),
    "n=25.*40 total"
  )
})

test_that("MOR warning emphasizes complete trip preference", {
  design <- make_small_cpue_design(n = 30, n_incomplete = 30)

  expect_warning(
    result <- estimate_cpue(design, estimator = "mor"),
    "Complete trips preferred"
  )
})

test_that("MOR warning references validation function", {
  design <- make_small_cpue_design(n = 30, n_incomplete = 30)

  expect_warning(
    estimate_cpue(design, estimator = "mor"),
    "validate_incomplete_trips"
  )
})
