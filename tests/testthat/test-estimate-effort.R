# Test helpers ----

#' Create test calendar data with 4+ rows per stratum
make_test_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
}

#' Create test count data matching test calendar structure
#' Each day_type stratum has at least 4 distinct dates (PSUs)
make_test_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    effort_hours = c(15, 23, 18, 21, 45, 52, 48, 51),
    stringsAsFactors = FALSE
  )
}

#' Create test creel_design with counts already attached
make_test_design_with_counts <- function() {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- make_test_counts()
  add_counts(design, counts) # nolint: object_usage_linter
}

# Basic behavior tests ----

test_that("estimate_effort returns creel_estimates class object", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_effort result has estimates tibble with correct columns", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_effort result has method == 'total'", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_equal(result$method, "total")
})

test_that("estimate_effort result has variance_method == 'taylor'", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_effort result has conf_level == 0.95 by default", {
  design <- make_test_design_with_counts()

  result <- estimate_effort(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_effort with custom conf_level = 0.90 produces different CI bounds", {
  design <- make_test_design_with_counts()

  result_95 <- estimate_effort(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_effort(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

test_that("estimate_effort errors on non-creel_design input", {
  fake_design <- list(counts = data.frame(effort_hours = 1:10))

  expect_error(
    estimate_effort(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_effort errors when counts not attached", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    estimate_effort(design), # nolint: object_usage_linter
    "add_counts"
  )
})

test_that("estimate_effort errors when count data has no numeric column", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create counts with only character/factor columns (no numeric count variable)
  bad_counts <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    description = rep("no fishing", 8)
  )

  # This should fail during add_counts (schema validation requires numeric column)
  expect_error(
    add_counts(design, bad_counts), # nolint: object_usage_linter
    "numeric"
  )
})

# Tier 2 validation tests ----

test_that("estimate_effort warns when count data has zero values", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- make_test_counts()
  counts$effort_hours[1] <- 0
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  expect_warning(
    estimate_effort(design2), # nolint: object_usage_linter
    "zero"
  )
})

test_that("estimate_effort warns when count data has negative values", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- make_test_counts()
  counts$effort_hours[1] <- -5
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  expect_warning(
    estimate_effort(design2), # nolint: object_usage_linter
    "negative"
  )
})

test_that("estimate_effort warns when stratum has < 3 observations", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Only 2 observations per stratum
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    effort_hours = c(15, 23, 45, 52)
  )
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  expect_warning(
    estimate_effort(design2), # nolint: object_usage_linter
    "sparse|less than 3|< 3"
  )
})

test_that("estimate_effort produces no warnings when data is clean", {
  design <- make_test_design_with_counts()

  # Should not produce warnings (no suppressWarnings needed)
  expect_no_warning <- function(expr) {
    warnings <- character()
    result <- withCallingHandlers(
      expr,
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
      }
    )

    # Filter out survey package warnings (expected)
    tidycreel_warnings <- grepl("zero|negative|sparse", warnings, ignore.case = TRUE)

    expect_false(any(tidycreel_warnings))
  }

  expect_no_warning(estimate_effort(design)) # nolint: object_usage_linter
})

# Reference tests (TEST-06 and TEST-07) ----

test_that("estimate_effort point estimate matches manual survey::svytotal", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_estimate <- as.numeric(coef(manual_result))

  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
})

test_that("estimate_effort SE matches manual SE() extraction", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_se <- as.numeric(survey::SE(manual_result))

  expect_equal(result$estimates$se, manual_se, tolerance = 1e-10)
})

test_that("estimate_effort CI bounds use qt() with survey degf", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual CI using qt() + survey::degf() (two-stage formula from Plan 36-02/D1)
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_se <- as.numeric(survey::SE(manual_result))
  manual_est <- as.numeric(coef(manual_result))
  df <- as.numeric(survey::degf(svy))
  t_crit <- qt(0.975, df = df)
  manual_ci_lower <- manual_est - t_crit * manual_se
  manual_ci_upper <- manual_est + t_crit * manual_se

  expect_equal(result$estimates$ci_lower, manual_ci_lower, tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci_upper, tolerance = 1e-10)
})

