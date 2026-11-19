# Some surveys draw count days and interview days separately (GH #628). Su &
# Liu's Great Lakes aerial-access survey flew two random weekdays a week and
# interviewed on three, as independent draws, so neither set of days contains
# the other.
#
# That is sound because total catch is estimated per stratum as effort x
# catch rate (Pollock et al. 1994, complemented surveys), and the catch-rate
# stage uses no day counts: its interviews are equal-probability draws within
# the stratum. What it needs is a register of the days interviews could come
# from, so a misdated interview is still refused (GH #454) -- now against the
# interview days rather than the count days.

ir_calendar <- function() {
  d <- as.Date("2024-06-03") + 0:13 # two weeks, Monday start
  wday <- as.POSIXlt(d)$wday # 0 = Sunday; locale-free, unlike weekdays()
  data.frame(
    date = d,
    day_type = ifelse(wday %in% c(0, 6), "weekend", "weekday"),
    # Counts: Mon, Wed + weekends. Interviews: Tue, Wed, Thu + weekends.
    sampled = wday %in% c(1, 3, 6, 0),
    interviewed = wday %in% c(2, 3, 4, 6, 0)
  )
}

ir_counts <- function(cal = ir_calendar()) {
  days <- cal[cal$sampled, ]
  data.frame(
    date = days$date, day_type = days$day_type,
    anglers = seq(10, by = 3, length.out = nrow(days)), hours = 12
  )
}

ir_interviews <- function(cal = ir_calendar()) {
  days <- cal[cal$interviewed, ]
  n <- nrow(days)
  # Interview-only days (no count) fish better, so a rate that dropped them
  # would differ from one that kept them.
  only <- rep(!days$sampled, each = 3)
  data.frame(
    date = rep(days$date, each = 3), day_type = rep(days$day_type, each = 3),
    catch = rep(c(0, 2, 5), n) + ifelse(only, 4, 0), hours = rep(c(1.5, 3, 4), n), status = "complete"
  )
}

ir_design <- function(cal = ir_calendar(), ...) {
  suppressMessages(creel_design(cal, date = date, strata = day_type, ...))
}

ir_add_counts <- function(d, cn = ir_counts()) {
  suppressWarnings(suppressMessages(add_counts(d, cn, count_col = anglers, period_length_col = hours)))
}

ir_add_interviews <- function(d, iv = ir_interviews()) {
  suppressWarnings(suppressMessages(add_interviews(
    d, iv, catch = catch, effort = hours, trip_status = status, n_anglers = 1
  )))
}

test_that("#628: without a register, an interview on a day with no count is still refused (#454)", {
  d <- ir_add_counts(ir_design())
  expect_error(ir_add_interviews(d), class = "creel_error_record_unworked_day")
})

test_that("#628: with interview_sampled, interviews on interview-only days are accepted", {
  d <- ir_add_interviews(ir_add_counts(ir_design(interview_sampled = interviewed)))
  expect_identical(nrow(d$interviews), nrow(ir_interviews()))
  # Tuesdays and Thursdays have interviews but no count.
  expect_true(any(as.POSIXlt(d$interviews$date)$wday == 2))
})

test_that("#628: total catch is each stratum's effort x its rate from ALL its interviews", {
  d <- ir_add_interviews(ir_add_counts(ir_design(interview_sampled = interviewed)))
  eff <- suppressWarnings(estimate_effort(d, by = day_type))$estimates
  iv <- ir_interviews()
  # Ratio of means per stratum over every interview, interview-only days included.
  rate <- tapply(iv$catch, iv$day_type, sum) / tapply(iv$hours, iv$day_type, sum)
  oracle <- sum(eff$estimate * rate[eff$day_type])
  total <- suppressWarnings(estimate_total_catch(d))$estimates$estimate
  expect_equal(total, oracle, tolerance = 1e-10)
  # The interview-only days move the answer: dropping them gives another total.
  kept <- iv[iv$date %in% ir_counts()$date, ]
  dropped <- sum(eff$estimate * (tapply(kept$catch, kept$day_type, sum) /
                                   tapply(kept$hours, kept$day_type, sum))[eff$day_type])
  expect_gt(abs(total - dropped), 1)
})

test_that("#628: the interview register decides alone -- a count day not marked for interviews refuses them", {
  cal <- ir_calendar()
  d <- ir_add_counts(ir_design(cal, interview_sampled = interviewed))
  iv <- ir_interviews()
  iv$date[1] <- as.Date("2024-06-03") # a Monday: counted, not an interview day
  err <- expect_error(ir_add_interviews(d, iv), class = "creel_error_interview_register")
  expect_s3_class(err, "creel_error_record_unworked_day")
  expect_match(conditionMessage(err), "2024-06-03", fixed = TRUE)
})

