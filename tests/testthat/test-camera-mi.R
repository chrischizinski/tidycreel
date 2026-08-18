# Multiple imputation of camera counts (GH #137) --------------------------------

make_mi_counts <- function(seed = 1L, n_days = 20L, outage_frac = 0.4) {
  set.seed(seed)
  dates <- as.Date("2024-06-01") + seq_len(n_days) - 1L
  day_type <- rep(c("weekday", "weekend"), length.out = n_days)
  counts <- as.integer(stats::rpois(n_days, lambda = 30))
  n_out <- as.integer(round(outage_frac * n_days))
  # Outages spread across both strata so neither is all-missing.
  outage_idx <- c(
    head(which(day_type == "weekday"), ceiling(n_out / 2)),
    head(which(day_type == "weekend"), floor(n_out / 2))
  )
  status <- rep("operational", n_days)
  status[outage_idx] <- "battery_failure"
  counts[outage_idx] <- NA_integer_
  data.frame(
    date = dates,
    day_type = day_type,
    ingress_count = counts,
    camera_status = status,
    stringsAsFactors = FALSE
  )
}

# Interviews paired to every count day, so the ratio-calibration path runs and
# each per-imputation estimate has a real (non-NA) SE. The uncalibrated path
# reports NA by design (GH #158), which is correct but leaves nothing for the
# within-imputation term to average.
make_mi_interviews <- function(counts, seed = 99L) {
  set.seed(seed)
  days <- counts[, c("date", "day_type")]
  do.call(rbind, lapply(seq_len(nrow(days)), function(i) {
    data.frame(
      date = rep(days$date[i], 3L),
      day_type = rep(days$day_type[i], 3L),
      hours_fished = stats::runif(3L, 1.5, 5),
      party_size = rep(1L, 3L),
      stringsAsFactors = FALSE
    )
  }))
}

make_mi_design <- function(counts) {
  cal <- unique(counts[, c("date", "day_type")])
  creel_design(
    cal,
    date = date,
    strata = day_type,
    survey_type = "camera",
    camera_mode = "counter"
  )
}

test_that("MI-01 (#137): m > 1 returns m distinct completed data sets", {
  raw <- make_mi_counts()
  imps <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type", m = 5L
  )
  expect_s3_class(imps, "camera_imputations")
  expect_length(imps, 5L)

  # The imputed values must actually DIFFER across completed sets. If they were
  # identical the between-imputation term would be zero and multiple imputation
  # would be an expensive way to reproduce the single-imputation defect.
  imputed_vals <- lapply(imps, function(d) d$ingress_count[d$.imputed])
  expect_gt(length(unique(vapply(imputed_vals, sum, numeric(1L)))), 1L)

  # Observed rows must be identical across sets -- only outages are drawn.
  observed <- lapply(imps, function(d) d$ingress_count[!d$.imputed])
  expect_equal(length(unique(observed)), 1L)
})

test_that("MI-02 (#137): m = 1 still returns a plain data frame, unchanged", {
  raw <- make_mi_counts()
  out <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type"
  )
  expect_s3_class(out, "data.frame")
  expect_false(inherits(out, "camera_imputations"))
  expect_equal(nrow(out), nrow(raw))
  expect_true(".imputed" %in% names(out))
})

test_that("MI-03 (#137): the pooled SE exceeds the single-imputation SE", {
  # Single imputation reports only the within-imputation half. Pooling adds the
  # between-imputation term, which is strictly positive whenever the completed
  # sets disagree -- so the pooled SE cannot be smaller.
  raw <- make_mi_counts()
  design <- make_mi_design(raw)
  ints <- make_mi_interviews(raw)

  single <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type"
  )
  d_single <- suppressWarnings(add_counts(design, single))
  se_single <- suppressWarnings(
    est_effort_camera(d_single, interviews = ints, n_anglers = "party_size")
  )$estimates$se

  imps <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type", m = 5L
  )
  pooled <- est_effort_camera_mi(
    design, imps, interviews = ints, n_anglers = "party_size"
  )

  expect_true(is.finite(se_single))
  expect_gt(pooled$estimates$se, se_single)

  # The between-imputation term is ~0 on THIS path, and that is correct rather
  # than a failure to propagate. The calibration ratio is a ratio of sums,
  # rho = sum(E_d) / sum(C_d), so the camera counts cancel out of the point
  # estimate (the package's "finding 22"); refilling the outage days
  # differently moves rho and the count total together and leaves the product
  # where it was. Multiple imputation still helps here, but through the
  # within-imputation term, because drawn counts are noisier than fitted means.
  expect_lt(pooled$se_components$between_imputation, 1e-6)
})

