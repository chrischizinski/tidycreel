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
#' interviews. Interviews with zero total catch have no rows in this dataset
#' (zero-catch anglers are represented by absence).
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
#' data(example_calendar)
#' data(example_interviews)
#' data(example_catch)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   harvest = catch_kept,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#' print(design)
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
"example_lengths"

#' Example calendar for spatially stratified creel survey
#'
#' A 12-day survey calendar used to demonstrate the spatially stratified
#' workflow with [add_sections()]. Contains 6 weekdays and 6 weekends from
#' June 2024. Matches the date range of [example_sections_counts] and
#' [example_sections_interviews].
#'
#' @format A data frame with 12 rows and 2 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), June 2024}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' data(example_sections_calendar)
#' head(example_sections_calendar)
#'
#' design <- creel_design(example_sections_calendar, date = date, strata = day_type)
#' print(design)
#'
#' @seealso [example_sections_counts], [example_sections_interviews],
#'   [add_sections()], [creel_design()]
"example_sections_calendar"

#' Example effort counts for spatially stratified creel survey
#'
#' Instantaneous count observations for a 3-section lake (North, Central, South)
#' covering 12 survey dates. Each section has one count row per date (36 rows
#' total). Effort varies materially by section: Central has the highest angler
#' traffic, South the lowest. Use with [add_sections()] and [add_counts()].
#'
#' @format A data frame with 36 rows and 4 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), matching [example_sections_calendar]}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}}
#'   \item{section}{Section identifier: \code{"North"}, \code{"Central"}, or
#'     \code{"South"}}
#'   \item{effort_hours}{Numeric instantaneous count of angler-hours observed}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' data(example_sections_calendar)
#' data(example_sections_counts)
#'
#' sections_df <- data.frame(
#'   section = c("North", "Central", "South"),
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(example_sections_calendar, date = date, strata = day_type)
#' design <- add_sections(design, sections_df, section_col = section)
#' design <- suppressWarnings(add_counts(design, example_sections_counts))
#' estimate_effort(design)
#'
#' @seealso [example_sections_calendar], [example_sections_interviews],
#'   [add_counts()], [add_sections()], [estimate_effort()]
"example_sections_counts"

#' Example interview data for spatially stratified creel survey
#'
#' Angler interview data for a 3-section lake (North, Central, South) with
#' 9 interviews per section (27 total). Catch rates differ materially across
#' sections: South has approximately 2.5x the catch rate of North, making this
#' dataset suitable for demonstrating spatially stratified estimation. The
#' \code{catch_kept} column enables [estimate_total_harvest()] in addition to
#' [estimate_catch_rate()] and [estimate_total_catch()].
#'
#' @format A data frame with 27 rows and 9 columns:
#' \describe{
#'   \item{date}{Interview date (Date class), matching [example_sections_calendar]}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}}
#'   \item{section}{Section identifier: \code{"North"}, \code{"Central"}, or
#'     \code{"South"}}
#'   \item{catch_total}{Integer total fish caught per interview}
#'   \item{catch_kept}{Integer fish harvested (kept); always
#'     \code{<= catch_total}}
#'   \item{hours_fished}{Numeric fishing effort in hours}
#'   \item{trip_status}{Character trip completion status; \code{"complete"}
#'     for all 27 interviews}
#'   \item{trip_duration}{Numeric trip duration in hours}
#'   \item{interview_id}{Integer interview identifier (1 to 27)}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' data(example_sections_calendar)
#' data(example_sections_counts)
#' data(example_sections_interviews)
#'
#' sections_df <- data.frame(
#'   section = c("North", "Central", "South"),
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(example_sections_calendar, date = date, strata = day_type)
#' design <- add_sections(design, sections_df, section_col = section)
#' design <- suppressWarnings(add_counts(design, example_sections_counts))
#' design <- suppressWarnings(add_interviews(design, example_sections_interviews,
#'   catch = catch_total, effort = hours_fished,
#'   harvest = catch_kept,
#'   trip_status = trip_status, trip_duration = trip_duration
#' ))
#' estimate_total_catch(design, aggregate_sections = TRUE)
#'
#' @seealso [example_sections_calendar], [example_sections_counts],
#'   [add_interviews()], [estimate_catch_rate()], [estimate_total_catch()]
"example_sections_interviews"

