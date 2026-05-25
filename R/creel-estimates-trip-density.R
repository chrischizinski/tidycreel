#' Estimate angler trips from extrapolated effort
#'
#' @description
#' Computes estimated angler trips (angler days) by dividing extrapolated
#' angler-hours effort by the mean trip length per stratum, with Delta Method
#' variance propagation (Powell 2007). This is a composable estimator: the
#' effort object must be pre-computed via \code{\link{estimate_effort}} before
#' calling this function.
#'
#' @param effort A \code{creel_estimates} object returned by
#'   \code{\link{estimate_effort}}. Must have a numeric \code{estimate} column
#'   and a \code{se} column in \code{effort$estimates}.
#' @param design A \code{creel_design} object with interview data containing
#'   a trip duration column (set via \code{add_interviews(trip_duration = ...)}).
#'   Used to compute per-stratum mean trip length.
#' @param conf_level Confidence level for confidence intervals. Default 0.95.
#' @param ... Reserved for future arguments.
#'
#' @return A \code{creel_estimates} object with \code{method = "angler-trips"}
#'   and \code{variance_method = "delta"}. The \code{estimates} tibble contains:
#'   \describe{
#'     \item{by_vars columns}{Any grouping columns from the effort object (if
#'       grouped).}
#'     \item{estimate}{Estimated angler trips per stratum (effort / mean trip
#'       length).}
#'     \item{se}{Standard error via Delta Method variance propagation.}
#'     \item{ci_lower}{Lower confidence interval bound.}
#'     \item{ci_upper}{Upper confidence interval bound.}
#'     \item{n}{Number of interviews contributing to mean trip length per
#'       stratum.}
#'   }
#'   For grouped effort, an \code{.overall} row is appended with
#'   \code{estimate = sum(stratum trips)} and \code{se} propagated by addition
#'   in quadrature.
#'
#' @references Powell, L. A. (2007). Approximating variance of demographic
#'   parameters using the delta method. \emph{Journal of Wildlife Management},
#'   71(3), 1018-1024.
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_exploitation_rate}}
#'
#' @export
estimate_angler_trips <- function(effort, design, conf_level = 0.95, ...) {

  # --- input guards ---
  if (!inherits(effort, "creel_estimates")) {
    cli::cli_abort(
      "{.arg effort} must be a {.cls creel_estimates} object from {.fn estimate_effort}."
    )
  }

  if (is.null(design$trip_duration_col)) {
    cli::cli_abort(c(
      "{.arg design} has no {.code trip_duration_col}.",
      "i" = "Set it via {.code add_interviews(trip_duration = <col>)}."
    ))
  }

  dur_col <- design$trip_duration_col

  # Check that by_vars columns exist in interviews
  if (!is.null(effort$by_vars)) {
    missing_bv <- setdiff(effort$by_vars, names(design$interviews))
    if (length(missing_bv) > 0) {
      cli::cli_abort(c(
        "Grouping column(s) from {.arg effort} are absent from {.code design$interviews}.",
        "x" = "Missing: {.val {missing_bv}}"
      ))
    }
  }

  # Warn on non-positive or NA duration values
  durations_all <- design$interviews[[dur_col]]
  bad_dur <- is.na(durations_all) | durations_all <= 0
  if (any(bad_dur)) {
    cli::cli_warn(c(
      "!" = paste0(
        sum(bad_dur),
        " interview(s) have non-positive or missing {.code {dur_col}} values."
      ),
      "i" = "These rows are excluded from the mean trip length calculation."
    ))
  }

  z <- stats::qnorm(1 - (1 - conf_level) / 2)

  # --- ungrouped case ---
  if (is.null(effort$by_vars)) {
    dur_vals <- durations_all[!is.na(durations_all) & durations_all > 0]
    n_int <- length(dur_vals)
    L     <- mean(dur_vals)
    se_L  <- stats::sd(dur_vals) / sqrt(n_int)

    if (L <= 0) {
      cli::cli_abort(
        "Mean trip length is zero or negative — check {.code {dur_col}} values."
      )
    }

    E     <- effort$estimates$estimate
    se_E  <- effort$estimates$se

    var_trips <- se_E^2 / L^2 + E^2 * se_L^2 / L^4
    se_trips  <- sqrt(var_trips)
    trips     <- E / L

    estimates_df <- tibble::tibble(
      estimate = trips,
      se       = se_trips,
      ci_lower = trips - z * se_trips,
      ci_upper = trips + z * se_trips,
      n        = n_int
    )

    return(
      new_creel_estimates(
        estimates       = estimates_df,
        method          = "angler-trips",
        variance_method = "delta",
        design          = NULL,
        conf_level      = conf_level,
        by_vars         = NULL
      )
    )
  }

  # --- grouped case ---
  interview_df <- design$interviews
  interview_df$.duration <- interview_df[[dur_col]]

  # Compute per-stratum mean trip length
  summary_df <- dplyr::summarise(
    dplyr::group_by(interview_df, dplyr::across(dplyr::all_of(effort$by_vars))),
    mean_L       = mean(.duration, na.rm = TRUE),
    se_L         = stats::sd(.duration, na.rm = TRUE) / sqrt(dplyr::n()),
    n_interviews = dplyr::n(),
    .groups      = "drop"
  )

  # Guard against zero mean trip length
  if (any(summary_df$mean_L <= 0, na.rm = TRUE)) {
    cli::cli_abort(
      "Mean trip length is zero or negative in at least one stratum — check {.code {dur_col}} values."
    )
  }

  # Join effort estimates with interview summary
  joined <- dplyr::left_join(effort$estimates, summary_df, by = effort$by_vars)

  # Guard against join key mismatches producing NA mean_L
  na_strata <- joined[is.na(joined$mean_L), effort$by_vars, drop = FALSE]
  if (nrow(na_strata) > 0) {
    cli::cli_abort(c(
      "Stratum key mismatch: some effort rows did not match any interview group.",
      "x" = "Unmatched strata: {.val {apply(na_strata, 1, paste, collapse = ' / ')}}"
    ))
  }

  # Row-wise Delta Method
  E         <- joined$estimate
  se_E      <- joined$se
  L         <- joined$mean_L
  se_L_vec  <- joined$se_L

  var_trips <- se_E^2 / L^2 + E^2 * se_L_vec^2 / L^4
  trips     <- E / L
  se_trips  <- sqrt(var_trips)

  # Per-stratum rows
  stratum_rows <- tibble::tibble(
    dplyr::select(joined, dplyr::all_of(effort$by_vars)),
    estimate = trips,
    se       = se_trips,
    ci_lower = trips - z * se_trips,
    ci_upper = trips + z * se_trips,
    n        = joined$n_interviews
  )

  # .overall row: additive aggregate
  overall_est <- sum(trips)
  overall_var <- sum(var_trips)
  overall_se  <- sqrt(overall_var)

  overall_vals <- stats::setNames(
    rep(".overall", length(effort$by_vars)),
    effort$by_vars
  )
  overall_row <- tibble::as_tibble(as.list(overall_vals))
  overall_row$estimate <- overall_est
  overall_row$se       <- overall_se
  overall_row$ci_lower <- overall_est - z * overall_se
  overall_row$ci_upper <- overall_est + z * overall_se
  overall_row$n        <- sum(joined$n_interviews)

  estimates_df <- dplyr::bind_rows(stratum_rows, overall_row)

  new_creel_estimates(
    estimates       = estimates_df,
    method          = "angler-trips",
    variance_method = "delta",
    design          = NULL,
    conf_level      = conf_level,
    by_vars         = effort$by_vars
  )
}
