# Format display tests ----

test_that("format.creel_estimates displays 'Ratio-of-Means CPUE' for ratio-of-means-cpue method", {
  obj <- tidycreel:::new_creel_estimates(
    estimates = tibble::tibble(estimate = 1.5, se = 0.3, ci_lower = 0.9, ci_upper = 2.1, n = 30L),
    method = "ratio-of-means-cpue"
  )
  output <- format(obj)

  expect_true(any(grepl("Ratio-of-Means CPUE", output)))
})

test_that("format.creel_estimates displays 'Total' for total method", {
  obj <- tidycreel:::new_creel_estimates(
    estimates = tibble::tibble(estimate = 100, se = 10, ci_lower = 80, ci_upper = 120, n = 50L),
    method = "total"
  )
  output <- format(obj)

  expect_true(any(grepl("Total", output)))
})

test_that("format.creel_estimates displays unknown method strings as-is", {
  obj <- tidycreel:::new_creel_estimates(
    estimates = tibble::tibble(estimate = 1.0, se = 0.1, ci_lower = 0.8, ci_upper = 1.2, n = 25L),
    method = "unknown-method"
  )
  output <- format(obj)

  expect_true(any(grepl("unknown-method", output)))
})

test_that("format displays 'Ratio-of-Means HPUE' for harvest method", {
  est <- tidycreel:::new_creel_estimates(
    estimates = tibble::tibble(estimate = 1, se = 0.1, ci_lower = 0.8, ci_upper = 1.2, n = 20),
    method = "ratio-of-means-hpue"
  )
  output <- format(est)
  expect_true(any(grepl("Ratio-of-Means HPUE", output)))
})
