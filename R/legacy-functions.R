#' Legacy Creel Analysis Functions
#'
#' These functions implement core creel survey analysis methods based on
#' established statistical foundations from Pollock et al. (1994) and
#' contemporary survey sampling theory. They provide the computational
#' backbone for effort and catch estimation in recreational fisheries.
#'
#' @name legacy-functions
#' @aliases strata_effort_estimator strata_catch_estimator daily_effort
#'   party_fish read_parameters
NULL

#' Strata-Level Effort Estimator
#'
#' Estimates total fishing effort by stratum using design-based inference
#' methods. This function implements the ratio estimator approach commonly
#' used in creel surveys to account for incomplete sampling coverage.
#'
#' @param design A creel design object created by \code{design_access()} or
#'   \code{design_roving()}.
#' @param strata_vars Character vector specifying stratification variables.
#'   Defaults to the strata variables used in the design object.
#' @param effort_type Character specifying the type of effort to estimate.
#'   Options: "angler_hours" (default), "angler_trips", "boat_hours".
#' @param confidence_level Numeric confidence level for interval estimation.
#'   Default is 0.95.
#'
#' @return A tibble containing:
#'   \describe{
#'     \item{strata}{Strata identifiers}
#'     \item{effort_estimate}{Point estimate of total effort}
#'     \item{standard_error}{Standard error of the estimate}
#'     \item{confidence_lower}{Lower confidence bound}
#'     \item{confidence_upper}{Upper confidence bound}
#'     \item{sample_size}{Number of observations in stratum}
#'     \item{design_effect}{Design effect due to weighting}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create design object
#' design <- design_access(interviews, calendar)
#' 
#' # Estimate effort by date and location
#' effort_results <- strata_effort_estimator(
#'   design = design,
#'   strata_vars = c("date", "location"),
#'   effort_type = "angler_hours"
#' )
#' }
strata_effort_estimator <- function(design, 
                                   strata_vars = NULL,
                                   effort_type = "angler_hours",
                                   confidence_level = 0.95) {
  
  # Validate design object
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a creel design object")
  }
  
  # Set default strata variables
  if (is.null(strata_vars)) {
    strata_vars <- design$strata_vars
  }
  
  # Validate effort type
  effort_type <- match.arg(effort_type,
                         choices = c("angler_hours", "angler_trips", "boat_hours"))
  
  # Extract interview data
  interviews <- design$interviews
  weights <- design$design_weights
  
  # Calculate effort measures based on type
  if (effort_type == "angler_hours") {
    effort_measure <- interviews$hours_fished * interviews$party_size
  } else if (effort_type == "angler_trips") {
    effort_measure <- rep(1, nrow(interviews))  # Each interview is one trip
  } else if (effort_type == "boat_hours") {
    effort_measure <- interviews$hours_fished
  }
  
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)
  
  # Calculate stratum totals using survey methods
  stratum_results <- tibble::tibble()
  
  unique_strata <- unique(strata_id)
  
  for (stratum in unique_strata) {
    stratum_idx <- strata_id == stratum
    
    if (sum(stratum_idx) > 0) {
      stratum_weights <- weights[stratum_idx]
      stratum_effort <- effort_measure[stratum_idx]
      
      # Calculate weighted total
      weighted_total <- sum(stratum_weights * stratum_effort)
      
      # Calculate standard error using Taylor linearization
      stratum_mean_weight <- mean(stratum_weights)
      stratum_var <- var(stratum_weights * stratum_effort)
      stratum_se <- sqrt(stratum_var * length(stratum_weights))
      
      # Calculate confidence interval
      alpha <- 1 - confidence_level
      t_critical <- qt(1 - alpha/2, df = sum(stratum_idx) - 1)
      margin_error <- t_critical * stratum_se
        
      # Create stratum identifier columns
      stratum_data <- interviews[strata_vars][stratum_idx, , drop = FALSE]
      stratum_values <- stratum_data[1, , drop = FALSE]
      
      stratum_result <- tibble::tibble(
        !!!stratum_values,
        effort_estimate = weighted_total,
        standard_error = stratum_se,
        confidence_lower = weighted_total - margin_error,
        confidence_upper = weighted_total + margin_error,
        sample_size = sum(stratum_idx),
        design_effect = 1  # Simplified for now
      )
      
      stratum_results <- dplyr::bind_rows(stratum_results, stratum_result)
    }
  }
  
  return(stratum_results)
}

