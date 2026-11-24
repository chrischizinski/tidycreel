# combine_estimates() / compare_estimates() (GH #585 part 3)
#
# Estimates from independently sampled surveys add, and so do their variances
# (Cochran 1977, ch. 5); the interval uses Satterthwaite df over the parts' own
# df. The arithmetic is one line. The risk this file pins is the other one: a
# hand-made sum is plausible and too precise whenever the parts share anything
# estimated or are not the same quantity, so every such case is refused with a
# classed error, and absent never becomes zero.

ce_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:9,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend", "weekday"), 2)
  )
}
ce_sampled <- function() ce_calendar()[c(1, 2, 3, 4, 6, 8), ]

ce_counts <- function(anglers) {
  data.frame(ce_sampled(), anglers = anglers, shift_hours = 8)
}

ce_design <- function(anglers, interviews = NULL) {
  d <- creel_design(ce_calendar(), date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(d, ce_counts(anglers), period_length_col = shift_hours) # nolint: object_usage_linter
  if (!is.null(interviews)) {
    d <- suppressMessages(suppressWarnings(add_interviews( # nolint: object_usage_linter
      d, interviews,
      catch = catch, effort = hours, harvest = catch, trip_status = status
    )))
  }
  d
}

ce_interviews <- function(shift = 0) {
  s <- ce_sampled()
  data.frame(
    date = rep(s$date, each = 2),
    day_type = rep(s$day_type, each = 2),
    hours = c(2, 3, 2.5, 4, 3, 2, 1.5, 2, 3.5, 2, 4, 1) + shift,
    catch = c(1, 0, 2, 3, 1, 1, 0, 1, 2, 0, 1, 1),
    status = "complete"
  )
}

q <- function(expr) suppressWarnings(suppressMessages(expr))
north <- function() q(estimate_effort(ce_design(c(12, 30, 9, 25, 14, 33)))) # nolint: object_usage_linter
south <- function() q(estimate_effort(ce_design(c(4, 11, 6, 15, 5, 12)))) # nolint: object_usage_linter

# ---- the arithmetic ----------------------------------------------------------

test_that("the sum, its SE and its Satterthwaite df equal the hand calculation", {
  a <- north()
  b <- south()
  x <- combine_estimates(a, b) # nolint: object_usage_linter

  va <- a$estimates$se^2
  vb <- b$estimates$se^2
  df_hand <- (va + vb)^2 / (va^2 / a$ci_df + vb^2 / b$ci_df)

  expect_equal(x$estimates$estimate, a$estimates$estimate + b$estimates$estimate)
  expect_equal(x$estimates$se, sqrt(va + vb))
  expect_equal(x$ci_df, df_hand)
  # The interval is a t interval on that df, not a normal one: the parts have
  # 4 df each, where the difference between the two is large.
  crit <- qt(0.975, df_hand)
  expect_equal(x$estimates$ci_upper, x$estimates$estimate + crit * x$estimates$se)
  expect_identical(x$method, "combined-effort")
  expect_identical(x$variance_method, "sum-of-independent")
  expect_identical(x$unit, "angler-hours")
})

test_that("normal parts give a normal interval; unknown df gives no interval", {
  a <- north()
  b <- south()
  a_norm <- set_estimate_slots(a, ci_df = Inf) # nolint: object_usage_linter
  b_norm <- set_estimate_slots(b, ci_df = Inf) # nolint: object_usage_linter
  expect_identical(combine_estimates(a_norm, b_norm)$ci_df, Inf) # nolint: object_usage_linter

  # NA df: the part's interval was not built from its SE, so no
  # reference distribution for the sum can be derived from it.
  b_na <- set_estimate_slots(b, ci_df = NA_real_) # nolint: object_usage_linter
  x <- combine_estimates(a, b_na) # nolint: object_usage_linter
  expect_true(is.na(x$ci_df))
  expect_true(is.na(x$estimates$ci_lower))
  expect_false(is.na(x$estimates$se))
})

test_that("an unknown estimate makes the sum unknown", {
  b <- south()
  est <- b$estimates
  est$estimate <- NA_real_
  b_na <- set_estimate_slots(b, estimates = est) # nolint: object_usage_linter
  expect_true(is.na(combine_estimates(north(), b_na)$estimates$estimate)) # nolint: object_usage_linter
})

test_that("parts with no variance at all give a normal (Inf df) reference", {
  zero <- function(x) {
    est <- x$estimates
    est$se <- 0
    set_estimate_slots(x, estimates = est) # nolint: object_usage_linter
  }
  # 0/0 would be NaN df and no interval for a sum that is known exactly.
  x <- combine_estimates(zero(north()), zero(south())) # nolint: object_usage_linter
  expect_identical(x$ci_df, Inf)
  expect_equal(x$estimates$ci_lower, x$estimates$estimate)
})

test_that("an unknown part makes the sum unknown, never a smaller sum", {
  b <- south()
  est <- b$estimates
  est$se <- NA_real_
  b_na <- set_estimate_slots(b, estimates = est) # nolint: object_usage_linter
  x <- combine_estimates(north(), b_na) # nolint: object_usage_linter
  expect_true(is.na(x$estimates$se))
  expect_equal(x$estimates$estimate, north()$estimates$estimate + b$estimates$estimate)
})

test_that("the difference, its SE, statistic and p-value match the hand calculation", {
  a <- north()
  b <- south()
  cmp <- compare_estimates(a, b) # nolint: object_usage_linter
  se_hand <- sqrt(a$estimates$se^2 + b$estimates$se^2)
  expect_equal(cmp$difference, a$estimates$estimate - b$estimates$estimate)
  expect_equal(cmp$se, se_hand)
  expect_equal(cmp$statistic, cmp$difference / se_hand)
  expect_equal(cmp$p_value, 2 * pt(-abs(cmp$statistic), cmp$df))
  expect_equal(cmp$df, combine_estimates(a, b)$ci_df) # nolint: object_usage_linter
})

test_that("grouped parts combine group by group, in the first part's order", {
  a <- q(estimate_effort(ce_design(c(12, 30, 9, 25, 14, 33)), by = day_type)) # nolint: object_usage_linter
  b <- q(estimate_effort(ce_design(c(4, 11, 6, 15, 5, 12)), by = day_type)) # nolint: object_usage_linter
  b_rev <- set_estimate_slots(b, estimates = b$estimates[2:1, ], ci_df = b$ci_df[2:1]) # nolint: object_usage_linter
  x <- combine_estimates(a, b_rev) # nolint: object_usage_linter

  expect_identical(x$estimates$day_type, a$estimates$day_type)
  expect_equal(x$estimates$estimate, a$estimates$estimate + b$estimates$estimate)
  expect_identical(x$by_vars, "day_type")
})

test_that("a group missing from one part is refused, not summed as zero", {
  a <- q(estimate_effort(ce_design(c(12, 30, 9, 25, 14, 33)), by = day_type)) # nolint: object_usage_linter
  b <- q(estimate_effort(ce_design(c(4, 11, 6, 15, 5, 12)), by = day_type)) # nolint: object_usage_linter
  b_one <- set_estimate_slots(b, estimates = b$estimates[1, ], ci_df = b$ci_df[1]) # nolint: object_usage_linter
  expect_error(combine_estimates(a, b_one), class = "creel_error_combine_group_missing") # nolint: object_usage_linter
})

test_that("SE components add as variances; absent adds nothing; unknown stays unknown", {
  a <- set_estimate_slots(north(), se_components = list(count_sampling = 3, within_day = 1)) # nolint: object_usage_linter
  b <- set_estimate_slots(south(), se_components = list(count_sampling = 4)) # nolint: object_usage_linter
  x <- combine_estimates(a, b) # nolint: object_usage_linter
  expect_equal(x$se_components$count_sampling, 5)
  # Absent from b means "does not apply there", so only a's term counts --
  # not NA, and not a component dropped from the result.
  expect_equal(x$se_components$within_day, 1)

  b_na <- set_estimate_slots(b, se_components = list(count_sampling = NA_real_)) # nolint: object_usage_linter
  expect_true(is.na(combine_estimates(a, b_na)$se_components$count_sampling)) # nolint: object_usage_linter

  # Absent from every part stays absent.
  expect_null(combine_estimates(north(), south())$se_components$within_day) # nolint: object_usage_linter
})

test_that("intervals from the combined estimate cover at nominal on independent parts", {
  # Two independent lakes, days drawn at random within strata, known season
  # totals. The parts' own df are small (few sampled days), so this is where
  # Satterthwaite rather than a normal interval matters.
  skip_on_cran()
  set.seed(585)
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:29,
    day_type = rep(c(rep("weekday", 5), rep("weekend", 2)), length.out = 30)
  )
  lake_truth <- function(mu) round(stats::rgamma(30, shape = 4, rate = 4 / mu))
  truth_a <- lake_truth(ifelse(cal$day_type == "weekend", 30, 12))
  truth_b <- lake_truth(ifelse(cal$day_type == "weekend", 18, 6))
  one <- function(truth) {
    days <- unlist(lapply(split(seq_len(30), cal$day_type), sample, size = 4))
    d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
    d <- add_counts( # nolint: object_usage_linter
      d, data.frame(cal[days, ], anglers = truth[days], shift_hours = 8),
      period_length_col = shift_hours
    )
    q(estimate_effort(d)) # nolint: object_usage_linter
  }
  target <- 8 * (sum(truth_a) + sum(truth_b))
  covered <- vapply(seq_len(80), function(i) {
    # Both lakes are counted on the same dates, so a day's count can match by
    # chance; that partial overlap is warned, and expected here.
    x <- withCallingHandlers(
      combine_estimates(one(truth_a), one(truth_b)), # nolint: object_usage_linter
      creel_warning_combine_partial_overlap = function(w) invokeRestart("muffleWarning")
    )
    x$estimates$ci_lower <= target && target <= x$estimates$ci_upper
  }, logical(1))
  # 80 replicates of a nominal 0.95 interval; a 0.85 floor is well outside
  # binomial noise for a correct interval. Over 400 replicates this design gave
  # 0.978 (normal reference 0.953), conservative as #505 expects with one
  # count per day. That conservatism means coverage alone cannot detect a
  # dropped variance term (dropping the smaller lake's SE still covered 0.955):
  # the hand-calculation test above is what pins the arithmetic. This one pins
  # that the interval is not anti-conservative end to end.
  expect_gte(mean(covered), 0.85)
})

