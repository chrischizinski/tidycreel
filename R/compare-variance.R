#' Compare Taylor linearization vs. replicate variance for creel estimates
#'
#' Takes a \code{\link{creel_estimates}} object produced with
#' \code{variance = "taylor"} and re-estimates using replicate weights
#' (bootstrap or jackknife) to produce a side-by-side comparison of standard
#' errors. A \code{cli_warn()} is issued for any row where the two SEs diverge
#' by more than \code{divergence_threshold}.
#'
#' @param x A \code{creel_estimates} object with \code{variance_method =
#'   "taylor"}. Must have been created with a \code{design} stored in
#'   \code{x$design}.
#' @param replicate_method Character. Replicate variance method to use for
#'   comparison. One of \code{"bootstrap"} (default) or \code{"jackknife"}.
#' @param conf_level Numeric confidence level (default: 0.95). Passed to the
#'   replicate estimation call.
#' @param divergence_threshold Numeric. Fraction by which replicate SE may
#'   differ from Taylor SE before a warning is issued (default: 0.10 = 10\%).
#'   A warning fires for any group where
#'   \code{|se_replicate / se_taylor - 1| > divergence_threshold}.
#' @param ... Additional arguments passed to the underlying estimator.
#'
#' @return A \code{creel_variance_comparison} S3 object (a tibble subclass)
#'   with columns:
#'   \describe{
#'     \item{se_taylor}{Taylor linearization SE from the original estimate.}
#'     \item{se_replicate}{Replicate-weight SE from the re-estimation.}
#'     \item{divergence_ratio}{Ratio \code{se_replicate / se_taylor}.
#'       \code{NA} when \code{se_taylor == 0}.}
#'     \item{diverges_flag}{Logical. \code{TRUE} when
#'       \code{|divergence_ratio - 1| > divergence_threshold}.}
#'   }
#'   Group columns (if any) are preserved. The full tibble is returned
#'   invisibly via \code{print()}. Use \code{as.data.frame()} or standard
#'   tibble methods for further processing.
#'
#' @section Method:
#' The function extracts the Taylor SE from \code{x$estimates$se}, then calls
#' the same estimator that produced \code{x} (resolved via \code{x$method})
#' with \code{variance = replicate_method}. The re-estimation uses
#' \code{x$design} and the grouping variables from \code{x$by_vars}.
#'
#' Divergence is computed as:
#' \deqn{ratio = se_{replicate} / se_{taylor}}
#' \deqn{diverges = |ratio - 1| > threshold}
#'
#' A ratio substantially different from 1 indicates that the Taylor
#' approximation may be unreliable for this design (e.g., sparse strata,
#' non-linear estimator). Replication-based variance is generally more robust
#' but slower to compute.
#'
#' @references
#' Wolter, K.M. 2007. Introduction to Variance Estimation, 2nd ed. Springer.
#'
#' Lumley, T. 2010. Complex Surveys: A Guide to Analysis Using R. Wiley.
#'
#' @examples
#' data("example_counts", package = "tidycreel")
#' data("example_interviews", package = "tidycreel")
#' cal <- unique(example_counts[, c("date", "day_type")])
#' design <- creel_design(cal, date = date, strata = day_type)
#' design <- suppressWarnings(add_counts(design, example_counts))
#' design <- suppressWarnings(add_interviews(
#'   design, example_interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration
#' ))
#' taylor_est <- suppressWarnings(estimate_catch_rate(design))
#' cmp <- suppressWarnings(compare_variance(taylor_est))
#' print(cmp)
#'
#' @export
compare_variance <- function(x,
                             replicate_method = c("bootstrap", "jackknife"),
                             conf_level = 0.95,
                             divergence_threshold = 0.10,
                             ...) {
  replicate_method <- match.arg(replicate_method)

  # Input validation
  if (!inherits(x, "creel_estimates")) {
    cli::cli_abort(c(
      "{.arg x} must be a {.cls creel_estimates} object.",
      "x" = "{.arg x} is {.cls {class(x)[1]}}.",
      "i" = paste0(
        "Produce a {.cls creel_estimates} object with ",
        "{.fn estimate_catch_rate} or {.fn estimate_effort}."
      )
    ))
  }

  if (is.null(x$design)) {
    cli::cli_abort(c(
      "No design stored in {.arg x}.",
      "x" = "{.field x$design} is NULL.",
      "i" = paste0(
        "The design reference is stored automatically when calling ",
        "{.fn estimate_catch_rate}. Re-run with the same design object."
      )
    ))
  }

  if (!is.numeric(divergence_threshold) ||
        length(divergence_threshold) != 1 ||
        divergence_threshold <= 0) {
    cli::cli_abort(c(
      "{.arg divergence_threshold} must be a positive number.",
      "x" = "Got {.val {divergence_threshold}}."
    ))
  }

  # Determine which estimator to call based on x$method
  method_str <- x$method
  by_vars   <- x$by_vars

  # Route to the correct re-estimation function
  estimator_fn <- resolve_variance_estimator(method_str) # nolint: object_usage_linter

  # Re-estimate with replicate variance
  replicate_est <- tryCatch(
    {
      if (is.null(by_vars) || length(by_vars) == 0) {
        estimator_fn(
          x$design,
          variance   = replicate_method,
          conf_level = conf_level,
          ...
        )
      } else {
        # For grouped re-estimation, inject a pre-evaluated by argument.
        # We temporarily set the by columns in a known position and call
        # with a formula-based approach via dplyr::vars.
        # Build a character vector of by columns and use tidyselect::all_of
        by_vars_local <- by_vars
        estimator_fn(
          x$design,
          by         = tidyselect::all_of(by_vars_local),
          variance   = replicate_method,
          conf_level = conf_level,
          ...
        )
      }
    },
    error = function(e) {
      cli::cli_abort(c(
        "Re-estimation with {.val {replicate_method}} variance failed.",
        "x" = conditionMessage(e),
        "i" = paste0(
          "Check that {.arg x$design} is still valid and that the ",
          "{.val {replicate_method}} method is supported for this design."
        )
      ))
    }
  )

  # Extract SEs
  se_taylor     <- x$estimates$se
  se_replicate  <- replicate_est$estimates$se

  # Build output tibble, preserving group columns
  est_df <- x$estimates
  group_cols <- setdiff(
    names(est_df),
    c("estimate", "se", "ci_lower", "ci_upper", "n", "method")
  )

  divergence_ratio <- ifelse(
    se_taylor == 0,
    NA_real_,
    se_replicate / se_taylor
  )
  diverges_flag <- !is.na(divergence_ratio) &
    (abs(divergence_ratio - 1) > divergence_threshold)

  se_tbl <- tibble::tibble(
    se_taylor        = se_taylor,
    se_replicate     = se_replicate,
    divergence_ratio = divergence_ratio,
    diverges_flag    = diverges_flag
  )

  if (length(group_cols) > 0) {
    out <- dplyr::bind_cols(est_df[, group_cols, drop = FALSE], se_tbl)
  } else {
    out <- se_tbl
  }

  # Warn for any divergent row
  n_diverge <- sum(diverges_flag, na.rm = TRUE)
  if (n_diverge > 0) {
    thresh_pct <- round(divergence_threshold * 100) # nolint: object_usage_linter
    cli::cli_warn(c(
      paste0(
        "{n_diverge} row{?s} show SE divergence > {thresh_pct}% ",
        "between Taylor and {replicate_method} variance."
      ),
      "i" = paste0(
        "Taylor linearization may be unreliable for this design. ",
        "Consider using {.code variance = \"{replicate_method}\"} for ",
        "final estimates."
      )
    ))
  }

  result <- structure(
    out,
    taylor_method    = x$variance_method,
    replicate_method = replicate_method,
    n_diverge        = n_diverge,
    divergence_threshold = divergence_threshold,
    class = c("creel_variance_comparison", class(out))
  )

  result
}

