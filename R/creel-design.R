#' Create a creel survey design
#'
#' @description
#' Constructs a `creel_design` object from calendar data with tidy column
#' selection. This is the entry point for all creel survey analysis workflows.
#' The design object stores the survey structure (date, strata, optional site),
#' validates input data (Tier 1 validation), and serves as the foundation for
#' adding count data and estimating effort.
#'
#' @param calendar A data frame containing calendar data with date and strata
#'   columns. Must have at least one Date column and one character/factor column
#'   (validated via internal schema check).
#' @param date Tidy selector for the date column. Must select exactly one
#'   column of class Date. Accepts bare column names or tidyselect helpers
#'   (e.g., `starts_with("date")`).
#' @param strata Tidy selector for strata columns. Can select one or more
#'   columns of class character or factor. Accepts bare column names or
#'   tidyselect helpers (e.g., `c(day_type, season)` or `starts_with("day")`).
#' @param site Optional tidy selector for a site column. Must select exactly
#'   one column of class character or factor if provided. Use for multi-site
#'   surveys. Default is `NULL` (single-site survey).
#' @param design_type Character string specifying the survey design type.
#'   Default is `"instantaneous"`. Future versions will support `"roving"`,
#'   `"aerial"`, and `"bus_route"`.
#'
#' @return A `creel_design` S3 object (list) with components:
#'   \item{calendar}{The original calendar data frame}
#'   \item{date_col}{Character name of the date column}
#'   \item{strata_cols}{Character vector of strata column names}
#'   \item{site_col}{Character name of site column, or NULL}
#'   \item{design_type}{Character design type}
#'   \item{counts}{NULL (populated by `add_counts()` in future)}
#'   \item{survey}{NULL (populated internally during estimation)}
#'
#' @section Tier 1 Validation:
#' The constructor performs fail-fast validation:
#' - Date column is class Date (not character, numeric, POSIXct)
#' - Date column contains no NA values
#' - Strata columns are character or factor (not numeric, logical)
#' - Site column (if provided) is character or factor
#'
#' @examples
#' # Basic design with single stratum
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
#'   day_type = c("weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' # Multiple strata
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   season = c("summer", "summer")
#' )
#' design <- creel_design(calendar, date = date, strata = c(day_type, season))
#'
#' # With site column for multi-site survey
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   lake = c("lake_a", "lake_b")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type, site = lake)
#'
#' # Using tidyselect helpers
#' calendar <- data.frame(
#'   survey_date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   day_period = c("morning", "evening")
#' )
#' design <- creel_design(
#'   calendar,
#'   date = starts_with("survey"),
#'   strata = starts_with("day")
#' )
#'
#' @export
creel_design <- function(calendar,
                         date,
                         strata,
                         site = NULL,
                         design_type = "instantaneous") {
  # 1. Structural validation (Phase 1 validator)
  validate_calendar_schema(calendar) # nolint: object_usage_linter

  # 2. Resolve tidy selectors to column names
  date_col <- resolve_single_col(
    rlang::enquo(date),
    calendar,
    "date",
    rlang::caller_env()
  )

  strata_cols <- resolve_multi_cols(
    rlang::enquo(strata),
    calendar,
    "strata",
    rlang::caller_env()
  )

  site_col <- NULL
  site_quo <- rlang::enquo(site)
  if (!rlang::quo_is_null(site_quo)) {
    site_col <- resolve_single_col(
      site_quo,
      calendar,
      "site",
      rlang::caller_env()
    )
  }

  # 3. Construct and validate
  design <- new_creel_design(
    calendar    = calendar,
    date_col    = date_col,
    strata_cols = strata_cols,
    site_col    = site_col,
    design_type = design_type
  )
  validate_creel_design(design)
}

