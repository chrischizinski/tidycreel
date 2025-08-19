library(testthat)
library(tidycreel)

# Test legacy helper functions
test_that("validate_creel_id works correctly", {
  expect_true(validate_creel_id("CREEL_2023_001"))
  expect_true(validate_creel_id("CREEL_2024_999"))
  expect_false(validate_creel_id("invalid"))
  expect_false(validate_creel_id("CREEL_2023_01")) # Missing leading zero
  expect_false(validate_creel_id("CREEL_23_001")) # Wrong year format
  expect_false(validate_creel_id("CREEL_2023_1000")) # Too many digits
  expect_false(validate_creel_id(NULL))
  expect_false(validate_creel_id(c("CREEL_2023_001", "CREEL_2023_002")))
})

test_that("extract_year_from_creel_id works correctly", {
  expect_equal(extract_year_from_creel_id("CREEL_2023_001"), 2023)
  expect_equal(extract_year_from_creel_id("CREEL_2024_999"), 2024)
  expect_equal(extract_year_from_creel_id("CREEL_1999_001"), 1999)
  expect_error(extract_year_from_creel_id("invalid"))
  expect_error(extract_year_from_creel_id("CREEL_2023_01"))
})

test_that("extract_sequence_from_creel_id works correctly", {
  expect_equal(extract_sequence_from_creel_id("CREEL_2023_001"), 1)
  expect_equal(extract_sequence_from_creel_id("CREEL_2023_999"), 999)
  expect_equal(extract_sequence_from_creel_id("CREEL_2023_010"), 10)
  expect_error(extract_sequence_from_creel_id("invalid"))
  expect_error(extract_sequence_from_creel_id("CREEL_2023_1"))
})

test_that("area conversion functions work correctly", {
  expect_equal(acres_to_hectares(1000), 404.686, tolerance = 0.001)
  expect_equal(hectares_to_acres(404.686), 1000, tolerance = 0.001)
  expect_equal(acres_to_hectares(0), 0)
  expect_equal(hectares_to_acres(0), 0)
  
  # Test round-trip conversion
  original_acres <- 1234.5
  converted_hectares <- acres_to_hectares(original_acres)
  back_to_acres <- hectares_to_acres(converted_hectares)
  expect_equal(back_to_acres, original_acres, tolerance = 0.001)
  
  expect_error(acres_to_hectares("invalid"))
  expect_error(hectares_to_acres("invalid"))
})

test_that("create_days_in_creel works correctly", {
  start_date <- as.Date("2023-01-01")
  end_date <- as.Date("2023-01-07")
  
  days <- create_days_in_creel(c(start_date, end_date))
  
  expect_s3_class(days, "data.frame")
  expect_equal(nrow(days), 7)
  expect_equal(days$date[1], start_date)
  expect_equal(days$date[7], end_date)
  
  # Check column names
  expect_true(all(c("date", "month", "day", "day_type") %in% names(days)))
  
  # Check day types
  expect_true(all(days$day_type %in% c("weekday", "weekend")))
  
  # Check months
  expect_true(all(days$month == 1))
  
  # Test error handling
  expect_error(create_days_in_creel("invalid"))
  expect_error(create_days_in_creel(c(start_date))) # Missing end date
  expect_error(create_days_in_creel(c(start_date, end_date, end_date))) # Too many dates
})

test_that("convert_legacy_names works correctly", {
  legacy_names <- c("cd_Date", "cd_Period", "BankAnglers", "BoatAnglers")
  expected <- c("date", "period", "bank_anglers", "boat_anglers")
  
  converted <- convert_legacy_names(legacy_names)
  expect_equal(converted, expected)
  
  # Test edge cases
  expect_equal(convert_legacy_names(character(0)), character(0))
  expect_equal(convert_legacy_names("simple"), "simple")
  expect_equal(convert_legacy_names("CD_Date"), "c_d_date")
  
  expect_error(convert_legacy_names(123))
  expect_error(convert_legacy_names(NULL))
})

