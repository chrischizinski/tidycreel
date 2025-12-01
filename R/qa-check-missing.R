#' Check for Missing Data Patterns
#'
#' Analyzes missing data patterns to detect systematic gaps, non-response bias,
#' and data collection issues that may affect survey estimates (Table 17.3,
#' general data completeness).
#'
#' @param data Survey data (interviews, counts, or other datasets)
#' @param required_cols Character vector of columns that should never be missing
#' @param important_cols Character vector of columns where missing data is
#'   concerning but not critical
#' @param by_group Character vector of grouping variables to analyze missing
#'   patterns within groups (e.g., by stratum, location, interviewer)
#' @param missing_threshold Proportion threshold above which missing data is
#'   flagged as problematic (default 0.05 = 5%)
#' @param pattern_threshold Minimum number of records required to identify
#'   a systematic missing pattern (default 5)
#' @param check_monotonic Logical, whether to check for monotonic missing
#'   patterns (increasing missingness over time) (default TRUE)
#' @param date_col Column containing date information for temporal analysis
#' @param max_patterns_to_show Maximum number of missing patterns to include
#'   in results (default 10)
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if missing data issues detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{n_total}{Total number of records}
#'     \item{n_complete_records}{Number of records with no missing values}
#'     \item{completeness_rate}{Proportion of complete records}
#'     \item{missing_by_column}{Missing data summary by column}
#'     \item{missing_patterns}{Common missing data patterns}
#'     \item{systematic_patterns}{Identified systematic missing patterns}
#'     \item{temporal_patterns}{Missing data patterns over time (if date provided)}
#'     \item{group_patterns}{Missing patterns by group (if grouping provided)}
#'     \item{critical_missing}{Records missing required columns}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Missing Data Analysis
#'
#' 1. **Overall Completeness:**
#'    - Calculate missing data rates by column
#'    - Identify columns with excessive missing data
#'    - Flag records missing critical information
#'
#' 2. **Missing Patterns:**
#'    - Identify common combinations of missing variables
#'    - Detect systematic patterns (e.g., always missing together)
#'    - Flag unusual missing patterns
#'
#' 3. **Temporal Patterns:**
#'    - Analyze missing data trends over time
#'    - Detect periods with high missing rates
#'    - Identify monotonic missing patterns
#'
#' 4. **Group Patterns:**
#'    - Compare missing rates across groups
#'    - Identify groups with systematic missing data
#'    - Detect interviewer or location effects
#'
#' 5. **Non-Response Analysis:**
#'    - Identify potential non-response bias
#'    - Flag systematic refusal patterns
#'    - Analyze partial vs complete non-response
#'
#' ## Common Missing Data Issues
#'
#' - **Required fields missing**: Date, location, basic catch info
#' - **Systematic refusal**: Anglers refusing certain questions
#' - **Interviewer effects**: Some interviewers missing more data
#' - **Temporal trends**: Increasing missingness over survey period
#' - **Equipment issues**: Missing data during certain periods
#' - **Training issues**: New staff missing more data
#'
#' @examples
#' \dontrun{
#' # Basic missing data analysis
#' missing_check <- qa_check_missing(interviews)
#' 
#' # With required and important columns specified
#' missing_check <- qa_check_missing(
#'   interviews,
#'   required_cols = c("date", "location", "catch_total"),
#'   important_cols = c("species", "length", "weight"),
#'   missing_threshold = 0.10
#' )
#' 
#' # Group-wise analysis
#' missing_check <- qa_check_missing(
#'   interviews,
#'   by_group = c("interviewer", "location"),
#'   date_col = "date",
#'   check_monotonic = TRUE
#' )
#' 
#' # Temporal pattern analysis
#' missing_check <- qa_check_missing(
#'   interviews,
#'   date_col = "survey_date",
#'   check_monotonic = TRUE,
#'   missing_threshold = 0.05
#' )
#' }
#'
#' @seealso \code{\link{qa_checks}}
#'
#' @export
qa_check_missing <- function(data,
                            required_cols = NULL,
                            important_cols = NULL,
                            by_group = NULL,
                            missing_threshold = 0.05,
                            pattern_threshold = 5,
                            check_monotonic = TRUE,
                            date_col = NULL,
                            max_patterns_to_show = 10) {
  
  # Initialize results
  n_total <- nrow(data)
  
  if (n_total == 0) {
    return(.empty_missing_result())
  }
  
  # 1. Overall completeness analysis
  missing_by_column <- .analyze_missing_by_column(
    data, required_cols, important_cols, missing_threshold
  )
  
  n_complete_records <- sum(complete.cases(data))
  completeness_rate <- n_complete_records / n_total
  
  # 2. Missing pattern analysis
  missing_patterns <- .analyze_missing_patterns(
    data, pattern_threshold, max_patterns_to_show
  )
  
  # 3. Systematic pattern detection
  systematic_patterns <- .detect_systematic_patterns(
    data, missing_patterns, pattern_threshold
  )
  
  # 4. Temporal pattern analysis
  temporal_patterns <- NULL
  if (check_monotonic && !is.null(date_col) && date_col %in% names(data)) {
    temporal_patterns <- .analyze_temporal_missing_patterns(
      data, date_col, missing_threshold
    )
  }
  
  # 5. Group pattern analysis
  group_patterns <- NULL
  if (!is.null(by_group)) {
    group_patterns <- .analyze_group_missing_patterns(
      data, by_group, missing_threshold
    )
  }
  
  # 6. Critical missing data
  critical_missing <- .identify_critical_missing(data, required_cols)
  
  # Determine severity
  severity <- .determine_missing_severity(
    missing_by_column, completeness_rate, systematic_patterns, 
    critical_missing, missing_threshold
  )
  
  issue_detected <- severity != "none"
  
  # Generate recommendations
  recommendation <- .generate_missing_recommendations(
    missing_by_column, systematic_patterns, temporal_patterns,
    group_patterns, critical_missing, missing_threshold
  )
  
  # Return results
  list(
    issue_detected = issue_detected,
    severity = severity,
    n_total = n_total,
    n_complete_records = n_complete_records,
    completeness_rate = completeness_rate,
    missing_by_column = missing_by_column,
    missing_patterns = missing_patterns,
    systematic_patterns = systematic_patterns,
    temporal_patterns = temporal_patterns,
    group_patterns = group_patterns,
    critical_missing = critical_missing,
    recommendation = recommendation
  )
}

