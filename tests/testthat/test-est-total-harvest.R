test_that("est_total_harvest validates required inputs", {
  # Missing required columns in effort_est
  bad_effort <- tibble::tibble(
    estimate = 100
    # Missing 'se' column
  )
  good_cpue <- tibble::tibble(
    estimate = 2.5,
    se = 0.3,
    n = 50
  )

  expect_error(
    est_total_harvest(bad_effort, good_cpue),
    "Missing required columns"
  )

  # Missing required columns in cpue_est
  good_effort <- tibble::tibble(
    estimate = 100,
    se = 10,
    n = 30
  )
  bad_cpue <- tibble::tibble(
    estimate = 2.5
    # Missing 'se' column
  )

  expect_error(
    est_total_harvest(good_effort, bad_cpue),
    "Missing required columns"
  )
})

test_that("est_total_harvest requires matching number of rows when by = NULL", {
  effort <- tibble::tibble(
    estimate = c(100, 150),
    se = c(10, 15),
    n = c(30, 30)
  )

  cpue <- tibble::tibble(
    estimate = 2.5,
    se = 0.3,
    n = 50
  )

  expect_error(
    est_total_harvest(effort, cpue, by = NULL),
    "must have exactly 1 row"
  )
})

test_that("est_total_harvest validates correlation parameter", {
  effort <- tibble::tibble(estimate = 100, se = 10, n = 30)
  cpue <- tibble::tibble(estimate = 2.5, se = 0.3, n = 50)

  # Correlation out of range
  expect_error(
    est_total_harvest(effort, cpue, correlation = 1.5),
    "between -1 and 1"
  )

  expect_error(
    est_total_harvest(effort, cpue, correlation = -1.5),
    "between -1 and 1"
  )

  # Auto correlation not yet implemented
  expect_error(
    est_total_harvest(effort, cpue, correlation = "auto"),
    "not yet implemented"
  )
})

test_that("est_total_harvest produces correct estimates with known values", {
  # Simple case: E = 100, C = 2.5 => H = 250
  effort <- tibble::tibble(
    estimate = 100,
    se = 10,
    n = 30
  )

  cpue <- tibble::tibble(
    estimate = 2.5,
    se = 0.3,
    n = 50
  )

  result <- est_total_harvest(
    effort, cpue,
    response = "catch_kept",
    correlation = NULL
  )

  # Check structure
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("estimate", "se", "ci_low", "ci_high", "deff", "n", "method", "diagnostics", "variance_info"))

  # Check estimate
  expect_equal(result$estimate, 100 * 2.5)
  expect_equal(result$estimate, 250)

  # Check variance propagation (independent)
  # Var(H) = E^2 * Var(C) + C^2 * Var(E)
  # Var(H) = 100^2 * 0.3^2 + 2.5^2 * 10^2
  # Var(H) = 10000 * 0.09 + 6.25 * 100
  # Var(H) = 900 + 625 = 1525
  # SE(H) = sqrt(1525) ≈ 39.05
  expected_var <- 100^2 * 0.3^2 + 2.5^2 * 10^2
  expected_se <- sqrt(expected_var)

  expect_equal(result$se, expected_se)

  # Check sample size (minimum)
  expect_equal(result$n, 30)

  # Check method
  expect_match(result$method, "product:catch_kept:independent")
})

test_that("est_total_harvest handles correlated estimates correctly", {
  effort <- tibble::tibble(
    estimate = 100,
    se = 10,
    n = 50
  )

  cpue <- tibble::tibble(
    estimate = 2.5,
    se = 0.3,
    n = 50
  )

  # Positive correlation
  result_corr <- est_total_harvest(
    effort, cpue,
    correlation = 0.5,
    response = "catch_total"
  )

  # Variance with correlation:
  # Var(H) = E^2 * Var(C) + C^2 * Var(E) + 2*E*C*Cov(E,C)
  # Cov(E,C) = rho * SE(E) * SE(C) = 0.5 * 10 * 0.3 = 1.5
  # Var(H) = 100^2 * 0.09 + 2.5^2 * 100 + 2*100*2.5*1.5
  # Var(H) = 900 + 625 + 750 = 2275
  E <- 100
  C <- 2.5
  SE_E <- 10
  SE_C <- 0.3
  rho <- 0.5

  Cov_EC <- rho * SE_E * SE_C
  expected_var <- E^2 * SE_C^2 + C^2 * SE_E^2 + 2 * E * C * Cov_EC
  expected_se <- sqrt(expected_var)

  expect_equal(result_corr$se, expected_se)
  expect_match(result_corr$method, "correlated")

  # Negative correlation
  result_neg <- est_total_harvest(
    effort, cpue,
    correlation = -0.3
  )

  Cov_EC_neg <- -0.3 * SE_E * SE_C
  expected_var_neg <- E^2 * SE_C^2 + C^2 * SE_E^2 + 2 * E * C * Cov_EC_neg
  expected_se_neg <- sqrt(expected_var_neg)

  expect_equal(result_neg$se, expected_se_neg)
})

