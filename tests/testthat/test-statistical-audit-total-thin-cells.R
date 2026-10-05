# A total is a sum of products, one per stratum (and per stratum x `by` cell),
# and each product's rate is a ratio estimate built from that cell's trips alone.
# The totals checked only the groups the caller asked for, so a total could rest
# on a 7-trip stratum with no signal: on the package example the headline
# `estimate_total_catch(d)` multiplies the weekend effort by a rate from 7 complete
# trips while `estimate_catch_rate(d, by = day_type)` refuses that same rate
# (GH #417, following #377). The cells are now reported as a warning, not an error.
#
# Warn, not refuse, because refusing would stop the package's own example and
# whether the floor is a validity floor for those cells has not been decided.

ttc_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

# Collect the thin-cell warnings (and only those) from one call.
ttc_thin_warnings <- function(expr) {
  got <- list()
  withCallingHandlers(
    suppressMessages(expr),
    warning = function(w) {
      if (inherits(w, "creel_warning_thin_rate_cells")) {
        got[[length(got) + 1L]] <<- w
      }
      invokeRestart("muffleWarning")
    }
  )
  got
}

ttc_example_design <- function(with_catch = TRUE) {
  data(example_counts, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- ttc_quiet(add_counts(d, example_counts)) # nolint: object_usage_linter
  d <- ttc_quiet(add_interviews( # nolint: object_usage_linter
    d, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  if (with_catch) {
    data(example_catch, package = "tidycreel")
    d <- ttc_quiet(add_catch( # nolint: object_usage_linter
      d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ))
  }
  d
}

# Eight days, strata day_type, `n_interviews` complete trips, with catch records
# (release totals need them).
ttc_design <- function(n_interviews) {
  set.seed(1)
  cal <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = 8L),
    day_type = rep_len(c("weekday", "weekend"), 8L), stringsAsFactors = FALSE
  )
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  counts <- data.frame(
    date = cal$date, day_type = cal$day_type,
    effort_hours = c(15, 23, 18, 21, 45, 52, 48, 51), period_hours = 12
  )
  d <- ttc_quiet(add_counts(d, counts, period_length_col = period_hours)) # nolint: object_usage_linter
  cd <- build_species_catch_for_tests(seq_len(n_interviews), 2L, TRUE) # nolint: object_usage_linter
  iv <- build_trip_interviews_for_tests( # nolint: object_usage_linter
    cal, n_interviews, cd$interview_catch_total, cd$interview_catch_kept
  )
  d <- ttc_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration, # nolint: object_usage_linter
    n_counted = n_counted, n_interviewed = n_interviewed # nolint: object_usage_linter
  ))
  ttc_quiet(add_catch( # nolint: object_usage_linter
    d, add_released_rows_for_tests(cd$catch_df), # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

ttc_totals <- list(
  catch = estimate_total_catch, # nolint: object_usage_linter
  harvest = estimate_total_harvest, # nolint: object_usage_linter
  release = estimate_total_release # nolint: object_usage_linter
)

test_that("#417: an ungrouped total warns once, naming the thin stratum and its n", {
  d <- ttc_example_design()
  for (nm in names(ttc_totals)) {
    got <- ttc_thin_warnings(ttc_totals[[nm]](d))
    # One warning per call, however many paths the call passes through.
    expect_length(got, 1L)
    msg <- conditionMessage(got[[1]])
    expect_match(msg, "day_type=weekend: n=7", fixed = TRUE, info = nm)
    # Weekday has exactly 10 complete trips: at the floor, not under it.
    expect_false(grepl("day_type=weekday", msg, fixed = TRUE), info = nm)
  }
})

test_that("#417: it is a warning, not a refusal: the total is still returned", {
  d <- ttc_example_design()
  res <- ttc_quiet(estimate_total_catch(d))
  expect_s3_class(res, "creel_estimates")
  expect_false(is.na(res$estimates$estimate))
})

test_that("#417: the species path reports its thin strata too", {
  d <- ttc_example_design(with_catch = TRUE)
  for (nm in names(ttc_totals)) {
    got <- ttc_thin_warnings(ttc_totals[[nm]](d, by = species)) # nolint: object_usage_linter
    expect_length(got, 1L)
    expect_match(conditionMessage(got[[1]]), "day_type=weekend: n=7", fixed = TRUE, info = nm)
  }
})

test_that("#417: a grouped total warns on thin cells whose BY-GROUP clears the floor", {
  # Totals can only group by columns the counts carry, so a stratum x by cell
  # finer than the group arises where the group is counted across the whole lake
  # and the cells are per section. `by = day_type` has 18 trips a group (clears
  # the #377 floor); each section's day-type cell has about 9.
  d <- make_sectioned_species_design(n_interviews = 36L) # nolint: object_usage_linter
  for (nm in names(ttc_totals)) {
    res <- NULL
    got <- ttc_thin_warnings(res <- ttc_totals[[nm]](d, by = day_type))
    expect_s3_class(res, "creel_estimates")
    msgs <- vapply(got, conditionMessage, character(1))
    expect_true(any(grepl("section=North, day_type=", msgs, fixed = TRUE)), info = nm)
    expect_true(any(grepl("section=South, day_type=", msgs, fixed = TRUE)), info = nm)
  }
})

test_that("#409: an ungrouped sectioned total checks each section x stratum rate cell", {
  # The total is now the stratified sum, sum_h(E_h x rate_h) per section, so each
  # section's day-type cell is a ratio estimate in its own right and is what a
  # thin rate means (GH #409). Before #409 it multiplied a section's effort by
  # one pooled rate and this test pinned the pooled count instead (#417). 36
  # interviews leave 18 per section and day-type cells of 8 or 10: the 8s warn,
  # named by section and day type, and the old pooled form never appears.
  d <- make_sectioned_species_design(n_interviews = 36L) # nolint: object_usage_linter
  for (nm in names(ttc_totals)) {
    msgs <- vapply(ttc_thin_warnings(ttc_totals[[nm]](d)), conditionMessage, character(1))
    expect_gt(length(msgs), 0L)
    expect_true(all(grepl("section=(North|South), day_type=", msgs)), info = nm)
    expect_false(any(grepl("section=(North|South): n=", msgs)), info = nm)
  }
})

test_that("#417: it does not over-warn: cells at or above 10 trips stay silent", {
  # One factor: the sample size. 80 interviews leave 40 per day type.
  big <- ttc_design(80L)
  for (nm in names(ttc_totals)) {
    expect_length(ttc_thin_warnings(ttc_totals[[nm]](big)), 0L)
    expect_length(ttc_thin_warnings(ttc_totals[[nm]](big, by = day_type)), 0L)
  }
  # And the same builder at 12 does warn, so silence above is not an artefact.
  small <- ttc_design(12L)
  expect_length(ttc_thin_warnings(estimate_total_catch(small)), 1L)
})
