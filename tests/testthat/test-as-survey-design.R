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

#' Create test creel_design with counts already attached
make_test_design_with_counts <- function() {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- make_test_counts()
  add_counts(design, counts) # nolint: object_usage_linter
}

# as_survey_design() core tests ----

test_that("as_survey_design returns survey.design2 class object", {
  design <- make_test_design_with_counts()

  result <- as_survey_design(design) # nolint: object_usage_linter

  expect_s3_class(result, "survey.design2")
})

test_that("as_survey_design returns structurally valid survey object", {
  design <- make_test_design_with_counts()

  result <- as_survey_design(design) # nolint: object_usage_linter

  # Survey.design2 objects have specific components
  expect_true(!is.null(result$variables))
  expect_true(!is.null(result$strata))
  expect_true(!is.null(result$cluster))
})

test_that("as_survey_design errors when design has no counts", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  expect_error(
    as_survey_design(design), # nolint: object_usage_linter
    "add_counts"
  )
})

test_that("as_survey_design errors when argument is not creel_design", {
  fake_design <- list(counts = data.frame(count = 1:10))

  expect_error(
    as_survey_design(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

# Once-per-session warning tests ----

test_that("as_survey_design issues warning on first call", {
  design <- make_test_design_with_counts()

  # First call should warn
  expect_warning(
    as_survey_design(design), # nolint: object_usage_linter
    "advanced feature"
  )
})

test_that("as_survey_design warning mentions estimate_effort", {
  design <- make_test_design_with_counts()

  # Warning should mention the recommended function
  expect_warning(
    as_survey_design(design), # nolint: object_usage_linter
    "estimate_effort"
  )
})

test_that("as_survey_design does not warn on second call in same session", {
  design <- make_test_design_with_counts()

  # First call triggers warning (suppress it)
  suppressWarnings(as_survey_design(design)) # nolint: object_usage_linter

  # Second call should NOT warn
  expect_no_warning(as_survey_design(design)) # nolint: object_usage_linter
})

# Copy semantics test ----

test_that("modifying returned survey object does not affect design$survey", {
  design <- make_test_design_with_counts()

  # Get survey object
  svy <- suppressWarnings(as_survey_design(design)) # nolint: object_usage_linter

  # Record original number of columns
  original_ncol <- ncol(design$survey$variables)

  # Modify the returned object
  svy$variables$new_test_column <- 999

  # Check that original design$survey is unchanged
  expect_equal(ncol(design$survey$variables), original_ncol)
  expect_false("new_test_column" %in% names(design$survey$variables))
})

# Integration tests (full workflow) ----

test_that("full workflow produces numeric result from svytotal", {
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- make_test_counts()
  design2 <- add_counts(design, counts) # nolint: object_usage_linter

  svy <- suppressWarnings(as_survey_design(design2)) # nolint: object_usage_linter

  # survey::svytotal should work on the extracted design
  result <- survey::svytotal(~count, svy)

  expect_type(result, "double")
  expect_true(is.numeric(result))
})

test_that("survey total from as_survey_design matches manual svydesign construction", {
  # Construct design via tidycreel
  design <- make_test_design_with_counts()
  svy_tidycreel <- suppressWarnings(as_survey_design(design)) # nolint: object_usage_linter
  total_tidycreel <- survey::svytotal(~count, svy_tidycreel)

  # Construct same design manually with survey package
  counts <- make_test_counts()
  svy_manual <- survey::svydesign(
    ids = ~date,
    strata = ~day_type,
    data = counts,
    nest = TRUE
  )
  total_manual <- survey::svytotal(~count, svy_manual)

  # Estimates should match
  expect_equal(as.numeric(total_tidycreel), as.numeric(total_manual))
})

test_that("multiple strata workflow works with as_survey_design", {
  # Create design with multiple strata
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

  design2 <- add_counts(design, counts) # nolint: object_usage_linter
  svy <- suppressWarnings(as_survey_design(design2)) # nolint: object_usage_linter

  # Should work with multiple strata
  result <- survey::svytotal(~count, svy)
  expect_true(is.numeric(result))
})