#' Strata-Level Catch Estimator
#'
#' Estimates total catch and harvest by species and stratum using design-based
#' inference methods. Implements ratio-of-means and mean-of-ratios estimators
#' appropriate for different survey designs.
#'
#' @param design A creel design object created by \code{design_access()} or
#'   \code{design_roving()}.
#' @param catch_type Character specifying what to estimate.
#'   Options: "catch" (total caught), "harvest" (kept), "release" (released).
#' @param species Character vector of species to estimate. If NULL, estimates
#'   for all species found in the data.
#' @param strata_vars Character vector specifying stratification variables.
#'   Defaults to the strata variables used in the design object.
#' @param estimator_type Character specifying estimator type.
#'   Options: "ratio_of_means" (default for incomplete trips),
#'   "mean_of_ratios" (for complete trips).
#' @param confidence_level Numeric confidence level for interval estimation.
#'   Default is 0.95.
#'
#' @return A tibble containing:
#'   \describe{
#'     \item{species}{Species identifier}
#'     \item{strata}{Strata identifiers}
#'     \item{catch_estimate}{Point estimate of total catch/harvest}
#'     \item{standard_error}{Standard error of the estimate}
#'     \item{confidence_lower}{Lower confidence bound}
#'     \item{confidence_upper}{Upper confidence bound}
#'     \item{sample_size}{Number of observations in stratum}
#'     \item{cpue_estimate}{Catch per unit effort}
#'     \item{effort_estimate}{Total effort in stratum}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Estimate harvest by species and date
#' harvest_results <- strata_catch_estimator(
#'   design = design,
#'   catch_type = "harvest",
#'   strata_vars = c("date", "location")
#' )
#' }
strata_catch_estimator <- function(design,
                                 catch_type = "catch",
                                 species = NULL,
                                 strata_vars = NULL,
                                 estimator_type = "ratio_of_means",
                                 confidence_level = 0.95) {
  
  # Validate design object
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a creel design object")
  }
  
  # Set default strata variables
  if (is.null(strata_vars)) {
    strata_vars <- design$strata_vars
  }
  
  # Validate parameters
  catch_type <- match.arg(catch_type,
                        choices = c("catch", "harvest", "release"))
  estimator_type <- match.arg(estimator_type,
                            choices = c("ratio_of_means", "mean_of_ratios"))
  
  # Extract interview data
  interviews <- design$interviews
  weights <- design$design_weights
  
  # Determine catch variable based on type
  catch_var <- switch(catch_type,
                    catch = "total_catch",
                    harvest = "harvest",
                    release = "release")
  
  # Filter for requested species
  if (!is.null(species)) {
    interviews <- interviews[interviews$species %in% species, ]
  }
  
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)
  
  # Calculate catch estimates by stratum and species
  results <- tibble::tibble()
  
  unique_species <- unique(interviews$species)
  unique_strata <- unique(strata_id)
  
  for (sp in unique_species) {
    sp_idx <- interviews$species == sp
    
    for (stratum in unique_strata) {
      stratum_idx <- strata_id == stratum & sp_idx
      
      if (sum(stratum_idx) > 0) {
        stratum_weights <- weights[stratum_idx]
        stratum_catch <- interviews[[catch_var]][stratum_idx]
        stratum_effort <- interviews$hours_fished[stratum_idx] * 
                         interviews$party_size[stratum_idx]
        
        # Calculate CPUE based on estimator type
        if (estimator_type == "ratio_of_means") {
          # Ratio-of-means estimator: sum(catch)/sum(effort)
          total_catch <- sum(stratum_weights * stratum_catch)
          total_effort <- sum(stratum_weights * stratum_effort)
          cpue <- total_catch / total_effort
          
          # Calculate standard error using delta method
          ratio_var <- calculate_ratio_se(
            x = stratum_catch,
            y = stratum_effort,
            weights = stratum_weights
          )
          
          catch_se <- sqrt(ratio_var) * total_effort
          
        } else {
          # Mean-of-ratios estimator: mean(catch/effort)
          ratios <- stratum_catch / stratum_effort
          weighted_ratios <- weighted.mean(ratios, stratum_weights)
          cpue <- weighted_ratios
          
          total_effort <- sum(stratum_weights * stratum_effort)
          total_catch <- cpue * total_effort
          
          # Standard error
          ratio_se <- sqrt(
            sum(stratum_weights^2 * (ratios - cpue)^2) / 
            (sum(stratum_weights)^2)
          )
          catch_se <- ratio_se * total_effort
        }
        
        # Calculate confidence interval
        alpha <- 1 - confidence_level
        t_critical <- qt(1 - alpha/2, df = sum(stratum_idx) - 1)
        margin_error <- t_critical * catch_se
        
        # Create stratum identifier columns
        stratum_data <- interviews[strata_vars][stratum_idx, , drop = FALSE]
        stratum_values <- stratum_data[1, , drop = FALSE]
        
        result <- tibble::tibble(
          species = sp,
          !!!stratum_values,
          catch_estimate = total_catch,
          standard_error = catch_se,
          confidence_lower = total_catch - margin_error,
          confidence_upper = total_catch + margin_error,
          sample_size = sum(stratum_idx),
          cpue_estimate = cpue,
          effort_estimate = total_effort
        )
        
        results <- dplyr::bind_rows(results, result)
      }
    }
  }
  
  return(results)
}