#' Low-level creel_design constructor
#'
#' Internal constructor that creates the creel_design structure with type
#' checking only. Does not perform semantic validation. Use [creel_design()]
#' for user-facing construction.
#'
#' @param calendar Data frame with calendar data
#' @param date_col Character name of date column
#' @param strata_cols Character vector of strata column names
#' @param site_col Character name of site column, or NULL
#' @param design_type Character design type
#'
#' @return A creel_design object (list with class attribute)
#'
#' @keywords internal
#' @noRd
new_creel_design <- function(calendar,
                             date_col,
                             strata_cols,
                             site_col = NULL,
                             design_type = "instantaneous") {
  stopifnot(is.data.frame(calendar))
  stopifnot(is.character(date_col), length(date_col) == 1)
  stopifnot(is.character(strata_cols), length(strata_cols) >= 1)
  stopifnot(is.null(site_col) || (is.character(site_col) && length(site_col) == 1))
  stopifnot(is.character(design_type), length(design_type) == 1)

  structure(
    list(
      calendar    = calendar,
      date_col    = date_col,
      strata_cols = strata_cols,
      site_col    = site_col,
      design_type = design_type,
      counts      = NULL,
      survey      = NULL
    ),
    class = "creel_design"
  )
}

#' Validate creel_design object (Tier 1)
#'
#' Performs semantic validation on a creel_design object. Checks that the
#' user-specified columns have appropriate types and values for creel survey
#' analysis.
#'
#' @param x A creel_design object
#'
#' @return Invisibly returns the input object on success. Aborts with
#'   informative cli error message on validation failure.
#'
#' @keywords internal
#' @noRd
validate_creel_design <- function(x) {
  cal <- x$calendar

  # Tier 1: Date column is actually Date class
  if (!inherits(cal[[x$date_col]], "Date")) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must be of class {.cls Date}.",
      "x" = "Column {.var {x$date_col}} is {.cls {class(cal[[x$date_col]])[1]}}.",
      "i" = "Convert with {.code as.Date()}."
    ))
  }

  # Tier 1: Date column has no NA values
  if (anyNA(cal[[x$date_col]])) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must not contain {.val NA} values.",
      "i" = "Remove or impute missing dates before creating a design."
    ))
  }

  # Tier 1: Strata columns exist and are character/factor
  for (col in x$strata_cols) {
    if (!is.character(cal[[col]]) && !is.factor(cal[[col]])) {
      cli::cli_abort(c(
        "Strata column {.var {col}} must be character or factor.",
        "x" = "Column {.var {col}} is {.cls {class(cal[[col]])[1]}}."
      ))
    }
  }

  # Tier 1: Site column (if provided) is character/factor
  if (!is.null(x$site_col)) {
    if (!is.character(cal[[x$site_col]]) && !is.factor(cal[[x$site_col]])) {
      cli::cli_abort(c(
        "Site column {.var {x$site_col}} must be character or factor.",
        "x" = "Column {.var {x$site_col}} is {.cls {class(cal[[x$site_col]])[1]}}."
      ))
    }
  }

  invisible(x)
}

#' Resolve single column from tidy selector
#'
#' Internal helper to resolve a tidy selector expression to exactly one column
#' name. Used for date and site parameters.
#'
#' @param expr Quosure containing the tidy selector expression
#' @param data Data frame to select from
#' @param arg_name Name of the argument (for error messages)
#' @param error_call Calling environment for error reporting
#'
#' @return Character scalar with the selected column name
#'
#' @keywords internal
#' @noRd
resolve_single_col <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  loc <- tidyselect::eval_select(
    expr,
    data = data,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = error_call
  )
  if (length(loc) != 1) {
    cli::cli_abort(
      "{.arg {arg_name}} must select exactly one column, not {length(loc)}.",
      call = error_call
    )
  }
  names(loc)
}

#' Resolve multiple columns from tidy selector
#'
#' Internal helper to resolve a tidy selector expression to one or more column
#' names. Used for strata parameter.
#'
#' @param expr Quosure containing the tidy selector expression
#' @param data Data frame to select from
#' @param arg_name Name of the argument (for error messages)
#' @param error_call Calling environment for error reporting
#'
#' @return Character vector with selected column names
#'
#' @keywords internal
#' @noRd
resolve_multi_cols <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  loc <- tidyselect::eval_select(
    expr,
    data = data,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = error_call
  )
  names(loc)
}

