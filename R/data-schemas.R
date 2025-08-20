#' Sampling Calendar Schema
#'
#' Defines the expected structure for sampling calendar data including
#' temporal strata definitions.
#'
#' @format A tibble with the following columns:
#' \describe{
#'   \item{date}{Date, sampling date}
#'   \item{stratum_id}{Character, unique stratum identifier}
#'   \item{day_type}{Character, type of day (weekday, weekend, holiday)}
#'   \item{season}{Character, season identifier}
#'   \item{month}{Character, month identifier}
#'   \item{weekend}{Logical, TRUE if weekend}
#'   \item{holiday}{Logical, TRUE if holiday}
#'   \item{shift_block}{Character, shift identifier (morning, afternoon, evening)}
#'   \item{target_sample}{Integer, target sample size for stratum}
#'   \item{actual_sample}{Integer, actual sample size achieved}
#' }
#'
#' @name calendar_schema
NULL

#' Interview Data Schema
#'
#' Defines the expected structure for angler interview data.
#'
#' @format A tibble with the following columns:
#' \describe{
#'   \item{interview_id}{Character, unique interview identifier}
#'   \item{date}{Date, interview date}
#'   \item{time_start}{POSIXct, interview start time}
#'   \item{time_end}{POSIXct, interview end time}
#'   \item{location}{Character, sampling location}
#'   \item{mode}{Character, fishing mode (bank, boat, ice, etc.)}
#'   \item{party_size}{Integer, number of anglers in party}
#'   \item{hours_fished}{Numeric, hours fished by party}
#'   \item{target_species}{Character, primary target species}
#'   \item{catch_total}{Integer, total fish caught}
#'   \item{catch_kept}{Integer, fish kept}
#'   \item{catch_released}{Integer, fish released}
#'   \item{weight_total}{Numeric, total weight of catch (kg)}
#'   \item{trip_complete}{Logical, TRUE if trip was complete at interview}
#'   \item{effort_expansion}{Numeric, expansion factor for effort estimation}
#' }
#'
#' @name interview_schema
NULL

#' Instantaneous Count Schema
#'
#' Defines the expected structure for instantaneous count data.
#'
#' @format A tibble with the following columns:
#' \describe{
#'   \item{count_id}{Character, unique count identifier}
#'   \item{date}{Date, count date}
#'   \item{time}{POSIXct, count time}
#'   \item{location}{Character, sampling location}
#'   \item{mode}{Character, fishing mode}
#'   \item{anglers_count}{Integer, number of anglers observed}
#'   \item{parties_count}{Integer, number of fishing parties observed}
#'   \item{weather_code}{Character, weather condition code}
#'   \item{temperature}{Numeric, temperature in Celsius}
#'   \item{wind_speed}{Numeric, wind speed}
#'   \item{visibility}{Character, visibility conditions}
#'   \item{count_duration}{Numeric, duration of count in minutes}
#' }
#'
#' @name count_schema
NULL

#' Auxiliary Data Schema
#'
#' Defines the expected structure for auxiliary data (sunrise/sunset, holidays).
#'
#' @format A tibble with the following columns:
#' \describe{
#'   \item{date}{Date, date of auxiliary data}
#'   \item{sunrise}{POSIXct, sunrise time}
#'   \item{sunset}{POSIXct, sunset time}
#'   \item{holiday}{Character, holiday name (if any)}
#' }
#'
#' @name auxiliary_schema
NULL

#' Reference Table Schema
#'
#' Defines the expected structure for reference tables (species, waterbody, etc.).
#'
#' @format A tibble with the following columns:
#' \describe{
#'   \item{code}{Character, unique code}
#'   \item{description}{Character, code description}
#' }
#'
#' @name reference_schema
NULL
#' Validate Calendar Data
#'
#' Validates that calendar data conforms to the expected schema.
#'
#' @param calendar A tibble containing calendar data
#' @param strict Logical, if TRUE throws error on validation failure
#'
#' @return Invisibly returns the validated data, or throws error if invalid
#' @export
#'
#' @examples
#' \dontrun{
#' calendar <- tibble::tibble(
#'   date = as.Date("2024-01-01"),
#'   stratum_id = "2024-01-01-weekday-morning",
#'   day_type = "weekday",
#'   season = "winter",
#'   month = "January",
#'   weekend = FALSE,
#'   holiday = FALSE,
#'   shift_block = "morning",
#'   target_sample = 10L,
#'   actual_sample = 8L
#' )
#' validate_calendar(calendar)
#' }
validate_calendar <- function(calendar, strict = TRUE) {
  required_cols <- c(
    "date", "stratum_id", "day_type", "season", "month",
    "weekend", "holiday", "shift_block", "target_sample",
    "actual_sample"
  )

  missing_cols <- setdiff(required_cols, names(calendar))

  if (length(missing_cols) > 0) {
    msg <- paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    if (strict) {
      cli::cli_abort(msg)
    } else {
      cli::cli_warn(msg)
    }
  }

  # Validate data types
  if (!inherits(calendar$date, "Date")) {
    cli::cli_abort("{.var date} must be a Date vector")
  }

  if (!is.logical(calendar$weekend) || !is.logical(calendar$holiday)) {
    cli::cli_abort("{.var weekend} and {.var holiday} must be logical vectors")
  }

  if (!all(c(calendar$target_sample, calendar$actual_sample) %% 1 == 0)) {
    cli::cli_abort("{.var target_sample} and {.var actual_sample} must be integers")
  }

  invisible(calendar)
}

