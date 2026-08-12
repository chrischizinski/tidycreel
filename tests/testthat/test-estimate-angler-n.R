# Chapman reference values
M_c <- 200L
n_c <- 50L
m_c <- 10L
N_hat_c <- ((M_c + 1) * (n_c + 1)) / (m_c + 1) - 1
var_N_c <- ((M_c + 1) * (n_c + 1) * (M_c - m_c) * (n_c - m_c)) /
  ((m_c + 2) * (m_c + 1)^2)
se_N_c <- sqrt(var_N_c)

# Petersen reference values
N_hat_p <- (M_c * n_c) / m_c # 200*50/10 = 1000

# Schnabel reference values (sum_m = 18 < 50 => Poisson CI branch)
M_s <- c(0L, 47L, 91L, 131L)
n_s <- c(50L, 50L, 50L, 50L)
m_s <- c(0L, 4L, 6L, 8L)
sum_Mn_s <- sum(M_s * n_s) # 0+2350+4550+6550 = 13450
sum_m_s <- sum(m_s) # 0+4+6+8 = 18
# Default is Chapman's (1952) small-sample correction, Dettloff (2023) eq. (6).
N_hat_s <- sum_Mn_s / (sum_m_s + 1) # 707.894...
N_hat_s_unadj <- sum_Mn_s / sum_m_s # 747.222...
se_inv_s <- sqrt(sum_m_s / sum_Mn_s^2)
se_N_s <- N_hat_s^2 * se_inv_s

# --- MR-01: Chapman estimator ---

test_that("Test A: Chapman N_hat matches ((M+1)(n+1)/(m+1))-1", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c)
  expect_equal(result$estimates$estimate, N_hat_c, tolerance = 1e-10)
})

test_that("Test B: Chapman SE matches sqrt(((M+1)(n+1)(M-m)(n-m))/((m+2)(m+1)^2))", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c)
  expect_equal(result$estimates$se, se_N_c, tolerance = 1e-10)
})

test_that("Test C: Chapman CI satisfies ci_lower <= estimate <= ci_upper", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c)
  expect_true(result$estimates$ci_lower <= result$estimates$estimate)
  expect_true(result$estimates$estimate <= result$estimates$ci_upper)
})

test_that("Test D: Chapman conf_level=0.90 gives narrower CI than conf_level=0.95", {
  result_95 <- estimate_angler_n(M = M_c, n = n_c, m = m_c, conf_level = 0.95)
  result_90 <- estimate_angler_n(M = M_c, n = n_c, m = m_c, conf_level = 0.90)
  expect_true(result_90$estimates$ci_upper < result_95$estimates$ci_upper)
})

test_that("Test E: Chapman returns class creel_estimates with method mark-recapture-chapman", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c)
  expect_s3_class(result, "creel_estimates")
  expect_equal(result$method, "mark-recapture-chapman")
})

test_that("Test F: Chapman estimates tibble has columns parameter, estimate, se, ci_lower, ci_upper, n", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c)
  expect_named(result$estimates, c("parameter", "estimate", "se", "ci_lower", "ci_upper", "n"))
})

# --- MR-01b: Sadinle transformed logit interval (default since 3.0.0) ---

test_that("Test P: logit lower bound never falls below the individuals observed", {
  # This is the property the interval is chosen for. Sadinle (2009) p.1923:
  # the .5 transformed logit lower limit can never be less than
  # n11 + n12 + n21 = M + n - m, the number of distinct individuals actually
  # handled. The Wald interval it replaces has no such guarantee -- it returns
  # -2124.8 at m = 3, and 48.7 at m = 5 against 245 observed. A test that only
  # checked non-negativity would miss the m = 5 case entirely.
  for (M in c(20L, 50L, 200L, 500L)) {
    for (n in c(10L, 50L, 200L)) {
      for (m in seq_len(min(M, n))) {
        result <- estimate_angler_n(M = M, n = n, m = m)
        expect_gte(result$estimates$ci_lower, M + n - m)
      }
    }
  }
})

test_that("Test Q: logit bounds match Sadinle (2009) sec. 5 computed by hand", {
  # M = 200, n = 50, m = 3 gives the 2x2 table n11 = 3, n12 = 197, n21 = 47.
  # With c = .5: se(log OR) = sqrt(1/3.5 + 1/197.5 + 1/47.5 + 3.5/(197.5*47.5)),
  # n22_hat = 197.5*47.5/3.5, and the N bounds add back the 247 observed.
  cc <- 0.5
  se_log_or <- sqrt(1 / 3.5 + 1 / 197.5 + 1 / 47.5 + 3.5 / (197.5 * 47.5))
  n22_hat <- 197.5 * 47.5 / 3.5
  z <- qnorm(0.975)
  expected_lo <- n22_hat * exp(-z * se_log_or) - cc + 247
  expected_hi <- n22_hat * exp(z * se_log_or) - cc + 247

  result <- estimate_angler_n(M = 200L, n = 50L, m = 3L)
  expect_equal(result$estimates$ci_lower, expected_lo, tolerance = 1e-9)
  expect_equal(result$estimates$ci_upper, expected_hi, tolerance = 1e-9)
  expect_equal(result$estimates$ci_lower, 1143.0653, tolerance = 1e-4)
})

