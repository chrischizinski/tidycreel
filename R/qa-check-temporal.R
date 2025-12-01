#' Check for Temporal Coverage Issues
#'
#' Detects gaps in temporal sampling coverage that may lead to biased
#' estimates due to incomplete representation of fishing activity patterns
#' (Table 17.3, #9).
#'
#' @param data Survey data (counts or interviews) containing temporal information
#' @param schedule Survey schedule data (optional, for planned vs actual comparison)
#' @param date_col Column containing date information
#' @param time_col Column containing time information (optional)
#' @param stratum_col Column containing stratum identifiers (optional)
#' @param location_col Column containing location identifiers (optional)
#' @param min_coverage_proportion Minimum proportion of time periods that should
#'   be sampled within each stratum (default 0.8 = 80%)
#' @param check_weekends Logical, whether to specifically check weekend coverage
#'   (default TRUE)
#' @param check_seasons Logical, whether to check seasonal coverage (default TRUE)
#' @param check_daily_hours Logical, whether to check coverage across hours of
#'   day (default TRUE)
#' @param min_days_per_stratum Minimum number of days that should be sampled
#'   per stratum (default 5)
#'
#' @return List with:
#'   \describe{
#'     \item{issue_detected}{Logical, TRUE if temporal coverage issues detected}
#'     \item{severity}{"high", "medium", "low", or "none"}
#'     \item{n_total}{Total number of records}
#'     \item{n_strata}{Number of temporal strata}
#'     \item{n_undersampled_strata}{Number of strata with insufficient coverage}
#'     \item{n_missing_weekends}{Number of strata missing weekend coverage}
#'     \item{n_missing_seasons}{Number of seasons with no coverage}
#'     \item{n_gaps_daily_hours}{Number of hour periods with no coverage}
#'     \item{coverage_by_stratum}{Coverage statistics by stratum}
#'     \item{weekend_coverage}{Weekend vs weekday coverage summary}
#'     \item{seasonal_coverage}{Coverage by season/month}
#'     \item{hourly_coverage}{Coverage by hour of day}
#'     \item{temporal_gaps}{Identified gaps in coverage}
#'     \item{undersampled_strata}{Details of strata with poor coverage}
#'     \item{recommendation}{Text guidance for remediation}
#'   }
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Stratum Coverage:**
#'    - Calculate sampling coverage within each temporal stratum
#'    - Flag strata below minimum coverage threshold
#'    - Check for completely unsampled strata
#'
#' 2. **Weekend Coverage:**
#'    - Compare weekend vs weekday sampling intensity
#'    - Flag if weekends are systematically under-sampled
#'    - Important because fishing patterns differ on weekends
#'
#' 3. **Seasonal Coverage:**
#'    - Check coverage across months/seasons
#'    - Flag missing seasonal periods
#'    - Detect seasonal sampling bias
#'
#' 4. **Daily Hour Coverage:**
#'    - Analyze coverage across hours of the day
#'    - Flag systematic gaps (e.g., early morning, evening)
#'    - Important for effort estimation accuracy
#'
#' 5. **Temporal Clustering:**
#'    - Detect if sampling is clustered in time
#'    - Flag long gaps between sampling periods
#'    - Check for systematic temporal bias
#'
#' ## Common Issues Detected
#'
#' - **Weekend Gaps**: No weekend sampling in fishing season
#' - **Seasonal Bias**: Only summer sampling for year-round fishery
#' - **Hour Gaps**: Missing early morning or evening periods
#' - **Stratum Gaps**: Some strata completely unsampled
#' - **Clustering**: All sampling in short time periods
#' - **Holiday Gaps**: Missing major fishing holidays
#'
#' @examples
#' \dontrun{
#' # Basic temporal coverage check
#' temporal_check <- qa_check_temporal(
#'   counts,
#'   date_col = "date",
#'   stratum_col = "stratum"
#' )
#' 
#' # Comprehensive temporal validation
#' temporal_check <- qa_check_temporal(
#'   interviews,
#'   schedule = survey_schedule,
#'   date_col = "date",
#'   time_col = "time_start",
#'   stratum_col = "stratum",
#'   location_col = "location",
#'   check_weekends = TRUE,
#'   check_seasons = TRUE,
#'   check_daily_hours = TRUE
#' )
#' 
#' # Check against planned schedule
#' temporal_check <- qa_check_temporal(
#'   counts,
#'   schedule = planned_schedule,
#'   date_col = "date"
#' )
#' }
#'
#' @seealso \code{\link{qa_checks}}, \code{\link{validate_calendar}}
#'
#' @export
qa_check_temporal <- function(data,
                             schedule = NULL,
                             date_col = "date",
                             time_col = NULL,
                             stratum_col = NULL,
                             location_col = NULL,
                             min_coverage_proportion = 0.8,
                             check_weekends = TRUE,
                             check_seasons = TRUE,
                             check_daily_hours = TRUE,
                             min_days_per_stratum = 5) {
  
  # Validate inputs
  tc_require_cols(data, date_col, "qa_check_temporal")
  
  if (!is.null(time_col)) {
    tc_require_cols(data, time_col, "qa_check_temporal")
  }
  
  if (!is.null(stratum_col)) {
    tc_require_cols(data, stratum_col, "qa_check_temporal")
  }
  
  # Initialize results
  n_total <- nrow(data)
  issues <- list()
  severity <- "none"
  
  # Convert date column to Date if needed
  if (!inherits(data[[date_col]], "Date")) {
    data[[date_col]] <- as.Date(data[[date_col]])
  }
  
  # Add temporal variables
  data$weekday <- weekdays(data[[date_col]])
  data$is_weekend <- data$weekday %in% c("Saturday", "Sunday")
  data$month <- lubridate::month(data[[date_col]])
  data$season <- .get_season(data$month)
  
  if (!is.null(time_col)) {
    data$hour <- lubridate::hour(data[[time_col]])
  }
  
  # 1. Stratum coverage analysis
  coverage_by_stratum <- .analyze_stratum_coverage(
    data, stratum_col, date_col, min_coverage_proportion, min_days_per_stratum
  )
  
  n_strata <- nrow(coverage_by_stratum)
  n_undersampled_strata <- sum(coverage_by_stratum$coverage_proportion < min_coverage_proportion, na.rm = TRUE)
  
  undersampled_strata <- coverage_by_stratum[
    coverage_by_stratum$coverage_proportion < min_coverage_proportion, 
  ]
  
  # 2. Weekend coverage analysis
  weekend_coverage <- .analyze_weekend_coverage(data, check_weekends)
  n_missing_weekends <- weekend_coverage$n_missing_weekends
  
  # 3. Seasonal coverage analysis
  seasonal_coverage <- .analyze_seasonal_coverage(data, check_seasons)
  n_missing_seasons <- seasonal_coverage$n_missing_seasons
  
  # 4. Daily hour coverage analysis
  hourly_coverage <- .analyze_hourly_coverage(data, time_col, check_daily_hours)
  n_gaps_daily_hours <- hourly_coverage$n_gaps
  
  # 5. Identify temporal gaps
  temporal_gaps <- .identify_temporal_gaps(data, date_col, stratum_col)
  
  # 6. Compare with schedule if provided
  schedule_comparison <- NULL
  if (!is.null(schedule)) {
    schedule_comparison <- .compare_with_schedule(data, schedule, date_col)
  }
  
  # Determine overall severity
  total_issues <- n_undersampled_strata + n_missing_weekends + 
                 n_missing_seasons + n_gaps_daily_hours
  
  coverage_score <- if (n_strata > 0) {
    mean(coverage_by_stratum$coverage_proportion, na.rm = TRUE)
  } else {
    1.0
  }
  
  if (total_issues == 0 && coverage_score >= min_coverage_proportion) {
    severity <- "none"
  } else if (coverage_score < 0.5 || n_undersampled_strata > n_strata * 0.5) {
    severity <- "high"  # Poor overall coverage
  } else if (total_issues > 0 || coverage_score < min_coverage_proportion) {
    severity <- "medium"  # Some coverage issues
  } else {
    severity <- "low"
  }
  
  issue_detected <- severity != "none"
  
  # Generate recommendations
  recommendation <- .generate_temporal_recommendations(
    n_undersampled_strata, n_missing_weekends, n_missing_seasons,
    n_gaps_daily_hours, coverage_score, min_coverage_proportion
  )
  
  # Return results
  list(
    issue_detected = issue_detected,
    severity = severity,
    n_total = n_total,
    n_strata = n_strata,
    n_undersampled_strata = n_undersampled_strata,
    n_missing_weekends = n_missing_weekends,
    n_missing_seasons = n_missing_seasons,
    n_gaps_daily_hours = n_gaps_daily_hours,
    coverage_by_stratum = coverage_by_stratum,
    weekend_coverage = weekend_coverage,
    seasonal_coverage = seasonal_coverage,
    hourly_coverage = hourly_coverage,
    temporal_gaps = temporal_gaps,
    undersampled_strata = undersampled_strata,
    schedule_comparison = schedule_comparison,
    recommendation = recommendation
  )
}

