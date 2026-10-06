# Night creels, schedule side (GH #407 part 4a). A survey day may start at a
# clock time other than midnight (`day_start`), so a night that crosses
# midnight -- one shift 19:30-06:00, or two halves 19:30-00:30 and
# 00:30-06:00 -- is one survey day dated by the evening it starts. Before this,
# every such shift was refused. What must hold:
# - the shift times are read on the survey-day clock, so the second half of a
#   split night belongs to the same survey day, not that morning;
# - which nights are the weekend is the agency's choice, never a silent
#   Saturday/Sunday default (a Friday night is dated Friday);
# - count instants are drawn across the whole shift, including after
#   midnight, and never run into the next survey day;
# - a night's length is real elapsed time, so a daylight-saving night is an
#   hour longer or shorter than its clock length;
# - a night schedule cannot reach estimation until counts can be mapped to
#   night survey days (4b): refused, never estimated on calendar dates.

ns_min <- function(x) vapply(x, function(t) parse_hhmm_to_min(t), integer(1), USE.NAMES = FALSE) # nolint: object_usage_linter
ns_survey <- function(x, ds = 720L, end = FALSE) survey_min(ns_min(x), ds, end) # nolint: object_usage_linter

ns_split_night <- function() {
  data.frame(period_id = 1:2, start_time = c("19:30", "00:30"), end_time = c("00:30", "06:00"))
}

ns_sched <- function(periods = ns_split_night(), day_start = "12:00",
                     weekend_days = c("Friday", "Saturday"), ...) {
  generate_schedule("2024-06-03", "2024-06-30", n_periods = 2, sampling_rate = 0.5,
                    periods_per_day = 1, periods = periods, day_start = day_start,
                    weekend_days = weekend_days, seed = 1, ...)
}

test_that("#407: a split night is one survey day only on a clock that starts after the night", {
  s <- ns_sched()
  expect_true(all(c("19:30", "00:30") %in% s$shift_start))
  expect_identical(unique(s$day_start), "12:00")
  # On the calendar-day clock 19:30-00:30 leaves its day: refused, not wrapped.
  expect_error(ns_sched(day_start = "00:00", weekend_days = NULL), "at or before")
  # A single 19:30-06:00 shift is fine on the night clock too.
  one <- data.frame(period_id = 1, start_time = "19:30", end_time = "06:00")
  s1 <- generate_schedule("2024-06-03", "2024-06-09", n_periods = 1, sampling_rate = 1,
                          periods = one, day_start = "12:00", weekend_days = "Sat", seed = 1)
  expect_identical(unique(s1$shift_end), "06:00")
})

test_that("#407: weekend nights are named, never defaulted, once the day is not the calendar day", {
  expect_error(ns_sched(weekend_days = NULL), "weekend_days")
  s <- ns_sched(include_all = TRUE)
  wd <- weekdays(s$date)
  # Friday and Saturday NIGHTS are the weekend; Sunday night is a weekday.
  expect_true(all(s$day_type[wd %in% c("Friday", "Saturday")] == "weekend"))
  expect_true(all(s$day_type[wd == "Sunday"] == "weekday"))
  # Three-letter and any-case names are the same choice.
  s3 <- ns_sched(include_all = TRUE, weekend_days = c("fri", "SAT"))
  expect_identical(s3$day_type, s$day_type)
  expect_error(ns_sched(weekend_days = "Fryday"), "Fryday")
  # Day schedules keep Saturday/Sunday and gain no column.
  day <- generate_schedule("2024-06-03", "2024-06-30", n_periods = 1, sampling_rate = 1,
                           include_all = TRUE, seed = 1)
  expect_identical(day$day_type == "weekend", weekdays(day$date) %in% c("Saturday", "Sunday"))
  expect_false("day_start" %in% names(day))
})

test_that("#407: night count instants span midnight and stay inside their shift and survey day", {
  s <- ns_sched()
  after_midnight <- 0L
  for (seed in 1:10) {
    a <- attach_count_times(s, n_windows = 3, window_size = 30, min_gap = 30,
                            strategy = "random", seed = seed)
    a <- a[!is.na(a$start_time), ]
    st <- ns_survey(a$start_time)
    expect_true(all(st >= ns_survey(a$shift_start)), info = seed)
    expect_true(all(st < ns_survey(a$shift_end, end = TRUE)), info = seed)
    expect_true(all(st + 30L <= 1440L), info = seed) # never into the next survey day
    first <- a$shift_start == "19:30"
    after_midnight <- after_midnight + sum(first & ns_min(a$start_time) < 720L)
  }
  # The 19:30-00:30 shift's last half hour is after midnight; over many draws
  # some counts must land there, or that half hour is never sampled.
  expect_gt(after_midnight, 0L)
})