test_that("Test R: ci_method = 'delta' reproduces the pre-3.0.0 Wald bounds", {
  # The escape hatch must be exact, not merely similar -- anyone pinning a
  # published number needs the old values back unchanged.
  result <- estimate_angler_n(M = 200L, n = 50L, m = 3L, ci_method = "delta")
  expect_equal(result$estimates$ci_lower, -2124.8, tolerance = 1e-4)
  expect_equal(result$estimates$ci_upper, 7248.3, tolerance = 1e-4)
  expect_lt(result$estimates$ci_lower, 0) # the defect, retained deliberately
})

test_that("Test S: saturated m == n puts the logit lower bound above N_hat", {
  # Every individual in the second sample was already marked, so the estimator
  # saturates at N_hat = M and the data imply N > M rather than N = M. The
  # lower limit sitting fractionally above the point estimate is the interval
  # being informative at a boundary; it is pinned so the behaviour stays
  # deliberate. Documented under @details.
  result <- estimate_angler_n(M = 500L, n = 10L, m = 10L)
  expect_equal(result$estimates$estimate, 500)
  expect_gt(result$estimates$ci_lower, result$estimates$estimate)
  expect_gte(result$estimates$ci_lower, 500) # never below the observed count
})

# --- MR-02: Petersen estimator ---

test_that("Test G: Petersen N_hat matches M*n/m", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c, method = "petersen")
  expect_equal(result$estimates$estimate, N_hat_p, tolerance = 1e-10)
})

test_that("Test H: Petersen m<7 fires error matching 'too small for the Petersen'", {
  expect_error(
    estimate_angler_n(M = 200L, n = 50L, m = 6L, method = "petersen"),
    regexp = "too small for the Petersen"
  )
})

test_that("Test I: Petersen m>=7 succeeds without error", {
  expect_no_error(
    estimate_angler_n(M = 200L, n = 50L, m = 10L, method = "petersen")
  )
})

test_that("Test J: Petersen returns method mark-recapture-petersen", {
  result <- estimate_angler_n(M = M_c, n = n_c, m = m_c, method = "petersen")
  expect_equal(result$method, "mark-recapture-petersen")
})

# --- MR-03: Schnabel estimator ---

test_that("Test K: Schnabel N_hat carries Chapman's +1 correction by default", {
  # Dettloff (2023) eq. (6). Two reasons this is the default rather than opt-in.
  # First, the unadjusted form turns biased *high* at moderate sample sizes,
  # which propagates into an inflated harvest estimate; the adjusted form's bias
  # "approaches zero ... without ever becoming positive". Second, Schnabel
  # reduces to Lincoln-Petersen at K = 2, so an unadjusted Schnabel made bias
  # handling depend on occasion count while method = "chapman" already carried
  # the +1 at two occasions. See finding 32 in AUDIT-dimensional-seams.md.
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  expect_equal(result$estimates$estimate, N_hat_s, tolerance = 1e-10)
  # The correction is exactly -1/(sum(m) + 1) in relative terms. Pinning the
  # ratio fails if the +1 is ever moved into se_inv or the numerator instead.
  expect_equal(
    result$estimates$estimate / N_hat_s_unadj,
    sum_m_s / (sum_m_s + 1),
    tolerance = 1e-12
  )
})

test_that("Test K2: bias_adjust = FALSE restores the pre-3.0.0 unadjusted form", {
  # The escape hatch must reproduce sum(M*n)/sum(m) exactly, since that is the
  # form fishmethods::schnabel() computes and every cross-check against it (see
  # Test N2) depends on this path staying bit-for-bit unadjusted.
  result <- estimate_angler_n(
    M = M_s, n = n_s, m = m_s, method = "schnabel", bias_adjust = FALSE
  )
  expect_equal(result$estimates$estimate, N_hat_s_unadj, tolerance = 1e-10)
})

test_that("Test L: Schnabel SE is in N scale (se > 1, not near 0)", {
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  expect_equal(result$estimates$se, se_N_s, tolerance = 1e-10)
  expect_true(result$estimates$se > 1)
})

