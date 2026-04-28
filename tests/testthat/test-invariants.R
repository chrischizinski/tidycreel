test_that("Phase 79 generator smoke test yields a valid bus-route design", {
  design <- build_br_design_for_tests(3L, 6L, 8L, seed = 42L)

  expect_s3_class(design, "creel_design")
  expect_identical(design$design_type, "bus_route")
  expect_true(nrow(design$interviews) == 8L)
  expect_true(all(design$interviews$n_counted >= design$interviews$n_interviewed))
})

test_that("INV-04: estimate outputs stay inside confidence bounds", {
  skip_if_not_installed("quickcheck")

  design <- build_br_design_for_tests(3L, 6L, 8L, seed = 42L)
  effort_fixed <- suppressWarnings(estimate_effort(design))
  catch_fixed <- suppressWarnings(estimate_total_catch(design))
  harvest_fixed <- suppressWarnings(estimate_harvest_rate(design))

  expect_true(all(effort_fixed$estimates$ci_lower <= effort_fixed$estimates$estimate))
  expect_true(all(effort_fixed$estimates$estimate <= effort_fixed$estimates$ci_upper))
  expect_true(all(catch_fixed$estimates$ci_lower <= catch_fixed$estimates$estimate))
  expect_true(all(catch_fixed$estimates$estimate <= catch_fixed$estimates$ci_upper))
  expect_true(all(harvest_fixed$estimates$ci_lower <= harvest_fixed$estimates$estimate))
  expect_true(all(harvest_fixed$estimates$estimate <= harvest_fixed$estimates$ci_upper))

  quickcheck::for_all(
    design = gen_valid_creel_design(n_min = 2L),
    property = function(design) {
      effort <- suppressWarnings(estimate_effort(design))
      catch <- suppressWarnings(estimate_total_catch(design))
      harvest <- suppressWarnings(estimate_harvest_rate(design))

      expect_true(all(effort$estimates$ci_lower <= effort$estimates$estimate))
      expect_true(all(effort$estimates$estimate <= effort$estimates$ci_upper))
      expect_true(all(catch$estimates$ci_lower <= catch$estimates$estimate))
      expect_true(all(catch$estimates$estimate <= catch$estimates$ci_upper))
      expect_true(all(harvest$estimates$ci_lower <= harvest$estimates$estimate))
      expect_true(all(harvest$estimates$estimate <= harvest$estimates$ci_upper))
    }
  )
})

test_that("INV-01: standard errors are positive across estimators", {
  skip_if_not_installed("quickcheck")

  design <- build_br_design_for_tests(3L, 6L, 8L, seed = 42L)
  effort_fixed <- suppressWarnings(estimate_effort(design))
  catch_fixed <- suppressWarnings(estimate_total_catch(design))
  harvest_fixed <- suppressWarnings(estimate_harvest_rate(design))

  expect_true(all(is.finite(effort_fixed$estimates$se) & effort_fixed$estimates$se > 0))
  expect_true(all(is.finite(catch_fixed$estimates$se) & catch_fixed$estimates$se > 0))
  expect_true(all(is.finite(harvest_fixed$estimates$se) & harvest_fixed$estimates$se > 0))

  quickcheck::for_all(
    design = gen_valid_creel_design(n_min = 2L),
    property = function(design) {
      effort <- suppressWarnings(estimate_effort(design))
      catch <- suppressWarnings(estimate_total_catch(design))
      harvest <- suppressWarnings(estimate_harvest_rate(design))

      expect_true(all(is.finite(effort$estimates$se) & effort$estimates$se > 0))
      expect_true(all(is.finite(catch$estimates$se) & catch$estimates$se > 0))
      expect_true(all(is.finite(harvest$estimates$se) & harvest$estimates$se > 0))
    }
  )
})

test_that("INV-02: catch and harvest estimates are non-negative", {
  skip_if_not_installed("quickcheck")

  design <- build_br_design_for_tests(3L, 6L, 8L, seed = 42L)
  catch_fixed <- suppressWarnings(estimate_total_catch(design))
  harvest_fixed <- suppressWarnings(estimate_harvest_rate(design))

  expect_true(all(catch_fixed$estimates$estimate >= 0))
  expect_true(all(harvest_fixed$estimates$estimate >= 0))

  quickcheck::for_all(
    design = gen_valid_creel_design(n_min = 2L),
    property = function(design) {
      catch <- suppressWarnings(estimate_total_catch(design))
      harvest <- suppressWarnings(estimate_harvest_rate(design))

      expect_true(all(catch$estimates$estimate >= 0))
      expect_true(all(harvest$estimates$estimate >= 0))
    }
  )
})

