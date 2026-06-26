# Tests for est_mean_length() in R/creel-estimates-length.R

make_ld <- function(by_species = TRUE) {
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
  if (by_species) {
    est_length_distribution(d, by = species, bin_width = 25) # nolint: object_usage_linter
  } else {
    est_length_distribution(d, bin_width = 25) # nolint: object_usage_linter
  }
}

# Guard tests ----

test_that("est_mean_length() errors when ld is not creel_length_distribution", {
  expect_error(est_mean_length(list()), "creel_length_distribution")
  expect_error(est_mean_length(data.frame()), "creel_length_distribution")
})

test_that("est_mean_length() errors when conf_level is out of range", {
  ld <- make_ld()
  expect_error(est_mean_length(ld, conf_level = 0), "in (0, 1)", fixed = TRUE)
  expect_error(est_mean_length(ld, conf_level = 1), "in (0, 1)", fixed = TRUE)
  expect_error(est_mean_length(ld, conf_level = -0.5), "in (0, 1)", fixed = TRUE)
})

# Return structure tests ----

test_that("est_mean_length() returns creel_mean_length data.frame", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  expect_s3_class(result, "creel_mean_length")
  expect_s3_class(result, "data.frame")
})

test_that("est_mean_length() returns expected columns (grouped)", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  expected_cols <- c(
    "species",
    "mean_length",
    "mean_length_se",
    "mean_length_ci_lower",
    "mean_length_ci_upper"
  )
  expect_true(all(expected_cols %in% names(result)))
})

test_that("est_mean_length() returns expected columns (ungrouped)", {
  ld <- make_ld(by_species = FALSE)
  result <- est_mean_length(ld)
  expected_cols <- c(
    "mean_length",
    "mean_length_se",
    "mean_length_ci_lower",
    "mean_length_ci_upper"
  )
  expect_true(all(expected_cols %in% names(result)))
  expect_false("species" %in% names(result))
})

test_that("est_mean_length() stores method attribute", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  expect_equal(attr(result, "method"), "mean_length")
  expect_equal(attr(result, "conf_level"), 0.95)
  expect_equal(attr(result, "by_vars"), "species")
})

# Grouping tests ----

test_that("grouped result has one row per species", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  expect_equal(nrow(result), length(unique(ld$species)))
  expect_setequal(result$species, unique(ld$species))
})

test_that("ungrouped result has one row", {
  ld <- make_ld(by_species = FALSE)
  result <- est_mean_length(ld)
  expect_equal(nrow(result), 1L)
})

# Numerical correctness tests ----

test_that("est_mean_length() matches manual sum(L_mid * N) / sum(N)", {
  ld <- make_ld()
  result <- est_mean_length(ld)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    expected <- sum(l_mid * rows$estimate) / sum(rows$estimate)
    actual <- result$mean_length[result$species == sp]
    expect_equal(actual, expected, tolerance = 1e-9, label = paste("mean_length for species", sp))
  }
})

test_that("est_mean_length() SE matches delta method (1/N) * sqrt(sum((L-mean)^2 * se^2))", {
  ld <- make_ld()
  result <- est_mean_length(ld)

  for (sp in unique(ld$species)) {
    rows <- ld[ld$species == sp, ]
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    n_total <- sum(rows$estimate)
    mean_l <- sum(l_mid * rows$estimate) / n_total
    expected_se <- sqrt(sum((l_mid - mean_l)^2 * rows$se^2)) / n_total
    actual_se <- result$mean_length_se[result$species == sp]
    expect_equal(
      actual_se,
      expected_se,
      tolerance = 1e-9,
      label = paste("mean_length_se for species", sp)
    )
  }
})

test_that("est_mean_length() CI is symmetric around estimate", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  upper_dist <- result$mean_length_ci_upper - result$mean_length
  lower_dist <- result$mean_length - result$mean_length_ci_lower
  expect_equal(upper_dist, lower_dist, tolerance = 1e-9)
})

test_that("est_mean_length() CI width equals 2 * z * se", {
  ld <- make_ld()
  result <- est_mean_length(ld, conf_level = 0.95)
  z <- qnorm(0.975)
  ci_half <- (result$mean_length_ci_upper - result$mean_length_ci_lower) / 2
  expect_equal(ci_half, z * result$mean_length_se, tolerance = 1e-9)
})

test_that("est_mean_length() mean_length is positive for positive lengths", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  expect_true(all(result$mean_length > 0))
})

test_that("est_mean_length() mean_length is within observed bin range", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  min_bin <- min(ld$bin_lower)
  max_bin <- max(ld$bin_upper)
  expect_true(all(result$mean_length >= min_bin))
  expect_true(all(result$mean_length <= max_bin))
})

# conf_level tests ----

test_that("est_mean_length() inherits conf_level from ld when not supplied", {
  ld <- make_ld()
  result <- est_mean_length(ld)
  expect_equal(attr(result, "conf_level"), attr(ld, "conf_level"))
})

test_that("est_mean_length() uses supplied conf_level over ld attribute", {
  ld <- make_ld()
  result <- est_mean_length(ld, conf_level = 0.90)
  expect_equal(attr(result, "conf_level"), 0.90)
  z_90 <- qnorm(0.95)
  ci_half <- (result$mean_length_ci_upper - result$mean_length_ci_lower) / 2
  expect_equal(ci_half, z_90 * result$mean_length_se, tolerance = 1e-9)
})

# Zero-total guard ----

make_zero_ld <- function() {
  ld <- data.frame(
    bin_lower = c(200, 225, 250),
    bin_upper = c(225, 250, 275),
    estimate = c(0, 0, 0),
    se = c(0, 0, 0),
    stringsAsFactors = FALSE
  )
  class(ld) <- c("creel_length_distribution", "data.frame")
  attr(ld, "by_vars") <- NULL
  attr(ld, "conf_level") <- 0.95
  ld
}

test_that("EML-ZT-01 est_mean_length() warns and returns NA when all estimates are zero", {
  ld <- make_zero_ld()
  expect_warning(result <- est_mean_length(ld), "zero")
  expect_true(is.na(result$mean_length))
  expect_true(is.na(result$mean_length_se))
})

test_that("EML-ZT-02 est_compliance() warns and returns NA when all estimates are zero", {
  ld <- make_zero_ld()
  expect_warning(result <- est_compliance(ld, min_length = 230), "zero")
  expect_true(is.na(result$compliance_prop))
  expect_true(is.na(result$compliance_se))
  expect_true(is.na(result$n_legal_est))
  expect_true(is.na(result$n_total_est))
})

test_that("EML-ZT-03 est_mean_length() warns NA only for zero-total group in grouped call", {
  ld <- data.frame(
    species = c("walleye", "walleye", "perch", "perch"),
    bin_lower = c(200, 225, 200, 225),
    bin_upper = c(225, 250, 225, 250),
    estimate = c(10, 20, 0, 0),
    se = c(1, 2, 0, 0),
    stringsAsFactors = FALSE
  )
  class(ld) <- c("creel_length_distribution", "data.frame")
  attr(ld, "by_vars") <- "species"
  attr(ld, "conf_level") <- 0.95

  expect_warning(result <- est_mean_length(ld), "zero")
  walleye_row <- result[result$species == "walleye", ]
  perch_row <- result[result$species == "perch", ]
  expect_false(is.na(walleye_row$mean_length))
  expect_true(is.na(perch_row$mean_length))
})
