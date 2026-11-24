# Tests for estimate_angler_trips() — RPT-01
#
# Effort objects are hand-built (estimate, se), so the tests isolate the trip
# length side. Designs are real: since GH #689 the mean trip length is a ratio
# estimator on the interview survey (interviews clustered within days, complete
# trips only), and the reference values below come from survey::svydesign()
# built directly on the interview frame, not from the package.

# -- Shared fixtures ----------------------------------------------------------

# Interviews over two day types, two or three days each. Incomplete trips are
# present on every day and must not reach the trip length.
td_interviews <- function() {
  data.frame(
    date = as.Date("2024-06-03") + c(0, 0, 0, 1, 1, 1, 2, 2, 5, 5, 5, 6, 6, 6),
    day_type = rep(c("weekday", "weekend"), c(8, 6)),
    trip_status = c(
      "complete", "complete", "incomplete", "complete", "complete", "incomplete", "complete", "complete",
      "complete", "complete", "incomplete", "complete", "complete", "incomplete"
    ),
    duration = c(3.0, 4.0, 0.5, 5.0, 3.5, 1.0, 4.5, 3.0, 2.0, 3.0, 0.5, 4.0, 3.5, 1.5),
    hours = 2,
    catch = 0L
  )
}

td_design <- function(iv = td_interviews()) {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:6,
    day_type = c(rep("weekday", 5), rep("weekend", 2))
  )
  # One stratum when the interviews carry one: ungrouped effort is accepted
  # only where there is nothing to pool across (GH #691).
  if (length(unique(iv$day_type)) == 1L) cal$day_type <- iv$day_type[1]
  d <- creel_design(cal, date = date, strata = day_type)
  suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch, effort = hours, trip_status = trip_status, trip_duration = duration
  )))
}

# Reference trip length from the survey package directly: complete trips,
# days as PSUs within day-type strata.
td_ref_svy <- function(iv = td_interviews()) {
  s <- suppressWarnings(survey::svydesign(ids = ~date, strata = ~day_type, data = iv))
  subset(s, trip_status == "complete")
}

# The ungrouped tests run on a one-stratum season: on a stratified one,
# ungrouped effort is refused (GH #691, tested below).
td_interviews_one <- function() {
  iv <- td_interviews()
  iv$day_type <- "season"
  iv
}
design_ungrouped <- td_design(td_interviews_one())
design_grouped <- td_design()
ref_ungrouped <- survey::svymean(~duration, td_ref_svy(td_interviews_one()))
ref_grouped <- survey::svyby(~duration, ~day_type, td_ref_svy(), survey::svymean)
ref_L <- function(dt) ref_grouped$duration[ref_grouped$day_type == dt]
ref_se <- function(dt) survey::SE(ref_grouped)[ref_grouped$day_type == dt]