#' Attach count data to a creel design
#'
#' @description
#' Attaches instantaneous count data to a creel_design object and constructs
#' the internal survey design object eagerly. This is the core of the survey
#' bridge layer - translating domain vocabulary (creel counts) into statistical
#' machinery (survey::svydesign). Eager construction catches design errors at
#' add_counts() time when users have context about what data they are adding.
#'
#' @param design A creel_design object (created with [creel_design()])
#' @param counts Data frame containing count data. Must have:
#'   - A Date column matching the design's date_col
#'   - All strata columns from the design's strata_cols
#'   - At least one numeric column (the count variable)
#'   - A PSU column (specified via psu argument, defaults to date_col)
#' @param psu Character string naming the PSU (Primary Sampling Unit) column
#'   in the count data. Defaults to NULL, which uses the design's date_col as
#'   the PSU (day-as-PSU is the most common creel design). For other designs,
#'   specify the PSU column explicitly (e.g., "site_day" for day-site PSUs).
#' @param allow_invalid Logical flag for validation behavior. If FALSE (default),
#'   validation failures abort with detailed error messages. If TRUE, validation
#'   failures generate warnings and attach counts anyway (use with caution).
#'
#' @return A new creel_design object (list) with components:
#'   \item{calendar}{Original calendar data frame}
#'   \item{date_col}{Character name of date column}
#'   \item{strata_cols}{Character vector of strata column names}
#'   \item{site_col}{Character name of site column, or NULL}
#'   \item{design_type}{Character design type}
#'   \item{counts}{The count data frame (newly attached)}
#'   \item{psu_col}{Character name of PSU column}
#'   \item{survey}{Internal survey.design2 object (newly constructed)}
#'   \item{validation}{creel_validation object with Tier 1 results}
#'
#' @section Immutability:
#' add_counts() follows functional programming patterns and returns a new
#' creel_design object. The original design object is not modified. This
#' prevents accidental data loss and makes the workflow explicit:
#' `design2 <- add_counts(design, counts)` not `add_counts(design, counts)`
#'
#' @section Validation:
#' add_counts() performs Tier 1 validation:
#' - Count data schema (Date column, numeric column) via validate_count_schema()
#' - Design column presence (date_col, strata_cols, PSU in count data)
#' - No NA values in design-critical columns (date, strata, PSU)
#' - Survey construction (catches lonely PSU errors, stratification issues)
#'
#' @section PSU Specification:
#' Per user decision (clarified 2026-02-08), PSU is specified only in add_counts(),
#' not in creel_design() constructor. PSU is only meaningful when count data is
#' present, making add_counts() the correct abstraction boundary. This design
#' allows the same creel_design calendar to be used with different PSU structures.
#'
#' @examples
#' # Basic usage - day as PSU (default)
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' counts <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   count = c(15, 23, 45, 52)
#' )
#'
#' design_with_counts <- add_counts(design, counts)
#' print(design_with_counts)
#'
#' # Custom PSU column
#' counts_with_site_psu <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   site_day = paste0("site_", 1:4),
#'   count = c(15, 23, 45, 52)
#' )
#'
#' design2 <- add_counts(design, counts_with_site_psu, psu = "site_day")
#'
#' @export
add_counts <- function(design, counts, psu = NULL, allow_invalid = FALSE) {
  # Validate design is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Check counts not already attached
  if (!is.null(design$counts)) {
    cli::cli_abort(c(
      "Counts already attached to design.",
      "x" = "The design object already has count data in the {.field $counts} slot.",
      "i" = "Create a new design with {.fn creel_design} to attach different counts.",
      "i" = "Use immutable workflow: {.code design2 <- add_counts(design, counts)}"
    ))
  }

  # Validate count data schema (Date column, numeric column)
  validate_count_schema(counts) # nolint: object_usage_linter

  # Set PSU column (default to date_col for day-as-PSU)
  if (is.null(psu)) {
    psu <- design$date_col
  }

  # Validate counts structure (Tier 1)
  validation <- validate_counts_tier1(counts, design, psu, allow_invalid) # nolint: object_usage_linter

  # Copy design and add counts + PSU
  new_design <- design
  new_design$counts <- counts
  new_design$psu_col <- psu

  # Construct survey design eagerly
  new_design$survey <- construct_survey_design(new_design) # nolint: object_usage_linter

  # Store validation results
  new_design$validation <- validation

  # Preserve class
  class(new_design) <- "creel_design"

  new_design
}