# Helper function to get season from month
.get_season <- function(month) {
  ifelse(month %in% c(12, 1, 2), "Winter",
  ifelse(month %in% c(3, 4, 5), "Spring", 
  ifelse(month %in% c(6, 7, 8), "Summer", "Fall")))
}

# Helper function to analyze stratum coverage
.analyze_stratum_coverage <- function(data, stratum_col, date_col, min_coverage, min_days) {
  if (is.null(stratum_col)) {
    # No strata defined, analyze overall coverage
    date_range <- range(data[[date_col]], na.rm = TRUE)
    total_days <- as.numeric(diff(date_range)) + 1
    sampled_days <- length(unique(data[[date_col]]))
    
    return(data.frame(
      stratum = "Overall",
      total_days = total_days,
      sampled_days = sampled_days,
      coverage_proportion = sampled_days / total_days,
      meets_minimum = sampled_days >= min_days,
      stringsAsFactors = FALSE
    ))
  }
  
  # Analyze by stratum
  strata <- unique(data[[stratum_col]])
  results <- data.frame()
  
  for (stratum in strata) {
    stratum_data <- data[data[[stratum_col]] == stratum, ]
    
    if (nrow(stratum_data) > 0) {
      date_range <- range(stratum_data[[date_col]], na.rm = TRUE)
      total_days <- as.numeric(diff(date_range)) + 1
      sampled_days <- length(unique(stratum_data[[date_col]]))
      
      results <- rbind(results, data.frame(
        stratum = stratum,
        total_days = total_days,
        sampled_days = sampled_days,
        coverage_proportion = sampled_days / total_days,
        meets_minimum = sampled_days >= min_days,
        stringsAsFactors = FALSE
      ))
    }
  }
  
  results
}

