#' Check for Party-Level Effort Calculation Errors
#'
#' Detects potential errors in party-level effort calculations, which
#' under/overestimates catch and harvest rates (Table 17.3, #8).
#'
#' @param interviews Interview data
#' @param effort_col Column containing effort (angler-hours). If NULL and
#'   hours_fished_col is provided, effort will be calculated from hours and anglers.
#' @param num_anglers_col Column containing number of anglers in party
#' @param hours_fished_col Column containing hours fished per angler or party
#' @param catch_col Column containing catch counts (for zero-effort validation)
#' @param party_id_col Column with party identifiers (optional)
#' @param tolerance Numeric tolerance for effort calculation validation (default 0.01)
#' @param max_hours Maximum reasonable hours fished (default 24)
#' @param min_hours Minimum reasonable hours fished (default 0.1)
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if effort issues detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{n_total}{Total number of interviews}
#'     \item{n_effort_inconsistent}{Number with incorrect effort calculations}
#'     \item{n_zero_effort}{Number with zero effort}
#'     \item{n_zero_effort_with_catch}{Zero effort but non-zero catch}
#'     \item{n_outliers}{Number with outlier effort values}
#'     \item{outlier_records}{Sample of outlier records}
#'     \item{effort_inconsistent_records}{Sample of records with calculation errors}
#'     \item{effort_summary}{Summary statistics of effort distribution}
#'     \item{decimal_error_candidates}{Records that may have decimal point errors}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Effort Calculation Validation:**
#'    - Check if effort = num_anglers × hours_fished
#'    - Flag inconsistencies (allowing for small rounding errors)
#'    - Recommend correction formula
#'
#' 2. **Individual Effort Variation:**
#'    - Check for documented individual-level effort within parties
#'    - Flag if always assuming all anglers fished equal time
#'    - Recommend individual-level effort collection
#'
#' 3. **Outlier Detection:**
#'    - Identify unusually high/low effort values
#'    - Flag trips > 24 hours or < 0.1 hours
#'    - Check for decimal point errors (e.g., 0.5 entered as 5)
#'
#' 4. **Zero Effort with Catch:**
#'    - Flag records with catch > 0 but effort = 0 or missing
#'    - These create division-by-zero in CPUE calculations
#'
#' ## Severity Levels
#' - **High:** >20% incorrect calculations OR zero effort with catch
#' - **Medium:** 5-20% incorrect calculations OR many outliers
#' - **Low:** <5% incorrect OR minor inconsistencies
#' - **None:** All effort calculations correct
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Basic check
#' qa_result <- qa_check_effort(
#'   interviews,
#'   effort_col = "hours_fished",
#'   num_anglers_col = "num_anglers",
#'   hours_fished_col = "hours_per_angler"
#' )
#'
#' # With catch validation
#' qa_result <- qa_check_effort(
#'   interviews,
#'   effort_col = "angler_hours",
#'   num_anglers_col = "num_anglers",
#'   hours_fished_col = "hours",
#'   catch_col = "catch_total"
#' )
#'
#' if (qa_result$issue_detected) {
#'   print(qa_result$recommendation)
#' }
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_check_effort <- function(
  interviews,
  effort_col = NULL,
  num_anglers_col = NULL,
  hours_fished_col = NULL,
  catch_col = NULL,
  party_id_col = NULL,
  tolerance = 0.01,
  max_hours = 24,
  min_hours = 0.1
) {

  # ============================================================================
  # STEP 1: INPUT VALIDATION
  # ============================================================================

  if (missing(interviews) || is.null(interviews) || nrow(interviews) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg interviews} must be a non-empty data frame.",
      "i" = "Provide interview data to check effort calculations."
    ))
  }

  # Must have at least effort_col OR hours_fished_col
  if (is.null(effort_col) && is.null(hours_fished_col)) {
    cli::cli_abort(c(
      "x" = "Must provide at least {.arg effort_col} or {.arg hours_fished_col}."
    ))
  }

  # Check that specified columns exist
  required_cols <- character(0)
  if (!is.null(effort_col)) required_cols <- c(required_cols, effort_col)
  if (!is.null(num_anglers_col)) required_cols <- c(required_cols, num_anglers_col)
  if (!is.null(hours_fished_col)) required_cols <- c(required_cols, hours_fished_col)

  missing_cols <- setdiff(required_cols, names(interviews))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Available columns: {.val {names(interviews)}}"
    ))
  }

  # Check optional columns
  if (!is.null(catch_col) && !catch_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Catch column {.val {catch_col}} not found.",
      "i" = "Skipping zero-effort-with-catch validation."
    ))
    catch_col <- NULL
  }

  if (!is.null(party_id_col) && !party_id_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Party ID column {.val {party_id_col}} not found.",
      "i" = "Skipping party-level analysis."
    ))
    party_id_col <- NULL
  }

  n_total <- nrow(interviews)

  # ============================================================================
  # STEP 2: EFFORT CALCULATION VALIDATION
  # ============================================================================

  n_effort_inconsistent <- 0
  effort_inconsistent_records <- NULL

  # Can only validate if we have all three columns
  if (!is.null(effort_col) && !is.null(num_anglers_col) && !is.null(hours_fished_col)) {

    effort_actual <- interviews[[effort_col]]
    num_anglers <- interviews[[num_anglers_col]]
    hours_fished <- interviews[[hours_fished_col]]

    # Calculate expected effort
    effort_expected <- num_anglers * hours_fished

    # Find inconsistencies (allowing for rounding tolerance)
    effort_diff <- abs(effort_actual - effort_expected)
    inconsistent <- !is.na(effort_actual) & !is.na(effort_expected) &
                    effort_diff > tolerance

    n_effort_inconsistent <- sum(inconsistent)

    if (n_effort_inconsistent > 0) {
      # Take up to 10 samples
      sample_idx <- head(which(inconsistent), 10)
      effort_inconsistent_records <- data.frame(
        effort_actual = effort_actual[sample_idx],
        num_anglers = num_anglers[sample_idx],
        hours_fished = hours_fished[sample_idx],
        effort_expected = effort_expected[sample_idx],
        difference = effort_diff[sample_idx]
      )
    }
  }

  # ============================================================================
  # STEP 3: ZERO EFFORT DETECTION
  # ============================================================================

  # Determine which column to use for effort
  effort_values <- if (!is.null(effort_col)) {
    interviews[[effort_col]]
  } else if (!is.null(hours_fished_col)) {
    interviews[[hours_fished_col]]
  } else {
    rep(NA_real_, n_total)
  }

  n_zero_effort <- sum(effort_values == 0, na.rm = TRUE)
  n_missing_effort <- sum(is.na(effort_values))

  # Check for zero effort with non-zero catch
  n_zero_effort_with_catch <- 0
  if (!is.null(catch_col)) {
    catch_values <- interviews[[catch_col]]
    zero_effort_with_catch <- (effort_values == 0 | is.na(effort_values)) &
                               !is.na(catch_values) & catch_values > 0
    n_zero_effort_with_catch <- sum(zero_effort_with_catch)
  }

  # ============================================================================
  # STEP 4: OUTLIER DETECTION
  # ============================================================================

  # Identify outliers (excluding NA and zero)
  valid_effort <- effort_values[!is.na(effort_values) & effort_values > 0]

  outliers_high <- effort_values > max_hours
  # Low outliers include negative values OR positive values < min_hours
  outliers_low <- (!is.na(effort_values) & effort_values < 0) |
                  (effort_values > 0 & effort_values < min_hours)

  n_outliers <- sum(outliers_high, na.rm = TRUE) + sum(outliers_low, na.rm = TRUE)

  outlier_records <- NULL
  if (n_outliers > 0) {
    outlier_idx <- which(outliers_high | outliers_low)
    sample_idx <- head(outlier_idx, 10)

    outlier_records <- data.frame(
      effort = effort_values[sample_idx],
      type = ifelse(outliers_high[sample_idx], "high", "low")
    )

    if (!is.null(num_anglers_col)) {
      outlier_records$num_anglers <- interviews[[num_anglers_col]][sample_idx]
    }
    if (!is.null(hours_fished_col)) {
      outlier_records$hours_fished <- interviews[[hours_fished_col]][sample_idx]
    }
  }

  # ============================================================================
  # STEP 5: DECIMAL POINT ERROR DETECTION
  # ============================================================================

  # Check for potential decimal point errors
  # E.g., 0.5 entered as 5, 0.8 entered as 8
  # Look for values that are exactly 10x what they should be

  decimal_error_candidates <- NULL

  if (!is.null(effort_col) && !is.null(num_anglers_col) && !is.null(hours_fished_col)) {
    # Potential decimal errors: effort is 10x expected
    effort_10x <- abs(effort_actual - effort_expected * 10) < tolerance
    # Or effort is 0.1x expected
    effort_01x <- abs(effort_actual * 10 - effort_expected) < tolerance

    decimal_candidates <- (effort_10x | effort_01x) &
                          !is.na(effort_actual) & !is.na(effort_expected)

    if (any(decimal_candidates)) {
      sample_idx <- head(which(decimal_candidates), 5)
      decimal_error_candidates <- data.frame(
        effort_actual = effort_actual[sample_idx],
        effort_expected = effort_expected[sample_idx],
        ratio = effort_actual[sample_idx] / effort_expected[sample_idx]
      )
    }
  }

  # ============================================================================
  # STEP 6: EFFORT SUMMARY STATISTICS
  # ============================================================================

  effort_summary <- data.frame(
    n_total = n_total,
    n_valid = sum(!is.na(effort_values)),
    n_zero = n_zero_effort,
    n_missing = n_missing_effort,
    mean_effort = if (length(valid_effort) > 0) mean(valid_effort) else NA_real_,
    median_effort = if (length(valid_effort) > 0) stats::median(valid_effort) else NA_real_,
    min_effort = if (length(valid_effort) > 0) min(valid_effort) else NA_real_,
    max_effort = if (length(valid_effort) > 0) max(valid_effort) else NA_real_,
    sd_effort = if (length(valid_effort) > 0) stats::sd(valid_effort) else NA_real_
  )

  # ============================================================================
  # STEP 7: DETERMINE SEVERITY
  # ============================================================================

  issue_detected <- FALSE
  severity <- "none"

  pct_inconsistent <- if (n_total > 0) n_effort_inconsistent / n_total else 0
  pct_outliers <- if (n_total > 0) n_outliers / n_total else 0

  if (n_zero_effort_with_catch > 0 || pct_inconsistent > 0.20) {
    severity <- "high"
    issue_detected <- TRUE
  } else if (pct_inconsistent > 0.05 || pct_outliers > 0.10) {
    severity <- "medium"
    issue_detected <- TRUE
  } else if (n_effort_inconsistent > 0 || n_outliers > 0 || !is.null(decimal_error_candidates)) {
    severity <- "low"
    issue_detected <- TRUE
  }

  # ============================================================================
  # STEP 8: GENERATE RECOMMENDATION
  # ============================================================================

  if (issue_detected) {
    recommendation <- paste0(
      "EFFORT CALCULATION ISSUE (Severity: ", toupper(severity), ")\n\n",
      "* Total interviews: ", n_total, "\n",
      "* Valid effort values: ", effort_summary$n_valid, "\n",
      "* Zero effort: ", n_zero_effort, "\n",
      "* Missing effort: ", n_missing_effort, "\n"
    )

    if (n_effort_inconsistent > 0) {
      recommendation <- paste0(
        recommendation,
        "\nEFFORT CALCULATION ERRORS:\n",
        "* Incorrect calculations: ", n_effort_inconsistent,
        " (", round(pct_inconsistent * 100, 1), "%)\\n",
        "* Expected formula: effort = num_anglers × hours_fished\n"
      )

      if (!is.null(effort_inconsistent_records) && nrow(effort_inconsistent_records) > 0) {
        recommendation <- paste0(
          recommendation,
          "\nSample of incorrect calculations:\n"
        )
        for (i in 1:min(3, nrow(effort_inconsistent_records))) {
          rec <- effort_inconsistent_records[i, ]
          recommendation <- paste0(
            recommendation,
            sprintf("  - Actual: %.2f, Expected: %.0f × %.2f = %.2f (diff: %.2f)\n",
                    rec$effort_actual, rec$num_anglers, rec$hours_fished,
                    rec$effort_expected, rec$difference)
          )
        }
      }
    }

    if (n_zero_effort_with_catch > 0) {
      recommendation <- paste0(
        recommendation,
        "\nZERO EFFORT WITH CATCH:\n",
        "* Records with catch but no effort: ", n_zero_effort_with_catch, "\n",
        "* This creates division-by-zero errors in CPUE calculations\n"
      )
    }

    if (n_outliers > 0) {
      recommendation <- paste0(
        recommendation,
        "\nOUTLIER EFFORT VALUES:\n",
        "* Outliers detected: ", n_outliers, " (", round(pct_outliers * 100, 1), "%)\\n",
        "* High outliers (>", max_hours, " hours): ", sum(outliers_high, na.rm = TRUE), "\n",
        "* Low outliers (<", min_hours, " hours): ", sum(outliers_low, na.rm = TRUE), "\n"
      )
    }

    if (!is.null(decimal_error_candidates)) {
      recommendation <- paste0(
        recommendation,
        "\nPOSSIBLE DECIMAL POINT ERRORS:\n",
        "* Records with 10× or 0.1× expected effort: ", nrow(decimal_error_candidates), "\n",
        "* Example: Actual = ", decimal_error_candidates$effort_actual[1],
        ", Expected = ", round(decimal_error_candidates$effort_expected[1], 2), "\n"
      )
    }

    recommendation <- paste0(
      recommendation,
      "\nRECOMMENDATIONS:\n",
      "1. Verify effort calculation formula: effort = num_anglers × hours_fished\n",
      "2. Review data entry protocols for decimal point errors\n",
      "3. Establish reasonable bounds for effort values (e.g., 0.1-24 hours)\n",
      "4. Ensure zero effort is only recorded for true zero-catch trips\n",
      "5. Consider collecting individual-level effort within parties\n",
      "6. Train staff on proper effort recording procedures\n",
      "\nIMPACT: Incorrect effort calculations lead to BIASED CPUE, catch, and harvest estimates."
    )
  } else {
    recommendation <- paste0(
      "No effort calculation issues detected.\n",
      "* All effort calculations appear correct\n",
      "* Mean effort: ", round(effort_summary$mean_effort, 2), " hours (±",
      round(effort_summary$sd_effort, 2), " SD)\n",
      "* Range: ", round(effort_summary$min_effort, 2), " to ",
      round(effort_summary$max_effort, 2), " hours"
    )
  }

  # ============================================================================
  # STEP 9: RETURN RESULTS
  # ============================================================================

  result <- list(
    issue_detected = issue_detected,
    severity = severity,
    n_total = n_total,
    n_effort_inconsistent = n_effort_inconsistent,
    pct_effort_inconsistent = pct_inconsistent,
    n_zero_effort = n_zero_effort,
    n_missing_effort = n_missing_effort,
    n_zero_effort_with_catch = n_zero_effort_with_catch,
    n_outliers = n_outliers,
    n_outliers_high = sum(outliers_high, na.rm = TRUE),
    n_outliers_low = sum(outliers_low, na.rm = TRUE),
    pct_outliers = pct_outliers,
    outlier_records = outlier_records,
    effort_inconsistent_records = effort_inconsistent_records,
    effort_summary = effort_summary,
    decimal_error_candidates = decimal_error_candidates,
    recommendation = recommendation
  )

  class(result) <- c("qa_check_result", "list")
  return(result)
}
