# Mark-Recapture Estimation Functions ----

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
#'     approximation on \eqn{1/\hat{N}} otherwise.
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
estimate_angler_n <- function(M, n, m, method = "chapman", conf_level = 0.95) {
  method <- match.arg(method, c("chapman", "petersen", "schnabel"))

  # --- input validation ---
  if (any(n <= 0))
    cli::cli_abort("{.arg n} must be > 0.")
  if (any(m < 0))
    cli::cli_abort("{.arg m} must be >= 0.")

  if (method == "schnabel") {
    # Schnabel: length checks must come before any per-element guards
    if (!all(lengths(list(M, n, m)) == length(M)))
      cli::cli_abort("{.arg M}, {.arg n}, and {.arg m} must be the same length for method = 'schnabel'.")
    if (length(M) < 2L)
      cli::cli_abort(c(
        "Schnabel requires >= 2 occasions.",
        "i" = "Use {.code method = 'chapman'} or {.code method = 'petersen'} for a single occasion."
      ))
    # For Schnabel, M[1] = 0 is valid (no marked fish at large before first sample)
    if (any(M < 0))
      cli::cli_abort("{.arg M} must be >= 0.")
    if (any(m > pmin(M, n)))
      cli::cli_abort("{.arg m} cannot exceed {.code min(M, n)} at any occasion.")
    if (sum(m) == 0L)
      cli::cli_abort("Total recaptures {.code sum(m)} is 0. Schnabel requires at least one recapture.")
  } else {
    # single-occasion guards (Chapman and Petersen)
    if (M <= 0)
      cli::cli_abort("{.arg M} must be > 0.")
    if (m == 0)
      cli::cli_abort("{.arg m} = 0: no recaptures makes N_hat undefined. Increase sampling effort.")
    if (m > n)
      cli::cli_abort("{.arg m} ({m}) cannot exceed {.arg n} ({n}).")
    if (m > M)
      cli::cli_abort("{.arg m} ({m}) cannot exceed {.arg M} ({M}).")
    if (method == "petersen" && m < 7L)
      cli::cli_abort(c(
        "{.arg m} = {m} is too small for the Petersen estimator.",
        "i" = "Petersen requires m >= 7 to avoid large positive bias.",
        "i" = "Use {.code method = 'chapman'} instead."
      ))
  }

  if (method == "chapman") {
    # --- point estimate ---
    N_hat <- ((M + 1) * (n + 1)) / (m + 1) - 1

    # --- variance ---
    var_N <- ((M + 1) * (n + 1) * (M - m) * (n - m)) / ((m + 2) * (m + 1)^2)
    se_N  <- sqrt(var_N)

    # --- CI ---
    z     <- stats::qnorm(1 - (1 - conf_level) / 2)
    ci_lo <- N_hat - z * se_N
    ci_hi <- N_hat + z * se_N

    # --- return ---
    new_creel_estimates(
      estimates = tibble::tibble(
        parameter = "N_hat",
        estimate  = N_hat,
        se        = se_N,
        ci_lower  = ci_lo,
        ci_upper  = ci_hi,
        n         = as.integer(m)
      ),
      method          = "mark-recapture-chapman",
      variance_method = "chapman",
      design          = NULL,
      conf_level      = conf_level,
      by_vars         = NULL
    )

  } else if (method == "petersen") {
    # --- point estimate ---
    N_hat <- (M * n) / m

    # --- variance (equivalent form: N_hat^2 * (1/m - 1/n)) ---
    var_N <- N_hat^2 * (1 / m - 1 / n)
    se_N  <- sqrt(var_N)

    # --- CI ---
    z     <- stats::qnorm(1 - (1 - conf_level) / 2)
    ci_lo <- N_hat - z * se_N
    ci_hi <- N_hat + z * se_N

    # --- return ---
    new_creel_estimates(
      estimates = tibble::tibble(
        parameter = "N_hat",
        estimate  = N_hat,
        se        = se_N,
        ci_lower  = ci_lo,
        ci_upper  = ci_hi,
        n         = as.integer(m)
      ),
      method          = "mark-recapture-petersen",
      variance_method = "petersen",
      design          = NULL,
      conf_level      = conf_level,
      by_vars         = NULL
    )

  } else {
    # method == "schnabel"
    # --- point estimate ---
    sum_Mn <- sum(M * n)
    sum_m  <- sum(m)
    N_hat  <- sum_Mn / sum_m

    # --- SE (delta method on 1/N_hat) ---
    se_inv <- sqrt(sum_m / sum_Mn^2)
    se_N   <- N_hat^2 * se_inv

    # --- CI ---
    alpha <- 1 - conf_level
    if (sum_m < 50L) {
      lo_m  <- stats::qpois(alpha / 2,       lambda = sum_m)
      hi_m  <- stats::qpois(1 - alpha / 2,   lambda = sum_m)
      # Guard against hi_m == 0 (degenerate Poisson quantile)
      ci_lo <- if (hi_m == 0) Inf else sum_Mn / hi_m
      if (lo_m == 0L) {
        cli::cli_warn("Schnabel Poisson CI: lower quantile is 0; ci_hi set to Inf.")
      }
      ci_hi <- if (lo_m == 0L) Inf else sum_Mn / lo_m
    } else {
      z     <- stats::qnorm(1 - (1 - conf_level) / 2)
      inv_N <- 1 / N_hat
      ci_lo <- 1 / (inv_N + z * se_inv)
      ci_hi <- 1 / (inv_N - z * se_inv)
    }

    # --- return ---
    new_creel_estimates(
      estimates = tibble::tibble(
        parameter = "N_hat",
        estimate  = N_hat,
        se        = se_N,
        ci_lower  = ci_lo,
        ci_upper  = ci_hi,
        n         = as.integer(sum_m)
      ),
      method          = "mark-recapture-schnabel",
      variance_method = "delta",
      design          = NULL,
      conf_level      = conf_level,
      by_vars         = NULL
    )
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
#' harvest rate (proportion of anglers that harvested fish). The delta-method
#' standard error is \eqn{SE(\hat{H}) = r \times SE(\hat{N})}, propagating only
#' the uncertainty in \eqn{\hat{N}} (harvest-rate uncertainty is not propagated
#' in this release).
#'
#' @param angler_n A \code{creel_estimates} object returned by
#'   \code{\link{estimate_angler_n}}.
#' @param harvest_rate numeric scalar. Proportion of anglers that harvested fish.
#'   Must be in \eqn{(0, 1]}. Uncertainty in the harvest rate is not propagated
#'   (see Details).
#' @param conf_level numeric. Confidence level for the CI. Default \code{0.95}.
#'
#' @details
#' The harvest rate is treated as a known constant in this implementation
#' (Hansen & Van Kirk 2018, D-04). Propagation of harvest-rate uncertainty via a
#' two-source delta method is a planned future extension.
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
estimate_mr_harvest <- function(angler_n, harvest_rate, conf_level = 0.95) {
  # --- input validation ---
  if (!inherits(angler_n, "creel_estimates"))
    cli::cli_abort(
      c(
        "{.arg angler_n} must be a {.cls creel_estimates} object.",
        "i" = "Use {.code estimate_angler_n()} to produce the required input."
      )
    )
  if (!grepl("^mark-recapture-", angler_n$method))
    cli::cli_abort(
      c(
        "{.arg angler_n} must come from {.fn estimate_angler_n}.",
        "i" = "Received method: {.val {angler_n$method}}."
      )
    )
  if (nrow(angler_n$estimates) != 1L)
    cli::cli_abort("{.arg angler_n} must be a single-occasion (single-row) estimate.")
  if (!is.numeric(harvest_rate) || length(harvest_rate) != 1L)
    cli::cli_abort("{.arg harvest_rate} must be a single numeric value.")
  if (harvest_rate <= 0 || harvest_rate > 1)
    cli::cli_abort("{.arg harvest_rate} must be in (0, 1], not {harvest_rate}.")

  # --- extract N_hat and se_N from the creel_estimates object ---
  N_hat <- angler_n$estimates$estimate
  se_N  <- angler_n$estimates$se

  # --- delta-method harvest estimate (H = N_hat * harvest_rate) ---
  harvest_hat <- N_hat * harvest_rate
  se_H        <- harvest_rate * se_N

  # --- CI ---
  z     <- stats::qnorm(1 - (1 - conf_level) / 2)
  ci_lo <- harvest_hat - z * se_H
  ci_hi <- harvest_hat + z * se_H

  # --- return ---
  new_creel_estimates(
    estimates = tibble::tibble(
      parameter = "total_harvest",
      estimate  = harvest_hat,
      se        = se_H,
      ci_lower  = ci_lo,
      ci_upper  = ci_hi
    ),
    method          = "mark-recapture-harvest",
    variance_method = "delta",
    design          = NULL,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}
