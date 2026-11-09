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
    date = as.Date(c("2024-06-03", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekend", "weekend")
  )
  design <- suppressWarnings(creel_design(
    cal,
    date = date,
    strata = day_type, # nolint: object_usage_linter
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
      date = date,
      strata = day_type, # nolint: object_usage_linter
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
    suppressWarnings(estimate_effort(design, target = "sampled_days")),
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
    date = date,
    strata = analysis_stratum, # nolint: object_usage_linter
    survey_type = "instantaneous"
  ))
  counts <- data.frame(
    date = cal$date,
    analysis_stratum = cal$analysis_stratum,
    n_counted = c(4L, 9L, 5L)
  )
  design <- suppressWarnings(add_counts(design, counts))

  expect_error(
    suppressWarnings(estimate_effort(design, target = "sampled_days")),
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
      "weekday",
      "weekend",
      "weekend",
      "weekend",
      "weekday",
      "weekend"
    )
  )
  design <- suppressWarnings(creel_design(
    cal,
    date = date,
    strata = day_type, # nolint: object_usage_linter
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
    design,
    int,
    catch = catch,
    effort = effort, # nolint: object_usage_linter
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
    date = dates,
    day_type = dts,
    count = all_counts[seq_len(2L * n_per_stratum)]
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
    # sampled_days: the replicate design's own message. On an expanded target
    # the one-day stratum is refused before any variance method runs (#601).
    estimate_effort(d, variance = "jackknife", target = "sampled_days"),
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
    # sampled_days: the replicate design's own message. On an expanded target
    # the one-day stratum is refused before any variance method runs (#601).
    estimate_effort(d, variance = "bootstrap", target = "sampled_days"),
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

# ---- GH #601: the expanded path names the stratum ----
#
# On period_total / stratum_total the one-PSU stratum reached survey::svyby(),
# whose message names no stratum, so the error said only "A stratum". Since
# #487 that was what a default call showed.

make_601_design <- function(counts_per_day = 1L) {
  cal <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend")
  )
  days <- cal[c(1, 3, 4), ]
  counts <- days[rep(seq_len(nrow(days)), each = counts_per_day), ]
  counts$t <- rep(letters[seq_len(counts_per_day)], nrow(days))
  counts$n <- seq_len(nrow(counts)) + 3
  design <- creel_design(cal, date = date, strata = day_type)
  if (counts_per_day == 1L) {
    suppressWarnings(add_counts(design, counts[, c("date", "day_type", "n")]))
  } else {
    suppressWarnings(add_counts(design, counts, count_time_col = t))
  }
}

test_that("expanded-target single-day error names the stratum (#601)", {
  for (target in c("period_total", "stratum_total")) {
    err <- expect_error(
      suppressWarnings(estimate_effort(make_601_design(), target = target)),
      class = "creel_error_single_psu"
    )
    expect_match(conditionMessage(err), "weekday", fixed = TRUE)
    expect_no_match(conditionMessage(err), "A stratum has only", fixed = TRUE)
  }
  # The default target is period_total (#487), so this is the default call.
  err <- expect_error(
    suppressWarnings(estimate_effort(make_601_design())),
    class = "creel_error_single_psu"
  )
  expect_match(conditionMessage(err), "weekday", fixed = TRUE)
})

test_that("sampled_days is offered only where it would work (#601)", {
  # One count on the day: sampled_days fails too, so it must not be the advice.
  one <- make_601_design(1L)
  err <- expect_error(suppressWarnings(estimate_effort(one)), class = "creel_error_single_psu")
  expect_match(conditionMessage(err), "counted once", fixed = TRUE)
  expect_error(
    suppressWarnings(estimate_effort(one, target = "sampled_days")),
    class = "creel_error_single_psu"
  )

  # Two counts on the day: sampled_days is a census of it and estimable.
  two <- make_601_design(2L)
  err <- expect_error(suppressWarnings(estimate_effort(two)), class = "creel_error_single_psu")
  expect_match(conditionMessage(err), "or use", fixed = TRUE)
  expect_no_match(conditionMessage(err), "counted once", fixed = TRUE)
  res <- suppressWarnings(estimate_effort(two, target = "sampled_days"))
  expect_true(is.finite(res$estimates$se))
})

test_that("a one-day stratum that is its whole calendar, counted twice, is not refused (#601)", {
  # A census (#505): N = n = 1 and the day has a within-day estimate.
  cal <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08")),
    day_type = c("weekday", "weekday", "holiday")
  )
  counts <- data.frame(
    date = rep(cal$date, each = 2), day_type = rep(cal$day_type, each = 2),
    t = rep(c("a", "b"), 3), n = c(4, 6, 5, 9, 30, 34)
  )
  d <- suppressWarnings(add_counts(creel_design(cal, date = date, strata = day_type), counts, count_time_col = t))
  res <- suppressWarnings(estimate_effort(d, target = "period_total", by = day_type))
  expect_true(all(is.finite(res$estimates$se)))
})

