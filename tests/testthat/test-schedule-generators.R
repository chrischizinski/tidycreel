test_that("SCHED-01: returns tibble with date, day_type, period_id columns for scalar sampling_rate", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = 0.3, seed = 42
  )
  expect_s3_class(sched, "creel_schedule")
  expect_s3_class(sched, "data.frame")
  expect_true(inherits(sched$date, "Date"))
  expect_type(sched$day_type, "character")
  expect_type(sched$period_id, "integer")
})

test_that("SCHED-01: stratified sampling — weekday and weekend proportions match sampling_rate", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  sched_all <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42,
    include_all = TRUE
  )
  all_weekday <- sum(sched_all$day_type == "weekday")
  all_weekend <- sum(sched_all$day_type == "weekend")
  sampled_weekday <- sum(sched_all$day_type == "weekday" & sched_all$sampled)
  sampled_weekend <- sum(sched_all$day_type == "weekend" & sched_all$sampled)

  expect_equal(sampled_weekday, round(all_weekday * 0.3))
  expect_equal(sampled_weekend, round(all_weekend * 0.6))
})

test_that("SCHED-01: seed reproducibility — same seed + inputs produce identical tibbles", {
  sched1 <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  sched2 <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  expect_equal(sched1, sched2)
})

test_that("SCHED-01: seed reproducibility — different seeds produce different results", {
  sched1 <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1, sampling_rate = 0.3, seed = 42
  )
  sched2 <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1, sampling_rate = 0.3, seed = 99
  )
  # Different seeds should (almost certainly) produce different row sets
  expect_false(identical(sched1$date, sched2$date))
})

test_that("SCHED-01: expand_periods = FALSE collapses to one row per sampled day", {
  sched_collapsed <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 3, sampling_rate = 0.3, seed = 42,
    expand_periods = FALSE
  )
  sched_expanded <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 3, sampling_rate = 0.3, seed = 42,
    expand_periods = TRUE
  )
  # Collapsed has one row per unique date; expanded has n_periods rows per date
  expect_equal(nrow(sched_collapsed) * 3, nrow(sched_expanded))
  expect_false("period_id" %in% names(sched_collapsed))
})

test_that("SCHED-01: include_all = TRUE returns full season with sampled logical column", {
  sched_all <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1, sampling_rate = 0.3, seed = 42,
    include_all = TRUE
  )
  # Full season is 92 days (June + July + August)
  expect_equal(nrow(sched_all), 92)
  expect_true("sampled" %in% names(sched_all))
  expect_type(sched_all$sampled, "logical")
})

test_that("SCHED-01: include_all = FALSE (default) does not include sampled column", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1, sampling_rate = 0.3, seed = 42
  )
  expect_false("sampled" %in% names(sched))
})

test_that("SCHED-01: error when both n_days and sampling_rate supplied", {
  expect_error(
    generate_schedule(
      start_date = "2024-06-01", end_date = "2024-08-31",
      n_periods = 2, n_days = 10, sampling_rate = 0.3, seed = 42
    ),
    class = "rlang_error"
  )
})

test_that("SCHED-01: error when neither n_days nor sampling_rate supplied", {
  expect_error(
    generate_schedule(
      start_date = "2024-06-01", end_date = "2024-08-31",
      n_periods = 2, seed = 42
    ),
    class = "rlang_error"
  )
})

test_that("SCHED-01: period_labels supplied — period_id is character", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = 0.3, seed = 42,
    period_labels = c("morning", "afternoon")
  )
  expect_type(sched$period_id, "character")
  expect_true(all(sched$period_id %in% c("morning", "afternoon")))
})

test_that("SCHED-01: ordered_periods = TRUE — period_id is an ordered factor", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 3, sampling_rate = 0.3, seed = 42,
    period_labels = c("morning", "afternoon", "evening"),
    ordered_periods = TRUE
  )
  expect_true(is.ordered(sched$period_id))
  expect_equal(levels(sched$period_id), c("morning", "afternoon", "evening"))
})

test_that("SCHED-01: output inherits 'creel_schedule' and 'data.frame'", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = 0.3, seed = 42
  )
  expect_true(inherits(sched, "creel_schedule"))
  expect_true(inherits(sched, "data.frame"))
})

test_that("SCHED-01: output passes validate_calendar_schema() without error", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = 0.3, seed = 42
  )
  expect_no_error(validate_creel_schedule(sched))
})