test_that("convert_to_legacy_names works correctly", {
  new_names <- c("date", "period", "bank_anglers", "boat_anglers")
  expected <- c("cd_Date", "cd_Period", "cd_BankAnglers", "cd_BoatAnglers")
  
  converted <- convert_to_legacy_names(new_names, "cd")
  expect_equal(converted, expected)
  
  # Test different prefixes
  converted_ii <- convert_to_legacy_names(new_names, "ii")
  expected_ii <- c("ii_Date", "ii_Period", "ii_BankAnglers", "ii_BoatAnglers")
  expect_equal(converted_ii, expected_ii)
  
  # Test edge cases
  expect_equal(convert_to_legacy_names(character(0), "cd"), character(0))
  expect_equal(convert_to_legacy_names("simple", "cd"), "cd_Simple")
  
  expect_error(convert_to_legacy_names(123, "cd"))
  expect_error(convert_to_legacy_names(new_names, 123))
})

test_that("check_legacy_data_complete works correctly", {
  # Test complete data
  complete_data <- list(
    counts = data.frame(cd_Date = as.Date("2023-01-01")),
    interviews = data.frame(ii_Date = as.Date("2023-01-01")),
    catch = data.frame(ir_Species = "Bass")
  )
  
  expect_true(check_legacy_data_complete(complete_data))
  
  # Test incomplete data
  incomplete_data <- list(
    counts = data.frame(cd_Date = as.Date("2023-01-01")),
    interviews = data.frame(ii_Date = as.Date("2023-01-01"))
  )
  expect_false(check_legacy_data_complete(incomplete_data))
  
  # Test wrong types
  wrong_types <- list(
    counts = "not a data frame",
    interviews = data.frame(ii_Date = as.Date("2023-01-01")),
    catch = data.frame(ir_Species = "Bass")
  )
  expect_false(check_legacy_data_complete(wrong_types))
  
  # Test empty list
  expect_false(check_legacy_data_complete(list()))
  
  # Test NULL
  expect_false(check_legacy_data_complete(NULL))
})

test_that("create_sample_legacy_data works correctly", {
  # Test counts data
  counts <- create_sample_legacy_data(10, "counts", "CREEL_2023_001")
  expect_s3_class(counts, "data.frame")
  expect_equal(nrow(counts), 10)
  expect_true(all(counts$cd_CreelUID == "CREEL_2023_001"))
  expect_true(all(c("cd_Date", "cd_Period", "cd_Section", "BankAnglers", "BoatAnglers") %in% names(counts)))
  
  # Test interviews data
  interviews <- create_sample_legacy_data(5, "interviews", "CREEL_2023_002")
  expect_s3_class(interviews, "data.frame")
  expect_equal(nrow(interviews), 5)
  expect_true(all(interviews$ii_Date >= as.Date("2023-01-01")))
  expect_true(all(interviews$ii_Date <= as.Date("2023-12-31")))
  
  # Test catch data
  catch <- create_sample_legacy_data(8, "catch", "CREEL_2024_001")
  expect_s3_class(catch, "data.frame")
  expect_equal(nrow(catch), 8)
  expect_true(all(catch$ir_UID %in% sprintf("INT%03d", 1:4)))
  
  # Test error handling
  expect_error(create_sample_legacy_data(-1, "counts", "CREEL_2023_001"))
  expect_error(create_sample_legacy_data(10, "invalid", "CREEL_2023_001"))
  expect_error(create_sample_legacy_data(10, "counts", "invalid"))
})

test_that("summarize_legacy_data works correctly", {
  # Create sample data
  legacy_data <- list(
    counts = create_sample_legacy_data(10, "counts", "CREEL_2023_001"),
    interviews = create_sample_legacy_data(5, "interviews", "CREEL_2023_001"),
    catch = create_sample_legacy_data(8, "catch", "CREEL_2023_001")
  )
  
  summary <- summarize_legacy_data(legacy_data)
  
  expect_type(summary, "list")
  expect_true(all(c("counts_summary", "interviews_summary", "catch_summary") %in% names(summary)))
  
  # Check counts summary
  expect_equal(summary$counts_summary$total_records, 10)
  expect_type(summary$counts_summary$sections, "character")
  expect_type(summary$counts_summary$periods, "numeric")
  
  # Check interviews summary
  expect_equal(summary$interviews_summary$total_records, 5)
  expect_type(summary$interviews_summary$sections, "character")
  expect_true(is.numeric(summary$interviews_summary$avg_party_size))
  
  # Check catch summary
  expect_equal(summary$catch_summary$total_records, 8)
  expect_type(summary$catch_summary$species, "character")
  expect_type(summary$catch_summary$catch_types, "character")
  expect_true(is.numeric(summary$catch_summary$total_fish))
  
  # Test error handling
  expect_error(summarize_legacy_data(list()))
  expect_error(summarize_legacy_data("invalid"))
})

