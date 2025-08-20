# Roving estimator tests
test_that("est_effort.roving returns correct effort for single group", {
  df <- tibble::tibble(
    date = as.Date("2025-08-20"),
    time = "12:00",
    count = 10,
    interval_minutes = 60
  )
  result <- est_effort.roving(df)
  expect_true(is.na(result$se[1]))
  expect_true(is.na(result$ci_high[1]))
  expect_true(is.na(result$ci_low[1]))
  expect_equal(result$estimate[1], 10 * 60 / 60)
})

test_that("est_effort.roving returns correct effort and SE/CI for multiple groups", {
  df <- tibble::tibble(
    date = rep(as.Date("2025-08-20"), 4),
    time = c("12:00", "13:00", "14:00", "15:00"),
    count = c(10, 12, 8, 15),
    interval_minutes = c(60, 60, 60, 60),
    location = c("A", "A", "B", "B")
  )
  result <- est_effort.roving(df)
  expect_true(all(!is.na(result$se)))
  expect_true(all(result$ci_high > result$ci_low))
  expect_equal(result$estimate[1], mean(c(10,12)) * 120 / 60)
  expect_equal(result$estimate[2], mean(c(8,15)) * 120 / 60)
})

test_that("est_effort.roving warns for missing columns", {
  df <- tibble::tibble(date = as.Date("2025-08-20"), count = 10)
  expect_error(est_effort.roving(df), "Missing columns")
})
# Aerial estimator tests
test_that("est_effort.aerial returns correct effort for single group", {
  df <- tibble::tibble(
    date = as.Date("2025-08-20"),
    time = "12:00",
    count = 10,
    interval_minutes = 60
  )
  result <- est_effort.aerial(df)
  expect_true(is.na(result$se[1]))
  expect_true(is.na(result$ci_high[1]))
  expect_true(is.na(result$ci_low[1]))
  expect_equal(result$estimate[1], 10 * 60 / 60)
})

test_that("est_effort.aerial returns correct effort and SE/CI for multiple groups", {
  df <- tibble::tibble(
    date = rep(as.Date("2025-08-20"), 4),
    time = c("12:00", "13:00", "14:00", "15:00"),
    count = c(10, 12, 8, 15),
    interval_minutes = c(60, 60, 60, 60),
    location = c("A", "A", "B", "B")
  )
  result <- est_effort.aerial(df)
  expect_true(all(!is.na(result$se)))
  expect_true(all(result$ci_high > result$ci_low))
  expect_equal(result$estimate[1], mean(c(10,12)) * 120 / 60)
  expect_equal(result$estimate[2], mean(c(8,15)) * 120 / 60)
})

test_that("est_effort.aerial warns for missing columns", {
  df <- tibble::tibble(date = as.Date("2025-08-20"), count = 10)
  expect_error(est_effort.aerial(df), "Missing columns")
})
# Progressive estimator tests
test_that("est_effort.progressive returns correct effort for single group", {
  df <- tibble::tibble(
    date = as.Date("2025-08-20"),
    time = "12:00",
    count = 10,
    interval_minutes = 60
  )
  result <- est_effort.progressive(df)
  expect_true(is.na(result$se[1]))
  expect_true(is.na(result$ci_high[1]))
  expect_true(is.na(result$ci_low[1]))
  expect_equal(result$estimate[1], 10 * 60 / (1 * 60))
})

test_that("est_effort.progressive returns correct effort and SE/CI for multiple groups", {
  df <- tibble::tibble(
    date = rep(as.Date("2025-08-20"), 4),
    time = c("12:00", "13:00", "14:00", "15:00"),
    count = c(10, 12, 8, 15),
    interval_minutes = c(60, 60, 60, 60),
    location = c("A", "A", "B", "B")
  )
  result <- est_effort.progressive(df)
  expect_true(all(!is.na(result$se)))
  expect_true(all(result$ci_high > result$ci_low))
  expect_equal(result$estimate[1], (10 + 12) * 120 / (2 * 60))
  expect_equal(result$estimate[2], (8 + 15) * 120 / (2 * 60))
})

test_that("est_effort.progressive warns for missing columns", {
  df <- tibble::tibble(date = as.Date("2025-08-20"), count = 10)
  expect_error(est_effort.progressive(df), "Missing columns")
})
test_that("est_effort.instantaneous calculates correct effort", {
  df <- tibble::tibble(
    date = as.Date("2025-08-20"),
    time = "12:00",
    count = 10,
    interval_minutes = 60
  )
  result <- est_effort.instantaneous(df)
  expect_equal(result$estimate, 10)
  expect_equal(result$n, 1)
  expect_equal(result$method, "instantaneous")
})

test_that("est_effort.instantaneous adjusts for visibility", {
  df <- tibble::tibble(
    date = as.Date("2025-08-20"),
    time = "12:00",
    count = 10,
    interval_minutes = 60,
    visibility_prop = 0.5
  )
  result <- est_effort.instantaneous(df, visibility_col = "visibility_prop")
  expect_true(result$estimate[1] >= 10)
})

test_that("est_effort.instantaneous returns correct CI and SE", {
  # Single group: SE and CI should be NA
  df_single <- tibble::tibble(
    date = as.Date("2025-08-20"),
    time = "12:00",
    count = 10,
    interval_minutes = 60
  )
  result_single <- est_effort.instantaneous(df_single)
  expect_true(is.na(result_single$se[1]))
  expect_true(is.na(result_single$ci_high[1]))
  expect_true(is.na(result_single$ci_low[1]))

  # Multiple groups: SE and CI should be valid
  df_multi <- tibble::tibble(
    date = rep(as.Date("2025-08-20"), 4),
    time = c("12:00", "13:00", "14:00", "15:00"),
    count = c(10, 12, 8, 15),
    interval_minutes = c(60, 60, 60, 60),
    location = c("A", "A", "B", "B")
  )
  result_multi <- est_effort.instantaneous(df_multi)
  expect_true(all(!is.na(result_multi$se)))
  expect_true(all(result_multi$ci_high > result_multi$ci_low))
})

test_that("est_effort.instantaneous warns for missing columns", {
  df <- tibble::tibble(date = as.Date("2025-08-20"), count = 10)
  expect_error(est_effort.instantaneous(df), "Missing columns")
})
