# Night creels, part 4b (GH #407): counts and interviews are mapped to the
# night they belong to. Records carry their CALENDAR date and clock time; a
# record timed before day_start belongs to the night that began the date
# before. Every estimator keys a day by the date column, so a record left on
# its calendar date splits a night into two PSUs and takes the next date's
# stratum -- with no error, which is what these tests pin.

n4b_tz <- "America/Chicago"

# A McConaughy-style season: two shifts a night, one drawn at p = 0.5;
# 19:30-00:30 and 00:30-06:00; Friday and Saturday nights are the weekend.
n4b_sched <- function() {
  generate_schedule("2024-04-01", "2024-04-14",
    n_periods = 2, sampling_rate = 0.5, periods_per_day = 1,
    day_start = "12:00", weekend_days = c("Friday", "Saturday"), include_all = TRUE,
    periods = data.frame(period_id = 1:2, start_time = c("19:30", "00:30"), end_time = c("00:30", "06:00")),
    seed = 1
  )
}

# Two counts per worked shift, each dated by its CALENDAR day; the stratum is
# the night's (as a crew records it).
n4b_counts <- function(s = n4b_sched()) {
  w <- s[!is.na(s$p_period), ]
  rows <- lapply(seq_len(nrow(w)), function(i) {
    r <- w[i, ]
    if (r$period_id == 1L) {
      t <- c("21:30", "00:15")
      dt <- r$date + c(0L, 1L)
      hrs <- 5
    } else {
      t <- c("01:30", "04:30")
      dt <- r$date + 1L
      hrs <- 5.5
    }
    data.frame(date = dt, day_type = r$day_type, period_id = r$period_id, time = t,
               anglers = c(4, 2) + i, hrs = hrs)
  })
  do.call(rbind, rows)
}

n4b_design <- function(s = n4b_sched(), ...) creel_design(s, date = date, strata = day_type, tz = n4b_tz, ...)

test_that("#407: night counts give the estimate of the same counts dated by their night", {
  s <- n4b_sched()
  cnt <- n4b_counts(s)
  night <- suppressWarnings(add_counts(n4b_design(s), cnt, count_col = anglers,
                                       count_time_col = time, period_length_col = hrs))

  # Oracle: the same counts re-dated by hand to their night, on a day design
  # (no day_start, no shift clock times; p_period still drives expansion).
  oracle_cnt <- cnt
  oracle_cnt$date <- oracle_cnt$date - as.integer(oracle_cnt$time < "12:00")
  day_cal <- as.data.frame(s)[c("date", "day_type", "period_id", "p_period")]
  oracle <- suppressWarnings(add_counts(creel_design(day_cal, date = date, strata = day_type),
    oracle_cnt, count_col = anglers, count_time_col = time, period_length_col = hrs))

  e_night <- suppressWarnings(estimate_effort(night))$estimates
  e_oracle <- suppressWarnings(estimate_effort(oracle))$estimates
  expect_equal(e_night$estimate, e_oracle$estimate)
  expect_equal(e_night$se, e_oracle$se)
  expect_equal(e_night$se_within, e_oracle$se_within)
  # One PSU per sampled night, not one per calendar date touched.
  expect_equal(nrow(night$counts), sum(!is.na(s$p_period)))
  # The calendar date is kept beside the counts.
  expect_setequal(night$count_calendar_dates$calendar_date, cnt$date)
})

test_that("#407: an after-midnight count labelled with its calendar date's stratum is refused", {
  s <- n4b_sched()
  cnt <- n4b_counts(s)
  # Thursday night 2024-04-04 (weekday); its 00:15 count falls on Friday 04-05,
  # which as a NIGHT is weekend. Labelled by its calendar date, it disagrees
  # with the night it belongs to.
  i <- which(cnt$date == as.Date("2024-04-05") & cnt$time == "00:15")
  expect_length(i, 1L)
  cnt$day_type[i] <- "weekend"
  expect_error(
    suppressWarnings(add_counts(n4b_design(s), cnt, count_col = anglers, count_time_col = time,
                                period_length_col = hrs)),
    class = "creel_error_record_strata_mismatch"
  )
})

