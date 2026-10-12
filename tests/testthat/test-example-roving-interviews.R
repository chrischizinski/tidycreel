# example_roving_interviews exists because simulate_creel_data() gives an
# incomplete trip its whole trip's catch over the hours fished so far (GH #494),
# which inflates a roving mean-of-ratios rate. These tests pin what makes the
# roving example honest: every trip is incomplete, its catch is the catch so
# far, and the roving estimator recovers the rate the data were simulated with.

roving_design <- function() {
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_season_counts,
    count_col = total_anglers, period_length_col = daylight_hours
  )
  suppressMessages(add_interviews(design, example_roving_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = hours_fished,
    n_anglers = n_anglers, interview_type = "roving"
  ))
}

test_that("roving interviews are incomplete trips on the season's sampled days", {
  x <- example_roving_interviews
  sampled <- example_season_calendar$date[example_season_calendar$sampled]
  expect_true(all(x$trip_status == "incomplete"))
  expect_true(all(x$date %in% sampled))
  # The clerk did not interview parties that had fished under 15 minutes.
  expect_true(all(x$hours_fished >= 0.25))
  expect_true(all(x$catch_kept <= x$catch_total))
  expect_type(x$n_anglers, "integer")
})

test_that("the roving rate is mean-of-ratios and covers the true 0.22", {
  rate <- suppressWarnings(suppressMessages(estimate_catch_rate(roving_design())))
  expect_identical(rate$estimator, "mor")
  expect_identical(rate$unit, "fish/angler-hour")
  # Whole-trip catch over partial hours (GH #494) pushes this rate well above
  # 0.22: on example_season_interviews the same estimator gives 0.63.
  est <- rate$estimates
  expect_lte(est$ci_lower, 0.22)
  expect_gte(est$ci_upper, 0.22)
})

test_that("catch so far scales with hours so far", {
  # Catch accrues over time, so a party's catch per angler-hour does not grow
  # as its hours so far shrink. Whole-trip catch would make the short half
  # catch at a much higher rate than the long half.
  x <- example_roving_interviews
  short <- x$hours_fished < stats::median(x$hours_fished)
  rate <- function(i) sum(x$catch_total[i]) / sum(x$hours_fished[i] * x$n_anglers[i])
  expect_lt(rate(short) / rate(!short), 1.5)
})
