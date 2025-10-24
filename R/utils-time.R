#' Utility: Parse to POSIXct
#'
#' Parses a vector to POSIXct using lubridate if available, else base R.
#' @param x Character or numeric vector
#' @return POSIXct vector
#' @export
tc_as_time <- function(x) {
  if (requireNamespace("lubridate", quietly = TRUE)) {
    lubridate::parse_date_time(x, orders = c("Ymd HMS", "Ymd HM", "Ymd", "mdY HMS", "mdY HM", "mdY"))
  } else {
    as.POSIXct(x, tz = "UTC", tryFormats = c("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d", "%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M", "%m/%d/%Y"))
  }
}

#' Utility: Confidence Interval Helper
#'
#' Computes normal or t-based confidence interval.
#' @param mean Numeric mean
#' @param se Standard error
#' @param level Confidence level
#' @param df Degrees of freedom (optional)
#' @return Numeric vector: lower, upper
#' @importFrom stats qt qnorm
#' @export
tc_confint <- function(mean, se, level = 0.95, df = NULL) {
  alpha <- 1 - level
  if (!is.null(df)) {
    crit <- qt(1 - alpha/2, df)
  } else {
    crit <- qnorm(1 - alpha/2)
  }
  c(mean - crit * se, mean + crit * se)
}

#' Parse time columns using lubridate
#'
#' Attempts to parse a vector of time strings to POSIXct using lubridate. Returns parsed times or original if already POSIXct.
#' @param x Character vector or POSIXct
#' @return POSIXct vector
#' @examples
#' parse_time_column(c("2025-08-20 08:00:00", "2025-08-20 12:00:00"))
#' @export
parse_time_column <- function(x) {
  if (inherits(x, c("POSIXct", "POSIXt"))) return(x)
  if (requireNamespace("lubridate", quietly = TRUE)) {
    lubridate::ymd_hms(x, quiet = TRUE)
  } else {
    as.POSIXct(x)
  }
}

#' Calculate interval in minutes between two time columns
#'
#' Uses lubridate to compute the difference in minutes between two POSIXct vectors.
#' @param start POSIXct vector
#' @param end POSIXct vector
#' @return Numeric vector of interval lengths in minutes
#' @examples
#' start_time <- as.POSIXct("2025-01-01 08:00:00")
#' end_time <- as.POSIXct("2025-01-01 12:30:00")
#' interval_minutes(start_time, end_time)
#' @export
interval_minutes <- function(start, end) {
  as.numeric(difftime(end, start, units = "mins"))
}

#' Standardize time column names using stringr
#'
#' Renames columns in a data.frame to standard time column names if common variants are found.
#' @param df Data.frame
#' @return Data.frame with standardized time column names
#' @examples
#' df <- data.frame(timestamp = "2025-01-01 08:00", value = 1)
#' standardize_time_columns(df)
#' @export
standardize_time_columns <- function(df) {
  if (requireNamespace("stringr", quietly = TRUE)) {
    names(df) <- stringr::str_replace_all(names(df),
      c("timestamp" = "time", "date_time" = "time", "datetime" = "time"))
  } else {
    names(df)[names(df) == "timestamp"] <- "time"
    names(df)[names(df) == "date_time"] <- "time"
    names(df)[names(df) == "datetime"] <- "time"
  }
  df
}
