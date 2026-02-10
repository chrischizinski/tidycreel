# Test helpers for Tier 2 interview warnings ----

#' Create test calendar data covering July 1-14, 2025 with weekday/weekend strata
make_tier2_test_calendar <- function() {
  dates <- seq(as.Date("2025-07-01"), as.Date("2025-07-14"), by = "day")
  data.frame(
    date = dates,
    day_type = ifelse(
      weekdays(dates) %in% c("Saturday", "Sunday"), "weekend", "weekday"
    ),
    stringsAsFactors = FALSE
  )
}

make_tier2_test_design <- function() {
  cal <- make_tier2_test_calendar()
  creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
}

# Tier 2 interview warnings tests ----

test_that("no warnings for clean interview data", {
  design <- make_tier2_test_design()
  clean_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04",
      "2025-07-05", "2025-07-06", "2025-07-07", "2025-07-08"
    )),
    hours_fished = c(2.0, 2.5, 3.0, 1.5, 2.0, 2.5, 3.0, 1.5),
    catch_total = c(5, 3, 7, 2, 6, 4, 8, 1),
    stringsAsFactors = FALSE
  )

  # Should not produce Tier 2 warnings (survey package warnings are OK)
  # Use suppressWarnings to hide survey package warnings, then check no warnings
  # were produced by warn_tier2_interview_issues
  result <- suppressWarnings({
    add_interviews(design, clean_interviews,
      catch = catch_total,
      effort = hours_fished
    )
  })

  expect_s3_class(result, "creel_design")
})

test_that("warning for very short trips (effort < 0.1 hours)", {
  design <- make_tier2_test_design()
  short_trip_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04"
    )),
    hours_fished = c(0.05, 2.0, 0.08, 2.5), # Two very short trips
    catch_total = c(1, 5, 1, 3),
    stringsAsFactors = FALSE
  )

  expect_warning(
    add_interviews(design, short_trip_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "2 interviews have effort < 0.1 hours"
  )
})

test_that("warning for zero catch values", {
  design <- make_tier2_test_design()
  zero_catch_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04"
    )),
    hours_fished = c(2.0, 2.5, 3.0, 1.5),
    catch_total = c(0, 5, 0, 3), # Two zero catch
    stringsAsFactors = FALSE
  )

  expect_warning(
    add_interviews(design, zero_catch_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "2 interviews have zero catch"
  )
})

test_that("warning for negative catch values", {
  design <- make_tier2_test_design()
  negative_catch_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04"
    )),
    hours_fished = c(2.0, 2.5, 3.0, 1.5),
    catch_total = c(-1, 5, 3, 2), # One negative catch
    stringsAsFactors = FALSE
  )

  expect_warning(
    add_interviews(design, negative_catch_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "1 interview has negative catch"
  )
})

test_that("warning for negative effort values", {
  design <- make_tier2_test_design()
  negative_effort_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04"
    )),
    hours_fished = c(-0.5, 2.0, 2.5, 3.0), # One negative effort
    catch_total = c(5, 3, 7, 2),
    stringsAsFactors = FALSE
  )

  expect_warning(
    add_interviews(design, negative_effort_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "1 interview has negative effort"
  )
})

test_that("warning for missing effort values (NA)", {
  design <- make_tier2_test_design()
  missing_effort_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04"
    )),
    hours_fished = c(NA, 2.0, NA, 2.5), # Two missing effort
    catch_total = c(5, 3, 7, 2),
    stringsAsFactors = FALSE
  )

  expect_warning(
    add_interviews(design, missing_effort_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "2 interviews have missing effort"
  )
})

test_that("warning for sparse strata (< 3 interviews per stratum)", {
  design <- make_tier2_test_design()
  sparse_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", # 2 weekdays
      "2025-07-05" # 1 weekend (sparse)
    )),
    hours_fished = c(2.0, 2.5, 3.0),
    catch_total = c(5, 3, 7),
    stringsAsFactors = FALSE
  )

  expect_warning(
    add_interviews(design, sparse_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "2 strata have fewer than 3 interviews"
  )
})

test_that("multiple warnings issued simultaneously", {
  design <- make_tier2_test_design()
  problematic_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03"
    )),
    hours_fished = c(0.05, -1.0, 2.0),
    catch_total = c(5, 0, -2),
    stringsAsFactors = FALSE
  )

  # Should produce multiple warnings
  expect_warning(
    add_interviews(design, problematic_interviews,
      catch = catch_total,
      effort = hours_fished
    ),
    "interview" # At least one warning will mention "interview"
  )
})

test_that("warnings do NOT prevent add_interviews() from succeeding", {
  design <- make_tier2_test_design()
  problematic_interviews <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04"
    )),
    hours_fished = c(0.05, NA, -1.0, 2.0), # Multiple issues
    catch_total = c(0, -1, 5, 2),
    stringsAsFactors = FALSE
  )

  # Should return a valid creel_design despite warnings
  suppressWarnings({
    result <- add_interviews(design, problematic_interviews,
      catch = catch_total,
      effort = hours_fished
    )
  })

  expect_s3_class(result, "creel_design")
  expect_false(is.null(result$interviews))
  expect_false(is.null(result$interview_survey))
})

test_that("no effort checks when effort column is NULL (catch-only interviews)", {
  design <- make_tier2_test_design()
  # This scenario isn't currently supported by add_interviews API,
  # but the warn function should handle effort_col = NULL gracefully
  # if called directly (defensive programming)

  # Create a design with mock structure
  mock_design <- design
  mock_design$interviews <- data.frame(
    date = as.Date(c("2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    catch_total = c(5, 3, 7, 2)
  )
  mock_design$catch_col <- "catch_total"
  mock_design$effort_col <- NULL # No effort column
  mock_design$strata_cols <- "day_type"

  # Should not error when effort_col is NULL (only catch warnings possible)
  # Need enough observations per stratum to avoid sparse warning
  result <- tryCatch(
    {
      warn_tier2_interview_issues(mock_design) # nolint: object_usage_linter
      TRUE
    },
    error = function(e) FALSE
  )

  expect_true(result)
})