test_that("#407: a record already dated by its night is refused, not moved a second day", {
  s <- n4b_sched()
  cnt <- n4b_counts(s)
  # 2022-style: the after-midnight count of the night of 04-04 is dated 04-04.
  # Mapped, it moves to 04-03, a night the schedule did not sample.
  i <- which(cnt$date == as.Date("2024-04-05") & cnt$time == "00:15")
  cnt$date[i] <- as.Date("2024-04-04")
  expect_error(
    suppressWarnings(add_counts(n4b_design(s), cnt, count_col = anglers, count_time_col = time,
                                period_length_col = hrs)),
    "did not sample"
  )

  # Where the night before WAS sampled, but on its other shift, the shift
  # check catches it: 04-01 worked period 2; a period-1 record dated 04-02 at
  # 00:15 maps to 04-01 period 1, which was not worked.
  cnt <- n4b_counts(s)
  extra <- data.frame(date = as.Date("2024-04-02"), day_type = "weekday", period_id = 1L,
                      time = "00:15", anglers = 3, hrs = 5.5)
  cnt <- rbind(cnt, extra)
  expect_error(
    suppressWarnings(add_counts(n4b_design(s), cnt, count_col = anglers, count_time_col = time,
                                period_length_col = hrs)),
    class = "creel_error_night_record_shift_not_worked"
  )
})

test_that("#407: night counts need a readable clock time", {
  s <- n4b_sched()
  cnt <- n4b_counts(s)
  expect_error(add_counts(n4b_design(s), cnt, count_col = anglers, period_length_col = hrs),
               class = "creel_error_night_time_required")
  cnt$time[1] <- "1:30 am"
  expect_error(add_counts(n4b_design(s), cnt, count_col = anglers, count_time_col = time,
                          period_length_col = hrs),
               class = "creel_error_night_time_unparseable")
})

test_that("#407: POSIXct count times must agree with the record date and the design's zone", {
  s <- n4b_sched()
  cnt <- n4b_counts(s)
  cnt$time <- as.POSIXct(paste(cnt$date, cnt$time), tz = n4b_tz)
  ok <- suppressWarnings(add_counts(n4b_design(s), cnt, count_col = anglers, count_time_col = time,
                                    period_length_col = hrs))
  expect_equal(nrow(ok$counts), sum(!is.na(s$p_period)))

  wrong_zone <- cnt
  attr(wrong_zone$time, "tzone") <- "UTC"
  expect_error(add_counts(n4b_design(s), wrong_zone, count_col = anglers, count_time_col = time,
                          period_length_col = hrs),
               class = "creel_error_night_tz_mismatch")

  # No zone at all would be read in the computer's zone (review): refused.
  no_zone <- cnt
  attr(no_zone$time, "tzone") <- ""
  expect_error(add_counts(n4b_design(s), no_zone, count_col = anglers, count_time_col = time,
                          period_length_col = hrs),
               class = "creel_error_night_tz_mismatch")

  off_date <- cnt
  off_date$date[1] <- off_date$date[1] + 1L
  expect_error(add_counts(n4b_design(s), off_date, count_col = anglers, count_time_col = time,
                          period_length_col = hrs),
               class = "creel_error_night_time_date_mismatch")
})

test_that("#407: night interviews are mapped by interview time and keep their calendar date", {
  s <- n4b_sched()
  d <- suppressWarnings(add_counts(n4b_design(s), n4b_counts(s), count_col = anglers,
                                   count_time_col = time, period_length_col = hrs))
  # Night of Thursday 04-04 (period 1): one interview before and one after midnight.
  iv <- data.frame(
    date = as.Date(c("2024-04-04", "2024-04-05")),
    day_type = "weekday",
    catch = c(2, 1), hours = c(2, 3), status = "complete",
    start = as.POSIXct(c("2024-04-04 20:00", "2024-04-04 22:30"), tz = n4b_tz),
    itime = as.POSIXct(c("2024-04-04 22:00", "2024-04-05 01:30"), tz = n4b_tz)
  )
  di <- suppressWarnings(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status,
                                        trip_start = start, interview_time = itime))
  expect_equal(nrow(di$interviews), 2L)
  expect_true(all(di$interviews$date == as.Date("2024-04-04")))
  expect_equal(di$interviews$calendar_date, iv$date)

  # B1: without a clock time an interview cannot be placed: refused.
  expect_error(
    add_interviews(d, iv, catch = catch, effort = hours, trip_status = status, trip_duration = hours),
    class = "creel_error_night_time_required"
  )
  # An interview whose mapped night was not sampled is refused (counts already were).
  iv2 <- iv
  iv2$date <- as.Date(c("2024-04-03", "2024-04-04"))
  iv2$start <- as.POSIXct(c("2024-04-03 20:00", "2024-04-03 22:30"), tz = n4b_tz)
  iv2$itime <- as.POSIXct(c("2024-04-03 22:00", "2024-04-04 01:30"), tz = n4b_tz)
  expect_error(
    suppressWarnings(add_interviews(d, iv2, catch = catch, effort = hours, trip_status = status,
                                    trip_start = start, interview_time = itime)),
    class = "creel_error_night_record_unsampled"
  )
})

