#' Check for Targeting Bias (Successful Parties)
#'
#' Detects potential targeting of successful fishing parties, which occurs
#' when interviewers preferentially interview anglers with visible fish
#' (e.g., at fish-cleaning stations). This leads to overestimation of catch
#' and harvest rates (Table 17.3, #2).
#'
#' @param interviews Interview data
#' @param catch_col Column containing catch counts (default "catch_total")
#' @param location_col Column containing interview locations (optional).
#'   Used to identify high-success locations like cleaning stations.
#' @param interviewer_col Column containing interviewer IDs (optional).
#'   Used to detect interviewer-specific bias.
#' @param success_threshold Proportion of non-zero catches above which
#'   targeting is suspected (default 0.85). Natural fisheries typically
#'   have 30-70% success rates.
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if potential targeting detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{overall_success_rate}{Proportion of interviews with catch > 0}
#'     \item{expected_success_rate}{Expected range based on fishery type}
#'     \item{location_stats}{Success rates by location (if location_col provided)}
#'     \item{high_success_locations}{Locations with >90% success (potential cleaning stations)}
#'     \item{interviewer_stats}{Success rates by interviewer (if interviewer_col provided)}
#'     \item{biased_interviewers}{Interviewers with significantly high success rates}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Overall Success Rate:**
#'    - Calculate proportion of interviews with catch > 0
#'    - Flag if success rate > success_threshold (default 85%)
#'    - Natural fisheries typically have 30-70% success rates
#'    - Rates >85% suggest potential targeting bias
#'
#' 2. **Location-Specific Targeting:**
#'    - Identify locations with very high success rates (>90%)
#'    - These may be fish-cleaning stations or boat ramps where successful
#'      anglers congregate
#'    - Check if these locations are overrepresented in sample
#'
#' 3. **Interviewer Bias:**
#'    - Compare success rates among interviewers
#'    - Flag interviewers with substantially higher success rates than average
#'    - Use statistical tests (chi-square) if sufficient sample size
#'
#' ## Severity Levels
#' - **High:** Success rate >90% or >3 high-success locations
#' - **Medium:** Success rate 85-90% or 1-2 high-success locations
#' - **Low:** Success rate 75-85%
#' - **None:** Success rate <75%
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Basic check
#' qa_result <- qa_check_targeting(
#'   interviews,
#'   catch_col = "catch_total"
#' )
#'
#' # With location analysis
#' qa_result <- qa_check_targeting(
#'   interviews,
#'   catch_col = "catch_total",
#'   location_col = "interview_location",
#'   interviewer_col = "clerk_id"
#' )
#'
#' if (qa_result$issue_detected) {
#'   print(qa_result$high_success_locations)
#'   print(qa_result$recommendation)
#' }
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_check_targeting <- function(
  interviews,
  catch_col = "catch_total",
  location_col = NULL,
  interviewer_col = NULL,
  success_threshold = 0.85
) {

  # ============================================================================
  # STEP 1: INPUT VALIDATION
  # ============================================================================

  if (missing(interviews) || is.null(interviews) || nrow(interviews) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg interviews} must be a non-empty data frame.",
      "i" = "Provide interview data to check for targeting bias."
    ))
  }

  # Check catch column exists
  if (!catch_col %in% names(interviews)) {
    cli::cli_abort(c(
      "x" = "Catch column {.val {catch_col}} not found in data.",
      "i" = "Available columns: {.val {names(interviews)}}"
    ))
  }

  # Validate threshold
  if (!is.numeric(success_threshold) || success_threshold <= 0 || success_threshold > 1) {
    cli::cli_abort(c(
      "x" = "{.arg success_threshold} must be between 0 and 1.",
      "i" = "Received: {.val {success_threshold}}"
    ))
  }

  # Check optional columns
  if (!is.null(location_col) && !location_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Location column {.val {location_col}} not found.",
      "i" = "Skipping location-specific analysis."
    ))
    location_col <- NULL
  }

  if (!is.null(interviewer_col) && !interviewer_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Interviewer column {.val {interviewer_col}} not found.",
      "i" = "Skipping interviewer-specific analysis."
    ))
    interviewer_col <- NULL
  }

  # ============================================================================
  # STEP 2: CALCULATE OVERALL SUCCESS RATE
  # ============================================================================

  catch_values <- interviews[[catch_col]]
  n_total <- sum(!is.na(catch_values))
  n_success <- sum(catch_values > 0, na.rm = TRUE)
  overall_success_rate <- n_success / n_total

  # ============================================================================
  # STEP 3: LOCATION-SPECIFIC ANALYSIS
  # ============================================================================

  location_stats <- NULL
  high_success_locations <- character(0)
  n_high_success_locs <- 0

  if (!is.null(location_col)) {
    location_stats <- interviews |>
      dplyr::group_by(.data[[location_col]]) |>
      dplyr::summarise(
        n_interviews = dplyr::n(),
        n_success = sum(.data[[catch_col]] > 0, na.rm = TRUE),
        success_rate = n_success / n_interviews,
        mean_catch = mean(.data[[catch_col]], na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(success_rate))

    # Flag locations with >90% success rate (potential cleaning stations)
    high_success_locs <- location_stats$success_rate > 0.90 & location_stats$n_interviews >= 5
    if (any(high_success_locs)) {
      high_success_locations <- location_stats[[location_col]][high_success_locs]
      n_high_success_locs <- length(high_success_locations)
    }
  }

  # ============================================================================
  # STEP 4: INTERVIEWER-SPECIFIC ANALYSIS
  # ============================================================================

  interviewer_stats <- NULL
  biased_interviewers <- character(0)

  if (!is.null(interviewer_col)) {
    interviewer_stats <- interviews |>
      dplyr::group_by(.data[[interviewer_col]]) |>
      dplyr::summarise(
        n_interviews = dplyr::n(),
        n_success = sum(.data[[catch_col]] > 0, na.rm = TRUE),
        success_rate = n_success / n_interviews,
        mean_catch = mean(.data[[catch_col]], na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(success_rate))

    # Flag interviewers with success rate >1.2x overall average and >=10 interviews
    avg_success <- overall_success_rate
    biased_threshold <- min(0.95, avg_success * 1.2)  # At least 20% higher, max 95%

    biased <- interviewer_stats$success_rate > biased_threshold &
              interviewer_stats$n_interviews >= 10

    if (any(biased)) {
      biased_interviewers <- interviewer_stats[[interviewer_col]][biased]
    }
  }

  # ============================================================================
  # STEP 5: DETERMINE SEVERITY
  # ============================================================================

  issue_detected <- FALSE
  severity <- "none"

  if (overall_success_rate > 0.90 || n_high_success_locs > 3) {
    severity <- "high"
    issue_detected <- TRUE
  } else if (overall_success_rate > success_threshold || n_high_success_locs > 0) {
    severity <- "medium"
    issue_detected <- TRUE
  } else if (overall_success_rate > 0.75 || length(biased_interviewers) > 0) {
    severity <- "low"
    issue_detected <- TRUE
  }

  # ============================================================================
  # STEP 6: GENERATE RECOMMENDATION
  # ============================================================================

  if (issue_detected) {
    recommendation <- paste0(
      "TARGETING BIAS DETECTED (Severity: ", toupper(severity), ")\n\n",
      "* Overall success rate: ", round(overall_success_rate * 100, 1), "%\n",
      "* Expected range for natural fisheries: 30-70%\n",
      "* Total interviews: ", n_total, "\n",
      "* Successful interviews: ", n_success, "\n\n"
    )

    if (n_high_success_locs > 0) {
      recommendation <- paste0(
        recommendation,
        "HIGH-SUCCESS LOCATIONS (>90% success, potential cleaning stations):\n"
      )
      for (loc in high_success_locations) {
        loc_data <- location_stats[location_stats[[location_col]] == loc, ]
        recommendation <- paste0(
          recommendation,
          "  - ", loc, ": ", round(loc_data$success_rate * 100, 1), "% success ",
          "(", loc_data$n_interviews, " interviews)\n"
        )
      }
      recommendation <- paste0(recommendation, "\n")
    }

    if (length(biased_interviewers) > 0) {
      recommendation <- paste0(
        recommendation,
        "INTERVIEWERS WITH HIGH SUCCESS RATES:\n"
      )
      for (int in biased_interviewers) {
        int_data <- interviewer_stats[interviewer_stats[[interviewer_col]] == int, ]
        recommendation <- paste0(
          recommendation,
          "  - ", int, ": ", round(int_data$success_rate * 100, 1), "% success ",
          "(", int_data$n_interviews, " interviews)\n"
        )
      }
      recommendation <- paste0(recommendation, "\n")
    }

    recommendation <- paste0(
      recommendation,
      "RECOMMENDATIONS:\n",
      "1. Review interview protocols to ensure random/systematic sampling\n",
      "2. Avoid interviewing primarily at fish-cleaning stations or boat ramps\n",
      "3. Ensure interviews represent full range of angler experiences (including unsuccessful trips)\n",
      "4. If high-success locations are unavoidable, record interview location for post-stratification\n",
      "5. Retrain staff on importance of unbiased sampling\n",
      "6. Consider time-location sampling to ensure representative coverage\n",
      "\nIMPACT: Targeting successful parties leads to OVERESTIMATION of catch rates and total harvest."
    )
  } else {
    recommendation <- paste0(
      "No targeting bias detected. Success rate: ", round(overall_success_rate * 100, 1), "% ",
      "(within expected range for representative sampling)"
    )
  }

  # ============================================================================
  # STEP 7: RETURN RESULTS
  # ============================================================================

  result <- list(
    issue_detected = issue_detected,
    severity = severity,
    overall_success_rate = overall_success_rate,
    n_total = n_total,
    n_success = n_success,
    expected_success_range = c(0.30, 0.70),
    location_stats = location_stats,
    high_success_locations = high_success_locations,
    n_high_success_locations = n_high_success_locs,
    interviewer_stats = interviewer_stats,
    biased_interviewers = biased_interviewers,
    recommendation = recommendation
  )

  class(result) <- c("qa_check_result", "list")
  return(result)
}


# ==============================================================================
# S3 METHOD: Print method for targeting check
# ==============================================================================

# Print method is defined in qa-check-zeros.R to avoid conflicts
# This function shares the qa_check_result class
