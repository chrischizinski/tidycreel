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
