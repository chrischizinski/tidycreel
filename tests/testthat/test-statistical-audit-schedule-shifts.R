# Many roving creels work ONE of two shifts on a sampled day, drawn at random.
# The shift is a second-stage sample within the day, and expanding a shift's
# effort to the day needs the probability it was drawn. generate_schedule()
# could only give every period every day or none, so users drew the shift with
# a line of base R and the probability was recorded nowhere (GH #385).

ss_shifts <- function() {
  data.frame(period_id = c("AM", "PM"), start_time = c("06:00", "13:00"), end_time = c("13:00", "20:00"))
}

ss_sched <- function(seed = 1, ...) {
  generate_schedule(
    "2024-06-01", "2024-07-31",
    n_periods = 2, period_labels = c("AM", "PM"),
    sampling_rate = c(weekday = 0.4, weekend = 0.6), seed = seed, ...
  )
}

test_that("#385: one of two shifts per sampled day, each recorded with p_period = 0.5", {
  s <- ss_sched(periods_per_day = 1)
  expect_identical(anyDuplicated(s$date), 0L)
  expect_true(all(s$period_id %in% c("AM", "PM")))
  expect_identical(unique(s$p_period), 0.5)
})

test_that("#385: the recorded p_period is each day's true chance of each shift", {
  # The estimator divides by p_period, so it must be the real inclusion
  # probability of that shift on that day, not just the average share. Every
  # day is sampled so only the shift draw varies; over many seeds a fixed day
  # must get each shift at the recorded rate, under both allocations,
  # including the odd-sized stratum where one shift gets an extra day.
  for (alloc in c("balanced", "random")) {
    first_day <- vapply(1:400, function(sd) {
      s <- generate_schedule(
        "2024-06-03", "2024-06-09",
        n_periods = 3, sampling_rate = 1, seed = sd,
        periods_per_day = 1, period_allocation = alloc
      )
      s$period_id[s$date == as.Date("2024-06-03")]
    }, integer(1))
    share <- tabulate(first_day, 3) / 400
    expect_true(all(abs(share - 1 / 3) < 0.1), info = paste(alloc, toString(round(share, 3))))
  }
})

test_that("#385: balanced allocation splits each stratum's days across shifts within one", {
  for (sd in 1:20) {
    s <- ss_sched(seed = sd, periods_per_day = 1)
    counts <- table(s$day_type, s$period_id)
    expect_true(all(apply(counts, 1, function(x) diff(range(x))) <= 1), info = paste("seed", sd))
  }
  # Two of three shifts per day: each day gets two different shifts.
  s3 <- generate_schedule(
    "2024-06-01", "2024-07-31",
    n_periods = 3, sampling_rate = 0.5, seed = 3, periods_per_day = 2
  )
  expect_true(all(tapply(s3$period_id, s3$date, function(x) length(unique(x))) == 2L))
  expect_true(all(abs(s3$p_period - 2 / 3) < 1e-12))
  counts3 <- table(s3$day_type, s3$period_id)
  expect_true(all(apply(counts3, 1, function(x) diff(range(x))) <= 1))
})

test_that("#385: a seed reproduces the shifts and selects the same days as before shifts existed", {
  expect_identical(ss_sched(seed = 9, periods_per_day = 1), ss_sched(seed = 9, periods_per_day = 1))
  # Adding a shift draw must not move the sampled days of an existing seed.
  expect_identical(unique(ss_sched(seed = 9)$date), ss_sched(seed = 9, periods_per_day = 1)$date)
})

test_that("#385: every period worked every day records p_period = 1 and is otherwise unchanged", {
  s <- ss_sched()
  expect_identical(unique(s$p_period), 1)
  expect_identical(nrow(s), 2L * length(unique(s$date)))
})

test_that("#385: unsampled days carry no shift and no probability", {
  s <- ss_sched(periods_per_day = 1, include_all = TRUE)
  expect_true(all(is.na(s$period_id[!s$sampled])))
  expect_true(all(is.na(s$p_period[!s$sampled])))
  expect_identical(unique(s$p_period[s$sampled]), 0.5)
})

test_that("#385: shift times are attached per row, inside the drawn shift", {
  s <- ss_sched(periods_per_day = 1, periods = ss_shifts())
  expect_identical(s$shift_start, ifelse(s$period_id == "AM", "06:00", "13:00"))
  expect_identical(s$shift_end, ifelse(s$period_id == "AM", "13:00", "20:00"))
})

test_that("#385: invalid shift arguments are refused", {
  expect_error(ss_sched(periods_per_day = 0), "periods_per_day")
  expect_error(ss_sched(periods_per_day = 3), "periods_per_day")
  expect_error(ss_sched(periods_per_day = 1.5), "periods_per_day")
  expect_error(ss_sched(periods_per_day = 1, expand_periods = FALSE), "expand_periods")
  expect_error(ss_sched(period_allocation = "weighted"), "period_allocation")
  expect_error(ss_sched(periods = ss_shifts()[1, ]), "one row per period")
  bad_time <- ss_shifts()
  bad_time$end_time[2] <- "25:00"
  expect_error(ss_sched(periods = bad_time), "HH:MM")
  # Crossing midnight waits for #407's clock-time handling.
  night <- ss_shifts()
  night$start_time[2] <- "19:30"
  night$end_time[2] <- "00:30"
  expect_error(ss_sched(periods = night), "crossing midnight")
})

test_that("#385: write_schedule() / read_schedule() keep the shift, its probability and its times", {
  s <- ss_sched(periods_per_day = 1, periods = ss_shifts(), include_all = TRUE)
  tmp <- withr::local_tempfile(fileext = ".csv")
  write_schedule(s, tmp)
  back <- read_schedule(tmp)
  expect_identical(back$period_id, s$period_id)
  expect_identical(back$p_period, s$p_period)
  expect_identical(back$shift_start, s$shift_start)
  expect_identical(back$shift_end, s$shift_end)
  skip_if_not_installed("writexl")
  skip_if_not_installed("readxl")
  tmpx <- withr::local_tempfile(fileext = ".xlsx")
  write_schedule(s, tmpx, format = "xlsx")
  backx <- read_schedule(tmpx)
  expect_identical(backx$p_period, s$p_period)
  expect_identical(backx$period_id, s$period_id)
})

test_that("#385: a schedule file with a worked shift but no usable probability is refused on read", {
  s <- as.data.frame(ss_sched(periods_per_day = 1))
  tmp <- withr::local_tempfile(fileext = ".csv")
  for (bad in list(NA, 0, 1.5, "half")) {
    x <- s
    x$p_period[3] <- bad
    utils::write.csv(x, tmp, row.names = FALSE)
    expect_error(read_schedule(tmp), "p_period", class = "creel_error_schema_validation")
  }
})

test_that("#385: a pre-p_period file of whole days is read as p_period = 1, with a warning", {
  # A file written before the column existed: every period worked every day,
  # so nothing was drawn and each period was certain to be worked.
  s <- as.data.frame(ss_sched(include_all = TRUE))
  s$p_period <- NULL
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(s, tmp, row.names = FALSE)
  expect_warning(back <- read_schedule(tmp), class = "creel_warning_p_period_inferred")
  expect_identical(unique(back$p_period), 1)
})

test_that("#385: a pre-p_period file whose days carry different shifts is refused", {
  # Different periods on different days means they were drawn; the chance is
  # not in the file and must not be guessed.
  s <- as.data.frame(ss_sched(periods_per_day = 1))
  s$p_period <- NULL
  tmp <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(s, tmp, row.names = FALSE)
  expect_error(read_schedule(tmp), "differ between days", class = "creel_error_schema_validation")
})