#' Daily Effort Estimation
#'
#' Calculates daily fishing effort estimates from count data using
#' instantaneous count methods. This function implements the standard
#' approach for expanding instantaneous counts to daily totals.
#'
#' @param counts A data frame containing count data with columns:
#'   \describe{
#'     \item{date}{Date of count}
#'     \item{time}{Time of count}
#'     \item{location}{Location identifier}
#'     \item{count_type}{Type of count (bank, boat, etc.)}
#'     \item{count_value}{Number of anglers/boats counted}
#'   }
#' @param calendar A data frame containing calendar information with columns:
#'   \describe{
#'     \item{date}{Date}
#'     \item{day_type}{Weekday, weekend, or holiday}
#'     \item{period}{Time period identifier}
#'     \item{period_length}{Length of period in hours}
#'     \item{period_probability}{Probability of sampling this period}
#'   }
#' @param strata_vars Character vector specifying stratification variables.
#'   Default is c("date", "location").
#' @param count_types Character vector specifying which count types to estimate.
#'   Default is c("bank", "boat").
#'
#' @return A tibble containing daily effort estimates with columns:
#'   \describe{
#'     \item{date}{Date}
#'     \item{location}{Location}
#'     \item{count_type}{Type of count}
#'     \item{daily_effort}{Estimated daily effort}
#'     \item{standard_error}{Standard error of estimate}
#'     \item{sample_size}{Number of counts used}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Calculate daily effort from counts
#' daily_effort_results <- daily_effort(
#'   counts = count_data,
#'   calendar = calendar_data,
#'   strata_vars = c("date", "location")
#' )
#' }
daily_effort <- function(counts, calendar, strata_vars = c("date", "location"), 
                        count_types = c("bank", "boat")) {
  
  # Validate inputs
  required_counts <- c("date", "time", "location", "count_type", "count_value")
  required_calendar <- c("date", "period", "period_length", "period_probability")
  
  if (!all(required_counts %in% names(counts))) {
    cli::cli_abort("counts must contain columns: {.val {required_counts}}")
  }
  
  if (!all(required_calendar %in% names(calendar))) {
    cli::cli_abort("calendar must contain columns: {.val {required_calendar}}")
  }
  
  # Convert date columns to Date type
  counts$date <- as.Date(counts$date)
  calendar$date <- as.Date(calendar$date)
  
  # Merge counts with calendar data
  counts_with_probs <- dplyr::left_join(
    counts,
    calendar,
    by = c("date", "period")
  )
  
  # Calculate daily effort for each count type
  results <- tibble::tibble()
  
  for (count_type in count_types) {
    type_counts <- counts_with_probs %>%
      dplyr::filter(count_type == !!count_type)
    
    if (nrow(type_counts) > 0) {
      # Group by date and location
      daily_groups <- type_counts %>%
        dplyr::group_by(date, location) %>%
        dplyr::summarise(
          daily_effort = sum(count_value * period_length / period_probability),
          sample_size = n(),
          .groups = "drop"
        )
      
      # Calculate standard errors (simplified approach)
      daily_groups <- daily_groups %>%
        dplyr::mutate(
          standard_error = daily_effort / sqrt(sample_size)
        )
      
      # Add count type
      daily_groups$count_type <- count_type
      
      results <- dplyr::bind_rows(results, daily_groups)
    }
  }
  
  return(results)
}

