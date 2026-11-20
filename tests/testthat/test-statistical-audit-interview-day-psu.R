# A rate's variance is taken between interview days (GH #661) ----
#
# Days are drawn; parties are met within a drawn day. Parties on one day share
# its weather, water and fish, so they are not independent draws: the day is
# the primary sampling unit and the interview the secondary one (Cochran 1977,
# Theorem 10.1; Breidt et al., the site-day as PSU; Bernard et al. 1998, the
# sampled period as first stage). Before #661 every interview was its own unit
# (`ids = ~1`), so 50 interviews on one day gave the same SE as 50 interviews
# on 50 days -- the variance could not see the design's weakest dimension.
#
# The references below are computed in base R from the definition of the
# linearized ratio variance, sharing no tidycreel or survey code.

dpsu_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-03") + c(0:4, 7:11),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
}

# 6 interview days x 6 parties. `rate_by_day` gives each day its own catch
# rate, so days differ; within a day the parties scatter around it.
dpsu_interviews <- function(dates, rate_by_day) {
  n_per <- 6L
  effort <- rep(c(2, 3, 4, 2.5, 3.5, 1.5), times = length(dates))
  jitter <- rep(c(-0.3, 0.2, 0.1, -0.1, 0.25, -0.15), times = length(dates))
  rate <- rep(rate_by_day, each = n_per) + jitter
  data.frame(
    date = rep(dates, each = n_per),
    catch_total = rate * effort,
    hours_fished = effort,
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
}

dpsu_design <- function(interviews, cal = dpsu_calendar()) {
  suppressMessages(suppressWarnings(add_interviews(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    interviews,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )))
}

# Linearized SE of sum(y) / sum(x), stratified, clustered on `psu`, no fpc:
# z = (y - R x) / X summed within each PSU, then n_h / (n_h - 1) times the
# squared deviations of the PSU totals from their stratum mean.
hand_ratio_se <- function(y, x, psu, stratum) {
  r <- sum(y) / sum(x)
  z <- (y - r * x) / sum(x)
  v <- 0
  for (h in unique(stratum)) {
    zt <- tapply(z[stratum == h], psu[stratum == h], sum)
    n <- length(zt)
    v <- v + n / (n - 1) * sum((zt - mean(zt))^2)
  }
  sqrt(v)
}

test_that("DPSU-01 (#661): the catch-rate SE is the two-stage value, days as PSUs", {
  cal <- dpsu_calendar()
  iv <- dpsu_interviews(cal$date[1:6], rate_by_day = c(1.0, 1.6, 0.8, 2.0, 1.2, 1.4))
  result <- suppressWarnings(estimate_catch_rate(dpsu_design(iv))) # nolint: object_usage_linter

  day <- hand_ratio_se(iv$catch_total, iv$hours_fished, iv$date, rep("weekday", nrow(iv)))
  interview <- hand_ratio_se(iv$catch_total, iv$hours_fished, seq_len(nrow(iv)), rep("weekday", nrow(iv)))

  expect_equal(result$estimates$estimate, sum(iv$catch_total) / sum(iv$hours_fished), tolerance = 1e-12)
  expect_equal(result$estimates$se, day, tolerance = 1e-10)
  # The interview-level value is the one #661 replaced. It must differ here, or
  # this test could not tell the two designs apart.
  expect_false(isTRUE(all.equal(day, interview, tolerance = 1e-3)))
})

test_that("DPSU-02 (#661): parties packed into alike days widen the SE; interview-level could not see it", {
  # The same 36 parties, assigned to days two ways. Packed: each day holds
  # parties of one rate, so days differ strongly. Spread: each day holds a mix,
  # so days agree. An interview-level variance ignores the date and reports
  # the same SE for both -- it would reward the design that learns least about
  # day-to-day variation, which is what a camera survey's interview schedule
  # most needs to know.
  cal <- dpsu_calendar()
  dates <- cal$date[1:6]
  packed <- dpsu_interviews(dates, rate_by_day = c(0.5, 0.7, 0.9, 2.1, 2.3, 2.5))
  spread <- packed
  spread$date <- rep(dates, times = 6) # each day now gets one party of each rate

  se_packed <- suppressWarnings(estimate_catch_rate(dpsu_design(packed)))$estimates$se # nolint: object_usage_linter
  se_spread <- suppressWarnings(estimate_catch_rate(dpsu_design(spread)))$estimates$se # nolint: object_usage_linter

  expect_gt(se_packed, 2 * se_spread)

  ones <- rep("weekday", nrow(packed))
  expect_equal(
    hand_ratio_se(packed$catch_total, packed$hours_fished, seq_len(nrow(packed)), ones),
    hand_ratio_se(spread$catch_total, spread$hours_fished, seq_len(nrow(spread)), ones),
    tolerance = 1e-12
  )
})

test_that("DPSU-03 (#661): a stratum interviewed on one day is refused by name", {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:6,
    day_type = c(rep("weekday", 5), "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  # Weekdays on three days; the weekend only on Saturday.
  iv <- rbind(
    dpsu_interviews(cal$date[1:3], rate_by_day = c(1, 1.5, 2)),
    dpsu_interviews(cal$date[6], rate_by_day = 1.2)
  )
  # Accepted when attached: no variance is taken there, and effort or another
  # stratum may still be estimable.
  design <- dpsu_design(iv, cal)
  expect_s3_class(design, "creel_design")

  # One day gives no day-to-day variation under any variance method, so the
  # rate is refused rather than given an SE nothing was observed for.
  for (v in c("taylor", "bootstrap", "jackknife")) {
    err <- expect_error(
      suppressWarnings(estimate_catch_rate(design, variance = v)), # nolint: object_usage_linter
      class = "creel_error_single_psu"
    )
    expect_match(conditionMessage(err), "weekend", fixed = TRUE)
    expect_match(conditionMessage(err), "only one day", fixed = TRUE)
    expect_no_match(conditionMessage(err), "weekday", fixed = TRUE)
  }

  # A second weekend day makes it estimable.
  iv2 <- rbind(iv, dpsu_interviews(cal$date[7], rate_by_day = 0.9))
  expect_no_error(suppressWarnings(estimate_catch_rate(dpsu_design(iv2, cal)))) # nolint: object_usage_linter
})