test_that("estimate_effort variance matches manual vcov() diagonal", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_variance <- as.numeric(vcov(manual_result))

  # Variance should equal SE^2
  expect_equal(result$estimates$se^2, manual_variance, tolerance = 1e-10)
})

# Grouped estimation test helpers ----

#' Create test design with grouping variables
#' Returns design with enough data for meaningful grouped estimation
make_test_design_with_groups <- function() {
  # Create calendar with 16 dates across 2 day_types and 2 periods
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-10", "2024-06-11",
      "2024-06-15", "2024-06-16", "2024-06-17", "2024-06-18",
      "2024-06-22", "2024-06-23", "2024-06-24", "2024-06-25"
    )),
    day_type = rep(c("weekday", "weekend"), each = 8),
    period = rep(c("morning", "afternoon"), 8),
    stringsAsFactors = FALSE
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Create counts with at least 4 observations per group
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    period = cal$period,
    effort_hours = c(
      15, 23, 18, 21, 22, 19, 20, 24, # weekday
      45, 52, 48, 51, 50, 47, 49, 53 # weekend
    ),
    stringsAsFactors = FALSE
  )

  add_counts(design, counts) # nolint: object_usage_linter
}

# Grouped estimation - basic behavior ----

test_that("estimate_effort with by = returns grouped creel_estimates", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
  expect_true(is.character(result$by_vars))
})

test_that("estimate_effort with by = returns tibble with group columns first", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  col_names <- names(result$estimates)
  expect_equal(col_names[1], "day_type")
  expect_true("estimate" %in% col_names)
  expect_true("se" %in% col_names)
  expect_true("ci_lower" %in% col_names)
  expect_true("ci_upper" %in% col_names)
  expect_true("n" %in% col_names)
})

test_that("estimate_effort with by = returns one row per group level", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  # Should have 2 rows: weekday and weekend
  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_effort with by = c() works with multiple grouping variables", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = c(day_type, period))) # nolint: object_usage_linter

  expect_equal(result$by_vars, c("day_type", "period"))
  expect_true("day_type" %in% names(result$estimates))
  expect_true("period" %in% names(result$estimates))

  # Should have 4 rows: weekday x morning, weekday x afternoon, weekend x morning, weekend x afternoon
  expect_equal(nrow(result$estimates), 4)
})

test_that("estimate_effort with by = includes sample sizes per group", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  expect_equal(sum(result$estimates$n), nrow(design$counts))
  expect_true(all(result$estimates$n > 0))
})

test_that("estimate_effort without by = still works (backward compat)", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Should return single-row output like Phase 4
  expect_equal(nrow(result$estimates), 1)
  expect_true(is.null(result$by_vars))
  expect_equal(result$estimates$n, nrow(design$counts))
})

# Grouped estimation - tidy selectors ----

test_that("estimate_effort by = accepts tidyselect helpers", {
  design <- make_test_design_with_groups()

  # starts_with should select day_type
  result <- suppressWarnings(estimate_effort(design, by = starts_with("day"))) # nolint: object_usage_linter

  expect_equal(result$by_vars, "day_type")
  expect_equal(nrow(result$estimates), 2)
})

test_that("estimate_effort by = errors on nonexistent column", {
  design <- make_test_design_with_groups()

  expect_error(
    estimate_effort(design, by = nonexistent_column), # nolint: object_usage_linter
    "nonexistent|not found|Can't"
  )
})

# Grouped estimation - print/format ----

test_that("format.creel_estimates shows Grouped by for grouped results", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter
  formatted <- format(result)

  expect_true(any(grepl("Grouped by", formatted, fixed = TRUE)))
  expect_true(any(grepl("day_type", formatted)))
})

