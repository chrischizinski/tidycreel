# Shifts bounded by sunrise and sunset change length with the date, so the
# expansion factor T_d (and the shift window the counts and length checks
# use) has to change with it (#368). Before this, users computed shift hours
# outside the package and the schedule could only carry fixed clock times.

ds_days <- function() seq(as.Date("2024-05-01"), as.Date("2024-08-31"), by = "day")

test_that("#368: AM + PM shifts cover sunrise to sunset, split at the cutoff", {
  d <- daylight_shifts(ds_days(), lat = 40.699, lon = -99.083, tz = "America/Chicago")
  expect_equal(nrow(d), 2L * length(ds_days()))
  am <- d[d$period_id == 1, ]
  pm <- d[d$period_id == 2, ]
  expect_true(all(am$end_time == "13:30") && all(pm$start_time == "13:30"))
  # Day length agrees with the independent Forsythe model to a few minutes.
  total <- am$hours + pm$hours
  expect_lt(max(abs(total - day_length(40.699, ds_days()))), 4 / 60)
  # Hours are the exact length of the HH:MM window, so add_counts()' window
  # check (0.01 h) sees the same number.
  mins <- function(x) vapply(x, parse_hhmm_to_min, integer(1), USE.NAMES = FALSE)
  expect_equal(d$hours, (mins(d$end_time) - mins(d$start_time)) / 60)
})

test_that("#368: longitude and daylight saving time move the clock times, not the day length", {
  # 2024-03-10 is the US spring-forward date: sunrise jumps about an hour later.
  d <- daylight_shifts(as.Date(c("2024-03-09", "2024-03-11")), 40.699, -99.083, "America/Chicago")
  mins <- function(x) vapply(x, parse_hhmm_to_min, integer(1), USE.NAMES = FALSE)
  rise <- mins(d$start_time[d$period_id == 1])
  expect_gt(diff(rise), 55)
  # Further west in the same zone, the sun rises later by 4 min per degree.
  east <- daylight_shifts(as.Date("2024-06-21"), 40.7, -95, "America/Chicago")
  west <- daylight_shifts(as.Date("2024-06-21"), 40.7, -100, "America/Chicago")
  shift_min <- mins(west$start_time[1]) - mins(east$start_time[1])
  expect_true(abs(shift_min - 20) <= 1)
  expect_lt(abs(sum(west$hours) - sum(east$hours)), 2 / 60)
})

test_that("#368: several cutoffs give several shifts; bad cutoffs are refused, naming dates", {
  d <- daylight_shifts(as.Date("2024-06-21"), 40.699, -99.083, "America/Chicago", cutoffs = c("11:00", "16:00"))
  expect_equal(d$period_id, 1:3)
  expect_equal(d$end_time[1:2], c("11:00", "16:00"))
  expect_error(daylight_shifts(as.Date("2024-12-21"), 40.699, -99.083, "America/Chicago", cutoffs = "18:00"),
               "2024-12-21")
  expect_error(daylight_shifts(as.Date("2024-06-21"), 40.699, -99.083, "Mars/Olympus"), "tz")
  expect_error(daylight_shifts(as.Date("2024-06-21"), 40.699, -99.083, "America/Chicago",
                               cutoffs = c("16:00", "11:00")), "increasing")
  expect_error(daylight_shifts(as.Date("2024-12-21"), 78, 15, "Arctic/Longyearbyen"), "does not rise")
})

test_that("#368: civil twilight lengthens both ends of the day", {
  base <- daylight_shifts(as.Date("2024-06-21"), 40.699, -99.083, "America/Chicago")
  civil <- daylight_shifts(as.Date("2024-06-21"), 40.699, -99.083, "America/Chicago", horizon = "civil")
  expect_gt(civil$hours[1], base$hours[1])
  expect_gt(civil$hours[2], base$hours[2])
})