#' Attach interview data to a creel design
#'
#' @description
#' Attaches interview data (catch, effort, and optionally harvest per completed
#' fishing trip) to a creel_design object and constructs the internal interview
#' survey design object eagerly. This enables catch rate and harvest rate
#' estimation from angler interviews. Follows the same tidy selector API pattern
#' as [add_counts()].
#'
#' @param design A creel_design object (created with [creel_design()])
#' @param interviews Data frame containing interview data. Must have:
#'   - A Date column matching the design's date_col
#'   - Numeric catch column (total fish caught per trip)
#'   - Numeric effort column (fishing time per trip, e.g., hours)
#'   - Character trip status column ("complete" or "incomplete")
#'   - Optional numeric harvest column (fish kept per trip)
#'   - Optional numeric trip duration column (hours) OR trip_start + interview_time columns (POSIXct)
#' @param catch Tidy selector for total catch column (required). Use bare column
#'   names (e.g., `catch = catch_total`) or tidyselect helpers.
#' @param effort Tidy selector for fishing effort column (required, e.g.,
#'   `effort = hours_fished`). Should represent time spent fishing per trip.
#' @param harvest Tidy selector for harvest (kept fish) column (optional,
#'   default NULL). If provided, will be validated for consistency (harvest <= catch).
#' @param trip_status Tidy selector for trip completion status column (required).
#'   Must contain "complete" or "incomplete" (case-insensitive). This is essential
#'   for downstream incomplete trip estimators.
#' @param trip_duration Tidy selector for trip duration column in hours (optional,
#'   default NULL). Provide either trip_duration OR trip_start + interview_time,
#'   not both. Duration values must be positive and >= 1/60 hours (1 minute).
#' @param trip_start Tidy selector for trip start time column (optional, default NULL).
#'   Must be POSIXct or POSIXlt. Requires interview_time to calculate duration.
#'   Use when duration needs to be calculated from timestamps.
#' @param interview_time Tidy selector for interview time column (optional, default NULL).
#'   Must be POSIXct or POSIXlt. Requires trip_start to calculate duration.
#'   Duration is calculated as interview_time - trip_start in hours.
#' @param date_col Character name of date column in interviews (default NULL,
#'   which uses the design's date_col). Specify explicitly if interview data
#'   uses a different date column name than the design calendar.
#' @param interview_type Character: "access" (complete trips at access point)
#'   or "roving" (incomplete trips during fishing). Default is "access". This
#'   affects how catch rates are calculated in estimation functions.
#' @param allow_invalid Logical flag for validation behavior. If FALSE (default),
#'   validation failures abort with detailed error messages. If TRUE, validation
#'   failures generate warnings and attach interviews anyway (use with caution).
#'
#' @return A new creel_design object (list) with components:
#'   \item{calendar}{Original calendar data frame}
#'   \item{date_col}{Character name of date column}
#'   \item{strata_cols}{Character vector of strata column names}
#'   \item{site_col}{Character name of site column, or NULL}
#'   \item{design_type}{Character design type}
#'   \item{counts}{Count data frame (if previously attached, or NULL)}
#'   \item{interviews}{The interview data frame (newly attached)}
#'   \item{catch_col}{Character name of catch column}
#'   \item{effort_col}{Character name of effort column}
#'   \item{harvest_col}{Character name of harvest column, or NULL}
#'   \item{trip_status_col}{Character name of trip status column}
#'   \item{trip_duration_col}{Character name of trip duration column, or NULL}
#'   \item{trip_start_col}{Character name of trip start time column, or NULL}
#'   \item{interview_time_col}{Character name of interview time column, or NULL}
#'   \item{interview_type}{Character interview type}
#'   \item{interview_survey}{Internal survey.design2 object (newly constructed)}
#'   \item{validation}{creel_validation object with Tier 1 results}
#'
#' @section Immutability:
#' add_interviews() follows functional programming patterns and returns a new
#' creel_design object. The original design object is not modified. This
#' prevents accidental data loss and makes the workflow explicit:
#' `design2 <- add_interviews(design, interviews, ...)` not `add_interviews(design, interviews, ...)`
#'
#' @section Validation:
#' add_interviews() performs Tier 1 validation:
#' - Interview data schema (Date column, numeric columns) via validate_interview_schema()
#' - Design column presence (date_col exists in interview data)
#' - No NA values in date column
#' - Interview dates exist in design calendar
#' - Catch and effort columns exist and are numeric
#' - Harvest column exists and is numeric (if provided)
#' - Harvest <= catch consistency (if harvest provided)
#' - Trip status valid ("complete" or "incomplete", case-insensitive)
#' - Trip status has no NA values
#' - Trip duration/time inputs are mutually exclusive (error if both provided)
#' - Trip duration is positive, >= 1 minute, warns if > 48 hours
#' - Trip start + interview_time are POSIXct/POSIXlt, calculate valid duration
#' - Interview survey construction (catches stratification issues)
#'
#' @section Calendar Integration:
#' Interview dates are automatically linked to the design calendar via date
#' matching. Strata from the calendar are inherited by the interview data,
#' enabling stratified estimation of catch rates.
#'
#' @examples
#' # Basic usage - with trip status and duration
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' interviews <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   catch_total = c(5, 3, 7, 2),
#'   hours_fished = c(2.0, 2.5, 3.0, 1.5),
#'   trip_status = c("complete", "complete", "incomplete", "complete"),
#'   trip_duration = c(2.0, 2.5, 1.5, 1.5)
#' )
#'
#' design_with_interviews <- add_interviews(
#'   design, interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#' print(design_with_interviews)
#'
#' # With harvest column and calculated duration from timestamps
#' interviews2 <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   catch_total = c(5, 3, 7, 2),
#'   catch_kept = c(2, 1, 5, 2),
#'   hours_fished = c(2.0, 2.5, 3.0, 1.5),
#'   trip_status = c("complete", "incomplete", "complete", "complete"),
#'   trip_start = as.POSIXct(c(
#'     "2024-06-01 08:00", "2024-06-02 09:00",
#'     "2024-06-03 07:00", "2024-06-04 10:00"
#'   )),
#'   interview_time = as.POSIXct(c(
#'     "2024-06-01 10:00", "2024-06-02 11:30",
#'     "2024-06-03 10:00", "2024-06-04 11:30"
#'   ))
#' )
#'
#' design2 <- add_interviews(
#'   design, interviews2,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   harvest = catch_kept,
#'   trip_status = trip_status,
#'   trip_start = trip_start,
#'   interview_time = interview_time
#' )
#'
#' @export
add_interviews <- function(design, interviews,
                           catch, effort, harvest = NULL,
                           trip_status,
                           trip_duration = NULL,
                           trip_start = NULL,
                           interview_time = NULL,
                           date_col = NULL,
                           interview_type = c("access", "roving"),
                           allow_invalid = FALSE) {
  # Validate design is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Check interviews not already attached
  if (!is.null(design$interviews)) {
    cli::cli_abort(c(
      "Interviews already attached to design.",
      "x" = "The design object already has interview data in the {.field $interviews} slot.",
      "i" = "Create a new design with {.fn creel_design} to attach different interviews.",
      "i" = "Use immutable workflow: {.code design2 <- add_interviews(design, interviews, ...)}"
    ))
  }

  # Validate interview data schema (Date column, numeric column)
  validate_interview_schema(interviews) # nolint: object_usage_linter

  # Resolve tidy selectors
  catch_col <- resolve_single_col(
    rlang::enquo(catch),
    interviews,
    "catch",
    rlang::caller_env()
  )

  effort_col <- resolve_single_col(
    rlang::enquo(effort),
    interviews,
    "effort",
    rlang::caller_env()
  )

  # Resolve harvest column (optional)
  harvest_col <- NULL
  harvest_quo <- rlang::enquo(harvest)
  if (!rlang::quo_is_null(harvest_quo)) {
    harvest_col <- resolve_single_col(
      harvest_quo,
      interviews,
      "harvest",
      rlang::caller_env()
    )
  }

  # Resolve trip_status column (required)
  trip_status_col <- resolve_single_col(
    rlang::enquo(trip_status),
    interviews,
    "trip_status",
    rlang::caller_env()
  )

  # Resolve trip duration input method
  trip_duration_col <- NULL
  trip_start_col <- NULL
  interview_time_col <- NULL

  trip_duration_quo <- rlang::enquo(trip_duration)
  trip_start_quo <- rlang::enquo(trip_start)
  interview_time_quo <- rlang::enquo(interview_time)

  if (!rlang::quo_is_null(trip_duration_quo)) {
    trip_duration_col <- resolve_single_col(
      trip_duration_quo,
      interviews,
      "trip_duration",
      rlang::caller_env()
    )
  }

  if (!rlang::quo_is_null(trip_start_quo)) {
    trip_start_col <- resolve_single_col(
      trip_start_quo,
      interviews,
      "trip_start",
      rlang::caller_env()
    )
  }

  if (!rlang::quo_is_null(interview_time_quo)) {
    interview_time_col <- resolve_single_col(
      interview_time_quo,
      interviews,
      "interview_time",
      rlang::caller_env()
    )
  }

  # Set date_col (default to design$date_col)
  if (is.null(date_col)) {
    date_col <- design$date_col
  }

  # Match interview_type
  interview_type <- match.arg(interview_type)

  # Validate interviews structure (Tier 1)
  validation <- validate_interviews_tier1(interviews, design, catch_col, effort_col, harvest_col, date_col, allow_invalid) # nolint: object_usage_linter

  # Validate trip metadata
  validate_trip_metadata(interviews, trip_status_col, trip_duration_col, trip_start_col, interview_time_col) # nolint: object_usage_linter

  # Calculate duration if needed (from trip_start + interview_time)
  if (!is.null(trip_start_col) && !is.null(interview_time_col) && is.null(trip_duration_col)) {
    interviews[[".trip_duration_hrs"]] <- as.numeric(
      difftime(interviews[[interview_time_col]], interviews[[trip_start_col]], units = "hours")
    )
    trip_duration_col <- ".trip_duration_hrs"
  }

  # Normalize trip_status to lowercase
  interviews[[trip_status_col]] <- tolower(interviews[[trip_status_col]])

  # Join interviews with calendar
  interviews_joined <- dplyr::left_join(
    interviews,
    design$calendar,
    by = stats::setNames(design$date_col, date_col),
    suffix = c("", "_cal")
  )

  # Copy design and add interview fields
  new_design <- design
  new_design$interviews <- interviews_joined
  new_design$catch_col <- catch_col
  new_design$effort_col <- effort_col
  new_design$harvest_col <- harvest_col
  new_design$interview_type <- interview_type
  new_design$trip_status_col <- trip_status_col
  new_design$trip_duration_col <- trip_duration_col
  new_design$trip_start_col <- trip_start_col
  new_design$interview_time_col <- interview_time_col

  # Construct interview survey eagerly
  new_design$interview_survey <- construct_interview_survey(new_design) # nolint: object_usage_linter

  # Store validation results
  new_design$validation <- validation

  # Warn for Tier 2 data quality issues
  warn_tier2_interview_issues(new_design) # nolint: object_usage_linter

  # Trip status summary
  status_table <- table(tolower(new_design$interviews[[trip_status_col]]))
  n_complete <- as.integer(status_table["complete"])
  n_incomplete <- as.integer(status_table["incomplete"])
  if (is.na(n_complete)) n_complete <- 0L
  if (is.na(n_incomplete)) n_incomplete <- 0L
  n_total <- n_complete + n_incomplete
  pct_complete <- round(100 * n_complete / n_total, 0) # nolint: object_usage_linter
  pct_incomplete <- round(100 * n_incomplete / n_total, 0) # nolint: object_usage_linter
  cli::cli_inform(c( # nolint: line_length_linter
    "i" = "Added {n_total} interview{?s}: {n_complete} complete ({pct_complete}%), {n_incomplete} incomplete ({pct_incomplete}%)"
  ))

  # Preserve class
  class(new_design) <- "creel_design"

  new_design
}

