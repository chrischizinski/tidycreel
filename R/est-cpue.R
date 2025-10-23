#' CPUE Estimator (survey-first)
#'
#' Design-based estimation of catch per unit effort (CPUE) using the
#' `survey` package. Supports ratio-of-means (recommended for incomplete trips)
#' and mean-of-ratios (for complete trips). Returns a tidy tibble with a
#' consistent schema across estimators.
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
#' @param mode Estimation mode: `"auto"` (default; automatically selects based on
#'   trip_complete field), `"ratio_of_means"` (for incomplete trips), or
#'   `"mean_of_ratios"` (for complete trips).
#' @param min_trip_hours Minimum trip duration in hours for incomplete trips.
#'   Trips shorter than this are truncated to avoid unstable ratios. Default 0.5 (30 minutes).
#'   Only used when mode="auto" or mode="ratio_of_means" with incomplete trips.
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#'
#' @details
#' - **Auto mode**: Examines `trip_complete` field to determine appropriate estimator.
#'   For complete trips uses mean-of-ratios; for incomplete uses ratio-of-means with
#'   truncation; for mixed data combines estimates using effort-weighting.
#' - **Ratio-of-means**: `svyratio(~response, ~effort_col)` optionally via
#'   `svyby(…, by=~group, FUN=svyratio)`. This is robust when trips are
#'   incomplete. Short trips are truncated when detected.
#' - **Mean-of-ratios**: computes trip-level `response/effort_col` then uses
#'   `svymean`/`svyby`. Prefer for complete trips with minimal zero-inflation.
#'
#' @importFrom stats update
#' @seealso [survey::svyratio()], [survey::svymean()], [survey::svyby()].
#' @export
est_cpue <- function(design,
                     by = NULL,
                     response = c("catch_total", "catch_kept", "weight_total"),
                     effort_col = "hours_fished",
                     mode = c("auto", "ratio_of_means", "mean_of_ratios"),
                     min_trip_hours = 0.5,
                     conf_level = 0.95) {
  response <- match.arg(response)
  mode <- match.arg(mode)

  # Handle auto mode
  if (mode == "auto") {
    return(est_cpue_auto(
      design = design,
      by = by,
      response = response,
      effort_col = effort_col,
      min_trip_hours = min_trip_hours,
      conf_level = conf_level
    ))
  }

  # Derive a survey design over interviews
  svy <- tc_interview_svy(design)
  vars <- svy$variables

  # Validate required columns
  req <- c(response, effort_col)
  tc_abort_missing_cols(vars, req, context = "est_cpue")

  # Grouping
  by <- tc_group_warn(by %||% character(), names(vars))

  # Build estimation by grouping
  if (mode == "ratio_of_means") {
    # Grouped svyratio
    if (length(by) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
      est <- survey::svyby(
        as.formula(paste0("~", response)),
        by = by_formula,
        design = svy,
        FUN = survey::svyratio,
        denominator = as.formula(paste0("~", effort_col)),
        na.rm = TRUE,
        keep.names = FALSE
      )
      out <- tibble::as_tibble(est)
      # Robust: take estimates and SE directly from model methods
      out$estimate <- as.numeric(stats::coef(est))
      se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
      if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
        out$se <- se_try
      } else {
        V <- attr(est, "var")
        out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      }
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se
      # n by group (unweighted count)
      n_by <- vars |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)
      out$method <- paste0("cpue_ratio_of_means:", response)
      out$diagnostics <- replicate(nrow(out), list(NULL))
      return(dplyr::select(out, dplyr::all_of(by), estimate, se, ci_low, ci_high, n, method, diagnostics))
    } else {
      r <- survey::svyratio(
        as.formula(paste0("~", response)),
        as.formula(paste0("~", effort_col)),
        svy,
        na.rm = TRUE
      )
      estimate <- as.numeric(stats::coef(r))
      se <- sqrt(as.numeric(stats::vcov(r)))
      ci <- tc_confint(estimate, se, level = conf_level)
      n <- nrow(vars)
      return(tibble::tibble(
        estimate = estimate, se = se, ci_low = ci[1], ci_high = ci[2], n = n,
        method = paste0("cpue_ratio_of_means:", response), diagnostics = list(NULL)
      ))
    }
  } else {
    # mean_of_ratios: define per-trip CPUE
    svy2 <- stats::update(svy, .cpue = vars[[response]] / vars[[effort_col]])
    if (length(by) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
      est <- survey::svyby(
        ~.cpue,
        by = by_formula,
        design = svy2,
        FUN = survey::svymean,
        na.rm = TRUE,
        keep.names = FALSE
      )
      out <- tibble::as_tibble(est)
      names(out)[names(out) == ".cpue"] <- "estimate"
      se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
      if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
        out$se <- se_try
      } else {
        V <- attr(est, "var")
        out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      }
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se
      n_by <- vars |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)
      out$method <- paste0("cpue_mean_of_ratios:", response)
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
      m <- survey::svymean(~.cpue, svy2, na.rm = TRUE)
      estimate <- as.numeric(m[1])
      se <- sqrt(as.numeric(stats::vcov(m)))
      ci <- tc_confint(estimate, se, level = conf_level)
      n <- nrow(vars)
      return(tibble::tibble(
        estimate = estimate, se = se, ci_low = ci[1], ci_high = ci[2], n = n,
        method = paste0("cpue_mean_of_ratios:", response), diagnostics = list(NULL)
      ))
    }
  }
}

