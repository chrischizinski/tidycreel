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
    L <- mean(dur_vals)
    if (n_int < 2L) {
      cli::cli_warn(c(
        "!" = "Only {n_int} valid trip duration value{?s}; SE of mean trip length is undefined.",
        "i" = "SE and CI will be {.val NA}. Point estimate (trips) is still returned."
      ))
      se_L <- NA_real_
    } else {
      se_L <- stats::sd(dur_vals) / sqrt(n_int)
    }

    if (L <= 0) {
      cli::cli_abort(
        "Mean trip length is zero or negative; check {.code {dur_col}} values."
      )
    }

    E <- effort$estimates$estimate
    se_E <- effort$estimates$se

    var_trips <- se_E^2 / L^2 + E^2 * se_L^2 / L^4
    se_trips <- sqrt(var_trips)
    trips <- E / L

    estimates_df <- tibble::tibble(
      estimate = trips,
      se = se_trips,
      ci_lower = trips - z * se_trips,
      ci_upper = trips + z * se_trips,
      n = n_int
    )

    return(
      new_creel_estimates(
        estimates = estimates_df,
        method = "angler-trips",
        variance_method = "delta",
        design = NULL,
        conf_level = conf_level,
        by_vars = NULL
      )
    )
  }

  # --- grouped case ---
  interview_df <- design$interviews
  interview_df$.duration <- interview_df[[dur_col]]

  # Compute per-stratum mean trip length
  summary_df <- dplyr::summarise(
    dplyr::group_by(interview_df, dplyr::across(dplyr::all_of(effort$by_vars))),
    mean_L = mean(.data$.duration, na.rm = TRUE),
    se_L = dplyr::if_else(
      dplyr::n() >= 2L,
      stats::sd(.data$.duration, na.rm = TRUE) / sqrt(dplyr::n()),
      NA_real_
    ),
    n_interviews = dplyr::n(),
    .groups = "drop"
  )

  # Warn about single-interview strata (SD undefined → SE/CI will be NA)
  singleton_strata <- summary_df[summary_df$n_interviews < 2L, , drop = FALSE]
  if (nrow(singleton_strata) > 0L) {
    stratum_labels <- apply(
      singleton_strata[effort$by_vars],
      1,
      paste,
      collapse = " / "
    )
    cli::cli_warn(c(
      "!" = "{nrow(singleton_strata)} stratum/strata {?has/have} only 1 interview; SE of mean trip length is undefined.",
      "i" = "SE and CI will be {.val NA} for: {.val {stratum_labels}}. Point estimates are still returned."
    ))
  }

  # Guard against zero mean trip length
  if (any(summary_df$mean_L <= 0, na.rm = TRUE)) {
    cli::cli_abort(
      "Mean trip length is zero or negative in at least one stratum; check {.code {dur_col}} values."
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
  E <- joined$estimate
  se_E <- joined$se
  L <- joined$mean_L
  se_L_vec <- joined$se_L

  var_trips <- se_E^2 / L^2 + E^2 * se_L_vec^2 / L^4
  trips <- E / L
  se_trips <- sqrt(var_trips)

  # Per-stratum rows
  stratum_rows <- tibble::tibble(
    dplyr::select(joined, dplyr::all_of(effort$by_vars)),
    estimate = trips,
    se = se_trips,
    ci_lower = trips - z * se_trips,
    ci_upper = trips + z * se_trips,
    n = joined$n_interviews
  )

  # .overall row: additive aggregate
  overall_est <- sum(trips)
  overall_var <- sum(var_trips)
  overall_se <- sqrt(overall_var)

  overall_vals <- stats::setNames(
    rep(".overall", length(effort$by_vars)),
    effort$by_vars
  )
  overall_row <- tibble::as_tibble(as.list(overall_vals))
  overall_row$estimate <- overall_est
  overall_row$se <- overall_se
  overall_row$ci_lower <- overall_est - z * overall_se
  overall_row$ci_upper <- overall_est + z * overall_se
  overall_row$n <- sum(joined$n_interviews)

  estimates_df <- dplyr::bind_rows(stratum_rows, overall_row)

  new_creel_estimates(
    estimates = estimates_df,
    method = "angler-trips",
    variance_method = "delta",
    design = NULL,
    conf_level = conf_level,
    by_vars = effort$by_vars
  )
}


#' Compute effort density as angler-hours per acre
#'
#' @description
#' Divides all effort estimate columns in a pre-computed \code{creel_estimates}
#' object by a surface area scalar (\code{acres}), producing angler-hours per
#' acre. Standard error propagates linearly because \code{acres} is a constant
#' (not a random variable), so no Delta Method is needed:
#' \code{se_per_acre = se_effort / acres}.
#'
#' This is a composable estimator: the effort object must be pre-computed via
#' \code{\link{estimate_effort}} before calling this function.
#'
#' @param effort A \code{creel_estimates} object returned by
#'   \code{\link{estimate_effort}}. Must contain \code{estimate}, \code{se},
#'   \code{ci_lower}, and \code{ci_upper} columns in \code{effort$estimates}.
#' @param acres A single positive numeric scalar giving the total lake surface
#'   area in acres. All effort estimate columns are divided by this value.
#' @param ... Reserved for future arguments.
#'
#' @return A \code{creel_estimates} object with \code{method = "effort-per-acre"}.
#'   The \code{estimates} tibble has the same rows as the input but with
#'   \code{estimate}, \code{se}, \code{ci_lower}, \code{ci_upper} (and
#'   \code{se_between}, \code{se_within} when present in the input) all divided
#'   by \code{acres}. Grouping columns (\code{by_vars}) and \code{n} are
#'   carried through unchanged. \code{variance_method} and \code{conf_level}
#'   are inherited from the input effort object.
#'
#' @seealso \code{\link{estimate_effort}}, \code{\link{estimate_angler_trips}}
#'
#' @export
estimate_effort_per_acre <- function(effort, acres, ...) {
  # --- input guards ---
  if (!inherits(effort, "creel_estimates")) {
    cli::cli_abort(
      "{.arg effort} must be a {.cls creel_estimates} object from {.fn estimate_effort}."
    )
  }

  if (!is.numeric(acres) || length(acres) != 1 || acres <= 0) {
    cli::cli_abort(
      "{.arg acres} must be a single positive number."
    )
  }

  # --- scale columns ---
  est_df <- effort$estimates

  est_df$estimate <- est_df$estimate / acres
  est_df$se <- est_df$se / acres
  est_df$ci_lower <- est_df$ci_lower / acres
  est_df$ci_upper <- est_df$ci_upper / acres

  if ("se_between" %in% names(est_df)) {
    est_df$se_between <- est_df$se_between / acres
  }
  if ("se_within" %in% names(est_df)) {
    est_df$se_within <- est_df$se_within / acres
  }

  # --- return ---
  new_creel_estimates(
    estimates = est_df,
    method = "effort-per-acre",
    variance_method = effort$variance_method,
    design = NULL,
    conf_level = effort$conf_level,
    by_vars = effort$by_vars
  )
}
