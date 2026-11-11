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

# GH #630: "which days were worked" had two sources. A bus-route or ice design
# names its register (`creel_design(sampled = )`) and #591 checks interviews
# against it; the #454 check read only the literal p_period / period_id /
# sampled columns. A calendar whose literal `sampled` column means something
# else then refused interviews on days the register says were worked. The
# register now decides alone when it is named, and both refusals share one
# class to catch.

ud_bus <- function(cal, iv_days, register = "worked") {
  frame <- data.frame(site = "S1", circuit = "C1", p_site = 1, p_period = 0.5)
  iv <- data.frame(
    date = iv_days, day_type = cal$day_type[match(iv_days, cal$date)],
    site = "S1", circuit = "C1", hours = 2, catch = 1L, trip_status = "complete",
    n_counted = 1L, n_interviewed = 1L
  )
  d <- ud_q(creel_design(cal, # nolint: object_usage_linter
    date = date, strata = day_type, survey_type = "bus_route",
    sampling_frame = frame, site = site, circuit = circuit,
    p_site = p_site, p_period = p_period, sampled = !!rlang::sym(register)
  ))
  ud_q(add_interviews(d, iv, # nolint: object_usage_linter
    catch = catch, effort = hours, trip_status = trip_status, n_anglers = 1,
    n_counted = n_counted, n_interviewed = n_interviewed
  ))
}

ud_bus_calendar <- function() {
  dates <- as.Date("2024-06-01") + 0:13
  cal <- data.frame(
    date = dates,
    day_type = ifelse(format(dates, "%u") %in% c("6", "7"), "weekend", "weekday")
  )
  cal$worked <- seq_along(dates) %% 2 == 1
  cal
}

test_that("#630: a named register decides alone, over an unrelated literal `sampled` column", {
  cal <- ud_bus_calendar()
  cal$sampled <- FALSE # some other flag; the register is `worked`
  worked_days <- cal$date[cal$worked]
  d <- ud_bus(cal, worked_days)
  expect_equal(nrow(d$interviews), length(worked_days))
})

test_that("#630: the same unworked day is refused under one class, however the calendar says so", {
  cal <- ud_bus_calendar()
  off <- cal$date[!cal$worked][1]
  on <- cal$date[cal$worked][1:2]
  # Named register (bus-route, #591).
  expect_error(ud_bus(cal, c(on, off)), class = "creel_error_record_unworked_day")
  # Literal `sampled` column on a day design (#454).
  cal2 <- cal
  cal2$sampled <- cal2$worked
  d <- ud_q(creel_design(cal2, date = date, strata = day_type)) # nolint: object_usage_linter
  iv <- ud_interviews(cal2, c(on, off))
  expect_error(
    ud_q(add_interviews(d, iv, # nolint: object_usage_linter
      catch = catch, effort = hours, trip_status = trip_status, n_anglers = 1
    )),
    class = "creel_error_record_unworked_day"
  )
})

# GH #630 (part 3): refused interviews, and those set aside by
# missing_trip_status = "exclude", skipped the worked-day check. They never
# enter a rate, but they are counted in the refusal and exclusion tables, so a
# row on a day the schedule never drew was counted there with no message.

ud_attach_extra <- function(cal, iv, ...) {
  worked <- cal$date[!is.na(cal$p_period)]
  cnt <- data.frame(
    date = worked, day_type = cal$day_type[match(worked, cal$date)],
    period_id = 1L, count = 20, hrs = 8
  )
  d <- ud_q(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- ud_q(add_counts(d, cnt, count_col = count, period_length_col = hrs)) # nolint: object_usage_linter
  ud_q(add_interviews(d, iv,
    catch = catch, effort = hours, trip_status = trip_status, n_anglers = 1, ... # nolint: object_usage_linter
  ))
}

test_that("#630: a refused interview on an unsampled day is refused too", {
  cal <- ud_calendar()
  worked <- cal$date[!is.na(cal$p_period)]
  off <- setdiff(cal$date, worked)[1]
  iv <- rbind(ud_interviews(cal, worked), ud_interviews(cal, off)[1, ])
  iv$refused <- c(rep(FALSE, nrow(iv) - 1L), TRUE)
  err <- expect_error(
    ud_attach_extra(cal, iv, refused = refused), # nolint: object_usage_linter
    class = "creel_error_record_unworked_day"
  )
  expect_match(conditionMessage(err), format(off), fixed = TRUE)
  # Named as a refusal, and not told it "cannot be weighted": it never is.
  expect_match(conditionMessage(err), "1 refused interview is dated", fixed = TRUE)
  expect_no_match(conditionMessage(err), "weighted", fixed = TRUE)
  # The same refused row on a worked day is accepted and counted as a refusal.
  iv_ok <- iv
  iv_ok$date[nrow(iv_ok)] <- worked[1]
  iv_ok$day_type[nrow(iv_ok)] <- cal$day_type[match(worked[1], cal$date)]
  expect_no_error(ud_attach_extra(cal, iv_ok, refused = refused)) # nolint: object_usage_linter
})

test_that("#630: an excluded no-trip-status interview on an unsampled day is refused too", {
  cal <- ud_calendar()
  worked <- cal$date[!is.na(cal$p_period)]
  off <- setdiff(cal$date, worked)[1]
  extra <- ud_interviews(cal, off)[1, ]
  extra$trip_status <- NA
  iv <- rbind(ud_interviews(cal, worked), extra)
  expect_error(
    ud_attach_extra(cal, iv, missing_trip_status = "exclude"),
    class = "creel_error_record_unworked_day"
  )
  iv$date[nrow(iv)] <- worked[1]
  iv$day_type[nrow(iv)] <- cal$day_type[match(worked[1], cal$date)]
  expect_no_error(ud_attach_extra(cal, iv, missing_trip_status = "exclude"))
})
