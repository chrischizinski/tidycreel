# Tests for est_effort_camera(calibration = "none") ----

# Helpers ---------------------------------------------------------------------
make_camera_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  suppressWarnings(
    creel_design(
      cal,
      date = date,
      strata = day_type, # nolint
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
}

make_camera_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    ingress_count = c(48L, 55L, 43L, 80L, 75L),
    camera_status = rep("operational", 5L),
    stringsAsFactors = FALSE
  )
}

make_interviews <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    hours_fished = c(3.5, 2.0, 4.0, 2.5, 3.0),
    stringsAsFactors = FALSE
  )
}

make_design_with_counts <- function() {
  d <- make_camera_design()
  suppressWarnings(add_counts(d, make_camera_counts()))
}

# Input validation ------------------------------------------------------------

test_that("CEST-01: errors when design is not creel_design", {
  expect_error(
    est_effort_camera(list(), calibration = "none"),
    class = "rlang_error"
  )
})

test_that("CEST-02: errors when conf_level out of range", {
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, h_open = 14, conf_level = 1.5, calibration = "none"),
    class = "rlang_error"
  )
})

test_that("CEST-02b: conf_level of length != 1 reaches the package's own error", {
  # A bare `conf_level <= 0` comparison on a length-2 input makes `||` raise
  # base R's "'length = 2' in coercion to 'logical(1)'", which is a simpleError:
  # the caller never sees which argument was wrong. The guard must reject the
  # length itself so the cli_abort naming `conf_level` is what actually fires.
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, h_open = 14, conf_level = c(0.90, 0.95), calibration = "none"),
    class = "rlang_error"
  )
  expect_error(
    est_effort_camera(d, h_open = 14, conf_level = numeric(0), calibration = "none"),
    class = "rlang_error"
  )
})

test_that("CEST-03: errors when no counts attached", {
  d <- make_camera_design()
  expect_error(
    est_effort_camera(d, h_open = 14, calibration = "none"),
    class = "rlang_error"
  )
})

test_that("CEST-04: errors in raw mode when h_open is NULL", {
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, interviews = NULL, h_open = NULL),
    class = "rlang_error"
  )
})

test_that("CEST-05: errors in raw mode when h_open <= 0", {
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, h_open = 0, calibration = "none"),
    class = "rlang_error"
  )
})

test_that("CEST-06: errors in ratio mode when effort_col missing", {
  d <- make_design_with_counts()
  int <- make_interviews()
  expect_error(
    est_effort_camera(d, interviews = int, effort_col = "nonexistent"),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("CEST-07: raw mode returns creel_estimates", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))
  expect_s3_class(res, "creel_estimates")
})

test_that("CEST-08: raw mode has expected columns", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))
  expect_true(all(
    c("estimate", "se", "ci_lower", "ci_upper", "n") %in%
      names(res$estimates)
  ))
})

test_that("CEST-09: ratio mode returns creel_estimates", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_s3_class(res, "creel_estimates")
})

test_that("CEST-10: ratio mode has expected columns", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_true(all(
    c("estimate", "se", "ci_lower", "ci_upper", "n") %in%
      names(res$estimates)
  ))
})

# Numeric correctness ---------------------------------------------------------

test_that("CEST-11: raw mode estimate = svytotal * h_open (positive)", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))
  expect_gt(res$estimates$estimate, 0)
})

test_that("CEST-12: ratio mode estimate is positive", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_gt(res$estimates$estimate, 0)
})

test_that("CEST-13: larger h_open gives proportionally larger raw estimate", {
  d <- make_design_with_counts()
  r1 <- suppressWarnings(est_effort_camera(d, h_open = 7, calibration = "none"))$estimates$estimate
  r2 <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))$estimates$estimate
  expect_equal(r2 / r1, 2, tolerance = 1e-6)
})

test_that("CEST-14: the uncalibrated raw path reports NA se, and the calibrated one a number", {
  # Rewritten from "se is non-negative". Under the uncalibrated opt-out the SE
  # is NA by design (GH #158): the branch assumes one angler-hour per count per
  # hour open and never measures that assumption, so its uncertainty is
  # unpropagated rather than zero. NA is the only honest report.
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))
  expect_true(is.na(res$estimates$se))
  expect_false(identical(res$estimates$se, 0))
  # The point estimate is unaffected by the opt-out.
  expect_true(is.finite(res$estimates$estimate))
  expect_gt(res$estimates$estimate, 0)
})

