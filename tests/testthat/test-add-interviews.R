# Test helpers ----

#' Create test calendar data covering July 1-14, 2025 with weekday/weekend strata
#' Must have 2+ dates per stratum for valid survey design
make_interview_test_calendar <- function() {
  dates <- seq(as.Date("2025-07-01"), as.Date("2025-07-14"), by = "day")
  data.frame(
    date = dates,
    day_type = ifelse(
      weekdays(dates) %in% c("Saturday", "Sunday"), "weekend", "weekday"
    ),
    stringsAsFactors = FALSE
  )
}

#' Create test interview data matching calendar dates
make_test_interviews <- function() {
  data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-03", "2025-07-04",
      "2025-07-05", "2025-07-06", "2025-07-07", "2025-07-08",
      "2025-07-09", "2025-07-10"
    )),
    hours_fished = c(2.0, 2.5, 3.0, 1.5, 2.0, 2.5, 3.0, 1.5, 2.0, 2.5),
    catch_total = c(5, 3, 7, 2, 6, 4, 8, 1, 5, 3),
    catch_kept = c(2, 1, 5, 2, 4, 2, 6, 1, 3, 2),
    trip_status = c(
      "complete", "complete", "incomplete", "complete", "complete",
      "incomplete", "complete", "complete", "complete", "incomplete"
    ),
    trip_duration = c(2.0, 2.5, 1.5, 1.5, 2.0, 1.0, 3.0, 1.5, 2.0, 1.0),
    stringsAsFactors = FALSE
  )
}

make_interview_test_design <- function() {
  cal <- make_interview_test_calendar()
  creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
}

# add_interviews() happy path tests ----

test_that("add_interviews returns creel_design S3 class", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_s3_class(result, "creel_design")
})

test_that("add_interviews attaches interview data to $interviews slot", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_false(is.null(result$interviews))
  # Check that interviews have been joined with calendar data
  expect_true("day_type" %in% names(result$interviews))
})

test_that("add_interviews constructs interview survey.design2 object eagerly", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_false(is.null(result$interview_survey))
  expect_s3_class(result$interview_survey, "survey.design2")
})

test_that("add_interviews preserves immutability - original design unchanged", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_null(design$interviews)
  expect_null(design$interview_survey)
})

test_that("add_interviews works with named arguments", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(
    design,
    interviews = interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration
  )

  expect_s3_class(result, "creel_design")
  expect_false(is.null(result$interviews))
})

test_that("add_interviews retains all original design fields", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_identical(result$calendar, design$calendar)
  expect_identical(result$date_col, design$date_col)
  expect_identical(result$strata_cols, design$strata_cols)
  expect_identical(result$site_col, design$site_col)
  expect_identical(result$design_type, design$design_type)
})

test_that("add_interviews stores catch_col and effort_col correctly", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_equal(result$catch_col, "catch_total")
  expect_equal(result$effort_col, "hours_fished")
})

test_that("add_interviews stores interview_type correctly (defaults to access)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_equal(result$interview_type, "access")
})

test_that("add_interviews works without harvest column (harvest = NULL)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_null(result$harvest_col)
  expect_s3_class(result, "creel_design")
})

test_that("add_interviews stores harvest_col when provided", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration
  )

  expect_equal(result$harvest_col, "catch_kept")
})

test_that("add_interviews works when counts already attached (parallel streams)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # First add some counts
  counts <- data.frame(
    date = as.Date(c(
      "2025-07-01", "2025-07-02", "2025-07-05", "2025-07-06"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(15, 23, 45, 52)
  )
  design_with_counts <- add_counts(design, counts)

  # Then add interviews
  result <- add_interviews(
    design_with_counts, interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration
  )

  expect_false(is.null(result$counts))
  expect_false(is.null(result$interviews))
})

test_that("add_interviews joins interviews with calendar data (strata inherited)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  # Check that calendar strata are present in joined interviews
  expect_true("day_type" %in% names(result$interviews))
  # Check that interview dates have corresponding strata
  expect_true(all(!is.na(result$interviews$day_type)))
})

