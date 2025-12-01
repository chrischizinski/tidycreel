#' Aggregate CPUE Across Species (REBUILT with Native Survey Integration)
#'
#' Combines CPUE estimates for multiple species into a single aggregate,
#' properly accounting for survey design and covariance between species with
#' NATIVE support for advanced variance methods.
#'
#' **NEW**: Native support for multiple variance methods, variance decomposition,
#' and design diagnostics without requiring wrapper functions.
#'
#' @param cpue_data Interview data (raw, before estimation) containing catch by species
#' @param svy_design Survey design object (`svydesign` or `svrepdesign`) built on `cpue_data`
#' @param species_col Column name containing species identifier
#' @param species_values Character vector of species to aggregate
#' @param group_name Name for the aggregated group (e.g., "black_bass", "panfish")
#' @param by Additional grouping variables (e.g., `c("location", "date")`)
#' @param response Type of catch: `"catch_total"`, `"catch_kept"`, or `"catch_released"`
#' @param effort_col Effort column for denominator (default `"hours_fished"`)
#' @param mode Estimation mode: `"auto"`, `"ratio_of_means"`, or `"mean_of_ratios"`.
#'   Defaults to `"ratio_of_means"` for robustness.
#' @param conf_level Confidence level for Wald CIs (default 0.95)
#' @param variance_method **NEW** Variance estimation method (default "survey")
#' @param decompose_variance **NEW** Logical, decompose variance (default FALSE)
#' @param design_diagnostics **NEW** Logical, compute diagnostics (default FALSE)
#' @param n_replicates **NEW** Bootstrap/jackknife replicates (default 1000)
#'
#' @return Tibble with grouping columns (including `species_group`), `estimate`,
#'   `se`, `ci_low`, `ci_high`, `deff` (design effect), `n`, `method`,
#'   `diagnostics` list-column, and `variance_info` list-column.
#'
#' @details
#' **Statistical Approach:**
#'
#' This function performs survey-design-based aggregation, which is CRITICAL for
#' proper variance estimation. It works by:
#'
#' 1. Creating an aggregated catch variable by summing catch across specified species
#' 2. Updating the survey design with this aggregated variable
#' 3. Estimating CPUE for the aggregate using standard survey methods
#' 4. Properly accounting for covariance between species
#'
#' **Why This Matters:**
#'
#' Simply adding species-specific harvest estimates ignores covariance between species.
#' This function ensures proper variance by aggregating at the CPUE level.
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE
#' cpue_black_bass <- aggregate_cpue(
#'   interviews, svy_int,
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass"
#' )
#'
#' # NEW: Advanced features
#' cpue_black_bass <- aggregate_cpue(
#'   interviews, svy_int,
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass",
#'   variance_method = "bootstrap",
#'   decompose_variance = TRUE,
#'   design_diagnostics = TRUE
#' )
#' }
#'
#' @seealso [est_cpue()], [est_total_harvest()]
#'
#' @export
aggregate_cpue <- function(
  cpue_data,
  svy_design,
  species_col = "species",
  species_values,
  group_name,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  effort_col = "hours_fished",
  mode = "ratio_of_means",
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
) {

  # ── Input Validation (unchanged) ──────────────────────────────────────────
  response <- match.arg(response)

  # Check that svy_design is a survey object
  if (!inherits(svy_design, c("survey.design", "survey.design2", "svyrep.design"))) {
    cli::cli_abort(c(
      "x" = "{.arg svy_design} must be a survey design object.",
      "i" = "Create one using {.fn survey::svydesign} or {.fn survey::svrepdesign}.",
      "!" = "Received: {.cls {class(svy_design)}}"
    ))
  }

  # Check that cpue_data matches design data
  design_data <- svy_design$variables
  if (nrow(cpue_data) != nrow(design_data)) {
    cli::cli_abort(c(
      "x" = "{.arg cpue_data} and {.arg svy_design} have different number of rows.",
      "i" = "cpue_data: {.val {nrow(cpue_data)}} rows",
      "i" = "svy_design: {.val {nrow(design_data)}} rows",
      "!" = "Ensure survey design was built on the same data."
    ))
  }

  # Validate required columns
  required_cols <- c(species_col, response, effort_col)
  tc_abort_missing_cols(cpue_data, required_cols, context = "aggregate_cpue")

  # Check grouping variables
  by <- tc_group_warn(by %||% character(), names(cpue_data))

  # Validate species_values
  if (length(species_values) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg species_values} cannot be empty.",
      "i" = "Provide at least one species to aggregate."
    ))
  }

  # Check which species are present
  available_species <- unique(cpue_data[[species_col]])
  present_species <- intersect(species_values, available_species)
  missing_species <- setdiff(species_values, available_species)

  if (length(missing_species) > 0) {
    cli::cli_warn(c(
      "!" = "Some species in {.arg species_values} are not in the data.",
      "i" = "Missing: {.val {missing_species}}",
      "i" = "These will be ignored (contribute zero to aggregate)."
    ))
  }

  if (length(present_species) == 0) {
    cli::cli_abort(c(
      "x" = "None of the species in {.arg species_values} are in the data.",
      "i" = "Available species: {.val {available_species}}",
      "!" = "Check spelling and species codes."
    ))
  }

  # ── Data Preparation (unchanged) ──────────────────────────────────────────
  # Create aggregated catch variable
  agg_data <- cpue_data |>
    dplyr::mutate(.species_match = .data[[species_col]] %in% present_species)

  # Create unique interview ID (check for collision with existing column)
  if (".interview_id" %in% names(agg_data)) {
    cli::cli_abort(c(
      "x" = "Input data contains a column named {.field .interview_id}",
      "i" = "This is a reserved internal column name",
      "i" = "Please rename this column before calling {.fn aggregate_cpue}"
    ))
  }
  agg_data$.interview_id <- seq_len(nrow(agg_data))

  # Sum catch across species within each interview
  agg_catch <- agg_data |>
    dplyr::filter(.data$.species_match) |>
    dplyr::group_by(.interview_id, dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(
      aggregated_catch = sum(.data[[response]], na.rm = TRUE),
      effort = dplyr::first(.data[[effort_col]]),
      .groups = "drop"
    )

  # Join back to preserve zeros
  full_agg <- cpue_data |>
    dplyr::mutate(.interview_id = seq_len(nrow(cpue_data))) |>
    dplyr::select(dplyr::all_of(c(".interview_id", by, effort_col))) |>
    dplyr::distinct() |>
    dplyr::left_join(
      agg_catch |> dplyr::select(dplyr::all_of(c(".interview_id", "aggregated_catch"))),
      by = ".interview_id"
    ) |>
    dplyr::mutate(aggregated_catch = dplyr::coalesce(aggregated_catch, 0))

  # Update survey design with aggregated variable
  updated_data <- design_data |>
    dplyr::mutate(.interview_id = seq_len(nrow(design_data))) |>
    dplyr::left_join(
      full_agg |> dplyr::select(dplyr::all_of(c(".interview_id", "aggregated_catch"))),
      by = ".interview_id"
    ) |>
    dplyr::mutate(aggregated_catch = dplyr::coalesce(aggregated_catch, 0))

  # Create updated survey design
  svy_updated <- stats::update(svy_design, aggregated_catch = updated_data$aggregated_catch)

  # ── Estimate CPUE (REBUILT with variance engine for mean_of_ratios) ───────

  # Check for zero or missing effort values
  zero_effort <- sum(updated_data[[effort_col]] <= 0 | is.na(updated_data[[effort_col]]), na.rm = TRUE)
  if (zero_effort > 0) {
    cli::cli_warn(c(
      "!" = "{zero_effort} observation(s) have zero or negative effort",
      "i" = "These will produce Inf or NaN CPUE values",
      "i" = "Consider filtering data or setting a minimum effort threshold"
    ))
  }

  # Handle zero effort by setting a minimum threshold
  updated_data[[effort_col]][updated_data[[effort_col]] <= 0 | is.na(updated_data[[effort_col]])] <- 0.001

  if (mode == "ratio_of_means") {
    # For ratio estimation, create the ratio first then use mean
    # This allows us to use tc_compute_variance
    # Replace Inf/NaN from zero effort with NA
    cpue_ratio_values <- updated_data$aggregated_catch / updated_data[[effort_col]]
    cpue_ratio_values[!is.finite(cpue_ratio_values)] <- NA_real_
    svy_ratio <- stats::update(svy_updated, .cpue_ratio = cpue_ratio_values)

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
      n_by <- updated_data |>
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
        n = nrow(updated_data)
      )
    }

  } else if (mode == "mean_of_ratios") {
    # Mean-of-ratios: create ratio variable first
    # Replace Inf/NaN from zero effort with NA
    cpue_agg_values <- updated_data$aggregated_catch / updated_data[[effort_col]]
    cpue_agg_values[!is.finite(cpue_agg_values)] <- NA_real_
    svy2 <- stats::update(svy_updated, .cpue_agg = cpue_agg_values)

    if (length(by) > 0) {
      # Grouped estimation using core variance engine
      variance_result <- tc_compute_variance(
        design = svy2,
        response = ".cpue_agg",
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
      n_by <- updated_data |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)

    } else {
      # Overall estimation using core variance engine
      variance_result <- tc_compute_variance(
        design = svy2,
        response = ".cpue_agg",
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
        n = nrow(updated_data)
      )
    }

  } else {
    cli::cli_abort(c(
      "x" = "Unsupported mode: {.val {mode}}",
      "i" = "Use 'ratio_of_means' or 'mean_of_ratios'"
    ))
  }

  # ── NEW: Variance Decomposition ───────────────────────────────────────────
  if (decompose_variance) {
    variance_result$decomposition <- tryCatch({
      # Use the appropriate design based on mode
      design_to_use <- if (mode == "ratio_of_means") svy_ratio else svy2
      response_to_use <- if (mode == "ratio_of_means") ".cpue_ratio" else ".cpue_agg"

      tc_decompose_variance(
        design = design_to_use,
        response = response_to_use,
        cluster_vars = character(),  # Interview-level data has no clusters
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

  # ── Add metadata columns ──────────────────────────────────────────────────
  # Add group name column
  out$species_group <- group_name

  # Add method
  out$method <- paste0("aggregate_cpue:", response, ":", mode)

  # Add diagnostics (original)
  out$diagnostics <- replicate(nrow(out), list(
    species_aggregated = present_species,
    species_missing = missing_species,
    n_species = length(present_species),
    aggregation_method = mode
  ), simplify = FALSE)

  # ── NEW: Add variance_info ────────────────────────────────────────────────
  out$variance_info <- replicate(nrow(out), variance_result %||% list(NULL), simplify = FALSE)

  # Return in standard schema
  result_cols <- c(
    if (length(by) > 0) by else character(0),
    "species_group",
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

  dplyr::select(out, dplyr::all_of(result_cols))
}
