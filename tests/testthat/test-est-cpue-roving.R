# Tests for est_cpue_roving()
# Roving/incomplete trip CPUE estimation with Pollock et al. (1997) methods

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("est_cpue_roving requires response column", {
  # Data without catch column
  data <- tibble::tibble(
    hours_fished = 1:10
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(svy, response = "catch_total"),
    "catch_total"
  )
})

test_that("est_cpue_roving requires effort column", {
  # Data without effort column
  data <- tibble::tibble(
    catch_total = 1:10
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(svy, effort_col = "hours_fished"),
    "hours_fished"
  )
})

test_that("est_cpue_roving validates min_trip_hours", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  # Negative value
  expect_error(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = -1),
    "non-negative"
  )

  # Non-numeric
  expect_error(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = "0.5"),
    "non-negative"
  )

  # Zero should be allowed (no truncation)
  expect_no_error(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = 0, length_bias_correction = "none")
  )
})

test_that("est_cpue_roving validates conf_level", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  # > 1
  expect_error(
    est_cpue_roving(svy, response = "catch_total", conf_level = 1.5),
    "between 0 and 1"
  )

  # = 1
  expect_error(
    est_cpue_roving(svy, response = "catch_total", conf_level = 1),
    "between 0 and 1"
  )

  # = 0
  expect_error(
    est_cpue_roving(svy, response = "catch_total", conf_level = 0),
    "between 0 and 1"
  )

  # < 0
  expect_error(
    est_cpue_roving(svy, response = "catch_total", conf_level = -0.5),
    "between 0 and 1"
  )
})

test_that("est_cpue_roving requires total_trip_effort_col when correction requested", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(svy, response = "catch_total", length_bias_correction = "pollock"),
    "total_trip_effort_col"
  )
})

test_that("est_cpue_roving validates total_trip_effort_col exists", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(
      svy,
      length_bias_correction = "pollock",
      total_trip_effort_col = "nonexistent_column"
    ),
    "nonexistent_column.*not found"
  )
})

test_that("est_cpue_roving validates grouping variables exist", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10),
    location = rep("A", 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  # This should warn about missing column, not error
  expect_warning(
    est_cpue_roving(svy, response = "catch_total", by = c("location", "nonexistent")),
    "nonexistent"
  )
})

# ==============================================================================
# TEST SUITE 2: TRIP TRUNCATION
# ==============================================================================

test_that("est_cpue_roving truncates short trips", {
  data <- tibble::tibble(
    catch_total = c(0, 1, 2, 3, 4),
    hours_fished = c(0.1, 0.3, 0.6, 1.0, 2.0)  # First 2 should be truncated
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    response = "catch_total",
    min_trip_hours = 0.5,
    length_bias_correction = "none",
    diagnostics = TRUE
  )

  # Should use only last 3 observations
  expect_equal(result$n, 3)
  expect_equal(result$diagnostics[[1]]$n_truncated, 2)
  expect_equal(result$diagnostics[[1]]$n_used, 3)
})

test_that("est_cpue_roving warns when >10% truncated", {
  data <- tibble::tibble(
    catch_total = 1:20,
    hours_fished = c(rep(0.2, 5), rep(1.0, 15))  # 25% short trips
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_warning(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = 0.5, length_bias_correction = "none"),
    "Truncating.*25"
  )
})

test_that("est_cpue_roving informs when <10% truncated", {
  data <- tibble::tibble(
    catch_total = 1:20,
    hours_fished = c(0.2, rep(1.0, 19))  # 5% short trips
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  # Should inform but not warn
  expect_message(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = 0.5, length_bias_correction = "none"),
    "Truncating.*1.*short"
  )
})

test_that("est_cpue_roving errors when all trips below threshold", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(0.2, 10)  # All below threshold
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = 0.5, length_bias_correction = "none"),
    "No trips remain"
  )
})

test_that("est_cpue_roving handles NA effort in truncation", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = c(NA, rep(1.0, 9))
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  # Should not error on NA, but NA will be excluded from catch rate calculation
  result <- est_cpue_roving(
    svy,
    length_bias_correction = "none"
  )

  expect_true(!is.na(result$estimate))
})

