# Mark-Recapture Estimation Functions ----

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
#'     weighted estimator for \eqn{K \geq 2} sampling occasions.
#'     \eqn{\hat{N} = \frac{\sum M_k n_k}{\sum m_k}}
#'     CI uses the Poisson branch when \eqn{\sum m_k < 50} and the normal
#'     approximation on \eqn{1/\hat{N}} otherwise, on \eqn{K - 1} degrees of
#'     freedom (Hansen & Van Kirk 2018, eq. A.5).
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
#'   \code{"petersen"}, or \code{"schnabel"}.
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
#' @return A \code{creel_estimates} S3 object with \code{method =
#'   "mark-recapture-chapman"} (or petersen/schnabel) and an \code{estimates}
#'   tibble with columns: \code{parameter}, \code{estimate}, \code{se},
#'   \code{ci_lower}, \code{ci_upper}, \code{n} (total recaptures).
#'
#' @references
#' Hansen, M. J., & Van Kirk, R. W. (2018). A mark-recapture-based approach
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
estimate_angler_n <- function(
  M,
  n,
  m,
  method = "chapman",
  conf_level = 0.95,
  ci_method = c("logit", "delta", "bootstrap"),
  B = 2000L
) {
  method <- match.arg(method, c("chapman", "petersen", "schnabel"))
  ci_method <- match.arg(ci_method)

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

  if (method == "schnabel") {
    # Schnabel: length checks must come before any per-element guards
    if (!all(lengths(list(M, n, m)) == length(M))) {
      cli::cli_abort(
        "{.arg M}, {.arg n}, and {.arg m} must be the same length for method = 'schnabel'."
      )
    }
    if (length(M) < 2L) {
      cli::cli_abort(c(
        "Schnabel requires >= 2 occasions.",
        "i" = "Use {.code method = 'chapman'} or {.code method = 'petersen'} for a single occasion."
      ))
    }
    # For Schnabel, M[1] = 0 is valid (no marked fish at large before first sample)
    if (any(M < 0)) {
      cli::cli_abort("{.arg M} must be >= 0.")
    }
    if (any(m > pmin(M, n))) {
      cli::cli_abort("{.arg m} cannot exceed {.code min(M, n)} at any occasion.")
    }
    if (sum(m) == 0L) {
      cli::cli_abort(
        "Total recaptures {.code sum(m)} is 0. Schnabel requires at least one recapture."
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
  } else {
    # method == "schnabel"
    # --- point estimate ---
    sum_Mn <- sum(M * n)
    sum_m <- sum(m)
    N_hat <- sum_Mn / sum_m

    # --- SE (delta method on 1/N_hat) ---
    se_inv <- sqrt(sum_m / sum_Mn^2)
    se_N <- N_hat^2 * se_inv

    # --- CI ---
    alpha <- 1 - conf_level
    if (sum_m < 50L) {
      lo_m <- stats::qpois(alpha / 2, lambda = sum_m)
      hi_m <- stats::qpois(1 - alpha / 2, lambda = sum_m)
      # Guard against hi_m == 0 (degenerate Poisson quantile)
      ci_lo <- if (hi_m == 0) Inf else sum_Mn / hi_m
      if (lo_m == 0L) {
        cli::cli_warn("Schnabel Poisson CI: lower quantile is 0; ci_hi set to Inf.")
      }
      ci_hi <- if (lo_m == 0L) Inf else sum_Mn / lo_m
    } else {
      # df is the number of sampling occasions minus one, not the recapture
      # total minus one. Hansen & Van Kirk (2018) eq. (A.5) uses t_{alpha/2, S-1}
      # for S sample days, as does fishmethods::schnabel(), the implementation
      # they modified. Keying df to sum(m) treats every recapture as an
      # independent observation and understates the interval: on 5 occasions
      # with sum(m) = 52 it returns t = 2.008 where S - 1 gives t = 2.776, a
      # 33% narrower CI. See finding 29 in AUDIT-dimensional-seams.md.
      z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, length(m) - 1L))
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
      sum_m_b[sum_m_b == 0L] <- 1L
      N_hat_b <- sum(M * n) / sum_m_b
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
#' Hansen, M. J., & Van Kirk, R. W. (2018). A mark-recapture-based approach
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
    z <- stats::qt(1 - (1 - conf_level) / 2, df = max(1L, n_mr - 1L))
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
