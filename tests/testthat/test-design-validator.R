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
  suppressWarnings(add_counts(d, example_counts, counts = n_anglers)) # nolint: object_usage_linter
}

make_design_with_interviews <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(add_counts(d, example_counts, counts = n_anglers)) # nolint: object_usage_linter
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
  d2 <- suppressWarnings(add_counts(d, example_counts, counts = n_anglers)) # nolint: object_usage_linter
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
  data(example_aerial_counts, package = "tidycreel")
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
  d <- suppressWarnings(
    creel_design(cal, # nolint: object_usage_linter
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "aerial", h_open = 14
    )
  )
  suppressWarnings(add_counts(d, example_aerial_counts, counts = n_anglers)) # nolint: object_usage_linter
}

make_camera_design <- function() {
  data(example_camera_counts, package = "tidycreel")
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
  d <- suppressWarnings(
    creel_design(cal, # nolint: object_usage_linter
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "camera"
    )
  )
  suppressWarnings(add_counts(d, example_camera_counts, counts = n_anglers)) # nolint: object_usage_linter
}

make_ice_design <- function() {
  data(example_ice_sampling_frame, package = "tidycreel")
  data(example_ice_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_ice_sampling_frame, # nolint: object_usage_linter
      date = date, strata = day_type, # nolint: object_usage_linter
      survey_type = "ice"
    )
  )
  suppressWarnings(
    add_interviews(d, example_ice_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
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
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("$missing_days is a tibble or data.frame", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("$low_n_strata is a tibble, data.frame, or NULL", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("design with all days sampled -> $missing_days has 0 rows", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("design missing a calendar day -> $missing_days has >= 1 row", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("aerial design -> $low_n_strata is NULL (no interview-based flags)", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("camera design -> $low_n_strata is NULL", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("ice design -> runs without error (no false-positive synthetic bus_route flags)", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("design with refused_col -> $refusals is non-NULL", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("design without refused_col -> $refusals is NULL", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("$passed is TRUE when no missing days and all strata >= n_min", {
    expect_true(FALSE, label = "stub: implement in Plan 03")
  })

  it("non-creel_design input triggers cli_abort()", {
    expect_error(
      check_completeness(list(not = "a creel_design"))
    )
  })
})