#' Example sampling frame for ice fishing creel survey
#'
#' A minimal sampling frame for a Nebraska ice fishing creel survey at Lake
#' McConaughy. Contains 12 weekend sampling days across January-February 2024.
#' Ice fishing surveys are a degenerate bus-route design where all access points
#' are sampled with certainty (\code{p_site = 1.0}), so only the period
#' sampling probability (\code{p_period}) is specified.
#'
#' @format A data frame with 12 rows and 3 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), January-February 2024}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}}
#'   \item{p_period}{Numeric period sampling probability in \code{(0, 1]}.
#'     The probability that a given period is included in the sample.}
#' }
#'
#' @source Simulated data based on Nebraska ice fishing survey protocols.
#'
#' @examples
#' data(example_ice_sampling_frame)
#' head(example_ice_sampling_frame)
#'
#' # Build an ice fishing design with scalar period sampling probability
#' design <- creel_design(
#'   example_ice_sampling_frame,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "ice",
#'   effort_type = "time_on_ice",
#'   p_period = 0.5
#' )
#' print(design)
#'
#' @seealso [example_ice_interviews] for matching interview data,
#'   [creel_design()] for ice survey design construction
"example_ice_sampling_frame"

#' Example interview data for ice fishing creel survey
#'
#' Angler interview data for an ice fishing creel survey at Lake McConaughy,
#' Nebraska. Contains 72 interviews across 12 sampling days in January-February
#' 2024. Anglers fish from both open-air setups and enclosed dark-house shelters,
#' targeting walleye and yellow perch. Dates match [example_ice_sampling_frame].
#'
#' @format A data frame with 72 rows and 10 columns:
#' \describe{
#'   \item{date}{Interview date (Date class), matching [example_ice_sampling_frame]}
#'   \item{n_counted}{Integer total number of angler parties counted at the
#'     access point during the sampling period}
#'   \item{n_interviewed}{Integer number of parties actually interviewed;
#'     always \code{<= n_counted}}
#'   \item{hours_on_ice}{Numeric hours the angler party was physically on the
#'     ice (total time-on-ice effort)}
#'   \item{active_fishing_hours}{Numeric hours spent actively fishing, excluding
#'     travel, setup, and breaks; always \code{<= hours_on_ice}}
#'   \item{walleye_catch}{Integer total walleye caught (kept + released)}
#'   \item{perch_catch}{Integer total yellow perch caught (kept + released)}
#'   \item{walleye_kept}{Integer walleye harvested; always \code{<= walleye_catch}}
#'   \item{perch_kept}{Integer yellow perch harvested; always \code{<= perch_catch}}
#'   \item{trip_status}{Character trip completion status: \code{"complete"} or
#'     \code{"incomplete"}}
#'   \item{shelter_mode}{Character shelter type used by the angler party:
#'     \code{"open"} (no shelter) or \code{"dark_house"} (enclosed shelter).
#'     Used to stratify effort estimates by shelter type.}
#' }
#'
#' @source Simulated data based on Nebraska ice fishing survey protocols.
#'
#' @examples
#' data(example_ice_sampling_frame)
#' data(example_ice_interviews)
#'
#' # Build an ice fishing design with scalar period sampling probability
#' design <- creel_design(
#'   example_ice_sampling_frame,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "ice",
#'   effort_type = "time_on_ice",
#'   p_period = 0.5
#' )
#'
#' design <- suppressMessages(add_interviews(
#'   design,
#'   example_ice_interviews,
#'   catch = walleye_catch,
#'   effort = hours_on_ice,
#'   harvest = walleye_kept,
#'   trip_status = trip_status,
#'   n_counted = n_counted,
#'   n_interviewed = n_interviewed
#' ))
#' suppressWarnings(estimate_effort(design))
#'
#' @seealso [example_ice_sampling_frame] for the matching sampling frame,
#'   [creel_design()], [add_interviews()], [estimate_effort()]
"example_ice_interviews"

