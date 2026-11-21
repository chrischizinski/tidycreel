# Non-syntactic column names are refused where the data enter (GH #674) ----
#
# The estimators build model formulas from column names -- strata, counts,
# catch, effort, `by` groups -- and a name such as `day type` does not parse in
# one. Every rate, total and grouped effort stopped with an R parse error
# ("unexpected symbol") on such a name. Any column can later be named in `by`,
# so every column of every data frame handed in is checked, used or not.

nsn_q <- function(x) suppressWarnings(suppressMessages(x))

nsn_base <- function() {
  d <- nsn_q(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  nsn_q(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

with_bad <- function(df, name = "clerk notes") {
  df[[name]] <- "x"
  df
}

test_that("NSN-01: every entry point refuses a non-syntactic column, used or not", {
  cal <- with_bad(example_calendar)
  expect_error(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    class = "creel_error_nonsyntactic_names"
  )

  d0 <- nsn_q(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  expect_error(
    add_counts(d0, with_bad(example_counts)),
    class = "creel_error_nonsyntactic_names"
  )
  expect_error(
    add_interviews(d0, with_bad(example_interviews),
      catch = catch_total, effort = hours_fished, trip_status = trip_status # nolint: object_usage_linter
    ),
    class = "creel_error_nonsyntactic_names"
  )
  expect_error(
    add_sections(d0, with_bad(data.frame(section = c("A", "B"))), section_col = section), # nolint: object_usage_linter
    class = "creel_error_nonsyntactic_names"
  )

  d <- nsn_base()
  expect_error(
    add_catch(d, with_bad(example_catch),
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    class = "creel_error_nonsyntactic_names"
  )
  dc <- nsn_q(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
  expect_error(
    add_lengths(dc, with_bad(example_lengths),
      length_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, length = length, length_type = length_type, # nolint: object_usage_linter
      count = count, release_format = "binned" # nolint: object_usage_linter
    ),
    class = "creel_error_nonsyntactic_names"
  )
  expect_error(
    add_ages(dc, with_bad(example_ages),
      age_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, age = age, age_type = age_type # nolint: object_usage_linter
    ),
    class = "creel_error_nonsyntactic_names"
  )
})

test_that("NSN-02: the message names every offending column and a syntactic rename", {
  cal <- example_calendar
  cal[["day type"]] <- cal$day_type
  cal[["2nd shift"]] <- "x"
  err <- expect_error(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    class = "creel_error_nonsyntactic_names"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "day type", fixed = TRUE)
  expect_match(msg, "2nd shift", fixed = TRUE)
  expect_match(msg, "day.type", fixed = TRUE)
  expect_match(msg, "X2nd.shift", fixed = TRUE)
})

test_that("NSN-03: reserved words, leading underscores and empty names are refused too", {
  for (bad in c("if", "_x", "")) {
    cal <- example_calendar
    cal$placeholder <- "x"
    names(cal)[ncol(cal)] <- bad
    expect_error(
      creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
      class = "creel_error_nonsyntactic_names"
    )
  }
})

test_that("NSN-04: ordinary names with dots, underscores and digits pass", {
  cal <- example_calendar
  cal$clerk.notes <- "x"
  cal$shift_2 <- "x"
  cal$.hidden <- "x"
  expect_no_error(nsn_q(creel_design(cal, date = date, strata = day_type))) # nolint: object_usage_linter
})

test_that("NSN-05: the bus-route sampling frame is checked too", {
  cal <- data.frame(date = as.Date("2024-06-01") + 0:1, day_type = "weekday")
  sf <- data.frame(site = c("A", "B"), circuit = "c", wait = c(60, 60), ct = 180)
  sf[["site name"]] <- c("North", "South")
  expect_error(
    creel_design(
      cal,
      date = date, strata = day_type, survey_type = "bus_route", # nolint: object_usage_linter
      sampling_frame = sf, site = site, circuit = circuit, # nolint: object_usage_linter
      wait_time = wait, circuit_time = ct, p_period = 1 # nolint: object_usage_linter
    ),
    class = "creel_error_nonsyntactic_names"
  )
})

test_that("NSN-06: the suggested rename cannot collide with an existing column", {
  cal <- example_calendar
  cal$clerk.notes <- "x"
  cal[["clerk notes"]] <- "y"
  err <- expect_error(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    class = "creel_error_nonsyntactic_names"
  )
  expect_match(conditionMessage(err), "clerk.notes.1", fixed = TRUE)
  repaired <- cal
  names(repaired) <- make.names(names(repaired), unique = TRUE)
  expect_no_error(suppressMessages(creel_design(repaired, date = date, strata = day_type))) # nolint: object_usage_linter
})

test_that("NSN-07: a header that is not valid text gets a classed error", {
  skip_if_not(l10n_info()[["UTF-8"]], "needs a UTF-8 locale to make the bytes invalid")
  cal <- example_calendar
  cal$placeholder <- "x"
  names(cal)[ncol(cal)] <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
  expect_error(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    class = "creel_error_nonsyntactic_names"
  )
})
