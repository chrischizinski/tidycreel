# Tests for Phase 32: compute_effort(), compute_angler_effort(),
# add_interviews() n_anglers default, summarize_cws_rates(), summarize_hws_rates().

# Fixtures ----

make_design_with_catch_for_cws <- function() { # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    species_sought = species_sought, # nolint: object_usage_linter
    angler_type = angler_type, # nolint: object_usage_linter
    n_anglers = n_anglers # nolint: object_usage_linter
  ))
  add_catch(d, example_catch, # nolint: object_usage_linter
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  )
}

make_design_no_catch <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    species_sought = species_sought # nolint: object_usage_linter
  ))
}

# compute_effort() tests ----

test_that("compute_effort() computes from timestamps when time_fished is NULL", {
  df <- data.frame(
    ts = as.POSIXct("2024-06-01 08:00"),
    it = as.POSIXct("2024-06-01 10:30")
  )
  result <- compute_effort(df, ts, it)
  expect_true(".effort" %in% names(result))
  expect_equal(result[[".effort"]], 2.5, tolerance = 1e-10)
})

test_that("compute_effort() uses time_fished override when non-NA", {
  df <- data.frame(
    ts = as.POSIXct(c("2024-06-01 08:00", "2024-06-01 09:00")),
    it = as.POSIXct(c("2024-06-01 10:30", "2024-06-01 12:00")),
    tf = c(NA_real_, 2.5)
  )
  result <- compute_effort(df, ts, it, tf)
  expect_equal(result[[".effort"]][1], 2.5, tolerance = 1e-10) # timestamp
  expect_equal(result[[".effort"]][2], 2.5, tolerance = 1e-10) # self-reported (overrides 3 hr timestamp)
})

test_that("compute_effort() preserves all original columns", {
  df <- data.frame(x = 1, ts = as.POSIXct("2024-06-01 08:00"), it = as.POSIXct("2024-06-01 10:00"))
  result <- compute_effort(df, ts, it)
  expect_true("x" %in% names(result))
  expect_true(".effort" %in% names(result))
})

test_that("compute_effort() handles all-NA time_fished (all use timestamps)", {
  df <- data.frame(
    ts = as.POSIXct(c("2024-06-01 08:00", "2024-06-01 09:00")),
    it = as.POSIXct(c("2024-06-01 10:00", "2024-06-01 11:00")),
    tf = c(NA_real_, NA_real_)
  )
  result <- compute_effort(df, ts, it, tf)
  expect_equal(result[[".effort"]], c(2.0, 2.0), tolerance = 1e-10)
})

# compute_angler_effort() tests ----

test_that("compute_angler_effort() multiplies effort by n_anglers", {
  df <- data.frame(eff = c(2.0, 3.0), ng = c(2L, 3L))
  result <- compute_angler_effort(df, eff, ng)
  expect_equal(result[[".angler_effort"]], c(4.0, 9.0), tolerance = 1e-10)
})

test_that("compute_angler_effort() with n_anglers = 1 returns effort unchanged", {
  df <- data.frame(eff = c(1.5, 2.0), ng = c(1L, 1L))
  result <- compute_angler_effort(df, eff, ng)
  expect_equal(result[[".angler_effort"]], c(1.5, 2.0), tolerance = 1e-10)
})

test_that("compute_angler_effort() preserves all original columns", {
  df <- data.frame(x = "a", eff = 2.0, ng = 2L)
  result <- compute_angler_effort(df, eff, ng)
  expect_true("x" %in% names(result))
  expect_true(".angler_effort" %in% names(result))
})

test_that("compute_angler_effort() returns numeric .angler_effort", {
  df <- data.frame(eff = 2.5, ng = 3L)
  result <- compute_angler_effort(df, eff, ng)
  expect_true(is.numeric(result[[".angler_effort"]]))
})

# add_interviews() n_anglers default (Phase 32) ----

test_that("add_interviews() without n_anglers emits cli_inform about assumption", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(creel_design(example_calendar, date = date, strata = day_type))
  expect_message(
    suppressWarnings(add_interviews(d, example_interviews,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status
    )),
    "assuming 1 angler"
  )
})

test_that("add_interviews() always sets angler_effort_col on returned design", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(creel_design(example_calendar, date = date, strata = day_type))
  d2 <- suppressWarnings(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status
  ))
  expect_equal(d2[["angler_effort_col"]], ".angler_effort")
  expect_true(".angler_effort" %in% names(d2[["interviews"]]))
})

test_that("add_interviews() with n_anglers=1 produces .angler_effort == effort", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(creel_design(example_calendar, date = date, strata = day_type))
  d2 <- suppressWarnings(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status
  ))
  ae <- d2[["interviews"]][[".angler_effort"]]
  ef <- d2[["interviews"]][[d2[["effort_col"]]]]
  expect_equal(ae, ef, tolerance = 1e-10)
})

