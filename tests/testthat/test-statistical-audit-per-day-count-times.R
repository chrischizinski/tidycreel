# Instantaneous-count effort assumes the count times are random on EACH sampled
# day. attach_count_times() used to copy one set of windows to every day, so a
# time-of-day pattern in pressure was sampled the same way every day and never
# averaged out, and with shifts every window had to be split and re-joined by
# hand (#385). Pollock et al. (Angler Survey Methods, ch. 11) draw the times --
# simple random or a systematic random start -- for each survey day.

pdc_periods <- function() {
  data.frame(period_id = 1:2, start_time = c("06:00", "13:00"), end_time = c("13:00", "20:00"))
}

pdc_schedule <- function(...) {
  generate_schedule(
    start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 2, sampling_rate = 0.5,
    periods_per_day = 1, periods = pdc_periods(), seed = 1, ...
  )
}

pdc_min <- function(x) vapply(as.character(x), parse_hhmm_to_min, integer(1), USE.NAMES = FALSE) # nolint: object_usage_linter

pdc_inside_shift <- function(a) {
  w <- a[!is.na(a$window_id), ]
  all(pdc_min(w$start_time) >= pdc_min(w$shift_start) & pdc_min(w$end_time) <= pdc_min(w$shift_end))
}

pdc_min_gap_holds <- function(a, gap) {
  w <- a[!is.na(a$window_id), ]
  ok <- tapply(seq_len(nrow(w)), paste(w$date, w$period_id), function(i) {
    st <- sort(pdc_min(w$start_time[i]))
    en <- sort(pdc_min(w$end_time[i]))
    length(st) < 2L || all(st[-1] - en[-length(en)] >= gap)
  })
  all(ok)
}

test_that("#385: every drawn window falls inside its day's shift", {
  for (strategy in c("random", "systematic")) {
    for (seed in 1:20) {
      a <- attach_count_times(pdc_schedule(), n_windows = 3, window_size = 30, min_gap = 40,
                              strategy = strategy, seed = seed)
      expect_true(pdc_inside_shift(a), info = paste(strategy, seed))
    }
  }
})

test_that("#385: random windows differ across days instead of repeating", {
  a <- attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
  w <- a[!is.na(a$window_id) & a$period_id == 1, ]
  per_day <- tapply(w$start_time, w$date, paste, collapse = ",")
  expect_gt(length(unique(per_day)), length(per_day) / 2)
})

test_that("#385: systematic draws a fresh random start each day", {
  # User decision 2026-10-05: the same offset every day carries the same bias
  # as copying clock times. Spacing stays the stratum length within a day.
  a <- attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 60,
                          strategy = "systematic", seed = 1)
  w <- a[!is.na(a$window_id) & a$period_id == 1, ]
  first <- tapply(pdc_min(w$start_time), w$date, min)
  expect_gt(length(unique(first)), 1L)
  spacing <- tapply(pdc_min(w$start_time), w$date, function(x) diff(sort(x)))
  expect_true(all(unlist(spacing) == 210L)) # 420 min / 2 windows
})

test_that("#385: the same seed gives the same windows; another seed does not", {
  a1 <- attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 60, seed = 7)
  a2 <- attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 60, seed = 7)
  a3 <- attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 60, seed = 8)
  expect_identical(a1$start_time, a2$start_time)
  expect_false(identical(a1$start_time, a3$start_time))
})

test_that("#385: min_gap holds on every day", {
  for (seed in 1:30) {
    a <- attach_count_times(pdc_schedule(), n_windows = 3, window_size = 30, min_gap = 70, seed = seed)
    expect_true(pdc_min_gap_holds(a, 70), info = as.character(seed))
  }
})

test_that("#385: generate_count_times(strategy = 'random') honours min_gap", {
  # Before #385 a window could start anywhere in its stratum, so neighbouring
  # windows could be 1 minute apart with min_gap = 60 (294 of 500 seeds).
  for (seed in 1:200) {
    ct <- generate_count_times(start_time = "06:00", end_time = "14:00", strategy = "random",
                               n_windows = 4, window_size = 30, min_gap = 60, seed = seed)
    gaps <- pdc_min(ct$start_time)[-1] - pdc_min(ct$end_time)[-4]
    expect_true(all(gaps >= 60), info = as.character(seed))
  }
})

