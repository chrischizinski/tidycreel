# Party-size expansion at the sections seam, effort path (GH #230)
#
# estimate_effort_sections() called new_creel_estimates() without se_expansion,
# so a sectioned effort estimate reported NULL for a component its section rows
# demonstrably carried -- GH #134/#145 one estimator over.
#
# The arithmetic half was worse than the issue described. The lake row's `se`
# came from aggregate_section_totals() plus the within-day component (GH #228),
# neither of which knows about a multiplier estimated outside the design, so the
# lake-wide standard error did not depend on party_size_se at all while both
# section rows did.
#
# The fixture is the rotating two-section design from test-expansion-sections.R:
# each day is sampled in exactly one section, and sections cross-cut strata, so
# a structure classified against the strata would be the wrong one.

eff_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    stringsAsFactors = FALSE
  )
}

eff_raw <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    section = rep(c("North", "South"), 4),
    angler_boats = c(6, 4, 2, 3, 4, 5, 8, 6),
    stringsAsFactors = FALSE
  )
}

eff_design <- function(counts) {
  design <- creel_design(eff_calendar(), date = date, strata = day_type)
  design <- add_sections(
    design,
    data.frame(section = c("North", "South"), stringsAsFactors = FALSE),
    section_col = section
  )
  suppressWarnings(add_counts(design, counts, count_col = "angler_count"))
}

