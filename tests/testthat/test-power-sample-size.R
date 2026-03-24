# Tests for creel_n_effort (POWER-01) and creel_n_cpue (POWER-02)
# Plans 49-01 / 49-02
# POWER-03 and POWER-04 stubs are skipped here, covered in Plans 49-03 and 49-04.

# POWER-01: creel_n_effort ----

test_that("creel_n_effort returns named vector with total element", {
  n_h <- c(weekday = 65, weekend = 28) # nolint: object_name_linter
  ybar_h <- c(weekday = 50, weekend = 60)
  s2_h <- c(weekday = 400, weekend = 500)

  result <- creel_n_effort(
    cv_target = 0.20,
    N_h = n_h, # nolint: object_name_linter
    ybar_h = ybar_h,
    s2_h = s2_h
  )

  expect_true(is.integer(result))
  expect_named(result, c("weekday", "weekend", "total"), ignore.order = FALSE)
  expect_true("total" %in% names(result))
  expect_true(all(result >= 1L))
})

test_that("creel_n_effort proportional allocation: stratum n_h sum is >= total", {
  n_h <- c(weekday = 65, weekend = 28) # nolint: object_name_linter

  result <- creel_n_effort(
    cv_target = 0.20,
    N_h = n_h, # nolint: object_name_linter
    ybar_h = c(weekday = 50, weekend = 60),
    s2_h = c(weekday = 400, weekend = 500)
  )
  stratum_sum <- sum(result[names(result) != "total"])

  # Stratum totals ceiling-ed independently, so sum(n_h) >= n_total
  expect_true(stratum_sum >= result[["total"]])
})

test_that("creel_n_effort structural check: smaller cv_target gives larger n", {
  n_h <- c(weekday = 65, weekend = 28) # nolint: object_name_linter

  n_tight <- creel_n_effort(
    cv_target = 0.10,
    N_h = n_h, # nolint: object_name_linter
    ybar_h = c(50, 60),
    s2_h = c(400, 500)
  )
  n_loose <- creel_n_effort(
    cv_target = 0.30,
    N_h = n_h, # nolint: object_name_linter
    ybar_h = c(50, 60),
    s2_h = c(400, 500)
  )

  expect_true(n_tight[["total"]] > n_loose[["total"]])
})

test_that("creel_n_effort errors on mismatched stratum lengths", {
  n_h <- c(weekday = 65, weekend = 28) # nolint: object_name_linter

  expect_error(
    creel_n_effort(
      cv_target = 0.20,
      N_h = n_h, # nolint: object_name_linter
      ybar_h = c(50, 60, 70), # length mismatch
      s2_h = c(400, 500)
    )
  )
})

test_that("creel_n_effort errors on cv_target outside (0, 1]", {
  n_h <- c(weekday = 65, weekend = 28) # nolint: object_name_linter
  ybar_h <- c(50, 60)
  s2_h <- c(400, 500)

  expect_error(creel_n_effort(cv_target = 0, N_h = n_h, ybar_h = ybar_h, s2_h = s2_h)) # nolint: object_name_linter
  expect_error(creel_n_effort(cv_target = -0.1, N_h = n_h, ybar_h = ybar_h, s2_h = s2_h)) # nolint: object_name_linter
  expect_error(creel_n_effort(cv_target = 1.1, N_h = n_h, ybar_h = ybar_h, s2_h = s2_h)) # nolint: object_name_linter
})

test_that("creel_n_effort errors on unnamed N_h", {
  expect_error(
    creel_n_effort(
      cv_target = 0.20,
      N_h = c(65, 28), # nolint: object_name_linter
      ybar_h = c(50, 60),
      s2_h = c(400, 500)
    )
  )
})

test_that("creel_n_effort works with single stratum", {
  result <- creel_n_effort(
    cv_target = 0.20,
    N_h = c(all_days = 93), # nolint: object_name_linter
    ybar_h = c(55),
    s2_h = c(450)
  )
  expect_named(result, c("all_days", "total"))
  expect_true(result[["all_days"]] >= 1L)
  expect_true(result[["total"]] >= 1L)
})

# POWER-02: creel_n_cpue ----

test_that("creel_n_cpue returns integer >= 1 for valid inputs", {
  result <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)

  expect_true(is.integer(result))
  expect_length(result, 1L)
  expect_true(result >= 1L)
})

test_that("creel_n_cpue numerical check: cv_catch=0.8, cv_effort=0.5, rho=0, cv_target=0.20 gives 23", {
  # ceiling((0.64 + 0.25 - 0) / 0.04) = ceiling(22.25) = 23 # nolint: commented_code_linter
  result <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)
  expect_equal(result, 23L)
})

test_that("creel_n_cpue rho=0 gives n >= rho>0 (conservative)", {
  n_no_corr <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)
  n_with_corr <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0.5, cv_target = 0.20)

  expect_true(n_no_corr >= n_with_corr)
})