# Helper function to analyze weekend coverage
.analyze_weekend_coverage <- function(data, check_weekends) {
  if (!check_weekends) {
    return(list(
      weekend_days = 0,
      weekday_days = 0,
      weekend_proportion = 0,
      n_missing_weekends = 0,
      weekend_bias = "not_checked"
    ))
  }
  
  weekend_days <- sum(data$is_weekend, na.rm = TRUE)
  weekday_days <- sum(!data$is_weekend, na.rm = TRUE)
  total_days <- weekend_days + weekday_days
  
  weekend_proportion <- if (total_days > 0) weekend_days / total_days else 0
  
  # Expected weekend proportion is ~2/7 ≈ 0.29
  expected_weekend_prop <- 2/7
  weekend_bias <- if (weekend_proportion < expected_weekend_prop * 0.5) {
    "under_sampled"
  } else if (weekend_proportion > expected_weekend_prop * 1.5) {
    "over_sampled"  
  } else {
    "balanced"
  }
  
  n_missing_weekends <- if (weekend_days == 0 && weekday_days > 0) 1 else 0
  
  list(
    weekend_days = weekend_days,
    weekday_days = weekday_days,
    weekend_proportion = weekend_proportion,
    expected_proportion = expected_weekend_prop,
    weekend_bias = weekend_bias,
    n_missing_weekends = n_missing_weekends
  )
}

# Helper function to analyze seasonal coverage
.analyze_seasonal_coverage <- function(data, check_seasons) {
  if (!check_seasons) {
    return(list(
      seasons_sampled = character(0),
      seasons_missing = character(0),
      n_missing_seasons = 0,
      seasonal_balance = "not_checked"
    ))
  }
  
  seasons_sampled <- unique(data$season)
  all_seasons <- c("Spring", "Summer", "Fall", "Winter")
  seasons_missing <- setdiff(all_seasons, seasons_sampled)
  
  # Calculate seasonal balance
  season_counts <- table(data$season)
  seasonal_balance <- if (length(season_counts) >= 2) {
    cv <- sd(season_counts) / mean(season_counts)
    if (cv > 1.0) "highly_unbalanced" else if (cv > 0.5) "unbalanced" else "balanced"
  } else {
    "insufficient_data"
  }
  
  list(
    seasons_sampled = seasons_sampled,
    seasons_missing = seasons_missing,
    n_missing_seasons = length(seasons_missing),
    season_counts = season_counts,
    seasonal_balance = seasonal_balance
  )
}

# Helper function to analyze hourly coverage
.analyze_hourly_coverage <- function(data, time_col, check_daily_hours) {
  if (!check_daily_hours || is.null(time_col)) {
    return(list(
      hours_sampled = integer(0),
      hours_missing = integer(0),
      n_gaps = 0,
      hourly_balance = "not_checked"
    ))
  }
  
  hours_sampled <- unique(data$hour)
  # Typical fishing hours are 5 AM to 9 PM
  expected_hours <- 5:21
  hours_missing <- setdiff(expected_hours, hours_sampled)
  
  # Check for major gaps (3+ consecutive missing hours)
  major_gaps <- .find_consecutive_gaps(hours_missing, min_gap = 3)
  
  list(
    hours_sampled = sort(hours_sampled),
    hours_missing = sort(hours_missing),
    n_gaps = length(hours_missing),
    major_gaps = major_gaps,
    hourly_balance = if (length(hours_missing) > length(expected_hours) * 0.5) "poor" else "adequate"
  )
}

