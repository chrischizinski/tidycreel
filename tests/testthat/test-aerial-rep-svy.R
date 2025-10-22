test_that("aerial estimator supports replicate-weight designs when provided", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21", "2025-08-22")),
    day_type = c("weekday", "weekday", "weekday"),
    month = c("August", "August", "August"),
    target_sample = c(6, 6, 6),
    actual_sample = c(3, 3, 3)
  )
  svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type", "month"))
  # Convert to replicate design with a small number of replicates
  svy_rep <- survey::as.svrepdesign(svy_day, type = "bootstrap", replicates = 25)

  counts <- tibble::tibble(
    date = rep(calendar$date, each = 2),
    location = rep(c("A", "B"), times = nrow(calendar)),
    count = c(10, 12, 8, 15, 9, 11),
    interval_minutes = 60,
    total_day_minutes = 720
  )

  res <- est_effort.aerial(
    counts,
    by = c("location"),
    minutes_col = c("interval_minutes"),
    total_minutes_col = c("total_day_minutes"),
    day_id = "date",
    svy = svy_rep
  )
  expect_true(all(c("estimate", "se") %in% names(res)))
  expect_true(all(!is.na(res$estimate)))
  expect_true(all(res$se >= 0))
})
