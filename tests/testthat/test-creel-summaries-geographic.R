# Tests for geographic summary functions -- Phase 96 (RPT-03, RPT-04, RPT-05)

# --- Shared fixtures -----------------------------------------------------------

make_boat_composition_design <- function() {
  counts_df <- data.frame(
    date          = as.Date(c("2024-05-01", "2024-05-04",
                              "2024-06-01", "2024-06-08")),
    day_type      = c("weekday", "weekend", "weekday", "weekend"),
    angler_boats  = c(3L, 2L, 4L, 1L),
    non_ang_boats = c(1L, 2L, 1L, 3L),
    count         = c(10L, 12L, 9L, 8L)
  )
  cal <- data.frame(
    date     = counts_df$date,
    day_type = counts_df$day_type
  )
  d <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_counts(d, counts_df) # nolint: object_usage_linter
  )
}

make_boat_composition_schema <- function(
    ab_col = "angler_boats",
    nb_col = "non_ang_boats") {
  creel_schema(
    survey_type       = "instantaneous",
    angler_boats_col  = ab_col,
    non_ang_boats_col = nb_col
  )
}

# --- summarize_boat_composition() — RPT-03 ------------------------------------

test_that("summarize_boat_composition() returns creel_summary_boat_composition class", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_s3_class(result, "creel_summary_boat_composition")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_boat_composition() has columns month, day_type, n_events, pct_angler_boats", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(all(c("month", "day_type", "n_events", "pct_angler_boats") %in% names(result)))
})

test_that("summarize_boat_composition() n_events is integer, pct_angler_boats is numeric", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(is.integer(result$n_events))
  expect_true(is.numeric(result$pct_angler_boats))
})

test_that("summarize_boat_composition() pct_angler_boats is in [0, 100]", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(all(result$pct_angler_boats >= 0))
  expect_true(all(result$pct_angler_boats <= 100))
})

test_that("summarize_boat_composition() correct pct for known input", {
  # May weekday: AB=3, NB=1 -> 3/(3+1) = 0.75 -> 75.0%
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  may_weekday <- result[result$month == "May" & result$day_type == "weekday", ]
  expect_equal(may_weekday$pct_angler_boats, 75.0)
})

test_that("summarize_boat_composition() aborts when design is not creel_design", {
  s <- make_boat_composition_schema()
  expect_error(
    summarize_boat_composition(list(), s),
    regexp = "creel_design"
  )
})

test_that("summarize_boat_composition() aborts when design$counts is NULL", {
  # Build a design without add_counts()
  cal <- data.frame(
    date     = as.Date("2024-05-01"),
    day_type = "weekday"
  )
  d_no_counts <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  s <- make_boat_composition_schema()
  expect_error(
    summarize_boat_composition(d_no_counts, s),
    regexp = "add_counts"
  )
})

test_that("summarize_boat_composition() aborts when schema$angler_boats_col is NULL", {
  d <- make_boat_composition_design()
  s_no_ab <- creel_schema(
    survey_type       = "instantaneous",
    non_ang_boats_col = "non_ang_boats"
  )
  expect_error(
    summarize_boat_composition(d, s_no_ab),
    regexp = "angler_boats_col"
  )
})

test_that("summarize_boat_composition() aborts when schema$non_ang_boats_col is NULL", {
  d <- make_boat_composition_design()
  s_no_nb <- creel_schema(
    survey_type      = "instantaneous",
    angler_boats_col = "angler_boats"
  )
  expect_error(
    summarize_boat_composition(d, s_no_nb),
    regexp = "non_ang_boats_col"
  )
})

test_that("summarize_boat_composition() result has one row per month x day_type combination", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  # 2 months (May, June) x 2 day types (weekday, weekend) = 4 rows
  expect_equal(nrow(result), 4L)
})