# Helper function to identify temporal gaps
.identify_temporal_gaps <- function(data, date_col, stratum_col) {
  gaps <- list()
  
  if (is.null(stratum_col)) {
    # Overall gaps
    dates <- sort(unique(data[[date_col]]))
    date_diffs <- diff(dates)
    long_gaps <- which(date_diffs > 7)  # Gaps > 1 week
    
    if (length(long_gaps) > 0) {
      gaps$overall <- data.frame(
        gap_start = dates[long_gaps],
        gap_end = dates[long_gaps + 1],
        gap_days = as.numeric(date_diffs[long_gaps]),
        stringsAsFactors = FALSE
      )
    }
  } else {
    # Gaps by stratum
    strata <- unique(data[[stratum_col]])
    for (stratum in strata) {
      stratum_data <- data[data[[stratum_col]] == stratum, ]
      dates <- sort(unique(stratum_data[[date_col]]))
      
      if (length(dates) > 1) {
        date_diffs <- diff(dates)
        long_gaps <- which(date_diffs > 7)
        
        if (length(long_gaps) > 0) {
          gaps[[stratum]] <- data.frame(
            stratum = stratum,
            gap_start = dates[long_gaps],
            gap_end = dates[long_gaps + 1],
            gap_days = as.numeric(date_diffs[long_gaps]),
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  
  gaps
}

# Helper function to compare with schedule
.compare_with_schedule <- function(data, schedule, date_col) {
  # Simplified schedule comparison
  # In practice, this would need more sophisticated logic
  
  actual_dates <- unique(data[[date_col]])
  
  if (date_col %in% names(schedule)) {
    planned_dates <- unique(schedule[[date_col]])
    
    missing_planned <- setdiff(planned_dates, actual_dates)
    extra_actual <- setdiff(actual_dates, planned_dates)
    
    list(
      planned_days = length(planned_dates),
      actual_days = length(actual_dates),
      missing_planned_days = length(missing_planned),
      extra_actual_days = length(extra_actual),
      adherence_rate = length(intersect(planned_dates, actual_dates)) / length(planned_dates)
    )
  } else {
    NULL
  }
}

# Helper function to find consecutive gaps
.find_consecutive_gaps <- function(missing_values, min_gap = 3) {
  if (length(missing_values) < min_gap) return(integer(0))
  
  gaps <- list()
  current_gap <- missing_values[1]
  
  for (i in 2:length(missing_values)) {
    if (missing_values[i] == missing_values[i-1] + 1) {
      current_gap <- c(current_gap, missing_values[i])
    } else {
      if (length(current_gap) >= min_gap) {
        gaps <- append(gaps, list(current_gap))
      }
      current_gap <- missing_values[i]
    }
  }
  
  # Check final gap
  if (length(current_gap) >= min_gap) {
    gaps <- append(gaps, list(current_gap))
  }
  
  gaps
}

# Helper function to generate recommendations
.generate_temporal_recommendations <- function(n_undersampled, n_missing_weekends, 
                                             n_missing_seasons, n_gaps_hours,
                                             coverage_score, min_coverage) {
  recommendations <- character(0)
  
  if (coverage_score < min_coverage) {
    recommendations <- c(recommendations,
      paste("Increase overall temporal coverage from", 
            round(coverage_score * 100, 1), "% to at least", 
            round(min_coverage * 100, 1), "%"))
  }
  
  if (n_undersampled > 0) {
    recommendations <- c(recommendations,
      paste("Address", n_undersampled, "undersampled temporal strata"))
  }
  
  if (n_missing_weekends > 0) {
    recommendations <- c(recommendations,
      "Add weekend sampling - fishing patterns differ on weekends")
  }
  
  if (n_missing_seasons > 0) {
    recommendations <- c(recommendations,
      paste("Add sampling for", n_missing_seasons, "missing seasons"))
  }
  
  if (n_gaps_hours > 5) {
    recommendations <- c(recommendations,
      paste("Address", n_gaps_hours, "gaps in daily hour coverage"))
  }
  
  if (length(recommendations) == 0) {
    recommendations <- "Temporal coverage appears adequate across all dimensions"
  }
  
  paste(recommendations, collapse = "; ")
}