# ==============================================================================
# TEST SUITE 3: KNOWN VALUE CALCULATIONS
# ==============================================================================

test_that("est_cpue_roving calculates correct mean-of-ratios without correction", {
  # Known data: constant catch rate
  data <- tibble::tibble(
    catch_total = c(2, 4, 6),
    hours_fished = c(1, 2, 3)
  )
  # Individual rates: 2/1=2, 4/2=2, 6/3=2
  # Mean rate: (2+2+2)/3 = 2

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    response = "catch_total",
    length_bias_correction = "none"
  )

  expect_equal(result$estimate, 2.0, tolerance = 1e-6)
  expect_equal(result$n, 3)
  expect_true(!is.na(result$se))
})

test_that("est_cpue_roving calculates correct mean-of-ratios with varying rates", {
  # Varying catch rates
  data <- tibble::tibble(
    catch_total = c(1, 4, 9),
    hours_fished = c(1, 2, 3)
  )
  # Rates: 1/1=1, 4/2=2, 9/3=3
  # Mean: (1+2+3)/3 = 2

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    response = "catch_total",
    length_bias_correction = "none"
  )

  expect_equal(result$estimate, 2.0, tolerance = 1e-6)
})

test_that("est_cpue_roving Pollock correction with constant rates", {
  # Constant rates but different trip lengths
  data <- tibble::tibble(
    catch_total = c(4, 6, 8),
    hours_fished = c(2, 3, 4),  # Observed effort
    planned_hours = c(4, 6, 8)  # Total planned (2x observed)
  )
  # Rates: 4/2=2, 6/3=2, 8/4=2
  # Weights: 1/4=0.25, 1/6≈0.167, 1/8=0.125
  # Weighted mean with constant rates should still be 2.0

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    response = "catch_total",
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock"
  )

  expect_equal(result$estimate, 2.0, tolerance = 1e-6)
  expect_true(result$diagnostics[[1]]$correction_applied)
})

test_that("est_cpue_roving handles zero catches correctly", {
  data <- tibble::tibble(
    catch_total = rep(0, 10),
    hours_fished = rep(2, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    length_bias_correction = "none"
  )

  expect_equal(result$estimate, 0.0)
  expect_true(result$se >= 0)
  expect_equal(result$n, 10)
})

test_that("est_cpue_roving handles single observation", {
  # Survey package requires >1 PSU, so use 2 identical observations
  data <- tibble::tibble(
    catch_total = c(5, 5),
    hours_fished = c(2, 2)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    response = "catch_total",
    length_bias_correction = "none"
  )

  expect_equal(result$estimate, 2.5, tolerance = 1e-6)
  expect_equal(result$n, 2)
})

test_that("est_cpue_roving warns about infinite catch rates", {
  data <- tibble::tibble(
    catch_total = c(5, 3, 2),
    hours_fished = c(2, 0, 1)  # Middle observation has zero effort
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  # Use min_trip_hours = 0 to avoid truncating the zero-effort row
  expect_warning(
    est_cpue_roving(svy, response = "catch_total", min_trip_hours = 0, length_bias_correction = "none"),
    "infinite.*undefined"
  )
})

# ==============================================================================
# TEST SUITE 4: GROUPED ESTIMATION
# ==============================================================================

test_that("est_cpue_roving handles grouped data correctly", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 5),
    catch_total = c(1, 2, 3, 4, 5, 2, 4, 6, 8, 10),
    hours_fished = c(rep(1, 5), rep(2, 5))
  )

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    by = "location",
    length_bias_correction = "none"
  )

  expect_equal(nrow(result), 2)
  expect_true(all(c("A", "B") %in% result$location))

  # Location A: rates = 1/1, 2/1, 3/1, 4/1, 5/1 = 1,2,3,4,5; mean = 3
  # Location B: rates = 2/2, 4/2, 6/2, 8/2, 10/2 = 1,2,3,4,5; mean = 3
  expect_equal(result$estimate[result$location == "A"], 3.0, tolerance = 1e-6)
  expect_equal(result$estimate[result$location == "B"], 3.0, tolerance = 1e-6)
})

