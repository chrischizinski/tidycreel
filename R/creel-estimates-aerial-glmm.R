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
#' @param target Character string giving the temporal basis of the returned
#'   estimate. `"sampled_days"` (default) expands the fitted day to every day
#'   the design sampled, matching what [estimate_effort()] returns for the same
#'   design so the two are comparable. `"mean_day"` reports a single average
#'   day, the basis this function reported before tidycreel 8.0.0. It is not
#'   identical to the old value: it now carries the retransformation factor
#'   the old code omitted, so it is higher by `exp(sigma^2 / 2)`.
#'
#'   Both are expectations, so both carry the retransformation factor described
#'   under Details. Neither expands beyond the sampled days: expanded targets
#'   are not supported for aerial designs by [estimate_effort()] either.
#' @param by Optional tidy selection of columns in `design$counts` to estimate
#'   within, typically the design strata (for example `by = day_type`). The
#'   strata enter the default model as additive fixed effects in ONE model --
#'   `count ~ poly(time_col, 2) + day_type + (1 | date)` -- so they share the
#'   diurnal curve's shape and differ in its level; see Details. Each stratum
#'   expands by its own sampled days. Counts with a missing value in a `by`
#'   column are refused rather than dropped. Supported on the delta path only
#'   (`boot = FALSE`). When `formula` is supplied it is used as given, and it
#'   must contain every `by` column as a fixed effect; otherwise every stratum
#'   would get the same curve, so the call is refused. A `by` column with only
#'   one observed level is left out of the model (its level is the intercept)
#'   and still reported as a row.
#'
#' @return A `creel_estimates` object with:
#'   - `estimate`: total angler effort integrated over the fishing day
#'   - `se`: standard error (delta method or bootstrap SD)
#'   - `se_between`: same as `se` (fixed-effect SE component)
#'   - `se_within`: always `NA_real_` — no Rasmussen within-day decomposition
#'     is performed for GLMM estimates
#'   - `ci_lower`, `ci_upper`: confidence interval bounds, and `NA_real_`
#'     whenever `se` is, on both the delta and bootstrap paths. If the
#'     visibility correction or the angler-to-people ratio was declared
#'     unknown, the total's uncertainty was never fully propagated, so no
#'     unconditional interval exists to report. Reporting the remaining
#'     spread would be an interval conditional on the unknown multiplier
#'     being exact -- indistinguishable from declaring it known with zero
#'     uncertainty, which is precisely the confusion `NA` exists to prevent.
#'   - `n`: number of count observations used to fit the model (with `by`,
#'     the observations in that stratum)
#'   - `method`: `"aerial_glmm_total"`
#'
#'   With `by`, there is one row per stratum, headed by the `by` columns, and
#'   the object carries `strata_vcov`: the covariance matrix of the stratum
#'   estimates, rows and columns in the order of the estimate rows. Its
#'   diagonal is `se^2`. The off-diagonal is not zero: every stratum is
#'   predicted from the same fixed effects, and the visibility correction and
#'   angler-to-people ratio are single estimates that multiply every stratum.
#'   Combine strata with it -- `sqrt(sum(strata_vcov))` is the SE of the
#'   summed total -- and never by adding the rows' SEs in quadrature, which
#'   understates it.
#'
#' @details
#' The fitted curve is a fixed-effects prediction: the day whose random
#' intercept is zero. On a log link that is the *median* day rather than the
#' mean one, so summing it across days would understate the total. Both targets
#' therefore carry a factor of `exp(sigma^2 / 2)`, where `sigma^2` is the
#' day-level intercept variance — 4% on the package's own fixture, and larger
#' where days vary more.
#'
#' That factor treats `sigma^2` as known. The reported standard error scales
#' with the expansion but does not carry the uncertainty in the variance
#' component itself, so it is mildly optimistic; quantifying that would need a
#' variance method neither the delta nor the bootstrap path offers today.
#'
#' ## Estimating within strata
#'
#' With `by`, the strata are additive: they shift the level of one shared
#' diurnal curve and do not change its shape. That follows Askey et al.
#' (2018), where day type is additive in every model structure compared; the
#' one interaction they tested (month x hour) was preferred by AIC, rejected by
#' BIC, and bought no predictive gain in cross-validation. A single model also
#' shares strength across strata, which matters when a stratum has few flights.
#'
#' The assumption can fail. Smucker et al. (2010, Table 1) report weekday and
#' weekend diurnal effort that differ in shape, most clearly for shore anglers.
#' So the default grouped fit also fits the time x stratum interaction and
#' reports the BIC difference as a message. A negative difference favours
#' separate shapes; fit one by passing `formula`, for example
#' `n_anglers ~ poly(time_of_flight, 2) * day_type + (1 | date)`. The estimate
#' is never switched automatically, because a choice made from the data is not
#' reflected in the reported standard error.
#'
#' Askey et al. also found that with many randomly timed counts (about 60 or
#' more) a model-based estimator offered no advantage over expanding the mean
#' count, which was the only unbiased estimator in their comparison. The GLMM
#' earns its place when flights are few or their timing is not random.
#'
#' @references
#'   Askey, P.J., Ward, H., Godin, T., Boucher, M., and Northrup, S. (2018).
#'   Angler effort estimates from instantaneous aerial counts: use of
#'   high-frequency time-lapse camera data to inform model-based estimators.
#'   North American Journal of Fisheries Management, 38, 194-209.
#'   \doi{10.1002/nafm.10010}
#'
#'   Smucker, B.J., Lorantas, R.M., and Rosenberger, J.L. (2010). Correcting
#'   bias introduced by aerial counts in angler effort estimation. North
#'   American Journal of Fisheries Management, 30, 1051-1061.
#'   \doi{10.1577/M09-193.1}
#'
#' @examplesIf rlang::is_installed("lme4")
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
#' # One row per day type, from one model with day type as an additive term.
#' # `visibility_correction = "none"` above leaves the SEs unknown (NA), so this
#' # design declares a measured detection probability and its SE.
#' design_v <- creel_design(
#'   aerial_cal,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "aerial",
#'   visibility_correction = 0.85,
#'   visibility_se = 0.05,
#'   angler_ratio = 1,
#'   angler_ratio_se = 0,
#'   h_open = 14
#' )
#' design_v <- add_counts(design_v, example_aerial_glmm_counts, count_col = n_anglers)
#' by_day <- estimate_effort_aerial_glmm(design_v, time_col = time_of_flight, by = day_type)
#' print(by_day)
#' # SE of the summed total: use the joint covariance, not quadrature
#' sqrt(sum(by_day$strata_vcov))
#'
#' # Bootstrap CIs. `nboot` is held low here so the example stays fast on a
#' # check machine; use at least 1000 replicates for real inference. The block
#' # is wrapped in \donttest{} for runtime alone -- it needs no resource the
#' # example cannot reach.
#' \donttest{
#' result_boot <- estimate_effort_aerial_glmm(
#'   design,
#'   time_col = time_of_flight,
#'   boot = TRUE,
#'   nboot = 25L
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
  conf_level = 0.95,
  target = c("sampled_days", "mean_day"),
  by = NULL
) {
  target <- match.arg(target)
  by_quo <- rlang::enquo(by)
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

  # 4b. Resolve `by` to column names, if grouping was asked for.
  by_vars <- if (rlang::quo_is_null(by_quo)) {
    character(0)
  } else {
    eval_select_count_by(by_quo, design, species_route = FALSE, error_call = rlang::caller_env())
  }

  # A count with no stratum cannot be placed in any stratum's total, and the
  # model fit would drop it silently (lme4's na.action), so the grouped and
  # ungrouped fits would rest on different data with nothing to say so. Refuse
  # with the count rather than exclude invisibly.
  if (length(by_vars) > 0L) {
    # The grouped path is delta-method only. Returning a delta SE while the
    # caller asked for a bootstrap would be a silently wrong variance method,
    # so refuse instead -- here, before either model is fitted, so the refusal
    # costs nothing and no fitting failure can mask it. bootMer can return a
    # vector statistic, so this is a gap rather than an impossibility.
    if (isTRUE(boot)) {
      cli::cli_abort(
        c(
          "Grouped estimation does not support the bootstrap.",
          "x" = "Got {.code by} together with {.code boot = TRUE}.",
          "i" = "Use {.code boot = FALSE} for grouped estimates, or drop {.arg by}."
        ),
        class = "creel_error_glmm_grouped_boot_unsupported"
      )
    }
    na_rows <- !stats::complete.cases(counts_data[, by_vars, drop = FALSE])
    if (any(na_rows)) {
      cli::cli_abort(
        c(
          "Missing values in grouping {cli::qty(length(by_vars))}column{?s} {.field {by_vars}}.",
          "x" = "{sum(na_rows)} of {nrow(counts_data)} count{?s} would belong to no stratum.",
          "i" = "Fill the missing values, or remove those counts before {.fn add_counts}."
        ),
        class = "creel_error_glmm_by_missing"
      )
    }
    # Fit on factors whose levels are exactly those observed, so the prediction
    # grid below can reuse the fitted levels and the design-matrix columns line
    # up. droplevels() keeps a supplied factor's own ordering.
    for (nm in by_vars) counts_data[[nm]] <- droplevels(as.factor(counts_data[[nm]]))
  }

  # 5. Build GLMM formula.
  #
  # Grouping variables enter as FIXED categorical predictors in one model, not
  # as separate models per stratum. That is what Askey et al. (2018) do -- their
  # data are "observations from a series of fixed temporal strata", with the
  # random intercept reserved for the unit being scaled (their camera-year, our
  # date), described there as "the key parameter that scales individual
  # observations to predict total effort". Fitting a model per stratum would
  # estimate a separate diurnal curve and a separate intercept variance from
  # each stratum's sampled days, which on a design with few days in a stratum is
  # the unstable case the wider literature warns against.
  #
  # The additive form assumes strata share the curve's SHAPE and differ in
  # level. In Askey et al. day type is additive in every structure compared
  # (their Table 3); the only interaction tested was month x hour, which AIC
  # preferred and BIC rejected, and cross-validation found no predictive gain
  # from it. Smucker et al. (2010, Table 1) show weekday and weekend diel
  # shapes that do differ, so the assumption can fail; the BIC comparison
  # reported below is there to show when.
  #
  # Only grouping columns that vary enter the model. A column with one observed
  # level (every flight on a weekday, say) cannot form contrasts, and its level
  # is already the intercept; its row is still reported. Names are backquoted so
  # a non-syntactic column (`day type`) parses.
  by_terms <- by_vars[vapply(by_vars, function(nm) nlevels(counts_data[[nm]]) > 1L, logical(1))]
  if (is.null(formula)) {
    rhs <- paste0("poly(", time_col_name, ", 2)")
    if (length(by_terms) > 0L) {
      rhs <- paste(c(rhs, paste0("`", by_terms, "`")), collapse = " + ")
    }
    glmm_formula <- stats::as.formula(
      paste0(count_var, " ~ ", rhs, " + (1|", design$date_col, ")")
    )
  } else {
    glmm_formula <- formula
    # A supplied formula that leaves a grouping column out of the fixed effects
    # predicts one curve for every stratum; the rows would then differ only by
    # their day counts and look like per-stratum estimates. Refuse instead.
    # Fixed-effect variables are read from the term labels, dropping the
    # random-effect terms (those containing `|`). Not lme4::nobars(): it has
    # moved to reformulas and warns on current lme4, and it would run on the
    # ungrouped path too, where there is nothing to check.
    missing_terms <- if (length(by_terms) > 0L) {
      labs <- attr(stats::terms(formula), "term.labels")
      fixed_vars <- unlist(lapply(labs[!grepl("|", labs, fixed = TRUE)], function(l) all.vars(str2lang(l))))
      setdiff(by_terms, fixed_vars)
    } else {
      character(0)
    }
    if (length(missing_terms) > 0L) {
      cli::cli_abort(
        c(
          "{.arg formula} must contain every {.arg by} column as a fixed effect.",
          "x" = "Not in the fixed effects: {.field {missing_terms}}.",
          "i" = "Without it every stratum gets the same diurnal curve and differs only by its number of sampled days."
        ),
        class = "creel_error_glmm_by_not_in_formula"
      )
    }
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

  # 6b. Shape check for the default grouped fit (GH #364). Information only:
  # the estimate always comes from the additive model above. BIC rather than
  # AIC, following Askey et al. (2018), where AIC selected an interaction that
  # cross-validation showed bought nothing at the scale of a total.
  if (length(by_terms) > 0L && is.null(formula)) {
    report_glmm_shape_bic(model, count_var, time_col_name, by_terms, design$date_col, counts_data, family)
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
  # A grouped fit carries the stratum in its fixed effects, so model.matrix()
  # needs that column present to build a design matrix at all. Seed it with the
  # first fitted level; the grouped branch below overwrites it per stratum,
  # and the ungrouped quantities computed from this placeholder are not reached
  # on that path.
  # Carried as a factor with the FULL fitted level set, not a bare value: a
  # column holding one level cannot form contrasts, and the levels must match
  # those the model was fitted with or the design matrix columns will not line
  # up.
  strata_levels <- lapply(by_vars, function(nm) levels(counts_data[[nm]]))
  names(strata_levels) <- by_vars
  for (nm in by_vars) {
    new_data[[nm]] <- factor(strata_levels[[nm]][1], levels = strata_levels[[nm]])
  }

  terms_obj <- stats::delete.response(stats::terms(model))
  x_mat <- stats::model.matrix(terms_obj, data = new_data) # nolint: object_name_linter
  beta <- lme4::fixef(model)
  # lme4 drops fixed-effect columns that are aliased (two `by` columns that
  # encode the same split, say), and fixef() and vcov() then omit them. Keep the
  # retained columns only, as predict() does; a dropped column's coefficient is
  # effectively zero, so the prediction is unchanged.
  x_mat <- x_mat[, names(beta), drop = FALSE] # nolint: object_name_linter
  mu <- as.numeric(exp(x_mat %*% beta))
  scale_factor <- h_open / (length(hour_grid) - 1L) # interval width: 100 pts = 99 gaps
  # sum(mu) * scale_factor integrates the fitted count-vs-time curve over h_open
  # hours, yielding people-hours. The visibility correction (1/v) and the
  # angler-to-people ratio (a) convert that to angler-hours — multiplying by
  # h_open again would double-count the time dimension.
  mean_day_effort <- sum(mu) * scale_factor * a / v

  # Expansion to the sampled days (GH #363).
  #
  # `mu` is built with the date column set to NA, so it is a FIXED-EFFECTS
  # prediction: the curve for a day whose random intercept is zero. On a log
  # link that is the MEDIAN day, not the mean one. Summing it across days would
  # therefore understate the total, because E[exp(b)] = exp(sigma^2 / 2) > 1 for
  # a mean-zero normal intercept. The factor is applied for both targets, since
  # both report an expectation.
  #
  # Treating sigma^2 as known understates the variance slightly; the SE below
  # scales by the same constant. That is a documented limitation, not an
  # oversight -- propagating the uncertainty in the variance component itself
  # would need a different variance method than either path offers today.
  # Only a single random INTERCEPT has a constant retransformation. With a
  # random slope the marginal correction is exp(Var(b0 + b1 t) / 2), which
  # varies across the integration grid, and summing the two variances as if
  # they were one constant -- ignoring their covariance -- would silently
  # return a wrong total for a formula this function documents as supported.
  # Refuse instead (GH #363).
  vc <- as.data.frame(lme4::VarCorr(model))
  intercept_rows <- is.na(vc$var2) & vc$var1 == "(Intercept)"
  if (nrow(vc) != 1L || !all(intercept_rows)) {
    cli::cli_abort(
      c(
        "Expanding to a total needs a single random intercept.",
        "x" = "The fitted model has {nrow(vc)} random-effect term{?s}.",
        "i" = paste0(
          "A random slope makes the log-link retransformation vary across the ",
          "day, so a single constant cannot express it."
        ),
        "i" = paste0(
        "Both targets report an expectation and both need the correction, so ",
        "neither is available here. Fit with a single random intercept ",
        "({.code (1 | date)}) to expand."
      )
      ),
      class = "creel_error_glmm_retransform_unsupported"
    )
  }
  sigma2 <- sum(vc$vcov[intercept_rows], na.rm = TRUE)
  retransform <- exp(sigma2 / 2)

  # 7b. Grouped estimation (GH #364).
  #
  # One model, already fitted above; only the prediction grid changes. Each
  # stratum's curve is the shared shape evaluated at that stratum's level, and
  # each stratum expands by ITS OWN sampled days -- the quantity the total
  # estimators multiply against that stratum's catch rate.
  if (length(by_vars) > 0L) {
    strata_tbl <- unique(counts_data[, by_vars, drop = FALSE])
    strata_tbl <- strata_tbl[do.call(order, unname(as.list(strata_tbl))), , drop = FALSE]
    row.names(strata_tbl) <- NULL
    v_cov <- as.matrix(stats::vcov(model)) # nolint: object_name_linter

    parts <- lapply(seq_len(nrow(strata_tbl)), function(i) {
      lvl <- strata_tbl[i, , drop = FALSE]
      grid_i <- new_data
      for (nm in by_vars) {
        grid_i[[nm]] <- factor(as.character(lvl[[nm]]), levels = strata_levels[[nm]])
      }
      x_i <- stats::model.matrix(terms_obj, data = grid_i)[, names(beta), drop = FALSE] # nolint: object_name_linter
      mu_i <- as.numeric(exp(x_i %*% beta))

      keep <- rep(TRUE, nrow(counts_data))
      for (nm in by_vars) keep <- keep & counts_data[[nm]] == lvl[[nm]]
      days_i <- length(unique(counts_data[[design$date_col]][keep]))
      expansion_i <- retransform * if (identical(target, "sampled_days")) days_i else 1

      list(
        est = sum(mu_i) * scale_factor * a / v * expansion_i,
        grad = expansion_i * scale_factor * a / v * colSums(mu_i * x_i),
        n = sum(keep)
      )
    })
    est <- vapply(parts, `[[`, numeric(1), "est")
    grad_mat <- do.call(rbind, lapply(parts, `[[`, "grad"))

    # Joint covariance of the stratum estimates, not only their variances.
    # Every stratum is predicted from the SAME fixed effects, so the model term
    # is correlated across strata through vcov(model); and v and a are single
    # estimates multiplying every stratum, so each contributes a rank-one,
    # perfectly correlated term (GH #135, #158). Summing the rows' SEs in
    # quadrature would treat both as independent and understate the SE of any
    # combination of strata; the full matrix is what a combination needs.
    cov_model <- grad_mat %*% v_cov %*% t(grad_mat)
    cov_vis <- if (is.null(se_v)) NULL else (se_v / v)^2 * tcrossprod(est)
    cov_ar <- if (is.null(se_a)) NULL else (se_a / a)^2 * tcrossprod(est)
    # No na.rm: an undeclared correction is NA, and a sum missing an unknown
    # term is a lower bound rather than a covariance (GH #135, #158).
    strata_vcov <- cov_model + (cov_vis %||% 0) + (cov_ar %||% 0)
    dimnames(strata_vcov) <- NULL

    se_i <- sqrt(diag(strata_vcov))
    z <- stats::qnorm(1 - (1 - conf_level) / 2)
    # The fit needed factors; the rows report each stratum in its source type,
    # as the other grouped estimators do, so they join to rates by value.
    grouped_df <- tibble::as_tibble(restore_group_types(strata_tbl, design$counts, by_vars)) # nolint: object_usage_linter
    grouped_df$estimate <- est
    grouped_df$se <- se_i
    grouped_df$se_between <- se_i
    grouped_df$se_within <- NA_real_
    grouped_df$ci_lower <- est - z * se_i
    grouped_df$ci_upper <- est + z * se_i
    grouped_df$n <- vapply(parts, `[[`, integer(1), "n")

    # Named components, as on the ungrouped delta path (GH #141): `model` is
    # the model term alone, never the combined SE.
    se_components <- list(model = sqrt(diag(cov_model)))
    if (!is.null(se_v)) se_components$visibility <- est * se_v / v
    if (!is.null(se_a)) se_components$angler_ratio <- est * se_a / a

    result <- new_creel_estimates( # nolint: object_usage_linter
      estimates = grouped_df,
      se_components = se_components,
      method = "aerial_glmm_total",
      variance_method = "delta",
      design = design,
      conf_level = conf_level,
      by_vars = by_vars,
      effort_target = target
    )
    result$strata_vcov <- strata_vcov
    return(result)
  }

  n_sampled_days <- length(unique(counts_data[[design$date_col]]))
  expansion <- retransform * if (identical(target, "sampled_days")) n_sampled_days else 1

  total_effort <- mean_day_effort * expansion

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
    # Gradient of the EXPANDED total, so `expansion` rides along with it.
    grad <- expansion * scale_factor * a / v * colSums(mu * x_mat)
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
      sum(mu_b) * scale_factor * a / v * expansion
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
    #
    # The interval goes with it (GH #357). When a multiplier is skipped, boot_t
    # carries the model term only, so its quantiles are an interval CONDITIONAL
    # on that multiplier being exact -- numerically identical to the interval
    # you get by declaring the multiplier known with zero uncertainty, which is
    # the one thing an unknown must never be confused with. The delta path
    # already reports NA here because its interval is derived from the SE and
    # inherits it; the bootstrap path builds quantiles independently, so it has
    # to say so explicitly.
    if ((!is.null(se_v) && is.na(se_v)) || (!is.null(se_a) && is.na(se_a))) {
      se <- NA_real_
      se_between <- NA_real_
      ci_lower <- NA_real_
      ci_upper <- NA_real_
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
    by_vars = NULL,
    effort_target = target
  )
}

#' Report whether strata appear to need their own diurnal shape
#'
#' Internal helper for [estimate_effort_aerial_glmm()] (GH #364). Refits the
#' default grouped model with a time x stratum interaction and reports the BIC
#' difference. Information only: the caller's estimate always comes from the
#' additive model. A refit that errors is reported as unavailable, and its
#' warnings are counted rather than passed through, since they belong to a
#' comparison model the caller never asked to use.
#'
#' @return `NULL`, invisibly. Called for the message.
#' @keywords internal
#' @noRd
report_glmm_shape_bic <- function(model, count_var, time_col_name, by_vars, date_col, data, family) {
  inter_formula <- stats::as.formula(paste0(
    count_var, " ~ poly(", time_col_name, ", 2) * (",
    paste0("`", by_vars, "`", collapse = " + "), ") + (1|", date_col, ")"
  ))
  n_warn <- 0L
  inter <- tryCatch(
    withCallingHandlers(
      if (is.null(family) || identical(family, "negbin")) {
        lme4::glmer.nb(inter_formula, data = data)
      } else {
        lme4::glmer(inter_formula, data = data, family = family)
      },
      warning = function(w) {
        n_warn <<- n_warn + 1L
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) NULL
  )
  if (is.null(inter)) {
    cli::cli_inform(c(
      "i" = "Could not fit the time x {.field {by_vars}} interaction to check the shared-shape assumption."
    ))
    return(invisible(NULL))
  }
  delta_bic <- stats::BIC(inter) - stats::BIC(model)
  verdict <- if (delta_bic < 0) {
    "favours separate diurnal shapes per stratum; consider an interaction via {.arg formula}"
  } else {
    "favours the shared shape used for this estimate"
  }
  cli::cli_inform(c(
    "i" = paste0("BIC(interaction) - BIC(additive) = {round(delta_bic, 1)}: ", verdict, "."),
    if (n_warn > 0L) c(" " = "The interaction fit raised {n_warn} warning{?s}; treat the comparison with caution.")
  ))
  invisible(NULL)
}
