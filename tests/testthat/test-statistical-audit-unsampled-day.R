# GH #454: on a day design whose calendar records which days were worked, an
# interview dated on a day the schedule did not draw was accepted. It joined
# its stratum and entered the rate, and every total built on it, with no
# message: measured before the fix, 12 interviews on 4 unsampled days moved a
# catch rate from 0.80 to 1.36 (their catch was set high to stand for a
# tournament day; the size is constructed, the silent inclusion is not).
# Counts on such days and interviews on night designs were already refused.
# Interviews are now refused too, for the user to correct or drop.

ud_q <- function(x) suppressWarnings(suppressMessages(x))

ud_calendar <- function() {
  generate_schedule("2024-06-01", "2024-06-30",
    n_periods = 1, sampling_rate = c(weekday = 0.4, weekend = 0.6),
    seed = 3, include_all = TRUE
  )
}

ud_interviews <- function(cal, days) {
  data.frame(
    date = rep(days, each = 3),
    day_type = cal$day_type[match(rep(days, each = 3), cal$date)],
    hours = rep(c(1.5, 2, 3), length(days)),
    catch = rep(c(0, 2, 4), length(days)),
    trip_status = "complete"
  )
}

ud_attach <- function(cal, iv) {
  worked <- cal$date[!is.na(cal$p_period)]
  cnt <- data.frame(
    date = worked, day_type = cal$day_type[match(worked, cal$date)],
    period_id = 1L, count = 20, hrs = 8
  )
  d <- ud_q(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- ud_q(add_counts(d, cnt, count_col = count, period_length_col = hrs)) # nolint: object_usage_linter
  ud_q(add_interviews(d, iv,
    catch = catch, effort = hours, trip_status = trip_status, n_anglers = 1 # nolint: object_usage_linter
  ))
}

test_that("#454: an interview on a day the schedule did not sample is refused", {
  cal <- ud_calendar()
  worked <- cal$date[!is.na(cal$p_period)]
  off <- setdiff(cal$date, worked)[1:4]
  iv <- rbind(ud_interviews(cal, worked), ud_interviews(cal, off))
  err <- expect_error(ud_attach(cal, iv), class = "creel_error_interview_unsampled_day")
  # The count of interviews and the days are named, so the user can find them.
  expect_match(conditionMessage(err), "12 interviews", fixed = TRUE)
  expect_match(conditionMessage(err), format(min(off)), fixed = TRUE)
})

test_that("#454: interviews on worked days only are attached and estimated as before", {
  cal <- ud_calendar()
  worked <- cal$date[!is.na(cal$p_period)]
  d <- ud_attach(cal, ud_interviews(cal, worked))
  expect_equal(nrow(d$interviews), 3L * length(worked))
  expect_true(is.finite(ud_q(estimate_catch_rate(d))$estimates$estimate))
})

test_that("#454: a calendar that records no worked days is not checked", {
  # Without p_period, period_id or sampled the calendar marks no day as
  # unsampled, so any calendar day is accepted, as before.
  cal <- ud_calendar()
  plain <- cal[!duplicated(cal$date), c("date", "day_type")]
  iv <- ud_interviews(plain, plain$date[1:6])
  d <- ud_q(creel_design(plain, date = date, strata = day_type)) # nolint: object_usage_linter
  expect_no_error(ud_q(add_interviews(d, iv,
    catch = catch, effort = hours, trip_status = trip_status, n_anglers = 1 # nolint: object_usage_linter
  )))
})

test_that("#454: a sampled = FALSE day is unsampled too", {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:5,
    day_type = rep(c("weekday", "weekend"), each = 3),
    sampled = c(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE)
  )
  iv <- ud_interviews(cal, cal$date[c(1, 3)])
  d <- ud_q(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  err <- expect_error(
    ud_q(add_interviews(d, iv,
      catch = catch, effort = hours, trip_status = trip_status, n_anglers = 1 # nolint: object_usage_linter
    )),
    class = "creel_error_interview_unsampled_day"
  )
  # Interviews and days are counted separately: three interviews, one day.
  expect_match(conditionMessage(err), "3 interviews are dated on 1 day the", fixed = TRUE)
})