# ---- refusals: not the same quantity ----------------------------------------

test_that("rates cannot be summed, but can be compared", {
  a <- q(estimate_catch_rate(ce_design(c(12, 30, 9, 25, 14, 33), ce_interviews()))) # nolint: object_usage_linter
  b <- q(estimate_catch_rate(ce_design(c(4, 11, 6, 15, 5, 12), ce_interviews(0.5)))) # nolint: object_usage_linter
  expect_error(combine_estimates(a, b), class = "creel_error_combine_rate") # nolint: object_usage_linter
  cmp <- compare_estimates(a, b) # nolint: object_usage_linter
  expect_equal(cmp$difference, a$estimates$estimate - b$estimates$estimate)
})

test_that("rate estimators may differ between parts and are reported", {
  # A roving mean-of-ratios and an access ratio-of-means estimate one quantity.
  a <- q(estimate_catch_rate(ce_design(c(12, 30, 9, 25, 14, 33), ce_interviews()), estimator = "mor", use_trips = "complete")) # nolint: object_usage_linter
  b <- q(estimate_catch_rate(ce_design(c(4, 11, 6, 15, 5, 12), ce_interviews(0.5)), estimator = "ratio-of-means")) # nolint: object_usage_linter
  cmp <- compare_estimates(a, b) # nolint: object_usage_linter
  expect_identical(cmp$estimator_a, a$estimator)
  expect_identical(cmp$estimator_b, b$estimator)
  expect_false(identical(cmp$estimator_a, cmp$estimator_b))
})