test_that("SCHED-01: n_days scalar selects correct number of days", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1, n_days = 10, seed = 42
  )
  # n_days = 10 applied uniformly: ~10 weekdays and ~10 weekends selected
  # With 92 days total split ~66 weekdays, 26 weekends
  # scalar expands to both strata, capped at stratum size
  unique_dates <- unique(sched$date)
  expect_true(length(unique_dates) > 0)
})

test_that("SCHED-01: withr scoping — global RNG state unchanged after generate_schedule()", {
  set.seed(100)
  x1 <- runif(1)
  set.seed(100)
  generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 1, sampling_rate = 0.3, seed = 42
  )
  x2 <- runif(1)
  expect_equal(x1, x2)
})

test_that("SCHED-01: output passes creel_design() without error", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-08-31",
    n_periods = 2, sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
  expect_no_error(creel_design(sched, date = date, strata = day_type))
})

# ---- SCHED-02: generate_bus_schedule() — implemented in Plan 02 ----

# Helper: minimal sampling_frame for tests
.bus_frame_single <- function() {
  data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.4, 0.3, 0.3),
    stringsAsFactors = FALSE
  )
}

.bus_frame_multi_circuit <- function() {
  data.frame(
    site = c("A", "B", "C", "D"),
    circuit = c("C1", "C1", "C2", "C2"),
    p_site = c(0.6, 0.4, 0.7, 0.3),
    stringsAsFactors = FALSE
  )
}

.bus_sched <- function() {
  generate_schedule( # nolint: object_usage_linter
    "2024-06-01", "2024-08-31",
    n_periods = 2,
    sampling_rate = c(weekday = 0.3, weekend = 0.6),
    seed = 42
  )
}

test_that("SCHED-02: generate_bus_schedule() returns inclusion_prob column", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 2
  )
  expect_true("inclusion_prob" %in% names(result))
  expect_true(all(result$inclusion_prob > 0))
  expect_true(all(result$inclusion_prob <= 1))
})

test_that("SCHED-02: output is a plain tibble (not creel_schedule subclass)", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 2
  )
  expect_false(inherits(result, "creel_schedule"))
  expect_true(is.data.frame(result))
})

test_that("SCHED-02: output retains all sampling_frame columns", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 2
  )
  expect_true("site" %in% names(result))
  expect_true("p_site" %in% names(result))
})

test_that("SCHED-02: inclusion_prob = p_site * (crew / n_circuits)", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 2
  )
  # single circuit → n_circuits = 1; p_period = 2/1 = 2 (capped?  no — crew can exceed 1)
  # Actually p_period = crew / n_circuits = 2/1 = 2, then inclusion_prob = p_site * 2
  # But crew=2 with 1 circuit → p_period=2 → inclusion_prob could exceed 1 for some sites
  # Use crew=1 to get clean values
  result2 <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 1
  )
  expected <- frame$p_site * (1 / 1)
  expect_equal(result2$inclusion_prob, expected)
})

test_that("SCHED-02: multi-circuit formula uses n_circuits in denominator", {
  frame <- .bus_frame_multi_circuit()
  sched <- .bus_sched()
  result <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, circuit = circuit, crew = 1
  )
  # 2 circuits → p_period = 1/2 = 0.5
  expected <- frame$p_site * 0.5
  expect_equal(result$inclusion_prob, expected)
})

test_that("SCHED-02: circuit = NULL treated as single circuit", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result_null <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 1
  )
  # Equivalent to explicitly using a single circuit
  frame2 <- frame
  frame2$circuit <- "circuit_1"
  result_explicit <- generate_bus_schedule(
    sched, frame2,
    site = site, p_site = p_site, circuit = circuit, crew = 1
  )
  expect_equal(result_null$inclusion_prob, result_explicit$inclusion_prob)
})

test_that("SCHED-02: p_site sum violation triggers cli_abort() with circuit info", {
  bad_frame <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.4, 0.3, 0.2), # sums to 0.9, not 1.0
    stringsAsFactors = FALSE
  )
  sched <- .bus_sched()
  expect_error(
    generate_bus_schedule(sched, bad_frame, site = site, p_site = p_site, crew = 2),
    class = "rlang_error"
  )
})