test_that("CEST-15: the uncalibrated raw path reports NA CI bounds", {
  # A confidence interval built from an NA standard error is NA, not a wide
  # interval. Reporting finite bounds here would imply coverage the estimator
  # cannot claim (GH #158).
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))
  e <- res$estimates
  expect_true(is.na(e$ci_lower))
  expect_true(is.na(e$ci_upper))
})

# Method label ----------------------------------------------------------------

test_that("CEST-16: raw mode method is camera_raw", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))
  expect_equal(res$method, "camera_raw")
})

test_that("CEST-17: ratio mode method is camera_ratio", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_equal(res$method, "camera_ratio")
})

# conf_level ------------------------------------------------------------------

test_that("CEST-18: higher conf_level gives wider CI on the calibrated path", {
  # Moved off the uncalibrated path, whose CI is now NA at every conf_level
  # (GH #158). The monotonicity being pinned is a property of the CI
  # construction, so it needs a path that actually produces one.
  d <- make_design_with_counts()
  r1 <- suppressWarnings(est_effort_camera(d, interviews = make_interviews(), conf_level = 0.90))
  r2 <- suppressWarnings(est_effort_camera(d, interviews = make_interviews(), conf_level = 0.99))
  w1 <- r1$estimates$ci_upper - r1$estimates$ci_lower
  w2 <- r2$estimates$ci_upper - r2$estimates$ci_lower
  expect_lt(w1, w2)
})

# non-camera design warning ---------------------------------------------------

test_that("CEST-19: non-camera design type produces a cli warning", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend")
  )
  d <- suppressWarnings(creel_design(cal, date = date, strata = day_type)) # nolint
  counts <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    count = c(10L, 12L, 14L, 20L, 22L)
  )
  d <- suppressWarnings(add_counts(d, counts))
  # The cli_warn for non-camera design type should fire
  expect_warning(
    est_effort_camera(d, h_open = 8, calibration = "none"),
    regexp = "design_type"
  )
})

# Finding 21: h_open must not apply time a second time -------------------------
#
# The raw-count branch expands a count by h_open. Once add_counts() gained the
# ability to apply T_d to any count type (finding 13), a design carrying both
# produced count x T_d x h_open -- angler-hour-hours, roughly double the truth,
# with nothing in the result saying so. These tests fail if that branch ever
# stops checking, which is what makes the number wrong rather than merely
# unlabelled.

make_camera_counts_with_td <- function() {
  counts <- make_camera_counts()
  counts$shift_hours <- rep(2, nrow(counts))
  counts
}

test_that("F21: raw-count branch refuses counts that already carry T_d", {
  d <- suppressWarnings(add_counts(
    make_camera_design(),
    make_camera_counts_with_td(),
    period_length_col = shift_hours # nolint: object_usage_linter
  ))

  # h_open would be the second time multiplier, so the product is not effort.
  expect_error(
    est_effort_camera(d, h_open = 14, calibration = "none"),
    class = "creel_error_camera_period_length"
  )
})

test_that("F21: raw-count branch is unaffected when no T_d was applied", {
  d <- make_design_with_counts()

  res <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))

  # sum(ingress) = 301 over 5 sampled days expanded to a 5-day calendar,
  # scaled by h_open = 14. Guards against the check firing on the normal path.
  expect_equal(res$estimates$estimate, 301 * 14)
})

test_that("F21: ratio-calibration branch accepts T_d, because it cancels", {
  d_td <- suppressWarnings(add_counts(
    make_camera_design(),
    make_camera_counts_with_td(),
    period_length_col = shift_hours # nolint: object_usage_linter
  ))
  d_raw <- make_design_with_counts()

  # The ratio path divides by mean(count) before multiplying by count, so a
  # constant T_d cancels out of the estimate entirely. Scoping the guard to the
  # raw branch is only correct if that is true -- assert it rather than assume.
  with_td <- suppressWarnings(
    est_effort_camera(d_td, interviews = make_interviews())
  )
  without_td <- suppressWarnings(
    est_effort_camera(d_raw, interviews = make_interviews())
  )

  expect_equal(with_td$estimates$estimate, without_td$estimates$estimate)
  expect_equal(with_td$method, "camera_ratio")
})

