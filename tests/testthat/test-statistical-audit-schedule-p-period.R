# A schedule that draws shifts (#385) records each sampled day's probability
# and shift window in the calendar. add_counts() must take p from there --
# otherwise a user passing the real shift length without p_period gets 1/p of
# the effort, silently -- and must check the period length against the window,
# because a length already divided by p (the pre-#368 workaround) plus the
# schedule's p doubles every effort and total with no other symptom.

sch_p_calendar <- function(p = 0.5, start = "13:00", end = "20:00") {
  data.frame(
    date = as.Date("2024-06-03") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    sampled = c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE),
    p_period = c(p, p, p, p, p, NA, p, NA),
    shift_start = c(start, start, start, start, start, NA, start, NA),
    shift_end = c(end, end, end, end, end, NA, end, NA)
  )
}

sch_p_counts <- function(hours = 7, days = as.Date("2024-06-03") + c(0, 1, 2, 3, 4, 6)) {
  day_type <- ifelse(format(days, "%d") %in% c("05", "06"), "weekend", "weekday")
  data.frame(
    date = rep(days, each = 2),
    day_type = rep(day_type, each = 2),
    count_time = rep(c("14:00", "17:00"), length(days)),
    anglers = rep(c(10, 14, 6, 9, 22, 30, 18, 25, 12, 8, 27, 21), length.out = 2 * length(days)),
    hours = hours
  )
}

sch_p_add <- function(calendar, counts, ...) {
  d <- suppressMessages(creel_design(calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts( # nolint: object_usage_linter
    d, counts,
    count_col = anglers, count_time_col = count_time, period_length_col = hours, ...
  )))
}

sch_p_effort <- function(d) suppressWarnings(suppressMessages(estimate_effort(d)))$estimates # nolint: object_usage_linter

test_that("#385: p_period is read from the schedule and expands like the explicit argument", {
  cn <- sch_p_counts(7)
  from_schedule <- sch_p_add(sch_p_calendar(), cn)
  plain_cal <- sch_p_calendar()[c("date", "day_type")]
  explicit <- sch_p_add(plain_cal, cn, p_period = 0.5)
  a <- sch_p_effort(from_schedule)
  b <- sch_p_effort(explicit)
  expect_equal(a$estimate, b$estimate, tolerance = 1e-12)
  expect_equal(a$se, b$se, tolerance = 1e-12)
  # Hand value: sum over days of mean count x 7 / 0.5. Without the schedule's
  # p the real length gives half of this.
  expect_equal(a$estimate, sum(tapply(cn$anglers, cn$date, mean) * 7 / 0.5), tolerance = 1e-12)
  expect_equal(a$estimate, 2 * sch_p_effort(sch_p_add(plain_cal, cn))$estimate, tolerance = 1e-12)
  expect_true(isTRUE(attr(from_schedule$p_period, "from_schedule")))
  expect_output(print(from_schedule), "from the schedule")
})

test_that("#385/#426: a length equal to window / p is refused as applying p twice", {
  # The issue's case: a 5 h window at p = 0.5. Length 10 errors; 5 passes.
  cal <- sch_p_calendar(start = "13:00", end = "18:00")
  expect_error(sch_p_add(cal, sch_p_counts(10)), class = "creel_error_p_period_applied_twice")
  expect_error(sch_p_add(cal, sch_p_counts(10)), "2024-06-03")
  expect_no_error(sch_p_add(cal, sch_p_counts(5)))
})

test_that("#385: a length that is neither the window nor window / p is refused", {
  expect_error(sch_p_add(sch_p_calendar(), sch_p_counts(6)), class = "creel_error_period_length_window")
  # Within 0.01 h is accepted: a 7 h 20 min shift typed as 7.33.
  cal <- sch_p_calendar(start = "13:00", end = "20:20")
  expect_no_error(sch_p_add(cal, sch_p_counts(7.33)))
})

test_that("#385: on a day with two worked shifts the length is their total", {
  # Two of three 5 h shifts worked, p = 2/3: daily effort is mean count x 10 / (2/3).
  base <- sch_p_calendar(p = 2 / 3, start = "06:00", end = "11:00")
  second <- base[base$sampled, ]
  second$shift_start <- "16:00"
  second$shift_end <- "21:00"
  cal <- rbind(base, second)
  cal <- cal[order(cal$date), ]
  cn <- sch_p_counts(10)
  d <- sch_p_add(cal, cn)
  expect_equal(
    sch_p_effort(d)$estimate,
    sum(tapply(cn$anglers, cn$date, mean) * 10 / (2 / 3)),
    tolerance = 1e-12
  )
  # One shift's length is not the day's window.
  expect_error(sch_p_add(cal, sch_p_counts(5)), class = "creel_error_period_length_window")
})

