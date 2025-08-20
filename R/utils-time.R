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
