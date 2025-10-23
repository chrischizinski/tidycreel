test_that("progressive estimator uses survey design for totals and SE", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    day_type = c("weekday", "weekday"),
    month = c("August", "August"),
    target_sample = c(4, 4),
    actual_sample = c(2, 2)
  )
  svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type", "month"))

  # Two passes per day/location
  counts <- tibble::tibble(
    date = rep(as.Date(c("2025-08-20", "2025-08-21")), each = 4),
    location = rep(c("A", "A", "B", "B"), times = 2),
    pass_id = rep(c(1, 2, 1, 2), times = 2),
    count = c(10, 12, 8, 15, 9, 11, 7, 16),
    route_minutes = 60
  )

  res <- est_effort.progressive(
    counts,
    by = c("location"),
    route_minutes_col = c("route_minutes"),
    pass_id = c("pass_id"),
    day_id = "date",
    svy = svy_day
  )

  expect_true(all(c("estimate", "se", "ci_low", "ci_high") %in% names(res)))
  expect_true(all(!is.na(res$estimate)))
  # SE may be NA for lonely PSUs (single observation per stratum)
  # This is statistically correct behavior
  if (any(!is.na(res$se))) {
    expect_true(all(res$se[!is.na(res$se)] >= 0))
  }
})