test_that("creel_n_cpue errors on cv_target <= 0", {
  expect_error(creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0))
  expect_error(creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = -0.1))
})

test_that("creel_n_cpue errors on cv_target > 1", {
  expect_error(creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 1.5))
})

test_that("creel_n_cpue errors on rho outside valid range", {
  expect_error(creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 1.5, cv_target = 0.20))
  expect_error(creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = -1.5, cv_target = 0.20))
})

test_that("creel_n_cpue errors on non-positive cv_catch or cv_effort", {
  expect_error(creel_n_cpue(cv_catch = 0, cv_effort = 0.5, rho = 0, cv_target = 0.20))
  expect_error(creel_n_cpue(cv_catch = 0.8, cv_effort = 0, rho = 0, cv_target = 0.20))
})

test_that("creel_n_cpue returns at least 1 when formula result rounds down", {
  result <- creel_n_cpue(cv_catch = 0.01, cv_effort = 0.01, rho = 0, cv_target = 0.99)
  expect_true(result >= 1L)
})

# POWER-03: creel_power ----

test_that("creel_power returns ~0.807 for known inputs (n=100, cv=0.5, delta=0.20)", {
  # ncp = 0.20 * sqrt(100/2) / 0.5 = 0.20 * 7.071 / 0.5 = 2.828 # nolint: commented_code_linter
  # z_crit = qnorm(0.975) = 1.96 # nolint: commented_code_linter
  # power = pnorm(2.828 - 1.96) + pnorm(-2.828 - 1.96) = 0.807 + ~0 = 0.807 # nolint: commented_code_linter
  result <- creel_power(n = 100, cv_historical = 0.5, delta_pct = 0.20)
  expect_equal(result, 0.807, tolerance = 0.001)
})

test_that("creel_power one-sided power > two-sided power for same inputs", {
  pwr_two <- creel_power(n = 50, cv_historical = 0.5, delta_pct = 0.20, alternative = "two.sided")
  pwr_one <- creel_power(n = 50, cv_historical = 0.5, delta_pct = 0.20, alternative = "one.sided")
  expect_true(pwr_one > pwr_two)
})

test_that("creel_power errors on n < 1", {
  expect_error(creel_power(n = 0, cv_historical = 0.5, delta_pct = 0.20))
  expect_error(creel_power(n = -5, cv_historical = 0.5, delta_pct = 0.20))
})

test_that("creel_power warns when delta_pct > 5", {
  expect_warning(
    creel_power(n = 100, cv_historical = 0.5, delta_pct = 6),
    regexp = "delta_pct > 5"
  )
})

test_that("creel_power returns a numeric scalar in (0, 1)", {
  result <- creel_power(n = 30, cv_historical = 0.6, delta_pct = 0.30)
  expect_true(is.numeric(result))
  expect_length(result, 1L)
  expect_true(result > 0 && result < 1)
})

# POWER-04: cv_from_n ----

test_that("cv_from_n effort round-trip: recovered CV <= target CV", {
  N_h <- c(weekday = 65L, weekend = 28L) # nolint: object_name_linter
  ybar_h <- c(weekday = 50, weekend = 60)
  s2_h <- c(weekday = 400, weekend = 500)
  cv_target <- 0.20

  n_required <- creel_n_effort(cv_target, N_h = N_h, ybar_h = ybar_h, s2_h = s2_h) # nolint: object_name_linter
  cv_back <- cv_from_n("effort", n = n_required[["total"]], N_h = N_h, ybar_h = ybar_h, s2_h = s2_h) # nolint: object_name_linter
  expect_lte(cv_back, cv_target)
})

test_that("cv_from_n cpue round-trip: recovered CV <= target CV", {
  cv_target <- 0.20
  n_req <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = cv_target)
  cv_back <- cv_from_n("cpue", n = n_req, cv_catch = 0.8, cv_effort = 0.5, rho = 0)
  expect_lte(cv_back, cv_target)
})

test_that("cv_from_n errors on n < 1", {
  N_h <- c(weekday = 65L) # nolint: object_name_linter
  expect_error(cv_from_n("effort", n = 0, N_h = N_h, ybar_h = 50, s2_h = 400)) # nolint: object_name_linter
  expect_error(cv_from_n("cpue", n = 0, cv_catch = 0.8, cv_effort = 0.5))
})

test_that("cv_from_n returns numeric scalar > 0", {
  N_h <- c(weekday = 65L) # nolint: object_name_linter
  result <- cv_from_n("effort", n = 10L, N_h = N_h, ybar_h = 50, s2_h = 400) # nolint: object_name_linter
  expect_true(is.numeric(result))
  expect_length(result, 1L)
  expect_true(result > 0)
})
