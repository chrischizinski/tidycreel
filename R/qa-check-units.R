#' Check for Mixed or Inconsistent Measurement Units
#'
#' Detects mixing of measurement units (inches vs mm) or precision levels,
#' which creates variability and unknown bias (Table 17.3, #6).
#'
#' @param interviews Interview data with measurements
#' @param length_col Column containing fish lengths (default "length_mm")
#' @param weight_col Column containing fish weights (optional)
#' @param species_col Column for species-specific checks (optional)
#' @param interviewer_col Column containing interviewer IDs (optional).
#'   Used to detect interviewer-specific unit preferences.
#' @param mm_range Numeric vector of length 2 specifying expected range for
#'   mm measurements (default c(50, 1000)). Values outside this suggest inches.
#' @param inch_range Numeric vector of length 2 specifying expected range for
#'   inch measurements (default c(2, 50)). Values in this range with low variance
#'   suggest inches.
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if unit issues detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{likely_units}{Detected measurement system: "mm", "inches", or "mixed"}
#'     \item{n_measurements}{Total number of length measurements}
#'     \item{n_likely_mm}{Number of measurements likely in mm}
#'     \item{n_likely_inches}{Number of measurements likely in inches}
#'     \item{precision_stats}{Summary of measurement precision (decimal places)}
#'     \item{mixed_unit_samples}{Sample of records with suspected wrong units}
#'     \item{interviewer_units}{Unit patterns by interviewer (if interviewer_col provided)}
#'     \item{suspicious_interviewers}{Interviewers using different units than majority}
#'     \item{species_unit_patterns}{Unit patterns by species (if species_col provided)}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Unit Detection:**
#'    - Examine length value distributions
#'    - Detect likely inch measurements (values 2-50 with low variance)
#'    - Detect likely mm measurements (values 50-1000)
#'    - Flag if both present in same dataset
#'
#' 2. **Precision Detection:**
#'    - Check for inconsistent precision (mix of 10mm, 1mm, 0.1mm)
#'    - Count decimal places to infer measurement precision
#'    - Recommend standardized precision levels
#'
#' 3. **Species-Specific:**
#'    - Flag suspicious length-species combinations (if species_col provided)
#'    - E.g., 500mm for a species typically 12" (likely wrong units)
#'
#' 4. **Interviewer Patterns:**
#'    - Check if different interviewers use different units
#'    - Flag interviewer-specific unit preferences
#'
#' ## Severity Levels
#' - **High:** Clear evidence of mixed units (>20% in wrong units)
#' - **Medium:** Moderate mixing (5-20% in wrong units) or inconsistent precision
#' - **Low:** Suspicious patterns (<5% in wrong units)
#' - **None:** Consistent units and precision
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Basic check
#' qa_result <- qa_check_units(
#'   interviews,
#'   length_col = "length_mm"
#' )
#'
#' # With interviewer analysis
#' qa_result <- qa_check_units(
#'   interviews,
#'   length_col = "length_mm",
#'   interviewer_col = "clerk_id",
#'   species_col = "species"
#' )
#'
#' if (qa_result$issue_detected) {
#'   print(qa_result$likely_units)
#'   print(qa_result$recommendation)
#' }
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_check_units <- function(
  interviews,
  length_col = "length_mm",
  weight_col = NULL,
  species_col = NULL,
  interviewer_col = NULL,
  mm_range = c(50, 1000),
  inch_range = c(2, 50)
) {

  # ============================================================================
  # STEP 1: INPUT VALIDATION
  # ============================================================================

  if (missing(interviews) || is.null(interviews) || nrow(interviews) == 0) {
    cli::cli_abort(c(
      "x" = "{.arg interviews} must be a non-empty data frame.",
      "i" = "Provide interview data with length measurements."
    ))
  }

  # Check length column exists
  if (!length_col %in% names(interviews)) {
    cli::cli_abort(c(
      "x" = "Length column {.val {length_col}} not found in data.",
      "i" = "Available columns: {.val {names(interviews)}}"
    ))
  }

  # Check optional columns
  if (!is.null(species_col) && !species_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Species column {.val {species_col}} not found.",
      "i" = "Skipping species-specific analysis."
    ))
    species_col <- NULL
  }

  if (!is.null(interviewer_col) && !interviewer_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Interviewer column {.val {interviewer_col}} not found.",
      "i" = "Skipping interviewer-specific analysis."
    ))
    interviewer_col <- NULL
  }

  if (!is.null(weight_col) && !weight_col %in% names(interviews)) {
    cli::cli_warn(c(
      "!" = "Weight column {.val {weight_col}} not found.",
      "i" = "Skipping weight-based validation."
    ))
    weight_col <- NULL
  }

  # ============================================================================
  # STEP 2: UNIT DETECTION
  # ============================================================================

  lengths <- interviews[[length_col]]
  lengths <- lengths[!is.na(lengths) & lengths > 0]  # Exclude NAs and zeros
  n_measurements <- length(lengths)

  if (n_measurements == 0) {
    cli::cli_abort(c(
      "x" = "No valid length measurements found in {.val {length_col}}.",
      "i" = "Column contains only NA or zero values."
    ))
  }

  # Classify each measurement as likely mm or inches
  likely_mm <- lengths >= mm_range[1] & lengths <= mm_range[2]
  likely_inches <- lengths >= inch_range[1] & lengths < mm_range[1]

  n_likely_mm <- sum(likely_mm)
  n_likely_inches <- sum(likely_inches)
  n_ambiguous <- n_measurements - n_likely_mm - n_likely_inches

  # Determine overall unit system
  pct_mm <- n_likely_mm / n_measurements
  pct_inches <- n_likely_inches / n_measurements

  if (pct_mm >= 0.8) {
    likely_units <- "mm"
  } else if (pct_inches >= 0.8) {
    likely_units <- "inches"
  } else {
    likely_units <- "mixed"
  }

  # ============================================================================
  # STEP 3: PRECISION ANALYSIS
  # ============================================================================

  # Count decimal places to infer precision
  decimal_places <- sapply(lengths, function(x) {
    str_val <- as.character(x)
    if (grepl("\\.", str_val)) {
      nchar(sub("^.*\\.", "", str_val))
    } else {
      0
    }
  })

  # Calculate CV handling division by zero
  mean_precision <- mean(decimal_places)
  precision_cv <- if (mean_precision > 0) {
    stats::sd(decimal_places) / mean_precision
  } else {
    0  # All integers = no variability
  }

  precision_stats <- data.frame(
    n_integer = sum(decimal_places == 0),
    n_one_decimal = sum(decimal_places == 1),
    n_two_decimal = sum(decimal_places == 2),
    n_three_plus = sum(decimal_places >= 3),
    precision_cv = precision_cv
  )

  # Flag inconsistent precision (high CV or multiple precision levels)
  inconsistent_precision <- (!is.na(precision_cv) && precision_cv > 0.5) ||
                             sum(precision_stats[1:4] > 0) > 2

  # ============================================================================
  # STEP 4: INTERVIEWER-SPECIFIC ANALYSIS
  # ============================================================================

  interviewer_units <- NULL
  suspicious_interviewers <- character(0)

  if (!is.null(interviewer_col)) {
    # Create dataframe for analysis
    interview_data <- data.frame(
      interviewer = interviews[[interviewer_col]],
      length = interviews[[length_col]],
      stringsAsFactors = FALSE
    )
    interview_data <- interview_data[!is.na(interview_data$length) &
                                      interview_data$length > 0, ]

    if (nrow(interview_data) > 0) {
      interviewer_units <- interview_data |>
        dplyr::group_by(interviewer) |>
        dplyr::summarise(
          n_measurements = dplyr::n(),
          n_likely_mm = sum(length >= mm_range[1] & length <= mm_range[2]),
          n_likely_inches = sum(length >= inch_range[1] & length < mm_range[1]),
          pct_mm = n_likely_mm / n_measurements,
          pct_inches = n_likely_inches / n_measurements,
          likely_unit = dplyr::case_when(
            pct_mm > 0.8 ~ "mm",
            pct_inches > 0.8 ~ "inches",
            TRUE ~ "mixed"
          ),
          .groups = "drop"
        ) |>
        dplyr::arrange(dplyr::desc(n_measurements))

      # Flag interviewers using different units than overall pattern
      # (at least 10 measurements and >30% in wrong unit)
      if (likely_units != "mixed") {
        # When overall is consistent, flag interviewers with >30% wrong units
        if (likely_units == "mm") {
          suspicious <- interviewer_units$n_measurements >= 10 &
                        interviewer_units$pct_inches > 0.3
        } else {
          suspicious <- interviewer_units$n_measurements >= 10 &
                        interviewer_units$pct_mm > 0.3
        }

        if (any(suspicious)) {
          suspicious_interviewers <- interviewer_units$interviewer[suspicious]
        }
      } else {
        # When overall is mixed, flag interviewers who are NOT mixed
        # (using only one unit system while others are mixed)
        suspicious <- interviewer_units$n_measurements >= 10 &
                      interviewer_units$likely_unit != "mixed"

        if (any(suspicious)) {
          suspicious_interviewers <- interviewer_units$interviewer[suspicious]
        }
      }
    }
  }

  # ============================================================================
  # STEP 5: SPECIES-SPECIFIC ANALYSIS
  # ============================================================================

  species_unit_patterns <- NULL

  if (!is.null(species_col)) {
    species_data <- data.frame(
      species = interviews[[species_col]],
      length = interviews[[length_col]],
      stringsAsFactors = FALSE
    )
    species_data <- species_data[!is.na(species_data$length) &
                                  species_data$length > 0, ]

    if (nrow(species_data) > 0) {
      species_unit_patterns <- species_data |>
        dplyr::group_by(species) |>
        dplyr::summarise(
          n_measurements = dplyr::n(),
          mean_length = mean(length),
          median_length = stats::median(length),
          min_length = min(length),
          max_length = max(length),
          n_likely_mm = sum(length >= mm_range[1] & length <= mm_range[2]),
          n_likely_inches = sum(length >= inch_range[1] & length < mm_range[1]),
          pct_mm = n_likely_mm / n_measurements,
          likely_unit = dplyr::case_when(
            pct_mm > 0.8 ~ "mm",
            pct_mm < 0.2 ~ "inches",
            TRUE ~ "mixed"
          ),
          .groups = "drop"
        ) |>
        dplyr::arrange(dplyr::desc(n_measurements))
    }
  }

  # ============================================================================
  # STEP 6: IDENTIFY SUSPICIOUS MEASUREMENTS
  # ============================================================================

  # Sample of measurements that might be in wrong units
  mixed_unit_samples <- NULL

  if (likely_units == "mixed" || (likely_units == "mm" && n_likely_inches > 0) ||
      (likely_units == "inches" && n_likely_mm > 0)) {

    # Identify suspicious measurements in original data
    all_lengths <- interviews[[length_col]]

    if (likely_units == "mm") {
      # Flag values that look like inches when we expect mm
      suspicious <- !is.na(all_lengths) & all_lengths > 0 &
                    all_lengths >= inch_range[1] & all_lengths < mm_range[1]
    } else if (likely_units == "inches") {
      # Flag values that look like mm when we expect inches
      suspicious <- !is.na(all_lengths) & all_lengths > 0 &
                    all_lengths >= mm_range[1] & all_lengths <= mm_range[2]
    } else {
      # Mixed: just take some samples from each unit type
      suspicious_mm <- !is.na(all_lengths) & all_lengths > 0 &
                       all_lengths >= mm_range[1] & all_lengths <= mm_range[2]
      suspicious_inches <- !is.na(all_lengths) & all_lengths > 0 &
                          all_lengths >= inch_range[1] & all_lengths < mm_range[1]
      suspicious <- suspicious_mm | suspicious_inches
    }

    suspicious_idx <- which(suspicious)

    if (length(suspicious_idx) > 0) {
      # Take up to 10 samples
      sample_idx <- head(suspicious_idx, 10)
      cols_to_include <- c(length_col)
      if (!is.null(species_col)) cols_to_include <- c(cols_to_include, species_col)
      if (!is.null(interviewer_col)) cols_to_include <- c(cols_to_include, interviewer_col)

      mixed_unit_samples <- interviews[sample_idx, cols_to_include, drop = FALSE]
    }
  }

  # ============================================================================
  # STEP 7: DETERMINE SEVERITY
  # ============================================================================

  issue_detected <- FALSE
  severity <- "none"

  # Calculate proportion in wrong units
  if (likely_units == "mm") {
    pct_wrong <- pct_inches
  } else if (likely_units == "inches") {
    pct_wrong <- pct_mm
  } else {
    # Mixed - use min as baseline
    pct_wrong <- min(pct_mm, pct_inches)
  }

  if (likely_units == "mixed" || pct_wrong > 0.20) {
    severity <- "high"
    issue_detected <- TRUE
  } else if (pct_wrong > 0.05 || inconsistent_precision) {
    severity <- "medium"
    issue_detected <- TRUE
  } else if (pct_wrong >= 0.01 || length(suspicious_interviewers) > 0) {
    severity <- "low"
    issue_detected <- TRUE
  }

  # ============================================================================
  # STEP 8: GENERATE RECOMMENDATION
  # ============================================================================

  if (issue_detected) {
    recommendation <- paste0(
      "MEASUREMENT UNIT ISSUE (Severity: ", toupper(severity), ")\n\n",
      "* Likely measurement system: ", toupper(likely_units), "\n",
      "* Total measurements: ", n_measurements, "\n",
      "* Likely mm: ", n_likely_mm, " (", round(pct_mm * 100, 1), "%)\n",
      "* Likely inches: ", n_likely_inches, " (", round(pct_inches * 100, 1), "%)\n",
      "* Ambiguous: ", n_ambiguous, " (", round(n_ambiguous/n_measurements * 100, 1), "%)\n\n"
    )

    if (likely_units == "mixed") {
      recommendation <- paste0(
        recommendation,
        "MIXED UNITS DETECTED:\n",
        "* Dataset contains mix of inches and millimeters\n",
        "* This creates systematic bias and unknown variability\n\n"
      )
    }

    if (inconsistent_precision) {
      recommendation <- paste0(
        recommendation,
        "INCONSISTENT PRECISION:\n",
        "* Integer values: ", precision_stats$n_integer, "\n",
        "* 1 decimal: ", precision_stats$n_one_decimal, "\n",
        "* 2 decimals: ", precision_stats$n_two_decimal, "\n",
        "* 3+ decimals: ", precision_stats$n_three_plus, "\n",
        "* Precision CV: ", round(precision_stats$precision_cv, 2), "\n\n"
      )
    }

    if (length(suspicious_interviewers) > 0) {
      recommendation <- paste0(
        recommendation,
        "INTERVIEWERS WITH DIFFERENT UNITS:\n"
      )
      for (int in suspicious_interviewers) {
        int_data <- interviewer_units[interviewer_units$interviewer == int, ]
        recommendation <- paste0(
          recommendation,
          "  - ", int, ": ", int_data$likely_unit, " (",
          int_data$n_measurements, " measurements)\n"
        )
      }
      recommendation <- paste0(recommendation, "\n")
    }

    recommendation <- paste0(
      recommendation,
      "RECOMMENDATIONS:\n",
      "1. Review data entry protocols to ensure consistent units\n",
      "2. Standardize measurement equipment (measuring boards/calipers)\n",
      "3. Train all staff on consistent measurement precision\n",
      "4. If mixed units detected, convert all to consistent system (preferably mm)\n",
      "5. Document measurement protocol in survey manual\n",
      "6. Add data entry validation to prevent unit mixing\n",
      "\nIMPACT: Mixed units create UNKNOWN BIAS and inflate variability in size estimates."
    )
  } else {
    recommendation <- paste0(
      "No measurement unit issues detected.\n",
      "* Likely units: ", likely_units, "\n",
      "* Measurements appear consistent with declared units"
    )
  }

  # ============================================================================
  # STEP 9: RETURN RESULTS
  # ============================================================================

  result <- list(
    issue_detected = issue_detected,
    severity = severity,
    likely_units = likely_units,
    n_measurements = n_measurements,
    n_likely_mm = n_likely_mm,
    n_likely_inches = n_likely_inches,
    n_ambiguous = n_ambiguous,
    pct_mm = pct_mm,
    pct_inches = pct_inches,
    precision_stats = precision_stats,
    inconsistent_precision = inconsistent_precision,
    mixed_unit_samples = mixed_unit_samples,
    interviewer_units = interviewer_units,
    suspicious_interviewers = suspicious_interviewers,
    species_unit_patterns = species_unit_patterns,
    recommendation = recommendation
  )

  class(result) <- c("qa_check_result", "list")
  return(result)
}