test_that("#385: a window that fills its stratum is placed at the stratum start", {
  # sample(x:x, 1) draws from 1:x when the range has one value; with
  # window_size equal to the stratum length the systematic start must be the
  # span start, not a random minute after midnight.
  ct <- generate_count_times(start_time = "06:00", end_time = "08:00", strategy = "systematic",
                             n_windows = 4, window_size = 30, min_gap = 0, seed = 3)
  expect_identical(ct$start_time, c("06:00", "06:30", "07:00", "07:30"))
})

test_that("#385: a schedule that draws shifts but has no shift times errors at attach time", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-06-14", n_periods = 2, sampling_rate = 0.5,
    periods_per_day = 1, seed = 1
  )
  expect_error(
    attach_count_times(sched, n_windows = 2, window_size = 30, min_gap = 60,
                       start_time = "06:00", end_time = "20:00"),
    "no shift times"
  )
})

test_that("#385: two worked shifts on a day each get windows inside themselves", {
  periods <- data.frame(period_id = 1:3, start_time = c("06:00", "11:00", "16:00"),
                        end_time = c("11:00", "16:00", "21:00"))
  sched <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-10", n_periods = 3,
                             sampling_rate = 0.5, periods_per_day = 2, periods = periods, seed = 2)
  a <- attach_count_times(sched, n_windows = 2, window_size = 30, min_gap = 60, seed = 2)
  expect_true(pdc_inside_shift(a))
  expect_equal(nrow(a), 2L * nrow(sched))
})

test_that("#385: fixed windows are given per shift and must fit it", {
  fw <- data.frame(period_id = c(1, 1, 2, 2), start_time = c("08:00", "11:00", "15:00", "18:00"),
                   end_time = c("08:30", "11:30", "15:30", "18:30"))
  a <- attach_count_times(pdc_schedule(), strategy = "fixed", fixed_windows = fw)
  expect_true(pdc_inside_shift(a))
  pm <- a[!is.na(a$window_id) & a$period_id == 2, ]
  expect_setequal(unique(pm$start_time), c("15:00", "18:00"))

  expect_error(
    attach_count_times(pdc_schedule(), strategy = "fixed", fixed_windows = fw[-1]),
    "period_id"
  )
  bad <- fw
  bad$start_time[3] <- "12:00"
  bad$end_time[3] <- "12:30"
  expect_error(attach_count_times(pdc_schedule(), strategy = "fixed", fixed_windows = bad), "outside the shift")
})

test_that("#385: a template is copied to every day, and refused where it leaves the shift", {
  ct <- generate_count_times(start_time = "06:00", end_time = "13:00", strategy = "systematic",
                             n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
  # The AM template falls outside every PM shift.
  expect_error(attach_count_times(pdc_schedule(), ct), "outside the shift")
  # Without shifts the template is copied as before: same times every day.
  sched <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-07", n_periods = 2,
                             sampling_rate = 0.5, seed = 1)
  a <- attach_count_times(sched, ct)
  expect_equal(nrow(a), nrow(sched) * nrow(ct))
  expect_equal(length(unique(a$start_time)), nrow(ct))
})

test_that("#385: a template and drawing arguments together are refused", {
  ct <- generate_count_times(start_time = "06:00", end_time = "13:00", strategy = "systematic",
                             n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
  expect_error(attach_count_times(pdc_schedule(), ct, n_windows = 2), "not both")
  expect_error(attach_count_times(pdc_schedule()), "Nothing to attach")
})

test_that("#385: drawn windows feed add_counts() with the schedule's p and window", {
  sched <- pdc_schedule(include_all = TRUE)
  a <- attach_count_times(sched, n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
  w <- a[!is.na(a$window_id), ]
  counts <- data.frame(
    date = w$date, day_type = w$day_type, count_time = w$start_time,
    anglers = seq_len(nrow(w)) %% 7 + 3, hours = 7
  )
  d <- suppressMessages(creel_design(sched, date = date, strata = day_type))
  out <- suppressWarnings(suppressMessages(add_counts(
    d, counts,
    count_col = anglers, count_time_col = count_time, period_length_col = hours
  )))
  est <- suppressWarnings(suppressMessages(estimate_effort(out)))$estimates$estimate
  expect_equal(est, sum(tapply(counts$anglers, counts$date, mean) * 7 / 0.5), tolerance = 1e-12)
})
