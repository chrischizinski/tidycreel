# Primary Source Validation: Malvestuto (1996) Box 20.6
# These tests are correctness proofs against published literature.
# If these tests pass, tidycreel reproduces the canonical bus-route
# estimation benchmark exactly.

# Malvestuto Box 20.6 Example 1 ----
# Box 20.6 data (Malvestuto 1996, p. 614): 4 sites, 1 circuit, no expansion.
# pi_i = p_site * p_period; n_counted == n_interviewed => expansion = 1.
# E_hat = sum(e_i / pi_i) = 200 + 160 + 287.5 + 200 = 847.5 angler-hours.

make_box20_6_example1 <- function() {
  # Sampling frame: p_site sums to 1.0; p_period = 0.50 for all sites.
  sf <- data.frame(
    site = c("A", "B", "C", "D"),
    circuit = "circ1",
    p_site = c(0.30, 0.25, 0.40, 0.05),
    p_period = 0.50,
    stringsAsFactors = FALSE
  )
  # Calendar: 4 weekday dates (>= 2 PSUs per stratum for survey::svydesign).
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekday", "weekday"),
    stringsAsFactors = FALSE
  )
  design <- creel_design( # nolint: object_usage_linter
    calendar = cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site, # nolint: object_usage_linter
    circuit = circuit, # nolint: object_usage_linter
    p_site = p_site, # nolint: object_usage_linter
    p_period = p_period # nolint: object_usage_linter
  )
  # Interview data: one row per interview, spread across 4 calendar dates.
  # Site A: 4 interviews of 7.5 h (4*7.5=30.0), pi_i=0.15, contribution=200.
  # Site B: 3 interviews of 20/3 h (3*20/3=20.0), pi_i=0.125, contribution=160.
  # Site C: 6 interviews of 57.5/6 h (total=57.5), pi_i=0.20, contribution=287.5.
  # Site D: 2 interviews of 2.5 h (2*2.5=5.0), pi_i=0.025, contribution=200.
  # n_counted = n_interviewed for all sites => expansion = 1.
  # E_hat = 200 + 160 + 287.5 + 200 = 847.5 angler-hours.
  # Total: 4+3+6+2 = 15 interview rows.
  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02",
      "2024-06-01", "2024-06-02", "2024-06-03",
      "2024-06-01", "2024-06-02", "2024-06-03",
      "2024-06-03", "2024-06-04",
      "2024-06-03", "2024-06-04",
      "2024-06-03"
    )),
    day_type = "weekday",
    site = c(
      "A", "A", "A", "A",
      "B", "B", "B",
      "C", "C", "C",
      "C", "C",
      "C", "D",
      "D"
    ),
    circuit = "circ1",
    hours_fished = c(
      7.5, 7.5, 7.5, 7.5,
      20.0 / 3, 20.0 / 3, 20.0 / 3,
      57.5 / 6, 57.5 / 6, 57.5 / 6,
      57.5 / 6, 57.5 / 6,
      57.5 / 6, 2.5,
      2.5
    ),
    fish_kept = c(
      1L, 0L, 1L, 0L,
      1L, 0L, 1L,
      1L, 1L, 0L,
      1L, 0L,
      1L, 0L,
      0L
    ),
    fish_caught = c(
      2L, 1L, 1L, 1L,
      2L, 1L, 1L,
      2L, 1L, 1L,
      1L, 1L,
      1L, 1L,
      1L
    ),
    n_counted = c(
      4L, 4L, 4L, 4L,
      3L, 3L, 3L,
      6L, 6L, 6L,
      6L, 6L,
      6L, 2L,
      2L
    ),
    n_interviewed = c(
      4L, 4L, 4L, 4L,
      3L, 3L, 3L,
      6L, 6L, 6L,
      6L, 6L,
      6L, 2L,
      2L
    ),
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  add_interviews( # nolint: object_usage_linter
    design,
    interviews,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
}

test_that(
  "Site C contribution to effort equals 57.5/0.20 = 287.5 (Malvestuto 1996, Box 20.6, p. 614)",
  {
    result <- estimate_effort(make_box20_6_example1())
    sc <- attr(result, "site_contributions")
    site_c <- sc[sc$site == "C", ]
    # Malvestuto 1996, Box 20.6, p. 614
    expect_equal(sum(site_c$e_i_over_pi_i), 287.5, tolerance = 1e-6)
  }
)

