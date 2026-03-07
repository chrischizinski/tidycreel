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
#' angler interview with catch, harvest, effort, trip metadata, and extended
#' interview attributes added in v0.5.0.
#'
#' @format A data frame with 22 rows and 12 columns:
#' \describe{
#'   \item{date}{Interview date (Date class), matching [example_calendar] dates}
#'   \item{hours_fished}{Numeric fishing effort in hours}
#'   \item{catch_total}{Integer total fish caught (kept + released)}
#'   \item{catch_kept}{Integer fish kept (harvest), always <= catch_total}
#'   \item{trip_status}{Character trip completion status ("complete" or "incomplete")}
#'   \item{trip_duration}{Numeric trip duration in hours}
#'   \item{interview_id}{Integer interview identifier (1 to 22), primary join key
#'     for \code{add_catch()} and future species-level data functions}
#'   \item{angler_type}{Angler party type: \code{"bank"} or \code{"boat"}}
#'   \item{angler_method}{Fishing method: \code{"bait"}, \code{"artificial"}, or
#'     \code{"fly"}}
#'   \item{species_sought}{Primary target species: \code{"walleye"}, \code{"bass"},
#'     or \code{"panfish"}}
#'   \item{n_anglers}{Integer number of anglers in party (1 to 4)}
#'   \item{refused}{Logical flag indicating a refused interview
#'     (\code{FALSE} for all 22 accepted interviews)}
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
#'   catch = catch_total,
#'   effort = hours_fished,
#'   harvest = catch_kept,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration,
#'   angler_type = angler_type,
#'   angler_method = angler_method,
#'   species_sought = species_sought,
#'   n_anglers = n_anglers,
#'   refused = refused
#' )
#' print(design)
#'
#' @seealso [example_calendar] for matching calendar data, [example_catch] for
#'   species-level catch data, [add_interviews()] to attach interviews to a design
"example_interviews"

#' Example species catch data for creel survey
#'
#' Long-format species-level catch data linked to [example_interviews]. Contains
#' catch, harvest, and release counts per species per interview for 12 of the 22
#' interviews. Suitable for use with \code{add_catch()} once that function is
#' available (Phase 29 Plan 02). Interviews with zero total catch have no rows
#' in this dataset (zero-catch anglers are represented by absence).
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{interview_id}{Integer, foreign key to [example_interviews]\code{$interview_id}}
#'   \item{species}{Character species name: \code{"walleye"}, \code{"bass"}, or
#'     \code{"panfish"}}
#'   \item{count}{Integer fish count for this species and catch type}
#'   \item{catch_type}{Character catch disposition: \code{"caught"} (total observed),
#'     \code{"harvested"} (kept), or \code{"released"}}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' \dontrun{
#' # Requires add_catch() from Phase 29 Plan 02
#' data(example_interviews)
#' data(example_catch)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   harvest = catch_kept
#' )
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' }
#'
#' @seealso [example_interviews] for the corresponding interview-level data,
#'   \code{add_catch()} to attach species catch to a design
"example_catch"

#' Example fish length data for creel survey
#'
#' Mixed-format length data containing individual harvest measurements (numeric,
#' in mm) and binned release counts (character bin labels) linked to
#' \code{\link{example_interviews}}. Suitable for use with
#' \code{\link{add_lengths}}.
#'
#' @format A data frame with 20 rows and 5 columns:
#' \describe{
#'   \item{interview_id}{Integer interview identifier. Foreign key to
#'     \code{example_interviews$interview_id}.}
#'   \item{species}{Character. Species name: \code{"walleye"},
#'     \code{"bass"}, or \code{"panfish"}.}
#'   \item{length}{Character. For harvest rows, a numeric length in mm
#'     (stored as character due to mixed column). For release rows, a bin
#'     label such as \code{"300-350"}.}
#'   \item{length_type}{Character. Measurement fate: \code{"harvest"} or
#'     \code{"release"}.}
#'   \item{count}{Integer. \code{NA_integer_} for harvest rows (individual
#'     measurements); positive integer count for release rows (binned format).}
#' }
#'
#' @source Simulated data for package examples.
#'
#' @seealso \code{\link{example_interviews}}, \code{\link{example_catch}},
#'   \code{\link{add_lengths}}
#'
#' @examples
#' \dontrun{
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#' design <- add_lengths(design, example_lengths,
#'   length_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   length = length,
#'   length_type = length_type,
#'   count = count,
#'   release_format = "binned"
#' )
#' print(design)
#' }
"example_lengths"
