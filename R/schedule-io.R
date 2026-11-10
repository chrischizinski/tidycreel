#' Coerce a value to Date
#'
#' Internal helper used by `coerce_schedule_columns()` to convert dates read
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
      creel_warn(
        c(
          "Some date values could not be parsed and were coerced to {.val NA}.",
          "i" = "{sum(new_nas)} value(s) failed date coercion."
        ),
        class = c("creel_warning_dates_coerced_na", "creel_warning")
      )
    }
    return(result)
  }
  result <- suppressWarnings(as.Date(x))
  was_na_before <- is.na(x)
  new_nas <- is.na(result) & !was_na_before
  if (any(new_nas)) {
    creel_warn(
      c(
        "Some date values could not be parsed and were coerced to {.val NA}.",
        "i" = "{sum(new_nas)} value(s) failed ISO 8601 coercion."
      ),
      class = c("creel_warning_dates_coerced_na", "creel_warning")
    )
  }
  result
}

#' Coerce schedule data frame columns to their canonical types
#'
#' Internal helper. Applies type coercion to the columns `date`, `day_type`,
#' `period_id`, `window_id`, and `sampled` if present. Column matching is by
#' name; columns absent from `df` are left alone. This ensures identical
#' coercion logic for both CSV and xlsx paths.
#'
#' The list is an allow-list, so a column a schedule generator adds in future
#' will round-trip as character until it is named here (GH #194).
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
    pid <- df$period_id
    all_numeric <- all(is.na(pid) | grepl("^[0-9]+$", pid))
    if (all_numeric) {
      df$period_id <- as.integer(pid)
    }
    # else: character period labels (e.g. "AM"/"PM") — preserve as-is
  }
  if ("window_id" %in% names(df)) {
    wid <- df$window_id
    all_numeric <- all(is.na(wid) | grepl("^[0-9]+$", wid))
    if (all_numeric) {
      df$window_id <- as.integer(wid)
    }
    # else: character window labels — preserve as-is, as for period_id
  }
  if ("sampled" %in% names(df)) {
    df$sampled <- as.logical(df$sampled)
  }
  if ("shift_hours" %in% names(df)) {
    sh <- df$shift_hours
    sh[!is.na(sh) & (sh == "NA" | sh == "")] <- NA
    df$shift_hours <- suppressWarnings(as.numeric(sh))
  }
  if ("p_period" %in% names(df)) {
    # Text that is not a number becomes NA, which validate_creel_schedule()
    # then refuses on any worked period (GH #385).
    pp <- df$p_period
    pp[!is.na(pp) & (pp == "NA" | pp == "")] <- NA
    df$p_period <- suppressWarnings(as.numeric(pp))
  }
  df
}

#' Decide the file format a writer uses, from `format` and the path's extension
#'
#' Shared by [write_schedule()] and [write_estimates()] (GH #547). `"auto"`
#' takes the format from a `.csv` or `.xlsx` extension and refuses any other.
#' An explicit format is used as given unless the extension names the other
#' format, which is refused: a `.xlsx` file holding CSV text is one Excel will
#' not open, and nothing in R would have said so.
#'
#' @param path Output path.
#' @param format `"auto"`, `"csv"` or `"xlsx"`, already matched.
#' @param call Environment of the user-facing caller, for the error.
#' @return `"csv"` or `"xlsx"`.
#' @keywords internal
#' @noRd
resolve_write_format <- function(path, format, call = rlang::caller_env()) {
  ext <- tolower(tools::file_ext(path))
  implied <- switch(ext, csv = "csv", xlsx = "xlsx", xls = "xlsx", NA_character_)
  if (identical(format, "auto")) {
    # .xls is the legacy binary format, which neither writer produces.
    if (is.na(implied) || identical(ext, "xls")) {
      cli::cli_abort(c(
        "Cannot infer the file format from {.path {path}}.",
        "i" = "Use a {.val .csv} or {.val .xlsx} extension, or set {.arg format}."
      ), class = c("creel_error_write_format", "creel_error"), call = call)
    }
    return(implied)
  }
  if (!is.na(implied) && !identical(implied, format)) {
    cli::cli_abort(c(
      "{.arg format} is {.val {format}}, but {.path {path}} names an {.val {implied}} file.",
      "x" = "The file would hold {format} content under a .{ext} name.",
      "i" = "Change the extension, or drop {.arg format} to use the one the name implies."
    ), class = c("creel_error_write_format", "creel_error"), call = call)
  }
  format
}

