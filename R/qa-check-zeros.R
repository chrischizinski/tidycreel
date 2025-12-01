#' Check for Missing Zero Counts or Catches
#'
#' Detects potential skipping of zeros in count or interview data, which
#' leads to overestimation of effort, catch, and harvest. This is one of
#' the most common and serious creel survey errors (Table 17.3, #1).
#'
#' @param data Count data (for counts) or interview data (for catches)
#' @param type Type of data: `"counts"` or `"interviews"`
#' @param date_col Column containing dates (default "date")
#' @param location_col Column containing locations (default "location").
#'   For interviews without location, set to NULL.
#' @param value_col Column containing counts or catches. Required for counts,
#'   defaults to "catch_total" for interviews.
#' @param interviewer_col For interviews, column containing interviewer IDs to
#'   check for interviewer-specific bias (default NULL)
#' @param expected_coverage Proportion of sampling frame expected to have data
#'   (default 0.95 for counts, 0.7 for interviews). If actual coverage is
#'   below this, a warning is issued.
#' @param expected_zero_rate For interviews, expected proportion of zero catches
#'   (default 0.2). Used to detect suspiciously low zero rates.
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if potential zero-skipping detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{check_type}{"counts" or "interviews"}
#'     \item{coverage_rate}{For counts: proportion of expected observations present}
#'     \item{zero_rate}{For interviews: proportion of zero catches}
#'     \item{missing_dates}{Dates that should have data but don't}
#'     \item{missing_locations}{Locations that should have data but don't}
#'     \item{missing_combinations}{Date-location combinations missing}
#'     \item{interviewer_zero_rates}{For interviews: zero rates by interviewer}
#'     \item{suspicious_interviewers}{Interviewers with unusually low zero rates}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' **For Counts:**
#' 1. Identify sampling frame (all date-location combinations that should be sampled)
#' 2. Check which combinations are missing
#' 3. Flag if coverage < expected_coverage threshold
#' 4. Report missing dates and locations
#'
#' **For Interviews:**
#' 1. Check for suspiciously low proportion of zero catches
#' 2. Compare to expected zero-inflation rate (varies by fishery)
#' 3. If interviewer_col provided, examine interviewer-specific zero rates
#' 4. Flag interviewers with unusually low zero rates
#'
#' ## Severity Levels
#' - **High:** Coverage < 70% or zero rate < 10% (for interviews)
#' - **Medium:** Coverage 70-90% or zero rate 10-30%
#' - **Low:** Coverage > 90% but < expected, or zero rate 30-50%
#' - **None:** No issues detected
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Check count data for missing zeros
#' qa_counts <- qa_check_zeros(
#'   counts,
#'   type = "counts",
#'   date_col = "date",
#'   location_col = "location",
#'   value_col = "count"
#' )
#'
#' if (qa_counts$issue_detected) {
#'   print(qa_counts$recommendation)
#' }
#'
#' # Check interview data for skipped zero catches
#' qa_interviews <- qa_check_zeros(
#'   interviews,
#'   type = "interviews",
#'   date_col = "interview_date",
#'   value_col = "catch_total",
#'   interviewer_col = "clerk_id"
#' )
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_check_zeros <- function(
  data,
  type = c("counts", "interviews"),
  date_col = "date",
  location_col = NULL,
  value_col = NULL,
  interviewer_col = NULL,
  expected_coverage = NULL,
  expected_zero_rate = 0.2
) {

  # ============================================================================
  # STEP 1: INPUT VALIDATION
  # ============================================================================

  type <- match.arg(type)

  # Check data is provided
  if (missing(data) || is.null(data) || nrow(data) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg data} must be a non-empty data frame.",
      "i" = "Provide count or interview data to check."
    ))
  }

  # Check required columns
  required_cols <- date_col

  # For counts, location_col is required by default
  # For interviews, location_col is optional
  if (type == "counts" && !is.null(location_col)) {
    required_cols <- c(required_cols, location_col)
  } else if (type == "interviews" && !is.null(location_col) && location_col != "") {
    required_cols <- c(required_cols, location_col)
  }

  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Columns in data: {.val {names(data)}}"
    ))
  }

  # Type-specific validation
  if (type == "counts") {
    if (is.null(value_col)) {
      cli::cli_abort(c(
        "x" = "{.arg value_col} is required for count data.",
        "i" = "Specify the column containing count values."
      ))
    }
    if (!value_col %in% names(data)) {
      cli::cli_abort(c(
        "x" = "Count column {.val {value_col}} not found in data."
      ))
    }
    # Default expected coverage for counts
    if (is.null(expected_coverage)) expected_coverage <- 0.95
  } else {
    # interviews
    if (is.null(value_col)) value_col <- "catch_total"
    if (!value_col %in% names(data)) {
      cli::cli_abort(c(
        "x" = "Catch column {.val {value_col}} not found in data.",
        "i" = "Available columns: {.val {names(data)}}"
      ))
    }
    # Default expected coverage for interviews
    if (is.null(expected_coverage)) expected_coverage <- 0.7
  }

  # ============================================================================
  # STEP 2: TYPE-SPECIFIC CHECKING
  # ============================================================================

  if (type == "counts") {
    result <- check_zeros_counts(
      data = data,
      date_col = date_col,
      location_col = location_col,
      value_col = value_col,
      expected_coverage = expected_coverage
    )
  } else {
    result <- check_zeros_interviews(
      data = data,
      date_col = date_col,
      value_col = value_col,
      interviewer_col = interviewer_col,
      expected_zero_rate = expected_zero_rate
    )
  }

  result$check_type <- type
  class(result) <- c("qa_check_result", "list")
  return(result)
}


