# Helper: build minimal creel_estimates objects for testing
make_est <- function(estimate_val, se_val = 1.0, by_vars = NULL) {
  tbl <- tibble::tibble(estimate = estimate_val, se = se_val)
  tidycreel:::new_creel_estimates(
    estimates       = tbl,
    method          = "total",
    variance_method = "taylor",
    design          = NULL,
    conf_level      = 0.95,
    by_vars         = by_vars
  )
}

test_that("season_summary() returns creel_season_summary (REPT-01a)", {
  e <- make_est(1000.0)
  c_est <- make_est(2.5)
  result <- season_summary(list(effort = e, cpue = c_est))
  expect_s3_class(result, "creel_season_summary")
})

test_that("$table slot matches individual estimate values numerically (REPT-01b)", {
  e <- make_est(1000.0)
  c_est <- make_est(2.5)
  result <- season_summary(list(effort = e, cpue = c_est))
  expect_true(tibble::is_tibble(result$table))
  expect_equal(result$table$effort_estimate, e$estimates$estimate, tolerance = 1e-6)
  expect_equal(result$table$cpue_estimate, c_est$estimates$estimate, tolerance = 1e-6)
})

test_that("season_summary() errors on non-creel_estimates element (REPT-01c)", {
  expect_error(
    season_summary(list(bad = "not_an_estimate")),
    regexp = "creel_estimates"
  )
})

test_that("$table exports to CSV with numeric types preserved (REPT-01d)", {
  e <- make_est(1000.0)
  c_est <- make_est(2.5)
  result <- season_summary(list(effort = e, cpue = c_est))
  tmp <- withr::local_tempdir()
  csv_path <- file.path(tmp, "s.csv")
  write_schedule(result$table, csv_path)
  back <- read.csv(csv_path)
  numeric_classes <- vapply(Filter(is.numeric, back), class, character(1))
  expect_true(all(numeric_classes %in% c("numeric", "integer")))
})

test_that("$table exports to xlsx without error (REPT-01e)", {
  skip_if_not_installed("writexl")
  e <- make_est(1000.0)
  c_est <- make_est(2.5)
  result <- season_summary(list(effort = e, cpue = c_est))
  tmp <- withr::local_tempdir()
  xlsx_path <- file.path(tmp, "s.xlsx")
  write_schedule(result$table, xlsx_path, format = "xlsx")
  expect_true(file.exists(xlsx_path))
})

test_that("format.creel_season_summary returns character vector (REPT-01f)", {
  e <- make_est(1000.0)
  c_est <- make_est(2.5)
  result <- season_summary(list(effort = e, cpue = c_est))
  out <- format(result)
  expect_type(out, "character")
  expect_gte(length(out), 1L)
})

test_that("print.creel_season_summary returns result invisibly (REPT-01g)", {
  e <- make_est(1000.0)
  c_est <- make_est(2.5)
  result <- season_summary(list(effort = e, cpue = c_est))
  ret <- withVisible(print(result))
  expect_false(ret$visible)
  expect_identical(ret$value, result)
})
