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

test_that("contract: every design's tidy() carries an `estimate` column (#199)", {
  # tidy() is the documented accessor, and its contract is a uniform shape
  # across designs -- that is what lets a report, a book chapter or a rollup
  # loop over survey types. Ice renamed `estimate` to carry its effort type,
  # so generic code reading tidy(x)$estimate got NULL, and sum(NULL) is 0: a
  # season total came back as zero rather than as an error. The same shape as
  # the v5.0.0 book-render defect.
  #
  # A design-specific name is welcome as an *additional* column. It may not
  # replace the one every other design returns.
  skip_if_not_installed("lme4")
  designs <- list(
    instantaneous = local({
      cal <- build_property_calendar(8L)
      d <- creel_design(cal, date = date, strata = day_type)
      cnt <- data.frame(
        date = sort(unique(cal$date))[1:4],
        day_type = "weekday",
        anglers = c(10, 20, 30, 40),
        stringsAsFactors = FALSE
      )
      suppressWarnings(suppressMessages(
        add_counts(d, cnt, count_col = anglers, psu = "date")
      ))
    }),
    bus_route = build_br_design_for_tests(4L, 8L, 40L, seed = 11L),
    ice = build_ice_design(8L, 40L, seed = 5L),
    br_degenerate = build_br_degenerate_design(8L, 40L, seed = 7L)
  )

  for (nm in names(designs)) {
    out <- tidy(suppressWarnings(estimate_effort(designs[[nm]])))
    expect_true("estimate" %in% names(out), info = nm)
    expect_true(is.numeric(out$estimate), info = nm)
    expect_true(all(c("se", "ci_lower", "ci_upper", "n") %in% names(out)), info = nm)
  }
})

test_that("contract: the ice effort-type column is an alias, not a replacement (#199)", {
  # Both names, agreeing. The descriptive name is worth keeping -- it records
  # which effort type was estimated -- but not at the cost of the shared one.
  ice <- build_ice_design(8L, 40L, seed = 5L)
  out <- tidy(suppressWarnings(estimate_effort(ice)))

  expect_true(all(c("estimate", "total_effort_hr_on_ice") %in% names(out)))
  expect_equal(out$estimate, out$total_effort_hr_on_ice)

  # And the read that used to return NULL now returns the total.
  expect_equal(sum(out$estimate), out$estimate)
  expect_gt(sum(out$estimate), 0)
})
