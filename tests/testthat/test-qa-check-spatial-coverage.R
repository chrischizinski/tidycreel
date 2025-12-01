# ==============================================================================
# TEST SUITE: qa_check_spatial_coverage()
# ==============================================================================

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("qa_check_spatial_coverage requires data", {
  expect_error(
    qa_check_spatial_coverage(type = "counts"),
    "data.*must be"
  )

  expect_error(
    qa_check_spatial_coverage(data = data.frame(), type = "counts"),
    "non-empty"
  )
})

test_that("qa_check_spatial_coverage validates required columns", {
  data <- tibble::tibble(
    location = c("A", "B"),
    count = 1:2
  )

  expect_error(
    qa_check_spatial_coverage(data, type = "counts", date_col = "missing"),
    "Missing required columns"
  )
})

test_that("qa_check_spatial_coverage validates min_coverage", {
  data <- tibble::tibble(
    location = c("A", "B"),
    date = as.Date("2025-01-01") + 0:1
  )

  expect_error(
    qa_check_spatial_coverage(data, type = "counts", min_coverage = 1.5),
    "between 0 and 1"
  )
})

# ==============================================================================
# TEST SUITE 2: PERFECT COVERAGE
# ==============================================================================

test_that("qa_check_spatial_coverage detects no issues with perfect coverage", {
  expected_locs <- c("A", "B", "C")

  data <- expand.grid(
    location = expected_locs,
    date = as.Date("2025-01-01") + 0:29
  )

  result <- qa_check_spatial_coverage(
    data,
    locations_expected = expected_locs,
    type = "counts"
  )

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$location_coverage, 1.0)
  expect_equal(result$n_locations_missing, 0)
  expect_equal(length(result$undersampled_locations), 0)
})

# ==============================================================================
# TEST SUITE 3: MISSING LOCATIONS - HIGH SEVERITY
# ==============================================================================

test_that("qa_check_spatial_coverage detects high severity for >20% missing", {
  expected_locs <- c("A", "B", "C", "D", "E")
  # Only sample A, B, C (60% coverage)

  data <- expand.grid(
    location = c("A", "B", "C"),
    date = as.Date("2025-01-01") + 0:9
  )

  result <- qa_check_spatial_coverage(
    data,
    locations_expected = expected_locs,
    type = "counts"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$location_coverage, 0.6)
  expect_equal(result$n_locations_missing, 2)
  expect_true(all(c("D", "E") %in% result$locations_missing))
})

# ==============================================================================
# TEST SUITE 4: MISSING LOCATIONS - MEDIUM SEVERITY
# ==============================================================================

test_that("qa_check_spatial_coverage detects medium severity for 10-20% missing", {
  expected_locs <- c("A", "B", "C", "D", "E", "F")
  # Only sample A, B, C, D, E (83% coverage - 1 missing = 17%)

  data <- expand.grid(
    location = c("A", "B", "C", "D", "E"),
    date = as.Date("2025-01-01") + 0:9
  )

  result <- qa_check_spatial_coverage(
    data,
    locations_expected = expected_locs,
    type = "counts"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "medium")
  expect_true(result$location_coverage >= 0.80 && result$location_coverage < 0.90)
})

# ==============================================================================
# TEST SUITE 5: UNDERSAMPLED LOCATIONS
# ==============================================================================

