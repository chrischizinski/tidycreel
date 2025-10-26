# ==============================================================================
# TEST SUITE: qa_check_zeros()
# ==============================================================================

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("qa_check_zeros requires data", {
  expect_error(
    qa_check_zeros(type = "counts"),
    "data.*must be"
  )

  expect_error(
    qa_check_zeros(data = data.frame(), type = "counts"),
    "non-empty"
  )
})

test_that("qa_check_zeros requires value_col for counts", {
  data <- tibble::tibble(
    date = as.Date("2025-01-01") + 0:9,
    location = "A",
    count = 1:10
  )

  expect_error(
    qa_check_zeros(data, type = "counts", date_col = "date"),
    "value_col.*required"
  )
})

test_that("qa_check_zeros validates column existence", {
  data <- tibble::tibble(
    date = as.Date("2025-01-01") + 0:9,
    count = 1:10
  )

  expect_error(
    qa_check_zeros(data, type = "counts", date_col = "missing_col", value_col = "count"),
    "Missing required columns"
  )

  expect_error(
    qa_check_zeros(data, type = "counts", date_col = "date", value_col = "missing_col"),
    "not found"
  )
})

# ==============================================================================
# TEST SUITE 2: COUNT DATA - PERFECT COVERAGE
# ==============================================================================

test_that("qa_check_zeros detects no issues with perfect coverage", {
  # Complete sampling frame: 10 dates x 2 locations = 20 observations
  data <- expand.grid(
    date = as.Date("2025-01-01") + 0:9,
    location = c("A", "B")
  )
  data$count <- rpois(nrow(data), lambda = 3)

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = "location",
    value_col = "count"
  )

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$coverage_rate, 1.0)
  expect_equal(result$n_missing, 0)
  expect_equal(length(result$missing_dates), 0)
  expect_equal(length(result$missing_locations), 0)
})

# ==============================================================================
# TEST SUITE 3: COUNT DATA - LOW COVERAGE (HIGH SEVERITY)
# ==============================================================================

test_that("qa_check_zeros detects high severity for coverage < 70%", {
  # Should have 10 dates x 2 locations = 20, but only provide 12 (60%)
  data <- expand.grid(
    date = as.Date("2025-01-01") + 0:9,
    location = c("A", "B")
  )
  data$count <- rpois(nrow(data), lambda = 3)

  # Remove 8 observations (40% missing)
  data <- data[1:12, ]

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = "location",
    value_col = "count"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_true(result$coverage_rate < 0.7)
  expect_equal(result$n_missing, 8)
  expect_gt(length(result$missing_dates), 0)
})

# ==============================================================================
# TEST SUITE 4: COUNT DATA - MEDIUM COVERAGE
# ==============================================================================

test_that("qa_check_zeros detects medium severity for coverage 70-90%", {
  # Should have 10 dates x 2 locations = 20, but only provide 16 (80%)
  data <- expand.grid(
    date = as.Date("2025-01-01") + 0:9,
    location = c("A", "B")
  )
  data$count <- rpois(nrow(data), lambda = 3)

  # Remove 4 observations (20% missing)
  data <- data[1:16, ]

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = "location",
    value_col = "count"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "medium")
  expect_true(result$coverage_rate >= 0.7 && result$coverage_rate < 0.9)
  expect_equal(result$n_missing, 4)
})

# ==============================================================================
# TEST SUITE 5: COUNT DATA - LOW SEVERITY
# ==============================================================================

test_that("qa_check_zeros detects low severity for coverage 90-95%", {
  # Should have 100 observations, provide 92 (92% coverage)
  data <- expand.grid(
    date = as.Date("2025-01-01") + 0:49,
    location = c("A", "B")
  )
  data$count <- rpois(nrow(data), lambda = 3)

  # Remove 8 observations (8% missing)
  data <- data[1:92, ]

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = "location",
    value_col = "count",
    expected_coverage = 0.95
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "low")
  expect_true(result$coverage_rate >= 0.9 && result$coverage_rate < 0.95)
})

# ==============================================================================
# TEST SUITE 6: COUNT DATA - WITHOUT LOCATION
# ==============================================================================

test_that("qa_check_zeros works without location column", {
  # Just dates, no location stratification
  data <- tibble::tibble(
    date = as.Date("2025-01-01") + 0:9,
    count = rpois(10, lambda = 3)
  )

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = NULL,
    value_col = "count"
  )

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$coverage_rate, 1.0)
})

# ==============================================================================
# TEST SUITE 7: INTERVIEW DATA - GOOD ZERO RATE
# ==============================================================================

test_that("qa_check_zeros detects no issues with adequate zero rate", {
  # 25% zero catches (above expected 20%)
  data <- tibble::tibble(
    interview_date = as.Date("2025-01-01") + sample(0:30, 100, replace = TRUE),
    catch_total = c(rep(0, 25), rep(1:10, length.out = 75))
  )

  result <- qa_check_zeros(
    data,
    type = "interviews",
    date_col = "interview_date",
    value_col = "catch_total",
    expected_zero_rate = 0.2
  )

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$zero_rate, 0.25)
})

# ==============================================================================
# TEST SUITE 8: INTERVIEW DATA - LOW ZERO RATE (HIGH SEVERITY)
# ==============================================================================