test_that("#368: daylight shifts drive the schedule, count times and add_counts() end to end", {
  shifts <- daylight_shifts(ds_days(), 40.699, -99.083, "America/Chicago")
  sched <- generate_schedule(
    start_date = "2024-05-01", end_date = "2024-08-31", n_periods = 2, sampling_rate = 0.2,
    periods_per_day = 1, include_all = TRUE, periods = shifts, seed = 11
  )
  worked <- sched[!is.na(sched$period_id), ]
  key <- paste(worked$date, worked$period_id)
  ref <- shifts[match(key, paste(shifts$date, shifts$period_id)), ]
  # Each day's drawn shift carries THAT day's daylight window.
  expect_equal(worked$shift_start, ref$start_time)
  expect_equal(worked$shift_end, ref$end_time)
  expect_gt(length(unique(worked$shift_start[worked$period_id == 1])), 10L)

  a <- attach_count_times(sched, n_windows = 2, window_size = 30, min_gap = 30, seed = 2)
  w <- a[!is.na(a$window_id), ]
  hours <- shifts$hours[match(paste(w$date, w$period_id), paste(shifts$date, shifts$period_id))]
  counts <- data.frame(date = w$date, day_type = w$day_type, count_time = w$start_time,
                       anglers = seq_len(nrow(w)) %% 9 + 2, hours = hours)
  d <- suppressMessages(creel_design(sched, date = date, strata = day_type))
  out <- suppressWarnings(suppressMessages(add_counts(
    d, counts, count_col = anglers, count_time_col = count_time, period_length_col = hours
  )))
  day_hours <- tapply(counts$hours, counts$date, `[`, 1)
  expected <- sum(tapply(counts$anglers, counts$date, mean) * day_hours / 0.5)
  expect_equal(suppressWarnings(suppressMessages(estimate_effort(out)))$estimates$estimate,
               expected, tolerance = 1e-10)

  # A fixed 7-hour length disagrees with the daylight window and is refused.
  counts$hours <- 7
  expect_error(suppressWarnings(suppressMessages(add_counts(
    d, counts, count_col = anglers, count_time_col = count_time, period_length_col = hours
  ))), class = "creel_error_period_length_window")
})

test_that("#368: a date-specific periods table must cover every worked date", {
  shifts <- daylight_shifts(seq(as.Date("2024-06-01"), as.Date("2024-06-15"), by = "day"),
                            40.699, -99.083, "America/Chicago")
  expect_error(
    generate_schedule(start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 2,
                      sampling_rate = 0.5, periods_per_day = 1, periods = shifts, seed = 1),
    "no shift times"
  )
  dup <- rbind(shifts, shifts[1, ])
  expect_error(
    generate_schedule(start_date = "2024-06-01", end_date = "2024-06-15", n_periods = 2,
                      sampling_rate = 0.5, periods_per_day = 1, periods = dup, seed = 1),
    "one row per date and period"
  )
})

test_that("#368 review: a span that does not divide evenly gives every minute the same chance", {
  # 06:00-13:01 is 421 minutes in two strata. Whole-minute strata of 210 and
  # 211 minutes weighted the minutes of the shorter one more, and a shared
  # systematic offset never reached 13:00 (Codex, #368 review).
  sched <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-01", n_periods = 1,
                             sampling_rate = 1, periods_per_day = 1, seed = 1,
                             periods = data.frame(period_id = 1, start_time = "06:00", end_time = "13:01"))
  mins <- function(x) vapply(x, parse_hhmm_to_min, integer(1), USE.NAMES = FALSE)
  for (strategy in c("random", "systematic")) {
    hits <- integer(421)
    for (seed in seq_len(3000)) {
      a <- attach_count_times(sched, n_windows = 2, window_size = 10, min_gap = 0,
                              strategy = strategy, seed = seed)
      st <- mins(a$start_time) - 360L + 1L
      hits[st] <- hits[st] + 1L
    }
    expect_gt(hits[421], 0) # 13:00 reachable
    # Each minute's chance is 2 / 421: compare first and second stratum.
    first <- mean(hits[1:200])
    second <- mean(hits[221:420])
    expect_lt(abs(first - second) / first, 0.06)
  }
})

test_that("#368 review: include_all schedules need shift times only on worked days", {
  days <- seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
  shifts <- daylight_shifts(days, 40.699, -99.083, "America/Chicago")
  # All periods worked on sampled days; unsampled days still carry period ids.
  probe <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 2,
                             sampling_rate = 0.5, include_all = TRUE, seed = 1)
  sampled_days <- unique(probe$date[probe$sampled])
  only_sampled <- shifts[shifts$date %in% sampled_days, ]
  expect_no_error(generate_schedule(start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 2,
                                    sampling_rate = 0.5, include_all = TRUE, seed = 1,
                                    periods = only_sampled))
})

test_that("#368 review: zones across the date line get their own local day", {
  # Apia: UTC+13 at longitude -171.75; the UTC-date cycle is the next local day.
  d <- daylight_shifts(as.Date("2024-06-21"), -13.83, -171.75, "Pacific/Apia", cutoffs = "12:00")
  mins <- function(x) vapply(x, parse_hhmm_to_min, integer(1), USE.NAMES = FALSE)
  expect_true(mins(d$start_time[1]) > 5 * 60 && mins(d$start_time[1]) < 9 * 60)
  expect_true(mins(d$end_time[2]) > 17 * 60 && mins(d$end_time[2]) < 20 * 60)
})

test_that("#368 review: a sunset rounding to midnight is refused, not written as 24:00", {
  expect_error(daylight_shifts(as.Date("2024-06-21"), 64.33, 10.4, "Europe/Oslo"), "midnight")
  expect_error(daylight_shifts(as.Date("2024-06-21"), 40.7, -99.1, "America/Chicago", cutoffs = c("13:30", NA)),
               "cutoffs")
})