test_that("est_cpue_roving handles multiple grouping variables", {
  data <- tidyr::expand_grid(
    location = c("A", "B"),
    species = c("bass", "trout")
  ) |>
    dplyr::mutate(
      catch_total = rep(1:4, each = 1),
      hours_fished = 1
    )

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    by = c("location", "species"),
    length_bias_correction = "none"
  )

  expect_equal(nrow(result), 4)
  expect_true(all(c("location", "species") %in% names(result)))
  expect_true(all(result$n == 1))  # Each group has 1 observation
})

test_that("est_cpue_roving preserves grouping structure with truncation", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 10),
    catch_total = 1:20,
    hours_fished = rep(c(0.2, 0.3, 0.6, 1.0, 1.5), 4)  # Some below threshold
  )

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    by = "location",
    min_trip_hours = 0.5,
    length_bias_correction = "none",
    diagnostics = TRUE
  )

  # Both groups should still be present
  expect_equal(nrow(result), 2)
  expect_true(all(c("A", "B") %in% result$location))

  # Each group should have same truncation (6 out of 10 trips kept)
  # Pattern c(0.2, 0.3, 0.6, 1.0, 1.5) repeated 2x per location
  # Values < 0.5: 0.2, 0.3 appear 2x = 4 truncated
  # Values >= 0.5: 0.6, 1.0, 1.5 appear 2x = 6 kept
  expect_true(all(result$n == 6))
})

# ==============================================================================
# TEST SUITE 5: LENGTH-BIAS CORRECTION
# ==============================================================================

test_that("est_cpue_roving warns when total_effort < observed_effort", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = 1:10,
    planned_hours = rep(5, 10)  # Some less than observed
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_warning(
    est_cpue_roving(
      svy,
      total_trip_effort_col = "planned_hours",
      length_bias_correction = "pollock"
    ),
    "total planned effort < observed effort"
  )
})

test_that("est_cpue_roving correction weights are calculated correctly", {
  data <- tibble::tibble(
    catch_total = c(2, 4, 6),
    hours_fished = c(1, 2, 3),
    planned_hours = c(2, 4, 6)  # Total planned effort
  )
  # Weights should be: 1/2=0.5, 1/4=0.25, 1/6≈0.167

  svy <- survey::svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock",
    diagnostics = TRUE
  )

  # Check diagnostics include correction info
  expect_true(result$diagnostics[[1]]$correction_applied)
  expect_equal(result$diagnostics[[1]]$length_bias_correction, "pollock")
  expect_true(!is.null(result$diagnostics[[1]]$mean_bias_weight))
})

test_that("est_cpue_roving with no correction matches unweighted mean", {
  data <- tibble::tibble(
    catch_total = c(2, 4, 6),
    hours_fished = c(1, 2, 3),
    planned_hours = c(10, 10, 10)  # All have same planned effort
  )

  svy <- survey::svydesign(ids = ~1, data = data)

  result_none <- est_cpue_roving(
    svy,
    length_bias_correction = "none"
  )

  result_pollock <- est_cpue_roving(
    svy,
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock"
  )

  # With equal weights, Pollock should match unweighted
  expect_equal(result_none$estimate, result_pollock$estimate, tolerance = 1e-3)
})

# ==============================================================================
# TEST SUITE 6: DIAGNOSTICS
# ==============================================================================

test_that("est_cpue_roving includes diagnostics when requested", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    diagnostics = TRUE,
    length_bias_correction = "none"
  )

  expect_true("diagnostics" %in% names(result))
  expect_true(is.list(result$diagnostics))
  expect_equal(length(result$diagnostics), 1)

  diag <- result$diagnostics[[1]]
  expect_true(!is.null(diag$n_original))
  expect_true(!is.null(diag$n_truncated))
  expect_true(!is.null(diag$n_used))
  expect_true(!is.null(diag$mean_effort_observed))
  expect_true(!is.null(diag$mean_catch_rate))
})