#' Write a creel schedule to a CSV or xlsx file
#'
#' Exports a `creel_schedule` object to disk, as CSV using base R (no extra
#' dependencies) or as xlsx. The `"xlsx"` format requires the \pkg{writexl}
#' package; an informative error is raised if it is not installed.
#'
#' @param schedule A `creel_schedule` object (or plain data frame) to export.
#' @param path File path for the output file. With `format = "auto"` its
#'   extension (`.csv` or `.xlsx`) sets the format.
#' @param format One of `"auto"` (default), `"csv"` or `"xlsx"`. `"auto"`
#'   takes the format from the extension of `path` and refuses any other
#'   extension. An explicit format is used for a path with any other extension,
#'   but refused when the extension names the other format, so a `.xlsx` file
#'   never holds CSV text. `"csv"` is written with [utils::write.csv()] (no row
#'   names); `"xlsx"` with [writexl::write_xlsx()] behind an
#'   [rlang::check_installed()] guard.
#' @param overwrite Logical. If `FALSE` (default), aborts with an error when
#'   `path` already exists. Set `TRUE` to replace an existing file.
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
#' @family "Scheduling"
#' @export
write_schedule <- function(schedule, path, format = c("auto", "csv", "xlsx"), overwrite = FALSE) {
  if (!overwrite && file.exists(path)) {
    cli::cli_abort(c(
      "File already exists: {.path {path}}",
      "i" = "Set {.code overwrite = TRUE} to replace it."
    ))
  }
  format <- resolve_write_format(path, match.arg(format))
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
#' first, then `coerce_schedule_columns()` applies type coercion -- the same
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
#'   - `p_period` (numeric, if present): the probability each worked period
#'     was drawn for its day. Every row with a period on a sampled day must
#'     carry one in (0, 1]; a missing, non-numeric or out-of-range value is an
#'     error, because the period could not be expanded to the day.
#'     A file with `period_id` but no `p_period` column (written before the
#'     column existed) is read as `p_period = 1`, with a warning, when every
#'     sampled day carries the same periods (each was worked every day); if
#'     the periods differ between days they were drawn, and it is an error.
#'   - `shift_start`, `shift_end` (character "HH:MM", if present)
#'   - `shift_hours` (numeric, if present)
#'   - `day_start` (character "HH:MM", if present): when each survey day
#'     begins; shift times are read on that clock
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
#' @family "Scheduling"
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
  # After validation: a file that is invalid for another reason errors without
  # a p_period warning first, and an inferred p_period = 1 is always valid.
  coerced <- infer_census_p_period(coerced, path)
  new_creel_schedule(coerced) # nolint: object_usage_linter
}

#' Supply p_period for a schedule file written before shifts were drawn
#'
#' Internal (GH #385). A file with `period_id` but no `p_period` predates the
#' column. If every sampled day carries the same set of periods, every period
#' was worked on every day -- no shift was drawn -- so each was certain to be
#' worked: `p_period = 1`, with a warning saying it was inferred. If the sets
#' differ between days, periods were drawn, and the probability is neither
#' recorded nor computable from the file: an error naming the days.
#'
#' @noRd
infer_census_p_period <- function(df, path, call = rlang::caller_env()) {
  if (!"period_id" %in% names(df) || "p_period" %in% names(df)) {
    return(df)
  }
  worked <- !is.na(df$period_id)
  if ("sampled" %in% names(df)) worked <- worked & df$sampled %in% TRUE
  if (!any(worked)) {
    return(df)
  }
  sets <- tapply(as.character(df$period_id[worked]), as.character(df$date[worked]),
                 function(x) paste(sort(unique(x)), collapse = "\u001f"))
  common <- names(which.max(table(sets)))
  odd_days <- names(sets)[sets != common]
  if (length(odd_days) > 0L) {
    cli::cli_abort(
      c(
        "{.path {basename(path)}} has periods but no {.col p_period} column, and the periods differ between days.",
        "x" = "{length(odd_days)} sampled day{?s} carr{?ies/y} a different set of periods than the rest \\
               (first: {.val {utils::head(odd_days, 3)}}), so periods were drawn and the chance each was \\
               worked is not in the file.",
        "i" = "Add a {.col p_period} column (e.g. 0.5 for one of two shifts drawn at random)."
      ),
      class = "creel_error_schema_validation",
      call = call
    )
  }
  df$p_period <- ifelse(worked, 1, NA_real_)
  creel_warn(
    c(
      "{.path {basename(path)}} has periods but no {.col p_period} column; set {.code p_period = 1}.",
      "i" = "Every sampled day carries the same periods, so every period was worked every day.",
      "i" = "If the periods were in fact drawn, add the real {.col p_period} to the file."
    ),
    class = c("creel_warning_p_period_inferred", "creel_warning")
  )
  df
}
