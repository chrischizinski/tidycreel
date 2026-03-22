#' Aerial effort estimation using svytotal scaled by h_open/v
#'
#' Internal function that estimates angler effort for aerial creel surveys.
#' Applies a linear scaling of survey::svytotal() by the calibration constant
#' h_over_v = h_open / visibility_correction. No delta method is needed because
#' h_open and v are fixed constants, not sample estimates.
#'
#' @param design A creel_design object with design_type == "aerial" and
#'   design$counts populated by add_counts().
#' @param variance_method Character string passed to get_variance_design().
#' @param conf_level Numeric confidence level for CI (e.g., 0.95).
#' @param verbose Logical; unused currently but kept for interface consistency.
#'
#' @return A creel_estimates object with columns estimate, se, se_between,
#'   se_within, ci_lower, ci_upper, n.
#'
#' @references
#'   Pollock, K.H., Jones, C.M., and Brown, T.L. (1994). Angler Survey Methods
#'   and Their Applications in Fisheries Management. American Fisheries Society
#'   Special Publication 25. Sec. 15.6.1, Eq. 15.4.
#'
#' @keywords internal
#' @noRd
estimate_effort_aerial <- function(design, variance_method, conf_level, verbose) { # nolint: object_usage_linter
  # Calibration constant: h_open / visibility_correction (v defaults to 1.0)
  h_over_v <- design$aerial$h_open / (design$aerial$visibility_correction %||% 1.0)

  # Identify count variable (same logic as estimate_effort_total)
  counts_data <- design$counts
  excluded_cols <- c(design$date_col, design$strata_cols, design$psu_col)
  numeric_cols <- names(counts_data)[sapply(counts_data, is.numeric)]
  count_vars <- setdiff(numeric_cols, excluded_cols)

  if (length(count_vars) == 0L) {
    cli::cli_abort(c(
      "No count variable found in count data.",
      "x" = "Count data must have at least one numeric column.",
      "i" = "Numeric columns found: {.field {numeric_cols}}",
      "i" = "Design metadata columns: {.field {excluded_cols}}"
    ))
  }

  count_var <- count_vars[1L]
  count_formula <- stats::reformulate(count_var)

  # Get appropriate survey design for variance method
  svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter

  # svytotal on the raw instantaneous count, then scale by h_over_v
  svy_result <- suppressWarnings(survey::svytotal(count_formula, svy_design))

  estimate <- as.numeric(coef(svy_result)) * h_over_v
  se_between <- as.numeric(survey::SE(svy_result)) * h_over_v

  # Within-day Rasmussen component (same as estimate_effort_total)
  var_within <- compute_within_day_var_contribution(design, by_vars = NULL) * h_over_v^2 # nolint: object_usage_linter
  se_within <- sqrt(var_within)

  # Combined SE
  se <- sqrt(se_between^2 + var_within)

  # Degrees of freedom and CI
  df <- as.numeric(survey::degf(svy_design))
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha / 2, df = df)
  ci_lower <- estimate - t_crit * se
  ci_upper <- estimate + t_crit * se

  n <- nrow(counts_data)

  estimates_df <- tibble::tibble(
    estimate   = estimate,
    se         = se,
    se_between = se_between,
    se_within  = se_within,
    ci_lower   = ci_lower,
    ci_upper   = ci_upper,
    n          = n
  )

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = "aerial_total",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}
