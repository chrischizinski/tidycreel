test_that("aggregate_cpue validates required inputs", {
  # Missing required columns
  bad_data <- tibble::tibble(
    interview_id = 1:10,
    hours_fished = runif(10, 1, 5)
    # Missing species and catch columns
  )
  svy <- survey::svydesign(ids = ~1, data = bad_data)

  expect_error(
    aggregate_cpue(
      bad_data, svy,
      species_values = c("bass", "pike"),
      group_name = "test"
    ),
    "Missing required columns"
  )
})

test_that("aggregate_cpue handles empty species_values", {
  data <- tibble::tibble(
    species = c("bass", "pike"),
    catch_kept = c(3, 2),
    hours_fished = c(4, 3)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    aggregate_cpue(
      data, svy,
      species_values = character(0),
      group_name = "empty",
      response = "catch_kept"
    ),
    "cannot be empty"
  )
})

test_that("aggregate_cpue warns about missing species", {
  data <- tibble::tibble(
    species = rep(c("bass", "pike"), each = 5),
    catch_kept = rpois(10, 3),
    hours_fished = runif(10, 2, 5)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_warning(
    aggregate_cpue(
      data, svy,
      species_values = c("bass", "walleye", "trout"),  # walleye and trout not in data
      group_name = "test",
      response = "catch_kept"
    ),
    "not in the data"
  )
})

test_that("aggregate_cpue errors when NO species match", {
  data <- tibble::tibble(
    species = c("bass", "pike"),
    catch_kept = c(3, 2),
    hours_fished = c(4, 3)
  )
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    aggregate_cpue(
      data, svy,
      species_values = c("walleye", "trout"),  # None in data
      group_name = "test",
      response = "catch_kept"
    ),
    "None of the species"
  )
})

test_that("aggregate_cpue produces correct structure", {
  # Create test data with multiple species
  set.seed(123)
  data <- tibble::tibble(
    species = rep(c("largemouth_bass", "smallmouth_bass", "bluegill"), each = 20),
    catch_kept = rpois(60, lambda = 3),
    catch_total = rpois(60, lambda = 5),
    hours_fished = runif(60, 2, 6)
  )

  svy <- survey::svydesign(ids = ~1, data = data)

  result <- aggregate_cpue(
    cpue_data = data,
    svy_design = svy,
    species_values = c("largemouth_bass", "smallmouth_bass"),
    group_name = "black_bass",
    response = "catch_kept"
  )

  # Check structure
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("species_group", "estimate", "se", "ci_low",
                         "ci_high", "deff", "n", "method", "diagnostics", "variance_info"))

  # Check values
  expect_equal(result$species_group, "black_bass")
  expect_type(result$estimate, "double")
  expect_type(result$se, "double")
  expect_type(result$n, "integer")
  expect_true(result$estimate > 0)
  expect_true(result$se > 0)
  expect_true(result$ci_low < result$estimate)
  expect_true(result$ci_high > result$estimate)
})

test_that("aggregate_cpue works with grouping variables", {
  set.seed(456)
  data <- tibble::tibble(
    location = rep(c("North", "South"), each = 30),
    species = rep(c("largemouth_bass", "smallmouth_bass", "pike"), times = 20),
    catch_kept = rpois(60, lambda = 2),
    hours_fished = runif(60, 2, 5)
  )

  svy <- survey::svydesign(ids = ~1, data = data)

  result <- aggregate_cpue(
    cpue_data = data,
    svy_design = svy,
    species_values = c("largemouth_bass", "smallmouth_bass"),
    group_name = "black_bass",
    by = "location",
    response = "catch_kept"
  )

  # Should have 2 rows (North and South)
  expect_equal(nrow(result), 2)
  expect_true("location" %in% names(result))
  expect_setequal(result$location, c("North", "South"))

  # Each row should have species_group
  expect_true(all(result$species_group == "black_bass"))
})

test_that("aggregate_cpue handles zeros correctly", {
  # Data where some interviews have zero catch of target species
  data <- tibble::tibble(
    species = c(rep("pike", 10), rep("bass", 10)),
    catch_kept = c(rep(3, 10), rep(0, 10)),
    hours_fished = runif(20, 2, 5)
  )

  svy <- survey::svydesign(ids = ~1, data = data)

  # Aggregate only bass (which has zero catch in this data)
  result <- aggregate_cpue(
    cpue_data = data,
    svy_design = svy,
    species_values = "bass",
    group_name = "bass_only",
    response = "catch_kept"
  )

  # Should complete without error
  expect_s3_class(result, "tbl_df")
  expect_equal(result$estimate, 0)
})

test_that("aggregate_cpue diagnostics include correct information", {
  data <- tibble::tibble(
    species = rep(c("largemouth_bass", "smallmouth_bass"), each = 10),
    catch_kept = rpois(20, 3),
    hours_fished = runif(20, 2, 5)
  )

  svy <- survey::svydesign(ids = ~1, data = data)

  result <- suppressWarnings(aggregate_cpue(
    data, svy,
    species_values = c("largemouth_bass", "smallmouth_bass", "spotted_bass"),
    group_name = "black_bass",
    response = "catch_kept"
  ))

  diag <- result$diagnostics[[1]]

  expect_type(diag, "list")
  expect_true("species_aggregated" %in% names(diag))
  expect_true("species_missing" %in% names(diag))
  expect_true("n_species" %in% names(diag))

  # Check that spotted_bass is listed as missing
  expect_true("spotted_bass" %in% diag$species_missing)
  expect_equal(diag$n_species, 2)  # Only 2 species present
})

test_that("aggregate_cpue works with different response types", {
  data <- tibble::tibble(
    species = rep(c("bass", "pike"), each = 10),
    catch_total = rpois(20, 5),
    catch_kept = rpois(20, 3),
    catch_released = rpois(20, 2),
    hours_fished = runif(20, 2, 5)
  )

  svy <- survey::svydesign(ids = ~1, data = data)

  # Test each response type
  result_total <- aggregate_cpue(
    data, svy,
    species_values = "bass",
    group_name = "bass",
    response = "catch_total"
  )

  result_kept <- aggregate_cpue(
    data, svy,
    species_values = "bass",
    group_name = "bass",
    response = "catch_kept"
  )

  result_released <- aggregate_cpue(
    data, svy,
    species_values = "bass",
    group_name = "bass",
    response = "catch_released"
  )

  # All should complete successfully
  expect_s3_class(result_total, "tbl_df")
  expect_s3_class(result_kept, "tbl_df")
  expect_s3_class(result_released, "tbl_df")

  # catch_total should generally be >= catch_kept (in expectation)
  # But with small samples and randomness, this isn't guaranteed
  # Just check they're all positive
  expect_true(result_total$estimate >= 0)
  expect_true(result_kept$estimate >= 0)
  expect_true(result_released$estimate >= 0)
})

test_that("aggregate_cpue matches individual species when only one species", {
  # Test that aggregating a single species gives same result as est_cpue for that species
  skip("Requires implementing est_cpue comparison - add after integration testing")
})

test_that("aggregate_cpue handles replicate weights", {
  # Test with svrepdesign
  skip("Replicate weights testing - add after basic functionality confirmed")
})
