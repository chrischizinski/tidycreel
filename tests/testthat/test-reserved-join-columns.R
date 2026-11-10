# GH #600: a join whose right-hand table brings a column the user's data
# already has suffixes both copies (`.x`/`.y`). The helper column the next line
# reads is then NULL, and the estimator failed with a base-R "replacement has 0
# rows, data has 4" that named neither the column nor the fix. No wrong number
# came out -- every case failed -- but the message gave the user nothing to go
# on. Each join now refuses the clash up front, with the classed error #598
# introduced for `.fpc_days`, and names the column.
#
# Only the route that performs the join refuses: a column that no join on the
# route collides with is ignored, as any extra column is.

quiet <- function(x) suppressWarnings(suppressMessages(x))

# ---- Counts: expanded-target and within-day joins ---------------------------

# 8 calendar days, 4 sampled, two counts a day, so both the within-day table
# (ss_d, k_d) and the expansion to the period (.N_avail, .n_sampled) are joined.
reserved_count_design <- function(extra = NULL) {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:7,
    day_type = rep(c("weekday", "weekend"), each = 4)
  )
  cnt <- data.frame(
    date = rep(cal$date[c(1, 2, 5, 6)], each = 2),
    day_type = rep(cal$day_type[c(1, 2, 5, 6)], each = 2),
    t = rep(1:2, 4),
    count = c(10, 14, 9, 12, 20, 16, 30, 26)
  )
  if (!is.null(extra)) cnt[[extra]] <- 99
  quiet(add_counts(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    cnt,
    count_time_col = t, count_col = count # nolint: object_usage_linter
  ))
}

test_that("#600: a count column named like an expansion helper is refused by name", {
  for (nm in c(".N_avail", ".n_sampled")) {
    d <- reserved_count_design(nm)
    err <- expect_error(
      quiet(estimate_effort(d, target = "period_total")),
      class = "creel_error_reserved_column",
      info = nm
    )
    expect_match(conditionMessage(err), nm, fixed = TRUE, info = nm)
    # The sampled-day total does not expand, so it does not join these and
    # must not refuse: the column is an ordinary extra column there.
    expect_equal(
      quiet(estimate_effort(d, target = "sampled_days"))$estimates$estimate,
      quiet(estimate_effort(reserved_count_design(), target = "sampled_days"))$estimates$estimate,
      info = nm
    )
  }
})

test_that("#600: a count column named .expansion_weight is not refused", {
  # No join adds it: the weight is assigned onto the internal copy after the
  # joins, so the user's column is replaced there and never read. Refusing it
  # would break a call that gives the right answer.
  expect_equal(
    quiet(estimate_effort(reserved_count_design(".expansion_weight"), target = "period_total"))$estimates,
    quiet(estimate_effort(reserved_count_design(), target = "period_total"))$estimates
  )
})

test_that("#600: a count column named ss_d or k_d is refused by name", {
  # The within-day variance table carries these two; it is joined for every
  # target once a day has two or more counts.
  for (nm in c("ss_d", "k_d")) {
    for (target in c("sampled_days", "period_total")) {
      err <- expect_error(
        quiet(estimate_effort(reserved_count_design(nm), target = target)),
        class = "creel_error_reserved_column",
        info = paste(nm, target)
      )
      expect_match(conditionMessage(err), nm, fixed = TRUE)
    }
  }
})

# ---- Interviews: species and release joins ----------------------------------

reserved_interview_design <- function(extra = NULL) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  iv <- example_interviews
  if (!is.null(extra)) iv[[extra]] <- 99
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(d, example_counts)
  d <- add_interviews(
    d, iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
  quiet(add_catch(
    d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

test_that("#600: an interview column named .species_count is refused by species estimates", {
  d <- quiet(reserved_interview_design(".species_count"))
  for (f in list(
    function() estimate_catch_rate(d, by = species), # nolint: object_usage_linter
    function() estimate_total_catch(d, by = species) # nolint: object_usage_linter
  )) {
    err <- expect_error(quiet(f()), class = "creel_error_reserved_column")
    expect_match(conditionMessage(err), ".species_count", fixed = TRUE)
  }
})

test_that("#600: an interview column named .release_count is refused by release estimates", {
  d <- quiet(reserved_interview_design(".release_count"))
  for (f in list(
    function() estimate_release_rate(d),
    function() estimate_release_rate(d, by = species), # nolint: object_usage_linter
    function() estimate_total_release(d)
  )) {
    err <- expect_error(quiet(f()), class = "creel_error_reserved_column")
    expect_match(conditionMessage(err), ".release_count", fixed = TRUE)
  }
})

# ---- Bus route: the sampled-day register join -------------------------------

test_that("#600: a bus-route interview column named .N_avail or .n_sampled is refused", {
  # With creel_design(sampled = ), the expanded bus-route total joins each
  # stratum's population and sampled days onto the interviews.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:3,
    day_type = "weekday",
    worked = c(TRUE, TRUE, FALSE, FALSE)
  )
  sf <- data.frame(site = c("A", "B"), circuit = "c", p_site = c(0.5, 0.5), p_period = 0.5)
  mk <- function(extra = NULL) {
    iv <- data.frame(
      iid = 1:4, date = cal$date[c(1, 1, 2, 2)], day_type = "weekday",
      site = c("A", "B", "A", "B"), circuit = "c",
      hrs = c(2, 4, 3, 1), catch = c(1, 3, 2, 0), kept = c(1, 2, 1, 0),
      trip_status = "complete", n_counted = 1L, n_interviewed = 1L
    )
    if (!is.null(extra)) iv[[extra]] <- 99
    d <- quiet(creel_design(
      cal,
      date = date, strata = day_type, survey_type = "bus_route", # nolint: object_usage_linter
      sampling_frame = sf, site = site, circuit = circuit, # nolint: object_usage_linter
      p_site = p_site, p_period = p_period, sampled = worked # nolint: object_usage_linter
    ))
    quiet(add_interviews(
      d, iv,
      effort = hrs, catch = catch, harvest = kept, trip_status = trip_status, # nolint: object_usage_linter
      n_counted = n_counted, n_interviewed = n_interviewed, n_anglers = 1 # nolint: object_usage_linter
    ))
  }
  base <- quiet(estimate_effort(mk(), target = "sampled_days"))$estimates
  expect_true(is.finite(quiet(estimate_effort(mk(), target = "period_total"))$estimates$estimate))
  for (nm in c(".N_avail", ".n_sampled")) {
    # The sampled-day total joins the same table but never reads it, so the
    # clash is harmless there and is not refused.
    expect_equal(quiet(estimate_effort(mk(nm), target = "sampled_days"))$estimates, base, info = nm)
    err <- expect_error(
      quiet(estimate_effort(mk(nm), target = "period_total")),
      class = "creel_error_reserved_column",
      info = nm
    )
    expect_match(conditionMessage(err), nm, fixed = TRUE)
  }
})