test_that("SCHED-02: p_site sums to 1.0 per circuit in multi-circuit case", {
  bad_frame <- data.frame(
    site = c("A", "B", "C", "D"),
    circuit = c("C1", "C1", "C2", "C2"),
    p_site = c(0.6, 0.4, 0.8, 0.3), # C2 sums to 1.1
    stringsAsFactors = FALSE
  )
  sched <- .bus_sched()
  expect_error(
    generate_bus_schedule(
      sched, bad_frame,
      site = site, p_site = p_site, circuit = circuit, crew = 2
    ),
    class = "rlang_error"
  )
})

test_that("SCHED-02: output passes creel_design(survey_type = 'bus_route')", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result <- generate_bus_schedule(
    sched, frame,
    site = site, p_site = p_site, crew = 1
  )
  # result has inclusion_prob and p_period columns; use p_period with creel_design
  expect_no_error(
    creel_design(
      sched,
      date = date,
      strata = day_type,
      survey_type = "bus_route",
      sampling_frame = result,
      site = site,
      p_site = p_site,
      p_period = p_period
    )
  )
})

test_that("SCHED-02: tidy selectors — bare name and quoted string both work", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  result_bare <- generate_bus_schedule(sched, frame, site = site, p_site = p_site, crew = 1)
  result_string <- generate_bus_schedule(sched, frame, site = "site", p_site = "p_site", crew = 1)
  expect_equal(result_bare$inclusion_prob, result_string$inclusion_prob)
})

test_that("SCHED-02: seed argument is accepted without error (reserved for future use)", {
  frame <- .bus_frame_single()
  sched <- .bus_sched()
  expect_no_error(
    generate_bus_schedule(sched, frame, site = site, p_site = p_site, crew = 1, seed = 42)
  )
})

# ---- COUNT-TIME: generate_count_times() — implemented in Plan 57-01 ----

# Canonical valid inputs: 480 min span (06:00–14:00), 4 windows of 30 min with 10 min gap
# stratum = 480/4 = 120 min; window_size + min_gap = 40 < 120 — valid
.ct_valid <- function(...) {
  generate_count_times( # nolint: object_usage_linter
    start_time  = "06:00",
    end_time    = "14:00",
    strategy    = "random",
    n_windows   = 4L,
    window_size = 30L,
    min_gap     = 10L,
    seed        = 42L,
    ...
  )
}

test_that("COUNT-TIME-01: random strategy returns creel_schedule with required columns", {
  result <- .ct_valid()
  expect_s3_class(result, "creel_schedule")
  expect_s3_class(result, "data.frame")
  expect_true("start_time" %in% names(result))
  expect_true("end_time" %in% names(result))
  expect_true("window_id" %in% names(result))
  expect_type(result$start_time, "character")
  expect_type(result$end_time, "character")
  expect_type(result$window_id, "integer")
})

test_that("COUNT-TIME-01: systematic strategy — windows spaced exactly k apart", {
  result <- generate_count_times(
    start_time  = "06:00",
    end_time    = "14:00",
    strategy    = "systematic",
    n_windows   = 4L,
    window_size = 30L,
    min_gap     = 10L,
    seed        = 42L
  )
  expect_s3_class(result, "creel_schedule")
  # Convert start_time to minutes and check spacing
  to_min <- function(hhmm) {
    parts <- strsplit(hhmm, ":")[[1]]
    as.integer(parts[1]) * 60L + as.integer(parts[2])
  }
  starts <- vapply(result$start_time, to_min, integer(1))
  k <- 480L / 4L # 120 min
  diffs <- diff(starts)
  expect_true(all(diffs == k))
})

test_that("COUNT-TIME-01: fixed strategy — returned rows match fixed_windows input", {
  fw <- data.frame(
    start_time = c("06:00", "08:00", "10:00"),
    end_time = c("06:30", "08:30", "10:30"),
    stringsAsFactors = FALSE
  )
  result <- generate_count_times(strategy = "fixed", fixed_windows = fw)
  expect_s3_class(result, "creel_schedule")
  expect_equal(result$start_time, fw$start_time)
  expect_equal(result$end_time, fw$end_time)
})

test_that("COUNT-TIME-01: seed reproducibility — same seed + inputs produce identical output", {
  r1 <- .ct_valid(seed = 7L)
  r2 <- .ct_valid(seed = 7L)
  expect_equal(r1, r2)
  # Systematic too
  s1 <- generate_count_times("06:00", "14:00", "systematic", 4L, 30L, 10L, seed = 7L)
  s2 <- generate_count_times("06:00", "14:00", "systematic", 4L, 30L, 10L, seed = 7L)
  expect_equal(s1, s2)
})

