#' Tidy a creel_estimates object into a flat tibble
#'
#' @param x A \code{creel_estimates} object.
#' @param ... Unused; reserved for future arguments.
#' @return A tibble with one row per estimate. All columns from
#'   \code{x$estimates} are returned unchanged. Required columns:
#'   \code{estimate}, \code{se}, \code{ci_lower}, \code{ci_upper}, \code{n}.
#' @method tidy creel_estimates
#' @export
#' @importFrom generics tidy
#' @seealso \code{\link{write_estimates}}
#' @family "Reporting & Diagnostics"
tidy.creel_estimates <- function(x, ...) {
  tibble::as_tibble(x$estimates)
}
