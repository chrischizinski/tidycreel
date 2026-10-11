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

# as_tibble() / as.data.frame() for creel_estimates (#476) ---------------------
#
# A result has to leave the package as data: dplyr verbs do not dispatch on a
# creel_estimates list, and before #476 as_tibble() and as.data.frame() errored
# with "cannot coerce class". The conversion also has to keep what the numbers
# mean, so the metadata is copied into columns.

.effort_by_day_type <- function() {
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) |> # nolint
      add_counts(example_counts) # nolint
  )
  suppressWarnings(estimate_effort(d, by = day_type)) # nolint
}

.interview_design <- function() {
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) |> # nolint
      add_counts(example_counts) # nolint
  )
  suppressMessages(suppressWarnings(add_interviews(
    d, example_interviews, # nolint
    catch = catch_total, effort = hours_fished, # nolint
    trip_status = trip_status, trip_duration = trip_duration # nolint
  )))
}

test_that("as_tibble() turns estimates into a table dplyr can filter", {
  est <- .effort_by_day_type()
  tbl <- tibble::as_tibble(est)

  expect_s3_class(tbl, "tbl_df")
  expect_identical(nrow(tbl), nrow(est$estimates))
  # The numbers are the object's own, row for row, not recomputed.
  expect_identical(tbl$estimate, est$estimates$estimate)
  expect_identical(tbl$se, est$estimates$se)

  weekday <- dplyr::filter(tbl, day_type == "weekday")
  expect_identical(nrow(weekday), 1L)
  expect_identical(weekday$estimate, est$estimates$estimate[est$estimates$day_type == "weekday"])
})

test_that("metadata columns carry the object's method, variance, level, target and unit", {
  est <- .effort_by_day_type()
  tbl <- tibble::as_tibble(est)

  expect_true(all(tbl$method == est$method))
  expect_true(all(tbl$variance_method == est$variance_method))
  expect_true(all(tbl$conf_level == est$conf_level))
  expect_true(all(tbl$effort_target == est$effort_target))
  # unit is always present; NA there means "could not be derived", which is
  # what the object says too.
  expect_true("unit" %in% names(tbl))
  expect_identical(unique(tbl$unit), est$unit)
})

test_that("a field that does not apply gives no column, so NA always means unknown", {
  # Effort takes no estimator choice: no estimator column, rather than an NA
  # that would read as "unknown estimator".
  effort <- tibble::as_tibble(.effort_by_day_type())
  expect_false("estimator" %in% names(effort))

  # A rate has an estimator but totals over nothing: the reverse.
  rate <- suppressMessages(suppressWarnings(estimate_catch_rate(.interview_design()))) # nolint
  rate_tbl <- tibble::as_tibble(rate)
  expect_identical(unique(rate_tbl$estimator), rate$estimator)
  expect_false("effort_target" %in% names(rate_tbl))
})

test_that("mean-of-ratios results convert through the parent method", {
  # Thirty incomplete trips: enough for the mean-of-ratios estimator to run.
  cal <- data.frame(date = as.Date("2024-06-01") + 0:3, day_type = "weekday")
  interviews <- data.frame(
    date = as.Date("2024-06-01"),
    catch_total = rep(c(2, 3, 4, 5), length.out = 30),
    hours_fished = rep(c(2, 3, 4, 2.5), length.out = 30),
    trip_status = "incomplete",
    trip_duration = rep(c(2, 3, 4, 2.5), length.out = 30)
  )
  design <- suppressMessages(suppressWarnings(
    creel_design(cal, date = date, strata = day_type) |> # nolint
      add_interviews(interviews, # nolint
        catch = catch_total, effort = hours_fished, # nolint
        trip_status = trip_status, trip_duration = trip_duration # nolint
      )
  ))
  mor <- suppressMessages(suppressWarnings(estimate_catch_rate(design, estimator = "mor"))) # nolint
  expect_s3_class(mor, "creel_estimates_mor")
  tbl <- tibble::as_tibble(mor)

  expect_s3_class(tbl, "tbl_df")
  expect_identical(tbl$estimate, mor$estimates$estimate)
  expect_identical(unique(tbl$estimator), "mor")
})

test_that("metadata = FALSE returns the estimates table alone", {
  est <- .effort_by_day_type()
  expect_identical(
    tibble::as_tibble(est, metadata = FALSE),
    tibble::as_tibble(est$estimates)
  )
})

test_that("as.data.frame() gives the same content as a plain data frame", {
  est <- .effort_by_day_type()
  df <- as.data.frame(est)

  expect_identical(class(df), "data.frame")
  expect_identical(df, as.data.frame(tibble::as_tibble(est)))
})

test_that("a grouping column named like a metadata column is refused, not overwritten", {
  # A user's `by` column called `unit` (a management unit, say) would otherwise
  # be silently replaced by the measurement unit.
  est <- new_creel_estimates( # nolint: object_usage_linter
    estimates = tibble::tibble(
      unit = c("north", "south"), estimate = c(1, 2), se = c(0.1, 0.2),
      ci_lower = c(0.8, 1.6), ci_upper = c(1.2, 2.4), n = c(5L, 6L)
    ),
    unit = "angler-hours"
  )

  expect_error(tibble::as_tibble(est), class = "creel_error_invalid_input")
  expect_identical(tibble::as_tibble(est, metadata = FALSE)$unit, c("north", "south"))
})

test_that("building a count design no longer triggers survey's equal-probability warning", {
  # The design's unit weights are stated, not assumed by survey. The warning
  # reached every user on every count design, the README Quick Start included.
  expect_no_warning(
    creel_design(example_calendar, date = date, strata = day_type) |> # nolint
      add_counts(example_counts), # nolint
    message = "No weights or probabilities supplied"
  )
})
