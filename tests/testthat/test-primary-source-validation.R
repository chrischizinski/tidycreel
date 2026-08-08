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
  design <- creel_design(
    # nolint: object_usage_linter
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
      "2024-06-01",
      "2024-06-01",
      "2024-06-02",
      "2024-06-02",
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-03",
      "2024-06-04",
      "2024-06-03",
      "2024-06-04",
      "2024-06-03"
    )),
    day_type = "weekday",
    site = c(
      "A",
      "A",
      "A",
      "A",
      "B",
      "B",
      "B",
      "C",
      "C",
      "C",
      "C",
      "C",
      "C",
      "D",
      "D"
    ),
    circuit = "circ1",
    hours_fished = c(
      7.5,
      7.5,
      7.5,
      7.5,
      20.0 / 3,
      20.0 / 3,
      20.0 / 3,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      2.5,
      2.5
    ),
    fish_kept = c(
      1L,
      0L,
      1L,
      0L,
      1L,
      0L,
      1L,
      1L,
      1L,
      0L,
      1L,
      0L,
      1L,
      0L,
      0L
    ),
    fish_caught = c(
      2L,
      1L,
      1L,
      1L,
      2L,
      1L,
      1L,
      2L,
      1L,
      1L,
      1L,
      1L,
      1L,
      1L,
      1L
    ),
    n_counted = c(
      4L,
      4L,
      4L,
      4L,
      3L,
      3L,
      3L,
      6L,
      6L,
      6L,
      6L,
      6L,
      6L,
      2L,
      2L
    ),
    n_interviewed = c(
      4L,
      4L,
      4L,
      4L,
      3L,
      3L,
      3L,
      6L,
      6L,
      6L,
      6L,
      6L,
      6L,
      2L,
      2L
    ),
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  add_interviews(
    # nolint: object_usage_linter
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

test_that("Site C contribution to effort equals 57.5/0.20 = 287.5 (Malvestuto 1996, Box 20.6, p. 614)", {
  result <- estimate_effort(make_box20_6_example1())
  sc <- attr(result, "site_contributions")
  site_c <- sc[sc$site == "C", ]
  # Malvestuto 1996, Box 20.6, p. 614
  expect_equal(sum(site_c$e_i_over_pi_i), 287.5, tolerance = 1e-6)
})

test_that("E_hat is sum of all site contributions (Horvitz-Thompson property)", {
  result <- estimate_effort(make_box20_6_example1())
  # Malvestuto 1996, Box 20.6, p. 614: E_hat = 200+160+287.5+200 = 847.5
  expected_e_hat <- 30.0 / 0.15 + 20.0 / 0.125 + 57.5 / 0.20 + 5.0 / 0.025
  expect_equal(result$estimates$estimate, expected_e_hat, tolerance = 1e-6)
})

test_that("estimate_effort() result class is creel_estimates for bus-route design", {
  result <- estimate_effort(make_box20_6_example1())
  expect_s3_class(result, "creel_estimates")
})

test_that("Bus-route effort method is 'total' (Horvitz-Thompson total estimator)", {
  result <- estimate_effort(make_box20_6_example1())
  expect_equal(result$method, "total")
})

test_that("Example 1 harvest estimate: H_hat = sum(h_i/pi_i) with per-interview harvest", {
  # Harvest uses fish_kept column with no expansion (n_counted = n_interviewed).
  # Per CONTEXT.md: effort validation alongside harvest/catch.
  result <- estimate_harvest_rate(make_box20_6_example1())
  expect_s3_class(result, "creel_estimates")
  # H_hat should be positive and finite
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
})

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
  design <- creel_design(
    # nolint: object_usage_linter
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
      "2024-06-01",
      "2024-06-01",
      "2024-06-02",
      "2024-06-02",
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-03",
      "2024-06-04",
      "2024-06-03",
      "2024-06-04",
      "2024-06-03"
    )),
    day_type = "weekday",
    site = c(
      "A",
      "A",
      "A",
      "A",
      "B",
      "B",
      "B",
      "C",
      "C",
      "C",
      "C",
      "C",
      "C",
      "D",
      "D"
    ),
    circuit = "circ1",
    hours_fished = c(
      7.5,
      7.5,
      7.5,
      7.5,
      20.0 / 3,
      20.0 / 3,
      20.0 / 3,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      57.5 / 6,
      2.5,
      2.5
    ),
    fish_kept = c(
      1L,
      0L,
      1L,
      0L,
      1L,
      0L,
      1L,
      1L,
      1L,
      0L,
      1L,
      0L,
      1L,
      0L,
      0L
    ),
    fish_caught = c(
      2L,
      1L,
      1L,
      1L,
      2L,
      1L,
      1L,
      2L,
      1L,
      1L,
      1L,
      1L,
      1L,
      1L,
      1L
    ),
    # Malvestuto 1996, Box 20.6, p. 614 (enumeration expansion):
    # Site C: 24 counted, 11 interviewed. Others: n_counted = n_interviewed.
    n_counted = c(
      4L,
      4L,
      4L,
      4L,
      3L,
      3L,
      3L,
      24L,
      24L,
      24L,
      24L,
      24L,
      24L,
      2L,
      2L
    ),
    n_interviewed = c(
      4L,
      4L,
      4L,
      4L,
      3L,
      3L,
      3L,
      11L,
      11L,
      11L,
      11L,
      11L,
      11L,
      2L,
      2L
    ),
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  add_interviews(
    # nolint: object_usage_linter
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

test_that("Site C expansion factor is 24/11 in enumeration counts", {
  design <- make_box20_6_example2()
  enum_counts <- get_enumeration_counts(design)
  site_c <- enum_counts[enum_counts$site == "C", ]
  # Malvestuto 1996, Box 20.6, p. 614
  expect_equal(site_c$.expansion[1], 24 / 11, tolerance = 1e-6)
})

test_that("E_hat with expansion is larger than E_hat without expansion (VALID-02)", {
  result_ex1 <- estimate_effort(make_box20_6_example1())
  result_ex2 <- estimate_effort(make_box20_6_example2())
  expect_gt(result_ex2$estimates$estimate, result_ex1$estimates$estimate)
})

test_that("Site C contribution with expansion equals (57.5 * 24/11) / 0.20", {
  result_ex2 <- estimate_effort(make_box20_6_example2())
  # Malvestuto 1996, Box 20.6, p. 614 (enumeration expansion)
  expansion <- 24 / 11
  expected_c <- (57.5 * expansion) / 0.20
  sc <- attr(result_ex2, "site_contributions")
  c_contributions <- sc[sc$site == "C", "e_i_over_pi_i"]
  expect_equal(sum(c_contributions), expected_c, tolerance = 1e-6)
})

test_that("Sites without expansion (A, B, D) have same contributions in Example 2 as Example 1", {
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
})

# Integration tests ----
# Verify the complete bus-route workflow wiring: design -> add_interviews -> estimate_*
# These tests catch ordering errors (expansion before weighting, wrong column propagation)
# that unit tests on individual functions cannot detect.
# VALID-05: complete workflow integration tests.

test_that("Complete bus-route workflow: design -> data -> effort estimation succeeds (VALID-05)", {
  d <- make_box20_6_example2()
  result <- suppressWarnings(estimate_effort(d))
  # VALID-05: complete workflow integration
  expect_s3_class(result, "creel_estimates")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("Complete bus-route workflow: design -> data -> harvest estimation succeeds (VALID-05)", {
  d <- make_box20_6_example2()
  result <- suppressWarnings(estimate_harvest_rate(d))
  expect_s3_class(result, "creel_estimates")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
})

test_that("Bus-route total-catch estimation succeeds with Box 20.6 data (VALID-05)", {
  d <- make_box20_6_example2()
  result <- suppressWarnings(estimate_total_catch(d))
  expect_s3_class(result, "creel_estimates")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

test_that("Grouped effort estimation by day_type returns one row (all weekday data)", {
  d <- make_box20_6_example2()
  result <- suppressWarnings(estimate_effort(d, by = day_type))
  expect_s3_class(result, "creel_estimates")
  # All dates are weekday so one group
  expect_equal(nrow(result$estimates), 1L)
})

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

test_that("Effort estimate matches manual survey::svydesign + svytotal (point estimate, tol 1e-6)", {
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
})

test_that("Effort SE matches manual survey::svydesign + svytotal (tol 1e-3)", {
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
})

test_that("Harvest estimate matches manual survey::svydesign + svytotal (point estimate, tol 1e-6)", {
  d <- make_box20_6_example1()
  int_data <- d$interviews
  # Compute HT harvest contribution per row: harvest * expansion / pi_i
  # (expansion = 1 for Example 1)
  int_data$.harvest_contrib <- int_data$fish_kept * int_data$.expansion / int_data$.pi_i
  svy_manual <- suppressWarnings(
    survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
  )
  manual_result <- survey::svytotal(~.harvest_contrib, svy_manual)
  # A manual svytotal is a total, so it validates the total estimator. This
  # comparison used to be made against estimate_harvest_rate(), which is how a
  # total came to be reported as a rate (GH #107).
  tidycreel_result <- suppressWarnings(estimate_total_harvest(d))
  expect_equal(
    tidycreel_result$estimates$estimate,
    as.numeric(coef(manual_result)),
    tolerance = 1e-6
  )
})

test_that("Harvest SE matches manual survey::svydesign + svytotal (tol 1e-3)", {
  d <- make_box20_6_example1()
  int_data <- d$interviews
  int_data$.harvest_contrib <- int_data$fish_kept * int_data$.expansion / int_data$.pi_i
  svy_manual <- suppressWarnings(
    survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
  )
  manual_result <- survey::svytotal(~.harvest_contrib, svy_manual)
  tidycreel_result <- suppressWarnings(estimate_total_harvest(d))
  # Per CONTEXT.md: SE tolerance 1e-3 (FPC differences acceptable)
  expect_equal(
    tidycreel_result$estimates$se,
    as.numeric(survey::SE(manual_result)),
    tolerance = 1e-3
  )
})

test_that("Bus-route HPUE matches manual survey::svyratio (point estimate and SE, GH #107)", {
  # The rate needs its own independent check against the survey package, built
  # the same way the effort and harvest totals are checked above.
  d <- make_box20_6_example1()
  int_data <- d$interviews
  int_data$.harvest_contrib <- int_data$fish_kept * int_data$.expansion / int_data$.pi_i
  int_data$.effort_contrib <- int_data[[d$angler_effort_col]] *
    int_data$.expansion / int_data$.pi_i
  svy_manual <- suppressWarnings(
    survey::svydesign(ids = ~1, strata = ~day_type, data = int_data)
  )
  manual_ratio <- suppressWarnings(
    survey::svyratio(~.harvest_contrib, ~.effort_contrib, svy_manual)
  )
  tidycreel_result <- suppressWarnings(estimate_harvest_rate(d))

  expect_equal(
    tidycreel_result$estimates$estimate,
    as.numeric(coef(manual_ratio)),
    tolerance = 1e-6
  )
  expect_equal(
    tidycreel_result$estimates$se,
    as.numeric(survey::SE(manual_ratio)),
    tolerance = 1e-3
  )
})

# AIR-04: Aerial effort — constructed numeric validation example ----
# Malvestuto (1996) Box 20.6 has no aerial worked example (only bus-route).
# A Delaware River Creel Survey 2002 report uses PPS design (pi_ik expansion
# factors), which is not compatible with the simple instantaneous count x h_open
# estimator implemented here.
#
# Alternate strategy: hand-calculable constructed example verified from
# the formula E = svytotal(counts) x h_open (Pollock et al. 1994, Ch. 12).
#
# Design: 5 weekdays + 2 weekend days, ALL counted on every day. h_open = 14 h.
# Weekday counts: 10, 15, 12, 8, 11 (sum = 56).
# Weekend counts: 25, 30 (sum = 55).
#
# Hand calculation (no FPC; all PSUs observed):
#   svytotal = sum(counts) = 56 + 55 = 111 anglers
#   E_hat = 111 x 14 = 1554 angler-hours
#
# Primary source: Pollock et al. (1994) Ch. 12 provides theoretical basis;
# Malvestuto (1996) Box 20.6 has no aerial worked example.

make_aerial_box20_6 <- function() {
  # Calendar: 5 weekdays + 2 weekend days in the study period.
  # All days are surveyed (every calendar date has a count row).
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-07",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c(
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend"
    ),
    stringsAsFactors = FALSE
  )
  # Counts: one observation per calendar day.
  # Weekday sums to 56 anglers; weekend sums to 55. Total = 111.
  # E_hat = 111 x 14 = 1554 angler-hours (exact, no rounding).
  counts <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06",
      "2024-06-07",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c(
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekday",
      "weekend",
      "weekend"
    ),
    n_anglers = c(10L, 15L, 12L, 8L, 11L, 25L, 30L),
    stringsAsFactors = FALSE
  )
  design <- creel_design(
    # nolint: object_usage_linter
    calendar = cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "aerial",
    h_open = 14
  )
  add_counts(
    # nolint: object_usage_linter
    design,
    counts
  )
}

test_that("AIR-04: estimate_effort() matches hand-calculated svytotal x h_open = 111 x 14 = 1554 angler-hours", {
  # nolint: line_length_linter
  # Constructed numeric example verified against hand-calculated formula:
  # svytotal equals sum of all counts (111 anglers) because all calendar
  # days are observed (no partial sampling, no FPC). E_hat = 111 x 14 = 1554.
  # Weekday sum is 56 (10+15+12+8+11); weekend sum is 55 (25+30).
  # Primary source: Pollock et al. (1994) Ch. 12 provides theoretical basis;
  # Malvestuto (1996) Box 20.6 has no aerial worked example.
  fixture <- make_aerial_box20_6()
  result <- suppressWarnings(estimate_effort(fixture))
  # E_hat = 111 x 14 = 1554 angler-hours (exact integer result)
  expect_equal(result$estimates$estimate, 1554, tolerance = 1e-4)
  expect_true(result$estimates$se > 0)
})

# Party size sensitivity (finding 2 / GH #106) ----
#
# Box 20.6 has exactly one angler per party, so party-hours and angler-hours
# coincide and every assertion above passes whether estimate_effort_br() reads
# the raw trip duration or the angler-effort column. That is precisely how a
# party-hours/angler-hours defect survived a suite that validates against a
# published source. These tests hold the published benchmark at party size 1 and
# additionally pin the behaviour the benchmark cannot see.

#' Box 20.6 Example 1 restated compactly, with an explicit party size.
#'
#' Same sites, probabilities, durations, and enumeration counts as
#' `make_box20_6_example1()`; `party_size` anglers per interviewed party.
make_box20_6_party <- function(party_size) {
  sf <- data.frame(
    site = c("A", "B", "C", "D"),
    circuit = "circ1",
    p_site = c(0.30, 0.25, 0.40, 0.05),
    p_period = 0.50,
    stringsAsFactors = FALSE
  )
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
  design <- creel_design(
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
  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02",
      "2024-06-01", "2024-06-02", "2024-06-03",
      "2024-06-01", "2024-06-02", "2024-06-03",
      "2024-06-03", "2024-06-04", "2024-06-03",
      "2024-06-03", "2024-06-04"
    )),
    site = c(rep("A", 4), rep("B", 3), rep("C", 6), rep("D", 2)),
    circuit = "circ1",
    hours_fished = c(
      rep(7.5, 4), rep(20 / 3, 3), rep(57.5 / 6, 6), rep(2.5, 2)
    ),
    n_anglers = as.integer(party_size),
    fish_kept = 1L,
    fish_caught = 2L,
    n_counted = c(rep(4L, 4), rep(3L, 3), rep(6L, 6), rep(2L, 2)),
    n_interviewed = c(rep(4L, 4), rep(3L, 3), rep(6L, 6), rep(2L, 2)),
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  add_interviews(
    design,
    interviews,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_anglers = n_anglers, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
}

test_that("one angler per party still reproduces Box 20.6 exactly (VALID-06)", {
  # The compact restatement must be the same design as the verbose fixture, or
  # the party-size assertions below prove nothing about the published example.
  result <- suppressWarnings(estimate_effort(make_box20_6_party(1L)))
  expect_equal(result$estimates$estimate, 847.5, tolerance = 1e-6)
})

test_that("bus-route effort scales with party size (VALID-06, GH #106)", {
  # Effort is angler-hours. Three anglers fishing the same hours are three times
  # the effort of one. Before #106 the estimate was invariant to party size and
  # understated the total by exactly the mean party size in any boat fishery.
  e1 <- suppressWarnings(estimate_effort(make_box20_6_party(1L)))$estimates
  e3 <- suppressWarnings(estimate_effort(make_box20_6_party(3L)))$estimates

  expect_equal(e3$estimate, 3 * e1$estimate, tolerance = 1e-6)
  expect_equal(e3$estimate, 2542.5, tolerance = 1e-6)

  # State the defect directly: an implementation reading the raw per-party trip
  # duration returns the party-size-1 answer here.
  expect_false(isTRUE(all.equal(e3$estimate, 847.5)))
})

test_that("bus-route effort SE scales with party size (VALID-06, GH #106)", {
  # The SE comes from svytotal on the same contribution column, so it carries the
  # same units as the point estimate. If only the estimate were rescaled, the CV
  # would change and this would fail.
  e1 <- suppressWarnings(estimate_effort(make_box20_6_party(1L)))$estimates
  e3 <- suppressWarnings(estimate_effort(make_box20_6_party(3L)))$estimates

  expect_equal(e3$se, 3 * e1$se, tolerance = 1e-6)
  expect_equal(e3$se / e3$estimate, e1$se / e1$estimate, tolerance = 1e-9)
})

test_that("mixed party sizes give the angler-weighted total, not the party count (GH #106)", {
  # A constant party size cannot distinguish "multiply the total by k" from
  # "weight each interview by its own party size". Mixed sizes can.
  design <- make_box20_6_party(1L)
  varied <- design$interviews
  # Site A parties carry 4 anglers each; everyone else stays at 1.
  varied[[design$n_anglers_col]] <- ifelse(varied$site == "A", 4L, 1L)
  varied[[design$angler_effort_col]] <-
    varied[[design$effort_col]] * varied[[design$n_anglers_col]]
  design$interviews <- varied

  result <- suppressWarnings(estimate_effort(design))
  # Site A contributes 30 h x 4 anglers / 0.15 = 800; the rest are unchanged.
  expect_equal(result$estimates$estimate, 800 + 160 + 287.5 + 200, tolerance = 1e-6)
})
