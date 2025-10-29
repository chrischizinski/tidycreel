# ==============================================================================
# TEST SUITE: qa_check_effort()
# ==============================================================================

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("qa_check_effort requires data", {
  expect_error(
    qa_check_effort(),
    "interviews.*must be"
  )

  expect_error(
    qa_check_effort(interviews = data.frame()),
    "non-empty"
  )
})

test_that("qa_check_effort requires at least one effort column", {
  data <- tibble::tibble(
    catch_total = 1:10
  )

  expect_error(
    qa_check_effort(data, effort_col = NULL, num_anglers_col = NULL, hours_fished_col = NULL),
    "Must provide at least"
  )
})

test_that("qa_check_effort validates required columns exist", {
  data <- tibble::tibble(
    catch_total = 1:10
  )

  expect_error(
    qa_check_effort(data, effort_col = "missing_col"),
    "Missing required columns"
  )
})

test_that("qa_check_effort handles missing optional columns gracefully", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 4, 2, 3)
  )

  expect_warning(
    result <- qa_check_effort(
      data,
      effort_col = "hours_fished",
      catch_col = "nonexistent"
    ),
    "not found"
  )

  expect_equal(result$n_zero_effort_with_catch, 0)
})

# ==============================================================================
# TEST SUITE 2: CORRECT EFFORT CALCULATIONS
# ==============================================================================

test_that("qa_check_effort detects no issues with correct calculations", {
  data <- tibble::tibble(
    num_anglers = c(1, 2, 3, 2, 1),
    hours_fished = c(2, 3, 4, 2, 3),
    effort = c(2, 6, 12, 4, 3)  # Correct: num_anglers × hours
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$n_effort_inconsistent, 0)
})

# ==============================================================================
# TEST SUITE 3: INCORRECT EFFORT CALCULATIONS - HIGH SEVERITY
# ==============================================================================

test_that("qa_check_effort detects high severity for >20% incorrect", {
  # 30% incorrect calculations
  data <- tibble::tibble(
    num_anglers = rep(c(1, 2, 3), 10),
    hours_fished = rep(c(2, 3, 4), 10),
    effort = c(
      rep(c(2, 6, 12), 7),   # 70% correct
      rep(c(5, 5, 5), 3)     # 30% incorrect
    )
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_true(result$n_effort_inconsistent >= 9)  # At least 30%
})

# ==============================================================================
# TEST SUITE 4: INCORRECT EFFORT CALCULATIONS - MEDIUM SEVERITY
# ==============================================================================

test_that("qa_check_effort detects medium severity for 5-20% incorrect", {
  # 10% incorrect calculations
  data <- tibble::tibble(
    num_anglers = rep(c(1, 2, 3), 10),
    hours_fished = rep(c(2, 3, 4), 10),
    effort = c(
      rep(c(2, 6, 12), 9),   # 90% correct
      rep(c(5, 5, 5), 1)     # 10% incorrect
    )
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "medium")
})

# ==============================================================================
# TEST SUITE 5: INCORRECT EFFORT CALCULATIONS - LOW SEVERITY
# ==============================================================================

test_that("qa_check_effort detects low severity for <5% incorrect", {
  # 3% incorrect calculations
  data <- tibble::tibble(
    num_anglers = c(rep(c(1, 2, 3), 10), 2),
    hours_fished = c(rep(c(2, 3, 4), 10), 3),
    effort = c(rep(c(2, 6, 12), 10), 10)  # Last one incorrect
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "low")
  expect_equal(result$n_effort_inconsistent, 1)
})

# ==============================================================================
# TEST SUITE 6: ZERO EFFORT DETECTION
# ==============================================================================

test_that("qa_check_effort detects zero effort values", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 0, 4, 0, 2)
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished"
  )

  expect_equal(result$n_zero_effort, 2)
})

test_that("qa_check_effort detects zero effort with non-zero catch", {
  data <- tibble::tibble(
    hours_fished = c(2, 0, 3, 0, 2),
    catch_total = c(5, 3, 10, 0, 8)  # Two zeros with catch
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished",
    catch_col = "catch_total"
  )

  expect_equal(result$n_zero_effort_with_catch, 1)  # One zero effort with non-zero catch
  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
})

test_that("qa_check_effort detects missing effort with non-zero catch", {
  data <- tibble::tibble(
    hours_fished = c(2, NA, 3, NA, 2),
    catch_total = c(5, 3, 10, 0, 8)  # One NA with catch
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished",
    catch_col = "catch_total"
  )

  expect_true(result$n_zero_effort_with_catch >= 1)
  expect_true(result$issue_detected)
})

# ==============================================================================
# TEST SUITE 7: OUTLIER DETECTION
# ==============================================================================

