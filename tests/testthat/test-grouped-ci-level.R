# Grouped intervals honour conf_level (GH #703).
#
# survey::svyby(vartype = "ci", ci.level = ) ignores ci.level: its ci_l/ci_u
# columns are always the 95% normal interval. Every grouped rate and bus-route
# path read them, so a user asking for an 80% or 90% interval with `by =` got a
# 95% one labelled with their level, while the same call without `by` (which
# uses confint(level = )) gave the level asked for. Nothing errored and the
# numbers looked ordinary.
#
# The check is on the interval itself: for a symmetric, unclamped row the
# critical value (ci_upper - estimate) / se must be the requested level's
# quantile on the row's recorded df. Since GH #705 that is Student's t on the
# design df, so the df must also be finite: a normal interval would pass the
# level check while ignoring how few days the interviews came from.

quiet <- function(expr) suppressWarnings(suppressMessages(expr))

expect_level <- function(x, conf_level) {
  est <- x$estimates
  ok <- !is.na(est$se) & est$se > 0 & is.finite(est$ci_upper) & is.finite(est$estimate)
  expect_true(any(ok), label = "at least one row with a checkable interval")
  expect_true(all(is.finite(x$ci_df[ok])))
  z <- (est$ci_upper[ok] - est$estimate[ok]) / est$se[ok]
  expect_equal(z, stats::qt(1 - (1 - conf_level) / 2, df = x$ci_df[ok]), tolerance = 1e-8)
  invisible(x)
}

ms_design <- function() {
  quiet(build_multistrata_multispecies_design_for_tests(n_days = 40, n_interviews = 200, seed = 1))
}

test_that("grouped rates use the requested level, not svyby's fixed 95%", {
  d <- ms_design()
  for (lvl in c(0.8, 0.9)) {
    expect_level(quiet(estimate_catch_rate(d, by = day_type, conf_level = lvl)), lvl)
    expect_level(quiet(estimate_harvest_rate(d, by = day_type, conf_level = lvl)), lvl)
    # species with an interview grouping goes through the grouped helper; species
    # alone is per-species ungrouped (confint) and was never affected.
    expect_level(quiet(estimate_catch_rate(d, by = c(species, day_type), conf_level = lvl)), lvl)
    expect_level(quiet(estimate_catch_rate(
      d, by = day_type, estimator = "mor", use_trips = "complete", conf_level = lvl
    )), lvl)
  }
})

test_that("a grouped rate's interval narrows with the level, as the ungrouped one does", {
  d <- ms_design()
  width <- function(x) x$estimates$ci_upper - x$estimates$ci_lower
  g80 <- quiet(estimate_catch_rate(d, by = day_type, conf_level = 0.8))
  g95 <- quiet(estimate_catch_rate(d, by = day_type, conf_level = 0.95))
  # Same estimates and SEs; only the interval may move.
  expect_equal(g80$estimates$estimate, g95$estimates$estimate)
  expect_equal(g80$estimates$se, g95$estimates$se)
  expect_true(all(width(g80) < width(g95)))
  expect_equal(width(g80) / width(g95), stats::qt(0.9, g95$ci_df) / stats::qt(0.975, g95$ci_df), tolerance = 1e-8)
})

test_that("the 95% default is unchanged", {
  d <- ms_design()
  expect_level(quiet(estimate_catch_rate(d, by = day_type)), 0.95)
})

test_that("grouped bus-route effort, rates and totals use the requested level", {
  d <- quiet(add_br_register(build_br_design_for_tests(n_sites = 4, n_days = 12, n_interviews = 80, seed = 3)))
  for (x in list(
    quiet(estimate_effort(d, by = day_type, conf_level = 0.8)),
    quiet(estimate_catch_rate(d, by = day_type, conf_level = 0.8)),
    quiet(estimate_total_catch(d, by = day_type, conf_level = 0.8))
  )) {
    est <- x$estimates
    # The lower bound is clamped at zero, so the upper bound carries the level.
    ok <- !is.na(est$se) & est$se > 0
    expect_true(any(ok))
    expect_true(all(is.finite(x$ci_df[ok])))
    expect_equal(
      (est$ci_upper[ok] - est$estimate[ok]) / est$se[ok],
      stats::qt(0.9, df = x$ci_df[ok]),
      tolerance = 1e-8
    )
  }
})