test_that("est_cpue_roving omits diagnostics when not requested", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    diagnostics = FALSE,
    length_bias_correction = "none"
  )

  expect_true("diagnostics" %in% names(result))
  # When diagnostics = FALSE, we get list(NULL) for each row
  expect_true(all(sapply(result$diagnostics, function(x) is.null(x) || length(x) == 0)))
})

test_that("est_cpue_roving diagnostics include correction info when applied", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = 1:10,
    planned_hours = (1:10) * 2
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock",
    diagnostics = TRUE
  )

  diag <- result$diagnostics[[1]]
  expect_equal(diag$length_bias_correction, "pollock")
  expect_true(diag$correction_applied)
  expect_true(!is.null(diag$mean_total_effort))
  expect_true(!is.null(diag$mean_bias_weight))
})

# ==============================================================================
# TEST SUITE 7: INTEGRATION WITH SURVEY PACKAGE
# ==============================================================================

test_that("est_cpue_roving works with stratified designs", {
  data <- tibble::tibble(
    catch_total = 1:20,
    hours_fished = rep(c(1, 2), 10),
    stratum = rep(c("weekday", "weekend"), each = 10)
  )

  svy <- survey::svydesign(
    ids = ~1,
    strata = ~stratum,
    data = data
  )

  result <- est_cpue_roving(
    svy,
    length_bias_correction = "none"
  )

  expect_true(!is.na(result$estimate))
  expect_true(!is.na(result$se))
})

test_that("est_cpue_roving works with replicate designs", {
  data <- tibble::tibble(
    catch_total = 1:20,
    hours_fished = rep(2, 20)
  )

  svy_simple <- survey::svydesign(ids = ~1, data = data)
  svy_rep <- survey::as.svrepdesign(svy_simple, type = "bootstrap", replicates = 50)

  result <- est_cpue_roving(
    svy_rep,
    length_bias_correction = "none"
  )

  expect_true(!is.na(result$estimate))
  expect_true(!is.na(result$se))
})

# ==============================================================================
# TEST SUITE 8: METHOD LABEL
# ==============================================================================

test_that("est_cpue_roving creates correct method label", {
  data <- tibble::tibble(
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result_none <- est_cpue_roving(
    svy,
    response = "catch_total",
    length_bias_correction = "none"
  )

  expect_equal(
    result_none$method,
    "cpue_roving:mean_of_ratios:catch_total:none"  # Fixed: use catch_total
  )

  result_pollock <- est_cpue_roving(
    svy,
    response = "catch_total",
    total_trip_effort_col = "hours_fished",  # Use same col for simplicity
    length_bias_correction = "pollock"
  )

  expect_equal(
    result_pollock$method,
    "cpue_roving:mean_of_ratios:catch_total:pollock"
  )
})

# ==============================================================================
# TEST SUITE 9: RETURN SCHEMA
# ==============================================================================

test_that("est_cpue_roving returns tidycreel standard schema", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 5),
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    by = "location",
    length_bias_correction = "none"
  )

  # Check standard columns present
  expected_cols <- c("location", "estimate", "se", "ci_low", "ci_high", "n", "method", "diagnostics")
  expect_true(all(expected_cols %in% names(result)))

  # Check column types
  expect_true(is.numeric(result$estimate))
  expect_true(is.numeric(result$se))
  expect_true(is.numeric(result$ci_low))
  expect_true(is.numeric(result$ci_high))
  expect_true(is.numeric(result$n) || is.integer(result$n))
  expect_true(is.character(result$method))
  expect_true(is.list(result$diagnostics))
})

test_that("est_cpue_roving column order matches tidycreel standard", {
  data <- tibble::tibble(
    location = rep("A", 10),
    catch_total = 1:10,
    hours_fished = rep(1, 10)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    by = "location",
    length_bias_correction = "none"
  )

  # Expected order: grouping, estimate, se, ci_low, ci_high, n, method, diagnostics
  col_order <- names(result)
  expect_equal(col_order[1], "location")
  expect_equal(col_order[2], "estimate")
  expect_equal(col_order[3], "se")
  expect_equal(col_order[length(col_order)], "diagnostics")
})