test_that("qa_check_effort detects high outliers (>24 hours)", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 30, 4, 50, 2)  # Two high outliers
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished",
    max_hours = 24
  )

  expect_equal(result$n_outliers_high, 2)
  expect_true(result$issue_detected)
})

test_that("qa_check_effort detects low outliers (<0.1 hours)", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 0.05, 4, 0.02, 2)  # Two low outliers
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished",
    min_hours = 0.1
  )

  expect_equal(result$n_outliers_low, 2)
  expect_true(result$issue_detected)
})

test_that("qa_check_effort medium severity with >10% outliers", {
  data <- tibble::tibble(
    hours_fished = c(rep(c(2, 3, 4), 8), rep(30, 3))  # ~11% outliers
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished",
    max_hours = 24
  )

  expect_true(result$pct_outliers > 0.10)
  expect_equal(result$severity, "medium")
})

# ==============================================================================
# TEST SUITE 8: DECIMAL POINT ERROR DETECTION
# ==============================================================================

test_that("qa_check_effort detects potential 10× decimal errors", {
  data <- tibble::tibble(
    num_anglers = c(2, 2, 2),
    hours_fished = c(3, 3, 3),
    effort = c(6, 60, 6)  # Middle one is 10× expected
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(!is.null(result$decimal_error_candidates))
  expect_equal(nrow(result$decimal_error_candidates), 1)
  expect_equal(result$decimal_error_candidates$ratio[1], 10)
})

test_that("qa_check_effort detects potential 0.1× decimal errors", {
  data <- tibble::tibble(
    num_anglers = c(2, 2, 2),
    hours_fished = c(3, 3, 3),
    effort = c(6, 0.6, 6)  # Middle one is 0.1× expected
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(!is.null(result$decimal_error_candidates))
  expect_equal(nrow(result$decimal_error_candidates), 1)
  expect_equal(result$decimal_error_candidates$ratio[1], 0.1)
})

# ==============================================================================
# TEST SUITE 9: EFFORT SUMMARY STATISTICS
# ==============================================================================

test_that("qa_check_effort calculates summary statistics", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 4, NA, 5, 0, 2)
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished"
  )

  expect_true(!is.null(result$effort_summary))
  expect_equal(result$effort_summary$n_total, 7)
  expect_equal(result$effort_summary$n_valid, 6)
  expect_equal(result$effort_summary$n_zero, 1)
  expect_equal(result$effort_summary$n_missing, 1)
  expect_true(!is.na(result$effort_summary$mean_effort))
  expect_true(!is.na(result$effort_summary$median_effort))
})

# ==============================================================================
# TEST SUITE 10: TOLERANCE PARAMETER
# ==============================================================================

test_that("qa_check_effort respects tolerance for rounding errors", {
  data <- tibble::tibble(
    num_anglers = c(2, 2, 2),
    hours_fished = c(3.33, 3.33, 3.33),
    effort = c(6.66, 6.70, 6.62)  # Rounding differences: 0, 0.04, 0.04
  )

  # With strict tolerance (0.01)
  result_strict <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished",
    tolerance = 0.01
  )

  # With larger tolerance (0.1)
  result_loose <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished",
    tolerance = 0.1
  )

  expect_true(result_strict$n_effort_inconsistent > 0)
  expect_equal(result_loose$n_effort_inconsistent, 0)
})

# ==============================================================================
# TEST SUITE 11: RETURN STRUCTURE
# ==============================================================================

test_that("qa_check_effort returns correct structure", {
  data <- tibble::tibble(
    num_anglers = c(1, 2, 3),
    hours_fished = c(2, 3, 4),
    effort = c(2, 6, 12)
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_s3_class(result, "qa_check_result")
  expect_true("issue_detected" %in% names(result))
  expect_true("severity" %in% names(result))
  expect_true("n_effort_inconsistent" %in% names(result))
  expect_true("n_zero_effort" %in% names(result))
  expect_true("n_outliers" %in% names(result))
  expect_true("effort_summary" %in% names(result))
  expect_true("recommendation" %in% names(result))

  expect_type(result$issue_detected, "logical")
  expect_type(result$severity, "character")
  expect_type(result$n_effort_inconsistent, "integer")
})

# ==============================================================================
# TEST SUITE 12: PRINT METHOD
# ==============================================================================

test_that("print.qa_check_result works for effort check", {
  data <- tibble::tibble(
    num_anglers = c(2, 2),
    hours_fished = c(3, 3),
    effort = c(6, 10)  # One incorrect
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_output(print(result), "QA CHECK")
  expect_output(print(result), "Effort Calculations")
})

# ==============================================================================
# TEST SUITE 13: EDGE CASES
# ==============================================================================

test_that("qa_check_effort handles single record", {
  data <- tibble::tibble(
    hours_fished = 2
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished"
  )

  expect_false(result$issue_detected)
  expect_equal(result$n_total, 1)
})

test_that("qa_check_effort handles all NA effort", {
  data <- tibble::tibble(
    hours_fished = rep(NA_real_, 5)
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished"
  )

  expect_equal(result$n_missing_effort, 5)
  expect_equal(result$effort_summary$n_valid, 0)
})

test_that("qa_check_effort handles all zero effort", {
  data <- tibble::tibble(
    hours_fished = rep(0, 5)
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished"
  )

  expect_equal(result$n_zero_effort, 5)
})

test_that("qa_check_effort handles negative effort values as outliers", {
  data <- tibble::tibble(
    hours_fished = c(2, -1, 3, 4)  # Negative is invalid
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished",
    min_hours = 0.1
  )

  # Negative values treated as outliers (< min)
  expect_true(result$n_outliers_low >= 1)
})

# ==============================================================================
# TEST SUITE 14: EFFORT WITHOUT VALIDATION COLUMNS
# ==============================================================================

test_that("qa_check_effort works with only effort column", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 4, 30, 2)
  )

  result <- qa_check_effort(
    data,
    effort_col = "hours_fished"
  )

  # Should still detect outliers and zeros
  expect_equal(result$n_effort_inconsistent, 0)  # Can't validate without other columns
  expect_true(result$n_outliers > 0)  # Can detect outliers
})

