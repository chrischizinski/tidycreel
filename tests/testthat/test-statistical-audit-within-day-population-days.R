# The within-day variance component scales by the stratum's population days
# N_h. It counted calendar ROWS, so a calendar with several rows per date --
# any multi-period generate_schedule() output used as the design calendar --
# inflated N_h and the within-day SE by sqrt(rows per date), with no message
# (GH #436). The between-day path already counted distinct dates.

wdn_counts <- function(cal) {
  days <- cal$date[c(1, 2, 3, 6, 7, 8, 9, 10, 13, 14)]
  set.seed(1)
  cn <- data.frame(
    date = rep(days, each = 3),
    count_time = rep(c("08:00", "11:00", "14:00"), 10),
    anglers = stats::rpois(30, 15),
    hours = 10
  )
  cn$day_type <- cal$day_type[match(cn$date, cal$date)]
  cn
}

wdn_effort <- function(cal, cn, target) {
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts( # nolint: object_usage_linter
    d, cn, count_col = anglers, count_time_col = count_time, period_length_col = hours
  )))
  suppressWarnings(suppressMessages(estimate_effort(d, target = target)))$estimates # nolint: object_usage_linter
}

test_that("#436: several calendar rows per date do not change any SE", {
  cal1 <- data.frame(
    date = as.Date("2024-06-03") + 0:13,
    day_type = rep(c(rep("weekday", 5), rep("weekend", 2)), 2)
  )
  cal2 <- cal1[rep(seq_len(nrow(cal1)), each = 2), ]
  cal2$period_id <- rep(1:2, nrow(cal1))
  cn <- wdn_counts(cal1)
  for (tg in c("sampled_days", "stratum_total", "period_total")) {
    one <- wdn_effort(cal1, cn, tg)
    two <- wdn_effort(cal2, cn, tg)
    expect_equal(two$estimate, one$estimate, tolerance = 1e-12, info = tg)
    expect_equal(two$se_within, one$se_within, tolerance = 1e-12, info = tg)
    expect_equal(two$se, one$se, tolerance = 1e-12, info = tg)
  }
})

test_that("#436: a generate_schedule() calendar with two periods gives the one-row-per-date SE", {
  sched <- generate_schedule(start_date = "2024-06-03", end_date = "2024-06-16", n_periods = 2,
                             sampling_rate = 1, include_all = TRUE, seed = 1)
  expect_equal(nrow(sched), 28L) # two rows per date
  one_row <- unique(sched[c("date", "day_type")])
  cn <- wdn_counts(one_row)
  expect_equal(wdn_effort(sched, cn, "stratum_total")$se_within,
               wdn_effort(one_row, cn, "stratum_total")$se_within,
               tolerance = 1e-12)
})
