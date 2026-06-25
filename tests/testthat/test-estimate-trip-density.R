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
    estimate = 1000,
    se = 50,
    se_between = 30,
    se_within = 40,
    ci_lower = 902,
    ci_upper = 1098,
    n = 20
  ),
  method = "total",
  variance_method = "taylor",
  design = NULL,
  conf_level = 0.95,
  by_vars = NULL
)

design_ungrouped <- list(
  trip_duration_col = "duration",
  interviews = data.frame(duration = dur_ungrouped)
)

dur_weekday <- c(3.0, 4.0, 5.0, 3.5, 4.5, 3.0)
dur_weekend <- c(2.0, 3.0, 4.0, 3.5)

effort_grouped <- new_creel_estimates(
  estimates = tibble::tibble(
    day_type = c("weekday", "weekend"),
    estimate = c(600, 400),
    se = c(30, 20),
    ci_lower = c(541, 361),
    ci_upper = c(659, 439),
    n = c(60L, 40L)
  ),
  method = "total",
  variance_method = "taylor",
  design = NULL,
  conf_level = 0.95,
  by_vars = "day_type"
)

design_grouped <- list(
  trip_duration_col = "duration",
  interviews = data.frame(
    day_type = c(rep("weekday", length(dur_weekday)), rep("weekend", length(dur_weekend))),
    duration = c(dur_weekday, dur_weekend)
  )
)

# -- Tests --------------------------------------------------------------------

test_that("Test A: ungrouped — point estimate equals E / mean(duration)", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  expected <- 1000 / mean(dur_ungrouped)
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
})

test_that("Test B: ungrouped — SE matches Delta Method formula Var(E/L) = Var(E)/L^2 + E^2*Var(L)/L^4", {
  # This test encodes WHY the SE is what it is: Delta Method ratio variance
  # for a derived quantity T = E / L where E and L are independently estimated.
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)

  E <- 1000
  se_E <- 50
  L <- mean(dur_ungrouped)
  se_L <- stats::sd(dur_ungrouped) / sqrt(length(dur_ungrouped))

  var_trips <- se_E^2 / L^2 + E^2 * se_L^2 / L^4
  expected_se <- sqrt(var_trips)

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

  L_wd <- mean(dur_weekday)
  se_L_wd <- stats::sd(dur_weekday) / sqrt(length(dur_weekday))
  L_we <- mean(dur_weekend)
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
    interviews = data.frame(duration = c(3.0, 4.0, 5.0))
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
  tmp <- tempfile(fileext = ".csv")
  expect_no_error(write_estimates(result, path = tmp))
  expect_true(file.exists(tmp))
})


# -- RPT-02: estimate_effort_per_acre() tests ---------------------------------

# Fixture: ungrouped effort with se_between/se_within present
effort_with_decomp <- new_creel_estimates(
  estimates = tibble::tibble(
    estimate = 5000,
    se = 250,
    se_between = 150,
    se_within = 200,
    ci_lower = 4510,
    ci_upper = 5490,
    n = 40
  ),
  method = "total",
  variance_method = "taylor",
  design = NULL,
  conf_level = 0.95,
  by_vars = NULL
)

# Fixture: grouped effort without se_between/se_within
effort_grouped_no_decomp <- new_creel_estimates(
  estimates = tibble::tibble(
    day_type = c("weekday", "weekend"),
    estimate = c(3000, 2000),
    se = c(150, 100),
    ci_lower = c(2706, 1804),
    ci_upper = c(3294, 2196),
    n = c(30L, 20L)
  ),
  method = "total",
  variance_method = "taylor",
  design = NULL,
  conf_level = 0.95,
  by_vars = "day_type"
)

test_that("Test M: estimate equals effort estimate / acres", {
  result <- estimate_effort_per_acre(effort_with_decomp, 120)
  expect_equal(result$estimates$estimate, 5000 / 120, tolerance = 1e-10)
})

test_that("Test N: se equals effort se / acres", {
  result <- estimate_effort_per_acre(effort_with_decomp, 120)
  expect_equal(result$estimates$se, 250 / 120, tolerance = 1e-10)
})

test_that("Test O: ci_lower and ci_upper scaled by 1/acres", {
  result <- estimate_effort_per_acre(effort_with_decomp, 120)
  expect_equal(result$estimates$ci_lower, 4510 / 120, tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, 5490 / 120, tolerance = 1e-10)
})