test_that("Test L2: bias_adjust leaves Var(1/N_hat) alone and rescales se only via the Jacobian", {
  # 1/N_hat_adj = 1/N_hat_unadj + 1/sum(M*n) -- a shift by a constant, so the
  # variance of 1/N_hat is identical under both forms. se_N differs only because
  # the delta-method Jacobian N_hat^2 is evaluated at a different point. If
  # someone ever keys se_inv to sum(m) + 1, this ratio breaks.
  adj <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  unadj <- estimate_angler_n(
    M = M_s, n = n_s, m = m_s, method = "schnabel", bias_adjust = FALSE
  )
  expect_equal(
    adj$estimates$se / unadj$estimates$se,
    (N_hat_s / N_hat_s_unadj)^2,
    tolerance = 1e-12
  )
})

test_that("Test M: Schnabel Poisson CI branch fires when sum(m) < 50 (ci_lower < N_hat < ci_upper)", {
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  # sum_m_s = 18 < 50, so Poisson branch should be used
  expect_true(sum(m_s) < 50L)
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

test_that("Test M2: the Poisson branch inverts sum(m) and so is identical under both bias_adjust settings", {
  # This branch is an inversion interval for N built from the Poisson
  # distribution of sum(m), not an interval centred on N_hat. It is therefore
  # valid under either estimator and is deliberately left unadjusted -- the
  # point estimate moves, the bounds do not. Contrast Test N3, where the t
  # branch *is* built around 1/N_hat and does follow the correction.
  adj <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  unadj <- estimate_angler_n(
    M = M_s, n = n_s, m = m_s, method = "schnabel", bias_adjust = FALSE
  )
  expect_identical(adj$estimates$ci_lower, unadj$estimates$ci_lower)
  expect_identical(adj$estimates$ci_upper, unadj$estimates$ci_upper)
  expect_false(adj$estimates$estimate == unadj$estimates$estimate)
})

test_that("Test M3: the adjusted point estimate stays inside the unadjusted Poisson interval across sum(m)", {
  # Leaving the Poisson bounds unadjusted is only defensible if the adjusted
  # N_hat cannot fall outside them. It cannot: the upper recapture quantile
  # exceeds sum(m) + 1 for every sum(m) >= 1, so sum(M*n)/(sum(m)+1) stays above
  # the lower bound. Swept rather than spot-checked because the Poisson
  # quantiles are step functions and a single fixture would not catch a
  # boundary failure at very small sum(m).
  for (k in c(1, 2, 3, 5, 9, 18, 30, 49)) {
    # At k <= 3 the lower Poisson quantile is 0 and ci_upper is Inf by design,
    # which warns. That is the documented behaviour and finding 30's subject,
    # not a failure of the containment property being checked here.
    r <- suppressWarnings(estimate_angler_n(
      M = c(0, 500), n = c(500, 500), m = c(0, k), method = "schnabel"
    ))
    expect_gt(r$estimates$estimate, r$estimates$ci_lower)
    expect_lt(r$estimates$estimate, r$estimates$ci_upper)
  }
})

test_that("Test N: Schnabel normal CI branch fires when sum(m) >= 50", {
  M_s2 <- c(0L, 100L, 200L, 300L, 400L)
  n_s2 <- c(100L, 100L, 100L, 100L, 100L)
  m_s2 <- c(0L, 10L, 12L, 14L, 16L) # sum(m) = 52 >= 50
  expect_true(sum(m_s2) >= 50L)
  result <- estimate_angler_n(M = M_s2, n = n_s2, m = m_s2, method = "schnabel")
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

test_that("Test N2: Schnabel t-branch df is occasions - 1, matching Hansen & Van Kirk (A.5)", {
  # The t quantile must be keyed to the number of sampling occasions, not to
  # the recapture total. Recaptures within one occasion are not independent
  # observations of the ratio, so df = sum(m) - 1 understates the interval.
  # Reference values are fishmethods::schnabel(catch = n, recaps = m,
  # newmarks = rep(100, 5)), the implementation Hansen & Van Kirk (2018)
  # modified; their eq. (A.5) gives the same t_{alpha/2, S-1}. Hard-coded
  # rather than computed so this fails if the df is ever keyed to sum(m)
  # again, which returns [1504.282, 2665.024] -- a 33% narrower interval.
  #
  # Pinned on bias_adjust = FALSE because fishmethods::schnabel() computes the
  # unadjusted estimator: this is the cross-implementation anchor, and it only
  # holds if the escape hatch stays exactly unadjusted. The adjusted default is
  # checked separately in Test N3.
  M_s2 <- c(0L, 100L, 200L, 300L, 400L)
  n_s2 <- c(100L, 100L, 100L, 100L, 100L)
  m_s2 <- c(0L, 10L, 12L, 14L, 16L) # 5 occasions, sum(m) = 52
  result <- estimate_angler_n(
    M = M_s2, n = n_s2, m = m_s2, method = "schnabel", bias_adjust = FALSE
  )
  expect_equal(result$estimates$estimate, 1923.0769, tolerance = 1e-4)
  expect_equal(result$estimates$ci_lower, 1388.4790, tolerance = 1e-4)
  expect_equal(result$estimates$ci_upper, 3127.0750, tolerance = 1e-4)
})

test_that("Test N3: the t branch is centred on 1/N_hat and so follows bias_adjust", {
  # The t interval is built from 1/N_hat +/- z * se_inv, so unlike the Poisson
  # branch (Test M2) the correction must move the bounds too -- otherwise the
  # reported estimate would sit off-centre in its own interval. Reference values
  # computed by hand from sum(M*n) = 100000, sum(m) = 52, df = 4:
  #   1/N = 53/100000, se_inv = sqrt(52)/100000, t = qt(0.975, 4) = 2.7764451
  M_s2 <- c(0L, 100L, 200L, 300L, 400L)
  n_s2 <- c(100L, 100L, 100L, 100L, 100L)
  m_s2 <- c(0L, 10L, 12L, 14L, 16L)
  result <- estimate_angler_n(M = M_s2, n = n_s2, m = m_s2, method = "schnabel")
  expect_equal(result$estimates$estimate, 100000 / 53, tolerance = 1e-9)
  inv_n <- 53 / 100000
  se_inv <- sqrt(52) / 100000
  tq <- stats::qt(0.975, df = 4)
  expect_equal(result$estimates$ci_lower, 1 / (inv_n + tq * se_inv), tolerance = 1e-9)
  expect_equal(result$estimates$ci_upper, 1 / (inv_n - tq * se_inv), tolerance = 1e-9)
  # and the bounds must differ from the unadjusted ones pinned in Test N2
  expect_false(isTRUE(all.equal(result$estimates$ci_lower, 1388.4790, tolerance = 1e-4)))
})

test_that("Test O: Schnabel returns method mark-recapture-schnabel", {
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  expect_equal(result$method, "mark-recapture-schnabel")
})

# --- MR-04: input guards ---

test_that("Test P: m=0 fires error for Chapman", {
  expect_error(
    estimate_angler_n(M = 200L, n = 50L, m = 0L),
    regexp = "m.*0|m.*must be"
  )
})

test_that("Test Q: m>n fires error for Chapman", {
  expect_error(
    estimate_angler_n(M = 200L, n = 10L, m = 15L),
    regexp = "m.*cannot exceed.*n|cannot exceed.*n"
  )
})

test_that("Test R: m>M fires error for Chapman", {
  expect_error(
    estimate_angler_n(M = 5L, n = 50L, m = 10L),
    regexp = "m.*cannot exceed.*M|cannot exceed.*M"
  )
})

test_that("Test S: Schnabel unequal vector lengths fires error", {
  expect_error(
    estimate_angler_n(M = c(0L, 47L, 91L), n = c(50L, 50L), m = c(0L, 4L), method = "schnabel"),
    regexp = "same length"
  )
})

test_that("Test T: Schnabel K<2 fires error", {
  expect_error(
    estimate_angler_n(M = c(0L), n = c(50L), m = c(0L), method = "schnabel"),
    regexp = "Schnabel requires"
  )
})

# --- MR-05: S3 compatibility with compare_designs() and autoplot() ---

test_that("Test U: compare_designs() accepts two Chapman results without error", {
  r_a <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  r_b <- estimate_angler_n(M = 300L, n = 80L, m = 15L)
  expect_no_error(compare_designs(list(a = r_a, b = r_b)))
})

test_that("Test V: autoplot() accepts Chapman result without error", {
  r <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
  expect_no_error(autoplot(r))
})

test_that("Test W: @examples smoke — estimate_angler_n(M=200, n=50, m=10) completes without error", {
  expect_no_error(estimate_angler_n(M = 200L, n = 50L, m = 10L))
})

# --- WARNING-02 fix: Schnabel ci_hi guard for lo_m = 0 ---

test_that("Test X: Schnabel warns and returns ci_hi = Inf when lo_m = 0", {
  # sum_m = 1 => qpois(0.025, 1) = 0 => lo_m = 0 => ci_hi = Inf
  expect_warning(
    result <- estimate_angler_n(
      M = c(0L, 10L),
      n = c(5L, 5L),
      m = c(0L, 1L),
      method = "schnabel"
    ),
    regexp = "ci_hi set to Inf"
  )
  expect_true(is.infinite(result$estimates$ci_upper))
})
