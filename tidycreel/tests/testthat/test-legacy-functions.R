# Test legacy functions and compatibility
library(testthat)
library(tidycreel)
library(dplyr)

test_that("legacy helper functions work correctly", {
  # Test capwords
  expect_equal(capwords("hello world"), "Hello World")
  expect_equal(capwords("HELLO WORLD", strict = TRUE), "Hello World")
  
  # Test trim
  expect_equal(trim("  hello  "), "hello")
  expect_equal(trim("\t\nhello\t\n"), "hello")
  
  # Test na.return
  expect_equal(na.return(NA), "-")
  expect_equal(na.return(5, "missing"), 5)
  expect_equal(na.return(NA, "missing"), "missing")
  
  # Test change_na
  expect_equal(change_na("NA"), NA)
  expect_equal(change_na("<NA>"), NA)
  expect_equal(change_na("hello"), "hello")
  
  # Test is.even
  expect_true(is.even(4))
  expect_false(is.even(5))
  expect_equal(is.even(c(2, 3, 4)), c(TRUE, FALSE, TRUE))
  
  # Test convertToLogical
  expect_true(convertToLogical(1))
  expect_false(convertToLogical(0))
  expect_equal(convertToLogical(2), 2)
  
  # Test split_wide_tables
  wide_df <- data.frame(a = 1:5, b = 6:10, c = 11:15, d = 16:20, e = 21:25)
  split_result <- split_wide_tables(wide_df, cut.width = 3)
  expect_length(split_result, 2)
  expect_equal(ncol(split_result[[1]]), 3)
  
  # Test create_days_in_creel
  dates <- as.Date(c("2023-01-01", "2023-01-07"))
  days_df <- create_days_in_creel(dates)
  expect_equal(nrow(days_df), 7)
  expect_true(all(c("Date", "month", "day", "day_type") %in% names(days_df)))
  expect_true(all(days_df$day_type %in% c("weekday", "weekend")))
})

test_that("legacy data validation works", {
  # Test validate_legacy_data
  params <- validate_legacy_data(123)
  
  expect_type(params, "list")
  expect_true("waterbody_code" %in% names(params))
  expect_true("start_end_dates" %in% names(params))
  expect_true("waterbody_area_ac" %in% names(params))
  expect_true("period_probs" %in% names(params))
  expect_true("section_probs" %in% names(params))
  
  # Check data types
  expect_type(params$waterbody_code, "character")
  expect_type(params$waterbody_area_ac, "double")
  expect_s3_class(params$start_end_dates, "Date")
  expect_s3_class(params$period_probs, "data.frame")
  expect_s3_class(params$section_probs, "data.frame")
})

test_that("legacy database parameters work", {
  params <- legacy_db_params(123)
  
  expect_type(params, "list")
  expect_true("server" %in% names(params))
  expect_true("database" %in% names(params))
  expect_true("uid" %in% names(params))
  expect_true("pwd" %in% names(params))
  expect_true("port" %in% names(params))
})

test_that("legacy wrapper functions work", {
  # Test legacy_data_access
  mock_data <- legacy_data_access(123)
  expect_type(mock_data, "list")
  expect_true("counts" %in% names(mock_data))
  expect_true("interviews" %in% names(mock_data))
  expect_true("calendar" %in% names(mock_data))
  
  # Test legacy_design
  design <- legacy_design(123)
  expect_s3_class(design, "creel_design")
  
  # Test legacy_estimate
  estimates <- legacy_estimate(123)
  expect_type(estimates, "list")
  expect_true("effort" %in% names(estimates))
  expect_true("catch" %in% names(estimates))
  
  # Test legacy_summary
  summary_result <- legacy_summary(123)
  expect_type(summary_result, "list")
  expect_true("summary" %in% names(summary_result))
})

test_that("daily_effort function works", {
  # Create mock data
  mock_params <- validate_legacy_data(123)
  
  # Test daily_effort with mock data
  result <- daily_effort(123)
  
  expect_s3_class(result, "data.frame")
  expect_true(all(c("Date", "Counttype", "daily_mean_num", "daily_var_1") %in% names(result)))
  expect_true(all(result$Counttype %in% c("BankAnglers", "BoatAnglers", "AnglerBoats", "NonAngBoats")))
})

test_that("party_fish function works", {
  # Test different catch types
  catch_result <- party_fish(123, type = "Catch")
  harvest_result <- party_fish(123, type = "Harvest")
  release_result <- party_fish(123, type = "Release")
  cws_result <- party_fish(123, type = "CWS")
  hws_result <- party_fish(123, type = "HWS")
  
  # Check structure
  for (result in list(catch_result, harvest_result, release_result, cws_result, hws_result)) {
    expect_s3_class(result, "data.frame")
    expect_true(all(c("UID", "Species", "PartyCatch", "IndivCatch") %in% names(result)))
  }
  
  # Check that different types produce different results
  expect_false(identical(catch_result, harvest_result))
})

test_that("read_parameters function works", {
  params <- read_parameters(123)
  
  expect_type(params, "list")
  expect_true("waterbody.info" %in% names(params))
  expect_true("do.codes" %in% names(params))
  expect_true("days_in_creel" %in% names(params))
  expect_true("sample_days" %in% names(params))
  expect_true("water_levels" %in% names(params))
  
  # Check waterbody info structure
  expect_type(params$waterbody.info, "list")
  expect_true("code" %in% names(params$waterbody.info))
  expect_true("waterbody_ac" %in% names(params$waterbody.info))
  expect_true("start_end_dates" %in% names(params$waterbody.info))
})

test_that("strata estimators work", {
  # Test strata_effort_estimator
  effort_est <- strata_effort_estimator(123)
  expect_type(effort_est, "list")
  expect_true("effort" %in% names(effort_est))
  expect_true("variance" %in% names(effort_est))
  
  # Test strata_catch_estimator
  catch_est <- strata_catch_estimator(123)
  expect_type(catch_est, "list")
  expect_true("catch" %in% names(catch_est))
  expect_true("variance" %in% names(catch_est))
})

test_that("legacy compatibility warnings work", {
  expect_warning(legacy_warning("old_function", "new_function"))
  expect_warning(legacy_warning("test_function"), "deprecated")
})

test_that("get_available_creels works", {
  creels <- get_available_creels()
  expect_s3_class(creels, "data.frame")
  expect_true(all(c("Creel_UID", "Creel_Title") %in% names(creels)))
})

test_that("legacy functions handle edge cases", {
  # Test with empty data
  expect_error(validate_legacy_data(NULL))
  
  # Test with invalid creel_id
  expect_warning(legacy_data_access(-1))
  
  # Test edge cases in daily_effort
  expect_warning(daily_effort(999))
  
  # Test edge cases in party_fish
  expect_error(party_fish(123, type = "invalid_type"))
})