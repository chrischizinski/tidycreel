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

#' Example interview data for creel survey
#'
#' Sample angler interview data demonstrating the structure required for
#' [add_interviews()]. Contains 22 interviews from June 1-14, 2024,
#' matching the [example_calendar] date range. Each row represents one
#' completed angler interview with catch, harvest, and effort information.
#'
#' @format A data frame with 22 rows and 4 columns:
#' \describe{
#'   \item{date}{Interview date (Date class), matching [example_calendar] dates}
#'   \item{hours_fished}{Numeric fishing effort in hours}
#'   \item{catch_total}{Integer total fish caught (kept + released)}
#'   \item{catch_kept}{Integer fish kept (harvest), always <= catch_total}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' # Load and use with a creel design
#' data(example_calendar)
#' data(example_interviews)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'                          catch = catch_total,
#'                          effort = hours_fished,
#'                          harvest = catch_kept)
#' print(design)
#'
#' @seealso [example_calendar] for matching calendar data, [add_interviews()] to
#'   attach interviews to a design
"example_interviews"