test_that("INV-06: species total catch estimates sum to the aggregate total", {
  skip_if_not_installed("quickcheck")

  design <- build_multispecies_design_for_tests(
    n_days = 6L,
    n_interviews = 10L,
    n_species = 3L,
    seed = 42L
  )

  aggregate_fixed <- suppressWarnings(suppressMessages(estimate_total_catch(design)))
  per_species_fixed <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, by = species)
  ))

  expect_equal(
    sum(per_species_fixed$estimates$estimate),
    aggregate_fixed$estimates$estimate,
    tolerance = 1e-6
  )

  quickcheck::for_all(
    design = gen_valid_creel_design_multi_species(n_species_min = 2L),
    property = function(design) {
      aggregate <- suppressWarnings(suppressMessages(estimate_total_catch(design)))
      per_species <- suppressWarnings(suppressMessages(
        estimate_total_catch(design, by = species)
      ))

      expect_equal(
        sum(per_species$estimates$estimate),
        aggregate$estimates$estimate,
        tolerance = 1e-6
      )
    }
  )
})

test_that("INV-06 multi-strata: species total catch sum equals aggregate for two-stratum designs", {
  skip_if_not_installed("quickcheck")

  design <- build_multistrata_multispecies_design_for_tests(
    n_days = 6L,
    n_interviews = 10L,
    n_species = 3L,
    seed = 42L
  )

  aggregate_fixed <- suppressWarnings(suppressMessages(estimate_total_catch(design)))
  per_species_fixed <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, by = species)
  ))

  expect_equal(
    sum(per_species_fixed$estimates$estimate),
    aggregate_fixed$estimates$estimate,
    tolerance = 1e-6
  )

  quickcheck::for_all(
    design = gen_valid_creel_design_multistrata_multispecies(n_species_min = 2L),
    property = function(design) {
      aggregate <- suppressWarnings(suppressMessages(estimate_total_catch(design)))
      per_species <- suppressWarnings(suppressMessages(
        estimate_total_catch(design, by = species)
      ))

      expect_equal(
        sum(per_species$estimates$estimate),
        aggregate$estimates$estimate,
        tolerance = 1e-6
      )
    }
  )
})

# Phase 81: Exploitation-Rate Invariants

test_that("INV-bound: u_hat in [0,1] for bounded inputs", {
  skip_if_not_installed("quickcheck")

  # Generate inputs where C <= T to guarantee u_hat <= 1
  quickcheck::for_all(
    T_val   = quickcheck::integer_bounded(left = 1L, right = 500L, len = 1L),
    n_val   = quickcheck::integer_bounded(left = 1L, right = 300L, len = 1L),
    frac_m  = quickcheck::double_bounded(left = 0, right = 1, len = 1L),
    frac_C  = quickcheck::double_bounded(left = 0, right = 1, len = 1L),
    se_frac = quickcheck::double_bounded(left = 0, right = 0.5, len = 1L),
    property = function(T_val, n_val, frac_m, frac_C, se_frac) {
      m_val    <- as.integer(floor(frac_m * n_val))
      C_val    <- frac_C * T_val                    # C <= T => u_hat <= 1
      se_C_val <- se_frac * C_val
      r <- estimate_exploitation_rate(
        T = T_val, C = C_val, se_C = se_C_val, n = n_val, m = m_val
      )
      u <- r$estimates$estimate
      expect_true(u >= 0 && u <= 1)
    }
  )
})

test_that("INV-monotone-C: u_hat increases with C (T, n, m fixed)", {
  skip_if_not_installed("quickcheck")

  quickcheck::for_all(
    T_val  = quickcheck::integer_bounded(left = 10L, right = 500L, len = 1L),
    n_val  = quickcheck::integer_bounded(left = 5L,  right = 300L, len = 1L),
    frac_m = quickcheck::double_bounded(left = 0.01, right = 0.5, len = 1L),
    property = function(T_val, n_val, frac_m) {
      m_val  <- as.integer(floor(frac_m * n_val))
      C1     <- T_val * 0.1
      C2     <- T_val * 0.5
      se_C   <- T_val * 0.05
      u1 <- estimate_exploitation_rate(
        T = T_val, C = C1, se_C = se_C, n = n_val, m = m_val
      )$estimates$estimate
      u2 <- estimate_exploitation_rate(
        T = T_val, C = C2, se_C = se_C, n = n_val, m = m_val
      )$estimates$estimate
      expect_true(u2 > u1)
    }
  )
})

