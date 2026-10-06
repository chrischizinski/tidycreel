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
#' @examples
#' sched <- generate_schedule(
#'   start_date    = "2024-06-01",
#'   end_date      = "2024-06-14",
#'   n_periods     = 1,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed          = 42
#' )
#' validate_creel_schedule(sched)
#'
#' @family "Scheduling"
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

    # p_period (GH #385): the chance each worked period (shift) was drawn for
    # that day. Every row with a period on a sampled day needs one in (0, 1];
    # without it the period cannot be expanded to the day. An unsampled day
    # (sampled = FALSE) has no drawn period and may carry NA.
    if ("p_period" %in% names(data)) {
      p <- data$p_period
      if (!is.numeric(p)) {
        collection$push("Column 'p_period' must be numeric")
      } else {
        needs_p <- rep(TRUE, nrow(data))
        if ("period_id" %in% names(data)) needs_p <- needs_p & !is.na(data$period_id)
        if ("sampled" %in% names(data)) needs_p <- needs_p & data$sampled %in% TRUE
        bad_p <- needs_p & (is.na(p) | p <= 0 | p > 1)
        if (any(bad_p)) {
          collection$push(paste0(
            "Column 'p_period' must be in (0, 1] for every worked period; ",
            sum(bad_p), " row(s) are missing or out of range (first on ",
            format(data$date[which(bad_p)[1]]), ")"
          ))
        }
      }
    }

    # day_start (GH #407): the clock time each survey day begins. One value
    # for the whole schedule; absent means "00:00".
    ds <- 0L
    if ("day_start" %in% names(data)) {
      dsv <- unique(as.character(data$day_start))
      if (length(dsv) != 1L || is.na(dsv) || !grepl("^([01][0-9]|2[0-3]):[0-5][0-9]$", dsv)) {
        collection$push("Column 'day_start' must hold one \"HH:MM\" time for every row")
      } else {
        ds <- parse_hhmm_to_min(dsv) # nolint: object_usage_linter
      }
    }

    # shift_hours (GH #407): a shift's real elapsed length, positive.
    if ("shift_hours" %in% names(data)) {
      sh <- data$shift_hours
      if (!is.numeric(sh)) {
        collection$push("Column 'shift_hours' must be numeric")
      } else if (any(!is.na(sh) & sh <= 0)) {
        collection$push("Column 'shift_hours' must be positive")
      }
    }

    # Shift times (GH #385): "HH:MM", both present, and each shift inside one
    # survey day on the clock that starts at day_start (#407). The shift
    # length is derived from them, so an unreadable time or a shift leaving
    # its survey day is refused here, not when it is used.
    if (any(c("shift_start", "shift_end") %in% names(data))) {
      if (!all(c("shift_start", "shift_end") %in% names(data))) {
        collection$push("Columns 'shift_start' and 'shift_end' must be supplied together")
      } else {
        st <- as.character(data$shift_start)
        en <- as.character(data$shift_end)
        has <- !is.na(st) | !is.na(en)
        hhmm <- "^([01][0-9]|2[0-3]):[0-5][0-9]$"
        bad_fmt <- has & (!grepl(hhmm, st) | !grepl(hhmm, en))
        # A worked period on a sampled day needs its shift: with the columns
        # present, a blank pair would leave that day's shift length unknown.
        worked <- rep(TRUE, nrow(data))
        if ("period_id" %in% names(data)) worked <- worked & !is.na(data$period_id)
        if ("sampled" %in% names(data)) worked <- worked & data$sampled %in% TRUE
        no_times <- worked & !has
        if (any(no_times)) {
          collection$push(paste0(
            "Every worked period needs 'shift_start' and 'shift_end'; ",
            sum(no_times), " row(s) have neither (first on ", format(data$date[which(no_times)[1]]), ")"
          ))
        }
        if (any(bad_fmt)) {
          collection$push(paste0(
            "Columns 'shift_start'/'shift_end' must be \"HH:MM\" (00:00 to 23:59); ",
            sum(bad_fmt), " row(s) are not (first on ", format(data$date[which(bad_fmt)[1]]), ")"
          ))
        } else if (any(has)) {
          to_min <- function(x) as.integer(substr(x, 1, 2)) * 60L + as.integer(substr(x, 4, 5))
          wraps <- has & survey_min(to_min(en), ds, end = TRUE) <= survey_min(to_min(st), ds) # nolint: object_usage_linter
          if (any(wraps, na.rm = TRUE)) {
            collection$push(paste0(
              "Shifts must end after they start within one survey day (day_start ",
              format_min_to_hhmm(ds), "); ", sum(wraps, na.rm = TRUE), " row(s) do not" # nolint: object_usage_linter
            ))
          }
        }
      }
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