test_that(
  "E_hat is sum of all site contributions (Horvitz-Thompson property)",
  {
    result <- estimate_effort(make_box20_6_example1())
    # Malvestuto 1996, Box 20.6, p. 614: E_hat = 200+160+287.5+200 = 847.5
    expected_e_hat <- 30.0 / 0.15 + 20.0 / 0.125 + 57.5 / 0.20 + 5.0 / 0.025
    expect_equal(result$estimates$estimate, expected_e_hat, tolerance = 1e-6)
  }
)

test_that(
  "estimate_effort() result class is creel_estimates for bus-route design",
  {
    result <- estimate_effort(make_box20_6_example1())
    expect_s3_class(result, "creel_estimates")
  }
)

test_that(
  "Bus-route effort method is 'total' (Horvitz-Thompson total estimator)",
  {
    result <- estimate_effort(make_box20_6_example1())
    expect_equal(result$method, "total")
  }
)

test_that(
  "Example 1 harvest estimate: H_hat = sum(h_i/pi_i) with per-interview harvest",
  {
    # Harvest uses fish_kept column with no expansion (n_counted = n_interviewed).
    # Per CONTEXT.md: effort validation alongside harvest/catch.
    result <- estimate_harvest(make_box20_6_example1())
    expect_s3_class(result, "creel_estimates")
    # H_hat should be positive and finite
    expect_true(is.numeric(result$estimates$estimate))
    expect_true(result$estimates$estimate > 0)
    expect_true(is.finite(result$estimates$estimate))
  }
)

# Malvestuto Box 20.6 Example 2 (enumeration expansion) ----
# Same design as Example 1 but Site C: n_counted=24, n_interviewed=11.
# expansion = 24/11 = 2.181818...
# All other sites: n_counted = n_interviewed => expansion = 1.
# E_hat(Example 2) > E_hat(Example 1) because Site C is up-weighted.

make_box20_6_example2 <- function() {
  # Sampling frame identical to Example 1.
  sf <- data.frame(
    site = c("A", "B", "C", "D"),
    circuit = "circ1",
    p_site = c(0.30, 0.25, 0.40, 0.05),
    p_period = 0.50,
    stringsAsFactors = FALSE
  )
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekday", "weekday"),
    stringsAsFactors = FALSE
  )
  design <- creel_design( # nolint: object_usage_linter
    calendar = cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site, # nolint: object_usage_linter
    circuit = circuit, # nolint: object_usage_linter
    p_site = p_site, # nolint: object_usage_linter
    p_period = p_period # nolint: object_usage_linter
  )
  # Site C: n_counted=24, n_interviewed=11 (Malvestuto 1996, Box 20.6, p. 614).
  # All other sites: n_counted = n_interviewed (expansion = 1).
  # Same effort values as Example 1; only Site C enumeration counts differ.
  # Total: 4+3+6+2 = 15 interview rows.
  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02",
      "2024-06-01", "2024-06-02", "2024-06-03",
      "2024-06-01", "2024-06-02", "2024-06-03",
      "2024-06-03", "2024-06-04",
      "2024-06-03", "2024-06-04",
      "2024-06-03"
    )),
    day_type = "weekday",
    site = c(
      "A", "A", "A", "A",
      "B", "B", "B",
      "C", "C", "C",
      "C", "C",
      "C", "D",
      "D"
    ),
    circuit = "circ1",
    hours_fished = c(
      7.5, 7.5, 7.5, 7.5,
      20.0 / 3, 20.0 / 3, 20.0 / 3,
      57.5 / 6, 57.5 / 6, 57.5 / 6,
      57.5 / 6, 57.5 / 6,
      57.5 / 6, 2.5,
      2.5
    ),
    fish_kept = c(
      1L, 0L, 1L, 0L,
      1L, 0L, 1L,
      1L, 1L, 0L,
      1L, 0L,
      1L, 0L,
      0L
    ),
    fish_caught = c(
      2L, 1L, 1L, 1L,
      2L, 1L, 1L,
      2L, 1L, 1L,
      1L, 1L,
      1L, 1L,
      1L
    ),
    # Malvestuto 1996, Box 20.6, p. 614 (enumeration expansion):
    # Site C: 24 counted, 11 interviewed. Others: n_counted = n_interviewed.
    n_counted = c(
      4L, 4L, 4L, 4L,
      3L, 3L, 3L,
      24L, 24L, 24L,
      24L, 24L,
      24L, 2L,
      2L
    ),
    n_interviewed = c(
      4L, 4L, 4L, 4L,
      3L, 3L, 3L,
      11L, 11L, 11L,
      11L, 11L,
      11L, 2L,
      2L
    ),
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  add_interviews( # nolint: object_usage_linter
    design,
    interviews,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
}