test_that("INV-monotone-m: u_hat increases with m (T, C, n fixed)", {
  skip_if_not_installed("quickcheck")

  quickcheck::for_all(
    T_val  = quickcheck::integer_bounded(left = 10L, right = 500L, len = 1L),
    n_val  = quickcheck::integer_bounded(left = 10L, right = 300L, len = 1L),
    frac_C = quickcheck::double_bounded(left = 0.05, right = 0.5, len = 1L),
    property = function(T_val, n_val, frac_C) {
      C_val  <- frac_C * T_val
      se_C   <- C_val * 0.1
      m1     <- as.integer(floor(n_val * 0.05))
      m2     <- as.integer(floor(n_val * 0.30))
      if (m1 >= m2) return(invisible(TRUE))  # skip degenerate case
      u1 <- estimate_exploitation_rate(
        T = T_val, C = C_val, se_C = se_C, n = n_val, m = m1
      )$estimates$estimate
      u2 <- estimate_exploitation_rate(
        T = T_val, C = C_val, se_C = se_C, n = n_val, m = m2
      )$estimates$estimate
      expect_true(u2 > u1)
    }
  )
})

test_that("INV-strata-agg: aggregate equals T-weighted mean of stratum estimates", {
  skip_if_not_installed("quickcheck")

  quickcheck::for_all(
    T1      = quickcheck::integer_bounded(left = 10L, right = 300L, len = 1L),
    T2      = quickcheck::integer_bounded(left = 10L, right = 300L, len = 1L),
    frac_C1 = quickcheck::double_bounded(left = 0.01, right = 0.5, len = 1L),
    frac_C2 = quickcheck::double_bounded(left = 0.01, right = 0.5, len = 1L),
    frac_m1 = quickcheck::double_bounded(left = 0.01, right = 0.5, len = 1L),
    frac_m2 = quickcheck::double_bounded(left = 0.01, right = 0.5, len = 1L),
    n1      = quickcheck::integer_bounded(left = 5L, right = 200L, len = 1L),
    n2      = quickcheck::integer_bounded(left = 5L, right = 200L, len = 1L),
    property = function(T1, T2, frac_C1, frac_C2, frac_m1, frac_m2, n1, n2) {
      C1 <- frac_C1 * T1; C2 <- frac_C2 * T2
      m1 <- as.integer(floor(frac_m1 * n1))
      m2 <- as.integer(floor(frac_m2 * n2))
      strata_df <- data.frame(
        stratum  = c("a", "b"),
        T_h      = c(T1, T2),
        C_h      = c(C1, C2),
        se_C_h   = c(C1 * 0.1, C2 * 0.1),
        n_h      = c(n1, n2),
        m_h      = c(m1, m2)
      )
      res          <- estimate_exploitation_rate(strata = strata_df, by = "stratum")
      ests         <- res$estimates
      stratum_ests <- ests[ests$stratum != ".overall", ]
      overall      <- ests[ests$stratum == ".overall", ]
      expected_agg <- sum(stratum_ests$T * stratum_ests$estimate) /
        sum(stratum_ests$T)
      expect_equal(overall$estimate, expected_agg, tolerance = 1e-10)
    }
  )
})

test_that("INV-03: ice and degenerate bus-route yield identical total catch estimates", {
  skip_if_not_installed("quickcheck")

  ice_fixed <- build_ice_design(n_days = 6L, n_interviews = 10L, seed = 42L)
  br_fixed <- build_br_degenerate_design(n_days = 6L, n_interviews = 10L, seed = 42L)

  ice_catch_fixed <- suppressWarnings(estimate_total_catch(ice_fixed))
  br_catch_fixed <- suppressWarnings(estimate_total_catch(br_fixed))

  expect_equal(
    ice_catch_fixed$estimates$estimate,
    br_catch_fixed$estimates$estimate,
    tolerance = 1e-6
  )

  quickcheck::for_all(
    params = gen_ice_equivalent_design_params(),
    property = function(params) {
      ice_design <- build_ice_design(
        n_days = params$n_days,
        n_interviews = params$n_interviews,
        seed = params$seed
      )
      br_design <- build_br_degenerate_design(
        n_days = params$n_days,
        n_interviews = params$n_interviews,
        seed = params$seed
      )

      ice_catch <- suppressWarnings(estimate_total_catch(ice_design))
      br_catch <- suppressWarnings(estimate_total_catch(br_design))

      expect_equal(
        ice_catch$estimates$estimate,
        br_catch$estimates$estimate,
        tolerance = 1e-6
      )
    }
  )
})