test_that("qa_check_zeros detects high severity for very low zero rate", {
  # Only 5% zero catches (expected 20%)
  data <- tibble::tibble(
    interview_date = as.Date("2025-01-01") + sample(0:30, 100, replace = TRUE),
    catch_total = c(rep(0, 5), rep(1:10, length.out = 95))
  )

  result <- qa_check_zeros(
    data,
    type = "interviews",
    date_col = "interview_date",
    value_col = "catch_total",
    expected_zero_rate = 0.2
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$zero_rate, 0.05)
  expect_true(result$zero_rate < 0.1)
})

# ==============================================================================
# TEST SUITE 9: INTERVIEW DATA - MEDIUM SEVERITY
# ==============================================================================

test_that("qa_check_zeros detects medium severity for moderately low zero rate", {
  # 12% zero catches (expected 20%, threshold is 10%)
  data <- tibble::tibble(
    interview_date = as.Date("2025-01-01") + sample(0:30, 100, replace = TRUE),
    catch_total = c(rep(0, 12), rep(1:10, length.out = 88))
  )

  result <- qa_check_zeros(
    data,
    type = "interviews",
    date_col = "interview_date",
    value_col = "catch_total",
    expected_zero_rate = 0.2
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "medium")
  expect_equal(result$zero_rate, 0.12)
})

# ==============================================================================
# TEST SUITE 10: INTERVIEW DATA - INTERVIEWER ANALYSIS
# ==============================================================================

test_that("qa_check_zeros identifies suspicious interviewers", {
  # Interviewer A has normal zero rate (20%), B has low zero rate (4%)
  data <- tibble::tibble(
    interview_date = as.Date("2025-01-01") + sample(0:30, 100, replace = TRUE),
    interviewer = c(rep("A", 50), rep("B", 50)),
    catch_total = c(
      c(rep(0, 10), rep(1:5, length.out = 40)),  # A: 20% zeros
      c(rep(0, 2), rep(1:5, length.out = 48))    # B: 4% zeros (suspicious!)
    )
  )

  result <- qa_check_zeros(
    data,
    type = "interviews",
    date_col = "interview_date",
    value_col = "catch_total",
    interviewer_col = "interviewer",
    expected_zero_rate = 0.2
  )

  expect_true(result$issue_detected)
  expect_true(!is.null(result$interviewer_zero_rates))
  expect_equal(nrow(result$interviewer_zero_rates), 2)
  expect_true("B" %in% result$suspicious_interviewers)
  expect_false("A" %in% result$suspicious_interviewers)
})

test_that("qa_check_zeros only flags interviewers with sufficient data", {
  # Interviewer with < 10 interviews should not be flagged
  data <- tibble::tibble(
    interview_date = as.Date("2025-01-01") + 1:15,
    interviewer = c(rep("A", 10), rep("B", 5)),
    catch_total = rep(1:5, length.out = 15)  # No zeros for either
  )

  result <- qa_check_zeros(
    data,
    type = "interviews",
    date_col = "interview_date",
    value_col = "catch_total",
    interviewer_col = "interviewer",
    expected_zero_rate = 0.2
  )

  # A should be flagged (10 interviews, 0% zeros), B should not (only 5 interviews)
  expect_true("A" %in% result$suspicious_interviewers)
  expect_false("B" %in% result$suspicious_interviewers)
})

# ==============================================================================
# TEST SUITE 11: RETURN STRUCTURE
# ==============================================================================

test_that("qa_check_zeros returns correct structure for counts", {
  data <- tibble::tibble(
    date = as.Date("2025-01-01") + 0:9,
    location = "A",
    count = 1:10
  )

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = "location",
    value_col = "count"
  )

  expect_s3_class(result, "qa_check_result")
  expect_true("issue_detected" %in% names(result))
  expect_true("severity" %in% names(result))
  expect_true("check_type" %in% names(result))
  expect_true("coverage_rate" %in% names(result))
  expect_true("recommendation" %in% names(result))
  expect_equal(result$check_type, "counts")
})

test_that("qa_check_zeros returns correct structure for interviews", {
  data <- tibble::tibble(
    interview_date = as.Date("2025-01-01") + 0:49,
    catch_total = rpois(50, lambda = 2)
  )

  result <- qa_check_zeros(
    data,
    type = "interviews",
    date_col = "interview_date",
    value_col = "catch_total"
  )

  expect_s3_class(result, "qa_check_result")
  expect_true("issue_detected" %in% names(result))
  expect_true("severity" %in% names(result))
  expect_true("check_type" %in% names(result))
  expect_true("zero_rate" %in% names(result))
  expect_true("recommendation" %in% names(result))
  expect_equal(result$check_type, "interviews")
})

# ==============================================================================
# TEST SUITE 12: PRINT METHOD
# ==============================================================================

test_that("print.qa_check_result works", {
  data <- tibble::tibble(
    date = as.Date("2025-01-01") + 0:9,
    count = 1:10
  )

  result <- qa_check_zeros(
    data,
    type = "counts",
    date_col = "date",
    location_col = NULL,
    value_col = "count"
  )

  # Should not error
  expect_output(print(result), "QA CHECK")
  expect_output(print(result), "COUNTS")
})
