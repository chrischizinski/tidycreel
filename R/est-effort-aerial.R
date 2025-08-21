#' Aerial Effort Estimator
#'
#' Estimate angler-hours from aerial snapshot counts using a mean-count
#' expansion within groups, with optional visibility and calibration
#' adjustments, and design-based variance via the `survey` package when a
#' day-level `svydesign` is provided.
#'
#' Effort per day×group = mean(adjusted_count) × total_minutes_represented ÷ 60.
#' Group totals are then computed with `survey::svytotal`/`svyby` when `svy`
#' encodes the day sampling design.
#'
#' @param counts Data frame/tibble of aerial counts with at least `count` and a
#'   minutes column (e.g., `flight_minutes`, `interval_minutes`, or `count_duration`).
#' @param by Character vector of grouping variables present in `counts`
#'   (e.g., `date`, `location`). Missing columns are ignored with a warning.
#' @param minutes_col Candidate column names for minutes represented by each
#'   count. The first present is used.
#' @param total_minutes_col Optional column giving the total minutes represented
#'   for the whole day×group (e.g., full day length or block coverage). If
#'   absent, the estimator falls back to the sum of per-count minutes within the
#'   day×group (warns).
#' @param day_id Day identifier (PSU), typically `date`, used to join to the
#'   survey design.
#' @param covariates Optional character vector of additional grouping variables
#'   for aerial conditions (e.g., `cloud`, `glare`, `observer`, `altitude`).
#' @param visibility_col Optional name of a column with visibility proportion
#'   (0–1). Counts are divided by this value (guarded to avoid division by very
#'   small numbers).
#' @param calibration_col Optional name of a column with multiplicative
#'   calibration factors to apply after visibility correction.
#' @param svy Optional `svydesign`/`svrepdesign` encoding the day sampling
#'   design (must include `day_id` in `svy$variables`). When provided, totals,
#'   SEs, and CIs are computed with `survey` functions.
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#' @examples
#' df <- tibble::tibble(
#'   date = as.Date(rep("2025-08-20", 4)),
#'   location = c("A","A","B","B"),
#'   count = c(10, 12, 8, 15),
#'   interval_minutes = c(60, 60, 60, 60)
#' )
#' est_effort.aerial(df)
#' @export
est_effort.aerial <- function(counts,
                              by = c("date", "location"),
                              minutes_col = c("flight_minutes", "interval_minutes", "count_duration"),
                              total_minutes_col = c("total_minutes", "total_day_minutes", "block_total_minutes"),
                              day_id = "date",
                              covariates = NULL,
                              visibility_col = NULL,
                              calibration_col = NULL,
                              svy = NULL,
                              post_strata_var = NULL,
                              post_strata = NULL,
                              calibrate_formula = NULL,
                              calibrate_population = NULL,
                              calfun = c("linear", "raking", "logit"),
                              conf_level = 0.95) {
  calfun <- match.arg(calfun)
  # Validate required columns
  tc_require_cols(counts, c("count"), context = "aerial effort")
  min_col <- intersect(minutes_col, names(counts))
  if (length(min_col) == 0) {
    cli::cli_abort(c(
      "x" = "Missing minutes column for aerial effort.",
      "i" = paste0("Provide one of: ", paste(minutes_col, collapse = ", "))
    ))
  }
  min_col <- min_col[1]

  # Visibility / calibration adjustments
  adj <- counts$count
  if (!is.null(visibility_col) && visibility_col %in% names(counts)) {
    vis <- pmax(counts[[visibility_col]], 0.1) # guardrail against tiny values
    adj <- adj / vis
  }
  if (!is.null(calibration_col) && calibration_col %in% names(counts)) {
    adj <- adj * counts[[calibration_col]]
  }

  counts$adj_count <- adj

  # Grouping
  by <- tc_group_warn(by, names(counts))
  if (is.null(covariates)) covariates <- character()
  covariates <- tc_group_warn(covariates, names(counts))
  by_all <- unique(c(by, covariates))

  # Determine total minutes represented per day×group
  tot_min_col <- intersect(total_minutes_col, names(counts))
  warn_used_sum <- FALSE
  if (length(tot_min_col) == 0) {
    # Fallback: sum of per-count minutes within day×group
    tot_min_col <- min_col
    warn_used_sum <- TRUE
  } else {
    tot_min_col <- tot_min_col[1]
  }

  # Compute day-level totals per group
  day_group <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(
      mean_count = mean(adj_count, na.rm = TRUE),
      total_minutes = if (warn_used_sum) sum(.data[[min_col]], na.rm = TRUE) else dplyr::first(.data[[tot_min_col]]),
      n_counts = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(effort_day = mean_count * total_minutes / 60)

  if (warn_used_sum) {
    cli::cli_warn(c("!" = paste0("Aerial: using sum of ", min_col, " per day×group as total minutes."),
                   "i" = "Provide `total_minutes_col` for proper expansion."))
  }

  # If a day-level survey design is provided, compute design-based totals via survey
  if (!is.null(svy)) {
    # Attempt to extract day-level weights and (optional) strata from svy
    svy_vars <- svy$variables
    if (!(day_id %in% names(svy_vars))) {
      cli::cli_abort(paste0("`svy` must have `", day_id, "` in its variables to join day-level totals."))
    }
    # Compose a minimal lookup with day_id and survey weights; include any grouping vars present
    svy_lookup <- tibble::tibble(
      !!rlang::sym(day_id) := svy_vars[[day_id]],
      .w = as.numeric(stats::weights(svy))
    )
    # Try to carry a strata column if present
    strata_col <- intersect(c("stratum", "strata", "stratum_id"), names(svy_vars))
    if (length(strata_col) > 0) {
      svy_lookup[[strata_col[1]]] <- svy_vars[[strata_col[1]]]
    }

    # Join weights/strata onto day_group
    day_group <- dplyr::left_join(day_group, svy_lookup, by = day_id)
    if (!".w" %in% names(day_group)) {
      cli::cli_abort(paste0("Failed to join survey weights. Ensure `svy` aligns on `", day_id, "`."))
    }

    # Build a survey design on day×group rows using day-level weights.
    # If `svy` is a replicate design, carry replicate weights over days.
    ids_formula <- stats::as.formula(paste("~", day_id))
    if (inherits(svy, "svyrep.design")) {
      # Extract replicate weights and attributes
      repmat <- survey::repweights(svy)
      repnames <- colnames(repmat)
      rep_df <- tibble::as_tibble(repmat)
      rep_df[[day_id]] <- svy_vars[[day_id]]
      # Join replicate weights to day_group (duplicates across group rows by day)
      day_group <- dplyr::left_join(day_group, rep_df, by = day_id)
      repcols <- repnames[repnames %in% names(day_group)]
      if (length(repcols) != ncol(repmat)) {
        cli::cli_abort("Failed to align replicate weights on day_id for aerial estimator.")
      }
      type <- attr(repmat, "type") %||% "bootstrap"
      scale <- attr(repmat, "scale") %||% 1
      rscales <- attr(repmat, "rscales") %||% 1
      combined.weights <- attr(repmat, "combined.weights") %||% TRUE
      design_eff <- survey::svrepdesign(
        data = day_group,
        repweights = as.matrix(day_group[, repcols]),
        weights = ~.w,
        type = type,
        scale = scale,
        rscales = rscales,
        combined.weights = combined.weights
      )
    } else {
      if (length(strata_col) > 0) {
        design_eff <- survey::svydesign(ids = ids_formula,
                                        strata = stats::as.formula(paste("~", strata_col[1])),
                                        weights = ~.w,
                                        data = day_group)
      } else {
        design_eff <- survey::svydesign(ids = ids_formula, weights = ~.w, data = day_group)
      }
    }

    # Optional: post-stratification by a categorical covariate
    if (!is.null(post_strata_var) && !is.null(post_strata)) {
      if (!(post_strata_var %in% names(day_group))) {
        cli::cli_abort(paste0("post_strata_var not found in counts/day_group data: ", post_strata_var))
      }
      # Ensure population table has columns: levels of post_strata_var and Freq
      if (!all(c(post_strata_var, "Freq") %in% names(post_strata))) {
        cli::cli_abort(paste0("post_strata must have columns: ", post_strata_var, " and Freq"))
      }
      pf <- stats::as.formula(paste("~", post_strata_var))
      design_eff <- survey::postStratify(design_eff, pf, post_strata)
    }

    # Optional: calibration to known totals
    if (!is.null(calibrate_formula) && !is.null(calibrate_population)) {
      calfun_fun <- switch(calfun,
        linear = survey::cal.linear,
        raking = survey::cal.raking,
        logit = survey::cal.logit
      )
      design_eff <- survey::calibrate(design_eff,
                                      formula = calibrate_formula,
                                      population = calibrate_population,
                                      calfun = calfun_fun)
    }

    # Use svyby to get totals by requested groups (by + covariates)
    if (length(by_all) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by_all, collapse = "+")))
      est <- survey::svyby(~effort_day, by = by_formula, design_eff, survey::svytotal, na.rm = TRUE)
      out <- tibble::as_tibble(est)
      names(out)[names(out) == "effort_day"] <- "estimate"
      # SE via vcov attribute for svyby (diagonal elements)
      V <- attr(est, "var")
      out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      # CI via normal approximation
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se
      out$n <- NA_integer_
      out$method <- "aerial"
      out$diagnostics <- replicate(nrow(out), list(NULL))
      out <- dplyr::select(out, dplyr::all_of(by_all), estimate, se, ci_low, ci_high, n, method, diagnostics)
      return(out)
    } else {
      total_est <- survey::svytotal(~effort_day, design_eff, na.rm = TRUE)
      estimate <- as.numeric(total_est[1])
      se <- sqrt(as.numeric(survey::vcov(total_est)))
      ci <- tc_confint(estimate, se, level = conf_level)
      return(tibble::tibble(
        estimate = estimate,
        se = se,
        ci_low = ci[1],
        ci_high = ci[2],
        n = NA_integer_,
        method = "aerial",
        diagnostics = list(NULL)
      ))
    }
  }

  # Fallback (no svy): produce per-group estimates using within-group variability only
  out <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by_all))) |>
    dplyr::summarise(
      mean_count = mean(adj_count, na.rm = TRUE),
      sd_count = stats::sd(adj_count, na.rm = TRUE),
      total_minutes = if (warn_used_sum) sum(.data[[min_col]], na.rm = TRUE) else dplyr::first(.data[[tot_min_col]]),
      n = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      estimate = mean_count * total_minutes / 60,
      se = ifelse(n > 1, (sd_count / sqrt(n)) * (total_minutes / 60), NA_real_)
    )
  # Compute CI row-wise to keep dependencies minimal
  out$ci_low <- NA_real_
  out$ci_high <- NA_real_
  idx <- which(out$n > 1 & !is.na(out$estimate) & !is.na(out$se))
  if (length(idx) > 0) {
    cis <- tc_confint(out$estimate[idx], out$se[idx], level = conf_level)
    out$ci_low[idx] <- cis[seq_along(idx)]
    out$ci_high[idx] <- cis[length(idx) + seq_along(idx)]
  }
  out$method <- "aerial"
  out$diagnostics <- replicate(nrow(out), list(NULL))
  dplyr::select(out, dplyr::all_of(by_all), estimate, se, ci_low, ci_high, n, method, diagnostics)
}

