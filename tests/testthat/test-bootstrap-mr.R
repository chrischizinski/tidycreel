test_that("BOOT-03-chapman: estimate_angler_n Chapman bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  r   <- estimate_angler_n(M = 200L, n = 50L, m = 10L, ci_method = "bootstrap")
  tbl <- tidy(r)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
  expect_true(is.numeric(attr(r, "boot_samples")))
  expect_equal(length(attr(r, "boot_samples")), 2000L)
})

test_that("BOOT-03-petersen: estimate_angler_n Petersen bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  r   <- estimate_angler_n(M = 200L, n = 50L, m = 10L, method = "petersen", ci_method = "bootstrap")
  tbl <- tidy(r)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
})

test_that("BOOT-03-schnabel: estimate_angler_n Schnabel bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  r <- estimate_angler_n(
    M = c(0L, 200L, 300L, 400L),
    n = c(50L, 50L, 50L, 50L),
    m = c(0L,  4L,  6L,  8L),
    method    = "schnabel",
    ci_method = "bootstrap"
  )
  tbl <- tidy(r)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
})

test_that("BOOT-03-delta: estimate_angler_n default has no boot columns", {
  r   <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  tbl <- tidy(r)
  expect_false("ci_lo_boot" %in% names(tbl))
  expect_false("ci_hi_boot" %in% names(tbl))
  expect_null(attr(r, "boot_samples"))
})

test_that("BOOT-04: estimate_mr_harvest bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  angler_n <- estimate_angler_n(M = 200L, n = 50L, m = 10L, ci_method = "bootstrap")
  result   <- estimate_mr_harvest(angler_n, harvest_rate = 0.35, ci_method = "bootstrap")
  tbl      <- tidy(result)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
})

test_that("BOOT-04-delta: estimate_mr_harvest default has no boot columns", {
  angler_n <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  result   <- estimate_mr_harvest(angler_n, harvest_rate = 0.35)
  tbl      <- tidy(result)
  expect_false("ci_lo_boot" %in% names(tbl))
})

test_that("BOOT-04-error: estimate_mr_harvest errors when boot_samples absent", {
  angler_n_delta <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  expect_error(
    estimate_mr_harvest(angler_n_delta, 0.35, ci_method = "bootstrap"),
    regexp = "ci_method = 'bootstrap' requires"
  )
})
