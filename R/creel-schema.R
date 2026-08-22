# Internal canonical column requirements per survey type — not exported
# Keys: survey type -> table name -> character vector of required canonical col names
CANONICAL_COLUMNS <- list(
  # nolint: object_name_linter
  instantaneous = list(
    interviews = c("date", "catch", "effort", "trip_status"),
    counts = c("date", "count"),
    catch = c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"),
    lengths = c("length_uid", "interview_uid", "species", "length_mm", "length_type")
  ),
  bus_route = list(
    interviews = c("date", "catch", "effort", "trip_status"),
    counts = c("date", "count"),
    catch = c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"),
    lengths = c("length_uid", "interview_uid", "species", "length_mm", "length_type")
  ),
  ice = list(
    interviews = c("date", "catch", "effort", "trip_status"),
    counts = c("date", "count"),
    catch = c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"),
    lengths = c("length_uid", "interview_uid", "species", "length_mm", "length_type")
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
COL_TO_TABLE <- list(
  # nolint: object_name_linter
  interviews = c(
    "date_col",
    "strata_cols",
    "catch_col",
    "effort_col",
    "trip_status_col",
    "harvest_col",
    "trip_duration_col",
    "trip_start_col",
    "interview_time_col",
    "n_anglers_col",
    # Both enumeration columns are interviews columns: add_interviews() resolves
    # them against the interviews frame and get_enumeration_counts() reads them
    # back off it. n_counted_col was grouped under `counts` on the strength of
    # its name alone, which told a bus-route user the enumeration count lived in
    # a table it is not in, while its own denominator was listed under another
    # (GH #170).
    "n_counted_col",
    "n_interviewed_col",
    "angler_type_col",
    "site_col",
    "circuit_col",
    "angler_method_col",
    "species_sought_col",
    "refused_col",
    "interview_uid_col"
  ),
  counts = c(
    "count_col",
    "strata_cols",
    # A count row is one observation at one moment, not a day's total. The time
    # is what distinguishes two counts on the same date, and without it they
    # read as two sampled days rather than two looks at one (GH #129).
    "count_time_col",
    "bank_anglers_col",
    "angler_boats_col",
    "non_ang_boats_col"
  ),
  catch = c(
    "catch_uid_col",
    "species_col",
    "catch_count_col",
    "catch_type_col"
  ),
  lengths = c(
    "length_uid_col",
    "length_mm_col",
    # A binned length row is a bin label plus a number of fish. Both are
    # optional: a source that measures every fish maps neither (GH #127).
    "length_bin_col",
    "length_count_col",
    "length_type_col"
  )
)

# The canonical vocabularies. A source that codes these columns has to say what
# its codes mean before the values can be trusted, because every downstream
# filter matches these literals: "complete" for trip filtering, "harvested" for
# harvest aggregation, "harvest"/"release" for length type.
# nolint start: object_name_linter
CANONICAL_VOCABULARY <- list(
  trip_status = c("complete", "incomplete"),
  catch_type  = c("caught", "harvested", "released"),
  length_type = c("harvest", "release")
)
# nolint end

#' Canonical vocabularies for the coded columns
#'
#' @description
#' The exact values `tidycreel` matches on for the three columns whose meaning
#' is a fixed vocabulary rather than a number: `trip_status`, `catch_type` and
#' `length_type`. Every downstream filter compares against these literals, so a
#' source that codes one of these columns has to be translated before its values
#' can be trusted — see the `value_maps` argument of [creel_schema()].
#'
#' Exported because `tidycreel.connect` translates source codes at the fetch and
#' has to check its targets against the same list this package filters on; a
#' second copy of the vocabulary would be free to drift from this one.
#'
#' @param column Optional canonical column name. When `NULL` (default) the whole
#'   named list is returned; otherwise the character vector for that column.
#'
#' @return A named list of character vectors, or one character vector when
#'   `column` is given.
#' @family "Survey Design"
#' @export
#' @examples
#' creel_vocabulary()
#' creel_vocabulary("trip_status")
creel_vocabulary <- function(column = NULL) {
  if (is.null(column)) {
    return(CANONICAL_VOCABULARY)
  }
  if (!is.character(column) || length(column) != 1L) {
    cli::cli_abort("{.arg column} must be a single column name or {.code NULL}.")
  }
  known <- names(CANONICAL_VOCABULARY) # nolint: object_name_linter
  if (!column %in% known) {
    cli::cli_abort(c(
      "{.val {column}} has no canonical vocabulary.",
      "i" = "Columns with one: {.field {known}}."
    ))
  }
  CANONICAL_VOCABULARY[[column]]
}


# Internal: check and normalise `value_maps`.
#
# Names are the canonical column; each entry maps that column's SOURCE codes to
# canonical values, `c("1" = "complete", "2" = "incomplete")` -- names are what
# the source writes, values what tidycreel means. The targets are checked
# against CANONICAL_VOCABULARY here rather than downstream: a map declaring
# `"1" = "compleet"` would otherwise pass the fetch and abort much later, at
# add_interviews(), pointing at the data instead of at the map.
#' @noRd
#' @keywords internal
normalize_value_maps <- function(value_maps) {
  if (is.null(value_maps)) {
    return(NULL)
  }
  if (!is.list(value_maps) || length(value_maps) == 0L || is.null(names(value_maps))) {
    cli::cli_abort(
      c(
        "{.arg value_maps} must be a non-empty named list.",
        "i" = paste0(
          "Key it by canonical column, e.g. ",
          "{.code value_maps = list(trip_status = c(\"1\" = \"complete\"))}."
        )
      ),
      class = "creel_error_schema_validation"
    )
  }

  known <- names(CANONICAL_VOCABULARY) # nolint: object_name_linter
  unknown <- setdiff(names(value_maps), known)
  if (length(unknown) > 0L) {
    cli::cli_abort(
      c(
        "{.arg value_maps} names {length(unknown)} column{?s} with no canonical vocabulary.",
        "x" = "Unknown: {.field {unknown}}.",
        "i" = "Mappable columns: {.field {known}}."
      ),
      class = "creel_error_schema_validation"
    )
  }

  for (col in names(value_maps)) {
    map <- value_maps[[col]]
    valid <- CANONICAL_VOCABULARY[[col]] # nolint: object_name_linter
    if (!is.character(map) || length(map) == 0L || is.null(names(map)) || !all(nzchar(names(map)))) {
      cli::cli_abort(
        c(
          "{.arg value_maps}${.field {col}} must be a fully named character vector.",
          "i" = "Names are the source's own codes, values the canonical meaning."
        ),
        class = "creel_error_schema_validation"
      )
    }
    if (anyDuplicated(names(map))) {
      dupes <- unique(names(map)[duplicated(names(map))]) # nolint: object_usage_linter
      cli::cli_abort(
        c(
          "{.arg value_maps}${.field {col}} maps the same source code twice.",
          "x" = "Duplicated: {.val {dupes}}."
        ),
        class = "creel_error_schema_validation"
      )
    }
    bad <- setdiff(unname(map), valid)
    if (length(bad) > 0L) {
      cli::cli_abort(
        c(
          "{.arg value_maps}${.field {col}} maps to {length(bad)} value{?s} outside the vocabulary.",
          "x" = "Not canonical: {.val {bad}}.",
          "i" = "Accepted values for {.field {col}}: {.val {valid}}."
        ),
        class = "creel_error_schema_validation"
      )
    }
  }

  value_maps
}

# Internal: put `strata_cols` into its fully-named form.
#
# Unlike every other schema field, a stratum column has no canonical tidycreel
# name. `add_counts()` matches `design$strata_cols` -- the caller's own calendar
# column names -- against the names of the counts frame, so the fetch layer has
# to deliver the column under the name the design will look for, not under a
# fixed one. That makes the mapping two-sided: names are the design-facing
# column, values the source column. An unnamed entry means the two agree.
#' @noRd
#' @keywords internal
normalize_strata_cols <- function(strata_cols) {
  if (is.null(strata_cols)) {
    return(NULL)
  }
  if (!is.character(strata_cols) || length(strata_cols) == 0L) {
    cli::cli_abort(
      c(
        "{.arg strata_cols} must be a non-empty character vector.",
        "x" = "{.arg strata_cols} is {.cls {class(strata_cols)[1]}} of length {length(strata_cols)}.",
        "i" = paste0(
          "Use {.code strata_cols = c(day_type = \"DayType\")}, or ",
          "{.code c(\"day_type\")} when the source column already carries ",
          "the name the design uses."
        )
      ),
      class = "creel_error_schema_validation"
    )
  }
  if (anyNA(strata_cols) || !all(nzchar(strata_cols))) {
    cli::cli_abort(
      c(
        "{.arg strata_cols} must not contain {.val NA} or empty source names.",
        "i" = "Every stratum column named must resolve to a column in the source table."
      ),
      class = "creel_error_schema_validation"
    )
  }

  nms <- names(strata_cols)
  if (is.null(nms)) {
    nms <- rep("", length(strata_cols))
  }
  # An unnamed entry names itself on both sides.
  nms[!nzchar(nms)] <- strata_cols[!nzchar(nms)]

  if (anyDuplicated(nms)) {
    dupes <- unique(nms[duplicated(nms)]) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "{.arg strata_cols} maps the same design column more than once.",
        "x" = "Duplicated: {.field {dupes}}.",
        "i" = "Each design-facing stratum column must come from exactly one source column."
      ),
      class = "creel_error_schema_validation"
    )
  }

  stats::setNames(as.character(strata_cols), nms)
}


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
#' @param strata_cols Stratum columns to carry through from the source, as a
#'   named character vector whose names are the columns the design refers to and
#'   whose values are the source columns holding them —
#'   `c(day_type = "DayType")`. An unnamed entry, `c("day_type")`, means the
#'   source already uses the design's name. Unlike every other field here, a
#'   stratum has no canonical tidycreel name: [add_counts()] matches
#'   `design$strata_cols` — the caller's own calendar column names — against the
#'   names of the counts frame, so the mapping has to be two-sided. Without it a
#'   fetched counts frame reaches [add_counts()] with no stratum label and any
#'   design built with `strata =` aborts (GH #171).
#' @param value_maps Source vocabularies for the coded columns, as a named list
#'   keyed by canonical column — `trip_status`, `catch_type`, `length_type`.
#'   Each entry is a fully named character vector mapping the source's own codes
#'   to canonical values: `c("1" = "complete", "2" = "incomplete")`. Names are
#'   what the source writes, values what tidycreel means.
#'
#'   Every downstream filter matches the canonical literals, so a source that
#'   codes these columns has to declare what its codes mean. Values already
#'   canonical pass through untouched; anything neither mapped nor canonical
#'   aborts at the fetch, where the source is still in view, rather than being
#'   recoded by hand afterwards — a hand recode folds an undeclared third code
#'   (`"refused"`, `"unknown"`) into complete or incomplete silently (GH #128).
#' @param catch_col Column name for catch count in interviews.
#' @param effort_col Column name for effort (hours) in interviews.
#' @param trip_status_col Column name for trip status in interviews.
#' @param count_col Column name for total angler count in counts (legacy single-column format).
#' @param count_time_col Column name for the time of a count observation, such
#'   as `"16:30"` or `"am"`. Optional. Map it whenever the source records more
#'   than one count per sampled day: the fetched `count_time` column is what
#'   [add_counts()]'s `count_time_col` argument groups on, and without it those
#'   rows reach the design as separate sampled days rather than as repeat looks
#'   at one, which sums the day's effort instead of averaging it and leaves the
#'   within-day variance component uncomputed (GH #129). Carried through as
#'   character: it is a label that distinguishes observations, not a quantity,
#'   and a source may write a clock time in any format.
#' @param bank_anglers_col Column name for bank (shore) angler count in counts.
#' @param angler_boats_col Column name for boats carrying anglers in counts.
#' @param non_ang_boats_col Column name for boats carrying no anglers in counts.
#'   Recorded by some agencies and not others; leave `NULL` where it is not.
#' @param catch_uid_col Column name for catch unique identifier.
#' @param interview_uid_col Column name for interview unique identifier.
#' @param species_col Column name for species.
#' @param catch_count_col Column name for catch count in the catch table.
#' @param catch_type_col Column name for catch type (harvest/release).
#' @param length_uid_col Column name for length unique identifier.
#' @param length_mm_col Column name for fish length (mm). Map it only for
#'   individually measured fish; a bin label belongs in `length_bin_col`, whose
#'   name does not assert a unit.
#' @param length_bin_col Column name for a length-bin label, such as
#'   `"300-350"`. Optional, and mutually exclusive with `length_mm_col` on any
#'   given row: a fish is either measured or binned. Pass the fetched
#'   `length_bin` column as [add_lengths()]'s `length` argument together with
#'   `release_format = "binned"` (GH #127).
#' @param length_count_col Column name for the number of fish a binned length
#'   row represents. Optional, but required by [add_lengths()] whenever binned
#'   release rows are present: a binned row is frequency-weighted, so dropping
#'   the count weights the length distribution by row multiplicity instead of by
#'   fish (GH #127). `NA` on individually measured rows.
#' @param length_type_col Column name for length type.
#' @param harvest_col Column name for harvest count.
#' @param trip_duration_col Column name for trip duration.
#' @param trip_start_col Column name for trip start time.
#' @param interview_time_col Column name for interview time.
#' @param n_anglers_col Column name for number of anglers.
#' @param n_counted_col Column name for number of anglers counted.
#' @param n_interviewed_col Column name for number of anglers interviewed.
#' @param angler_type_col Column name for angler type.
#' @param site_col Column name for the site an interview was taken at. Bus-route
#'   designs need it to join the site inclusion probability; without it
#'   `add_interviews()` cannot build the \eqn{\pi_i} term (GH #126).
#' @param circuit_col Column name for the bus-route circuit an interview belongs
#'   to. Required alongside `site_col` for the bus-route expansion (GH #126).
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
  strata_cols = NULL,
  value_maps = NULL,
  catch_col = NULL,
  effort_col = NULL,
  trip_status_col = NULL,
  count_col = NULL,
  count_time_col = NULL,
  catch_uid_col = NULL,
  interview_uid_col = NULL,
  species_col = NULL,
  catch_count_col = NULL,
  catch_type_col = NULL,
  length_uid_col = NULL,
  length_mm_col = NULL,
  length_bin_col = NULL,
  length_count_col = NULL,
  length_type_col = NULL,
  harvest_col = NULL,
  trip_duration_col = NULL,
  trip_start_col = NULL,
  interview_time_col = NULL,
  n_anglers_col = NULL,
  n_counted_col = NULL,
  n_interviewed_col = NULL,
  bank_anglers_col = NULL,
  angler_boats_col = NULL,
  non_ang_boats_col = NULL,
  angler_type_col = NULL,
  site_col = NULL,
  circuit_col = NULL,
  angler_method_col = NULL,
  species_sought_col = NULL,
  refused_col = NULL
) {
  survey_type <- match.arg(survey_type)
  strata_cols <- normalize_strata_cols(strata_cols)
  value_maps <- normalize_value_maps(value_maps)
  new_creel_schema(
    survey_type,
    list(
      interviews_table = interviews_table,
      counts_table = counts_table,
      catch_table = catch_table,
      lengths_table = lengths_table,
      date_col = date_col,
      strata_cols = strata_cols,
      value_maps = value_maps,
      catch_col = catch_col,
      effort_col = effort_col,
      trip_status_col = trip_status_col,
      count_col = count_col,
      count_time_col = count_time_col,
      catch_uid_col = catch_uid_col,
      interview_uid_col = interview_uid_col,
      species_col = species_col,
      catch_count_col = catch_count_col,
      catch_type_col = catch_type_col,
      length_uid_col = length_uid_col,
      length_mm_col = length_mm_col,
      length_bin_col = length_bin_col,
      length_count_col = length_count_col,
      length_type_col = length_type_col,
      harvest_col = harvest_col,
      trip_duration_col = trip_duration_col,
      trip_start_col = trip_start_col,
      interview_time_col = interview_time_col,
      n_anglers_col = n_anglers_col,
      n_counted_col = n_counted_col,
      n_interviewed_col = n_interviewed_col,
      bank_anglers_col = bank_anglers_col,
      angler_boats_col = angler_boats_col,
      non_ang_boats_col = non_ang_boats_col,
      angler_type_col = angler_type_col,
      site_col = site_col,
      circuit_col = circuit_col,
      angler_method_col = angler_method_col,
      species_sought_col = species_sought_col,
      refused_col = refused_col
    )
  )
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
      counts_table = "counts",
      catch_table = "catch",
      lengths_table = "lengths"
    )

    for (tbl_field in names(table_fields)) {
      tbl_name <- x[[tbl_field]]
      tbl_key <- table_fields[[tbl_field]]
      cols <- COL_TO_TABLE[[tbl_key]] # nolint: object_name_linter
      mapped <- Filter(function(f) !is.null(x[[f]]), cols)

      if (!is.null(tbl_name) || length(mapped) > 0) {
        cli::cli_h2("{tbl_key}: {if (is.null(tbl_name)) '(not set)' else tbl_name}")
        for (cf in mapped) {
          if (identical(cf, "strata_cols")) {
            # Two-sided and possibly plural, so print one line per stratum under
            # the design-facing name rather than the field name.
            for (nm in names(x$strata_cols)) {
              cli::cli_text("  {nm} -> {x$strata_cols[[nm]]}")
            }
          } else {
            cli::cli_text("  {sub('_col$', '', cf)} -> {x[[cf]]}")
          }
        }
      }
    }

    # Vocabularies belong to no one table -- trip_status is an interviews
    # column, catch_type a catch column -- so they print under their own heading
    # rather than being split across the blocks above.
    if (!is.null(x$value_maps)) {
      cli::cli_h2("value maps")
      for (col in names(x$value_maps)) {
        map <- x$value_maps[[col]]
        for (code in names(map)) {
          cli::cli_text("  {col}: {code} -> {map[[code]]}")
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
