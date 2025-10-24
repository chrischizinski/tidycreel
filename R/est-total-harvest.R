#' Estimate Total Harvest/Catch Using Product Estimator
#'
#' Estimates total harvest, catch, or releases by multiplying effort and CPUE
#' estimates with proper variance propagation using the delta method.
#'
#' @param effort_est Tibble from `est_effort()` with effort estimates
#' @param cpue_est Tibble from `est_cpue()` or `aggregate_cpue()` with CPUE estimates
#' @param by Character vector of grouping variables (must match between inputs).
#'   If `NULL`, assumes both inputs represent the same population (e.g., all species).
#' @param response Type of catch: `"catch_total"`, `"catch_kept"`, or `"catch_released"`.
#'   Must match the response type used in CPUE estimation.
#' @param method Estimation method: `"product"` (default) or `"separate_ratio"`.
#'   Product estimator is recommended for most cases.
#' @param correlation Correlation between effort and CPUE estimates:
#'   - `NULL` (default): Assumes independent (conservative, appropriate when
#'     effort and CPUE from different data sources)
#'   - Numeric value between -1 and 1: Use specified correlation
#'   - `"auto"`: Attempt to estimate from data (not yet implemented)
#' @param conf_level Confidence level for Wald confidence intervals (default 0.95)
#' @param diagnostics Include diagnostic information in output (default `TRUE`)
#'
#' @return Tibble with standard tidycreel schema:
#'   - Grouping columns (from `by` parameter)
#'   - `estimate`: Total harvest/catch/release estimate
#'   - `se`: Standard error
#'   - `ci_low`, `ci_high`: Confidence interval bounds
#'   - `n`: Sample size (minimum of effort and CPUE sample sizes)
#'   - `method`: Method used for estimation
#'   - `diagnostics`: List-column with diagnostic information
#'
#' @details
#' ## Statistical Method
#'
#' Combines effort (E) and catch-per-unit-effort (C) estimates:
#'
#' \deqn{H = E \times C}
#'
#' where:
#' - H = Total harvest/catch
#' - E = Total effort (angler-hours)
#' - C = CPUE (catch per angler-hour)
#'
#' ## Variance Propagation (Delta Method)
#'
#' When effort and CPUE are **independent** (default):
#' \deqn{Var(H) = E^2 \times Var(C) + C^2 \times Var(E)}
#'
#' When effort and CPUE are **correlated**:
#' \deqn{Var(H) = E^2 \times Var(C) + C^2 \times Var(E) + 2 \times E \times C \times Cov(E,C)}
#'
#' where \eqn{Cov(E,C) = \rho \times SE(E) \times SE(C)} and \eqn{\rho} is the
#' correlation coefficient.
#'
#' ## When to Use Correlation
#'
#' **Use correlation = 0 (NULL, default) when:**
#' - Effort estimated from count data (access point, bus route)
#' - CPUE estimated from separate interview data
#' - Different survey designs or time periods
#'
#' **Use non-zero correlation when:**
#' - Both estimates come from the same interview survey
#' - Roving surveys where effort and CPUE use same data source
#' - You have prior knowledge of correlation structure
#'
#' ## Species Aggregation
#'
#' For species group estimates (e.g., black bass, panfish), use `aggregate_cpue()`
#' BEFORE calling this function to ensure proper variance estimation:
#'
#' ```r
#' # CORRECT approach
#' cpue_black_bass <- aggregate_cpue(
#'   interviews, svy_int,
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass"
#' )
#' harvest_black_bass <- est_total_harvest(effort_est, cpue_black_bass)
#'
#' # WRONG approach (ignores covariance)
#' harvest_lmb <- est_total_harvest(effort_est, cpue_largemouth)
#' harvest_smb <- est_total_harvest(effort_est, cpue_smallmouth)
#' harvest_wrong <- harvest_lmb$estimate + harvest_smb$estimate  # Bad!
#' ```
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#' library(survey)
#'
#' # Complete workflow
#' # 1. Estimate effort from count data
#' svy_day <- as_day_svydesign(
#'   calendar,
#'   day_id = "date",
#'   strata_vars = "day_type"
#' )
#' effort_est <- est_effort(
#'   svy_day, counts,
#'   method = "instantaneous",
#'   by = "location"
#' )
#'
#' # 2. Estimate CPUE from interview data
#' svy_int <- svydesign(ids = ~1, weights = ~1, data = interviews)
#' cpue_est <- est_cpue(
#'   svy_int,
#'   by = c("location", "species"),
#'   response = "catch_kept"
#' )
#'
#' # 3. Calculate total harvest
#' harvest_total <- est_total_harvest(
#'   effort_est,
#'   cpue_est,
#'   by = c("location", "species"),
#'   response = "catch_kept"
#' )
#'
#' # Species group aggregation
#' cpue_black_bass <- aggregate_cpue(
#'   interviews, svy_int,
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass",
#'   response = "catch_kept"
#' )
#' harvest_black_bass <- est_total_harvest(effort_est, cpue_black_bass)
#'
#' # Multiple response types
#' catch_total <- est_total_harvest(effort_est, cpue_total,
#'                                  response = "catch_total")
#' releases <- est_total_harvest(effort_est, cpue_released,
#'                               response = "catch_released")
#'
#' # Verify relationship: total ≈ kept + released
#' all.equal(
#'   catch_total$estimate,
#'   harvest_total$estimate + releases$estimate
#' )
#' }
#'
#' @references
#' Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods
#'   and Their Applications in Fisheries Management. American Fisheries
#'   Society Special Publication 25.
#'
#' Seber, G.A.F. 1982. The Estimation of Animal Abundance and Related Parameters.
#'   2nd edition. Charles Griffin, London.
#'
#' @seealso
#' [est_effort()], [est_cpue()], [aggregate_cpue()], [est_catch()]
#'
#' @export
#' @importFrom stats qnorm
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
  # Validate inputs
  response <- match.arg(response)
  method <- match.arg(method)

  # Currently only product method is implemented
  if (method != "product") {
    cli::cli_abort(c(
      "x" = "{.arg method} = {.val {method}} is not yet implemented.",
      "i" = "Currently only {.val product} estimator is supported.",
      ">" = "Use {.code method = 'product'} (the default)."
    ))
  }

  # Validate that inputs are data frames/tibbles
  if (!is.data.frame(effort_est)) {
    cli::cli_abort(c(
      "x" = "{.arg effort_est} must be a data frame or tibble.",
      "i" = "Received: {.cls {class(effort_est)}}"
    ))
  }

  if (!is.data.frame(cpue_est)) {
    cli::cli_abort(c(
      "x" = "{.arg cpue_est} must be a data frame or tibble.",
      "i" = "Received: {.cls {class(cpue_est)}}"
    ))
  }

  # Check for required columns in both inputs
  required_cols <- c("estimate", "se")
  tc_abort_missing_cols(effort_est, required_cols, context = "effort_est")
  tc_abort_missing_cols(cpue_est, required_cols, context = "cpue_est")

  # Check that grouping variables exist in both datasets
  if (!is.null(by)) {
    # Verify all grouping columns present in both datasets
    missing_effort <- setdiff(by, names(effort_est))
    missing_cpue <- setdiff(by, names(cpue_est))

    if (length(missing_effort) > 0) {
      cli::cli_abort(c(
        "x" = "Grouping variables not found in {.arg effort_est}.",
        "i" = "Missing: {.val {missing_effort}}",
        ">" = "Check that {.arg by} variables match between inputs."
      ))
    }

    if (length(missing_cpue) > 0) {
      cli::cli_abort(c(
        "x" = "Grouping variables not found in {.arg cpue_est}.",
        "i" = "Missing: {.val {missing_cpue}}",
        ">" = "Check that {.arg by} variables match between inputs."
      ))
    }
  }

  # Validate correlation parameter
  if (!is.null(correlation)) {
    if (is.character(correlation)) {
      if (correlation == "auto") {
        cli::cli_abort(c(
          "x" = "{.code correlation = 'auto'} is not yet implemented.",
          "i" = "Use {.code correlation = NULL} (independent, default) or",
          "i" = "Provide a numeric correlation value between -1 and 1."
        ))
      } else {
        cli::cli_abort(c(
          "x" = "Invalid {.arg correlation} value: {.val {correlation}}",
          "i" = "Must be {.code NULL}, {.code 'auto'}, or numeric."
        ))
      }
    } else if (is.numeric(correlation)) {
      if (correlation < -1 || correlation > 1) {
        cli::cli_abort(c(
          "x" = "Correlation must be between -1 and 1.",
          "i" = "Received: {.val {correlation}}"
        ))
      }
    } else {
      cli::cli_abort(c(
        "x" = "Invalid {.arg correlation} type: {.cls {class(correlation)}}",
        "i" = "Must be {.code NULL}, {.code 'auto'}, or numeric."
      ))
    }
  }

  # Join effort and CPUE estimates
  if (!is.null(by)) {
    # Identify additional grouping columns in cpue_est (e.g., species)
    # These will be preserved in the output
    cpue_extra_cols <- setdiff(names(cpue_est), c(by, "estimate", "se", "n", "method", "ci_low", "ci_high", "diagnostics"))
    cpue_cols_to_keep <- c(by, cpue_extra_cols, "estimate", "se", "n")

    # Join by specified grouping variables
    joined <- dplyr::inner_join(
      effort_est |> dplyr::select(dplyr::all_of(c(by, "estimate", "se", "n"))),
      cpue_est |> dplyr::select(dplyr::all_of(cpue_cols_to_keep)),
      by = by,
      suffix = c("_effort", "_cpue")
    )

    # Check that join produced results
    if (nrow(joined) == 0) {
      cli::cli_abort(c(
        "x" = "No matching groups between {.arg effort_est} and {.arg cpue_est}.",
        "i" = "Check that grouping variables {.val {by}} have matching values.",
        ">" = "effort_est groups: {.val {unique(effort_est[[by[1]]])}}",
        ">" = "cpue_est groups: {.val {unique(cpue_est[[by[1]]])}}"
      ))
    }

    # Warn if not all groups matched
    n_effort_groups <- nrow(effort_est)
    n_cpue_groups <- nrow(cpue_est)
    n_joined_groups <- nrow(joined)

    if (n_joined_groups < n_effort_groups || n_joined_groups < n_cpue_groups) {
      cli::cli_warn(c(
        "!" = "Not all groups matched between effort and CPUE estimates.",
        "i" = "effort_est: {.val {n_effort_groups}} groups",
        "i" = "cpue_est: {.val {n_cpue_groups}} groups",
        "i" = "Matched: {.val {n_joined_groups}} groups",
        ">" = "Only matched groups will be included in results."
      ))
    }
  } else {
    # No grouping - should be single row each
    if (nrow(effort_est) != 1 || nrow(cpue_est) != 1) {
      cli::cli_abort(c(
        "x" = "When {.arg by = NULL}, both inputs must have exactly 1 row.",
        "i" = "effort_est: {.val {nrow(effort_est)}} rows",
        "i" = "cpue_est: {.val {nrow(cpue_est)}} rows",
        ">" = "Either specify {.arg by} or ensure single-row inputs."
      ))
    }

    joined <- tibble::tibble(
      estimate_effort = effort_est$estimate,
      se_effort = effort_est$se,
      n_effort = effort_est$n %||% NA_integer_,
      estimate_cpue = cpue_est$estimate,
      se_cpue = cpue_est$se,
      n_cpue = cpue_est$n %||% NA_integer_
    )
  }

  # Extract effort and CPUE values
  E <- joined$estimate_effort
  SE_E <- joined$se_effort
  C <- joined$estimate_cpue
  SE_C <- joined$se_cpue

  # Calculate total harvest using product estimator: H = E × C
  H <- E * C

  # Calculate variance using delta method
  Var_E <- SE_E^2
  Var_C <- SE_C^2

  if (is.null(correlation) || correlation == 0) {
    # Independent estimates (default)
    Var_H <- E^2 * Var_C + C^2 * Var_E
    cor_used <- 0
  } else {
    # Correlated estimates
    # Cov(E, C) = rho * SE(E) * SE(C)
    Cov_EC <- correlation * SE_E * SE_C
    Var_H <- E^2 * Var_C + C^2 * Var_E + 2 * E * C * Cov_EC
    cor_used <- correlation
  }

  SE_H <- sqrt(Var_H)

  # Calculate confidence intervals (Wald)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  ci_low <- H - z * SE_H
  ci_high <- H + z * SE_H

  # Sample size (use minimum of effort and CPUE sample sizes)
  n <- pmin(joined$n_effort, joined$n_cpue, na.rm = TRUE)

  # Build output tibble
  if (!is.null(by)) {
    # Preserve all grouping columns including extra ones from cpue_est
    grouping_cols <- intersect(names(joined), c(by, cpue_extra_cols))
    out <- joined |>
      dplyr::select(dplyr::all_of(grouping_cols)) |>
      dplyr::mutate(
        estimate = H,
        se = SE_H,
        ci_low = ci_low,
        ci_high = ci_high,
        n = n
      )
  } else {
    out <- tibble::tibble(
      estimate = H,
      se = SE_H,
      ci_low = ci_low,
      ci_high = ci_high,
      n = n
    )
  }

  # Add method column
  out$method <- paste0("product:", response, ":", ifelse(cor_used == 0, "independent", "correlated"))

  # Add diagnostics if requested
  if (diagnostics) {
    # Create diagnostics for each row
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
    "n",
    "method",
    "diagnostics"
  )

  # Filter to only columns that actually exist in out
  result_cols <- intersect(result_cols, names(out))

  dplyr::select(out, dplyr::all_of(result_cols))
}
