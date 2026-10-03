# A sectioned effort total's `.lake_total` within-day SE was the quadrature sum
# of the sections' own: sqrt(sum(se_within_i^2)). That is right when the
# sections' count times were drawn independently, and wrong when the same drawn
# times were used in every section -- both then rise on a busy afternoon and fall
# on a quiet morning together, and the lake's within-day variance carries a
# covariance the quadrature sum drops (GH #403).
#
# Whether the times were shared is a fact about the schedule, so it is declared
# (`add_sections(shared_count_times = TRUE)`), never read off matching labels:
# one clerk on a circuit counts "am" in each section at a different moment.

sct_calendar <- function() {
  cal <- data.frame(date = as.Date("2024-06-01") + 0:13)
  cal$day_type <- ifelse(format(cal$date, "%u") %in% c("6", "7"), "weekend", "weekday")
  cal
}

# Four sampled days, two per stratum, two counts per day. Explicit numbers, not
# random draws, so the hand computation below is the same on every run.
sct_counts <- function(b_slope = c(15, 20, 25, 30), b_labels = c(9, 15)) {
  days <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  day_type <- c("weekday", "weekday", "weekend", "weekend")
  a_base <- c(10, 12, 20, 22)
  a_bump <- c(6, 8, 10, 12)
  b_base <- c(30, 34, 50, 55)
  mk <- function(sec, am, pm, times) {
    data.frame(
      date = rep(days, each = 2), day_type = rep(day_type, each = 2),
      section = sec, count_time = rep(times, 4),
      n = as.vector(rbind(am, pm))
    )
  }
  rbind(
    mk("A", a_base, a_base + a_bump, c(9, 15)),
    mk("B", b_base, b_base + b_slope, b_labels)
  )
}

sct_design <- function(cnt, shared = FALSE, with_times = TRUE) {
  cal <- sct_calendar()
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("A", "B")), # nolint: object_usage_linter
    section_col = section, shared_count_times = shared # nolint: object_usage_linter
  )
  if (with_times) {
    suppressWarnings(add_counts(d, cnt, count_col = "n", count_time_col = count_time)) # nolint: object_usage_linter
  } else {
    one <- cnt[cnt$count_time == 9, ]
    suppressWarnings(add_counts(d, one, count_col = "n")) # nolint: object_usage_linter
  }
}

sct_est <- function(d) suppressMessages(suppressWarnings(estimate_effort(d))) # nolint: object_usage_linter

# The Rasmussen within-day variance of the quantity being reported, written out
# independently of the package: add the sections up at each occasion, take the
# sum of squares of that total across the day's counts, and sum over strata.
# With k counts per day this reduces to sum(ss_d) / (k * (k - 1)) per stratum.
sct_hand_within_var <- function(cnt, sections) {
  cnt <- cnt[cnt$section %in% sections, ]
  v <- 0
  for (st in unique(cnt$day_type)) {
    s <- cnt[cnt$day_type == st, ]
    ss <- vapply(split(s, s$date), function(day) {
      tot <- tapply(day$n, day$count_time, sum)
      sum((tot - mean(tot))^2)
    }, numeric(1))
    k <- length(unique(s$count_time))
    v <- v + sum(ss) / (k * (k - 1))
  }
  v
}

test_that("#403: the hand computation reproduces a single section's own within-day SE", {
  # Guards the test itself: if this formula did not match the package where the
  # answer is not in dispute, agreeing on the lake total would mean nothing.
  cnt <- sct_counts()
  res <- sct_est(sct_design(cnt))
  for (sec in c("A", "B")) {
    got <- res$estimates$se_within[res$estimates$section == sec]
    expect_equal(got, sqrt(sct_hand_within_var(cnt, sec)), tolerance = 1e-8)
  }
})

test_that("#403: declared shared count times pool the sections per occasion", {
  cnt <- sct_counts()
  res <- sct_est(sct_design(cnt, shared = TRUE))
  lake <- res$estimates[res$estimates$section == ".lake_total", ]
  expect_equal(lake$se_within, sqrt(sct_hand_within_var(cnt, c("A", "B"))), tolerance = 1e-8)
  # The sections rise together, so the pooled component exceeds the quadrature
  # sum the old code reported.
  secs <- res$estimates[res$estimates$section %in% c("A", "B"), ]
  expect_gt(lake$se_within, sqrt(sum(secs$se_within^2)))
  # Only the within-day part moves: the between-day part and the total follow.
  expect_equal(lake$se, sqrt(lake$se_between^2 + lake$se_within^2), tolerance = 1e-8)
})

