# Tests for summary.creel_estimates() — SUMM-01 through SUMM-05

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

# ---- SUMM-01: return class ----

test_that("summary.creel_estimates() returns a creel_summary object", {
  est <- make_effort_est()
  result <- summary(est)
  expect_s3_class(result, "creel_summary")
})

test_that("summary.creel_estimates() works for cpue estimates", {
  est <- make_cpue_est()
  result <- summary(est)
  expect_s3_class(result, "creel_summary")
})

test_that("summary.creel_estimates() works for grouped estimates", {
  est <- make_grouped_est()
  result <- summary(est)
  expect_s3_class(result, "creel_summary")
})

# ---- SUMM-02: structure ----

test_that("creel_summary contains table, method, variance_method, conf_level", {
  est <- make_effort_est()
  result <- summary(est)
  expect_true(!is.null(result$table))
  expect_true(!is.null(result$method))
  expect_true(!is.null(result$variance_method))
  expect_true(!is.null(result$conf_level))
})

test_that("creel_summary$table is a data.frame with human-readable columns", {
  est <- make_effort_est()
  result <- summary(est)
  expect_s3_class(result$table, "data.frame")
  expect_true("Estimate" %in% names(result$table))
  expect_true("SE" %in% names(result$table))
  expect_true("CI Lower" %in% names(result$table))
  expect_true("CI Upper" %in% names(result$table))
})

test_that("creel_summary$table for grouped estimates has group columns", {
  est <- make_grouped_est()
  result <- summary(est)
  expect_true("day_type" %in% names(result$table))
})

# ---- SUMM-03: print ----

test_that("print.creel_summary() produces output without error", {
  est <- make_effort_est()
  result <- summary(est)
  expect_output(print(result))
})

test_that("print.creel_summary() works for grouped estimates", {
  est <- make_grouped_est()
  result <- summary(est)
  expect_output(print(result))
})

# ---- SUMM-04: as.data.frame ----

test_that("as.data.frame.creel_summary() returns a data.frame", {
  est <- make_effort_est()
  result <- summary(est)
  df <- as.data.frame(result)
  expect_s3_class(df, "data.frame")
  expect_true(nrow(df) >= 1L)
})

test_that("as.data.frame.creel_summary() returns one row per group", {
  est <- make_grouped_est()
  result <- summary(est)
  df <- as.data.frame(result)
  expect_equal(nrow(df), nrow(est$estimates))
})

# ---- SUMM-05: n column ----

test_that("creel_summary$table includes N column", {
  est <- make_effort_est()
  result <- summary(est)
  expect_true("N" %in% names(result$table))
})
