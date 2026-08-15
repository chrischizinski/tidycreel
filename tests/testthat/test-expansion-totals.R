# Party-size expansion at the totals seam (GH #134, GH #144)
#
# The three totals route through estimate_effort_*(), whose standard error
# already carries the party-size term, and then sum per-stratum product
# variances. Two separate defects meet here: the combination across strata
# ignores whether the multiplier is shared (GH #144), and the resulting object
# reports se_expansion = NULL while demonstrably carrying the term (GH #134).

totals_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
}

totals_raw <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    angler_boats = c(6, 2, 4, 8, 5, 5),
    stringsAsFactors = FALSE
  )
}

totals_interviews <- function() {
  data.frame(
    date = rep(as.Date("2024-06-01") + 0:5, each = 4),
    day_type = rep(rep(c("weekday", "weekend"), 3), each = 4),
    catch_total = c(3, 4, 2, 5, 6, 4, 2, 3, 3, 6, 7, 5, 4, 4, 5, 3, 2, 4, 3, 5, 4, 6, 3, 4),
    harvest_total = c(2, 2, 1, 3, 4, 2, 1, 2, 2, 4, 5, 3, 2, 3, 3, 2, 1, 2, 2, 3, 3, 4, 2, 2),
    hours_fished = 2,
    status = "complete",
    interview_id = seq_len(24),
    stringsAsFactors = FALSE
  )
}

totals_catch <- function() {
  iv <- totals_interviews()
  data.frame(
    interview_id = rep(iv$interview_id, 2),
    species = "walleye",
    count = c(iv$harvest_total, iv$catch_total - iv$harvest_total),
    catch_type = rep(c("harvested", "released"), each = nrow(iv)),
    stringsAsFactors = FALSE
  )
}

totals_design <- function(counts) {
  design <- creel_design(totals_calendar(), date = date, strata = day_type)
  design <- suppressWarnings(add_counts(design, counts, count_col = "angler_count"))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    totals_interviews(),
    catch = catch_total,
    effort = hours_fished,
    harvest = harvest_total,
    trip_status = status
  )))
  suppressWarnings(add_catch(
    design,
    totals_catch(),
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  ))
}

