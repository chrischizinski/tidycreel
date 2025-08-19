#' Legacy API Wrapper Functions
#'
#' Wrapper functions that provide compatibility with the legacy creel analysis API
#' while using the new tidycreel package internals.
#'
#' @name legacy-wrappers
#' @keywords internal
NULL

#' Read Parameters (Legacy API)
#'
#' Legacy function to read parameters from database or configuration.
#' This is a wrapper around the new tidycreel configuration system.
#'
#' @param creel_id Character string identifying the creel survey
#' @param data_source Character string specifying data source ("database" or "config")
#' @param config_path Path to configuration file (optional)
#' @param ... Additional parameters passed to configuration
#'
#' @return List containing parameters in legacy format
#' @export
#' @examples
#' \dontrun{
#' params <- read_parameters("CREEL_2024_001")
#' }
read_parameters <- function(creel_id, data_source = "database", config_path = NULL, ...) {
  # Validate inputs
  validate_creel_id(creel_id)
  
  # Get configuration
  config <- get_legacy_configuration(creel_id, data_source, config_path, ...)
  
  # Create legacy parameter structure
  parameters <- list()
  
  # Waterbody info
  parameters[["waterbody.info"]] <- list(
    code = creel_id,
    waterbody_ac = config$waterbody_area,
    waterbody_ha = round(config$waterbody_area * 0.404686, digits = 0),
    start_end_dates = as.Date(c(config$start_date, config$end_date)),
    period_probs = config$periods,
    special_daytype = NULL,
    special_days = NULL,
    corrected_water_levels = FALSE,
    data_status = 1
  )
  
  # Do codes
  parameters[["do.codes"]] <- data.frame(
    do.highuse = config$high_use_days,
    do.holidays = config$holidays,
    do.sections = config$sections_enabled
  )
  
  # Days in creel
  parameters[["days_in_creel"]] <- create_legacy_calendar(config)
  
  # Sample days
  parameters[["sample_days"]] <- data.frame(
    month = unique(parameters$days_in_creel$month),
    day_type = c("weekday", "weekend", "highuse"),
    Sampled = 0,
    Available = 30,
    CountsPerPeriod = 4
  )
  
  # Water levels
  parameters[["water_levels"]] <- data.frame(
    month = 1:12,
    acres = rep(config$waterbody_area, 12),
    Hectares = rep(round(config$waterbody_area * 0.404686, digits = 0), 12)
  )
  
  return(parameters)
}

#' Daily Effort (Legacy API)
#'
#' Legacy function to calculate daily effort estimates.
#' This is a wrapper around the new tidycreel effort estimation.
#'
#' @param creel_id Character string identifying the creel survey
#' @param counts Data frame with count data (optional, will load from database if NULL)
#' @param interviews Data frame with interview data (optional, will load from database if NULL)
#' @param config_path Path to configuration file (optional)
#' @param ... Additional parameters
#'
#' @return Data frame with daily effort estimates in legacy format
#' @export
#' @examples
#' \dontrun{
#' effort <- daily_effort("CREEL_2024_001")
#' }
daily_effort <- function(creel_id, counts = NULL, interviews = NULL, config_path = NULL, ...) {
  # Validate inputs
  validate_creel_id(creel_id)
  
  # Load data if not provided
  if (is.null(counts) || is.null(interviews)) {
    data <- load_legacy_data(creel_id, ...)
    counts <- data$counts
    interviews <- data$interviews
  }
  
  # Convert legacy names
  counts <- convert_legacy_names(counts)
  interviews <- convert_legacy_names(interviews)
  
  # Validate data
  data <- validate_legacy_data(list(
    counts = counts,
    interviews = interviews
  ))
  
  # Get configuration
  config <- get_legacy_configuration(creel_id, config_path = config_path, ...)
  
  # Create survey design
  design <- create_creel_design(
    counts = data$counts,
    interviews = data$interviews,
    calendar = data$calendar,
    survey_type = "access_point",
    strata = list(
      time = c("weekday", "weekend", "highuse"),
      space = "Section"
    )
  )
  
  # Calculate effort
  effort_estimates <- est_effort(
    design,
    effort_type = "angler_hours",
    by_strata = TRUE
  )
  
  # Format for legacy output
  legacy_output <- format_legacy_output(effort_estimates, "daily_effort")
  
  return(legacy_output)
}

