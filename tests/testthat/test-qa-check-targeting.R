# ==============================================================================
# TEST SUITE: qa_check_targeting()
# ==============================================================================

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("qa_check_targeting requires data", {
  expect_error(
    qa_check_targeting(),
    "interviews.*must be"
  )

  expect_error(
    qa_check_targeting(interviews = data.frame()),
    "non-empty"
  )
})

test_that("qa_check_targeting validates catch column", {
  data <- tibble::tibble(
    date = as.Date("2025-01-01") + 0:9,
    catch_total = 1:10
  )

  expect_error(
    qa_check_targeting(data, catch_col = "missing_col"),
    "not found"
  )
})

test_that("qa_check_targeting validates success_threshold", {
  data <- tibble::tibble(
    catch_total = 1:10
  )

  expect_error(
    qa_check_targeting(data, success_threshold = 1.5),
    "between 0 and 1"
  )

  expect_error(
    qa_check_targeting(data, success_threshold = -0.1),
    "between 0 and 1"
  )
})

# ==============================================================================
# TEST SUITE 2: NO BIAS - REPRESENTATIVE SAMPLING
# ==============================================================================

test_that("qa_check_targeting detects no issues with normal success rate", {
  # 50% success rate (normal)
  data <- tibble::tibble(
    catch_total = c(rep(0, 50), rep(1:5, length.out = 50))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$overall_success_rate, 0.5)
  expect_equal(result$n_total, 100)
  expect_equal(result$n_success, 50)
})

# ==============================================================================
# TEST SUITE 3: LOW SEVERITY - MILD TARGETING
# ==============================================================================

test_that("qa_check_targeting detects low severity for 75-85% success", {
  # 78% success rate
  data <- tibble::tibble(
    catch_total = c(rep(0, 22), rep(1:5, length.out = 78))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "low")
  expect_equal(result$overall_success_rate, 0.78)
})

# ==============================================================================
# TEST SUITE 4: MEDIUM SEVERITY - MODERATE TARGETING
# ==============================================================================

test_that("qa_check_targeting detects medium severity for 85-90% success", {
  # 87% success rate
  data <- tibble::tibble(
    catch_total = c(rep(0, 13), rep(1:5, length.out = 87))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "medium")
  expect_equal(result$overall_success_rate, 0.87)
})

# ==============================================================================
# TEST SUITE 5: HIGH SEVERITY - SEVERE TARGETING
# ==============================================================================

test_that("qa_check_targeting detects high severity for >90% success", {
  # 95% success rate
  data <- tibble::tibble(
    catch_total = c(rep(0, 5), rep(1:5, length.out = 95))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$overall_success_rate, 0.95)
})

# ==============================================================================
# TEST SUITE 6: LOCATION-SPECIFIC TARGETING
# ==============================================================================

test_that("qa_check_targeting identifies high-success locations", {
  # Location A: normal (50%), Location B: cleaning station (95%)
  data <- tibble::tibble(
    location = c(rep("Boat Ramp", 50), rep("Cleaning Station", 50)),
    catch_total = c(
      c(rep(0, 25), rep(1:3, length.out = 25)),  # 50% success
      c(rep(0, 2), rep(1:5, length.out = 48))    # 96% success
    )
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    location_col = "location"
  )

  expect_true(result$issue_detected)
  expect_true(!is.null(result$location_stats))
  expect_equal(nrow(result$location_stats), 2)
  expect_true("Cleaning Station" %in% result$high_success_locations)
  expect_false("Boat Ramp" %in% result$high_success_locations)
})

test_that("qa_check_targeting flags multiple high-success locations as high severity", {
  # 4 locations with >90% success
  data <- tibble::tibble(
    location = rep(c("Loc1", "Loc2", "Loc3", "Loc4"), each = 25),
    catch_total = c(
      c(rep(0, 2), rep(1:3, length.out = 23)),  # 92% success
      c(rep(0, 2), rep(1:3, length.out = 23)),  # 92% success
      c(rep(0, 2), rep(1:3, length.out = 23)),  # 92% success
      c(rep(0, 2), rep(1:3, length.out = 23))   # 92% success
    )
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    location_col = "location"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$n_high_success_locations, 4)
})

test_that("qa_check_targeting requires >=5 interviews to flag location", {
  # Location with only 3 interviews at 100% success should not be flagged
  data <- tibble::tibble(
    location = c(rep("MainLoc", 50), rep("SmallLoc", 3)),
    catch_total = c(
      rep(c(0,0,1,2,3), 10),  # 50: 20 zeros, 30 non-zeros (60%)
      c(1, 2, 3)              # 3: all non-zero (100%)
    )
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    location_col = "location"
  )

  expect_false("SmallLoc" %in% result$high_success_locations)
})

# ==============================================================================
# TEST SUITE 7: INTERVIEWER-SPECIFIC BIAS
# ==============================================================================

test_that("qa_check_targeting identifies biased interviewers", {
  # Interviewer A: normal (50%), Interviewer B: targets successful (90%)
  data <- tibble::tibble(
    interviewer = c(rep("A", 50), rep("B", 50)),
    catch_total = c(
      c(rep(0, 25), rep(1:3, length.out = 25)),  # 50% success
      c(rep(0, 5), rep(1:5, length.out = 45))    # 90% success
    )
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    interviewer_col = "interviewer"
  )

  expect_true(result$issue_detected)
  expect_true(!is.null(result$interviewer_stats))
  expect_equal(nrow(result$interviewer_stats), 2)
  expect_true("B" %in% result$biased_interviewers)
  expect_false("A" %in% result$biased_interviewers)
})

