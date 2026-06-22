# Tests for add_ages() in R/creel-design.R
#
# age_uid is the interview foreign-key column in age data (mirrors length_uid
# in add_lengths), not a unique per-record ID.

make_design <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

make_ages <- function(interview_ids = 1:5) {
  data.frame(
    interview_id = interview_ids,
    species      = "walleye",
    est_age      = c(2L, 4L, 3L, 5L, 2L)[seq_along(interview_ids)],
    fate         = "harvest",
    stringsAsFactors = FALSE
  )
}

# Guard tests ----

test_that("add_ages() errors when design is not creel_design", {
  expect_error(
    add_ages(list(), make_ages(),
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "creel_design"
  )
})

test_that("add_ages() errors when ages already attached", {
  d <- make_design()
  d2 <- add_ages(d, make_ages(),
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_error(
    add_ages(d2, make_ages(),
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "already has age data"
  )
})

test_that("add_ages() errors when interviews not attached", {
  data(example_calendar, package = "tidycreel")
  d_bare <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    add_ages(d_bare, make_ages(),
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "Interviews must be attached"
  )
})

test_that("add_ages() errors when age_type has invalid values", {
  d <- make_design()
  bad <- make_ages()
  bad$fate <- "dead"
  expect_error(
    add_ages(d, bad,
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "Invalid"
  )
})

test_that("add_ages() errors when age_uid references interview not in design", {
  d <- make_design()
  bad <- make_ages(interview_ids = c(1, 2, 9999))
  expect_error(
    add_ages(d, bad,
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "not found in design interviews"
  )
})

test_that("add_ages() errors when age values are non-numeric", {
  d <- make_design()
  bad <- make_ages()
  bad$est_age <- c("two", "four", "three", "five", "two")
  expect_error(
    add_ages(d, bad,
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "must be numeric"
  )
})

test_that("add_ages() errors when age values are negative", {
  d <- make_design()
  bad <- make_ages()
  bad$est_age[1] <- -1L
  expect_error(
    add_ages(d, bad,
      age_uid = interview_id, interview_uid = interview_id,
      species = species, age = est_age, age_type = fate),
    "non-negative"
  )
})

# Return value tests ----

test_that("add_ages() returns a creel_design object", {
  d <- make_design()
  result <- add_ages(d, make_ages(),
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_s3_class(result, "creel_design")
})

test_that("add_ages() attaches data to design$ages", {
  d <- make_design()
  ages <- make_ages()
  result <- add_ages(d, ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_false(is.null(result$ages))
  expect_equal(nrow(result$ages), nrow(ages))
})

test_that("add_ages() stores correct column-name slots", {
  d <- make_design()
  result <- add_ages(d, make_ages(),
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_equal(result$ages_uid_col, "interview_id")
  expect_equal(result$ages_interview_uid_col, "interview_id")
  expect_equal(result$ages_species_col, "species")
  expect_equal(result$ages_age_col, "est_age")
  expect_equal(result$ages_type_col, "fate")
})

test_that("add_ages() is immutable — original design unchanged", {
  d <- make_design()
  add_ages(d, make_ages(),
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_null(d$ages)
})

test_that("add_ages() normalises age_type to lowercase", {
  d <- make_design()
  ages <- make_ages()
  ages$fate <- "Harvest"
  result <- add_ages(d, ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_true(all(result$ages$fate == "harvest"))
})

test_that("add_ages() accepts age = 0 (age-0 fish)", {
  d <- make_design()
  ages <- make_ages()
  ages$est_age[1] <- 0L
  result <- add_ages(d, ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_equal(result$ages$est_age[1], 0L)
})

test_that("add_ages() accepts release age_type", {
  d <- make_design()
  ages <- make_ages()
  ages$fate <- "release"
  result <- add_ages(d, ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate)
  expect_s3_class(result, "creel_design")
})