test_that("#628: the interview register does not change how counts are read", {
  # Effort comes from the counts alone; the register only routes interviews.
  cal <- ir_calendar()
  with_reg <- ir_add_counts(ir_design(cal, interview_sampled = interviewed))
  without <- ir_add_counts(ir_design(cal))
  expect_equal(
    suppressWarnings(estimate_effort(with_reg, by = day_type))$estimates,
    suppressWarnings(estimate_effort(without, by = day_type))$estimates
  )
})

test_that("#628: interview_sampled must be a logical calendar column marking some day", {
  cal <- ir_calendar()
  cal$flag <- ifelse(cal$interviewed, "y", "n")
  expect_error(ir_design(cal, interview_sampled = flag), class = "creel_error_interview_register")
  cal$none <- FALSE
  expect_error(ir_design(cal, interview_sampled = none), class = "creel_error_interview_register")
  cal$gap <- cal$interviewed
  cal$gap[2] <- NA
  expect_error(ir_design(cal, interview_sampled = gap), class = "creel_error_interview_register")
})

test_that("#628: interview_sampled is refused on bus-route and ice designs", {
  # Their interviews are the effort data: the interview days are the sampled days.
  cal <- ir_calendar()
  expect_error(
    suppressMessages(creel_design(cal, date = date, strata = day_type, survey_type = "ice",
                                  effort_type = "time_on_ice", interview_sampled = interviewed)),
    class = "creel_error_interview_register"
  )
})

test_that("#628: a declared interview draw silences the #426 interview-shift warning", {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:1, day_type = "weekday",
    period_id = 2L, p_period = 0.5, shift_start = "13:00", shift_end = "20:00",
    interviewed = TRUE
  )
  counts <- data.frame(date = rep(cal$date, each = 2), day_type = "weekday",
                       time = c("14:00", "17:00"), anglers = 1:4, hours = 7)
  t <- as.POSIXct(c("2024-06-03 09:00", "2024-06-04 10:00"), tz = "UTC")
  iv <- data.frame(date = cal$date, day_type = "weekday", catch = c(1, 2), hours = 2,
                   status = "complete", start = t - 7200, itime = t)
  add <- function(design) {
    d <- suppressWarnings(suppressMessages(add_counts(design, counts, count_col = anglers,
                                                      count_time_col = time, period_length_col = hours)))
    withCallingHandlers(
      suppressMessages(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status,
                                      trip_start = start, interview_time = itime, n_anglers = 1)),
      warning = function(w) if (!inherits(w, "creel_warning_interview_outside_shift")) invokeRestart("muffleWarning")
    )
  }
  expect_warning(add(ir_design(cal)), class = "creel_warning_interview_outside_shift")
  expect_no_warning(add(ir_design(cal, interview_sampled = interviewed)))
})

test_that("#628: a saved design keeps its interview register", {
  d <- ir_add_interviews(ir_add_counts(ir_design(interview_sampled = interviewed)))
  p <- tempfile(fileext = ".zip")
  on.exit(unlink(p))
  suppressMessages(write_design(d, p))
  r <- suppressWarnings(suppressMessages(read_design(p)))
  expect_identical(r$interview_sampled_col, "interviewed")
  expect_equal(
    suppressWarnings(estimate_total_catch(r))$estimates$estimate,
    suppressWarnings(estimate_total_catch(d))$estimates$estimate
  )
})

test_that("#628 review: a column that marks count days cannot be the interview register", {
  # calendar_worked_rows() reads `sampled` as the count days; reusing it would
  # make one flag mean both.
  expect_error(ir_design(interview_sampled = sampled), class = "creel_error_interview_register")
})

test_that("#628 review: a refused interview on an unmarked day is not said to be weighted", {
  d <- ir_add_counts(ir_design(interview_sampled = interviewed))
  err <- expect_error(
    tidycreel:::check_interview_register(
      data.frame(date = as.Date("2024-06-03")), d, "date", "refused interview"
    ),
    class = "creel_error_interview_register"
  )
  expect_no_match(conditionMessage(err), "cannot be weighted")
})

test_that("#628 review: on a calendar with a row per section, the register is read per section", {
  # North interviewed on the day, South not: a South interview that day was
  # not scheduled, even though the date has a TRUE row.
  d <- ir_design()
  d$calendar <- data.frame(
    date = rep(as.Date("2024-06-04"), 2), day_type = "weekday",
    section = c("North", "South"), interviewed = c(TRUE, FALSE)
  )
  d$section_col <- "section"
  d$interview_sampled_col <- "interviewed"
  rec <- data.frame(date = as.Date("2024-06-04"), section = c("North", "South"))
  expect_no_error(tidycreel:::check_interview_register(rec[1, ], d, "date", "interview"))
  expect_error(
    tidycreel:::check_interview_register(rec[2, ], d, "date", "interview"),
    class = "creel_error_interview_register"
  )
})
