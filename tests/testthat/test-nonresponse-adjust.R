# Helper -----------------------------------------------------------------------

make_nr_design <- function() {
  data("example_counts", package = "tidycreel", envir = environment())
  data("example_interviews", package = "tidycreel", envir = environment())
  cal <- unique(example_counts[, c("date", "day_type")])
  design <- suppressMessages(
    creel_design(cal, date = date, strata = day_type)
  )
  design <- suppressMessages(suppressWarnings(
    add_counts(design, example_counts)
  ))
  suppressMessages(suppressWarnings(
    add_interviews(design, example_interviews,
      catch         = catch_total,
      effort        = hours_fished,
      trip_status   = trip_status,
      trip_duration = trip_duration
    )
  ))
}

make_response_rates <- function(weekday_pct = 0.90, weekend_pct = 0.80) {
  data.frame(
    stratum = c("weekday", "weekend"),
    n_sampled = c(100L, 80L),
    n_responded = as.integer(c(
      round(100 * weekday_pct),
      round(80 * weekend_pct)
    )),
    stringsAsFactors = FALSE
  )
}

# Basic functionality tests ----------------------------------------------------

test_that("NR-01: adjust_nonresponse returns creel_design", {
  design <- make_nr_design()
  resp <- make_response_rates()
  result <- suppressWarnings(adjust_nonresponse(design, resp))
  expect_s3_class(result, "creel_design")
})

test_that("NR-02: adjusted design has nonresponse_diagnostics attribute", {
  design <- make_nr_design()
  resp <- make_response_rates()
  result <- suppressWarnings(adjust_nonresponse(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  expect_s3_class(diag, "data.frame")
})

test_that("NR-03: diagnostics has required columns", {
  design <- make_nr_design()
  resp <- make_response_rates()
  result <- suppressWarnings(adjust_nonresponse(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  expect_true("stratum" %in% names(diag))
  expect_true("n_sampled" %in% names(diag))
  expect_true("n_responded" %in% names(diag))
  expect_true("response_rate" %in% names(diag))
  expect_true("weight_adjustment" %in% names(diag))
})

test_that("NR-04: response_rate = n_responded / n_sampled", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.80, weekend_pct = 0.60)
  result <- suppressWarnings(adjust_nonresponse(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  wd <- diag[diag$stratum == "weekday", ]
  we <- diag[diag$stratum == "weekend", ]
  expect_equal(wd$response_rate, 0.80, tolerance = 0.01)
  expect_equal(we$response_rate, 0.60, tolerance = 0.01)
})

test_that("NR-05: weight_adjustment = 1 / response_rate", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.80, weekend_pct = 0.50)
  result <- suppressWarnings(adjust_nonresponse(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  expect_equal(diag$weight_adjustment, 1 / diag$response_rate,
    tolerance = 1e-8
  )
})

# Warning / abort tests --------------------------------------------------------

test_that("NR-06: cli_warn when any response rate < 0.50", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.90, weekend_pct = 0.40)
  expect_warning(
    adjust_nonresponse(design, resp),
    regexp = "Low response rate|<50%"
  )
})

test_that("NR-07: no warning when all response rates >= 0.50", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.90, weekend_pct = 0.60)
  expect_no_warning(adjust_nonresponse(design, resp))
})

test_that("NR-08: cli_abort on zero-response stratum", {
  design <- make_nr_design()
  resp <- data.frame(
    stratum = c("weekday", "weekend"),
    n_sampled = c(100L, 80L),
    n_responded = c(0L, 60L),
    stringsAsFactors = FALSE
  )
  expect_error(
    adjust_nonresponse(design, resp),
    regexp = "Zero-response"
  )
})

test_that("NR-09: cli_abort when n_responded > n_sampled", {
  design <- make_nr_design()
  resp <- data.frame(
    stratum = c("weekday", "weekend"),
    n_sampled = c(100L, 80L),
    n_responded = c(110L, 60L),
    stringsAsFactors = FALSE
  )
  expect_error(
    adjust_nonresponse(design, resp),
    regexp = "n_responded.*n_sampled|n_sampled"
  )
})

test_that("NR-10: errors on non-creel_design input", {
  expect_error(
    adjust_nonresponse(list(), data.frame()),
    regexp = "creel_design"
  )
})

test_that("NR-11: errors when response_rates is missing required columns", {
  design <- make_nr_design()
  bad_resp <- data.frame(stratum = "weekday", n_sampled = 100L)
  expect_error(
    adjust_nonresponse(design, bad_resp),
    regexp = "missing required columns|n_responded"
  )
})

# Perfect response (rate = 1) should be a no-op on estimates ------------------

test_that("NR-12: unit response rate = 1 produces same estimates as unadjusted", {
  design <- make_nr_design()
  resp <- data.frame(
    stratum = c("weekday", "weekend"),
    n_sampled = c(100L, 100L),
    n_responded = c(100L, 100L),
    stringsAsFactors = FALSE
  )
  adj_design <- suppressWarnings(adjust_nonresponse(design, resp))
  est_orig <- suppressWarnings(estimate_catch_rate(design))
  est_adj <- suppressWarnings(estimate_catch_rate(adj_design))
  expect_equal(est_orig$estimates$estimate, est_adj$estimates$estimate,
    tolerance = 1e-6
  )
})
