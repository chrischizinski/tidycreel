# est_effort_camera_mi() -------------------------------------------------------

#' Pool camera effort estimates across multiply imputed count data sets
#'
#' `r lifecycle::badge("experimental")`
#'
#' @description
#' Estimates camera effort once per completed data set produced by
#' [impute_camera_counts()] with `m > 1`, then combines the results with
#' Rubin's (1987) rules.
#'
#' This exists because a single completed data set structurally cannot carry
#' the uncertainty introduced by imputing. Inside `survey::svytotal()` a
#' predicted count is indistinguishable from an observed one, so the imputation
#' model's own error is dropped; and predictions are smoother than real counts,
#' so the between-day component shrinks as well. The reported SE is therefore
#' biased downward twice over, and can fall *below* the SE of the same design
#' with the outage days simply deleted — reporting more precision from less
#' information (GH #137).
#'
#' @details
#' # The pooled variance
#'
#' With \eqn{M} completed data sets giving estimates \eqn{Q_m} and variances
#' \eqn{U_m = SE_m^2}:
#'
#' \deqn{\bar{Q} = \frac{1}{M} \sum_m Q_m}
#' \deqn{\bar{U} = \frac{1}{M} \sum_m U_m}
#' \deqn{B = \frac{M+1}{M(M-1)} \sum_m (Q_m - \bar{Q})^2}
#' \deqn{T = \bar{U} + B}
#'
#' \eqn{\bar{U}} is the **within-imputation** variance — the average of what
#' each completed data set reports, and the only part single imputation can
#' produce. \eqn{B} is the **between-imputation** term, and it is the one that
#' is structurally missing today: it measures how much the estimate moves when
#' the outage days are filled differently, which a single filled data set
#' cannot express at all.
#'
#' This is the pooling in Afrifa-Yamoah et al. (2020) equation (5). Their
#' \eqn{(M+1)/(M(M-1))} factor is the usual Rubin \eqn{(1 + 1/M)} inflation
#' written over the raw sum of squares rather than the sample variance; the two
#' are the same quantity.
#'
#' Degrees of freedom use Rubin's classic expression
#' \eqn{\nu = (M-1)(1 + \bar{U}/B)^2}, which is finite precisely because
#' \eqn{B > 0}.
#'
#' @param design A [creel_design()] object of `design_type == "camera"`
#'   **without** counts attached. Counts come from `imputations`, one completed
#'   set at a time.
#' @param imputations A `camera_imputations` object from
#'   [impute_camera_counts()] with `m > 1`.
#' @param ... Further arguments passed to [est_effort_camera()], such as
#'   `interviews`, `h_open`, or `calibration`.
#' @param conf_level Numeric confidence level. Default `0.95`.
#'
#' @return A `creel_estimates` object with `method = "camera_mi"`. Its
#'   `se_components` names the two halves of the pooled variance as
#'   `within_imputation` and `between_imputation`, so a reader can see how much
#'   of the uncertainty came from imputing. The per-imputation results are
#'   attached as `attr(result, "imputations")`.
#'
#' @references
#'   Afrifa-Yamoah, E., Taylor, S.M., Fisher, A., and Mueller, U. 2020.
#'   Imputation of missing data from time-lapse cameras used in recreational
#'   fishing surveys. ICES Journal of Marine Science 77(7-8):2984-2994.
#'
#'   Rubin, D.B. 1987. Multiple Imputation for Nonresponse in Surveys. Wiley.
#'
#' @family "Estimation"
#' @export
est_effort_camera_mi <- function(design, imputations, ..., conf_level = 0.95) {
  if (!inherits(imputations, "camera_imputations")) {
    cli::cli_abort(c(
      "{.arg imputations} must be a {.cls camera_imputations} object.",
      "i" = "Produce one with {.code impute_camera_counts(..., m = 5)}.",
      "x" = "Got {.cls {class(imputations)[1]}}."
    ))
  }
  n_imp <- length(imputations)
  if (n_imp < 2L) {
    cli::cli_abort(c(
      "Pooling requires at least 2 completed data sets, not {n_imp}.",
      "i" = "The between-imputation variance is undefined for a single one -- which is the defect being fixed."
    ))
  }

  # Estimate once per completed data set.
  per_imp <- lapply(imputations, function(cc) {
    d <- suppressWarnings(add_counts(design, cc))
    suppressWarnings(est_effort_camera(d, ..., conf_level = conf_level))
  })

  q <- vapply(per_imp, function(x) as.numeric(x$estimates$estimate), numeric(1L))
  u <- vapply(per_imp, function(x) as.numeric(x$estimates$se)^2, numeric(1L))

  # An NA in any completed set makes the pooled quantity unknown, not smaller.
  # No na.rm anywhere below, for the same reason the rest of the package
  # refuses it: a sum missing an unknown term is a lower bound, not an SE.
  pooled <- .rubin_pool(q, u, conf_level = conf_level)

  estimates_df <- tibble::tibble(
    estimate = pooled$estimate,
    se = pooled$se,
    se_between = pooled$se,
    se_within = NA_real_,
    ci_lower = pooled$estimate - pooled$t_crit * pooled$se,
    ci_upper = pooled$estimate + pooled$t_crit * pooled$se,
    n = nrow(imputations[[1L]])
  )

  result <- new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "camera_mi",
    variance_method = "rubin",
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    unit = per_imp[[1L]]$unit %||% NA_character_,
    # Named so a reader can see how much of the uncertainty came from imputing
    # rather than from sampling (GH #141).
    se_components = list(
      within_imputation = sqrt(pooled$var_within),
      between_imputation = sqrt(pooled$var_between)
    )
  )
  attr(result, "imputations") <- per_imp
  attr(result, "m") <- n_imp
  result
}

#' Combine point estimates and variances by Rubin's rules
#'
#' @param q Numeric vector of per-imputation point estimates.
#' @param u Numeric vector of per-imputation variances (squared SEs).
#' @return A list with `estimate`, `se`, `var_within`, `var_between`, `df`,
#'   and `t_crit` (at the caller's confidence level, supplied via `conf_level`).
#' @keywords internal
#' @noRd
.rubin_pool <- function(q, u, conf_level = 0.95) {
  m <- length(q)
  q_bar <- mean(q)
  var_within <- mean(u)

  # Afrifa-Yamoah et al. (2020) eq. (5). Written over the raw sum of squares
  # with an (M+1)/(M(M-1)) factor, which is Rubin's (1 + 1/M) inflation applied
  # to the sample variance sum((q - q_bar)^2)/(M - 1) -- the same quantity,
  # kept in the paper's form so the two can be compared directly.
  var_between <- (m + 1) / (m * (m - 1)) * sum((q - q_bar)^2)

  var_total <- var_within + var_between

  # Rubin's classic degrees of freedom. Finite precisely because var_between is
  # positive; the single-imputation case this replaces has no df at all because
  # it has no between term.
  df <- if (var_between > 0) {
    (m - 1) * (1 + var_within / var_between)^2
  } else {
    # All completed sets agreed exactly. Possible with a degenerate model, and
    # it means the between term contributed nothing -- not that it was skipped.
    Inf
  }

  list(
    estimate = q_bar,
    se = sqrt(var_total),
    var_within = var_within,
    var_between = var_between,
    df = df,
    t_crit = stats::qt(1 - (1 - conf_level) / 2, df = df)
  )
}
