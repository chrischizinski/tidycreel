#' Estimate Total Harvest/Catch Using Product Estimator (REBUILT)
#'
#' Estimates total harvest, catch, or releases by multiplying effort and CPUE
#' estimates with proper variance propagation using the delta method.
#'
#' **REBUILT**: Enhanced output structure with design effects and comprehensive
#' variance information, matching the native survey integration architecture.
#'
#' @param effort_est Tibble from `est_effort()` with effort estimates
#' @param cpue_est Tibble from `est_cpue()` or `aggregate_cpue()` with CPUE estimates
#' @param by Character vector of grouping variables (must match between inputs).
#' @param response Type of catch: `"catch_total"`, `"catch_kept"`, or `"catch_released"`.
#' @param method Estimation method: `"product"` (default) or `"separate_ratio"`.
#' @param correlation Correlation between effort and CPUE estimates (default `NULL`):
#'   - `NULL`: Independent (conservative)
#'   - Numeric (-1 to 1): Specified correlation
#'   - `"auto"`: Estimate from data (not implemented)
#' @param conf_level Confidence level for Wald CIs (default 0.95)
#' @param diagnostics Include diagnostic information (default `TRUE`)
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `deff` (design effect propagated from inputs), `n`, `method`, `diagnostics`
#'   list-column, and `variance_info` list-column.
#'
#' @details
#' ## Statistical Method
#'
#' Combines effort (E) and CPUE (C): H = E × C
#'
#' ## Variance Propagation (Delta Method)
#'
#' Independent (default): Var(H) = E² × Var(C) + C² × Var(E)
#' Correlated: Var(H) = E² × Var(C) + C² × Var(E) + 2 × E × C × Cov(E,C)
#'
#' ## Species Aggregation
#'
#' Use `aggregate_cpue()` BEFORE this function for proper variance:
#'
#' ```r
#' # CORRECT
#' cpue_black_bass <- aggregate_cpue(interviews, svy_int,
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass")
#' harvest <- est_total_harvest(effort_est, cpue_black_bass)
#'
#' # WRONG (ignores covariance)
#' harvest <- sum(est_total_harvest(effort, cpue_lmb)$estimate,
#'                est_total_harvest(effort, cpue_smb)$estimate)
#' ```
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE
#' harvest <- est_total_harvest(effort_est, cpue_est)
#'
#' # NEW: Enhanced output with deff and variance_info
#' harvest <- est_total_harvest(effort_est, cpue_est)
#' harvest$deff  # Design effect propagated from inputs
#' harvest$variance_info[[1]]  # Delta method details
#' }
#'
#' @references
#' Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods.
#' American Fisheries Society Special Publication 25.
#'
#' @seealso [est_effort()], [est_cpue()], [aggregate_cpue()]
#'
#' @export
est_total_harvest <- function(
  effort_est,
  cpue_est,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  method = c("product", "separate_ratio"),
  correlation = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
) {

  # ── Input Validation (unchanged) ──────────────────────────────────────────
  response <- match.arg(response)
  method <- match.arg(method)

  if (method != "product") {
    cli::cli_abort(c(
      "x" = "{.arg method} = {.val {method}} is not yet implemented.",
      "i" = "Currently only {.val product} estimator is supported."
    ))
  }

  # Validate inputs are data frames
  if (!is.data.frame(effort_est)) {
    cli::cli_abort("{.arg effort_est} must be a data frame or tibble.")
  }
  if (!is.data.frame(cpue_est)) {
    cli::cli_abort("{.arg cpue_est} must be a data frame or tibble.")
  }

  # Check required columns
  required_cols <- c("estimate", "se")
  tc_abort_missing_cols(effort_est, required_cols, context = "effort_est")
  tc_abort_missing_cols(cpue_est, required_cols, context = "cpue_est")

  # Check grouping variables
  if (!is.null(by)) {
    missing_effort <- setdiff(by, names(effort_est))
    missing_cpue <- setdiff(by, names(cpue_est))

    if (length(missing_effort) > 0) {
      cli::cli_abort(c(
        "x" = "Grouping variables not found in {.arg effort_est}.",
        "i" = "Missing: {.val {missing_effort}}"
      ))
    }
    if (length(missing_cpue) > 0) {
      cli::cli_abort(c(
        "x" = "Grouping variables not found in {.arg cpue_est}.",
        "i" = "Missing: {.val {missing_cpue}}"
      ))
    }
  }

  # Validate correlation
  if (!is.null(correlation)) {
    if (is.character(correlation)) {
      if (correlation == "auto") {
        cli::cli_abort(c(
          "x" = "{.code correlation = 'auto'} not yet implemented.",
          "i" = "Use {.code NULL} (independent) or numeric value."
        ))
      } else {
        cli::cli_abort("Invalid {.arg correlation} value.")
      }
    } else if (is.numeric(correlation)) {
      if (correlation < -1 || correlation > 1) {
        cli::cli_abort("Correlation must be between -1 and 1.")
      }
    } else {
      cli::cli_abort("Invalid {.arg correlation} type.")
    }
  }

  # ── Join Effort and CPUE (unchanged) ──────────────────────────────────────
  if (!is.null(by)) {
    cpue_extra_cols <- setdiff(
      names(cpue_est),
      c(by, "estimate", "se", "n", "method", "ci_low", "ci_high", "diagnostics", "deff", "variance_info")
    )
    cpue_cols_to_keep <- c(by, cpue_extra_cols, "estimate", "se", "n")

    # Also get deff if present
    if ("deff" %in% names(cpue_est)) {
      cpue_cols_to_keep <- c(cpue_cols_to_keep, "deff")
    }

    effort_cols_to_keep <- c(by, "estimate", "se", "n")
    if ("deff" %in% names(effort_est)) {
      effort_cols_to_keep <- c(effort_cols_to_keep, "deff")
    }

    joined <- dplyr::inner_join(
      effort_est |> dplyr::select(dplyr::all_of(effort_cols_to_keep)),
      cpue_est |> dplyr::select(dplyr::all_of(cpue_cols_to_keep)),
      by = by,
      suffix = c("_effort", "_cpue")
    )

    if (nrow(joined) == 0) {
      cli::cli_abort(c(
        "x" = "No matching groups between effort and CPUE.",
        "i" = "Check grouping variables have matching values."
      ))
    }

    # Warn if not all groups matched
    if (nrow(joined) < nrow(effort_est) || nrow(joined) < nrow(cpue_est)) {
      cli::cli_warn(c(
        "!" = "Not all groups matched.",
        "i" = "effort: {nrow(effort_est)}, cpue: {nrow(cpue_est)}, matched: {nrow(joined)}"
      ))
    }
  } else {
    if (nrow(effort_est) != 1 || nrow(cpue_est) != 1) {
      cli::cli_abort(c(
        "x" = "When {.arg by = NULL}, both inputs must have exactly 1 row."
      ))
    }

    joined <- tibble::tibble(
      estimate_effort = effort_est$estimate,
      se_effort = effort_est$se,
      n_effort = effort_est$n %||% NA_integer_,
      deff_effort = if ("deff" %in% names(effort_est)) effort_est$deff else NA_real_,
      estimate_cpue = cpue_est$estimate,
      se_cpue = cpue_est$se,
      n_cpue = cpue_est$n %||% NA_integer_,
      deff_cpue = if ("deff" %in% names(cpue_est)) cpue_est$deff else NA_real_
    )
  }

  # ── Product Estimator: H = E × C (unchanged) ──────────────────────────────
  E <- joined$estimate_effort
  SE_E <- joined$se_effort
  C <- joined$estimate_cpue
  SE_C <- joined$se_cpue

  H <- E * C

  # ── Delta Method Variance (unchanged) ─────────────────────────────────────
  Var_E <- SE_E^2
  Var_C <- SE_C^2

  if (is.null(correlation) || correlation == 0) {
    Var_H <- E^2 * Var_C + C^2 * Var_E
    cor_used <- 0
  } else {
    Cov_EC <- correlation * SE_E * SE_C
    Var_H <- E^2 * Var_C + C^2 * Var_E + 2 * E * C * Cov_EC
    cor_used <- correlation
  }

  SE_H <- sqrt(Var_H)

  # Confidence intervals
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  ci_low <- H - z * SE_H
  ci_high <- H + z * SE_H

  # Sample size
  n <- pmin(joined$n_effort, joined$n_cpue, na.rm = TRUE)

  # ── NEW: Propagate design effects ─────────────────────────────────────────
  # Extract deff from inputs if available
  deff_effort <- if ("deff_effort" %in% names(joined)) {
    joined$deff_effort
  } else {
    rep(NA_real_, nrow(joined))
  }

  deff_cpue <- if ("deff_cpue" %in% names(joined)) {
    joined$deff_cpue
  } else {
    rep(NA_real_, nrow(joined))
  }

  # Combined deff: geometric mean of input deffs (if both available)
  deff_combined <- ifelse(
    !is.na(deff_effort) & !is.na(deff_cpue),
    sqrt(deff_effort * deff_cpue),
    ifelse(!is.na(deff_effort), deff_effort,
           ifelse(!is.na(deff_cpue), deff_cpue, NA_real_))
  )

  # ── Build Output (REBUILT) ────────────────────────────────────────────────
  if (!is.null(by)) {
    grouping_cols <- intersect(names(joined), c(by, cpue_extra_cols))
    out <- joined |>
      dplyr::select(dplyr::all_of(grouping_cols)) |>
      dplyr::mutate(
        estimate = H,
        se = SE_H,
        ci_low = ci_low,
        ci_high = ci_high,
        deff = deff_combined,
        n = n
      )
  } else {
    out <- tibble::tibble(
      estimate = H,
      se = SE_H,
      ci_low = ci_low,
      ci_high = ci_high,
      deff = deff_combined,
      n = n
    )
  }

  # Method
  out$method <- paste0("product:", response, ":", ifelse(cor_used == 0, "independent", "correlated"))

  # ── Diagnostics (unchanged) ───────────────────────────────────────────────
  if (diagnostics) {
    out$diagnostics <- vector("list", nrow(out))
    for (i in seq_len(nrow(out))) {
      diag_info <- list(
        effort_estimate = E[i],
        cpue_estimate = C[i],
        correlation_used = cor_used,
        variance_components = list(
          var_effort = Var_E[i],
          var_cpue = Var_C[i],
          var_total = Var_H[i]
        )
      )
      if (cor_used != 0) {
        diag_info$covariance_EC <- correlation * SE_E[i] * SE_C[i]
      }
      out$diagnostics[[i]] <- diag_info
    }
  } else {
    out$diagnostics <- vector("list", nrow(out))
  }

  # ── NEW: Add variance_info ────────────────────────────────────────────────
  # For product estimator, variance_info contains delta method details
  out$variance_info <- vector("list", nrow(out))
  for (i in seq_len(nrow(out))) {
    out$variance_info[[i]] <- list(
      method = "delta_method",
      product_type = "effort_times_cpue",
      effort = E[i],
      cpue = C[i],
      se_effort = SE_E[i],
      se_cpue = SE_C[i],
      correlation = cor_used,
      variance_formula = ifelse(
        cor_used == 0,
        "Var(H) = E² × Var(C) + C² × Var(E)",
        "Var(H) = E² × Var(C) + C² × Var(E) + 2 × E × C × Cov(E,C)"
      ),
      deff_effort = deff_effort[i],
      deff_cpue = deff_cpue[i],
      deff_combined = deff_combined[i]
    )
  }

  # Return with consistent column order
  result_cols <- c(
    if (!is.null(by)) {
      c(by, if (exists("cpue_extra_cols")) cpue_extra_cols else character(0))
    } else {
      character(0)
    },
    "estimate",
    "se",
    "ci_low",
    "ci_high",
    "deff",
    "n",
    "method",
    "diagnostics",
    "variance_info"
  )

  result_cols <- intersect(result_cols, names(out))
  dplyr::select(out, dplyr::all_of(result_cols))
}
