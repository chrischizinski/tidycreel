#' Adjust a creel design for nonresponse bias (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `adjust_nonresponse()` does not change any estimate, and never has (GH
#' #633). It is deprecated in tidycreel 9.0.0 and will be removed in a later
#' major release.
#'
#' * **Counts have no nonresponse.** An instantaneous count has no respondent
#'   (Pollock, Jones and Brown 1994 rate count-side refusals as not
#'   applicable). The count-side branch read a field no step sets, so it never
#'   ran.
#' * **A per-stratum adjustment cancels.** Every interview in a stratum is
#'   multiplied by the same factor, which cancels in that stratum's catch rate
#'   and so in every total built as stratum effort times stratum rate. The
#'   rate estimators rebuild their survey from the interviews and never read
#'   the re-weighted one.
#'
#' Record refusals instead with `add_interviews(refused = )` and report them
#' with [summarize_refusals()]. The diagnostics this function attaches
#' (response rate and weight factor per stratum) are still returned, with a
#' deprecation warning on every call.
#'
#' @param design A \code{creel_design} object with at least one survey
#'   sub-object already attached (\code{\link{add_counts}} or
#'   \code{\link{add_interviews}}).
#' @param response_rates A data frame or tibble with one row per stratum,
#'   containing at minimum the columns:
#'   \describe{
#'     \item{stratum}{Character or factor. Stratum identifier matching the
#'       values in the design's strata column.}
#'     \item{n_sampled}{Integer. Number of units approached for interview in
#'       the stratum.}
#'     \item{n_responded}{Integer. Number of units that actually responded.
#'       Must be \code{<= n_sampled}.}
#'   }
#' @param method Character. Weighting method to apply. Currently only
#'   \code{"postStratify"} (default) is implemented. It multiplies each
#'   observation's sampling weight by the inverse response rate for its stratum.
#'   Specifying \code{"calibrate"} raises an error; use \code{survey::calibrate}
#'   directly with population totals from your sampling frame.
#' @param stratum_col Character. Name of the stratum column in
#'   \code{response_rates} (default: \code{"stratum"}).
#'
#' @return The input \code{creel_design}, whose estimates are unchanged. The
#'   design includes an attribute \code{"nonresponse_diagnostics"} (a tibble
#'   with columns \code{stratum}, \code{n_sampled}, \code{n_responded},
#'   \code{response_rate}, \code{weight_adjustment}) that can be retrieved
#'   with \code{attr(result, "nonresponse_diagnostics")}.
#'
#' @section Adjustment method:
#' This describes the factors reported in \code{"nonresponse_diagnostics"}. No
#' estimator reads the re-weighted survey (see Description).
#'
#' For each stratum \eqn{h}:
#' \deqn{response\_rate_h = n\_responded_h / n\_sampled_h}
#' \deqn{weight\_adjustment_h = 1 / response\_rate_h}
#'
#' The original weights are multiplied by \code{weight_adjustment_h}, which
#' upweights respondents to represent non-respondents (Armstrong & Overton 1977).
#' This assumes that respondents and non-respondents are exchangeable within
#' strata (a missing-at-random assumption). When this is implausible, a
#' sensitivity analysis comparing pre- and post-adjustment estimates is
#' recommended.
#'
#' @references
#' Armstrong, B.G. and Overton, W.S. 1977. Estimating nonresponse bias in
#' mail surveys. Journal of Marketing Research 14:396--402.
#'
#' Pollock, K.H., Jones, C.M. and Brown, T.L. 1994. Angler Survey Methods
#' and Their Applications in Fisheries Management. American Fisheries Society,
#' Bethesda, MD.
#'
#' @examples
#' data("example_counts", package = "tidycreel")
#' data("example_interviews", package = "tidycreel")
#' data("example_calendar", package = "tidycreel")
#' cal <- example_calendar # the season; the counts cover 14 of its 30 days
#' design <- creel_design(cal, date = date, strata = day_type)
#' design <- suppressWarnings(add_counts(design, example_counts))
#' design <- suppressWarnings(add_interviews(
#'   design, example_interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration
#' ))
#'
#' resp <- data.frame(
#'   stratum     = c("weekday", "weekend"),
#'   n_sampled   = c(80L, 60L),
#'   n_responded = c(72L, 48L)
#' )
#' adj_design <- suppressWarnings(adjust_nonresponse(design, resp))
#' attr(adj_design, "nonresponse_diagnostics")
#'
#' @family "Reporting & Diagnostics"
#' @export
adjust_nonresponse <- function(
  design,
  response_rates,
  method = c("postStratify", "calibrate"),
  stratum_col = "stratum"
) {
  # GH #633: every call, not once per session -- a user who believes the
  # estimates are adjusted must be told each time they run it.
  lifecycle::deprecate_warn(
    when = "9.0.0",
    what = "adjust_nonresponse()",
    details = c(
      x = paste(
        "It does not change any estimate: counts have no nonresponse, and a",
        "per-stratum weight cancels in each stratum's catch rate."
      ),
      i = paste(
        "Record refusals with `add_interviews(refused = )` and report them",
        "with `summarize_refusals()`."
      )
    ),
    always = TRUE
  )
  method <- match.arg(method)

  # Input validation -----------------------------------------------------------
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  if (!is.data.frame(response_rates)) {
    cli::cli_abort(c(
      "{.arg response_rates} must be a data frame or tibble.",
      "x" = "{.arg response_rates} is {.cls {class(response_rates)[1]}}."
    ))
  }

  required_cols <- c(stratum_col, "n_sampled", "n_responded")
  missing_cols <- setdiff(required_cols, names(response_rates))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "{.arg response_rates} is missing required columns.",
      "x" = "Missing: {.field {missing_cols}}.",
      "i" = paste0(
        "Required columns: {.field stratum} (or the value of ",
        "{.arg stratum_col}), {.field n_sampled}, {.field n_responded}."
      )
    ))
  }

  # Validate n_responded <= n_sampled
  bad_rows <- response_rates$n_responded > response_rates$n_sampled
  if (any(bad_rows, na.rm = TRUE)) {
    cli::cli_abort(c(
      "{.field n_responded} must be <= {.field n_sampled} for all strata.",
      "x" = paste0(
        "Strata with invalid values: ",
        "{.val {response_rates[[stratum_col]][bad_rows]}}."
      )
    ))
  }

  # Compute response rates and adjustments
  strata_vals <- response_rates[[stratum_col]]
  n_sampled <- as.integer(response_rates$n_sampled)
  n_responded <- as.integer(response_rates$n_responded)

  # Abort on zero-response strata
  zero_resp <- n_responded == 0L
  if (any(zero_resp, na.rm = TRUE)) {
    cli::cli_abort(c(
      "Zero-response strata detected: adjustment is undefined.",
      "x" = paste0(
        "Strata with zero responses: ",
        "{.val {strata_vals[zero_resp]}}."
      ),
      "i" = paste0(
        "Remove these strata from {.arg response_rates} or collapse ",
        "them with adjacent strata before adjusting."
      )
    ))
  }

  response_rate <- n_responded / n_sampled
  weight_adj <- 1 / response_rate

  # Warn when any stratum has < 50% response rate
  low_resp <- response_rate < 0.50
  if (any(low_resp, na.rm = TRUE)) {
    low_strata <- strata_vals[low_resp] # nolint: object_usage_linter
    pcts <- round(100 * response_rate[low_resp]) # nolint: object_usage_linter
    creel_warn(c(
      paste0(
        "Low response rate (<50%) in {sum(low_resp)} ",
        "strat{?um/a}: {.val {low_strata}} ",
        "({pcts}%)."
      ),
      "i" = paste0(
        "Nonresponse bias correction relies on the missing-at-random ",
        "assumption. Low response rates may indicate selective refusal."
      )
    ),
    class = c("creel_warning_low_response_rate", "creel_warning")
    )
  }

  # Build diagnostics tibble
  diagnostics <- tibble::tibble(
    stratum = strata_vals,
    n_sampled = n_sampled,
    n_responded = n_responded,
    response_rate = response_rate,
    weight_adjustment = weight_adj
  )

  # Apply weight adjustments ---------------------------------------------------
  # Determine which sub-design(s) to adjust
  adjusted_design <- design

  # No count-side branch: it read design$counts_survey, a field no step sets,
  # so it never ran (GH #633), and an unknown field name now errors (#594).
  if (!is.null(design$interview_survey)) {
    adjusted_design$interview_survey <- apply_nonresponse_weights(
      design$interview_survey,
      design$strata_cols,
      diagnostics,
      method = method
    )
  }

  if (is.null(design$interview_survey)) {
    creel_inform(c(
      "No survey sub-designs found to adjust.",
      "i" = paste0(
        "Call {.fn add_interviews} before ",
        "{.fn adjust_nonresponse}."
      )
    ),
    class = c("creel_message_no_subdesigns", "creel_message")
    )
  }

  attr(adjusted_design, "nonresponse_diagnostics") <- diagnostics
  # Not a design step (it is not replayed by read_design()), so its warnings
  # are put on the design here (GH #496).
  record_design_warnings(adjusted_design) # nolint: object_usage_linter
}

