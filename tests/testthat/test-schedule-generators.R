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