effort_ungrouped <- new_creel_estimates(
  ci_df = Inf,
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

effort_grouped <- new_creel_estimates(
  ci_df = Inf,
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

# -- Tests --------------------------------------------------------------------

test_that("Test A: ungrouped — point estimate equals E / mean complete-trip length", {
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)
  iv <- td_interviews()
  expected <- 1000 / mean(iv$duration[iv$trip_status == "complete"])
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
  # The incomplete trips (0.5-1.5 h elapsed) would pull L down and trips up.
  expect_lt(result$estimates$estimate, 1000 / mean(iv$duration))
  expect_equal(result$estimates$n, sum(iv$trip_status == "complete"))
})

test_that("Test B: ungrouped — SE matches Delta Method formula Var(E/L) = Var(E)/L^2 + E^2*Var(L)/L^4", {
  # This test encodes WHY the SE is what it is: Delta Method ratio variance
  # for a derived quantity T = E / L where E and L are independently estimated,
  # with Var(L) from the interview design (days as PSUs), not sd / sqrt(n).
  result <- estimate_angler_trips(effort_ungrouped, design_ungrouped)

  E <- 1000
  se_E <- 50
  L <- as.numeric(coef(ref_ungrouped))
  se_L <- as.numeric(survey::SE(ref_ungrouped))

  var_trips <- se_E^2 / L^2 + E^2 * se_L^2 / L^4
  expected_se <- sqrt(var_trips)

  expect_equal(result$estimates$se, expected_se, tolerance = 1e-10)
  # The CI uses the interview design's df (5 days less 1 stratum), not n - 1.
  t4 <- stats::qt(0.975, df = 4)
  expect_equal(result$estimates$ci_upper - result$estimates$estimate, t4 * expected_se)
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

test_that("ungrouped effort on a stratified design is refused, not pooled (GH #691)", {
  # One trip length pooled over weekdays and weekends is weighted by the
  # interviews each stratum got, not by its share of the trips, so E / L is
  # biased whenever interviewing is not proportional to effort. Season trips
  # are sum_h E_h / L_h, which needs effort by stratum.
  expect_error(
    estimate_angler_trips(effort_ungrouped, design_grouped),
    class = "creel_error_trips_need_strata"
  )
  expect_error(
    estimate_angler_trips(effort_ungrouped, design_grouped),
    "by = day_type"
  )
  # Effort grouped by something other than the strata pools them all the same.
  by_other <- effort_grouped
  by_other$by_vars <- "angler_type"
  by_other$estimates <- dplyr::rename(by_other$estimates, angler_type = day_type)
  iv <- td_interviews()
  iv$angler_type <- iv$day_type
  expect_error(
    estimate_angler_trips(by_other, td_design(iv)),
    "c\\(day_type, angler_type\\)"
  )
})

test_that("Test F: grouped — .overall row present, estimate = sum of stratum trips", {
  result <- estimate_angler_trips(effort_grouped, design_grouped)

  # Must have 3 rows: weekday, weekend, .overall
  expect_equal(nrow(result$estimates), 3L)

  expected_overall <- 600 / ref_L("weekday") + 400 / ref_L("weekend")

  overall_est <- result$estimates$estimate[result$estimates$day_type == ".overall"]
  expect_equal(overall_est, expected_overall, tolerance = 1e-10)
})

test_that("Test G: grouped — .overall SE is quadrature sum of stratum variances", {
  result <- estimate_angler_trips(effort_grouped, design_grouped)

  var_wd <- 30^2 / ref_L("weekday")^2 + 600^2 * ref_se("weekday")^2 / ref_L("weekday")^4
  var_we <- 20^2 / ref_L("weekend")^2 + 400^2 * ref_se("weekend")^2 / ref_L("weekend")^4

  expected_overall_se <- sqrt(var_wd + var_we)

  overall_se <- result$estimates$se[result$estimates$day_type == ".overall"]
  expect_equal(overall_se, expected_overall_se, tolerance = 1e-10)
})

test_that("Test H: grouped — per-stratum estimates match E/L per stratum", {
  result <- estimate_angler_trips(effort_grouped, design_grouped)

  ests <- result$estimates[result$estimates$day_type != ".overall", ]
  expect_equal(ests$estimate[ests$day_type == "weekday"], 600 / ref_L("weekday"), tolerance = 1e-10)
  expect_equal(ests$estimate[ests$day_type == "weekend"], 400 / ref_L("weekend"), tolerance = 1e-10)
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
  ci_df = Inf,
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
  ci_df = Inf,
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
    ci_df = Inf,
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
  # One complete trip; the rest are incomplete and do not count.
  iv <- td_interviews_one()
  iv$trip_status <- "incomplete"
  iv$trip_status[1] <- "complete"
  design_one <- td_design(iv)
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
    ci_df = Inf,
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
  # One complete weekend trip; the other weekend interviews are incomplete.
  iv <- td_interviews()
  iv$trip_status[iv$day_type == "weekend"] <- "incomplete"
  iv$trip_status[9] <- "complete"
  design_g <- td_design(iv)
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

# TRIPD-112: effort-family guard (finding 11) ----

make_effort_and_rate <- function() {
  design <- build_multispecies_design_for_tests(n_days = 8, n_interviews = 24, seed = 3)
  list(
    design = design,
    effort = suppressWarnings(suppressMessages(estimate_effort(design))),
    rate = suppressWarnings(suppressMessages(estimate_catch_rate(design)))
  )
}

test_that("estimate_angler_trips() rejects a rate object (GH #112)", {
  # Both consumers guarded only on class, never on $method. A CPUE object passed
  # the class check, so fish per hour was divided by hours per trip and
  # relabelled "angler-trips" -- a number with no defensible unit and no warning.
  #
  # The guard is on the quantity, not the actor: it refuses a rate, and admits
  # party-hours effort (finding 12c). These matchers said "angler-hours" while
  # the message did, which was the wrong claim rather than the wrong check.
  fx <- make_effort_and_rate()

  expect_error(
    estimate_angler_trips(fx$rate, fx$design),
    "must hold effort"
  )
})

test_that("estimate_effort_per_acre() rejects a rate object (GH #112)", {
  fx <- make_effort_and_rate()

  expect_error(
    estimate_effort_per_acre(fx$rate, acres = 100),
    "must hold effort"
  )
})

test_that("estimate_angler_trips() rejects a fish-valued total (GH #112)", {
  # The bus-route HT totals are the other way in: fish-valued, and since GH #111
  # they carry their own method strings rather than the effort string "total".
  design <- build_br_design_for_tests(n_sites = 3, n_days = 8, n_interviews = 24, seed = 42)
  total <- suppressWarnings(suppressMessages(estimate_total_harvest(design, target = "sampled_days")))

  expect_error(
    estimate_angler_trips(total, design),
    "must hold effort"
  )
})

test_that("the effort-family guard still admits genuine effort objects (GH #112)", {
  # The guard must not reject what these functions exist to consume.
  fx <- make_effort_and_rate()
  # The fixture's counts carry no period length, so the effort's unit is
  # unknown and, with varying party sizes, trips refuse it (GH #689). Declaring
  # it here isolates the guard under test.
  fx$effort$unit <- "angler-hours"
  # Trips need effort by stratum on a stratified design (GH #691).
  by_stratum <- suppressWarnings(suppressMessages(
    estimate_effort(fx$design, by = dplyr::all_of(fx$design$strata_cols))
  ))
  by_stratum$unit <- "angler-hours"

  expect_s3_class(
    suppressWarnings(estimate_angler_trips(by_stratum, fx$design)),
    "creel_estimates"
  )
  expect_s3_class(
    suppressWarnings(estimate_effort_per_acre(fx$effort, acres = 100)),
    "creel_estimates"
  )
})
