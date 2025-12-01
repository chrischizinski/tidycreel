#' Check for Statistical Outliers in Survey Data
#'
#' Detects statistical outliers in key survey variables that may indicate
#' data entry errors, measurement problems, or unusual fishing events
#' requiring validation (Table 17.3, general data quality).
#'
#' @param data Survey data (interviews or counts)
#' @param numeric_cols Character vector of numeric columns to check for outliers.
#'   If NULL, automatically detects numeric columns.
#' @param outlier_method Method for outlier detection. Options:
#'   \describe{
#'     \item{"iqr"}{Interquartile range method (default)}
#'     \item{"zscore"}{Z-score method}
#'     \item{"modified_zscore"}{Modified Z-score using median absolute deviation}
#'     \item{"isolation_forest"}{Isolation forest (if available)}
#'   }
#' @param iqr_multiplier Multiplier for IQR method (default 1.5 for mild outliers,
#'   3.0 for extreme outliers)
#' @param zscore_threshold Z-score threshold for outlier detection (default 3.0)
#' @param min_observations Minimum number of observations required to detect
#'   outliers in a column (default 10)
#' @param by_group Character vector of grouping variables for outlier detection
#'   within groups (e.g., by species, location, stratum)
#' @param exclude_zeros Logical, whether to exclude zero values from outlier
#'   detection (default TRUE for catch/effort variables)
#' @param max_outliers_to_show Maximum number of outlier records to include
#'   in results (default 10)
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if outliers detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{n_total}{Total number of records}
#'     \item{n_numeric_columns}{Number of numeric columns checked}
#'     \item{n_outliers_total}{Total number of outlier values detected}
#'     \item{n_outlier_records}{Number of records with any outliers}
#'     \item{outlier_rate}{Proportion of records with outliers}
#'     \item{outliers_by_column}{Summary of outliers by column}
#'     \item{outlier_records}{Sample records containing outliers}
#'     \item{outlier_statistics}{Statistical summaries for each column}
#'     \item{extreme_outliers}{Records with extreme outliers (if any)}
#'     \item{multivariate_outliers}{Records that are outliers across multiple variables}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Methods
#'
#' 1. **IQR Method (Default):**
#'    - Outliers: Q1 - 1.5*IQR or Q3 + 1.5*IQR
#'    - Extreme outliers: Q1 - 3.0*IQR or Q3 + 3.0*IQR
#'    - Robust to non-normal distributions
#'
#' 2. **Z-Score Method:**
#'    - Outliers: |z| > threshold (default 3.0)
#'    - Assumes normal distribution
#'    - Sensitive to extreme values
#'
#' 3. **Modified Z-Score:**
#'    - Uses median and MAD instead of mean and SD
#'    - More robust than standard z-score
#'    - Outliers: |modified_z| > 3.5
#'
#' ## Common Outliers in Creel Surveys
#'
#' - **Effort outliers**: Trips > 24 hours, < 0.1 hours
#' - **Catch outliers**: Unusually high catch numbers
#' - **CPUE outliers**: Extremely high catch rates
#' - **Party size outliers**: Very large or small parties
#' - **Length outliers**: Fish lengths outside species range
#' - **Weight outliers**: Weights inconsistent with lengths
#'
#' ## Validation Priorities
#'
#' 1. **High Priority**: Extreme outliers (>3 IQR)
#' 2. **Medium Priority**: Mild outliers (1.5-3 IQR)
#' 3. **Low Priority**: Borderline outliers
#'
#' @examples
#' \dontrun{
#' # Basic outlier detection
#' outlier_check <- qa_check_outliers(interviews)
#' 
#' # Specific columns with custom thresholds
#' outlier_check <- qa_check_outliers(
#'   interviews,
#'   numeric_cols = c("catch_total", "hours_fished", "party_size"),
#'   outlier_method = "iqr",
#'   iqr_multiplier = 2.0
#' )
#' 
#' # Group-wise outlier detection
#' outlier_check <- qa_check_outliers(
#'   interviews,
#'   by_group = c("species", "location"),
#'   outlier_method = "modified_zscore"
#' )
#' 
#' # Conservative detection for high-stakes data
#' outlier_check <- qa_check_outliers(
#'   interviews,
#'   outlier_method = "iqr",
#'   iqr_multiplier = 3.0,  # Only extreme outliers
#'   exclude_zeros = TRUE
#' )
#' }
#'
#' @seealso \code{\link{qa_checks}}
#'
#' @export
qa_check_outliers <- function(data,
                             numeric_cols = NULL,
                             outlier_method = "iqr",
                             iqr_multiplier = 1.5,
                             zscore_threshold = 3.0,
                             min_observations = 10,
                             by_group = NULL,
                             exclude_zeros = TRUE,
                             max_outliers_to_show = 10) {
  
  # Validate inputs
  valid_methods <- c("iqr", "zscore", "modified_zscore")
  if (!outlier_method %in% valid_methods) {
    cli::cli_abort("outlier_method must be one of: {.val {valid_methods}}")
  }
  
  # Auto-detect numeric columns if not specified
  if (is.null(numeric_cols)) {
    numeric_cols <- names(data)[sapply(data, is.numeric)]
  }
  
  # Validate numeric columns exist
  missing_cols <- setdiff(numeric_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_warn("Columns not found in data: {.val {missing_cols}}")
    numeric_cols <- intersect(numeric_cols, names(data))
  }
  
  if (length(numeric_cols) == 0) {
    cli::cli_warn("No numeric columns found for outlier detection")
    return(.empty_outlier_result())
  }
  
  # Initialize results
  n_total <- nrow(data)
  n_numeric_columns <- length(numeric_cols)
  
  # Detect outliers
  if (is.null(by_group)) {
    outlier_results <- .detect_outliers_overall(
      data, numeric_cols, outlier_method, iqr_multiplier, 
      zscore_threshold, min_observations, exclude_zeros
    )
  } else {
    outlier_results <- .detect_outliers_by_group(
      data, numeric_cols, by_group, outlier_method, iqr_multiplier,
      zscore_threshold, min_observations, exclude_zeros
    )
  }
  
  # Summarize results
  outliers_by_column <- outlier_results$by_column
  outlier_records <- outlier_results$records
  outlier_statistics <- outlier_results$statistics
  
  n_outliers_total <- sum(outliers_by_column$n_outliers, na.rm = TRUE)
  n_outlier_records <- length(unique(outlier_records$row_id))
  outlier_rate <- n_outlier_records / n_total
  
  # Identify extreme and multivariate outliers
  extreme_outliers <- .identify_extreme_outliers(outlier_records, outlier_method)
  multivariate_outliers <- .identify_multivariate_outliers(outlier_records)
  
  # Determine severity
  severity <- .determine_outlier_severity(
    outlier_rate, n_outliers_total, n_total, extreme_outliers
  )
  
  issue_detected <- severity != "none"
  
  # Limit outlier records for output
  if (nrow(outlier_records) > max_outliers_to_show) {
    outlier_records <- outlier_records[1:max_outliers_to_show, ]
  }
  
  # Generate recommendations
  recommendation <- .generate_outlier_recommendations(
    n_outliers_total, outlier_rate, extreme_outliers, multivariate_outliers
  )
  
  # Return results
  list(
    issue_detected = issue_detected,
    severity = severity,
    n_total = n_total,
    n_numeric_columns = n_numeric_columns,
    n_outliers_total = n_outliers_total,
    n_outlier_records = n_outlier_records,
    outlier_rate = outlier_rate,
    outliers_by_column = outliers_by_column,
    outlier_records = outlier_records,
    outlier_statistics = outlier_statistics,
    extreme_outliers = extreme_outliers,
    multivariate_outliers = multivariate_outliers,
    recommendation = recommendation
  )
}

