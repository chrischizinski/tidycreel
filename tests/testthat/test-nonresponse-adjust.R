# GH #633: nr_adjust() is deprecated because it changes no estimate.
# The tests below that exercise its inputs and diagnostics call it through
# nr_adjust(), which muffles only the deprecation warning, so the function's
# own warnings and errors are still seen; the #633 tests at the end check the
# deprecation warning itself.
nr_adjust <- function(...) {
  withCallingHandlers(
    adjust_nonresponse(...),
    lifecycle_warning_deprecated = function(w) invokeRestart("muffleWarning")
  )
}

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
    add_interviews(
      design,
      example_interviews,
      catch = catch_total,
      effort = hours_fished,
      trip_status = trip_status,
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
  result <- suppressWarnings(nr_adjust(design, resp))
  expect_s3_class(result, "creel_design")
})

test_that("NR-02: adjusted design has nonresponse_diagnostics attribute", {
  design <- make_nr_design()
  resp <- make_response_rates()
  result <- suppressWarnings(nr_adjust(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  expect_s3_class(diag, "data.frame")
})

test_that("NR-03: diagnostics has required columns", {
  design <- make_nr_design()
  resp <- make_response_rates()
  result <- suppressWarnings(nr_adjust(design, resp))
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
  result <- suppressWarnings(nr_adjust(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  wd <- diag[diag$stratum == "weekday", ]
  we <- diag[diag$stratum == "weekend", ]
  expect_equal(wd$response_rate, 0.80, tolerance = 0.01)
  expect_equal(we$response_rate, 0.60, tolerance = 0.01)
})

test_that("NR-05: weight_adjustment = 1 / response_rate", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.80, weekend_pct = 0.50)
  result <- suppressWarnings(nr_adjust(design, resp))
  diag <- attr(result, "nonresponse_diagnostics")
  expect_equal(diag$weight_adjustment, 1 / diag$response_rate, tolerance = 1e-8)
})

# Warning / abort tests --------------------------------------------------------

test_that("NR-06: cli_warn when any response rate < 0.50", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.90, weekend_pct = 0.40)
  expect_warning(
    nr_adjust(design, resp),
    regexp = "Low response rate|<50%"
  )
})

test_that("NR-07: no warning when all response rates >= 0.50", {
  design <- make_nr_design()
  resp <- make_response_rates(weekday_pct = 0.90, weekend_pct = 0.60)
  expect_no_warning(nr_adjust(design, resp))
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
    nr_adjust(design, resp),
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
    nr_adjust(design, resp),
    regexp = "n_responded.*n_sampled|n_sampled"
  )
})

test_that("NR-10: errors on non-creel_design input", {
  expect_error(
    nr_adjust(list(), data.frame()),
    regexp = "creel_design"
  )
})

test_that("NR-11: errors when response_rates is missing required columns", {
  design <- make_nr_design()
  bad_resp <- data.frame(stratum = "weekday", n_sampled = 100L)
  expect_error(
    nr_adjust(design, bad_resp),
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
  adj_design <- suppressWarnings(nr_adjust(design, resp))
  est_orig <- suppressWarnings(estimate_catch_rate(design))
  est_adj <- suppressWarnings(estimate_catch_rate(adj_design))
  expect_equal(est_orig$estimates$estimate, est_adj$estimates$estimate, tolerance = 1e-6)
})

# NR-13: method dispatch guards -----------------------------------------------

test_that("NR-13: method='calibrate' raises an informative error", {
  design <- make_nr_design()
  resp <- data.frame(
    stratum = c("weekday", "weekend"),
    n_sampled = c(80L, 60L),
    n_responded = c(72L, 48L),
    stringsAsFactors = FALSE
  )
  expect_error(
    nr_adjust(design, resp, method = "calibrate"),
    regexp = "not yet implemented"
  )
})

# GH #633 ---------------------------------------------------------------------

test_that("#633: adjust_nonresponse() warns it is deprecated, on every call", {
  design <- make_nr_design()
  resp <- make_response_rates(0.5, 0.9)
  # `always = TRUE`: the second call in a session warns too, since a user who
  # believes the estimates are adjusted must be told each time.
  for (i in 1:2) {
    expect_warning(
      suppressMessages(adjust_nonresponse(design, resp)),
      class = "lifecycle_warning_deprecated"
    )
  }
})

test_that("#633: an adjustment with unequal response rates changes no estimate", {
  # Why it is deprecated: response rates of 0.5 and 0.9 are a large
  # adjustment, yet the rate, total and effort are identical. Counts have no
  # nonresponse, and a per-stratum weight cancels in each stratum's rate.
  design <- make_nr_design()
  adj <- suppressWarnings(suppressMessages(
    adjust_nonresponse(design, make_response_rates(0.5, 0.9))
  ))
  q <- function(x) suppressWarnings(suppressMessages(x))
  expect_identical(
    q(estimate_catch_rate(adj))$estimates$estimate,
    q(estimate_catch_rate(design))$estimates$estimate
  )
  expect_identical(
    q(estimate_total_catch(adj))$estimates$estimate,
    q(estimate_total_catch(design))$estimates$estimate
  )
  expect_identical(
    q(estimate_effort(adj))$estimates$estimate,
    q(estimate_effort(design))$estimates$estimate
  )
  # The diagnostics are still attached.
  expect_s3_class(attr(adj, "nonresponse_diagnostics"), "data.frame")
})
