# Tests for estimate_effort_aerial_glmm()
# Covers GLMM-01 (basic usage), GLMM-02 (output contract), GLMM-03 (guards)

# Shared fixture: aerial creel_design with example_aerial_glmm_counts ----
# `visibility_correction` defaults to "none" -- an UNKNOWN correction, se_v = NA.
# Every test here shared that until GH #357, which is why none of them could see
# an interval that ignored it. Pass a numeric correction with `visibility_se` to
# get the known-uncertainty case.
make_aerial_glmm_design <- function(visibility_correction = "none", visibility_se = NULL,
                                    with_count_time = FALSE) {
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
  if (with_count_time) {
    # estimate_effort() refuses repeated same-day counts unless it can tell them
    # apart; the GLMM reads the same column through `time_col` instead.
    add_counts(design, example_aerial_glmm_counts, # nolint: object_usage_linter
      count_col = n_anglers, count_time_col = time_of_flight
    )
  } else {
    add_counts(design, example_aerial_glmm_counts, count_col = n_anglers) # nolint: object_usage_linter
  }
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
  # Seeded: the bracket assertions below read 2.5%/97.5% quantiles of only ten
  # replicates, which are effectively the min and max. Unseeded, a run where all
  # ten land on one side of the estimate fails a correct estimator.
  set.seed(42)
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

# GLMM-07: temporal basis of the returned estimate (GH #363) ----

test_that("GLMM-07: the default estimate is on the same basis as estimate_effort()", {
  skip_if_not_installed("lme4")
  # Before GH #363 this function returned a single average day while
  # estimate_effort() returned a total across the sampled days, so the two
  # differed by a factor of n_days on the same design with nothing in either
  # signature to say so. The discriminating fact is the RATIO: a diurnal
  # correction is a modest percentage, not an order of magnitude.
  design <- make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0)
  glmm <- suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  )
  simple <- suppressMessages(estimate_effort(
    make_aerial_glmm_design(
      visibility_correction = 1, visibility_se = 0, with_count_time = TRUE
    )
  ))

  ratio <- glmm$estimates$estimate / simple$estimates$estimate
  expect_gt(ratio, 0.5)
  expect_lt(ratio, 2)
  expect_identical(glmm$effort_target, "sampled_days")
})

test_that("GLMM-07: mean_day is the sampled-days total divided by the sampled days", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0)
  total <- suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  )
  one_day <- suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight, target = "mean_day")
  )
  n_days <- length(unique(design$counts[[design$date_col]]))

  expect_equal(total$estimates$estimate, one_day$estimates$estimate * n_days)
  expect_identical(one_day$effort_target, "mean_day")
})

test_that("GLMM-07: the standard error scales with the expansion, not just the estimate", {
  skip_if_not_installed("lme4")
  # An expansion that moved the point estimate without moving its SE would
  # report a total n_days times larger at unchanged precision.
  design <- make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0)
  total <- suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  )
  one_day <- suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight, target = "mean_day")
  )
  n_days <- length(unique(design$counts[[design$date_col]]))

  expect_equal(total$estimates$se, one_day$estimates$se * n_days)
  # The CV is what must NOT move: the same curve, described over more days.
  expect_equal(
    total$estimates$se / total$estimates$estimate,
    one_day$estimates$se / one_day$estimates$estimate
  )
})

