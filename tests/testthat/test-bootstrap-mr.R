test_that("BOOT-03-chapman: estimate_angler_n Chapman bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  r <- estimate_angler_n(M = 200L, n = 50L, m = 10L, ci_method = "bootstrap")
  tbl <- tidy(r)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
  expect_true(is.numeric(attr(r, "boot_samples")))
  expect_equal(length(attr(r, "boot_samples")), 2000L)
})

test_that("BOOT-03-petersen: estimate_angler_n Petersen bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  r <- estimate_angler_n(M = 200L, n = 50L, m = 10L, method = "petersen", ci_method = "bootstrap")
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
    m = c(0L, 4L, 6L, 8L),
    method = "schnabel",
    ci_method = "bootstrap"
  )
  tbl <- tidy(r)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
})

test_that("BOOT-03-delta: estimate_angler_n default has no boot columns", {
  r <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  tbl <- tidy(r)
  expect_false("ci_lo_boot" %in% names(tbl))
  expect_false("ci_hi_boot" %in% names(tbl))
  expect_null(attr(r, "boot_samples"))
})

test_that("BOOT-04: estimate_mr_harvest bootstrap returns ci_lo_boot/ci_hi_boot", {
  set.seed(42L)
  angler_n <- estimate_angler_n(M = 200L, n = 50L, m = 10L, ci_method = "bootstrap")
  result <- estimate_mr_harvest(angler_n, harvest_rate = 0.35, ci_method = "bootstrap")
  tbl <- tidy(result)
  expect_true(all(c("ci_lo_boot", "ci_hi_boot", "ci_lower", "ci_upper") %in% names(tbl)))
  expect_true(all(tbl$ci_lo_boot < tbl$estimate))
  expect_true(all(tbl$estimate < tbl$ci_hi_boot))
})

test_that("BOOT-04-delta: estimate_mr_harvest default has no boot columns", {
  angler_n <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  result <- estimate_mr_harvest(angler_n, harvest_rate = 0.35)
  tbl <- tidy(result)
  expect_false("ci_lo_boot" %in% names(tbl))
})

test_that("BOOT-04-error: estimate_mr_harvest errors when boot_samples absent", {
  angler_n_delta <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  expect_error(
    estimate_mr_harvest(angler_n_delta, 0.35, ci_method = "bootstrap"),
    regexp = "ci_method = 'bootstrap' requires"
  )
})

# GH #209 -- every method must honour ci_method = "bootstrap" or refuse it ----

test_that("BOOT-06: every method either honours ci_method='bootstrap' or refuses it (GH #209)", {
  # Schumacher-Eschmeyer used to do neither: it appended no ci_lo_boot/ci_hi_boot
  # columns, attached no boot_samples, and raised nothing -- so an explicitly
  # requested inference method vanished, and estimate_mr_harvest() then aborted
  # telling the caller to do what they had already done.
  #
  # Written as a loop over every method rather than one test each, so a fifth
  # estimator cannot reintroduce the gap by simply not having a test written for
  # it. The contract is deliberately "honour OR refuse" -- silence is the bug.
  M_multi <- c(0, 50, 90, 120)
  n_multi <- c(60, 70, 65, 80)
  m_multi <- c(0, 8, 12, 15)

  call_for <- function(method) {
    if (method %in% c("schnabel", "schumacher")) {
      function() {
        estimate_angler_n(
          M = M_multi, n = n_multi, m = m_multi,
          method = method, ci_method = "bootstrap", B = 200L
        )
      }
    } else {
      function() {
        estimate_angler_n(
          M = 100, n = 80, m = 15,
          method = method, ci_method = "bootstrap", B = 200L
        )
      }
    }
  }

  for (method in c("chapman", "petersen", "schnabel", "schumacher")) {
    result <- tryCatch(suppressMessages(call_for(method)()), error = function(e) e)

    if (inherits(result, "error")) {
      # Refusal is acceptable, but it must be a deliberate, classed refusal
      # naming the problem -- not an incidental failure.
      expect_match(
        conditionMessage(result), "bootstrap",
        info = paste(method, "refused bootstrap without saying so")
      )
    } else {
      # Honoured: the extra columns AND the samples estimate_mr_harvest() reads.
      expect_true(
        all(c("ci_lo_boot", "ci_hi_boot") %in% names(result$estimates)),
        info = paste(method, "accepted ci_method='bootstrap' but returned no boot columns")
      )
      expect_false(
        is.null(attr(result, "boot_samples")),
        info = paste(method, "accepted ci_method='bootstrap' but attached no boot_samples")
      )
    }
  }
})

test_that("BOOT-06-schumacher: the refusal is classed and points somewhere useful (GH #209)", {
  expect_error(
    estimate_angler_n(
      M = c(0, 50, 90, 120), n = c(60, 70, 65, 80), m = c(0, 8, 12, 15),
      method = "schumacher", ci_method = "bootstrap"
    ),
    class = "creel_error_schumacher_no_bootstrap"
  )
})

test_that("BOOT-06-schumacher: logit and delta both return the regression interval (GH #209)", {
  # The refusal must not cost the method its ordinary intervals. Schumacher has
  # one interval -- Seber (1982) eq. 4.17 on 1/N_hat -- so the two settings agree
  # here by construction, and that is the documented behaviour rather than an
  # accident worth preserving silently.
  args <- list(M = c(0, 50, 90, 120), n = c(60, 70, 65, 80), m = c(0, 8, 12, 15),
               method = "schumacher")
  a <- do.call(estimate_angler_n, c(args, list(ci_method = "logit")))
  b <- do.call(estimate_angler_n, c(args, list(ci_method = "delta")))
  expect_identical(a$estimates, b$estimates)
  expect_true(is.finite(a$estimates$ci_lower))
})