test_that("#407: the time zone comes from the argument, then the option, never the computer", {
  s <- n4b_sched()
  withr::local_options(tidycreel.tz = NULL)
  expect_error(creel_design(s, date = date, strata = day_type), class = "creel_error_night_tz_required")
  withr::local_options(tidycreel.tz = "America/Denver")
  expect_identical(creel_design(s, date = date, strata = day_type)$night$tz, "America/Denver")
  expect_identical(creel_design(s, date = date, strata = day_type, tz = n4b_tz)$night$tz, n4b_tz)
  expect_error(creel_design(s, date = date, strata = day_type, tz = "Central"),
               class = "creel_error_night_tz_required")
  # A day design needs no zone.
  day <- generate_schedule("2024-06-03", "2024-06-30", n_periods = 1, sampling_rate = 0.5, seed = 1)
  withr::local_options(tidycreel.tz = NULL)
  expect_null(suppressWarnings(creel_design(day, date = date, strata = day_type))$night)
})

test_that("#407: day_start can be declared on a hand-built calendar; two sources must agree", {
  cal <- data.frame(date = as.Date("2024-04-01") + 0:6, day_type = "weekday",
                    shift_start = "19:30", shift_end = "06:00")
  d <- creel_design(cal, date = date, strata = day_type, day_start = "12:00", tz = n4b_tz)
  expect_identical(d$night$day_start, "12:00")
  s <- n4b_sched()
  expect_error(creel_design(s, date = date, strata = day_type, day_start = "15:00", tz = n4b_tz),
               class = "creel_error_day_start_conflict")
})

test_that("#407: night_date = 'end' and non-roving night designs are refused (A1)", {
  s <- n4b_sched()
  expect_error(creel_design(s, date = date, strata = day_type, tz = n4b_tz, night_date = "end"),
               class = "creel_error_night_date_unsupported")
  expect_error(creel_design(s, date = date, strata = day_type, tz = n4b_tz, night_date = "noon"))
  expect_error(creel_design(s, date = date, strata = day_type, tz = n4b_tz, survey_type = "camera",
                            camera_mode = "counter"),
               class = "creel_error_night_design_unsupported")
})

test_that("#407: a night's shift window is its real elapsed length across a DST change", {
  # Night of Sat 2024-11-02: clocks fall back at 02:00, so 19:30-06:00 is 10.5 h
  # on the clock and 11.5 h of real time.
  cal <- data.frame(date = as.Date(c("2024-11-01", "2024-11-02")), day_type = "weekend",
                    period_id = 1L, p_period = 1, shift_start = "19:30", shift_end = "06:00")
  d <- creel_design(cal, date = date, strata = day_type, day_start = "12:00", tz = n4b_tz)
  cnt <- data.frame(date = as.Date(c("2024-11-01", "2024-11-02", "2024-11-02", "2024-11-03")),
                    day_type = "weekend", time = c("22:00", "03:00", "22:00", "03:00"),
                    anglers = c(4, 2, 5, 3),
                    # Night of 11-01: 10.5 h. Night of 11-02 (DST ends): 11.5 h.
                    hrs = c(10.5, 10.5, 11.5, 11.5))
  ok <- suppressWarnings(add_counts(d, cnt, count_col = anglers, count_time_col = time,
                                    period_length_col = hrs))
  expect_equal(nrow(ok$counts), 2L)
  # The clock length is refused on the DST night: it would understate effort by 1 h in 11.5.
  clock <- cnt
  clock$hrs[clock$hrs == 11.5] <- 10.5
  expect_error(suppressWarnings(add_counts(d, clock, count_col = anglers, count_time_col = time,
                                           period_length_col = hrs)),
               class = "creel_error_period_length_window")
})

