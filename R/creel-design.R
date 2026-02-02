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
    cli::cli_text("Counts: {.val {if (has_counts) 'attached' else 'none'}}")
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