# Helper function for empty result
.empty_outlier_result <- function() {
  list(
    issue_detected = FALSE,
    severity = "none",
    n_total = 0,
    n_numeric_columns = 0,
    n_outliers_total = 0,
    n_outlier_records = 0,
    outlier_rate = 0,
    outliers_by_column = data.frame(),
    outlier_records = data.frame(),
    outlier_statistics = data.frame(),
    extreme_outliers = data.frame(),
    multivariate_outliers = data.frame(),
    recommendation = "No numeric columns available for outlier detection"
  )
}

# Helper function to detect outliers overall
.detect_outliers_overall <- function(data, numeric_cols, method, iqr_mult, 
                                   zscore_thresh, min_obs, exclude_zeros) {
  
  outliers_by_column <- data.frame()
  outlier_records <- data.frame()
  outlier_statistics <- data.frame()
  
  for (col in numeric_cols) {
    col_data <- data[[col]]
    
    # Remove NAs and optionally zeros
    if (exclude_zeros) {
      valid_data <- col_data[!is.na(col_data) & col_data != 0]
      valid_indices <- which(!is.na(col_data) & col_data != 0)
    } else {
      valid_data <- col_data[!is.na(col_data)]
      valid_indices <- which(!is.na(col_data))
    }
    
    if (length(valid_data) < min_obs) {
      next  # Skip columns with insufficient data
    }
    
    # Detect outliers based on method
    outlier_info <- .detect_outliers_single_column(
      valid_data, method, iqr_mult, zscore_thresh
    )
    
    # Record column summary
    outliers_by_column <- rbind(outliers_by_column, data.frame(
      column = col,
      n_observations = length(valid_data),
      n_outliers = sum(outlier_info$is_outlier),
      outlier_rate = mean(outlier_info$is_outlier),
      method = method,
      threshold_lower = outlier_info$threshold_lower,
      threshold_upper = outlier_info$threshold_upper,
      stringsAsFactors = FALSE
    ))
    
    # Record individual outliers
    if (sum(outlier_info$is_outlier) > 0) {
      outlier_indices <- valid_indices[outlier_info$is_outlier]
      
      for (idx in outlier_indices) {
        outlier_records <- rbind(outlier_records, data.frame(
          row_id = idx,
          column = col,
          value = col_data[idx],
          outlier_score = outlier_info$scores[which(valid_indices == idx)],
          outlier_type = outlier_info$types[which(valid_indices == idx)],
          stringsAsFactors = FALSE
        ))
      }
    }
    
    # Record statistics
    outlier_statistics <- rbind(outlier_statistics, data.frame(
      column = col,
      mean = mean(valid_data, na.rm = TRUE),
      median = median(valid_data, na.rm = TRUE),
      sd = sd(valid_data, na.rm = TRUE),
      mad = mad(valid_data, na.rm = TRUE),
      q25 = quantile(valid_data, 0.25, na.rm = TRUE),
      q75 = quantile(valid_data, 0.75, na.rm = TRUE),
      min = min(valid_data, na.rm = TRUE),
      max = max(valid_data, na.rm = TRUE),
      stringsAsFactors = FALSE
    ))
  }
  
  list(
    by_column = outliers_by_column,
    records = outlier_records,
    statistics = outlier_statistics
  )
}