# One estimate, used in every stratum: errors perfectly correlated across strata.
shared_counts <- function() {
  derive_angler_count(
    totals_raw(),
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
}

# Two estimates with identical value and identical SE, one per stratum: errors
# independent across strata. Statistically a different design from the above,
# and its total standard error must be smaller.
separate_counts <- function() {
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mps = c(2.5, 2.5),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(weekday = 0.1, weekend = 0.1)
  derive_angler_count(totals_raw(), boat_count = angler_boats, party_size = lookup)
}

test_that("a shared multiplier gives a larger total SE than separate ones (GH #144)", {
  # The numbers are identical in every respect except whether one estimate or
  # two produced them, so any difference in the total is entirely the
  # correlation structure. Summing per-stratum variances in quadrature erases
  # it, and returns the same standard error for both -- understating the shared
  # case by sqrt(H).
  shared <- suppressWarnings(estimate_total_catch(totals_design(shared_counts())))
  separate <- suppressWarnings(estimate_total_catch(totals_design(separate_counts())))

  expect_equal(shared$estimates$estimate, separate$estimates$estimate)
  expect_gt(shared$estimates$se, separate$estimates$se)
})

test_that("the shared expansion term equals the linear sum over strata (GH #144)", {
  # Pins the arithmetic, not just the direction: with one estimate spanning the
  # strata the contributions add before squaring, so the total variance carries
  # (sum_h R_h * se_exp_h)^2 where the independent case carries the sum of
  # squares.
  design <- totals_design(shared_counts())
  effort <- suppressWarnings(estimate_effort(design, by = day_type))
  rate <- suppressWarnings(estimate_catch_rate(design, by = day_type))

  se_exp_h <- effort$se_expansion
  r_h <- rate$estimates$estimate
  quadrature <- sum((r_h * se_exp_h)^2)
  linear <- sum(r_h * se_exp_h)^2

  shared <- suppressWarnings(estimate_total_catch(design))
  separate <- suppressWarnings(estimate_total_catch(totals_design(separate_counts())))

  # The separate-estimate design is the quadrature case, and differs from the
  # shared one by exactly the covariance the shared case adds.
  expect_equal(
    shared$estimates$se^2 - separate$estimates$se^2,
    linear - quadrature,
    tolerance = 1e-8
  )
})

test_that("separate per-stratum estimates are unchanged by the correction (GH #144)", {
  # The independent case was already right. Written as the missing covariance
  # rather than as a re-decomposition precisely so that this number does not
  # move; a regression here means the fix perturbed the Goodman cross term.
  separate <- suppressWarnings(estimate_total_catch(totals_design(separate_counts())))
  expect_equal(separate$estimates$se, 29.65782009, tolerance = 1e-6)
})

test_that("totals report the party-size component they carry (GH #134)", {
  # estimate_effort() honors the NULL-means-not-propagated contract; the totals
  # did not, so a totals object whose se demonstrably contains the term reported
  # se_expansion = NULL. Anyone applying the documented NULL test to a total
  # concluded the component was missing -- the exact misreading the field exists
  # to prevent.
  shared <- suppressWarnings(estimate_total_catch(totals_design(shared_counts())))
  expect_false(is.null(shared$se_expansion))
  expect_gt(shared$se_expansion, 0)
})

test_that("totals without a party-size SE keep se_expansion NULL (GH #134)", {
  # The contract runs both ways: NULL has to stay reachable, or it stops meaning
  # anything.
  counts <- derive_angler_count(
    totals_raw(),
    boat_count = angler_boats,
    party_size = 2.5
  )
  result <- suppressWarnings(estimate_total_catch(totals_design(counts)))
  expect_null(result$se_expansion)
})

test_that("harvest and release totals carry the component too (GH #134)", {
  # The three files are near-twins; a seam defect in one is a seam defect in all
  # three, and they have drifted before.
  design <- totals_design(shared_counts())
  harvest <- suppressWarnings(estimate_total_harvest(design))
  release <- suppressWarnings(estimate_total_release(design))

  expect_false(is.null(harvest$se_expansion))
  expect_false(is.null(release$se_expansion))
})

test_that("harvest and release totals also correct the shared combination (GH #144)", {
  for (fn in list(estimate_total_harvest, estimate_total_release)) {
    shared <- suppressWarnings(fn(totals_design(shared_counts())))
    separate <- suppressWarnings(fn(totals_design(separate_counts())))
    expect_gt(shared$estimates$se, separate$estimates$se)
  }
})

# GH #144: the structure classifier decides the arithmetic, so test it directly -

test_that("one estimate for the whole design is classified as shared (GH #144)", {
  # mean_party_size() without `by` returns a single estimate, which is the
  # default and the case the quadrature sum got wrong.
  design <- totals_design(shared_counts())
  expect_identical(expansion_group_structure(design), "shared")
})

test_that("one estimate per stratum is classified as nested (GH #144)", {
  design <- totals_design(separate_counts())
  expect_identical(expansion_group_structure(design), "nested")
})

test_that("a design with no expansion has no structure (GH #144)", {
  counts <- derive_angler_count(
    totals_raw(),
    boat_count = angler_boats,
    party_size = 2.5
  )
  expect_null(expansion_group_structure(totals_design(counts)))
})

test_that("groups straddling strata unevenly give an NA total SE and warn (GH #144)", {
  # A per-row party size makes the group the multiplier's own value, so a value
  # shared by both strata alongside one confined to a single stratum produces a
  # geometry that is neither independent nor wholly shared. Quadrature would
  # understate and the linear sum would overstate; the decomposition needed to
  # do better is not recoverable from a per-stratum standard error, so the
  # honest answer is that the combination is unknown.
  raw <- totals_raw()
  raw$mps <- c(2.5, 2.5, 2.5, 3.0, 2.5, 3.0)
  raw$mps_se <- 0.1
  counts <- derive_angler_count(
    raw,
    boat_count = angler_boats,
    party_size = mps,
    party_size_se = mps_se
  )
  design <- totals_design(counts)
  expect_identical(expansion_group_structure(design), "partial")

  expect_warning(
    result <- estimate_total_catch(design),
    class = "creel_warning_expansion_structure_unknown"
  )
  expect_true(is.na(result$estimates$se))
  # NA, not dropped and not zero: the component applies and is unknown.
  expect_true(is.na(result$se_expansion))
})

test_that("an NA total SE from an unknown structure carries into the CI (GH #144)", {
  # A standard error that goes NA must not leave a confidence interval behind
  # that looks computed.
  raw <- totals_raw()
  raw$mps <- c(2.5, 2.5, 2.5, 3.0, 2.5, 3.0)
  raw$mps_se <- 0.1
  counts <- derive_angler_count(
    raw,
    boat_count = angler_boats,
    party_size = mps,
    party_size_se = mps_se
  )
  result <- suppressWarnings(estimate_total_catch(totals_design(counts)))

  expect_true(is.na(result$estimates$ci_lower))
  expect_true(is.na(result$estimates$ci_upper))
})
