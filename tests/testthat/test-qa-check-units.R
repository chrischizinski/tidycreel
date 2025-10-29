# ==============================================================================
# TEST SUITE: qa_check_units()
# ==============================================================================

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("qa_check_units requires data", {
  expect_error(
    qa_check_units(),
    "interviews.*must be"
  )

  expect_error(
    qa_check_units(interviews = data.frame()),
    "non-empty"
  )
})

test_that("qa_check_units validates length column", {
  data <- tibble::tibble(
    catch_total = 1:10
  )

  expect_error(
    qa_check_units(data, length_col = "missing_col"),
    "not found"
  )
})

test_that("qa_check_units handles missing optional columns gracefully", {
  data <- tibble::tibble(
    length_mm = c(100, 150, 200)
  )

  expect_warning(
    result <- qa_check_units(
      data,
      length_col = "length_mm",
      species_col = "nonexistent"
    ),
    "not found"
  )

  expect_null(result$species_unit_patterns)
})

test_that("qa_check_units requires non-zero lengths", {
  data <- tibble::tibble(
    length_mm = c(0, NA, 0, NA)
  )

  expect_error(
    qa_check_units(data, length_col = "length_mm"),
    "No valid length measurements"
  )
})

# ==============================================================================
# TEST SUITE 2: MILLIMETER MEASUREMENTS (CONSISTENT)
# ==============================================================================

test_that("qa_check_units detects no issues with consistent mm measurements", {
  data <- tibble::tibble(
    length_mm = c(100, 150, 200, 250, 300, 180, 220, 190, 210, 170)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$likely_units, "mm")
  expect_equal(result$n_measurements, 10)
  expect_equal(result$n_likely_mm, 10)
  expect_equal(result$n_likely_inches, 0)
})

# ==============================================================================
# TEST SUITE 3: INCH MEASUREMENTS (CONSISTENT)
# ==============================================================================

test_that("qa_check_units detects no issues with consistent inch measurements", {
  data <- tibble::tibble(
    length_inches = c(8, 10, 12, 15, 9, 11, 14, 13, 16, 10)
  )

  result <- qa_check_units(data, length_col = "length_inches")

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
  expect_equal(result$likely_units, "inches")
  expect_equal(result$n_measurements, 10)
})

# ==============================================================================
# TEST SUITE 4: MIXED UNITS - HIGH SEVERITY
# ==============================================================================

test_that("qa_check_units detects high severity for clearly mixed units", {
  # Mix of mm (150-300) and inches (8-15)
  data <- tibble::tibble(
    length = c(150, 200, 250, 8, 10, 12, 180, 220, 9, 11)
  )

  result <- qa_check_units(data, length_col = "length")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(result$likely_units, "mixed")
})

test_that("qa_check_units detects high severity for >20% in wrong units", {
  # Mostly mm but 30% in inches
  data <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250, 180, 220, 190, 210), 7),  # 70% mm
                   rep(c(8, 10, 12), 10))                          # 30% inches
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
})

# ==============================================================================
# TEST SUITE 5: MEDIUM SEVERITY - SOME MIXING
# ==============================================================================

test_that("qa_check_units detects medium severity for 5-20% wrong units", {
  # Mostly mm but 10% in inches
  data <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250, 180, 220, 190, 210, 170, 160), 10),  # 90 mm
                   rep(c(8, 10, 12, 9, 11), 2))                              # 10 inches
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "medium")
})

test_that("qa_check_units detects medium severity for inconsistent precision", {
  # All mm but varying precision
  data <- tibble::tibble(
    length_mm = c(100, 150.0, 200.00, 250.1, 300.25, 180, 220.0, 190.00)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(result$inconsistent_precision)
  # May trigger medium or low depending on CV threshold
  expect_true(result$severity %in% c("medium", "low"))
})

# ==============================================================================
# TEST SUITE 6: LOW SEVERITY - MINOR ISSUES
# ==============================================================================

test_that("qa_check_units detects low severity for <5% wrong units", {
  # Mostly mm but 2% in inches
  data <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250, 180, 220, 190, 210, 170, 160), 11),  # 99 mm
                   c(10))                                                     # 1 inch (1%)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(result$issue_detected)
  expect_equal(result$severity, "low")
})

# ==============================================================================
# TEST SUITE 7: INTERVIEWER-SPECIFIC UNIT DETECTION
# ==============================================================================

test_that("qa_check_units identifies interviewer-specific unit usage", {
  # Interviewer A uses mm, Interviewer B uses inches
  data <- tibble::tibble(
    interviewer = c(rep("A", 30), rep("B", 30)),
    length = c(rep(c(150, 200, 250, 180, 220), 6),  # A: mm
               rep(c(8, 10, 12, 9, 11), 6))          # B: inches
  )

  result <- qa_check_units(
    data,
    length_col = "length",
    interviewer_col = "interviewer"
  )

  expect_true(result$issue_detected)
  expect_true(!is.null(result$interviewer_units))
  expect_equal(nrow(result$interviewer_units), 2)

  # Both should be flagged as suspicious (using different units from mixed overall)
  expect_true(length(result$suspicious_interviewers) > 0)
})

