#' Legacy stubs removed; not part of the package
#' @name tidycreel-compat-stubs
NULL

# nolint start: object_name_linter, brace_linter, semicolon_linter, commas_linter, trailing_blank_lines_linter
# Compatibility shims to satisfy NAMESPACE during incremental builds.
# Replace TODO stubs with real implementations when ready.
# nocov start

# ---- Internal helper ----
#' Internal TODO stub for compatibility
#' @name .todo
#' @keywords internal
.todo <- function(name) {
  stop(sprintf("%s(): not yet implemented (stub for build).", name), call. = FALSE)
  invisible(NULL)
}

# ---- Simple utilities (implemented) ----

#' Convert acres to hectares
#' @param x numeric vector (acres)
#' @return numeric vector (hectares)
#' @export
acres_to_hectares <- function(x) x * 0.40468564224

#' Convert hectares to acres
#' @param x numeric vector (hectares)
#' @return numeric vector (acres)
#' @export
hectares_to_acres <- function(x) x / 0.40468564224

#' Capitalize words
#' @param x character vector
#' @return character vector
#' @export
capwords <- function(x) stringr::str_to_title(x)

#' Trim leading and trailing whitespace
#' @param x character vector
#' @return character vector
#' @export
trim <- function(x) stringr::str_trim(x)

#' Even-number predicate
#' @param x integer/numeric vector
#' @return logical
#' @export
is.even <- function(x) (x %% 2L) == 0L

#' Convert to logical (compat)
#' @param x any
#' @return logical
#' @export
convertToLogical <- function(x) as.logical(x)

#' Replace NAs with a value (compat)
#' @param x vector
#' @param value replacement value (default NA)
#' @return vector with NAs replaced
#' @export
na.return <- function(x, value = NA) {
  x[is.na(x)] <- value
  x
}

#' Change NA or specific values to a target
#' @param x vector
#' @param from values to treat as missing (default NA)
#' @param to replacement value (default 0)
#' @return vector with replacements
#' @export
change_na <- function(x, from = NA, to = 0) {
  x[is.na(x) | x %in% from] <- to
  x
}

# ---- Legacy/DB/Project stubs (exported but not yet implemented) ----
# Keep signatures minimal; mark as internal to avoid cluttering user help.

#' @export
#' @keywords internal
connect_creel <- function(...) .todo("connect_creel")

#' @export
#' @keywords internal
db_disconnect <- function(...) .todo("db_disconnect")

#' @export
#' @keywords internal
db_exec <- function(...) .todo("db_exec")

#' @export
#' @keywords internal
db_read <- function(...) .todo("db_read")

#' @export
#' @keywords internal
convert_legacy_date <- function(x, ...) .todo("convert_legacy_date")

#' @export
#' @keywords internal
convert_to_legacy_date <- function(x, ...) .todo("convert_to_legacy_date")

#' @export
#' @keywords internal
convert_to_legacy_names <- function(x, ...) .todo("convert_to_legacy_names")

#' @export
#' @keywords internal
create_days_in_creel <- function(...) .todo("create_days_in_creel")

#' @export
#' @keywords internal
create_sample_legacy_data <- function(...) .todo("create_sample_legacy_data")

#' @export
#' @keywords internal
extract_sequence_from_creel_id <- function(...) .todo("extract_sequence_from_creel_id")

#' @export
#' @keywords internal
extract_year_from_creel_id <- function(...) .todo("extract_year_from_creel_id")

#' @export
#' @keywords internal
legacy_data_access <- function(...) .todo("legacy_data_access")

#' @export
#' @keywords internal
legacy_design <- function(...) .todo("legacy_design")

#' @export
#' @keywords internal
legacy_estimate <- function(...) .todo("legacy_estimate")

#' @export
#' @keywords internal
legacy_summary <- function(...) .todo("legacy_summary")

#' @export
#' @keywords internal
split_wide_tables <- function(...) .todo("split_wide_tables")

#' @export
#' @keywords internal
summarize_legacy_data <- function(...) .todo("summarize_legacy_data")

# nocov end
# nolint end