#' Example camera counts dataset (counter mode)
#'
#' A dataset of daily ingress counts from a remote camera at a boat launch.
#' Contains 10 rows covering non-consecutive sampling days in June 2024.
#' Includes one row with \code{camera_status = "battery_failure"} and
#' \code{ingress_count = NA} demonstrating informative gap handling.
#'
#' @format A data frame with 10 rows and 4 variables:
#' \describe{
#'   \item{date}{Survey date (Date class), non-consecutive days in June 2024.}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}.}
#'   \item{ingress_count}{Daily ingress angler count (integer).
#'     \code{NA} when the camera was not operational.}
#'   \item{camera_status}{Camera operational status. One of
#'     \code{"operational"}, \code{"battery_failure"}, \code{"memory_full"},
#'     or \code{"occlusion"}.}
#' }
#'
#' @source Simulated for package documentation.
#'
#' @examples
#' data(example_camera_counts)
#' head(example_camera_counts)
#'
#' # Filter to operational rows before adding to a camera design
#' data(example_calendar)
#' design <- creel_design(
#'   example_calendar,
#'   date = date, strata = day_type,
#'   survey_type = "camera",
#'   camera_mode = "counter"
#' )
#' counts_clean <- subset(example_camera_counts, camera_status == "operational")
#' design <- suppressWarnings(add_counts(design, counts_clean))
#'
#' @seealso [example_camera_timestamps], [example_camera_interviews],
#'   [creel_design()], [add_counts()]
"example_camera_counts"

#' Example camera timestamps dataset (ingress-egress mode)
#'
#' A dataset of raw ingress and egress timestamps recorded by a remote camera
#' at a boat launch. Contains 14 rows spanning 4 sampling days in June 2024
#' (3-4 anglers per day). Suitable for use with
#' \code{\link{preprocess_camera_timestamps}}.
#' One row has a trip duration greater than 8 hours (an unusually long fishing
#' day); all other durations are between 1.5 and 5.5 hours.
#'
#' @format A data frame with 14 rows and 4 variables:
#' \describe{
#'   \item{date}{Survey date (Date class), June 2024.}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}.}
#'   \item{ingress_time}{Angler arrival time (POSIXct, America/Chicago timezone).}
#'   \item{egress_time}{Angler departure time (POSIXct, America/Chicago timezone).
#'     Always later than \code{ingress_time}.}
#' }
#'
#' @source Simulated for package documentation.
#'
#' @examples
#' data(example_camera_timestamps)
#' head(example_camera_timestamps)
#'
#' # Preprocess to daily effort hours
#' daily_effort <- preprocess_camera_timestamps(
#'   example_camera_timestamps,
#'   date_col = date,
#'   ingress_col = ingress_time,
#'   egress_col = egress_time
#' )
#' head(daily_effort)
#'
#' @seealso [example_camera_counts], [example_camera_interviews],
#'   [preprocess_camera_timestamps()]
"example_camera_timestamps"

