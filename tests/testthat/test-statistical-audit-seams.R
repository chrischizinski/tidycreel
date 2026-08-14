# Statistical-audit seed tests. These demonstrate the three test patterns the
# audit framework relies on (metamorphic invariants, independent reference
# calculations, known-vs-unknown distinctions) — they are exemplars for future
# audit tests, not a complete audit. See README-statistical-audit.md.

test_that("metamorphic: estimates are invariant to interview row order", {
  # A design-based estimate is a function of the data, not of row position.
  # Sensitivity to row order would mean some quantity (a weight, a stratum,
  # a first-row unit guess) is being picked up positionally — the bug class
  # behind prior finding #105 (add_counts selected its column positionally).
  design <- build_br_design_for_tests(3L, 6L, 12L, seed = 42L)

  baseline_effort <- suppressWarnings(estimate_effort(design))
  baseline_catch <- suppressWarnings(estimate_total_catch(design))

  shuffled <- design
  shuffled$interviews <- sa_shuffle_rows(shuffled$interviews, seed = 7L)

  sa_expect_same_estimates(baseline_effort, suppressWarnings(estimate_effort(shuffled)))
  sa_expect_same_estimates(baseline_catch, suppressWarnings(estimate_total_catch(shuffled)))
})

test_that("metamorphic: estimates are invariant to an irrelevant column", {
  # Adding a column no estimator consumes must change nothing. A violation
  # means column selection somewhere is positional or greedy rather than
  # by name — the same seam class as finding #105.
  design <- build_br_design_for_tests(3L, 6L, 12L, seed = 42L)

  baseline_effort <- suppressWarnings(estimate_effort(design))
  baseline_catch <- suppressWarnings(estimate_total_catch(design))

  decorated <- design
  decorated$interviews$irrelevant_note <- seq_len(nrow(decorated$interviews))

  sa_expect_same_estimates(baseline_effort, suppressWarnings(estimate_effort(decorated)))
  sa_expect_same_estimates(baseline_catch, suppressWarnings(estimate_total_catch(decorated)))
})

test_that("reference calculation: mean_party_size matches base-R arithmetic", {
  # Method 2 of the audit protocol: the statistical definition computed in
  # plain base R, sharing no tidycreel helper with the implementation. The
  # estimand is the mean party size among boat parties; its SE is sd/sqrt(n)
  # because parties are treated as an iid sample of the party-size
  # distribution.
  interviews <- tibble::tibble(
    n_anglers = c(2, 3, 4, 9, 9),
    angler_type = c("boat", "boat", "boat", "bank", "bank")
  )

  out <- mean_party_size(interviews, n_anglers, angler_type = angler_type)

  boat_sizes <- c(2, 3, 4)
  expect_equal(as.numeric(out), sum(boat_sizes) / 3)
  expect_equal(attr(out, "se"), stats::sd(boat_sizes) / sqrt(3))
})

test_that("distinction: a single-party party size has unknown SE, not zero SE", {
  # 0 and NA are different statements. One interviewed party yields a mean
  # with no measurable spread: the SE is unknown (NA), not zero. A zero here
  # would enter the effort variance as "multiplier known exactly", which is
  # indistinguishable from the uncertainty never having been propagated —
  # the exact defect class fixed in #121.
  interviews <- tibble::tibble(
    n_anglers = c(3, 5),
    angler_type = c("boat", "bank")
  )

  out <- mean_party_size(interviews, n_anglers, angler_type = angler_type)

  expect_equal(as.numeric(out), 3)
  expect_identical(attr(out, "se"), NA_real_)
})
