#' Standardize trip/interview rows for interview-based workflows
#'
#' @description
#' Converts raw-ish interview records into a canonical tibble for downstream use
#' with `add_interviews()`. This helper standardizes the trip/interview unit,
#' computes effort from timestamps when needed, normalizes `trip_status`, and
#' emits stable columns for effort, trip duration, angler party size, and
#' optional interview attributes.
#'
#' The returned table always contains canonical columns:
#' `date`, `interview_uid`, `effort_hours`, `trip_status`, `trip_duration`,
#' `n_anglers`, and `refused`. Optional columns such as `catch_total`,
#' `harvest_total`, `angler_type`, `angler_method`, `species_sought`, and any
#' selected strata are appended when supplied.
#'
#' @param data A data frame containing interview records.
#' @param date Tidy selector for the Date column.
#' @param interview_uid Tidy selector for the unique interview identifier.
#' @param effort_hours Optional tidy selector for an effort-in-hours column.
#'   Supply this when hours are already available directly.
#' @param trip_status Tidy selector for the trip-status column. Values are
#'   normalized to lowercase and must resolve to `"complete"` or `"incomplete"`.
#' @param trip_duration Optional tidy selector for a trip duration column in
#'   hours. When omitted, the helper uses `effort_hours` if present or computes
#'   duration from `trip_start` and `interview_time`.
#' @param trip_start Optional tidy selector for trip start timestamps.
#' @param interview_time Optional tidy selector for interview timestamps.
#'   When `effort_hours` is omitted, `trip_start` and `interview_time` are used
#'   to compute effort in hours.
#' @param catch_total Optional tidy selector for total catch per trip.
#' @param harvest_total Optional tidy selector for total harvest per trip.
#' @param angler_type Optional tidy selector for angler type (e.g. `"bank"`,
#'   `"boat"`).
#' @param angler_method Optional tidy selector for fishing method.
#' @param species_sought Optional tidy selector for the target species field.
#' @param n_anglers Optional tidy selector for party size. Defaults to `1L` when
#'   omitted.
#' @param refused Optional tidy selector for the refused interview flag.
#'   Defaults to `FALSE` when omitted.
#' @param strata Optional tidy selector for one or more strata columns to carry
#'   forward into the standardized output.
#'
#' @return A tibble with canonical trip/interview columns ready for
#'   `add_interviews()`.
#'
#' @seealso [compute_effort()], [add_interviews()]
#' @export
prep_interviews_trips <- function(data,
                                  date,
                                  interview_uid,
                                  effort_hours = NULL,
                                  trip_status,
                                  trip_duration = NULL,
                                  trip_start = NULL,
                                  interview_time = NULL,
                                  catch_total = NULL,
                                  harvest_total = NULL,
                                  angler_type = NULL,
                                  angler_method = NULL,
                                  species_sought = NULL,
                                  n_anglers = NULL,
                                  refused = NULL,
                                  strata = NULL) {
  date_quo <- rlang::enquo(date)
  interview_uid_quo <- rlang::enquo(interview_uid)
  effort_hours_quo <- rlang::enquo(effort_hours)
  trip_status_quo <- rlang::enquo(trip_status)
  trip_duration_quo <- rlang::enquo(trip_duration)
  trip_start_quo <- rlang::enquo(trip_start)
  interview_time_quo <- rlang::enquo(interview_time)
  catch_total_quo <- rlang::enquo(catch_total)
  harvest_total_quo <- rlang::enquo(harvest_total)
  angler_type_quo <- rlang::enquo(angler_type)
  angler_method_quo <- rlang::enquo(angler_method)
  species_sought_quo <- rlang::enquo(species_sought)
  n_anglers_quo <- rlang::enquo(n_anglers)
  refused_quo <- rlang::enquo(refused)
  strata_quo <- rlang::enquo(strata)

  resolve_one <- function(quo, arg_name) {
    cols <- names(tidyselect::eval_select(quo, data))
    if (length(cols) != 1L) {
      cli::cli_abort(c(
        "{.arg {arg_name}} must select exactly one column.",
        "x" = "Selected {length(cols)} columns."
      ))
    }
    cols
  }

  resolve_optional_one <- function(quo, arg_name) {
    if (rlang::quo_is_null(quo)) {
      return(NULL)
    }
    cols <- names(tidyselect::eval_select(quo, data))
    if (length(cols) != 1L) {
      cli::cli_abort(c(
        "{.arg {arg_name}} must select exactly one column when supplied.",
        "x" = "Selected {length(cols)} columns."
      ))
    }
    cols
  }

  date_col <- resolve_one(date_quo, "date")
  interview_uid_col <- resolve_one(interview_uid_quo, "interview_uid")
  trip_status_col <- resolve_one(trip_status_quo, "trip_status")
  effort_hours_col <- resolve_optional_one(effort_hours_quo, "effort_hours")
  trip_duration_col <- resolve_optional_one(trip_duration_quo, "trip_duration")
  trip_start_col <- resolve_optional_one(trip_start_quo, "trip_start")
  interview_time_col <- resolve_optional_one(interview_time_quo, "interview_time")
  catch_total_col <- resolve_optional_one(catch_total_quo, "catch_total")
  harvest_total_col <- resolve_optional_one(harvest_total_quo, "harvest_total")
  angler_type_col <- resolve_optional_one(angler_type_quo, "angler_type")
  angler_method_col <- resolve_optional_one(angler_method_quo, "angler_method")
  species_sought_col <- resolve_optional_one(species_sought_quo, "species_sought")
  n_anglers_col <- resolve_optional_one(n_anglers_quo, "n_anglers")
  refused_col <- resolve_optional_one(refused_quo, "refused")
  strata_cols <- if (rlang::quo_is_null(strata_quo)) {
    character(0)
  } else {
    names(tidyselect::eval_select(strata_quo, data))
  }

  date_vals <- data[[date_col]]
  if (!inherits(date_vals, "Date")) {
    cli::cli_abort(c(
      "{.field {date_col}} must be a {.cls Date} column.",
      "x" = "Got class {.cls {class(date_vals)[1]}}."
    ))
  }

  if (is.null(effort_hours_col)) {
    if (is.null(trip_start_col) || is.null(interview_time_col)) {
      cli::cli_abort(c(
        "Provide either {.arg effort_hours} or both {.arg trip_start} and {.arg interview_time}.",
        "x" = "Cannot compute effort hours from the supplied columns."
      ))
    }
    effort_df <- compute_effort(data, !!trip_start_quo, !!interview_time_quo) # nolint: object_usage_linter.
    effort_vals <- effort_df[[".effort"]]
  } else {
    effort_vals <- data[[effort_hours_col]]
  }

  if (!is.numeric(effort_vals)) {
    cli::cli_abort(c(
      "{.field effort_hours} must resolve to a numeric column.",
      "x" = "Got class {.cls {class(effort_vals)[1]}}."
    ))
  }

  if (is.null(trip_duration_col)) {
    trip_duration_vals <- effort_vals
  } else {
    trip_duration_vals <- data[[trip_duration_col]]
  }

  if (!is.numeric(trip_duration_vals)) {
    cli::cli_abort(c(
      "{.field trip_duration} must resolve to a numeric column.",
      "x" = "Got class {.cls {class(trip_duration_vals)[1]}}."
    ))
  }

  trip_status_vals <- tolower(as.character(data[[trip_status_col]]))
  valid_status <- c("complete", "incomplete")
  bad_status <- unique(stats::na.omit(trip_status_vals[!trip_status_vals %in% valid_status]))
  if (length(bad_status) > 0) {
    cli::cli_abort(c(
      "{.field {trip_status_col}} contains invalid trip-status values.",
      "x" = "Invalid value{?s}: {.val {bad_status}}.",
      "i" = "Valid values are {.val complete} and {.val incomplete}."
    ))
  }

  if (is.null(n_anglers_col)) {
    n_anglers_vals <- rep(1L, nrow(data))
  } else {
    n_anglers_vals <- data[[n_anglers_col]]
  }

  if (!is.numeric(n_anglers_vals)) {
    cli::cli_abort(c(
      "{.field n_anglers} must resolve to a numeric column.",
      "x" = "Got class {.cls {class(n_anglers_vals)[1]}}."
    ))
  }

  if (is.null(refused_col)) {
    refused_vals <- rep(FALSE, nrow(data))
  } else {
    refused_vals <- as.logical(data[[refused_col]])
  }

  out <- tibble::tibble(
    date = date_vals,
    interview_uid = data[[interview_uid_col]],
    effort_hours = effort_vals,
    trip_status = trip_status_vals,
    trip_duration = trip_duration_vals,
    n_anglers = n_anglers_vals,
    refused = refused_vals
  )

  for (col in strata_cols) {
    out[[col]] <- data[[col]]
  }

  if (!is.null(catch_total_col)) {
    out[["catch_total"]] <- data[[catch_total_col]]
  }
  if (!is.null(harvest_total_col)) {
    out[["harvest_total"]] <- data[[harvest_total_col]]
  }
  if (!is.null(angler_type_col)) {
    out[["angler_type"]] <- as.character(data[[angler_type_col]])
  }
  if (!is.null(angler_method_col)) {
    out[["angler_method"]] <- data[[angler_method_col]]
  }
  if (!is.null(species_sought_col)) {
    out[["species_sought"]] <- data[[species_sought_col]]
  }

  out
}