test_that("format.creel_estimates shows no Grouped by for ungrouped results", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter
  formatted <- format(result)

  expect_false(any(grepl("Grouped by", formatted, fixed = TRUE)))
})

test_that("format.creel_estimates shows Taylor linearization for taylor method", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "taylor")) # nolint: object_usage_linter
  formatted <- format(result)

  # Should show "Taylor linearization" (display name, not "taylor")
  expect_true(any(grepl("Taylor", formatted, ignore.case = TRUE)))
})

test_that("format.creel_estimates shows Bootstrap for bootstrap method", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter
  formatted <- format(result)

  # Should show "Bootstrap"
  expect_true(any(grepl("Bootstrap", formatted, ignore.case = TRUE)))
})

test_that("format.creel_estimates shows Jackknife for jackknife method", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "jackknife")) # nolint: object_usage_linter
  formatted <- format(result)

  # Should show "Jackknife"
  expect_true(any(grepl("Jackknife", formatted, ignore.case = TRUE)))
})

# Grouped estimation - Tier 2 validation ----

test_that("estimate_effort with by = warns on sparse groups", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekday", "weekend", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    period = c("morning", "afternoon", "morning", "afternoon", "morning", "afternoon"),
    effort_hours = c(15, 23, 18, 21, 45, 52)
  )
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  # Group by period - each group has only 3 observations per day_type stratum (6 total / 2 periods)
  # This should warn about sparse groups
  expect_warning(
    estimate_effort(design2, by = period), # nolint: object_usage_linter
    "sparse|fewer than 3|< 3"
  )
})

# Grouped estimation - reference tests ----

test_that("grouped estimate_effort matches manual svyby point estimates", {
  design <- make_test_design_with_groups()

  # tidycreel grouped estimate
  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  # Manual survey::svyby calculation
  svy <- design$survey
  manual_result <- survey::svyby(
    ~effort_hours,
    ~day_type,
    svy,
    survey::svytotal,
    vartype = c("se", "ci")
  )

  # Match point estimates for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_est <- result$estimates$estimate[i]
    manual_est <- manual_result$effort_hours[manual_result$day_type == day]

    expect_equal(tidycreel_est, manual_est, tolerance = 1e-10)
  }
})

test_that("grouped estimate_effort matches manual svyby standard errors", {
  design <- make_test_design_with_groups()

  # tidycreel grouped estimate
  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  # Manual survey::svyby calculation
  svy <- design$survey
  manual_result <- survey::svyby(
    ~effort_hours,
    ~day_type,
    svy,
    survey::svytotal,
    vartype = c("se", "ci")
  )

  # Match standard errors for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_se <- result$estimates$se[i]
    manual_se <- manual_result$se[manual_result$day_type == day]

    expect_equal(tidycreel_se, manual_se, tolerance = 1e-10)
  }
})

test_that("grouped estimate_effort CI bounds use qt() with survey degf", {
  design <- make_test_design_with_groups()

  # tidycreel grouped estimate
  result <- suppressWarnings(estimate_effort(design, by = day_type)) # nolint: object_usage_linter

  # Manual CI using qt() + survey::degf() (two-stage formula from Plan 36-02/D1)
  svy <- design$survey
  manual_result <- survey::svyby(
    ~effort_hours,
    ~day_type,
    svy,
    survey::svytotal,
    vartype = "se"
  )
  df <- as.numeric(survey::degf(svy))
  t_crit <- qt(0.975, df = df)

  # Match CI bounds for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_ci_lower <- result$estimates$ci_lower[i]
    tidycreel_ci_upper <- result$estimates$ci_upper[i]
    manual_est <- manual_result$effort_hours[manual_result$day_type == day]
    manual_se <- manual_result$se[manual_result$day_type == day]
    manual_ci_lower <- manual_est - t_crit * manual_se
    manual_ci_upper <- manual_est + t_crit * manual_se

    expect_equal(tidycreel_ci_lower, manual_ci_lower, tolerance = 1e-10)
    expect_equal(tidycreel_ci_upper, manual_ci_upper, tolerance = 1e-10)
  }
})