# Helper function for empty result
.empty_missing_result <- function() {
  list(
    issue_detected = FALSE,
    severity = "none",
    n_total = 0,
    n_complete_records = 0,
    completeness_rate = 1.0,
    missing_by_column = data.frame(),
    missing_patterns = data.frame(),
    systematic_patterns = data.frame(),
    temporal_patterns = NULL,
    group_patterns = NULL,
    critical_missing = data.frame(),
    recommendation = "No data available for missing pattern analysis"
  )
}

# Helper function to analyze missing by column
.analyze_missing_by_column <- function(data, required_cols, important_cols, threshold) {
  n_total <- nrow(data)
  
  missing_summary <- data.frame()
  
  for (col in names(data)) {
    n_missing <- sum(is.na(data[[col]]))
    missing_rate <- n_missing / n_total
    
    # Determine column importance
    importance <- if (col %in% required_cols) {
      "required"
    } else if (col %in% important_cols) {
      "important"
    } else {
      "optional"
    }
    
    # Determine if problematic
    is_problematic <- (importance == "required" && n_missing > 0) ||
                     (importance == "important" && missing_rate > threshold) ||
                     (importance == "optional" && missing_rate > threshold * 2)
    
    missing_summary <- rbind(missing_summary, data.frame(
      column = col,
      n_missing = n_missing,
      missing_rate = missing_rate,
      importance = importance,
      is_problematic = is_problematic,
      stringsAsFactors = FALSE
    ))
  }
  
  # Sort by missing rate (descending)
  missing_summary <- missing_summary[order(-missing_summary$missing_rate), ]
  
  missing_summary
}