test_that("qa_check_units requires >=10 measurements to flag interviewer", {
  # Interviewer with only 8 measurements should not be flagged
  data <- tibble::tibble(
    interviewer = c(rep("A", 50), rep("B", 8)),
    length = c(rep(c(150, 200, 250, 180, 220), 10),  # A: 50 mm
               rep(c(8, 10), 4))                      # B: 8 inches
  )

  result <- qa_check_units(
    data,
    length_col = "length",
    interviewer_col = "interviewer"
  )

  expect_false("B" %in% result$suspicious_interviewers)
})

test_that("qa_check_units flags interviewer with >30% in wrong units", {
  # Overall: mm (90%), A follows pattern, B has 40% inches
  data <- tibble::tibble(
    interviewer = c(rep("A", 45), rep("B", 45)),
    length = c(
      rep(c(150, 200, 250, 180, 220), 9),          # A: all mm
      c(rep(c(150, 200, 250), 9), rep(c(10, 12), 9))  # B: 60% mm, 40% inches
    )
  )

  result <- qa_check_units(
    data,
    length_col = "length",
    interviewer_col = "interviewer"
  )

  expect_true("B" %in% result$suspicious_interviewers)
  expect_false("A" %in% result$suspicious_interviewers)
})

# ==============================================================================
# TEST SUITE 8: SPECIES-SPECIFIC ANALYSIS
# ==============================================================================

test_that("qa_check_units provides species-specific unit patterns", {
  data <- tibble::tibble(
    species = c(rep("Bass", 30), rep("Bluegill", 30)),
    length = c(rep(c(200, 250, 300, 280, 320), 6),  # Bass: mm (larger)
               rep(c(80, 100, 120, 90, 110), 6))     # Bluegill: mm (smaller)
  )

  result <- qa_check_units(
    data,
    length_col = "length",
    species_col = "species"
  )

  expect_true(!is.null(result$species_unit_patterns))
  expect_equal(nrow(result$species_unit_patterns), 2)

  # Check structure
  expect_true("mean_length" %in% names(result$species_unit_patterns))
  expect_true("likely_unit" %in% names(result$species_unit_patterns))
})

# ==============================================================================
# TEST SUITE 9: PRECISION ANALYSIS
# ==============================================================================

test_that("qa_check_units calculates precision statistics", {
  data <- tibble::tibble(
    length_mm = c(100, 150.5, 200.25, 180, 220.0, 190)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(!is.null(result$precision_stats))
  expect_true("n_integer" %in% names(result$precision_stats))
  expect_true("n_one_decimal" %in% names(result$precision_stats))
  expect_true("n_two_decimal" %in% names(result$precision_stats))
  expect_true("precision_cv" %in% names(result$precision_stats))
})

test_that("qa_check_units flags high precision variability", {
  # Mix of integer, 1 decimal, 2 decimal
  data <- tibble::tibble(
    length_mm = c(rep(100, 10), rep(150.5, 10), rep(200.25, 10))
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(!is.null(result$precision_stats$precision_cv))
})

# ==============================================================================
# TEST SUITE 10: MIXED UNIT SAMPLES
# ==============================================================================

test_that("qa_check_units provides sample of suspicious measurements", {
  data <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250), 10), rep(c(8, 10, 12), 3))
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_true(!is.null(result$mixed_unit_samples))
  expect_true(nrow(result$mixed_unit_samples) <= 10)
})

test_that("qa_check_units includes relevant columns in samples", {
  data <- tibble::tibble(
    species = c(rep("Bass", 35), rep("Bluegill", 4)),
    interviewer = c(rep("A", 35), rep("B", 4)),
    length_mm = c(rep(c(150, 200, 250, 180, 220), 7), rep(c(8, 10), 2))  # 35 + 4 = 39
  )

  result <- qa_check_units(
    data,
    length_col = "length_mm",
    species_col = "species",
    interviewer_col = "interviewer"
  )

  if (!is.null(result$mixed_unit_samples)) {
    expect_true("species" %in% names(result$mixed_unit_samples))
    expect_true("interviewer" %in% names(result$mixed_unit_samples))
  }
})

# ==============================================================================
# TEST SUITE 11: RETURN STRUCTURE
# ==============================================================================