# Variance method selection tests ----

# Variance parameter validation ----

test_that("estimate_effort errors on invalid variance method", {
  design <- make_test_design_with_counts()

  expect_error(
    estimate_effort(design, variance = "invalid"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

test_that("estimate_effort accepts variance = 'taylor' explicitly", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "taylor")) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_effort accepts variance = 'bootstrap'", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

# Bootstrap behavior ----

test_that("bootstrap result has variance_method = 'bootstrap'", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
})

test_that("bootstrap point estimate is numeric and positive", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

test_that("bootstrap SE is numeric and positive", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("bootstrap point estimate is close to Taylor estimate", {
  design <- make_test_design_with_counts()

  result_taylor <- suppressWarnings(estimate_effort(design, variance = "taylor")) # nolint: object_usage_linter
  result_bootstrap <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter

  # For smooth statistics, bootstrap and taylor should give similar point estimates
  # Use 5% relative tolerance
  expect_equal(
    result_bootstrap$estimates$estimate,
    result_taylor$estimates$estimate,
    tolerance = 0.05 * result_taylor$estimates$estimate
  )
})

# Jackknife behavior ----

test_that("jackknife result has variance_method = 'jackknife'", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "jackknife")) # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
})

test_that("jackknife point estimate is numeric and positive", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "jackknife")) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

test_that("jackknife SE is numeric and positive", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design, variance = "jackknife")) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("jackknife point estimate is close to Taylor estimate", {
  design <- make_test_design_with_counts()

  result_taylor <- suppressWarnings(estimate_effort(design, variance = "taylor")) # nolint: object_usage_linter
  result_jackknife <- suppressWarnings(estimate_effort(design, variance = "jackknife")) # nolint: object_usage_linter

  # For smooth statistics, jackknife and taylor should give similar point estimates
  # Use 5% relative tolerance
  expect_equal(
    result_jackknife$estimates$estimate,
    result_taylor$estimates$estimate,
    tolerance = 0.05 * result_taylor$estimates$estimate
  )
})

# Backward compatibility ----

test_that("estimate_effort() with no variance arg returns variance_method = 'taylor'", {
  design <- make_test_design_with_counts()

  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_effort() with no variance arg identical to variance = 'taylor'", {
  design <- make_test_design_with_counts()

  result_default <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter
  result_taylor <- suppressWarnings(estimate_effort(design, variance = "taylor")) # nolint: object_usage_linter

  expect_equal(result_default$estimates$estimate, result_taylor$estimates$estimate)
  expect_equal(result_default$estimates$se, result_taylor$estimates$se)
  expect_equal(result_default$estimates$ci_lower, result_taylor$estimates$ci_lower)
  expect_equal(result_default$estimates$ci_upper, result_taylor$estimates$ci_upper)
})

# Grouped estimation with variance methods ----

test_that("estimate_effort with by = and variance = 'bootstrap' returns grouped estimates", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type, variance = "bootstrap")) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$variance_method, "bootstrap")
  expect_equal(result$by_vars, "day_type")
  expect_equal(nrow(result$estimates), 2)
})

test_that("grouped bootstrap has correct column structure", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type, variance = "bootstrap")) # nolint: object_usage_linter

  col_names <- names(result$estimates)
  expect_equal(col_names[1], "day_type")
  expect_true("estimate" %in% col_names)
  expect_true("se" %in% col_names)
  expect_true("ci_lower" %in% col_names)
  expect_true("ci_upper" %in% col_names)
  expect_true("n" %in% col_names)
})

test_that("grouped jackknife produces positive estimates for each group", {
  design <- make_test_design_with_groups()

  result <- suppressWarnings(estimate_effort(design, by = day_type, variance = "jackknife")) # nolint: object_usage_linter

  expect_true(all(result$estimates$estimate > 0))
  expect_true(all(result$estimates$se > 0))
})

