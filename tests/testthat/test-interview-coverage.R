# check_interview_coverage() (GH #709).
#
# A catch total is counted effort x interview rate, and it is right only if the
# interviewed trips can represent the fishing the counts measured. The
# estimators check that across strata (#373, #691); nothing checked it within
# a stratum, so a morning-only interview plan on a lake with an evening bite
# passed every check while its rate described morning trips only.
#
# What these tests hold the function to:
# - it finds that gap, in both layers, and sizes it as a share of counted effort;
# - the plan layer can say "not interviewable" only from the plan, and says
#   NA -- never "covered" -- without it;
# - the data layer compares interviewed fishing TIME (Hoenig et al. 1997), not
#   the number of interviews;
# - anything it cannot see is NA: a block with no count, a stratum whose
#   interviews carry no clock time.

quiet <- function(expr) suppressWarnings(suppressMessages(expr))

# Ten-day calendar, four sampled days. Counts hourly 06:00-20:00 at the given
# density; every interviewed trip fishes [trip_hour, trip_hour + hours).
ic_design <- function(density = function(h) ifelse(h < 12, 10, 30),
                      count_hours = 6:20, trip_hours = c(6.5, 7, 8), hours = 3,
                      timed = TRUE) {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:9, day_type = "weekday")
  days <- cal$date[c(1, 3, 6, 8)]
  counts <- data.frame(
    date = rep(days, each = length(count_hours)), day_type = "weekday",
    count_time = rep(sprintf("%02d:00", count_hours), length(days)),
    anglers = rep(density(count_hours), length(days))
  )
  start <- as.POSIXct(paste(rep(days, each = length(trip_hours)), "00:00"), tz = "UTC") +
    rep(trip_hours, length(days)) * 3600
  iv <- data.frame(
    date = rep(days, each = length(trip_hours)), day_type = "weekday",
    catch = 1, hours = hours, status = "complete",
    trip_start = start, interview_time = start + hours * 3600
  )
  d <- quiet(creel_design(cal, date = date, strata = day_type))
  d <- quiet(add_counts(d, counts, count_col = anglers, count_time_col = count_time))
  if (timed) {
    quiet(add_interviews(d, iv,
      catch = catch, effort = hours, trip_status = status,
      trip_start = trip_start, interview_time = interview_time
    ))
  } else {
    quiet(add_interviews(d, iv, catch = catch, effort = hours, trip_status = status, trip_duration = hours))
  }
}

block_row <- function(tbl, start) tbl[tbl$block_start == start, , drop = FALSE]

test_that("the blog's case: morning-only interviews leave the afternoon and evening as a data gap", {
  r <- check_interview_coverage(ic_design())
  d <- r$data
  # Trips fish 06:30-11:00 at the latest; every counted block from 11:00 on has
  # anglers and no interviewed fishing.
  expect_true(all(block_row(d, "11:00")$gap, block_row(d, "15:00")$gap, block_row(d, "20:00")$gap))
  expect_false(block_row(d, "08:00")$gap)
  # Its size: counted effort in those blocks over all counted effort. Hourly
  # counts, density 10 before noon and 30 after: 11:00 is 10, 12:00-20:00 is
  # 9 x 30, against 6 x 10 + 9 x 30.
  expect_equal(r$summary$effort_share_in_data_gaps, (10 + 9 * 30) / (6 * 10 + 9 * 30))
})

test_that("interviewed fishing is measured in hours fished in each block, not interviews", {
  d <- check_interview_coverage(ic_design(trip_hours = 6.5, hours = 3))$data
  # Four trips, each 06:30-09:30: half an hour in the 06:00 and 09:00 blocks.
  expect_equal(block_row(d, "06:00")$interviewed_hours, 4 * 0.5)
  expect_equal(block_row(d, "07:00")$interviewed_hours, 4 * 1)
  expect_equal(block_row(d, "09:00")$interviewed_hours, 4 * 0.5)
  # Each block is touched by all four trips; only the hours tell them apart.
  expect_identical(block_row(d, "06:00")$n_interviews, block_row(d, "07:00")$n_interviews)
  expect_equal(sum(d$interviewed_share, na.rm = TRUE), 1)
  expect_equal(block_row(d, "06:00")$interviewed_share, 0.5 / 3)
})