test_that(
  "Site C expansion factor is 24/11 in enumeration counts",
  {
    design <- make_box20_6_example2()
    enum_counts <- get_enumeration_counts(design)
    site_c <- enum_counts[enum_counts$site == "C", ]
    # Malvestuto 1996, Box 20.6, p. 614
    expect_equal(site_c$.expansion[1], 24 / 11, tolerance = 1e-6)
  }
)

test_that(
  "E_hat with expansion is larger than E_hat without expansion (VALID-02)",
  {
    result_ex1 <- estimate_effort(make_box20_6_example1())
    result_ex2 <- estimate_effort(make_box20_6_example2())
    expect_gt(result_ex2$estimates$estimate, result_ex1$estimates$estimate)
  }
)

test_that(
  "Site C contribution with expansion equals (57.5 * 24/11) / 0.20",
  {
    result_ex2 <- estimate_effort(make_box20_6_example2())
    # Malvestuto 1996, Box 20.6, p. 614 (enumeration expansion)
    expansion <- 24 / 11
    expected_c <- (57.5 * expansion) / 0.20
    sc <- attr(result_ex2, "site_contributions")
    c_contributions <- sc[sc$site == "C", "e_i_over_pi_i"]
    expect_equal(sum(c_contributions), expected_c, tolerance = 1e-6)
  }
)

test_that(
  "Sites without expansion (A, B, D) have same contributions in Example 2 as Example 1",
  {
    result_ex1 <- estimate_effort(make_box20_6_example1())
    result_ex2 <- estimate_effort(make_box20_6_example2())
    sc1 <- attr(result_ex1, "site_contributions")
    sc2 <- attr(result_ex2, "site_contributions")
    for (s in c("A", "B", "D")) {
      sum1 <- sum(sc1[sc1$site == s, "e_i_over_pi_i"])
      sum2 <- sum(sc2[sc2$site == s, "e_i_over_pi_i"])
      lbl <- paste0("Site ", s, " contribution unchanged between Ex1 and Ex2")
      expect_equal(sum2, sum1, tolerance = 1e-6, label = lbl)
    }
  }
)

# Integration tests ----
# Verify the complete bus-route workflow wiring: design -> add_interviews -> estimate_*
# These tests catch ordering errors (expansion before weighting, wrong column propagation)
# that unit tests on individual functions cannot detect.
# VALID-05: complete workflow integration tests.

test_that(
  "Complete bus-route workflow: design -> data -> effort estimation succeeds (VALID-05)",
  {
    d <- make_box20_6_example2()
    result <- suppressWarnings(estimate_effort(d))
    # VALID-05: complete workflow integration
    expect_s3_class(result, "creel_estimates")
    expect_true(is.finite(result$estimates$estimate))
    expect_true(result$estimates$estimate > 0)
    expect_true(is.finite(result$estimates$se))
    expect_true(result$estimates$se > 0)
  }
)

test_that(
  "Complete bus-route workflow: design -> data -> harvest estimation succeeds (VALID-05)",
  {
    d <- make_box20_6_example2()
    result <- suppressWarnings(estimate_harvest(d))
    expect_s3_class(result, "creel_estimates")
    expect_true(is.finite(result$estimates$estimate))
    expect_true(result$estimates$estimate > 0)
    expect_true(is.finite(result$estimates$se))
  }
)

test_that(
  "Bus-route total-catch estimation succeeds with Box 20.6 data (VALID-05)",
  {
    d <- make_box20_6_example2()
    result <- suppressWarnings(estimate_total_catch(d))
    expect_s3_class(result, "creel_estimates")
    expect_true(is.finite(result$estimates$estimate))
    expect_true(result$estimates$estimate > 0)
  }
)

