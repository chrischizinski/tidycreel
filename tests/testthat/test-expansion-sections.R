# Party-size expansion at the sections seam (GH #145)
#
# estimate_total_*_sections() builds its frame by hand instead of routing
# through compute_stratum_product_sum(), so the GH #144 correction never
# reached it: the lake row aggregated the sections in quadrature, which is only
# right when each party-size estimate is confined to one section. It also
# reported se_expansion = NULL while its `se` demonstrably carried the term,
# repeating GH #134 one partition over.
#
# Sections are a different partition from strata and may cross-cut them, so the
# fixtures below are deliberately built with a party-size estimate that is
# nested within sections while spanning strata -- classifying against the
# strata would return a defensible-looking answer for the wrong geometry.

# Rotating sections: each day is sampled in exactly one section, and sections
# cross-cut strata -- each covers two weekdays and two weekend days -- which is
# the property that makes the strata classifier the wrong one to reuse.
#
# This fixture was originally built this way because
# `check_expansion_constant_per_psu()` keyed on the day alone and so refused a
# section-specific estimate on any day sampled in two sections. That was a bug
# in the key, not a property of the statistics, and it is fixed (GH #155): a
# multi-section day can now carry one estimate per section. The fixture stays
# rotating regardless, because its numbers are pinned across #144/#145/#150 and
# re-shaping it would silently re-baseline all three.
sections_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    stringsAsFactors = FALSE
  )
}

sections_raw <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    section = rep(c("North", "South"), 4),
    angler_boats = c(6, 4, 2, 3, 4, 5, 8, 6),
    stringsAsFactors = FALSE
  )
}

sections_interviews <- function() {
  raw <- sections_raw()
  data.frame(
    date = rep(raw$date, each = 4),
    day_type = rep(raw$day_type, each = 4),
    section = rep(raw$section, each = 4),
    catch_total = c(
      3, 4, 2, 5, 6, 4, 2, 3,
      3, 6, 7, 5, 4, 4, 5, 3,
      2, 4, 3, 5, 4, 6, 3, 4,
      5, 3, 4, 2, 3, 5, 6, 4
    ),
    harvest_total = c(
      2, 2, 1, 3, 4, 2, 1, 2,
      2, 4, 5, 3, 2, 3, 3, 2,
      1, 2, 2, 3, 3, 4, 2, 2,
      3, 2, 2, 1, 2, 3, 4, 2
    ),
    hours_fished = 2,
    status = "complete",
    interview_id = seq_len(32),
    stringsAsFactors = FALSE
  )
}

sections_design <- function(counts) {
  design <- creel_design(sections_calendar(), date = date, strata = day_type)
  design <- add_sections(
    design,
    data.frame(section = c("North", "South"), stringsAsFactors = FALSE),
    section_col = section
  )
  design <- suppressWarnings(add_counts(design, counts, count_col = "angler_count"))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    sections_interviews(),
    catch = catch_total,
    effort = hours_fished,
    harvest = harvest_total,
    trip_status = status
  )))
  suppressWarnings(add_catch(
    design,
    sections_catch(),
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  ))
}

sections_catch <- function() {
  iv <- sections_interviews()
  data.frame(
    interview_id = rep(iv$interview_id, 2),
    species = "walleye",
    count = c(iv$harvest_total, iv$catch_total - iv$harvest_total),
    catch_type = rep(c("harvested", "released"), each = nrow(iv)),
    stringsAsFactors = FALSE
  )
}

