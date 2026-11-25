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
#' @return List: `data` (zero-effort trips removed, with the fit columns),
#'   `svy` (the variance design), `vars` (the fit columns' names: catch,
#'   effort, catch x effort, effort^2).
#' @keywords internal
#' @noRd
regression_cpue_survey <- function(design, variance_method, by_vars = NULL, min_n = 3L,
                                   call = rlang::caller_env()) {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$angler_effort_col

  if (is.null(catch_col) || is.null(effort_col)) {
    creel_abort(c(
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
  # The interview-count floor first, so a sample too small to fit is told so
  # rather than refused for its days (or, with none left, crashing in svydesign).
  n <- nrow(interviews_data)
  if (n < min_n) {
    creel_abort(c(
      "Regression CPUE requires at least {min_n} interview{?s}.",
      "x" = "Only {n} valid interview{?s} available after filtering."
    ), call = call)
  }
  catch <- as.numeric(interviews_data[[catch_col]])
  effort <- as.numeric(interviews_data[[effort_col]])
  # Scratch names no user column already holds, so a `by` or strata column is
  # never overwritten by a fit variable.
  nm <- utils::tail(make.unique(c(names(interviews_data), ".reg_c", ".reg_e", ".reg_ce", ".reg_e2")), 4L)
  interviews_data[[nm[1]]] <- catch
  interviews_data[[nm[2]]] <- effort
  interviews_data[[nm[3]]] <- catch * effort
  interviews_data[[nm[4]]] <- effort^2

  strata_cols <- design$strata_cols
  # Backquoted, so a column such as `day type` survives the formula.
  strata_formula <- if (length(strata_cols) > 0L) stats::reformulate(paste0("`", strata_cols, "`")) else NULL
  svy <- build_interview_survey( # nolint: object_usage_linter
    interviews_data,
    strata = strata_formula,
    psu = interview_psu_col(design, interviews_data), frame = interview_day_frame(design) # nolint: object_usage_linter
  )
  svy <- get_variance_design(svy, variance_method, call = call, by = by_vars) # nolint: object_usage_linter
  list(data = interviews_data, svy = svy, vars = nm)
}

#' Slope, SE and interval on one (domain of the) survey
#'
#' @keywords internal
#' @noRd
regression_cpue_fit <- function(svy, force_origin, conf_level, vars, by_vars = NULL,
                                df = design_df(svy)) { # nolint: object_usage_linter
  unavailable <- list(estimate = NA_real_, se = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_, df = NA_real_)
  # Unknown catch or effort in the domain leaves the slope unknown, as it did
  # before: svyglm() would drop those trips silently and fit the rest.
  w <- if (inherits(svy, "svyrep.design")) stats::weights(svy, "sampling") else stats::weights(svy)
  in_domain <- w > 0
  if (anyNA(svy$variables[in_domain, vars, drop = FALSE])) {
    return(unavailable)
  }
  # The caller collects the undefined-draw conditions into one warning
  # (with_defined_draws()), so several groups are named together.
  if (force_origin) {
    fit <- suppressWarnings(draws_defined(survey::svyratio, by_vars)( # nolint: object_usage_linter
      stats::reformulate(vars[3]), svy, denominator = stats::reformulate(vars[4])
    ))
    est <- as.numeric(stats::coef(fit))
    se <- as.numeric(survey::SE(fit))
  } else {
    # A bootstrap draw holding none of the domain's days: svyglm() returns a
    # bare coefficient vector for it, with no warning to catch. The slope is
    # the full-sample weighted least-squares fit svyglm() would report; its
    # SE is unknown (GH #673).
    n_empty <- empty_draws(svy) # nolint: object_usage_linter
    if (n_empty > 0L) {
      wls <- stats::lm(
        stats::reformulate(vars[2], vars[1]),
        data = svy$variables[in_domain, , drop = FALSE], weights = w[in_domain]
      )
      est <- unname(stats::coef(wls)[vars[2]])
      if (is.na(est)) {
        return(unavailable)
      }
      signal_undefined_draws(svy, by_vars, n_empty) # nolint: object_usage_linter
      return(list(estimate = est, se = NA_real_, ci_lower = NA_real_, ci_upper = NA_real_, df = NA_real_))
    }
    fit <- tryCatch(
      suppressWarnings(
        draws_defined(survey::svyglm, by_vars)(stats::reformulate(vars[2], vars[1]), svy) # nolint: object_usage_linter
      ),
      error = function(e) NULL
    )
    # A slope the data cannot identify (one effort value throughout) has no
    # coefficient: unavailable for this domain, not an abort of every group.
    if (is.null(fit) || is.na(stats::coef(fit)[vars[2]]) || !vars[2] %in% rownames(stats::vcov(fit))) {
      return(unavailable)
    }
    est <- unname(stats::coef(fit)[vars[2]])
    se <- unname(sqrt(stats::vcov(fit)[vars[2], vars[2]]))
  }
  # Student's t on the design df, interview days minus strata, as every rate
  # (GH #705). Not confint.svyglm()'s residual df, which also subtracts the
  # intercept: the slope's sampling variance is the days', as the ratio's is.
  # A group is fitted on a subset of a replicate design, which cannot count
  # its own domain, so the caller passes the domain's df.
  ci <- design_t_ci(est, se, conf_level, df) # nolint: object_usage_linter
  list(estimate = est, se = se, ci_lower = ci$lower, ci_upper = ci$upper, df = df)
}

#' Internal: regression CPUE (ungrouped), day-clustered design-based SE
#'
#' @keywords internal
#' @noRd
estimate_cpue_regression_total <- function(design, conf_level, force_origin, variance_method = "taylor",
                                           call = rlang::caller_env()) {
  # Across strata, each stratum's slope weighted by its effort (GH #691).
  strata <- if (rate_pooling_on()) pooled_strata(design, NULL) else NULL # nolint: object_usage_linter
  if (!is.null(strata)) {
    pooled <- regression_pooled_total(design, strata, conf_level, force_origin, variance_method, call) # nolint: object_usage_linter
    pooled_df <- attr(pooled, "ci_df")
    attr(pooled, "ci_df") <- NULL
    return(new_creel_estimates( # nolint: object_usage_linter
      estimates = pooled,
      method = "regression-cpue",
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL,
      estimator = "regression",
      ci_df = pooled_df, # Satterthwaite over slopes and effort (GH #705)
      unit = rate_unit(design) # nolint: object_usage_linter
    ))
  }
  prep <- regression_cpue_survey(design, variance_method, call = call)
  n <- nrow(prep$data)
  fit <- with_defined_draws( # nolint: object_usage_linter
    regression_cpue_fit(prep$svy, force_origin, conf_level, prep$vars),
    call = call
  )
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
    ci_df = fit$df, # t on the design df (GH #705)
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
  variance_method = "taylor",
  call = rlang::caller_env()
) {
  # A group that is not a stratum, across strata, has no effort of its own to
  # weight its strata's slopes by (GH #691).
  strata <- if (rate_pooling_on()) pooled_strata(design, by_vars) else NULL # nolint: object_usage_linter
  if (!is.null(strata)) refuse_pooled_grouped_regression(strata, by_vars, call) # nolint: object_usage_linter
  # Groups take the small-group warning below, not the 3-interview floor; an
  # empty frame is still refused.
  prep <- regression_cpue_survey(design, variance_method, by_vars = by_vars, min_n = 1L, call = call)
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

  rows <- with_defined_draws(lapply(seq_along(keys), function(i) { # nolint: object_usage_linter
    k <- keys[[i]]
    n_g <- sum(row_key == k)
    if (n_g < 3L) {
      label <- tost_group_label(groups, i, by_vars) # nolint: object_usage_linter
      creel_warn(c(
        "Group {label}: fewer than 3 interviews; regression CPUE unreliable.",
        "i" = "Only {n_g} interview{?s} in this group."
      ),
      class = c("creel_warning_regression_small_group", "creel_warning")
      )
    }
    # A domain: the group's trips on the whole survey, every day kept.
    fit <- regression_cpue_fit(
      svy[svy_key == k, ], force_origin, conf_level, prep$vars, by_vars,
      df = design_df(svy, by_vars, k) # nolint: object_usage_linter
    )
    grp_vals <- groups[i, , drop = FALSE]
    rownames(grp_vals) <- NULL
    cbind(
      grp_vals,
      tibble::tibble(
        estimate = fit$estimate,
        se = fit$se,
        ci_lower = fit$ci_lower,
        ci_upper = fit$ci_upper,
        n = n_g,
        .ci_df = fit$df
      )
    )
  }), call = call)

  estimates_df <- tibble::as_tibble(do.call(rbind, rows))
  row_ci_df <- estimates_df$.ci_df
  estimates_df$.ci_df <- NULL

  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "regression-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    estimator = "regression",
    ci_df = row_ci_df, # t on the design df (GH #705)
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
#' # Counts too: each estimator weights the day types by their effort.
#' design <- creel_design(example_calendar, date = date, strata = day_type) |>
#'   add_counts(example_counts) |>
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
    creel_abort("All estimators failed. Check design has valid catch and effort columns.")
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
    creel_abort("{.pkg ggplot2} is required for {.fn autoplot.cpue_comparison}.")
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
