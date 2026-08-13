# Length-weight regression error in est_biomass() (GH #117)
#
# a and b are point estimates from a regression, and a * L^b multiplies every
# length bin, so their error is perfectly correlated across bins and does not
# shrink as bins are added. These tests pin the size of the term, the pivot
# behaviour that lets the parameter covariance be dropped by construction, and
# that the term stays absent rather than zero when it is not supplied.

biomass_ld <- function() {
  ld <- data.frame(
    bin_lower = c(100, 200, 300),
    bin_upper = c(200, 300, 400),
    estimate = c(1000, 500, 200),
    se = c(100, 60, 30),
    stringsAsFactors = FALSE
  )
  class(ld) <- c("creel_length_distribution", "data.frame")
  attr(ld, "conf_level") <- 0.95
  ld
}

test_that("the parameter term matches the delta method by hand", {
  ld <- biomass_ld()
  a <- 0.0088
  b <- 3.1
  l0 <- 250

  result <- est_biomass(ld, a = a, b = b, alpha_se = 0.05, b_se = 0.03, L0 = l0)

  l_mid <- c(150, 250, 350)
  w_h <- a * l_mid^b
  biomass <- sum(w_h * ld$estimate)
  alpha <- a * l0^b
  d_alpha <- biomass / alpha
  d_b <- sum(w_h * ld$estimate * log(l_mid / l0))
  expected <- sqrt(d_alpha^2 * 0.05^2 + d_b^2 * 0.03^2)

  expect_equal(attr(result, "biomass_se_params"), expected)
})

test_that("propagating the parameter error moves only the SE, not the estimate", {
  ld <- biomass_ld()
  without <- est_biomass(ld, a = 0.0088, b = 3.1)
  with_p <- est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03, L0 = 250)

  expect_equal(with_p$biomass_estimate, without$biomass_estimate)
  expect_gt(with_p$biomass_se, without$biomass_se)
  expect_equal(
    with_p$biomass_se,
    sqrt(without$biomass_se^2 + attr(with_p, "biomass_se_params")^2)
  )
})

test_that("the component is absent, not zero, when nothing is supplied", {
  # A zero would be indistinguishable from a propagated term that contributed
  # nothing, which is the claim this function must not make silently.
  result <- est_biomass(biomass_ld(), a = 0.0088, b = 3.1)

  expect_null(attr(result, "biomass_se_params"))
  expect_null(attr(result, "L0"))
})

test_that("the three uncertainty arguments are all-or-nothing", {
  ld <- biomass_ld()

  expect_error(
    est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05),
    "must be given together"
  )
  expect_error(
    est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03),
    "must be given together"
  )
  # L0 alone propagates nothing, so it is just as incomplete.
  expect_error(
    est_biomass(ld, a = 0.0088, b = 3.1, L0 = 250),
    "must be given together"
  )
})

test_that("the exponent contribution vanishes at the biomass-weighted pivot", {
  # This is the property that makes the parameterisation worth its extra
  # argument: at the pivot the exponent's leverage on total biomass is zero, so
  # the two parameters are near-orthogonal and their covariance is negligible.
  ld <- biomass_ld()
  a <- 0.0088
  b <- 3.1
  l_mid <- c(150, 250, 350)
  bin_biomass <- a * l_mid^b * ld$estimate

  # The L0 at which sum(B_h * log(L_h / L0)) == 0
  pivot <- exp(sum(bin_biomass * log(l_mid)) / sum(bin_biomass))

  at_pivot <- est_biomass(ld, a = a, b = b, alpha_se = 0.05, b_se = 0.03, L0 = pivot)
  off_pivot <- est_biomass(ld, a = a, b = b, alpha_se = 0.05, b_se = 0.03, L0 = pivot * 3)

  # b_se contributes nothing at the pivot: the whole term is the alpha part.
  biomass <- sum(bin_biomass)
  alpha_at_pivot <- a * pivot^b
  expect_equal(
    attr(at_pivot, "biomass_se_params"),
    (biomass / alpha_at_pivot) * 0.05
  )

  # Away from it the exponent term reappears and the component grows.
  expect_gt(
    attr(off_pivot, "biomass_se_params"),
    attr(at_pivot, "biomass_se_params")
  )
})

test_that("borrowing parameters from differently sized fish costs more", {
  # The contribution scales with ln(L_h / L0), so a pivot far from these fish --
  # which is what borrowing from another system means -- is penalised. That is
  # the intended behaviour, not an artefact.
  ld <- biomass_ld()
  near <- est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03, L0 = 250)
  far <- est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03, L0 = 25)

  expect_gt(attr(far, "biomass_se_params"), attr(near, "biomass_se_params"))
})

test_that("a zero parameter SE is accepted but a negative one is not", {
  ld <- biomass_ld()

  # Zero is a legitimate user statement ("this parameter is fixed by fiat"),
  # unlike a zero arrived at by default, so it is allowed when explicit.
  zeroed <- est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0, b_se = 0, L0 = 250)
  expect_equal(attr(zeroed, "biomass_se_params"), 0)
  expect_false(is.null(attr(zeroed, "biomass_se_params")))

  expect_error(
    est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = -0.05, b_se = 0.03, L0 = 250),
    "must not be negative"
  )
  expect_error(
    est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03, L0 = 0),
    "greater than zero"
  )
  expect_error(
    est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = NA_real_, b_se = 0.03, L0 = 250),
    "single finite number"
  )
})

test_that("grouped biomass carries one parameter component per group", {
  ld <- data.frame(
    species = rep(c("bass", "walleye"), each = 3),
    bin_lower = rep(c(100, 200, 300), 2),
    bin_upper = rep(c(200, 300, 400), 2),
    estimate = c(1000, 500, 200, 300, 400, 100),
    se = c(100, 60, 30, 40, 50, 20),
    stringsAsFactors = FALSE
  )
  class(ld) <- c("creel_length_distribution", "data.frame")
  attr(ld, "conf_level") <- 0.95
  attr(ld, "by_vars") <- "species"

  result <- est_biomass(ld, a = 0.0088, b = 3.1, alpha_se = 0.05, b_se = 0.03, L0 = 250)

  expect_length(attr(result, "biomass_se_params"), 2L)
  expect_equal(
    result$biomass_se,
    sqrt(
      vapply(seq_len(2), function(i) {
        rows <- ld[ld$species == unique(ld$species)[i], , drop = FALSE]
        l_mid <- (rows$bin_lower + rows$bin_upper) / 2
        sum((0.0088 * l_mid^3.1)^2 * rows$se^2)
      }, numeric(1)) +
        attr(result, "biomass_se_params")^2
    )
  )
})
