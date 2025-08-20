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
    msg <- paste0(
      "Missing columns in ", context, ": ",
      paste(missing, collapse=", ")
    )
    stop(msg, call. = FALSE)
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
    msg <- paste0(
      "Note: The following grouping columns were not found in your data and will be ignored: ",
      paste(missing, collapse=", "),
      ". Results will be grouped by available columns only. ",
      "To avoid this message, ensure your data includes all expected grouping columns."
    )
    warning(msg)
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
