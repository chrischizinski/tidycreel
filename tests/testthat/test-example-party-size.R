# example_ice_interviews and example_aerial_interviews carry a party size
# (GH #480). Their rows are parties, so without it effort and catch rates are in
# party-hours, and the survey-type articles called those "angler-hours". These
# tests pin that passing the column is what makes the units angler-hours.

test_that("the example interview party sizes are whole anglers, 1 to 4", {
  for (d in c("example_ice_interviews", "example_aerial_interviews")) {
    x <- get(d, envir = asNamespace("tidycreel"))
    expect_type(x$n_anglers, "integer")
    expect_true(all(x$n_anglers >= 1L & x$n_anglers <= 4L), info = d)
  }
})

test_that("ice effort and catch rate are per angler-hour with party size", {
  design <- creel_design(example_ice_sampling_frame,
    date = date, strata = day_type, survey_type = "ice",
    effort_type = "time_on_ice", p_period = 0.5
  )
  design <- suppressMessages(add_interviews(design, example_ice_interviews,
    catch = walleye_catch, effort = hours_on_ice, harvest = walleye_kept,
    trip_status = trip_status, n_counted = n_counted,
    n_interviewed = n_interviewed, n_anglers = n_anglers
  ))
  expect_identical(estimate_effort(design)$unit, "angler-hours")
  expect_identical(
    suppressMessages(estimate_catch_rate(design))$unit, "fish/angler-hour"
  )
})

test_that("the aerial total is in fish once party size is passed", {
  cal <- unique(example_aerial_counts[, c("date", "day_type")])
  design <- creel_design(cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = "none", angler_ratio = 1, angler_ratio_se = 0,
    h_open = 14
  )
  design <- add_counts(design, example_aerial_counts)
  design <- suppressMessages(add_interviews(design, example_aerial_interviews,
    catch = walleye_catch, effort = hours_fished, trip_status = trip_status,
    n_anglers = n_anglers
  ))
  total <- expect_no_warning(suppressMessages(estimate_total_catch(design)))
  expect_identical(total$unit, "fish")
  # A party-hour rate times angler-hour effort overstates the total by about
  # the mean party size; the angler-hour total must be the smaller one.
  expect_lt(total$estimates$estimate, 3507.6)

  # Each stratum's total is its effort times its angler-hour catch rate. The
  # 18 weekend interviews draw the n < 30 advisory, which is expected here.
  expect_warning(
    by_total <- suppressMessages(estimate_total_catch(design, by = day_type)),
    "Small sample size"
  )
  by_effort <- estimate_effort(design, by = day_type)
  # The total has just printed the advisory for this design; the rate
  # records it without printing it again (GH #496).
  by_rate <- expect_no_warning(suppressMessages(estimate_catch_rate(design, by = day_type)))
  expect_true("creel_warning_small_sample" %in% get_warnings(by_rate)$class)
  expect_equal(
    by_total$estimates$estimate,
    by_effort$estimates$estimate * by_rate$estimates$estimate
  )
})