test_that("different quantities, targets, units, grouping or levels are refused", {
  a <- north()
  b <- south()
  catch_total <- q(estimate_total_catch(ce_design(c(4, 11, 6, 15, 5, 12), ce_interviews(0.5)))) # nolint: object_usage_linter
  expect_error(combine_estimates(a, catch_total), class = "creel_error_combine_quantity_mismatch") # nolint: object_usage_linter

  sampled <- q(estimate_effort(ce_design(c(4, 11, 6, 15, 5, 12)), target = "sampled_days")) # nolint: object_usage_linter
  expect_error(combine_estimates(a, sampled), class = "creel_error_combine_target_mismatch") # nolint: object_usage_linter

  b_level <- q(estimate_effort(ce_design(c(4, 11, 6, 15, 5, 12)), conf_level = 0.9)) # nolint: object_usage_linter
  expect_error(combine_estimates(a, b_level), class = "creel_error_combine_conf_level_mismatch") # nolint: object_usage_linter

  b_by <- q(estimate_effort(ce_design(c(4, 11, 6, 15, 5, 12)), by = day_type)) # nolint: object_usage_linter
  expect_error(combine_estimates(a, b_by), class = "creel_error_combine_by_mismatch") # nolint: object_usage_linter
  # Rows that would align under the first part's grouping still refuse when
  # the parts were not grouped the same way.
  a_by <- q(estimate_effort(ce_design(c(12, 30, 9, 25, 14, 33)), by = day_type)) # nolint: object_usage_linter
  b_unlabelled <- b_by
  b_unlabelled$by_vars <- NULL
  expect_error(combine_estimates(a_by, b_unlabelled), class = "creel_error_combine_by_mismatch") # nolint: object_usage_linter

  b_unit <- b
  b_unit$unit <- "party-hours"
  expect_error(combine_estimates(a, b_unit), class = "creel_error_combine_unit_mismatch") # nolint: object_usage_linter
})