# One estimate, used in both sections: its error is a single random quantity
# common to them, so the contributions are perfectly correlated.
shared_section_counts <- function() {
  derive_angler_count(
    sections_raw(),
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
}

# Two estimates of identical value and identical standard error, one per
# section: the errors are independent across sections. Every number the
# estimator sees is the same as above; only the count of estimates differs.
# Note this is the case that spans strata while nesting within sections.
separate_section_counts <- function() {
  lookup <- data.frame(
    section = c("North", "South"),
    mps = c(2.5, 2.5),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(North = 0.1, South = 0.1)
  derive_angler_count(sections_raw(), boat_count = angler_boats, party_size = lookup)
}

lake_row <- function(result) {
  result$estimates[result$estimates$section == ".lake_total", ]
}

test_that("a shared multiplier gives a larger lake-total SE than per-section ones (GH #145)", {
  # The two designs are identical in every respect except whether one estimate
  # or two produced the party sizes, so any difference in the lake row is
  # entirely the correlation structure. Quadrature erases it and returns the
  # same standard error for both, understating the shared case.
  shared <- suppressWarnings(estimate_total_catch(sections_design(shared_section_counts())))
  separate <- suppressWarnings(estimate_total_catch(sections_design(separate_section_counts())))

  expect_equal(lake_row(shared)$estimate, lake_row(separate)$estimate)
  expect_gt(lake_row(shared)$se, lake_row(separate)$se)
})

test_that("the per-section rows are identical under both structures (GH #145)", {
  # Only the aggregation was wrong. Each section's own total is a single
  # estimate whose party-size term does not combine with anything, so a
  # regression here means the correction reached rows it had no business
  # touching.
  shared <- suppressWarnings(estimate_total_catch(sections_design(shared_section_counts())))
  separate <- suppressWarnings(estimate_total_catch(sections_design(separate_section_counts())))

  sec_only <- function(result) result$estimates[result$estimates$section != ".lake_total", ]
  expect_equal(sec_only(shared)$se, sec_only(separate)$se)
})

test_that("the shared lake term equals the linear sum over sections (GH #145)", {
  # Pins the arithmetic rather than the direction: with one estimate spanning
  # the sections the contributions add before squaring, so the lake variance
  # carries (sum_i R_i * se_exp_i)^2 where the independent case carries the sum
  # of squares. The difference between the two designs is exactly that gap.
  shared <- suppressWarnings(estimate_total_catch(sections_design(shared_section_counts())))
  separate <- suppressWarnings(estimate_total_catch(sections_design(separate_section_counts())))

  contrib <- separate$se_expansion[separate$estimates$section != ".lake_total"]
  quadrature <- sum(contrib^2)
  linear <- sum(contrib)^2

  expect_equal(
    lake_row(shared)$se^2 - lake_row(separate)$se^2,
    linear - quadrature,
    tolerance = 1e-8
  )
})

test_that("per-section estimates are unchanged by the correction (GH #145)", {
  # The independent case was already right. The correction is written as the
  # missing covariance rather than a re-derivation precisely so this number
  # does not move.
  separate <- suppressWarnings(estimate_total_catch(sections_design(separate_section_counts())))
  expect_equal(
    lake_row(separate)$se,
    sqrt(sum(separate$estimates$se[separate$estimates$section != ".lake_total"]^2)),
    tolerance = 1e-10
  )
})

test_that("a sections total reports the party-size component its SE carries (GH #145, GH #134)", {
  # se_expansion = NULL means "never propagated". The sections constructor said
  # that while its `se` contained the term, which is the reporting half of the
  # same defect.
  shared <- suppressWarnings(estimate_total_catch(sections_design(shared_section_counts())))

  expect_false(is.null(shared$se_expansion))
  expect_length(shared$se_expansion, nrow(shared$estimates))
  # The lake entry is the combined term, larger than either section's own.
  lake_component <- shared$se_expansion[shared$estimates$section == ".lake_total"]
  sec_components <- shared$se_expansion[shared$estimates$section != ".lake_total"]
  expect_equal(lake_component, sum(sec_components), tolerance = 1e-10)
})

test_that("a design without expansion reports no component and keeps its SE (GH #145)", {
  # No party-size estimate means the component does not apply -- NULL, not a
  # zero, which would be indistinguishable from a term that never propagated.
  plain <- sections_raw()
  plain$angler_count <- plain$angler_boats * 2.5
  result <- suppressWarnings(estimate_total_catch(sections_design(plain)))

  expect_null(result$se_expansion)
  sec_se <- result$estimates$se[result$estimates$section != ".lake_total"]
  expect_equal(lake_row(result)$se, sqrt(sum(sec_se^2)), tolerance = 1e-10)
})

test_that("harvest and release sections totals carry the same correction (GH #145)", {
  # The three totals files are near-twins and have drifted apart before; the
  # correction routes through one shared helper, and this is what holds all
  # three to it.
  shared_design <- sections_design(shared_section_counts())
  separate_design <- sections_design(separate_section_counts())

  harvest_shared <- suppressWarnings(estimate_total_harvest(shared_design))
  harvest_separate <- suppressWarnings(estimate_total_harvest(separate_design))
  expect_gt(lake_row(harvest_shared)$se, lake_row(harvest_separate)$se)
  expect_false(is.null(harvest_shared$se_expansion))

  release_shared <- suppressWarnings(estimate_total_release(shared_design))
  release_separate <- suppressWarnings(estimate_total_release(separate_design))
  expect_gt(lake_row(release_shared)$se, lake_row(release_separate)$se)
  expect_false(is.null(release_shared$se_expansion))
})

# GH #150: recovering the "partial" geometry the per-part component lost ------

# One party-size estimate per day_type. Sections cross-cut day_type -- each
# section covers two weekdays and two weekend days -- so every group straddles
# both sections. This is the geometry #150 names as ordinary rather than
# exotic: `mean_party_size(by = day_type)` is a routine thing to write, and
# before the decomposition was carried it forced the lake row to NA.
partial_section_counts <- function() {
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mps = c(2.5, 2.5),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(weekday = 0.1, weekend = 0.1)
  derive_angler_count(sections_raw(), boat_count = angler_boats, party_size = lookup)
}

test_that("a partial section geometry returns a finite lake SE (GH #150)", {
  # The classifier still says "partial" -- the geometry has not changed, only
  # what the estimator can do with it.
  design <- sections_design(partial_section_counts())
  expect_identical(
    expansion_group_structure(design, design[["section_col"]]),
    "partial"
  )

  expect_no_warning(
    result <- estimate_total_catch(design),
    class = "creel_warning_expansion_structure_unknown"
  )
  expect_false(is.na(lake_row(result)$se))
})

test_that("the partial lake SE sits between the nested and shared ones (GH #150)", {
  # Bracketing, not just finiteness. Each group spans both sections, so the
  # covariance is positive and the answer must exceed the independent case;
  # the groups are disjoint from each other, so it must fall short of treating
  # every section as driven by one estimate.
  partial <- suppressWarnings(estimate_total_catch(sections_design(partial_section_counts())))
  nested <- suppressWarnings(estimate_total_catch(sections_design(separate_section_counts())))
  shared <- suppressWarnings(estimate_total_catch(sections_design(shared_section_counts())))

  expect_gt(lake_row(partial)$se, lake_row(nested)$se)
  expect_lt(lake_row(partial)$se, lake_row(shared)$se)
})

test_that("the partial lake SE equals the hand-combined decomposition (GH #150)", {
  # Hand-computed outside the estimator: each group's per-section
  # contributions are b = 1.0 (North) and 0.9 (South), scaled by the section
  # rates 1.96875 and 2.06250. Same-group terms add before squaring, different
  # groups add as variances, giving 2 * 3.825^2 = 29.26125 for the expansion
  # term. Pinning the arithmetic rather than the output keeps this from
  # ratifying whatever the code happens to produce.
  result <- suppressWarnings(estimate_total_catch(sections_design(partial_section_counts())))
  secs <- result$estimates[result$estimates$section != ".lake_total", ]
  components <- result$se_expansion[result$estimates$section != ".lake_total"]

  exact_var <- 2 * 3.825^2
  expected <- sqrt(sum(secs$se^2) - sum(components^2) + exact_var)

  expect_equal(lake_row(result)$se, expected, tolerance = 1e-9)
  expect_equal(lake_row(result)$se, 37.23078214, tolerance = 1e-7)
})

test_that("the nested and shared section SEs are untouched by #150", {
  # These two were already exact. #150 must recover the third case without
  # perturbing them, so their branches keep their own arithmetic rather than
  # routing through the general formula.
  nested <- suppressWarnings(estimate_total_catch(sections_design(separate_section_counts())))
  shared <- suppressWarnings(estimate_total_catch(sections_design(shared_section_counts())))

  expect_equal(lake_row(nested)$se, 37.2297, tolerance = 1e-5)
  expect_equal(lake_row(shared)$se, 37.6203, tolerance = 1e-5)
})

test_that("harvest and release recover the partial geometry too (GH #150)", {
  # The three twins share combine_section_variances(), and the decomposition
  # has to be collected in all three loops to reach it. A twin that forgot to
  # collect it would fall back to NA here while catch returned a number.
  design <- sections_design(partial_section_counts())

  harvest <- suppressWarnings(estimate_total_harvest(design))
  release <- suppressWarnings(estimate_total_release(design))

  expect_false(is.na(lake_row(harvest)$se))
  expect_false(is.na(lake_row(release)$se))
})

test_that("the refusal remains for a partial structure with no decomposition (GH #144, #150)", {
  # The fallback is not dead code: an estimator that never carried the
  # decomposition still reaches the partial branch with nothing to combine,
  # and must refuse rather than pick a shortcut. Exercised directly because no
  # first-party effort path produces that state any more.
  expect_warning(
    result <- add_expansion_covariance(
      pv = 10,
      rate = c(2, 3),
      expansion_se = c(0.5, 0.5),
      structure = "partial",
      decomposition = NULL
    ),
    class = "creel_warning_expansion_structure_unknown"
  )
  expect_true(is.na(result))
})
