# Chapman reference values
M_c <- 200L; n_c <- 50L; m_c <- 10L
N_hat_c <- ((M_c + 1) * (n_c + 1)) / (m_c + 1) - 1
var_N_c  <- ((M_c + 1) * (n_c + 1) * (M_c - m_c) * (n_c - m_c)) /
              ((m_c + 2) * (m_c + 1)^2)
se_N_c   <- sqrt(var_N_c)

# Petersen reference values
N_hat_p <- (M_c * n_c) / m_c    # 200*50/10 = 1000

# Schnabel reference values (sum_m = 18 < 50 => Poisson CI branch)
M_s <- c(0L, 47L, 91L, 131L)
n_s <- c(50L, 50L, 50L, 50L)
m_s <- c(0L,  4L,  6L,  8L)
sum_Mn_s <- sum(M_s * n_s)   # 0+2350+4550+6550 = 13450
sum_m_s  <- sum(m_s)         # 0+4+6+8 = 18
N_hat_s  <- sum_Mn_s / sum_m_s  # 747.222...
se_inv_s <- sqrt(sum_m_s / sum_Mn_s^2)
se_N_s   <- N_hat_s^2 * se_inv_s

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

test_that("Test K: Schnabel N_hat matches sum(M*n)/sum(m)", {
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  expect_equal(result$estimates$estimate, N_hat_s, tolerance = 1e-10)
})

test_that("Test L: Schnabel SE is in N scale (se > 1, not near 0)", {
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  expect_equal(result$estimates$se, se_N_s, tolerance = 1e-10)
  expect_true(result$estimates$se > 1)
})

test_that("Test M: Schnabel Poisson CI branch fires when sum(m) < 50 (ci_lower < N_hat < ci_upper)", {
  result <- estimate_angler_n(M = M_s, n = n_s, m = m_s, method = "schnabel")
  # sum_m_s = 18 < 50, so Poisson branch should be used
  expect_true(sum(m_s) < 50L)
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

test_that("Test N: Schnabel normal CI branch fires when sum(m) >= 50", {
  M_s2 <- c(0L,  100L, 200L, 300L, 400L)
  n_s2 <- c(100L, 100L, 100L, 100L, 100L)
  m_s2 <- c(0L,   10L,  12L,  14L,  16L)   # sum(m) = 52 >= 50
  expect_true(sum(m_s2) >= 50L)
  result <- estimate_angler_n(M = M_s2, n = n_s2, m = m_s2, method = "schnabel")
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
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
      M = c(0L, 10L), n = c(5L, 5L), m = c(0L, 1L), method = "schnabel"
    ),
    regexp = "ci_hi set to Inf"
  )
  expect_true(is.infinite(result$estimates$ci_upper))
})
