test_that("decompose_variance works with survey design objects", {
  # Create test data
  test_data <- data.frame(
    date = rep(as.Date("2023-06-01") + 0:9, each = 3),
    stratum = rep(c("weekday", "weekend"), each = 15),
    shift = rep(c("morning", "afternoon", "evening"), 10),
    anglers_count = rpois(30, lambda = 5),
    location = rep(c("site_a", "site_b"), 15)
  )
  
  # Create survey design
  design <- survey::svydesign(
    ids = ~1,
    strata = ~stratum,
    data = test_data,
    weights = rep(1, nrow(test_data))
  )
  
  # Test basic variance decomposition
  result <- decompose_variance(
    design = design,
    response = "anglers_count",
    cluster_vars = c("stratum", "location")
  )
  
  # Check structure
  expect_s3_class(result, "variance_decomp")
  expect_true("components" %in% names(result))
  expect_true("proportions" %in% names(result))
  expect_true("method_info" %in% names(result))
  
  # Check components data frame
  expect_s3_class(result$components, "data.frame")
  expect_true("component" %in% names(result$components))
  expect_true("variance" %in% names(result$components))
  
  # Check method info
  expect_equal(result$method_info$method, "survey")
  expect_equal(result$method_info$response_variable, "anglers_count")
})

test_that("decompose_variance handles different methods", {
  # Create simple test data
  test_data <- data.frame(
    date = rep(as.Date("2023-06-01") + 0:4, each = 2),
    stratum = rep(c("A", "B"), 5),
    anglers_count = rpois(10, lambda = 3)
  )
  
  design <- survey::svydesign(
    ids = ~1,
    data = test_data,
    weights = rep(1, nrow(test_data))
  )
  
  # Test survey method (default)
  result_survey <- decompose_variance(
    design = design,
    response = "anglers_count",
    method = "survey"
  )
  
  expect_s3_class(result_survey, "variance_decomp")
  expect_equal(result_survey$method_info$method, "survey")
  
  # Test bootstrap method (should work but may give warnings)
  expect_warning(
    result_bootstrap <- decompose_variance(
      design = design,
      response = "anglers_count", 
      method = "bootstrap",
      n_bootstrap = 10  # Small number for testing
    )
  )
  
  expect_s3_class(result_bootstrap, "variance_decomp")
})

test_that("decompose_variance validates inputs correctly", {
  # Test with non-survey object
  expect_error(
    decompose_variance(
      design = data.frame(x = 1:5),
      response = "y"
    ),
    "must be a survey design object"
  )
  
  # Create valid design for other tests
  test_data <- data.frame(
    anglers_count = rpois(10, 3),
    stratum = rep(c("A", "B"), 5)
  )
  
  design <- survey::svydesign(
    ids = ~1,
    data = test_data,
    weights = rep(1, nrow(test_data))
  )
  
  # Test with invalid method
  expect_error(
    decompose_variance(design, "anglers_count", method = "invalid"),
    "Method must be one of"
  )
  
  # Test with missing response variable
  expect_error(
    decompose_variance(design, "missing_var"),
    "not found in design data"
  )
  
  # Test with missing cluster variables (should give error)
  expect_error(
    decompose_variance(design, "anglers_count", cluster_vars = "invalid_var"),
    "No valid cluster variables"
  )
})

test_that("print method works for variance_decomp objects", {
  # Create minimal test object
  test_data <- data.frame(
    anglers_count = rpois(6, 3),
    stratum = rep(c("A", "B"), 3)
  )
  
  design <- survey::svydesign(
    ids = ~1,
    data = test_data,
    weights = rep(1, nrow(test_data))
  )
  
  result <- decompose_variance(design, "anglers_count")
  
  # Test that print method works without error
  expect_no_error(print(result))
  expect_s3_class(result, "variance_decomp")
})

test_that("optimal_allocation function works", {
  # Create mock variance decomposition result
  mock_result <- list(
    components = data.frame(
      component = c("among_day", "among_stratum", "within_cluster"),
      variance = c(10, 5, 2),
      stringsAsFactors = FALSE
    ),
    proportions = c("among_day" = 0.59, "among_stratum" = 0.29, "within_cluster" = 0.12),
    method_info = list(method = "survey")
  )
  class(mock_result) <- "variance_decomp"
  
  # Test general allocation (no costs)
  allocation <- optimal_allocation(mock_result)
  
  expect_type(allocation, "list")
  expect_true(length(allocation) > 0)
  
  # Test with costs
  allocation_with_costs <- optimal_allocation(
    mock_result,
    total_budget = 1000,
    cost_per_unit = c("day" = 50, "stratum" = 30)
  )
  
  expect_type(allocation_with_costs, "list")
})

test_that("variance decomposition handles edge cases", {
  # Test with minimal data
  minimal_data <- data.frame(
    anglers_count = c(1, 2, 3),
    stratum = c("A", "A", "B")
  )
  
  design <- survey::svydesign(
    ids = ~1,
    data = minimal_data,
    weights = rep(1, nrow(minimal_data))
  )
  
  # Should work but may have warnings
  result <- decompose_variance(design, "anglers_count")
  
  expect_s3_class(result, "variance_decomp")
})

test_that("plot method works for variance_decomp objects", {
  skip_if_not_installed("ggplot2")
  
  # Create test variance decomposition result
  test_data <- data.frame(
    anglers_count = rpois(12, 4),
    stratum = rep(c("A", "B"), 6),
    date = rep(as.Date("2023-06-01") + 0:5, each = 2)
  )
  
  design <- survey::svydesign(
    ids = ~1,
    strata = ~stratum,
    data = test_data,
    weights = rep(1, nrow(test_data))
  )
  
  result <- decompose_variance(design, "anglers_count")
  
  # Test that plot method works
  expect_no_error(plot(result, type = "components"))
  
  # Test different plot types
  if (length(result$proportions) > 0) {
    expect_no_error(plot(result, type = "proportions"))
  }
  
  # Test invalid plot type
  expect_error(
    plot(result, type = "invalid"),
    "Plot type must be one of"
  )
})