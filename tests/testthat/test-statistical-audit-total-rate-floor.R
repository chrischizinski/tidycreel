# A total is effort x a rate. The rate functions refuse a `by` group with fewer
# than 10 trips (`validate_ratio_sample_size()`), but the totals never called it:
# on the package example, `estimate_catch_rate(d, by = day_type)` refused the
# weekend group (n = 7) while `estimate_total_catch(d, by = day_type)` returned a
# weekend total built on that same rate, with no warning (GH #377). The two
# cannot both be right; the totals now put the groups the caller asked for
# through the same validator, on the same trip-filtered interviews.
#
# Deliberately NOT covered, and pinned below so it stays a decision and not an
# accident: the stratum x `by` cells a total actually multiplies, and the
# ungrouped total. Both are tracked separately.

trf_design <- function(n_interviews) {
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
  d <- suppressMessages(suppressWarnings(add_counts(d, counts, period_length_col = period_hours))) # nolint: object_usage_linter
  cd <- build_species_catch_for_tests(seq_len(n_interviews), 2L, TRUE) # nolint: object_usage_linter
  iv <- build_trip_interviews_for_tests( # nolint: object_usage_linter
    cal, n_interviews, cd$interview_catch_total, cd$interview_catch_kept
  )
  d <- suppressMessages(suppressWarnings(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration, # nolint: object_usage_linter
    n_counted = n_counted, n_interviewed = n_interviewed # nolint: object_usage_linter
  )))
  suppressMessages(suppressWarnings(add_catch( # nolint: object_usage_linter
    d, add_released_rows_for_tests(cd$catch_df), # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )))
}

trf_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

# (total, its rate): the pairs the issue says must agree.
trf_pairs <- list(
  catch = list(total = estimate_total_catch, rate = estimate_catch_rate), # nolint: object_usage_linter
  harvest = list(total = estimate_total_harvest, rate = estimate_harvest_rate), # nolint: object_usage_linter
  release = list(total = estimate_total_release, rate = estimate_release_rate) # nolint: object_usage_linter
)

test_that("#377: a grouped total refuses exactly when its rate refuses (the package example)", {
  # The issue's own reproduction: weekend has 7 complete trips.
  data(example_counts, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- trf_quiet(add_counts(d, example_counts)) # nolint: object_usage_linter
  d <- trf_quiet(add_interviews( # nolint: object_usage_linter
    d, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  data(example_catch, package = "tidycreel")
  d <- trf_quiet(add_catch( # nolint: object_usage_linter
    d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
  for (p in trf_pairs) {
    expect_error(trf_quiet(p$rate(d, by = day_type)), "Insufficient sample size") # nolint: object_usage_linter
    expect_error(trf_quiet(p$total(d, by = day_type)), "Insufficient sample size") # nolint: object_usage_linter
  }
})

test_that("#377: parity across the twins and the species path varies only the sample size", {
  # One factor: n_interviews. 12 -> 6 per day type (refused); 40 -> 20 (clear).
  small <- trf_design(12L)
  large <- trf_design(40L)
  for (nm in names(trf_pairs)) {
    p <- trf_pairs[[nm]]
    for (by_arg in list(quote(day_type), quote(c(day_type, species)))) {
      call_total <- function(d) trf_quiet(eval(bquote(p$total(d, by = .(by_arg)))))
      call_rate <- function(d) trf_quiet(eval(bquote(p$rate(d, by = .(by_arg)))))
      label <- paste(nm, deparse(by_arg))
      expect_error(call_rate(small), "Insufficient sample size", info = label)
      expect_error(call_total(small), "Insufficient sample size", info = label)
      # The floor does not over-refuse: the same calls clear at n = 20 a group.
      expect_no_error(call_rate(large))
      expect_no_error(call_total(large))
    }
  }
})

test_that("#377: the total's refusal is the rate's own message, naming the group", {
  # Same validator, so the same words: a user told the rate was too thin for a
  # group should be told the same about the total.
  small <- trf_design(12L)
  msg <- function(f) {
    tryCatch(
      {
        trf_quiet(f())
        NA_character_
      },
      error = function(e) conditionMessage(e)
    )
  }
  rate_msg <- msg(function() estimate_catch_rate(small, by = day_type)) # nolint: object_usage_linter
  total_msg <- msg(function() estimate_total_catch(small, by = day_type)) # nolint: object_usage_linter
  expect_match(total_msg, "day_type=weekday", fixed = TRUE)
  expect_match(total_msg, "n=6", fixed = TRUE)
  expect_identical(
    sub(".*(Insufficient sample size)", "\\1", total_msg),
    sub(".*(Insufficient sample size)", "\\1", rate_msg)
  )
})

test_that("#377: sectioned grouped and species totals honour the same floor", {
  # The sectioned path resolves `by` for itself and has its own species branch.
  small <- make_sectioned_species_design(n_interviews = 12L) # nolint: object_usage_linter
  large <- make_sectioned_species_design(n_interviews = 36L) # nolint: object_usage_linter
  for (p in trf_pairs) {
    expect_error(trf_quiet(p$total(small, by = day_type)), "Insufficient sample size") # nolint: object_usage_linter
    expect_error(trf_quiet(p$total(small, by = c(day_type, species))), "Insufficient sample size") # nolint: object_usage_linter
    expect_no_error(trf_quiet(p$total(large, by = day_type))) # nolint: object_usage_linter
    expect_no_error(trf_quiet(p$total(large, by = c(day_type, species)))) # nolint: object_usage_linter
  }
})

test_that("#377: scope boundary -- an ungrouped total is unchanged, even on thin strata", {
  # Pinned on purpose. With no `by` there is no group to mirror, and the
  # stratum cells a total multiplies are a wider question than the rate
  # function's own floor. At 12 interviews each stratum has 6 trips and the
  # ungrouped total still returns, as it did before. Changing that is a decision,
  # not a side effect of this fix.
  small <- trf_design(12L)
  for (p in trf_pairs) {
    expect_no_error(trf_quiet(p$total(small))) # nolint: object_usage_linter
  }
})
