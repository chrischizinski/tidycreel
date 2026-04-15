# Tests for autoplot.creel_estimates() — PLOT-01 through PLOT-05

# Skip all tests if ggplot2 is not installed
skip_if_not_installed("ggplot2")

# ---- Shared fixtures ----

make_effort_est <- function() {
  suppressWarnings({
    cal <- unique(example_counts[, c("date", "day_type")]) # nolint: object_usage_linter
    design <- creel_design(
      cal,
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "instantaneous"
    )
    design <- add_counts(design, example_counts) # nolint: object_usage_linter
    estimate_effort(design)
  })
}

make_grouped_est <- function() {
  suppressWarnings({
    cal <- unique(example_counts[, c("date", "day_type")]) # nolint: object_usage_linter
    design <- creel_design(
      cal,
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "instantaneous"
    )
    design <- add_counts(design, example_counts) # nolint: object_usage_linter
    estimate_effort(design, by = day_type) # nolint: object_usage_linter
  })
}

make_cpue_est <- function() {
  suppressWarnings({
    cal <- unique(example_counts[, c("date", "day_type")]) # nolint: object_usage_linter
    design <- creel_design(
      cal,
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "instantaneous"
    )
    design <- add_counts(design, example_counts) # nolint: object_usage_linter
    design <- add_interviews(
      design, example_interviews, # nolint: object_usage_linter
      catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
    estimate_catch_rate(design)
  })
}

# ---- PLOT-01: return type ----

test_that("autoplot() returns a ggplot object for ungrouped effort", {
  est <- make_effort_est()
  result <- ggplot2::autoplot(est)
  expect_s3_class(result, "ggplot")
})

test_that("autoplot() returns a ggplot object for grouped effort", {
  est <- make_grouped_est()
  result <- ggplot2::autoplot(est)
  expect_s3_class(result, "ggplot")
})

test_that("autoplot() returns a ggplot object for cpue estimates", {
  est <- make_cpue_est()
  result <- ggplot2::autoplot(est)
  expect_s3_class(result, "ggplot")
})

# ---- PLOT-02: renders without error ----

test_that("autoplot() renders (ggplot_build) without error for ungrouped", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est)
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot() renders without error for grouped", {
  est <- make_grouped_est()
  p <- ggplot2::autoplot(est)
  expect_no_error(ggplot2::ggplot_build(p))
})

# ---- PLOT-03: title argument ----

test_that("autoplot() accepts a title argument", {
  est <- make_effort_est()
  expect_no_error(ggplot2::autoplot(est, title = "My survey effort"))
})

test_that("autoplot() title appears in plot labels", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est, title = "Effort Estimate")
  expect_equal(p$labels$title, "Effort Estimate")
})

# ---- PLOT-04: data mapped to estimate ----

test_that("autoplot() plot data contains estimate values", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est)
  built <- ggplot2::ggplot_build(p)
  # The first layer's data should have y (estimate), ymin, ymax
  layer_data <- built$data[[1L]]
  expect_true("y" %in% names(layer_data) || "yintercept" %in% names(layer_data))
})

# ---- PLOT-05: autoplot dispatch works without explicit ggplot2:: prefix ----

test_that("ggplot2::autoplot dispatches to autoplot.creel_estimates", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est)
  # The method should have been dispatched -- result is a ggplot
  expect_s3_class(p, "ggplot")
})

test_that("autoplot() accepts theme = 'creel' for ungrouped estimates", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est, theme = "creel")
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot() accepts theme = 'creel' for grouped estimates", {
  est <- make_grouped_est()
  p <- ggplot2::autoplot(est, theme = "creel")
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot() includes effort target in caption when present", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est)
  expect_match(p$labels$caption, "Effort target", ignore.case = FALSE)
  expect_match(p$labels$caption, "sampled_days", ignore.case = FALSE)
})

test_that("autoplot() includes effort target in default effort title", {
  est <- make_effort_est()
  p <- ggplot2::autoplot(est)
  expect_match(p$labels$title, "sampled_days", ignore.case = FALSE)
})
