# prop_of_lake_total carried no uncertainty in the three sectioned product
# totals (GH #243).
#
# A reader comparing shares across sections had nothing to judge the comparison
# by, in a table where every other quantity carries an SE and a CI. #231 fixed
# the same complaint for `estimate_effort_sections()`, but that fix does not
# port: for effort the proportion is a domain total over an overall total from
# ONE design, so `svyratio()` returns the ratio and its error together. Here
#
#   prop_h = (E_h * rate_h) / sum_k (E_k * rate_k)
#
# has a numerator and denominator that are each products of two estimates from
# DIFFERENT designs -- effort from the counts, rate from the interviews -- and
# the numerator is one of the denominator's own terms. There is no single
# design to hand `svyratio()`, so the error is derived by delta method.
#
# The load-bearing property is the two-section identity: with two sections the
# shares sum to 1, so one is a linear function of the other and their errors
# must be equal. A derivation that dropped the numerator-in-denominator
# correlation reproduces the shares exactly and still fails this. Measured on
# the fixture below, dropping the cross term moves the two apart by 1.2e-4
# while every other reported number stays put.

# Reuse the #144/#145/#150/#238 fixtures rather than restating them: their
# numbers are pinned across four issues, and a second copy would drift. The
# file is all helper definitions plus test_that() calls, so stubbing test_that
# picks up every fixture wherever it sits without re-running its tests.
fixtures <- new.env(parent = globalenv())
fixtures$test_that <- function(...) invisible(NULL)
sys.source(test_path("test-expansion-sections.R"), envir = fixtures)
for (.nm in setdiff(ls(fixtures), "test_that")) {
  assign(.nm, get(.nm, envir = fixtures))
}

prop_se_of <- function(result) {
  e <- result$estimates
  e$se_prop_of_lake_total[e$section != ".lake_total" & !is.na(e$estimate)]
}

sectioned_totals <- list(
  catch = estimate_total_catch,
  harvest = estimate_total_harvest,
  release = estimate_total_release
)

# The column exists at all -------------------------------------------------

test_that("PROPSE-01: all three sectioned product totals report the SE", {
  design <- sections_design(shared_section_counts())
  for (nm in names(sectioned_totals)) {
    result <- suppressWarnings(sectioned_totals[[nm]](design))
    expect_true(
      "se_prop_of_lake_total" %in% names(result$estimates),
      info = nm
    )
    # Every other quantity in the row carries an error; this one used not to.
    expect_true(all(is.finite(prop_se_of(result))), info = nm)
    expect_true(all(prop_se_of(result) > 0), info = nm)
  }
})

# The identity that discriminates a correct derivation ----------------------

test_that("PROPSE-02: with two sections the two shares carry equal error", {
  # p_2 = 1 - p_1 exactly, so Var(p_2) = Var(p_1). This is the assertion that
  # fails if the numerator-in-denominator correlation is dropped.
  for (counts in list(shared_section_counts(), separate_section_counts())) {
    design <- sections_design(counts)
    for (nm in names(sectioned_totals)) {
      se <- prop_se_of(suppressWarnings(sectioned_totals[[nm]](design)))
      expect_length(se, 2L)
      expect_equal(se[[1]], se[[2]], tolerance = 1e-10, info = nm)
    }
  }
})

test_that("PROPSE-03: dropping the cross-covariance would break that identity", {
  # Guards the guard. If the mutant also satisfied PROPSE-02, PROPSE-02 would
  # be proving nothing. Computed from the reported numbers rather than from
  # package internals, so it stays honest if the internals move.
  result <- suppressWarnings(estimate_total_catch(
    sections_design(shared_section_counts())
  ))
  e <- result$estimates
  sec <- e[e$section != ".lake_total", ]
  lake <- e[e$section == ".lake_total", ]

  est <- sec$estimate
  v <- sec$se^2
  s <- sum(est)
  p <- est / s
  v_lake <- lake$se^2

  with_cross <- sqrt((v - 2 * p * (v + (v_lake - sum(v)) / 2) + p^2 * v_lake) / s^2)
  no_cross <- sqrt((v - 2 * p * v + p^2 * v_lake) / s^2)

  expect_equal(with_cross[[1]], with_cross[[2]], tolerance = 1e-10)
  expect_gt(abs(no_cross[[1]] - no_cross[[2]]), 1e-6)
  # And the reported values are the with-cross ones.
  expect_equal(sec$se_prop_of_lake_total, with_cross, tolerance = 1e-8)
})

# The covariance model actually reaches the proportion ----------------------

test_that("PROPSE-04: a shared multiplier and per-section ones give different errors", {
  # The two fixtures feed the estimator identical numbers and differ only in
  # how many party-size estimates there are. If the proportion's error ignored
  # the expansion structure, these would come out equal -- as the shares
  # themselves do.
  shared <- suppressWarnings(estimate_total_catch(
    sections_design(shared_section_counts())
  ))
  nested <- suppressWarnings(estimate_total_catch(
    sections_design(separate_section_counts())
  ))

  expect_equal(
    shared$estimates$prop_of_lake_total,
    nested$estimates$prop_of_lake_total,
    tolerance = 1e-10
  )
  expect_false(isTRUE(all.equal(
    prop_se_of(shared)[[1]],
    prop_se_of(nested)[[1]],
    tolerance = 1e-8
  )))
})