test_that("#407: a systematic night keeps its spacing across midnight", {
  one <- data.frame(period_id = 1, start_time = "22:00", end_time = "04:00")
  s <- generate_schedule("2024-06-03", "2024-06-09", n_periods = 1, sampling_rate = 1,
                         periods = one, day_start = "12:00", weekend_days = "Sat", seed = 1)
  a <- attach_count_times(s, n_windows = 3, window_size = 30, min_gap = 90,
                          strategy = "systematic", seed = 3)
  gaps <- tapply(ns_survey(a$start_time), a$date, function(x) unique(diff(sort(x))))
  expect_true(all(vapply(gaps, length, integer(1)) == 1L))
  expect_true(all(unlist(gaps) == 120L)) # 6 h / 3 windows, unbroken by midnight
})

test_that("#407: write_schedule() / read_schedule() keep the survey-day start and real hours", {
  nights <- daylight_shifts(seq(as.Date("2024-10-28"), as.Date("2024-11-10"), by = "day"),
                            40.699, -99.083, "America/Chicago", cutoffs = "00:30", night = TRUE)
  s <- generate_schedule("2024-10-28", "2024-11-10", n_periods = 2, sampling_rate = 0.5,
                         periods_per_day = 1, periods = nights, day_start = "12:00",
                         weekend_days = c("Fri", "Sat"), seed = 1)
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(s, tmp)
  back <- read_schedule(tmp)
  expect_identical(unique(back$day_start), "12:00")
  expect_equal(back$shift_hours, s$shift_hours)
  # The same file without day_start has shifts leaving their calendar day.
  raw <- utils::read.csv(tmp, colClasses = "character")
  raw$day_start <- NULL
  utils::write.csv(raw, tmp, row.names = FALSE)
  expect_error(read_schedule(tmp), "within one survey day")
})

test_that("#407: a night's hours are elapsed time, an hour off its clock length across DST", {
  n <- daylight_shifts(as.Date(c("2024-11-01", "2024-11-02", "2024-03-09")), 40.699, -99.083,
                       "America/Chicago", cutoffs = "00:30", night = TRUE)
  clock <- (ns_survey(n$end_time, end = TRUE) - ns_survey(n$start_time)) / 60
  late <- n$period_id == 2 # 00:30 to sunrise, where the change falls
  expect_equal(n$hours[late & n$date == as.Date("2024-11-01")], clock[late & n$date == as.Date("2024-11-01")])
  expect_equal(n$hours[late & n$date == as.Date("2024-11-02")],
               clock[late & n$date == as.Date("2024-11-02")] + 1) # fall back: +1 h
  expect_equal(n$hours[late & n$date == as.Date("2024-03-09")],
               clock[late & n$date == as.Date("2024-03-09")] - 1) # spring forward: -1 h
  expect_equal(n$hours[!late], clock[!late])
  # A cutoff in the repeated hour happens twice: which shift gets the extra
  # hour would be an arbitrary pick, so it is refused (review).
  expect_error(daylight_shifts(as.Date("2024-11-02"), 40.699, -99.083, "America/Chicago",
                               cutoffs = "01:30", night = TRUE), "repeated")
  # A cutoff in the skipped hour has no time that night.
  expect_error(daylight_shifts(as.Date("2024-03-09"), 40.699, -99.083, "America/Chicago",
                               cutoffs = "02:30", night = TRUE), "skipped")
  expect_error(daylight_shifts(as.Date("2024-06-01"), 40.699, -99.083, "America/Chicago",
                               cutoffs = c("01:00", "22:00"), night = TRUE), "evening to morning")
  # A periods table whose hours disagree with its own times by more than DST.
  bad <- ns_split_night()
  bad$hours <- c(5, 9)
  expect_error(ns_sched(periods = bad), "hours")
})

test_that("#407: a night schedule is refused as a design calendar until counts can be mapped", {
  s <- ns_sched()
  expect_error(creel_design(s, date = date, strata = day_type),
               class = "creel_error_night_design_pending")
  # A day schedule is unaffected.
  day <- generate_schedule("2024-06-03", "2024-06-30", n_periods = 1, sampling_rate = 0.5, seed = 1)
  expect_no_error(suppressWarnings(creel_design(day, date = date, strata = day_type)))
})

test_that("#407: generate_count_times() still refuses an end before its start", {
  # A night span is declared through generate_schedule(day_start = ); here
  # "14:00" to "06:00" is far more often swapped times than a 16 h night.
  expect_error(generate_count_times(start_time = "19:30", end_time = "06:00", strategy = "systematic",
                                    n_windows = 3, window_size = 30, min_gap = 60, seed = 1),
               "attach_count_times")
})
