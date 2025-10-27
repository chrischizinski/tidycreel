#' Instantaneous Effort Estimator (REBUILT with Native Survey Integration)
#'
#' Estimate angler-hours from instantaneous (snapshot) counts using mean-count
#' expansion per day × group, then compute design-based totals and variance via
#' the `survey` package with NATIVE support for advanced variance methods.
#'
#' **NEW**: This function now natively supports multiple variance estimation methods,
#' variance decomposition, and design diagnostics without requiring wrapper functions.
#'
#' @param counts Tibble/data.frame of instantaneous counts with columns:
#'   `count`, a minutes column (one of `interval_minutes`, `count_duration`,
#'   or `flight_minutes`), grouping variables (e.g., `date`, `location`), and
#'   optionally `total_day_minutes` or `total_minutes` for day-level expansion.
#' @param by Character vector of grouping variables (e.g., `date`, `location`).
#'   Missing columns are ignored with a warning.
#' @param minutes_col Candidate name(s) for per-count minutes. The first present
#'   is used.
#' @param total_minutes_col Candidate name(s) for day×group total minutes.
#'   If absent, falls back to the sum of per-count minutes within the day×group
#'   (warns).
#' @param day_id Day identifier (PSU), typically `date`, used to join with the
#'   survey design.
#' @param covariates Optional character vector of additional grouping variables
#'   (e.g., `shift_block`, `day_type`).
#' @param svy Optional `svydesign`/`svrepdesign` for day-level sampling design.
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#' @param variance_method **NEW** Variance estimation method:
#'   \describe{
#'     \item{"survey"}{Standard survey package variance (default, backward compatible)}
#'     \item{"svyrecvar"}{survey:::svyrecvar internals for maximum accuracy}
#'     \item{"bootstrap"}{Bootstrap resampling variance}
#'     \item{"jackknife"}{Jackknife resampling variance}
#'     \item{"linearization"}{Taylor linearization (alias for "survey")}
#'   }
#' @param decompose_variance **NEW** Logical, whether to decompose variance into
#'   components (among-day, within-day, etc.). Adds variance decomposition to
#'   the variance_info output. Default FALSE for backward compatibility.
#' @param design_diagnostics **NEW** Logical, whether to compute design quality
#'   diagnostics. Adds diagnostic information to variance_info output.
#'   Default FALSE for backward compatibility.
#' @param n_replicates **NEW** Number of bootstrap/jackknife replicates (default 1000)
#'
#' @details
#' ## Survey-Based Estimation
#'
#' Aggregates per-count observations to day × group totals and uses a
#' day-PSU survey design to compute totals/variance via the `survey` package.
#' When `svy` is not provided, a non-design fallback uses within-group
#' variability to approximate SE/CI; prefer a valid survey design for
#' defensible inference.
#'
#' ## NEW: Advanced Variance Methods
#'
#' This rebuilt function provides NATIVE support for advanced variance estimation:
#'
#' - **Standard** (`variance_method = "survey"`): Uses survey package public API
#' - **Survey Internals** (`variance_method = "svyrecvar"`): Most accurate for complex designs
#' - **Bootstrap** (`variance_method = "bootstrap"`): Resampling-based variance
#' - **Jackknife** (`variance_method = "jackknife"`): Leave-one-out variance
#'
#' These are built-in, not wrapper functions, ensuring optimal performance.
#'
#' ## NEW: Variance Decomposition
#'
#' Set `decompose_variance = TRUE` to decompose total variance into components:
#' - Among-day variance
#' - Within-day variance
#' - Stratum effects (if stratified design)
#'
#' Results are available in the `variance_info` list-column.
#'
#' ## NEW: Design Diagnostics
#'
#' Set `design_diagnostics = TRUE` to assess design quality:
#' - Singleton strata/clusters detection
#' - Weight distribution analysis
#' - Sample size adequacy checks
#' - Design improvement recommendations
#'
#' @return Tibble with grouping columns plus:
#'   \describe{
#'     \item{estimate}{Estimated total effort (angler-hours)}
#'     \item{se}{Standard error}
#'     \item{ci_low, ci_high}{Confidence interval limits}
#'     \item{deff}{Design effect (variance inflation due to design)}
#'     \item{n}{Sample size}
#'     \item{method}{Estimation method ("instantaneous")}
#'     \item{variance_info}{**NEW** List-column with comprehensive variance information:}
#'   }
#'
#'   The `variance_info` list-column contains:
#'   - `variance`: Variance estimate
#'   - `method`: Variance method used
#'   - `method_details`: Method-specific information
#'   - `decomposition`: Variance components (if `decompose_variance = TRUE`)
#'   - `diagnostics`: Design diagnostics (if `design_diagnostics = TRUE`)
#'
#' @seealso [as_day_svydesign()], [tc_compute_variance()], [tc_decompose_variance()],
#'   [tc_design_diagnostics()]
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE: Standard usage (no change from old version)
#' result <- est_effort.instantaneous_rebuilt(counts, svy = design)
#'
#' # NEW: Bootstrap variance
#' result_boot <- est_effort.instantaneous_rebuilt(
#'   counts,
#'   svy = design,
#'   variance_method = "bootstrap",
#'   n_replicates = 2000
#' )
#'
#' # NEW: With variance decomposition
#' result_decomp <- est_effort.instantaneous_rebuilt(
#'   counts,
#'   svy = design,
#'   variance_method = "survey",
#'   decompose_variance = TRUE
#' )
#'
#' # View decomposition
#' result_decomp$variance_info[[1]]$decomposition
#'
#' # NEW: Complete analysis with all features
#' result_full <- est_effort.instantaneous_rebuilt(
#'   counts,
#'   svy = design,
#'   variance_method = "svyrecvar",
#'   decompose_variance = TRUE,
#'   design_diagnostics = TRUE
#' )
#'
#' # View diagnostics
#' result_full$variance_info[[1]]$diagnostics
#' }
#'
#' @export
est_effort.instantaneous <- function(
  counts,
  by = c("date", "location"),
  minutes_col = c(
    "interval_minutes",
    "count_duration",
    "flight_minutes"
  ),
  total_minutes_col = c(
    "total_minutes",
    "total_day_minutes",
    "block_total_minutes"
  ),
  day_id = "date",
  covariates = NULL,
  svy = NULL,
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
) {

  # ── Input Validation (unchanged from original) ────────────────────────────
  tc_require_cols(counts, c("count"), context = "instantaneous effort")
  min_col <- intersect(minutes_col, names(counts))
  if (length(min_col) == 0) cli::cli_abort(c(
    "x" = "Missing per-count minutes column for instantaneous effort.",
    "i" = paste0("Provide one of: ", paste(minutes_col, collapse = ", "))
  ))
  min_col <- min_col[1]

  # Grouping
  by <- tc_group_warn(by, names(counts))
  if (is.null(covariates)) covariates <- character()
  covariates <- tc_group_warn(covariates, names(counts))
  by_all <- unique(c(by, covariates))

  # Determine total minutes column
  tot_min_col <- intersect(total_minutes_col, names(counts))
  warn_used_sum <- FALSE
  if (length(tot_min_col) == 0) {
    tot_min_col <- min_col
    warn_used_sum <- TRUE
  } else {
    tot_min_col <- tot_min_col[1]
  }

  # ── Compute Day-Level Totals (unchanged from original) ────────────────────
  day_group <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(
      mean_count = mean(.data$count, na.rm = TRUE),
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
      "!" = paste0(
        "Instantaneous: using sum of ", min_col,
        " per day×group as total minutes."
      ),
      "i" = "Provide `total_minutes_col` for proper expansion."
    ))
  }

  # ── Design-Based Path (REBUILT with native survey integration) ───────────
  if (!is.null(svy)) {
    svy_vars <- svy$variables
    if (!(day_id %in% names(svy_vars))) {
      cli::cli_abort(paste0("`svy` must include day_id variable: ", day_id))
    }

    # Join weights (unchanged from original)
    day_group$.w <- as.numeric(stats::weights(svy))[match(
      day_group[[day_id]], svy_vars[[day_id]]
    )]
    if (any(is.na(day_group$.w))) {
      cli::cli_abort(paste0("Failed to align survey weights on ", day_id))
    }

    # Build effort design (unchanged from original)
    ids_formula <- stats::as.formula(paste("~", day_id))
    if (inherits(svy, "svyrep.design")) {
      repmat <- survey::repweights(svy)
      rep_df <- tibble::as_tibble(repmat)
      rep_df[[day_id]] <- svy_vars[[day_id]]
      day_group <- dplyr::left_join(day_group, rep_df, by = day_id)
      repcols <- colnames(repmat)
      design_eff <- survey::svrepdesign(
        data = day_group,
        repweights = as.matrix(day_group[, repcols]),
        weights = ~.w,
        type = attr(repmat, "type") %||% "bootstrap",
        scale = attr(repmat, "scale") %||% 1,
        rscales = attr(repmat, "rscales") %||% 1,
        combined.weights = attr(repmat, "combined.weights") %||% TRUE
      )
    } else {
      design_eff <- survey::svydesign(ids = ids_formula, weights = ~.w, data = day_group)
    }

    # ── NEW: Use Core Variance Engine ────────────────────────────────────────
    # This is the key change: use tc_compute_variance instead of direct survey calls
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

      # Build output tibble
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
        method = "instantaneous"
      )

    } else {
      # Overall estimation (no grouping)
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
        method = "instantaneous"
      )
    }

    # ── NEW: Variance Decomposition if requested ─────────────────────────────
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

    # ── NEW: Design Diagnostics if requested ─────────────────────────────────
    if (design_diagnostics) {
      variance_result$diagnostics <- tryCatch({
        tc_design_diagnostics(design = design_eff, detailed = FALSE)
      }, error = function(e) {
        cli::cli_warn("Design diagnostics failed: {e$message}")
        NULL
      })
    }

    # ── NEW: Add variance_info list-column ───────────────────────────────────
    # This is the enriched output structure
    out$variance_info <- replicate(nrow(out), list(variance_result), simplify = FALSE)

    # Return with consistent column order
    return(dplyr::select(
      out,
      dplyr::any_of(by_all),
      estimate, se, ci_low, ci_high, deff, n, method, variance_info
    ))
  }

  # ── Fallback: non-design path (unchanged from original) ──────────────────
  out <- counts |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by_all))) |>
    dplyr::summarise(
      mean_count = mean(.data$count, na.rm = TRUE),
      sd_count = stats::sd(.data$count, na.rm = TRUE),
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
      se = dplyr::if_else(n > 1, (sd_count / sqrt(n)) * (total_minutes / 60), NA_real_)
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
  out$method <- "instantaneous"
  out$variance_info <- replicate(nrow(out), list(NULL), simplify = FALSE)

  dplyr::select(
    out,
    dplyr::any_of(by_all),
    estimate, se, ci_low, ci_high, deff, n, method, variance_info
  )
}