# Validation error tests ----

test_that("add_interviews errors when interviews already attached", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_error(
    add_interviews(result, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "already"
  )
})

test_that("add_interviews errors when design is not creel_design class", {
  interviews <- make_test_interviews()
  fake_design <- list(calendar = make_interview_test_calendar())

  expect_error(
    add_interviews(fake_design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "creel_design"
  )
})

test_that("add_interviews errors when interview data has no Date column", {
  design <- make_interview_test_design()
  bad_interviews <- data.frame(
    day = c("2025-07-01", "2025-07-02"),
    catch_total = c(10, 20),
    hours_fished = c(2.0, 2.5)
  )

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "Date"
  )
})

test_that("add_interviews errors when interview data has no numeric column", {
  design <- make_interview_test_design()
  bad_interviews <- data.frame(
    date = as.Date(c("2025-07-01", "2025-07-02")),
    description = c("weekday", "weekend")
  )

  expect_error(
    add_interviews(design, bad_interviews, catch = description, effort = description),
    "numeric"
  )
})

test_that("add_interviews errors when date_col from design not found in interview data", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  names(bad_interviews)[names(bad_interviews) == "date"] <- "survey_date"

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "date"
  )
})

test_that("add_interviews errors when catch column not found in data", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  names(bad_interviews)[names(bad_interviews) == "catch_total"] <- "total_catch"

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "catch_total"
  )
})

test_that("add_interviews errors when effort column not found in data", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  names(bad_interviews)[names(bad_interviews) == "hours_fished"] <- "effort_hours"

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "hours_fished"
  )
})

test_that("add_interviews errors when date column contains NA values", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  bad_interviews$date[2] <- NA

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "NA"
  )
})

test_that("add_interviews errors when interview dates not in calendar", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  # Add a date outside the calendar range
  bad_interviews$date[1] <- as.Date("2025-08-01")

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "not found in design calendar"
  )
})

test_that("add_interviews errors when harvest > catch", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  # Make harvest exceed catch for one row
  bad_interviews$catch_kept[1] <- 10
  bad_interviews$catch_total[1] <- 5

  expect_error(
    add_interviews(
      design, bad_interviews,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, trip_duration = trip_duration
    ),
    "Harvest exceeds catch"
  )
})

# Survey design construction tests ----

test_that("interview_survey has correct class (survey.design2)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_s3_class(result$interview_survey, "survey.design2")
})

test_that("interview_survey uses ~1 for ids (terminal units, no clustering)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  # Check that ids formula is ~1 (terminal sampling units)
  expect_equal(as.character(result$interview_survey$call$ids), c("~", "1"))
})

test_that("interview_survey has correct strata (from calendar join)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  # Survey object should have strata based on day_type
  expect_true(!is.null(result$interview_survey$strata))
})

# Validation storage tests ----

test_that("add_interviews stores validation results in $validation slot", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_s3_class(result$validation, "creel_validation")
})

test_that("validation$passed is TRUE when interviews are valid", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_true(result$validation$passed)
})

test_that("validation$tier is 1L (integer Tier 1)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_identical(result$validation$tier, 1L)
})

# Example dataset integration tests ----

test_that("example_interviews works with example_calendar in complete workflow", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type)
  result <- suppressWarnings({
    add_interviews(design, example_interviews,
      catch = catch_total,
      effort = hours_fished,
      harvest = catch_kept,
      trip_status = trip_status,
      trip_duration = trip_duration
    )
  })

  expect_s3_class(result, "creel_design")
  expect_false(is.null(result$interviews))
  expect_false(is.null(result$interview_survey))
  expect_equal(result$catch_col, "catch_total")
  expect_equal(result$effort_col, "hours_fished")
  expect_equal(result$harvest_col, "catch_kept")
  expect_equal(result$interview_type, "access")
})

