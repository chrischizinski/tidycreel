#' Column-mapping contract for tidycreel data sources
#'
#' @description
#' `creel_schema()` constructs a `creel_schema` S3 object that maps canonical
#' tidycreel column names to actual column and table names in a data source.
#' The schema is the full connection contract consumed by `creel_connect()` and
#' `fetch_*()` functions in the tidycreel.connect companion package.
#'
#' Construction is permissive — all column arguments default to `NULL`. Use
#' [validate_creel_schema()] to check that required columns for the given
#' survey type are mapped.
#'
#' @param survey_type Survey type. One of `"instantaneous"`, `"bus_route"`,
#'   `"ice"`, `"camera"`, or `"aerial"`. Validated at construction via
#'   `match.arg()`.
#' @param interviews_table Name of the interviews table in the data source.
#' @param counts_table Name of the counts table in the data source.
#' @param catch_table Name of the catch table in the data source.
#' @param lengths_table Name of the lengths table in the data source.
#' @param date_col Column name for survey date.
#' @param catch_col Column name for catch count in interviews.
#' @param effort_col Column name for effort (hours) in interviews.
#' @param trip_status_col Column name for trip status in interviews.
#' @param count_col Column name for angler count in counts.
#' @param catch_uid_col Column name for catch unique identifier.
#' @param interview_uid_col Column name for interview unique identifier.
#' @param species_col Column name for species.
#' @param catch_count_col Column name for catch count in catch table.
#' @param catch_type_col Column name for catch type (harvest/release).
#' @param length_uid_col Column name for length unique identifier.
#' @param length_mm_col Column name for fish length (mm).
#' @param length_type_col Column name for length type.
#' @param harvest_col Column name for harvest count.
#' @param trip_duration_col Column name for trip duration.
#' @param trip_start_col Column name for trip start time.
#' @param interview_time_col Column name for interview time.
#' @param n_anglers_col Column name for number of anglers.
#' @param n_counted_col Column name for number of anglers counted.
#' @param n_interviewed_col Column name for number of anglers interviewed.
#' @param angler_type_col Column name for angler type.
#' @param angler_method_col Column name for fishing method.
#' @param species_sought_col Column name for target species.
#' @param refused_col Column name for refused interviews indicator.
#'
#' @return A `creel_schema` S3 object.
#' @export
#' @examples
#' s <- creel_schema(
#'   survey_type = "instantaneous",
#'   interviews_table = "vwInterviews",
#'   counts_table = "vwCounts",
#'   date_col = "SurveyDate",
#'   catch_col = "TotalCatch",
#'   effort_col = "EffortHours",
#'   trip_status_col = "TripStatus",
#'   count_col = "AnglerCount"
#' )
#' print(s)
creel_schema <- function(...) stop("not yet implemented") # nolint: args_definition_linter


#' Validate a creel_schema object
#'
#' @description
#' Checks that all columns required for the schema's `survey_type` are mapped
#' (non-NULL). Aborts with an informative `cli_abort()` listing each missing
#' column and its table.
#'
#' @param schema A `creel_schema` object created by [creel_schema()].
#'
#' @return `invisible(schema)` if all required columns are mapped.
#' @export
validate_creel_schema <- function(schema) stop("not yet implemented")


#' Format method for creel_schema
#'
#' @param x A `creel_schema` object.
#' @param ... Ignored.
#' @return A character vector of formatted lines.
#' @export
format.creel_schema <- function(x, ...) stop("not yet implemented")


#' Print method for creel_schema
#'
#' @param x A `creel_schema` object.
#' @param ... Passed to [format.creel_schema()].
#' @return `invisible(x)`.
#' @export
print.creel_schema <- function(x, ...) stop("not yet implemented")


# Internal canonical column requirements — not exported
CANONICAL_COLUMNS <- list() # nolint: object_name_linter