#' Format a creel_design object
#'
#' @param x A creel_design object
#' @param ... Additional arguments (ignored)
#'
#' @return A character vector with the formatted output
#'
#' @export
format.creel_design <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_h1("Creel Survey Design")
    cli::cli_text("Type: {.val {x$design_type}}")
    cli::cli_text("Date column: {.field {x$date_col}}")
    cli::cli_text("Strata: {.field {paste(x$strata_cols, collapse = ', ')}}")
    if (!is.null(x$site_col)) {
      cli::cli_text("Site column: {.field {x$site_col}}")
    }

    n_days <- nrow(x$calendar) # nolint: object_usage_linter
    date_range <- range(x$calendar[[x$date_col]]) # nolint: object_usage_linter
    cli::cli_text("Calendar: {.val {n_days}} day{?s} ({date_range[1]} to {date_range[2]})")

    # Strata summary
    for (col in x$strata_cols) {
      levels <- unique(x$calendar[[col]]) # nolint: object_usage_linter
      cli::cli_text("  {.field {col}}: {.val {length(levels)}} level{?s}")
    }

    has_counts <- !is.null(x$counts) # nolint: object_usage_linter
    has_survey <- !is.null(x$survey) # nolint: object_usage_linter
    if (has_counts) {
      n_counts <- nrow(x$counts) # nolint: object_usage_linter
      psu_col <- x$psu_col # nolint: object_usage_linter
      cli::cli_text("Counts: {.val {n_counts}} observation{?s}")
      cli::cli_text("  PSU column: {.field {psu_col}}")
      if (has_survey) {
        survey_class <- class(x$survey)[1] # nolint: object_usage_linter
        cli::cli_text("  Survey: {.cls {survey_class}} (constructed)")
      }
    } else {
      cli::cli_text("Counts: {.val none}")
    }

    has_interviews <- !is.null(x$interviews) # nolint: object_usage_linter
    if (has_interviews) {
      n_interviews <- nrow(x$interviews) # nolint: object_usage_linter
      interview_type <- x$interview_type # nolint: object_usage_linter
      catch_col <- x$catch_col # nolint: object_usage_linter
      effort_col <- x$effort_col # nolint: object_usage_linter
      cli::cli_text("Interviews: {.val {n_interviews}} observation{?s}")
      cli::cli_text("  Type: {.val {interview_type}}")
      cli::cli_text("  Catch: {.field {catch_col}}")
      cli::cli_text("  Effort: {.field {effort_col}}")
      if (!is.null(x$harvest_col)) {
        harvest_col <- x$harvest_col # nolint: object_usage_linter
        cli::cli_text("  Harvest: {.field {harvest_col}}")
      }
      if (!is.null(x$trip_status_col)) {
        trip_status_col <- x$trip_status_col # nolint: object_usage_linter
        status_table <- table(tolower(x$interviews[[trip_status_col]])) # nolint: object_usage_linter
        n_complete <- as.integer(status_table["complete"]) # nolint: object_usage_linter
        n_incomplete <- as.integer(status_table["incomplete"]) # nolint: object_usage_linter
        if (is.na(n_complete)) n_complete <- 0L
        if (is.na(n_incomplete)) n_incomplete <- 0L
        cli::cli_text("  Trip status: {n_complete} complete, {n_incomplete} incomplete")
      }
      if (!is.null(x$interview_survey)) {
        interview_survey_class <- class(x$interview_survey)[1] # nolint: object_usage_linter
        cli::cli_text("  Survey: {.cls {interview_survey_class}} (constructed)")
      }
    } else {
      cli::cli_text("Interviews: {.val none}")
    }
  })
}

#' Print a creel_design object
#'
#' @param x A creel_design object
#' @param ... Additional arguments passed to [format.creel_design()]
#'
#' @return Invisibly returns the input object
#'
#' @export
print.creel_design <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' Summarize a creel_design object
#'
#' @param object A creel_design object
#' @param ... Additional arguments passed to [print.creel_design()]
#'
#' @return Invisibly returns the input object
#'
#' @export
summary.creel_design <- function(object, ...) {
  print(object, ...)
  invisible(object)
}
