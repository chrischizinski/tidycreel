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

test_that("#594: a design whose columns are all present estimates as before", {
  d <- inv_design()
  expect_no_error(suppressWarnings(suppressMessages(estimate_total_catch(d))))
  # Editing values, not dropping columns, is still followed, not refused.
  d$interviews <- d$interviews[d$interviews$catch_total < 10, , drop = FALSE]
  expect_no_error(suppressWarnings(suppressMessages(estimate_catch_rate(d))))
})
