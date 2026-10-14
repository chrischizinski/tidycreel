# The finite-population correction removed within-day uncertainty (GH #505).
#
# A day's effort estimate varies for two reasons: which day was drawn, and when
# in the day its counts fell. The between-day variance of the daily estimates
# carries both. The FPC (1 - n/N) is right for the first -- sample every day
# and there is no day-to-day uncertainty left -- but wrong for the second:
# with every day sampled, each count still fell at a random moment. Cochran
# (1977, ch. 10) restores the second with a within-day term, which needs two or
# more counts per day. With one count per day nothing restored it, and a
# fully sampled stratum reported an SE of exactly 0.
#
# The fix: a stratum takes the FPC only when every sampled day in it has two
# or more counts. Otherwise its variance is the with-replacement one, which is
# conservative (Cochran eq. 10.42). The multi-count case is unchanged.

q <- function(x) suppressWarnings(suppressMessages(x))

effort_se <- function(design, ...) {
  est <- q(estimate_effort(design, target = "period_total", ...))$estimates
  c(se = est$se, se_between = est$se_between, se_within = est$se_within)
}

single_count_design <- function(n_anglers, n_days = length(n_anglers)) {
  cal <- data.frame(date = as.Date("2024-06-03") + seq_len(n_days) - 1L, day_type = "weekday")
  counts <- data.frame(
    date = cal$date[seq_along(n_anglers)], day_type = "weekday",
    n_anglers = n_anglers, hours = 10
  )
  q(add_counts(creel_design(cal, date = date, strata = day_type), counts, period_length_col = hours))
}

two_count_design <- function(drop_row = NULL) {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:7, day_type = "weekday")
  counts <- data.frame(
    date = rep(as.Date("2024-06-03") + 0:3, each = 2), day_type = "weekday",
    count_time = rep(c("am", "pm"), 4),
    n_anglers = c(10L, 20L, 20L, 30L, 30L, 40L, 40L, 50L), hours = 10
  )
  if (!is.null(drop_row)) counts <- counts[-drop_row, ]
  q(add_counts(creel_design(cal, date = date, strata = day_type), counts,
    count_time_col = count_time, period_length_col = hours
  ))
}

test_that("a fully sampled stratum with one count per day does not report SE 0", {
  # Each count is 0 or 20 anglers depending on when it fell, so each day is 0
  # or 200 angler-hours: the true SE of the total over count times is 200.
  # Before the fix the FPC was 1 - 4/4 = 0 and the SE was exactly 0.
  design <- single_count_design(c(0L, 20L, 20L, 0L))
  se <- effort_se(design)

  daily <- c(0, 200, 200, 0)
  expect_equal(se[["se"]], sqrt(4^2 * var(daily) / 4)) # no FPC: 230.9
  expect_gt(se[["se"]], 200) # conservative, never below the truth here
})

test_that("one count per day on a partly sampled stratum gets no FPC", {
  # 4 of 8 days sampled. With the FPC the variance would be halved.
  design <- single_count_design(c(15L, 25L, 35L, 45L), n_days = 8)
  daily <- c(150, 250, 350, 450)
  expect_equal(effort_se(design)[["se"]], sqrt(8^2 * var(daily) / 4))
})

test_that("two counts per day keep the FPC and the within-day term", {
  # The within-day term restores what the FPC removes, so this case was
  # already right and must not change: Cochran's two-stage estimator.
  se <- effort_se(two_count_design())
  daily <- c(150, 250, 350, 450)
  expect_equal(se[["se_between"]], sqrt(8^2 * (1 - 4 / 8) * var(daily) / 4)) # 365.1
  expect_equal(se[["se_within"]], sqrt(8 * 5000 / 2)) # 141.4
})

test_that("one single-count day takes the FPC away from its whole stratum", {
  # Day 4 lost its afternoon count. Its within-day variation is then
  # unestimated, so the stratum cannot take the correction.
  se <- effort_se(two_count_design(drop_row = 8))
  daily <- c(150, 250, 350, 400)
  expect_equal(se[["se_between"]], sqrt(8^2 * var(daily) / 4))
})

