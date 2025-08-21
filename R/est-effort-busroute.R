#' Bus-Route Effort Estimation (Horvitz-Thompson)
#'
#' Estimate fishing effort for bus-route designs using the Horvitz-Thompson estimator.
#' Accepts a `busroute_design` object and counts data. Returns a tibble with stratum, estimate, SE, CI, n, and diagnostics.
#'
#' @param x A `busroute_design` object.
#' @param counts Optional tibble/data.frame of counts. If `x` contains `$counts`, that will be used by default.
#' @param by Character vector of grouping (stratification) variables to retain in output.
#' @param conf_level Confidence level for CI (default 0.95).
#' @param ... Reserved for future arguments.
#'
#' @return A tibble with columns: stratum variables (`by`), `estimate`, `se`, `ci_low`, `ci_high`, `n`, `method`, `diagnostics`.
#'
#' @export
est_effort.busroute_design <- function(x,
                                       counts = NULL,
                                       by = c("date", "shift_block", "location"),
                                       conf_level = 0.95,
                                       ...) {
  # Input validation
  if (is.null(counts) && !is.null(x$counts)) counts <- x$counts
  if (is.null(counts)) stop("Counts data must be supplied via `counts` or present in the design object as `$counts`.")

  required <- c("cycle", "count", "inclusion_prob")
  missing <- setdiff(required, names(counts))
  if (length(missing) > 0) stop(paste("Missing required columns:", paste(missing, collapse=", ")))

  by <- intersect(by, names(counts))
  if (length(by) == 0) warning("No grouping variables found; aggregating all counts together.")

  # Cycle checks
  if (anyDuplicated(counts$cycle)) warning("Duplicate cycles detected in counts data.")
  if (any(is.na(counts$cycle))) warning("Missing cycle labels in counts data.")

  # HT estimator
  counts$ht_effort <- counts$count / counts$inclusion_prob

  # Analytic variance for HT estimator (per stratum)
  # Var(HT) = sum( (1 - pi) / pi^2 * count^2 )
  counts$ht_var <- (1 - counts$inclusion_prob) / (counts$inclusion_prob^2) * (counts$count^2)

  # Check for replicate weights (bootstrap/jackknife)
  replicate_weights <- NULL
  if (!is.null(x$replicate_weights)) {
    replicate_weights <- x$replicate_weights
  } else if (!is.null(counts$replicate_weights)) {
    replicate_weights <- counts$replicate_weights
  }

  # Aggregate by stratum
  agg <- stats::aggregate(cbind(ht_effort, ht_var) ~ ., data = counts[c(by, "ht_effort", "ht_var")], FUN = sum, na.rm = TRUE)
  agg$n <- as.integer(stats::aggregate(ht_effort ~ ., data = counts[c(by, "ht_effort")], FUN = length)$ht_effort)

  # Variance estimation
  if (!is.null(replicate_weights)) {
    # Replicate weights: matrix (n x R), same order as counts
    R <- ncol(replicate_weights)
    rep_estimates <- matrix(NA_real_, nrow = nrow(agg), ncol = R)
    for (r in seq_len(R)) {
      rep_ht <- counts$count / replicate_weights[, r]
      rep_agg <- stats::aggregate(rep_ht ~ ., data = counts[c(by)], FUN = sum, na.rm = TRUE)
      rep_estimates[, r] <- rep_agg$rep_ht
    }
    # Bootstrap: variance = var(rep_estimates)
    # Jackknife: variance = (R-1)/R * sum((rep_estimates - mean(rep_estimates))^2)
    if (!is.null(x$replicate_method) && x$replicate_method == "jackknife") {
      rep_mean <- rowMeans(rep_estimates)
      agg$se <- sqrt((R - 1) / R * rowSums((rep_estimates - rep_mean)^2))
    } else {
      agg$se <- apply(rep_estimates, 1, sd)
    }
    z <- qnorm(1 - (1 - conf_level) / 2)
    agg$ci_low <- agg$ht_effort - z * agg$se
    agg$ci_high <- agg$ht_effort + z * agg$se
    agg$method <- if (!is.null(x$replicate_method)) paste0("busroute_ht_", x$replicate_method) else "busroute_ht_bootstrap"
  } else {
    # Analytic variance
    agg$se <- sqrt(agg$ht_var)
    z <- qnorm(1 - (1 - conf_level) / 2)
    agg$ci_low <- agg$ht_effort - z * agg$se
    agg$ci_high <- agg$ht_effort + z * agg$se
    agg$method <- "busroute_ht"
  }
  agg$diagnostics <- NA_character_  # TODO: add diagnostics

  out <- agg[c(by, "ht_effort", "se", "ci_low", "ci_high", "n", "method", "diagnostics")]
  names(out)[names(out) == "ht_effort"] <- "estimate"
  return(out)
}
