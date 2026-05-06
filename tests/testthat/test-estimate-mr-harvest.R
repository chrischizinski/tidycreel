# Build a shared angler_n result for harvest tests
angler_result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
rate           <- 0.35

# --- MR-06: estimate_mr_harvest() delta-method harvest estimator ---

test_that("Test A: harvest = N_hat * harvest_rate", {
  result <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate)
  expect_equal(
    result$estimates$estimate,
    angler_result$estimates$estimate * rate,
    tolerance = 1e-10
  )
})

test_that("Test B: SE = harvest_rate * se_N", {
  result <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate)
  expect_equal(
    result$estimates$se,
    rate * angler_result$estimates$se,
    tolerance = 1e-10
  )
})

test_that("Test C: CI satisfies ci_lower <= estimate <= ci_upper", {
  result <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate)
  expect_true(result$estimates$ci_lower <= result$estimates$estimate)
  expect_true(result$estimates$estimate <= result$estimates$ci_upper)
})

test_that("Test D: conf_level=0.90 gives narrower CI than conf_level=0.95", {
  result_95 <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate, conf_level = 0.95)
  result_90 <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate, conf_level = 0.90)
  expect_true(result_90$estimates$ci_upper < result_95$estimates$ci_upper)
})

test_that("Test E: returns class creel_estimates with method mark-recapture-harvest", {
  result <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate)
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "mark-recapture-harvest")
})

test_that("Test F: parameter column equals 'total_harvest'", {
  result <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate)
  expect_equal(result$estimates$parameter, "total_harvest")
})

test_that("Test G: estimates tibble has columns parameter, estimate, se, ci_lower, ci_upper", {
  result <- estimate_mr_harvest(angler_n = angler_result, harvest_rate = rate)
  expect_named(result$estimates, c("parameter", "estimate", "se", "ci_lower", "ci_upper"))
})

test_that("Test H: non-creel_estimates input fires error matching 'creel_estimates'", {
  expect_error(
    estimate_mr_harvest(angler_n = list(x = 1), harvest_rate = rate),
    regexp = "creel_estimates"
  )
})

test_that("Test I: exploitation-rate creel_estimates fires error", {
  er_result <- estimate_exploitation_rate(T = 200L, C = 450.0, se_C = 42.0, n = 180L, m = 15L)
  expect_error(
    estimate_mr_harvest(angler_n = er_result, harvest_rate = rate),
    regexp = "estimate_angler_n|mark-recapture"
  )
})

test_that("Test J: harvest_rate = 0 fires error", {
  expect_error(
    estimate_mr_harvest(angler_n = angler_result, harvest_rate = 0),
    regexp = "harvest_rate.*must be|\\(0, 1\\]"
  )
})

test_that("Test K: @examples smoke — two-step call completes without error", {
  expect_no_error({
    r <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
    estimate_mr_harvest(angler_n = r, harvest_rate = 0.35)
  })
})

# --- WARNING-03 fix: harvest_rate > 1 upper-bound guard tested ---

test_that("Test L: harvest_rate > 1 fires error", {
  expect_error(
    estimate_mr_harvest(angler_n = angler_result, harvest_rate = 1.1),
    regexp = "harvest_rate.*must be|\\(0, 1\\]"
  )
})
