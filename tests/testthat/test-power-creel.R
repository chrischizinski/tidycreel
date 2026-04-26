# Tests for power_creel() ----

# Shared inputs ---------------------------------------------------------------
effort_args <- list(
  strata = c("weekday", "weekend"),
  N_h    = c(65, 28),
  ybar_h = c(50, 60),
  s2_h   = c(400, 500)
)

# mode = "effort_n" -----------------------------------------------------------

test_that("PWRC-01: effort_n returns data frame", {
  res <- do.call(power_creel, c(
    list(mode = "effort_n", target_rse = 0.20),
    effort_args
  ))
  expect_s3_class(res, "data.frame")
})

test_that("PWRC-02: effort_n has expected columns", {
  res <- do.call(power_creel, c(
    list(mode = "effort_n", target_rse = 0.20),
    effort_args
  ))
  expect_named(res, c("stratum", "n_required", "target_rse"))
})

test_that("PWRC-03: effort_n has stratum rows + total row", {
  res <- do.call(power_creel, c(
    list(mode = "effort_n", target_rse = 0.20),
    effort_args
  ))
  expect_true("total" %in% res$stratum)
  expect_true("weekday" %in% res$stratum)
  expect_true("weekend" %in% res$stratum)
})

test_that("PWRC-04: effort_n n_required are positive integers", {
  res <- do.call(power_creel, c(
    list(mode = "effort_n", target_rse = 0.20),
    effort_args
  ))
  expect_true(is.integer(res$n_required))
  expect_true(all(res$n_required >= 1L))
})

test_that("PWRC-05: effort_n target_rse column matches input", {
  res <- do.call(power_creel, c(
    list(mode = "effort_n", target_rse = 0.15),
    effort_args
  ))
  expect_true(all(res$target_rse == 0.15))
})

test_that("PWRC-06: effort_n higher RSE target gives fewer required days", {
  n_tight <- do.call(
    power_creel,
    c(list(mode = "effort_n", target_rse = 0.10), effort_args)
  )
  n_loose <- do.call(
    power_creel,
    c(list(mode = "effort_n", target_rse = 0.30), effort_args)
  )
  expect_gt(
    n_tight$n_required[n_tight$stratum == "total"],
    n_loose$n_required[n_loose$stratum == "total"]
  )
})

test_that("PWRC-07: effort_n errors without target_rse", {
  expect_error(
    do.call(power_creel, c(list(mode = "effort_n"), effort_args)),
    class = "rlang_error"
  )
})

test_that("PWRC-08: effort_n errors without N_h", {
  expect_error(
    power_creel(
      mode = "effort_n", target_rse = 0.20,
      strata = c("a", "b"), ybar_h = c(1, 1), s2_h = c(1, 1)
    ),
    class = "rlang_error"
  )
})

test_that("PWRC-09: effort_n errors when strata length != N_h length", {
  expect_error(
    power_creel(
      mode = "effort_n", target_rse = 0.20,
      strata = c("a"), N_h = c(10, 20),
      ybar_h = c(1, 1), s2_h = c(1, 1)
    ),
    class = "rlang_error"
  )
})

# mode = "cpue_n" -------------------------------------------------------------

test_that("PWRC-10: cpue_n returns data frame", {
  res <- power_creel(
    mode = "cpue_n", target_rse = 0.20,
    cv_catch = 0.8, cv_effort = 0.5
  )
  expect_s3_class(res, "data.frame")
})

test_that("PWRC-11: cpue_n has expected columns", {
  res <- power_creel(
    mode = "cpue_n", target_rse = 0.20,
    cv_catch = 0.8, cv_effort = 0.5
  )
  expect_named(res, c(
    "n_required", "target_rse", "cv_catch",
    "cv_effort", "rho"
  ))
})

test_that("PWRC-12: cpue_n n_required is a positive integer", {
  res <- power_creel(
    mode = "cpue_n", target_rse = 0.20,
    cv_catch = 0.8, cv_effort = 0.5
  )
  expect_equal(nrow(res), 1L)
  expect_true(is.integer(res$n_required))
  expect_gt(res$n_required, 0L)
})

