# Tests for ci_method = "bootstrap" in bus-route estimators ----------------
# BOOT-01, BOOT-01-delta, BOOT-02, BOOT-02-delta

# Helper: build bus-route design with enough PSUs (>=2 per stratum) for bootstrap
.make_br_harvest_boot <- function() {
  set.seed(123L)
  suppressMessages(suppressWarnings({
    d <- build_br_design_for_tests(4L, 8L, 12L, seed = 123L)
    counts <- data.frame(
      date = d$calendar$date,
      day_type = d$calendar$day_type,
      effort_hours = c(15, 20, 18, 22, 16, 19, 14, 21),
      stringsAsFactors = FALSE
    )
    add_counts(d, counts)
  }))
}

# BOOT-01: estimate_total_harvest bootstrap returns ci_lo_boot / ci_hi_boot ---

test_that("BOOT-01: estimate_total_harvest bootstrap returns ci_lo_boot/ci_hi_boot", {
  d <- .make_br_harvest_boot()
  result <- suppressWarnings(estimate_total_harvest(d, ci_method = "bootstrap"))
  tbl <- tidy(result)

  expect_true("ci_lo_boot" %in% names(tbl))
  expect_true("ci_hi_boot" %in% names(tbl))
  expect_true("ci_lower" %in% names(tbl))
  expect_true("ci_upper" %in% names(tbl))

  expect_lt(tbl$ci_lo_boot, tbl$estimate)
  expect_gt(tbl$ci_hi_boot, tbl$estimate)
})

# BOOT-01-delta: default estimate_total_harvest has no boot columns ----------

test_that("BOOT-01-delta: estimate_total_harvest default has no boot columns", {
  d <- .make_br_harvest_boot()
  result <- suppressWarnings(estimate_total_harvest(d))
  tbl <- tidy(result)

  expect_false("ci_lo_boot" %in% names(tbl))
  expect_false("ci_hi_boot" %in% names(tbl))
})

# BOOT-02: estimate_total_catch bootstrap returns ci_lo_boot / ci_hi_boot ----

test_that("BOOT-02: estimate_total_catch bootstrap returns ci_lo_boot/ci_hi_boot", {
  d <- .make_br_harvest_boot()
  result <- suppressWarnings(estimate_total_catch(d, ci_method = "bootstrap"))
  tbl <- tidy(result)

  expect_true("ci_lo_boot" %in% names(tbl))
  expect_true("ci_hi_boot" %in% names(tbl))
  expect_true("ci_lower" %in% names(tbl))
  expect_true("ci_upper" %in% names(tbl))

  expect_lt(tbl$ci_lo_boot, tbl$estimate)
  expect_gt(tbl$ci_hi_boot, tbl$estimate)
})

# BOOT-02-delta: default estimate_total_catch has no boot columns ------------

test_that("BOOT-02-delta: estimate_total_catch default has no boot columns", {
  d <- .make_br_harvest_boot()
  result <- suppressWarnings(estimate_total_catch(d))
  tbl <- tidy(result)

  expect_false("ci_lo_boot" %in% names(tbl))
  expect_false("ci_hi_boot" %in% names(tbl))
})

# BOOT-01b: estimate_total_harvest bootstrap with by_vars (grouped path) ------

test_that("BOOT-01b: estimate_total_harvest bootstrap with by_vars returns boot columns per group", {
  d <- .make_br_harvest_boot()
  result <- suppressWarnings(estimate_total_harvest(d, by = day_type, ci_method = "bootstrap"))
  tbl <- tidy(result)

  expect_true("ci_lo_boot" %in% names(tbl))
  expect_true("ci_hi_boot" %in% names(tbl))
  expect_true(nrow(tbl) > 1L)
  expect_true(all(is.numeric(tbl$ci_lo_boot)))
  expect_true(all(is.numeric(tbl$ci_hi_boot)))
})

# BOOT-02b: estimate_total_catch bootstrap with by_vars (grouped path) -------

test_that("BOOT-02b: estimate_total_catch bootstrap with by_vars returns boot columns per group", {
  d <- .make_br_harvest_boot()
  result <- suppressWarnings(estimate_total_catch(d, by = day_type, ci_method = "bootstrap"))
  tbl <- tidy(result)

  expect_true("ci_lo_boot" %in% names(tbl))
  expect_true("ci_hi_boot" %in% names(tbl))
  expect_true(nrow(tbl) > 1L)
  expect_true(all(is.numeric(tbl$ci_lo_boot)))
  expect_true(all(is.numeric(tbl$ci_hi_boot)))
})