#' Party-Level Fish Analysis
#'
#' Analyzes catch data at the party level to calculate various catch metrics
#' including total catch, harvest, release, and catch-while-sought (CWS)
#' measures. This function implements the standard approach for handling
#' party-level interview data in creel surveys.
#'
#' @param interviews A data frame containing interview data with columns:
#'   \describe{
#'     \item{interview_id}{Unique interview identifier}
#'     \item{date}{Date of interview}
#'     \item{location}{Location identifier}
#'     \item{party_size}{Number of anglers in party}
#'     \item{hours_fished}{Total hours fished by party}
#'     \item{species}{Species identifier}
#'     \item{total_catch}{Total fish caught}
#'     \item{harvest}{Number of fish kept}
#'     \item{release}{Number of fish released}
#'     \item{species_sought}{Species targeted by anglers}
#'   }
#' @param analysis_type Character specifying type of analysis:
#'   \describe{
#'     \item{"catch"}{Total catch per party}
#'     \item{"harvest"}{Harvest per party}
#'     \item{"release"}{Release per party}
#'     \item{"cws"}{Catch-while-sought (targeted species only)}
#'     \item{"hws"}{Harvest-while-sought (targeted species harvest)}
#'     \item{"rws"}{Release-while-sought (targeted species release)}
#'   }
#' @param strata_vars Character vector specifying stratification variables.
#'   Default is c("date", "location").
#'
#' @return A tibble containing party-level catch analysis with columns:
#'   \describe{
#'     \item{interview_id}{Interview identifier}
#'     \item{date}{Date}
#'     \item{location}{Location}
#'     \item{party_size}{Number of anglers}
#'     \item{hours_fished}{Effort hours}
#'     \item{species}{Species}
#'     \item{party_catch}{Total catch for party}
#'     \item{individual_catch}{Catch per angler}
#'     \item{cpue}{Catch per unit effort}
#'     \item{analysis_type}{Type of analysis performed}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Analyze catch-while-sought for targeted species
#' cws_results <- party_fish(
#'   interviews = interview_data,
#'   analysis_type = "cws"
#' )
#' }
party_fish <- function(interviews, analysis_type = "catch", 
                      strata_vars = c("date", "location")) {
  
  # Validate inputs
  required_cols <- c("interview_id", "date", "location", "party_size", 
                    "hours_fished", "species", "total_catch", "harvest", 
                    "release", "species_sought")
  
  if (!all(required_cols %in% names(interviews))) {
    cli::cli_abort("interviews must contain columns: {.val {required_cols}}")
  }
  
  # Validate analysis type
  analysis_type <- match.arg(analysis_type,
                           choices = c("catch", "harvest", "release", 
                                     "cws", "hws", "rws"))
  
  # Convert date to Date type
  interviews$date <- as.Date(interviews$date)
  
  # Handle different analysis types
  if (analysis_type %in% c("cws", "hws", "rws")) {
    # Catch-while-sought analysis
    
    # Create targeted species flag
    interviews <- interviews %>%
      dplyr::mutate(
        is_targeted = species == species_sought | species_sought == 999,
        cws_catch = dplyr::if_else(is_targeted, total_catch, 0),
        hws_catch = dplyr::if_else(is_targeted, harvest, 0),
        rws_catch = dplyr::if_else(is_targeted, release, 0)
      )
    
    # Select appropriate catch variable
    catch_var <- switch(analysis_type,
                      cws = "cws_catch",
                      hws = "hws_catch",
                      rws = "rws_catch")
    
    interviews$analysis_catch <- interviews[[catch_var]]
    
  } else {
    # Standard catch analysis
    catch_var <- switch(analysis_type,
                      catch = "total_catch",
                      harvest = "harvest",
                      release = "release")
    
    interviews$analysis_catch <- interviews[[catch_var]]
  }
  
  # Calculate party-level metrics
  results <- interviews %>%
    dplyr::group_by(interview_id, date, location, party_size, hours_fished, 
                   species, species_sought) %>%
    dplyr::summarise(
      party_catch = sum(analysis_catch),
      individual_catch = sum(analysis_catch) / party_size,
      cpue = sum(analysis_catch) / hours_fished,
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      analysis_type = analysis_type
    )
  
  return(results)
}