test_that("est_total_harvest works with grouped data", {
  # Realistic scenario: Effort by location, CPUE by location and species
  # Effort is estimated at location level (all species combined)
  effort <- tibble::tibble(
    location = c("North", "South"),
    estimate = c(100, 150),
    se = c(10, 15),
    n = c(30, 30)
  )

  # CPUE is estimated by location and species
  cpue <- tibble::tibble(
    location = rep(c("North", "South"), each = 2),
    species = rep(c("bass", "pike"), times = 2),
    estimate = c(2.0, 1.5, 2.5, 1.8),
    se = c(0.3, 0.2, 0.4, 0.25),
    n = c(50, 50, 50, 50)
  )

  # Join by location only - effort applies to all species within location
  result <- est_total_harvest(
    effort, cpue,
    by = "location",
    response = "catch_kept"
  )

  # Should have 4 rows (2 locations × 2 species)
  expect_equal(nrow(result), 4)

  # Check grouping columns present
  expect_true("location" %in% names(result))
  expect_true("species" %in% names(result))

  # Check each combination
  expect_setequal(result$location, c("North", "North", "South", "South"))
  expect_setequal(result$species, c("bass", "pike", "bass", "pike"))

  # Check specific calculation (North, bass)
  # North effort (100) × North bass CPUE (2.0) = 200
  north_bass <- result |> dplyr::filter(location == "North", species == "bass")
  expect_equal(north_bass$estimate, 100 * 2.0)
  expect_equal(north_bass$estimate, 200)

  # Check another (South, pike)
  # South effort (150) × South pike CPUE (1.8) = 270
  south_pike <- result |> dplyr::filter(location == "South", species == "pike")
  expect_equal(south_pike$estimate, 150 * 1.8)
  expect_equal(south_pike$estimate, 270)
})

test_that("est_total_harvest handles different response types", {
  effort <- tibble::tibble(
    estimate = 100,
    se = 10,
    n = 30
  )

  cpue_total <- tibble::tibble(estimate = 5.0, se = 0.5, n = 50)
  cpue_kept <- tibble::tibble(estimate = 3.0, se = 0.4, n = 50)
  cpue_released <- tibble::tibble(estimate = 2.0, se = 0.3, n = 50)

  result_total <- est_total_harvest(effort, cpue_total, response = "catch_total")
  result_kept <- est_total_harvest(effort, cpue_kept, response = "catch_kept")
  result_released <- est_total_harvest(effort, cpue_released, response = "catch_released")

  # Check methods reflect response type
  expect_match(result_total$method, "catch_total")
  expect_match(result_kept$method, "catch_kept")
  expect_match(result_released$method, "catch_released")

  # Check estimates
  expect_equal(result_total$estimate, 500)
  expect_equal(result_kept$estimate, 300)
  expect_equal(result_released$estimate, 200)

  # Verify relationship (approximately): total = kept + released
  expect_equal(result_total$estimate, result_kept$estimate + result_released$estimate)
})

test_that("est_total_harvest handles zero estimates", {
  # Zero effort
  effort_zero <- tibble::tibble(estimate = 0, se = 0, n = 30)
  cpue <- tibble::tibble(estimate = 2.5, se = 0.3, n = 50)

  result_zero_effort <- est_total_harvest(effort_zero, cpue)

  expect_equal(result_zero_effort$estimate, 0)
  # Variance should still be calculated: 0^2 * Var(C) + C^2 * Var(E) = C^2 * Var(E)
  expect_equal(result_zero_effort$se, 2.5 * 0)
  expect_equal(result_zero_effort$se, 0)

  # Zero CPUE
  effort <- tibble::tibble(estimate = 100, se = 10, n = 30)
  cpue_zero <- tibble::tibble(estimate = 0, se = 0.1, n = 50)

  result_zero_cpue <- est_total_harvest(effort, cpue_zero)

  expect_equal(result_zero_cpue$estimate, 0)
  # Variance: E^2 * Var(C) + 0^2 * Var(E) = E^2 * Var(C)
  expected_se <- 100 * 0.1
  expect_equal(result_zero_cpue$se, expected_se)
})

test_that("est_total_harvest warns when groups don't match", {
  effort <- tibble::tibble(
    location = c("North", "South"),
    estimate = c(100, 150),
    se = c(10, 15),
    n = c(30, 30)
  )

  cpue <- tibble::tibble(
    location = c("North", "East"),  # East doesn't match South
    estimate = c(2.5, 2.0),
    se = c(0.3, 0.25),
    n = c(50, 50)
  )

  expect_warning(
    result <- est_total_harvest(effort, cpue, by = "location"),
    "Not all groups matched"
  )

  # Should only include matching group (North)
  expect_equal(nrow(result), 1)
  expect_equal(result$location, "North")
})

test_that("est_total_harvest errors when no groups match", {
  effort <- tibble::tibble(
    location = c("North", "South"),
    estimate = c(100, 150),
    se = c(10, 15),
    n = c(30, 30)
  )

  cpue <- tibble::tibble(
    location = c("East", "West"),  # No overlap
    estimate = c(2.5, 2.0),
    se = c(0.3, 0.25),
    n = c(50, 50)
  )

  expect_error(
    est_total_harvest(effort, cpue, by = "location"),
    "No matching groups"
  )
})

