# GH #405: one within-day variance estimator for every effort target.
#
# The within-day term is the second stage of a two-stage estimator: each sampled
# day's count mean has variance s_d^2 / k_d, and the stratum's term is
# (N / n) * sum_d s_d^2 / k_d (Cochran 1977, ch. 11). Rasmussen et al.'s (1998)
# pooled form, (N / k_bar) * sum(ss_d) / (n * (k_bar - 1)), equals it only when
# every day has the same number of counts; with 2 and 10 counts a day it was
# 56% low on #405's probe, and its error has no fixed sign.
#
# A stratum with any day counted once takes no finite-population correction
# (GH #505). Its uncorrected day-to-day term already contains the within-day
# variation, so it carries no within-day term on any target.
#
# Reference values are computed in base R from the raw counts below, not
# through any tidycreel helper.

# Ten weekdays (Mon 3 Jun .. Fri 14 Jun 2024), four sampled. One weekend
# stratum with one count a day keeps the design stratified.
make_405_design <- function(k_per_day, month_of_day = NULL) {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:13)
  cal$day_type <- ifelse(format(cal$date, "%u") %in% c("6", "7"), "weekend", "weekday")
  wd <- cal$date[cal$day_type == "weekday"][1:4]
  rows <- lapply(seq_along(wd), function(i) {
    k <- k_per_day[i]
    m <- 10 * i
    y <- if (k == 1L) m else m + (seq_len(k) - (k + 1) / 2) # spread varies with k
    data.frame(
      date = wd[i], day_type = "weekday",
      count_time = sprintf("t%02d", seq_len(k)), n = y
    )
  })
  counts <- do.call(rbind, rows)
  wk <- cal$date[cal$day_type == "weekend"][1:2]
  counts <- rbind(counts, data.frame(
    date = wk, day_type = "weekend", count_time = "t01", n = c(50, 90)
  ))
  if (!is.null(month_of_day)) {
    counts$half <- c(rep(month_of_day, times = k_per_day), "a", "b")
  }
  design <- creel_design(cal, date = date, strata = day_type)
  list(
    design = add_counts(design, counts, count_col = "n", count_time_col = count_time),
    counts = counts[counts$day_type == "weekday", ],
    N = 10L, n = 4L
  )
}

# sum_d s_d^2 / k_d over the weekday days, from the raw counts.
var_of_day_means <- function(counts) {
  per_day <- split(counts$n, counts$date)
  sum(vapply(per_day, function(y) stats::var(y) / length(y), numeric(1)))
}

weekday_row <- function(design, target) {
  e <- tidy(suppressWarnings(suppressMessages(
    estimate_effort(design, target = target, by = day_type)
  )))
  e[e$day_type == "weekday", ]
}

test_that("expanded within-day term weights each day by its own counts (#405)", {
  f <- make_405_design(c(2L, 10L, 2L, 10L))
  expected <- sqrt((f$N / f$n) * var_of_day_means(f$counts))

  for (target in c("stratum_total", "period_total")) {
    row <- weekday_row(f$design, target)
    expect_equal(row$se_within, expected, label = target)
  }
  # The pooled k_bar form gives a different number here (larger on this fixture,
  # smaller on #405's: its error has no fixed sign); were it still in use, the
  # equality above would fail.
  ss <- vapply(split(f$counts$n, f$counts$date), function(y) sum((y - mean(y))^2), numeric(1))
  k_bar <- mean(c(2, 10, 2, 10))
  pooled <- sqrt((f$N / k_bar) * sum(ss) / (f$n * (k_bar - 1)))
  expect_gt(abs(pooled - expected) / expected, 0.5)
})

test_that("the within-day term differs across targets only by N / n (#405)", {
  # One formula on every target: sampled_days is the same term with N = n. Before
  # #405 sampled_days was per-day and the expanded targets pooled, so this ratio
  # was not sqrt(N / n) with unequal counts.
  f <- make_405_design(c(2L, 10L, 2L, 10L))
  sd <- weekday_row(f$design, "sampled_days")
  st <- weekday_row(f$design, "stratum_total")
  expect_equal(sd$se_within, sqrt(var_of_day_means(f$counts)))
  expect_equal(st$se_within / sd$se_within, sqrt(f$N / f$n))
})

test_that("equal counts a day keep Rasmussen's pooled value (#405)", {
  f <- make_405_design(c(3L, 3L, 3L, 3L))
  ss <- vapply(split(f$counts$n, f$counts$date), function(y) sum((y - mean(y))^2), numeric(1))
  rasmussen <- sqrt((f$N / 3) * sum(ss) / (f$n * (3 - 1)))
  expect_equal(weekday_row(f$design, "stratum_total")$se_within, rasmussen)
})

test_that("a stratum with a one-count day carries no within-day term on any target (#405)", {
  f <- make_405_design(c(1L, 3L, 3L, 3L))
  for (target in c("sampled_days", "stratum_total", "period_total")) {
    row <- weekday_row(f$design, target)
    # The day-to-day term is uncorrected and already holds the within-day
    # variation; the within-day term on top of it counted that twice.
    expect_equal(row$se_within, 0, label = target)
    expect_equal(row$se, row$se_between, label = target)
    expect_equal(row$se_basis, "between_day_upper_bound", label = target)
  }
  # The uncorrected day-to-day term: unit weights N / n, no FPC, so
  # Var = N^2 * s^2 / n of the day means.
  day_means <- vapply(split(f$counts$n, f$counts$date), mean, numeric(1))
  expect_equal(
    weekday_row(f$design, "stratum_total")$se_between,
    sqrt(f$N^2 * stats::var(day_means) / f$n)
  )
})

test_that("the one-count rule is per stratum, not per by group (#405)", {
  # Days 1-2 in half "a", days 3-4 in half "b"; the one-count day is in "a".
  # The weekday stratum takes no correction, so half "b" -- whose own days all
  # have 3 counts -- must not add a within-day term on top of its uncorrected
  # day-to-day term either.
  f <- make_405_design(c(1L, 3L, 3L, 3L), month_of_day = c("a", "a", "b", "b"))
  e <- tidy(suppressWarnings(suppressMessages(
    estimate_effort(f$design, target = "stratum_total", by = half)
  )))
  expect_equal(e$se_within, rep(0, nrow(e)))
})
