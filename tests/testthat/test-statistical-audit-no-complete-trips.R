# On a design with no complete trips the default trip filter keeps nothing. The
# rate functions stopped there by name ("No complete trips available for HPUE
# estimation") and so did the bus-route paths (GH #128), but the three totals
# rebuilt the interview survey from an empty frame and died inside survey's
# rowSums(): "all arguments must have the same length", an unclassed base error
# that names neither trips nor `use_trips` (GH #410).

nct_design <- function(trip_status = "incomplete", with_catch = TRUE) {
  data(example_counts, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  iv <- example_interviews
  if (!is.null(trip_status)) {
    iv$trip_status <- trip_status
  }
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, example_counts))) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
  if (with_catch) {
    data(example_catch, package = "tidycreel")
    d <- suppressWarnings(suppressMessages(add_catch( # nolint: object_usage_linter
      d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    )))
  }
  d
}

nct_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

nct_totals <- list(
  catch = estimate_total_catch, # nolint: object_usage_linter
  harvest = estimate_total_harvest, # nolint: object_usage_linter
  release = estimate_total_release # nolint: object_usage_linter
)
nct_rates <- list(
  catch = estimate_catch_rate, # nolint: object_usage_linter
  harvest = estimate_harvest_rate, # nolint: object_usage_linter
  release = estimate_release_rate # nolint: object_usage_linter
)

test_that("#410: every total path names the missing trips, in a classed error", {
  d <- nct_design()
  for (nm in names(nct_totals)) {
    f <- nct_totals[[nm]]
    for (path in list(NULL, quote(day_type), quote(species))) {
      call_it <- function() {
        if (is.null(path)) {
          nct_quiet(f(d))
        } else {
          nct_quiet(eval(bquote(f(d, by = .(path)))))
        }
      }
      label <- paste(nm, if (is.null(path)) "ungrouped" else deparse(path))
      err <- tryCatch(call_it(), error = function(e) e)
      # Not the base rowSums() failure it used to be.
      expect_s3_class(err, "creel_error_no_complete_trips")
      expect_false(inherits(err, "simpleError"), info = label)
      expect_match(conditionMessage(err), paste("total", nm), fixed = TRUE, info = label)
      expect_match(conditionMessage(err), "use_trips", fixed = TRUE, info = label)
      expect_no_match(conditionMessage(err), "rowSums|same length", info = label)
    }
  }
})

test_that("#410: the rate functions already stop on the same condition, and share the class", {
  d <- nct_design()
  for (nm in names(nct_rates)) {
    expect_error(
      nct_quiet(nct_rates[[nm]](d)),
      class = "creel_error_no_complete_trips"
    )
  }
})

test_that("#410: a sectioned design with no complete trips is stopped the same way", {
  d <- make_sectioned_species_design() # nolint: object_usage_linter
  d$interviews$trip_status <- "incomplete"
  for (nm in names(nct_totals)) {
    expect_error(
      nct_quiet(nct_totals[[nm]](d)),
      class = "creel_error_no_complete_trips"
    )
  }
})

test_that("#410: the remedies the message recommends work, and only in the stated form", {
  d <- nct_design()
  for (nm in names(nct_totals)) {
    f <- nct_totals[[nm]]
    expect_s3_class(nct_quiet(f(d, use_trips = "all")), "creel_estimates")
    expect_s3_class(nct_quiet(f(d, use_trips = "all", estimator = "mor")), "creel_estimates")
    # `estimator = "mor"` alone leaves the trip set at "complete": the message
    # says so, and this pins that it is true.
    expect_error(
      nct_quiet(f(d, estimator = "mor")),
      class = "creel_error_no_complete_trips"
    )
  }
})

test_that("#410: it does not fire when there are complete trips", {
  d <- nct_design(trip_status = NULL)
  for (nm in names(nct_totals)) {
    expect_no_error(nct_quiet(nct_totals[[nm]](d)))
  }
})
