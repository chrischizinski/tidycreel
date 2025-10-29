#' Aerial Effort Estimator (REBUILT with Native Survey Integration)
#'
#' Estimate angler-hours from aerial snapshot counts using a mean-count
#' expansion within groups, with optional visibility and calibration
#' adjustments, and design-based variance via the `survey` package with
#' NATIVE support for advanced variance methods.
#'
#' **NEW**: Native support for multiple variance methods, variance decomposition,
#' and design diagnostics without requiring wrapper functions.
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
#' @param post_strata_var Optional post-stratification variable name
#' @param post_strata Optional post-stratification population table
#' @param calibrate_formula Optional calibration formula
#' @param calibrate_population Optional calibration population totals
#' @param calfun Calibration function: "linear", "raking", or "logit"
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#' @param variance_method **NEW** Variance estimation method (default "survey")
#' @param decompose_variance **NEW** Logical, decompose variance (default FALSE)
#' @param design_diagnostics **NEW** Logical, compute diagnostics (default FALSE)
#' @param n_replicates **NEW** Bootstrap/jackknife replicates (default 1000)
#' @param ... Additional arguments passed to survey functions
#'
#' @return Tibble with grouping columns plus:
#'   \describe{
#'     \item{estimate}{Estimated total effort (angler-hours)}
#'     \item{se}{Standard error}
#'     \item{ci_low, ci_high}{Confidence interval limits}
#'     \item{deff}{Design effect}
#'     \item{n}{Sample size}
#'     \item{method}{Estimation method ("aerial")}
#'     \item{variance_info}{**NEW** List-column with comprehensive variance information}
#'   }
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE
#' result <- est_effort.aerial_rebuilt(counts, svy = design)
#'
#' # NEW: Complete analysis
#' result_full <- est_effort.aerial_rebuilt(
#'   counts,
#'   svy = design,
#'   variance_method = "bootstrap",
#'   decompose_variance = TRUE,
#'   design_diagnostics = TRUE
#' )
#' }
#'
#' @export
est_effort.aerial <- function(
  counts,
  by = c("date", "location"),
  minutes_col = c("flight_minutes", "interval_minutes", "count_duration"),
  total_minutes_col = c(
    "total_minutes",
    "total_day_minutes",
    "block_total_minutes"
  ),
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
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
) {

  calfun <- match.arg(calfun)

  # ── Input Validation ──────────────────────────────────────────────────────
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

  # Determine total minutes
  tot_min_col <- intersect(total_minutes_col, names(counts))
  warn_used_sum <- FALSE
  if (length(tot_min_col) == 0) {
    tot_min_col <- min_col
    warn_used_sum <- TRUE
  } else {
    tot_min_col <- tot_min_col[1]
  }

  # ── Compute Day-Level Totals ─────────────────────────────────────────────
  day_group <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(
      mean_count = mean(adj_count, na.rm = TRUE),
      total_minutes = if (warn_used_sum) {
        sum(.data[[min_col]], na.rm = TRUE)
      } else {
        dplyr::first(.data[[tot_min_col]])
      },
      n_counts = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(effort_day = mean_count * total_minutes / 60)

  if (warn_used_sum) {
    cli::cli_warn(c(
      "!" = paste0("Aerial: using sum of ", min_col, " per day×group as total minutes."),
      "i" = "Provide `total_minutes_col` for proper expansion."
    ))
  }

  # ── Design-Based Path (REBUILT) ──────────────────────────────────────────
  if (!is.null(svy)) {
    svy_vars <- svy$variables
    if (!(day_id %in% names(svy_vars))) {
      cli::cli_abort(paste0("`svy` must have `", day_id, "` in its variables."))
    }

    # Align weights
    base_w <- if (inherits(svy, "svyrep.design")) {
      as.numeric(stats::weights(svy, type = "sampling"))
    } else {
      as.numeric(stats::weights(svy))
    }
    idx <- match(day_group[[day_id]], svy_vars[[day_id]])
    if (any(is.na(idx))) {
      cli::cli_abort(paste0("Failed to align day_id on `", day_id, "`."))
    }
    day_group$.w <- base_w[idx]

    # Strata if available
    strata_col <- intersect(c("stratum", "strata", "stratum_id"), names(svy_vars))
    if (length(strata_col) > 0 && !inherits(svy, "svyrep.design")) {
      day_group$.strata <- svy_vars[[strata_col[1]]][idx]
    }

    # Build design
    ids_formula <- stats::as.formula(paste("~", day_id))
    if (inherits(svy, "svyrep.design")) {
      repmat <- svy$repweights
      if (is.null(repmat)) cli::cli_abort("Replicate weights not found.")
      repmat_mat <- as.matrix(repmat)
      repweights_aligned <- repmat_mat[idx, , drop = FALSE]
      type <- attr(repmat, "type") %||% "bootstrap"
      scale <- attr(repmat, "scale") %||% 1
      rscales <- attr(repmat, "rscales") %||% 1
      combined.weights <- attr(repmat, "combined.weights") %||% TRUE
      design_eff <- survey::svrepdesign(
        data = day_group,
        repweights = repweights_aligned,
        weights = ~.w,
        type = type,
        scale = scale,
        rscales = rscales,
        combined.weights = combined.weights
      )
    } else {
      if (".strata" %in% names(day_group)) {
        design_eff <- survey::svydesign(
          ids = ids_formula,
          strata = ~.strata,
          weights = ~.w,
          data = day_group,
          nest = TRUE,
          lonely.psu = "adjust"
        )
      } else {
        design_eff <- survey::svydesign(
          ids = ids_formula,
          weights = ~.w,
          data = day_group,
          nest = TRUE,
          lonely.psu = "adjust"
        )
      }
    }

    # Optional post-stratification
    if (!is.null(post_strata_var) && !is.null(post_strata)) {
      if (!(post_strata_var %in% names(day_group))) {
        cli::cli_abort(paste0("post_strata_var not found: ", post_strata_var))
      }
      if (!all(c(post_strata_var, "Freq") %in% names(post_strata))) {
        cli::cli_abort(paste0("post_strata must have: ", post_strata_var, " and Freq"))
      }
      pf <- stats::as.formula(paste("~", post_strata_var))
      design_eff <- survey::postStratify(design_eff, pf, post_strata)
    }

    # Optional calibration
    if (!is.null(calibrate_formula) && !is.null(calibrate_population)) {
      calfun_fun <- switch(calfun,
        linear = survey::cal.linear,
        raking = survey::cal.raking,
        logit = survey::cal.logit
      )
      design_eff <- survey::calibrate(
        design_eff,
        formula = calibrate_formula,
        population = calibrate_population,
        calfun = calfun_fun
      )
    }

    # ── NEW: Use Core Variance Engine ────────────────────────────────────────
    if (length(by_all) > 0) {
      # Grouped estimation
      variance_result <- tc_compute_variance(
        design = design_eff,
        response = "effort_day",
        method = variance_method,
        by = by_all,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      out <- tibble::tibble(
        !!!setNames(
          lapply(by_all, function(v) design_eff$variables[[v]][seq_along(variance_result$estimate)]),
          by_all
        ),
        estimate = variance_result$estimate,
        se = variance_result$se,
        ci_low = variance_result$ci_lower,
        ci_high = variance_result$ci_upper,
        deff = variance_result$deff,
        n = rep(NA_integer_, length(variance_result$estimate)),
        method = "aerial"
      )

    } else {
      # Overall estimation
      variance_result <- tc_compute_variance(
        design = design_eff,
        response = "effort_day",
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
        n = NA_integer_,
        method = "aerial"
      )
    }

    # ── NEW: Variance Decomposition ───────────────────────────────────────────
    if (decompose_variance) {
      variance_result$decomposition <- tryCatch({
        tc_decompose_variance(
          design = design_eff,
          response = "effort_day",
          cluster_vars = c(day_id),
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
      variance_result$diagnostics <- tryCatch({
        tc_design_diagnostics(design = design_eff, detailed = FALSE)
      }, error = function(e) {
        cli::cli_warn("Design diagnostics failed: {e$message}")
        NULL
      })
    }

    # ── NEW: Add variance_info ────────────────────────────────────────────────
    out$variance_info <- replicate(nrow(out), variance_result, simplify = FALSE)

    return(dplyr::select(
      out,
      dplyr::any_of(by_all),
      estimate, se, ci_low, ci_high, deff, n, method, variance_info
    ))
  }

  # ── Fallback: non-design path ─────────────────────────────────────────────
  out <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by_all))) |>
    dplyr::summarise(
      mean_count = mean(adj_count, na.rm = TRUE),
      sd_count = stats::sd(adj_count, na.rm = TRUE),
      total_minutes = if (warn_used_sum) {
        sum(.data[[min_col]], na.rm = TRUE)
      } else {
        dplyr::first(.data[[tot_min_col]])
      },
      n = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      estimate = mean_count * total_minutes / 60,
      se = ifelse(n > 1, (sd_count / sqrt(n)) * (total_minutes / 60), NA_real_)
    )

  out$ci_low <- NA_real_
  out$ci_high <- NA_real_
  idx <- which(out$n > 1 & !is.na(out$estimate) & !is.na(out$se))
  if (length(idx) > 0) {
    cis <- tc_confint(out$estimate[idx], out$se[idx], level = conf_level)
    out$ci_low[idx] <- cis[seq_along(idx)]
    out$ci_high[idx] <- cis[length(idx) + seq_along(idx)]
  }

  out$deff <- NA_real_
  out$method <- "aerial"
  out$variance_info <- replicate(nrow(out), NULL, simplify = FALSE)

  dplyr::select(
    out,
    dplyr::any_of(by_all),
    estimate, se, ci_low, ci_high, deff, n, method, variance_info
  )
}
