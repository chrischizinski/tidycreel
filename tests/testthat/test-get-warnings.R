# get_warnings(): every warning is also recorded on the object its call
# returns (GH #496). A warning that scrolls past is otherwise gone, and a user
# who cannot look back silences everything, including the warnings that mean
# an estimate may be wrong.

roving_design <- function(n_anglers = TRUE) {
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_season_counts,
    count_col = total_anglers, period_length_col = daylight_hours
  )
  args <- list(design, example_roving_interviews,
    catch = quote(catch_total), harvest = quote(catch_kept),
    effort = quote(hours_fished), trip_status = quote(trip_status),
    trip_duration = quote(hours_fished), interview_type = "roving"
  )
  if (n_anglers) args$n_anglers <- quote(n_anglers)
  suppressMessages(do.call(add_interviews, args))
}

# The creel_warning classes a call raises, with the value it returned.
raised <- function(expr) {
  seen <- character()
  value <- withCallingHandlers(
    suppressMessages(expr),
    creel_warning = function(w) {
      seen <<- c(seen, grep("^creel_warning_", class(w), value = TRUE)[1])
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, classes = seen)
}

test_that("a warning raised by an estimator is on the estimate, with its tier", {
  design <- roving_design()
  out <- raised(estimate_catch_rate(design))
  w <- get_warnings(out$value)
  expect_identical(w$class, out$classes)
  expect_identical(w$class, "creel_warning_mor_truncation")
  # Truncation is a data-quality fact (tier 2), not a may-be-wrong one.
  expect_identical(w$tier, 2L)
  expect_identical(w$fn, "mor_truncation_message")
  expect_match(w$message, "MOR truncation: 29 trips excluded")
  # Plain text: the record is for reading back, not for the console.
  expect_false(grepl("\033[", w$message, fixed = TRUE))
})

test_that("a total records the warnings of the rate it computes internally", {
  # The truncation that printed came from inside the total; reading the total
  # back must show it, or the record disagrees with what the console showed.
  design <- roving_design()
  out <- raised(estimate_total_catch(design, target = "period_total"))
  expect_true("creel_warning_mor_truncation" %in% out$classes)
  expect_setequal(get_warnings(out$value)$class, out$classes)
})

test_that("a warning muffled for one call is still recorded", {
  # Per-call handling quietens the console; it must not erase the fact.
  design <- roving_design()
  rate <- withCallingHandlers(
    suppressMessages(estimate_catch_rate(design)),
    creel_warning_mor_truncation = function(w) invokeRestart("muffleWarning")
  )
  expect_identical(get_warnings(rate)$class, "creel_warning_mor_truncation")
})

test_that("an estimate holds only its own call's warnings", {
  # Records are keyed to the call. If they leaked, the second estimate would
  # carry the first one's truncation and report a problem it does not have.
  design <- roving_design()
  first <- raised(estimate_catch_rate(design))
  expect_gt(nrow(get_warnings(first$value)), 0)
  second <- raised(estimate_effort(design, target = "period_total"))
  expect_identical(second$classes, character())
  expect_identical(nrow(get_warnings(second$value)), 0L)
})

test_that("a design keeps the warnings of each step that built it", {
  design <- raised(roving_design(n_anglers = FALSE))
  w <- get_warnings(design$value)
  expect_identical(w$class, design$classes)
  expect_true("creel_warning_no_party_size" %in% w$class)
  # Units: an estimate from this design may be per party-hour.
  expect_identical(w$tier[w$class == "creel_warning_no_party_size"], 1L)
  # Named even though roving_design() reaches add_interviews() by do.call().
  expect_identical(w$fn[w$class == "creel_warning_no_party_size"], "add_interviews")
})

test_that("a later step adds to the design's record and keeps what was there", {
  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  design <- raised(add_interviews(design, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  ))$value
  before <- get_warnings(design)
  expect_true("creel_warning_no_party_size" %in% before$class)
  after <- add_catch(design, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )
  expect_true(all(before$id %in% get_warnings(after)$id))
  # The record is the design's own; a step does not duplicate it.
  expect_false(anyDuplicated(get_warnings(after)$id) > 0)
})

test_that("nothing raised gives an empty table with the documented columns", {
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  w <- get_warnings(design)
  expect_identical(nrow(w), 0L)
  expect_named(w, c("id", "class", "tier", "fn", "message"))
})

test_that("get_warnings() refuses an object that keeps no record", {
  expect_error(get_warnings(data.frame()), class = "creel_error_get_warnings_class")
})

test_that("finished calls do not accumulate in the session log", {
  # The log only needs the calls in progress; a long season script must not
  # grow it without bound.
  design <- roving_design()
  for (i in 1:5) raised(estimate_catch_rate(design))
  expect_lte(length(tidycreel:::creel_warning_log$records), 1L)
})
