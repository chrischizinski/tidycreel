# The regression catch rate is clustered on the survey day (GH #665) ----
#
# CPUE3 is the slope of catch on angler effort across interviews: through the
# origin sum(c e) / sum(e^2), a ratio of two totals; with an intercept the
# least-squares coefficient. Its standard error was a leave-one-INTERVIEW-out
# jackknife, so 12 trips on one day counted as 12 independent units, while
# every other rate takes its variance between days (GH #661). The slope is
# now estimated on the same day-clustered interview survey: linearized under
# Taylor (Binder 1983; Lumley 2010, ch. 5), delete-one-day under the jackknife.
#
# References are computed in base R from the definitions, sharing no tidycreel
# or survey code.
#
# They are the interview survey's slope with equal interview weights. Across
# strata a regression rate is now each stratum's slope weighted by its effort
# (GH #691), which sits on top of these mechanics and is tested in
# test-statistical-audit-pooled-strata.R, so this file runs with that
# weighting switched off.
# File-scoped: testthat runs a top-level defer at the end of this file.
old_rate_pooling <- rate_pooling_state$off
rate_pooling_state$off <- TRUE
withr::defer(rate_pooling_state$off <- old_rate_pooling)

reg_q <- function(x) suppressWarnings(suppressMessages(x))

reg_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-03") + c(0:4, 7:11),
    day_type = rep(c("weekday", "weekend"), each = 5),
    stringsAsFactors = FALSE
  )
}

# Six complete trips a day; each day has its own catch rate.
reg_interviews <- function(dates = reg_calendar()$date) {
  day_rate <- c(0.6, 1.8, 1.0, 2.4, 1.3, 0.9, 2.0, 1.5, 0.7, 2.2)[seq_along(dates)]
  effort <- c(2, 3, 4, 2.5, 3.5, 1.5)
  jitter <- c(-0.3, 0.2, 0.1, -0.1, 0.25, -0.15)
  do.call(rbind, lapply(seq_along(dates), function(i) {
    data.frame(
      date = dates[i], catch_total = (day_rate[i] + jitter) * effort + 0.4,
      hours_fished = effort, trip_status = "complete", trip_duration = effort,
      stringsAsFactors = FALSE
    )
  }))
}