# Minimal helper: interview-level svy design from `creel_design` or passthrough
#' @keywords internal
tc_interview_svy <- function(design) {
  if (inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    return(design)
  }
  if (inherits(design, "creel_design")) {
    interviews <- design$interviews
    if (is.null(interviews)) {
      cli::cli_abort(
        "creel_design must include $interviews for CPUE/catch estimators."
      )
    }
    # Use strata vars when available; assume equal weights (warn)
    if (!is.null(design$strata_vars)) {
      strata_present <- intersect(design$strata_vars, names(interviews))
      if (length(strata_present) == 0) strata_present <- NULL
    } else {
      strata_present <- NULL
    }
    cli::cli_warn(c(
      "!" = "Constructing an equal-weight interview design (ids=~1).",
      "i" = "Provide a proper svydesign/svrepdesign for defensible inference."
    ))
    return(
      survey::svydesign(
        ids = ~1,
        strata = if (!is.null(strata_present)) stats::as.formula(
          paste("~", paste(strata_present, collapse = "+"))
        ) else NULL,
        data = interviews
      )
    )
  }
  cli::cli_abort("design must be a svydesign/svrepdesign or creel_design.")
}

# Auto mode: intelligent estimator selection based on trip_complete field
#' @keywords internal
est_cpue_auto <- function(design, by, response, effort_col, min_trip_hours, conf_level) {
  # Get survey design and data
  svy <- tc_interview_svy(design)
  vars <- svy$variables

  # Check for trip_complete column (STRICT requirement)
  if (!"trip_complete" %in% names(vars)) {
    cli::cli_abort(c(
      "x" = "mode='auto' requires a 'trip_complete' column in interview data.",
      "i" = "Add trip_complete (logical: TRUE for complete trips, FALSE for incomplete),",
      "i" = "or specify mode='ratio_of_means' or mode='mean_of_ratios' explicitly."
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
    cli::cli_warn(c(
      "!" = "{n_na} interview{?s} with missing trip_complete status will be excluded."
    ))
    # Filter out NAs
    vars <- vars[!is.na(vars$trip_complete), ]
    svy <- survey::subset(svy, !is.na(trip_complete))
    n_total <- n_complete + n_incomplete
  }

  if (n_total == 0) {
    cli::cli_abort("No valid interviews after removing missing trip_complete values.")
  }

  pct_complete <- round(100 * n_complete / n_total, 1)
  pct_incomplete <- round(100 * n_incomplete / n_total, 1)

  # Case 1: All complete trips
  if (n_incomplete == 0) {
    cli::cli_inform(c(
      "v" = "Auto mode: Detected 100% complete trips (n={n_complete}).",
      "i" = "Using mean-of-ratios estimator (appropriate for complete trips)."
    ))
    return(est_cpue(
      design = svy,
      by = by,
      response = response,
      effort_col = effort_col,
      mode = "mean_of_ratios",
      conf_level = conf_level
    ))
  }

  # Case 2: All incomplete trips
  if (n_complete == 0) {
    # Apply truncation
    n_before <- nrow(vars)
    short_trips <- vars[[effort_col]] < min_trip_hours
    n_truncated <- sum(short_trips, na.rm = TRUE)

    if (n_truncated > 0) {
      cli::cli_inform(c(
        "v" = "Auto mode: Detected 100% incomplete trips (n={n_incomplete}).",
        "!" = "Truncating {n_truncated} trip{?s} < {min_trip_hours} hours to avoid unstable ratios.",
        "i" = "Using ratio-of-means estimator (appropriate for incomplete trips)."
      ))
      svy <- survey::subset(svy, !!as.name(effort_col) >= min_trip_hours)
    } else {
      cli::cli_inform(c(
        "v" = "Auto mode: Detected 100% incomplete trips (n={n_incomplete}).",
        "i" = "Using ratio-of-means estimator (appropriate for incomplete trips)."
      ))
    }

    return(est_cpue(
      design = svy,
      by = by,
      response = response,
      effort_col = effort_col,
      mode = "ratio_of_means",
      conf_level = conf_level
    ))
  }

  # Case 3: Mixed complete and incomplete trips (HYBRID)
  cli::cli_inform(c(
    "v" = "Auto mode: Detected mixed trip types:",
    "*" = "Complete: {n_complete} ({pct_complete}%)",
    "*" = "Incomplete: {n_incomplete} ({pct_incomplete}%)",
    "i" = "Using hybrid approach: separate estimation + effort-weighted combination."
  ))

  # Separate into complete and incomplete
  svy_complete <- survey::subset(svy, trip_complete == TRUE)
  svy_incomplete <- survey::subset(svy, trip_complete == FALSE)

  # Apply truncation to incomplete trips
  vars_incomplete <- svy_incomplete$variables
  short_trips <- vars_incomplete[[effort_col]] < min_trip_hours
  n_truncated <- sum(short_trips, na.rm = TRUE)

  if (n_truncated > 0) {
    cli::cli_inform(c(
      "!" = "Truncating {n_truncated} short incomplete trip{?s} < {min_trip_hours} hours."
    ))
    svy_incomplete <- survey::subset(svy_incomplete, !!as.name(effort_col) >= min_trip_hours)
  }

  # Estimate CPUE for each group
  cpue_complete <- est_cpue(
    design = svy_complete,
    by = by,
    response = response,
    effort_col = effort_col,
    mode = "mean_of_ratios",
    conf_level = conf_level
  )

  cpue_incomplete <- est_cpue(
    design = svy_incomplete,
    by = by,
    response = response,
    effort_col = effort_col,
    mode = "ratio_of_means",
    conf_level = conf_level
  )

  # Calculate total effort for each group
  vars_complete <- svy_complete$variables
  vars_incomplete_filtered <- svy_incomplete$variables

  E_complete <- sum(vars_complete[[effort_col]], na.rm = TRUE)
  E_incomplete <- sum(vars_incomplete_filtered[[effort_col]], na.rm = TRUE)
  E_total <- E_complete + E_incomplete

  # Combine estimates using effort-weighting
  # R_combined = (R1 * E_complete + R2 * E_incomplete) / E_total
  w_complete <- E_complete / E_total
  w_incomplete <- E_incomplete / E_total

  R1 <- cpue_complete$estimate
  R2 <- cpue_incomplete$estimate
  SE1 <- cpue_complete$se
  SE2 <- cpue_incomplete$se

  # Combined estimate
  R_combined <- R1 * w_complete + R2 * w_incomplete

  # Combined SE using delta method
  # Var(R_combined) ≈ w1^2 * Var(R1) + w2^2 * Var(R2)
  # (assuming independence between complete and incomplete samples)
  SE_combined <- sqrt(w_complete^2 * SE1^2 + w_incomplete^2 * SE2^2)

  # Confidence interval
  z <- stats::qnorm(1 - (1 - conf_level)/2)
  ci_low <- R_combined - z * SE_combined
  ci_high <- R_combined + z * SE_combined

  cli::cli_inform(c(
    "v" = "Hybrid combination complete:",
    "*" = "Complete trips: CPUE = {round(R1, 3)} (weight = {round(w_complete, 3)})",
    "*" = "Incomplete trips: CPUE = {round(R2, 3)} (weight = {round(w_incomplete, 3)})",
    "*" = "Combined: CPUE = {round(R_combined, 3)} +/- {round(SE_combined, 3)}"
  ))

  # Return combined result
  result <- tibble::tibble(
    estimate = R_combined,
    se = SE_combined,
    ci_low = ci_low,
    ci_high = ci_high,
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
    ))
  )

  # Add grouping columns if present
  if (!is.null(by) && length(by) > 0) {
    # For now, hybrid mode doesn't support grouping
    cli::cli_warn(c(
      "!" = "Grouping (by=) not yet supported in hybrid mode.",
      "i" = "Returning overall estimate across all groups."
    ))
  }

  return(result)
}
