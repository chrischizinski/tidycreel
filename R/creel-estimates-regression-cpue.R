# Regression CPUE (CPUE3) and Estimator Comparison ----

# The regression estimator is the slope of catch on effort across interviews.
# Through the origin it is sum(c e) / sum(e^2), a ratio of two totals, so it is
# estimated with svyratio(); with an intercept it is a regression coefficient,
# estimated with svyglm(). Both run on the same day-clustered interview survey
# as every other rate (GH #661, #665): the day is the primary sampling unit,
# a trip filter is a domain of every interviewed day (GH #663), `variance`
# selects Taylor, bootstrap or jackknife, and a stratum or group interviewed on
# one day is refused. Interview weights are equal, so the slopes are the
# ordinary least-squares ones; only their standard errors depend on the design.
# They used to come from a leave-one-INTERVIEW-out jackknife, which treated 12
# trips on one day as 12 independent units.

#' Interview frame and survey for the regression slope
#'
#' @return List: `data` (zero-effort trips removed, with the slope's
#'   `.reg_ce` = c e and `.reg_e2` = e^2 columns), `svy` (the variance design).
#' @keywords internal
#' @noRd
regression_cpue_survey <- function(design, variance_method, by_vars = NULL, call = rlang::caller_env()) {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$angler_effort_col

  if (is.null(catch_col) || is.null(effort_col)) {
    cli::cli_abort(c(
      "Regression CPUE requires catch and effort columns.",
      "x" = "Design missing {.field catch_col} or {.field angler_effort_col}.",
      "i" = "Call {.fn add_interviews} with {.arg catch_col} and {.arg effort_col}."
    ))
  }

  zero_eff <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_eff)) {
    n_zero <- sum(zero_eff) # nolint: object_usage_linter
    creel_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from regression CPUE.",
      "i" = "CPUE regression requires effort > 0."
    ),
    class = c("creel_warning_effort_excluded", "creel_warning")
    )
    interviews_data <- interviews_data[!zero_eff, , drop = FALSE]
  }
  catch <- as.numeric(interviews_data[[catch_col]])
  effort <- as.numeric(interviews_data[[effort_col]])
  interviews_data$.reg_c <- catch
  interviews_data$.reg_e <- effort
  interviews_data$.reg_ce <- catch * effort
  interviews_data$.reg_e2 <- effort^2

  strata_cols <- design$strata_cols
  strata_formula <- if (length(strata_cols) > 0L) stats::reformulate(strata_cols) else NULL
  svy <- build_interview_survey( # nolint: object_usage_linter
    interviews_data,
    strata = strata_formula,
    psu = interview_psu_col(design, interviews_data), frame = interview_day_frame(design) # nolint: object_usage_linter
  )
  svy <- get_variance_design(svy, variance_method, call = call, by = by_vars) # nolint: object_usage_linter
  list(data = interviews_data, svy = svy)
}

#' Slope, SE and interval on one (domain of the) survey
#'
#' @keywords internal
#' @noRd
regression_cpue_fit <- function(svy, force_origin, conf_level) {
  if (force_origin) {
    fit <- suppressWarnings(survey::svyratio(~.reg_ce, ~.reg_e2, svy))
    est <- as.numeric(stats::coef(fit))
    se <- as.numeric(survey::SE(fit))
    ci <- stats::confint(fit, level = conf_level)
  } else {
    fit <- suppressWarnings(survey::svyglm(.reg_c ~ .reg_e, design = svy))
    est <- unname(stats::coef(fit)[".reg_e"])
    se <- unname(sqrt(stats::vcov(fit)[".reg_e", ".reg_e"]))
    ci <- stats::confint(fit, parm = ".reg_e", level = conf_level)
  }
  list(estimate = est, se = se, ci_lower = unname(ci[1, 1]), ci_upper = unname(ci[1, 2]))
}

#' Internal: regression CPUE (ungrouped), day-clustered design-based SE
#'
#' @keywords internal
#' @noRd
estimate_cpue_regression_total <- function(design, conf_level, force_origin, variance_method = "taylor") {
  prep <- regression_cpue_survey(design, variance_method)
  n <- nrow(prep$data)
  if (n < 3L) {
    cli::cli_abort(c(
      "Regression CPUE requires at least 3 interviews.",
      "x" = "Only {n} valid interview{?s} available after filtering."
    ))
  }
  fit <- regression_cpue_fit(prep$svy, force_origin, conf_level)
  estimates_df <- tibble::tibble(
    estimate = fit$estimate,
    se = fit$se,
    ci_lower = fit$ci_lower,
    ci_upper = fit$ci_upper,
    n = n
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "regression-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    estimator = "regression",
    unit = rate_unit(design) # nolint: object_usage_linter
  )
}


