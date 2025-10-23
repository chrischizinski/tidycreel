#' Extract Standard Errors from Survey Estimates
#'
#' Utility function to extract standard errors from survey package estimates
#' using the preferred method (survey::SE) with fallback to variance attributes.
#'
#' @param est Survey estimate object from `survey::svyby()` or similar
#' @param n_rows Expected number of rows in the output (for validation)
#'
#' @return Numeric vector of standard errors, or NA if extraction fails
#' @keywords internal
#' @noRd
tc_extract_se <- function(est, n_rows) {
  # Try survey::SE first (preferred method)
  se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)

  if (!inherits(se_try, "try-error") && length(se_try) == n_rows) {
    return(se_try)
  }

  # Fallback: extract from variance attribute
  V <- attr(est, "var")
  if (!is.null(V) && length(V) > 0) {
    return(sqrt(diag(V)))
  }

  # If all else fails, return NA
  rep(NA_real_, n_rows)
}
