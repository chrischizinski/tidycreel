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

# The window start is the count instant (#432), so it must be inside the
# shift; the slot after it may run past the shift end.
pdc_inside_shift <- function(a) {
  w <- a[!is.na(a$window_id), ]
  all(pdc_min(w$start_time) >= pdc_min(w$shift_start) & pdc_min(w$start_time) < pdc_min(w$shift_end))
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

test_that("#385: every drawn count starts inside its day's shift", {
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

test_that("#385: with systematic windows min_gap holds on every day", {
  # Only systematic guarantees the gap; random trades it for equal coverage
  # (next test). User decision 2026-10-05.
  for (seed in 1:30) {
    a <- attach_count_times(pdc_schedule(), n_windows = 3, window_size = 30, min_gap = 70,
                            strategy = "systematic", seed = seed)
    expect_true(pdc_min_gap_holds(a, 70), info = as.character(seed))
  }
})

test_that("#385 review: random starts range over the whole stratum, whatever min_gap is", {
  # Holding back room for min_gap pinned the first three of four windows to
  # 06:00, 08:00 and 10:00 (min_gap = 90, 120-min strata): pressure at
  # 07:00-08:00 was never counted on any seed (Codex, #385 review). Each start
  # is uniform over its whole stratum (#432): 06:00-07:59 in the first.
  starts <- vapply(seq_len(600), function(seed) {
    ct <- generate_count_times(start_time = "06:00", end_time = "14:00", strategy = "random",
                               n_windows = 4, window_size = 30, min_gap = 90, seed = seed)
    pdc_min(ct$start_time)[1]
  }, integer(1)) - 360L
  expect_equal(range(starts), c(0L, 119L))
  # Roughly uniform: each third of 0..119 holds about a third of the draws.
  thirds <- table(cut(starts, c(-1, 39, 79, 119)))
  expect_true(all(abs(thirds / 600 - 1 / 3) < 0.06))
  # The hour the restricted draw never reached.
  expect_true(any(starts >= 60L))
})

test_that("#385 review: per-day random draws cover the whole shift over a season", {
  a <- attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 120, seed = 4)
  w <- a[!is.na(a$window_id) & a$period_id == 2, ]
  # A 13:00-20:00 shift in two 210-min strata, min_gap 120: the restricted
  # draw could never start a first window after 14:00.
  first <- tapply(pdc_min(w$start_time), w$date, min)
  expect_true(any(first > pdc_min("14:00")))
})

test_that("#385: a window that fills its stratum is drawn without an internal error", {
  # sample(x:x, 1) draws from 1:x when the range has one value, which tripped
  # an internal stopifnot. Starts are now uniform over the 30-min stratum
  # (#432) and every 30 min after.
  ct <- generate_count_times(start_time = "06:00", end_time = "08:00", strategy = "systematic",
                             n_windows = 4, window_size = 30, min_gap = 0, seed = 3)
  st <- pdc_min(ct$start_time)
  expect_true(st[1] >= pdc_min("06:00") && st[1] < pdc_min("06:30"))
  expect_equal(diff(st), rep(30L, 3))
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

test_that("#385 review: one window needs no room for min_gap", {
  expect_no_error(ct <- generate_count_times(start_time = "06:00", end_time = "12:00", strategy = "random",
                                             n_windows = 1, window_size = 360, min_gap = 60, seed = 1))
  expect_equal(nrow(ct), 1L)
})

test_that("#385 review: negative window arguments are refused", {
  expect_error(attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = -10, seed = 1),
               "min_gap")
  expect_error(generate_count_times(start_time = "06:00", end_time = "14:00", strategy = "random",
                                    n_windows = 2, window_size = -30, min_gap = 0, seed = 1),
               "window_size")
})

test_that("#385 review: a schedule with no rows gives a typed empty result", {
  empty <- pdc_schedule()[0, ]
  a <- attach_count_times(empty, n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
  expect_s3_class(a, "creel_schedule")
  expect_equal(nrow(a), 0L)
  expect_true(all(c("start_time", "end_time", "window_id") %in% names(a)))
})

test_that("#385 review: fixed windows must fall inside a given start_time -- end_time", {
  sched <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-07", n_periods = 2,
                             sampling_rate = 0.5, seed = 1)
  fw <- data.frame(start_time = c("05:00", "09:00"), end_time = c("05:30", "09:30"))
  expect_error(
    attach_count_times(sched, strategy = "fixed", fixed_windows = fw, start_time = "06:00", end_time = "14:00"),
    "outside"
  )
  expect_no_error(attach_count_times(sched, strategy = "fixed", fixed_windows = fw))
})

test_that("#385 review: no seed draws without a .Random.seed warning", {
  expect_no_warning(attach_count_times(pdc_schedule(), n_windows = 2, window_size = 30, min_gap = 60))
  expect_no_warning(generate_count_times(start_time = "06:00", end_time = "14:00", strategy = "random",
                                         n_windows = 2, window_size = 30, min_gap = 10))
})

test_that("#432: every minute of each stratum can be a count start, not only where the slot fits", {
  # Crews count at the start of the slot, so the start is the count instant.
  # Drawing it only where the whole 30-min slot fitted meant the last 30 min
  # of every 120-min stratum were never counted (2 of 8 hours).
  hits <- integer(480)
  for (seed in seq_len(800)) {
    for (strategy in c("random", "systematic")) {
      ct <- generate_count_times(
        start_time = "06:00", end_time = "14:00", strategy = strategy,
        n_windows = 4, window_size = 30, min_gap = 0, seed = seed
      )
      st <- pdc_min(ct$start_time) - 360L + 1L
      hits[st] <- hits[st] + 1L
    }
  }
  # The final 30 min of strata 1-3 (07:30-08:00, 09:30-10:00, 11:30-12:00).
  tails <- c(91:120, 211:240, 331:360)
  expect_true(all(hits[tails] > 0))
  # Per-minute start frequency is flat within a stratum: tail vs head.
  expect_lt(abs(mean(hits[91:120]) - mean(hits[1:30])) / mean(hits[1:30]), 0.25)
})

pdc_slots_overlap <- function(a, window_size) {
  w <- a[!is.na(a$window_id), ]
  any(tapply(pdc_min(w$start_time), as.character(w$date), function(st) {
    st <- sort(st)
    length(st) > 1L && any(st[-1] < st[-length(st)] + window_size)
  }))
}

test_that("#432 review: no day's slots overlap -- one crew can make every count as drawn", {
  # Delaying an overlapping count moves its instant to max(drawn, previous
  # end), which is not uniform and biases effort (Codex, #432 review). A day
  # whose random slots overlap is redrawn instead (user decision).
  for (seed in 1:200) {
    ct <- generate_count_times(start_time = "06:00", end_time = "08:00", strategy = "random",
                               n_windows = 2, window_size = 30, min_gap = 0, seed = seed)
    st <- pdc_min(ct$start_time)
    expect_true(st[2] >= st[1] + 30L, info = as.character(seed))
  }
  a <- attach_count_times(pdc_schedule(), n_windows = 3, window_size = 60, min_gap = 0, seed = 5)
  expect_false(pdc_slots_overlap(a, 60L))
})

test_that("#432 review: overlaps are checked across adjacent shifts on the same day", {
  # Codex: shifts 06:00-08:00 and 08:00-10:00, two systematic 60-min windows
  # each; shift 1's last slot ran to 08:56 while shift 2's first count was at
  # 08:03, with no warning.
  periods <- data.frame(period_id = 1:2, start_time = c("06:00", "08:00"), end_time = c("08:00", "10:00"))
  sched <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-20", n_periods = 2,
                             sampling_rate = 0.5, periods_per_day = 2, periods = periods, seed = 1)
  for (seed in 1:20) {
    a <- attach_count_times(sched, n_windows = 2, window_size = 60, min_gap = 0,
                            strategy = "systematic", seed = seed)
    expect_false(pdc_slots_overlap(a, 60L), info = as.character(seed))
  }
})

test_that("#432 review: a generated template attaches to its own span when its last slot runs on", {
  # Systematic starts over the whole stratum can end the last slot after the
  # span; the template check refused it although every count starts inside.
  sched <- generate_schedule(start_date = "2024-06-01", end_date = "2024-06-14", n_periods = 1,
                             sampling_rate = 0.5, periods_per_day = 1, seed = 1,
                             periods = data.frame(period_id = 1, start_time = "06:00", end_time = "08:00"))
  ct <- generate_count_times(start_time = "06:00", end_time = "08:00", strategy = "systematic",
                             n_windows = 2, window_size = 60, min_gap = 0, seed = 1)
  expect_gt(max(pdc_min(ct$end_time)), pdc_min("08:00"))
  expect_no_error(attach_count_times(sched, ct))
})

test_that("#432: a slot that would cross midnight is refused", {
  expect_error(
    generate_count_times(start_time = "22:00", end_time = "23:59", strategy = "systematic",
                         n_windows = 1, window_size = 90, min_gap = 0, seed = 2),
    "midnight"
  )
})
