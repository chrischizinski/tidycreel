# Internal canonical column requirements per survey type — not exported
# Keys: survey type -> table name -> character vector of required canonical col names
CANONICAL_COLUMNS <- list( # nolint: object_name_linter
  instantaneous = list(
    interviews = c("date", "catch", "effort", "trip_status"),
    counts     = c("date", "count"),
    catch      = c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"),
    lengths    = c("length_uid", "interview_uid", "species", "length_mm", "length_type")
  ),
  bus_route = list(
    interviews = c("date", "catch", "effort", "trip_status"),
    counts     = c("date", "count"),
    catch      = c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"),
    lengths    = c("length_uid", "interview_uid", "species", "length_mm", "length_type")
  ),
  ice = list(
    interviews = c("date", "catch", "effort", "trip_status"),
    counts     = c("date", "count"),
    catch      = c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"),
    lengths    = c("length_uid", "interview_uid", "species", "length_mm", "length_type")
  ),
  camera = list(
    counts = c("date", "count")
  ),
  aerial = list(
    counts = c("date", "count")
  )
)

# Column-to-table mapping for print grouping (internal)
# nolint: object_name_linter
COL_TO_TABLE <- list( # nolint: object_name_linter
  interviews = c(
    "date_col", "catch_col", "effort_col", "trip_status_col",
    "harvest_col", "trip_duration_col", "trip_start_col",
    "interview_time_col", "n_anglers_col", "n_interviewed_col",
    "angler_type_col", "angler_method_col", "species_sought_col",
    "refused_col", "interview_uid_col"
  ),
  counts = c(
    "count_col", "n_counted_col"
  ),
  catch = c(
    "catch_uid_col", "species_col", "catch_count_col", "catch_type_col"
  ),
  lengths = c(
    "length_uid_col", "length_mm_col", "length_type_col"
  )
)

# Internal constructor — not exported
#' @noRd
#' @keywords internal
new_creel_schema <- function(survey_type, mappings) {
  stopifnot(is.character(survey_type), length(survey_type) == 1L)
  stopifnot(is.list(mappings))
  structure(c(list(survey_type = survey_type), mappings), class = "creel_schema")
}


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
#' @param catch_count_col Column name for catch count in the catch table.
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
#' @family "Survey Design"
#' @export
#' @examples
#' s <- creel_schema(
#'   survey_type      = "instantaneous",
#'   interviews_table = "vwInterviews",
#'   counts_table     = "vwCounts",
#'   date_col         = "SurveyDate",
#'   catch_col        = "TotalCatch",
#'   effort_col       = "EffortHours",
#'   trip_status_col  = "TripStatus",
#'   count_col        = "AnglerCount"
#' )
#' print(s)
creel_schema <- function(
  survey_type = c("instantaneous", "bus_route", "ice", "camera", "aerial"),
  interviews_table = NULL,
  counts_table = NULL,
  catch_table = NULL,
  lengths_table = NULL,
  date_col = NULL,
  catch_col = NULL,
  effort_col = NULL,
  trip_status_col = NULL,
  count_col = NULL,
  catch_uid_col = NULL,
  interview_uid_col = NULL,
  species_col = NULL,
  catch_count_col = NULL,
  catch_type_col = NULL,
  length_uid_col = NULL,
  length_mm_col = NULL,
  length_type_col = NULL,
  harvest_col = NULL,
  trip_duration_col = NULL,
  trip_start_col = NULL,
  interview_time_col = NULL,
  n_anglers_col = NULL,
  n_counted_col = NULL,
  n_interviewed_col = NULL,
  angler_type_col = NULL,
  angler_method_col = NULL,
  species_sought_col = NULL,
  refused_col = NULL
) {
  survey_type <- match.arg(survey_type)
  new_creel_schema(survey_type, list(
    interviews_table   = interviews_table,
    counts_table       = counts_table,
    catch_table        = catch_table,
    lengths_table      = lengths_table,
    date_col           = date_col,
    catch_col          = catch_col,
    effort_col         = effort_col,
    trip_status_col    = trip_status_col,
    count_col          = count_col,
    catch_uid_col      = catch_uid_col,
    interview_uid_col  = interview_uid_col,
    species_col        = species_col,
    catch_count_col    = catch_count_col,
    catch_type_col     = catch_type_col,
    length_uid_col     = length_uid_col,
    length_mm_col      = length_mm_col,
    length_type_col    = length_type_col,
    harvest_col        = harvest_col,
    trip_duration_col  = trip_duration_col,
    trip_start_col     = trip_start_col,
    interview_time_col = interview_time_col,
    n_anglers_col      = n_anglers_col,
    n_counted_col      = n_counted_col,
    n_interviewed_col  = n_interviewed_col,
    angler_type_col    = angler_type_col,
    angler_method_col  = angler_method_col,
    species_sought_col = species_sought_col,
    refused_col        = refused_col
  ))
}


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
#' @family "Survey Design"
#' @export
validate_creel_schema <- function(schema) {
  if (!inherits(schema, "creel_schema")) {
    cli::cli_abort(
      c(
        "{.arg schema} must be a {.cls creel_schema} object.",
        "i" = "Create one with {.fn creel_schema}."
      ),
      class = "creel_error_schema_validation"
    )
  }

  required <- CANONICAL_COLUMNS[[schema$survey_type]] # nolint: object_name_linter

  missing_bullets <- character(0)
  for (table in names(required)) {
    for (col in required[[table]]) {
      field <- paste0(col, "_col")
      if (is.null(schema[[field]])) {
        missing_bullets <- c(
          missing_bullets,
          stats::setNames(
            paste0(col, " (", table, " table) is missing"),
            "x"
          )
        )
      }
    }
  }

  if (length(missing_bullets) > 0) {
    cli::cli_abort(
      c(
        "creel_schema validation failed for survey_type {.val {schema$survey_type}}:",
        missing_bullets
      ),
      class = "creel_error_schema_validation"
    )
  }

  invisible(schema)
}


#' Format method for creel_schema
#'
#' @param x A `creel_schema` object.
#' @param ... Ignored.
#' @return A character vector of formatted lines.
#' @export
format.creel_schema <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_text("<creel_schema: {x$survey_type}>")

    table_fields <- c(
      interviews_table = "interviews",
      counts_table     = "counts",
      catch_table      = "catch",
      lengths_table    = "lengths"
    )

    for (tbl_field in names(table_fields)) {
      tbl_name <- x[[tbl_field]]
      tbl_key <- table_fields[[tbl_field]]
      cols <- COL_TO_TABLE[[tbl_key]] # nolint: object_name_linter
      mapped <- Filter(function(f) !is.null(x[[f]]), cols)

      if (!is.null(tbl_name) || length(mapped) > 0) {
        cli::cli_h2("{tbl_key}: {if (is.null(tbl_name)) '(not set)' else tbl_name}")
        for (cf in mapped) {
          cli::cli_text("  {sub('_col$', '', cf)} -> {x[[cf]]}")
        }
      }
    }
  })
}


#' Print method for creel_schema
#'
#' @param x A `creel_schema` object.
#' @param ... Passed to [format.creel_schema()].
#' @return `invisible(x)`.
#' @export
print.creel_schema <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