test_that("a morning-only interview plan makes the rest of the fishing day not interviewable", {
  r <- check_interview_coverage(
    ic_design(),
    periods = data.frame(start = "06:00", end = "12:00"),
    fishing_hours = c("06:00", "21:00")
  )
  p <- r$plan
  expect_true(block_row(p, "08:00")$interviewable)
  expect_false(block_row(p, "12:00")$interviewable)
  expect_false(block_row(p, "20:00")$interviewable)
  # Outside the fishing day there is no trip to cover: NA, not FALSE.
  expect_true(is.na(block_row(p, "23:00")$interviewable))
  expect_false(block_row(p, "23:00")$in_fishing_day)
  expect_equal(r$summary$fishing_hours_not_interviewable, 9)
  expect_equal(r$summary$effort_share_not_interviewable, (9 * 30) / (6 * 10 + 9 * 30))

  full <- check_interview_coverage(
    ic_design(),
    periods = data.frame(start = c("06:00", "13:30"), end = c("13:30", "21:00")),
    fishing_hours = c("06:00", "21:00")
  )
  expect_equal(full$summary$fishing_hours_not_interviewable, 0)
  expect_equal(full$summary$effort_share_not_interviewable, 0)
})

test_that("a survey whose interviews cover the day has no gaps", {
  r <- check_interview_coverage(ic_design(trip_hours = c(6, 9, 12, 15, 18), hours = 3))
  counted <- !is.na(r$data$mean_count)
  expect_false(any(r$data$gap[counted]))
  expect_equal(r$summary$effort_share_in_data_gaps, 0)
})

test_that("interviews with no clock time leave the data layer unknown, never covered", {
  r <- check_interview_coverage(ic_design(timed = FALSE))
  expect_identical(r$summary$n_no_clock_time, 12L)
  counted <- !is.na(r$data$mean_count)
  expect_true(all(is.na(r$data$gap[counted])))
  expect_true(is.na(r$summary$effort_share_in_data_gaps))
})

test_that("without periods and fishing hours the plan layer is NA, never covered", {
  r <- check_interview_coverage(ic_design())
  expect_true(all(is.na(r$plan$interviewable)))
  expect_true(is.na(r$summary$fishing_hours_not_interviewable))
  expect_true(is.na(r$summary$effort_share_not_interviewable))
  # One without the other is still no plan.
  r2 <- check_interview_coverage(ic_design(), periods = data.frame(start = "06:00", end = "12:00"))
  expect_true(all(is.na(r2$plan$interviewable)))
})

test_that("a block with no count has unknown effort: NA, not zero and not a gap", {
  d <- check_interview_coverage(ic_design(count_hours = c(8, 19)))$data
  nine <- block_row(d, "09:00")
  expect_true(is.na(nine$mean_count))
  expect_identical(nine$n_count_obs, 0L)
  expect_true(is.na(nine$gap))
  expect_true(is.na(nine$effort_share))
  # Shares are of counted effort only.
  expect_equal(sum(d$effort_share, na.rm = TRUE), 1)
  expect_true(block_row(d, "19:00")$gap)
})

