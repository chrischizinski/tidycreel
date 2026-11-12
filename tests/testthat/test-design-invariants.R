# Cross-field invariants of a creel_design (GH #594 Part A).
#
# A creel_design is a plain list, so a user can edit design$counts or
# design$interviews after attaching them. The estimators rebuild their survey
# from the current tables, so they follow such an edit. Two things did not:
#
#   * as_creel_svydesign() returned the survey stored at add_counts() time, so
#     the escape hatch described different data than estimate_effort() used;
#   * a design whose *_col field names a column the table no longer has failed
#     with "object 'catch' not found" or, worse, ran on without the column.

inv_design <- function() {
  data("example_calendar", package = "tidycreel", envir = environment())
  data("example_counts", package = "tidycreel", envir = environment())
  data("example_interviews", package = "tidycreel", envir = environment())
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressMessages(add_counts(d, example_counts))
  suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration,
    n_anglers = n_anglers, angler_type = angler_type
  ))
}

# --- as_creel_svydesign() follows the counts the estimators use --------------

test_that("#594: as_creel_svydesign() describes the counts the design holds now", {
  d <- inv_design()
  d$counts <- d$counts[-1, , drop = FALSE]
  svy <- suppressMessages(as_creel_svydesign(d))
  # Before: 14 rows from the counts as attached, while counts held 13.
  expect_identical(nrow(svy$variables), nrow(d$counts))
})

test_that("#594: an edited count reaches as_creel_svydesign(), as it reaches estimate_effort()", {
  d <- inv_design()
  d$counts$effort_hours[1] <- 500
  svy <- suppressMessages(as_creel_svydesign(d))
  expect_identical(svy$variables$effort_hours[1], 500)
  # Same survey as a design built fresh from the edited counts, which is the
  # design estimate_effort() already behaves like after the edit.
  data("example_calendar", package = "tidycreel", envir = environment())
  fresh <- creel_design(example_calendar, date = date, strata = day_type)
  fresh <- suppressMessages(add_counts(fresh, d$counts[c("date", "day_type", "effort_hours")]))
  svy_fresh <- suppressMessages(as_creel_svydesign(fresh))
  expect_equal(
    survey::SE(survey::svytotal(~effort_hours, svy)),
    survey::SE(survey::svytotal(~effort_hours, svy_fresh))
  )
  expect_equal(
    suppressWarnings(suppressMessages(estimate_effort(d)))$estimates$estimate,
    suppressWarnings(suppressMessages(estimate_effort(fresh)))$estimates$estimate
  )
})

# --- a *_col field must name a column of its table ---------------------------

test_that("#594: a count column removed after attaching is refused by name", {
  d <- inv_design()
  d$counts$effort_hours <- NULL
  expect_error(
    suppressWarnings(estimate_effort(d)),
    class = "creel_error_design_column_missing"
  )
  expect_error(suppressWarnings(estimate_effort(d)), "count_col")
})

test_that("#594: a renamed catch column is refused by name, not 'object not found'", {
  d <- inv_design()
  names(d$interviews)[names(d$interviews) == "catch_total"] <- "catch"
  expect_error(
    suppressWarnings(estimate_catch_rate(d)),
    class = "creel_error_design_column_missing"
  )
  expect_error(suppressWarnings(estimate_catch_rate(d)), "catch_col")
})

test_that("#594: a dropped effort column is refused, though the rate could still run", {
  # The rate reads .angler_effort, so before this it ran on and returned a
  # number from a design that claims a column it does not have.
  d <- inv_design()
  d$interviews$hours_fished <- NULL
  expect_error(
    suppressWarnings(estimate_catch_rate(d)),
    class = "creel_error_design_column_missing"
  )
})

test_that("#594: the column check runs in every total and the harvest rate", {
  d <- inv_design()
  d$interviews$catch_kept <- NULL
  for (f in list(estimate_harvest_rate, estimate_total_harvest, estimate_total_catch)) {
    expect_error(
      suppressWarnings(suppressMessages(f(d))),
      class = "creel_error_design_column_missing"
    )
  }
})

