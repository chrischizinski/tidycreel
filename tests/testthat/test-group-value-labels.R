# Refusal messages name each group by its values (GH #679) ----
#
# group_value_labels() turned a one-row data frame into labels with unlist(),
# which drops each column's class first: a Date came out as its day number and
# a factor beside a numeric column as its level code. "Group gear=1, zone=1"
# named a group the user cannot find in their data.

test_that("GVL-01 (#679): each column keeps its own class", {
  expect_identical(
    group_value_labels(data.frame(g = factor("b", levels = c("a", "b")), z = 1)), # nolint: object_usage_linter
    c("b", "1")
  )
  expect_identical(group_value_labels(data.frame(dt = as.Date("2024-06-03"))), "2024-06-03") # nolint: object_usage_linter
  # The unknown group promote_na_groups() makes with addNA(), beside an integer.
  expect_identical(
    group_value_labels(data.frame(g = addNA(factor(NA, levels = "a")), z = 2L)), # nolint: object_usage_linter
    c("<unknown>", "2")
  )
  # A group labelled "NA" is not the unknown group.
  expect_identical(
    group_value_labels(data.frame(g = "NA", h = NA_character_)), # nolint: object_usage_linter
    c("NA", "<unknown>")
  )
})

gvl_design <- function(reps = 1L, gear_levels = c("net", "rod")) {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "weekday")
  iv <- data.frame(
    date = rep(cal$date, each = 3 * reps), catch_total = c(1, 2, 3), hours_fished = c(2, 3, 4),
    trip_status = "complete", trip_duration = c(2, 3, 4),
    # "net" is level 1: its code would read as zone 1's value.
    gear = factor(rep(rev(gear_levels), length.out = 12 * reps), levels = gear_levels),
    zone = rep(1:2, each = 6 * reps)
  )
  suppressWarnings(suppressMessages(add_interviews(
    creel_design(cal, date = date, strata = day_type), iv, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, n_anglers = 1, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
}

test_that("GVL-02 (#679): the sample-size refusal names factor and date groups by value", {
  d <- gvl_design()
  e <- expect_error(suppressMessages(estimate_catch_rate(d, by = c(gear, zone)))) # nolint: object_usage_linter
  expect_match(conditionMessage(e), "gear=net, zone=1", fixed = TRUE)
  expect_no_match(conditionMessage(e), "gear=1", fixed = TRUE)
  e <- expect_error(suppressMessages(estimate_catch_rate(d, by = date))) # nolint: object_usage_linter
  expect_match(conditionMessage(e), "date=2024-06-03", fixed = TRUE)
})

test_that("GVL-03 (#679): a value's braces are shown, not evaluated", {
  # cli reads braces in a message as code. A gear level "net {boat}" stopped
  # the small-sample warning, and the estimate with it, with an evaluation
  # error; and the refusal named no group.
  lv <- c("net {boat}", "rod")
  d <- gvl_design(reps = 4L, gear_levels = lv)
  expect_warning(
    r <- suppressMessages(estimate_catch_rate(d, by = c(gear, zone))), # nolint: object_usage_linter
    "gear=net \\{boat\\}, zone=1",
    class = "creel_warning_small_sample"
  )
  expect_identical(nrow(r$estimates), 4L)
  e <- expect_error(suppressMessages(estimate_catch_rate(gvl_design(gear_levels = lv), by = c(gear, zone)))) # nolint: object_usage_linter
  expect_match(conditionMessage(e), "gear=net {boat}, zone=1", fixed = TRUE)
})
