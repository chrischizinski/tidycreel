# Unknown design fields error (GH #594 Part B).
#
# A creel_design is a list, and a missing element reads as NULL, which the
# package takes to mean "not attached". So a misspelled field passed for an
# unattached table: adjust_nonresponse() read design$counts_survey, which no
# step sets, and its count branch never ran (#633). R's `$` also matched a
# prefix, so design$strata_col read strata_cols.

fd_design <- function() {
  data("example_calendar", package = "tidycreel", envir = environment())
  creel_design(example_calendar, date = date, strata = day_type)
}

test_that("#594: a misspelled field is an error, not NULL", {
  d <- fd_design()
  expect_error(d$conunt_col, class = "creel_error_design_unknown_field")
  expect_error(d$conunt_col, "count_col") # the suggestion
  expect_error(d[["counts_survey"]], class = "creel_error_design_unknown_field")
})

test_that("#594: a known field that is not attached yet still reads as NULL", {
  d <- fd_design()
  expect_null(d$catch)
  expect_null(d[["sections"]])
  expect_null(d$counts)
})

test_that("#594: `$` no longer matches a prefix of a field name", {
  d <- fd_design()
  # Before: d$strata_col silently returned strata_cols.
  expect_error(d$strata_col, class = "creel_error_design_unknown_field")
  expect_identical(d$strata_cols, "day_type")
})

test_that("#594: positional [[ and list operations are unaffected", {
  d <- fd_design()
  expect_identical(d[[1]], unclass(d)[[1]])
  expect_true("calendar" %in% names(d))
  d$counts <- NULL
  expect_s3_class(d, "creel_design")
})

test_that("#594: every field a built design carries is in the known-field list", {
  # Fails when a step starts setting a field that was not added to
  # creel_design_fields -- which would make reading it an error.
  data("example_counts", package = "tidycreel", envir = environment())
  data("example_interviews", package = "tidycreel", envir = environment())
  data("example_catch", package = "tidycreel", envir = environment())
  data("example_lengths", package = "tidycreel", envir = environment())
  data("example_ages", package = "tidycreel", envir = environment())
  data("example_sections_calendar", package = "tidycreel", envir = environment())
  data("example_sections_counts", package = "tidycreel", envir = environment())
  data("example_sections_interviews", package = "tidycreel", envir = environment())
  q <- function(x) suppressWarnings(suppressMessages(x))
  d <- q(add_counts(fd_design(), example_counts))
  d <- q(add_interviews(d, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = n_anglers
  ))
  d <- q(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  d <- q(add_lengths(d, example_lengths,
    length_uid = interview_id, interview_uid = interview_id, species = species,
    length = length, length_type = length_type, count = count, release_format = "binned"
  ))
  d <- q(add_ages(d, example_ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = age, age_type = age_type
  ))
  s <- creel_design(example_sections_calendar, date = date, strata = day_type)
  s <- add_sections(s, data.frame(section = c("North", "Central", "South")), section_col = section)
  s <- q(add_counts(s, example_sections_counts))
  s <- q(add_interviews(s, example_sections_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status, n_anglers = 1
  ))
  br <- build_br_design_for_tests(3, 8, 30, seed = 1)
  ice <- build_ice_design(8, 30, seed = 1)
  for (des in list(d, s, br, ice)) {
    expect_true(all(names(des) %in% creel_design_fields),
      info = paste(setdiff(names(des), creel_design_fields), collapse = ", ")
    )
  }
})

test_that("#594: single-bracket reads are guarded too", {
  d <- fd_design()
  expect_error(d["conunt_col"], class = "creel_error_design_unknown_field")
  expect_error(d[c("calendar", "conunt_col")], class = "creel_error_design_unknown_field")
  expect_named(d[c("date_col", "strata_cols")], c("date_col", "strata_cols"))
  expect_identical(length(d[]), length(unclass(d)))
})

test_that("#594: an unknown field cannot be set, so nothing is set that cannot be read", {
  d <- fd_design()
  expect_error(d$conunt_col <- "x", class = "creel_error_design_unknown_field")
  expect_error(d[["conunt_col"]] <- "x", class = "creel_error_design_unknown_field")
  d$count_col <- "count"
  expect_identical(d$count_col, "count")
  d[["count_col"]] <- NULL
  expect_null(d$count_col)
})

test_that("#594: an NA field name errors without a list of NA suggestions", {
  d <- fd_design()
  err <- tryCatch(d[[NA_character_]], error = function(e) e)
  expect_s3_class(err, "creel_error_design_unknown_field")
  expect_false(grepl("Did you mean", conditionMessage(err)))
})