reg_design <- function(iv, cal = reg_calendar()) {
  reg_q(add_interviews(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    iv,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

# Stratified between-day variance of a linearization score: per-day sums over
# every interviewed day, then n_h / (n_h - 1) * sum((Z - Zbar)^2) per stratum.
reg_taylor_var <- function(z, day, day_stratum) {
  days <- names(day_stratum)
  s <- tapply(z, factor(day, levels = days), sum)
  s[is.na(s)] <- 0
  v <- 0
  for (h in unique(day_stratum)) {
    k <- day_stratum == h
    n <- sum(k)
    v <- v + n / (n - 1) * sum((s[k] - mean(s[k]))^2)
  }
  v
}

reg_day_stratum <- function(iv, cal = reg_calendar()) {
  key <- cal[cal$date %in% iv$date, ]
  stats::setNames(key$day_type, as.character(key$date))
}

test_that("REG-01 (#665): the through-origin slope's Taylor SE is between days", {
  iv <- reg_interviews()
  d <- reg_design(iv)
  x <- d$interviews
  c_ <- x$catch_total
  e <- x[[d$angler_effort_col]]
  beta <- sum(c_ * e) / sum(e^2)
  z <- (c_ * e - beta * e^2) / sum(e^2)
  se_hand <- sqrt(reg_taylor_var(z, as.character(x$date), reg_day_stratum(x)))

  r <- reg_q(estimate_catch_rate(d, estimator = "regression"))
  expect_equal(r$estimates$estimate, beta, tolerance = 1e-12)
  expect_equal(r$estimates$se, se_hand, tolerance = 1e-8)
  expect_identical(r$variance_method, "taylor")
})

test_that("REG-02 (#665): the intercept slope's SE is the linearized coefficient's", {
  iv <- reg_interviews()
  d <- reg_design(iv)
  x <- d$interviews
  y <- x$catch_total
  e <- x[[d$angler_effort_col]]
  sxx <- sum((e - mean(e))^2)
  beta <- sum((e - mean(e)) * (y - mean(y))) / sxx
  resid <- (y - mean(y)) - beta * (e - mean(e))
  z <- (e - mean(e)) * resid / sxx
  se_hand <- sqrt(reg_taylor_var(z, as.character(x$date), reg_day_stratum(x)))

  r <- reg_q(estimate_catch_rate(d, estimator = "regression", force_origin = FALSE))
  expect_equal(r$estimates$estimate, beta, tolerance = 1e-10)
  expect_equal(r$estimates$se, se_hand, tolerance = 1e-6)
})

test_that("REG-03 (#665): the jackknife deletes a day, not an interview", {
  # JKn: delete day d of stratum h, weight that stratum's other days by
  # n_h / (n_h - 1); Var = sum_h (n_h - 1) / n_h sum_d (beta_(d) - beta)^2.
  iv <- reg_interviews()
  d <- reg_design(iv)
  x <- d$interviews
  c_ <- x$catch_total
  e <- x[[d$angler_effort_col]]
  day <- as.character(x$date)
  ds <- reg_day_stratum(x)
  slope <- function(w) sum(w * c_ * e) / sum(w * e^2)
  full <- slope(rep(1, nrow(x)))
  v <- 0
  for (h in unique(ds)) {
    days_h <- names(ds)[ds == h]
    n <- length(days_h)
    reps <- vapply(days_h, function(dd) {
      slope(ifelse(day == dd, 0, ifelse(x$day_type == h, n / (n - 1), 1)))
    }, numeric(1))
    v <- v + (n - 1) / n * sum((reps - full)^2)
  }
  r <- reg_q(estimate_catch_rate(d, estimator = "regression", variance = "jackknife"))
  expect_equal(r$estimates$se, sqrt(v), tolerance = 1e-8)
  expect_identical(r$variance_method, "jackknife")
})

test_that("REG-04 (#665): a group's slope is a domain of every interviewed day", {
  # Group "big" holds the trips of 3 hours or more, and has none on two days
  # (one per stratum). Those days were interviewed: for the group they are
  # days of zero catch and zero effort, and they stay in the variance.
  iv <- reg_interviews()
  iv$boat <- ifelse(iv$hours_fished >= 3, "big", "small")
  cal <- reg_calendar()
  iv$boat[iv$date %in% cal$date[c(2, 7)]] <- "small"
  d <- reg_design(iv)
  x <- d$interviews
  e <- x[[d$angler_effort_col]]
  c_ <- x$catch_total
  r <- reg_q(estimate_catch_rate(d, estimator = "regression", by = boat))
  for (g in c("big", "small")) {
    k <- x$boat == g
    beta <- sum(c_[k] * e[k]) / sum(e[k]^2)
    z <- ifelse(k, (c_ * e - beta * e^2) / sum(e[k]^2), 0)
    se_hand <- sqrt(reg_taylor_var(z, as.character(x$date), reg_day_stratum(x)))
    row <- r$estimates[r$estimates$boat == g, ]
    expect_equal(row$estimate, beta, tolerance = 1e-12)
    expect_equal(row$se, se_hand, tolerance = 1e-8)
    expect_equal(row$n, sum(k))
  }
})

test_that("REG-05 (#665): a stratum interviewed on one day is refused, as for every rate", {
  # The issue's case: the weekend's trips all on one day. The ratio estimator
  # refused it; the regression returned an interview-level SE.
  cal <- reg_calendar()
  iv <- reg_interviews(cal$date[1:6])
  d <- add_rate_counts(reg_design(iv)) # rates pooled across strata need each stratum's effort (GH #691)
  for (vm in c("taylor", "bootstrap", "jackknife")) {
    expect_error(
      reg_q(estimate_catch_rate(d, estimator = "regression", variance = vm)),
      class = "creel_error_single_psu"
    )
    expect_error(
      reg_q(estimate_catch_rate(d, estimator = "ratio-of-means", variance = vm)),
      class = "creel_error_single_psu"
    )
  }
})

test_that("REG-06 (#665): the same trips packed onto fewer days change the SE", {
  # An interview-level jackknife sees the same 60 interviews either way. The
  # day-clustered SE does not: spread over 10 days the days differ; packed two
  # days' trips per day, half as many days carry the between-day variance.
  cal <- reg_calendar()
  iv <- reg_interviews()
  spread <- reg_q(estimate_catch_rate(reg_design(iv), estimator = "regression"))$estimates
  packed_iv <- iv
  packed_iv$date <- cal$date[c(1, 1, 3, 3, 5, 6, 6, 8, 8, 10)][match(iv$date, cal$date)]
  packed <- reg_q(estimate_catch_rate(reg_design(packed_iv), estimator = "regression"))$estimates
  expect_equal(packed$estimate, spread$estimate, tolerance = 1e-12)
  expect_gt(abs(packed$se / spread$se - 1), 0.05)
})

test_that("REG-07 (#665): a group's jackknife keeps the days without its trips", {
  # Delete-one-day JKn for the domain: deleting a day the group never fished
  # still reweights its stratum's other days, so it moves the replicate.
  iv <- reg_interviews()
  iv$boat <- ifelse(iv$hours_fished >= 3, "big", "small")
  cal <- reg_calendar()
  iv$boat[iv$date %in% cal$date[c(2, 7)]] <- "small"
  d <- reg_design(iv)
  x <- d$interviews
  e <- x[[d$angler_effort_col]]
  c_ <- x$catch_total
  day <- as.character(x$date)
  ds <- reg_day_stratum(x)
  k <- x$boat == "big"
  slope <- function(w) sum((w * c_ * e)[k]) / sum((w * e^2)[k])
  full <- slope(rep(1, nrow(x)))
  v <- 0
  for (h in unique(ds)) {
    days_h <- names(ds)[ds == h]
    n <- length(days_h)
    reps <- vapply(days_h, function(dd) {
      slope(ifelse(day == dd, 0, ifelse(x$day_type == h, n / (n - 1), 1)))
    }, numeric(1))
    v <- v + (n - 1) / n * sum((reps - full)^2)
  }
  r <- reg_q(estimate_catch_rate(d, estimator = "regression", by = boat, variance = "jackknife"))
  expect_equal(r$estimates$se[r$estimates$boat == "big"], sqrt(v), tolerance = 1e-8)
})

test_that("REG-08 (#665): the complete-trip slope keeps interviewed days without complete trips", {
  # Two days (one per stratum) have only incomplete trips. They were sampled:
  # for the complete-trip slope they are zero days, as for the ratio (GH #663).
  iv <- reg_interviews()
  cal <- reg_calendar()
  iv$trip_status[iv$date %in% cal$date[c(2, 7)]] <- "incomplete"
  d <- reg_design(iv)
  x <- d$interviews
  e <- x[[d$angler_effort_col]]
  c_ <- x$catch_total
  k <- x$trip_status == "complete"
  beta <- sum(c_[k] * e[k]) / sum(e[k]^2)
  z <- ifelse(k, (c_ * e - beta * e^2) / sum(e[k]^2), 0)
  se_hand <- sqrt(reg_taylor_var(z, as.character(x$date), reg_day_stratum(x)))
  r <- reg_q(estimate_catch_rate(d, estimator = "regression", use_trips = "complete"))
  expect_equal(r$estimates$estimate, beta, tolerance = 1e-12)
  expect_equal(r$estimates$se, se_hand, tolerance = 1e-8)
})

test_that("REG-09 (#665 review): edge cases fail loud or stay unknown, not wrong", {
  cal <- reg_calendar()
  iv <- reg_interviews()
  # Too few interviews is reported as too few, before any day check.
  d2 <- reg_design(iv[1:2, ], cal)
  expect_error(reg_q(estimate_catch_rate(d2, estimator = "regression", use_trips = "all")), "at least 3 interviews")
  # An unknown catch leaves the slope unknown instead of being dropped.
  iv_na <- iv
  iv_na$catch_total[iv_na$date == cal$date[3]] <- NA
  d_na <- reg_design(iv_na)
  r_na <- reg_q(estimate_catch_rate(d_na, estimator = "regression", force_origin = FALSE, use_trips = "all"))
  expect_true(is.na(r_na$estimates$estimate))
  # The intercept fit's interval is on the normal scale: finite on two days.
  d_two <- reg_design(iv[iv$date %in% cal$date[c(1, 2, 6, 7)], ])
  r_two <- reg_q(estimate_catch_rate(d_two, estimator = "regression", force_origin = FALSE))$estimates
  z <- stats::qnorm(0.975)
  expect_equal(r_two$ci_upper - r_two$estimate, z * r_two$se, tolerance = 1e-8)
  # A group whose slope is unidentifiable (one effort value) is unavailable,
  # and the other groups are still estimated.
  iv_c <- iv
  iv_c$boat <- ifelse(iv_c$hours_fished >= 3, "big", "small")
  iv_c$hours_fished[iv_c$boat == "small"] <- 2
  iv_c$trip_duration <- iv_c$hours_fished
  r_c <- reg_q(estimate_catch_rate(reg_design(iv_c), estimator = "regression", force_origin = FALSE, by = boat))$estimates
  expect_true(is.na(r_c$estimate[r_c$boat == "small"]))
  expect_false(is.na(r_c$estimate[r_c$boat == "big"]))
})

test_that("REG-10 (#665 review): a user column is not overwritten by the fit", {
  cal <- reg_calendar()
  iv <- reg_interviews()
  # A user column with a scratch variable's name is not overwritten.
  iv$.reg_e <- ifelse(iv$hours_fished >= 3, "big", "small")
  r <- reg_q(estimate_catch_rate(reg_design(iv), estimator = "regression", by = .reg_e))$estimates
  expect_setequal(r$.reg_e, c("big", "small"))
})

test_that("REG-11 (#665 review): an unknown group met on one day is refused, not merged with \"NA\"", {
  cal <- reg_calendar()
  iv <- reg_interviews()
  iv$gear <- "rod"
  iv$gear[iv$date == cal$date[1]] <- NA
  iv$gear[iv$date %in% cal$date[c(2, 3)]] <- "NA"
  d <- reg_design(iv)
  expect_error(
    reg_q(estimate_catch_rate(d, estimator = "regression", by = gear)),
    class = "creel_error_single_psu"
  )
})