test_that("#385: an explicit p_period must agree with the schedule", {
  cn <- sch_p_counts(7)
  expect_error(sch_p_add(sch_p_calendar(), cn, p_period = 0.25), class = "creel_error_p_period_invalid")
  expect_error(sch_p_add(sch_p_calendar(), cn, p_period = 0.25), "disagrees with the schedule")
  expect_equal(
    sch_p_effort(sch_p_add(sch_p_calendar(), cn, p_period = 0.5))$estimate,
    sch_p_effort(sch_p_add(sch_p_calendar(), cn))$estimate,
    tolerance = 1e-12
  )
})

test_that("#385: counts on a day the schedule did not sample are refused, naming the day", {
  # 2024-06-08 is unsampled in the schedule (no shift, p NA): its counts have
  # no known probability. Refused even with p_period passed (user decision).
  cn <- sch_p_counts(7, days = as.Date("2024-06-03") + c(0, 1, 5))
  expect_error(sch_p_add(sch_p_calendar(), cn), class = "creel_error_p_period_invalid")
  expect_error(sch_p_add(sch_p_calendar(), cn), "2024-06-08")
  expect_error(sch_p_add(sch_p_calendar(), cn, p_period = 0.5), "did not sample")
})

test_that("#385: a shift schedule without period_length_col is refused", {
  d <- suppressMessages(creel_design(sch_p_calendar(), date = date, strata = day_type))
  expect_error(
    suppressWarnings(add_counts(d, sch_p_counts(7), count_col = anglers, count_time_col = count_time)),
    class = "creel_error_p_period_invalid"
  )
})

test_that("#385: a shift crossing midnight is refused until #407", {
  # 19:30-00:30 is 5 h, but which date its counts belong to is #407's question.
  cal <- sch_p_calendar(start = "19:30", end = "00:30")
  expect_error(sch_p_add(cal, sch_p_counts(5)), class = "creel_error_period_length_window")
  expect_error(sch_p_add(cal, sch_p_counts(5)), "crosses midnight")
})

test_that("#385: a day with two different probabilities in the schedule is refused", {
  cal <- sch_p_calendar()
  extra <- cal[1, ]
  extra$p_period <- 0.25
  expect_error(sch_p_add(rbind(cal, extra), sch_p_counts(7)), class = "creel_error_p_period_invalid")
})

test_that("#385: a schedule with every p = 1 and no shift times changes nothing", {
  # Every period worked: generate_schedule() writes p_period = 1. Counts on an
  # unsampled day are not this check's business then, and effort is unchanged.
  cal <- sch_p_calendar(p = 1)[c("date", "day_type", "p_period")]
  cn <- sch_p_counts(7, days = as.Date("2024-06-03") + c(0, 1, 2, 3, 5))
  expect_equal(
    sch_p_effort(sch_p_add(cal, cn))$estimate,
    sch_p_effort(sch_p_add(cal[c("date", "day_type")], cn))$estimate,
    tolerance = 1e-12
  )
  expect_null(sch_p_add(cal, cn)$p_period)
})

test_that("#385: generate_schedule() output drives add_counts() end to end", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-06-14", n_periods = 2, sampling_rate = 0.5,
    periods_per_day = 1, include_all = TRUE, seed = 1,
    periods = data.frame(period_id = 1:2, start_time = c("06:00", "13:00"), end_time = c("13:00", "20:00"))
  )
  days <- sched$date[sched$sampled]
  cn <- data.frame(
    date = rep(days, each = 2),
    day_type = rep(sched$day_type[sched$sampled], each = 2),
    count_time = "10:00",
    anglers = seq_len(2 * length(days)),
    hours = 7
  )
  cn$count_time <- rep(c("10:00", "12:00"), length(days))
  d <- sch_p_add(sched, cn)
  expect_equal(
    sch_p_effort(d)$estimate,
    sum(tapply(cn$anglers, cn$date, mean) * 7 / 0.5),
    tolerance = 1e-12
  )
  cn$hours <- 14
  expect_error(sch_p_add(sched, cn), class = "creel_error_p_period_applied_twice")
})
