# GH #183: N_h / n_h has to count the same kind of thing on both sides.
#
# The numerator counted calendar rows and the denominator counted rows of the
# aggregated counts table, so a day carrying k count rows -- two shift periods,
# three sections -- divided every weight by k. The expanded total came back low
# by exactly k, with no error and no warning, which is how the companion book
# published a Cedar Lake season at half its surveyed coverage.

sections_expansion_design <- function() {
  suppressMessages(suppressWarnings(
    creel_design(example_sections_calendar, date = "date", strata = "day_type") |>
      add_counts(example_sections_counts, count_col = effort_hours)
  ))
}

test_that("a day carrying several count rows expands by days, not by rows", {
  design <- sections_expansion_design()
  result <- suppressMessages(suppressWarnings(
    estimate_effort(design, target = "stratum_total")
  ))

  # Hand Horvitz-Thompson: sum each day's sections into a day total, expand by
  # N_h / n_h over DAYS. Every calendar day was sampled here, so the weights are
  # 1 and the total is the sum of the counts -- 846, not the 282 that dividing
  # by 36 rows produced.
  day_totals <- stats::aggregate(
    effort_hours ~ date + day_type,
    data = example_sections_counts,
    FUN = sum
  )
  expect_equal(result$estimates$estimate, sum(day_totals$effort_hours))
  expect_equal(result$estimates$estimate, 846)
})

test_that("one row per sampled day is expanded exactly as before", {
  # The regression guard: this is the shape every existing expansion test uses,
  # and its numbers must not move.
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4L),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-03")),
    day_type = "weekday",
    effort_hours = c(10, 14),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings(
    creel_design(cal, date = "date", strata = "day_type") |> add_counts(counts)
  ))
  result <- suppressMessages(suppressWarnings(
    estimate_effort(design, target = "stratum_total")
  ))
  # 4 frame days / 2 sampled days = 2, applied to 24 sampled angler-hours.
  expect_equal(result$estimates$estimate, 48)
})

test_that("a frame listed at a finer resolution than the day does not inflate N", {
  # The mirror of the same defect, and what counting rows on the numerator alone
  # would have left in place: a calendar with one row per day x period describes
  # the same four days, so it must not expand as though it described eight.
  cal_day <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4L),
    stringsAsFactors = FALSE
  )
  cal_period <- do.call(rbind, list(cal_day, cal_day))
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-03")),
    day_type = "weekday",
    effort_hours = c(10, 14),
    stringsAsFactors = FALSE
  )
  build <- function(cal) {
    suppressMessages(suppressWarnings(
      creel_design(cal, date = "date", strata = "day_type") |> add_counts(counts)
    ))
  }
  day_result <- suppressMessages(suppressWarnings(
    estimate_effort(build(cal_day), target = "stratum_total")
  ))
  period_result <- suppressMessages(suppressWarnings(
    estimate_effort(build(cal_period), target = "stratum_total")
  ))
  expect_equal(period_result$estimates$estimate, day_result$estimates$estimate)
})

test_that("expanding a day that carries several rows says so", {
  design <- sections_expansion_design()
  msg <- paste(
    utils::capture.output(
      suppressWarnings(estimate_effort(design, target = "stratum_total")),
      type = "message"
    ),
    collapse = " "
  )
  # Both quantities, and the plural agreeing with each: cli binds {?s} to the
  # nearest preceding value, which made the first draft read "12 sampled date
  # value carrying 36 count rows".
  expect_match(msg, "12 sampled units")
  expect_match(msg, "36 count rows")
  expect_no_match(msg, "sampled unit carrying")
})

test_that("one row per day says nothing about rows", {
  # A message on every expansion would be noise, and noise is what lets the
  # cases that matter go unread.
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4L),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-03")),
    day_type = "weekday",
    effort_hours = c(10, 14),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings(
    creel_design(cal, date = "date", strata = "day_type") |> add_counts(counts)
  ))
  msg <- paste(
    utils::capture.output(
      suppressWarnings(estimate_effort(design, target = "stratum_total")),
      type = "message"
    ),
    collapse = " "
  )
  expect_no_match(msg, "sampled unit")
})