test_that("#594: release, age and length estimators refuse a missing column too", {
  data("example_catch", package = "tidycreel", envir = environment())
  data("example_lengths", package = "tidycreel", envir = environment())
  data("example_ages", package = "tidycreel", envir = environment())
  d <- inv_design()
  d <- suppressMessages(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  d <- suppressMessages(add_lengths(d, example_lengths,
    length_uid = interview_id, interview_uid = interview_id,
    species = species, length = length, length_type = length_type,
    count = count, release_format = "binned"
  ))
  d <- suppressMessages(add_ages(d, example_ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = age, age_type = age_type
  ))
  # Each runs on the intact design, so the refusal below is the check's.
  run <- list(
    total_release = function(d) estimate_total_release(d),
    age = function(d) est_age_distribution(d, by = species),
    length = function(d) est_length_distribution(d, by = species, bin_width = 25)
  )
  for (f in run) expect_no_error(suppressWarnings(suppressMessages(f(d))))
  d$interviews$angler_type <- NULL
  for (nm in names(run)) {
    expect_error(
      suppressWarnings(suppressMessages(run[[nm]](d))),
      class = "creel_error_design_column_missing",
      info = nm
    )
  }
})

test_that("#594: as_creel_svydesign() checks only the counts it is built from", {
  d <- inv_design()
  d$interviews$angler_type <- NULL
  expect_no_error(suppressMessages(as_creel_svydesign(d)))
  d$counts$effort_hours <- NULL
  expect_error(
    suppressMessages(as_creel_svydesign(d)),
    class = "creel_error_design_column_missing"
  )
})

test_that("#594: a refused as_creel_svydesign() does not spend its one-time notice", {
  d <- inv_design()
  broken <- d
  broken$counts$effort_hours <- NULL
  expect_error(suppressMessages(as_creel_svydesign(broken)))
  expect_message(as_creel_svydesign(d), class = "creel_message_internal_svydesign")
})

test_that("#594: a design whose columns are all present estimates as before", {
  d <- inv_design()
  expect_no_error(suppressWarnings(suppressMessages(estimate_total_catch(d))))
  # Editing values, not dropping columns, is still followed, not refused.
  d$interviews <- d$interviews[d$interviews$catch_total < 10, , drop = FALSE]
  expect_no_error(suppressWarnings(suppressMessages(estimate_catch_rate(d))))
})

# --- step 2: catch, lengths, ages, sections ----------------------------------

inv_bio_design <- function() {
  data("example_catch", package = "tidycreel", envir = environment())
  data("example_lengths", package = "tidycreel", envir = environment())
  data("example_ages", package = "tidycreel", envir = environment())
  d <- inv_design()
  d <- suppressMessages(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  d <- suppressMessages(add_lengths(d, example_lengths,
    length_uid = interview_id, interview_uid = interview_id,
    species = species, length = length, length_type = length_type,
    count = count, release_format = "binned"
  ))
  suppressMessages(add_ages(d, example_ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = age, age_type = age_type
  ))
}

test_that("#594: a renamed catch, length or age column is refused by name", {
  d <- inv_bio_design()
  # Before: "`x` and `y` must share the same src" and "arguments imply
  # differing number of rows: 14, 0".
  d1 <- d
  names(d1$catch)[names(d1$catch) == "species"] <- "sp"
  expect_error(
    suppressWarnings(estimate_total_catch(d1, by = species)),
    class = "creel_error_design_column_missing"
  )
  expect_error(suppressWarnings(estimate_total_catch(d1, by = species)), "catch_species_col")
  d2 <- d
  d2$lengths$length <- NULL
  expect_error(
    suppressWarnings(est_length_distribution(d2, by = species, bin_width = 25)),
    class = "creel_error_design_column_missing"
  )
  d3 <- d
  d3$ages$age <- NULL
  expect_error(
    suppressWarnings(est_age_distribution(d3, by = species)),
    class = "creel_error_design_column_missing"
  )
})

test_that("#594: catch rows whose interview was removed are still followed, not refused", {
  # Decision on #594: every estimate equals a fresh design built from the
  # filtered data, so the edit is followed as in step 1.
  d <- inv_bio_design()
  d$interviews <- d$interviews[!d$interviews$interview_id %in% c("1", "2"), , drop = FALSE]
  expect_no_error(suppressWarnings(suppressMessages(estimate_total_catch(d, by = species))))
})

inv_sections <- function() {
  data("example_sections_calendar", package = "tidycreel", envir = environment())
  data("example_sections_counts", package = "tidycreel", envir = environment())
  data("example_sections_interviews", package = "tidycreel", envir = environment())
  d <- creel_design(example_sections_calendar, date = date, strata = day_type)
  d <- add_sections(d, data.frame(section = c("North", "Central", "South")),
    section_col = section
  )
  d <- suppressWarnings(suppressMessages(add_counts(d, example_sections_counts)))
  suppressWarnings(suppressMessages(add_interviews(d, example_sections_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = 1
  )))
}

est_quiet <- function(f, d) suppressWarnings(suppressMessages(f(d)))

test_that("#594: a section dropped from design$sections is refused, not left out of one total", {
  # Before: effort's lake total still included South (1310) while total
  # catch's left it out (1539 of 1945), in the same report, with no message.
  d <- inv_sections()
  d$sections <- d$sections[d$sections$section != "South", , drop = FALSE]
  for (f in list(estimate_effort, estimate_catch_rate, estimate_total_catch)) {
    expect_error(est_quiet(f, d), class = "creel_error_design_section_unregistered")
  }
  expect_error(est_quiet(estimate_effort, d), "South")
})

test_that("#594: counts relabelled to an unregistered section are refused", {
  d <- inv_sections()
  d$counts$section[d$counts$section == "South"] <- "Sth"
  expect_error(
    est_quiet(estimate_total_catch, d),
    class = "creel_error_design_section_unregistered"
  )
})

test_that("#594: a renamed section column is refused, not reported as a lake total of 0", {
  d <- inv_sections()
  names(d$counts)[names(d$counts) == "section"] <- "sec"
  expect_error(
    est_quiet(estimate_total_catch, d),
    class = "creel_error_design_column_missing"
  )
  d <- inv_sections()
  names(d$sections)[names(d$sections) == "section"] <- "sec"
  expect_error(
    est_quiet(estimate_total_catch, d),
    class = "creel_error_design_column_missing"
  )
})

test_that("#594: counts with no section column cannot join a sectioned design", {
  # Reachable without any edit: add_counts() let section-less counts onto a
  # sectioned design, and estimate_total_catch() then reported every section
  # NA and a lake total of 0 with SE 0.
  data("example_sections_calendar", package = "tidycreel", envir = environment())
  data("example_sections_counts", package = "tidycreel", envir = environment())
  d <- creel_design(example_sections_calendar, date = date, strata = day_type)
  d <- add_sections(d, data.frame(section = c("North", "Central", "South")),
    section_col = section
  )
  no_section <- stats::aggregate(effort_hours ~ date + day_type, example_sections_counts, sum)
  expect_error(
    suppressWarnings(suppressMessages(add_counts(d, no_section))),
    class = "creel_error_design_column_missing"
  )
})

test_that("#594: an intact sectioned design estimates as before", {
  d <- inv_sections()
  expect_no_error(est_quiet(estimate_total_catch, d))
})

test_that("#594: a design whose section_col field was deleted is refused, not let through", {
  d <- inv_sections()
  d$section_col <- NULL
  expect_error(
    est_quiet(estimate_total_catch, d),
    class = "creel_error_design_column_missing"
  )
})

test_that("#638: bus-route and ice designs refuse sections, which no estimator uses", {
  # Every estimator dispatches these designs before its section branch, so
  # sections were accepted and then dropped from every estimate in silence.
  br <- build_br_design_for_tests(3, 8, 30, seed = 1)
  ice <- build_ice_design(8, 30, seed = 1)
  for (d in list(br, ice)) {
    expect_error(
      add_sections(d, data.frame(section = c("A", "B")), section_col = section),
      class = "creel_error_dispatch_unsupported"
    )
  }
  expect_error(
    add_sections(br, data.frame(section = c("A", "B")), section_col = section),
    "bus-route"
  )
  expect_error(
    add_sections(ice, data.frame(section = c("A", "B")), section_col = section),
    "ice"
  )
})