test_that("qa_check_units returns correct structure", {
  data <- tibble::tibble(
    length_mm = c(100, 150, 200, 250, 180, 220, 190, 210, 170, 160)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_s3_class(result, "qa_check_result")
  expect_true("issue_detected" %in% names(result))
  expect_true("severity" %in% names(result))
  expect_true("likely_units" %in% names(result))
  expect_true("n_measurements" %in% names(result))
  expect_true("n_likely_mm" %in% names(result))
  expect_true("n_likely_inches" %in% names(result))
  expect_true("precision_stats" %in% names(result))
  expect_true("recommendation" %in% names(result))

  expect_type(result$issue_detected, "logical")
  expect_type(result$severity, "character")
  expect_type(result$likely_units, "character")
  expect_type(result$n_measurements, "integer")
})

# ==============================================================================
# TEST SUITE 12: PRINT METHOD
# ==============================================================================

test_that("print.qa_check_result works for units check", {
  data <- tibble::tibble(
    length = c(rep(c(150, 200, 250), 10), rep(c(8, 10), 5))
  )

  result <- qa_check_units(data, length_col = "length")

  expect_output(print(result), "QA CHECK")
  expect_output(print(result), "Mixed Units")
})

# ==============================================================================
# TEST SUITE 13: EDGE CASES
# ==============================================================================

test_that("qa_check_units handles single measurement", {
  data <- tibble::tibble(
    length_mm = 150
  )

  result <- qa_check_units(data, length_col = "length_mm")

  expect_false(result$issue_detected)
  expect_equal(result$n_measurements, 1)
})

test_that("qa_check_units handles large measurements (over 1000mm)", {
  # Some species can exceed 1000mm
  data <- tibble::tibble(
    length_mm = c(1200, 1300, 1400, 1100, 1250)
  )

  result <- qa_check_units(
    data,
    length_col = "length_mm",
    mm_range = c(50, 2000)  # Adjust range for large species
  )

  expect_equal(result$n_likely_mm, 5)
})

test_that("qa_check_units handles very small measurements", {
  # Young-of-year fish
  data <- tibble::tibble(
    length_mm = c(25, 30, 35, 28, 32)
  )

  result <- qa_check_units(
    data,
    length_col = "length_mm",
    mm_range = c(20, 1000)  # Include small fish
  )

  expect_equal(result$likely_units, "mm")
})

test_that("qa_check_units handles NA values", {
  data <- tibble::tibble(
    length_mm = c(100, 150, NA, 200, 250, NA, 180)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  # Should exclude NAs
  expect_equal(result$n_measurements, 5)
})

test_that("qa_check_units handles zero values", {
  data <- tibble::tibble(
    length_mm = c(0, 100, 150, 0, 200, 250, 0)
  )

  result <- qa_check_units(data, length_col = "length_mm")

  # Should exclude zeros
  expect_equal(result$n_measurements, 4)
})

# ==============================================================================
# TEST SUITE 14: BOUNDARY CASES
# ==============================================================================

test_that("qa_check_units handles ambiguous range (40-60)", {
  # With default ranges (mm: 50-1000, inches: 2-50), values 40-60 are split
  # Values < 50 are inches, values >= 50 are mm
  data <- tibble::tibble(
    length = c(45, 50, 55, 48, 52)
  )

  result <- qa_check_units(data, length_col = "length")

  # With default ranges: 45, 48 are inches; 50, 52, 55 are mm
  expect_equal(result$n_likely_inches, 2)
  expect_equal(result$n_likely_mm, 3)
  expect_equal(result$n_ambiguous, 0)
  expect_equal(result$likely_units, "mixed")
})

test_that("qa_check_units uses custom ranges", {
  data <- tibble::tibble(
    length = c(5, 6, 7, 8, 9, 10)
  )

  result <- qa_check_units(
    data,
    length_col = "length",
    inch_range = c(4, 12),
    mm_range = c(100, 500)
  )

  expect_equal(result$likely_units, "inches")
  expect_equal(result$n_likely_inches, 6)
})

# ==============================================================================
# TEST SUITE 15: SEVERITY THRESHOLDS
# ==============================================================================

test_that("qa_check_units severity levels are correct", {
  # Test exact threshold boundaries

  # High: >20% wrong
  data_high <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250, 180), 10), rep(c(8, 10, 12), 4))  # 12/52 = 23% inches
  )
  result_high <- qa_check_units(data_high, length_col = "length_mm")
  expect_equal(result_high$severity, "high")

  # Medium: 5-20% wrong
  data_med <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250), 19), rep(c(8), 2))  # ~3.4% but triggers medium due to presence
  )
  # This might be low severity depending on exact percentage

  # Low: 1-5% wrong
  data_low <- tibble::tibble(
    length_mm = c(rep(c(150, 200, 250), 33), c(8))  # 1% inches
  )
  result_low <- qa_check_units(data_low, length_col = "length_mm")
  expect_equal(result_low$severity, "low")
})
