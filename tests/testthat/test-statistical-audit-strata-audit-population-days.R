# audit_strata() is the planning check of whether each stratum meets an RSE
# target. Its N_h counted calendar ROWS, so a calendar with several rows per
# date -- a multi-period generate_schedule(), or a schedule with count windows
# attached -- doubled the population days, broke the FPC (a fully sampled
# stratum reported a non-zero RSE) and moved DEFF, with no message (GH #440,
# the private copy of the rule #436 fixed in the estimators). Its strata key
# was pasted with sep = "", so two different strata could merge into one row.

sapd_cal <- function() {
  data.frame(
    date = as.Date("2024-06-03") + 0:13,
    day_type = rep(c(rep("weekday", 5), rep("weekend", 2)), 2)
  )
}

sapd_counts <- function(cal) {
  # weekday: 6 of 10 days sampled; weekend: all 4 (a census)
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

sapd_design <- function(cal, cn, strata = "day_type") {
  d <- suppressMessages(creel_design(cal, date = date, strata = dplyr::all_of(strata))) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts( # nolint: object_usage_linter
    d, cn, count_col = anglers, count_time_col = count_time, period_length_col = hours
  )))
}

sapd_audit <- function(cal, cn, ...) {
  suppressWarnings(audit_strata(sapd_design(cal, cn, ...))) # nolint: object_usage_linter
}

test_that("#440: two calendar rows per date leave N_h, RSE and DEFF unchanged", {
  cal1 <- sapd_cal()
  cal2 <- cal1[rep(seq_len(nrow(cal1)), each = 2), ]
  cal2$period_id <- rep(1:2, nrow(cal1))
  cn <- sapd_counts(cal1)
  one <- sapd_audit(cal1, cn)
  two <- sapd_audit(cal2, cn)

  # N_h is the number of days, whatever the calendar's row layout
  expect_equal(two$strata$N_h, c(10L, 4L))
  expect_equal(two$strata$N_h, one$strata$N_h)
  # the weekend is a census: the FPC makes its RSE exactly zero
  expect_equal(unname(two$strata$RSE[two$strata$stratum == "weekend"]), 0)
  expect_equal(two$strata$RSE, one$strata$RSE, tolerance = 1e-12)
  expect_equal(two$strata$DEFF, one$strata$DEFF, tolerance = 1e-12)
  expect_equal(two$deff, one$deff, tolerance = 1e-12)
})

test_that("#440: a schedule with count windows attached audits like its one-row calendar", {
  sched <- generate_schedule(start_date = "2024-06-03", end_date = "2024-06-16", n_periods = 1,
                             sampling_rate = 1, include_all = TRUE, seed = 1)
  att <- suppressMessages(attach_count_times(
    sched, n_windows = 3, window_size = 60, min_gap = 60, strategy = "systematic",
    start_time = "08:00", end_time = "18:00", seed = 1
  ))
  expect_gt(nrow(att), length(unique(att$date))) # several rows per date
  one_row <- unique(att[c("date", "day_type")])
  cn <- sapd_counts(one_row)
  expect_equal(sapd_audit(att, cn)$strata$N_h, sapd_audit(one_row, cn)$strata$N_h)
})

test_that("#440: distinct multi-column strata are never merged by their pasted labels", {
  # sep = "" made "a"+"bc" and "ab"+"c" one stratum ("abc")
  cal <- sapd_cal()
  cal$g1 <- ifelse(cal$day_type == "weekday", "a", "ab")
  cal$g2 <- ifelse(cal$day_type == "weekday", "bc", "c")
  cn <- sapd_counts(cal)
  cn$g1 <- cal$g1[match(cn$date, cal$date)]
  cn$g2 <- cal$g2[match(cn$date, cal$date)]
  res <- sapd_audit(cal, cn, strata = c("g1", "g2"))
  expect_setequal(res$strata$stratum, c("a / bc", "ab / c"))
  expect_equal(res$strata$N_h[res$strata$stratum == "a / bc"], 10L)
  expect_equal(res$strata$N_h[res$strata$stratum == "ab / c"], 4L)
})

test_that("#440: plot_design()'s n_days counts days, not calendar rows", {
  skip_if_not_installed("ggplot2")
  cal1 <- sapd_cal()
  cal2 <- cal1[rep(seq_len(nrow(cal1)), each = 2), ]
  d <- suppressMessages(creel_design(cal2, date = date, strata = day_type)) # nolint: object_usage_linter
  p <- plot_design(d) # nolint: object_usage_linter
  expect_equal(p$data$n_days[p$data$stratum == "weekday"], 10L)
  expect_equal(p$data$n_days[p$data$stratum == "weekend"], 4L)
})

test_that("#440: unit rows within a day (bank and boat) are one sampled day, not two", {
  # 4 of 8 days sampled. Counting unit rows made n_h = 8 = N_h and reported a
  # census (RSE 0) for a stratum half unsampled.
  cal <- data.frame(date = as.Date("2024-06-03") + c(0:3, 7:10), day_type = "weekday")
  cn <- data.frame(date = cal$date[c(1, 2, 5, 6)], count_time = "08:00",
                   anglers = c(10, 14, 9, 20), hours = 10, day_type = "weekday")
  cn2 <- rbind(transform(cn, effort_type = "bank"),
               transform(cn, effort_type = "boat", anglers = anglers + 3))
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts( # nolint: object_usage_linter
    d, cn2, count_col = anglers, count_time_col = count_time, period_length_col = hours,
    unit_cols = c("date", "effort_type")
  )))
  expect_equal(nrow(d$counts), 8L) # two unit rows per sampled day
  res <- suppressWarnings(audit_strata(d)) # nolint: object_usage_linter
  expect_equal(res$strata$N_h, 8L)
  expect_equal(res$strata$n_h, 4L)
  # the day's effort is its units' total, as the estimator's PSU total is
  day_tot <- tapply(d$counts[[d$count_col %||% "anglers"]], d$counts$date, sum)
  expect_equal(unname(res$strata$ybar_h), mean(day_tot))
  expect_gt(unname(res$strata$RSE), 0)
})

test_that("#440: strata whose labels would coincide are refused, not merged", {
  cal <- sapd_cal()
  cal$g1 <- ifelse(cal$day_type == "weekday", "a / b", "a")
  cal$g2 <- ifelse(cal$day_type == "weekday", "c", "b / c")
  cn <- sapd_counts(cal)
  cn$g1 <- cal$g1[match(cn$date, cal$date)]
  cn$g2 <- cal$g2[match(cn$date, cal$date)]
  expect_error(
    audit_strata(sapd_design(cal, cn, strata = c("g1", "g2"))), # nolint: object_usage_linter
    class = "creel_error_strata_label_collision"
  )
})
