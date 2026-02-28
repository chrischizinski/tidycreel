#' Example calendar data for creel survey
#'
#' A sample survey calendar dataset demonstrating the structure required for
#' [creel_design()]. Contains 14 days (June 1-14, 2024) with weekday/weekend
#' strata, representing a two-week survey period.
#'
#' @format A data frame with 14 rows and 2 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), June 1-14, 2024}
#'   \item{day_type}{Day type stratum: "weekday" or "weekend"}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' # Load and inspect
#' data(example_calendar)
#' head(example_calendar)
#'
#' # Create a creel design
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' print(design)
#'
#' @seealso [example_counts] for matching count data, [creel_design()] to
#'   create a design from calendar data
"example_calendar"

#' Example count data for creel survey
#'
#' Sample instantaneous count observations matching [example_calendar].
#' Contains effort measurements for each survey date, suitable for use
#' with [add_counts()] and [estimate_effort()].
#'
#' @format A data frame with 14 rows and 3 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), matching [example_calendar] dates}
#'   \item{day_type}{Day type stratum: "weekday" or "weekend", matching calendar}
#'   \item{effort_hours}{Numeric count variable: total angler-hours observed}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' # Load and use with a creel design
#' data(example_calendar)
#' data(example_counts)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' result <- estimate_effort(design)
#' print(result)
#'
#' @seealso [example_calendar] for matching calendar data, [add_counts()] to
#'   attach counts to a design
"example_counts"
