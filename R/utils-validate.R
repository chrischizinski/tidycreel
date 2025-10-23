#' Utility: Require Columns
#'
#' Checks that all required columns are present in a data.frame. Throws an error listing missing columns.
#' @param df Data frame to check
#' @param cols Character vector of required column names
#' @param context Optional string describing the context (for error message)
#' @return Invisibly returns TRUE if all columns are present
#' @export
#' @examples
#' tc_require_cols(data.frame(a=1, b=2), c("a", "b"))
tc_require_cols <- function(df, cols, context = "") {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "x" = paste0("Missing columns in ", context, "."),
      "i" = paste0("Add: ", paste(missing, collapse = ", "))
    ))
  }
  invisible(TRUE)
}

#' Abort with a standardized message for missing columns (cli)
#' @param df Data frame to check
#' @param cols Required columns
#' @param context Context string for error message
#' @export
tc_abort_missing_cols <- function(df, cols, context = "") {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    cli::cli_abort(
      c(
        "x" = paste0("Missing required columns in ", context, "."),
        "i" = paste0("Add: ", paste(missing, collapse = ", "))
      )
    )
  }
  invisible(TRUE)
}

#' Utility: Guess Columns
#'
#' Maps synonyms to standard column names if present.
#' @param df Data frame
#' @param synonyms Named character vector (names = standard, values = synonyms)
#' @return Data frame with columns renamed
#' @export
tc_guess_cols <- function(df, synonyms) {
  for (std in names(synonyms)) {
    syn <- synonyms[[std]]
    if (syn %in% names(df) && !(std %in% names(df))) {
      names(df)[names(df) == syn] <- std
    }
  }
  df
}

#' Utility: Group Warn
#'
#' Drops absent grouping columns with a warning.
#' @param by Character vector of grouping columns
#' @param df_names Names of data frame
#' @return Filtered grouping columns
#' @export
tc_group_warn <- function(by, df_names) {
  missing <- setdiff(by, df_names)
  if (length(missing) > 0) {
    msg <- paste0("Grouping columns not found and will be ignored: ", paste(missing, collapse = ", "))
    warning(msg, call. = FALSE)
    by <- intersect(by, df_names)
  }
  by
}

#' Utility: Diagnostics for Dropped Rows
#'
#' Builds a diagnostics tibble for dropped rows.
#' @param df_before Data frame before dropping
#' @param df_after Data frame after dropping
#' @param reason Reason for drop
#' @return Tibble with diagnostics
#' @export
tc_diag_drop <- function(df_before, df_after, reason) {
  n_before <- nrow(df_before)
  n_after <- nrow(df_after)
  tibble::tibble(
    reason = reason,
    n_dropped = n_before - n_after,
    n_remaining = n_after
  )
}

#' Validate required columns in a data.frame
#'
#' Checks that all required columns are present in the input data.frame or tibble.
#' Returns TRUE if all are present, otherwise returns a character vector of missing columns.
#'
#' @param df A data.frame or tibble
#' @param required Character vector of required column names
#' @return TRUE if all present, else character vector of missing columns
#' @examples
#' df <- data.frame(date = "2025-01-01", count = 5)
#' validate_required_columns(df, c("date", "count"))
#' @export
validate_required_columns <- function(df, required) {
  missing <- setdiff(required, names(df))
  if (length(missing) == 0) TRUE else missing
}

#' Validate values in a column
#'
#' Checks that all values in a column are within a set of allowed values.
#' Returns TRUE if all are valid, otherwise returns a vector of invalid values.
#'
#' @param x Vector of values
#' @param allowed Allowed values
#' @return TRUE if all valid, else vector of invalid values
#' @examples
#' shifts <- c("AM", "PM", "AM")
#' validate_allowed_values(shifts, c("AM", "PM", "EVE"))
#' @export
validate_allowed_values <- function(x, allowed) {
  invalid <- setdiff(unique(x), allowed)
  if (length(invalid) == 0) TRUE else invalid
}

#' Report dropped rows
#'
#' Returns a summary of rows dropped due to missing or invalid data.
#'
#' @param original Original data.frame
#' @param filtered Filtered data.frame
#' @return List with n_dropped and dropped_rows
#' @examples
#' df_original <- data.frame(id = 1:3, value = c(10, NA, 30))
#' df_cleaned <- data.frame(id = c(1, 3), value = c(10, 30))
#' report_dropped_rows(df_original, df_cleaned)
#' @export
report_dropped_rows <- function(original, filtered) {
  dropped <- dplyr::anti_join(original, filtered, by = intersect(names(original), names(filtered)))
  list(n_dropped = nrow(dropped), dropped_rows = dropped)
}

#' Clamp probabilities to (0,1] with a warning
#' @param x numeric vector of probabilities
#' @param name optional name for messaging
#' @return clamped numeric vector
#' @export
tc_clamp01 <- function(x, name = "probability") {
  idx <- which(!is.na(x) & (x <= 0 | x > 1))
  if (length(idx) > 0) {
    cli::cli_warn(c("!" = paste0(length(idx), " ", name, " values outside (0,1]; clamping applied.")))
  }
  pmax(pmin(x, 1), .Machine$double.eps)
}

#' Drop rows with missing values in required columns; return diagnostics
#' @param df data.frame
#' @param required_cols character vector of column names
#' @param reason text reason for diagnostics
#' @return list(df = filtered_df, diagnostics = tibble)
#' @export
tc_drop_na_rows <- function(df, required_cols, reason = "missing required fields") {
  before <- df
  keep <- Reduce(`&`, lapply(required_cols, function(col) !is.na(df[[col]])))
  df2 <- df[keep, , drop = FALSE]
  diag <- tc_diag_drop(before, df2, reason = reason)
  list(df = df2, diagnostics = diag)
}