#' Validate Interview Data
#'
#' Validates that interview data conforms to the expected schema.
#'
#' @param interviews A tibble containing interview data
#' @param strict Logical, if TRUE throws error on validation failure
#'
#' @return Invisibly returns the validated data, or throws error if invalid
#' @export
#'
#' @examples
#' \dontrun{
#' interviews <- tibble::tibble(
#'   interview_id = "INT001",
#'   date = as.Date("2024-01-01"),
#'   time_start = as.POSIXct("2024-01-01 08:00:00"),
#'   time_end = as.POSIXct("2024-01-01 08:15:00"),
#'   location = "Lake_A",
#'   mode = "boat",
#'   party_size = 2L,
#'   hours_fished = 4.5,
#'   target_species = "walleye",
#'   catch_total = 5L,
#'   catch_kept = 3L,
#'   catch_released = 2L,
#'   weight_total = 2.5,
#'   trip_complete = TRUE,
#'   effort_expansion = 1.0
#' )
#' validate_interviews(interviews)
#' }
validate_interviews <- function(interviews, strict = TRUE) {
  required_cols <- c(
    "interview_id", "date", "time_start", "time_end",
    "location", "mode", "party_size", "hours_fished",
    "target_species", "catch_total", "catch_kept",
    "catch_released", "weight_total", "trip_complete",
    "effort_expansion"
  )

  missing_cols <- setdiff(required_cols, names(interviews))

  if (length(missing_cols) > 0) {
    msg <- paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    if (strict) {
      cli::cli_abort(msg)
    } else {
      cli::cli_warn(msg)
    }
  }

  # Validate data types
  if (!inherits(interviews$date, "Date")) {
    cli::cli_abort("{.var date} must be a Date vector")
  }

  if (!inherits(interviews$time_start, "POSIXct") || !inherits(interviews$time_end, "POSIXct")) {
    cli::cli_abort("{.var time_start} and {.var time_end} must be POSIXct vectors")
  }

  if (!all(c(
    interviews$party_size, interviews$catch_total,
    interviews$catch_kept, interviews$catch_released
  ) %% 1 == 0)) {
    cli::cli_abort("Count variables must be integers")
  }

  if (any(interviews$hours_fished < 0)) {
    cli::cli_abort("{.var hours_fished} must be non-negative")
  }

  invisible(interviews)
}

#' Validate Count Data
#'
#' Validates that instantaneous count data conforms to the expected schema.
#'
#' @param counts A tibble containing count data
#' @param strict Logical, if TRUE throws error on validation failure
#'
#' @return Invisibly returns the validated data, or throws error if invalid
#' @export
#'
#' @examples
#' \dontrun{
#' counts <- tibble::tibble(
#'   count_id = "CNT001",
#'   date = as.Date("2024-01-01"),
#'   time = as.POSIXct("2024-01-01 09:00:00"),
#'   location = "Lake_A",
#'   mode = "boat",
#'   anglers_count = 15L,
#'   parties_count = 8L,
#'   weather_code = "clear",
#'   temperature = 22.5,
#'   wind_speed = 5.2,
#'   visibility = "good",
#'   count_duration = 15
#' )
#' validate_counts(counts)
#' }
validate_counts <- function(counts, strict = TRUE) {
  required_cols <- c(
    "count_id", "date", "time", "location", "mode",
    "anglers_count", "parties_count", "weather_code",
    "temperature", "wind_speed", "visibility", "count_duration"
  )

  missing_cols <- setdiff(required_cols, names(counts))
  
  if (length(missing_cols) > 0) {
    msg <- paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    if (strict) {
      cli::cli_abort(msg)
    } else {
      cli::cli_warn(msg)
    }
  }
  
  if (!inherits(counts$date, "Date")) {
    cli::cli_abort("{.var date} must be a Date vector")
  }
  
  if (!inherits(counts$time, "POSIXct")) {
    cli::cli_abort("{.var time} must be a POSIXct vector")
  }
  
  if (!all(c(counts$anglers_count, counts$parties_count, counts$count_duration) %% 1 == 0)) {
    cli::cli_abort("Count variables must be integers")
  }
  
  if (any(counts$anglers_count < 0) || any(counts$parties_count < 0)) {
    cli::cli_abort("Count variables must be non-negative")
  }
  
  invisible(counts)
}

#' Validate auxiliary data schema
#'
#' @param auxiliary A tibble containing auxiliary data
#' @param strict Logical, if TRUE throws error on validation failure
#' @return Invisibly returns the validated data, or throws error if invalid
#' @export
validate_auxiliary <- function(auxiliary, strict = TRUE) {
  required_cols <- c("date", "sunrise", "sunset", "holiday")
  
  missing_cols <- setdiff(required_cols, names(auxiliary))
  
  if (length(missing_cols) > 0) {
    msg <- paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    if (strict) {
      cli::cli_abort(msg)
    } else {
      cli::cli_warn(msg)
    }
  }
  
  if (!inherits(auxiliary$date, "Date")) {
    cli::cli_abort("{.var date} must be a Date vector")
  }
  
  if (!inherits(auxiliary$sunrise, "POSIXct") || !inherits(auxiliary$sunset, "POSIXct")) {
    cli::cli_abort("{.var sunrise} and {.var sunset} must be POSIXct vectors")
  }
  
  invisible(auxiliary)
}

#' Validate reference table schema
#'
#' @param reference A tibble containing reference table data
#' @param strict Logical, if TRUE throws error on validation failure
#' @return Invisibly returns the validated data, or throws error if invalid
#' @export
validate_reference <- function(reference, strict = TRUE) {
  required_cols <- c("code", "description")
  
  missing_cols <- setdiff(required_cols, names(reference))
  
  if (length(missing_cols) > 0) {
    msg <- paste("Missing required columns:", paste(missing_cols, collapse = ", "))
    if (strict) {
      cli::cli_abort(msg)
    } else {
      cli::cli_warn(msg)
    }
  }
  
  invisible(reference)
}

