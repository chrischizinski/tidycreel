#' Validate calendar data schema
#'
#' Internal validator that checks if data frame has the required structure for
#' calendar data: at least one Date column and at least one character/factor
#' column for strata.
#'
#' @param data A data frame to validate
#'
#' @return Invisibly returns the input data frame on success. Aborts with
#'   informative error message on validation failure.
#'
#' @keywords internal
#' @noRd
validate_calendar_schema <- function(data) {
  collection <- checkmate::makeAssertCollection()
  checkmate::assert_data_frame(data, min.rows = 1, add = collection)

  if (is.data.frame(data) && nrow(data) > 0) {
    has_date <- any(vapply(data, inherits, logical(1), "Date"))
    if (!has_date) {
      collection$push("Must contain at least one Date column")
    }

    has_char <- any(vapply(data, is.character, logical(1))) ||
      any(vapply(data, is.factor, logical(1)))
    if (!has_char) {
      collection$push("Must contain at least one character or factor column for strata")
    }
  }

  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(c(
      "Calendar data validation failed:",
      stats::setNames(msgs, rep("x", length(msgs))),
      "i" = paste(
        "Calendar data must be a data frame with at least one Date column",
        "and one character/factor column for strata."
      )
    ))
  }

  invisible(data)
}

#' Validate count data schema
#'
#' Internal validator that checks if data frame has the required structure for
#' count data: at least one Date column and at least one numeric (integer or
#' double) column.
#'
#' @param data A data frame to validate
#'
#' @return Invisibly returns the input data frame on success. Aborts with
#'   informative error message on validation failure.
#'
#' @keywords internal
#' @noRd
validate_count_schema <- function(data) {
  collection <- checkmate::makeAssertCollection()
  checkmate::assert_data_frame(data, min.rows = 1, add = collection)

  if (is.data.frame(data) && nrow(data) > 0) {
    has_date <- any(vapply(data, inherits, logical(1), "Date"))
    if (!has_date) {
      collection$push("Must contain at least one Date column")
    }

    has_numeric <- any(vapply(data, is.numeric, logical(1)))
    if (!has_numeric) {
      collection$push("Must contain at least one numeric column")
    }
  }

  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(c(
      "Count data validation failed:",
      stats::setNames(msgs, rep("x", length(msgs))),
      "i" = paste(
        "Count data must be a data frame with at least one Date column",
        "and one numeric column."
      )
    ))
  }

  invisible(data)
}