#' Back-compat alias for aerial estimator
#'
#' Accepts either a `creel_design` in `x` with embedded counts or a `counts`
#' data frame directly. Prefer `est_effort.aerial()` with `counts`.
#'
#' @inheritParams est_effort.aerial
#' @param x Optional `creel_design` containing a `$counts` component.
#' @export
est_effort_aerial <- function(x = NULL,
                              counts = NULL,
                              by = c("date", "location"),
                              minutes_col = c("flight_minutes", "interval_minutes", "count_duration"),
                              total_minutes_col = c("total_minutes", "total_day_minutes", "block_total_minutes"),
                              day_id = "date",
                              covariates = NULL,
                              visibility_col = NULL,
                              calibration_col = NULL,
                              svy = NULL,
                              conf_level = 0.95,
                              ...) {
  if (is.null(counts)) {
    if (!is.null(x) && !is.null(x$counts)) {
      counts <- x$counts
    } else {
      cli::cli_abort("Provide `counts` or a design object `x` with `$counts`.")
    }
  }
  est_effort.aerial(counts = counts,
                    by = by,
                    minutes_col = minutes_col,
                    total_minutes_col = total_minutes_col,
                    day_id = day_id,
                    covariates = covariates,
                    visibility_col = visibility_col,
                    calibration_col = calibration_col,
                    svy = svy,
                    conf_level = conf_level)
}