test_that("a multi-column stratum is named with its parts (#601, #422)", {
  cal <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-07-01", "2024-07-02")),
    day_type = "weekday", month = c("06", "06", "07", "07")
  )
  counts <- data.frame(date = cal$date[c(1, 3, 4)], day_type = "weekday", month = c("06", "07", "07"), n = 4:6)
  d <- suppressWarnings(add_counts(creel_design(cal, date = date, strata = c(day_type, month)), counts))
  err <- expect_error(suppressWarnings(estimate_effort(d)), class = "creel_error_single_psu")
  expect_match(conditionMessage(err), "weekday / 06", fixed = TRUE)
})

# ---- #503: single-PSU advice names no method that also refuses ----------------

test_that("#503: no single-PSU error sends the user to a method that refuses the same design", {
  # A one-day stratum has no day-to-day variation to measure, so every
  # variance method refuses it. The jackknife and bootstrap errors used to say
  # "or use variance = 'taylor'", which sent the user from one refusal to the
  # next. Each method is checked to refuse, so naming any of them would be the
  # same dead end.
  d <- make_repvar_design(1L)
  for (v in c("taylor", "jackknife", "bootstrap")) {
    err <- expect_error(
      suppressWarnings(estimate_effort(d, variance = v, target = "sampled_days")),
      class = "creel_error_single_psu"
    )
    msg <- cli::ansi_strip(conditionMessage(err))
    expect_no_match(msg, "variance =", fixed = TRUE)
    expect_no_match(msg, "taylor", ignore.case = TRUE)
    expect_match(msg, "combine sparse strata", fixed = TRUE)
  }
})

test_that("#503: a single-PSU error raised in a tryCatch() handler names a function, not the handler", {
  # Without `call =`, cli reports the handler, which prints as
  # "Error in `value[[3L]]()`".
  d <- make_repvar_design(1L)
  for (v in c("taylor", "jackknife")) {
    for (by_type in c(FALSE, TRUE)) {
      err <- expect_error(
        suppressWarnings(if (by_type) {
          estimate_effort(d, variance = v, target = "sampled_days", by = day_type)
        } else {
          estimate_effort(d, variance = v, target = "sampled_days")
        }),
        class = "creel_error_single_psu"
      )
      fn <- deparse(conditionCall(err)[[1]])
      expect_false(grepl("value[[", fn, fixed = TRUE), info = paste(v, by_type, fn))
      expect_match(fn, "^estimate_effort", info = paste(v, by_type))
    }
  }
})

# ---- #613: the bootstrap refuses a one-PSU stratum, as Taylor and the jackknife do

# Weekday: 3 of 5 days sampled. Weekend: 1 of 2 days sampled, so one PSU in a
# stratum that is not a census.
make_one_psu_mixed_design <- function() {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:6,
    day_type = c(rep("weekday", 5), rep("weekend", 2))
  )
  cnt <- data.frame(
    date = cal$date[c(1, 2, 3, 6)], day_type = cal$day_type[c(1, 2, 3, 6)],
    count = c(10L, 14L, 9L, 30L), site = c("a", "b", "a", "b")
  )
  suppressWarnings(add_counts(creel_design(cal, date = date, strata = day_type), cnt))
}

test_that("#613: bootstrap refuses one one-PSU stratum among several instead of giving it zero variance", {
  # The Canty-Davison bootstrap resamples n_h of n_h PSUs; with n_h = 1 every
  # replicate draws the same day, so the stratum's variance came out as 0. The
  # ungrouped SE silently left the weekend out, and `by = day_type` reported the
  # weekend with se = 0 -- a zero that reads as "measured, no uncertainty".
  d <- make_one_psu_mixed_design()
  calls <- list(
    function() estimate_effort(d, variance = "bootstrap", target = "sampled_days"),
    function() estimate_effort(d, variance = "bootstrap", target = "sampled_days", by = day_type),
    function() estimate_effort(d, variance = "bootstrap", target = "sampled_days", by = site)
  )
  for (f in calls) {
    set.seed(1)
    err <- expect_error(suppressWarnings(f()), class = "creel_error_single_psu")
    msg <- cli::ansi_strip(conditionMessage(err))
    expect_match(msg, "weekend", fixed = TRUE)
    expect_match(msg, "combine sparse strata", fixed = TRUE)
  }
  # The other two methods refuse the same design; the bootstrap now agrees.
  for (v in c("taylor", "jackknife")) {
    expect_error(
      suppressWarnings(estimate_effort(d, variance = v, target = "sampled_days", by = day_type)),
      class = "creel_error_single_psu"
    )
  }
})