test_that("an unknown unit is refused, never assumed to match", {
  d <- creel_design(ce_calendar(), date = date, strata = day_type) # nolint: object_usage_linter
  bare <- function(n) {
    q(estimate_effort(add_counts(d, data.frame(ce_sampled(), anglers = n)))) # nolint: object_usage_linter
  }
  a <- bare(c(12, 30, 9, 25, 14, 33))
  expect_true(is.na(a$unit))
  expect_error(combine_estimates(a, bare(c(4, 11, 6, 15, 5, 12))), class = "creel_error_combine_unit_unknown") # nolint: object_usage_linter
})

test_that("unsupported estimates and non-estimates are refused", {
  expect_error(combine_estimates(north()), class = "creel_error_combine_too_few") # nolint: object_usage_linter
  expect_error(combine_estimates(north(), data.frame()), class = "creel_error_combine_not_estimate") # nolint: object_usage_linter
  odd <- north()
  odd$method <- "petersen"
  expect_error(combine_estimates(odd, odd), class = "creel_error_combine_unsupported") # nolint: object_usage_linter
})

# ---- refusals: shared uncertainty --------------------------------------------

test_that("the same counts behind both parts are refused", {
  a <- north()
  expect_error(combine_estimates(a, a), class = "creel_error_combine_shared_counts") # nolint: object_usage_linter
  expect_error(compare_estimates(a, a), class = "creel_error_combine_shared_counts") # nolint: object_usage_linter
})

test_that("one pooled set of interviews behind two rates is refused", {
  # The most likely misuse of a comparison: the same interviews on both sides
  # give a difference of exactly 0 with a positive SE, which reads as "no
  # difference" when no comparison was made.
  pooled <- ce_interviews()
  a <- q(estimate_catch_rate(ce_design(c(12, 30, 9, 25, 14, 33), pooled))) # nolint: object_usage_linter
  b <- q(estimate_catch_rate(ce_design(c(4, 11, 6, 15, 5, 12), pooled))) # nolint: object_usage_linter
  expect_error(compare_estimates(a, b), class = "creel_error_combine_shared_interviews") # nolint: object_usage_linter

  # A pooled superset is the same misuse: one part's rows are all in the other.
  bigger <- rbind(pooled, transform(pooled, hours = hours + 10))
  c_sup <- q(estimate_catch_rate(ce_design(c(4, 11, 6, 15, 5, 12), bigger))) # nolint: object_usage_linter
  expect_error(compare_estimates(a, c_sup), class = "creel_error_combine_shared_interviews") # nolint: object_usage_linter
})

test_that("a partial overlap warns with its size and is not refused", {
  iv_a <- ce_interviews()
  iv_b <- ce_interviews(0.5)
  iv_b[1, ] <- iv_a[1, ]
  a <- q(estimate_catch_rate(ce_design(c(12, 30, 9, 25, 14, 33), iv_a))) # nolint: object_usage_linter
  b <- q(estimate_catch_rate(ce_design(c(4, 11, 6, 15, 5, 12), iv_b))) # nolint: object_usage_linter
  expect_warning(compare_estimates(a, b), "1 identical interviews row", class = "creel_warning_combine_partial_overlap") # nolint: object_usage_linter
})

