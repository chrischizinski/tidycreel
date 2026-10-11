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
#' @seealso [as_tibble.creel_estimates()] for the same table with the
#'   estimate's method, unit and confidence level as columns;
#'   \code{\link{write_estimates}}
#' @family "Reporting & Diagnostics"
tidy.creel_estimates <- function(x, ...) {
  out <- tibble::as_tibble(x$estimates)
  if (!"n" %in% names(out)) {
    out[["n"]] <- NA_integer_
  }
  out
}

#' Convert estimates to a tibble or data frame
#'
#' Turns a `creel_estimates` result into a plain table that dplyr, tidyr and
#' ggplot2 accept, so a result can be filtered, joined, bound to other results
#' or written out like any other data.
#'
#' A `creel_estimates` object keeps what the numbers mean (the method, the unit,
#' the confidence level) beside its table rather than in attributes on it,
#' because an ordinary `select()` or `filter()` drops attributes without a
#' word. The conversion copies that metadata into columns, so it travels with
#' every row and is visible if it is dropped.
#'
#' @param x A `creel_estimates` object, as returned by the `estimate_*()`
#'   functions.
#' @param ... Unused by `as_tibble()`; passed to [as.data.frame()] by
#'   `as.data.frame()`.
#' @param metadata If `TRUE` (the default), add the metadata columns described
#'   below. If `FALSE`, return the estimates table alone.
#'
#' @return A tibble (`as_tibble()`) or data frame (`as.data.frame()`) with one
#'   row per estimate: the grouping columns, `estimate`, `se`, `ci_lower`,
#'   `ci_upper`, `n` (`NA` where the estimator reports no sample size) and
#'   any further columns the estimator reports. With
#'   `metadata = TRUE` these columns follow:
#'   \describe{
#'     \item{`method`}{The estimation method, e.g. `"total"`.}
#'     \item{`estimator`}{The rate estimator asked for, e.g.
#'       `"ratio-of-means"`. Present only on results whose function takes an
#'       estimator choice.}
#'     \item{`variance_method`}{`"taylor"`, `"bootstrap"` or `"jackknife"`.}
#'     \item{`conf_level`}{Confidence level of `ci_lower` and `ci_upper`.}
#'     \item{`effort_target`}{What an effort or total estimate totals over,
#'       e.g. `"sampled_days"`. Present only on results that have one.}
#'     \item{`unit`}{The unit of `estimate`, e.g. `"angler-hours"`. `NA` means
#'       the unit could not be derived from the data, not that there is none.}
#'   }
#'
#'   Standard-error components (`x$se_components`) are not returned as
#'   columns, for the reason given in [tidy.creel_estimates()]: read them from
#'   the object or from `print()`.
#'
#'   A grouping column with the same name as a metadata column (a `by` column
#'   called `unit`, say) is an error rather than being overwritten; use
#'   `metadata = FALSE` and read the metadata from the object.
#'
#' @examples
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' est <- estimate_effort(design, by = day_type)
#'
#' tibble::as_tibble(est)
#' as.data.frame(est, metadata = FALSE)
#'
#' @seealso [tidy.creel_estimates()]
#' @family "Reporting & Diagnostics"
#' @name as_tibble.creel_estimates
NULL

#' @rdname as_tibble.creel_estimates
#' @importFrom tibble as_tibble
#' @export
as_tibble.creel_estimates <- function(x, ..., metadata = TRUE) {
  # Same guaranteed columns as tidy(): n is NA where the estimator reports no
  # sample size (mark-recapture harvest, for one).
  out <- tidy.creel_estimates(x)
  if (!isTRUE(metadata)) {
    return(out)
  }

  # A field that does not apply to this result (NULL) gives no column, so an
  # NA in a metadata column always means unknown, never "not applicable".
  meta <- list(
    method = x$method,
    estimator = x$estimator,
    variance_method = x$variance_method,
    conf_level = x$conf_level,
    effort_target = x$effort_target,
    unit = x$unit %||% NA_character_
  )
  meta <- meta[!vapply(meta, is.null, logical(1))]

  clash <- intersect(names(meta), names(out))
  if (length(clash) > 0L) {
    cli::cli_abort(
      c(
        "The estimates already have a column named {.field {clash}}.",
        "x" = "Adding the metadata {cli::qty(length(clash))}column{?s} would overwrite {?it/them}.",
        "i" = "Use {.code as_tibble(x, metadata = FALSE)} and read the metadata from the object."
      ),
      class = "creel_error_invalid_input"
    )
  }

  for (nm in names(meta)) {
    value <- meta[[nm]]
    if (!length(value) %in% c(1L, nrow(out))) {
      cli::cli_abort(
        "Metadata {.field {nm}} has {length(value)} values for {nrow(out)} row{?s}.",
        class = "creel_error_invalid_input"
      )
    }
    out[[nm]] <- rep_len(value, nrow(out))
  }
  out
}

#' @rdname as_tibble.creel_estimates
#' @export
as.data.frame.creel_estimates <- function(x, ..., metadata = TRUE) {
  as.data.frame(as_tibble.creel_estimates(x, metadata = metadata), ...)
}