#' Read Survey Parameters
#'
#' Reads and validates survey parameters from configuration data, similar to
#' the legacy read_parameters function. This provides a bridge for users
#' transitioning from legacy systems.
#'
#' @param config_data A list or data frame containing survey configuration
#'   parameters including waterbody information, sampling design, and
#'   stratification details.
#' @param creel_id Optional identifier for the creel survey, used for
#'   compatibility with legacy systems.
#'
#' @return A list containing:
#'   \describe{
#'     \item{waterbody_info}{Waterbody characteristics and metadata}
#'     \item{design_parameters}{Sampling design parameters}
#'     \item{strata_definitions}{Stratification scheme}
#'     \item{period_probabilities}{Time period sampling probabilities}
#'     \item{validation_status}{Data completeness and quality flags}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Read parameters from legacy configuration
#' params <- read_parameters(config_data = survey_config)
#' }
read_parameters <- function(config_data, creel_id = NULL) {
  
  # Initialize parameters list
  parameters <- list()
  
  # Waterbody information
  if ("waterbody_code" %in% names(config_data)) {
    parameters$waterbody_info <- list(
      code = config_data$waterbody_code,
      name = config_data$waterbody_name %||% NA_character_,
      area_acres = config_data$area_acres %||% NA_real_,
      area_hectares = config_data$area_hectares %||% NA_real_
    )
  }
  
  # Design parameters
  if ("start_date" %in% names(config_data) && "end_date" %in% names(config_data)) {
    parameters$design_parameters <- list(
      start_date = as.Date(config_data$start_date),
      end_date = as.Date(config_data$end_date),
      survey_type = config_data$survey_type %||% "access_point",
      sampling_method = config_data$sampling_method %||% "stratified_random"
    )
  }
  
  # Strata definitions
  if ("strata_vars" %in% names(config_data)) {
    parameters$strata_definitions <- list(
      strata_vars = config_data$strata_vars,
      strata_levels = config_data$strata_levels %||% NULL,
      day_types = config_data$day_types %||% c("weekday", "weekend", "holiday")
    )
  }
  
  # Period probabilities
  if ("period_probs" %in% names(config_data)) {
    parameters$period_probabilities <- config_data$period_probs
  } else {
    # Default period structure
    parameters$period_probabilities <- tibble::tibble(
      period = 1:4,
      start_time = c("06:00", "10:00", "14:00", "18:00"),
      end_time = c("10:00", "14:00", "18:00", "22:00"),
      probability = 0.25,
      period_length = 4
    )
  }
  
  # Validation status
  parameters$validation_status <- list(
    data_complete = config_data$data_complete %||% TRUE,
    missing_data = config_data$missing_data %||% character(0),
    warnings = config_data$warnings %||% character(0)
  )
  
  # Add creel_id if provided
  if (!is.null(creel_id)) {
    parameters$creel_id <- creel_id
  }
  
  return(parameters)
}

