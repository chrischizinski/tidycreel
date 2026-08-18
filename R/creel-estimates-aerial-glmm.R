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
#'   visibility_correction = "none",
#'   angler_ratio = 1,
#'   angler_ratio_se = 0,
#'   h_open = 14
#' )
#' design <- add_counts(design, example_aerial_glmm_counts, count_col = n_anglers)
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
#' @family "Estimation"
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
  count_var <- resolve_count_col( # nolint: object_usage_linter
    counts = counts_data,
    excluded = c(design$date_col, design$strata_cols, design$psu_col, time_col_name),
    count_col = design$count_col
  )

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
    # Deliberately no nAGQ / glmerControl overrides. Askey et al. (2018) used
    # nAGQ = 0 and optimizer = "nloptwrap" only because their data set exceeded
    # 250,000 observations, and warn that nAGQ = 0 "would not be preferred for
    # smaller data sets because it is a more efficient but less-accurate form of
    # parameter estimation for random effects". Creel-sized data belong in the
    # accurate regime, so the paper's options are not carried over.
    model <- lme4::glmer.nb(glmm_formula, data = counts_data)
  } else {
    model <- lme4::glmer(glmm_formula, data = counts_data, family = family)
  }

  # 7. Build prediction grid for numerical integration over the fishing day.
  # Integrate over exactly h_open hours anchored at open_start.
  # Using only the observed flight range would truncate the integral and understate
  # effort for unsampled morning/evening hours — the whole point of the GLMM.
  h_open <- design$aerial$h_open
  # No `%||% 1.0`: creel_design() requires visibility_correction for an aerial
  # design and normalises the explicit "none" opt-out to v = 1 with
  # se_v = NA (GH #135).
  v <- design$aerial$visibility_correction
  se_v <- design$aerial$visibility_se
  # Angler-to-people ratio: an aerial count is a raw observer count (GH #158).
  a <- design$aerial$angler_ratio
  se_a <- design$aerial$angler_ratio_se
  if (!is.null(design$aerial$open_start)) {
    open_start <- design$aerial$open_start
  } else {
    open_start <- min(counts_data[[time_col_name]]) - 0.5
    cli::cli_inform(c(
      "i" = paste0(
        "Integration window start derived from data: ",
        round(open_start, 2),
        " h (earliest flight - 0.5 h)."
      ),
      " " = "Specify {.arg open_start} in {.fn creel_design} for a fixed fishery opening time."
    ))
  }
  open_end <- open_start + h_open # always spans the full fishing day
  hour_grid <- seq(open_start, open_end, length.out = 100)

  new_data <- stats::setNames(
    data.frame(hour_grid, NA_character_, stringsAsFactors = FALSE),
    c(time_col_name, design$date_col)
  )

  terms_obj <- stats::delete.response(stats::terms(model))
  x_mat <- stats::model.matrix(terms_obj, data = new_data) # nolint: object_name_linter
  beta <- lme4::fixef(model)
  mu <- as.numeric(exp(x_mat %*% beta))
  scale_factor <- h_open / (length(hour_grid) - 1L) # interval width: 100 pts = 99 gaps
  # sum(mu) * scale_factor integrates the fitted count-vs-time curve over h_open
  # hours, yielding people-hours. The visibility correction (1/v) and the
  # angler-to-people ratio (a) convert that to angler-hours — multiplying by
  # h_open again would double-count the time dimension.
  total_effort <- sum(mu) * scale_factor * a / v

  # 8. Variance: delta method (default) or bootstrap
  #
  # The visibility correction v is estimated, not known (GH #135). It is a
  # SHARED multiplier: one estimate divides the whole integrated curve, so it is
  # perfectly correlated across flights and does not shrink as more flights are
  # flown. Its term therefore enters once at the total on both paths.
  #
  # This composition is tidycreel's own reasoning. Askey et al. (2018) -- this
  # estimator's cited source -- contains no visibility correction and no
  # bootstrap, and does not speak to v; it propagates uncertainty by
  # cross-validation rather than analytically. Smucker et al. (2010) is the
  # source for v itself, not for how it composes here.
  # The angler-to-people ratio is the same kind of object and composes the same
  # way (GH #158).
  var_visibility <- if (is.null(se_v)) NULL else (total_effort * se_v / v)^2
  var_angler_ratio <- if (is.null(se_a)) NULL else (total_effort * se_a / a)^2

  if (!boot) {
    v_mat <- as.matrix(stats::vcov(model)) # nolint: object_name_linter
    grad <- scale_factor * a / v * colSums(mu * x_mat)
    var_model <- as.numeric(t(grad) %*% v_mat %*% grad)
    # No na.rm: these are NA under the declared "none" opt-outs, and a sum
    # missing an unknown term is a lower bound, not an SE.
    se <- sqrt(var_model + (var_visibility %||% 0) + (var_angler_ratio %||% 0))
    se_between <- se

    alpha <- 1 - conf_level
    z_crit <- stats::qnorm(1 - alpha / 2)
    ci_lower <- total_effort - z_crit * se
    ci_upper <- total_effort + z_crit * se
  } else {
    # 9. Bootstrap path
    cli::cli_inform("Running {nboot} bootstrap replicates via lme4::bootMer...")

    if (length(design$strata_cols) > 0L) {
      cli::cli_warn(c(
        "!" = "Bootstrap SE ignores design strata ({.val {design$strata_cols}}).",
        "i" = "The default GLMM formula has no stratum term; bootstrap resamples from \\
        a single pooled model. Include strata in {.arg formula} for stratified inference."
      ))
    }

    boot_fn <- function(m) {
      mu_b <- as.numeric(exp(x_mat %*% lme4::fixef(m)))
      sum(mu_b) * scale_factor * a / v
    }

    b <- lme4::bootMer(model, FUN = boot_fn, nsim = nboot, type = "parametric", use.u = FALSE)
    boot_t <- as.numeric(b$t)

    # Resample v ONCE PER REPLICATE, outside the model refit (GH #135).
    #
    # boot_fn holds v fixed, so bootMer's spread carries the model only. One
    # draw of v is then applied to a whole replicate. Drawing v per flight
    # inside the loop instead would average n_flights independent draws and
    # shrink its contribution like 1/sqrt(n_flights) -- destroying exactly the
    # shared character that makes v matter, and silently, since the SE would
    # still look plausible.
    #
    # boot_t = G_b / v, so multiplying by v / v_draw substitutes the drawn
    # value without refitting.
    if (!is.null(se_v) && !is.na(se_v)) {
      v_draws <- stats::rnorm(length(boot_t), mean = v, sd = se_v)
      # A normal draw for a probability can leave (0, 1]. Dividing by a
      # non-positive draw would produce a negative or infinite replicate, so
      # refuse rather than clamp: clamping would quietly bias v upward and
      # report a narrower SE than the supplied uncertainty implies.
      bad_draws <- sum(v_draws <= 0 | v_draws > 1)
      if (bad_draws > 0.001 * length(v_draws)) {
        cli::cli_abort(
          c(
            "{.arg visibility_se} is too large for a normal approximation on the bootstrap path.",
            "x" = paste0(
              "{bad_draws} of {length(v_draws)} draws of the detection probability ",
              "fell outside (0, 1]."
            ),
            "i" = "v = {.val {v}} with SE {.val {se_v}} puts appreciable mass on impossible values.",
            "i" = "Use the delta path ({.code boot = FALSE}), or supply a better-determined correction."
          ),
          class = "creel_error_visibility_se_bootstrap_range"
        )
      }
      v_draws[v_draws <= 0 | v_draws > 1] <- NA_real_
      boot_t <- boot_t * v / v_draws
    }

    # The angler-to-people ratio is drawn the same way and for the same reason:
    # one draw per replicate, outside the model refit, because it too is a
    # shared multiplier (GH #158). boot_t carries a as a factor, so multiplying
    # by a_draw / a substitutes the drawn value.
    if (!is.null(se_a) && !is.na(se_a) && se_a > 0) {
      a_draws <- stats::rnorm(length(boot_t), mean = a, sd = se_a)
      bad_a <- sum(a_draws <= 0 | a_draws > 1)
      if (bad_a > 0.001 * length(a_draws)) {
        cli::cli_abort(
          c(
            "{.arg angler_ratio_se} is too large for a normal approximation on the bootstrap path.",
            "x" = "{bad_a} of {length(a_draws)} draws of the angler-to-people ratio fell outside (0, 1].",
            "i" = "Use the delta path ({.code boot = FALSE}), or supply a better-determined ratio."
          ),
          class = "creel_error_angler_ratio_se_bootstrap_range"
        )
      }
      a_draws[a_draws <= 0 | a_draws > 1] <- NA_real_
      boot_t <- boot_t * a_draws / a
    }

    se <- stats::sd(boot_t, na.rm = TRUE)
    se_between <- se

    ci_probs <- c((1 - conf_level) / 2, 1 - (1 - conf_level) / 2)
    ci_vec <- stats::quantile(boot_t, ci_probs, names = FALSE, na.rm = TRUE)
    ci_lower <- ci_vec[1L]
    ci_upper <- ci_vec[2L]

    # A declared "none" opt-out carries se = NA, which the resampling block
    # above deliberately skips (there is nothing to draw). The SE must still go
    # NA: the uncertainty is unpropagated, not zero. Applies to either
    # multiplier (GH #135, #158).
    if ((!is.null(se_v) && is.na(se_v)) || (!is.null(se_a) && is.na(se_a))) {
      se <- NA_real_
      se_between <- NA_real_
    }
  }

  # 10. Assemble output
  estimates_df <- tibble::tibble(
    estimate = total_effort,
    se = se,
    se_between = se_between,
    se_within = NA_real_,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = nrow(counts_data)
  )

  variance_method_str <- if (boot) "bootstrap" else "delta"

  # On the bootstrap path v is inside the replicates rather than a separable
  # summand, so only the delta path can report the two parts apart (GH #141).
  se_components <- list(model = se_between)
  if (!boot && (!is.null(var_visibility) || !is.null(var_angler_ratio))) {
    se_components$model <- sqrt(var_model)
    if (!is.null(var_visibility)) se_components$visibility <- sqrt(var_visibility)
    if (!is.null(var_angler_ratio)) se_components$angler_ratio <- sqrt(var_angler_ratio)
  }

  new_creel_estimates(
    # nolint: object_usage_linter
    estimates = estimates_df,
    se_components = se_components,
    method = "aerial_glmm_total",
    variance_method = variance_method_str,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}
