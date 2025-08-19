library(testthat)
library(tidycreel)

# Test legacy wrapper functions
test_that("get_legacy_data works correctly", {
  # Test with valid creel ID
  data <- get_legacy_data("CREEL_2023_001", validate = TRUE)
  expect_type(data, "list")
  expect_true(all(c("counts", "interviews", "catch") %in% names(data)))
  expect_true(all(c("metadata") %in% names(data)))
  
  # Test data structure
  expect_s3_class(data$counts, "data.frame")
  expect_s3_class(data$interviews, "data.frame")
  expect_s3_class(data$catch, "data.frame")
  
  # Test metadata
  expect_equal(data$metadata$creel_id, "CREEL_2023_001")
  expect_equal(data$metadata$year, 2023)
  expect_equal(data$metadata$sequence, 1)
  
  # Test validation
  expect_error(get_legacy_data("invalid"))
  expect_error(get_legacy_data("CREEL_2023_01"))
  expect_error(get_legacy_data(NULL))
})

test_that("read_parameters works correctly", {
  # Test with sample data
  params <- read_parameters("CREEL_2023_001")
  expect_type(params, "list")
  
  # Test structure
  expect_true(all(c("waterbody_info", "do_codes", "days_in_creel", 
                   "sample_days", "water_levels", "period_probs") %in% names(params)))
  
  # Test waterbody info
  expect_type(params$waterbody_info, "list")
  expect_equal(params$waterbody_info$code, "WB001")
  expect_true(is.numeric(params$waterbody_info$waterbody_ac))
  expect_true(is.numeric(params$waterbody_info$waterbody_ha))
  
  # Test do codes
  expect_s3_class(params$do_codes, "data.frame")
  expect_true(all(c("do_highuse", "do_holidays", "do_sections") %in% names(params$do_codes)))
  
  # Test days in creel
  expect_s3_class(params$days_in_creel, "data.frame")
  expect_true(all(c("date", "month", "day", "day_type") %in% names(params$days_in_creel)))
  
  # Test with provided data
  legacy_data <- get_legacy_data("CREEL_2023_002")
  params2 <- read_parameters("CREEL_2023_002", legacy_data)
  expect_type(params2, "list")
})

test_that("daily_effort works correctly", {
  # Test basic functionality
  effort <- daily_effort("CREEL_2023_001")
  expect_s3_class(effort, "data.frame")
  
  # Test structure
  expect_true(all(c("date", "bank_anglers", "boat_anglers") %in% names(effort)))
  expect_true("legacy_format" %in% names(effort))
  expect_true(effort$legacy_format[1])
  
  # Test with provided data
  legacy_data <- get_legacy_data("CREEL_2023_002")
  effort2 <- daily_effort("CREEL_2023_002", legacy_data)
  expect_s3_class(effort2, "data.frame")
  
  # Test error handling
  expect_error(daily_effort("invalid"))
})

test_that("party_fish works correctly", {
  # Test basic functionality
  fish_stats <- party_fish("CREEL_2023_001")
  expect_s3_class(fish_stats, "data.frame")
  
  # Test structure
  expect_true("legacy_format" %in% names(fish_stats))
  expect_true(fish_stats$legacy_format[1])
  
  # Test type filtering
  harvest_only <- party_fish("CREEL_2023_001", type = "Harvest")
  expect_s3_class(harvest_only, "data.frame")
  
  multiple_types <- party_fish("CREEL_2023_001", type = c("Catch", "Harvest"))
  expect_s3_class(multiple_types, "data.frame")
  
  # Test with provided data
  legacy_data <- get_legacy_data("CREEL_2023_002")
  fish_stats2 <- party_fish("CREEL_2023_002", legacy_data = legacy_data)
  expect_s3_class(fish_stats2, "data.frame")
})

test_that("get_available_creels works correctly", {
  creels <- get_available_creels()
  expect_s3_class(creels, "data.frame")
  expect_true(all(c("Creel_UID", "Creel_Title", "Creel_DataComplete") %in% names(creels)))
  
  # Test structure
  expect_true(nrow(creels) > 0)
  expect_true(all(grepl("^CREEL_\\d{4}_\\d{3}$", creels$Creel_UID)))
  expect_true(all(creels$Creel_DataComplete %in% c(0, 1)))
})

test_that("run_legacy_analysis works correctly", {
  # Test basic functionality
  results <- run_legacy_analysis("CREEL_2023_001")
  expect_type(results, "list")
  
  # Test structure
  required_components <- c("parameters", "daily_effort", "party_fish", 
                          "effort_estimates", "catch_estimates", "summary", "metadata")
  expect_true(all(required_components %in% names(results)))
  
  # Test parameters
  expect_type(results$parameters, "list")
  expect_true(all(c("waterbody_info", "do_codes") %in% names(results$parameters)))
  
  # Test estimates
  expect_type(results$effort_estimates, "list")
  expect_type(results$catch_estimates, "list")
  expect_true("total_effort" %in% names(results$effort_estimates))
  expect_true("total_catch" %in% names(results$catch_estimates))
  
  # Test metadata
  expect_equal(results$metadata$creel_id, "CREEL_2023_001")
  expect_true(is.numeric(results$metadata$package_version))
  
  # Test output formats
  results_legacy <- run_legacy_analysis("CREEL_2023_002", output_format = "legacy")
  expect_true(results_legacy$legacy_format)
  
  results_both <- run_legacy_analysis("CREEL_2023_003", output_format = "both")
  expect_true(all(c("legacy_format", "new_format") %in% names(results_both)))
  
  # Test with plots
  results_plots <- run_legacy_analysis("CREEL_2023_004", include_plots = TRUE)
  expect_true("plots" %in% names(results_plots))
  
  # Test error handling
  expect_error(run_legacy_analysis("invalid"))
})

