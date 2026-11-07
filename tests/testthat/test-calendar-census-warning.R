# GH #584: a calendar holding only the sampled days.
#
# The calendar is the population of days; N_h is counted from it. Built from
# the sampled dates, every stratum is a census and the season total -- the
# default target since #487 -- is the effort of those days alone, with nothing
# said. add_counts() now warns when every day of every stratum has a count.

census_class <- "creel_warning_calendar_is_census"

test_that("a calendar of the sampled dates alone warns (#584)", {
  cal <- example_calendar[example_calendar$date %in% example_counts$date, ]
  design <- creel_design(cal, date = date, strata = day_type)
  expect_warning(add_counts(design, example_counts), class = census_class)
})

test_that("a calendar with unsampled days does not warn (#584)", {
  # example_calendar is June; the counts cover June 1-14.
  design <- creel_design(example_calendar, date = date, strata = day_type)
  expect_no_warning(add_counts(design, example_counts), class = census_class)
})

test_that("one census stratum among sampled ones does not warn (#584)", {
  # A fully sampled holiday is usually deliberate; only the all-strata case is
  # the likely mistake.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:6)
  cal$day_type <- c(rep("weekday", 5), "holiday", "holiday")
  counts <- data.frame(
    date = cal$date[c(1, 3, 6, 7)], day_type = cal$day_type[c(1, 3, 6, 7)],
    n = c(4, 6, 20, 24)
  )
  design <- creel_design(cal, date = date, strata = day_type)
  expect_no_warning(add_counts(design, counts), class = census_class)
})

test_that("the warning says what the totals then are and how to fix it (#584)", {
  cal <- example_calendar[example_calendar$date %in% example_counts$date, ]
  w <- expect_warning(
    add_counts(creel_design(cal, date = date, strata = day_type), example_counts),
    class = census_class
  )
  msg <- conditionMessage(w)
  expect_match(msg, "all 14 days", fixed = TRUE)
  expect_match(msg, "census totals of these days only", fixed = TRUE)
  expect_match(msg, "creel_calendar()", fixed = TRUE)
})

test_that("the census and the season calendar give the totals the warning describes (#584)", {
  # Why it matters: on the issue's pattern the census calendar returns the
  # sampled days' effort as the season total. With June's 30 days the same
  # counts expand by N_h / n_h.
  cal <- example_calendar[example_calendar$date %in% example_counts$date, ]
  census <- suppressWarnings(estimate_effort(add_counts(
    creel_design(cal, date = date, strata = day_type), example_counts
  )))
  season <- suppressWarnings(estimate_effort(add_counts(
    creel_design(example_calendar, date = date, strata = day_type), example_counts
  )))
  sampled_sum <- sum(example_counts$effort_hours)
  expect_equal(census$estimates$estimate, sampled_sum)
  wk <- example_counts$day_type == "weekend"
  expect_equal(
    season$estimates$estimate,
    sum(example_counts$effort_hours[wk]) * 10 / 4 + sum(example_counts$effort_hours[!wk]) * 20 / 10
  )
})

test_that("camera designs are not checked: no estimator expands them (#584)", {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "weekday")
  counts <- data.frame(date = cal$date, day_type = "weekday", ingress_count = c(5, 8, 6, 9))
  design <- creel_design(cal, date = date, strata = day_type, survey_type = "camera", camera_mode = "counter")
  expect_no_warning(suppressMessages(add_counts(design, counts)), class = census_class)
})
