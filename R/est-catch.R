#' Catch/Harvest Total Estimator (survey-first)
#'
#' Design-based estimation of total catch or harvest from interview data
#' using the `survey` package. Returns tidy totals by groups with standard
#' errors and Wald confidence intervals.
#'
#' @param design A `svydesign`/`svrepdesign` over interviews, or a
#'   `creel_design` with `interviews` (an equal-weight design is constructed
#'   if needed, with a warning).
#' @param by Character vector of grouping variables in the interview data.
#' @param response One of `"catch_total"`, `"catch_kept"`, or `"weight_total"`.
#'   Determines the total being estimated.
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#'
#' @importFrom stats as.formula qnorm
#' @seealso [survey::svytotal()], [survey::svyby()].
#' @export
est_catch <- function(design,
                      by = NULL,
                      response = c("catch_total", "catch_kept", "weight_total"),
                      conf_level = 0.95) {
  response <- match.arg(response)
  svy <- tc_interview_svy(design)
  vars <- svy$variables
  tc_abort_missing_cols(vars, response, context = "est_catch")

  by <- tc_group_warn(by %||% character(), names(vars))

  if (length(by) > 0) {
    by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
    est <- survey::svyby(
      as.formula(paste0("~", response)),
      by = by_formula,
      design = svy,
      FUN = survey::svytotal,
      na.rm = TRUE,
      keep.names = FALSE
    )
    out <- tibble::as_tibble(est)
    names(out)[names(out) == response] <- "estimate"
    se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
    if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
      out$se <- se_try
    } else {
      var_mat <- attr(est, "var")
      out$se <- if (!is.null(var_mat) && length(var_mat) > 0) {
        sqrt(diag(var_mat))
      } else {
        rep(NA_real_, nrow(out))
      }
    }
    z <- stats::qnorm(1 - (1 - conf_level)/2)
    out$ci_low <- out$estimate - z * out$se
    out$ci_high <- out$estimate + z * out$se
    n_by <- vars |>
      dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
      dplyr::summarise(n = dplyr::n(), .groups = "drop")
    out <- dplyr::left_join(out, n_by, by = by)
    out$method <- paste0("catch_total:", response)
    out$diagnostics <- replicate(nrow(out), list(NULL))
    return(dplyr::select(
      out,
      dplyr::all_of(by),
      estimate,
      se,
      ci_low,
      ci_high,
      n,
      method,
      diagnostics
    ))
  } else {
    total_est <- survey::svytotal(
      as.formula(paste0("~", response)),
      svy,
      na.rm = TRUE
    )
    estimate <- as.numeric(total_est[1])
    se <- sqrt(as.numeric(vcov(total_est)))
    ci <- tc_confint(estimate, se, level = conf_level)
    n <- nrow(vars)
    return(tibble::tibble(
      estimate = estimate, se = se, ci_low = ci[1], ci_high = ci[2], n = n,
      method = paste0("catch_total:", response), diagnostics = list(NULL)
    ))
  }
}
