# Tests for est_length_distribution() in R/creel-estimates-length.R

# Fixtures ----

make_design_with_lengths_for_est <- function() { # nolint: object_length_linter
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
  add_lengths(d, example_lengths, # nolint: object_usage_linter
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
}

make_design_no_lengths_for_est <- function() { # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")

  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

# Guard tests ----

test_that("est_length_distribution() errors when design is not creel_design", {
  expect_error(
    est_length_distribution(list()),
    "must be a"
  )
})

test_that("est_length_distribution() errors when no lengths attached", {
  expect_error(
    est_length_distribution(make_design_no_lengths_for_est()),
    "No length data found"
  )
})

test_that("est_length_distribution() errors when bin_width is not positive", {
  d <- make_design_with_lengths_for_est()
  expect_error(est_length_distribution(d, bin_width = 0), "positive")
  expect_error(est_length_distribution(d, bin_width = -10), "positive")
  expect_error(est_length_distribution(d, bin_width = "25"), "positive")
})

test_that("est_length_distribution() errors on missing length_col", {
  d <- make_design_with_lengths_for_est()
  expect_error(
    est_length_distribution(d, length_col = "length_mm"),
    "not found"
  )
})

# Output structure tests ----

test_that("est_length_distribution() returns classed data.frame", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d)
  expect_s3_class(result, "creel_length_distribution")
  expect_s3_class(result, "data.frame")
})

test_that("est_length_distribution() returns expected columns", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch")
  expect_true(all(c(
    "length_bin", "bin_lower", "bin_upper", "estimate", "se",
    "ci_lower", "ci_upper", "percent", "cumulative_percent", "n"
  ) %in% names(result)))
})

test_that("est_length_distribution() length_bin is ordered", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest")
  expect_true(is.ordered(result[["length_bin"]]))
})

test_that("est_length_distribution() stores metadata attrs", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "release", bin_width = 25)
  expect_equal(attr(result, "type"), "release")
  expect_equal(attr(result, "bin_width"), 25)
  expect_equal(attr(result, "variance_method"), "taylor")
})

# Estimation behavior tests ----

test_that("ungrouped catch estimate sums to expected total fish count for example data", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch")
  expect_equal(sum(result[["estimate"]]), 37, tolerance = 1e-8)
})

test_that("ungrouped harvest estimate sums to expected total harvest fish count", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest")
  expect_equal(sum(result[["estimate"]]), 14, tolerance = 1e-8)
})

test_that("ungrouped release estimate sums to expected expanded release fish count", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "release")
  expect_equal(sum(result[["estimate"]]), 23, tolerance = 1e-8)
})

test_that("grouped species estimate returns expected species totals", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  est_by_species <- tapply(result[["estimate"]], result[["species"]], sum)
  expect_equal(est_by_species[["walleye"]], 13, tolerance = 1e-8)
  expect_equal(est_by_species[["bass"]], 13, tolerance = 1e-8)
  expect_equal(est_by_species[["panfish"]], 11, tolerance = 1e-8)
})

test_that("grouped output includes by variable and keeps percent near 100 within group", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species, bin_width = 25) # nolint: object_usage_linter
  expect_true("species" %in% names(result))
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    expect_equal(sum(sub$percent), 100, tolerance = 0.1)
  }
})

test_that("cumulative_percent is non-decreasing within species", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest", by = species, bin_width = 25) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    diffs <- diff(sub$cumulative_percent)
    expect_true(all(diffs >= -1e-10))
  }
})

test_that("standard errors are non-negative", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  expect_true(all(result$se >= 0))
})

# autoplot tests ----

skip_if_not_installed("ggplot2")

test_that("autoplot() returns a ggplot object for ungrouped length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", bin_width = 25)
  p <- ggplot2::autoplot(result)
  expect_s3_class(p, "ggplot")
})

test_that("autoplot() returns a ggplot object for grouped length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species, bin_width = 25) # nolint: object_usage_linter
  p <- ggplot2::autoplot(result)
  expect_s3_class(p, "ggplot")
})

test_that("autoplot() renders without error for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest", by = species, bin_width = 25) # nolint: object_usage_linter
  p <- ggplot2::autoplot(result)
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot() uses histogram-style columns for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", bin_width = 25)
  p <- ggplot2::autoplot(result)
  built <- ggplot2::ggplot_build(p)
  expect_true("xmin" %in% names(built$data[[1L]]))
  expect_true("xmax" %in% names(built$data[[1L]]))
})

test_that("autoplot() accepts a title argument for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "release", bin_width = 25)
  p <- ggplot2::autoplot(result, title = "Release Size Structure")
  expect_equal(p$labels$title, "Release Size Structure")
})

test_that("autoplot() accepts theme = 'creel' for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species, bin_width = 25) # nolint: object_usage_linter
  p <- ggplot2::autoplot(result, theme = "creel")
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})
