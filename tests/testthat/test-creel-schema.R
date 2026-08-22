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
    date_col = "SurveyDate",
    count_col = "AnglerCount"
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


## strata_cols (GH #171) -----------------------------------------------------

test_that("strata_cols normalises a named mapping and keeps both sides", {
  # A stratum is the one mapped quantity with no canonical name: add_counts()
  # matches the caller's own calendar column names, so the mapping is two-sided
  # and the design-facing name has to survive as the vector's names.
  s <- creel_schema(survey_type = "instantaneous", strata_cols = c(day_type = "DayType"))
  expect_equal(s$strata_cols, c(day_type = "DayType"))
})

test_that("an unnamed strata_cols entry names itself on both sides", {
  s <- creel_schema(survey_type = "instantaneous", strata_cols = c("day_type"))
  expect_equal(s$strata_cols, c(day_type = "day_type"))
})

test_that("strata_cols accepts a partially named vector", {
  s <- creel_schema(
    survey_type = "instantaneous",
    strata_cols = c(day_type = "DayType", "period")
  )
  expect_equal(s$strata_cols, c(day_type = "DayType", period = "period"))
})

test_that("strata_cols rejects a non-character, an empty name, and a duplicate target", {
  # Each of these would otherwise reach the fetch layer and silently carry
  # nothing, which is the failure mode #171 is about.
  expect_error(
    creel_schema(survey_type = "instantaneous", strata_cols = 1:2),
    class = "creel_error_schema_validation"
  )
  expect_error(
    creel_schema(survey_type = "instantaneous", strata_cols = c(day_type = NA_character_)),
    class = "creel_error_schema_validation"
  )
  expect_error(
    creel_schema(survey_type = "instantaneous", strata_cols = c(day_type = "A", day_type = "B")),
    class = "creel_error_schema_validation"
  )
})

test_that("strata_cols prints under both tables using the design-facing name", {
  s <- creel_schema(survey_type = "instantaneous", strata_cols = c(day_type = "DayType"))
  out <- capture.output(print(s))
  # The design refers to `day_type`; `strata_cols` is the field, not the column.
  expect_true(any(grepl("day_type -> DayType", out, fixed = TRUE)))
  expect_false(any(grepl("strata_cols ->", out, fixed = TRUE)))
})


## COL_TO_TABLE grouping (GH #170) -------------------------------------------

test_that("both enumeration columns print under interviews, not counts", {
  # n_counted and n_interviewed are a numerator and its denominator on the same
  # table: add_interviews() resolves both against the interviews frame and
  # get_enumeration_counts() reads them back off it. Grouping n_counted under
  # counts told a bus-route user it lived in a table it is not in.
  s <- creel_schema(
    survey_type       = "bus_route",
    n_counted_col     = "Seen",
    n_interviewed_col = "Asked",
    # Something genuinely on the counts table, so that block prints and the
    # ordering assertion below has two headers to sit between.
    count_col         = "AnglerCount"
  )
  out <- capture.output(print(s))

  interviews_at <- grep("interviews:", out)
  counts_at     <- grep("counts:", out)
  seen_at       <- grep("n_counted -> Seen", out, fixed = TRUE)
  asked_at      <- grep("n_interviewed -> Asked", out, fixed = TRUE)

  expect_length(seen_at, 1L)
  expect_length(asked_at, 1L)
  # Both fall in the interviews block, i.e. after its header and before counts'.
  expect_true(seen_at > interviews_at && seen_at < counts_at)
  expect_true(asked_at > interviews_at && asked_at < counts_at)
})


## binned length columns (GH #127) -------------------------------------------

test_that("length_bin_col and length_count_col are carried on the schema", {
  # The pair a binned source needs: a label, and the number of fish it stands
  # for. Storing the label in length_mm_col instead is what rested a millimetre
  # unit on a group label.
  s <- creel_schema(
    survey_type      = "instantaneous",
    length_bin_col   = "LengthGroup",
    length_count_col = "GroupCount"
  )

  expect_equal(s$length_bin_col, "LengthGroup")
  expect_equal(s$length_count_col, "GroupCount")
})

test_that("the binned pair is optional, so a measured schema still validates", {
  # Requiring it would break every schema for a source that measures each fish,
  # which is why the pair is absent from CANONICAL_COLUMNS.
  s <- creel_schema(
    survey_type       = "instantaneous",
    date_col          = "SurveyDate",
    catch_col         = "TotalCatch",
    effort_col        = "EffortHours",
    trip_status_col   = "TripStatus",
    count_col         = "AnglerCount",
    catch_uid_col     = "CatchID",
    interview_uid_col = "InterviewID",
    species_col       = "Species",
    catch_count_col   = "FishCount",
    catch_type_col    = "CatchType",
    length_uid_col    = "LengthID",
    length_mm_col     = "LengthMM",
    length_type_col   = "LengthType"
  )

  expect_silent(validate_creel_schema(s))
  expect_null(s$length_bin_col)
  expect_null(s$length_count_col)
})