test_that("Test P: se_between and se_within scaled when present", {
  # This test encodes WHY se_between/se_within must be scaled: they are
  # variance components of the effort estimate, and dividing effort by a
  # constant acres divisor requires dividing all SE components by the same
  # constant (linear propagation, no Delta Method needed).
  result <- estimate_effort_per_acre(effort_with_decomp, 120)
  expect_equal(result$estimates$se_between, 150 / 120, tolerance = 1e-10)
  expect_equal(result$estimates$se_within, 200 / 120, tolerance = 1e-10)
})

test_that("Test Q: se_between and se_within absent when not in input", {
  # Guard correctness: when effort lacks variance decomposition columns,
  # estimate_effort_per_acre must not fabricate them.
  result2 <- estimate_effort_per_acre(effort_grouped_no_decomp, 80)
  expect_false("se_between" %in% names(result2$estimates))
  expect_false("se_within" %in% names(result2$estimates))
})

test_that("Test R: returns creel_estimates with method effort-per-acre", {
  result <- estimate_effort_per_acre(effort_with_decomp, 120)
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "effort-per-acre")
})

test_that("Test S: by_vars and conf_level inherited from effort object", {
  result2 <- estimate_effort_per_acre(effort_grouped_no_decomp, 80)
  expect_equal(result2$by_vars, "day_type")
  expect_equal(result2$conf_level, 0.95)
})

test_that("Test T: non-positive acres fires cli_abort", {
  expect_error(estimate_effort_per_acre(effort_with_decomp, 0), regexp = "positive")
  expect_error(estimate_effort_per_acre(effort_with_decomp, -5), regexp = "positive")
})

test_that("Test U: grouped result row count unchanged (no .overall appended)", {
  result2 <- estimate_effort_per_acre(effort_grouped_no_decomp, 80)
  expect_equal(nrow(result2$estimates), 2L)
})

test_that("Test V: smoke — tidy() and write_estimates() succeed", {
  result <- estimate_effort_per_acre(effort_with_decomp, 120)
  expect_s3_class(tidy(result), "data.frame")
  tmp <- tempfile(fileext = ".csv")
  expect_no_error(write_estimates(result, path = tmp))
  expect_true(file.exists(tmp))
})

# -- RPT-01b: single-interview stratum NA-SE guards ---------------------------

test_that("RPT-01b: ungrouped single interview warns and returns NA SE/CI", {
  effort_one <- new_creel_estimates(
    estimates = tibble::tibble(
      estimate = 500,
      se = 25,
      ci_lower = 451,
      ci_upper = 549,
      n = 1L
    ),
    method = "total",
    variance_method = "taylor",
    design = NULL,
    conf_level = 0.95,
    by_vars = NULL
  )
  design_one <- list(
    trip_duration_col = "duration",
    interviews = data.frame(duration = 4.0)
  )
  expect_warning(
    result <- estimate_angler_trips(effort_one, design_one),
    regexp = "SE of mean trip length is undefined"
  )
  expect_false(is.na(result$estimates$estimate)) # point estimate valid
  expect_true(is.na(result$estimates$se))
  expect_true(is.na(result$estimates$ci_lower))
  expect_true(is.na(result$estimates$ci_upper))
})

test_that("RPT-01b: grouped singleton stratum warns and returns NA SE/CI for that row", {
  effort_g <- new_creel_estimates(
    estimates = tibble::tibble(
      day_type = c("weekday", "weekend"),
      estimate = c(600, 400),
      se = c(30, 20),
      ci_lower = c(541, 361),
      ci_upper = c(659, 439),
      n = c(6L, 1L)
    ),
    method = "total",
    variance_method = "taylor",
    design = NULL,
    conf_level = 0.95,
    by_vars = "day_type"
  )
  design_g <- list(
    trip_duration_col = "duration",
    interviews = data.frame(
      day_type = c(rep("weekday", 6), "weekend"),
      duration = c(3.0, 4.0, 5.0, 3.5, 4.5, 3.0, 2.0)
    )
  )
  expect_warning(
    result <- estimate_angler_trips(effort_g, design_g),
    regexp = "SE of mean trip length is undefined"
  )
  stratum_rows <- result$estimates[result$estimates$day_type != ".overall", ]
  wknd <- stratum_rows[stratum_rows$day_type == "weekend", ]
  wkday <- stratum_rows[stratum_rows$day_type == "weekday", ]
  expect_false(is.na(wknd$estimate)) # point estimate valid
  expect_true(is.na(wknd$se)) # SE undefined for singleton
  expect_false(is.na(wkday$se)) # weekday (n=6) has valid SE
})