test_that("strata are corrected independently, under every variance method", {
  # Weekdays: one count a day (no FPC). Weekends: two counts a day (FPC kept).
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:13,
    day_type = rep(c("weekday", "weekend"), c(10, 4))
  )
  counts <- rbind(
    data.frame(
      date = as.Date("2024-06-03") + 0:4, day_type = "weekday", count_time = "am",
      n_anglers = c(5L, 9L, 7L, 12L, 6L), hours = 10
    ),
    data.frame(
      date = rep(as.Date("2024-06-03") + 10:11, each = 2), day_type = "weekend",
      count_time = rep(c("am", "pm"), 2), n_anglers = c(20L, 30L, 25L, 15L), hours = 10
    )
  )
  design <- q(add_counts(creel_design(cal, date = date, strata = day_type), counts,
    count_time_col = count_time, period_length_col = hours
  ))

  v_weekday <- 10^2 * var(c(50, 90, 70, 120, 60)) / 5 # no FPC
  v_weekend <- 4^2 * (1 - 2 / 4) * var(c(250, 200)) / 2 # FPC
  taylor <- effort_se(design)
  expect_equal(taylor[["se_between"]], sqrt(v_weekday + v_weekend))
  expect_equal(taylor[["se_within"]], sqrt(4 * 5000 / 2))

  # The jackknife reproduces Taylor for a total. It reads "no FPC" as a very
  # large population, which an infinite one would turn into NaN.
  expect_equal(effort_se(design, variance = "jackknife"), taylor)

  # The bootstrap cannot build a population that large, so the two groups of
  # strata are resampled separately. Its SE is random; it must exist and sit
  # near Taylor's.
  set.seed(505)
  boot <- effort_se(design, variance = "bootstrap")
  expect_true(is.finite(boot[["se"]]))
  expect_lt(abs(boot[["se"]] / taylor[["se"]] - 1), 0.3)
})

test_that("the mixed-FPC bootstrap draws exactly what survey draws when all strata are corrected", {
  # The builder exists only for mixed designs; on a fully corrected design it
  # must agree with survey::as.svrepdesign() draw for draw, or it is not the
  # same bootstrap.
  design <- survey::svydesign(
    ids = ~psu, strata = ~stratum, fpc = ~pop, weights = ~w, nest = TRUE,
    data = data.frame(
      psu = 1:8, stratum = rep(c("a", "b"), each = 4), pop = rep(c(20, 12), each = 4),
      w = rep(c(5, 3), each = 4), y = c(3, 7, 2, 9, 11, 4, 6, 8)
    )
  )
  set.seed(1)
  reference <- survey::SE(survey::svytotal(~y, survey::as.svrepdesign(design, type = "bootstrap", replicates = 50)))
  set.seed(1)
  builder <- survey::SE(survey::svytotal(~y, bootstrap_mixed_fpc(design, replicates = 50)))
  expect_equal(as.numeric(builder), as.numeric(reference))
})

test_that("a one-day census stratum with one count refuses its variance instead of reporting 0", {
  # One day out of one, counted once: the correction used to make it a
  # certainty unit with SE 0. Neither variance part is estimable from a single
  # count, so the grouped path refuses with the package's own error rather
  # than survey's raw one.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:4,
    day_type = c(rep("weekday", 4), "holiday")
  )
  counts <- data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-07")),
    day_type = c("weekday", "weekday", "holiday"),
    n_anglers = c(10L, 12L, 30L), hours = 10
  )
  design <- q(add_counts(creel_design(cal, date = date, strata = day_type), counts,
    period_length_col = hours
  ))
  expect_error(
    q(estimate_effort(design, by = day_type, target = "period_total")),
    class = "creel_error_single_psu"
  )
})
