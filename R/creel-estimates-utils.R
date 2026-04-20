# Bus-route estimation utilities ----
# Functions that operate on creel_estimates objects produced by bus-route
# estimators. Separated from creel-design.R (Layer 1) because these functions
# consume Layer 2 (estimation) output, not Layer 1 (design) objects.

#' Extract per-site effort contributions from a bus-route estimate
#'
#' Returns the per-site calculation table (eᵢ, πᵢ, eᵢ/πᵢ) stored as an
#' attribute on effort estimate objects returned by [estimate_effort()] for
#' bus-route survey designs. This table enables traceability of the
#' Horvitz-Thompson estimator (Jones & Pollock 2012, Eq. 19.4) and supports
#' validation against published examples (Malvestuto 1996, Box 20.6).
#'
#' @param x A creel_estimates object returned by [estimate_effort()] for a
#'   bus-route design.
#'
#' @return A tibble with columns:
#'   \item{site}{Site identifier (from sampling frame)}
#'   \item{circuit}{Circuit identifier (from sampling frame)}
#'   \item{e_i}{Enumeration-expanded effort at site i (effort * expansion)}
#'   \item{pi_i}{Inclusion probability for site i (p_site * p_period)}
#'   \item{e_i_over_pi_i}{Site contribution to Horvitz-Thompson estimate}
#'
#' @references
#' Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
#' estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
#' & T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883-919).
#' American Fisheries Society.
#'
#' @seealso [estimate_effort()], [get_sampling_frame()], [get_inclusion_probs()],
#'   [get_enumeration_counts()]
#'
#' @examples
#' # (Bus-route design + add_interviews() required — see estimate_effort() docs)
#' # After: result <- estimate_effort(design_with_br_interviews)
#' # site_table <- get_site_contributions(result)
#'
#' @export
get_site_contributions <- function(x) {
  # Guard 1: must be creel_estimates
  if (!inherits(x, "creel_estimates")) {
    cls <- class(x)[1] # nolint: object_usage_linter
    cli::cli_abort(c(
      "{.arg x} must be a {.cls creel_estimates} object.",
      "x" = "{.arg x} is {.cls {cls}}.",
      "i" = "Pass the result of {.fn estimate_effort} for a bus-route design."
    ))
  }

  # Guard 2: site_contributions attribute must be present
  site_tbl <- attr(x, "site_contributions")
  if (is.null(site_tbl)) {
    cli::cli_abort(c(
      "No site contributions found in this estimate.",
      "x" = "The {.field site_contributions} attribute is absent.",
      "i" = paste(
        "Site contributions are only stored for bus-route designs.",
        "Ensure {.fn estimate_effort} was called on a bus-route {.cls creel_design}."
      )
    ))
  }

  tibble::as_tibble(site_tbl)
}