# Helper function to analyze missing patterns
.analyze_missing_patterns <- function(data, pattern_threshold, max_patterns) {
  # Create missing indicator matrix
  missing_matrix <- is.na(data)
  
  # Convert to pattern strings
  pattern_strings <- apply(missing_matrix, 1, function(row) {
    paste(ifelse(row, "1", "0"), collapse = "")
  })
  
  # Count patterns
  pattern_counts <- table(pattern_strings)
  pattern_counts <- sort(pattern_counts, decreasing = TRUE)
  
  # Keep only patterns above threshold
  significant_patterns <- pattern_counts[pattern_counts >= pattern_threshold]
  
  if (length(significant_patterns) == 0) {
    return(data.frame())
  }
  
  # Limit to max patterns
  if (length(significant_patterns) > max_patterns) {
    significant_patterns <- significant_patterns[1:max_patterns]
  }
  
  # Create pattern summary
  pattern_summary <- data.frame()
  
  for (i in seq_along(significant_patterns)) {
    pattern <- names(significant_patterns)[i]
    count <- significant_patterns[i]
    
    # Decode pattern
    pattern_bits <- strsplit(pattern, "")[[1]]
    missing_cols <- names(data)[pattern_bits == "1"]
    
    pattern_summary <- rbind(pattern_summary, data.frame(
      pattern_id = i,
      pattern = pattern,
      count = count,
      proportion = count / nrow(data),
      n_missing_cols = sum(pattern_bits == "1"),
      missing_columns = paste(missing_cols, collapse = ", "),
      stringsAsFactors = FALSE
    ))
  }
  
  pattern_summary
}