test_that("a night creel's blocks run on the survey-day clock, past midnight", {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:9, day_type = "weekday")
  days <- cal$date[c(1, 3, 6, 8)]
  # Counts at 20:00 and at 02:00 the next calendar morning, the same survey day.
  counts <- data.frame(
    day_type = "weekday",
    count_time = as.POSIXct(c(rbind(paste(days, "20:00"), paste(days + 1, "02:00"))), tz = "UTC"),
    anglers = rep(c(12, 20), length(days))
  )
  # Dated by calendar day, as a crew records them; the design maps each to its
  # survey day from day_start.
  counts$date <- as.Date(counts$count_time, tz = "UTC")
  start <- as.POSIXct(paste(days, "19:00"), tz = "UTC")
  iv <- data.frame(
    day_type = "weekday", catch = 1, hours = 3, status = "complete",
    trip_start = start, interview_time = start + 3 * 3600
  )
  iv$date <- as.Date(iv$interview_time, tz = "UTC")
  d <- quiet(creel_design(cal, date = date, strata = day_type, day_start = "12:00", tz = "UTC"))
  d <- quiet(add_counts(d, counts, count_col = anglers, count_time_col = count_time))
  d <- quiet(add_interviews(d, iv,
    catch = catch, effort = hours, trip_status = status,
    trip_start = trip_start, interview_time = interview_time
  ))
  r <- check_interview_coverage(
    d,
    periods = data.frame(start = "18:00", end = "23:00"),
    fishing_hours = c("18:00", "06:00")
  )
  # The survey day starts at 12:00, so its blocks start there.
  expect_identical(r$data$block_start[1], "12:00")
  expect_true(block_row(r$data, "02:00")$gap)
  expect_false(block_row(r$data, "20:00")$gap)
  expect_false(block_row(r$plan, "02:00")$interviewable)
  expect_true(block_row(r$plan, "02:00")$in_fishing_day)
  expect_equal(r$summary$fishing_hours_not_interviewable, 7)
})

test_that("a trip that began before the survey day is clipped at its start, not wrapped to its end", {
  # Started 23:00 the previous evening, interviewed 01:00: on a day design that
  # is one hour of fishing in the 00:00 block of the interview's day. Anchoring
  # on the start would put it at 23:00 and clip it to nothing.
  d <- ic_design(trip_hours = -1, hours = 2)
  r <- check_interview_coverage(d)
  expect_equal(block_row(r$data, "00:00")$interviewed_hours, 4 * 1)
  expect_equal(block_row(r$data, "23:00")$interviewed_hours, 0)
})

test_that("designs whose interviews cannot be timed against counts are refused", {
  d <- quiet(build_br_design_for_tests(n_sites = 3, n_days = 6, n_interviews = 30, seed = 1))
  expect_error(check_interview_coverage(d), class = "creel_error_coverage_unsupported")
  expect_error(check_interview_coverage(d), class = "creel_error")
  expect_error(check_interview_coverage(list()), class = "creel_error_invalid_input")
  expect_error(check_interview_coverage(ic_design(), block = 0), class = "creel_error_invalid_input")
})

test_that("plan inputs are checked, not guessed", {
  expect_error(
    check_interview_coverage(ic_design(), periods = data.frame(start = "6am", end = "12:00"), fishing_hours = c("06:00", "21:00")),
    class = "creel_error_coverage_input"
  )
  expect_error(
    check_interview_coverage(ic_design(), periods = data.frame(from = "06:00"), fishing_hours = c("06:00", "21:00")),
    class = "creel_error_coverage_input"
  )
  # A stratum the table does not cover is refused rather than assumed covered.
  expect_error(
    check_interview_coverage(
      ic_design(),
      periods = data.frame(day_type = "weekend", start = "06:00", end = "12:00"),
      fishing_hours = c("06:00", "21:00")
    ),
    class = "creel_error_coverage_input"
  )
})

test_that("the printed report names both layers and says unknown, not covered", {
  out <- format(check_interview_coverage(ic_design(timed = FALSE)))
  expect_true(any(grepl("Data: unknown", out, fixed = TRUE)))
  expect_true(any(grepl("Plan: unknown hours", out, fixed = TRUE)))
  expect_true(any(grepl("12 interview(s) carry no clock time", out, fixed = TRUE)))
})