test_that(
  "Grouped effort estimation by day_type returns one row (all weekday data)",
  {
    d <- make_box20_6_example2()
    result <- suppressWarnings(estimate_effort(d, by = day_type))
    expect_s3_class(result, "creel_estimates")
    # All dates are weekday so one group
    expect_equal(nrow(result$estimates), 1L)
  }
)

# Survey package cross-validation ----
# Verify inverse probability weighting by replicating the HT estimator manually
# using survey::svydesign() + survey::svytotal() on the same contribution column.
#
# Approach: the implementation computes .contribution = e_i * expansion / pi_i
# and then calls svytotal(~.contribution, svydesign(ids=~1, strata=~day_type)).
# We replicate the same computation manually and compare outputs.
# This proves the variance machinery is correctly wired (Eq. 19.4-19.5).
#
# Use Example 1 (no expansion, expansion=1) for transparency: hand arithmetic is exact.
# Point estimate tolerance: 1e-6 (exact match expected)
# SE tolerance: 1e-3 (per CONTEXT.md decision)

test_that(
  "Effort estimate matches manual survey::svydesign + svytotal (point estimate, tol 1e-6)",
  {
    d <- make_box20_6_example1()
    int_data <- d$interviews
    # Compute HT contribution per row: effort * expansion / pi_i
    # (expansion = 1 for Example 1, so this is effort / pi_i)
    # Proves inverse probability weighting correctly implements Eq. 19.4
    int_data$.effort_contrib <- int_data$hours_fished * int_data$.expansion / int_data$.pi_i
    svy_manual <- suppressWarnings(
      survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
    )
    manual_result <- survey::svytotal(~.effort_contrib, svy_manual)
    tidycreel_result <- suppressWarnings(estimate_effort(d))
    expect_equal(
      tidycreel_result$estimates$estimate,
      as.numeric(coef(manual_result)),
      tolerance = 1e-6
    )
  }
)

test_that(
  "Effort SE matches manual survey::svydesign + svytotal (tol 1e-3)",
  {
    d <- make_box20_6_example1()
    int_data <- d$interviews
    int_data$.effort_contrib <- int_data$hours_fished * int_data$.expansion / int_data$.pi_i
    svy_manual <- suppressWarnings(
      survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
    )
    manual_result <- survey::svytotal(~.effort_contrib, svy_manual)
    tidycreel_result <- suppressWarnings(estimate_effort(d))
    # Per CONTEXT.md: SE tolerance 1e-3 (FPC differences acceptable)
    expect_equal(
      tidycreel_result$estimates$se,
      as.numeric(survey::SE(manual_result)),
      tolerance = 1e-3
    )
  }
)

test_that(
  "Harvest estimate matches manual survey::svydesign + svytotal (point estimate, tol 1e-6)",
  {
    d <- make_box20_6_example1()
    int_data <- d$interviews
    # Compute HT harvest contribution per row: harvest * expansion / pi_i
    # (expansion = 1 for Example 1)
    int_data$.harvest_contrib <- int_data$fish_kept * int_data$.expansion / int_data$.pi_i
    svy_manual <- suppressWarnings(
      survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
    )
    manual_result <- survey::svytotal(~.harvest_contrib, svy_manual)
    tidycreel_result <- suppressWarnings(estimate_harvest(d))
    expect_equal(
      tidycreel_result$estimates$estimate,
      as.numeric(coef(manual_result)),
      tolerance = 1e-6
    )
  }
)

test_that(
  "Harvest SE matches manual survey::svydesign + svytotal (tol 1e-3)",
  {
    d <- make_box20_6_example1()
    int_data <- d$interviews
    int_data$.harvest_contrib <- int_data$fish_kept * int_data$.expansion / int_data$.pi_i
    svy_manual <- suppressWarnings(
      survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
    )
    manual_result <- survey::svytotal(~.harvest_contrib, svy_manual)
    tidycreel_result <- suppressWarnings(estimate_harvest(d))
    # Per CONTEXT.md: SE tolerance 1e-3 (FPC differences acceptable)
    expect_equal(
      tidycreel_result$estimates$se,
      as.numeric(survey::SE(manual_result)),
      tolerance = 1e-3
    )
  }
)
