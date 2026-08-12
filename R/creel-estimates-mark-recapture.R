# Mark-Recapture Estimation Functions ----

#' Lower-tail quantile of Ilienko's continuous Poisson distribution
#'
#' Ilienko (2013) Definition 3.1: the continuous Poisson with parameter
#' \eqn{\lambda} has distribution function \eqn{F(x) = \Gamma(x, \lambda)/\Gamma(x)}
#' for \eqn{x > 0}. This is the genuine continuous interpolant of the discrete
#' Poisson, not a nearby gamma: Ilienko's eq. (1) shows the same expression gives
#' the discrete CDF \eqn{P(X < x)} at integer \eqn{x}, which the tests pin.
#'
#' Hansen & Van Kirk (2018) use it to replace a zero Poisson quantile, which
#' would otherwise send the Schnabel upper bound to infinity.
#'
#' The quantile sits in the *shape* argument of `pgamma()`, so it has no
#' closed form and must be solved for. That is the trap the source paper fell
#' into — their worked example reports `qgamma(0.025, shape = 2) = 0.24`, the
#' quantile of a Gamma(2, 1) variate, where inverting their own eq. (A.4) at
#' \eqn{\lambda = 2} gives 0.3292. Equation A.4 is a faithful transcription of
#' Ilienko; the example and Figure A.1 are not. See finding 30 in
#' AUDIT-dimensional-seams.md.
#'
#' @param p Lower-tail probability.
#' @param lambda Poisson parameter, > 0.
#' @return Numeric(1), the value x with `Gamma(x, lambda)/Gamma(x) == p`.
#' @noRd
.continuous_poisson_q <- function(p, lambda) {
  # F is increasing in x from 0 to 1, so the root is unique. The upper bracket
  # grows with lambda; lambda + 10 clears it comfortably for any p < 1 in the
  # range this is called on (lambda = sum(m) < 50).
  cdf <- function(x) stats::pgamma(lambda, shape = x, lower.tail = FALSE) - p
  stats::uniroot(cdf, lower = 1e-10, upper = lambda + 10, tol = .Machine$double.eps^0.5)$root
}

#' Sadinle's 0.5 transformed logit interval for a two-sample capture table
#'
#' Sadinle (2009) sec. 5. The two-sample experiment is a 2x2 table with
#' \eqn{n_{11} = m} seen twice, \eqn{n_{12} = M - m} marked but not recaptured,
#' \eqn{n_{21} = n - m} caught only in the second sample, and \eqn{n_{22}}
#' unobserved. Under independence the odds ratio is 1, so a logit interval for
#' the odds ratio transforms into one for \eqn{n_{22}}; adding the observed
#' count back gives the interval for \eqn{N}.
#'
#' Adding \code{cc} to every cell is what makes this always computable — no
#' cell count can drive a division by zero — and it is why the lower limit can
#' never fall below the number of individuals actually observed.
#'
#' @param M,n,m Marked released, second-sample size, recaptures.
#' @param conf_level Confidence level.
#' @param cc Continuity correction added to each cell. Sadinle's 0.5.
#' @return Numeric vector of length 2, `c(lower, upper)`.
#' @noRd
.mr_logit_ci <- function(M, n, m, conf_level, cc = 0.5) {
  n11 <- m
  n12 <- M - m
  n21 <- n - m
  observed <- n11 + n12 + n21

  se_log_or <- sqrt(
    1 / (n11 + cc) + 1 / (n12 + cc) + 1 / (n21 + cc) +
      (n11 + cc) / ((n12 + cc) * (n21 + cc))
  )
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  n22_hat <- (n12 + cc) * (n21 + cc) / (n11 + cc)

  # n22 is a count of individuals never seen, so its lower bound cannot be
  # negative. Clamping at zero is the parameter-space boundary, not a fudge,
  # and it is what makes Sadinle's stated guarantee hold exactly: the lower
  # limit for N is then never below the observed count. Without it the bound
  # dips a few tenths under `observed` in saturated corners such as
  # M = 500, n = 10, m = 9, where n22_hat * exp(-z * se) falls below cc.
  c(
    max(0, n22_hat * exp(-z * se_log_or) - cc) + observed,
    n22_hat * exp(z * se_log_or) - cc + observed
  )
}