test_that("format_legacy_output works correctly", {
  # Create sample results
  results <- list(
    metadata = list(
      creel_id = "CREEL_2023_001",
      analysis_date = Sys.time(),
      package_version = "1.0.0"
    ),
    parameters = list(waterbody_info = list(code = "WB001")),
    daily_effort = data.frame(date = as.Date("2023-01-01"), effort = 100),
    party_fish = data.frame(species = "Bass", count = 50),
    effort_estimates = list(total_effort = 1000),
    catch_estimates = list(total_catch = 500),
    summary = list(summary_stats = "complete")
  )
  
  formatted <- format_legacy_output(results)
  
  expect_type(formatted, "list")
  expect_true(formatted$legacy_format)
  expect_equal(formatted$creel_id, "CREEL_2023_001")
  expect_true(all(c("parameters", "daily_effort", "party_fish", "effort_estimates", "catch_estimates", "summary") %in% names(formatted)))
  
  # Check attributes
  expect_true(!is.null(attr(formatted, "metadata")))
  
  # Test error handling
  expect_error(format_legacy_output("invalid"))
  expect_error(format_legacy_output(NULL))
})

test_that("validate_legacy_format works correctly", {
  # Test valid counts data
  counts <- create_sample_legacy_data(5, "counts", "CREEL_2023_001")
  expect_true(validate_legacy_format(counts, "counts"))
  
  # Test valid interviews data
  interviews <- create_sample_legacy_data(5, "interviews", "CREEL_2023_001")
  expect_true(validate_legacy_format(interviews, "interviews"))
  
  # Test valid catch data
  catch <- create_sample_legacy_data(5, "catch", "CREEL_2023_001")
  expect_true(validate_legacy_format(catch, "catch"))
  
  # Test invalid data
  invalid_counts <- counts[, -1] # Remove required column
  expect_false(validate_legacy_format(invalid_counts, "counts"))
  
  # Test wrong type
  expect_false(validate_legacy_format(counts, "invalid"))
  expect_false(validate_legacy_format("not a data frame", "counts"))
})

test_that("date conversion functions work correctly", {
  test_date <- as.Date("2023-01-15")
  legacy_str <- "01/15/2023"
  
  # Test conversion to legacy format
  converted_str <- convert_to_legacy_date(test_date)
  expect_equal(converted_str, legacy_str)
  
  # Test conversion from legacy format
  converted_date <- convert_legacy_date(legacy_str)
  expect_equal(converted_date, test_date)
  
  # Test round-trip conversion
  round_trip <- convert_legacy_date(convert_to_legacy_date(test_date))
  expect_equal(round_trip, test_date)
  
  # Test error handling
  expect_error(convert_to_legacy_date("invalid"))
  expect_error(convert_legacy_date("invalid"))
  expect_error(convert_legacy_date("15/01/2023")) # Wrong format
})

test_that("confidence interval calculation works correctly", {
  # Test normal case
  ci <- calculate_legacy_ci(100, 10, 50)
  expect_type(ci, "list")
  expect_true(all(c("lower", "upper", "conf_level", "margin_error") %in% names(ci)))
  expect_equal(ci$conf_level, 0.95)
  expect_true(ci$lower < 100 && ci$upper > 100)
  
  # Test edge cases
  ci_small_n <- calculate_legacy_ci(100, 10, 1)
  expect_true(all(is.na(c(ci_small_n$lower, ci_small_n$upper))))
  
  ci_zero_n <- calculate_legacy_ci(100, 10, 0)
  expect_true(all(is.na(c(ci_zero_n$lower, ci_zero_n$upper))))
  
  # Test different confidence levels
  ci_90 <- calculate_legacy_ci(100, 10, 50, conf_level = 0.90)
  expect_equal(ci_90$conf_level, 0.90)
  expect_true(ci_90$margin_error < ci$margin_error)
})

