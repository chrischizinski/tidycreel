#' GLMM-based aerial effort estimation with diurnal correction
#'
#' `r lifecycle::badge("experimental")`
#'
#' @description
#' Estimates total angler effort from aerial creel surveys using a generalized
#' linear mixed model (GLMM), following the approach of Askey et al. (2018).
#' When flights occur at non-random times of day, simple scaling of instantaneous
#' counts can over- or under-estimate daily effort. This function fits a
#' negative-binomial GLMM (or user-specified family) to model how angler counts
#' change through the day, then integrates the fitted diurnal curve over the
#' fishing day to obtain a bias-corrected effort estimate.
#'
#' The default model is the quadratic temporal model from Askey (2018):
#' \code{count ~ poly(time_col, 2) + (1 | date)}, fitted via
#' [lme4::glmer.nb()]. Variance is propagated via the delta method (default) or
#' parametric bootstrap ([lme4::bootMer()]).
#'
#' @param design A [creel_design()] object with `design_type == "aerial"` and
#'   counts attached via [add_counts()]. The counts data must contain the
#'   time-of-flight column specified by `time_col`.
#' @param time_col Unquoted name of the numeric column in `design$counts`
#'   recording the hour of each aerial overflight (e.g., `time_of_flight`).
#' @param formula Optional. A formula for the GLMM, passed directly to
#'   [lme4::glmer.nb()] or [lme4::glmer()]. If `NULL` (default), the Askey
#'   (2018) quadratic formula is used:
#'   `count ~ poly(time_col, 2) + (1 | date)`.
#' @param family Optional. A family object or character string specifying the
#'   GLM family. If `NULL` or `"negbin"` (default), [lme4::glmer.nb()] is
#'   used. Otherwise, [lme4::glmer()] is called with the specified family.
#' @param boot Logical. If `TRUE`, use [lme4::bootMer()] for parametric
#'   bootstrap confidence intervals instead of the delta method. Default
#'   `FALSE`.
#' @param nboot Integer. Number of bootstrap replicates when `boot = TRUE`.
#'   Default `500L`.
#' @param conf_level Numeric confidence level for the CI. Default `0.95`.
#'
#' @return A `creel_estimates` object with:
#'   - `estimate`: total angler effort integrated over the fishing day
#'   - `se`: standard error (delta method or bootstrap SD)
#'   - `se_between`: same as `se` (fixed-effect SE component)
#'   - `se_within`: always `NA_real_` — no Rasmussen within-day decomposition
#'     is performed for GLMM estimates
#'   - `ci_lower`, `ci_upper`: confidence interval bounds
#'   - `n`: number of count observations used to fit the model
#'   - `method`: `"aerial_glmm_total"`
#'
#' @references
#'   Askey, P.J., et al. (2018). Correcting for non-random flight timing in
#'   aerial creel surveys using a generalized linear mixed model.
#'   North American Journal of Fisheries Management, 38, 1204-1215.
#'   \doi{10.1002/nafm.10010}
#'
#' @examples
#' \dontrun{
#' data(example_aerial_glmm_counts)
#'
#' aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
#' aerial_cal <- aerial_cal[order(aerial_cal$date), ]
#' design <- creel_design(
#'   aerial_cal,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "aerial",
#'   h_open = 14
#' )
#' design <- add_counts(design, example_aerial_glmm_counts)
#'
#' # Default Askey quadratic model with delta-method SE
#' result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
#' print(result)
#'
#' # Bootstrap CIs (slower)
#' result_boot <- estimate_effort_aerial_glmm(
#'   design,
#'   time_col = time_of_flight,
#'   boot = TRUE,
#'   nboot = 100L
#' )
#' print(result_boot)
#' }
#'
#' @export
estimate_effort_aerial_glmm <- function(
  design,
  time_col,
  formula = NULL,
  family = NULL,
  boot = FALSE,
  nboot = 500L,
  conf_level = 0.95
) {
  # 1. Guard: lme4 must be installed
  rlang::check_installed("lme4", reason = "to fit the GLMM aerial effort estimator")

  # 2. Guard: design_type must be "aerial"
  if (!identical(design$design_type, "aerial")) {
    cli::cli_abort(c(
      "{.fn estimate_effort_aerial_glmm} requires an aerial survey design.",
      "x" = "Found {.field design_type} = {.val {design$design_type}}.",
      "i" = "Use {.fn estimate_effort} for {.val {design$design_type}} surveys."
    ))
  }

  # 3. Resolve time_col (tidyselect-style unquoted name)
  time_col_quo <- rlang::enquo(time_col)
  time_col_name <- rlang::as_name(time_col_quo)
  if (!time_col_name %in% names(design$counts)) {
    cli::cli_abort(c(
      "Column {.field {time_col_name}} not found in {.code design$counts}.",
      "i" = "Available columns: {.field {names(design$counts)}}"
    ))
  }

  # 4. Identify count variable (exclude design metadata and time column)
  counts_data <- design$counts
  excluded_cols <- c(design$date_col, design$strata_cols, design$psu_col, time_col_name)
  numeric_cols <- names(counts_data)[vapply(counts_data, is.numeric, logical(1L))]
  count_vars <- setdiff(numeric_cols, excluded_cols)

  if (length(count_vars) == 0L) {
    cli::cli_abort(c(
      "No count variable found in count data.",
      "x" = "Count data must have at least one numeric column.",
      "i" = "Numeric columns found: {.field {numeric_cols}}",
      "i" = "Design metadata and time columns: {.field {excluded_cols}}"
    ))
  }

  count_var <- count_vars[1L]

  # 5. Build GLMM formula
  if (is.null(formula)) {
    glmm_formula <- stats::as.formula(
      paste0(count_var, " ~ poly(", time_col_name, ", 2) + (1|", design$date_col, ")")
    )
  } else {
    glmm_formula <- formula
  }

  # 6. Fit model
  if (is.null(family) || identical(family, "negbin")) {
    model <- lme4::glmer.nb(glmm_formula, data = counts_data)
  } else {
    model <- lme4::glmer(glmm_formula, data = counts_data, family = family)
  }

  # 7. Build prediction grid for numerical integration over the fishing day
  h_over_v <- design$aerial$h_open / (design$aerial$visibility_correction %||% 1.0)

  open_start <- min(counts_data[[time_col_name]]) - 0.5
  open_end <- max(counts_data[[time_col_name]]) + 0.5
  hour_grid <- seq(open_start, open_end, length.out = 100)

  new_data <- stats::setNames(
    data.frame(hour_grid, NA_character_, stringsAsFactors = FALSE),
    c(time_col_name, design$date_col)
  )

  terms_obj <- stats::delete.response(stats::terms(model))
  x_mat <- stats::model.matrix(terms_obj, data = new_data) # nolint: object_name_linter
  beta <- lme4::fixef(model)
  mu <- as.numeric(exp(x_mat %*% beta))
  scale_factor <- (open_end - open_start) / 100
  total_effort <- sum(mu) * scale_factor * h_over_v

  # 8. Variance: delta method (default) or bootstrap
  if (!boot) {
    v_mat <- as.matrix(stats::vcov(model)) # nolint: object_name_linter
    grad <- scale_factor * h_over_v * colSums(mu * x_mat)
    var_total <- as.numeric(t(grad) %*% v_mat %*% grad)
    se <- sqrt(var_total)
    se_between <- se

    alpha <- 1 - conf_level
    z_crit <- stats::qnorm(1 - alpha / 2)
    ci_lower <- total_effort - z_crit * se
    ci_upper <- total_effort + z_crit * se
  } else {
    # 9. Bootstrap path
    cli::cli_inform("Running {nboot} bootstrap replicates via lme4::bootMer...")

    boot_fn <- function(m) {
      mu_b <- as.numeric(exp(x_mat %*% lme4::fixef(m)))
      sum(mu_b) * scale_factor * h_over_v
    }

    b <- lme4::bootMer(model, FUN = boot_fn, nsim = nboot, type = "parametric", use.u = FALSE)
    se <- stats::sd(b$t)
    se_between <- se

    ci_probs <- c((1 - conf_level) / 2, 1 - (1 - conf_level) / 2)
    ci_vec <- stats::quantile(b$t, ci_probs, names = FALSE)
    ci_lower <- ci_vec[1L]
    ci_upper <- ci_vec[2L]
  }

  # 10. Assemble output
  estimates_df <- tibble::tibble(
    estimate   = total_effort,
    se         = se,
    se_between = se_between,
    se_within  = NA_real_,
    ci_lower   = ci_lower,
    ci_upper   = ci_upper,
    n          = nrow(counts_data)
  )

  variance_method_str <- if (boot) "bootstrap" else "delta"

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = estimates_df,
    method          = "aerial_glmm_total",
    variance_method = variance_method_str,
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}
