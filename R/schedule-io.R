#' Coerce a value to Date
#'
#' Internal helper used by [coerce_schedule_columns()] to convert dates read
#' from CSV or xlsx into class `Date`. Handles pass-through for `Date`,
#' conversion from `POSIXct`/`POSIXlt`, numeric Excel serial numbers
#' (origin `"1899-12-30"`), and ISO 8601 character strings.
#'
#' @param x A vector of class `Date`, `POSIXct`, `POSIXlt`, numeric, or
#'   character.
#'
#' @return A `Date` vector.
#'
#' @noRd
coerce_to_date <- function(x) {
  if (inherits(x, "Date")) {
    return(x)
  }
  if (inherits(x, c("POSIXct", "POSIXlt"))) {
    return(as.Date(x))
  }
  if (is.numeric(x)) {
    return(as.Date(as.integer(x), origin = "1899-12-30"))
  }
  # Character — ISO 8601 (YYYY-MM-DD), Excel text serial, or Excel string
  # Treat literal "NA" strings (produced by write.csv for NA values) as NA
  x[!is.na(x) & x == "NA"] <- NA_character_
  # Detect character values that look like Excel serial numbers (pure digits)
  # readxl col_types="text" returns date cells as character serial numbers
  looks_numeric <- !is.na(x) & grepl("^[0-9]+$", x)
  if (any(looks_numeric)) {
    result <- rep(as.Date(NA_character_), length(x))
    result[looks_numeric] <- as.Date(
      as.integer(x[looks_numeric]),
      origin = "1899-12-30"
    )
    result[!looks_numeric] <- suppressWarnings(as.Date(x[!looks_numeric]))
    was_na_before <- is.na(x)
    new_nas <- is.na(result) & !was_na_before
    if (any(new_nas)) {
      cli::cli_warn(
        c(
          "Some date values could not be parsed and were coerced to {.val NA}.",
          "i" = "{sum(new_nas)} value(s) failed date coercion."
        )
      )
    }
    return(result)
  }
  result <- suppressWarnings(as.Date(x))
  was_na_before <- is.na(x)
  new_nas <- is.na(result) & !was_na_before
  if (any(new_nas)) {
    cli::cli_warn(
      c(
        "Some date values could not be parsed and were coerced to {.val NA}.",
        "i" = "{sum(new_nas)} value(s) failed ISO 8601 coercion."
      )
    )
  }
  result
}

#' Coerce schedule data frame columns to their canonical types
#'
#' Internal helper. Applies type coercion to the columns `date`, `day_type`,
#' `period_id`, and `sampled` if present. Column matching is by name; columns
#' absent from `df` are left alone. This ensures identical coercion logic for
#' both CSV and xlsx paths.
#'
#' @param df A data frame with all columns as character (as produced by
#'   `utils::read.csv(colClasses = "character")` or
#'   `readxl::read_excel(col_types = "text")`).
#'
#' @return `df` with columns coerced to their canonical types.
#'
#' @noRd
coerce_schedule_columns <- function(df) {
  if ("date" %in% names(df)) {
    df$date <- coerce_to_date(df$date)
  }
  if ("day_type" %in% names(df)) {
    df$day_type <- as.character(df$day_type)
    # Convert literal "NA" strings (from write.csv) back to NA_character_
    df$day_type[!is.na(df$day_type) & df$day_type == "NA"] <- NA_character_
  }
  if ("period_id" %in% names(df)) {
    df$period_id <- suppressWarnings(as.integer(df$period_id))
  }
  if ("sampled" %in% names(df)) {
    df$sampled <- as.logical(df$sampled)
  }
  df
}

#' Write a creel schedule to a CSV or xlsx file
#'
#' Exports a `creel_schedule` object to disk. The default format is CSV using
#' base R (no extra dependencies). The `"xlsx"` format requires the
#' \pkg{writexl} package; an informative error is raised if it is not
#' installed.
#'
#' @param schedule A `creel_schedule` object (or plain data frame) to export.
#' @param path File path for the output file.
#' @param format One of `"csv"` (default) or `"xlsx"`. When `"csv"`, the file
#'   is written with [utils::write.csv()] (no row names). When `"xlsx"`,
#'   [writexl::write_xlsx()] is used behind an [rlang::check_installed()]
#'   guard.
#'
#' @return `path`, returned invisibly.
#'
#' @examples
#' sched <- generate_schedule(
#'   "2024-06-01", "2024-08-31",
#'   n_periods = 2,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed = 42
#' )
#' tmp <- tempfile(fileext = ".csv")
#' write_schedule(sched, tmp)
#'
#' @export
write_schedule <- function(schedule, path, format = c("csv", "xlsx")) {
  format <- match.arg(format)
  if (format == "xlsx") {
    rlang::check_installed("writexl", reason = "to write xlsx schedule files")
    writexl::write_xlsx(schedule, path)
  } else {
    utils::write.csv(schedule, path, row.names = FALSE)
  }
  invisible(path)
}

#' Read a schedule file into a validated creel_schedule object
#'
#' Reads a CSV or xlsx schedule file produced by [write_schedule()] (or
#' hand-built in Excel) and returns a validated `creel_schedule` object ready
#' for use with [creel_design()].
#'
#' The format is detected from the file extension. All columns are read as text
#' first, then [coerce_schedule_columns()] applies type coercion — the same
#' logic runs regardless of format so that Excel-reformatted dates and serial
#' numbers are handled consistently.
#'
#' @param path Path to a CSV (`.csv`) or xlsx (`.xlsx`, `.xls`) schedule file.
#'   For xlsx files the \pkg{readxl} package must be installed.
#'
#' @return A `creel_schedule` object with columns:
#'   - `date` (Date)
#'   - `day_type` (character)
#'   - `period_id` (integer, if present)
#'   - `sampled` (logical, if present)
#'
#' @examples
#' sched <- generate_schedule(
#'   "2024-06-01", "2024-08-31",
#'   n_periods = 2,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed = 42
#' )
#' tmp <- tempfile(fileext = ".csv")
#' write_schedule(sched, tmp)
#' sched2 <- read_schedule(tmp)
#' inherits(sched2, "creel_schedule")
#'
#' @export
read_schedule <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("xlsx", "xls")) {
    rlang::check_installed("readxl", reason = "to read xlsx schedule files")
    raw <- readxl::read_excel(path, col_types = "text")
  } else {
    raw <- utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      colClasses = "character"
    )
  }
  raw <- as.data.frame(raw)
  coerced <- coerce_schedule_columns(raw)
  validate_creel_schedule(coerced) # nolint: object_usage_linter
  new_creel_schedule(coerced) # nolint: object_usage_linter
}
