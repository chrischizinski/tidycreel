#' Check Spatial Coverage Completeness
#'
#' Detects incomplete spatial coverage for both counts and interviews,
#' which creates unrepresentative samples and unknown bias (Table 17.3, #4-5).
#'
#' @param data Count or interview data
#' @param locations_expected Character vector of all locations that should be sampled.
#'   If NULL, uses all unique locations found in data.
#' @param location_col Column containing location names (default "location")
#' @param date_col Column containing dates (default "date")
#' @param type Data type: `"counts"` or `"interviews"`
#' @param interviewer_col Column containing interviewer IDs (optional).
#'   Used to check if interviewers cover all locations.
#' @param min_coverage Minimum acceptable coverage proportion (default 0.90)
#' @param min_sample_size Minimum sample size per location to avoid low-n warnings (default 10)
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if coverage issues detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{location_coverage}{Proportion of expected locations sampled}
#'     \item{locations_observed}{Locations found in data}
#'     \item{locations_missing}{Expected locations not in data}
#'     \item{location_stats}{Sample sizes and temporal coverage by location}
#'     \item{undersampled_locations}{Locations with sample size < min_sample_size}
#'     \item{temporal_gaps}{Locations with poor temporal coverage}
#'     \item{interviewer_coverage}{Coverage matrix by interviewer (if interviewer_col provided)}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Location Coverage:**
#'    - Check which expected locations are missing entirely
#'    - Calculate proportion of locations covered
#'    - Flag if coverage < min_coverage
#'
#' 2. **Sample Size Adequacy:**
#'    - Compare sample sizes among locations
#'    - Flag locations with very low sample sizes (< min_sample_size)
#'    - Check for extreme imbalance (CV > 1.0)
#'
#' 3. **Temporal Coverage:**
#'    - For each location, check temporal span vs overall season
#'    - Flag locations with temporal coverage < 70% of season
#'
#' 4. **Interviewer Coverage (optional):**
#'    - Check if interviewers cover all locations
#'    - Flag if certain interviewers only work certain sites
#'
#' ## Severity Levels
#' - **High:** Missing >20% of locations OR >50% have low sample sizes
#' - **Medium:** Missing 10-20% of locations OR 25-50% have low sample sizes
#' - **Low:** Missing <10% of locations OR <25% have low sample sizes
#' - **None:** All locations covered with adequate samples
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Define expected locations
#' expected_locs <- c("North Shore", "South Shore", "East Bay", "West Bay")
#'
#' # Check spatial coverage
#' qa_result <- qa_check_spatial_coverage(
#'   counts,
#'   locations_expected = expected_locs,
#'   location_col = "location",
#'   date_col = "date",
#'   type = "counts"
#' )
#'
#' # With interviewer analysis
#' qa_result <- qa_check_spatial_coverage(
#'   interviews,
#'   locations_expected = expected_locs,
#'   location_col = "location",
#'   interviewer_col = "clerk_id",
#'   type = "interviews"
#' )
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_check_spatial_coverage <- function(
  data,
  locations_expected = NULL,
  location_col = "location",
  date_col = "date",
  type = c("counts", "interviews"),
  interviewer_col = NULL,
  min_coverage = 0.90,
  min_sample_size = 10
) {

  # ============================================================================
  # STEP 1: INPUT VALIDATION
  # ============================================================================

  type <- match.arg(type)

  if (missing(data) || is.null(data) || nrow(data) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg data} must be a non-empty data frame.",
      "i" = "Provide count or interview data to check spatial coverage."
    ))
  }

  # Check required columns
  required_cols <- c(location_col, date_col)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Available columns: {.val {names(data)}}"
    ))
  }

  # Check optional interviewer column
  if (!is.null(interviewer_col) && !interviewer_col %in% names(data)) {
    cli::cli_warn(c(
      "!" = "Interviewer column {.val {interviewer_col}} not found.",
      "i" = "Skipping interviewer coverage analysis."
    ))
    interviewer_col <- NULL
  }

  # Validate thresholds
  if (!is.numeric(min_coverage) || min_coverage <= 0 || min_coverage > 1) {
    cli::cli_abort(c(
      "x" = "{.arg min_coverage} must be between 0 and 1.",
      "i" = "Received: {.val {min_coverage}}"
    ))
  }

  # ============================================================================
  # STEP 2: LOCATION COVERAGE
  # ============================================================================

  locations_observed <- unique(data[[location_col]])
  locations_observed <- locations_observed[!is.na(locations_observed)]

  # If expected locations not provided, use all observed
  if (is.null(locations_expected)) {
    locations_expected <- locations_observed
    cli::cli_inform(c(
      "i" = "No expected locations provided. Using {length(locations_expected)} observed location{?s}."
    ))
  }

  locations_missing <- setdiff(locations_expected, locations_observed)
  locations_found <- intersect(locations_expected, locations_observed)
  n_expected <- length(locations_expected)
  n_found <- length(locations_found)
  location_coverage <- n_found / n_expected

  # ============================================================================
  # STEP 3: SAMPLE SIZE AND TEMPORAL COVERAGE BY LOCATION
  # ============================================================================

  # Calculate overall temporal range
  dates <- data[[date_col]]
  date_range <- range(dates, na.rm = TRUE)
  total_days <- as.numeric(diff(date_range))

  # Calculate stats by location
  location_stats <- data |>
    dplyr::group_by(.data[[location_col]]) |>
    dplyr::summarise(
      n_samples = dplyr::n(),
      first_date = min(.data[[date_col]], na.rm = TRUE),
      last_date = max(.data[[date_col]], na.rm = TRUE),
      n_days = dplyr::n_distinct(.data[[date_col]]),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      days_span = as.numeric(.data$last_date - .data$first_date),
      temporal_coverage = .data$days_span / total_days
    ) |>
    dplyr::arrange(dplyr::desc(n_samples))

  # Identify undersampled locations
  undersampled <- location_stats$n_samples < min_sample_size
  undersampled_locations <- if (any(undersampled)) {
    location_stats[[location_col]][undersampled]
  } else {
    character(0)
  }

  # Identify locations with poor temporal coverage (<70% of season)
  temporal_gaps <- location_stats$temporal_coverage < 0.70
  locations_with_gaps <- if (any(temporal_gaps)) {
    location_stats[[location_col]][temporal_gaps]
  } else {
    character(0)
  }

  # Check sample size imbalance (high CV indicates imbalance)
  sample_size_cv <- stats::sd(location_stats$n_samples) / mean(location_stats$n_samples)

  # ============================================================================
  # STEP 4: INTERVIEWER COVERAGE (OPTIONAL)
  # ============================================================================

  interviewer_coverage <- NULL
  interviewers_with_limited_coverage <- character(0)

  if (!is.null(interviewer_col)) {
    interviewer_coverage <- data |>
      dplyr::group_by(.data[[interviewer_col]], .data[[location_col]]) |>
      dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
      tidyr::pivot_wider(
        names_from = dplyr::all_of(location_col),
        values_from = n,
        values_fill = 0
      )

    # Check if any interviewer covers <80% of locations with >=5 interviews total
    n_locations <- length(locations_observed)
    interviewer_totals <- data |>
      dplyr::group_by(.data[[interviewer_col]]) |>
      dplyr::summarise(
        n_total = dplyr::n(),
        n_locations = dplyr::n_distinct(.data[[location_col]]),
        .groups = "drop"
      )

    limited_coverage <- interviewer_totals$n_total >= 5 &
                       interviewer_totals$n_locations / n_locations < 0.80

    if (any(limited_coverage)) {
      interviewers_with_limited_coverage <- interviewer_totals[[interviewer_col]][limited_coverage]
    }
  }

  # ============================================================================
  # STEP 5: DETERMINE SEVERITY
  # ============================================================================

  issue_detected <- FALSE
  severity <- "none"

  pct_missing <- (1 - location_coverage) * 100
  n_locs_observed <- length(locations_observed)
  pct_undersampled <- if (n_locs_observed > 0) {
    sum(undersampled) / n_locs_observed * 100
  } else {
    0
  }

  if (location_coverage < 0.80 || pct_undersampled > 50) {
    severity <- "high"
    issue_detected <- TRUE
  } else if (location_coverage < 0.90 || pct_undersampled > 25) {
    severity <- "medium"
    issue_detected <- TRUE
  } else if (length(undersampled_locations) > 0 || length(locations_with_gaps) > 0) {
    severity <- "low"
    issue_detected <- TRUE
  }

  # ============================================================================
  # STEP 6: GENERATE RECOMMENDATION
  # ============================================================================

  if (issue_detected) {
    recommendation <- paste0(
      "SPATIAL COVERAGE ISSUE (Severity: ", toupper(severity), ")\n\n",
      "* Location coverage: ", round(location_coverage * 100, 1), "% ",
      "(expected >=", round(min_coverage * 100, 0), "%)\n",
      "* Locations expected: ", n_expected, "\n",
      "* Locations found: ", n_found, " (", length(locations_observed), " total observed)\n"
    )

    if (length(locations_missing) > 0) {
      recommendation <- paste0(
        recommendation,
        "* Missing locations (", length(locations_missing), "): ",
        paste(head(locations_missing, 5), collapse = ", "),
        if (length(locations_missing) > 5) " ..." else "", "\n"
      )
    }

    if (length(undersampled_locations) > 0) {
      recommendation <- paste0(
        recommendation,
        "\nUNDERSAMPLED LOCATIONS (< ", min_sample_size, " samples):\n"
      )
      for (loc in head(undersampled_locations, 5)) {
        loc_data <- location_stats[location_stats[[location_col]] == loc, ]
        recommendation <- paste0(
          recommendation,
          "  - ", loc, ": n = ", loc_data$n_samples, "\n"
        )
      }
      if (length(undersampled_locations) > 5) {
        recommendation <- paste0(recommendation, "  ... and ", length(undersampled_locations) - 5, " more\n")
      }
    }

    if (length(locations_with_gaps) > 0) {
      recommendation <- paste0(
        recommendation,
        "\nLOCATIONS WITH TEMPORAL GAPS (<70% of season):\n"
      )
      for (loc in head(locations_with_gaps, 5)) {
        loc_data <- location_stats[location_stats[[location_col]] == loc, ]
        recommendation <- paste0(
          recommendation,
          "  - ", loc, ": ", round(loc_data$temporal_coverage * 100, 1), "% coverage\n"
        )
      }
    }

    if (!is.na(sample_size_cv) && sample_size_cv > 1.0) {
      recommendation <- paste0(
        recommendation,
        "\nSAMPLE SIZE IMBALANCE:\n",
        "* CV = ", round(sample_size_cv, 2), " (high variability in effort allocation)\n"
      )
    }

    if (length(interviewers_with_limited_coverage) > 0) {
      recommendation <- paste0(
        recommendation,
        "\nINTERVIEWERS WITH LIMITED SPATIAL COVERAGE:\n",
        paste("  - ", interviewers_with_limited_coverage, collapse = "\n"), "\n"
      )
    }

    recommendation <- paste0(
      recommendation,
      "\nRECOMMENDATIONS:\n",
      "1. Ensure sampling protocol covers ALL waterbody locations\n",
      "2. Increase sampling effort at undersampled locations\n",
      "3. Maintain consistent temporal coverage across all locations\n",
      "4. Use stratified random sampling to ensure proportional coverage\n",
      "5. Review interviewer assignments to ensure broad spatial coverage\n",
      "6. If certain locations are inaccessible, document and adjust inference domain\n",
      "\nIMPACT: Incomplete spatial coverage creates UNREPRESENTATIVE SAMPLES and UNKNOWN BIAS."
    )
  } else {
    recommendation <- paste0(
      "No spatial coverage issues detected.\n",
      "* Coverage: ", round(location_coverage * 100, 1), "% of expected locations\n",
      "* All locations have adequate sample sizes"
    )
  }

  # ============================================================================
  # STEP 7: RETURN RESULTS
  # ============================================================================

  result <- list(
    issue_detected = issue_detected,
    severity = severity,
    location_coverage = location_coverage,
    n_locations_expected = n_expected,
    n_locations_observed = length(locations_observed),
    n_locations_found = n_found,
    n_locations_missing = length(locations_missing),
    locations_expected = locations_expected,
    locations_observed = locations_observed,
    locations_missing = locations_missing,
    location_stats = location_stats,
    undersampled_locations = undersampled_locations,
    temporal_gaps = locations_with_gaps,
    sample_size_cv = sample_size_cv,
    interviewer_coverage = interviewer_coverage,
    interviewers_with_limited_coverage = interviewers_with_limited_coverage,
    recommendation = recommendation
  )

  class(result) <- c("qa_check_result", "list")
  return(result)
}
