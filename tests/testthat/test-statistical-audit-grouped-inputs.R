# A grouped tibble kept its dplyr grouping when the design stored it, and every
# later distinct()/count()/join on the stored table then worked within groups
# (GH #441). Measured before the fix: counts grouped by a non-stratum column
# inflated stratum-total effort 4.3-fold (358.6 -> 1532.3); a grouped calendar
# split N_h and reported a census (SE 141 -> 0); grouping by date -- the usual
# leftover of group_by(date, ...) |> summarise() -- failed with a cryptic
# error. None of it warned. Inputs are now ungrouped at every entry point.

gi_grouped <- function(df, col) {
  dplyr::group_by(tibble::as_tibble(df), dplyr::across(dplyr::all_of(col)))
}

# Every table stored anywhere in the design, however deeply nested.
gi_any_grouped <- function(x) {
  if (inherits(x, c("grouped_df", "rowwise_df"))) {
    return(TRUE)
  }
  if (is.list(x) && !is.data.frame(x)) {
    return(any(vapply(x, gi_any_grouped, logical(1))))
  }
  FALSE
}

gi_data <- function() {
  data(example_calendar, package = "tidycreel", envir = environment())
  data(example_counts, package = "tidycreel", envir = environment())
  data(example_interviews, package = "tidycreel", envir = environment())
  data(example_catch, package = "tidycreel", envir = environment())
  cal <- example_calendar # nolint: object_usage_linter
  cal$week <- paste0("w", format(cal$date, "%U"))
  # 9 of 14 days counted, so no stratum is a census and an SE can fall to 0
  cn <- example_counts[c(1, 2, 3, 5, 6, 8, 10, 12, 13), ] # nolint: object_usage_linter
  cn$week <- paste0("w", format(cn$date, "%U"))
  list(cal = cal, cn = cn, iv = example_interviews, ct = example_catch) # nolint: object_usage_linter
}

gi_design <- function(cal, cn, iv = NULL, ct = NULL) {
  d <- suppressWarnings(suppressMessages(creel_design(cal, date = date, strata = day_type))) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, cn))) # nolint: object_usage_linter
  if (!is.null(iv)) {
    d <- suppressWarnings(suppressMessages(add_interviews( # nolint: object_usage_linter
      d, iv, catch = catch_total, harvest = catch_kept, effort = hours_fished,
      n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration
    )))
  }
  if (!is.null(ct)) {
    d <- suppressWarnings(suppressMessages(add_catch( # nolint: object_usage_linter
      d, ct, catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )))
  }
  d
}

gi_effort <- function(d) {
  vapply(c("stratum_total", "period_total"), function(tg) {
    e <- suppressWarnings(suppressMessages(estimate_effort(d, target = tg)))$estimates # nolint: object_usage_linter
    c(e$estimate, e$se)
  }, numeric(2))
}

test_that("#441: counts grouped by any column give the ungrouped effort and SE", {
  x <- gi_data()
  base <- gi_effort(gi_design(x$cal, x$cn))
  # week: a non-stratum column (was x4.3); date: the summarise() leftover
  # (was an error); day_type: the stratum (was already harmless)
  for (col in c("week", "date", "day_type")) {
    d <- gi_design(x$cal, gi_grouped(x$cn, col))
    expect_false(gi_any_grouped(d), info = col)
    expect_equal(gi_effort(d), base, tolerance = 1e-12, info = col)
  }
  d <- gi_design(x$cal, dplyr::rowwise(tibble::as_tibble(x$cn)))
  expect_false(gi_any_grouped(d), info = "rowwise")
  expect_equal(gi_effort(d), base, tolerance = 1e-12, info = "rowwise")
})

test_that("#441: a grouped calendar gives the ungrouped effort and SE", {
  x <- gi_data()
  base <- gi_effort(gi_design(x$cal, x$cn))
  for (col in c("week", "date", "day_type")) {
    d <- gi_design(gi_grouped(x$cal, col), x$cn)
    expect_false(gi_any_grouped(d), info = col)
    expect_equal(gi_effort(d), base, tolerance = 1e-12, info = col)
  }
})