# One estimate used in both sections: its error is a single random quantity
# common to them, so the contributions are perfectly correlated.
eff_shared_counts <- function() {
  derive_angler_count(
    eff_raw(),
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
}

# Two estimates of identical value and identical standard error, one per
# section: the errors are independent. Every number the estimator sees is the
# same as above; only the count of estimates differs.
eff_separate_counts <- function() {
  lookup <- data.frame(
    section = c("North", "South"),
    mps = c(2.5, 2.5),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(North = 0.1, South = 0.1)
  derive_angler_count(eff_raw(), boat_count = angler_boats, party_size = lookup)
}

# No party-size estimate at all: the multiplier is a known constant.
eff_plain_counts <- function() {
  plain <- eff_raw()
  plain$angler_count <- plain$angler_boats * 2.5
  plain
}

eff_effort <- function(counts) {
  suppressWarnings(suppressMessages(estimate_effort(eff_design(counts))))
}

eff_lake <- function(result) {
  result$estimates[result$estimates$section == ".lake_total", ]
}

eff_sections <- function(result) {
  result$estimates[result$estimates$section != ".lake_total", ]
}

test_that("the lake total's SE responds to the party-size standard error", {
  # The defect the issue understated. Two designs identical except for whether a
  # party-size SE was supplied. Both section rows moved and the lake row was
  # bit-identical at 14.577380, so the headline number of a sectioned effort
  # survey did not depend on the party-size uncertainty at all.
  with_se <- eff_effort(eff_shared_counts())
  without <- eff_effort(eff_plain_counts())

  expect_equal(eff_lake(with_se)$estimate, eff_lake(without)$estimate)
  expect_gt(eff_lake(with_se)$se, eff_lake(without)$se)

  # And the section rows must still respond, so the test cannot pass by the
  # component having stopped propagating anywhere.
  expect_gt(
    sum(eff_sections(with_se)$se),
    sum(eff_sections(without)$se)
  )
})

test_that("a sections effort total reports the party-size component its SE carries", {
  # se_expansion = NULL is this package's signal for "this component does not
  # apply", and it was indistinguishable from a design where no party-size SE
  # was ever supplied. The reporting half of the same defect.
  result <- eff_effort(eff_shared_counts())

  expect_false(is.null(result$se_expansion))
  expect_length(result$se_expansion, nrow(result$estimates))
})

test_that("a shared multiplier combines linearly across sections", {
  # Pins the arithmetic, not the direction. One estimate spanning the sections
  # makes the contributions perfectly correlated, so they add before squaring.
  # Quadrature would give sqrt(2^2 + 1.8^2) = 2.69 instead of 3.8.
  result <- eff_effort(eff_shared_counts())
  components <- result$se_expansion
  sec_components <- components[result$estimates$section != ".lake_total"]
  lake_component <- components[result$estimates$section == ".lake_total"]

  # North is sampled on four days carrying 6 + 2 + 4 + 8 = 20 boats, South
  # 4 + 3 + 5 + 6 = 18, and the multiplier's SE is 0.1.
  expect_equal(sec_components, c(2.0, 1.8))
  expect_equal(lake_component, sum(sec_components))
})

test_that("per-section estimates are unchanged by the correlation structure", {
  # Only the aggregation differs between the two designs. Each section's own
  # total is a single estimate whose party-size term combines with nothing, so a
  # difference here means the correction reached rows it had no business
  # touching.
  shared <- eff_effort(eff_shared_counts())
  separate <- eff_effort(eff_separate_counts())

  expect_equal(eff_sections(shared)$se, eff_sections(separate)$se)
  expect_equal(eff_sections(shared)$estimate, eff_sections(separate)$estimate)
})

test_that("a shared multiplier gives a larger lake SE than per-section ones", {
  # The two designs are identical in every respect except whether one estimate
  # or two produced the party sizes, so any difference in the lake row is
  # entirely the correlation structure. Combining in quadrature regardless would
  # return the same SE for both and understate the shared case.
  shared <- eff_effort(eff_shared_counts())
  separate <- eff_effort(eff_separate_counts())

  expect_equal(eff_lake(shared)$estimate, eff_lake(separate)$estimate)
  expect_gt(eff_lake(shared)$se, eff_lake(separate)$se)

  # The gap is exactly the covariance the shared structure adds: the linear sum
  # replaces the sum of squares, and nothing else changes.
  contrib <- separate$se_expansion[separate$estimates$section != ".lake_total"]
  expect_equal(
    eff_lake(shared)$se^2 - eff_lake(separate)$se^2,
    sum(contrib)^2 - sum(contrib^2),
    tolerance = 1e-8
  )
})

test_that("the independent case combines in quadrature and leaves the base alone", {
  # The nested structure was already right in principle -- there was simply no
  # term to be right about. Asserting the exact value pins that adding the
  # component did not disturb the between-day and within-day base.
  separate <- eff_effort(eff_separate_counts())
  without <- eff_effort(eff_plain_counts())
  lake <- eff_lake(separate)
  contrib <- separate$se_expansion[separate$estimates$section != ".lake_total"]

  # Without this the identity is vacuous when no component propagates at all:
  # `sum(numeric(0)^2)` is 0 and both sides collapse to the base.
  expect_length(contrib, 2L)
  expect_true(all(contrib > 0))

  expect_equal(
    lake$se^2,
    eff_lake(without)$se^2 + sum(contrib^2),
    tolerance = 1e-8
  )
})

test_that("a design without expansion reports no component and keeps its SE", {
  # The complement, and the backward-compatibility guard: no party-size estimate
  # means the component does not apply -- NULL, not a zero, which would be
  # indistinguishable from a term that never propagated. The reported SE must be
  # untouched by this change.
  result <- eff_effort(eff_plain_counts())

  expect_null(result$se_expansion)
  lake <- eff_lake(result)
  expect_equal(lake$se, sqrt(lake$se_between^2 + lake$se_within^2))
})

eff_partial_counts <- function() {
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mps = c(2.5, 2.5),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(weekday = 0.1, weekend = 0.1)
  derive_angler_count(eff_raw(), boat_count = angler_boats, party_size = lookup)
}

test_that("groups straddling the sections resolve exactly from the decomposition", {
  # The third branch, exercised through this call site rather than through the
  # helper's own tests: one party-size estimate per day type, where the sections
  # rotate, so each group spans both sections and neither nesting nor sharing
  # describes the geometry. Quadrature would understate and the linear sum would
  # overstate -- but the per-group decomposition makes the exact combination
  # computable, so it must not fall back to refusing (GH #150).
  #
  # This is a regression test for the call site's own arguments, not for the
  # helper. `exact_expansion_var()` guards on
  # `length(decomposition) != length(rate)`, so passing the scalar 1 as the rate
  # made a resolvable geometry fail the length check and warn -- a refusal that
  # looked like the documented behaviour while being an argument bug.
  expect_silent(
    result <- suppressMessages(suppressWarnings(
      estimate_effort(eff_design(eff_partial_counts()))
    ))
  )

  lake <- eff_lake(result)
  expect_false(is.na(lake$se))

  # Both day-type groups cover 19 boats across the two sections -- North's
  # 6 + 4 weekday and 2 + 8 weekend, South's 4 + 5 and 3 + 6 -- so each group
  # totals 1.9 and the exact term is sqrt(1.9^2 + 1.9^2).
  lake_component <- result$se_expansion[result$estimates$section == ".lake_total"]
  expect_equal(lake_component, sqrt(2 * 1.9^2))

  # Strictly above the quadrature the independent structure would have given,
  # and no greater than the linear sum the shared structure would have given.
  # The upper bound is attained here rather than strict: this fixture is
  # symmetric, so both groups cover the same 19 boats and the general form
  # coincides with the shared one. That is a property of these numbers, not of
  # the estimator, which is why only the lower bound is strict.
  sec_components <- result$se_expansion[result$estimates$section != ".lake_total"]
  expect_gt(lake_component, sqrt(sum(sec_components^2)))
  expect_lte(lake_component, sum(sec_components))
})

test_that("the reported decomposition is the one the component was summed from", {
  # `new_creel_estimates()` states the invariant: one entry per row of
  # `estimates`, NULL exactly when `se_expansion` is. A sections object returned
  # a component with no decomposition behind it, so `se_expansion` was
  # recoverable from nothing and a downstream combination over a wider partition
  # had no group index to work from.
  result <- suppressMessages(suppressWarnings(
    estimate_effort(eff_design(eff_partial_counts()))
  ))

  expect_false(is.null(result$expansion_decomposition))
  expect_length(result$expansion_decomposition, nrow(result$estimates))

  # Squaring and summing any row's decomposition reproduces that row's
  # component, which is what makes the two describe one geometry rather than
  # two. Checked on every row, lake included.
  for (i in seq_len(nrow(result$estimates))) {
    expect_equal(
      sqrt(sum(result$expansion_decomposition[[i]]^2)),
      result$se_expansion[[i]]
    )
  }

  # The lake entry is keyed by party-size group, not by section: it is the
  # groups summed across the sections, which is exactly what a wider
  # combination needs.
  expect_setequal(names(result$expansion_decomposition[[3L]]), c("weekday", "weekend"))
})

test_that("no decomposition means no component, not a zero", {
  # The invariant's other half. A design with no party-size estimate carries
  # neither, and reporting an empty decomposition beside a NULL component would
  # make "does not apply" indistinguishable from "summed to nothing".
  result <- eff_effort(eff_plain_counts())

  expect_null(result$se_expansion)
  expect_null(result$expansion_decomposition)
})

test_that("the component survives aggregate_sections = FALSE", {
  # With no lake row there is nothing to combine, but each section still carries
  # its own component and the vector must stay aligned to the rows that remain.
  result <- suppressWarnings(suppressMessages(
    estimate_effort(eff_design(eff_shared_counts()), aggregate_sections = FALSE)
  ))

  expect_false(any(result$estimates$section == ".lake_total"))
  expect_length(result$se_expansion, nrow(result$estimates))
  expect_equal(result$se_expansion, c(2.0, 1.8))
})
