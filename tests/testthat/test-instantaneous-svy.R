test_that("instantaneous estimator uses survey design for totals and SE", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    day_type = c("weekday", "weekday"),
    month = c("August", "August"),
    target_sample = c(4, 4),
    actual_sample = c(2, 2)
  )
  svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type", "month"))

  counts <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-20", "2025-08-21", "2025-08-21")),
    location = c("A", "B", "A", "B"),
    count = c(10, 12, 8, 15),
    interval_minutes = c(60, 60, 60, 60),
    total_day_minutes = c(720, 720, 720, 720)
  )

  res <- est_effort.instantaneous(
    counts,
    by = c("location"),
    minutes_col = c("interval_minutes"),
    total_minutes_col = c("total_day_minutes"),
    day_id = "date",
    svy = svy_day
  )

  expect_true(all(c("estimate", "se", "ci_low", "ci_high") %in% names(res)))
  expect_true(all(!is.na(res$estimate)))
  expect_true(all(!is.na(res$se)))
  expect_true(all(res$ci_high >= res$ci_low))
})