test_that("#441: the issue's grouped-calendar census is gone (SE 141, not 0)", {
  cal <- data.frame(date = as.Date("2024-06-03") + c(0:3, 7:10), day_type = "weekday",
                    week = rep(c("w1", "w2"), each = 4))
  cn <- data.frame(date = cal$date[c(1, 2, 5, 6)], count_time = "08:00",
                   anglers = c(10, 14, 9, 20), hours = 10, day_type = "weekday")
  build <- function(cal) {
    d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
    d <- suppressWarnings(suppressMessages(add_counts( # nolint: object_usage_linter
      d, cn, count_col = anglers, count_time_col = count_time, period_length_col = hours
    )))
    suppressWarnings(suppressMessages(estimate_effort(d, target = "stratum_total")))$estimates # nolint: object_usage_linter
  }
  plain <- build(cal)
  grouped <- build(gi_grouped(cal, "week"))
  expect_gt(grouped$se, 0)
  expect_equal(grouped$se, plain$se, tolerance = 1e-12)
  expect_equal(grouped$estimate, plain$estimate, tolerance = 1e-12)
})

test_that("#441: interviews and catch are stored ungrouped and estimate as ungrouped", {
  x <- gi_data()
  rates <- function(d) {
    c(
      suppressWarnings(suppressMessages(estimate_catch_rate(d)))$estimates$estimate, # nolint: object_usage_linter
      suppressWarnings(suppressMessages(estimate_total_catch(d)))$estimates$se # nolint: object_usage_linter
    )
  }
  base <- rates(gi_design(x$cal, x$cn, x$iv, x$ct))
  d_iv <- gi_design(x$cal, x$cn, gi_grouped(x$iv, "angler_method"), x$ct)
  d_ct <- gi_design(x$cal, x$cn, x$iv, gi_grouped(x$ct, "catch_type"))
  expect_false(gi_any_grouped(d_iv))
  expect_false(gi_any_grouped(d_ct))
  expect_equal(rates(d_iv), base, tolerance = 1e-12)
  expect_equal(rates(d_ct), base, tolerance = 1e-12)
})

test_that("#441: add_sections(), add_lengths() and add_ages() store ungrouped tables", {
  x <- gi_data()
  d <- gi_design(x$cal, x$cn, x$iv)
  data(example_lengths, package = "tidycreel", envir = environment())
  ln <- suppressWarnings(suppressMessages(add_lengths( # nolint: object_usage_linter
    d, gi_grouped(example_lengths, "species"), # nolint: object_usage_linter
    length_uid = interview_id, interview_uid = interview_id, species = species,
    length = length, length_type = length_type, count = count, release_format = "binned"
  )))
  expect_false(gi_any_grouped(ln))

  ages <- data.frame(interview_id = 1:5, species = "walleye", est_age = c(2L, 4L, 3L, 5L, 2L),
                     fate = "harvest")
  ag <- suppressWarnings(suppressMessages(add_ages( # nolint: object_usage_linter
    d, gi_grouped(ages, "species"), age_uid = interview_id, interview_uid = interview_id,
    species = species, age = est_age, age_type = fate
  )))
  expect_false(gi_any_grouped(ag))

  sec <- suppressWarnings(suppressMessages(creel_design(x$cal, date = date, strata = day_type))) # nolint: object_usage_linter
  sec <- suppressWarnings(suppressMessages(add_sections( # nolint: object_usage_linter
    sec, gi_grouped(data.frame(section = c("North", "South")), "section"), section_col = section
  )))
  expect_false(gi_any_grouped(sec))
})

test_that("#441: a bus-route sampling frame is stored ungrouped", {
  cal <- build_property_calendar(6L) # nolint: object_usage_linter
  sf <- data.frame(site = c("S1", "S2", "S3"), circuit = "C1", p_site = c(0.2, 0.3, 0.5),
                   p_period = 0.8)
  d <- suppressWarnings(suppressMessages(creel_design( # nolint: object_usage_linter
    cal, date = date, strata = day_type, survey_type = "bus_route",
    sampling_frame = gi_grouped(sf, "circuit"), site = site, circuit = circuit,
    p_site = p_site, p_period = p_period
  )))
  expect_false(gi_any_grouped(d))
})