#' Internal: grouped regression CPUE, each group a domain of the survey
#'
#' @keywords internal
#' @noRd
estimate_cpue_reg_grouped <- function(
  design,
  by_vars,
  conf_level, # nolint: object_length_linter
  force_origin,
  variance_method = "taylor"
) {
  prep <- regression_cpue_survey(design, variance_method, by_vars = by_vars)
  interviews_data <- prep$data
  svy <- prep$svy

  # Keyed with group_key(), not paste(sep = ""): pasting with no separator
  # merged groups such as ("a", "bc") and ("ab", "c").
  row_key <- group_key(interviews_data, by_vars) # nolint: object_usage_linter
  svy_key <- group_key(svy$variables, by_vars) # nolint: object_usage_linter
  first <- !duplicated(row_key)
  groups <- interviews_data[first, by_vars, drop = FALSE]
  keys <- row_key[first]
  ord <- do.call(order, unname(as.list(groups)))
  groups <- groups[ord, , drop = FALSE]
  keys <- keys[ord]

  rows <- lapply(seq_along(keys), function(i) {
    k <- keys[[i]]
    n_g <- sum(row_key == k)
    if (n_g < 3L) {
      creel_warn(c(
        "Group {.val {k}}: fewer than 3 interviews; regression CPUE unreliable.",
        "i" = "Only {n_g} interview{?s} in this group."
      ),
      class = c("creel_warning_regression_small_group", "creel_warning")
      )
    }
    # A domain: the group's trips on the whole survey, every day kept.
    fit <- regression_cpue_fit(svy[svy_key == k, ], force_origin, conf_level)
    grp_vals <- groups[i, , drop = FALSE]
    rownames(grp_vals) <- NULL
    cbind(
      grp_vals,
      tibble::tibble(
        estimate = fit$estimate,
        se = fit$se,
        ci_lower = fit$ci_lower,
        ci_upper = fit$ci_upper,
        n = n_g
      )
    )
  })

  estimates_df <- tibble::as_tibble(do.call(rbind, rows))

  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "regression-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    estimator = "regression",
    unit = rate_unit(design) # nolint: object_usage_linter
  )
}