#' Example interview data for camera-monitored creel survey
#'
#' Angler interview data for a summer creel survey at a camera-monitored boat
#' launch. Contains 40 interviews across 8 sampling days in June 2024,
#' targeting walleye and bass. All interviews are complete trips. Dates match
#' the date range in \code{\link{example_camera_counts}}.
#'
#' @format A data frame with 40 rows and 8 variables:
#' \describe{
#'   \item{date}{Interview date (Date class), June 2024.}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}.}
#'   \item{trip_status}{Trip completion status: \code{"complete"} for all 40
#'     interviews.}
#'   \item{hours_fished}{Numeric fishing effort in hours (range 0.5-5.0).}
#'   \item{walleye}{Integer total walleye caught (kept + released).}
#'   \item{walleye_kept}{Integer walleye harvested; always
#'     \code{<= walleye}.}
#'   \item{bass}{Integer total bass caught (kept + released).}
#'   \item{bass_kept}{Integer bass harvested; always \code{<= bass}.}
#' }
#'
#' @source Simulated for package documentation.
#'
#' @examples
#' data(example_camera_counts)
#' data(example_camera_interviews)
#'
#' # Build a calendar that spans all camera dataset dates
#' cam_dates <- sort(unique(c(
#'   example_camera_counts$date,
#'   example_camera_interviews$date
#' )))
#' cam_cal <- data.frame(
#'   date = cam_dates,
#'   day_type = ifelse(
#'     weekdays(cam_dates) %in% c("Saturday", "Sunday"),
#'     "weekend", "weekday"
#'   ),
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(
#'   cam_cal,
#'   date = date, strata = day_type,
#'   survey_type = "camera",
#'   camera_mode = "counter"
#' )
#' counts_clean <- subset(example_camera_counts, camera_status == "operational")
#' design <- suppressWarnings(add_counts(design, counts_clean))
#' design <- suppressWarnings(add_interviews(
#'   design, example_camera_interviews,
#'   catch = walleye, effort = hours_fished, trip_status = trip_status
#' ))
#' suppressWarnings(estimate_catch_rate(design))
#'
#' @seealso [example_camera_counts], [example_camera_timestamps],
#'   [add_interviews()], [estimate_catch_rate()], [estimate_total_catch()]
"example_camera_interviews"

#' Example aerial angler count dataset
#'
#' A dataset of instantaneous angler counts from aerial overflights of a
#' Nebraska reservoir, used to demonstrate aerial survey effort estimation.
#' Contains 16 rows representing one overflight per sampling day across an
#' 8-week summer season (June-July 2024). Weekday and weekend counts vary
#' realistically to produce non-trivial between-day variance in the effort
#' estimate.
#'
#' @format A data frame with 16 rows and 3 variables:
#' \describe{
#'   \item{date}{Survey date (Date class), June-July 2024.}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}.}
#'   \item{n_anglers}{Instantaneous angler count from one aerial overflight
#'     (integer). Weekday counts range 15-40; weekend counts range 40-80.}
#' }
#'
#' @source Simulated for package documentation.
#'
#' @examples
#' data(example_aerial_counts)
#' head(example_aerial_counts)
#'
#' # Build a calendar from count dates and construct an aerial design
#' aerial_cal <- data.frame(
#'   date = example_aerial_counts$date,
#'   day_type = example_aerial_counts$day_type,
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(
#'   aerial_cal,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "aerial",
#'   h_open = 14
#' )
#' print(design)
#'
#' @seealso [example_aerial_interviews] for matching interview data,
#'   [creel_design()], [add_counts()], [estimate_effort()]
"example_aerial_counts"

#' Example angler interview data for aerial creel survey
#'
#' Angler interview data for an aerial creel survey at a Nebraska reservoir.
#' Contains 48 interviews across 16 sampling days in June-July 2024, with
#' 3 interviews per sampling day. Anglers target walleye and bass. All
#' interviews are complete trips. Dates match \code{\link{example_aerial_counts}}.
#'
#' @format A data frame with 48 rows and 8 variables:
#' \describe{
#'   \item{date}{Interview date (Date class), June-July 2024.}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"}.}
#'   \item{trip_status}{Trip completion status: \code{"complete"} for all 48
#'     interviews.}
#'   \item{hours_fished}{Numeric trip duration in hours (range 1.0-5.0).
#'     This column feeds the mean trip duration (\eqn{\bar{L}}) used in
#'     \code{\link{estimate_catch_rate}}.}
#'   \item{walleye_catch}{Integer total walleye caught (kept + released).}
#'   \item{walleye_kept}{Integer walleye harvested; always
#'     \code{<= walleye_catch}.}
#'   \item{bass_catch}{Integer total bass caught (kept + released).}
#'   \item{bass_kept}{Integer bass harvested; always \code{<= bass_catch}.}
#' }
#'
#' @source Simulated for package documentation.
#'
#' @examples
#' data(example_aerial_counts)
#' data(example_aerial_interviews)
#'
#' # Build an aerial design and add interview data
#' aerial_cal <- data.frame(
#'   date = example_aerial_counts$date,
#'   day_type = example_aerial_counts$day_type,
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(
#'   aerial_cal,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "aerial",
#'   h_open = 14
#' )
#' design <- add_counts(design, example_aerial_counts)
#' design <- suppressWarnings(add_interviews(
#'   design,
#'   example_aerial_interviews,
#'   catch = walleye_catch,
#'   effort = hours_fished,
#'   trip_status = trip_status
#' ))
#' suppressWarnings(estimate_catch_rate(design))
#'
#' @seealso [example_aerial_counts] for matching count data,
#'   [creel_design()], [add_interviews()], [estimate_catch_rate()],
#'   [estimate_total_catch()]
"example_aerial_interviews"

#' Example multi-flight aerial count data for GLMM effort estimation
#'
#' Simulated instantaneous angler counts from aerial overflights of a Nebraska
#' reservoir, designed to demonstrate GLMM-based effort estimation following
#' Askey (2018). Contains 48 rows: 12 survey days with 4 overflights per day
#' at fixed hours (07:00, 10:00, 13:00, 16:00). Counts follow a diurnal curve
#' (low at dawn, peak mid-morning, lower in afternoon) with day-level Poisson
#' variability and a day random intercept.
#'
#' @format A data frame with 48 rows and 4 columns:
#' \describe{
#'   \item{date}{Survey date (Date class), 12 days spaced 3 days apart starting
#'     2024-06-03.}
#'   \item{day_type}{Day type stratum: \code{"weekday"} or \code{"weekend"},
#'     derived from the calendar date.}
#'   \item{n_anglers}{Instantaneous angler count from one aerial overflight
#'     (integer). Follows a diurnal curve with day-level random effects.}
#'   \item{time_of_flight}{Hour of the aerial overflight (numeric). One of
#'     \code{7.0}, \code{10.0}, \code{13.0}, or \code{16.0}.}
#' }
#'
#' @source Simulated data following Askey (2018) NAJFM doi:10.1002/nafm.10010.
#'
#' @references
#'   Askey, P.J., et al. (2018). Correcting for non-random flight timing in
#'   aerial creel surveys using a generalized linear mixed model.
#'   North American Journal of Fisheries Management, 38, 1204-1215.
#'   \doi{10.1002/nafm.10010}
#'
#' @examples
#' data(example_aerial_glmm_counts)
#' head(example_aerial_glmm_counts)
#'
#' \dontrun{
#' # Build an aerial design and estimate effort with GLMM correction
#' aerial_cal <- data.frame(
#'   date = unique(example_aerial_glmm_counts$date),
#'   day_type = unique(example_aerial_glmm_counts[, c("date", "day_type")])[["day_type"]],
#'   stringsAsFactors = FALSE
#' )
#' design <- creel_design(
#'   aerial_cal,
#'   date = date,
#'   strata = day_type,
#'   survey_type = "aerial",
#'   h_open = 14
#' )
#' design <- add_counts(design, example_aerial_glmm_counts)
#' result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
#' print(result)
#' }
#'
#' @seealso [example_aerial_counts] for the simple single-flight dataset,
#'   [estimate_effort_aerial_glmm()] for the GLMM-based estimator,
#'   [creel_design()], [add_counts()]
"example_aerial_glmm_counts"

#' Toy count data for data validation examples
#'
#' A small creel count data frame designed for demonstrating
#' `validate_creel_data()` and related data-cleaning functions. Contains
#' an intentional `NA` in the `count` column to trigger the NA-rate check.
#'
#' @format A data frame with 6 rows and 4 columns:
#' \describe{
#'   \item{date}{Survey date (Date class).}
#'   \item{day_type}{Day type stratum: `"weekday"` or `"weekend"`.}
#'   \item{section}{Survey section: `"A"` or `"B"`.}
#'   \item{count}{Instantaneous angler count; one row is intentionally `NA`.}
#' }
#'
#' @source Simulated data for package examples and vignettes.
#'
#' @examples
#' data(creel_counts_toy)
#' \dontrun{
#' validate_creel_data(counts = creel_counts_toy)
#' }
#'
#' @seealso [creel_interviews_toy]
"creel_counts_toy"

#' Toy interview data for data validation examples
#'
#' A small creel interview data frame with intentional data quality issues
#' for demonstrating `validate_creel_data()` and `standardize_species()`.
#' Includes an empty species string, a negative `fish_kept` value, and a
#' missing `trip_hours` value.
#'
#' @format A data frame with 6 rows and 5 columns:
#' \describe{
#'   \item{date}{Interview date (Date class).}
#'   \item{day_type}{Day type stratum: `"weekday"` or `"weekend"`.}
#'   \item{species}{Free-text species name; includes empty string and
#'     unrecognised value to demonstrate `standardize_species()` behaviour.}
#'   \item{fish_kept}{Number of fish kept; one row is intentionally negative.}
#'   \item{trip_hours}{Trip duration in hours; one row is intentionally `NA`.}
#' }
#'
#' @source Simulated data for package examples and vignettes.
#'
#' @examples
#' data(creel_interviews_toy)
#' \dontrun{
#' validate_creel_data(interviews = creel_interviews_toy)
#' standardize_species(creel_interviews_toy, species_col = "species")
#' }
#'
#' @seealso [creel_counts_toy]
"creel_interviews_toy"