test_that("est_total_harvest errors when grouping variable missing", {
  effort <- tibble::tibble(
    location = "North",
    estimate = 100,
    se = 10,
    n = 30
  )

  cpue <- tibble::tibble(
    species = "bass",  # Different grouping variable
    estimate = 2.5,
    se = 0.3,
    n = 50
  )

  expect_error(
    est_total_harvest(effort, cpue, by = "location"),
    "not found in"
  )
})

test_that("est_total_harvest includes diagnostics when requested", {
  effort <- tibble::tibble(estimate = 100, se = 10, n = 30)
  cpue <- tibble::tibble(estimate = 2.5, se = 0.3, n = 50)

  result_with_diag <- est_total_harvest(effort, cpue, diagnostics = TRUE)
  result_no_diag <- est_total_harvest(effort, cpue, diagnostics = FALSE)

  # Both should have diagnostics column
  expect_true("diagnostics" %in% names(result_with_diag))
  expect_true("diagnostics" %in% names(result_no_diag))

  # With diagnostics should have content
  diag <- result_with_diag$diagnostics[[1]]
  expect_type(diag, "list")
  expect_true("effort_estimate" %in% names(diag))
  expect_true("cpue_estimate" %in% names(diag))
  expect_true("correlation_used" %in% names(diag))
  expect_true("variance_components" %in% names(diag))

  expect_equal(diag$effort_estimate, 100)
  expect_equal(diag$cpue_estimate, 2.5)
  expect_equal(diag$correlation_used, 0)

  # Without diagnostics should be empty
  diag_empty <- result_no_diag$diagnostics[[1]]
  expect_equal(length(diag_empty), 0)
})

test_that("est_total_harvest diagnostics include covariance when correlated", {
  effort <- tibble::tibble(estimate = 100, se = 10, n = 50)
  cpue <- tibble::tibble(estimate = 2.5, se = 0.3, n = 50)

  result <- est_total_harvest(effort, cpue, correlation = 0.5, diagnostics = TRUE)

  diag <- result$diagnostics[[1]]
  expect_true("covariance_EC" %in% names(diag))
  expect_equal(diag$covariance_EC, 0.5 * 10 * 0.3)
  expect_equal(diag$correlation_used, 0.5)
})

test_that("est_total_harvest confidence intervals are valid", {
  effort <- tibble::tibble(estimate = 100, se = 10, n = 30)
  cpue <- tibble::tibble(estimate = 2.5, se = 0.3, n = 50)

  # Default 95% CI
  result_95 <- est_total_harvest(effort, cpue, conf_level = 0.95)

  expect_true(result_95$ci_low < result_95$estimate)
  expect_true(result_95$ci_high > result_95$estimate)
  expect_true(result_95$ci_high > result_95$ci_low)

  # 90% CI should be narrower
  result_90 <- est_total_harvest(effort, cpue, conf_level = 0.90)

  expect_true(result_90$ci_high - result_90$ci_low < result_95$ci_high - result_95$ci_low)
})

test_that("est_total_harvest works with aggregate_cpue output", {
  # Create simulated interview data
  set.seed(123)
  interviews <- tibble::tibble(
    species = rep(c("largemouth_bass", "smallmouth_bass", "pike"), each = 20),
    catch_kept = rpois(60, lambda = 3),
    hours_fished = runif(60, 2, 6)
  )

  svy <- survey::svydesign(ids = ~1, data = interviews)

  # Aggregate black bass species
  cpue_black_bass <- aggregate_cpue(
    cpue_data = interviews,
    svy_design = svy,
    species_values = c("largemouth_bass", "smallmouth_bass"),
    group_name = "black_bass",
    response = "catch_kept"
  )

  # Create effort estimate
  effort <- tibble::tibble(
    estimate = 1000,
    se = 100,
    n = 30
  )

  # Calculate total harvest for aggregated species
  result <- est_total_harvest(effort, cpue_black_bass, response = "catch_kept")

  # Should complete without error
  expect_s3_class(result, "tbl_df")
  expect_true(result$estimate > 0)
  expect_true(result$se > 0)
})

test_that("est_total_harvest rejects separate_ratio method (not yet implemented)", {
  effort <- tibble::tibble(estimate = 100, se = 10, n = 30)
  cpue <- tibble::tibble(estimate = 2.5, se = 0.3, n = 50)

  expect_error(
    est_total_harvest(effort, cpue, method = "separate_ratio"),
    "not yet implemented"
  )
})

test_that("est_total_harvest validates input types", {
  # Non-data.frame effort_est
  expect_error(
    est_total_harvest(
      "not a dataframe",
      tibble::tibble(estimate = 2.5, se = 0.3, n = 50)
    ),
    "must be a data frame"
  )

  # Non-data.frame cpue_est
  expect_error(
    est_total_harvest(
      tibble::tibble(estimate = 100, se = 10, n = 30),
      "not a dataframe"
    ),
    "must be a data frame"
  )
})