#' Standardize long catch-table rows for interview-based workflows
#'
#' @description
#' Converts a long-format catch table into a canonical tibble for downstream use
#' with `add_catch()`. The helper standardizes the interview linkage field,
#' species field, numeric catch counts, and normalized catch-type values while
#' keeping the data in long form.
#'
#' The returned table always contains canonical columns:
#' `interview_uid`, `species`, `count`, and `catch_type`.
#'
#' @param data A data frame in long format: one row per interview/species/catch-type
#'   combination.
#' @param interview_uid Tidy selector for the interview linkage column.
#' @param species Tidy selector for the species code or name column.
#' @param count Tidy selector for the numeric catch count column.
#' @param catch_type Tidy selector for the catch fate column. Values are
#'   normalized to lowercase.
#'
#' @return A tibble with canonical columns `interview_uid`, `species`, `count`,
#'   and `catch_type`.
#'
#' @seealso [add_catch()]
#' @export
prep_interview_catch <- function(data,
                                 interview_uid,
                                 species,
                                 count,
                                 catch_type) {
  interview_uid_quo <- rlang::enquo(interview_uid)
  species_quo <- rlang::enquo(species)
  count_quo <- rlang::enquo(count)
  catch_type_quo <- rlang::enquo(catch_type)

  resolve_one <- function(quo, arg_name) {
    cols <- names(tidyselect::eval_select(quo, data))
    if (length(cols) != 1L) {
      cli::cli_abort(c(
        "{.arg {arg_name}} must select exactly one column.",
        "x" = "Selected {length(cols)} columns."
      ))
    }
    cols
  }

  interview_uid_col <- resolve_one(interview_uid_quo, "interview_uid")
  species_col <- resolve_one(species_quo, "species")
  count_col <- resolve_one(count_quo, "count")
  catch_type_col <- resolve_one(catch_type_quo, "catch_type")

  count_vals <- data[[count_col]]
  if (!is.numeric(count_vals)) {
    cli::cli_abort(c(
      "{.field {count_col}} must be numeric.",
      "x" = "Got class {.cls {class(count_vals)[1]}}."
    ))
  }

  species_vals <- data[[species_col]]
  if (!(is.character(species_vals) || is.factor(species_vals))) {
    cli::cli_abort(c(
      "{.field {species_col}} must be character or factor.",
      "x" = "Got class {.cls {class(species_vals)[1]}}."
    ))
  }

  catch_type_vals <- tolower(as.character(data[[catch_type_col]]))

  tibble::tibble(
    interview_uid = data[[interview_uid_col]],
    species = as.character(species_vals),
    count = count_vals,
    catch_type = catch_type_vals
  )
}
