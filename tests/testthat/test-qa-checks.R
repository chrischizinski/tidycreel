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