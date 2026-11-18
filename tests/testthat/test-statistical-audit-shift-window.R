# A schedule drawn with shift times (#385) says when each sampled day was
# worked. Counts and interviews relate to that window differently (GH #426):
#
# - A COUNT is expanded by the probability of the shift it was taken in
#   (daily effort = mean count x window / p_period). A count taken outside the
#   drawn shift is expanded as if it had been drawn -- a plausible number with
#   no symptom -- so it is refused.
# - An INTERVIEW only has to come from the same stratum: total catch is
#   effort x rate per stratum, and interviews need not share a day or shift
#   with the counts (Pollock et al. 1997, complemented surveys). An interview
#   outside the drawn shift is a coverage question, so it warns.
#
# Times within 15 minutes of a shift's ends count as inside it.

sw_calendar <- function(start = "13:00", end = "20:00") {
  data.frame(
    date = as.Date("2024-06-03") + 0:3,
    day_type = "weekday",
    period_id = 2L,
    p_period = 0.5,
    shift_start = start,
    shift_end = end
  )
}

sw_counts <- function(times = c("14:00", "17:00")) {
  days <- as.Date("2024-06-03") + 0:3
  data.frame(
    date = rep(days, each = 2),
    day_type = "weekday",
    count_time = rep(times, 4),
    anglers = c(10, 14, 6, 9, 22, 30, 18, 25),
    hours = 7
  )
}

sw_design <- function(cal = sw_calendar()) {
  suppressMessages(creel_design(cal, date = date, strata = day_type))
}

sw_add <- function(counts, cal = sw_calendar(), ...) {
  suppressMessages(add_counts(
    sw_design(cal), counts,
    count_col = anglers, count_time_col = count_time, period_length_col = hours, ...
  ))
}

sw_interviews <- function(hour) {
  t <- as.POSIXct(paste("2024-06-03", c(hour, "16:00")), tz = "UTC")
  data.frame(
    date = as.Date("2024-06-03"), day_type = "weekday",
    catch = c(2, 1), hours = c(2, 1.5), status = "complete",
    start = t - 7200, itime = t
  )
}

sw_add_interviews <- function(design, iv) {
  suppressMessages(add_interviews(
    design, iv, catch = catch, effort = hours, trip_status = status,
    trip_start = start, interview_time = itime
  ))
}

# Only the warning under test reaches the expectation.
sw_only <- function(expr, cls) {
  withCallingHandlers(expr, warning = function(w) {
    if (!inherits(w, cls)) invokeRestart("muffleWarning")
  })
}

test_that("#426: a count timed outside the drawn shift is refused, naming the record and the shift", {
  cn <- sw_counts()
  cn$count_time[3] <- "10:00" # morning count on a day whose worked shift is 13:00-20:00
  err <- expect_error(sw_add(cn), class = "creel_error_count_outside_shift")
  expect_match(conditionMessage(err), "1 count is timed outside", fixed = TRUE)
  expect_match(conditionMessage(err), "2024-06-04 10:00", fixed = TRUE)
  expect_match(conditionMessage(err), "13:00-20:00", fixed = TRUE)
  # Counts inside the shift attach as before.
  expect_s3_class(suppressWarnings(sw_add(sw_counts())), "creel_design")
})

test_that("#426: 15 minutes either side of the shift is inside it; 16 is not", {
  expect_no_error(suppressWarnings(sw_add(sw_counts(c("12:45", "20:15")))))
  expect_error(sw_add(sw_counts(c("12:44", "17:00"))), class = "creel_error_count_outside_shift")
  expect_error(sw_add(sw_counts(c("14:00", "20:16"))), class = "creel_error_count_outside_shift")
})

test_that("#426: allow_invalid = TRUE attaches the counts with a recorded tier-1 warning", {
  cn <- sw_counts()
  cn$count_time[1] <- "08:00"
  expect_warning(
    d <- sw_only(sw_add(cn, allow_invalid = TRUE), "creel_warning_count_outside_shift"),
    class = "creel_warning_count_outside_shift"
  )
  expect_s3_class(d, "creel_design")
  w <- get_warnings(d)
  expect_true("creel_warning_count_outside_shift" %in% w$class)
  expect_identical(w$tier[w$class == "creel_warning_count_outside_shift"][1], 1L)
})

test_that("#426: a count_time_col of labels, not clock times, is not checked", {
  # count_time_col names distinct counts within a day; labels are allowed.
  expect_no_error(suppressWarnings(sw_add(sw_counts(c("first", "second")))))
})

test_that("#426: a calendar without shift times is not checked", {
  cal <- sw_calendar()
  cal$shift_start <- NULL
  cal$shift_end <- NULL
  expect_no_error(suppressWarnings(sw_add(sw_counts(c("03:00", "23:00")), cal = cal)))
})

test_that("#426: an interview outside the drawn shift warns, and is kept", {
  d <- suppressWarnings(sw_add(sw_counts()))
  expect_warning(
    with_iv <- sw_only(sw_add_interviews(d, sw_interviews("09:00")), "creel_warning_interview_outside_shift"),
    class = "creel_warning_interview_outside_shift"
  )
  # A warning, not a filter: the interview still enters the rate.
  expect_identical(nrow(with_iv$interviews), 2L)
  w <- get_warnings(with_iv)
  expect_identical(w$tier[w$class == "creel_warning_interview_outside_shift"][1], 2L)
})

test_that("#426: interviews inside the drawn shift raise no shift warning", {
  d <- suppressWarnings(sw_add(sw_counts()))
  expect_no_warning(sw_only(sw_add_interviews(d, sw_interviews("19:00")), "creel_warning_interview_outside_shift"))
})

test_that("#426: on a night design the window is read across midnight", {
  tz <- "America/Chicago"
  # Every night worked, shift 19:30-00:30 at p = 0.5.
  cal <- data.frame(
    date = as.Date("2024-04-01") + 0:3, day_type = "weekday",
    period_id = 1L, p_period = 0.5, shift_start = "19:30", shift_end = "00:30"
  )
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type, tz = tz, day_start = "12:00"))
  counts <- function(late) {
    data.frame(
      date = rep(as.Date("2024-04-01") + 0:3, each = 2) + rep(c(0L, 1L), 4),
      day_type = "weekday", period_id = 1L,
      time = rep(c("21:30", late), 4), anglers = 1:8, hrs = 5
    )
  }
  add <- function(cn) {
    suppressMessages(add_counts(d, cn, count_col = anglers, count_time_col = time, period_length_col = hrs))
  }
  # 00:15 the next calendar day is inside the night's 19:30-00:30 shift.
  expect_no_error(suppressWarnings(add(counts("00:15"))))
  # 01:30 maps to the same night but after its worked shift ended: a count
  # from the 00:30-06:00 shift labelled as the drawn one.
  expect_error(add(counts("01:30")), class = "creel_error_count_outside_shift")
})