test_that("qa_check_targeting requires >=10 interviews to flag interviewer", {
  # Interviewer with only 8 interviews should not be flagged
  data <- tibble::tibble(
    interviewer = c(rep("A", 50), rep("B", 8)),
    catch_total = c(
      c(rep(0, 25), rep(1:3, length.out = 25)),  # 50% success
      rep(1:3, length.out = 8)                    # 100% but only 8 interviews
    )
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    interviewer_col = "interviewer"
  )

  expect_false("B" %in% result$biased_interviewers)
})

test_that("qa_check_targeting uses 1.2x threshold for interviewer bias", {
  # Overall success: 60%, Interviewer needs >72% (1.2x) to be flagged
  # A: 30% success, B: 90% success, Overall: 60%
  # Threshold: 60% * 1.2 = 72%, so B (90%) should be flagged
  data <- tibble::tibble(
    interviewer = c(rep("A", 50), rep("B", 50)),
    catch_total = c(
      c(rep(0, 35), rep(1:3, length.out = 15)),  # 30% success
      c(rep(0, 5), rep(1:3, length.out = 45))    # 90% success (>1.2x avg)
    )
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    interviewer_col = "interviewer"
  )

  expect_true("B" %in% result$biased_interviewers)
})

# ==============================================================================
# TEST SUITE 8: MISSING OPTIONAL COLUMNS
# ==============================================================================

test_that("qa_check_targeting handles missing location column gracefully", {
  data <- tibble::tibble(
    catch_total = c(rep(0, 10), rep(1:3, length.out = 90))
  )

  expect_warning(
    result <- qa_check_targeting(
      data,
      catch_col = "catch_total",
      location_col = "nonexistent"
    ),
    "not found"
  )

  expect_true(result$issue_detected)
  expect_null(result$location_stats)
})

test_that("qa_check_targeting handles missing interviewer column gracefully", {
  data <- tibble::tibble(
    catch_total = c(rep(0, 10), rep(1:3, length.out = 90))
  )

  expect_warning(
    result <- qa_check_targeting(
      data,
      catch_col = "catch_total",
      interviewer_col = "nonexistent"
    ),
    "not found"
  )

  expect_true(result$issue_detected)
  expect_null(result$interviewer_stats)
})

# ==============================================================================
# TEST SUITE 9: RETURN STRUCTURE
# ==============================================================================

test_that("qa_check_targeting returns correct structure", {
  data <- tibble::tibble(
    catch_total = c(rep(0, 50), rep(1:5, length.out = 50))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_s3_class(result, "qa_check_result")
  expect_true("issue_detected" %in% names(result))
  expect_true("severity" %in% names(result))
  expect_true("overall_success_rate" %in% names(result))
  expect_true("n_total" %in% names(result))
  expect_true("n_success" %in% names(result))
  expect_true("expected_success_range" %in% names(result))
  expect_true("recommendation" %in% names(result))

  expect_type(result$issue_detected, "logical")
  expect_type(result$severity, "character")
  expect_type(result$overall_success_rate, "double")
  expect_equal(length(result$expected_success_range), 2)
})

test_that("qa_check_targeting includes location stats when provided", {
  data <- tibble::tibble(
    location = rep(c("A", "B"), each = 50),
    catch_total = c(rep(0, 50), rep(1:5, length.out = 50))
  )

  result <- qa_check_targeting(
    data,
    catch_col = "catch_total",
    location_col = "location"
  )

  expect_true(!is.null(result$location_stats))
  expect_s3_class(result$location_stats, "data.frame")
  expect_true("success_rate" %in% names(result$location_stats))
  expect_true("n_interviews" %in% names(result$location_stats))
})

# ==============================================================================
# TEST SUITE 10: PRINT METHOD
# ==============================================================================

test_that("print.qa_check_result works for targeting check", {
  data <- tibble::tibble(
    catch_total = c(rep(0, 10), rep(1:3, length.out = 90))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  # Should not error
  expect_output(print(result), "QA CHECK")
  expect_output(print(result), "Targeting Bias")
})

# ==============================================================================
# TEST SUITE 11: EDGE CASES
# ==============================================================================

test_that("qa_check_targeting handles all-zero catches", {
  data <- tibble::tibble(
    catch_total = rep(0, 100)
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_false(result$issue_detected)
  expect_equal(result$overall_success_rate, 0.0)
})

test_that("qa_check_targeting handles all-nonzero catches", {
  data <- tibble::tibble(
    catch_total = rep(1:5, length.out = 100)
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$overall_success_rate, 1.0)
})

test_that("qa_check_targeting handles NA values", {
  data <- tibble::tibble(
    catch_total = c(rep(0, 10), rep(1:3, length.out = 85), rep(NA, 5))
  )

  result <- qa_check_targeting(data, catch_col = "catch_total")

  # Should exclude NAs from calculation
  expect_equal(result$n_total, 95)  # 100 - 5 NAs
  expect_equal(result$overall_success_rate, 85/95)
})