test_that("validate_legacy_analysis works correctly", {
  # Test valid results
  results <- run_legacy_analysis("CREEL_2023_001")
  expect_true(validate_legacy_analysis(results))
  
  # Test invalid results
  expect_false(validate_legacy_analysis(NULL))
  expect_false(validate_legacy_analysis("not a list"))
  expect_false(validate_legacy_analysis(list()))
  expect_false(validate_legacy_analysis(list(parameters = "invalid")))
})

test_that("export_legacy_results works correctly", {
  # Create temporary directory
  temp_dir <- tempdir()
  
  # Test basic export
  results <- run_legacy_analysis("CREEL_2023_001")
  files <- export_legacy_results(results, temp_dir, formats = "csv")
  expect_type(files, "character")
  expect_true(length(files) > 0)
  expect_true(all(file.exists(files)))
  
  # Test multiple formats
  files_multi <- export_legacy_results(results, temp_dir, formats = c("csv", "rds"))
  expect_type(files_multi, "character")
  expect_true(length(files_multi) > length(files))
  
  # Test with metadata
  files_meta <- export_legacy_results(results, temp_dir, include_metadata = TRUE)
  expect_true(any(grepl("metadata", files_meta)))
  
  # Test error handling
  expect_error(export_legacy_results("invalid"))
  expect_error(export_legacy_results(list()))
  
  # Clean up
  unlink(files, recursive = TRUE)
  unlink(files_multi, recursive = TRUE)
  unlink(files_meta, recursive = TRUE)
})

test_that("legacy wrappers handle edge cases", {
  # Test empty data
  empty_data <- list(
    counts = data.frame(),
    interviews = data.frame(),
    catch = data.frame()
  )
  
  # These should handle empty data gracefully
  expect_s3_class(daily_effort("CREEL_2023_001", empty_data), "data.frame")
  expect_s3_class(party_fish("CREEL_2023_001", legacy_data = empty_data), "data.frame")
  
  # Test single record
  single_data <- list(
    counts = data.frame(cd_CreelUID = "CREEL_2023_001", cd_Date = as.Date("2023-01-01"), 
                       cd_Period = 1, cd_Section = "A", BankAnglers = 5, BoatAnglers = 3),
    interviews = data.frame(ii_UID = "INT001", ii_Date = as.Date("2023-01-01"), 
                           ii_Section = "A", ii_PartySize = 2),
    catch = data.frame(ir_UID = "INT001", ir_Species = "Bass", ir_CatchType = "Harvest", ir_Num = 3)
  )
  
  results_single <- run_legacy_analysis("CREEL_2023_001", legacy_data = single_data)
  expect_true(validate_legacy_analysis(results_single))
})

test_that("legacy wrappers maintain consistency", {
  # Test that results are consistent across calls
  set.seed(123)
  results1 <- run_legacy_analysis("CREEL_2023_001")
  
  set.seed(123)
  results2 <- run_legacy_analysis("CREEL_2023_001")
  
  # Check that key components are identical
  expect_equal(results1$metadata$creel_id, results2$metadata$creel_id)
  expect_equal(results1$parameters$waterbody_info$code, results2$parameters$waterbody_info$code)
  
  # Test parameter extraction consistency
  params1 <- read_parameters("CREEL_2023_001")
  params2 <- read_parameters("CREEL_2023_001")
  
  expect_equal(params1$waterbody_info$code, params2$waterbody_info$code)
  expect_equal(params1$waterbody_info$waterbody_ac, params2$waterbody_info$waterbody_ac)
})

test_that("legacy wrappers handle different creel IDs", {
  # Test different years
  results_2023 <- run_legacy_analysis("CREEL_2023_001")
  results_2024 <- run_legacy_analysis("CREEL_2024_001")
  
  expect_equal(results_2023$metadata$year, 2023)
  expect_equal(results_2024$metadata$year, 2024)
  
  # Test different sequences
  results_001 <- run_legacy_analysis("CREEL_2023_001")
  results_002 <- run_legacy_analysis("CREEL_2023_002")
  
  expect_equal(results_001$parameters$waterbody_info$code, "WB001")
  expect_equal(results_002$parameters$waterbody_info$code, "WB002")
  
  # Test edge case sequences
  results_999 <- run_legacy_analysis("CREEL_2023_999")
  expect_equal(results_999$parameters$waterbody_info$code, "WB999")
})

test_that("legacy wrappers integrate with new API", {
  # Test that legacy wrappers can use new API functions
  legacy_data <- get_legacy_data("CREEL_2023_001")
  
  # Convert to new format
  counts_new <- legacy_data$counts
  names(counts_new) <- convert_legacy_names(names(counts_new))
  
  interviews_new <- legacy_data$interviews
  names(interviews_new) <- convert_legacy_names(names(interviews_new))
  
  # Test that new API functions work with converted data
  expect_s3_class(counts_new, "data.frame")
  expect_s3_class(interviews_new, "data.frame")
  
  # Test that legacy wrappers can be called from new API context
  results <- run_legacy_analysis("CREEL_2023_001")
  expect_true(validate_legacy_analysis(results))
})