test_that("PWRC-13: cpue_n rho = 0.5 gives fewer interviews than rho = 0", {
  n_zero <- power_creel(
    mode = "cpue_n", target_rse = 0.20,
    cv_catch = 0.8, cv_effort = 0.5, rho = 0
  )$n_required
  n_pos <- power_creel(
    mode = "cpue_n", target_rse = 0.20,
    cv_catch = 0.8, cv_effort = 0.5, rho = 0.5
  )$n_required
  expect_gte(n_zero, n_pos)
})

test_that("PWRC-14: cpue_n errors without target_rse", {
  expect_error(
    power_creel(mode = "cpue_n", cv_catch = 0.8, cv_effort = 0.5),
    class = "rlang_error"
  )
})

test_that("PWRC-15: cpue_n errors without cv_catch", {
  expect_error(
    power_creel(mode = "cpue_n", target_rse = 0.20, cv_effort = 0.5),
    class = "rlang_error"
  )
})

# mode = "power" --------------------------------------------------------------

test_that("PWRC-16: power mode returns data frame", {
  res <- power_creel(
    mode = "power", n = 80L,
    cv_historical = 0.5, delta_pct = 0.20
  )
  expect_s3_class(res, "data.frame")
})

test_that("PWRC-17: power mode has expected columns", {
  res <- power_creel(
    mode = "power", n = 80L,
    cv_historical = 0.5, delta_pct = 0.20
  )
  expect_named(res, c(
    "power", "n", "delta_pct", "cv_historical",
    "alpha", "alternative"
  ))
})

test_that("PWRC-18: power is in (0, 1)", {
  res <- power_creel(
    mode = "power", n = 80L,
    cv_historical = 0.5, delta_pct = 0.20
  )
  expect_gt(res$power, 0)
  expect_lt(res$power, 1)
})

test_that("PWRC-19: larger n gives higher power", {
  p_small <- power_creel(
    mode = "power", n = 30L,
    cv_historical = 0.5, delta_pct = 0.20
  )$power
  p_large <- power_creel(
    mode = "power", n = 200L,
    cv_historical = 0.5, delta_pct = 0.20
  )$power
  expect_gt(p_large, p_small)
})

test_that("PWRC-20: cv_catch used as cv_historical proxy", {
  res <- power_creel(
    mode = "power", n = 80L,
    cv_catch = 0.5, delta_pct = 0.20
  )
  expect_equal(res$cv_historical, 0.5)
})

test_that("PWRC-21: power mode errors without n", {
  expect_error(
    power_creel(mode = "power", cv_historical = 0.5, delta_pct = 0.20),
    class = "rlang_error"
  )
})

test_that("PWRC-22: power mode errors without delta_pct", {
  expect_error(
    power_creel(mode = "power", n = 80L, cv_historical = 0.5),
    class = "rlang_error"
  )
})

test_that("PWRC-23: power mode errors without cv source", {
  expect_error(
    power_creel(mode = "power", n = 80L, delta_pct = 0.20),
    class = "rlang_error"
  )
})

test_that("PWRC-24: one.sided gives higher power than two.sided", {
  p_two <- power_creel(
    mode = "power", n = 80L,
    cv_historical = 0.5, delta_pct = 0.20,
    alternative = "two.sided"
  )$power
  p_one <- power_creel(
    mode = "power", n = 80L,
    cv_historical = 0.5, delta_pct = 0.20,
    alternative = "one.sided"
  )$power
  expect_gt(p_one, p_two)
})

test_that("PWRC-25: default mode is effort_n", {
  res <- power_creel(
    target_rse = 0.20,
    strata = effort_args$strata,
    N_h = effort_args$N_h,
    ybar_h = effort_args$ybar_h,
    s2_h = effort_args$s2_h
  )
  expect_true("stratum" %in% names(res))
})