test_that("example_interviews has expected structure", {
  data(example_interviews, package = "tidycreel")

  expect_s3_class(example_interviews, "data.frame")
  expect_true(nrow(example_interviews) > 0)
  expect_true("date" %in% names(example_interviews))
  expect_true("hours_fished" %in% names(example_interviews))
  expect_true("catch_total" %in% names(example_interviews))
  expect_true("catch_kept" %in% names(example_interviews))
  expect_true(inherits(example_interviews$date, "Date"))
  expect_true(is.numeric(example_interviews$hours_fished))
  expect_true(is.numeric(example_interviews$catch_total))
  expect_true(is.numeric(example_interviews$catch_kept))
  # Validate catch_kept <= catch_total
  expect_true(all(example_interviews$catch_kept <= example_interviews$catch_total))
})

# Trip metadata validation tests ----

test_that("add_interviews stores trip_status_col in design object", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_equal(result$trip_status_col, "trip_status")
})

test_that("add_interviews stores trip_duration_col in design object", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)

  expect_equal(result$trip_duration_col, "trip_duration")
})

test_that("trip_status normalized to lowercase (uppercase input)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_status <- c(
    "Complete", "COMPLETE", "INCOMPLETE", "Complete", "Complete",
    "incomplete", "COMPLETE", "Complete", "complete", "Incomplete"
  )

  result <- suppressWarnings({
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)
  })

  # Check all values are lowercase
  expect_true(all(result$interviews$trip_status %in% c("complete", "incomplete")))
})

test_that("case-insensitive trip_status accepted (Complete, COMPLETE, complete)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_status <- c(
    "Complete", "COMPLETE", "complete", "Incomplete", "INCOMPLETE",
    "incomplete", "Complete", "complete", "INCOMPLETE", "Incomplete"
  )

  # Should not error (message is expected informational output)
  expect_no_error({
    result <- suppressWarnings({
      add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)
    })
  })
})

test_that("trip status summary message emitted", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  expect_message(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "Added.*interview"
  )
})

test_that("trip status summary message shows correct counts", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # 7 complete, 3 incomplete
  expect_message(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "7 complete.*3 incomplete"
  )
})

test_that("trip status summary message shows correct percentages", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # 7 complete (70%), 3 incomplete (30%)
  expect_message(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "70%.*30%"
  )
})

test_that("duration calculated from trip_start + interview_time (POSIXct)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # Add POSIXct times instead of duration
  interviews$trip_start <- as.POSIXct("2025-07-01 08:00:00") + (0:9) * 3600 * 24
  interviews$interview_time <- interviews$trip_start + interviews$trip_duration * 3600
  interviews$trip_duration <- NULL # Remove direct duration

  result <- suppressWarnings({
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start, interview_time = interview_time
    )
  })

  # Check that .trip_duration_hrs was created
  expect_true(".trip_duration_hrs" %in% names(result$interviews))
  expect_equal(result$trip_duration_col, ".trip_duration_hrs")
})

test_that("calculated duration stored as numeric hours", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # Add POSIXct times
  interviews$trip_start <- as.POSIXct("2025-07-01 08:00:00")
  interviews$interview_time <- as.POSIXct("2025-07-01 10:30:00") # 2.5 hours later
  interviews$trip_duration <- NULL

  result <- suppressWarnings({
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start, interview_time = interview_time
    )
  })

  # Calculated duration should be numeric and approximately 2.5 hours
  expect_true(is.numeric(result$interviews[[result$trip_duration_col]]))
  expect_equal(result$interviews[[result$trip_duration_col]][1], 2.5, tolerance = 0.01)
})

