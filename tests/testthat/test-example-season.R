# Tests for the example_season_* datasets, which carry vignette("tidycreel")
# (GH #480). The tutorial teaches expansion from sampled days to a season, so
# the data must actually have unsampled days, real weekend labels, and counts
# whose season total can be checked by hand.

test_that("the season calendar has unsampled days to expand to", {
  data("example_season_calendar", package = "tidycreel")
  cal <- example_season_calendar
  expect_equal(nrow(cal), 120L)
  expect_equal(sum(cal$sampled), 36L)
  # Each stratum must be partly sampled, or period_total equals sampled_days
  # there and the tutorial's central contrast disappears.
  by_stratum <- tapply(cal$sampled, cal$day_type, mean)
  expect_true(all(by_stratum > 0 & by_stratum < 1))
})

test_that("weekend labels match the real day of the week", {
  data("example_season_calendar", package = "tidycreel")
  cal <- example_season_calendar
  is_weekend <- format(cal$date, "%u") %in% c("6", "7")
  expect_identical(cal$day_type == "weekend", is_weekend)
})

test_that("counts and interviews fall on exactly the sampled days", {
  data("example_season_calendar", package = "tidycreel")
  data("example_season_counts", package = "tidycreel")
  data("example_season_interviews", package = "tidycreel")
  sampled <- example_season_calendar$date[example_season_calendar$sampled]
  expect_setequal(example_season_counts$date, sampled)
  expect_true(all(example_season_interviews$date %in% sampled))
  expect_true(all(example_season_counts$total_anglers > 0))
  expect_true(all(
    example_season_interviews$catch_kept <= example_season_interviews$catch_total
  ))
  expect_false(anyDuplicated(example_season_interviews$interview_id) > 0)
})

test_that("season effort is each stratum's mean day times its days", {
  data("example_season_calendar", package = "tidycreel")
  data("example_season_counts", package = "tidycreel")
  cal <- example_season_calendar
  cnt <- example_season_counts

  design <- creel_design(cal, date = date, strata = day_type)
  design <- add_counts(design, cnt,
    count_col = total_anglers, period_length_col = daylight_hours
  )

  day_effort <- cnt$total_anglers * cnt$daylight_hours
  by_hand <- sum(
    tapply(day_effort, cnt$day_type, mean)[c("weekday", "weekend")] *
      table(cal$day_type)[c("weekday", "weekend")]
  )

  season <- expect_no_warning(estimate_effort(design, target = "period_total"))
  sampled <- estimate_effort(design)
  expect_equal(season$estimates$estimate, by_hand)
  expect_equal(sampled$estimates$estimate, sum(day_effort))
  expect_identical(season$unit, "angler-hours")
})

test_that("the tutorial's totals are in fish", {
  data("example_season_calendar", package = "tidycreel")
  data("example_season_counts", package = "tidycreel")
  data("example_season_interviews", package = "tidycreel")
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_season_counts,
    count_col = total_anglers, period_length_col = daylight_hours
  )
  # The zero-catch advisory is the one warning the tutorial explains.
  expect_warning(
    design <- suppressMessages(add_interviews(design, example_season_interviews,
      catch = catch_total, harvest = catch_kept, effort = hours_fished,
      trip_status = trip_status, trip_duration = trip_duration,
      n_anglers = n_anglers
    )),
    "zero catch"
  )
  total <- expect_no_warning(suppressMessages(
    estimate_total_catch(design, by = day_type, target = "period_total")
  ))
  expect_identical(total$unit, "fish")
  expect_equal(nrow(total$estimates), 2L)
})