# Finding 22: the calibration ratio is a ratio of sums, so the camera counts
# cancel and the estimate inherits whatever unit `effort_col` holds. Before
# `n_anglers` existed there was no way to tell angler-hours from party-hours on
# this path, and no way for a caller to supply the missing information.

test_that("CEST-22: ratio path warns when n_anglers is not supplied", {
  d <- make_design_with_counts()
  expect_warning(
    est_effort_camera(d, interviews = make_interviews()),
    regexp = "angler-hours from party-hours"
  )
})

test_that("CEST-22: unit is unknown when n_anglers is not supplied", {
  # NA is the claim that tidycreel does not know, which is what the warning
  # above says out loud.
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, interviews = make_interviews()))
  expect_true(is.na(res$unit))
})

test_that("CEST-22: supplying n_anglers as a column earns the angler-hours label", {
  d <- make_design_with_counts()
  ints <- make_interviews()
  ints$party <- c(2, 2, 1, 3, 1)
  res <- est_effort_camera(d, interviews = ints, n_anglers = "party")
  expect_equal(res$unit, "angler-hours")
})

test_that("CEST-22: n_anglers changes the estimate, not just the label", {
  # The label is only honest if the function did the arithmetic that produces
  # it. A constant party size of 2 must double the estimate; if it does not,
  # the multiplication never reached the calibration and the label is a
  # declaration.
  d <- make_design_with_counts()
  ints <- make_interviews()
  base <- suppressWarnings(est_effort_camera(d, interviews = ints))
  doubled <- est_effort_camera(d, interviews = ints, n_anglers = 2)
  expect_equal(doubled$estimates$estimate, 2 * base$estimates$estimate)
  expect_equal(doubled$unit, "angler-hours")
})

test_that("CEST-22: no ambiguity warning once n_anglers is supplied", {
  d <- make_design_with_counts()
  expect_no_warning(
    est_effort_camera(d, interviews = make_interviews(), n_anglers = 1)
  )
})

test_that("CEST-22: n_anglers goes through the shared party-size rule", {
  # Reuses validate_party_size() rather than reimplementing it, so a party of
  # zero is refused here for the same reason it is in add_interviews().
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, interviews = make_interviews(), n_anglers = 0),
    regexp = "positive party size"
  )
})

# GH #136: single paired calibration day ---------------------------------------

test_that("CEST-23: one paired day yields an NA SE, not an exact ratio (GH #136)", {
  # With a single matched interview/count day the calibration ratio has no
  # measurable spread: its variance is unknown, not zero. A zero enters the
  # delta combination as "the multiplier is known exactly", so the maximally
  # uncertain calibration reported the same SE as a perfectly known one.
  # Unknown uncertainty surfaces as NA so it propagates (se_of_mean()
  # precedent, NEWS 3.2.0). Weekday has two paired days, weekend one: the
  # weekend NA must survive the cross-stratum combination into the overall SE.
  d <- make_design_with_counts()
  mixed <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08")),
    day_type = c("weekday", "weekday", "weekend"),
    hours_fished = c(3.5, 4.0, 2.5),
    stringsAsFactors = FALSE
  )
  expect_warning(
    result <- est_effort_camera(d, interviews = mixed, n_anglers = 1),
    class = "creel_warning_camera_single_day"
  )
  est <- result$estimates
  expect_true(is.finite(est$estimate))
  expect_true(is.na(est$se))
  expect_true(is.na(est$ci_lower))
  expect_true(is.na(est$ci_upper))
})

# GH #137: imputed counts entering the estimator as observed data --------------

test_that("CEST-24: imputed counts trigger a warning naming the imputed share (GH #137)", {
  # impute_camera_counts() flags predicted rows .imputed = TRUE, but nothing
  # downstream reads the flag: inside svytotal() predictions are
  # indistinguishable from observations, the prediction uncertainty is
  # dropped, and model-smoothed counts shrink the between-day variance. Until
  # the variance treatment lands (GH #137 full fix), the estimator must at
  # least say so.
  d <- make_camera_design()
  counts <- make_camera_counts()
  counts$.imputed <- c(FALSE, TRUE, FALSE, FALSE, TRUE)
  d <- suppressWarnings(add_counts(d, counts))
  expect_warning(
    est_effort_camera(d, h_open = 14, calibration = "none"),
    class = "creel_warning_camera_imputed_counts"
  )
})

