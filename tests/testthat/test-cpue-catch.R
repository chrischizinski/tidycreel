test_that("est_cpue returns tidy output with expected columns", {
  interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", package = "tidycreel"), show_col_types = FALSE)
  design <- survey::svydesign(ids = ~1, weights = ~1, data = interviews)

  res <- suppressWarnings(est_cpue(design, by = c("target_species"), response = "catch_total", mode = "ratio_of_means"))
  expect_s3_class(res, "data.frame")
  expect_true(all(c("estimate", "se", "ci_low", "ci_high", "n", "method") %in% names(res)))
  expect_true(nrow(res) >= 1)
})

test_that("est_catch returns totals with expected columns", {
  interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", package = "tidycreel"), show_col_types = FALSE)
  design <- survey::svydesign(ids = ~1, weights = ~1, data = interviews)

  res <- suppressWarnings(est_catch(design, by = c("target_species"), response = "catch_kept"))
  expect_s3_class(res, "data.frame")
  expect_true(all(c("estimate", "se", "ci_low", "ci_high", "n", "method") %in% names(res)))
  expect_true(nrow(res) >= 1)
})
