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

test_that("estimate_effort CI bounds match manual confint()", {
  design <- make_test_design_with_counts()

  # tidycreel estimate
  result <- suppressWarnings(estimate_effort(design)) # nolint: object_usage_linter

  # Manual survey package calculation
  svy <- design$survey
  manual_result <- survey::svytotal(~effort_hours, svy)
  manual_ci <- confint(manual_result, level = 0.95)

  expect_equal(result$estimates$ci_lower, manual_ci[1, 1], tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci[1, 2], tolerance = 1e-10)
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
    manual_se <- manual_result$se.effort_hours[manual_result$day_type == day]

    expect_equal(tidycreel_se, manual_se, tolerance = 1e-10)
  }
})

test_that("grouped estimate_effort matches manual svyby confidence intervals", {
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
    vartype = c("se", "ci"),
    ci.level = 0.95
  )

  # Match CI bounds for each group
  for (i in seq_len(nrow(result$estimates))) {
    day <- result$estimates$day_type[i]
    tidycreel_ci_lower <- result$estimates$ci_lower[i]
    tidycreel_ci_upper <- result$estimates$ci_upper[i]
    manual_ci_lower <- manual_result$ci_l.effort_hours[manual_result$day_type == day]
    manual_ci_upper <- manual_result$ci_u.effort_hours[manual_result$day_type == day]

    expect_equal(tidycreel_ci_lower, manual_ci_lower, tolerance = 1e-10)
    expect_equal(tidycreel_ci_upper, manual_ci_upper, tolerance = 1e-10)
  }
})
