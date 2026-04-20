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
    cli::cli_abort(
      c(
        "Calendar data validation failed:",
        stats::setNames(msgs, rep("x", length(msgs))),
        "i" = paste(
          "Calendar data must be a data frame with at least one Date column",
          "and one character/factor column for strata."
        )
      ),
      class = "creel_error_schema_validation"
    )
  }

  invisible(data)
}

#' Validate a creel_schedule object
#'
#' Checks that a `creel_schedule` (or plain data frame intended for use with
#' [creel_design()]) has the required columns, correct types, and sensible
#' values. Called by [read_schedule()] after coercion and available for users
#' to validate hand-constructed schedules.
#'
#' @param data A data frame to validate.
#'
#' @return Invisibly returns the input data frame on success. Aborts with an
#'   informative error message on validation failure.
#'
#' @export
validate_creel_schedule <- function(data) {
  collection <- checkmate::makeAssertCollection()
  checkmate::assert_data_frame(data, min.rows = 1, add = collection)

  if (is.data.frame(data) && nrow(data) > 0) {
    # Required columns
    if (!"date" %in% names(data)) {
      collection$push("Required column 'date' is missing")
    } else if (!inherits(data$date, "Date")) {
      collection$push("Column 'date' must be class Date")
    } else {
      bad_dates <- data$date < as.Date("1970-01-01") | data$date > as.Date("2100-12-31")
      if (any(bad_dates, na.rm = TRUE)) {
        collection$push("Column 'date' contains values outside plausible range 1970-2100")
      }
    }

    if (!"day_type" %in% names(data)) {
      collection$push("Required column 'day_type' is missing")
    } else if (!is.character(data$day_type)) {
      collection$push("Column 'day_type' must be character (not factor or other type)")
    } else {
      # Value-level checks: reject NA and empty string
      if (any(is.na(data$day_type))) {
        collection$push("Column 'day_type' contains NA values")
      }
      if (any(!is.na(data$day_type) & nchar(data$day_type) == 0L)) {
        collection$push("Column 'day_type' contains empty string values")
      }
    }

    # period_id is optional (absent when expand_periods = FALSE), but if present must be positive
    if ("period_id" %in% names(data)) {
      pid <- data$period_id
      if (is.integer(pid) || is.numeric(pid)) {
        if (any(!is.na(pid) & pid <= 0)) {
          collection$push("Column 'period_id' must contain only positive values")
        }
      }
      # character and factor period_id are always valid — no further checks
    }
  }

  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(
      c(
        "creel_schedule validation failed:",
        stats::setNames(msgs, rep("x", length(msgs))),
        "i" = "Ensure 'date' is Date class, 'day_type' is non-NA non-empty character."
      ),
      class = "creel_error_schema_validation"
    )
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
    cli::cli_abort(
      c(
        "Count data validation failed:",
        stats::setNames(msgs, rep("x", length(msgs))),
        "i" = paste(
          "Count data must be a data frame with at least one Date column",
          "and one numeric column."
        )
      ),
      class = "creel_error_schema_validation"
    )
  }

  invisible(data)
}

#' Validate interview data schema
#'
#' Internal validator that checks if data frame has the required structure for
#' interview data: at least one Date column and at least one numeric column
#' (for catch/effort/harvest).
#'
#' @param data A data frame to validate
#'
#' @return Invisibly returns the input data frame on success. Aborts with
#'   informative error message on validation failure.
#'
#' @keywords internal
#' @noRd
validate_interview_schema <- function(data) {
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
    cli::cli_abort(
      c(
        "Interview data validation failed:",
        stats::setNames(msgs, rep("x", length(msgs))),
        "i" = paste(
          "Interview data must be a data frame with at least one Date column",
          "and one numeric column."
        )
      ),
      class = "creel_error_schema_validation"
    )
  }

  invisible(data)
}
