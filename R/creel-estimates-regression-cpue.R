# Regression CPUE (CPUE3) and Estimator Comparison ----

#' Internal: OLS regression CPUE with leave-one-out jackknife SE (ungrouped)
#'
#' @keywords internal
#' @noRd
#' @importFrom stats lm coef qt
estimate_cpue_regression_total <- function(design, conf_level, force_origin) {
  interviews_data <- design$interviews
  catch_col  <- design$catch_col
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
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from regression CPUE.",
      "i" = "CPUE regression requires effort > 0."
    ))
    interviews_data <- interviews_data[!zero_eff, , drop = FALSE]
  }

  catch  <- as.numeric(interviews_data[[catch_col]])
  effort <- as.numeric(interviews_data[[effort_col]])
  n      <- length(catch)

  if (n < 3L) {
    cli::cli_abort(c(
      "Regression CPUE requires at least 3 interviews.",
      "x" = "Only {n} valid interview{?s} available after filtering."
    ))
  }

  beta_hat <- .ols_slope(catch, effort, force_origin)
  jk_se    <- .jackknife_slope_se(catch, effort, force_origin)

  df  <- n - 1L
  t_c <- qt((1 + conf_level) / 2, df = df)

  estimates_df <- tibble::tibble(
    estimate = beta_hat,
    se       = jk_se,
    ci_lower = beta_hat - t_c * jk_se,
    ci_upper = beta_hat + t_c * jk_se,
    n        = n
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = "regression-cpue",
    variance_method = "jackknife",
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}


#' Internal: grouped regression CPUE with jackknife SE
#'
#' @keywords internal
#' @noRd
estimate_cpue_reg_grouped <- function(design, by_vars, conf_level,  # nolint: object_length_linter
                                      force_origin) {
  interviews_data <- design$interviews
  catch_col  <- design$catch_col
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
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from regression CPUE.",
      "i" = "CPUE regression requires effort > 0."
    ))
    interviews_data <- interviews_data[!zero_eff, , drop = FALSE]
  }

  group_key <- do.call(paste, c(interviews_data[by_vars], sep = ""))
  groups    <- sort(unique(group_key))

  rows <- lapply(groups, function(gk) {
    idx    <- group_key == gk
    sub    <- interviews_data[idx, , drop = FALSE]
    catch  <- as.numeric(sub[[catch_col]])
    effort <- as.numeric(sub[[effort_col]])
    n_g    <- length(catch)

    if (n_g < 3L) {
      cli::cli_warn(c(
        "Group {.val {gk}}: fewer than 3 interviews; regression CPUE unreliable.",
        "i" = "Only {n_g} interview{?s} in this group."
      ))
    }

    beta_hat <- .ols_slope(catch, effort, force_origin)
    jk_se    <- .jackknife_slope_se(catch, effort, force_origin)
    df       <- n_g - 1L
    t_c      <- qt((1 + conf_level) / 2, df = max(df, 1L))

    grp_vals <- sub[1L, by_vars, drop = FALSE]
    rownames(grp_vals) <- NULL

    cbind(
      grp_vals,
      tibble::tibble(
        estimate = beta_hat,
        se       = jk_se,
        ci_lower = beta_hat - t_c * jk_se,
        ci_upper = beta_hat + t_c * jk_se,
        n        = n_g
      )
    )
  })

  estimates_df <- tibble::as_tibble(do.call(rbind, rows))

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = "regression-cpue",
    variance_method = "jackknife",
    design          = design,
    conf_level      = conf_level,
    by_vars         = by_vars
  )
}


#' OLS slope (with or without forced origin)
#'
#' @keywords internal
#' @noRd
.ols_slope <- function(catch, effort, force_origin) {
  if (force_origin) {
    sum(catch * effort) / sum(effort^2)
  } else {
    xbar <- mean(effort)
    ybar <- mean(catch)
    (sum((effort - xbar) * (catch - ybar))) / sum((effort - xbar)^2)
  }
}