test_that("#407: a calendar shift that leaves its survey day is refused on a night design", {
  cal <- data.frame(date = as.Date("2024-04-01") + 0:1, day_type = "weekday",
                    period_id = 1L, p_period = 1, shift_start = "05:00", shift_end = "14:00")
  d <- creel_design(cal, date = date, strata = day_type, day_start = "12:00", tz = n4b_tz)
  cnt <- data.frame(date = as.Date("2024-04-02") + 0:1, day_type = "weekday",
                    time = "06:00", anglers = 3, hrs = 9)
  expect_error(add_counts(d, cnt, count_col = anglers, count_time_col = time, period_length_col = hrs),
               "does not fit inside one survey day")
})

test_that("#407: a DST-ambiguous shift bound with shift_hours NA is refused, not crashed on", {
  # 01:30 on 2024-11-03 happens twice in Chicago. The row has a shift_hours
  # column but no value for it (review): the clock times must decide, and
  # cannot.
  cal <- data.frame(date = as.Date(c("2024-11-01", "2024-11-02")), day_type = "weekend",
                    period_id = 1L, p_period = 1, shift_start = "19:30",
                    shift_end = c("06:00", "01:30"), shift_hours = c(10.5, NA))
  d <- creel_design(cal, date = date, strata = day_type, day_start = "12:00", tz = n4b_tz)
  cnt <- data.frame(date = as.Date(c("2024-11-01", "2024-11-02")), day_type = "weekend",
                    time = "22:00", anglers = c(4, 5), hrs = c(10.5, 7))
  expect_error(add_counts(d, cnt, count_col = anglers, count_time_col = time, period_length_col = hrs),
               class = "creel_error_period_length_window")
})

test_that("#407: a night interview's time places it without forcing a clock duration", {
  # Field crews record effort as interview minus start unless the angler
  # reports a break; that recorded value is the duration. On a night design
  # the interview time is required to place the interview, so it must be
  # accepted without trip_start and beside trip_duration, and the recorded
  # duration must not be replaced by the clock span.
  s <- n4b_sched()
  d <- suppressWarnings(add_counts(n4b_design(s), n4b_counts(s), count_col = anglers,
                                   count_time_col = time, period_length_col = hrs))
  iv <- data.frame(
    date = as.Date(c("2024-04-04", "2024-04-05")), day_type = "weekday",
    catch = c(2, 1), hours = c(2, 1.5), status = "complete",
    # Started 22:30, interviewed 01:30: a 3 h span, but 1.5 h fishing (a break).
    itime = as.POSIXct(c("2024-04-04 22:00", "2024-04-05 01:30"), tz = n4b_tz)
  )
  alone <- suppressWarnings(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status,
                                           interview_time = itime))
  expect_true(all(alone$interviews$date == as.Date("2024-04-04")))
  with_dur <- suppressWarnings(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status,
                                              trip_duration = hours, interview_time = itime))
  expect_equal(with_dur$interviews[[with_dur$trip_duration_col]], c(2, 1.5))
  # trip_start beside trip_duration clashes; the message must not tell a night
  # user to drop interview_time, which the design requires (review).
  iv$start <- iv$itime - 3600
  err <- tryCatch(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status,
                                 trip_duration = hours, trip_start = start, interview_time = itime),
                  error = function(e) conditionMessage(e))
  expect_match(err, "trip_duration or trip_start, not both")
  expect_no_match(err, "trip_start/interview_time")
  # Day designs keep the old rule: an interview time alone has no use there.
  day <- suppressWarnings(creel_design(data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "weekday"),
                                       date = date, strata = day_type))
  day <- suppressWarnings(add_counts(day, data.frame(date = as.Date("2024-06-03") + 0:3,
                                                     day_type = "weekday", anglers = 1:4),
                                     count_col = anglers))
  div <- data.frame(date = as.Date("2024-06-03"), day_type = "weekday", catch = 1, hours = 2,
                    status = "complete", itime = as.POSIXct("2024-06-03 10:00", tz = n4b_tz))
  expect_error(add_interviews(day, div, catch = catch, effort = hours, trip_status = status,
                              interview_time = itime), "requires trip_start")
})
