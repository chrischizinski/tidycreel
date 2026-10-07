# add_interviews() joined interviews to the calendar on the date alone (plus any
# strata the interviews carried). A calendar with k rows per date -- a schedule
# with several shifts a day used as the calendar, which #385 relies on for
# p_period -- matched every interview k times, and the copies were stored and
# estimated as independent interviews (GH #447). Measured before the fix, with
# 15 interviews on a two-shift calendar: 30 stored, CPUE unchanged, SE 0.1271
# -> 0.0865, n 15 -> 30, and a stratum with 8 complete trips got past the
# 10-trip guard. Nothing warned. Interviews are now joined to the day.

icr_data <- function() {
  data(example_calendar, package = "tidycreel", envir = environment())
  data(example_counts, package = "tidycreel", envir = environment())
  data(example_interviews, package = "tidycreel", envir = environment())
  cal <- example_calendar # nolint: object_usage_linter
  cal$week <- paste0("w", format(cal$date, "%U"))
  # The same days, each split into two shifts: everything that describes the
  # day is repeated, and the shift's own columns differ between the two rows.
  cal2 <- rbind(
    transform(cal, period_id = 1L, shift = "early"),
    transform(cal, period_id = 2L, shift = "late")
  )
  cal2 <- cal2[order(cal2$date, cal2$period_id), ]
  list(cal = cal, cal2 = cal2, cn = example_counts, iv = example_interviews) # nolint: object_usage_linter
}

icr_design <- function(cal, iv, cn = NULL) {
  d <- suppressWarnings(suppressMessages(creel_design(cal, date = date, strata = day_type))) # nolint: object_usage_linter
  if (!is.null(cn)) {
    d <- suppressWarnings(suppressMessages(add_counts(d, cn))) # nolint: object_usage_linter
  }
  suppressWarnings(suppressMessages(add_interviews( # nolint: object_usage_linter
    d, iv, catch = catch_total, harvest = catch_kept, effort = hours_fished,
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration
  )))
}

icr_rate <- function(d, ...) {
  e <- suppressWarnings(suppressMessages(estimate_catch_rate(d, ...)))$estimates # nolint: object_usage_linter
  e[c("estimate", "se", "n")]
}

test_that("each interview is stored once, however many rows the calendar holds per date", {
  x <- icr_data()
  d1 <- icr_design(x$cal, x$iv)
  d2 <- icr_design(x$cal2, x$iv)
  expect_identical(nrow(d1$interviews), nrow(x$iv))
  expect_identical(nrow(d2$interviews), nrow(x$iv))
})

test_that("a two-shift calendar gives the catch rate, SE and n of the one-row calendar", {
  x <- icr_data()
  # A copy of every interview leaves the ratio alone and shrinks the SE by
  # about sqrt(2), so the SE and n are what tell the two apart.
  expect_equal(icr_rate(icr_design(x$cal2, x$iv)), icr_rate(icr_design(x$cal, x$iv)))
})

test_that("a two-shift calendar gives the total catch and SE of the one-row calendar", {
  x <- icr_data()
  # Counts do not join the calendar, so a two-shift calendar would differ here
  # only through the interview side.
  total <- function(cal) {
    d <- icr_design(cal, x$iv, x$cn)
    e <- suppressWarnings(suppressMessages(estimate_total_catch(d)))$estimates # nolint: object_usage_linter
    c(e$estimate, e$se)
  }
  expect_equal(total(x$cal2), total(x$cal))
})

test_that("day-level calendar columns still reach the interviews", {
  x <- icr_data()
  d2 <- icr_design(x$cal2, x$iv)
  # `week` describes the day, so it is the same on both shift rows and an
  # interview belongs to exactly one week.
  expect_true("week" %in% names(d2$interviews))
  expect_identical(
    d2$interviews$week,
    x$cal$week[match(d2$interviews$date, x$cal$date)]
  )
})

test_that("shift columns are not attached to interviews that name no shift", {
  x <- icr_data()
  d2 <- icr_design(x$cal2, x$iv)
  # An interview without a shift belongs to both shift rows equally, so the
  # shift's columns have no single value to give it. Attaching them was what
  # copied the interview.
  expect_false(any(c("period_id", "shift") %in% names(d2$interviews)))
})

test_that("a calendar date split across strata the interviews do not carry is refused", {
  x <- icr_data()
  # Two strata on one date, and interviews with no stratum column: there is no
  # way to tell which stratum an interview belongs to. Before the fix each
  # interview went into both.
  cal <- rbind(
    transform(x$cal, zone = "north"),
    transform(x$cal, zone = "south")
  )
  d <- suppressWarnings(suppressMessages(creel_design(cal, date = date, strata = c(day_type, zone)))) # nolint: object_usage_linter
  expect_error(
    suppressWarnings(suppressMessages(add_interviews(
      d, x$iv, catch = catch_total, harvest = catch_kept, effort = hours_fished,
      n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration
    ))),
    class = "creel_error_interview_calendar_ambiguous"
  )
  # With the stratum on each interview, the date and stratum name one row.
  iv <- x$iv
  iv$zone <- rep(c("north", "south"), length.out = nrow(iv))
  d2 <- suppressWarnings(suppressMessages(add_interviews(
    d, iv, catch = catch_total, harvest = catch_kept, effort = hours_fished,
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration
  )))
  expect_identical(nrow(d2$interviews), nrow(iv))
})