test_that("CEST-24: no imputation warning when .imputed is present but all FALSE", {
  d <- make_camera_design()
  counts <- make_camera_counts()
  counts$.imputed <- rep(FALSE, 5L)
  d <- suppressWarnings(add_counts(d, counts))
  expect_no_warning(est_effort_camera(d, h_open = 14, calibration = "none"))
})

test_that("CEST-24: imputed-count warning text states n, share, and the SE gap (GH #137)", {
  d <- make_camera_design()
  counts <- make_camera_counts()
  counts$.imputed <- c(FALSE, TRUE, FALSE, FALSE, TRUE)
  d <- suppressWarnings(add_counts(d, counts))
  expect_snapshot(res <- est_effort_camera(d, h_open = 14, calibration = "none"))
})

test_that("CEST-25: imputed days must not shrink the SE below dropping those days (GH #137)", {
  # No longer skipped. Prediction uncertainty IS propagated now, via multiple
  # imputation and Rubin pooling in est_effort_camera_mi(); the monotonicity
  # assertion this placeholder described lives in test-camera-mi.R as MI-06,
  # where the fixtures for m completed data sets already exist.
  #
  # Kept as a pointer rather than deleted so the CEST- series stays contiguous
  # and anyone tracing #137 from this file finds where it went.
  expect_true(is.function(est_effort_camera_mi))
})

test_that("CEST-23: a duplicate count row is refused before it can reach var_rho (GH #136, #142)", {
  # n_days once counted matched count *rows*, so a second row for the same
  # date made a one-paired-day stratum look like two and computed var_rho from
  # a single day's residuals repeated. That was closed by keying the
  # single-day test on distinct dates (#136), a holding position that left the
  # ratio itself double-counting the day (#142). The calibration path now
  # refuses the table outright, so the false-precision path is unreachable by
  # this route rather than merely guarded against.
  d <- make_camera_design()
  counts <- make_camera_counts()
  repeat_row <- counts[counts$date == as.Date("2024-06-08"), ]
  repeat_row$ingress_count <- repeat_row$ingress_count + 1L
  dup <- rbind(counts, repeat_row)
  d <- suppressWarnings(add_counts(d, dup))
  mixed <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08")),
    day_type = c("weekday", "weekday", "weekend"),
    hours_fished = c(3.5, 4.0, 2.5),
    stringsAsFactors = FALSE
  )
  expect_error(
    est_effort_camera(d, interviews = mixed, n_anglers = 1),
    class = "creel_error_camera_duplicate_count_days"
  )
})

# GH #142: duplicate count rows double-count a day in the ratio calibration ----

test_that("CEST-26: a repeated count date is refused on the calibration path (GH #142)", {
  # rho = sum(E_d) / sum(C_d) pairs by date membership and re-reads
  # daily_effort once per matching count row, so a second row for one date
  # counts that day twice on both sides, and the svytotal of raw counts counts
  # it again. Measured on this fixture: 16 clean vs 19.5 with 2024-06-03
  # repeated -- a 22% move in the POINT ESTIMATE from a row carrying no new
  # information. Only the generic CNT-06 duplicate-PSU warning fired.
  d <- make_camera_design()
  counts <- make_camera_counts()
  repeat_row <- counts[counts$date == as.Date("2024-06-03"), ]
  repeat_row$ingress_count <- repeat_row$ingress_count + 1L
  dup <- rbind(counts, repeat_row)
  d <- suppressWarnings(add_counts(d, dup))
  expect_error(
    est_effort_camera(d, interviews = make_interviews(), n_anglers = 1),
    class = "creel_error_camera_duplicate_count_days"
  )
})

test_that("CEST-26: the refusal names the offending date (GH #142)", {
  # The trigger is a duplicated row, not a modelling choice, so the caller has
  # to be told which day to look at -- a bare "duplicate rows" would leave
  # them diffing the counts table by hand.
  d <- make_camera_design()
  counts <- make_camera_counts()
  repeat_row <- counts[counts$date == as.Date("2024-06-03"), ]
  repeat_row$ingress_count <- repeat_row$ingress_count + 1L
  dup <- rbind(counts, repeat_row)
  d <- suppressWarnings(add_counts(d, dup))
  err <- tryCatch(
    est_effort_camera(d, interviews = make_interviews(), n_anglers = 1),
    creel_error_camera_duplicate_count_days = function(e) e
  )
  msg <- cli::ansi_strip(paste(conditionMessage(err), collapse = "\n"))
  expect_match(msg, "2024-06-03", fixed = TRUE)
  expect_match(msg, "count_time_col", fixed = TRUE)
})

