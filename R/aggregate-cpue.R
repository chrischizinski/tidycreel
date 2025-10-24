#' Aggregate CPUE Across Species Using Survey Design
#'
#' Combines CPUE estimates for multiple species into a single aggregate,
#' properly accounting for survey design and covariance between species.
#' This function is essential for calculating total harvest for species groups
#' (e.g., black bass, panfish, catfish) while maintaining proper variance estimation.
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
#'
#' @return Tibble with grouping columns (including `species_group`), `estimate`,
#'   `se`, `ci_low`, `ci_high`, `n`, `method`, and `diagnostics` list-column.
#'   Schema matches `est_cpue()` output for seamless use with `est_total_harvest()`.
#'
#' @details
#' **Statistical Approach:**
#'
#' This function performs survey-design-based aggregation, which is CRITICAL for
#' proper variance estimation. It works by:
#'
#' 1. Creating an aggregated catch variable by summing catch across specified species
#'    within each interview
#' 2. Updating the survey design with this aggregated variable
#' 3. Estimating CPUE for the aggregate using standard survey methods
#' 4. Properly accounting for covariance between species
#'
#' **Why This Matters:**
#'
#' Simply adding species-specific harvest estimates (effort × CPUE for each species)
#' and summing them produces INCORRECT variance estimates because it ignores
#' the covariance between species catches. This function ensures proper variance
#' by aggregating at the CPUE level before multiplying by effort.
#'
#' **WRONG Approach:**
#' ```r
#' # DON'T DO THIS - ignores covariance
#' harvest_lmb <- est_total_harvest(effort, cpue_largemouth)
#' harvest_smb <- est_total_harvest(effort, cpue_smallmouth)
#' harvest_bass_wrong <- harvest_lmb$estimate + harvest_smb$estimate
#' ```
#'
#' **CORRECT Approach:**
#' ```r
#' # DO THIS - proper survey-based aggregation
#' cpue_black_bass <- aggregate_cpue(
#'   interviews, svy_int,
#'   species_values = c("largemouth_bass", "smallmouth_bass"),
#'   group_name = "black_bass"
#' )
#' harvest_bass_correct <- est_total_harvest(effort, cpue_black_bass)
#' ```
#'
#' **Missing Species Handling:**
#'
#' If `species_values` includes species not present in the data, they are
#' silently ignored (contributing zero to the aggregate). A warning is issued
#' if ALL specified species are missing.
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#' library(survey)
#'
#' # Example: Aggregate black bass species
#' svy_int <- svydesign(ids = ~1, weights = ~1, data = interviews)
#'
#' cpue_black_bass <- aggregate_cpue(
#'   cpue_data = interviews,
#'   svy_design = svy_int,
#'   species_col = "species",
#'   species_values = c("largemouth_bass", "smallmouth_bass", "spotted_bass"),
#'   group_name = "black_bass",
#'   response = "catch_kept"
#' )
#'
#' # Use in harvest calculation
#' harvest_black_bass <- est_total_harvest(effort_est, cpue_black_bass)
#'
#' # Aggregate by location and species group
#' cpue_panfish_by_loc <- aggregate_cpue(
#'   cpue_data = interviews,
#'   svy_design = svy_int,
#'   species_values = c("bluegill", "redear_sunfish", "green_sunfish"),
#'   group_name = "panfish",
#'   by = "location",
#'   response = "catch_kept"
#' )
#'
#' # All species combined
#' cpue_all_species <- aggregate_cpue(
#'   cpue_data = interviews,
#'   svy_design = svy_int,
#'   species_values = unique(interviews$species),
#'   group_name = "all_species",
#'   response = "catch_total"
#' )
#' }
#'
#' @references
#' Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods
#'   and Their Applications in Fisheries Management. American Fisheries
#'   Society Special Publication 25.
#'
#' @seealso
#' [est_cpue()], [est_total_harvest()]
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
  conf_level = 0.95
) {
  # Validate inputs
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

  # Validate required columns in cpue_data
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

  # Check which species are actually in the data
  available_species <- unique(cpue_data[[species_col]])
  present_species <- intersect(species_values, available_species)
  missing_species <- setdiff(species_values, available_species)

  # Warn about missing species
  if (length(missing_species) > 0) {
    cli::cli_warn(c(
      "!" = "Some species in {.arg species_values} are not in the data.",
      "i" = "Missing: {.val {missing_species}}",
      "i" = "These will be ignored (contribute zero to aggregate)."
    ))
  }

  # Error if ALL species are missing
  if (length(present_species) == 0) {
    cli::cli_abort(c(
      "x" = "None of the species in {.arg species_values} are in the data.",
      "i" = "Available species: {.val {available_species}}",
      "!" = "Check spelling and species codes."
    ))
  }

  # Create aggregated catch variable
  # For each interview, sum catch across the specified species
  agg_data <- cpue_data |>
    dplyr::mutate(
      .species_match = .data[[species_col]] %in% present_species
    )

  # Group by interview-level identifier + optional grouping vars
  # We need to identify unique interviews - use row number as ID if no interview_id
  agg_data$.interview_id <- seq_len(nrow(agg_data))

  # Sum catch across species within each interview
  agg_catch <- agg_data |>
    dplyr::filter(.data$.species_match) |>
    dplyr::group_by(.interview_id, dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(
      aggregated_catch = sum(.data[[response]], na.rm = TRUE),
      effort = dplyr::first(.data[[effort_col]]),  # Effort is interview-level
      .groups = "drop"
    )

  # Join back to full interview data to preserve zeros
  # (interviews with zero catch of target species)
  full_agg <- cpue_data |>
    dplyr::mutate(.interview_id = seq_len(nrow(cpue_data))) |>
    dplyr::select(dplyr::all_of(c(".interview_id", by, effort_col))) |>
    dplyr::distinct() |>
    dplyr::left_join(
      agg_catch |> dplyr::select(dplyr::all_of(c(".interview_id", "aggregated_catch"))),
      by = ".interview_id"
    ) |>
    dplyr::mutate(
      aggregated_catch = dplyr::coalesce(aggregated_catch, 0)
    )

  # Update survey design with aggregated variable
  # We need to merge the aggregated catch back into the design data
  updated_data <- design_data |>
    dplyr::mutate(.interview_id = seq_len(nrow(design_data))) |>
    dplyr::left_join(
      full_agg |> dplyr::select(dplyr::all_of(c(".interview_id", "aggregated_catch"))),
      by = ".interview_id"
    ) |>
    dplyr::mutate(
      aggregated_catch = dplyr::coalesce(aggregated_catch, 0)
    )

  # Create updated survey design with aggregated catch
  svy_updated <- stats::update(svy_design, aggregated_catch = updated_data$aggregated_catch)

  # Estimate CPUE for the aggregated catch using standard est_cpue logic
  # We'll use ratio-of-means by default (most robust)
  if (mode == "ratio_of_means") {
    if (length(by) > 0) {
      # Grouped estimation
      by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
      est <- survey::svyby(
        ~aggregated_catch,
        by = by_formula,
        design = svy_updated,
        FUN = survey::svyratio,
        denominator = stats::as.formula(paste0("~", effort_col)),
        na.rm = TRUE,
        keep.names = FALSE
      )

      out <- tibble::as_tibble(est)
      out$estimate <- as.numeric(stats::coef(est))

      # Extract standard errors
      se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)
      if (!inherits(se_try, "try-error") && length(se_try) == nrow(out)) {
        out$se <- se_try
      } else {
        V <- attr(est, "var")
        out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      }

      # Confidence intervals
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se

      # Sample size (unweighted count)
      n_by <- updated_data |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)

    } else {
      # Ungrouped estimation
      r <- survey::svyratio(
        ~aggregated_catch,
        stats::as.formula(paste0("~", effort_col)),
        svy_updated,
        na.rm = TRUE
      )
      estimate <- as.numeric(stats::coef(r))
      se <- sqrt(as.numeric(stats::vcov(r)))
      ci <- tc_confint(estimate, se, level = conf_level)
      n <- nrow(updated_data)

      out <- tibble::tibble(
        estimate = estimate,
        se = se,
        ci_low = ci[1],
        ci_high = ci[2],
        n = n
      )
    }
  } else if (mode == "mean_of_ratios") {
    # Mean-of-ratios approach
    svy2 <- stats::update(svy_updated, .cpue_agg = aggregated_catch / updated_data[[effort_col]])

    if (length(by) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by, collapse = "+")))
      est <- survey::svyby(
        ~.cpue_agg,
        by = by_formula,
        design = svy2,
        FUN = survey::svymean,
        na.rm = TRUE,
        keep.names = FALSE
      )

      out <- tibble::as_tibble(est)
      names(out)[names(out) == ".cpue_agg"] <- "estimate"

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

      n_by <- updated_data |>
        dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
        dplyr::summarise(n = dplyr::n(), .groups = "drop")
      out <- dplyr::left_join(out, n_by, by = by)

    } else {
      est <- survey::svymean(~.cpue_agg, svy2, na.rm = TRUE)
      estimate <- as.numeric(stats::coef(est))
      se <- sqrt(as.numeric(stats::vcov(est)))
      ci <- tc_confint(estimate, se, level = conf_level)
      n <- nrow(updated_data)

      out <- tibble::tibble(
        estimate = estimate,
        se = se,
        ci_low = ci[1],
        ci_high = ci[2],
        n = n
      )
    }
  } else {
    cli::cli_abort(c(
      "x" = "Unsupported mode: {.val {mode}}",
      "i" = "Use 'ratio_of_means' or 'mean_of_ratios'"
    ))
  }

  # Add group name column
  out$species_group <- group_name

  # Add method and diagnostics
  out$method <- paste0("aggregate_cpue:", response, ":", mode)
  out$diagnostics <- replicate(nrow(out), list(list(
    species_aggregated = present_species,
    species_missing = missing_species,
    n_species = length(present_species),
    aggregation_method = mode
  )))

  # Return in standard schema (matching est_cpue)
  result_cols <- c(
    if (length(by) > 0) by else character(0),
    "species_group",
    "estimate",
    "se",
    "ci_low",
    "ci_high",
    "n",
    "method",
    "diagnostics"
  )

  dplyr::select(out, dplyr::all_of(result_cols))
}