#' Compare CPUE estimators (ROM, MOR, Regression)
#'
#' @description
#' Runs all three CPUE estimators — Ratio-of-Means (ROM / CPUE\eqn{_2}),
#' Mean-of-Ratios (MOR / CPUE\eqn{_1}), and the regression slope of catch on
#' effort (CPUE\eqn{_3}) — on the same creel design, all with Taylor
#' (linearization) standard errors on the day-clustered interview survey, and
#' returns a
#' combined tibble with a \code{cpue_method} column for side-by-side
#' comparison.
#'
#' This implements the Petrere et al. (2010) Table 1 estimator comparison
#' workflow. When the three estimators yield materially different estimates,
#' the choice of estimator matters; \code{compare_cpue_estimators()} makes
#' divergence visible.
#'
#' @param design A creel_design object with interviews attached. Must have
#'   \code{catch_col} and \code{angler_effort_col} set.
#' @param by Optional tidy selector for grouping variables. Passed to each
#'   underlying \code{\link{estimate_catch_rate}} call.
#' @param conf_level Numeric. Confidence level. Default 0.95.
#' @param force_origin Logical. Force regression through origin. Default
#'   \code{TRUE} (standard CPUE\eqn{_3} formulation).
#' @param verbose Logical. If \code{TRUE}, prints a brief message for each
#'   estimator run. Default \code{FALSE}.
#'
#' @return A tibble with columns \code{cpue_method} (character: \code{"rom"},
#'   \code{"mor"}, \code{"regression"}), plus \code{estimate}, \code{se},
#'   \code{ci_lower}, \code{ci_upper}, \code{n}, and any grouping columns
#'   when \code{by} is specified. The tibble has class
#'   \code{c("cpue_comparison", "tbl_df", "tbl", "data.frame")}.
#'
#' @details
#' Estimator definitions following Petrere et al. (2010):
#' \describe{
#'   \item{ROM (CPUE\eqn{_2})}{Ratio of means: total catch / total effort
#'     (survey::svyratio). Unbiased for complete trips.}
#'   \item{MOR (CPUE\eqn{_1})}{Mean of individual ratios:
#'     mean(catch\eqn{_i} / effort\eqn{_i}) (survey::svymean). Preferred
#'     for incomplete trips.}
#'   \item{Regression (CPUE\eqn{_3})}{OLS slope \eqn{\hat{\beta}} from
#'     \eqn{C_i = \beta f_i + \varepsilon_i}, its SE linearized on the
#'     day-clustered survey like the other two.
#'     Most robust when proportionality is violated (non-zero intercept).}
#' }
#'
#' @references
#' Petrere, M. Jr., Giacomini, H.C. & De Marco, P. Jr. (2010).
#' Catch-per-unit-effort: which estimator is best? \emph{Braz. J. Biol.}
#' 70: 483–491. \doi{10.1590/S1519-69842010005000010}
#'
#' @examples
#' design <- creel_design(example_calendar, date = date, strata = day_type) |>
#'   add_interviews(example_interviews,
#'     catch = catch_total, effort = hours_fished,
#'     trip_status = trip_status, n_anglers = n_anglers
#'   )
#'
#' compare_cpue_estimators(design)
#'
#' @seealso \code{\link{estimate_catch_rate}}
#' @family "Estimation"
#' @export
compare_cpue_estimators <- function(
  design,
  by = NULL,
  conf_level = 0.95,
  force_origin = TRUE,
  verbose = FALSE
) {
  checkmate::assert_class(design, "creel_design")
  checkmate::assert_number(conf_level, lower = 0.5, upper = 1.0)
  checkmate::assert_flag(force_origin)
  checkmate::assert_flag(verbose)

  by_quo <- rlang::enquo(by)

  .run <- function(est_name, est_str, use_trips_val = "complete") {
    if (verbose) {
      cli::cli_inform("Running {.val {est_name}} estimator...")
    }
    tryCatch(
      {
        if (rlang::quo_is_null(by_quo)) {
          r <- estimate_catch_rate(
            # nolint: object_usage_linter
            design,
            variance = "taylor",
            conf_level = conf_level,
            estimator = est_str,
            use_trips = use_trips_val,
            force_origin = force_origin
          )
        } else {
          r <- estimate_catch_rate(
            # nolint: object_usage_linter
            design,
            by = !!by_quo,
            variance = "taylor",
            conf_level = conf_level,
            estimator = est_str,
            use_trips = use_trips_val,
            force_origin = force_origin
          )
        }
        df <- r$estimates
        df$cpue_method <- est_name
        df
      },
      error = function(e) {
        creel_warn(c(
          "Estimator {.val {est_name}} failed.",
          "x" = conditionMessage(e)
        ),
        class = c("creel_warning_estimator_failed", "creel_warning")
        )
        NULL
      }
    )
  }

  rom_df <- .run("rom", "ratio-of-means", "complete")
  mor_df <- .run("mor", "mor", "complete")
  reg_df <- .run("regression", "regression", "complete")

  rows <- Filter(Negate(is.null), list(rom_df, mor_df, reg_df))
  if (length(rows) == 0L) {
    cli::cli_abort("All estimators failed. Check design has valid catch and effort columns.")
  }

  out <- do.call(rbind, rows)
  # Bring cpue_method to front
  out <- out[, c("cpue_method", setdiff(names(out), "cpue_method")), drop = FALSE]
  structure(
    tibble::as_tibble(out),
    class = c("cpue_comparison", "tbl_df", "tbl", "data.frame")
  )
}


#' @export
#' @importFrom ggplot2 ggplot aes geom_point geom_errorbar facet_wrap labs theme_bw theme
autoplot.cpue_comparison <- function(object, ...) {
  # nolint: object_name_linter
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("{.pkg ggplot2} is required for {.fn autoplot.cpue_comparison}.")
  }
  by_cols <- setdiff(names(object), c("cpue_method", "estimate", "se", "ci_lower", "ci_upper", "n"))
  p <- ggplot2::ggplot(
    object,
    ggplot2::aes(
      x = .data[["cpue_method"]],
      y = .data[["estimate"]],
      ymin = .data[["ci_lower"]],
      ymax = .data[["ci_upper"]],
      colour = .data[["cpue_method"]]
    )
  ) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_errorbar(width = 0.2) +
    ggplot2::labs(x = "Estimator", y = "CPUE (fish/hr)", colour = NULL) +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "none")
  if (length(by_cols) > 0L) {
    facet_formula <- stats::reformulate(by_cols)
    p <- p + ggplot2::facet_wrap(facet_formula)
  }
  p
}