#' Estimate angler population size via closed-population mark-recapture
#'
#' @description
#' Computes a closed-population mark-recapture estimate of total angler
#' population size (N_hat) using one of three estimators:
#'
#' \itemize{
#'   \item \strong{Chapman} (default, \code{method = "chapman"}): A bias-corrected
#'     version of the Petersen estimator recommended when recaptures are small.
#'     \eqn{\hat{N} = \frac{(M+1)(n+1)}{(m+1)} - 1}
#'   \item \strong{Petersen} (\code{method = "petersen"}): The unadjusted
#'     Lincoln-Petersen estimator. Requires at least 7 recaptures (\eqn{m \geq 7})
#'     to avoid large positive bias; use Chapman for smaller recapture counts.
#'     \eqn{\hat{N} = \frac{M \cdot n}{m}}
#'   \item \strong{Schnabel} (\code{method = "schnabel"}): A multi-occasion
#'     weighted estimator for \eqn{K \geq 2} sampling occasions, carrying
#'     Chapman's (1952) small-sample correction by default.
#'     \eqn{\hat{N} = \frac{\sum M_k n_k}{\sum m_k + 1}}
#'     CI uses the Poisson branch when \eqn{\sum m_k < 50} and the normal
#'     approximation on \eqn{1/\hat{N}} otherwise, on \eqn{K - 1} degrees of
#'     freedom (Hansen & Van Kirk 2018, eq. A.5).
#'   \item \strong{Schumacher-Eschmeyer} (\code{method = "schumacher"}): The
#'     regression alternative to Schnabel for \eqn{K \geq 3} occasions, fitting
#'     \eqn{m_k/n_k} against \eqn{M_k} through the origin with slope \eqn{1/N}.
#'     \eqn{\hat{N} = \frac{\sum n_k M_k^2}{\sum m_k M_k}}
#'     Interval from Seber (1982) eq. (4.17) on \eqn{K - 2} degrees of freedom.
#'     Also carries Dettloff's (2023) eq. (8) small-sample correction by default.
#' }
#'
#' @param M integer or numeric. Number of marked animals released (first sample).
#'   For \code{method = "schnabel"}, a vector of cumulative marked-at-large
#'   counts before each sampling occasion (\code{M[1] = 0}).
#' @param n integer or numeric. Number captured in second sample. For Schnabel,
#'   a vector of per-occasion catch counts (same length as \code{M}).
#' @param m integer or numeric. Number of recaptures. Scalar for Chapman and
#'   Petersen; vector (same length as \code{M}) for Schnabel.
#' @param method character(1). One of \code{"chapman"} (default),
#'   \code{"petersen"}, \code{"schnabel"}, or \code{"schumacher"}.
#' @param conf_level numeric. Confidence level for the CI. Default \code{0.95}.
#' @param ci_method character(1). CI construction for the Chapman and Petersen
#'   branches: \code{"logit"} (default) is Sadinle's (2009) 0.5 transformed logit
#'   interval; \code{"delta"} is the symmetric Wald interval
#'   \eqn{\hat{N} \pm t_{\alpha/2,\,m-1} SE(\hat{N})} that was the default before
#'   3.0.0; \code{"bootstrap"} keeps the \code{"logit"} bounds and additionally
#'   appends \code{ci_lo_boot} and \code{ci_hi_boot} columns from a parametric
#'   bootstrap via \code{stats::rbinom()}, attaching
#'   \code{attr(result, "boot_samples")}. The Schnabel branch ignores this
#'   argument for its analytic bounds — it always inverts Poisson quantiles or
#'   uses the \eqn{t} approximation on \eqn{1/\hat{N}}, per Hansen & Van Kirk
#'   (2018) — but still honours \code{"bootstrap"} for the extra columns.
#' @param B integer(1). Number of bootstrap replicates when
#'   \code{ci_method = "bootstrap"}. Default \code{2000L}.
#' @param bias_adjust logical(1). Multi-occasion methods only; ignored by the
#'   Chapman and Petersen branches, which carry their own bias handling.
#'   \code{TRUE} (default, new in 3.0.0) applies the small-sample correction —
#'   Chapman's (1952), dividing by \eqn{\sum m_k + 1}, for Schnabel, and
#'   Dettloff's (2023) eq. (8) for Schumacher-Eschmeyer. \code{FALSE} restores
#'   the unadjusted forms, which are what \code{fishmethods::schnabel()}
#'   computes for both and, for Schnabel, the only form available before 3.0.0.
#'
#' @details
#' \strong{Why the Chapman and Petersen default is not a Wald interval.}
#' \eqn{\hat{N}} is a ratio with a small integer denominator, so its sampling
#' distribution is strongly right-skewed and a symmetric interval leaves the
#' parameter space. Evans et al. (1996) measured Wald coverage failing on one
#' side 27.9\% of the time against a 2.5\% nominal rate, and Otis et al. (1978)
#' and Dettloff (2023) report the same. With \code{M = 200}, \code{n = 50} and
#' \code{m = 3} the Wald lower bound is \code{-2124.8}; at \code{m = 5} it is
#' \code{48.7}, below the 245 individuals actually observed. Chapman is
#' recommended precisely when recaptures are few, so this is the regime the
#' default estimator is chosen for.
#'
#' The default \code{"logit"} interval is Sadinle's (2009) 0.5 transformed
#' logit, built on the \eqn{2 \times 2} capture table
#' (\eqn{n_{11} = m}, \eqn{n_{12} = M - m}, \eqn{n_{21} = n - m}) with 0.5 added
#' to each cell. Sadinle compared nine intervals and found it "the best of the
#' intervals reported here", with near-nominal coverage even for small
#' populations and capture probabilities near 0 or 1, where profile-likelihood
#' and Monte Carlo intervals both degrade. Its lower limit is guaranteed never
#' to fall below \eqn{n_{11} + n_{12} + n_{21}}, the number of individuals
#' actually seen — the property the Wald interval lacks. It is closed-form and
#' always computable, since the 0.5 continuity correction removes every
#' zero-count division.
#'
#' \strong{One consequence worth knowing.} When \eqn{m = n} — every individual
#' in the second sample was already marked — the estimator saturates at
#' \eqn{\hat{N} = M}, which is also the observed count. The logit lower limit
#' then sits fractionally \emph{above} \eqn{\hat{N}}, because the data imply
#' \eqn{N > M} rather than \eqn{N = M}. This is the interval being informative
#' at a boundary, not an error; pass \code{ci_method = "delta"} if a bound that
#' brackets the point estimate matters more than coverage.
#'
#' \code{ci_method = "delta"} reproduces the pre-3.0.0 bounds exactly.
#'
#' \strong{Choosing between Schnabel and Schumacher-Eschmeyer, and a warning about
#' how not to.} They use identical field data and differ in how they pool it:
#' Schnabel is a ratio of sums, Schumacher-Eschmeyer a weighted regression through
#' the origin. Seber (1982) expects the regression form "to be robust with regard
#' to departures from the underlying assumptions" and recommends using it "in
#' conjunction with the other methods" — as a cross-check, not a replacement. That
#' is a weaker claim than it is sometimes reported as; Seber neither demonstrates
#' the robustness nor calls it the most robust method. Dettloff (2023) found the
#' two adjusted forms "effectively equivalent at larger sample sizes", with
#' Schumacher-Eschmeyer less variable and Schnabel reaching unbiasedness slightly
#' sooner.
#'
#' \strong{Do not pick whichever gives the narrower interval.} Hansen & Van Kirk
#' (2018) computed both and "selected the mark-recapture estimator that produced
#' the smallest 95\% CI", and that procedure does not have 95\% coverage: choosing
#' the narrower of two intervals after seeing them conditions on the luckier draw,
#' so the reported interval is narrower than its nominal level. tidycreel therefore
#' does not implement the selection rule. Decide between the estimators on design
#' grounds before looking at the answer, or report both.
#'
#' \strong{The Schnabel upper bound at very few recaptures.} The Poisson interval
#' inverts the distribution of \eqn{\sum m_k}, so it needs the lower quantile
#' \eqn{q_{\alpha/2}} in its denominator. That quantile is \emph{zero} whenever
#' \eqn{\sum m_k \leq 3} at the 95\% level, which used to send \code{ci_upper} to
#' \code{Inf}. Following Hansen & Van Kirk (2018) eq. (A.4), tidycreel substitutes
#' Ilienko's (2013) continuous Poisson in exactly that case — it has distribution
#' function \eqn{\Gamma(x, \lambda)/\Gamma(x)}, is positive there, and so returns a
#' finite bound. The substitution fires only where the discrete quantile is zero;
#' from \eqn{\sum m_k \geq 4} the continuous quantile sits just above the discrete
#' one, so this is a targeted patch rather than a change of method.
#'
#' \strong{Read that bound for what it is.} It comes from a continuous
#' interpolation of a discrete distribution at one to three total recaptures, not
#' from the data, and it is wide. It stands in for "the data do not bound this
#' above" rather than measuring anything, which is why the function still warns
#' when it fires. Ilienko's construction is the genuine interpolant — his eq. (1)
#' shows the same expression returns the discrete Poisson CDF at integer
#' \eqn{x} — but interpolating at \eqn{\sum m_k = 1} is still interpolating.
#'
#' \strong{Where the Petersen \eqn{m \geq 7} guard comes from.} The threshold is a
#' practical stand-in, not a derivation, and it is worth knowing why no exact one
#' is available. Robson & Regier (1964) give two conditions: Chapman is exactly
#' unbiased when \eqn{M + n \geq N}, and its negative bias stays under 2\% when
#' \eqn{\sqrt{Mn} \geq 2\sqrt{N}} — the geometric mean of marks and captures at
#' least twice the square root of the population size. Both depend on \eqn{N},
#' the unknown being estimated. Dettloff (2023) calls this "paradoxical" and
#' treats such rules as "a way of avoiding inaccurate estimates from absurdly
#' small sample sizes based on an educated guess of the order of magnitude" of
#' \eqn{N}. A fixed \eqn{m} threshold is that guess made concrete; it rules out
#' the regime where Petersen's positive bias is severe without pretending to a
#' precision the conditions cannot deliver. Chapman is the better default at any
#' recapture count and is what the error message points to.
#'
#' \strong{Why Schnabel is bias-adjusted by default.} Each \eqn{m_k} is
#' approximately Poisson with parameter \eqn{M_k n_k / N}, which motivated
#' Chapman's (1952) \eqn{+1} correction to the recapture total. Dettloff (2023)
#' simulated both forms and found the unadjusted estimator turns biased
#' \emph{high} at moderate sample sizes before settling, whereas the adjusted
#' form has bias that "approaches zero as the sample size increases without ever
#' becoming positive", with lower variance and no cost at large samples; he
#' recommends the adjusted estimators "in place of the originals in all
#' scenarios". The package already defaults to the analogous \eqn{+1} correction
#' at two occasions (\code{method = "chapman"}), and Schnabel reduces exactly to
#' Lincoln-Petersen at \eqn{K = 2}, so leaving Schnabel unadjusted made bias
#' handling depend on how many occasions were sampled. The relative shift is
#' \eqn{-1/(\sum m_k + 1)}: −33\% at \eqn{\sum m_k = 2}, −1.9\% at 52, −0.2\% at
#' 500. Pass \code{bias_adjust = FALSE} for the previous form.
#'
#' @return A \code{creel_estimates} S3 object with \code{method =
#'   "mark-recapture-chapman"} (or petersen/schnabel) and an \code{estimates}
#'   tibble with columns: \code{parameter}, \code{estimate}, \code{se},
#'   \code{ci_lower}, \code{ci_upper}, \code{n} (total recaptures).
#'
#' @references
#' Hansen, J. M., & Van Kirk, R. W. (2018). A mark-recapture-based approach
#' for estimating angler harvest. \emph{North American Journal of Fisheries
#' Management}, 38(2), 400--410. \doi{10.1002/nafm.10038}
#'
#' Sadinle, M. (2009). Transformed logit confidence intervals for small
#' populations in single capture-recapture estimation.
#' \emph{Communications in Statistics - Simulation and Computation}, 38(9),
#' 1909--1924. \doi{10.1080/03610910903168595}
#'
#' Evans, M. A., Kim, H.-M., & O'Brien, T. E. (1996). An application of
#' profile-likelihood based confidence interval to capture-recapture
#' estimators. \emph{Journal of Agricultural, Biological, and Environmental
#' Statistics}, 1(1), 131--140. \doi{10.2307/1400565}
#'
#' Dettloff, K. (2023). Assessment of bias and precision among simple closed
#' population mark-recapture estimators. \emph{Fisheries Research}, 265,
#' 106756. \doi{10.1016/j.fishres.2023.106756}
#'
#' Chapman, D. G. (1952). Inverse, multiple and sequential sample censuses.
#' \emph{Biometrics}, 8(4), 286--306. \doi{10.2307/3001864}
#'
#' Robson, D. S., & Regier, H. A. (1964). Sample size in Petersen mark-recapture
#' experiments. \emph{Transactions of the American Fisheries Society}, 93(3),
#' 215--226. \doi{10.1577/1548-8659(1964)93[215:SSIPME]2.0.CO;2}
#'
#' Ilienko, A. (2013). Continuous counterparts of Poisson and binomial
#' distributions and their properties. \emph{Annales Universitatis Scientiarum
#' Budapestinensis de Rolando Eotvos Nominatae, Sectio Computatorica}, 39,
#' 137--147.
#'
#' Schnabel, Z. E. (1938). The estimation of the total fish population of a
#' lake. \emph{The American Mathematical Monthly}, 45(6), 348--352.
#' \doi{10.2307/2304025}
#'
#' Chapman, D. G. (1951). Some properties of the hypergeometric distribution
#' with applications to zoological sample censuses. \emph{University of
#' California Publications in Statistics}, 1(7), 131--160.
#'
#' Schumacher, F. X., & Eschmeyer, R. W. (1943). The estimation of fish
#' populations in lakes or ponds. \emph{Journal of the Tennessee Academy of
#' Science}, 18, 228--249.
#'
#' Seber, G. A. F. (1982). \emph{The Estimation of Animal Abundance and Related
#' Parameters}, 2nd ed. Macmillan, New York.
#'
#' De Lury, D. B. (1958). The estimation of population size by a marking and
#' recapture procedure. \emph{Journal of the Fisheries Research Board of
#' Canada}, 15(1), 19--25. \doi{10.1139/f58-002}
#'
#' @family Estimation
#' @export
#'
#' @examples
#' # Chapman (default) — bias-corrected Petersen
#' result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
#' print(result)
#'
#' # Petersen — requires m >= 7
#' result_p <- estimate_angler_n(M = 200L, n = 50L, m = 10L, method = "petersen")
#' print(result_p)
#'
#' # Schnabel — multi-occasion with parallel vectors
#' result_s <- estimate_angler_n(
#'   M = c(0L, 47L, 91L, 131L),
#'   n = c(50L, 50L, 50L, 50L),
#'   m = c(0L,  4L,  6L,  8L),
#'   method = "schnabel"
#' )
#' print(result_s)
#'
#' # Schumacher-Eschmeyer — the regression alternative, needs >= 3 occasions
#' result_se <- estimate_angler_n(
#'   M = c(0L, 47L, 91L, 131L),
#'   n = c(50L, 50L, 50L, 50L),
#'   m = c(0L,  4L,  6L,  8L),
#'   method = "schumacher"
#' )
#' print(result_se)
estimate_angler_n <- function(
  M,
  n,
  m,
  method = "chapman",
  conf_level = 0.95,
  ci_method = c("logit", "delta", "bootstrap"),
  B = 2000L,
  bias_adjust = TRUE
) {
  method <- match.arg(method, c("chapman", "petersen", "schnabel", "schumacher"))
  ci_method <- match.arg(ci_method)
  multi_occasion <- method %in% c("schnabel", "schumacher")
  if (!is.logical(bias_adjust) || length(bias_adjust) != 1L || is.na(bias_adjust)) {
    cli::cli_abort("{.arg bias_adjust} must be a single non-missing logical value.")
  }

  # Coerce to numeric before validation to prevent integer overflow in products
  # (M * n can exceed .Machine$integer.max for large reservoir surveys)
  M <- as.numeric(M)
  n <- as.numeric(n)
  m <- as.numeric(m)

  # --- input validation ---
  if (any(n <= 0)) {
    cli::cli_abort("{.arg n} must be > 0.")
  }
  if (any(m < 0)) {
    cli::cli_abort("{.arg m} must be >= 0.")
  }

  if (multi_occasion) {
    # Multi-occasion: length checks must come before any per-element guards
    if (!all(lengths(list(M, n, m)) == length(M))) {
      cli::cli_abort(
        "{.arg M}, {.arg n}, and {.arg m} must be the same length for method = {.val {method}}."
      )
    }
    # Schnabel needs 2 occasions; Schumacher-Eschmeyer is a regression through
    # the origin on s - 1 usable points and spends 2 df, so it needs 3. Dettloff
    # (2023) eq. (7) states the estimator "for k > 2" for the same reason.
    min_occasions <- if (method == "schumacher") 3L else 2L
    label <- if (method == "schumacher") "Schumacher-Eschmeyer" else "Schnabel"
    if (length(M) < min_occasions) {
      cli::cli_abort(c(
        "{label} requires >= {min_occasions} occasions.",
        "i" = if (method == "schumacher") {
          "Use {.code method = 'schnabel'} for two occasions."
        } else {
          "Use {.code method = 'chapman'} or {.code method = 'petersen'} for a single occasion."
        }
      ))
    }
    # M[1] = 0 is valid (no marked fish at large before the first sample)
    if (any(M < 0)) {
      cli::cli_abort("{.arg M} must be >= 0.")
    }
    if (any(m > pmin(M, n))) {
      cli::cli_abort("{.arg m} cannot exceed {.code min(M, n)} at any occasion.")
    }
    if (sum(m) == 0L) {
      cli::cli_abort(
        "Total recaptures {.code sum(m)} is 0. {label} requires at least one recapture."
      )
    }
  } else {
    # single-occasion guards (Chapman and Petersen)
    if (M <= 0) {
      cli::cli_abort("{.arg M} must be > 0.")
    }
    if (m == 0) {
      cli::cli_abort("{.arg m} = 0: no recaptures makes N_hat undefined. Increase sampling effort.")
    }
    if (m > n) {
      cli::cli_abort("{.arg m} ({m}) cannot exceed {.arg n} ({n}).")
    }
    if (m > M) {
      cli::cli_abort("{.arg m} ({m}) cannot exceed {.arg M} ({M}).")
    }
    if (method == "petersen" && m < 7L) {
      cli::cli_abort(c(
        "{.arg m} = {m} is too small for the Petersen estimator.",
        "i" = "Petersen requires m >= 7 to avoid large positive bias.",
        "i" = "Use {.code method = 'chapman'} instead."
      ))
    }
  }

  # Unit: NA on every branch. N_hat inherits its actor from whatever the caller
  # marked, and M, n, and m arrive as bare numerics that nothing here inspects.
  # Creel mark-recapture is routinely run on boats or parties rather than on
  # individual anglers, so asserting "anglers" would put a confident label on a
  # party-level count. See finding 25 in AUDIT-dimensional-seams.md.
  if (method == "chapman") {
    # --- point estimate ---
    N_hat <- ((M + 1) * (n + 1)) / (m + 1) - 1

    # --- variance ---
    var_N <- ((M + 1) * (n + 1) * (M - m) * (n - m)) / ((m + 2) * (m + 1)^2)
    se_N <- sqrt(var_N)

    # --- CI ---
    # Wald is retained only under ci_method = "delta". It is symmetric while
    # N_hat is right-skewed, so it leaves the parameter space at the small
    # recapture counts Chapman exists for. See finding 27 in
    # AUDIT-dimensional-seams.md.
    if (ci_method == "delta") {
      z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, m - 1L))
      ci_lo <- N_hat - z * se_N
      ci_hi <- N_hat + z * se_N
    } else {
      logit_ci <- .mr_logit_ci(M, n, m, conf_level)
      ci_lo <- logit_ci[1]
      ci_hi <- logit_ci[2]
    }

    # --- return ---
    estimates_df <- tibble::tibble(
      parameter = "N_hat",
      estimate = N_hat,
      se = se_N,
      ci_lower = ci_lo,
      ci_upper = ci_hi,
      n = as.integer(m)
    )
    if (ci_method == "bootstrap") {
      m_b <- stats::rbinom(B, size = n, prob = m / n)
      # No zero-guard needed: denominator is (m_b + 1), never zero even when m_b = 0.
      # Zero-guard belongs only on the Petersen path where m_b is the bare denominator.
      N_hat_b <- ((M + 1L) * (n + 1L)) / (m_b + 1L) - 1
      alpha <- 1 - conf_level
      ci_lo_boot <- stats::quantile(N_hat_b, alpha / 2, names = FALSE)
      ci_hi_boot <- stats::quantile(N_hat_b, 1 - alpha / 2, names = FALSE)
      estimates_df$ci_lo_boot <- ci_lo_boot
      estimates_df$ci_hi_boot <- ci_hi_boot
    }
    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "mark-recapture-chapman",
      variance_method = "chapman",
      design = NULL,
      conf_level = conf_level,
      by_vars = NULL,
      unit = NA_character_
    )
    # Carried so estimate_mr_harvest() can rebuild the interval at its own
    # conf_level rather than silently reusing this one.
    attr(result, "capture_table") <- c(M = M, n = n, m = m)
    if (ci_method == "bootstrap") {
      attr(result, "boot_samples") <- N_hat_b
    }
    result
  } else if (method == "petersen") {
    # --- point estimate ---
    N_hat <- (M * n) / m

    # --- variance (equivalent form: N_hat^2 * (1/m - 1/n)) ---
    var_N <- N_hat^2 * (1 / m - 1 / n)
    se_N <- sqrt(var_N)

    # --- CI ---
    # Same construction as the Chapman branch: the logit interval is built on
    # the capture table, not on the point estimator, so it serves both.
    if (ci_method == "delta") {
      z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, m - 1L))
      ci_lo <- N_hat - z * se_N
      ci_hi <- N_hat + z * se_N
    } else {
      logit_ci <- .mr_logit_ci(M, n, m, conf_level)
      ci_lo <- logit_ci[1]
      ci_hi <- logit_ci[2]
    }

    # --- return ---
    estimates_df <- tibble::tibble(
      parameter = "N_hat",
      estimate = N_hat,
      se = se_N,
      ci_lower = ci_lo,
      ci_upper = ci_hi,
      n = as.integer(m)
    )
    if (ci_method == "bootstrap") {
      m_b <- stats::rbinom(B, size = n, prob = m / n)
      m_b[m_b == 0L] <- 1L
      N_hat_b <- (M * n) / m_b
      alpha <- 1 - conf_level
      ci_lo_boot <- stats::quantile(N_hat_b, alpha / 2, names = FALSE)
      ci_hi_boot <- stats::quantile(N_hat_b, 1 - alpha / 2, names = FALSE)
      estimates_df$ci_lo_boot <- ci_lo_boot
      estimates_df$ci_hi_boot <- ci_hi_boot
    }
    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "mark-recapture-petersen",
      variance_method = "petersen",
      design = NULL,
      conf_level = conf_level,
      by_vars = NULL,
      unit = NA_character_
    )
    attr(result, "capture_table") <- c(M = M, n = n, m = m)
    if (ci_method == "bootstrap") {
      attr(result, "boot_samples") <- N_hat_b
    }
    result
  } else if (method == "schumacher") {
    # Schumacher-Eschmeyer: a weighted regression of m_k/n_k on M_k through the
    # origin, slope 1/N. Seber (1982) sec. 4.1.3 derives it; De Lury (1958)
    # supplies the argument for weighting by n_k rather than by the reciprocal
    # variances, since the true marked proportions are the thing most likely to
    # be wrong in the field. Also known as Hayne's method (Hayne 1949b).
    # See finding 31 in AUDIT-dimensional-seams.md.
    #
    # Occasion 1 contributes nothing: M_1 = 0 zeroes every term below. Seber
    # excludes it explicitly -- y_1 is always 0 when M_1 = 0, so it is not a
    # random observation, which is why df is s - 2 and not s - 1.
    sum_nM2 <- sum(n * M^2)
    sum_mM <- sum(m * M)
    s_occ <- length(m)

    # No guard on sum_mM == 0 -- it cannot happen. The validation above rejects
    # m_k > min(M_k, n_k) and sum(m) == 0, so some m_j > 0 with M_j >= m_j > 0,
    # which makes sum(m * M) strictly positive. A defensive check here would be
    # unreachable code.

    # Dettloff (2023) eq. (8) proposes the Chapman-style small-sample correction
    # for this estimator, analogous to eq. (6) for Schnabel, and reports it had
    # the fastest reduction in bias at small sample sizes while staying exactly
    # unbiased at large ones. Note the numerator sum runs from k = 2: unlike
    # every other term here, (M_k + 1)^2 (n_k + 1) does NOT vanish at M_1 = 0,
    # so occasion 1 has to be dropped by hand rather than by the algebra.
    N_hat <- if (bias_adjust) {
      idx <- seq_along(m)[-1]
      sum((M[idx] + 1)^2 * (n[idx] + 1)) / sum(M * (m + 1)) - 2
    } else {
      sum_nM2 / sum_mM
    }

    # Seber (1982) eq. (4.17). sigma^2 is the residual mean square of the
    # weighted regression on s - 2 degrees of freedom.
    sigma2 <- (sum(m^2 / n) - sum_mM^2 / sum_nM2) / (s_occ - 2L)
    se_inv <- sqrt(max(0, sigma2) / sum_nM2)
    se_N <- N_hat^2 * se_inv

    z <- stats::qt(1 - (1 - conf_level) / 2, df = s_occ - 2L)
    # 4.17 rearranges to 1/(beta_hat +/- t * se_inv), so this interval is centred
    # on 1/N_hat rather than being an inversion independent of it -- contrast the
    # Schnabel Poisson branch. It therefore has to follow bias_adjust, or the
    # reported estimate would sit off-centre in its own interval.
    #
    # Dettloff supplies no variance or interval for eq. (8), and unlike his
    # eq. (6) the correction is not a constant shift of 1/N_hat, so the variance
    # is not provably unchanged. Taking Seber's se_inv at the corrected location
    # is an approximation, and bias_adjust = FALSE is the exact, published path.
    inv_N <- 1 / N_hat
    ci_lo <- 1 / (inv_N + z * se_inv)
    ci_hi <- 1 / (inv_N - z * se_inv)

    estimates_df <- tibble::tibble(
      parameter = "N_hat",
      estimate = N_hat,
      se = se_N,
      ci_lower = ci_lo,
      ci_upper = if (ci_hi < 0) Inf else ci_hi,
      n = as.integer(sum(m))
    )
    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "mark-recapture-schumacher",
      variance_method = "delta",
      design = NULL,
      conf_level = conf_level,
      by_vars = NULL,
      unit = NA_character_
    )
    attr(result, "n_occasions") <- s_occ
    result
  } else {
    # method == "schnabel"
    # --- point estimate ---
    sum_Mn <- sum(M * n)
    sum_m <- sum(m)
    # Chapman's (1952) small-sample correction adds 1 to the recapture total,
    # since each m_k is approximately Poisson with parameter M_k n_k / N.
    # Dettloff (2023) eq. (6) measured the unadjusted form turning biased high
    # at moderate sample sizes, while the adjusted form "approaches zero as the
    # sample size increases without ever becoming positive" with lower variance,
    # and recommends "the adjusted estimators are used in place of the originals
    # in all scenarios". The correction is exactly -1/(sum(m) + 1) in relative
    # terms: -33% at sum(m) = 2, -1.9% at 52, -0.2% at 500.
    # bias_adjust = FALSE restores the unadjusted form, which is what
    # fishmethods::schnabel() computes. See finding 32 in
    # AUDIT-dimensional-seams.md.
    N_hat <- sum_Mn / (sum_m + if (bias_adjust) 1 else 0)

    # --- SE (delta method on 1/N_hat) ---
    # The correction shifts 1/N_hat by the constant 1/sum_Mn, which leaves
    # Var(1/N_hat) unchanged, so se_inv is keyed to sum_m under both forms.
    # se_N evaluates the delta-method Jacobian at whichever N_hat is reported.
    se_inv <- sqrt(sum_m / sum_Mn^2)
    se_N <- N_hat^2 * se_inv

    # --- CI ---
    alpha <- 1 - conf_level
    if (sum_m < 50L) {
      # This branch inverts the Poisson distribution of sum(m) directly rather
      # than centring on N_hat, so it is a valid interval for N under either
      # form and is deliberately left unadjusted. N_hat stays strictly inside
      # it: qpois(1 - alpha/2, sum_m) > sum_m + 1 for every sum_m >= 1.
      lo_m <- stats::qpois(alpha / 2, lambda = sum_m)
      hi_m <- stats::qpois(1 - alpha / 2, lambda = sum_m)
      # Guard against hi_m == 0 (degenerate Poisson quantile)
      ci_lo <- if (hi_m == 0) Inf else sum_Mn / hi_m
      if (lo_m == 0L) {
        # The discrete lower quantile is 0 whenever sum(m) is small enough --
        # sum(m) <= 3 at the 95% level -- which sends the upper bound to
        # infinity. Hansen & Van Kirk (2018) eq. (A.4) substitute Ilienko's
        # (2013) continuous Poisson in exactly this case, which has a positive
        # quantile there and so yields a finite bound. Applied only when the
        # discrete quantile is 0: at sum(m) >= 4 the continuous quantile sits
        # just above the discrete one, so this stays a targeted substitution
        # rather than a change of method. See finding 30.
        lo_cont <- .continuous_poisson_q(alpha / 2, sum_m)
        ci_hi <- sum_Mn / lo_cont
        cli::cli_warn(c(
          "Schnabel Poisson CI: the discrete lower quantile is 0 at {.code sum(m) = {sum_m}}.",
          "i" = "{.field ci_upper} comes from the continuous Poisson (Ilienko 2013) rather than
                 the data, and is an interpolation between the achievable discrete bounds.",
          "i" = "Treat it as a stand-in for an unbounded upper limit, not as a measured one."
        ))
      } else {
        ci_hi <- sum_Mn / lo_m
      }
    } else {
      # df is the number of sampling occasions minus one, not the recapture
      # total minus one. Hansen & Van Kirk (2018) eq. (A.5) uses t_{alpha/2, S-1}
      # for S sample days, as does fishmethods::schnabel(), the implementation
      # they modified. Keying df to sum(m) treats every recapture as an
      # independent observation and understates the interval: on 5 occasions
      # with sum(m) = 52 it returns t = 2.008 where S - 1 gives t = 2.776, a
      # 33% narrower CI. See finding 29 in AUDIT-dimensional-seams.md.
      z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, length(m) - 1L))
      # Unlike the Poisson branch, this interval is built around 1/N_hat, so it
      # follows the bias_adjust choice automatically.
      inv_N <- 1 / N_hat
      ci_lo <- 1 / (inv_N + z * se_inv)
      ci_hi <- 1 / (inv_N - z * se_inv)
    }

    # --- return ---
    estimates_df <- tibble::tibble(
      parameter = "N_hat",
      estimate = N_hat,
      se = se_N,
      ci_lower = ci_lo,
      ci_upper = ci_hi,
      n = as.integer(sum_m)
    )
    if (ci_method == "bootstrap") {
      m_b_matrix <- vapply(
        seq_along(m),
        function(i) stats::rbinom(B, size = n[i], prob = m[i] / n[i]),
        numeric(B)
      ) # matrix B x k (each column is one occasion)
      sum_m_b <- rowSums(m_b_matrix)
      # Replicates use the same estimator as the point estimate, so the
      # bootstrap columns describe the quantity actually reported. Under
      # bias_adjust the +1 keeps a zero-recapture replicate finite on its own;
      # the unadjusted form needs the floor at 1 instead.
      denom_b <- if (bias_adjust) sum_m_b + 1 else pmax(sum_m_b, 1)
      N_hat_b <- sum_Mn / denom_b
      alpha <- 1 - conf_level
      ci_lo_boot <- stats::quantile(N_hat_b, alpha / 2, names = FALSE)
      ci_hi_boot <- stats::quantile(N_hat_b, 1 - alpha / 2, names = FALSE)
      estimates_df$ci_lo_boot <- ci_lo_boot
      estimates_df$ci_hi_boot <- ci_hi_boot
    }
    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = "mark-recapture-schnabel",
      variance_method = "delta",
      design = NULL,
      conf_level = conf_level,
      by_vars = NULL,
      unit = NA_character_
    )
    # Schnabel carries no two-sample capture table, but estimate_mr_harvest()
    # needs the occasion count to key its t quantile the same way the CI above
    # does. Without it the harvest interval falls back to sum(m) - 1 degrees of
    # freedom -- the defect finding 29 fixed here. See finding 33.
    attr(result, "n_occasions") <- length(m)
    if (ci_method == "bootstrap") {
      attr(result, "boot_samples") <- N_hat_b
    }
    result
  }
}

