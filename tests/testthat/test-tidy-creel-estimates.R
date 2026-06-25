# Tests for tidy.creel_estimates() — TIDY-01 through TIDY-05 ----------------

# Helper: build a bus-route creel_estimates via estimate_total_harvest_br
.make_br_harvest <- function() {
  set.seed(42L)
  d <- suppressMessages(suppressWarnings(
    build_br_design_for_tests(3L, 6L, 8L, seed = 42L)
  ))
  counts <- data.frame(
    date = d$calendar$date,
    day_type = d$calendar$day_type,
    effort_hours = c(15, 20, 18, 22, 16, 19),
    stringsAsFactors = FALSE
  )
  d2 <- suppressMessages(suppressWarnings(add_counts(d, counts)))
  suppressMessages(suppressWarnings(estimate_total_harvest(d2)))
}

# Helper: build a standard instantaneous creel_estimates via estimate_total_catch
.make_total_catch <- function() {
  data("example_calendar", package = "tidycreel", envir = parent.frame())
  data("example_counts", package = "tidycreel", envir = parent.frame())
  data("example_interviews", package = "tidycreel", envir = parent.frame())
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint
  )
  d <- suppressWarnings(add_counts(d, example_counts)) # nolint
  d <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint
      catch = catch_total, # nolint
      effort = hours_fished, # nolint
      trip_status = trip_status, # nolint
      trip_duration = trip_duration # nolint
    )
  )
  suppressWarnings(estimate_total_catch(d))
}

# ---- TIDY-01: estimate_total_harvest() dispatching estimate_total_harvest_br ----

test_that("TIDY-01: tidy(estimate_total_harvest_br) returns flat tibble", {
  result <- tidy(.make_br_harvest())
  expect_s3_class(result, "tbl_df")
  expect_false(any(vapply(result, is.list, logical(1L))))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result)))
  expect_gt(nrow(result), 0L)
})

# ---- TIDY-02: estimate_total_catch() ----------------------------------------

test_that("TIDY-02: tidy(estimate_total_catch) returns flat tibble", {
  result <- tidy(.make_total_catch())
  expect_s3_class(result, "tbl_df")
  expect_false(any(vapply(result, is.list, logical(1L))))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result)))
  expect_gt(nrow(result), 0L)
})

# ---- TIDY-03: estimate_angler_n() -------------------------------------------

test_that("TIDY-03: tidy(estimate_angler_n) returns flat tibble", {
  result <- tidy(estimate_angler_n(M = 200L, n = 50L, m = 10L))
  expect_s3_class(result, "tbl_df")
  expect_false(any(vapply(result, is.list, logical(1L))))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result)))
  expect_gt(nrow(result), 0L)
})

# ---- TIDY-04: estimate_mr_harvest() -----------------------------------------

test_that("TIDY-04: tidy(estimate_mr_harvest) returns flat tibble with n = NA", {
  angler_n <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  result <- tidy(estimate_mr_harvest(angler_n = angler_n, harvest_rate = 0.35))
  expect_s3_class(result, "tbl_df")
  expect_false(any(vapply(result, is.list, logical(1L))))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result)))
  expect_true(all(is.na(result$n)))
  expect_gt(nrow(result), 0L)
})

# ---- TIDY-05: estimate_exploitation_rate() ----------------------------------

test_that("TIDY-05: tidy(estimate_exploitation_rate) returns flat tibble", {
  result <- tidy(
    estimate_exploitation_rate(
      T = 200L,
      C = 450.0,
      se_C = 42.0,
      n = 180L,
      m = 15L
    )
  )
  expect_s3_class(result, "tbl_df")
  expect_false(any(vapply(result, is.list, logical(1L))))
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result)))
  expect_gt(nrow(result), 0L)
})