test_that("GLMM-07: the median-day prediction is corrected before it is expanded", {
  skip_if_not_installed("lme4")
  # exp(X beta) is the day whose random intercept is zero -- the median day on a
  # log link. Reporting it as a mean understates by exp(sigma^2 / 2). The fitted
  # intercept variance is non-zero on this fixture, so a mean_day estimate that
  # equalled the raw integral would mean the correction was never applied.
  design <- make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0)
  one_day <- suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight, target = "mean_day")
  )

  # Rebuild the UNCORRECTED integral independently, the way the function did
  # before GH #363: fit the same model, predict the fixed-effects curve over the
  # same grid, integrate. Asserting only that exp(sigma^2 / 2) > 1 would pass
  # with the correction deleted, which is the whole point of computing this.
  model <- lme4::glmer.nb(
    n_anglers ~ poly(time_of_flight, 2) + (1 | date),
    data = design$counts
  )
  h_open <- design$aerial$h_open
  open_start <- min(design$counts$time_of_flight) - 0.5
  grid <- seq(open_start, open_start + h_open, length.out = 100)
  new_data <- stats::setNames(
    data.frame(grid, NA_character_, stringsAsFactors = FALSE),
    c("time_of_flight", design$date_col)
  )
  x_mat <- stats::model.matrix(stats::delete.response(stats::terms(model)), data = new_data)
  mu <- as.numeric(exp(x_mat %*% lme4::fixef(model)))
  uncorrected <- sum(mu) * (h_open / (length(grid) - 1L))

  vc <- as.data.frame(lme4::VarCorr(model))
  sigma2 <- sum(vc$vcov[is.na(vc$var2) & vc$var1 == "(Intercept)"], na.rm = TRUE)
  expect_gt(sigma2, 0)

  # The reported mean day is the uncorrected integral times exp(sigma^2 / 2).
  expect_equal(one_day$estimates$estimate, uncorrected * exp(sigma2 / 2), tolerance = 1e-3)
  # And it is strictly larger than the uncorrected value, so deleting the
  # correction fails this test rather than passing it.
  expect_gt(one_day$estimates$estimate, uncorrected)
})

test_that("GLMM-07: a random slope is refused rather than corrected with a constant", {
  skip_if_not_installed("lme4")
  # exp(Var(b0 + b1 t) / 2) varies across the integration grid, so no single
  # factor expresses it. Summing the two variances would return a plausible
  # wrong number for a formula this function documents as supported.
  design <- make_aerial_glmm_design(visibility_correction = 1, visibility_se = 0)
  expect_error(
    suppressWarnings(suppressMessages(estimate_effort_aerial_glmm(
      design,
      time_col = time_of_flight,
      formula = n_anglers ~ time_of_flight + (time_of_flight | date)
    ))),
    class = "creel_error_glmm_retransform_unsupported"
  )
})

# GLMM-08: estimation within strata (GH #364) ----
#
# The fixture has 8 weekday and 4 weekend sampled days, so a stratum expanded
# by the design-wide 12 days is visibly wrong, and the two strata cannot be
# confused for one another.

grouped_glmm <- function(design, ...) {
  suppressWarnings(suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight, by = day_type, ...)
  ))
}

test_that("GLMM-08: by returns one row per stratum, headed by the stratum", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  result <- grouped_glmm(design)

  expect_identical(as.character(result$estimates$day_type), c("weekday", "weekend"))
  expect_identical(result$by_vars, "day_type")
  # Every count belongs to exactly one stratum.
  expect_identical(sum(result$estimates$n), nrow(design$counts))
})

test_that("GLMM-08: each stratum expands by its OWN sampled days", {
  skip_if_not_installed("lme4")
  # Why: the totals multiply each stratum's effort by that stratum's rate, so a
  # stratum expanded by the design-wide day count would inflate weekend effort
  # threefold (12 days where 4 were sampled).
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  total <- grouped_glmm(design)
  one_day <- grouped_glmm(design, target = "mean_day")

  expect_equal(total$estimates$estimate, one_day$estimates$estimate * c(8, 4))
})

test_that("GLMM-08: strata_vcov carries the covariance the shared terms induce", {
  skip_if_not_installed("lme4")
  # Why: every stratum is predicted from the same coefficients and divided by
  # the same v. Treating the rows as independent understates the SE of any
  # combination of them, so the covariance must be present and positive.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  result <- grouped_glmm(design)
  vc <- result$strata_vcov

  expect_equal(dim(vc), c(2L, 2L))
  expect_equal(diag(vc), result$estimates$se^2)
  expect_gt(vc[1, 2], 0)
  expect_gt(sqrt(sum(vc)), sqrt(sum(result$estimates$se^2)))
})

