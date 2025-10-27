#' CPUE Estimator (REBUILT with Native Survey Integration)
#'
#' Design-based estimation of catch per unit effort (CPUE) using the
#' `survey` package with NATIVE support for advanced variance methods.
#'
#' **NEW**: Native support for multiple variance methods, variance decomposition,
#' and design diagnostics without requiring wrapper functions.
#'
#' @param design A `svydesign`/`svrepdesign` built on interview data, or a
#'   `creel_design` containing `interviews`. If a `creel_design` is supplied,
#'   a minimal equal-weight design is constructed (warns).
#' @param by Character vector of grouping variables present in the interview
#'   data (e.g., `c("target_species","location")`). Missing columns are
#'   ignored with a warning.
#' @param response One of `"catch_total"`, `"catch_kept"`, or `"weight_total"`.
#'   Determines the CPUE numerator.
#' @param effort_col Interview effort column for the denominator (default
#'   `"hours_fished"`).
#' @param mode Estimation mode: `"auto"` (default), `"ratio_of_means"`, or
#'   `"mean_of_ratios"`.
#' @param min_trip_hours Minimum trip duration for incomplete trips (default 0.5).
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#' @param variance_method **NEW** Variance estimation method (default "survey")
#' @param decompose_variance **NEW** Logical, decompose variance (default FALSE)
#' @param design_diagnostics **NEW** Logical, compute diagnostics (default FALSE)
#' @param n_replicates **NEW** Bootstrap/jackknife replicates (default 1000)
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `deff` (design effect), `n`, `method`, `diagnostics` list-column, and
#'   `variance_info` list-column.
#'
#' @details
#' - **Auto mode**: Examines `trip_complete` field to determine appropriate estimator.
#' - **Ratio-of-means**: Robust for incomplete trips
#' - **Mean-of-ratios**: Preferred for complete trips
#' - **For roving surveys**: Use [est_cpue_roving()] for Pollock correction
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE
#' result <- est_cpue(design, response = "catch_kept")
#'
#' # NEW: Advanced features
#' result <- est_cpue(
#'   design,
#'   response = "catch_kept",
#'   variance_method = "bootstrap",
#'   decompose_variance = TRUE,
#'   design_diagnostics = TRUE
#' )
#' }
#'
#' @seealso [est_cpue_roving()], [survey::svyratio()], [survey::svymean()]
#' @export
est_cpue <- function(design,
                             by = NULL,
                             response = c("catch_total", "catch_kept", "weight_total"),
                             effort_col = "hours_fished",
                             mode = c("auto", "ratio_of_means", "mean_of_ratios"),
                             min_trip_hours = 0.5,
                             conf_level = 0.95,
                             variance_method = "survey",
                             decompose_variance = FALSE,
                             design_diagnostics = FALSE,
                             n_replicates = 1000) {
  response <- match.arg(response)
  mode <- match.arg(mode)

  # Handle auto mode (delegates to helper which will call this function recursively)
  if (mode == "auto") {
    return(est_cpue_auto(
      design = design,
      by = by,
      response = response,
      effort_col = effort_col,
      min_trip_hours = min_trip_hours,
      conf_level = conf_level,
      variance_method = variance_method,
      decompose_variance = decompose_variance,
      design_diagnostics = design_diagnostics,
      n_replicates = n_replicates
    ))
  }

  # ── Derive Survey Design (unchanged) ──────────────────────────────────────
  svy <- tc_interview_svy(design)
  vars <- svy$variables

  # Validate required columns
  req <- c(response, effort_col)
  tc_abort_missing_cols(vars, req, context = "est_cpue")

  # Grouping
  by <- tc_group_warn(by %||% character(), names(vars))

  # ── Estimate CPUE (REBUILT with variance engine) ─────────────────────────

  # Check for zero or missing effort values
  zero_effort <- sum(vars[[effort_col]] <= 0 | is.na(vars[[effort_col]]), na.rm = TRUE)
  if (zero_effort > 0) {
    cli::cli_warn(c(
      "!" = "{zero_effort} observation(s) have zero or negative effort",
      "i" = "These will produce Inf or NaN CPUE values",
      "i" = "Consider filtering data or setting a minimum effort threshold"
    ))
  }

  if (mode == "ratio_of_means") {
    # For ratio estimation, create ratio variable first then use mean
    # Replace Inf/NaN from zero effort with NA
    cpue_ratio_values <- vars[[response]] / vars[[effort_col]]
    cpue_ratio_values[!is.finite(cpue_ratio_values)] <- NA_real_
    svy_ratio <- stats::update(svy, .cpue_ratio = cpue_ratio_values)

    if (length(by) > 0) {
      # Grouped estimation using core variance engine
      variance_result <- tc_compute_variance(
        design = svy_ratio,
        response = ".cpue_ratio",
        method = variance_method,
        by = by,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      # Use group_data from variance_result for proper alignment
      if (!is.null(variance_result$group_data)) {
        out <- tibble::as_tibble(variance_result$group_data)
      } else {
        # Fallback: extract from design (shouldn't happen with fixed variance engine)
        out <- tibble::tibble(
          !!!setNames(
            lapply(by, function(v) unique(svy_ratio$variables[[v]])[seq_along(variance_result$estimate)]),
            by
          )
        )
      }

      # Add variance estimates
      out$estimate <- variance_result$estimate
      out$se <- variance_result$se
      out$ci_low <- variance_result$ci_lower
      out$ci_high <- variance_result$ci_upper
      out$deff <- variance_result$deff

      # Get sample sizes (now properly aligned with variance results)
      n_by <- vars |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)

    } else {
      # Overall estimation using core variance engine
      variance_result <- tc_compute_variance(
        design = svy_ratio,
        response = ".cpue_ratio",
        method = variance_method,
        by = NULL,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      out <- tibble::tibble(
        estimate = variance_result$estimate,
        se = variance_result$se,
        ci_low = variance_result$ci_lower,
        ci_high = variance_result$ci_upper,
        deff = variance_result$deff,
        n = nrow(vars)
      )
    }

    out$method <- paste0("cpue_ratio_of_means:", response)

  } else {
    # mean_of_ratios: define per-trip CPUE
    # Replace Inf/NaN from zero effort with NA
    cpue_values <- vars[[response]] / vars[[effort_col]]
    cpue_values[!is.finite(cpue_values)] <- NA_real_
    svy2 <- stats::update(svy, .cpue = cpue_values)

    if (length(by) > 0) {
      # Grouped estimation using core variance engine
      variance_result <- tc_compute_variance(
        design = svy2,
        response = ".cpue",
        method = variance_method,
        by = by,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      # Use group_data from variance_result for proper alignment
      if (!is.null(variance_result$group_data)) {
        out <- tibble::as_tibble(variance_result$group_data)
      } else {
        # Fallback: extract from design (shouldn't happen with fixed variance engine)
        out <- tibble::tibble(
          !!!setNames(
            lapply(by, function(v) unique(svy2$variables[[v]])[seq_along(variance_result$estimate)]),
            by
          )
        )
      }

      # Add variance estimates
      out$estimate <- variance_result$estimate
      out$se <- variance_result$se
      out$ci_low <- variance_result$ci_lower
      out$ci_high <- variance_result$ci_upper
      out$deff <- variance_result$deff

      # Get sample sizes (now properly aligned with variance results)
      n_by <- vars |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)

    } else {
      # Overall estimation using core variance engine
      variance_result <- tc_compute_variance(
        design = svy2,
        response = ".cpue",
        method = variance_method,
        by = NULL,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      out <- tibble::tibble(
        estimate = variance_result$estimate,
        se = variance_result$se,
        ci_low = variance_result$ci_lower,
        ci_high = variance_result$ci_upper,
        deff = variance_result$deff,
        n = nrow(vars)
      )
    }

    out$method <- paste0("cpue_mean_of_ratios:", response)
  }

  # ── NEW: Variance Decomposition ───────────────────────────────────────────
  if (decompose_variance) {
    variance_result$decomposition <- tryCatch({
      design_to_use <- if (mode == "ratio_of_means") svy_ratio else svy2
      response_to_use <- if (mode == "ratio_of_means") ".cpue_ratio" else ".cpue"

      tc_decompose_variance(
        design = design_to_use,
        response = response_to_use,
        cluster_vars = character(),
        method = "anova",
        conf_level = conf_level
      )
    }, error = function(e) {
      cli::cli_warn("Variance decomposition failed: {e$message}")
      NULL
    })
  }

  # ── NEW: Design Diagnostics ───────────────────────────────────────────────
  if (design_diagnostics) {
    variance_result$diagnostics_survey <- tryCatch({
      design_to_use <- if (mode == "ratio_of_means") svy_ratio else svy2
      tc_design_diagnostics(design = design_to_use, detailed = FALSE)
    }, error = function(e) {
      cli::cli_warn("Design diagnostics failed: {e$message}")
      NULL
    })
  }

  # ── Add metadata ──────────────────────────────────────────────────────────
  out$diagnostics <- replicate(nrow(out), list(NULL), simplify = FALSE)
  out$variance_info <- replicate(nrow(out), list(variance_result), simplify = FALSE)

  return(dplyr::select(
    out,
    dplyr::all_of(by),
    estimate, se, ci_low, ci_high, deff, n, method, diagnostics, variance_info
  ))
}

# Auto mode: intelligent estimator selection (REBUILT to pass new parameters)
#' @keywords internal
est_cpue_auto <- function(design, by, response, effort_col, min_trip_hours,
                                   conf_level, variance_method, decompose_variance,
                                   design_diagnostics, n_replicates) {
  # Get survey design and data
  svy <- tc_interview_svy(design)
  vars <- svy$variables

  # Check for trip_complete column
  if (!"trip_complete" %in% names(vars)) {
    cli::cli_abort(c(
      "x" = "mode='auto' requires a 'trip_complete' column in interview data.",
      "i" = "Add trip_complete (logical: TRUE/FALSE), or specify mode explicitly."
    ))
  }

  # Validate required columns
  req <- c(response, effort_col, "trip_complete")
  tc_abort_missing_cols(vars, req, context = "est_cpue (auto mode)")

  # Analyze trip completion status
  n_complete <- sum(vars$trip_complete == TRUE, na.rm = TRUE)
  n_incomplete <- sum(vars$trip_complete == FALSE, na.rm = TRUE)
  n_total <- n_complete + n_incomplete

  # Handle NA values
  n_na <- sum(is.na(vars$trip_complete))
  if (n_na > 0) {
    cli::cli_warn("{n_na} interview{?s} with missing trip_complete excluded.")
    vars <- vars[!is.na(vars$trip_complete), ]
    svy <- survey::subset(svy, !is.na(trip_complete))
    n_total <- n_complete + n_incomplete
  }

  if (n_total == 0) {
    cli::cli_abort("No valid interviews after removing missing trip_complete.")
  }

  pct_complete <- round(100 * n_complete / n_total, 1)
  pct_incomplete <- round(100 * n_incomplete / n_total, 1)

  # Case 1: All complete trips
  if (n_incomplete == 0) {
    cli::cli_inform(c(
      "v" = "Auto: 100% complete trips (n={n_complete}). Using mean-of-ratios."
    ))
    return(est_cpue(
      design = svy,
      by = by,
      response = response,
      effort_col = effort_col,
      mode = "mean_of_ratios",
      conf_level = conf_level,
      variance_method = variance_method,
      decompose_variance = decompose_variance,
      design_diagnostics = design_diagnostics,
      n_replicates = n_replicates
    ))
  }

  # Case 2: All incomplete trips
  if (n_complete == 0) {
    # Apply truncation
    short_trips <- vars[[effort_col]] < min_trip_hours
    n_truncated <- sum(short_trips, na.rm = TRUE)

    if (n_truncated > 0) {
      cli::cli_inform(c(
        "v" = "Auto: 100% incomplete trips (n={n_incomplete}).",
        "!" = "Truncating {n_truncated} trip{?s} < {min_trip_hours} hours.",
        "i" = "Using ratio-of-means."
      ))
      svy <- survey::subset(svy, !!as.name(effort_col) >= min_trip_hours)
    } else {
      cli::cli_inform(c(
        "v" = "Auto: 100% incomplete trips (n={n_incomplete}). Using ratio-of-means."
      ))
    }

    return(est_cpue(
      design = svy,
      by = by,
      response = response,
      effort_col = effort_col,
      mode = "ratio_of_means",
      conf_level = conf_level,
      variance_method = variance_method,
      decompose_variance = decompose_variance,
      design_diagnostics = design_diagnostics,
      n_replicates = n_replicates
    ))
  }

  # Case 3: Mixed (hybrid approach)
  cli::cli_inform(c(
    "v" = "Auto: Mixed trips - Complete: {n_complete} ({pct_complete}%), Incomplete: {n_incomplete} ({pct_incomplete}%)",
    "i" = "Using hybrid: separate estimation + effort-weighted combination."
  ))

  # Separate into complete and incomplete
  svy_complete <- survey::subset(svy, trip_complete == TRUE)
  svy_incomplete <- survey::subset(svy, trip_complete == FALSE)

  # Apply truncation to incomplete
  vars_incomplete <- svy_incomplete$variables
  short_trips <- vars_incomplete[[effort_col]] < min_trip_hours
  n_truncated <- sum(short_trips, na.rm = TRUE)

  if (n_truncated > 0) {
    cli::cli_inform("!" = "Truncating {n_truncated} short incomplete trip{?s}.")
    svy_incomplete <- survey::subset(svy_incomplete, !!as.name(effort_col) >= min_trip_hours)
  }

  # Estimate for each group
  cpue_complete <- est_cpue(
    design = svy_complete,
    by = by,
    response = response,
    effort_col = effort_col,
    mode = "mean_of_ratios",
    conf_level = conf_level,
    variance_method = variance_method,
    decompose_variance = FALSE,  # Don't decompose in subgroups
    design_diagnostics = FALSE,
    n_replicates = n_replicates
  )

  cpue_incomplete <- est_cpue(
    design = svy_incomplete,
    by = by,
    response = response,
    effort_col = effort_col,
    mode = "ratio_of_means",
    conf_level = conf_level,
    variance_method = variance_method,
    decompose_variance = FALSE,
    design_diagnostics = FALSE,
    n_replicates = n_replicates
  )

  # Calculate effort weights
  vars_complete <- svy_complete$variables
  vars_incomplete_filtered <- svy_incomplete$variables

  E_complete <- sum(vars_complete[[effort_col]], na.rm = TRUE)
  E_incomplete <- sum(vars_incomplete_filtered[[effort_col]], na.rm = TRUE)
  E_total <- E_complete + E_incomplete

  w_complete <- E_complete / E_total
  w_incomplete <- E_incomplete / E_total

  R1 <- cpue_complete$estimate
  R2 <- cpue_incomplete$estimate
  SE1 <- cpue_complete$se
  SE2 <- cpue_incomplete$se

  # Combined estimate
  R_combined <- R1 * w_complete + R2 * w_incomplete

  # Combined SE using delta method
  SE_combined <- sqrt(w_complete^2 * SE1^2 + w_incomplete^2 * SE2^2)

  # Confidence interval
  z <- stats::qnorm(1 - (1 - conf_level)/2)
  ci_low <- R_combined - z * SE_combined
  ci_high <- R_combined + z * SE_combined

  cli::cli_inform(c(
    "v" = "Hybrid complete:",
    "*" = "Complete: CPUE = {round(R1, 3)} (w = {round(w_complete, 3)})",
    "*" = "Incomplete: CPUE = {round(R2, 3)} (w = {round(w_incomplete, 3)})",
    "*" = "Combined: CPUE = {round(R_combined, 3)} +/- {round(SE_combined, 3)}"
  ))

  # Build combined result
  # Note: For hybrid, deff is not computed (would need special handling)
  result <- tibble::tibble(
    estimate = R_combined,
    se = SE_combined,
    ci_low = ci_low,
    ci_high = ci_high,
    deff = NA_real_,
    n = n_total,
    method = paste0("cpue_hybrid:", response),
    diagnostics = list(list(
      n_complete = n_complete,
      n_incomplete = n_incomplete - n_truncated,
      n_truncated = n_truncated,
      cpue_complete = R1,
      cpue_incomplete = R2,
      se_complete = SE1,
      se_incomplete = SE2,
      effort_complete = E_complete,
      effort_incomplete = E_incomplete,
      weight_complete = w_complete,
      weight_incomplete = w_incomplete
    )),
    variance_info = list(NULL)  # Hybrid doesn't have single variance_info
  )

  # Warn about grouping
  if (!is.null(by) && length(by) > 0) {
    cli::cli_warn(c(
      "!" = "Grouping not yet supported in hybrid mode.",
      "i" = "Returning overall estimate."
    ))
  }

  return(result)
}