test_that("trip_start_col and interview_time_col stored when provided", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # Add POSIXct times
  interviews$trip_start <- as.POSIXct("2025-07-01 08:00:00") + (0:9) * 3600 * 24
  interviews$interview_time <- interviews$trip_start + interviews$trip_duration * 3600
  interviews$trip_duration <- NULL

  result <- suppressWarnings({
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start, interview_time = interview_time
    )
  })

  expect_equal(result$trip_start_col, "trip_start")
  expect_equal(result$interview_time_col, "interview_time")
})

# Validation error tests ----

test_that("error when trip_status column has invalid values", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_status[1] <- "finished"

  expect_error(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "invalid value.*finished"
  )
})

test_that("error when trip_status column has NA values", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_status[1] <- NA

  expect_error(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "NA value"
  )
})

test_that("error when both trip_duration AND trip_start are provided (mutually exclusive)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  # Add both duration and times (should error)
  interviews$trip_start <- as.POSIXct("2025-07-01 08:00:00") + (0:9) * 3600 * 24
  interviews$interview_time <- interviews$trip_start + interviews$trip_duration * 3600

  expect_error(
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_duration = trip_duration,
      trip_start = trip_start, interview_time = interview_time
    ),
    "Provide either.*not both"
  )
})

test_that("error when trip_start provided without interview_time", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  interviews$trip_start <- as.POSIXct("2025-07-01 08:00:00") + (0:9) * 3600 * 24
  interviews$trip_duration <- NULL

  expect_error(
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start
    ),
    "trip_start requires interview_time"
  )
})

test_that("error when interview_time provided without trip_start", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  interviews$interview_time <- as.POSIXct("2025-07-01 10:00:00") + (0:9) * 3600 * 24
  interviews$trip_duration <- NULL

  expect_error(
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, interview_time = interview_time
    ),
    "interview_time requires trip_start"
  )
})

test_that("error when trip_duration has negative values", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_duration[1] <- -1.0

  expect_error(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "negative values"
  )
})

test_that("error when trip_duration < 1/60 hours (less than 1 minute)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_duration[1] <- 0.01 # 0.6 minutes

  expect_error(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "less than 1 minute"
  )
})

test_that("error when trip_duration has NA values", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_duration[1] <- NA

  expect_error(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "NA value"
  )
})

test_that("error when calculated duration is negative (interview_time < trip_start)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  interviews$trip_start <- as.POSIXct("2025-07-01 10:00:00")
  interviews$interview_time <- as.POSIXct("2025-07-01 08:00:00") # Before trip_start
  interviews$trip_duration <- NULL

  expect_error(
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start, interview_time = interview_time
    ),
    "negative"
  )
})

test_that("error when calculated duration < 1 minute", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  interviews$trip_start <- as.POSIXct("2025-07-01 08:00:00")
  interviews$interview_time <- as.POSIXct("2025-07-01 08:00:30") # 30 seconds later
  interviews$trip_duration <- NULL

  expect_error(
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start, interview_time = interview_time
    ),
    "less than 1 minute"
  )
})

test_that("error when trip_start/interview_time are not POSIXct", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  interviews$trip_start <- "2025-07-01 08:00:00" # Character, not POSIXct
  interviews$interview_time <- "2025-07-01 10:00:00"
  interviews$trip_duration <- NULL

  expect_error(
    add_interviews(design, interviews,
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_start = trip_start, interview_time = interview_time
    ),
    "POSIXct"
  )
})

test_that("warning when trip_duration > 48 hours", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()
  interviews$trip_duration[1] <- 50.0 # 50 hours

  expect_warning(
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration),
    "48 hours"
  )
})

# Format display test ----

test_that("format.creel_design() shows trip status summary when trip metadata present", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- suppressWarnings({
    add_interviews(design, interviews, catch = catch_total, effort = hours_fished, trip_status = trip_status, trip_duration = trip_duration)
  })

  formatted <- format(result)

  # Check that trip status is mentioned in the formatted output
  expect_true(any(grepl("Trip status", formatted)))
  expect_true(any(grepl("complete", formatted)))
  expect_true(any(grepl("incomplete", formatted)))
})