test_that("#403: without the declaration nothing changes, even when the labels match", {
  # Labels "9" and "15" are in both sections here. Matching labels are not a
  # declaration: the default stays independent.
  cnt <- sct_counts()
  off <- sct_est(sct_design(cnt, shared = FALSE))
  on <- sct_est(sct_design(cnt, shared = TRUE))
  lake_off <- off$estimates[off$estimates$section == ".lake_total", ]
  secs_off <- off$estimates[off$estimates$section %in% c("A", "B"), ]
  expect_equal(lake_off$se_within, sqrt(sum(secs_off$se_within^2)), tolerance = 1e-10)
  # The per-section rows are identical either way; only the lake row differs.
  expect_equal(
    off$estimates[off$estimates$section %in% c("A", "B"), ],
    on$estimates[on$estimates$section %in% c("A", "B"), ]
  )
  expect_equal(lake_off$estimate, on$estimates$estimate[on$estimates$section == ".lake_total"])
})

test_that("#403: the pooled component is a covariance, not just an inflation", {
  # ONE factor varies: the sign of section B's diurnal slope. When B falls as A
  # rises their errors offset, and pooling must give LESS than the quadrature
  # sum. A fix that merely scaled the lake SE up would pass the test above and
  # fail this one.
  cnt <- sct_counts(b_slope = -c(15, 20, 25, 30))
  res <- sct_est(sct_design(cnt, shared = TRUE))
  lake <- res$estimates[res$estimates$section == ".lake_total", ]
  secs <- res$estimates[res$estimates$section %in% c("A", "B"), ]
  expect_lt(lake$se_within, sqrt(sum(secs$se_within^2)))
  expect_equal(lake$se_within, sqrt(sct_hand_within_var(cnt, c("A", "B"))), tolerance = 1e-8)
})

test_that("#403: sections not counted at the same known occasions are added as independent", {
  # Declared shared, but B's labels differ from A's, so no day pairs. The
  # declaration cannot be honoured by pairing; the days fall back to
  # independence, and say so, exactly as unpaired units do (GH #373).
  cnt <- sct_counts(b_labels = c(10, 16))
  d <- sct_design(cnt, shared = TRUE)
  msgs <- character(0)
  res <- withCallingHandlers(
    suppressWarnings(estimate_effort(d)), # nolint: object_usage_linter
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  lake <- res$estimates[res$estimates$section == ".lake_total", ]
  secs <- res$estimates[res$estimates$section %in% c("A", "B"), ]
  expect_equal(lake$se_within, sqrt(sum(secs$se_within^2)), tolerance = 1e-8)
  expect_true(any(grepl("cannot be paired", msgs)))
})

test_that("#403: a declaration that cannot be honoured is refused, not ignored", {
  cnt <- sct_counts()
  d <- sct_design(cnt, shared = TRUE, with_times = FALSE)
  expect_error(sct_est(d), class = "creel_error_shared_times_unpooled")
})

test_that("#403: shared_count_times must be a plain TRUE or FALSE", {
  cal <- sct_calendar()
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  secs <- data.frame(section = c("A", "B"))
  for (bad in list("yes", NA, c(TRUE, FALSE), 1L)) {
    expect_error(
      add_sections(d, secs, section_col = section, shared_count_times = bad), # nolint: object_usage_linter
      "shared_count_times"
    )
  }
})

test_that("#403: units finer than the section are refused, not pooled flat", {
  # Codex, #403: bank and boat inside each section, A counted at (9, 15) and B at
  # (10, 16), so no day pairs across sections. The flat pooling treated all four
  # units as independent and reported a lake component of 14.14 -- BELOW the
  # undeclared 20.0 -- because it lost the bank/boat pairing inside each section.
  cal <- sct_calendar()
  cal <- cal[cal$date %in% (as.Date("2024-06-03") + 0:1), ]
  mk <- function(sec, times, type) {
    data.frame(
      date = rep(cal$date, each = 2), day_type = "weekday", section = sec,
      angler_type = type, count_time = rep(times, 2), n = rep(c(10, 20), 2)
    )
  }
  cnt <- rbind(
    mk("A", c(9, 15), "bank"), mk("A", c(9, 15), "boat"),
    mk("B", c(10, 16), "bank"), mk("B", c(10, 16), "boat")
  )
  build <- function(shared) {
    d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
    d <- add_sections(d, data.frame(section = c("A", "B")), # nolint: object_usage_linter
      section_col = section, shared_count_times = shared # nolint: object_usage_linter
    )
    suppressWarnings(add_counts(d, cnt, # nolint: object_usage_linter
      count_col = "n", count_time_col = count_time,
      unit_cols = c("date", "day_type", "section", "angler_type")
    ))
  }
  expect_error(sct_est(build(TRUE)), class = "creel_error_shared_times_finer_units")
  # The undeclared default is untouched, and is the larger figure the declared
  # path used to undercut.
  res <- sct_est(build(FALSE))
  lake <- res$estimates[res$estimates$section == ".lake_total", ]
  expect_equal(lake$se_within, 20, tolerance = 1e-8)
})