test_that("MI-03b (#137): the between-imputation term is positive where counts drive the estimate", {
  # The raw-count path expands the counts directly, so refilling the outage
  # days DOES move the point estimate and the between-imputation term is
  # strictly positive. This is the term a single completed data set
  # structurally cannot have.
  raw <- make_mi_counts()
  design <- make_mi_design(raw)
  imps <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type", m = 5L
  )
  pooled <- est_effort_camera_mi(design, imps, h_open = 14, calibration = "none")

  expect_gt(pooled$se_components$between_imputation, 0)
  # The within half is NA here because the uncalibrated path reports NA SE by
  # design (GH #158). The between term is computed from the point estimates
  # alone, so it survives that -- and it is the half that says how much the
  # answer depends on how the gaps were filled.
  expect_true(is.na(pooled$se_components$within_imputation))
})

test_that("MI-04 (#137): the between-imputation term matches Afrifa-Yamoah eq. (5)", {
  # Pins the pooling arithmetic itself against the published formula, rather
  # than only asserting the SE grew.
  q <- c(100, 110, 90, 105, 95)
  u <- c(25, 26, 24, 25, 25)
  m <- length(q)
  expected_between <- (m + 1) / (m * (m - 1)) * sum((q - mean(q))^2)
  expected_within <- mean(u)

  pooled <- tidycreel:::.rubin_pool(q, u)
  expect_equal(pooled$var_between, expected_between, tolerance = 1e-12)
  expect_equal(pooled$var_within, expected_within, tolerance = 1e-12)
  expect_equal(pooled$se, sqrt(expected_within + expected_between), tolerance = 1e-12)

  # Rubin's (1 + 1/M) form over the sample variance is the same quantity, which
  # is worth pinning because the paper writes it the other way.
  expect_equal(
    expected_between,
    (1 + 1 / m) * sum((q - mean(q))^2) / (m - 1),
    tolerance = 1e-12
  )
})

test_that("MI-05 (#137): pooling refuses a single completed data set", {
  raw <- make_mi_counts()
  design <- make_mi_design(raw)
  single <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type"
  )
  expect_error(
    est_effort_camera_mi(design, single, h_open = 14, calibration = "none"),
    regexp = "camera_imputations"
  )
})

test_that("MI-06 (#137): information monotonicity -- imputed days do not buy precision", {
  # The regression test named in the issue. A design where 40% of days are
  # imputed carries strictly LESS information than the same design with those
  # days dropped, so its SE must not be smaller. Single imputation could report
  # a smaller one, because it adds smooth predictions that look like data.
  #
  # 40% sits inside the 0.06-0.61 outage range Afrifa-Yamoah et al. (2020)
  # studied, so the scenario is defensible against the literature.
  raw <- make_mi_counts(outage_frac = 0.4)
  design <- make_mi_design(raw)
  ints <- make_mi_interviews(raw)

  imps <- impute_camera_counts(
    raw, count_col = "ingress_count", strata_col = "day_type", m = 5L
  )
  pooled <- est_effort_camera_mi(
    design, imps, interviews = ints, n_anglers = "party_size"
  )
  var_imputed <- pooled$estimates$se^2

  # Same design with the outage days deleted rather than filled.
  dropped <- raw[!is.na(raw$ingress_count), , drop = FALSE]
  d_drop <- suppressWarnings(add_counts(make_mi_design(dropped), dropped))
  res_drop <- suppressWarnings(
    est_effort_camera(
      d_drop, interviews = make_mi_interviews(dropped), n_anglers = "party_size"
    )
  )
  var_dropped <- res_drop$estimates$se^2

  # Per-day precision is what is comparable here: dropping days shrinks the
  # total as well as its SE, so compare coefficients of variation.
  cv_imputed <- sqrt(var_imputed) / pooled$estimates$estimate
  cv_dropped <- sqrt(var_dropped) / res_drop$estimates$estimate

  expect_gte(cv_imputed, cv_dropped * 0.999)
})