test_that("GLMM-08: v enters the covariance as ONE shared multiplier", {
  skip_if_not_installed("lme4")
  # Why: a single estimate of v divides every stratum, so its term is perfectly
  # correlated across strata. Doubling its SE must move the off-diagonal by
  # exactly (se_v2^2 - se_v1^2) / v^2 * E1 * E2. A per-stratum independent
  # treatment would leave the off-diagonal unchanged.
  lo <- grouped_glmm(make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05))
  hi <- grouped_glmm(make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.10))
  e <- lo$estimates$estimate

  expect_equal(hi$estimates$estimate, e)
  expect_equal(
    hi$strata_vcov[1, 2] - lo$strata_vcov[1, 2],
    (0.10^2 - 0.05^2) / 0.8^2 * e[1] * e[2]
  )
})

test_that("GLMM-08: the model component is the model term alone, not the combined SE", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  result <- grouped_glmm(design)
  comp <- result$se_components

  expect_true(all(comp$model < result$estimates$se))
  expect_equal(
    comp$model^2 + comp$visibility^2 + comp$angler_ratio^2,
    result$estimates$se^2
  )
})

test_that("GLMM-08: an unknown visibility correction leaves the grouped SE unknown", {
  skip_if_not_installed("lme4")
  # Why: a declared-unknown v has no SE to add; reporting the model term alone
  # would pass it off as known (GH #135, #357).
  result <- grouped_glmm(make_aerial_glmm_design())

  expect_true(all(is.finite(result$estimates$estimate)))
  expect_true(all(is.na(result$estimates$se)))
  expect_true(all(is.na(result$estimates$ci_lower)))
  expect_true(all(is.na(result$strata_vcov)))
})

test_that("GLMM-08: a count with no stratum is its own NA row, not dropped", {
  skip_if_not_installed("lme4")
  # Why: an unknown stratum is a stratum like any other (#317, #321). Refusing
  # made this the one grouped estimator that could not report a design with a
  # few unlabelled days; dropping the counts (lme4's na.action) would fit the
  # grouped model to different data from the ungrouped one. The rows must
  # account for every count, and the NA row must expand by ITS days.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  wd_dates <- unique(design$counts$date[design$counts$day_type == "weekday"])
  unknown <- design$counts$date %in% wd_dates[1:2]
  design$counts$day_type <- as.character(design$counts$day_type)
  design$counts$day_type[unknown] <- NA
  result <- grouped_glmm(design)
  est <- result$estimates

  expect_identical(est$day_type, c("weekday", "weekend", NA))
  expect_identical(sum(est$n), nrow(design$counts))
  expect_identical(est$n[3], sum(unknown))
  expect_true(all(is.finite(est$estimate)))
  expect_true(all(is.finite(est$se)))
  expect_identical(dim(result$strata_vcov), c(3L, 3L))

  # mean_day divides out each row's own sampled days: 2 for the NA stratum.
  per_day <- grouped_glmm(design, target = "mean_day")$estimates
  expect_equal(est$estimate[3] / per_day$estimate[3], 2)
})

test_that("GLMM-08: a stratum labelled \"NA\" is not the unknown stratum", {
  skip_if_not_installed("lme4")
  # Why: rows are matched to their counts by level, and a value comparison
  # would either miss the unknown stratum (NA == NA is NA) or merge it with a
  # real label spelling "NA". Each count must land in exactly one row.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  dates <- unique(design$counts$date)
  design$counts$day_type <- as.character(design$counts$day_type)
  design$counts$day_type[design$counts$date %in% dates[1:2]] <- NA
  design$counts$day_type[design$counts$date %in% dates[3:4]] <- "NA"
  est <- grouped_glmm(design)$estimates

  expect_identical(sum(is.na(est$day_type)), 1L)
  expect_identical(sum(est$day_type %in% "NA"), 1L)
  expect_identical(sum(est$n), nrow(design$counts))
  expect_identical(est$n[is.na(est$day_type)], sum(design$counts$date %in% dates[1:2]))
})

test_that("GLMM-08: a numeric stratum with an unknown value stays numeric", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  design$counts$weekend <- as.numeric(design$counts$day_type == "weekend")
  design$counts$weekend[design$counts$date == min(design$counts$date)] <- NA
  est <- suppressWarnings(suppressMessages(estimate_effort_aerial_glmm(
    design,
    time_col = time_of_flight, by = weekend
  )))$estimates

  expect_type(est$weekend, "double")
  expect_identical(est$weekend, c(0, 1, NA))
})