#' Legacy Data Validation
#'
#' Validates data formats and structure for compatibility with legacy
#' creel analysis systems. This function helps identify potential issues
#' when transitioning from legacy systems to the new tidycreel package.
#'
#' @param data A data frame to validate (interviews, counts, or calendar data)
#' @param data_type Character specifying the type of data:
#'   "interviews", "counts", or "calendar"
#'
#' @return A list containing:
#'   \describe{
#'     \item{is_valid}{Logical indicating if data is valid}
#'     \item{issues}{Character vector of validation issues found}
#'     \item{warnings}{Character vector of warnings}
#'     \item{recommendations}{Suggested fixes for issues}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Validate interview data
#' validation <- validate_legacy_data(interview_data, "interviews")
#' }
validate_legacy_data <- function(data, data_type) {
  
  issues <- character(0)
  warnings <- character(0)
  recommendations <- character(0)
  
  # Common checks
  if (!is.data.frame(data)) {
    issues <- c(issues, "Input must be a data frame")
    return(list(
      is_valid = FALSE,
      issues = issues,
      warnings = warnings,
      recommendations = recommendations
    ))
  }
  
  if (nrow(data) == 0) {
    issues <- c(issues, "Data frame is empty")
    return(list(
      is_valid = FALSE,
      issues = issues,
      warnings = warnings,
      recommendations = recommendations
    ))
  }
  
  # Type-specific checks
  if (data_type == "interviews") {
    required_cols <- c("interview_id", "date", "location", "party_size", 
                      "hours_fished", "species", "total_catch", "harvest", 
                      "release", "species_sought")
    
    missing_cols <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0) {
      issues <- c(issues, paste("Missing required columns:", 
                               paste(missing_cols, collapse = ", ")))
      recommendations <- c(recommendations, 
                          paste("Add columns:", paste(missing_cols, collapse = ", ")))
    }
    
    # Check data types
    if (!is.numeric(data$party_size)) {
      warnings <- c(warnings, "party_size should be numeric")
    }
    
    if (!is.numeric(data$hours_fished)) {
      warnings <- c(warnings, "hours_fished should be numeric")
    }
    
  } else if (data_type == "counts") {
    required_cols <- c("date", "time", "location", "count_type", "count_value")
    
    missing_cols <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0) {
      issues <- c(issues, paste("Missing required columns:", 
                               paste(missing_cols, collapse = ", ")))
    }
    
  } else if (data_type == "calendar") {
    required_cols <- c("date", "period", "period_length", "period_probability")
    
    missing_cols <- setdiff(required_cols, names(data))
    if (length(missing_cols) > 0) {
      issues <- c(issues, paste("Missing required columns:",
                               paste(missing_cols, collapse = ", ")))
    }
  }
  
  # Final validation
  is_valid <- length(issues) == 0
  
  if (is_valid && length(warnings) > 0) {
    warnings <- c(warnings, "Data is valid but has warnings")
  }
  
  return(list(
    is_valid = is_valid,
    issues = issues,
    warnings = warnings,
    recommendations = recommendations
  ))
}

#' Calculate Ratio Standard Error
#'
#' Helper function to calculate the standard error of a ratio estimator
#' using the delta method. This is used internally by strata_catch_estimator.
#'
#' @param x Numeric vector of numerator values
#' @param y Numeric vector of denominator values
#' @param weights Numeric vector of sampling weights
#'
#' @return Numeric value representing the variance of the ratio estimator
#'
#' @keywords internal
calculate_ratio_se <- function(x, y, weights) {
  
  # Calculate weighted means
  x_mean <- weighted.mean(x, weights)
  y_mean <- weighted.mean(y, weights)
  
  # Calculate ratio
  ratio <- x_mean / y_mean
  
  # Calculate residuals
  x_resid <- x - x_mean
  y_resid <- y - y_mean
  
  # Calculate variance using delta method
  var_ratio <- (1 / (sum(weights) * y_mean^2)) *
    sum(weights^2 * (x_resid - ratio * y_resid)^2)
  
  return(var_ratio)
}