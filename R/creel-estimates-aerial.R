#' Aerial effort estimation using svytotal scaled by h_open/v
#'
#' Internal function that estimates angler effort for aerial creel surveys.
#' Applies a linear scaling of survey::svytotal() by the calibration constant
#' h_over_v = h_open / visibility_correction.
#'
#' h_open is a fixed constant. v is not: it is estimated from paired air-ground
#' counts, and the standard field method reports its SE as routine output
#' (Smucker et al. 2010, eq. 6-7). When that SE is supplied, a delta term for v
#' is added ONCE at the total -- see the comment at its computation below for
#' why it cannot be added per stratum (GH #135).
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
#'   Smucker, B.J., Lorantas, R.M., and Rosenberger, A.E. (2010). Correcting
#'   bias introduced by aerial counts in angler effort estimation. (Source for
#'   the ground-truthing ratio and its standard error.)
#'
#' @keywords internal
#' @noRd
estimate_effort_aerial <- function(
  design,
  variance_method,
  conf_level,
  verbose,
  effort_target = "sampled_days"
) {
  # nolint: object_usage_linter
  # Calibration constant: h_open / visibility_correction.
  #
  # No `%||% 1.0` here any more. creel_design() now requires
  # visibility_correction for an aerial design and normalises the explicit
  # "none" opt-out to v = 1 with se_v = NA, so a 1 reaching this line is always
  # a stated claim rather than an absent argument (GH #135).
  v <- design$aerial$visibility_correction
  se_v <- design$aerial$visibility_se

  # Angler-to-people ratio (GH #158). An aerial count is a raw observer count
  # and nothing in it separates anglers from other people, so the count is
  # scaled by `a` to reach anglers. Smucker et al. (2010) apply this alongside
  # the visibility correction; the two push in OPPOSITE directions (0.404 down,
  # 2.69 up), so applying only the visibility correction is not conservative --
  # it is biased in the direction of the correction that was kept.
  a <- design$aerial$angler_ratio
  se_a <- design$aerial$angler_ratio_se

  h_over_v <- design$aerial$h_open * a / v

  # Identify count variable (same logic as estimate_effort_total)
  counts_data <- design$counts
  count_var <- resolve_count_col( # nolint: object_usage_linter
    counts = counts_data,
    excluded = c(design$date_col, design$strata_cols, design$psu_col),
    count_col = design$count_col
  )
  count_formula <- stats::reformulate(count_var)

  # Get appropriate survey design for variance method
  svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter

  # svytotal on the raw instantaneous count, then scale by h_over_v. The count
  # is guaranteed raw: add_counts() refuses period_length_col on an aerial
  # design, so nothing has already multiplied it by a period (finding 21).
  svy_result <- suppressWarnings(survey::svytotal(count_formula, svy_design))

  estimate <- as.numeric(coef(svy_result)) * h_over_v
  se_between <- as.numeric(survey::SE(svy_result)) * h_over_v

  # Within-day Rasmussen component (same as estimate_effort_total)
  var_within <- compute_within_day_var_contribution(
    design,
    by_vars = NULL,
    target = "sampled_days"
  ) *
    h_over_v^2 # nolint: object_usage_linter
  se_within <- sqrt(var_within)

  # Visibility-correction component (GH #135).
  #
  # With E = C * h_open / v and C independent of v, the delta method gives
  #   Var(E) = (h_open/v)^2 Var(C)  +  (E/v)^2 Var(v)
  # so the second term's SE contribution is E * se_v / v.
  #
  # Added ONCE at the total, never per stratum. v is a single estimate dividing
  # every scaled count, so it is perfectly correlated across flights and strata
  # and does not shrink as more flights are flown. Adding it per stratum and
  # summing in quadrature would treat a shared multiplier as independent and
  # understate it -- the same trap as GH #150.
  #
  # This mirrors the camera calibration ratio, which already solves this exact
  # problem (creel-estimates-camera.R: var_calibration). It is deliberately not
  # a new idiom.
  #
  # NOTE: this composition is tidycreel's own. Askey et al. (2018), the aerial
  # GLMM path's cited source, contains no visibility correction and no
  # bootstrap; it does not speak to v at all. Smucker et al. (2010) is the
  # source for v itself, not for this variance composition.
  var_visibility <- if (is.null(se_v)) NULL else (estimate * se_v / v)^2
  se_visibility <- if (is.null(var_visibility)) NULL else sqrt(var_visibility)

  # The angler-to-people ratio is the same kind of object as v -- one estimate
  # scaling every count -- so it composes the same way and enters once at the
  # total (GH #158).
  var_angler_ratio <- if (is.null(se_a)) NULL else (estimate * se_a / a)^2
  se_angler_ratio <- if (is.null(var_angler_ratio)) NULL else sqrt(var_angler_ratio)

  # Party-size expansion contribution (GH #121/#158).
  #
  # This estimator previously never called compute_expansion_var_contribution(),
  # so a boat count expanded by derive_angler_count() with a party_size_se
  # reached svytotal() with its multiplier's uncertainty silently discarded --
  # the carrier columns survived add_counts() and were then simply not read.
  # Scaled by h_over_v^2 because the contribution is computed on the raw count
  # scale, exactly as var_within is.
  var_expansion_raw <- compute_expansion_var_contribution( # nolint: object_usage_linter
    design,
    svy_design,
    by_vars = NULL
  )
  expansion_decomposition <- attr(var_expansion_raw, "decomposition")
  # Stripped to a bare number before any arithmetic: R propagates attributes
  # through `+` and `sqrt()`, so leaving the decomposition attached would stamp
  # it onto the reported `se`.
  var_expansion <- if (is.null(var_expansion_raw)) {
    NULL
  } else {
    as.numeric(var_expansion_raw) * h_over_v^2
  }
  se_expansion <- if (is.null(var_expansion)) NULL else sqrt(var_expansion)

  # Combined SE. The visibility and angler-ratio terms are NA under their
  # declared "none" opt-outs, and no na.rm is used: a sum missing an unknown
  # term is a lower bound, not an SE, so the total must go NA with it.
  se <- sqrt(
    se_between^2 +
      var_within +
      (var_visibility %||% 0) +
      (var_angler_ratio %||% 0) +
      (var_expansion %||% 0)
  )

  # Degrees of freedom and CI
  df <- as.numeric(survey::degf(svy_design))
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha / 2, df = df)
  ci_lower <- estimate - t_crit * se
  ci_upper <- estimate + t_crit * se

  n <- nrow(counts_data)

  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    se_between = se_between,
    se_within = se_within,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = n
  )

  # Named components (GH #141). `visibility` is present-and-NA under the
  # declared opt-out and present-and-numeric when an SE was supplied; it is
  # omitted entirely only when the correction was supplied without one, which
  # is the "does not apply" case rather than the "unknown" case.
  se_components <- list(
    count_sampling = se_between,
    within_day = se_within
  )
  if (!is.null(se_visibility)) {
    se_components$visibility <- se_visibility
  }
  if (!is.null(se_angler_ratio)) {
    se_components$angler_ratio <- se_angler_ratio
  }

  new_creel_estimates( # nolint: object_usage_linter
    # nolint: object_usage_linter
    estimates = estimates_df,
    se_components = se_components, # nolint: object_usage_linter
    se_expansion = se_expansion, # nolint: object_usage_linter
    expansion_decomposition = expansion_decomposition, # nolint: object_usage_linter
    method = "aerial_total",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    effort_target = effort_target,
    # Unconditional, not design$effort_unit: an aerial design refuses
    # period_length_col, so its effort_unit is always NA. h_open is the sole
    # period source here (finding 21), and count x hours is angler-hours.
    unit = "angler-hours" # nolint: object_usage_linter
  )
}
