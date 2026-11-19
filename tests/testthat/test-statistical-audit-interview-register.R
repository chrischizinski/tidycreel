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
  wk <- weekdays(d) %in% c("Saturday", "Sunday")
  data.frame(
    date = d,
    day_type = ifelse(wk, "weekend", "weekday"),
    # Counts: Mon, Wed + weekends. Interviews: Tue, Wed, Thu + weekends.
    sampled = weekdays(d) %in% c("Monday", "Wednesday", "Saturday", "Sunday"),
    interviewed = weekdays(d) %in% c("Tuesday", "Wednesday", "Thursday", "Saturday", "Sunday")
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
  data.frame(
    date = rep(days$date, each = 3), day_type = rep(days$day_type, each = 3),
    catch = rep(c(0, 2, 5), n), hours = rep(c(1.5, 3, 4), n), status = "complete"
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
  expect_true(any(weekdays(d$interviews$date) == "Tuesday"))
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