#' Party Fish (Legacy API)
#'
#' Legacy function to calculate party-level catch statistics.
#' This is a wrapper around the new tidycreel catch estimation.
#'
#' @param creel_id Character string identifying the creel survey
#' @param type Character string indicating catch type ("Catch", "Harvest", "Release", "CWS", "HWS", "RWS")
#' @param counts Data frame with count data (optional)
#' @param interviews Data frame with interview data (optional)
#' @param catch_data Data frame with catch data (optional)
#' @param config_path Path to configuration file (optional)
#' @param ... Additional parameters
#'
#' @return Data frame with party-level catch statistics in legacy format
#' @export
#' @examples
#' \dontrun{
#' catches <- party_fish("CREEL_2024_001", type = "Catch")
#' }
party_fish <- function(creel_id, type = c("Catch", "Harvest", "Release", "CWS", "HWS", "RWS"), 
                      counts = NULL, interviews = NULL, catch_data = NULL, 
                      config_path = NULL, ...) {
  # Validate inputs
  validate_creel_id(creel_id)
  type <- match.arg(type)
  
  # Load data if not provided
  if (is.null(counts) || is.null(interviews) || is.null(catch_data)) {
    data <- load_legacy_data(creel_id, ...)
    counts <- data$counts
    interviews <- data$interviews
    catch_data <- data$catch_data
  }
  
  # Convert legacy names
  counts <- convert_legacy_names(counts)
  interviews <- convert_legacy_names(interviews)
  catch_data <- convert_legacy_names(catch_data)
  
  # Validate data
  data <- validate_legacy_data(list(
    counts = counts,
    interviews = interviews,
    catch_data = catch_data
  ))
  
  # Create survey design
  design <- create_creel_design(
    counts = data$counts,
    interviews = data$interviews,
    catch_data = data$catch_data,
    survey_type = "access_point",
    strata = list(
      time = c("weekday", "weekend", "highuse"),
      space = "Section"
    )
  )
  
  # Calculate catch based on type
  if (type == "Catch") {
    catch_estimates <- est_catch(
      design,
      catch_type = "total",
      by_strata = TRUE,
      by_species = TRUE
    )
  } else if (type == "Harvest") {
    catch_estimates <- est_catch(
      design,
      catch_type = "harvest",
      by_strata = TRUE,
      by_species = TRUE
    )
  } else if (type == "Release") {
    catch_estimates <- est_catch(
      design,
      catch_type = "release",
      by_strata = TRUE,
      by_species = TRUE
    )
  } else if (type == "CWS") {
    catch_estimates <- est_catch(
      design,
      catch_type = "targeted",
      by_strata = TRUE,
      by_species = TRUE
    )
  } else if (type == "HWS") {
    catch_estimates <- est_catch(
      design,
      catch_type = "targeted_harvest",
      by_strata = TRUE,
      by_species = TRUE
    )
  } else if (type == "RWS") {
    catch_estimates <- est_catch(
      design,
      catch_type = "targeted_release",
      by_strata = TRUE,
      by_species = TRUE
    )
  }
  
  # Format for legacy output
  legacy_output <- format_legacy_output(catch_estimates, "party_fish")
  
  return(legacy_output)
}

#' Get Available Creels (Legacy API)
#'
#' Legacy function to list available creel surveys.
#' This is a wrapper that returns mock data for compatibility.
#'
#' @param data_source Character string specifying data source
#' @param config_path Path to configuration file (optional)
#'
#' @return Data frame with available creels
#' @export
#' @examples
#' \dontrun{
#' creels <- get_available_creels()
#' }
get_available_creels <- function(data_source = "database", config_path = NULL) {
  # Return mock data for compatibility
  available_creels <- data.frame(
    Creel_UID = c("CREEL_2024_001", "CREEL_2024_002", "CREEL_2023_001"),
    Creel_Title = c("Lake Survey 2024", "River Survey 2024", "Lake Survey 2023"),
    stringsAsFactors = FALSE
  )
  
  return(available_creels)
}