test_that("GLMM-08: an unused factor level does not break the prediction grid", {
  skip_if_not_installed("lme4")
  # Why: the grid must use the levels the model was fitted with. lme4 drops an
  # unused level when it fits, and the grid reads its levels from the data, so
  # the two agree only because the data are droplevels()-ed first. Without that
  # the grid carries a level the model never fitted and the design-matrix
  # columns stop lining up.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  plain <- grouped_glmm(design)
  design$counts$day_type <- factor(
    design$counts$day_type,
    levels = c("holiday", "weekday", "weekend")
  )
  padded <- grouped_glmm(design)

  expect_equal(padded$estimates$estimate, plain$estimates$estimate)
})

test_that("GLMM-08: by with boot = TRUE is refused", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  expect_error(
    grouped_glmm(design, boot = TRUE, nboot = 5L),
    class = "creel_error_glmm_grouped_boot_unsupported"
  )
})

test_that("GLMM-08: the default grouped fit reports the shape check; a user formula does not", {
  skip_if_not_installed("lme4")
  # Why: the additive default assumes strata share the diurnal shape, which
  # Smucker et al. (2010) show can fail. The BIC comparison is how a user
  # learns that; a user who wrote the formula has already made the choice.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  msgs <- character(0)
  withCallingHandlers(
    suppressWarnings(
      estimate_effort_aerial_glmm(design, time_col = time_of_flight, by = day_type)
    ),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_true(any(grepl("BIC(interaction) - BIC(additive)", msgs, fixed = TRUE)))

  msgs <- character(0)
  withCallingHandlers(
    suppressWarnings(
      estimate_effort_aerial_glmm(
        design,
        time_col = time_of_flight,
        by = day_type,
        formula = n_anglers ~ poly(time_of_flight, 2) + day_type + (1 | date)
      )
    ),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_length(grep("BIC", msgs, fixed = TRUE), 0L)
  # The positive assertion above proves messages were captured at all.
  expect_gt(length(msgs), 0L)
})

test_that("GLMM-08: a supplied formula without the by column is refused", {
  skip_if_not_installed("lme4")
  # Why: without the stratum in the fixed effects every stratum gets the same
  # curve (the mean day was identical, 492.56, for both), so the rows differ
  # only by their day counts and pass for per-stratum estimates.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  expect_error(
    grouped_glmm(design, formula = n_anglers ~ poly(time_of_flight, 2) + (1 | date)),
    class = "creel_error_glmm_by_not_in_formula"
  )
})

test_that("GLMM-08: a by column with one observed level still returns its row", {
  skip_if_not_installed("lme4")
  # Why: a season flown only on weekdays is a real design; a one-level factor
  # cannot form contrasts, so it must be left out of the model, not crash it.
  data("example_aerial_glmm_counts", envir = environment())
  weekday <- example_aerial_glmm_counts[example_aerial_glmm_counts$day_type == "weekday", ]
  cal <- unique(weekday[, c("date", "day_type")])
  design <- suppressWarnings(suppressMessages(add_counts(
    creel_design(cal,
      date = date, strata = day_type, survey_type = "aerial",
      visibility_correction = 0.8, visibility_se = 0.05,
      angler_ratio = 1, angler_ratio_se = 0, h_open = 14
    ),
    weekday,
    count_col = n_anglers
  )))
  grouped <- grouped_glmm(design)
  pooled <- suppressWarnings(suppressMessages(
    estimate_effort_aerial_glmm(design, time_col = time_of_flight)
  ))

  expect_identical(as.character(grouped$estimates$day_type), "weekday")
  # One stratum is the whole design, so it must equal the ungrouped fit.
  expect_equal(grouped$estimates$estimate, pooled$estimates$estimate)
})

test_that("GLMM-08: a non-syntactic by column name is accepted", {
  skip_if_not_installed("lme4")
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  plain <- grouped_glmm(design)
  design$counts[["day type"]] <- design$counts$day_type
  spaced <- suppressWarnings(suppressMessages(estimate_effort_aerial_glmm(
    design,
    time_col = time_of_flight, by = tidyselect::all_of("day type")
  )))

  expect_equal(spaced$estimates$estimate, plain$estimates$estimate)
})

test_that("GLMM-08: by with boot = TRUE is refused before any model is fitted", {
  skip_if_not_installed("lme4")
  # Why: the refusal is about the argument combination, so it must not wait on
  # two GLMM fits (the estimate and the shape check) or be masked when one of
  # them fails. A fit that is reached here stops with a different error.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  local_mocked_bindings(
    glmer.nb = function(...) stop("a model was fitted"),
    .package = "lme4"
  )
  expect_error(
    grouped_glmm(design, boot = TRUE, nboot = 5L),
    class = "creel_error_glmm_grouped_boot_unsupported"
  )
})