test_that("CEST-26: the remedy the error recommends actually works (GH #142)", {
  # The refusal is only defensible because a caller with genuine sub-daily
  # counts has somewhere to go. count_time_col collapses them to one row per
  # day in add_counts(), so the same raw data reaches the calibration path in
  # the shape it requires. If this ever stops holding, the error is a dead end.
  d <- make_camera_design()
  sub_daily <- data.frame(
    date = rep(
      as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-08", "2024-06-09")),
      each = 2L
    ),
    day_type = rep(c("weekday", "weekday", "weekday", "weekend", "weekend"), each = 2L),
    count_time = rep(c("am", "pm"), 5L),
    ingress_count = c(48L, 50L, 55L, 52L, 43L, 40L, 80L, 78L, 75L, 70L),
    camera_status = "operational",
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(add_counts(
    d,
    sub_daily,
    count_col = "ingress_count",
    count_time_col = count_time
  ))
  result <- est_effort_camera(d, interviews = make_interviews(), n_anglers = 1)
  expect_true(is.finite(result$estimates$estimate))
})

test_that("CEST-26: a clean one-row-per-day table is unaffected by the guard (GH #142)", {
  # The guard must refuse only the duplicated case. A repeated *stratum* value
  # across distinct dates is the ordinary shape of every camera design, so
  # keying the check on the date alone -- or on the stratum -- would refuse
  # every valid table.
  d <- make_design_with_counts()
  result <- est_effort_camera(d, interviews = make_interviews(), n_anglers = 1)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(is.finite(result$estimates$se))
})

test_that("CEST-26: the raw-count path now refuses an identical row too (GH #152)", {
  # This test used to pin the opposite: #142 refused a repeated date on the
  # calibration path only, and the raw path was left alone deliberately so the
  # scope was a decision on record rather than an oversight. #152 closed that
  # gap for the case that is decidable -- a row identical in every column, which
  # is malformed whatever the sampling unit turns out to be.
  d <- make_camera_design()
  counts <- make_camera_counts()
  dup <- rbind(counts, counts[counts$date == as.Date("2024-06-03"), ])
  expect_error(
    add_counts(d, dup),
    class = "creel_error_duplicate_count_rows"
  )
})

test_that("CEST-26: a repeat carrying a DIFFERENT count still reaches the raw path (GH #152)", {
  # The remaining half of #152, recorded rather than claimed fixed. Two rows for
  # one date holding different counts are not decidable from the table alone:
  # they may be two counts of one day whose count_time was never recorded, or a
  # re-entry with a typo. svytotal() still sums them, so the estimate still
  # rises -- CNT-06 warns, and that is the only signal.
  d <- make_camera_design()
  counts <- make_camera_counts()
  repeat_row <- counts[counts$date == as.Date("2024-06-03"), ]
  repeat_row$ingress_count <- repeat_row$ingress_count + 1L
  dup <- rbind(counts, repeat_row)
  expect_warning(add_counts(d, dup), regexp = "repeated sampling")

  d <- suppressWarnings(add_counts(d, dup))
  result <- est_effort_camera(d, h_open = 14, calibration = "none")
  expect_true(is.finite(result$estimates$estimate))
})

test_that("CEST-24: within-day aggregation does not erase the imputed flag (GH #137)", {
  # aggregate_within_day() builds each PSU row from its first sub-count, so a
  # day whose 09:00 count was observed and whose 15:00 count was imputed came
  # out flagged FALSE. Half the count data was model prediction and nothing
  # warned. The flag has to collapse with any(), not by position.
  d <- make_camera_design()
  counts <- data.frame(
    date = rep(as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-08", "2024-06-09")), each = 2L),
    day_type = rep(c("weekday", "weekday", "weekday", "weekend", "weekend"), each = 2L),
    count_time = rep(c("am", "pm"), 5L),
    ingress_count = c(48L, 50L, 55L, 52L, 43L, 40L, 80L, 78L, 75L, 70L),
    camera_status = "operational",
    .imputed = rep(c(FALSE, TRUE), 5L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(add_counts(
    d,
    counts,
    count_col = "ingress_count",
    count_time_col = count_time
  ))
  expect_true(all(d$counts$.imputed))
  expect_warning(
    est_effort_camera(d, h_open = 14, calibration = "none"),
    class = "creel_warning_camera_imputed_counts"
  )
})

test_that("CEST-24: a day with no imputed sub-count stays unflagged through aggregation", {
  # The any() collapse must not mark clean days: it reports what happened,
  # not that imputation happened somewhere in the table.
  d <- make_camera_design()
  counts <- data.frame(
    date = rep(as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-08", "2024-06-09")), each = 2L),
    day_type = rep(c("weekday", "weekday", "weekday", "weekend", "weekend"), each = 2L),
    count_time = rep(c("am", "pm"), 5L),
    ingress_count = c(48L, 50L, 55L, 52L, 43L, 40L, 80L, 78L, 75L, 70L),
    camera_status = "operational",
    .imputed = c(FALSE, TRUE, rep(FALSE, 8L)),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(add_counts(
    d,
    counts,
    count_col = "ingress_count",
    count_time_col = count_time
  ))
  expect_identical(d$counts$.imputed, c(TRUE, FALSE, FALSE, FALSE, FALSE))
})

# CEST-27: the generic estimators refuse a camera design (GH #214) -------------
#
# A camera design has no branch in estimate_effort()'s dispatch chain, so before
# this guard it fell through to the instantaneous path and its daily ingress
# counts -- a count of arrivals -- were summed as though they were instantaneous
# counts of anglers present. The result was a plausible number with a plausible
# SE, and nothing said it was not effort.
#
# The refusal is raised at all four entry points because the three totals call
# estimate_effort_total() directly and never pass through estimate_effort().

make_camera_design_with_interviews <- function() {
  d <- make_design_with_counts()
  ints <- make_interviews()
  ints$walleye <- c(1L, 0L, 2L, 1L, 3L)
  ints$trip_status <- "complete"
  suppressMessages(suppressWarnings(add_interviews(
    d,
    ints,
    catch = walleye,
    effort = hours_fished,
    trip_status = trip_status
  )))
}

test_that("CEST-27: estimate_effort() refuses a camera design (GH #214)", {
  expect_error(
    suppressWarnings(estimate_effort(make_design_with_counts())),
    class = "creel_error_camera_generic_estimator"
  )
})

test_that("CEST-27: the refusal names the estimator the caller actually reached", {
  # A generic "unsupported design" message would leave the caller guessing which
  # of the four entry points objected. Each names itself.
  expect_error(
    suppressWarnings(estimate_effort(make_design_with_counts())),
    regexp = "estimate_effort\\(\\)"
  )
  expect_error(
    suppressWarnings(estimate_total_catch(make_camera_design_with_interviews())),
    regexp = "estimate_total_catch\\(\\)"
  )
})

test_that("CEST-27: the effort refusal states why an ingress count is not effort", {
  # The reason is the whole point of the guard: the caller has a number, it looks
  # like effort, and only the estimand distinguishes it. Saying "unsupported"
  # would not tell them their data are fine and their function is wrong.
  expect_error(
    suppressWarnings(estimate_effort(make_design_with_counts())),
    regexp = "arrivals"
  )
})

test_that("CEST-27: the effort refusal points at the estimator that does handle camera", {
  expect_error(
    suppressWarnings(estimate_effort(make_design_with_counts())),
    regexp = "est_effort_camera"
  )
})

test_that("CEST-27: the remedy the effort refusal recommends actually works", {
  # Same pattern as CEST-26: an error that recommends a fix is only correct if
  # the fix runs on the very design that was refused.
  d <- make_design_with_counts()
  expect_error(
    suppressWarnings(estimate_effort(d)),
    class = "creel_error_camera_generic_estimator"
  )
  est <- suppressWarnings(est_effort_camera(d, interviews = make_interviews()))
  expect_s3_class(est, "creel_estimates")
  expect_true(is.finite(est$estimates$estimate))
})

test_that("CEST-27: estimate_total_catch() refuses a camera design (GH #214)", {
  # This is the path that produced the audit's headline number: a rate per
  # party-hour multiplied by a count of arrivals, reported as fish.
  expect_error(
    suppressWarnings(estimate_total_catch(make_camera_design_with_interviews())),
    class = "creel_error_camera_generic_estimator"
  )
})

test_that("CEST-27: estimate_total_harvest() refuses a camera design (GH #214)", {
  expect_error(
    suppressWarnings(estimate_total_harvest(make_camera_design_with_interviews())),
    class = "creel_error_camera_generic_estimator"
  )
})

test_that("CEST-27: the totals say there is no camera catch estimator to reach for", {
  # The effort refusal has a remedy; the totals do not, and must not imply one.
  expect_error(
    suppressWarnings(estimate_total_catch(make_camera_design_with_interviews())),
    regexp = "effort only"
  )
})

test_that("CEST-27: the refusal precedes the missing-counts error", {
  # Placement, not decoration. A camera design with no counts attached should be
  # told which function it wants, not told to call add_counts() and come back to
  # the same wrong function.
  expect_error(
    suppressWarnings(estimate_effort(make_camera_design())),
    class = "creel_error_camera_generic_estimator"
  )
})

test_that("CEST-27: the guard keys on design_type, not on the count column's name", {
  # A camera design whose count column is named like an instantaneous one is
  # still a camera design. Keying on the data would let a rename slip past.
  d <- make_camera_design()
  counts <- make_camera_counts()
  names(counts)[names(counts) == "ingress_count"] <- "angler_count"
  d <- suppressWarnings(add_counts(d, counts))
  expect_error(
    suppressWarnings(estimate_effort(d)),
    class = "creel_error_camera_generic_estimator"
  )
})

test_that("CEST-27: non-camera designs still estimate effort", {
  # The guard must be inert everywhere else. Without this, a refusal that fired
  # on every design would pass every test above.
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(creel_design(
    cal,
    date = date,
    strata = day_type, # nolint
    survey_type = "instantaneous"
  ))
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    angler_count = c(10L, 20L, 12L, 22L, 11L, 21L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(add_counts(d, counts))
  est <- suppressWarnings(estimate_effort(d))
  expect_s3_class(est, "creel_estimates")
  expect_equal(est$estimates$estimate, 96)
})

# CEST-28: the calibration honours every declared stratum column (GH #216) -----
#
# A design declaring `strata = c(day_type, site)` has strata day_type x site.
# The calibration used only `strata_cols[1L]`, so one pooled hours-per-count
# ratio was formed over the coarser partition and applied to counts belonging
# to a stratum that never contributed to it.
#
# Every fixture above declares exactly one stratum column, which is why the
# defect was unreachable from the suite: with one column `strata_cols[1L]` IS
# the whole stratification. These fixtures declare two.

make_two_strata_design <- function() {
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = "weekday",
    site = rep(c("north", "south"), each = 4L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(
    creel_design(
      cal,
      date = date,
      strata = c(day_type, site), # nolint
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    site = cal$site,
    # north is the low-count site, south the high-count one: 40 and 400 counts
    ingress_count = rep(c(10L, 100L), each = 4L),
    camera_status = rep("operational", 8L),
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_counts(d, counts))
}

# north fishes 40 h on 10 counts (rho = 4.0 h/count); south 10 h on 100 counts
# (rho = 0.1). The two regimes are 40x apart, and `site` is the column the
# estimator dropped.
make_two_strata_interviews <- function(days = c(1L, 2L, 3L, 5L)) {
  all_ints <- data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = "weekday",
    site = rep(c("north", "south"), each = 4L),
    hours_fished = rep(c(40, 10), each = 4L),
    party_size = 1,
    stringsAsFactors = FALSE
  )
  all_ints[days, , drop = FALSE]
}

test_that("CEST-28: rho is estimated within each declared stratum, not just the first (GH #216)", {
  # Interview effort is deliberately unbalanced across `site` -- three north
  # days against one south day -- because that imbalance is the whole defect.
  # Pooling weights the ratio toward whichever stratum was interviewed more,
  # then applies it to every stratum's counts.
  d <- make_two_strata_design()
  res <- suppressWarnings(
    est_effort_camera(
      d,
      interviews = make_two_strata_interviews(),
      n_anglers = "party_size"
    )
  )
  # north: rho 4.0 x 40 counts = 160. south: rho 0.1 x 400 counts = 40.
  expect_equal(res$estimates$estimate, 200)
  # The pooled ratio was 1.0 h/count over all 440 counts. Named so a future
  # regression reports which number came back, not merely that one did.
  expect_false(isTRUE(all.equal(res$estimates$estimate, 440)))
})

test_that("CEST-28: a balanced fixture cannot detect the pooling, but its SE can (GH #216)", {
  # When every day is an interview day the ratio of sums telescopes and the
  # point estimate survives the pooling unchanged. A smoke test on the estimate
  # therefore proves nothing here; the calibration variance is what carries the
  # evidence, because pooling two 40x-apart site regimes turns a residual of
  # zero within each stratum into a large one across them.
  d <- make_two_strata_design()
  res <- suppressWarnings(
    est_effort_camera(
      d,
      interviews = make_two_strata_interviews(days = 1:8),
      n_anglers = "party_size"
    )
  )
  expect_equal(res$estimates$estimate, 200)
  # Within each stratum E_d = rho * C_d exactly, so every residual is 0.
  # Pooled, the same data gave a calibration SE of 107.2045.
  expect_equal(res$se_components$calibration, 0)
  expect_equal(res$estimates$se, 0)
})

test_that("CEST-28: a third stratum column is honoured too (GH #216)", {
  # Guards against a fix that hard-codes two columns instead of using all of
  # `design$strata_cols`.
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = "weekday",
    site = rep(c("north", "south"), each = 4L),
    gear = "boat",
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(
    creel_design(
      cal,
      date = date,
      strata = c(day_type, site, gear), # nolint
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    site = cal$site,
    gear = cal$gear,
    ingress_count = rep(c(10L, 100L), each = 4L),
    camera_status = rep("operational", 8L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(add_counts(d, counts))
  ints <- cbind(make_two_strata_interviews(), gear = "boat")
  res <- suppressWarnings(
    est_effort_camera(d, interviews = ints, n_anglers = "party_size")
  )
  expect_equal(res$estimates$estimate, 200)
})

test_that("CEST-28: a stratum column absent from interviews is named, not silently dropped (GH #216)", {
  # Before the ratio was keyed on every column, an interviews table lacking one
  # of them still calibrated -- on whatever columns it happened to carry. Now
  # every declared column is required, so the failure states which is missing
  # rather than reporting an empty stratum.
  d <- make_two_strata_design()
  ints <- make_two_strata_interviews()
  ints$site <- NULL
  expect_error(
    est_effort_camera(d, interviews = ints, n_anglers = "party_size"),
    "missing the stratum column.*site"
  )
})

test_that("CEST-28: the single-pair warning names the full stratum (GH #216)", {
  # With `site` restored to the key, south has one paired interview day, so
  # #136's guard fires -- and must say which stratum, using every column that
  # defines it rather than the first one only.
  d <- make_two_strata_design()
  expect_warning(
    est_effort_camera(
      d,
      interviews = make_two_strata_interviews(),
      n_anglers = "party_size"
    ),
    "weekday / south",
    class = "creel_warning_camera_single_day"
  )
})

test_that("CEST-28: an unmeasurable stratum ratio makes the reported SE NA, not small (GH #216)", {
  # Consequence of estimating within the declared strata: south now has one
  # paired day, so its var(rho) is unknown. The pooled ratio hid that behind a
  # finite 406.15. An SE built from a sum missing an unknown term is a lower
  # bound, not an SE.
  d <- make_two_strata_design()
  res <- suppressWarnings(
    est_effort_camera(
      d,
      interviews = make_two_strata_interviews(),
      n_anglers = "party_size"
    )
  )
  expect_true(is.na(res$estimates$se))
  expect_true(is.na(res$se_components$calibration))
  expect_equal(res$se_components$count_sampling, 0)
})

test_that("CEST-28: single-column designs are unaffected (GH #216)", {
  # Inertness control. With one stratum column the new key is that column, so
  # every existing camera estimate must be bit-identical.
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_equal(res$estimates$estimate, 18.9660194174757, tolerance = 1e-12)
  expect_equal(res$estimates$se, 3.2661325499868386, tolerance = 1e-12)
})