test_that("add_interviews() with n_anglers column produces .angler_effort = effort * n_anglers", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(creel_design(example_calendar, date = date, strata = day_type))
  d2 <- suppressWarnings(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, n_anglers = n_anglers # nolint: object_usage_linter
  ))
  ae <- d2[["interviews"]][[".angler_effort"]]
  ef <- d2[["interviews"]][[d2[["effort_col"]]]]
  ng <- d2[["interviews"]][[d2[["n_anglers_col"]]]]
  expect_equal(ae, ef * ng, tolerance = 1e-10)
})

# summarize_cws_rates() guard tests ----

test_that("summarize_cws_rates() errors when design is not creel_design", {
  expect_error(
    summarize_cws_rates(list()),
    "must be a"
  )
})

test_that("summarize_cws_rates() errors when no interviews attached", {
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(creel_design(example_calendar, date = date, strata = day_type))
  expect_error(summarize_cws_rates(d), "No interviews found")
})

test_that("summarize_cws_rates() errors when species_sought_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(creel_design(example_calendar, date = date, strata = day_type))
  d2 <- suppressWarnings(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status # no species_sought
  ))
  expect_error(summarize_cws_rates(d2), "species_sought")
})

test_that("summarize_cws_rates() errors when no catch data attached", {
  expect_error(
    summarize_cws_rates(make_design_no_catch()),
    "No catch data found"
  )
})

# summarize_cws_rates() happy-path tests ----

test_that("summarize_cws_rates() returns correct columns when by = species_sought", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_cws_rates(d, by = species_sought) # nolint: object_usage_linter
  expected_cols <- c("species_sought", "N", "mean_rate", "se", "ci_lower", "ci_upper")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("summarize_cws_rates() returns class c('creel_summary_cws_rates', 'data.frame')", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_cws_rates(d, by = species_sought) # nolint: object_usage_linter
  expect_s3_class(result, "creel_summary_cws_rates")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_cws_rates() N column is integer", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_cws_rates(d, by = species_sought) # nolint: object_usage_linter
  expect_true(is.integer(result[["N"]]))
})

test_that("summarize_cws_rates() mean_rate is non-negative", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_cws_rates(d, by = species_sought) # nolint: object_usage_linter
  expect_true(all(result[["mean_rate"]] >= 0))
})

test_that("summarize_cws_rates() with by = c(angler_type, species_sought) returns grouping cols", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_cws_rates(d, by = c(angler_type, species_sought)) # nolint: object_usage_linter
  expect_true(all(c("angler_type", "species_sought", "N", "mean_rate") %in% names(result)))
})

test_that("summarize_cws_rates() ungrouped returns single-row data.frame", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_cws_rates(d)
  expect_equal(nrow(result), 1L)
  expect_true(all(c("N", "mean_rate", "se", "ci_lower", "ci_upper") %in% names(result)))
})

# summarize_hws_rates() tests ----

test_that("summarize_hws_rates() errors when design is not creel_design", {
  expect_error(summarize_hws_rates(list()), "must be a")
})

test_that("summarize_hws_rates() errors when no catch data attached", {
  expect_error(summarize_hws_rates(make_design_no_catch()), "No catch data found")
})

test_that("summarize_hws_rates() returns correct columns when by = species_sought", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_hws_rates(d, by = species_sought) # nolint: object_usage_linter
  expected_cols <- c("species_sought", "N", "mean_rate", "se", "ci_lower", "ci_upper")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("summarize_hws_rates() returns class c('creel_summary_hws_rates', 'data.frame')", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_hws_rates(d, by = species_sought) # nolint: object_usage_linter
  expect_s3_class(result, "creel_summary_hws_rates")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_hws_rates() mean_rate <= summarize_cws_rates() mean_rate (harvest subset of catch)", {
  d <- make_design_with_catch_for_cws()
  cws <- summarize_cws_rates(d, by = species_sought) # nolint: object_usage_linter
  hws <- summarize_hws_rates(d, by = species_sought) # nolint: object_usage_linter
  merged <- merge(
    cws[, c("species_sought", "mean_rate")],
    hws[, c("species_sought", "mean_rate")],
    by = "species_sought", suffixes = c("_cws", "_hws")
  )
  expect_true(all(merged[["mean_rate_hws"]] <= merged[["mean_rate_cws"]] + 1e-10))
})

test_that("summarize_hws_rates() ungrouped returns single-row data.frame", {
  d <- make_design_with_catch_for_cws()
  result <- summarize_hws_rates(d)
  expect_equal(nrow(result), 1L)
})
