# Test helpers ----

#' Create test calendar data with 4+ rows per stratum
make_test_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
}

#' Create test count data matching test calendar structure
#' Each day_type stratum has at least 2 distinct dates (PSUs)
make_test_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    count = c(15, 23, 18, 21, 45, 52, 48, 51),
    stringsAsFactors = FALSE
  )
}

#' Create test creel_design
make_test_design <- function() {
  cal <- make_test_calendar()
  creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
}

# add_counts() happy path tests ----

test_that("add_counts returns creel_design S3 class", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_s3_class(result, "creel_design")
})

test_that("add_counts attaches count data to $counts slot", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_false(is.null(result$counts))
  expect_identical(result$counts, counts)
})

test_that("add_counts constructs svydesign object eagerly", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_false(is.null(result$survey))
  expect_s3_class(result$survey, "survey.design2")
})

test_that("add_counts preserves immutability - original design unchanged", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_null(design$counts)
  expect_null(design$survey)
})

test_that("add_counts works with named arguments", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts = counts)

  expect_s3_class(result, "creel_design")
  expect_false(is.null(result$counts))
})

test_that("add_counts retains all original design fields", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_identical(result$calendar, design$calendar)
  expect_identical(result$date_col, design$date_col)
  expect_identical(result$strata_cols, design$strata_cols)
  expect_identical(result$site_col, design$site_col)
  expect_identical(result$design_type, design$design_type)
})

# add_counts() validation error tests ----

test_that("add_counts errors when counts already attached", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_error(
    add_counts(result, counts),
    "already"
  )
})

test_that("add_counts errors when design is not creel_design class", {
  counts <- make_test_counts()
  fake_design <- list(calendar = make_test_calendar())

  expect_error(
    add_counts(fake_design, counts),
    "creel_design"
  )
})

test_that("add_counts errors when count data has no Date column", {
  design <- make_test_design()
  bad_counts <- data.frame(
    day = c("2024-06-01", "2024-06-02"),
    count = c(10, 20)
  )

  expect_error(
    add_counts(design, bad_counts),
    "Date"
  )
})

test_that("add_counts errors when count data has no numeric column", {
  design <- make_test_design()
  bad_counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    description = c("weekday", "weekend")
  )

  expect_error(
    add_counts(design, bad_counts),
    "numeric"
  )
})

test_that("add_counts errors when date_col from design not in count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  names(bad_counts)[names(bad_counts) == "date"] <- "survey_date"

  expect_error(
    add_counts(design, bad_counts),
    "date"
  )
})

test_that("add_counts errors when strata_cols from design not in count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  names(bad_counts)[names(bad_counts) == "day_type"] <- "stratum"

  expect_error(
    add_counts(design, bad_counts),
    "day_type"
  )
})

test_that("add_counts errors when PSU column not in count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  names(bad_counts)[names(bad_counts) == "date"] <- "survey_date"

  expect_error(
    add_counts(design, bad_counts, psu = "date"),
    "PSU|date"
  )
})

test_that("add_counts errors when date column contains NA values", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  bad_counts$date[2] <- NA

  expect_error(
    add_counts(design, bad_counts),
    "NA"
  )
})

test_that("add_counts errors when strata columns contain NA values", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  bad_counts$day_type[3] <- NA

  expect_error(
    add_counts(design, bad_counts),
    "NA"
  )
})

# construct_survey_design() tests ----

test_that("construct_survey_design returns survey.design2 object", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_s3_class(result$survey, "survey.design2")
})

test_that("survey object has correct strata - single stratum", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  # Survey object should have strata based on day_type
  expect_true(!is.null(result$survey$strata))
})

test_that("survey object has correct strata - multiple strata", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    season = rep(c("spring", "summer"), 4)
  )
  design <- creel_design(cal, date = date, strata = c(day_type, season)) # nolint: object_usage_linter

  counts <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    season = rep(c("spring", "summer"), 4),
    count = c(15, 23, 18, 21, 45, 52, 48, 51)
  )

  result <- add_counts(design, counts)

  # Survey object should combine multiple strata via interaction
  expect_true(!is.null(result$survey$strata))
})

test_that("construct_survey_design allows lonely PSU (errors caught during estimation)", {
  # Create design with lonely PSU - only one date per stratum
  # Note: survey package doesn't error during construction, only during variance estimation
  # This is correct behavior - we catch lonely PSU errors in Phase 4 estimation functions
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    day_type = c("weekday", "weekend"),
    count = c(15, 45)
  )

  # Should construct successfully - lonely PSU errors happen during estimation
  result <- add_counts(design, counts)
  expect_s3_class(result, "creel_design")
  expect_s3_class(result$survey, "survey.design2")
})

# Validation storage tests ----

test_that("add_counts stores validation results in $validation slot", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_s3_class(result$validation, "creel_validation")
})

test_that("validation$passed is TRUE when counts are valid", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_true(result$validation$passed)
})

test_that("validation$tier is 1L (integer Tier 1)", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_identical(result$validation$tier, 1L)
})

# Error handling tests for construct_survey_design ----

test_that("add_counts errors gracefully when PSU column missing from count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  # Remove date column (which is default PSU)
  bad_counts <- bad_counts[, setdiff(names(bad_counts), "date")]

  # Should error with friendly message about missing PSU column
  expect_error(
    add_counts(design, bad_counts, psu = "date"),
    "PSU|date|column"
  )
})

