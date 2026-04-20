# Tests for single-PSU diagnostic hardening — DIAG-01 through DIAG-04
#
# Before the fix: survey:::onestrat fires a plain simpleError with the message
# "Stratum (X) has only one PSU at stage 1" -- not an rlang_error, no guidance.
# After the fix: all survey call sites catch this condition and re-raise via
# cli::cli_abort() so the error is a structured rlang_error with actionable text.

# ---- Shared fixtures ----

# Design where 'weekday' stratum has only 1 PSU (day)
make_single_psu_design <- function() {
  cal <- data.frame(
    date     = as.Date(c("2024-06-03", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekend", "weekend")
  )
  design <- suppressWarnings(creel_design(
    cal,
    date = date, strata = day_type, # nolint: object_usage_linter
    survey_type = "instantaneous"
  ))
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    n_counted = c(4L, 5L, 6L)
  )
  suppressWarnings(add_counts(design, counts))
}

# Design with adequate PSUs per stratum
make_adequate_design <- function() {
  suppressWarnings({
    cal <- unique(example_counts[, c("date", "day_type")]) # nolint: object_usage_linter
    design <- creel_design(
      cal,
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "instantaneous"
    )
    add_counts(design, example_counts) # nolint: object_usage_linter
  })
}

# ---- DIAG-01: error is now a structured rlang_error ----

test_that("estimate_effort() single-PSU error is a creel_error_single_psu", {
  design <- make_single_psu_design()
  err <- tryCatch(
    suppressWarnings(estimate_effort(design)),
    error = function(e) e
  )
  expect_true(inherits(err, "creel_error_single_psu"))
})

test_that("estimate_effort() single-PSU error mentions the stratum name", {
  design <- make_single_psu_design()
  expect_error(
    suppressWarnings(estimate_effort(design)),
    regexp = "weekday",
    ignore.case = TRUE
  )
})

test_that("estimate_effort() single-PSU error contains actionable guidance", {
  design <- make_single_psu_design()
  expect_error(
    suppressWarnings(estimate_effort(design)),
    regexp = "sampling rate|combine|PSU|stratum",
    ignore.case = TRUE
  )
})

test_that("estimate_effort() single-PSU error names a special stratum explicitly", {
  cal <- data.frame(
    date = as.Date(c("2027-07-30", "2027-07-31", "2027-08-01")),
    analysis_stratum = c("weekday", "high_use", "weekday"),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(creel_design(
    cal,
    date = date, strata = analysis_stratum, # nolint: object_usage_linter
    survey_type = "instantaneous"
  ))
  counts <- data.frame(
    date = cal$date,
    analysis_stratum = cal$analysis_stratum,
    n_counted = c(4L, 9L, 5L)
  )
  design <- suppressWarnings(add_counts(design, counts))

  expect_error(
    suppressWarnings(estimate_effort(design)),
    regexp = "high_use",
    ignore.case = TRUE
  )
})

# ---- DIAG-02: grouped estimate_effort ----

test_that("estimate_effort(by=...) single-PSU error is an rlang_error", {
  design <- make_single_psu_design()
  err <- tryCatch(
    suppressWarnings(estimate_effort(design, by = day_type)), # nolint: object_usage_linter
    error = function(e) e
  )
  expect_true(inherits(err, "rlang_error"))
})

# ---- DIAG-03: estimate_catch_rate with adequate design ----

test_that("estimate_catch_rate() on adequate design works without PSU error", {
  cal <- data.frame(
    date = as.Date("2024-06-01") + c(0, 5, 6, 7, 12, 13),
    day_type = c(
      "weekday", "weekend", "weekend",
      "weekend", "weekday", "weekend"
    )
  )
  design <- suppressWarnings(creel_design(
    cal,
    date = date, strata = day_type, # nolint: object_usage_linter
    survey_type = "instantaneous"
  ))
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    n_counted = rep(5L, nrow(cal))
  )
  design <- suppressWarnings(add_counts(design, counts))
  int <- data.frame(
    date = rep(cal$date, each = 2L),
    day_type = rep(cal$day_type, each = 2L),
    effort = 2.0,
    catch = 1L,
    trip_status = "complete",
    interview_id = seq_len(12L)
  )
  design <- suppressWarnings(add_interviews(
    design, int,
    catch = catch, effort = effort, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  expect_no_error(suppressWarnings(estimate_catch_rate(design)))
})

# ---- DIAG-04: adequate design still works ----

test_that("estimate_effort() on adequate design returns creel_estimates", {
  design <- make_adequate_design()
  result <- suppressWarnings(estimate_effort(design))
  expect_s3_class(result, "creel_estimates")
})

# ---- Replicate variance single-PSU diagnostics --------------------------------

# Helper: design with n PSUs per stratum and varied counts
make_repvar_design <- function(n_per_stratum) {
  all_counts <- c(5L, 12L, 8L, 20L, 3L, 40L, 55L, 48L, 11L, 30L)
  dates <- c(
    seq(as.Date("2024-06-03"), by = "1 day", length.out = n_per_stratum),
    seq(as.Date("2024-06-08"), by = "7 day", length.out = n_per_stratum)
  )
  dts <- c(rep("weekday", n_per_stratum), rep("weekend", n_per_stratum))
  cal <- data.frame(date = dates, day_type = dts)
  d <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  cnts <- data.frame(
    date     = dates,
    day_type = dts,
    count    = all_counts[seq_len(2L * n_per_stratum)]
  )
  suppressWarnings(add_counts(d, cnts))
}

test_that("REPVAR-01: jackknife with 1-PSU per stratum raises creel_error_single_psu", {
  d <- make_repvar_design(1L)
  expect_error(
    estimate_effort(d, variance = "jackknife"),
    class = "creel_error_single_psu"
  )
})

test_that("REPVAR-02: jackknife 1-PSU error message names the stratum", {
  d <- make_repvar_design(1L)
  expect_error(
    estimate_effort(d, variance = "jackknife"),
    regexp = "only 1 PSU"
  )
})

test_that("REPVAR-03: bootstrap with 1-PSU per stratum raises creel_error_single_psu", {
  d <- make_repvar_design(1L)
  expect_error(
    estimate_effort(d, variance = "bootstrap"),
    class = "creel_error_single_psu"
  )
})

test_that("REPVAR-04: bootstrap 1-PSU error message mentions bootstrap", {
  d <- make_repvar_design(1L)
  expect_error(
    estimate_effort(d, variance = "bootstrap"),
    regexp = "[Bb]ootstrap"
  )
})

test_that("REPVAR-05: bootstrap with 2-PSU per stratum returns finite SE", {
  d <- make_repvar_design(2L)
  result <- suppressWarnings(estimate_effort(d, variance = "bootstrap"))
  expect_true(is.finite(result$estimates$se))
  expect_gt(result$estimates$se, 0)
})

test_that("REPVAR-06: jackknife with 2-PSU per stratum returns finite SE", {
  d <- make_repvar_design(2L)
  result <- suppressWarnings(estimate_effort(d, variance = "jackknife"))
  expect_true(is.finite(result$estimates$se))
  expect_gt(result$estimates$se, 0)
})

test_that("REPVAR-07: bootstrap and jackknife SEs are in same ballpark for 4-PSU design", {
  d <- make_repvar_design(4L)
  se_boot <- suppressWarnings(
    estimate_effort(d, variance = "bootstrap")
  )$estimates$se
  se_jk <- suppressWarnings(
    estimate_effort(d, variance = "jackknife")
  )$estimates$se
  # Both finite and within 3x of each other
  expect_true(is.finite(se_boot))
  expect_true(is.finite(se_jk))
  expect_lt(se_boot / se_jk, 3)
  expect_gt(se_boot / se_jk, 1 / 3)
})
