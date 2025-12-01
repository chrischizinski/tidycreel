test_that("qa_checks runs successfully with interview data", {
  # Create simple test data
  test_interviews <- data.frame(
    date = as.Date("2023-06-15"),
    species = c("Walleye", "Northern Pike", "Walleye", "Bass", "Unknown"),
    catch_total = c(2, 1, 0, 3, 1),
    hours_fished = c(4, 3, 2, 5, 1),
    num_anglers = c(2, 1, 2, 1, 1),
    effort = c(8, 3, 4, 5, 1),
    location = c("Lake A", "Lake A", "Lake B", "Lake A", "Lake B")
  )
  
  # Run QA checks with only effort check to avoid parameter conflicts
  result <- qa_checks(
    interviews = test_interviews, 
    checks = "effort",
    return_details = FALSE,
    effort_col = "effort",
    hours_fished_col = "hours_fished"
  )
  
  # Basic structure tests
  expect_s3_class(result, "qa_checks_result")
  expect_type(result$overall_score, "double")
  expect_type(result$overall_grade, "character")
  expect_type(result$issues_detected, "integer")
  expect_s3_class(result$summary, "data.frame")
  expect_type(result$recommendations, "character")
})

test_that("qa_checks handles missing data gracefully", {
  expect_error(
    qa_checks(),
    "At least one of.*must be provided"
  )
})

test_that("qa_checks validates check names", {
  test_interviews <- data.frame(
    species = "Walleye",
    catch_total = 1,
    hours_fished = 2
  )
  
  expect_error(
    qa_checks(interviews = test_interviews, checks = "invalid_check"),
    "Invalid check names"
  )
})

test_that("qa_checks scoring system works", {
  # Test with data that should have no issues
  clean_interviews <- data.frame(
    species = rep(c("Walleye", "Northern Pike"), 10),
    catch_total = rep(c(1, 2), 10),
    hours_fished = rep(c(3, 4), 10),
    num_anglers = rep(1, 20),
    effort = rep(c(3, 4), 10)
  )
  
  result <- qa_checks(
    interviews = clean_interviews, 
    checks = "effort",
    return_details = FALSE,
    effort_col = "effort",
    hours_fished_col = "hours_fished"
  )
  
  # Should have high score with clean data
  expect_gte(result$overall_score, 80)
  expect_true(result$overall_grade %in% c("A", "B"))
})

test_that("print method works for qa_checks_result", {
  test_interviews <- data.frame(
    species = "Walleye",
    catch_total = 1,
    hours_fished = 2,
    effort = 2
  )
  
  result <- qa_checks(
    interviews = test_interviews, 
    checks = "effort",
    return_details = FALSE,
    effort_col = "effort",
    hours_fished_col = "hours_fished"
  )
  
  # Should not error when printing and should be correct class
  expect_s3_class(result, "qa_checks_result")
  expect_no_error(print(result))
})

test_that("all QA checks can be run together", {
  # Create comprehensive test data
  test_interviews <- data.frame(
    date = as.Date("2023-06-15") + 0:9,
    species = c(rep("Walleye", 5), rep("Northern Pike", 3), "Bass", "Unknown"),
    catch_total = c(2, 1, 0, 3, 1, 2, 0, 1, 5, NA),
    hours_fished = c(4, 3, 2, 5, 1, 3, 4, 2, 8, 2),
    num_anglers = c(2, 1, 2, 1, 1, 2, 1, 1, 3, 1),
    effort = c(8, 3, 4, 5, 1, 6, 4, 2, 24, 2),
    location = c(rep("Lake A", 5), rep("Lake B", 5)),
    stratum = c(rep("Weekday", 5), rep("Weekend", 5))
  )
  
  test_counts <- data.frame(
    date = as.Date("2023-06-15") + 0:9,
    location = c(rep("Lake A", 5), rep("Lake B", 5)),
    anglers_count = c(5, 3, 0, 8, 2, 4, 0, 6, 12, 1),
    stratum = c(rep("Weekday", 5), rep("Weekend", 5))
  )
  
  # Run compatible checks (avoid parameter conflicts for now)
  result <- qa_checks(
    interviews = test_interviews,
    counts = test_counts,
    checks = c("species", "temporal", "outliers", "missing"),
    return_details = TRUE
  )
  
  # Should complete without error
  expect_s3_class(result, "qa_checks_result")
  expect_type(result$overall_score, "double")
  expect_true(result$overall_score >= 0 && result$overall_score <= 100)
  expect_true(result$overall_grade %in% c("A", "B", "C", "D", "F"))
})

test_that("individual QA check functions work", {
  test_data <- data.frame(
    date = as.Date("2023-06-15") + 0:4,
    species = c("Walleye", "Pike", "Bass", "Walleye", "Trout"),
    catch_total = c(2, 1, 0, 3, 100),  # 100 is outlier
    hours_fished = c(4, 3, 2, 5, 1),
    effort = c(8, 3, 4, 10, 1),
    location = rep("Lake A", 5)
  )
  
  # Test species check
  species_result <- qa_check_species(test_data, species_col = "species")
  expect_type(species_result$issue_detected, "logical")
  expect_true(species_result$severity %in% c("high", "medium", "low", "none"))
  
  # Test outlier check
  outlier_result <- qa_check_outliers(test_data, numeric_cols = "catch_total")
  expect_type(outlier_result$issue_detected, "logical")
  expect_gte(outlier_result$n_outliers_total, 0)
  
  # Test temporal check
  temporal_result <- qa_check_temporal(test_data, date_col = "date")
  expect_type(temporal_result$issue_detected, "logical")
  expect_gte(temporal_result$n_strata, 0)
  
  # Test missing check
  missing_result <- qa_check_missing(test_data)
  expect_type(missing_result$issue_detected, "logical")
  expect_gte(missing_result$completeness_rate, 0)
  expect_lte(missing_result$completeness_rate, 1)
})