# Helper function to detect systematic patterns
.detect_systematic_patterns <- function(data, missing_patterns, threshold) {
  if (nrow(missing_patterns) == 0) {
    return(data.frame())
  }
  
  systematic <- data.frame()
  
  # Look for patterns with multiple missing columns
  multi_missing <- missing_patterns[missing_patterns$n_missing_cols > 1, ]
  
  if (nrow(multi_missing) > 0) {
    for (i in seq_len(nrow(multi_missing))) {
      pattern <- multi_missing[i, ]
      
      # Check if this represents a systematic issue
      if (pattern$count >= threshold && pattern$proportion > 0.02) {
        systematic <- rbind(systematic, data.frame(
          pattern_type = "multi_column_missing",
          description = paste("Missing:", pattern$missing_columns),
          count = pattern$count,
          proportion = pattern$proportion,
          severity = if (pattern$proportion > 0.10) "high" else if (pattern$proportion > 0.05) "medium" else "low",
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  
  systematic
}

# Helper function to analyze temporal missing patterns
.analyze_temporal_missing_patterns <- function(data, date_col, threshold) {
  if (!date_col %in% names(data)) {
    return(NULL)
  }
  
  # Convert date column
  dates <- as.Date(data[[date_col]])
  
  if (all(is.na(dates))) {
    return(NULL)
  }
  
  # Calculate missing rates by date
  date_missing_rates <- data.frame()
  
  unique_dates <- sort(unique(dates[!is.na(dates)]))
  
  for (date in unique_dates) {
    date_data <- data[dates == date & !is.na(dates), ]
    
    if (nrow(date_data) > 0) {
      overall_missing_rate <- 1 - mean(complete.cases(date_data))
      
      date_missing_rates <- rbind(date_missing_rates, data.frame(
        date = as.Date(date, origin = "1970-01-01"),
        n_records = nrow(date_data),
        missing_rate = overall_missing_rate,
        stringsAsFactors = FALSE
      ))
    }
  }
  
  if (nrow(date_missing_rates) == 0) {
    return(NULL)
  }
  
  # Check for monotonic trend
  if (nrow(date_missing_rates) >= 3) {
    correlation <- cor(as.numeric(date_missing_rates$date), 
                      date_missing_rates$missing_rate, 
                      use = "complete.obs")
    
    monotonic_trend <- if (is.na(correlation)) {
      "insufficient_data"
    } else if (correlation > 0.3) {
      "increasing"
    } else if (correlation < -0.3) {
      "decreasing"
    } else {
      "stable"
    }
  } else {
    monotonic_trend <- "insufficient_data"
  }
  
  # Identify problematic periods
  problematic_dates <- date_missing_rates[
    date_missing_rates$missing_rate > threshold, 
  ]
  
  list(
    by_date = date_missing_rates,
    monotonic_trend = monotonic_trend,
    trend_correlation = if (exists("correlation")) correlation else NA,
    problematic_periods = problematic_dates,
    n_problematic_dates = nrow(problematic_dates)
  )
}

# Helper function to analyze group missing patterns
.analyze_group_missing_patterns <- function(data, by_group, threshold) {
  # Validate grouping columns
  missing_group_cols <- setdiff(by_group, names(data))
  if (length(missing_group_cols) > 0) {
    cli::cli_warn("Grouping columns not found: {.val {missing_group_cols}}")
    by_group <- intersect(by_group, names(data))
  }
  
  if (length(by_group) == 0) {
    return(NULL)
  }
  
  # For simplicity, analyze by first grouping variable
  group_col <- by_group[1]
  groups <- unique(data[[group_col]])
  groups <- groups[!is.na(groups)]
  
  group_summary <- data.frame()
  
  for (group in groups) {
    group_data <- data[data[[group_col]] == group & !is.na(data[[group_col]]), ]
    
    if (nrow(group_data) > 0) {
      completeness_rate <- mean(complete.cases(group_data))
      missing_rate <- 1 - completeness_rate
      
      group_summary <- rbind(group_summary, data.frame(
        group_variable = group_col,
        group_value = as.character(group),
        n_records = nrow(group_data),
        missing_rate = missing_rate,
        completeness_rate = completeness_rate,
        is_problematic = missing_rate > threshold,
        stringsAsFactors = FALSE
      ))
    }
  }
  
  # Sort by missing rate (descending)
  if (nrow(group_summary) > 0) {
    group_summary <- group_summary[order(-group_summary$missing_rate), ]
  }
  
  group_summary
}

# Helper function to identify critical missing
.identify_critical_missing <- function(data, required_cols) {
  if (is.null(required_cols) || length(required_cols) == 0) {
    return(data.frame())
  }
  
  # Check which required columns exist
  existing_required <- intersect(required_cols, names(data))
  
  if (length(existing_required) == 0) {
    return(data.frame())
  }
  
  # Find records missing any required columns
  missing_required <- data.frame()
  
  for (i in seq_len(nrow(data))) {
    row_data <- data[i, existing_required, drop = FALSE]
    missing_cols <- existing_required[is.na(row_data)]
    
    if (length(missing_cols) > 0) {
      missing_required <- rbind(missing_required, data.frame(
        row_id = i,
        n_missing_required = length(missing_cols),
        missing_required_cols = paste(missing_cols, collapse = ", "),
        stringsAsFactors = FALSE
      ))
    }
  }
  
  missing_required
}

# Helper function to determine severity
.determine_missing_severity <- function(missing_by_column, completeness_rate, 
                                      systematic_patterns, critical_missing, threshold) {
  
  # High severity conditions
  if (completeness_rate < 0.8 || nrow(critical_missing) > 0) {
    return("high")
  }
  
  # Check for high missing rates in important columns
  problematic_cols <- sum(missing_by_column$is_problematic, na.rm = TRUE)
  high_missing_cols <- sum(missing_by_column$missing_rate > threshold * 2, na.rm = TRUE)
  
  if (high_missing_cols > 0 || nrow(systematic_patterns) > 0) {
    return("medium")
  }
  
  if (problematic_cols > 0 || completeness_rate < 0.95) {
    return("low")
  }
  
  return("none")
}

# Helper function to generate recommendations
.generate_missing_recommendations <- function(missing_by_column, systematic_patterns,
                                            temporal_patterns, group_patterns,
                                            critical_missing, threshold) {
  recommendations <- character(0)
  
  # Critical missing data
  if (nrow(critical_missing) > 0) {
    recommendations <- c(recommendations,
      paste("CRITICAL: Address", nrow(critical_missing), "records missing required fields"))
  }
  
  # High missing rate columns
  high_missing <- missing_by_column[missing_by_column$missing_rate > threshold, ]
  if (nrow(high_missing) > 0) {
    recommendations <- c(recommendations,
      paste("Review", nrow(high_missing), "columns with high missing rates"))
  }
  
  # Systematic patterns
  if (nrow(systematic_patterns) > 0) {
    recommendations <- c(recommendations,
      paste("Investigate", nrow(systematic_patterns), "systematic missing patterns"))
  }
  
  # Temporal trends
  if (!is.null(temporal_patterns) && temporal_patterns$monotonic_trend %in% c("increasing", "decreasing")) {
    recommendations <- c(recommendations,
      paste("Address", temporal_patterns$monotonic_trend, "missing data trend over time"))
  }
  
  # Group differences
  if (!is.null(group_patterns)) {
    problematic_groups <- sum(group_patterns$is_problematic, na.rm = TRUE)
    if (problematic_groups > 0) {
      recommendations <- c(recommendations,
        paste("Address missing data issues in", problematic_groups, "groups"))
    }
  }
  
  if (length(recommendations) == 0) {
    recommendations <- "Missing data patterns appear acceptable"
  } else {
    recommendations <- c(recommendations,
      "Consider multiple imputation or sensitivity analysis for missing data")
  }
  
  paste(recommendations, collapse = "; ")
}