test_that("qa_check_effort can use hours_fished when effort_col is NULL", {
  data <- tibble::tibble(
    hours_fished = c(2, 3, 0, 4)
  )

  result <- qa_check_effort(
    data,
    effort_col = NULL,
    hours_fished_col = "hours_fished"
  )

  expect_equal(result$n_zero_effort, 1)
  expect_equal(result$n_total, 4)
})

# ==============================================================================
# TEST SUITE 15: EFFORT INCONSISTENT RECORDS SAMPLE
# ==============================================================================

test_that("qa_check_effort provides sample of inconsistent records", {
  data <- tibble::tibble(
    num_anglers = rep(2, 15),
    hours_fished = rep(3, 15),
    effort = c(rep(6, 10), rep(10, 5))  # 5 incorrect
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(!is.null(result$effort_inconsistent_records))
  expect_equal(nrow(result$effort_inconsistent_records), 5)
  expect_true("difference" %in% names(result$effort_inconsistent_records))
})

test_that("qa_check_effort limits inconsistent records sample to 10", {
  data <- tibble::tibble(
    num_anglers = rep(2, 20),
    hours_fished = rep(3, 20),
    effort = rep(10, 20)  # All incorrect
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished"
  )

  expect_true(!is.null(result$effort_inconsistent_records))
  expect_equal(nrow(result$effort_inconsistent_records), 10)
})

# ==============================================================================
# TEST SUITE 16: OUTLIER RECORDS SAMPLE
# ==============================================================================

test_that("qa_check_effort provides sample of outlier records", {
  data <- tibble::tibble(
    num_anglers = c(rep(2, 10), rep(2, 5)),
    hours_fished = c(rep(3, 10), rep(30, 5)),  # 5 outliers
    effort = c(rep(6, 10), rep(60, 5))
  )

  result <- qa_check_effort(
    data,
    effort_col = "effort",
    num_anglers_col = "num_anglers",
    hours_fished_col = "hours_fished",
    max_hours = 24
  )

  expect_true(!is.null(result$outlier_records))
  expect_equal(nrow(result$outlier_records), 5)
  expect_true("type" %in% names(result$outlier_records))
})

# ==============================================================================
# TEST SUITE 17: SEVERITY THRESHOLD BOUNDARIES
# ==============================================================================

test_that("qa_check_effort severity thresholds are correct", {
  # High: >20% incorrect
  data_high <- tibble::tibble(
    num_anglers = rep(2, 25),
    hours_fished = rep(3, 25),
    effort = c(rep(6, 19), rep(10, 6))  # 24% incorrect
  )
  result_high <- qa_check_effort(data_high, "effort", "num_anglers", "hours_fished")
  expect_equal(result_high$severity, "high")

  # Medium: 5-20% incorrect
  data_med <- tibble::tibble(
    num_anglers = rep(2, 20),
    hours_fished = rep(3, 20),
    effort = c(rep(6, 18), rep(10, 2))  # 10% incorrect
  )
  result_med <- qa_check_effort(data_med, "effort", "num_anglers", "hours_fished")
  expect_equal(result_med$severity, "medium")

  # Low: <5% incorrect
  data_low <- tibble::tibble(
    num_anglers = rep(2, 30),
    hours_fished = rep(3, 30),
    effort = c(rep(6, 29), 10)  # 3.3% incorrect
  )
  result_low <- qa_check_effort(data_low, "effort", "num_anglers", "hours_fished")
  expect_equal(result_low$severity, "low")
})