#' Leave-one-out jackknife SE for OLS slope
#'
#' @keywords internal
#' @noRd
.jackknife_slope_se <- function(catch, effort, force_origin) {
  n        <- length(catch)
  beta_hat <- .ols_slope(catch, effort, force_origin)
  theta_i  <- vapply(seq_len(n), function(i) {
    .ols_slope(catch[-i], effort[-i], force_origin)
  }, numeric(1L))
  # Jackknife variance: (n-1)/n * sum((theta_i - mean(theta_i))^2)
  jk_var <- (n - 1L) / n * sum((theta_i - mean(theta_i))^2)
  sqrt(jk_var)
}


#' Compare CPUE estimators (ROM, MOR, Regression)
#'
#' @description
#' Runs all three CPUE estimators — Ratio-of-Means (ROM / CPUE\eqn{_2}),
#' Mean-of-Ratios (MOR / CPUE\eqn{_1}), and OLS regression slope with
#' jackknife SE (CPUE\eqn{_3}) — on the same creel design and returns a
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
#'     \eqn{C_i = \beta f_i + \varepsilon_i} with leave-one-out jackknife SE.
#'     Most robust when proportionality is violated (non-zero intercept).}
#' }
#'
#' @references
#' Petrere, M. et al. (2010). Catch-per-unit-effort: which estimator is best?
#' \emph{Fish. Res.} 106: 325–333.
#'
#' @examples
#' \dontrun{
#' design <- creel_design(calendar, date_col = date, strata_col = day_type) |>
#'   add_interviews(interviews, catch_col = catch_total,
#'                  effort_col = hours_fished, trip_status_col = trip_status)
#'
#' compare_cpue_estimators(design)
#' compare_cpue_estimators(design, by = day_type)
#' }
#'
#' @seealso \code{\link{estimate_catch_rate}}
#' @family "Estimation"
#' @export
compare_cpue_estimators <- function(design, by = NULL, conf_level = 0.95,
                                    force_origin = TRUE, verbose = FALSE) {
  checkmate::assert_class(design, "creel_design")
  checkmate::assert_number(conf_level, lower = 0.5, upper = 1.0)
  checkmate::assert_flag(force_origin)
  checkmate::assert_flag(verbose)

  by_quo <- rlang::enquo(by)

  .run <- function(est_name, est_str, use_trips_val = "complete") {
    if (verbose) cli::cli_inform("Running {.val {est_name}} estimator...")
    tryCatch({
      if (rlang::quo_is_null(by_quo)) {
        r <- estimate_catch_rate( # nolint: object_usage_linter
          design,
          variance     = if (est_str == "regression") "jackknife" else "taylor",
          conf_level   = conf_level,
          estimator    = est_str,
          use_trips    = use_trips_val,
          force_origin = force_origin
        )
      } else {
        r <- estimate_catch_rate( # nolint: object_usage_linter
          design,
          by           = !!by_quo,
          variance     = if (est_str == "regression") "jackknife" else "taylor",
          conf_level   = conf_level,
          estimator    = est_str,
          use_trips    = use_trips_val,
          force_origin = force_origin
        )
      }
      df <- r$estimates
      df$cpue_method <- est_name
      df
    }, error = function(e) {
      cli::cli_warn(c(
        "Estimator {.val {est_name}} failed.",
        "x" = conditionMessage(e)
      ))
      NULL
    })
  }

  rom_df  <- .run("rom",        "ratio-of-means", "complete")
  mor_df  <- .run("mor",        "mor",            "complete")
  reg_df  <- .run("regression", "regression",     "complete")

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
autoplot.cpue_comparison <- function(object, ...) {  # nolint: object_name_linter
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("{.pkg ggplot2} is required for {.fn autoplot.cpue_comparison}.")
  }
  by_cols <- setdiff(names(object),
                     c("cpue_method", "estimate", "se",
                       "ci_lower", "ci_upper", "n"))
  p <- ggplot2::ggplot(
    object,
    ggplot2::aes(
      x      = .data[["cpue_method"]],
      y      = .data[["estimate"]],
      ymin   = .data[["ci_lower"]],
      ymax   = .data[["ci_upper"]],
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
