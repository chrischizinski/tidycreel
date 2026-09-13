# Tests for estimate_effort_aerial_glmm()
# Covers GLMM-01 (basic usage), GLMM-02 (output contract), GLMM-03 (guards)

# Shared fixture: aerial creel_design with example_aerial_glmm_counts ----
# `visibility_correction` defaults to "none" -- an UNKNOWN correction, se_v = NA.
# Every test here shared that until GH #357, which is why none of them could see
# an interval that ignored it. Pass a numeric correction with `visibility_se` to
# get the known-uncertainty case.
make_aerial_glmm_design <- function(visibility_correction = "none", visibility_se = NULL) {
  data("example_aerial_glmm_counts", envir = environment())
  aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")]) # nolint: object_usage_linter
  aerial_cal <- aerial_cal[order(aerial_cal$date), ]
  design <- if (is.null(visibility_se)) {
    creel_design(
      # nolint: object_usage_linter
      aerial_cal,
      date = date,
      strata = day_type, # nolint: object_usage_linter
      survey_type = "aerial",
      visibility_correction = visibility_correction,
      angler_ratio = 1,
      angler_ratio_se = 0,
      h_open = 14
    )
  } else {
    creel_design(
      # nolint: object_usage_linter
      aerial_cal,
      date = date,
      strata = day_type, # nolint: object_usage_linter
      survey_type = "aerial",
      visibility_correction = visibility_correction,
      visibility_se = visibility_se,
      angler_ratio = 1,
      angler_ratio_se = 0,
      h_open = 14
    )
  }
  add_counts(design, example_aerial_glmm_counts, count_col = n_anglers) # nolint: object_usage_linter
}

# GLMM-01: Basic usage ----

test_that("estimate_effort_aerial_glmm() returns without error for aerial design", {
  design <- make_aerial_glmm_design()
  expect_no_error(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  )
})

test_that("default Askey formula fits; result$estimates$estimate is finite positive", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  est <- result$estimates$estimate
  expect_true(is.numeric(est))
  expect_true(is.finite(est))
  expect_true(est > 0)
})

test_that("custom formula is accepted without error", {
  design <- make_aerial_glmm_design()
  expect_no_error(
    estimate_effort_aerial_glmm(
      design,
      time_col = time_of_flight,
      formula = n_anglers ~ time_of_flight + (1 | date)
    )
  )
})

test_that("boot = TRUE returns valid CIs when the correction's uncertainty is known", {
  # Was written against the "none" fixture, so it asserted an interval that
  # silently ignored an unknown multiplier -- the GH #357 defect, encoded as the
  # expected result. A bootstrap interval is only reportable when every
  # multiplier's uncertainty is known, so that is what this now exercises.
  design <- make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0)
  result <- suppressMessages(
    estimate_effort_aerial_glmm(
      design,
      time_col = time_of_flight,
      boot = TRUE,
      nboot = 10L
    )
  )
  est <- result$estimates$estimate
  ci_lower <- result$estimates$ci_lower
  ci_upper <- result$estimates$ci_upper
  expect_true(is.finite(result$estimates$se))
  expect_true(ci_lower < est)
  expect_true(ci_upper > est)
})

# GLMM-02: Output contract ----

test_that("result inherits 'creel_estimates'", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimates tibble has required columns", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  required_cols <- c("estimate", "se", "se_between", "se_within", "ci_lower", "ci_upper", "n")
  expect_true(all(required_cols %in% names(result$estimates)))
})

test_that("result$estimates$se_within is NA_real_", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  expect_true(is.na(result$estimates$se_within))
  expect_type(result$estimates$se_within, "double")
})

test_that("result$method is 'aerial_glmm_total'", {
  design <- make_aerial_glmm_design()
  result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  expect_equal(result$method, "aerial_glmm_total")
})

# GLMM-03: Guards ----

test_that("cli_abort() fires when design_type is not 'aerial'", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-10",
      "2024-06-11",
      "2024-06-17",
      "2024-06-18"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
  bad_design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = rep(20, 8),
    time_of_flight = rep(10.0, 8),
    stringsAsFactors = FALSE
  )
  bad_design <- add_counts(bad_design, counts, count_col = effort_hours) # nolint: object_usage_linter
  expect_error(
    estimate_effort_aerial_glmm(bad_design, time_col = time_of_flight),
    class = "rlang_error"
  )
})

test_that("rlang::check_installed fires an rlang_error for a non-existent package", {
  # Validates the rlang::check_installed() mechanism used in estimate_effort_aerial_glmm()
  expect_error(
    rlang::check_installed("lme4_notinstalled_package_xyz"),
    class = "rlang_error"
  )
})

# GLMM-05: open_start integration window ----

