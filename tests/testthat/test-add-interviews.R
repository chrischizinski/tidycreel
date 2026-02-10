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

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_s3_class(result, "creel_design")
})

test_that("add_interviews attaches interview data to $interviews slot", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_false(is.null(result$interviews))
  # Check that interviews have been joined with calendar data
  expect_true("day_type" %in% names(result$interviews))
})

test_that("add_interviews constructs interview survey.design2 object eagerly", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_false(is.null(result$interview_survey))
  expect_s3_class(result$interview_survey, "survey.design2")
})

test_that("add_interviews preserves immutability - original design unchanged", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_null(design$interviews)
  expect_null(design$interview_survey)
})

test_that("add_interviews works with named arguments", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(
    design, interviews = interviews,
    catch = catch_total, effort = hours_fished
  )

  expect_s3_class(result, "creel_design")
  expect_false(is.null(result$interviews))
})

test_that("add_interviews retains all original design fields", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_identical(result$calendar, design$calendar)
  expect_identical(result$date_col, design$date_col)
  expect_identical(result$strata_cols, design$strata_cols)
  expect_identical(result$site_col, design$site_col)
  expect_identical(result$design_type, design$design_type)
})

test_that("add_interviews stores catch_col and effort_col correctly", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_equal(result$catch_col, "catch_total")
  expect_equal(result$effort_col, "hours_fished")
})

test_that("add_interviews stores interview_type correctly (defaults to access)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_equal(result$interview_type, "access")
})

test_that("add_interviews works without harvest column (harvest = NULL)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_null(result$harvest_col)
  expect_s3_class(result, "creel_design")
})

test_that("add_interviews stores harvest_col when provided", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept
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
    catch = catch_total, effort = hours_fished
  )

  expect_false(is.null(result$counts))
  expect_false(is.null(result$interviews))
})

test_that("add_interviews joins interviews with calendar data (strata inherited)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  # Check that calendar strata are present in joined interviews
  expect_true("day_type" %in% names(result$interviews))
  # Check that interview dates have corresponding strata
  expect_true(all(!is.na(result$interviews$day_type)))
})

# Validation error tests ----

test_that("add_interviews errors when interviews already attached", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_error(
    add_interviews(result, interviews, catch = catch_total, effort = hours_fished),
    "already"
  )
})

test_that("add_interviews errors when design is not creel_design class", {
  interviews <- make_test_interviews()
  fake_design <- list(calendar = make_interview_test_calendar())

  expect_error(
    add_interviews(fake_design, interviews, catch = catch_total, effort = hours_fished),
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
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished),
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
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished),
    "date"
  )
})

test_that("add_interviews errors when catch column not found in data", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  names(bad_interviews)[names(bad_interviews) == "catch_total"] <- "total_catch"

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished),
    "catch_total"
  )
})

test_that("add_interviews errors when effort column not found in data", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  names(bad_interviews)[names(bad_interviews) == "hours_fished"] <- "effort_hours"

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished),
    "hours_fished"
  )
})

test_that("add_interviews errors when date column contains NA values", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  bad_interviews$date[2] <- NA

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished),
    "NA"
  )
})

test_that("add_interviews errors when interview dates not in calendar", {
  design <- make_interview_test_design()
  bad_interviews <- make_test_interviews()
  # Add a date outside the calendar range
  bad_interviews$date[1] <- as.Date("2025-08-01")

  expect_error(
    add_interviews(design, bad_interviews, catch = catch_total, effort = hours_fished),
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
      catch = catch_total, effort = hours_fished, harvest = catch_kept
    ),
    "Harvest exceeds catch"
  )
})

# Survey design construction tests ----

test_that("interview_survey has correct class (survey.design2)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_s3_class(result$interview_survey, "survey.design2")
})

test_that("interview_survey uses ~1 for ids (terminal units, no clustering)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  # Check that ids formula is ~1 (terminal sampling units)
  expect_equal(as.character(result$interview_survey$call$ids), c("~", "1"))
})

test_that("interview_survey has correct strata (from calendar join)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  # Survey object should have strata based on day_type
  expect_true(!is.null(result$interview_survey$strata))
})

# Validation storage tests ----

test_that("add_interviews stores validation results in $validation slot", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_s3_class(result$validation, "creel_validation")
})

test_that("validation$passed is TRUE when interviews are valid", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

  expect_true(result$validation$passed)
})

test_that("validation$tier is 1L (integer Tier 1)", {
  design <- make_interview_test_design()
  interviews <- make_test_interviews()

  result <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)

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
      harvest = catch_kept
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