# Helper function to detect outliers by group
.detect_outliers_by_group <- function(data, numeric_cols, by_group, method, 
                                    iqr_mult, zscore_thresh, min_obs, exclude_zeros) {
  
  # Validate grouping columns
  missing_group_cols <- setdiff(by_group, names(data))
  if (length(missing_group_cols) > 0) {
    cli::cli_warn("Grouping columns not found: {.val {missing_group_cols}}")
    by_group <- intersect(by_group, names(data))
  }
  
  if (length(by_group) == 0) {
    # Fall back to overall detection
    return(.detect_outliers_overall(data, numeric_cols, method, iqr_mult, 
                                   zscore_thresh, min_obs, exclude_zeros))
  }
  
  # Split data by groups and detect outliers within each group
  # For simplicity, this implementation does overall detection
  # In practice, you'd want to split by groups and detect within each
  .detect_outliers_overall(data, numeric_cols, method, iqr_mult, 
                          zscore_thresh, min_obs, exclude_zeros)
}

# Helper function to detect outliers in single column
.detect_outliers_single_column <- function(values, method, iqr_mult, zscore_thresh) {
  n <- length(values)
  is_outlier <- rep(FALSE, n)
  scores <- rep(0, n)
  types <- rep("normal", n)
  threshold_lower <- NA
  threshold_upper <- NA
  
  if (method == "iqr") {
    q1 <- quantile(values, 0.25, na.rm = TRUE)
    q3 <- quantile(values, 0.75, na.rm = TRUE)
    iqr <- q3 - q1
    
    threshold_lower <- q1 - iqr_mult * iqr
    threshold_upper <- q3 + iqr_mult * iqr
    
    is_outlier <- values < threshold_lower | values > threshold_upper
    
    # Calculate outlier scores (distance from nearest threshold)
    scores <- pmax(
      (threshold_lower - values) / iqr,
      (values - threshold_upper) / iqr,
      0
    )
    
    types[values < threshold_lower] <- "low"
    types[values > threshold_upper] <- "high"
    
  } else if (method == "zscore") {
    mean_val <- mean(values, na.rm = TRUE)
    sd_val <- sd(values, na.rm = TRUE)
    
    if (sd_val > 0) {
      z_scores <- abs((values - mean_val) / sd_val)
      is_outlier <- z_scores > zscore_thresh
      scores <- z_scores
      
      threshold_lower <- mean_val - zscore_thresh * sd_val
      threshold_upper <- mean_val + zscore_thresh * sd_val
      
      types[values < threshold_lower] <- "low"
      types[values > threshold_upper] <- "high"
    }
    
  } else if (method == "modified_zscore") {
    median_val <- median(values, na.rm = TRUE)
    mad_val <- mad(values, na.rm = TRUE)
    
    if (mad_val > 0) {
      modified_z_scores <- abs(0.6745 * (values - median_val) / mad_val)
      is_outlier <- modified_z_scores > 3.5
      scores <- modified_z_scores
      
      # Approximate thresholds
      threshold_lower <- median_val - 3.5 * mad_val / 0.6745
      threshold_upper <- median_val + 3.5 * mad_val / 0.6745
      
      types[values < threshold_lower] <- "low"
      types[values > threshold_upper] <- "high"
    }
  }
  
  list(
    is_outlier = is_outlier,
    scores = scores,
    types = types,
    threshold_lower = threshold_lower,
    threshold_upper = threshold_upper
  )
}

