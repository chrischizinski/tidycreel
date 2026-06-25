# Snapshot regression tests for bootstrap-capable estimators
# Tests verify that default (delta-method) output is numerically stable
# Update snapshots intentionally: testthat::snapshot_accept("bootstrap-snapshots")

# Helper: build bus-route creel_design suitable for estimate_total_harvest()
# and estimate_total_catch().  Uses seed = 42L for reproducibility.
.make_br_design <- function() {
  set.seed(42L)
  suppressMessages(suppressWarnings({
    d <- build_br_design_for_tests(3L, 6L, 8L, seed = 42L)
    counts <- data.frame(
      date = d$calendar$date,
      day_type = d$calendar$day_type,
      effort_hours = c(15, 20, 18, 22, 16, 19),
      stringsAsFactors = FALSE
    )
    add_counts(d, counts)
  }))
}

# SNAP-BOOT-01: estimate_total_harvest default (delta-method) output ----------

test_that("SNAP-BOOT-01: estimate_total_harvest default output is stable", {
  design <- .make_br_design()
  result <- suppressWarnings(estimate_total_harvest(design))
  expect_snapshot(tidy(result))
})

# SNAP-BOOT-02: estimate_total_catch default (delta-method) output ------------

test_that("SNAP-BOOT-02: estimate_total_catch default output is stable", {
  design <- .make_br_design()
  result <- suppressWarnings(estimate_total_catch(design))
  expect_snapshot(tidy(result))
})

# SNAP-BOOT-03: estimate_angler_n default (delta-method) output ---------------

test_that("SNAP-BOOT-03: estimate_angler_n default output is stable", {
  result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  expect_snapshot(tidy(result))
})

# SNAP-BOOT-04: estimate_mr_harvest default (delta-method) output -------------

test_that("SNAP-BOOT-04: estimate_mr_harvest default output is stable", {
  angler_n <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  result <- estimate_mr_harvest(angler_n, harvest_rate = 0.35)
  expect_snapshot(tidy(result))
})