# Mark-Recapture Harvest Estimation ----

#' Estimate total harvest from a mark-recapture population estimate
#'
#' @description
#' Computes a total harvest estimate and its uncertainty using the delta method,
#' given a closed-population angler population estimate from
#' \code{\link{estimate_angler_n}} and a known harvest rate.
#'
#' The point estimate is \eqn{\hat{H} = \hat{N} \times r} where \eqn{r} is the
#' harvest rate in fish per angler. The delta-method
#' standard error is \eqn{SE(\hat{H}) = r \times SE(\hat{N})}, propagating only
#' the uncertainty in \eqn{\hat{N}} (harvest-rate uncertainty is not propagated
#' in this release).
#'
#' @param angler_n A \code{creel_estimates} object returned by
#'   \code{\link{estimate_angler_n}}.
#' @param harvest_rate numeric scalar. Harvest per angler, in fish per angler,
#'   over the same period \code{angler_n} counts anglers for. Must be
#'   \eqn{> 0}. This is a rate, not a proportion, and is not bounded above: a
#'   fishery averaging 1.4 fish per angler is a legal value. In the notation of
#'   Hansen & Van Kirk (2018) eq. (1), \eqn{H = N \cdot D \cdot V}, this
#'   argument is the product \eqn{D \times V} — mean days fished per angler
#'   times mean daily harvest per angler — not \eqn{V} alone.
#'   Uncertainty in the harvest rate is not propagated (see Details).
#' @param conf_level numeric. Confidence level for the CI. Default \code{0.95}.
#' @param ci_method character(1). CI construction method: \code{"delta"} (default)
#'   uses the analytic delta-method formula; \code{"bootstrap"} propagates the
#'   bootstrap samples stored in \code{attr(angler_n, "boot_samples")} (produced
#'   by calling \code{estimate_angler_n(..., ci_method = "bootstrap")} first).
#'
#' @details
#' The harvest rate is treated as a known constant. This is a simplification
#' made by this implementation, not by the cited method: Hansen & Van Kirk
#' (2018) estimate both factors of the rate, give each a log-normal sampling
#' distribution, and resample them alongside \eqn{\hat{N}} in the bootstrap
#' that produces their harvest CIs. Holding the rate fixed therefore makes the
#' reported \code{se} a lower bound on the true uncertainty. Propagation of
#' harvest-rate uncertainty via a two-source delta method is a planned future
#' extension.
#'
#' The delta-method interval is also symmetric, which for a mark-recapture
#' estimate is optimistic at the lower end and can place \code{ci_lower} below
#' zero when recaptures are few; see the same note under
#' \code{\link{estimate_angler_n}}.
#'
#' @return A \code{creel_estimates} S3 object with \code{method =
#'   "mark-recapture-harvest"} and an \code{estimates} tibble with columns:
#'   \code{parameter}, \code{estimate}, \code{se}, \code{ci_lower},
#'   \code{ci_upper}.
#'
#' @references
#' Hansen, J. M., & Van Kirk, R. W. (2018). A mark-recapture-based approach
#' for estimating angler harvest. \emph{North American Journal of Fisheries
#' Management}, 38(2), 400--410. \doi{10.1002/nafm.10038}
#'
#' @family Estimation
#' @export
#'
#' @examples
#' # Step 1: estimate angler population
#' result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
#'
#' # Step 2: compute total harvest
#' harvest <- estimate_mr_harvest(angler_n = result, harvest_rate = 0.35)
#' print(harvest)
estimate_mr_harvest <- function(
  angler_n,
  harvest_rate,
  conf_level = 0.95,
  ci_method = c("logit", "delta", "bootstrap")
) {
  ci_method <- match.arg(ci_method)
  # --- input validation ---
  if (!inherits(angler_n, "creel_estimates")) {
    cli::cli_abort(
      c(
        "{.arg angler_n} must be a {.cls creel_estimates} object.",
        "i" = "Use {.code estimate_angler_n()} to produce the required input."
      )
    )
  }
  if (!grepl("^mark-recapture-", angler_n$method)) {
    cli::cli_abort(
      c(
        "{.arg angler_n} must come from {.fn estimate_angler_n}.",
        "i" = "Received method: {.val {angler_n$method}}."
      )
    )
  }
  if (nrow(angler_n$estimates) != 1L) {
    cli::cli_abort("{.arg angler_n} must be a single-occasion (single-row) estimate.")
  }
  if (!is.numeric(harvest_rate) || length(harvest_rate) != 1L) {
    cli::cli_abort("{.arg harvest_rate} must be a single numeric value.")
  }
  if (harvest_rate <= 0) {
    cli::cli_abort("{.arg harvest_rate} must be > 0, not {harvest_rate}.")
  }

  # --- extract N_hat and se_N from the creel_estimates object ---
  N_hat <- angler_n$estimates$estimate
  se_N <- angler_n$estimates$se

  # --- delta-method harvest estimate (H = N_hat * harvest_rate) ---
  harvest_hat <- N_hat * harvest_rate
  se_H <- harvest_rate * se_N

  # --- CI ---
  # H = N x harvest_rate is a monotone linear map with harvest_rate > 0
  # guaranteed above, so scaling the endpoints of the N interval is exact:
  # P(N in [L, U]) = P(H in [rL, rU]). Rebuilding a symmetric interval here
  # instead -- as the code did before 3.0.0 -- discarded whatever construction
  # estimate_angler_n() had chosen and put ci_lower below zero at small
  # recapture counts (finding 27).
  #
  # The capture table is rebuilt at this call's conf_level rather than reusing
  # angler_n's bounds directly, so conf_level keeps working here. Schnabel
  # carries no two-sample table and keeps the legacy Wald interval.
  capture_table <- attr(angler_n, "capture_table")
  n_mr <- as.integer(angler_n$estimates$n)
  if (ci_method != "delta" && !is.null(capture_table)) {
    logit_ci <- .mr_logit_ci(
      capture_table[["M"]], capture_table[["n"]], capture_table[["m"]], conf_level
    )
    ci_lo <- logit_ci[1] * harvest_rate
    ci_hi <- logit_ci[2] * harvest_rate
  } else {
    # Degrees of freedom must match the branch that produced angler_n. For
    # Chapman and Petersen the n column is the recapture count m, so m - 1 is
    # right. For Schnabel it is sum(m), and keying the t quantile to that
    # repeats finding 29 on the harvest path: recaptures within one occasion
    # are not independent observations of the ratio. Use the occasion count
    # that estimate_angler_n() attached instead. See finding 33.
    n_occ <- attr(angler_n, "n_occasions")
    df_h <- if (is.null(n_occ)) n_mr - 1L else n_occ - 1L
    z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, df_h))
    ci_lo <- harvest_hat - z * se_H
    ci_hi <- harvest_hat + z * se_H
  }

  # --- return ---
  estimates_df <- tibble::tibble(
    parameter = "total_harvest",
    estimate = harvest_hat,
    se = se_H,
    ci_lower = ci_lo,
    ci_upper = ci_hi
  )
  if (ci_method == "bootstrap") {
    boot_samples <- attr(angler_n, "boot_samples")
    if (is.null(boot_samples)) {
      cli::cli_abort(c(
        "ci_method = 'bootstrap' requires angler_n computed with ci_method = 'bootstrap'.",
        "i" = "Call estimate_angler_n(..., ci_method = 'bootstrap') first."
      ))
    }
    harvest_b <- boot_samples * harvest_rate
    ci_lo_boot <- stats::quantile(harvest_b, (1 - conf_level) / 2, names = FALSE)
    ci_hi_boot <- stats::quantile(harvest_b, 1 - (1 - conf_level) / 2, names = FALSE)
    estimates_df$ci_lo_boot <- ci_lo_boot
    estimates_df$ci_hi_boot <- ci_hi_boot
  }
  # Unit: NA. H = N_hat x harvest_rate is in fish only if N_hat counts anglers,
  # and estimate_angler_n() cannot know its own actor (finding 25). Claiming
  # "fish" here would launder that unknown into a confident label.
  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "mark-recapture-harvest",
    variance_method = "delta",
    design = NULL,
    conf_level = conf_level,
    by_vars = NULL,
    unit = NA_character_
  )
}