# ==============================================================================
# INTERNAL FUNCTION: Check zeros in count data
# ==============================================================================

check_zeros_counts <- function(data, date_col, location_col, value_col, expected_coverage) {

  # Identify sampling frame
  all_dates <- unique(data[[date_col]])
  if (!is.null(location_col)) {
    all_locations <- unique(data[[location_col]])
    expected_obs <- expand.grid(
      date = all_dates,
      location = all_locations,
      stringsAsFactors = FALSE
    )
    names(expected_obs) <- c(date_col, location_col)
  } else {
    expected_obs <- data.frame(date = all_dates, stringsAsFactors = FALSE)
    names(expected_obs) <- date_col
  }

  n_expected <- nrow(expected_obs)
  n_actual <- nrow(data)

  # Find missing combinations
  if (!is.null(location_col)) {
    merge_cols <- c(date_col, location_col)
  } else {
    merge_cols <- date_col
  }

  missing <- dplyr::anti_join(expected_obs, data, by = merge_cols)

  # Calculate coverage rate
  coverage_rate <- n_actual / n_expected

  # Identify missing dates and locations
  if (nrow(missing) > 0) {
    missing_dates <- unique(missing[[date_col]])
    missing_locations <- if (!is.null(location_col)) {
      unique(missing[[location_col]])
    } else {
      character(0)
    }
  } else {
    missing_dates <- character(0)
    missing_locations <- character(0)
  }

  # Determine severity
  if (coverage_rate < 0.7) {
    severity <- "high"
    issue_detected <- TRUE
  } else if (coverage_rate < 0.9) {
    severity <- "medium"
    issue_detected <- TRUE
  } else if (coverage_rate < expected_coverage) {
    severity <- "low"
    issue_detected <- TRUE
  } else {
    severity <- "none"
    issue_detected <- FALSE
  }

  # Generate recommendation
  if (issue_detected) {
    pct_missing <- round((1 - coverage_rate) * 100, 1)
    recommendation <- paste0(
      "COUNTS COVERAGE ISSUE (Severity: ", toupper(severity), ")\n\n",
      "* Coverage rate: ", round(coverage_rate * 100, 1), "% ",
      "(expected >= ", round(expected_coverage * 100, 0), "%)\n",
      "* Missing ", nrow(missing), " out of ", n_expected, " expected observations ",
      "(", pct_missing, "% missing)\n",
      if (length(missing_dates) > 0) paste0("* Missing dates: ", length(missing_dates), "\n") else "",
      if (length(missing_locations) > 0) paste0("* Missing locations: ", length(missing_locations), "\n") else "",
      "\nRECOMMENDATIONS:\n",
      "1. Review sampling protocol to ensure all scheduled counts are conducted\n",
      "2. Check for systematic patterns in missing data (specific days/locations)\n",
      "3. If zeros were intentionally not recorded, add explicit zero records\n",
      "4. Consider whether missing data represents true non-sampling or data entry error\n",
      "\nIMPACT: Missing zeros lead to OVERESTIMATION of effort, catch, and harvest."
    )
  } else {
    recommendation <- paste0(
      "No coverage issues detected. Coverage rate: ", round(coverage_rate * 100, 1), "%"
    )
  }

  list(
    issue_detected = issue_detected,
    severity = severity,
    coverage_rate = coverage_rate,
    n_expected = n_expected,
    n_actual = n_actual,
    n_missing = nrow(missing),
    missing_dates = missing_dates,
    missing_locations = missing_locations,
    missing_combinations = if (nrow(missing) > 0 && nrow(missing) <= 20) missing else NULL,
    zero_rate = NA_real_,
    interviewer_zero_rates = NULL,
    suspicious_interviewers = character(0),
    recommendation = recommendation
  )
}


# ==============================================================================
# INTERNAL FUNCTION: Check zeros in interview data
# ==============================================================================

