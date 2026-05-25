# Tests for estimate_angler_trips() — RPT-01
#
# Fixture data used throughout:
#   Ungrouped effort: single-stratum E=1000, se=50, n=20
#   Ungrouped design: 5 interview durations (3.0, 4.0, 5.0, 3.5, 4.5)
#   Grouped effort:   day_type in {weekday, weekend}, E={600,400}, se={30,20}
#   Grouped design:   6 weekday durations, 4 weekend durations

# -- Shared fixtures ----------------------------------------------------------

dur_ungrouped <- c(3.0, 4.0, 5.0, 3.5, 4.5)

effort_ungrouped <- new_creel_estimates(
  estimates = tibble::tibble(
    estimate   = 1000,
    se         = 50,
    se_between = 30,
    se_within  = 40,
    ci_lower   = 902,
    ci_upper   = 1098,
    n          = 20
  ),
  method          = "total",
  variance_method = "taylor",
  design          = NULL,
  conf_level      = 0.95,
  by_vars         = NULL
)

design_ungrouped <- list(
  trip_duration_col = "duration",
  interviews        = data.frame(duration = dur_ungrouped)
)

dur_weekday <- c(3.0, 4.0, 5.0, 3.5, 4.5, 3.0)
dur_weekend <- c(2.0, 3.0, 4.0, 3.5)

effort_grouped <- new_creel_estimates(
  estimates = tibble::tibble(
    day_type = c("weekday", "weekend"),
    estimate = c(600, 400),
    se       = c(30, 20),
    ci_lower = c(541, 361),
    ci_upper = c(659, 439),
    n        = c(60L, 40L)
  ),
  method          = "total",
  variance_method = "taylor",
  design          = NULL,
  conf_level      = 0.95,
  by_vars         = "day_type"
)

design_grouped <- list(
  trip_duration_col = "duration",
  interviews        = data.frame(
    day_type = c(rep("weekday", length(dur_weekday)), rep("weekend", length(dur_weekend))),
    duration = c(dur_weekday, dur_weekend)
  )
)

# -- Tests --------------------------------------------------------------------

test_that("Test A: ungrouped — point estimate equals E / mean(duration)", {
  result   <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  expected <- 1000 / mean(dur_ungrouped)
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
})

test_that("Test B: ungrouped — SE matches Delta Method formula Var(E/L) = Var(E)/L^2 + E^2*Var(L)/L^4", {
  # This test encodes WHY the SE is what it is: Delta Method ratio variance
  # for a derived quantity T = E / L where E and L are independently estimated.
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)

  E     <- 1000
  se_E  <- 50
  L     <- mean(dur_ungrouped)
  se_L  <- stats::sd(dur_ungrouped) / sqrt(length(dur_ungrouped))

  var_trips    <- se_E^2 / L^2 + E^2 * se_L^2 / L^4
  expected_se  <- sqrt(var_trips)

  expect_equal(result$estimates$se, expected_se, tolerance = 1e-10)
})

test_that("Test C: ungrouped — CI contains estimate", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  expect_true(result$estimates$ci_lower <= result$estimates$estimate)
  expect_true(result$estimates$estimate <= result$estimates$ci_upper)
})

test_that("Test D: returns creel_estimates with method angler-trips and variance_method delta", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "angler-trips")
  expect_equal(result$variance_method, "delta")
})

test_that("Test E: ungrouped — no .overall row (single observation)", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  expect_equal(nrow(result$estimates), 1L)
})

test_that("Test F: grouped — .overall row present, estimate = sum of stratum trips", {
  result <- estimate_angler_trips(effort_grouped, design_grouped)

  # Must have 3 rows: weekday, weekend, .overall
  expect_equal(nrow(result$estimates), 3L)

  L_wd <- mean(dur_weekday)
  L_we <- mean(dur_weekend)
  expected_overall <- 600 / L_wd + 400 / L_we

  overall_est <- result$estimates$estimate[result$estimates$day_type == ".overall"]
  expect_equal(overall_est, expected_overall, tolerance = 1e-10)
})

test_that("Test G: grouped — .overall SE is quadrature sum of stratum variances", {
  result <- estimate_angler_trips(effort_grouped, design_grouped)

  L_wd   <- mean(dur_weekday)
  se_L_wd <- stats::sd(dur_weekday) / sqrt(length(dur_weekday))
  L_we   <- mean(dur_weekend)
  se_L_we <- stats::sd(dur_weekend) / sqrt(length(dur_weekend))

  var_wd <- 30^2 / L_wd^2 + 600^2 * se_L_wd^2 / L_wd^4
  var_we <- 20^2 / L_we^2 + 400^2 * se_L_we^2 / L_we^4

  expected_overall_se <- sqrt(var_wd + var_we)

  overall_se <- result$estimates$se[result$estimates$day_type == ".overall"]
  expect_equal(overall_se, expected_overall_se, tolerance = 1e-10)
})

test_that("Test H: grouped — per-stratum estimates match E/L per stratum", {
  result <- estimate_angler_trips(effort_grouped, design_grouped)

  L_wd <- mean(dur_weekday)
  L_we <- mean(dur_weekend)

  ests <- result$estimates[result$estimates$day_type != ".overall", ]
  expect_equal(ests$estimate[ests$day_type == "weekday"], 600 / L_wd, tolerance = 1e-10)
  expect_equal(ests$estimate[ests$day_type == "weekend"], 400 / L_we, tolerance = 1e-10)
})

test_that("Test I: NULL trip_duration_col fires cli_abort", {
  design_no_dur <- list(trip_duration_col = NULL, interviews = data.frame(x = 1:5))
  expect_error(
    estimate_angler_trips(effort_ungrouped, design_no_dur),
    regexp = "trip_duration_col"
  )
})

test_that("Test J: missing by_vars column in interviews fires cli_abort", {
  # Grouped effort expects 'day_type' in interviews, but this design has none
  design_no_bv <- list(
    trip_duration_col = "duration",
    interviews        = data.frame(duration = c(3.0, 4.0, 5.0))
  )
  expect_error(
    estimate_angler_trips(effort_grouped, design_no_bv),
    regexp = "day_type"
  )
})

test_that("Test K: smoke — tidy() returns a data.frame", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  expect_s3_class(tidy(result), "data.frame")
})

test_that("Test L: smoke — write_estimates() to tempfile succeeds", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  tmp    <- tempfile(fileext = ".csv")
  expect_no_error(write_estimates(result, path = tmp))
  expect_true(file.exists(tmp))
})
