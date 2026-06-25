# Tests for est_biomass() in R/creel-estimates-length.R

# Fixtures ----

make_ld_grouped <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")

  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(add_interviews(
    d,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  d <- add_lengths(
    d,
    example_lengths, # nolint: object_usage_linter
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  est_length_distribution(d, by = species, bin_width = 25) # nolint: object_usage_linter
}

make_ld_ungrouped <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")

  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(add_interviews(
    d,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_lumber
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  d <- add_lengths(
    d,
    example_lengths, # nolint: object_usage_linter
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  est_length_distribution(d, bin_width = 25) # nolint: object_usage_linter
}

# Guard tests ----

test_that("est_biomass() errors when ld is not creel_length_distribution", {
  expect_error(est_biomass(list(), a = 0.01, b = 3), "creel_length_distribution")
  expect_error(est_biomass(data.frame(), a = 0.01, b = 3), "creel_length_distribution")
})

test_that("est_biomass() errors when a is non-positive or non-numeric", {
  ld <- make_ld_grouped()
  expect_error(est_biomass(ld, a = 0, b = 3), "single positive")
  expect_error(est_biomass(ld, a = -1, b = 3), "single positive")
  expect_error(est_biomass(ld, a = NA_real_, b = 3), "single positive")
  expect_error(est_biomass(ld, a = c(0.01, 0.02), b = 3), "single positive")
  expect_error(est_biomass(ld, a = "x", b = 3), "single positive")
})

test_that("est_biomass() errors when b is non-numeric or NA", {
  ld <- make_ld_grouped()
  expect_error(est_biomass(ld, a = 0.01, b = NA_real_), "single numeric")
  expect_error(est_biomass(ld, a = 0.01, b = "x"), "single numeric")
  expect_error(est_biomass(ld, a = 0.01, b = c(3, 4)), "single numeric")
})

test_that("est_biomass() errors when conf_level is out of range", {
  ld <- make_ld_grouped()
  expect_error(est_biomass(ld, a = 0.01, b = 3, conf_level = 0), "in (0, 1)", fixed = TRUE)
  expect_error(est_biomass(ld, a = 0.01, b = 3, conf_level = 1), "in (0, 1)", fixed = TRUE)
  expect_error(est_biomass(ld, a = 0.01, b = 3, conf_level = -0.5), "in (0, 1)", fixed = TRUE)
})

# Return structure tests ----

test_that("est_biomass() returns creel_biomass data.frame", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expect_s3_class(result, "creel_biomass")
  expect_s3_class(result, "data.frame")
})

test_that("est_biomass() returns expected columns (grouped)", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expected_cols <- c(
    "species",
    "biomass_estimate",
    "biomass_se",
    "biomass_ci_lower",
    "biomass_ci_upper"
  )
  expect_true(all(expected_cols %in% names(result)))
})

test_that("est_biomass() returns expected columns (ungrouped)", {
  ld <- make_ld_ungrouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expected_cols <- c("biomass_estimate", "biomass_se", "biomass_ci_lower", "biomass_ci_upper")
  expect_true(all(expected_cols %in% names(result)))
  expect_false("species" %in% names(result))
})

test_that("est_biomass() stores method attributes", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.0088, b = 3.1)
  expect_equal(attr(result, "method"), "biomass")
  expect_equal(attr(result, "a"), 0.0088)
  expect_equal(attr(result, "b"), 3.1)
  expect_equal(attr(result, "conf_level"), 0.95)
  expect_equal(attr(result, "by_vars"), "species")
})

# Grouping tests ----

test_that("grouped result has one row per species", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  species_in_ld <- unique(ld$species)
  expect_equal(nrow(result), length(species_in_ld))
  expect_setequal(result$species, species_in_ld)
})

test_that("ungrouped result has one row", {
  ld <- make_ld_ungrouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expect_equal(nrow(result), 1L)
})

# Numerical correctness tests ----

test_that("est_biomass() biomass_estimate matches manual W = a * L_mid^b * N_h sum", {
  ld <- make_ld_grouped()
  a <- 0.01
  b <- 3.0
  result <- est_biomass(ld, a = a, b = b)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    expected_biomass <- sum(a * l_mid^b * rows$estimate)
    actual_biomass <- result$biomass_estimate[result$species == sp]
    expect_equal(
      actual_biomass,
      expected_biomass,
      tolerance = 1e-9,
      label = paste("biomass for species", sp)
    )
  }
})

test_that("est_biomass() biomass_se matches delta method sqrt(sum(w^2 * se^2))", {
  ld <- make_ld_grouped()
  a <- 0.01
  b <- 3.0
  result <- est_biomass(ld, a = a, b = b)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    w_h <- a * l_mid^b
    expected_se <- sqrt(sum(w_h^2 * rows$se^2))
    actual_se <- result$biomass_se[result$species == sp]
    expect_equal(actual_se, expected_se, tolerance = 1e-9, label = paste("SE for species", sp))
  }
})

test_that("est_biomass() CI width equals 2 * z * se", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3, conf_level = 0.95)
  z <- qnorm(0.975)
  ci_half <- (result$biomass_ci_upper - result$biomass_ci_lower) / 2
  expect_equal(ci_half, z * result$biomass_se, tolerance = 1e-9)
})

test_that("est_biomass() CI is symmetric around estimate", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  upper_dist <- result$biomass_ci_upper - result$biomass_estimate
  lower_dist <- result$biomass_estimate - result$biomass_ci_lower
  expect_equal(upper_dist, lower_dist, tolerance = 1e-9)
})

test_that("est_biomass() biomass_estimate is positive when lengths > 0", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expect_true(all(result$biomass_estimate > 0))
})

test_that("est_biomass() biomass_se is non-negative", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expect_true(all(result$biomass_se >= 0))
})

# conf_level inheritance ----

test_that("est_biomass() inherits conf_level from ld when not supplied", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3)
  expect_equal(attr(result, "conf_level"), attr(ld, "conf_level"))
})

test_that("est_biomass() uses supplied conf_level over ld attribute", {
  ld <- make_ld_grouped()
  result <- est_biomass(ld, a = 0.01, b = 3, conf_level = 0.90)
  expect_equal(attr(result, "conf_level"), 0.90)
  z_90 <- qnorm(0.95)
  ci_half <- (result$biomass_ci_upper - result$biomass_ci_lower) / 2
  expect_equal(ci_half, z_90 * result$biomass_se, tolerance = 1e-9)
})

# b edge cases ----

test_that("est_biomass() works with b = 1 (linear weight)", {
  ld <- make_ld_ungrouped()
  result <- est_biomass(ld, a = 1, b = 1)
  rows <- ld
  l_mid <- (rows$bin_lower + rows$bin_upper) / 2
  expected <- sum(1 * l_mid^1 * rows$estimate)
  expect_equal(result$biomass_estimate, expected, tolerance = 1e-9)
})

test_that("est_biomass() works with b = 3 (cubic weight, typical fish)", {
  ld <- make_ld_ungrouped()
  result <- est_biomass(ld, a = 0.0088, b = 3.0)
  expect_true(is.numeric(result$biomass_estimate))
  expect_true(result$biomass_estimate > 0)
})