check_zeros_interviews <- function(data, date_col, value_col, interviewer_col, expected_zero_rate) {

  # Calculate overall zero rate
  catch_values <- data[[value_col]]
  zero_rate <- sum(catch_values == 0, na.rm = TRUE) / sum(!is.na(catch_values))

  # Check interviewer-specific zero rates
  interviewer_zero_rates <- NULL
  suspicious_interviewers <- character(0)

  if (!is.null(interviewer_col) && interviewer_col %in% names(data)) {
    interviewer_stats <- data |>
      dplyr::group_by(.data[[interviewer_col]]) |>
      dplyr::summarise(
        n_interviews = dplyr::n(),
        n_zeros = sum(.data[[value_col]] == 0, na.rm = TRUE),
        zero_rate = n_zeros / n_interviews,
        .groups = "drop"
      )

    interviewer_zero_rates <- interviewer_stats

    # Flag interviewers with unusually low zero rates (< 50% of expected)
    threshold <- expected_zero_rate * 0.5
    suspicious <- interviewer_stats$zero_rate < threshold & interviewer_stats$n_interviews >= 10
    if (any(suspicious)) {
      suspicious_interviewers <- interviewer_stats[[interviewer_col]][suspicious]
    }
  }

  # Determine severity
  # High: < 10%
  # Medium: 10% to < 15% (50-75% of expected)
  # Low: 15% to < expected
  if (zero_rate < 0.1) {
    severity <- "high"
    issue_detected <- TRUE
  } else if (zero_rate < expected_zero_rate * 0.75) {
    severity <- "medium"
    issue_detected <- TRUE
  } else if (zero_rate < expected_zero_rate) {
    severity <- "low"
    issue_detected <- TRUE
  } else {
    severity <- "none"
    issue_detected <- FALSE
  }

  # Generate recommendation
  if (issue_detected) {
    recommendation <- paste0(
      "ZERO CATCH RATE ISSUE (Severity: ", toupper(severity), ")\n\n",
      "* Observed zero catch rate: ", round(zero_rate * 100, 1), "%\n",
      "* Expected zero catch rate: ~", round(expected_zero_rate * 100, 0), "%\n",
      "* Total interviews: ", nrow(data), "\n",
      "* Interviews with zero catch: ", sum(catch_values == 0, na.rm = TRUE), "\n",
      if (length(suspicious_interviewers) > 0) {
        paste0("\n* SUSPICIOUS INTERVIEWERS (very low zero rates):\n",
               paste0("  - ", suspicious_interviewers, collapse = "\n"), "\n")
      } else "",
      "\nRECOMMENDATIONS:\n",
      "1. Review interview protocols to ensure zero catches are recorded\n",
      "2. Check if clerks are targeting successful parties (e.g., at cleaning stations)\n",
      "3. Verify training emphasizes importance of recording all interviews, including zeros\n",
      "4. If specific interviewers have low zero rates, review their methods\n",
      "5. Consider whether interview location introduces bias (e.g., boat ramps vs active fishing areas)\n",
      "\nIMPACT: Skipping zero catches leads to OVERESTIMATION of catch rates, total catch, and harvest."
    )
  } else {
    recommendation <- paste0(
      "No zero catch issues detected. Zero rate: ", round(zero_rate * 100, 1), "% ",
      "(expected ~", round(expected_zero_rate * 100, 0), "%)"
    )
  }

  list(
    issue_detected = issue_detected,
    severity = severity,
    zero_rate = zero_rate,
    n_total = nrow(data),
    n_zeros = sum(catch_values == 0, na.rm = TRUE),
    coverage_rate = NA_real_,
    n_expected = NA_integer_,
    n_actual = NA_integer_,
    n_missing = NA_integer_,
    missing_dates = character(0),
    missing_locations = character(0),
    missing_combinations = NULL,
    interviewer_zero_rates = interviewer_zero_rates,
    suspicious_interviewers = suspicious_interviewers,
    recommendation = recommendation
  )
}


# ==============================================================================
# S3 METHOD: Print method for qa_check_result
# ==============================================================================

#' @export
print.qa_check_result <- function(x, ...) {
  cat("\n")
  cat("=================================================================\n")

  # Determine which check this is based on presence of specific fields
  if (!is.null(x$check_type)) {
    # qa_check_zeros
    cat("QA CHECK: Missing Zeros (Table 17.3, Mistake #1)\n")
    cat("=================================================================\n\n")
    cat("Check Type:", toupper(x$check_type), "\n")
  } else if (!is.null(x$overall_success_rate)) {
    # qa_check_targeting
    cat("QA CHECK: Targeting Bias (Table 17.3, Mistake #2)\n")
    cat("=================================================================\n\n")
  } else if (!is.null(x$location_coverage)) {
    # qa_check_spatial_coverage
    cat("QA CHECK: Spatial Coverage (Table 17.3, Mistakes #4-5)\n")
    cat("=================================================================\n\n")
  } else if (!is.null(x$likely_units)) {
    # qa_check_units
    cat("QA CHECK: Mixed Units (Table 17.3, Mistake #6)\n")
    cat("=================================================================\n\n")
  } else if (!is.null(x$n_effort_inconsistent)) {
    # qa_check_effort
    cat("QA CHECK: Effort Calculations (Table 17.3, Mistake #8)\n")
    cat("=================================================================\n\n")
  } else {
    # Generic QA check
    cat("QA CHECK\n")
    cat("=================================================================\n\n")
  }

  cat("Issue Detected:", if (x$issue_detected) "YES" else "NO", "\n")
  cat("Severity:", toupper(x$severity), "\n\n")

  cat(x$recommendation)
  cat("\n\n")

  invisible(x)
}
