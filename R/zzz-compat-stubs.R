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
  cli::cli_abort(sprintf("%s(): not yet implemented (stub for build).", name))
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

## Legacy/DB/Project stubs removed per survey-first scope.

# nocov end
# nolint end
