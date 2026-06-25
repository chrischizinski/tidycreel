#' Tidy a creel_estimates object into a flat tibble
#'
#' @param x A \code{creel_estimates} object.
#' @param ... Unused; reserved for future arguments.
#' @return A tibble with one row per estimate. All columns from
#'   \code{x$estimates} are returned, plus \code{n} padded to
#'   \code{NA_integer_} when the estimator does not produce a sample size
#'   (e.g. mark-recapture harvest). Guaranteed columns:
#'   \code{estimate}, \code{se}, \code{ci_lower}, \code{ci_upper}, \code{n}.
#' @method tidy creel_estimates
#' @export
#' @importFrom generics tidy
#' @seealso \code{\link{write_estimates}}
#' @family "Reporting & Diagnostics"
tidy.creel_estimates <- function(x, ...) {
  out <- tibble::as_tibble(x$estimates)
  if (!"n" %in% names(out)) {
    out[["n"]] <- NA_integer_
  }
  out
}
