# Count-observability of `by=` (GH #241) ----
#
# Effort is estimated from the counts, so `by=` on effort and on any total can
# only name a column the count data carries. That refusal is statistically
# correct and must stay. What these tests pin is the *explanation*: tidyselect
# reported it as "Column `x` doesn't exist", which is false to the user's
# situation -- the column does exist, in the interviews, and worked in
# `estimate_catch_rate(by=)` one call earlier. A biologist reading the old
# message reasonably concludes the argument is inconsistent and copies the
# column into the counts, which fabricates a classification the counter never
# made and biases the result. The message is the guard against that.

#' Design whose interviews carry an attribute the counts do not
#'
#' `target` (species sought) is knowable only by asking an angler. A counter
#' driving past cannot classify it, so it can never group effort.
make_count_unobservable_design <- function(n_interviews = 24L) {
  cal <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = 8L),
    day_type = rep_len(c("weekday", "weekend"), 8L),
    stringsAsFactors = FALSE
  )

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = c(15, 23, 18, 21, 45, 52, 48, 51),
    period_hours = rep(12, 8L),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    add_counts(design, counts, period_length_col = period_hours)
  ))

  catch_data <- build_species_catch_for_tests(
    interview_ids = seq_len(n_interviews),
    n_species = 2L,
    include_harvest = TRUE
  )
  interviews <- build_trip_interviews_for_tests(
    calendar = cal,
    n_interviews = n_interviews,
    catch_total = catch_data$interview_catch_total,
    catch_kept = catch_data$interview_catch_kept
  )
  # The interview-only attribute under test.
  interviews$target <- rep_len(c("bass", "bluegill"), n_interviews)

  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    n_anglers = n_anglers,
    trip_status = trip_status,
    trip_duration = trip_duration,
    n_counted = n_counted,
    n_interviewed = n_interviewed
  )))

  suppressMessages(suppressWarnings(add_catch(
    design,
    catch_data$catch_df,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )))
}

test_that("CBY-01: estimate_effort names the count constraint, not a missing column", {
  set.seed(241)
  design <- make_count_unobservable_design()

  # The class is what callers can branch on; the old failure was an
  # undifferentiated vctrs subscript error shared with genuine typos.
  expect_error(
    estimate_effort(design, by = target), # nolint: object_usage_linter
    class = "creel_error_count_unobservable_by"
  )
})

test_that("CBY-02: the message says the column is in the interviews, and lists what can group effort", {
  set.seed(241)
  design <- make_count_unobservable_design()

  err <- expect_error(estimate_effort(design, by = target)) # nolint: object_usage_linter
  msg <- cli::ansi_strip(conditionMessage(err))

  # Names the actual state the user is in: it exists, just not where effort comes from.
  expect_match(msg, "target")
  expect_match(msg, "interview data but not the count data")
  # Tells them what they *can* group by, so the next call is a fix not a guess.
  expect_match(msg, "day_type")
  # Blocks the wrong workaround explicitly.
  expect_match(msg, "fabricate a classification")
})

test_that("CBY-03: the message routes to the rate, which really does accept the same column", {
  set.seed(241)
  design <- make_count_unobservable_design()

  err <- expect_error(estimate_effort(design, by = target)) # nolint: object_usage_linter
  expect_match(cli::ansi_strip(conditionMessage(err)), "estimate_catch_rate(by = target)", fixed = TRUE)

  # The suggestion has to be true, or it is worse than no suggestion. This is
  # the contrast that made the old message misleading in the first place.
  rate <- suppressMessages(suppressWarnings(
    estimate_catch_rate(design, by = target) # nolint: object_usage_linter
  ))
  expect_true("target" %in% names(rate$estimates))
})

test_that("CBY-04: a mixed selector names only the count-unobservable part", {
  set.seed(241)
  design <- make_count_unobservable_design()

  err <- expect_error(
    estimate_effort(design, by = c(day_type, target)), # nolint: object_usage_linter
    class = "creel_error_count_unobservable_by"
  )
  msg <- cli::ansi_strip(conditionMessage(err))
  # day_type is groupable and must not be reported as the offender.
  expect_match(msg, "target is in the interview data")
})

test_that("CBY-05: a column in neither table still raises tidyselect's own error", {
  set.seed(241)
  design <- make_count_unobservable_design()

  # Over-catching would relabel ordinary typos as a statistical constraint.
  expect_error(
    estimate_effort(design, by = nonexistent_col), # nolint: object_usage_linter
    class = "vctrs_error_subscript_oob"
  )
})

test_that("CBY-06: totals raise the same constraint, and offer the species route", {
  set.seed(241)
  design <- make_count_unobservable_design()

  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    err <- expect_error(
      fn(design, by = target), # nolint: object_usage_linter
      class = "creel_error_count_unobservable_by"
    )
    # A total needs effort at the domain, so species is routed through catch
    # apportionment against whole effort rather than by splitting effort.
    expect_match(cli::ansi_strip(conditionMessage(err)), "apportions catch against whole effort")
  }

  # estimate_effort() has no species route, so it must not advertise one.
  err_effort <- expect_error(estimate_effort(design, by = target)) # nolint: object_usage_linter
  expect_no_match(cli::ansi_strip(conditionMessage(err_effort)), "apportions catch")
})

test_that("CBY-07: a groupable column is unaffected by the new error path", {
  set.seed(241)
  design <- make_count_unobservable_design()

  # The guard wraps the existing resolution, so selectors that worked must be
  # untouched -- including helper selectors, which would change meaning if the
  # selector were resolved against counts and interviews together.
  eff <- suppressMessages(suppressWarnings(
    estimate_effort(design, by = day_type) # nolint: object_usage_linter
  ))
  expect_true("day_type" %in% names(eff$estimates))

  eff_sel <- suppressMessages(suppressWarnings(
    estimate_effort(design, by = starts_with("day")) # nolint: object_usage_linter
  ))
  expect_identical(eff_sel$estimates$day_type, eff$estimates$day_type)

  tot <- suppressMessages(suppressWarnings(
    estimate_total_catch(design, by = day_type) # nolint: object_usage_linter
  ))
  expect_true("day_type" %in% names(tot$estimates))
})