test_that("GLMM-08: a user formula is checked without lme4::nobars()", {
  skip_if_not_installed("lme4")
  # Why: nobars() has moved to reformulas and warns on current lme4, and the
  # check ran on the ungrouped path too, so every existing custom-formula call
  # gained a deprecation warning. The check must still refuse a formula that
  # leaves the by column out, and still accept one that has it.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  local_mocked_bindings(
    nobars = function(...) stop("nobars was called"),
    .package = "lme4"
  )
  pooled <- suppressWarnings(suppressMessages(estimate_effort_aerial_glmm(
    design,
    time_col = time_of_flight,
    formula = n_anglers ~ poly(time_of_flight, 2) + (1 | date)
  )))
  expect_s3_class(pooled, "creel_estimates")
  inter <- grouped_glmm(
    design,
    formula = n_anglers ~ poly(time_of_flight, 2) * day_type + (1 | date)
  )
  expect_identical(nrow(inter$estimates), 2L)
  expect_error(
    grouped_glmm(design, formula = n_anglers ~ poly(time_of_flight, 2) + (1 | date)),
    class = "creel_error_glmm_by_not_in_formula"
  )
  # A by column that appears only inside the random effects is not a fixed effect.
  expect_error(
    grouped_glmm(design, formula = n_anglers ~ poly(time_of_flight, 2) + (1 | day_type)),
    class = "creel_error_glmm_by_not_in_formula"
  )
})

test_that("GLMM-08: aliased by columns give the same strata as one of them alone", {
  skip_if_not_installed("lme4")
  # Why: two by columns that encode the same split make the fixed-effect matrix
  # rank deficient; lme4 drops the redundant column from fixef() and vcov(), and
  # the prediction grid must drop it too, or the call fails with
  # "non-conformable arguments" after both fits.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  single <- grouped_glmm(design)
  design$counts$day_code <- paste0("code_", design$counts$day_type)
  both <- suppressWarnings(suppressMessages(estimate_effort_aerial_glmm(
    design,
    time_col = time_of_flight, by = c(day_type, day_code)
  )))

  expect_equal(both$estimates$estimate, single$estimates$estimate)
  expect_equal(both$estimates$se, single$estimates$se)
  expect_equal(both$strata_vcov, single$strata_vcov)
})

test_that("GLMM-08: stratum columns keep their source type", {
  skip_if_not_installed("lme4")
  # Why: the fit needs factors, but the rows are joined to rate estimates by
  # value; a numeric or character stratum returned as a factor does not join
  # like its source, and every other grouped estimator restores the type.
  design <- make_aerial_glmm_design(visibility_correction = 0.8, visibility_se = 0.05)
  design$counts$day_type <- as.character(design$counts$day_type)
  chr <- grouped_glmm(design)
  expect_type(chr$estimates$day_type, "character")

  design$counts$weekend <- as.numeric(design$counts$day_type == "weekend")
  num <- suppressWarnings(suppressMessages(estimate_effort_aerial_glmm(
    design,
    time_col = time_of_flight, by = weekend
  )))
  expect_type(num$estimates$weekend, "double")
  expect_identical(num$estimates$weekend, c(0, 1))
  expect_equal(num$estimates$estimate, chr$estimates$estimate)
})
