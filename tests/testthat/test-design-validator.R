# Tests for validate_design() (VALID-01) and check_completeness() (QUAL-01)
# Phase 50 Plans 50-01 through 50-03
# This file: failing stubs only — implementation comes in Plans 02 and 03.

# --- Shared fixtures -----------------------------------------------------------

make_standard_design <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(add_counts(d, example_counts)) # nolint: object_usage_linter
}

make_design_with_interviews <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(add_counts(d, example_counts)) # nolint: object_usage_linter
  suppressWarnings(
    add_interviews(d2, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
}

make_design_with_refusals <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  example_interviews$refused <- FALSE
  example_interviews$refused[1] <- TRUE
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(add_counts(d, example_counts)) # nolint: object_usage_linter
  suppressWarnings(
    add_interviews(d2, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
}

make_aerial_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06", "2024-06-07",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend"
    ),
    stringsAsFactors = FALSE
  )
  aerial_counts <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06", "2024-06-07",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend"
    ),
    n_counted = c(39L, 32L, 29L, 35L, 28L, 45L, 52L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(
    creel_design(cal, # nolint: object_usage_linter
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "aerial", h_open = 14
    )
  )
  suppressWarnings(add_counts(d, aerial_counts)) # nolint: object_usage_linter
}

make_camera_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06", "2024-06-07",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend"
    ),
    stringsAsFactors = FALSE
  )
  camera_counts <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06", "2024-06-07",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend"
    ),
    ingress_count = c(48L, 55L, 43L, 50L, 37L, 62L, 70L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(
    creel_design(cal, # nolint: object_usage_linter
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
  suppressWarnings(add_counts(d, camera_counts)) # nolint: object_usage_linter
}

make_ice_design <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  interviews <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    hours_fished = c(2.0, 1.5, 3.0, 2.5),
    catch_total = c(1L, 2L, 0L, 3L),
    trip_status = c("complete", "complete", "complete", "complete"),
    n_counted = c(5L, 8L, 10L, 7L),
    n_interviewed = c(3L, 4L, 5L, 4L),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(
    creel_design(cal, # nolint: object_usage_linter
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "ice",
      effort_type = "time_on_ice",
      p_period = 0.5
    )
  )
  suppressMessages(suppressWarnings(
    add_interviews(d, interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      n_counted = n_counted, # nolint: object_usage_linter
      n_interviewed = n_interviewed # nolint: object_usage_linter
    )
  ))
}

# Pilot values consistent with creel_n_effort benchmark (Phase 49)
N_H <- c(weekday = 65L, weekend = 28L) # nolint: object_name_linter
YBAR_H <- c(weekday = 50, weekend = 60) # nolint: object_name_linter
S2_H <- c(weekday = 400, weekend = 500) # nolint: object_name_linter
CV_TARGET <- 0.20 # nolint: object_name_linter
# n_required from Phase 49 benchmark (cv_target = 0.20):
#   creel_n_effort gives weekday = 3, weekend = 2 (verified 2026-03-24)
N_PROPOSED_PASS <- c(weekday = 10L, weekend = 5L) # both strata pass  # nolint: object_name_linter
N_PROPOSED_FAIL <- c(weekday = 1L, weekend = 1L) # both strata warn/fail  # nolint: object_name_linter
N_PROPOSED_MIXED <- c(weekday = 10L, weekend = 1L) # weekday pass, weekend warn/fail  # nolint: object_name_linter

# ==============================================================================
# Block 1: validate_design() — VALID-01
# ==============================================================================

describe("validate_design() — VALID-01", {
  it("returns an object of class creel_design_report", {
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_PASS, cv_target = CV_TARGET # nolint: object_name_linter
    )
    expect_s3_class(r, "creel_design_report")
  })

  it("$results tibble has required columns", {
    # columns: stratum, status, n_proposed, n_required, cv_actual, cv_target, message
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_PASS, cv_target = CV_TARGET # nolint: object_name_linter
    )
    expect_named(r$results,
      c("stratum", "status", "n_proposed", "n_required", "cv_actual", "cv_target", "message"),
      ignore.order = FALSE
    )
    expect_equal(nrow(r$results), length(N_H)) # nolint: object_name_linter
  })

  it("stratum with n_proposed >= n_required gets status == 'pass'", {
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_PASS, cv_target = CV_TARGET # nolint: object_name_linter
    )
    expect_true(all(r$results$status == "pass"))
  })

  it("stratum with n_proposed < n_required gets status 'fail' or 'warn'", {
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_FAIL, cv_target = CV_TARGET # nolint: object_name_linter
    )
    expect_true(all(r$results$status %in% c("fail", "warn")))
  })

  it("cv_actual matches cv_from_n() output exactly (no duplicate formula)", {
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_PASS, cv_target = CV_TARGET # nolint: object_name_linter
    )
    # Check weekday stratum cv_actual matches direct cv_from_n() call
    expected_cv_weekday <- cv_from_n(
      "effort",
      n = N_PROPOSED_PASS[["weekday"]], # nolint: object_name_linter
      N_h = N_H["weekday"], ybar_h = YBAR_H["weekday"], s2_h = S2_H["weekday"] # nolint: object_name_linter
    )
    expect_equal(
      r$results$cv_actual[r$results$stratum == "weekday"],
      round(expected_cv_weekday, 4)
    )
  })

  it("$passed is TRUE when all strata pass", {
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_PASS, cv_target = CV_TARGET # nolint: object_name_linter
    )
    expect_true(r$passed)
  })

  it("$passed is FALSE when any stratum fails", {
    r <- validate_design(
      N_h = N_H, ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
      n_proposed = N_PROPOSED_FAIL, cv_target = CV_TARGET # nolint: object_name_linter
    )
    expect_false(r$passed)
  })

  it("non-data-frame sampling_frame input triggers cli_abort()", {
    expect_error(
      validate_design(
        N_h = "not_a_vector", ybar_h = YBAR_H, s2_h = S2_H, # nolint: object_name_linter
        n_proposed = N_PROPOSED_PASS, cv_target = CV_TARGET # nolint: object_name_linter
      )
    )
  })
})