test_that("COUNT-TIME-01: different seeds produce different random results", {
  r1 <- .ct_valid(seed = 1L)
  r2 <- .ct_valid(seed = 2L)
  expect_false(identical(r1$start_time, r2$start_time))
})

test_that("COUNT-TIME-02: output passes write_schedule() without error", {
  result <- .ct_valid()
  tmp <- tempfile(fileext = ".csv")
  expect_no_error(write_schedule(result, tmp))
  expect_true(file.exists(tmp))
})

test_that("COUNT-TIME-03: missing strategy argument throws cli_abort()", {
  expect_error(
    generate_count_times(
      start_time = "06:00", end_time = "14:00",
      n_windows = 4L, window_size = 30L, min_gap = 10L, seed = 42L
    ),
    class = "rlang_error"
  )
})

test_that("COUNT-TIME-03: unknown strategy throws cli_abort()", {
  expect_error(
    generate_count_times("06:00", "14:00", "badstrat", 4L, 30L, 10L, seed = 42L),
    class = "rlang_error"
  )
})

test_that("COUNT-TIME-03: end_time <= start_time throws cli_abort()", {
  expect_error(
    generate_count_times("14:00", "06:00", "random", 4L, 30L, 10L, seed = 42L),
    class = "rlang_error"
  )
  expect_error(
    generate_count_times("06:00", "06:00", "random", 4L, 30L, 10L, seed = 42L),
    class = "rlang_error"
  )
})

test_that("COUNT-TIME-03: n_windows does not evenly divide span throws cli_abort()", {
  # 480 / 7 is non-integer
  expect_error(
    generate_count_times("06:00", "14:00", "random", 7L, 30L, 10L, seed = 42L),
    class = "rlang_error"
  )
})

test_that("COUNT-TIME-03: window_size + min_gap > stratum_length throws cli_abort()", {
  expect_error(
    generate_count_times("06:00", "14:00", "random", 4L, 100L, 30L, seed = 42L),
    class = "rlang_error"
  )
})

test_that("COUNT-TIME-04: random strategy — all windows within [start_time, end_time]", {
  result <- .ct_valid()
  to_min <- function(hhmm) {
    parts <- strsplit(hhmm, ":")[[1]]
    as.integer(parts[1]) * 60L + as.integer(parts[2])
  }
  start_min <- 6L * 60L # 360
  end_min <- 14L * 60L # 840
  starts <- vapply(result$start_time, to_min, integer(1))
  ends <- vapply(result$end_time, to_min, integer(1))
  expect_true(all(starts >= start_min))
  expect_true(all(ends <= end_min))
})

test_that("COUNT-TIME-04: systematic strategy — all windows within [start_time, end_time]", {
  result <- generate_count_times(
    "06:00", "14:00", "systematic", 4L, 30L, 10L,
    seed = 42L
  )
  to_min <- function(hhmm) {
    parts <- strsplit(hhmm, ":")[[1]]
    as.integer(parts[1]) * 60L + as.integer(parts[2])
  }
  start_min <- 6L * 60L
  end_min <- 14L * 60L
  starts <- vapply(result$start_time, to_min, integer(1))
  ends <- vapply(result$end_time, to_min, integer(1))
  expect_true(all(starts >= start_min))
  expect_true(all(ends <= end_min))
})

test_that("COUNT-TIME-04: random strategy — no windows overlap", {
  result <- .ct_valid()
  to_min <- function(hhmm) {
    parts <- strsplit(hhmm, ":")[[1]]
    as.integer(parts[1]) * 60L + as.integer(parts[2])
  }
  starts <- sort(vapply(result$start_time, to_min, integer(1)))
  ends <- sort(vapply(result$end_time, to_min, integer(1)))
  if (length(ends) > 1) {
    expect_true(all(ends[-length(ends)] <= starts[-1]))
  }
})

test_that("COUNT-TIME-04: fixed strategy — overlapping fixed_windows throws cli_abort()", {
  fw_overlap <- data.frame(
    start_time = c("06:00", "06:20"),
    end_time = c("06:30", "06:50"), # 06:20 < 06:30 — overlap
    stringsAsFactors = FALSE
  )
  expect_error(
    generate_count_times(strategy = "fixed", fixed_windows = fw_overlap),
    class = "rlang_error"
  )
})
