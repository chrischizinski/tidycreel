#' Legacy Helper Functions
#'
#' Helper functions to support legacy API compatibility and data conversion.
#'
#' @name legacy-helpers
#' @keywords internal
NULL

#' Validate Creel ID
#'
#' Validates that a creel ID is in the expected format.
#'
#' @param creel_id Character string to validate
#'
#' @return Logical indicating validity
#' @keywords internal
validate_creel_id <- function(creel_id) {
  if (!is.character(creel_id) || length(creel_id) != 1) {
    stop("creel_id must be a single character string")
  }
  
  # Basic format check - adjust as needed for your system
  if (!grepl("^CREEL_[0-9]{4}_[0-9]{3}$", creel_id)) {
    warning("creel_id format may not be standard. Expected format: CREEL_YYYY_NNN")
  }
  
  return(TRUE)
}

#' Get Legacy Configuration
#'
#' Retrieves configuration for legacy API compatibility.
#'
#' @param creel_id Character string identifying the creel survey
#' @param data_source Character string specifying data source
#' @param config_path Path to configuration file (optional)
#' @param ... Additional parameters
#'
#' @return List containing configuration parameters
#' @keywords internal
get_legacy_configuration <- function(creel_id, data_source = "database", config_path = NULL, ...) {
  # Default configuration
  config <- list(
    waterbody_area = 1000,  # Default area in acres
    start_date = as.Date("2024-01-01"),
    end_date = as.Date("2024-12-31"),
    periods = data.frame(
      Month = 1:12,
      Period = 1:4,
      PeriodStartTime = c("06:00:00", "10:00:00", "14:00:00", "18:00:00"),
      PeriodEndTime = c("10:00:00", "14:00:00", "18:00:00", "22:00:00"),
      PeriodProbability = 0.25,
      CountsPerPeriod = 1,
      PeriodLengthInHours = 4
    ),
    high_use_days = TRUE,
    holidays = TRUE,
    sections_enabled = TRUE
  )
  
  # Try to load from config file if provided
  if (!is.null(config_path) && file.exists(config_path)) {
    tryCatch({
      file_config <- jsonlite::fromJSON(config_path)
      config <- modifyList(config, file_config)
    }, error = function(e) {
      warning("Could not load configuration from file: ", e$message)
    })
  }
  
  return(config)
}

#' Convert Legacy Names
#'
#' Converts column names from legacy format to new format.
#'
#' @param data Data frame to convert
#' @param type Character string indicating data type ("counts", "interviews", "catch")
#'
#' @return Data frame with converted column names
#' @keywords internal
convert_legacy_names <- function(data, type = NULL) {
  if (is.null(data) || nrow(data) == 0) {
    return(data)
  }
  
  # Define name mappings
  name_mappings <- list(
    counts = c(
      "cd_Date" = "date",
      "cd_Period" = "period",
      "cd_CountTime" = "count_time",
      "cd_Section" = "section",
      "BankAnglers" = "bank_anglers",
      "BoatAnglers" = "boat_anglers",
      "AnglerBoats" = "angler_boats",
      "NonAngBoats" = "non_angler_boats"
    ),
    interviews = c(
      "ii_UID" = "interview_id",
      "ii_Date" = "date",
      "ii_Section" = "section",
      "ii_TimeFishedHours" = "hours_fished",
      "ii_TimeFishedMinutes" = "minutes_fished",
      "ii_NumberAnglers" = "party_size",
      "ii_AnglerType" = "angler_type",
      "ii_AnglerMethod" = "angler_method",
      "ii_TripType" = "trip_type",
      "ii_SpeciesSought" = "species_sought",
      "ii_Refused" = "refused"
    ),
    catch = c(
      "ir_UID" = "interview_id",
      "ir_Species" = "species",
      "ir_CatchType" = "catch_type",
      "ir_Num" = "number"
    )
  )
  
  # Apply mappings based on type or auto-detect
  if (!is.null(type) && type %in% names(name_mappings)) {
    mappings <- name_mappings[[type]]
  } else {
    # Auto-detect based on column names
    mappings <- c()
    for (type_name in names(name_mappings)) {
      type_mappings <- name_mappings[[type_name]]
      if (any(names(data) %in% names(type_mappings))) {
        mappings <- c(mappings, type_mappings)
      }
    }
  }
  
  # Apply mappings
  names(data) <- names(mappings)[match(names(data), mappings)]
  
  return(data)
}

#' Validate Legacy Data
#'
#' Validates data loaded through legacy API.
#'
#' @param data_list List containing counts, interviews, and catch data
#'
#' @return List with validated data
#' @keywords internal
validate_legacy_data <- function(data_list) {
  required_cols <- list(
    counts = c("date", "period", "section"),
    interviews = c("date", "section", "hours_fished", "minutes_fished", "party_size"),
    catch_data = c("interview_id", "species", "catch_type", "number")
  )
  
  # Check each data type
  for (data_type in names(required_cols)) {
    if (!is.null(data_list[[data_type]])) {
      data <- data_list[[data_type]]
      
      # Check required columns
      missing_cols <- setdiff(required_cols[[data_type]], names(data))
      if (length(missing_cols) > 0) {
        warning(sprintf("Missing required columns in %s: %s", 
                       data_type, paste(missing_cols, collapse = ", ")))
      }
      
      # Validate data types
      if ("date" %in% names(data)) {
        data$date <- as.Date(data$date)
      }
      
      if ("hours_fished" %in% names(data)) {
        data$hours_fished <- as.numeric(data$hours_fished)
      }
      
      if ("minutes_fished" %in% names(data)) {
        data$minutes_fished <- as.numeric(data$minutes_fished)
      }
      
      if ("party_size" %in% names(data)) {
        data$party_size <- as.integer(data$party_size)
      }
      
      if ("number" %in% names(data)) {
        data$number <- as.integer(data$number)
      }
      
      data_list[[data_type]] <- data
    }
  }
  
  return(data_list)
}

#' Create Legacy Calendar
#'
#' Creates calendar data frame in legacy format.
#'
#' @param config List containing configuration parameters
#'
#' @return Data frame with calendar data
#' @keywords internal
create_legacy_calendar <- function(config) {
  # Create sequence of dates
  dates <- seq