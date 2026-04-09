## SCHEMA-01: creel_schema() construction -----------------------------------

test_that("creel_schema() returns object with class 'creel_schema'", {
  s <- creel_schema(survey_type = "instantaneous")
  expect_s3_class(s, "creel_schema")
})

test_that("creel_schema() with invalid survey_type throws match.arg error", {
  expect_error(
    creel_schema(survey_type = "invalid_type"),
    regexp = "should be one of|arg.*choices"
  )
})

test_that("creel_schema() with all NULLs constructs without error (permissive)", {
  expect_no_error(creel_schema(survey_type = "instantaneous"))
})

test_that("creel_schema()$survey_type stores the survey_type value", {
  s <- creel_schema(survey_type = "bus_route")
  expect_equal(s$survey_type, "bus_route")
})

test_that("creel_schema()$interviews_table stores the table name value", {
  s <- creel_schema(survey_type = "instantaneous", interviews_table = "vwInterviews")
  expect_equal(s$interviews_table, "vwInterviews")
})

test_that("creel_schema()$date_col stores the column name value", {
  s <- creel_schema(survey_type = "instantaneous", date_col = "SurveyDate")
  expect_equal(s$date_col, "SurveyDate")
})


## SCHEMA-03: validate_creel_schema() ---------------------------------------

test_that("validate_creel_schema() returns invisible(schema) when complete instantaneous schema", {
  s <- creel_schema(
    survey_type = "instantaneous",
    date_col = "date",
    catch_col = "catch_count",
    effort_col = "effort_hours",
    trip_status_col = "trip_status",
    count_col = "angler_count",
    catch_uid_col = "catch_uid",
    interview_uid_col = "interview_uid",
    species_col = "species",
    catch_count_col = "catch_count",
    catch_type_col = "catch_type",
    length_uid_col = "length_uid",
    length_mm_col = "length_mm",
    length_type_col = "length_type"
  )
  result <- validate_creel_schema(s)
  expect_identical(result, s)
})

test_that("validate_creel_schema() throws cli_abort() when required interviews columns are missing", {
  s <- creel_schema(survey_type = "instantaneous")
  expect_error(validate_creel_schema(s))
})

test_that("error message includes missing column name (e.g., 'catch')", {
  s <- creel_schema(survey_type = "instantaneous")
  expect_error(validate_creel_schema(s), regexp = "catch")
})

test_that("error message includes the table name (e.g., 'interviews table')", {
  s <- creel_schema(survey_type = "instantaneous")
  expect_error(validate_creel_schema(s), regexp = "interviews table")
})

test_that("validate_creel_schema() passes for camera type with only counts columns", {
  s <- creel_schema(
    survey_type = "camera",
    date_col    = "SurveyDate",
    count_col   = "AnglerCount"
  )
  expect_no_error(validate_creel_schema(s))
})

test_that("validate_creel_schema() throws when non-creel_schema object passed", {
  expect_error(validate_creel_schema(list(survey_type = "instantaneous")))
})


## SCHEMA-04: format.creel_schema() and print.creel_schema() ---------------

test_that("format.creel_schema() returns a character vector", {
  s <- creel_schema(survey_type = "instantaneous", date_col = "SurveyDate")
  result <- format(s)
  expect_type(result, "character")
})

test_that("print output contains '<creel_schema: instantaneous>' header", {
  s <- creel_schema(survey_type = "instantaneous")
  expect_output(print(s), regexp = "creel_schema.*instantaneous")
})

test_that("print output contains mapped column names (non-NULL only)", {
  s <- creel_schema(survey_type = "instantaneous", date_col = "SurveyDate")
  expect_output(print(s), regexp = "SurveyDate")
})

test_that("print output does NOT contain NULL mappings", {
  s <- creel_schema(survey_type = "instantaneous", date_col = "SurveyDate")
  out <- capture.output(print(s))
  # catch_col is NULL — "catch_col" or raw "NULL" should not appear in output
  expect_false(any(grepl("NULL", out)))
})


## make_test_db() fixture ---------------------------------------------------

test_that("make_test_db() returns a DBI connection object", {
  skip_if_not_installed("duckdb")
  con <- make_test_db()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  expect_true(DBI::dbIsValid(con))
})

test_that("make_test_db() creates interviews, counts, catch, lengths tables", {
  skip_if_not_installed("duckdb")
  con <- make_test_db()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  tables <- DBI::dbListTables(con)
  expect_true(all(c("interviews", "counts", "catch", "lengths") %in% tables))
})
