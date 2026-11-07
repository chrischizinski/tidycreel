# GH #391: check_completeness() reported every unsampled calendar day as
# missing. In a sampled design most calendar days are meant to have no counts,
# so "missing" means a SCHEDULED day with no counts, and needs the schedule.

q391 <- function(x) suppressWarnings(suppressMessages(x))

design_391 <- function(counts = example_counts) {
  d <- q391(add_counts(creel_design(example_calendar, date = date, strata = day_type), counts))
  q391(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status
  ))
}

test_that("unsampled calendar days are not reported missing without a schedule (#391)", {
  # example_calendar is June (30 days); the counts cover 14. Before #391 the
  # 16 unsampled days were all reported missing and `passed` was FALSE.
  r <- check_completeness(design_391(), n_min = 1L)
  expect_false(r$missing_days_checked)
  expect_equal(nrow(r$missing_days), 0L)
  expect_true(r$passed)
  expect_true(is.na(r$schedule_source))
  # Coverage is reported instead, per stratum.
  cov <- r$coverage[order(r$coverage$day_type), ]
  expect_equal(cov$n_calendar, c(20L, 10L))
  expect_equal(cov$n_counted, c(10L, 4L))
  expect_match(paste(format(r), collapse = "\n"), "not checked", fixed = TRUE)
})

test_that("a scheduled day with no counts is reported, by date and stratum (#391)", {
  # Scheduled: the 14 counted days plus June 20, which nobody counted.
  sched <- data.frame(date = c(unique(example_counts$date), as.Date("2024-06-20")))
  r <- check_completeness(design_391(), n_min = 1L, schedule = sched)
  expect_true(r$missing_days_checked)
  expect_equal(r$schedule_source, "schedule")
  expect_equal(nrow(r$missing_days), 1L)
  expect_equal(r$missing_days$date, as.Date("2024-06-20"))
  expect_equal(r$missing_days$day_type, "weekday")
  expect_false(r$passed)
})

test_that("a schedule with nothing missing passes (#391)", {
  r <- check_completeness(design_391(), n_min = 1L, schedule = data.frame(date = unique(example_counts$date)))
  expect_equal(nrow(r$missing_days), 0L)
  expect_true(r$passed)
})

test_that("a schedule's sampled column keeps only its TRUE rows (#391)", {
  sched <- data.frame(date = example_calendar$date, sampled = example_calendar$date %in% example_counts$date)
  r <- check_completeness(design_391(), n_min = 1L, schedule = sched)
  expect_equal(nrow(r$missing_days), 0L)
  sched$sampled[sched$date == as.Date("2024-06-25")] <- TRUE
  r2 <- check_completeness(design_391(), n_min = 1L, schedule = sched)
  expect_equal(r2$missing_days$date, as.Date("2024-06-25"))
})

test_that("a schedule outside the calendar, or without dates, is refused (#391)", {
  d <- design_391()
  expect_error(
    check_completeness(d, schedule = data.frame(date = as.Date("2024-08-01"))),
    class = "creel_error_schedule_invalid"
  )
  expect_error(
    check_completeness(d, schedule = data.frame(day = 1:3)),
    class = "creel_error_schedule_invalid"
  )
  expect_error(check_completeness(d, schedule = "2024-06-01"), class = "creel_error_schedule_invalid")
})

test_that("a generate_schedule() schedule is accepted (#391)", {
  sched <- generate_schedule(
    start_date = "2024-06-01", end_date = "2024-06-30", n_periods = 1,
    sampling_rate = c(weekday = 0.3, weekend = 0.5), seed = 1
  )
  r <- check_completeness(design_391(), n_min = 1L, schedule = sched)
  expect_true(r$missing_days_checked)
  # Every reported day is a scheduled day without counts.
  expect_true(all(r$missing_days$date %in% as.Date(sched$date)))
  expect_false(any(r$missing_days$date %in% example_counts$date))
})

test_that("the sampled register is the schedule, but needs counts to check (#391)", {
  cal <- data.frame(
    date = as.Date("2024-01-10") + 0:5,
    day_type = c("weekday", "weekday", "weekend", "weekend", "weekday", "weekday"),
    worked = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)
  )
  iv <- data.frame(
    date = cal$date[1:4], day_type = cal$day_type[1:4],
    hours_fished = c(2, 1.5, 3, 2.5), catch_total = c(1L, 2L, 0L, 3L),
    trip_status = "complete", n_counted = c(5L, 8L, 10L, 7L), n_interviewed = c(3L, 4L, 5L, 4L)
  )
  d <- q391(creel_design(cal,
    date = date, strata = day_type, survey_type = "ice",
    effort_type = "time_on_ice", p_period = 0.5, sampled = worked
  ))
  d <- q391(add_interviews(d, iv,
    catch = catch_total, effort = hours_fished, trip_status = trip_status,
    n_counted = n_counted, n_interviewed = n_interviewed
  ))
  r <- q391(check_completeness(d, n_min = 1L))
  # Ice effort comes from interviews and a worked day with nobody fishing
  # leaves none, so with no counts there is nothing to check against.
  expect_equal(r$schedule_source, "sampled register")
  expect_false(r$missing_days_checked)
  expect_equal(nrow(r$missing_days), 0L)
  expect_match(paste(format(r), collapse = "\n"), "no counts are attached", fixed = TRUE)
})
