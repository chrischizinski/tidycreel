# Bus-route estimation utilities ----
# Functions that operate on creel_estimates objects produced by bus-route
# estimators. Separated from creel-design.R (Layer 1) because these functions
# consume Layer 2 (estimation) output, not Layer 1 (design) objects.

#' Extract per-site effort contributions from a bus-route estimate
#'
#' Returns the per-site calculation table (\eqn{e_i}, \eqn{\pi_i}, \eqn{e_i/\pi_i}) stored as an
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
#' cal <- data.frame(
#'   date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
#'   day_type = "weekday"
#' )
#' sf <- data.frame(
#'   site = c("A", "B"),
#'   circuit = c("am", "am"),
#'   p_site = c(0.6, 0.4),
#'   p_period = rep(0.5, 2)
#' )
#' design_br <- creel_design(
#'   cal,
#'   date = date, strata = day_type,
#'   survey_type = "bus_route", sampling_frame = sf,
#'   site = site, circuit = circuit,
#'   p_site = p_site, p_period = p_period
#' )
#' interviews <- data.frame(
#'   date = as.Date(c("2024-06-03", "2024-06-04")),
#'   site = c("A", "B"), circuit = c("am", "am"),
#'   catch_total = c(3L, 2L), hours_fished = c(2.0, 1.5),
#'   trip_status = c("complete", "complete"),
#'   trip_duration = c(2.0, 1.5),
#'   n_counted = c(5L, 4L), n_interviewed = c(3L, 2L)
#' )
#' design_br <- add_interviews(
#'   design_br, interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration,
#'   n_counted = n_counted, n_interviewed = n_interviewed
#' )
#' result <- estimate_effort(design_br)
#' get_site_contributions(result)
#'
#' @family "Bus-Route Helpers"
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