test_that("GLMM-05: fixed open_start suppresses data-derived window message", {
  skip_if_not_installed("lme4")
  data("example_aerial_glmm_counts", envir = environment())
  aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
  aerial_cal <- aerial_cal[order(aerial_cal$date), ]
  design <- creel_design(
    aerial_cal,
    date = date,
    strata = day_type,
    survey_type = "aerial",
    visibility_correction = "none",
    angler_ratio = 1,
    angler_ratio_se = 0,
    h_open = 14,
    open_start = 5.0
  )
  design <- add_counts(design, example_aerial_glmm_counts, count_col = n_anglers)
  msgs <- character(0)
  withCallingHandlers(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_false(any(grepl("derived from data", msgs, fixed = TRUE)))
})

test_that("GLMM-05: missing open_start emits data-derived window message", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design()
  msgs <- character(0)
  withCallingHandlers(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_true(any(grepl("derived from data", msgs, fixed = TRUE)))
})

test_that("GLMM-05: fixed open_start yields finite estimate", {
  skip_if_not_installed("lme4")
  data("example_aerial_glmm_counts", envir = environment())
  aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
  aerial_cal <- aerial_cal[order(aerial_cal$date), ]
  design <- creel_design(
    aerial_cal,
    date = date,
    strata = day_type,
    survey_type = "aerial",
    visibility_correction = "none",
    angler_ratio = 1,
    angler_ratio_se = 0,
    h_open = 14,
    open_start = 5.0
  )
  design <- add_counts(design, example_aerial_glmm_counts, count_col = n_anglers)
  result <- suppressMessages(estimate_effort_aerial_glmm(design, time_col = time_of_flight))
  expect_true(is.finite(result$estimates$estimate))
})

# GLMM-06: unknown multiplier uncertainty suppresses the interval (GH #357) ----

test_that("GLMM-06: bootstrap CI is NA when the visibility correction is unknown", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = "none")
  result <- suppressMessages(
    estimate_effort_aerial_glmm(
      design,
      time_col = time_of_flight,
      boot = TRUE,
      nboot = 10L
    )
  )
  # The point estimate survives; only the uncertainty is unreportable.
  expect_true(is.finite(result$estimates$estimate))
  expect_true(is.na(result$estimates$se))
  expect_true(is.na(result$estimates$ci_lower))
  expect_true(is.na(result$estimates$ci_upper))
})

test_that("GLMM-06: an unknown correction is not reported like a zero-uncertainty one", {
  skip_if_not_installed("lme4")
  # The discriminating test for GH #357. ONE factor varies: whether the
  # visibility correction's uncertainty is declared UNKNOWN ("none", se_v = NA)
  # or declared KNOWN AND ZERO (v = 1, se_v = 0). Both divide the total by 1, so
  # the point estimate is identical by construction and the interval is the only
  # thing under test.
  #
  # Before the fix these two returned bit-for-bit identical bootstrap intervals,
  # which meant "never studied" was reported exactly as "studied, found no
  # uncertainty" -- the one equivalence this package must never assert.
  run <- function(design) {
    set.seed(42)
    suppressMessages(
      estimate_effort_aerial_glmm(
        design,
        time_col = time_of_flight,
        boot = TRUE,
        nboot = 50L
      )
    )$estimates
  }
  unknown <- run(make_aerial_glmm_design(visibility_correction = "none"))
  zero <- run(make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0))

  # A reporting change, not an estimation one: the totals still agree.
  expect_equal(unknown$estimate, zero$estimate)

  # The known-zero case keeps a real interval ...
  expect_true(is.finite(zero$ci_lower))
  expect_true(is.finite(zero$ci_upper))
  expect_true(is.finite(zero$se))

  # ... and the unknown case must not share it.
  expect_true(is.na(unknown$ci_lower))
  expect_true(is.na(unknown$ci_upper))
  expect_true(is.na(unknown$se))
})

test_that("GLMM-06: the delta path already agreed, and still does", {
  skip_if_not_installed("lme4")
  # The delta interval is derived from the SE, so it inherited the NA for free.
  # Pinned here so the two paths cannot drift apart again.
  unknown <- suppressMessages(
    estimate_effort_aerial_glmm(
      make_aerial_glmm_design(visibility_correction = "none"),
      time_col = time_of_flight
    )
  )$estimates
  known <- suppressMessages(
    estimate_effort_aerial_glmm(
      make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0),
      time_col = time_of_flight
    )
  )$estimates

  expect_true(is.na(unknown$se))
  expect_true(is.na(unknown$ci_lower))
  expect_true(is.na(unknown$ci_upper))
  expect_true(is.finite(known$se))
  expect_true(is.finite(known$ci_lower))
  expect_true(is.finite(known$ci_upper))
})