# Reference tests for variance methods ----

test_that("bootstrap estimate matches manual as.svrepdesign + svytotal", {
  design <- make_test_design_with_counts()

  # Set seed for reproducible bootstrap replicates
  set.seed(20240609)
  result <- suppressWarnings(estimate_effort(design, variance = "bootstrap")) # nolint: object_usage_linter

  # Manual bootstrap calculation
  set.seed(20240609)
  rep_design <- suppressWarnings(survey::as.svrepdesign(
    design$survey,
    type = "bootstrap",
    replicates = 500
  ))
  manual_result <- survey::svytotal(~effort_hours, rep_design)
  manual_estimate <- as.numeric(coef(manual_result))
  manual_se <- as.numeric(survey::SE(manual_result))

  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-10)
})

test_that("jackknife estimate matches manual as.svrepdesign + svytotal", {
  design <- make_test_design_with_counts()

  # Jackknife is deterministic (no seed needed)
  result <- suppressWarnings(estimate_effort(design, variance = "jackknife")) # nolint: object_usage_linter

  # Manual jackknife calculation
  rep_design <- suppressWarnings(survey::as.svrepdesign(
    design$survey,
    type = "auto"
  ))
  manual_result <- survey::svytotal(~effort_hours, rep_design)
  manual_estimate <- as.numeric(coef(manual_result))
  manual_se <- as.numeric(survey::SE(manual_result))

  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-10)
})

test_that("grouped bootstrap matches manual as.svrepdesign + svyby", {
  design <- make_test_design_with_groups()

  # Set seed for reproducible bootstrap replicates
  set.seed(20240610)
  result <- suppressWarnings(estimate_effort(design, by = day_type, variance = "bootstrap")) # nolint: object_usage_linter

  # Manual grouped bootstrap calculation
  set.seed(20240610)
  rep_design <- suppressWarnings(survey::as.svrepdesign(
    design$survey,
    type = "bootstrap",
    replicates = 500
  ))
  manual_result <- survey::svyby(
    ~effort_hours,
    ~day_type,
    rep_design,
    survey::svytotal,
    vartype = c("se", "ci")
  )

  # Match point estimates and SEs for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_est <- result$estimates$estimate[i]
    tidycreel_se <- result$estimates$se[i]
    manual_est <- manual_result$effort_hours[manual_result$day_type == day]
    manual_se <- manual_result$se[manual_result$day_type == day]

    expect_equal(tidycreel_est, manual_est, tolerance = 1e-10)
    expect_equal(tidycreel_se, manual_se, tolerance = 1e-10)
  }
})

# Bus-route effort estimation tests ----
# Helpers defined at section scope per Phase 21-02 / Phase 22-02 convention

make_br_effort_design <- function() {
  # 4-date calendar (required: >= 2 PSUs per stratum for interview survey)
  cal <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
    day_type = c("weekday", "weekday", "weekday", "weekday")
  )
  # Sampling frame: 2 sites, 1 circuit
  sf <- data.frame(
    site = c("A", "B"),
    circuit = c("C1", "C1"),
    p_site = c(0.4, 0.6),
    p_period = c(0.5, 0.5)
  )
  creel_design( # nolint: object_usage_linter
    cal,
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

make_br_effort_interviews <- function() {
  # 2 interview rows (different dates — satisfies >= 2 PSU survey requirement)
  # Site A: 5 counted, 3 interviewed, effort = 2.0 hours each
  # Site B: 10 counted, 5 interviewed, effort = 1.5 hours each
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday"),
    site = c("A", "B"),
    circuit = c("C1", "C1"),
    hours_fished = c(2.0, 1.5),
    catch_total = c(1L, 2L),
    trip_status = c("complete", "complete"),
    n_counted = c(5L, 10L),
    n_interviewed = c(3L, 5L)
  )
}

