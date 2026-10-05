# An ungrouped total on a sectioned design multiplied each section's whole
# effort by ONE rate pooled across its strata -- a combined ratio -- while every
# other total path forms sum_h(E_h x rate_h): the non-sectioned total, the
# sectioned `by =` path and the species path. On one design the section total
# and the sum of its `by = day_type` rows disagreed (South harvest +3.3%,
# release -4.1% on this fixture; GH #409). Cochran (1977, s. 6.12) prefers the
# separate ratio when every stratum's sample is adequate, which the package's
# rate floor already demands; Pope et al. (Ch. 17) form strataFish per stratum.

ssum_totals <- list(
  catch = estimate_total_catch,
  harvest = estimate_total_harvest,
  release = estimate_total_release
)

ssum_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

test_that("#409: a section's ungrouped total is the sum of its by = <strata> rows", {
  set.seed(409)
  d <- make_sectioned_species_design(n_interviews = 36L) # nolint: object_usage_linter
  for (nm in names(ssum_totals)) {
    ung <- ssum_quiet(ssum_totals[[nm]](d))$estimates
    grp <- ssum_quiet(ssum_totals[[nm]](d, by = day_type))$estimates
    for (s in c("North", "South")) {
      rows <- grp[grp$section == s, ]
      expect_equal(ung$estimate[ung$section == s], sum(rows$estimate), tolerance = 1e-10, info = paste(nm, s))
      # This fixture has no party-size expansion, so the strata are independent
      # and the section's variance is the sum of its strata's.
      expect_equal(ung$se[ung$section == s]^2, sum(rows$se^2), tolerance = 1e-10, info = paste(nm, s))
    }
    # The lake total is the sum of the sections.
    expect_equal(
      ung$estimate[ung$section == ".lake_total"],
      sum(ung$estimate[ung$section %in% c("North", "South")]),
      tolerance = 1e-10, info = nm
    )
  }
})

test_that("#409: the fixture's interview mix differs from its effort mix, so the old form would differ", {
  # A combined and a separate ratio agree when interviews are spread like
  # effort. If the fixture had that property the test above could not fail.
  set.seed(409)
  d <- make_sectioned_species_design(n_interviews = 36L) # nolint: object_usage_linter
  cn <- d$counts
  iv <- d$interviews
  gap <- vapply(c("North", "South"), function(s) {
    e <- prop.table(tapply(cn$effort_hours[cn$section == s], cn$day_type[cn$section == s], sum))
    n <- prop.table(table(iv$day_type[iv$section == s]))
    max(abs(e - n[names(e)]))
  }, numeric(1))
  expect_true(any(gap > 0.05))
})