test_that("one party-size estimate behind both parts is refused", {
  pd <- function(boats) {
    counts <- derive_angler_count( # nolint: object_usage_linter
      data.frame(ce_sampled(), boats = boats, shift_hours = 8),
      boat_count = boats, party_size = 2.5, party_size_se = 0.1
    )
    d <- creel_design(ce_calendar(), date = date, strata = day_type) # nolint: object_usage_linter
    q(estimate_effort(add_counts(d, counts, count_col = "angler_count", period_length_col = shift_hours))) # nolint: object_usage_linter
  }
  a <- pd(c(5, 9, 4, 11, 6, 12))
  b <- pd(c(2, 4, 3, 6, 2, 5))
  expect_error(combine_estimates(a, b), class = "creel_error_combine_shared_party_size") # nolint: object_usage_linter

  # Identity lost (counts derived before expansion_id): refused as unknown.
  b_unknown <- b
  b_unknown$provenance$party_size <- NA_character_
  expect_error(combine_estimates(a, b_unknown), class = "creel_error_combine_provenance_unknown") # nolint: object_usage_linter
})

test_that("a combined estimate keeps its parts' stamps for a later combination", {
  # combine(a, b) has no single design; without the union of stamps, adding a
  # part that shares a's party size would pass.
  pd <- function(boats, se = 0.1) {
    counts <- derive_angler_count( # nolint: object_usage_linter
      data.frame(ce_sampled(), boats = boats, shift_hours = 8),
      boat_count = boats, party_size = 2.5, party_size_se = se
    )
    d <- creel_design(ce_calendar(), date = date, strata = day_type) # nolint: object_usage_linter
    q(estimate_effort(add_counts(d, counts, count_col = "angler_count", period_length_col = shift_hours))) # nolint: object_usage_linter
  }
  a <- pd(c(5, 9, 4, 11, 6, 12), se = 0.1)
  b <- pd(c(2, 4, 3, 6, 2, 5), se = 0.2)
  ab <- combine_estimates(a, b) # nolint: object_usage_linter
  expect_setequal(ab$provenance$party_size, c(a$provenance$party_size, b$provenance$party_size))
  expect_equal(ab$se_expansion, sqrt(a$se_expansion^2 + b$se_expansion^2))
  shares_a <- pd(c(7, 3, 8, 2, 9, 4), se = 0.1)
  expect_error(combine_estimates(ab, shares_a), class = "creel_error_combine_shared_party_size") # nolint: object_usage_linter
})

test_that("one aerial calibration component behind both parts is refused", {
  aerial <- function(n, v_se, a_se) {
    cal <- ce_calendar()
    d <- creel_design( # nolint: object_usage_linter
      cal,
      date = date, strata = day_type, survey_type = "aerial",
      visibility_correction = 0.9, visibility_se = v_se,
      angler_ratio = 1, angler_ratio_se = a_se, h_open = 14
    )
    q(estimate_effort(add_counts(d, data.frame(ce_sampled(), n_anglers = n)))) # nolint: object_usage_linter
  }
  # Shared visibility study, separately estimated angler ratios.
  a <- aerial(c(22, 18, 30, 45, 38, 51), 0.05, 0.02)
  b <- aerial(c(12, 8, 20, 25, 18, 21), 0.05, 0.03)
  expect_error(combine_estimates(a, b), class = "creel_error_combine_shared_aerial_calibration") # nolint: object_usage_linter

  # A calibration declared exact has nothing to share.
  c_exact <- aerial(c(12, 8, 20, 25, 18, 21), 0, 0)
  a_exact <- aerial(c(22, 18, 30, 45, 38, 51), 0, 0)
  expect_s3_class(combine_estimates(a_exact, c_exact), "creel_estimates") # nolint: object_usage_linter
})

test_that("a part with no design cannot be checked and is refused", {
  b <- south()
  b$design <- NULL
  expect_error(combine_estimates(north(), b), class = "creel_error_combine_provenance_unknown") # nolint: object_usage_linter
})