#' Apply nonresponse weight adjustment to an svydesign
#'
#' @param svy An \code{svydesign} or \code{svrepdesign} object.
#' @param strata_cols Character vector of strata column names.
#' @param diagnostics Tibble with stratum, response_rate, weight_adjustment.
#' @param method Character. "postStratify" or "calibrate".
#' @return Updated svydesign.
#' @keywords internal
#' @noRd
apply_nonresponse_weights <- function(svy, strata_cols, diagnostics, method) {
  if (is.null(svy)) {
    return(NULL)
  }
  if (!inherits(svy, "survey.design") && !inherits(svy, "svyrep.design")) {
    return(svy)
  }

  # "calibrate" requires population totals not available here; it must be
  # called directly via survey::calibrate() with a suitable population frame.
  if (method == "calibrate") {
    cli::cli_abort(c(
      '{.val "calibrate"} method is not yet implemented in {.fn adjust_nonresponse}.',
      "i" = paste0(
        'Use {.val "postStratify"} (the default), which applies the ',
        "inverse-response-rate weight scaling documented in the function."
      ),
      "i" = paste0(
        "For calibration, call {.fn survey::calibrate} directly with ",
        "population totals derived from your sampling frame."
      )
    ))
  }

  # Build stratum-weight mapping
  strat_weights <- setNames(
    diagnostics$weight_adjustment,
    as.character(diagnostics$stratum)
  )

  # Determine the stratum column in the survey data
  svy_data <- svy$variables
  if (is.null(svy_data)) {
    return(svy)
  }

  strat_col <- NULL
  for (sc in strata_cols) {
    if (sc %in% names(svy_data)) {
      strat_col <- sc
      break
    }
  }
  if (is.null(strat_col)) {
    return(svy)
  }

  strat_values <- as.character(svy_data[[strat_col]])

  # Scale weights
  wt_multipliers <- strat_weights[strat_values]
  wt_multipliers[is.na(wt_multipliers)] <- 1.0

  if (inherits(svy, "svyrep.design")) {
    # Scale per-observation base weights (pweights = sampling weights = 1/prob).
    # Multiply by per-stratum nonresponse multiplier to upweight respondents.
    svy$pweights <- svy$pweights * wt_multipliers
    # Scale replicate weight matrix row-wise by the same per-observation
    # multipliers so that variance estimates reflect the adjusted weights.
    rw <- as.matrix(svy$repweights)
    svy$repweights <- sweep(rw, 1, wt_multipliers, "*")
  } else {
    # For standard svydesign: prob is the inclusion probability (lower = higher
    # weight), so divide by multiplier to increase weight for respondents.
    svy$prob <- svy$prob / wt_multipliers
    svy$allprob <- lapply(
      svy$allprob,
      function(p) p / wt_multipliers
    )
  }

  svy
}
