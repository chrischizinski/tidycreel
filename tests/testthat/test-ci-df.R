# Every creel_estimates records, per row, the degrees of freedom of the
# reference distribution its confidence interval was built on (GH #585 PR 1).
#
# Why it matters: a sum or difference of independent estimates
# (combine_estimates() / compare_estimates(), #585 PR 3) builds its interval on
# Satterthwaite df, df = (sum v_i)^2 / sum(v_i^2 / df_i), which needs each
# part's own df_i. Recomputing it later is not an option -- the estimators use
# different rules (#705) -- so the df has to be recorded where the interval is
# built, and it has to be the df the interval actually used. A recorded df that
# disagrees with the interval would give a combined interval with the wrong
# coverage and no error.
#
# The central check is therefore on the interval itself, not on a constant:
# for a symmetric, unclamped row, (ci_upper - estimate) / se is the critical
# value, and it must equal qt(1 - alpha / 2, ci_df) (qnorm when ci_df = Inf).
# Recording a different df than the one used fails it.

# Rows where the upper bound is a plain estimate + z * se.
expect_interval_uses_ci_df <- function(x, conf_level = 0.95) {
  expect_s3_class(x, "creel_estimates")
  est <- x$estimates
  expect_length(x$ci_df, nrow(est))
  ok <- !is.na(est$se) & est$se > 0 & is.finite(est$ci_upper) &
    is.finite(est$estimate) & !is.na(x$ci_df)
  expect_true(any(ok), label = "at least one row with a checkable interval")
  z_implied <- (est$ci_upper[ok] - est$estimate[ok]) / est$se[ok]
  z_recorded <- stats::qt(1 - (1 - conf_level) / 2, df = x$ci_df[ok])
  expect_equal(z_implied, z_recorded, tolerance = 1e-8)
  invisible(x)
}

quiet <- function(expr) suppressWarnings(suppressMessages(expr))

ms_design <- function() {
  quiet(build_multistrata_multispecies_design_for_tests(n_days = 40, n_interviews = 200, seed = 1))
}

# --- constructor contract ---------------------------------------------------

test_that("the constructor refuses to build an estimate without its CI df", {
  est <- tibble::tibble(estimate = 1, se = 0.1, ci_lower = 0.8, ci_upper = 1.2, n = 10L)
  expect_error(new_creel_estimates(est), "ci_df")
  expect_error(new_creel_estimates(est, ci_df = "9"), "ci_df must be numeric")
  expect_error(new_creel_estimates(est, ci_df = -1), "non-negative")
  two <- rbind(est, est)
  expect_error(new_creel_estimates(two, ci_df = c(1, 2, 3)), "one per row")
})

test_that("one df is recycled to every row; Inf, NA and 0 are kept as given", {
  est <- tibble::tibble(estimate = 1:3, se = 0.1, ci_lower = 0, ci_upper = 4, n = 10L)
  expect_identical(new_creel_estimates(est, ci_df = 9)$ci_df, c(9, 9, 9))
  x <- new_creel_estimates(est, ci_df = c(Inf, NA_real_, 0))
  expect_identical(x$ci_df, c(Inf, NA_real_, 0))
  # Not a column: printing and the tibble's shape are unchanged.
  expect_false("ci_df" %in% names(x$estimates))
})

test_that("a row with no interval records no df, whatever its estimator uses", {
  # An unknown estimate has NA bounds; a finite df beside it would let a later
  # combination treat the unavailable row as having a reference distribution.
  est <- tibble::tibble(
    estimate = c(1, NA), se = c(0.1, NA), ci_lower = c(0.8, NA), ci_upper = c(1.2, NA), n = 10L
  )
  expect_identical(new_creel_estimates(est, ci_df = 9)$ci_df, c(9, NA_real_))
})

# --- instantaneous design: effort, rates, totals ------------------------------

test_that("effort records the design df its t interval used, ungrouped and grouped", {
  d <- ms_design()
  e <- quiet(estimate_effort(d))
  expect_interval_uses_ci_df(e)
  expect_true(is.finite(e$ci_df))
  g <- quiet(estimate_effort(d, by = day_type))
  expect_interval_uses_ci_df(g)
  # Grouped effort keys every group to the whole design's df (#705 item 6).
  expect_identical(unique(g$ci_df), e$ci_df)
})

test_that("rates record Inf: survey's confint() and svyby() intervals are normal", {
  d <- ms_design()
  for (x in list(
    quiet(estimate_catch_rate(d)),
    quiet(estimate_catch_rate(d, by = day_type)),
    quiet(estimate_catch_rate(d, by = species)),
    quiet(estimate_harvest_rate(d)),
    # The fixture has complete trips only; MOR runs on them when asked, and
    # reaches the separate creel_estimates_mor constructor.
    quiet(estimate_catch_rate(d, estimator = "mor", use_trips = "complete"))
  )) {
    expect_interval_uses_ci_df(x)
    expect_true(all(x$ci_df == Inf))
  }
})