#' Resolve re-estimation function from a creel_estimates method string
#'
#' @keywords internal
#' @noRd
resolve_variance_estimator <- function(method_str) {
  if (grepl("cpue|hpue|rpue|catch.rate|ratio", method_str, ignore.case = TRUE)) {
    return(function(design, ...) {
      suppressWarnings(estimate_catch_rate(design, ...))
    })
  }
  if (grepl("effort", method_str, ignore.case = TRUE)) {
    return(function(design, ...) {
      suppressWarnings(estimate_effort(design, ...))
    })
  }
  # Fallback: try estimate_catch_rate
  cli::cli_warn(c(
    "Cannot determine estimator from method string {.val {method_str}}.",
    "i" = "Defaulting to {.fn estimate_catch_rate} for re-estimation."
  ))
  function(design, ...) suppressWarnings(estimate_catch_rate(design, ...))
}

#' Print a creel_variance_comparison object
#'
#' @param x A \code{creel_variance_comparison} object.
#' @param ... Additional arguments (ignored).
#' @return \code{x}, invisibly.
#' @export
print.creel_variance_comparison <- function(x, ...) {
  cli::cli_h1("Variance Comparison: Taylor vs. {attr(x, 'replicate_method')}")
  cli::cli_text(
    "Divergence threshold: {round(attr(x, 'divergence_threshold') * 100)}%"
  )
  n_div <- attr(x, "n_diverge")
  if (n_div == 0) {
    cli::cli_alert_success(
      "All rows within threshold."
    )
  } else {
    cli::cli_alert_warning(
      "{n_div} row{?s} exceed divergence threshold."
    )
  }
  cat("\n")
  print(tibble::as_tibble(x), ...)
  invisible(x)
}

#' Coerce creel_variance_comparison to data.frame
#'
#' @param x A \code{creel_variance_comparison} object.
#' @param ... Additional arguments passed to \code{as.data.frame.tbl_df}.
#' @return A plain \code{data.frame}.
#' @export
as.data.frame.creel_variance_comparison <- function(x, ...) {
  as.data.frame(tibble::as_tibble(x), ...)
}
