#' Tidy a creel_estimates object into a flat tibble
#'
#' @param x A \code{creel_estimates} object.
#' @param ... Unused; reserved for future arguments.
#' @return A tibble with one row per estimate. All columns from
#'   \code{x$estimates} are returned, plus \code{n} padded to
#'   \code{NA_integer_} when the estimator does not produce a sample size
#'   (e.g. mark-recapture harvest). Guaranteed columns:
#'   \code{estimate}, \code{se}, \code{ci_lower}, \code{ci_upper}, \code{n}.
#'
#'   \strong{Lossy for uncertainty components.} Named components -- the
#'   \code{x$se_components} list, and the \code{se_expansion} slot it mirrors --
#'   stay on the object and are deliberately not returned as columns. The
#'   contract distinguishes a component that does not apply or was never
#'   propagated (an absent name) from one that applies but is unknown
#'   (\code{NA}), and a tibble column collapses both to \code{NA} --
#'   reintroducing exactly the ambiguity the absent name was chosen to prevent.
#'   Read them from the object (\code{x$se_components}) or from \code{print()},
#'   which also states each component's relationship to \code{se}.
#'
#'   Note also that \code{se_between} and \code{se_within}, where present, do
#'   not reconstruct \code{se} on designs carrying a party-size expansion: the
#'   expansion term is a third contribution and is not among the visible
#'   columns.
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