test_that("an ungrouped total records interviews minus strata, the df its t used", {
  d <- ms_design()
  tot <- quiet(estimate_total_catch(d))
  expect_interval_uses_ci_df(tot)
  # The rule is sum(n) - H over the stratum rate cells (#705 item 3): pinned
  # here so a change to it is a deliberate one.
  rates <- quiet(estimate_catch_rate(d, by = day_type))
  expect_identical(tot$ci_df, as.numeric(max(1L, sum(rates$estimates$n) - nrow(rates$estimates))))
})

test_that("grouped and species totals carry each row's own df, row-aligned", {
  d <- ms_design()
  g <- quiet(estimate_total_catch(d, by = day_type))
  expect_interval_uses_ci_df(g)
  # Per group: that group's interviews less its strata (#705 item 4).
  expect_identical(g$ci_df, as.numeric(g$estimates$n - 1L))
  sp <- quiet(estimate_total_catch(d, by = c(species, day_type)))
  expect_interval_uses_ci_df(sp)
  expect_identical(sp$ci_df, as.numeric(sp$estimates$n - 1L))
  expect_interval_uses_ci_df(quiet(estimate_total_harvest(d)))
  # The fixture records no releases, so the release total is a known zero with
  # SE 0 and no interval to check; the df is still recorded.
  rel <- quiet(estimate_total_release(d))
  expect_length(rel$ci_df, nrow(rel$estimates))
  expect_true(all(is.finite(rel$ci_df)))
})

# --- sections ---------------------------------------------------------------

test_that("sectioned effort and totals record each section's df and the lake row's", {
  d <- quiet(make_sectioned_species_design())
  e <- quiet(estimate_effort(d))
  expect_interval_uses_ci_df(e)
  tot <- quiet(estimate_total_catch(d))
  expect_interval_uses_ci_df(tot)
  sec <- tot$estimates$section != ".lake_total"
  lake <- !sec
  expect_true(any(lake))
  # The lake row's t uses the sum of the sections' own df (GH #409).
  expect_equal(tot$ci_df[lake], max(1, sum(tot$ci_df[sec])))
  r <- quiet(estimate_catch_rate(d))
  expect_interval_uses_ci_df(r)
})

# --- bus-route --------------------------------------------------------------

test_that("bus-route effort, rates and totals record Inf (survey confint)", {
  d <- quiet(add_br_register(build_br_design_for_tests(n_sites = 4, n_days = 12, n_interviews = 80, seed = 3)))
  for (x in list(
    quiet(estimate_effort(d)),
    quiet(estimate_catch_rate(d)),
    quiet(estimate_total_catch(d))
  )) {
    est <- x$estimates
    expect_length(x$ci_df, nrow(est))
    expect_true(all(x$ci_df == Inf))
  }
})

# --- estimators on summary inputs --------------------------------------------

test_that("mark-recapture records the df of the interval it built, or NA", {
  delta <- estimate_angler_n(M = 100, n = 80, m = 20, ci_method = "delta")
  expect_interval_uses_ci_df(delta)
  expect_identical(delta$ci_df, 19)
  # The logit interval is asymmetric and uses the normal quantile.
  expect_identical(estimate_angler_n(M = 100, n = 80, m = 20)$ci_df, Inf)

  # Schnabel with sum(m) < 50 inverts a Poisson: no df describes it, and a
  # later combination must not be handed one (decision 2026-11-24).
  small <- quiet(estimate_angler_n(
    M = c(0L, 47L, 91L, 131L), n = rep(50L, 4L), m = c(0L, 4L, 6L, 8L), method = "schnabel"
  ))
  expect_identical(small$ci_df, NA_real_)
  big <- quiet(estimate_angler_n(
    M = c(0L, 80L, 140L, 190L), n = rep(100L, 4L), m = c(0L, 15L, 20L, 25L), method = "schnabel"
  ))
  # occasions - 1, not recaptures - 1 (finding 29).
  expect_identical(big$ci_df, 3)
})

test_that("stratified exploitation records n_h - 1 per stratum and sum(n_h) - H overall", {
  strata_df <- data.frame(
    stratum = c("weekday", "weekend"), T_h = c(120L, 80L), C_h = c(280, 170),
    se_C_h = c(28, 22), n_h = c(110L, 70L), m_h = c(9L, 6L)
  )
  x <- estimate_exploitation_rate(strata = strata_df, by = "stratum")
  expect_interval_uses_ci_df(x)
  expect_identical(x$ci_df, c(109, 69, 178))
})

# --- guard: no constructor call can omit it ---------------------------------

test_that("every constructor call in R/ passes ci_df", {
  r_dir <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(r_dir), "package source not available (installed copy)")
  missing <- character(0)
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    exprs <- parse(f, keep.source = TRUE)
    pd <- utils::getParseData(exprs)
    calls <- pd[pd$token == "SYMBOL_FUNCTION_CALL" &
      pd$text %in% c("new_creel_estimates", "new_creel_estimates_mor"), ]
    for (i in seq_len(nrow(calls))) {
      expr_id <- pd$parent[pd$id == pd$parent[pd$id == calls$id[i]]]
      args <- pd$text[pd$parent == expr_id & pd$token == "SYMBOL_SUB"]
      if (!"ci_df" %in% args) missing <- c(missing, paste0(basename(f), ":", calls$line1[i]))
    }
  }
  expect_identical(missing, character(0))
})