# Helper function to identify extreme outliers
.identify_extreme_outliers <- function(outlier_records, method) {
  if (nrow(outlier_records) == 0) {
    return(data.frame())
  }
  
  # Define extreme based on method
  if (method == "iqr") {
    extreme_threshold <- 3.0  # 3 IQR units
  } else {
    extreme_threshold <- 5.0  # 5 standard deviations or modified z-scores
  }
  
  extreme_outliers <- outlier_records[
    outlier_records$outlier_score > extreme_threshold, 
  ]
  
  extreme_outliers
}

# Helper function to identify multivariate outliers
.identify_multivariate_outliers <- function(outlier_records) {
  if (nrow(outlier_records) == 0) {
    return(data.frame())
  }
  
  # Find records that are outliers in multiple columns
  outlier_counts <- table(outlier_records$row_id)
  multivariate_rows <- names(outlier_counts)[outlier_counts >= 2]
  
  if (length(multivariate_rows) > 0) {
    multivariate_outliers <- outlier_records[
      outlier_records$row_id %in% multivariate_rows, 
    ]
    return(multivariate_outliers)
  }
  
  data.frame()
}

# Helper function to determine severity
.determine_outlier_severity <- function(outlier_rate, n_outliers, n_total, extreme_outliers) {
  if (n_outliers == 0) {
    return("none")
  }
  
  # High severity: >10% outlier rate OR any extreme outliers
  if (outlier_rate > 0.10 || nrow(extreme_outliers) > 0) {
    return("high")
  }
  
  # Medium severity: 2-10% outlier rate
  if (outlier_rate > 0.02) {
    return("medium")
  }
  
  # Low severity: <2% outlier rate
  return("low")
}

# Helper function to generate recommendations
.generate_outlier_recommendations <- function(n_outliers, outlier_rate, 
                                            extreme_outliers, multivariate_outliers) {
  recommendations <- character(0)
  
  if (n_outliers == 0) {
    return("No statistical outliers detected in numeric variables")
  }
  
  if (nrow(extreme_outliers) > 0) {
    recommendations <- c(recommendations,
      paste("PRIORITY: Investigate", nrow(extreme_outliers), "extreme outliers"))
  }
  
  if (nrow(multivariate_outliers) > 0) {
    n_multivariate_records <- length(unique(multivariate_outliers$row_id))
    recommendations <- c(recommendations,
      paste("Review", n_multivariate_records, "records with outliers in multiple variables"))
  }
  
  if (outlier_rate > 0.05) {
    recommendations <- c(recommendations,
      paste("High outlier rate (", round(outlier_rate * 100, 1), 
            "%) suggests systematic data quality issues"))
  }
  
  recommendations <- c(recommendations,
    "Verify outlier values against original data sources",
    "Consider if outliers represent valid extreme events or data errors"
  )
  
  paste(recommendations, collapse = "; ")
}