test_that("#613: grouped bootstrap on all one-PSU strata refuses instead of returning NaN", {
  d <- make_repvar_design(1L)
  set.seed(1)
  expect_error(
    suppressWarnings(estimate_effort(d, variance = "bootstrap", target = "sampled_days", by = day_type)),
    class = "creel_error_single_psu"
  )
})

test_that("#613: a one-day stratum that is its whole calendar, counted twice, is still estimated by bootstrap", {
  # N = n = 1: the between-day variance is exactly 0 and the within-day term
  # carries the stratum (#505). This one-PSU stratum is a census, not missing
  # information, so the refusal must not reach it.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:5,
    day_type = c(rep("weekday", 5), "weekend")
  )
  cnt <- data.frame(
    date = rep(cal$date[c(1, 2, 3, 6)], each = 2),
    day_type = rep(cal$day_type[c(1, 2, 3, 6)], each = 2),
    t = rep(1:2, 4), count = c(10, 14, 9, 12, 20, 16, 30, 26)
  )
  d <- suppressWarnings(add_counts(
    creel_design(cal, date = date, strata = day_type), cnt,
    count_time_col = t
  ))
  set.seed(1)
  boot <- suppressWarnings(estimate_effort(d, variance = "bootstrap", by = day_type))$estimates
  taylor <- suppressWarnings(estimate_effort(d, variance = "taylor", by = day_type))$estimates
  we <- boot$day_type == "weekend"
  expect_true(all(is.finite(boot$se)))
  expect_gt(boot$se[we], 0)
  # Its SE is the within-day term alone under either method.
  expect_equal(boot$se[we], taylor$se[taylor$day_type == "weekend"])

  # Nor may it change the other strata's bootstrap variance. Averaged into the
  # PSUs per stratum, the census's one PSU shrank that count from 3 to 1.5 and
  # doubled the weekday's bootstrap variance (ensemble review). With the same
  # seed, the weekday's day-to-day SE must be what it is with no weekend at all.
  weekday_only <- suppressWarnings(add_counts(
    creel_design(cal[cal$day_type == "weekday", ], date = date, strata = day_type),
    cnt[cnt$day_type == "weekday", ],
    count_time_col = t
  ))
  set.seed(1)
  alone <- suppressWarnings(estimate_effort(weekday_only, variance = "bootstrap"))$estimates
  expect_equal(boot$se_between[!we], alone$se_between)
})

test_that("#613: a census stratum labelled with the empty string is not refused", {
  # The census exemption is looked up per stratum; a name lookup never matches
  # "", which refused a stratum Taylor and the jackknife estimate. Checked on
  # the survey design directly, then end to end below now that the within-day
  # term also reaches a "" stratum (#614).
  df <- data.frame(
    strat = c("a", "a", "a", ""), day = c(1, 2, 3, 4),
    y = c(10, 14, 9, 30), pop = c(5, 5, 5, 1)
  )
  svy <- survey::svydesign(ids = ~day, strata = ~strat, fpc = ~pop, data = df)
  expect_null(refuse_single_psu_bootstrap(svy))

  # The same stratum not fully sampled is refused.
  df$pop[4] <- 2
  svy <- survey::svydesign(ids = ~day, strata = ~strat, fpc = ~pop, data = df)
  expect_error(refuse_single_psu_bootstrap(svy), class = "creel_error_single_psu")

  # End to end: a "" stratum that is its whole calendar (one day) and was
  # counted twice is a census, and the bootstrap estimates it.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:5, day_type = c(rep("weekday", 5), ""))
  cnt <- data.frame(
    date = rep(cal$date[c(1, 2, 3, 6)], each = 2),
    day_type = rep(cal$day_type[c(1, 2, 3, 6)], each = 2),
    t = rep(1:2, 4), count = c(10, 14, 9, 12, 20, 16, 30, 26)
  )
  design <- suppressWarnings(suppressMessages(
    add_counts(creel_design(cal, date = date, strata = day_type), cnt, count_time_col = t)
  ))
  set.seed(613)
  est <- suppressWarnings(suppressMessages(
    estimate_effort(design, target = "period_total", variance = "bootstrap")
  ))$estimates
  expect_true(is.finite(est$se))
})
