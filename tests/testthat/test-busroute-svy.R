test_that("bus-route estimator uses day PSU design for totals and SE", {
  # Minimal calendar for two days
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    day_type = c("weekday", "weekday"),
    month = c("August", "August"),
    target_sample = c(4, 4),
    actual_sample = c(2, 2)
  )
  # Build dummy busroute design with calendar and empty interviews (not used here)
  dummy_interviews <- tibble::tibble(location = character(), date = as.Date(character()))
  dummy_counts <- tibble::tibble()
  route_schedule <- tibble::tibble(route_stop = character(), time = character(), expected_coverage = numeric())
  br_design <- design_busroute(dummy_interviews, dummy_counts, calendar, route_schedule)

  # Observations with inclusion probabilities and route minutes
  counts <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21", "2025-08-20", "2025-08-21")),
    location = c("A", "A", "B", "B"),
    count = c(10, 8, 12, 15),
    inclusion_prob = c(0.5, 0.5, 0.5, 0.5),
    route_minutes = 60
  )

  res_ht <- est_effort.busroute_design(br_design, counts = counts, by = c("location"))
  expect_true(all(c("estimate", "se", "ci_low", "ci_high") %in% names(res_ht)))
  expect_true(all(!is.na(res_ht$estimate)))
  expect_true(all(res_ht$se >= 0))
})

test_that("bus-route errors when route_minutes missing without contrib_hours_col", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    day_type = c("weekday", "weekday"),
    month = c("August", "August"),
    target_sample = c(2, 2),
    actual_sample = c(1, 1)
  )
  dummy_interviews <- tibble::tibble(location = character(), date = as.Date(character()))
  dummy_counts <- tibble::tibble()
  route_schedule <- tibble::tibble(route_stop = character(), time = character(), expected_coverage = numeric())
  br_design <- design_busroute(dummy_interviews, dummy_counts, calendar, route_schedule)

  counts <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    location = c("A", "B"),
    count = c(10, 12),
    inclusion_prob = c(0.5, 0.5)
    # route_minutes missing
  )
  expect_error(est_effort.busroute_design(br_design, counts = counts, by = c("location")))
})

test_that("bus-route estimator supports replicate-weight designs when provided", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21", "2025-08-22")),
    day_type = c("weekday", "weekday", "weekday"),
    month = c("August", "August", "August"),
    target_sample = c(3, 3, 3),
    actual_sample = c(1, 1, 1)
  )
  dummy_interviews <- tibble::tibble(location = character(), date = as.Date(character()))
  dummy_counts <- tibble::tibble()
  route_schedule <- tibble::tibble(route_stop = character(), time = character(), expected_coverage = numeric())
  br_design <- design_busroute(dummy_interviews, dummy_counts, calendar, route_schedule)

  counts <- tibble::tibble(
    date = rep(calendar$date, each = 2),
    location = rep(c("A", "B"), times = nrow(calendar)),
    count = c(10, 12, 8, 15, 9, 11),
    inclusion_prob = 0.5,
    route_minutes = 60
  )

  svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type", "month"))
  svy_rep <- survey::as.svrepdesign(svy_day, type = "bootstrap", replicates = 25)

  res <- est_effort.busroute_design(br_design, counts = counts, by = c("location"), svy = svy_rep)
  expect_true(all(c("estimate", "se") %in% names(res)))
  expect_true(all(!is.na(res$estimate)))
  expect_true(all(res$se >= 0))
})

test_that("bus-route estimator clamps invalid inclusion probabilities with warning", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    day_type = c("weekday", "weekday"),
    month = c("August", "August"),
    target_sample = c(4, 4),
    actual_sample = c(2, 2)
  )
  dummy_interviews <- tibble::tibble(location = character(), date = as.Date(character()))
  dummy_counts <- tibble::tibble()
  route_schedule <- tibble::tibble(route_stop = character(), time = character(), expected_coverage = numeric())
  br_design <- design_busroute(dummy_interviews, dummy_counts, calendar, route_schedule)

  counts <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    location = c("A", "B"),
    count = c(10, 12),
    inclusion_prob = c(0, 1.2), # invalid values
    route_minutes = 60
  )

  expect_warning({
    res <- est_effort.busroute_design(br_design, counts = counts, by = c("location"))
  })
})

test_that("bus-route estimator accepts contrib_hours_col path", {
  calendar <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    day_type = c("weekday", "weekday"),
    month = c("August", "August"),
    target_sample = c(4, 4),
    actual_sample = c(2, 2)
  )
  dummy_interviews <- tibble::tibble(location = character(), date = as.Date(character()))
  dummy_counts <- tibble::tibble()
  route_schedule <- tibble::tibble(route_stop = character(), time = character(), expected_coverage = numeric())
  br_design <- design_busroute(dummy_interviews, dummy_counts, calendar, route_schedule)

  counts <- tibble::tibble(
    date = as.Date(c("2025-08-20", "2025-08-21")),
    location = c("A", "B"),
    inclusion_prob = c(0.5, 0.5),
    contrib_hours = c(3, 4)
  )
  res <- est_effort.busroute_design(br_design, counts = counts, by = c("location"), contrib_hours_col = "contrib_hours")
  expect_true(all(!is.na(res$estimate)))
})
