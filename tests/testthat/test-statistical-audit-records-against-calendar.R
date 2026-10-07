# Counts and interviews carry their own date and strata, and add_counts() /
# add_interviews() used them as given, never looking them up in the calendar
# (GH #449). The calendar is the population of days -- N_h is counted from it
# -- so a count dated outside it became a sampled day the population does not
# contain, and a record whose stratum disagreed with the calendar was estimated
# in the stratum it named. Measured before the fix, on the fixture below
# (estimate 151, SE 6.30): 4 weekday counts dated outside the calendar gave 277
# (SE 35.30); 12 gave 511 with n_h = 20 against N_h = 10; a Monday count
# labelled "weekend" moved the SE to 13.53. None of it warned.

rac_data <- function() {
  dates <- seq(as.Date("2024-06-03"), by = 1, length.out = 14)
  # ISO day number, so the fixture does not depend on the locale.
  day_type <- ifelse(format(dates, "%u") %in% c("6", "7"), "weekend", "weekday")
  cal <- data.frame(date = dates, day_type = day_type)
  idx <- c(1, 2, 3, 4, 6, 7, 8, 9, 13, 14)
  counts <- data.frame(
    date = dates[idx], day_type = day_type[idx],
    count = c(10, 12, 8, 11, 20, 22, 9, 13, 25, 21)
  )
  list(cal = cal, counts = counts)
}

rac_design <- function(cal, strata = rlang::quo(day_type)) {
  suppressWarnings(suppressMessages(creel_design(cal, date = date, strata = !!strata))) # nolint: object_usage_linter
}

rac_effort <- function(d, counts) {
  d <- suppressWarnings(suppressMessages(add_counts(d, counts))) # nolint: object_usage_linter
  e <- suppressWarnings(suppressMessages(estimate_effort(d)))$estimates # nolint: object_usage_linter
  c(e$estimate, e$se)
}

test_that("counts that agree with the calendar estimate as before", {
  x <- rac_data()
  # The values the fix must not move, measured on the code before it.
  expect_equal(rac_effort(rac_design(x$cal), x$counts), c(151, 6.298148), tolerance = 1e-6)
})

test_that("a count dated outside the calendar is refused", {
  x <- rac_data()
  extra <- data.frame(
    date = seq(as.Date("2024-07-01"), by = 1, length.out = 4),
    day_type = "weekday", count = c(30, 35, 28, 33)
  )
  expect_error(
    rac_effort(rac_design(x$cal), rbind(x$counts, extra)),
    class = "creel_error_record_outside_calendar"
  )
})

test_that("more sampled days than population days cannot be reached through foreign dates", {
  x <- rac_data()
  # 12 foreign weekday days on top of 8 real ones: n_h = 20, N_h = 10.
  extra <- data.frame(
    date = seq(as.Date("2024-07-01"), by = 1, length.out = 12),
    day_type = "weekday", count = 30
  )
  expect_error(
    rac_effort(rac_design(x$cal), rbind(x$counts, extra)),
    class = "creel_error_record_outside_calendar"
  )
})

test_that("a count whose stratum disagrees with the calendar is refused, naming the day", {
  x <- rac_data()
  cn <- x$counts
  cn$day_type[1] <- "weekend" # 2024-06-03 is a Monday
  expect_error(
    rac_effort(rac_design(x$cal), cn),
    class = "creel_error_record_strata_mismatch"
  )
  msg <- tryCatch(rac_effort(rac_design(x$cal), cn), error = conditionMessage)
  expect_match(msg, "2024-06-03: count row says weekend, calendar says weekday", fixed = TRUE)
})

test_that("factor strata in the records match character strata in the calendar", {
  x <- rac_data()
  cn <- x$counts
  cn$day_type <- factor(cn$day_type)
  expect_equal(rac_effort(rac_design(x$cal), cn), rac_effort(rac_design(x$cal), x$counts))
})

test_that("a calendar with several strata on a date accepts each of them", {
  x <- rac_data()
  cal <- rbind(transform(x$cal, zone = "north"), transform(x$cal, zone = "south"))
  d <- rac_design(cal, rlang::quo(c(day_type, zone)))
  cn <- rbind(transform(x$counts, zone = "north"), transform(x$counts, zone = "south"))
  expect_no_error(suppressWarnings(suppressMessages(add_counts(d, cn))))
  cn$zone[1] <- "east"
  expect_error(
    suppressWarnings(suppressMessages(add_counts(d, cn))),
    class = "creel_error_record_strata_mismatch"
  )
})

test_that("a missing date is left to the tier-1 check, not reported as outside the calendar", {
  x <- rac_data()
  cn <- x$counts
  cn$date[1] <- NA
  d <- rac_design(x$cal)
  # Refused by tier 1, which names the missing value...
  err <- tryCatch(suppressWarnings(suppressMessages(add_counts(d, cn))), error = identity)
  expect_s3_class(err, "error")
  expect_false(inherits(err, "creel_error_record_outside_calendar"))
  expect_match(conditionMessage(err), "contains 1 NA value", fixed = TRUE)
  # ...and with allow_invalid = TRUE, where tier 1 only warns, the calendar
  # check does not turn the missing date into one of its own errors. (The
  # survey design then fails on the missing PSU, as it did before #449.)
  err2 <- tryCatch(
    suppressWarnings(suppressMessages(add_counts(d, cn, allow_invalid = TRUE))),
    error = identity
  )
  expect_false(inherits(err2, "creel_error_record_outside_calendar"))
  expect_false(inherits(err2, "creel_error_record_strata_mismatch"))
})

test_that("an interview whose stratum disagrees with the calendar is refused", {
  data(example_calendar, package = "tidycreel", envir = environment())
  data(example_interviews, package = "tidycreel", envir = environment())
  cal <- example_calendar # nolint: object_usage_linter
  iv <- example_interviews # nolint: object_usage_linter
  iv$day_type <- cal$day_type[match(iv$date, cal$date)]
  d <- rac_design(cal)
  attach_iv <- function(iv) {
    suppressWarnings(suppressMessages(add_interviews(
      d, iv, catch = catch_total, harvest = catch_kept, effort = hours_fished,
      n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration
    )))
  }
  expect_no_error(attach_iv(iv))
  # Before the fix three weekday interviews relabelled "weekend" were stored
  # as weekend interviews (10 weekday / 12 weekend instead of 13 / 9).
  wd <- which(iv$day_type == "weekday")[1:3]
  iv$day_type[wd] <- "weekend"
  expect_error(attach_iv(iv), class = "creel_error_record_strata_mismatch")
})