test_that("the binned pair prints under lengths", {
  s <- creel_schema(
    survey_type      = "instantaneous",
    length_mm_col    = "LengthMM",
    length_bin_col   = "LengthGroup",
    length_count_col = "GroupCount"
  )
  out <- capture.output(print(s))

  lengths_at <- grep("lengths:", out)
  bin_at     <- grep("length_bin -> LengthGroup", out, fixed = TRUE)
  count_at   <- grep("length_count -> GroupCount", out, fixed = TRUE)

  expect_length(bin_at, 1L)
  expect_length(count_at, 1L)
  expect_true(all(c(bin_at, count_at) > lengths_at))
})

## value_maps (GH #128) -------------------------------------------------------

test_that("value_maps stores a source vocabulary keyed by canonical column", {
  # Names are the source's own codes, values what tidycreel means. Downstream
  # filters match the canonical literals, so a coded source has to say what its
  # codes mean before its values can be trusted.
  s <- creel_schema(
    survey_type = "instantaneous",
    value_maps  = list(trip_status = c("1" = "complete", "2" = "incomplete"))
  )

  expect_equal(s$value_maps$trip_status, c("1" = "complete", "2" = "incomplete"))
})

test_that("value_maps rejects a target outside the canonical vocabulary", {
  # Checked here rather than downstream: a typo'd target would otherwise sail
  # through the fetch and abort at add_interviews(), pointing at the data
  # instead of at the map that mistranslated it.
  expect_error(
    creel_schema(
      survey_type = "instantaneous",
      value_maps  = list(trip_status = c("1" = "compleet"))
    ),
    "outside the vocabulary",
    class = "creel_error_schema_validation"
  )
})

test_that("value_maps rejects a column with no canonical vocabulary", {
  # Only trip_status, catch_type and length_type have fixed vocabularies. A map
  # for anything else would silently never be applied.
  expect_error(
    creel_schema(
      survey_type = "instantaneous",
      value_maps  = list(day_type = c("1" = "complete"))
    ),
    "no canonical vocabulary",
    class = "creel_error_schema_validation"
  )
})

test_that("value_maps requires every entry to name its source code", {
  expect_error(
    creel_schema(
      survey_type = "instantaneous",
      value_maps  = list(trip_status = c("complete"))
    ),
    "fully named",
    class = "creel_error_schema_validation"
  )
})

test_that("value_maps refuses to map one source code twice", {
  # A duplicated code has two meanings and no way to choose between them.
  expect_error(
    creel_schema(
      survey_type = "instantaneous",
      value_maps  = list(trip_status = c("1" = "complete", "1" = "incomplete"))
    ),
    "same source code twice",
    class = "creel_error_schema_validation"
  )
})

test_that("value_maps accepts all three coded columns", {
  s <- creel_schema(
    survey_type = "instantaneous",
    value_maps  = list(
      trip_status = c("1" = "complete"),
      catch_type  = c(H = "harvested", R = "released"),
      length_type = c(H = "harvest")
    )
  )

  expect_named(s$value_maps, c("trip_status", "catch_type", "length_type"))
})

test_that("value_maps prints under its own heading", {
  # trip_status is an interviews column and catch_type a catch column, so a
  # vocabulary belongs to no single table block.
  s <- creel_schema(
    survey_type = "instantaneous",
    value_maps  = list(trip_status = c("1" = "complete"))
  )
  out <- capture.output(print(s))

  expect_true(any(grepl("value maps", out)))
  expect_true(any(grepl("trip_status: 1 -> complete", out, fixed = TRUE)))
})

## count time (GH #129) --------------------------------------------------------

test_that("count_time_col is carried on the schema", {
  # A count row is one observation, not a day's total. The time is what
  # distinguishes two counts on one date; with no field for it, those rows read
  # as two sampled days.
  s <- creel_schema(
    survey_type    = "instantaneous",
    count_time_col = "CountTime"
  )

  expect_equal(s$count_time_col, "CountTime")
})

test_that("count_time_col is optional, so an existing schema still validates", {
  # Every schema written before #129 maps no count time, and requiring one
  # would break all of them -- which is why it is absent from CANONICAL_COLUMNS.
  s <- creel_schema(
    survey_type       = "instantaneous",
    date_col          = "SurveyDate",
    catch_col         = "TotalCatch",
    effort_col        = "EffortHours",
    trip_status_col   = "TripStatus",
    count_col         = "AnglerCount",
    catch_uid_col     = "CatchID",
    interview_uid_col = "InterviewID",
    species_col       = "Species",
    catch_count_col   = "FishCount",
    catch_type_col    = "CatchType",
    length_uid_col    = "LengthID",
    length_mm_col     = "LengthMM",
    length_type_col   = "LengthType"
  )

  expect_silent(validate_creel_schema(s))
  expect_null(s$count_time_col)
})

test_that("count_time_col prints under counts", {
  # It describes a count row, so listing it under any other table would send a
  # reader to the wrong frame -- the mistake #170 fixed for n_counted_col.
  s <- creel_schema(
    survey_type      = "instantaneous",
    count_time_col   = "CountTime",
    bank_anglers_col = "ShoreAnglers"
  )
  out <- capture.output(print(s))

  counts_at <- grep("counts:", out)
  time_at   <- grep("count_time -> CountTime", out, fixed = TRUE)

  expect_length(time_at, 1L)
  expect_true(all(time_at > counts_at))
})