test_that("qa_check_spatial_coverage identifies undersampled locations", {
  data <- tibble::tibble(
    location = c(rep("A", 20), rep("B", 5), rep("C", 3)),  # B and C undersampled
    date = as.Date("2025-01-01") + sample(0:29, 28, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(
    data,
    type = "counts",
    min_sample_size = 10
  )

  expect_true(result$issue_detected)
  expect_true("B" %in% result$undersampled_locations)
  expect_true("C" %in% result$undersampled_locations)
  expect_false("A" %in% result$undersampled_locations)
})

test_that("qa_check_spatial_coverage high severity when >50% undersampled", {
  data <- tibble::tibble(
    location = c(rep("A", 5), rep("B", 4), rep("C", 3)),
    date = as.Date("2025-01-01") + sample(0:29, 12, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(
    data,
    type = "counts",
    min_sample_size = 10
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")  # All 3 locations undersampled (100%)
  expect_equal(length(result$undersampled_locations), 3)
})

# ==============================================================================
# TEST SUITE 6: TEMPORAL GAPS
# ==============================================================================

test_that("qa_check_spatial_coverage identifies temporal gaps", {
  # Location A: sampled throughout (30 days)
  # Location B: only sampled first 10 days (<70% coverage)
  data <- tibble::tibble(
    location = c(rep("A", 30), rep("B", 10)),
    date = c(
      as.Date("2025-01-01") + 0:29,  # A: full coverage
      as.Date("2025-01-01") + 0:9    # B: only first 10 days
    )
  )

  result <- qa_check_spatial_coverage(
    data,
    type = "counts"
  )

  expect_true(result$issue_detected)
  expect_true("B" %in% result$temporal_gaps)
  expect_false("A" %in% result$temporal_gaps)

  # Check temporal coverage values
  b_stats <- result$location_stats[result$location_stats$location == "B", ]
  expect_true(b_stats$temporal_coverage < 0.70)
})

# ==============================================================================
# TEST SUITE 7: SAMPLE SIZE IMBALANCE
# ==============================================================================

test_that("qa_check_spatial_coverage calculates sample size CV", {
  # Highly imbalanced: A=50, B=10, C=2
  data <- tibble::tibble(
    location = c(rep("A", 50), rep("B", 10), rep("C", 2)),
    date = as.Date("2025-01-01") + sample(0:29, 62, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(
    data,
    type = "counts"
  )

  expect_true(result$issue_detected)
  expect_true(!is.null(result$sample_size_cv))
  expect_true(result$sample_size_cv > 1.0)  # High CV indicates imbalance
})

# ==============================================================================
# TEST SUITE 8: INTERVIEWER COVERAGE
# ==============================================================================

test_that("qa_check_spatial_coverage checks interviewer spatial coverage", {
  # Interviewer A covers all locations
  # Interviewer B only covers location X (limited coverage)
  data <- tibble::tibble(
    location = c(rep(c("X", "Y", "Z"), 10), rep("X", 20)),
    date = as.Date("2025-01-01") + sample(0:29, 50, replace = TRUE),
    interviewer = c(rep("A", 30), rep("B", 20))
  )

  result <- qa_check_spatial_coverage(
    data,
    type = "interviews",
    interviewer_col = "interviewer"
  )

  expect_true(!is.null(result$interviewer_coverage))
  expect_true("B" %in% result$interviewers_with_limited_coverage)
  expect_false("A" %in% result$interviewers_with_limited_coverage)
})

test_that("qa_check_spatial_coverage requires >=5 interviews to flag interviewer", {
  # Interviewer with only 3 interviews shouldn't be flagged
  data <- tibble::tibble(
    location = c(rep(c("X", "Y", "Z"), 10), rep("X", 3)),
    date = as.Date("2025-01-01") + sample(0:29, 33, replace = TRUE),
    interviewer = c(rep("A", 30), rep("B", 3))
  )

  result <- qa_check_spatial_coverage(
    data,
    type = "interviews",
    interviewer_col = "interviewer"
  )

  expect_false("B" %in% result$interviewers_with_limited_coverage)
})

# ==============================================================================
# TEST SUITE 9: NO EXPECTED LOCATIONS PROVIDED
# ==============================================================================

test_that("qa_check_spatial_coverage uses observed locations when expected not provided", {
  data <- tibble::tibble(
    location = rep(c("A", "B", "C"), each = 10),
    date = as.Date("2025-01-01") + sample(0:29, 30, replace = TRUE)
  )

  expect_message(
    result <- qa_check_spatial_coverage(data, type = "counts"),
    "Using.*observed location"
  )

  expect_equal(result$location_coverage, 1.0)
  expect_equal(length(result$locations_expected), 3)
  expect_equal(length(result$locations_missing), 0)
})

# ==============================================================================
# TEST SUITE 10: RETURN STRUCTURE
# ==============================================================================

test_that("qa_check_spatial_coverage returns correct structure", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 15),
    date = as.Date("2025-01-01") + sample(0:29, 30, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(data, type = "counts")

  expect_s3_class(result, "qa_check_result")
  expect_true("issue_detected" %in% names(result))
  expect_true("severity" %in% names(result))
  expect_true("location_coverage" %in% names(result))
  expect_true("locations_expected" %in% names(result))
  expect_true("locations_observed" %in% names(result))
  expect_true("locations_missing" %in% names(result))
  expect_true("location_stats" %in% names(result))
  expect_true("undersampled_locations" %in% names(result))
  expect_true("temporal_gaps" %in% names(result))
  expect_true("recommendation" %in% names(result))

  expect_s3_class(result$location_stats, "data.frame")
  expect_true("n_samples" %in% names(result$location_stats))
  expect_true("temporal_coverage" %in% names(result$location_stats))
})

# ==============================================================================
# TEST SUITE 11: PRINT METHOD
# ==============================================================================

test_that("print.qa_check_result works for spatial coverage check", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 15),
    date = as.Date("2025-01-01") + sample(0:29, 30, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(data, type = "counts")

  expect_output(print(result), "QA CHECK")
  expect_output(print(result), "Spatial Coverage")
})

# ==============================================================================
# TEST SUITE 12: EDGE CASES
# ==============================================================================

test_that("qa_check_spatial_coverage handles single location", {
  data <- tibble::tibble(
    location = rep("A", 20),
    date = as.Date("2025-01-01") + 0:19
  )

  result <- qa_check_spatial_coverage(data, type = "counts")

  expect_false(result$issue_detected)
  expect_equal(result$location_coverage, 1.0)
})

test_that("qa_check_spatial_coverage handles NA locations", {
  data <- tibble::tibble(
    location = c(rep("A", 10), rep("B", 10), rep(NA, 5)),
    date = as.Date("2025-01-01") + sample(0:29, 25, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(data, type = "counts")

  # Should exclude NAs from location list
  expect_equal(length(result$locations_observed), 2)
  expect_false(any(is.na(result$locations_observed)))
})

test_that("qa_check_spatial_coverage handles all locations missing", {
  expected_locs <- c("A", "B", "C")

  data <- tibble::tibble(
    location = rep("X", 10),  # Different from expected
    date = as.Date("2025-01-01") + 0:9
  )

  result <- qa_check_spatial_coverage(
    data,
    locations_expected = expected_locs,
    type = "counts"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$location_coverage, 0.0)
  expect_equal(length(result$locations_missing), 3)
})

# ==============================================================================
# TEST SUITE 13: MISSING OPTIONAL COLUMNS
# ==============================================================================

test_that("qa_check_spatial_coverage handles missing interviewer column gracefully", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 10),
    date = as.Date("2025-01-01") + sample(0:29, 20, replace = TRUE)
  )

  expect_warning(
    result <- qa_check_spatial_coverage(
      data,
      type = "interviews",
      interviewer_col = "nonexistent"
    ),
    "not found"
  )

  expect_null(result$interviewer_coverage)
})

# ==============================================================================
# TEST SUITE 14: LOCATION STATS SORTING
# ==============================================================================

test_that("qa_check_spatial_coverage sorts location stats by sample size", {
  data <- tibble::tibble(
    location = c(rep("A", 50), rep("B", 10), rep("C", 30)),
    date = as.Date("2025-01-01") + sample(0:29, 90, replace = TRUE)
  )

  result <- qa_check_spatial_coverage(data, type = "counts")

  # Should be sorted descending by n_samples
  expect_equal(result$location_stats$location[1], "A")  # Highest
  expect_equal(result$location_stats$location[2], "C")
  expect_equal(result$location_stats$location[3], "B")  # Lowest
  expect_true(all(diff(result$location_stats$n_samples) <= 0))  # Descending
})
