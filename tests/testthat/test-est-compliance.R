# Tests for est_compliance() in R/creel-estimates-length.R

make_ld <- function(by_species = TRUE) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")

  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  d <- add_lengths(d, example_lengths, # nolint: object_usage_linter
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  if (by_species) {
    est_length_distribution(d, by = species, bin_width = 25) # nolint: object_usage_linter
  } else {
    est_length_distribution(d, bin_width = 25) # nolint: object_usage_linter
  }
}

# Guard tests ----

test_that("est_compliance() errors when ld is not creel_length_distribution", {
  expect_error(est_compliance(list(), min_length = 300), "creel_length_distribution")
  expect_error(est_compliance(data.frame(), min_length = 300), "creel_length_distribution")
})

test_that("est_compliance() errors when min_length is invalid", {
  ld <- make_ld()
  expect_error(est_compliance(ld, min_length = 0), "single positive")
  expect_error(est_compliance(ld, min_length = -1), "single positive")
  expect_error(est_compliance(ld, min_length = NA_real_), "single positive")
  expect_error(est_compliance(ld, min_length = c(300, 400)), "single positive")
  expect_error(est_compliance(ld, min_length = "300"), "single positive")
})

test_that("est_compliance() errors when conf_level is out of range", {
  ld <- make_ld()
  expect_error(est_compliance(ld, 300, conf_level = 0), "in (0, 1)", fixed = TRUE)
  expect_error(est_compliance(ld, 300, conf_level = 1), "in (0, 1)", fixed = TRUE)
})

# Return structure tests ----

test_that("est_compliance() returns creel_compliance data.frame", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)
  expect_s3_class(result, "creel_compliance")
  expect_s3_class(result, "data.frame")
})

test_that("est_compliance() returns expected columns (grouped)", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)
  expected_cols <- c("species", "min_length", "n_legal_est", "n_total_est",
                     "compliance_prop", "compliance_se",
                     "compliance_ci_lower", "compliance_ci_upper")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("est_compliance() returns expected columns (ungrouped)", {
  ld <- make_ld(by_species = FALSE)
  result <- est_compliance(ld, min_length = 300)
  expected_cols <- c("min_length", "n_legal_est", "n_total_est",
                     "compliance_prop", "compliance_se",
                     "compliance_ci_lower", "compliance_ci_upper")
  expect_true(all(expected_cols %in% names(result)))
  expect_false("species" %in% names(result))
})

test_that("est_compliance() stores method attributes", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 356)
  expect_equal(attr(result, "method"), "compliance")
  expect_equal(attr(result, "min_length"), 356)
  expect_equal(attr(result, "conf_level"), 0.95)
  expect_equal(attr(result, "by_vars"), "species")
})

# Grouping tests ----

test_that("grouped result has one row per species", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)
  expect_equal(nrow(result), length(unique(ld$species)))
  expect_setequal(result$species, unique(ld$species))
})

test_that("ungrouped result has one row", {
  ld <- make_ld(by_species = FALSE)
  result <- est_compliance(ld, min_length = 300)
  expect_equal(nrow(result), 1L)
})

# Numerical correctness tests ----

test_that("est_compliance() matches manual P = sum(I_h * N_h) / sum(N_h)", {
  ld <- make_ld()
  min_l <- 300
  result <- est_compliance(ld, min_length = min_l)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    legal <- rows$bin_lower >= min_l
    expected_p <- sum(rows$estimate[legal]) / sum(rows$estimate)
    actual_p <- result$compliance_prop[result$species == sp]
    expect_equal(actual_p, expected_p, tolerance = 1e-9,
                 label = paste("compliance_prop for species", sp))
  }
})

test_that("est_compliance() n_total_est matches sum(estimate)", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    expected_total <- sum(rows$estimate)
    actual_total <- result$n_total_est[result$species == sp]
    expect_equal(actual_total, expected_total, tolerance = 1e-9,
                 label = paste("n_total_est for species", sp))
  }
})

test_that("est_compliance() n_legal_est + n_illegal_est = n_total_est", {
  ld <- make_ld()
  min_l <- 300
  result <- est_compliance(ld, min_length = min_l)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    illegal_est <- sum(rows$estimate[rows$bin_lower < min_l])
    row <- result[result$species == sp, ]
    expect_equal(row$n_legal_est + illegal_est, row$n_total_est, tolerance = 1e-9,
                 label = paste("legal + illegal = total for species", sp))
  }
})

test_that("est_compliance() compliance_prop is in [0, 1]", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)
  expect_true(all(result$compliance_prop >= 0))
  expect_true(all(result$compliance_prop <= 1))
})

test_that("est_compliance() CI bounds are in [0, 1]", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)
  expect_true(all(result$compliance_ci_lower >= 0))
  expect_true(all(result$compliance_ci_upper <= 1))
})

# Boundary cases ----

test_that("est_compliance() compliance_prop = 1 when min_length below all bins", {
  ld <- make_ld(by_species = FALSE)
  result <- est_compliance(ld, min_length = 1)
  expect_equal(result$compliance_prop, 1.0, tolerance = 1e-9)
})

test_that("est_compliance() compliance_prop = 0 when min_length above all bins", {
  ld <- make_ld(by_species = FALSE)
  result <- est_compliance(ld, min_length = 1e6)
  expect_equal(result$compliance_prop, 0.0, tolerance = 1e-9)
})

# conf_level tests ----

test_that("est_compliance() inherits conf_level from ld when not supplied", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300)
  expect_equal(attr(result, "conf_level"), attr(ld, "conf_level"))
})

test_that("est_compliance() uses supplied conf_level over ld attribute", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 300, conf_level = 0.90)
  expect_equal(attr(result, "conf_level"), 0.90)
})

test_that("min_length column in result equals supplied min_length", {
  ld <- make_ld()
  result <- est_compliance(ld, min_length = 356)
  expect_true(all(result$min_length == 356))
})