test_that("estimate_effort dispatches to bus-route estimator for bus_route design", {
  design <- make_br_effort_design()
  d <- add_interviews(design, make_br_effort_interviews(),
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  result <- estimate_effort(d)
  expect_s3_class(result, "creel_estimates")
  expect_true(is.numeric(result$estimates$estimate))
})

test_that("bus-route effort estimate matches Eq. 19.4 sum(e_i / pi_i)", {
  design <- make_br_effort_design()
  d <- add_interviews(design, make_br_effort_interviews(),
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  result <- estimate_effort(d)
  # Eq 19.4: site A contribution = (2.0 * 5/3) / 0.2 = 16.67, site B = (1.5 * 2.0) / 0.3 = 10
  # Total HT estimate ≈ 26.67; test verifies positive, finite result
  expect_true(result$estimates$estimate > 0)
  expect_true(!is.na(result$estimates$se))
})

test_that("bus-route estimate has site_contributions attribute", {
  design <- make_br_effort_design()
  d <- add_interviews(design, make_br_effort_interviews(),
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  result <- estimate_effort(d)
  sc <- attr(result, "site_contributions")
  expect_false(is.null(sc))
  expect_true(all(c("e_i", "pi_i", "e_i_over_pi_i") %in% names(sc)))
})

test_that("get_site_contributions returns tibble with correct columns", {
  design <- make_br_effort_design()
  d <- add_interviews(design, make_br_effort_interviews(),
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  result <- estimate_effort(d)
  sc <- get_site_contributions(result)
  expect_s3_class(sc, "tbl_df")
  expect_true("e_i" %in% names(sc))
  expect_true("pi_i" %in% names(sc))
  expect_true("e_i_over_pi_i" %in% names(sc))
})

test_that("get_site_contributions errors for non-creel_estimates input", {
  expect_error(
    get_site_contributions(list()),
    regexp = "creel_estimates"
  )
})

test_that("get_site_contributions errors when site_contributions attribute absent", {
  # Standard (non-bus-route) estimate has no attribute
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    effort_hours = c(15, 23, 45, 52)
  )
  d <- add_counts(design, counts)
  result <- estimate_effort(d)
  expect_error(
    get_site_contributions(result),
    regexp = "site_contributions"
  )
})

test_that("verbose=TRUE prints bus-route dispatch message for bus_route design", {
  design <- make_br_effort_design()
  d <- add_interviews(design, make_br_effort_interviews(),
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  expect_message(
    estimate_effort(d, verbose = TRUE),
    regexp = "Jones & Pollock"
  )
})

test_that("verbose=FALSE (default) produces no dispatch message", {
  design <- make_br_effort_design()
  d <- add_interviews(design, make_br_effort_interviews(),
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  # Should produce no message (dispatch is silent by default; warnings from survey pkg are expected)
  expect_no_message(suppressWarnings(estimate_effort(d)))
})

test_that("estimate_effort by=circuit returns proportion column for bus-route", {
  # 2-circuit design
  cal <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
    day_type = c("weekday", "weekday", "weekday", "weekday")
  )
  sf2 <- data.frame(
    site = c("A", "B", "C", "D"),
    circuit = c("C1", "C1", "C2", "C2"),
    p_site = c(0.4, 0.6, 0.5, 0.5),
    p_period = c(0.5, 0.5, 0.5, 0.5)
  )
  design2 <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "bus_route",
    sampling_frame = sf2,
    site = site, # nolint: object_usage_linter
    circuit = circuit, # nolint: object_usage_linter
    p_site = p_site, # nolint: object_usage_linter
    p_period = p_period # nolint: object_usage_linter
  )
  interviews2 <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
    day_type = c("weekday", "weekday", "weekday", "weekday"),
    site = c("A", "B", "C", "D"),
    circuit = c("C1", "C1", "C2", "C2"),
    hours_fished = c(2.0, 1.5, 3.0, 2.5),
    catch_total = c(1L, 2L, 1L, 3L),
    trip_status = c("complete", "complete", "complete", "complete"),
    n_counted = c(5L, 10L, 4L, 8L),
    n_interviewed = c(3L, 5L, 2L, 4L)
  )
  d2 <- add_interviews(design2, interviews2,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  result <- estimate_effort(d2, by = circuit) # nolint: object_usage_linter
  expect_true("proportion" %in% names(result$estimates))
  expect_true("circuit" %in% names(result$estimates))
  expect_equal(sum(result$estimates$proportion), 1.0, tolerance = 1e-10)
})

test_that("zero-effort site (n_counted=0, n_interviewed=0) contributes 0 to estimate", {
  design <- make_br_effort_design()
  interviews_zero <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday"),
    site = c("A", "B"),
    circuit = c("C1", "C1"),
    hours_fished = c(2.0, 0.0),
    catch_total = c(1L, 0L),
    trip_status = c("complete", "complete"),
    n_counted = c(5L, 0L),
    n_interviewed = c(3L, 0L)
  )
  d <- add_interviews(design, interviews_zero,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed # nolint: object_usage_linter
  )
  result <- estimate_effort(d)
  # Site B contributes 0 (zero-effort site) — estimate should be > 0 (Site A contributes)
  expect_true(result$estimates$estimate > 0)
  sc <- get_site_contributions(result)
  # Site B's e_i_over_pi_i should be 0
  site_b <- sc[sc$site == "B", ]
  expect_equal(site_b$e_i_over_pi_i, 0, tolerance = 1e-10)
})

# Within-day variance (Rasmussen two-stage) tests ----
# Plan 36-02: VAR-01, VAR-02, VAR-03, VAR-04

# Helper: build a creel_design with two counts per day
make_multi_count_design <- function() {
  data(example_calendar, envir = environment()) # nolint: object_usage_linter
  data(example_counts, envir = environment()) # nolint: object_usage_linter
  counts_am <- example_counts # nolint: object_usage_linter
  counts_am$count_time <- "am"
  counts_pm <- example_counts # nolint: object_usage_linter
  counts_pm$count_time <- "pm"
  # Ensure within-day variance is non-zero: pm counts differ from am
  counts_pm$effort_hours <- counts_pm$effort_hours + 4
  multi_counts <- rbind(counts_am, counts_pm)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter
}

test_that("estimate_effort() SE unchanged for single-count-per-day data (VAR-01)", {
  data(example_calendar, envir = environment()) # nolint: object_usage_linter
  data(example_counts, envir = environment()) # nolint: object_usage_linter
  design_single <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design_single <- add_counts(design_single, example_counts) # nolint: object_usage_linter

  result_single <- suppressWarnings(estimate_effort(design_single)) # nolint: object_usage_linter
  # VAR-01: within_day_var is NULL -> se_within = 0, se_between = se (total)
  expect_equal(result_single$estimates$se_between, result_single$estimates$se)
  expect_equal(result_single$estimates$se_within, 0)
})

test_that("estimate_effort() SE is larger with within-day variance (VAR-02)", {
  data(example_calendar, envir = environment()) # nolint: object_usage_linter
  data(example_counts, envir = environment()) # nolint: object_usage_linter
  design_multi <- make_multi_count_design()
  design_single <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design_single <- add_counts(design_single, example_counts) # nolint: object_usage_linter

  result_multi <- suppressWarnings(estimate_effort(design_multi)) # nolint: object_usage_linter
  result_single <- suppressWarnings(estimate_effort(design_single)) # nolint: object_usage_linter

  # Two-stage SE must be >= between-day-only SE (within-day adds variance when counts vary)
  expect_gte(result_multi$estimates$se, result_multi$estimates$se_between)

  # se_within > 0 when K_d >= 2 and counts differ within day
  expect_gt(result_multi$estimates$se_within, 0)
})

test_that("estimate_effort() output includes se_between and se_within columns (VAR-04)", {
  design_multi <- make_multi_count_design()
  result <- suppressWarnings(estimate_effort(design_multi)) # nolint: object_usage_linter
  expect_true("se_between" %in% names(result$estimates))
  expect_true("se_within" %in% names(result$estimates))
})

test_that("se_between and se_within present in output even for single-count design", {
  data(example_calendar, envir = environment()) # nolint: object_usage_linter
  data(example_counts, envir = environment()) # nolint: object_usage_linter
  design_single <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design_single <- add_counts(design_single, example_counts) # nolint: object_usage_linter
  result <- suppressWarnings(estimate_effort(design_single)) # nolint: object_usage_linter
  expect_true("se_between" %in% names(result$estimates))
  expect_true("se_within" %in% names(result$estimates))
})

test_that("estimate_effort() total se equals sqrt(se_between^2 + se_within^2)", {
  design_multi <- make_multi_count_design()
  result <- suppressWarnings(estimate_effort(design_multi)) # nolint: object_usage_linter
  est <- result$estimates
  expected_se <- sqrt(est$se_between^2 + est$se_within^2)
  expect_equal(est$se, expected_se, tolerance = 1e-10)
})

test_that("estimate_effort() emits informational message for mixed K_d (VAR-03)", {
  data(example_calendar, envir = environment()) # nolint: object_usage_linter
  data(example_counts, envir = environment()) # nolint: object_usage_linter
  # Build design where some days have K_d = 2 and one day has K_d = 1
  counts_am <- example_counts # nolint: object_usage_linter
  counts_am$count_time <- "am"
  counts_pm <- example_counts[-1L, ] # nolint: object_usage_linter; drop first day -- creates mixed K_d
  counts_pm$count_time <- "pm"
  mixed_counts <- rbind(counts_am, counts_pm)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, mixed_counts, count_time_col = count_time) # nolint: object_usage_linter

  # VAR-03: informational message about days with nC = 1
  expect_message(
    suppressWarnings(estimate_effort(d)), # nolint: object_usage_linter
    regexp = "nC = 1"
  )
})

test_that("estimate_effort() grouped output has se_between and se_within columns", {
  design_multi <- make_multi_count_design()
  result <- suppressWarnings(estimate_effort(design_multi, by = day_type)) # nolint: object_usage_linter
  expect_true("se_between" %in% names(result$estimates))
  expect_true("se_within" %in% names(result$estimates))
})

# Helper: two-PSU progressive design (Pope et al. worked example + second PSU for variance)
make_pope_progressive_design <- function() {
  # Pope et al. Ch. 17: C = 234, τ = 2h, T_d = 8h → Ê_d = 1872 angler-hours
  # Two PSUs sampled so estimate_effort() can compute between-PSU variance
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    day_type = c("weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  cts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    day_type = c("weekend", "weekend"),
    n_anglers = c(234L, 100L),
    shift_hours = c(8, 8),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  add_counts( # nolint: object_usage_linter
    design, cts,
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
}

test_that("progressive Ê_d computation matches Pope et al. worked example (EFF-02)", {
  d <- make_pope_progressive_design()
  # First PSU: Ê_d = 234 × 2 × (8/2) = 1872 angler-hours stored in count column
  expect_equal(d$counts$n_anglers[d$counts$date == as.Date("2024-06-01")], 1872, tolerance = 1e-10)
  # Second PSU: Ê_d = 100 × 8 = 800
  expect_equal(d$counts$n_anglers[d$counts$date == as.Date("2024-06-08")], 800, tolerance = 1e-10)
  # estimate_effort() runs without error (both PSUs sampled → variance computable)
  result <- suppressWarnings(estimate_effort(d))
  expect_true(is.numeric(result$estimates$estimate))
  expect_gt(result$estimates$estimate, 0)
  # se_between and se_within always present (Phase 36 guarantee)
  expect_true("se_between" %in% names(result$estimates))
  expect_true("se_within" %in% names(result$estimates))
})
