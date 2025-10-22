test_that("tc_as_time parses dates with lubridate if available", {
  x <- c("2025-08-20 12:34:56", "2025-08-20")
  result <- tc_as_time(x)
  expect_s3_class(result, "POSIXct")
})

test_that("tc_confint computes normal CI", {
  ci <- tc_confint(10, 2, level = 0.95)
  expect_length(ci, 2)
  expect_true(ci[2] > ci[1])
})

test_that("tc_confint computes t-based CI if df provided", {
  ci <- tc_confint(10, 2, level = 0.95, df = 10)
  expect_length(ci, 2)
  expect_true(ci[2] > ci[1])
})