test_that("add_counts errors gracefully when strata column missing from count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  # Remove strata column
  bad_counts <- bad_counts[, setdiff(names(bad_counts), "day_type")]

  # Should error with friendly message about missing strata column
  expect_error(
    add_counts(design, bad_counts),
    "day_type|strata|column"
  )
})

# Multiple counts per PSU (Phase 36) ----

test_that("add_counts() accepts count_time_col without error (CNT-02)", {
  counts_am <- example_counts
  counts_am$count_time <- "am"
  counts_pm <- example_counts
  counts_pm$count_time <- "pm"
  multi_counts <- rbind(counts_am, counts_pm)
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  expect_no_error(
    add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter
  )
})

test_that("add_counts() with count_time_col reduces counts to one row per PSU (EFF-03)", {
  # Build two-count-per-day data
  counts_am <- example_counts
  counts_am$count_time <- "am"
  counts_pm <- example_counts
  counts_pm$count_time <- "pm"
  counts_pm$effort_hours <- counts_pm$effort_hours + 2 # different values per count
  multi_counts <- rbind(counts_am, counts_pm)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter

  # After aggregation: one row per unique PSU (date x strata)
  expect_equal(nrow(d$counts), nrow(example_counts))
})

test_that("add_counts() stores within_day_var slot with ss_d and k_d columns", {
  counts_am <- example_counts
  counts_am$count_time <- "am"
  counts_pm <- example_counts
  counts_pm$count_time <- "pm"
  counts_pm$effort_hours <- counts_pm$effort_hours + 4
  multi_counts <- rbind(counts_am, counts_pm)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter

  expect_false(is.null(d$within_day_var))
  expect_true(all(c("ss_d", "k_d") %in% names(d$within_day_var)))
  expect_equal(nrow(d$within_day_var), nrow(example_counts))
  expect_true(all(d$within_day_var$k_d == 2L))
})

test_that("add_counts() single-count path produces NULL within_day_var (CNT-04)", {
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, example_counts)

  expect_null(d$within_day_var)
  expect_null(d$count_time_col)
})

test_that("add_counts() warns on duplicate PSU rows when count_time_col = NULL (CNT-06)", {
  # Duplicate every row to simulate forgotten count_time_col
  dup_counts <- rbind(example_counts, example_counts)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  expect_warning(
    add_counts(design, dup_counts),
    regexp = "Duplicate PSU values"
  )
})

test_that("add_counts() sets count_type slot to 'instantaneous' by default", {
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, example_counts)
  expect_equal(d$count_type, "instantaneous")
})

test_that("add_counts() aborts when count_type = 'progressive' and circuit_time = NULL (CNT-05)", {
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  expect_error(
    add_counts(design, example_counts, count_type = "progressive"),
    regexp = "circuit_time"
  )
})

#' Create progressive count data (raw angler counts + shift duration)
make_progressive_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    n_anglers = c(15L, 23L, 18L, 21L, 45L, 52L, 48L, 51L),
    shift_hours = rep(8, 8),
    stringsAsFactors = FALSE
  )
}

test_that("add_counts() accepts count_type = 'progressive' with required args (CNT-01)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  expect_no_error(
    add_counts(
      design, prog_counts,
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = shift_hours # nolint: object_usage_linter
    )
  )
})

test_that("add_counts() aborts when count_type = 'progressive' and period_length_col = NULL (CNT-05)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  expect_error(
    add_counts(design, prog_counts, count_type = "progressive", circuit_time = 2),
    regexp = "period_length_col"
  )
})

test_that("add_counts() replaces raw counts with Ê_d = count × period_length for progressive (EFF-02)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  # κ = 8 / 2 = 4; Ê_d = n_anglers × circuit_time × κ = n_anglers × shift_hours
  expected_effort <- prog_counts$n_anglers * prog_counts$shift_hours

  d <- add_counts(
    design, prog_counts,
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  expect_equal(d$counts$n_anglers, expected_effort, tolerance = 1e-10)
})

test_that("add_counts() drops period_length_col from design$counts after progressive computation", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  d <- add_counts(
    design, make_progressive_counts(),
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  expect_false("shift_hours" %in% names(d$counts))
})

test_that("add_counts() stores circuit_time and period_length_col slots (CNT-03)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  d <- add_counts(
    design, make_progressive_counts(),
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  expect_equal(d$circuit_time, 2)
  expect_equal(d$period_length_col, "shift_hours")
})

test_that("add_counts() aborts when count_time_col and count_type = 'progressive' combined", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  prog_counts$circuit_id <- rep(c("am", "pm"), length.out = nrow(prog_counts))
  expect_error(
    add_counts(
      design, prog_counts,
      count_time_col = circuit_id, # nolint: object_usage_linter
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = shift_hours # nolint: object_usage_linter
    ),
    regexp = "count_time_col.*progressive|progressive.*count_time_col"
  )
})

test_that("add_counts() aborts when period_length column contains non-positive values", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  bad_counts <- make_progressive_counts()
  bad_counts$shift_hours[1] <- 0
  expect_error(
    add_counts(
      design, bad_counts,
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = shift_hours # nolint: object_usage_linter
    ),
    regexp = "positive"
  )
})