#' Load Legacy Data
#'
#' Helper function to load data for legacy API functions.
#'
#' @param creel_id Character string identifying the creel survey
#' @param data_source Character string specifying data source
#' @param config_path Path to configuration file (optional)
#' @param ... Additional parameters
#'
#' @return List containing counts, interviews, and catch data
#' @keywords internal
load_legacy_data <- function(creel_id, data_source = "database", config_path = NULL, ...) {
  if (data_source == "database") {
    # Try to connect to database
    con <- tryCatch({
      connect_creel()
    }, error = function(e) {
      warning("Could not connect to database: ", e$message)
      NULL
    })
    
    if (!is.null(con)) {
      # Load from database
      counts <- db_read(con, "SELECT * FROM CountData WHERE CreelUID = ?", list(creel_id))
      interviews <- db_read(con, "SELECT * FROM InterviewData WHERE CreelUID = ?", list(creel_id))
      catch_data <- db_read(con, "SELECT * FROM CatchData WHERE CreelUID = ?", list(creel_id))
      
      db_disconnect(con)
      
      return(list(
        counts = counts,
        interviews = interviews,
        catch_data = catch_data
      ))
    }
  }
  
  # Load from toy data if database fails
  config <- get_legacy_configuration(creel_id, config_path = config_path, ...)
  
  # Load toy data
  counts <- read.csv(system.file("extdata", "toy_counts.csv", package = "tidycreel"))
  interviews <- read.csv(system.file("extdata", "toy_interviews.csv", package = "tidycreel"))
  catch_data <- read.csv(system.file("extdata", "toy_catch.csv", package = "tidycreel"))
  
  # Filter for creel_id if specified
  if (!is.null(creel_id) && creel_id != "") {
    counts <- counts[counts$CreelUID == creel_id, ]
    interviews <- interviews[interviews$CreelUID == creel_id, ]
    catch_data <- catch_data[catch_data$CreelUID == creel_id, ]
  }
  
  return(list(
    counts = counts,
    interviews = interviews,
    catch_data = catch_data
  ))
}

#' Create Creel Design (Legacy Bridge)
#'
#' Creates survey design object for legacy compatibility.
#'
#' @param counts Data frame with count data
#' @param interviews Data frame with interview data
#' @param catch_data Data frame with catch data (optional)
#' @param calendar Data frame with calendar data (optional)
#' @param survey_type Character string indicating survey type
#' @param strata List of strata definitions
#'
#' @return Survey design object
#' @keywords internal
create_creel_design <- function(counts, interviews, catch_data = NULL, calendar = NULL,
                              survey_type = "access_point", strata = NULL) {
  
  # Create survey design using new API
  design <- creel_design(
    counts = counts,
    interviews = interviews,
    catch_data = catch_data,
    survey_type = survey_type,
    strata = strata
  )
  
  return(design)
}

#' Est Effort (Legacy Bridge)
#'
#' Calculates effort estimates for legacy compatibility.
#'
#' @param design Survey design object
#' @param effort_type Character string indicating effort type
#' @param by_strata Logical indicating whether to stratify results
#'
#' @return Data frame with effort estimates
#' @keywords internal
est_effort <- function(design, effort_type = "angler_hours", by_strata = TRUE) {
  # Use new API to calculate effort
  effort <- strata_effort_estimator(
    design = design,
    effort_type = effort_type,
    by_strata = by_strata
  )
  
  return(effort)
}

#' Est Catch (Legacy Bridge)
#'
#' Calculates catch estimates for legacy compatibility.
#'
#' @param design Survey design object
#' @param catch_type Character string indicating catch type
#' @param by_strata Logical indicating whether to stratify results
#' @param by_species Logical indicating whether to stratify by species
#'
#' @return Data frame with catch estimates
#' @keywords internal
est_catch <- function(design, catch_type = "total", by_strata = TRUE, by_species = TRUE) {
  # Use new API to calculate catch
  catch <- strata_catch_estimator(
    design = design,
    catch_type = catch_type,
    by_strata = by_strata,
    by_species = by_species
  )
  
  return(catch)
}