# ==============================================================================
# Block 2: check_completeness() — QUAL-01
# ==============================================================================

describe("check_completeness() — QUAL-01", {
  it("returns an object of class creel_completeness_report", {
    d <- make_design_with_interviews()
    r <- suppressWarnings(check_completeness(d))
    expect_s3_class(r, "creel_completeness_report")
  })

  it("$missing_days is a tibble or data.frame", {
    d <- make_design_with_interviews()
    r <- suppressWarnings(check_completeness(d))
    expect_true(is.data.frame(r$missing_days))
  })

  it("$low_n_strata is a tibble, data.frame, or NULL", {
    d <- make_design_with_interviews()
    r <- suppressWarnings(check_completeness(d))
    expect_true(is.null(r$low_n_strata) || is.data.frame(r$low_n_strata))
  })

  it("design with all days sampled -> $missing_days has 0 rows", {
    d <- make_design_with_interviews()
    r <- suppressWarnings(check_completeness(d))
    expect_equal(nrow(r$missing_days), 0L)
  })

  it("design missing a calendar day -> $missing_days has >= 1 row", {
    # Build a design where calendar has more dates than counts
    data(example_calendar, package = "tidycreel")
    data(example_counts, package = "tidycreel")
    d <- suppressWarnings(
      creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
    )
    # Remove one count date so it's "missing"
    first_date <- unique(example_counts$date)[1]
    counts_trimmed <- example_counts[example_counts$date != first_date, ]
    d2 <- suppressWarnings(add_counts(d, counts_trimmed))
    r <- suppressWarnings(check_completeness(d2))
    expect_gte(nrow(r$missing_days), 1L)
  })

  it("aerial design -> $low_n_strata is NULL (no interview-based flags)", {
    d <- make_aerial_design()
    r <- suppressWarnings(check_completeness(d))
    expect_null(r$low_n_strata)
  })

  it("camera design -> $low_n_strata is NULL", {
    d <- make_camera_design()
    r <- suppressWarnings(check_completeness(d))
    expect_null(r$low_n_strata)
  })

  it("ice design -> runs without error (no false-positive synthetic bus_route flags)", {
    d <- make_ice_design()
    r <- suppressWarnings(check_completeness(d))
    expect_s3_class(r, "creel_completeness_report")
    expect_true(is.data.frame(r$missing_days))
  })

  it("design with refused_col -> $refusals is non-NULL", {
    d <- make_design_with_refusals()
    r <- suppressWarnings(check_completeness(d))
    expect_false(is.null(r$refusals))
    expect_s3_class(r$refusals, "creel_summary_refusals")
  })

  it("design without refused_col -> $refusals is NULL", {
    d <- make_design_with_interviews()
    r <- suppressWarnings(check_completeness(d))
    expect_null(r$refusals)
  })

  it("$passed is TRUE when no missing days and all strata >= n_min", {
    d <- make_design_with_interviews()
    # Use a very low n_min so all strata pass
    r <- suppressWarnings(check_completeness(d, n_min = 1L))
    # missing_days should be 0 rows for complete data
    if (nrow(r$missing_days) == 0L) {
      expect_true(r$passed)
    } else {
      skip("example data has missing days")
    }
  })

  it("non-creel_design input triggers cli_abort()", {
    expect_error(
      check_completeness(list(not = "a creel_design"))
    )
  })
})