test_that("error and warning handlers work correctly", {
  # Test error handler
  error <- legacy_error_handler("Test error", "TEST_ERROR", list(creel_id = "CREEL_2023_001"))
  expect_type(error, "list")
  expect_true(error$error)
  expect_equal(error$message, "Test error")
  expect_equal(error$code, "TEST_ERROR")
  expect_equal(error$context$creel_id, "CREEL_2023_001")
  expect_true(!is.null(error$timestamp))
  
  # Test warning handler
  warning <- legacy_warning_handler("Test warning", "TEST_WARNING", list(creel_id = "CREEL_2023_001"))
  expect_type(warning, "list")
  expect_true(warning$warning)
  expect_equal(warning$message, "Test warning")
  expect_equal(warning$code, "TEST_WARNING")
  expect_equal(warning$context$creel_id, "CREEL_2023_001")
  expect_true(!is.null(warning$timestamp))
  
  # Test default values
  error_default <- legacy_error_handler("Default error")
  expect_equal(error_default$code, "GENERAL_ERROR")
  expect_equal(error_default$context, list())
})

test_that("legacy configuration works correctly", {
  config <- get_legacy_configuration()
  
  expect_type(config, "list")
  expect_true(all(c("database", "analysis", "output") %in% names(config)))
  
  # Check database configuration
  expect_type(config$database, "list")
  expect_true(all(c("host", "port", "name", "user") %in% names(config$database)))
  expect_equal(config$database$host, "129.93.168.13")
  expect_equal(config$database$port, 1433)
  
  # Check analysis configuration
  expect_type(config$analysis, "list")
  expect_equal(config$analysis$confidence_level, 0.95)
  expect_equal(config$analysis$min_sample_size, 30)
  
  # Check output configuration
  expect_type(config$output, "list")
  expect_true("csv" %in% config$output$formats)
  expect_true(config$output$include_metadata)
})

test_that("legacy database functions handle gracefully", {
  # These functions should return warnings since they're placeholders
  expect_warning(get_legacy_db_connection())
  expect_warning(query_legacy_database("SELECT * FROM counts"))
  expect_false(check_legacy_db_available())
})

test_that("helper functions handle edge cases", {
  # Test NA handling
  expect_false(validate_creel_id(NA))
  expect_error(extract_year_from_creel_id(NA))
  expect_error(extract_sequence_from_creel_id(NA))
  
  # Test empty strings
  expect_false(validate_creel_id(""))
  expect_error(extract_year_from_creel_id(""))
  
  # Test zero values
  expect_equal(acres_to_hectares(0), 0)
  expect_equal(hectares_to_acres(0), 0)
  
  # Test negative values
  expect_equal(acres_to_hectares(-100), -40.4686, tolerance = 0.001)
  
  # Test very large values
  expect_equal(acres_to_hectares(1000000), 404686)
})

test_that("helper functions maintain consistency", {
  # Test creel ID extraction consistency
  creel_id <- "CREEL_2023_001"
  year <- extract_year_from_creel_id(creel_id)
  sequence <- extract_sequence_from_creel_id(creel_id)
  
  expect_equal(year, 2023)
  expect_equal(sequence, 1)
  
  # Test name conversion consistency
  legacy_names <- c("cd_Date", "cd_Period")
  new_names <- convert_legacy_names(legacy_names)
  back_to_legacy <- convert_to_legacy_names(new_names, "cd")
  
  expect_equal(back_to_legacy, legacy_names)
  
  # Test date conversion consistency
  test_date <- as.Date("2023-06-15")
  legacy_str <- convert_to_legacy_date(test_date)
  back_to_date <- convert_legacy_date(legacy_str)
  
  expect_equal(back_to_date, test_date)
})