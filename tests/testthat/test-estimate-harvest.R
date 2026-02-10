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
    stringsAsFactors = FALSE
  )
}

#' Create test design with interviews including harvest (32+)
make_harvest_design <- function() {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews_harvest()
  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept) # nolint: object_usage_linter
}

#' Create design without harvest column
make_design_without_harvest <- function() {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  interviews <- make_test_interviews_harvest()
  # Omit harvest parameter
  add_interviews(design, interviews, catch = catch_total, effort = hours_fished) # nolint: object_usage_linter
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
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept) # nolint: object_usage_linter
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
    stringsAsFactors = FALSE
  )

  add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept) # nolint: object_usage_linter
}

# Basic behavior tests ----

test_that("estimate_harvest returns creel_estimates class object", {
  design <- make_harvest_design()

  result <- estimate_harvest(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_harvest result has estimates tibble with correct columns", {
  design <- make_harvest_design()

  result <- estimate_harvest(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_harvest result method is 'ratio-of-means-hpue'", {
  design <- make_harvest_design()

  result <- estimate_harvest(design) # nolint: object_usage_linter

  expect_equal(result$method, "ratio-of-means-hpue")
})

test_that("estimate_harvest result variance_method is 'taylor' by default", {
  design <- make_harvest_design()

  result <- estimate_harvest(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_harvest result conf_level is 0.95 by default", {
  design <- make_harvest_design()

  result <- estimate_harvest(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_harvest estimate is a positive numeric value", {
  design <- make_harvest_design()

  result <- estimate_harvest(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_harvest errors when design is not creel_design", {
  fake_design <- list(interviews = data.frame(catch_kept = 1:10, hours_fished = 1:10))

  expect_error(
    estimate_harvest(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_harvest errors when design has no interview_survey", {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    estimate_harvest(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_harvest errors for invalid variance method", {
  design <- make_harvest_design()

  expect_error(
    estimate_harvest(design, variance = "invalid"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

test_that("estimate_harvest errors when design missing effort_col", {
  cal <- make_test_calendar_harvest()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Manually construct design with interviews but no effort_col
  interviews <- make_test_interviews_harvest()
  design$interviews <- interviews
  design$interview_survey <- list(placeholder = TRUE) # fake survey object
  design$harvest_col <- "catch_kept"
  # deliberately omit effort_col

  expect_error(
    estimate_harvest(design), # nolint: object_usage_linter
    "effort"
  )
})

test_that("estimate_harvest errors when design has no harvest_col", {
  design <- make_design_without_harvest()

  expect_error(
    estimate_harvest(design), # nolint: object_usage_linter
    "harvest"
  )
})

# Sample size validation tests ----

test_that("estimate_harvest errors when n < 10 ungrouped", {
  design <- make_small_harvest_design(5)

  expect_error(
    estimate_harvest(design), # nolint: object_usage_linter
    "10"
  )
})

test_that("estimate_harvest warns when 10 <= n < 30 ungrouped", {
  design <- make_small_harvest_design(15)

  expect_warning(
    estimate_harvest(design), # nolint: object_usage_linter
    "30"
  )
})

test_that("estimate_harvest has no sample size warning when n >= 30 ungrouped", {
  design <- make_harvest_design() # has 32 interviews

  # Capture warnings
  warnings <- character()
  result <- withCallingHandlers(
    estimate_harvest(design), # nolint: object_usage_linter
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
    }
  )

  # Filter for sample size warnings only
  sample_warnings <- grepl("sample|10|30", warnings, ignore.case = TRUE)

  expect_false(any(sample_warnings))
})

test_that("estimate_harvest errors when any group has n < 10 in grouped estimation", {
  design <- make_unbalanced_harvest_design() # weekend has only 5

  expect_error(
    estimate_harvest(design, by = day_type), # nolint: object_usage_linter
    "10"
  )
})

# Grouped estimation tests ----

test_that("estimate_harvest grouped by day_type returns creel_estimates with by_vars set", {
  design <- make_harvest_design()

  result <- estimate_harvest(design, by = day_type) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_harvest grouped result estimates tibble has day_type column", {
  design <- make_harvest_design()

  result <- estimate_harvest(design, by = day_type) # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_harvest grouped result has one row per group level", {
  design <- make_harvest_design()

  result <- estimate_harvest(design, by = day_type) # nolint: object_usage_linter

  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_harvest grouped result has n column reflecting per-group sample sizes", {
  design <- make_harvest_design()

  result <- estimate_harvest(design, by = day_type) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$interviews))
  expect_true(all(result$estimates$n > 0))
})

# Reference tests ----

test_that("ungrouped HPUE matches manual svyratio calculation", {
  design <- make_harvest_design()

  # tidycreel estimate
  result <- estimate_harvest(design) # nolint: object_usage_linter

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
  result <- estimate_harvest(design, by = day_type) # nolint: object_usage_linter

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
  result <- estimate_harvest(design) # nolint: object_usage_linter

  # Manual survey::svyratio calculation
  svy <- design$interview_survey
  manual_result <- survey::svyratio(~catch_kept, ~hours_fished, svy)
  manual_variance <- as.numeric(vcov(manual_result))

  expect_equal(result$estimates$se^2, manual_variance, tolerance = 1e-10)
})

# HPUE vs CPUE relationship tests ----

test_that("HPUE estimate <= CPUE estimate (harvest is subset of catch)", {
  design <- make_harvest_design()

  result_hpue <- estimate_harvest(design) # nolint: object_usage_linter
  result_cpue <- estimate_cpue(design) # nolint: object_usage_linter

  # HPUE should be <= CPUE since harvest <= catch
  expect_true(result_hpue$estimates$estimate <= result_cpue$estimates$estimate)
})

test_that("HPUE and CPUE use same n (sample size should match)", {
  design <- make_harvest_design()

  result_hpue <- estimate_harvest(design) # nolint: object_usage_linter
  result_cpue <- estimate_cpue(design) # nolint: object_usage_linter

  expect_equal(result_hpue$estimates$n, result_cpue$estimates$n)
})

# Custom confidence level test ----

test_that("estimate_harvest with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_harvest_design()

  result_95 <- estimate_harvest(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_harvest(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})
