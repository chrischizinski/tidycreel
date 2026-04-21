#' Adjust a creel design for nonresponse bias
#'
#' Applies nonresponse weighting to a \code{creel_design} object by scaling
#' survey weights within each stratum by the inverse of the observed response
#' rate. The adjustment uses \code{\link[survey]{postStratify}} (default) or
#' \code{\link[survey]{calibrate}} to update the internal
#' \code{\link[survey]{svydesign}} object, so all downstream estimators
#' (\code{\link{estimate_effort}}, \code{\link{estimate_catch_rate}}, etc.)
#' automatically use the corrected weights.
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
#' @param method Character. Weighting method to apply. Either
#'   \code{"postStratify"} (default, adjusts weights to match known stratum
#'   totals inversely proportional to response rate) or \code{"calibrate"}
#'   (calibration estimator via \code{survey::calibrate}; requires stratum
#'   population totals in \code{response_rates}).
#' @param stratum_col Character. Name of the stratum column in
#'   \code{response_rates} (default: \code{"stratum"}).
#'
#' @return The input \code{creel_design} with adjusted weights. The updated
#'   design includes an attribute \code{"nonresponse_diagnostics"} (a tibble
#'   with columns \code{stratum}, \code{n_sampled}, \code{n_responded},
#'   \code{response_rate}, \code{weight_adjustment}) that can be retrieved
#'   with \code{attr(result, "nonresponse_diagnostics")}.
#'
#' @section Adjustment method:
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
#' cal <- unique(example_counts[, c("date", "day_type")])
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
#' adj_design <- adjust_nonresponse(design, resp)
#' attr(adj_design, "nonresponse_diagnostics")
#'
#' @family "Reporting & Diagnostics"
#' @export
adjust_nonresponse <- function(design,
                               response_rates,
                               method = c("postStratify", "calibrate"),
                               stratum_col = "stratum") {
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
    cli::cli_warn(c(
      paste0(
        "Low response rate (<50%) in {sum(low_resp)} ",
        "strat{?um/a}: {.val {low_strata}} ",
        "({pcts}%)."
      ),
      "i" = paste0(
        "Nonresponse bias correction relies on the missing-at-random ",
        "assumption. Low response rates may indicate selective refusal."
      )
    ))
  }

  # Build diagnostics tibble
  diagnostics <- tibble::tibble(
    stratum           = strata_vals,
    n_sampled         = n_sampled,
    n_responded       = n_responded,
    response_rate     = response_rate,
    weight_adjustment = weight_adj
  )

  # Apply weight adjustments ---------------------------------------------------
  # Determine which sub-design(s) to adjust
  adjusted_design <- design

  if (!is.null(design$counts_survey)) {
    adjusted_design$counts_survey <- apply_nonresponse_weights(
      design$counts_survey,
      design$strata_cols,
      diagnostics,
      method = method
    )
  }

  if (!is.null(design$interview_survey)) {
    adjusted_design$interview_survey <- apply_nonresponse_weights(
      design$interview_survey,
      design$strata_cols,
      diagnostics,
      method = method
    )
  }

  if (is.null(design$counts_survey) && is.null(design$interview_survey)) {
    cli::cli_warn(c(
      "No survey sub-designs found to adjust.",
      "i" = paste0(
        "Call {.fn add_counts} or {.fn add_interviews} before ",
        "{.fn adjust_nonresponse}."
      )
    ))
  }

  attr(adjusted_design, "nonresponse_diagnostics") <- diagnostics
  adjusted_design
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
apply_nonresponse_weights <- function(svy, strata_cols, diagnostics,
                                      method) {
  if (is.null(svy)) {
    return(NULL)
  }
  if (!inherits(svy, "survey.design") && !inherits(svy, "svyrep.design")) {
    return(svy)
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
    # For replicate designs: scale the scale slot
    svy$scale <- svy$scale * mean(wt_multipliers, na.rm = TRUE)
  } else {
    # For standard svydesign: scale prob / weights
    svy$prob <- svy$prob / wt_multipliers
    svy$allprob <- lapply(
      svy$allprob,
      function(p) p / wt_multipliers
    )
  }

  svy
}
