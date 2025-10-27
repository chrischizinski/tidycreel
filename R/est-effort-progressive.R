#' Progressive (Roving) Effort Estimator (REBUILT with Native Survey Integration)
#'
#' Estimate angler-hours from progressive (roving) counts by summing pass-level
#' counts × route_minutes per day × group, then compute design-based totals and
#' variance via the `survey` package with NATIVE support for advanced variance methods.
#'
#' **NEW**: Native support for multiple variance methods, variance decomposition,
#' and design diagnostics without requiring wrapper functions.
#'
#' @param counts Tibble/data.frame of progressive counts with columns: `count`,
#'   `route_minutes` (or candidate), grouping variables (e.g., `date`, `location`),
#'   and optional `pass_id`/`circuit_id`.
#' @param by Character vector of grouping variables (e.g., `date`, `location`).
#'   Missing columns are ignored with a warning.
#' @param route_minutes_col Name(s) of the per-pass route minutes column; the
#'   first present is used.
#' @param pass_id Optional column name identifying passes. If absent, rows are
#'   treated as pass records and summed within day × group.
#' @param day_id Day identifier (PSU), typically `date`, used to join with the
#'   survey design.
#' @param covariates Optional character vector of additional grouping variables.
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
#'   components. Adds variance decomposition to variance_info output. Default FALSE.
#' @param design_diagnostics **NEW** Logical, whether to compute design quality
#'   diagnostics. Adds diagnostic information to variance_info output. Default FALSE.
#' @param n_replicates **NEW** Number of bootstrap/jackknife replicates (default 1000)
#'
#' @return Tibble with grouping columns plus:
#'   \describe{
#'     \item{estimate}{Estimated total effort (angler-hours)}
#'     \item{se}{Standard error}
#'     \item{ci_low, ci_high}{Confidence interval limits}
#'     \item{deff}{Design effect}
#'     \item{n}{Sample size}
#'     \item{method}{Estimation method ("progressive")}
#'     \item{variance_info}{**NEW** List-column with comprehensive variance information}
#'   }
#'
#' @details
#' Sums pass-level contributions to day × group totals and uses the day-PSU
#' survey design to compute totals and variance via the `survey` package.
#'
#' ## NEW: Advanced Variance Methods
#' This rebuilt function provides NATIVE support for advanced variance estimation.
#' See `tc_compute_variance()` for details on variance methods.
#'
#' ## NEW: Variance Decomposition
#' Set `decompose_variance = TRUE` to decompose total variance into components.
#' Results available in the `variance_info` list-column.
#'
#' ## NEW: Design Diagnostics
#' Set `design_diagnostics = TRUE` to assess design quality with recommendations.
#'
#' @seealso [as_day_svydesign()], [tc_compute_variance()], [tc_decompose_variance()],
#'   [tc_design_diagnostics()]
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE: Standard usage
#' result <- est_effort.progressive_rebuilt(counts, svy = design)
#'
#' # NEW: Bootstrap variance
#' result_boot <- est_effort.progressive_rebuilt(
#'   counts,
#'   svy = design,
#'   variance_method = "bootstrap"
#' )
#'
#' # NEW: Complete analysis
#' result_full <- est_effort.progressive_rebuilt(
#'   counts,
#'   svy = design,
#'   variance_method = "svyrecvar",
#'   decompose_variance = TRUE,
#'   design_diagnostics = TRUE
#' )
#' }
#'
#' @export
est_effort.progressive <- function(
  counts,
  by = c("date", "location"),
  route_minutes_col = c("route_minutes", "circuit_minutes"),
  pass_id = c("pass_id", "circuit_id"),
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
  tc_require_cols(counts, c("count"), context = "progressive effort")
  rm_col <- intersect(route_minutes_col, names(counts))
  if (length(rm_col) == 0) cli::cli_abort(c(
    "x" = "Missing route minutes column for progressive effort.",
    "i" = paste0("Provide one of: ", paste(route_minutes_col, collapse = ", "))
  ))
  rm_col <- rm_col[1]

  # Grouping
  by <- tc_group_warn(by, names(counts))
  if (is.null(covariates)) covariates <- character()
  covariates <- tc_group_warn(covariates, names(counts))
  by_all <- unique(c(by, covariates))

  # Define pass groupers
  pass_col <- intersect(pass_id, names(counts))
  if (length(pass_col) > 0) pass_col <- pass_col[1] else pass_col <- NULL

  # ── Compute Pass and Day Totals (unchanged from original) ─────────────────
  if (!is.null(pass_col)) {
    pass_totals <- counts |>
      dplyr::group_by(
        dplyr::across(dplyr::all_of(c(day_id, by_all, pass_col)))
      ) |>
      dplyr::summarise(
        pass_effort = sum(.data$count * .data[[rm_col]], na.rm = TRUE) / 60,
        .groups = "drop"
      )
  } else {
    pass_totals <- counts |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
      dplyr::summarise(
        pass_effort = sum(.data$count * .data[[rm_col]], na.rm = TRUE) / 60,
        .groups = "drop"
      )
  }

  day_group <- pass_totals |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(
      effort_day = sum(pass_effort, na.rm = TRUE),
      n_passes = dplyr::n(),
      .groups = "drop"
    )

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
        method = "progressive"
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
        method = "progressive"
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
    out$variance_info <- replicate(nrow(out), list(variance_result), simplify = FALSE)

    # Return with consistent column order
    return(dplyr::select(
      out,
      dplyr::any_of(by_all),
      estimate, se, ci_low, ci_high, deff, n, method, variance_info
    ))
  }

  # ── Fallback: non-design path (unchanged from original) ──────────────────
  out <- day_group |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by_all))) |>
    dplyr::summarise(
      estimate = sum(effort_day, na.rm = TRUE),
      n = sum(n_passes),
      .groups = "drop"
    )

  out$se <- NA_real_
  out$ci_low <- NA_real_
  out$ci_high <- NA_real_
  out$deff <- NA_real_
  out$method <- "progressive"
  out$variance_info <- replicate(nrow(out), list(NULL), simplify = FALSE)

  dplyr::select(
    out,
    dplyr::any_of(by_all),
    estimate, se, ci_low, ci_high, deff, n, method, variance_info
  )
}