test_that("PROPSE-05: a partial geometry resolves rather than falling back to NA", {
  design <- sections_design(partial_section_counts())
  expect_identical(
    expansion_group_structure(design, design[["section_col"]]),
    "partial"
  )
  result <- suppressWarnings(estimate_total_catch(design))
  expect_true(all(is.finite(prop_se_of(result))))
})

test_that("PROPSE-06: an unresolvable geometry reports no error for the share", {
  # The lake variance is NA there, and the proportion must not report an error
  # its own denominator could not produce.
  expect_true(is.na(section_cross_covariance(
    rate = c(2, 3),
    expansion_se = c(0.5, 0.5),
    structure = "partial",
    decomposition = NULL,
    n = 2L
  )[[1]]))
  expect_true(is.na(section_prop_of_lake_se(
    section_est = c(10, 20),
    section_var = c(4, 9),
    lake_var = NA_real_,
    cross = c(0, 0)
  )[[1]]))
})

# The special rows ----------------------------------------------------------

test_that("PROPSE-07: .lake_total reports exactly 0, not NA", {
  # Its share of itself is 1 by construction and was never estimated. One of
  # the few places in this package where a zero standard error is the honest
  # answer rather than a component that failed to propagate.
  for (nm in names(sectioned_totals)) {
    result <- suppressWarnings(sectioned_totals[[nm]](
      sections_design(shared_section_counts())
    ))
    lake <- lake_row(result)
    expect_identical(lake$prop_of_lake_total, 1.0, info = nm)
    expect_false(is.na(lake$se_prop_of_lake_total), info = nm)
    expect_equal(lake$se_prop_of_lake_total, 0, info = nm)
  }
})

test_that("PROPSE-08: a single present section has a share of 1 with no error", {
  # The three delta terms cancel on their own; nothing special-cases this.
  se <- section_prop_of_lake_se(
    section_est = 100,
    section_var = 25,
    lake_var = 25,
    cross = 0
  )
  expect_equal(se, 0)
})

test_that("PROPSE-09: an absent section reports NA for the share and its error", {
  # A zero would claim the section held none of the total rather than that
  # nothing was observed in it.
  counts <- shared_section_counts()
  counts <- counts[counts$section != "South", ]
  design <- sections_design(counts)
  result <- suppressWarnings(estimate_total_catch(design))
  absent <- result$estimates[result$estimates$section == "South", ]
  skip_if(nrow(absent) == 0L, "fixture did not produce an absent section row")
  expect_true(is.na(absent$prop_of_lake_total))
  expect_true(is.na(absent$se_prop_of_lake_total))
})

# What must not have moved --------------------------------------------------

test_that("PROPSE-10: the shares and every other column are unchanged", {
  # The fix adds an error to an existing number. If the number itself moved,
  # this stopped being a reporting fix and became a re-estimation.
  result <- suppressWarnings(estimate_total_catch(
    sections_design(shared_section_counts())
  ))
  e <- result$estimates
  expect_equal(
    e$prop_of_lake_total[e$section != ".lake_total"],
    e$estimate[e$section != ".lake_total"] /
      sum(e$estimate[e$section != ".lake_total"]),
    tolerance = 1e-12
  )
  # Pinned across #144/#145/#150/#238; the same fixture, the same numbers.
  expect_equal(
    e$estimate,
    c(98.4375, 92.8125, 191.25),
    tolerance = 1e-6
  )
  expect_equal(
    e$se,
    c(32.54820, 18.07388, 37.62030),
    tolerance = 1e-5
  )
})

test_that("PROPSE-11: the denominator variance is the lake row's own variance", {
  # GH #134: the reported error must belong to the number beside it, not to a
  # parallel derivation free to drift. The section SE and the lake SE come from
  # one `combine_section_variances()` call, so recomputing the proportion's
  # error from the REPORTED lake se reproduces it.
  for (counts in list(shared_section_counts(), separate_section_counts())) {
    result <- suppressWarnings(estimate_total_catch(sections_design(counts)))
    e <- result$estimates
    sec <- e[e$section != ".lake_total", ]
    v_lake <- e$se[e$section == ".lake_total"]^2
    est <- sec$estimate
    v <- sec$se^2
    s <- sum(est)
    p <- est / s
    cross <- (v_lake - sum(v)) / 2
    expect_equal(
      sec$se_prop_of_lake_total,
      sqrt(pmax(0, (v - 2 * p * (v + cross) + p^2 * v_lake) / s^2)),
      tolerance = 1e-8
    )
  }
})

test_that("PROPSE-12: the grouped path reports neither column", {
  # The share is only defined against a lake-wide denominator, which the
  # grouped path does not build. Unchanged by this fix; pinned so it stays so.
  design <- sections_design(shared_section_counts())
  result <- suppressWarnings(estimate_total_catch(design, by = "day_type"))
  expect_false("prop_of_lake_total" %in% names(result$estimates))
  expect_false("se_prop_of_lake_total" %in% names(result$estimates))
})
