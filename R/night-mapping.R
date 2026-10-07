# Night creels: mapping records to survey days (GH #407, part 4b)
#
# A survey day runs from `day_start` on its date to `day_start` on the next
# date. With day_start = "12:00", the night of Apr 3 holds a 20:00 count on
# Apr 3 and a 00:45 count on Apr 4. Every estimator keys a day by the date
# column -- PSU, within-day key, N_h / n_h, the shift lookup, the stratum -- so
# replacing each record's calendar date with its survey date when it enters the
# design is the whole mapping; nothing downstream has night-specific code.

#' The night settings of a design, or NULL for a day design
#'
#' Internal (GH #407). `calendar` already carries any `day_start` argument as
#' its column (see `apply_day_start_arg()`). A night design is one whose survey
#' day does not start at midnight.
#'
#' @return `NULL`, or a list with `day_start` ("HH:MM"), `day_start_min`,
#'   `night_date` and `tz`.
#' @keywords internal
#' @noRd
resolve_night_design <- function(calendar, design_type, night_date, tz,
                                 call = rlang::caller_env()) {
  night_date <- rlang::arg_match0(night_date, c("start", "end"), arg_nm = "night_date", error_call = call)
  ds_min <- schedule_day_start(calendar, call = call) # nolint: object_usage_linter
  if (ds_min == 0L) {
    return(NULL)
  }
  ds <- format_min_to_hhmm(ds_min) # nolint: object_usage_linter
  if (identical(night_date, "end")) {
    cli::cli_abort(
      c(
        "{.code night_date = \"end\"} is not supported.",
        "x" = "A night schedule dates each night by the day it starts, and so does \\
               its calendar: the day types, months and season ends are those of the start date.",
        "i" = "Use {.code night_date = \"start\"} (the default)."
      ),
      class = "creel_error_night_date_unsupported",
      call = call
    )
  }
  if (!identical(design_type, "instantaneous")) {
    cli::cli_abort(
      c(
        "Night survey days (day_start {.val {ds}}) are only supported for roving and \\
         access designs ({.code survey_type = \"instantaneous\"}).",
        "x" = "Got {.val {design_type}}, which keys its days in ways not yet mapped to nights."
      ),
      class = "creel_error_night_design_unsupported",
      call = call
    )
  }
  list(
    day_start = ds,
    day_start_min = ds_min,
    night_date = night_date,
    tz = resolve_design_tz(tz, call = call)
  )
}

#' Carry a `day_start` argument into the calendar
#'
#' Internal (GH #407). A schedule from `generate_schedule(day_start = )` names
#' its day start in a column; a hand-built calendar can name it with the
#' argument. Two sources that disagree are refused rather than one picked.
#'
#' @keywords internal
#' @noRd
apply_day_start_arg <- function(calendar, day_start, call = rlang::caller_env()) {
  if (is.null(day_start)) {
    return(calendar)
  }
  ds_min <- parse_day_start(day_start, call = call) # nolint: object_usage_linter
  if ("day_start" %in% names(calendar)) {
    cal_min <- schedule_day_start(calendar, call = call) # nolint: object_usage_linter
    if (cal_min != ds_min) {
      cli::cli_abort(
        c(
          "{.arg day_start} disagrees with the calendar's {.field day_start} column.",
          "x" = "The argument is {.val {day_start}}; the calendar says \\
                 {.val {format_min_to_hhmm(cal_min)}}.",
          "i" = "Drop the argument, or correct the calendar."
        ),
        class = "creel_error_day_start_conflict",
        call = call
      )
    }
    return(calendar)
  }
  calendar$day_start <- day_start
  calendar
}

#' The time zone a design is read in
#'
#' Internal (GH #407). Order: the `tz` argument, then
#' `options(tidycreel.tz)`, then an error. Never `Sys.timezone()`: that is the
#' analyst's computer, not the water. Only night designs ask for one.
#'
#' @keywords internal
#' @noRd
resolve_design_tz <- function(tz, call = rlang::caller_env()) {
  if (is.null(tz)) tz <- getOption("tidycreel.tz")
  if (is.null(tz)) {
    cli::cli_abort(
      c(
        "A night design needs a time zone.",
        "x" = "Neither {.arg tz} nor the {.field tidycreel.tz} option is set.",
        "i" = "Shift lengths across a daylight-saving change, and times given as POSIXct, \\
               are read in it.",
        "i" = "Pass e.g. {.code tz = \"America/Chicago\"}, or set the {.field tidycreel.tz} \\
               option once per session."
      ),
      class = "creel_error_night_tz_required",
      call = call
    )
  }
  if (!is.character(tz) || length(tz) != 1L || is.na(tz) || !tz %in% OlsonNames()) {
    cli::cli_abort(
      c(
        "{.arg tz} must be one time zone name from {.fn OlsonNames}.",
        "x" = "Got {.val {tz}}."
      ),
      class = "creel_error_night_tz_required",
      call = call
    )
  }
  tz
}

#' Map records to the night they belong to
#'
#' Internal (GH #407). `dates` are the records' calendar dates, `times` their
#' clock times ("HH:MM" or POSIXct). A time before `day_start` belongs to the
#' survey day that began the previous date.
#'
#' A POSIXct time names its own calendar date; it must be the record's date,
#' or the two disagree about the day. Its time zone, when it names one, must
#' be the design's.
#'
#' @return The survey dates (Date), one per record.
#' @keywords internal
#' @noRd
night_survey_dates <- function(dates, times, night, what, time_arg, call = rlang::caller_env()) {
  if (is.null(times)) {
    cli::cli_abort(
      c(
        "On a night design every {what} needs a clock time.",
        "x" = "{.arg {time_arg}} was not given.",
        "i" = "A record after midnight belongs to the night before; without its time \\
               it cannot be placed on either side of midnight."
      ),
      class = "creel_error_night_time_required",
      call = call
    )
  }
  if (inherits(times, "POSIXt")) {
    times <- as.POSIXct(times)
    zone <- attr(times, "tzone")
    zone <- if (is.null(zone)) "" else zone[1]
    if (nzchar(zone) && !identical(zone, night$tz)) {
      cli::cli_abort(
        c(
          "The {what} times are in time zone {.val {zone}}, the design's is {.val {night$tz}}.",
          "i" = "Convert them, e.g. {.code lubridate::with_tz()}, or check the design's {.arg tz}."
        ),
        class = "creel_error_night_tz_mismatch",
        call = call
      )
    }
    bad <- is.na(times)
    if (!any(bad)) {
      local_date <- as.Date(format(times, "%Y-%m-%d", tz = zone))
      off <- local_date != dates
      if (any(off)) {
        cli::cli_abort(
          c(
            "{sum(off)} {what} time{?s} fall{?s/} on a different date from {?its/their} \\
             record's date.",
            "x" = "First: dated {.val {format(dates[which(off)[1]])}}, timed \\
                   {.val {format(times[which(off)[1]], tz = zone)}}.",
            "i" = "Records carry their calendar date and time; the design maps them to nights."
          ),
          class = "creel_error_night_time_date_mismatch",
          call = call
        )
      }
      clock <- as.POSIXlt(times, tz = zone)
      mins <- clock$hour * 60L + clock$min
    }
  } else if (is.character(times) || is.factor(times)) {
    times <- as.character(times)
    bad <- is.na(times) | !grepl("^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$", times)
    if (!any(bad)) mins <- as.integer(substr(times, 1, 2)) * 60L + as.integer(substr(times, 4, 5))
  } else {
    bad <- rep(TRUE, length(times))
  }
  if (any(bad)) {
    cli::cli_abort(
      c(
        "{sum(bad)} {what} time{?s} in {.arg {time_arg}} cannot be read as a clock time.",
        "x" = "First: {.val {as.character(times[which(bad)[1]])}}.",
        "i" = "Give each {what} a time as {.val HH:MM} or a POSIXct date-time."
      ),
      class = "creel_error_night_time_unparseable",
      call = call
    )
  }
  dates - as.integer(mins < night$day_start_min)
}

#' The calendar rows on which a shift was worked
#'
#' Internal (GH #407). The same rule the shift lookup uses: a row with no
#' probability, no period or `sampled` FALSE was not worked. `NULL` when the
#' calendar does not say.
#'
#' @keywords internal
#' @noRd
calendar_worked_rows <- function(cal) {
  cols <- intersect(c("p_period", "period_id", "sampled"), names(cal))
  if (length(cols) == 0L) {
    return(NULL)
  }
  worked <- rep(TRUE, nrow(cal))
  if ("p_period" %in% cols) worked <- worked & !is.na(cal$p_period)
  if ("period_id" %in% cols) worked <- worked & !is.na(cal$period_id)
  if ("sampled" %in% cols) worked <- worked & cal$sampled %in% TRUE
  worked
}

#' Check mapped records against the nights and shifts the calendar worked
#'
#' Internal (GH #407). A record already dated by its night (the start date)
#' is moved back one more day by the mapping. Where that day was not sampled,
#' or its worked shift is a different one, the record does not belong there:
#' refused, since joining it would add a day or a shift that was never drawn.
#' Counts on unsampled days are already refused by the shift lookup; this adds
#' interviews, and the shift check for both.
#'
#' @keywords internal
#' @noRd
check_night_records_worked <- function(records, design, date_col, what, call = rlang::caller_env()) {
  cal <- design$calendar
  worked <- calendar_worked_rows(cal)
  if (is.null(worked)) {
    return(invisible(NULL))
  }
  cal_date <- design$date_col
  rec_day <- format(records[[date_col]])
  sampled <- rec_day %in% format(cal[[cal_date]][worked])
  if (!all(sampled)) {
    bad <- unique(rec_day[!sampled]) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "{sum(!sampled)} {what}{?s} map{?s/} to {length(bad)} night{?s} the schedule did not \\
         sample: {.val {bad}}.",
        "i" = "Records carry their calendar date: a 00:45 record belongs to the night before. \\
               A record already dated by its night is moved back a day too far."
      ),
      class = "creel_error_night_record_unsampled",
      call = call
    )
  }
  if ("period_id" %in% names(records) && "period_id" %in% names(cal)) {
    rec_key <- paste(rec_day, as.character(records$period_id), sep = " / ")
    cal_key <- paste(format(cal[[cal_date]][worked]), as.character(cal$period_id[worked]), sep = " / ")
    off <- !is.na(records$period_id) & !rec_key %in% cal_key
    if (any(off)) {
      bad <- unique(rec_key[off]) # nolint: object_usage_linter
      cli::cli_abort(
        c(
          "{sum(off)} {what}{?s} map{?s/} to a shift the schedule did not work that night: \\
           {.val {bad}} (night / period).",
          "i" = "Records carry their calendar date: a 00:45 record belongs to the night before. \\
                 A record already dated by its night is moved back a day too far."
        ),
        class = "creel_error_night_record_shift_not_worked",
        call = call
      )
    }
  }
  invisible(NULL)
}

#' Real elapsed hours of each calendar shift on a night design
#'
#' Internal (GH #407). `shift_hours`, where the schedule carries it, is the
#' elapsed length already (`daylight_shifts(night = TRUE)`). Otherwise each
#' bound is placed on its calendar date -- a time before `day_start` is on the
#' next one -- and read in the design's time zone, so a shift across a
#' daylight-saving change has its real length, not its clock length. A bound
#' the change skipped or repeated is refused rather than guessed.
#'
#' @keywords internal
#' @noRd
night_shift_hours <- function(cal, date_col, night, call = rlang::caller_env()) {
  ds <- night$day_start_min
  st <- vapply(as.character(cal$shift_start), function(t) {
    if (is.na(t)) NA_integer_ else parse_hhmm_to_min(t) # nolint: object_usage_linter
  }, integer(1), USE.NAMES = FALSE)
  en <- vapply(as.character(cal$shift_end), function(t) {
    if (is.na(t)) NA_integer_ else parse_hhmm_to_min(t) # nolint: object_usage_linter
  }, integer(1), USE.NAMES = FALSE)
  stamp <- function(clock, off) {
    day <- cal[[date_col]] + as.integer(ds + off >= 1440L)
    paste(format(day), format_min_to_hhmm(clock)) # nolint: object_usage_linter
  }
  s_off <- survey_min(st, ds) # nolint: object_usage_linter
  e_off <- survey_min(en, ds, end = TRUE) # nolint: object_usage_linter
  ok <- !is.na(st) & !is.na(en)
  # The calendar's shift times are not validated when the design is built, so
  # a shift that leaves its survey day (05:00-14:00 with day_start 12:00) is
  # refused here, where its length would otherwise come out negative.
  leaves <- ok & e_off <= s_off
  if (any(leaves)) {
    bad <- unique(format(cal[[date_col]][leaves])) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "A shift does not fit inside one survey day on {length(bad)} night{?s}: {.val {bad}}.",
        "x" = "Survey days start at {night$day_start}; a shift must end after it starts \\
               on that clock."
      ),
      class = "creel_error_period_length_window",
      call = call
    )
  }
  hours <- rep(NA_real_, nrow(cal))
  if (any(ok)) {
    s <- local_instants(stamp(st, s_off)[ok], night$tz) # nolint: object_usage_linter
    e <- local_instants(stamp(en, e_off)[ok], night$tz) # nolint: object_usage_linter
    amb <- s$n != 1L | e$n != 1L
    if (any(amb) && !"shift_hours" %in% names(cal)) {
      bad <- unique(format(cal[[date_col]][ok][amb])) # nolint: object_usage_linter
      cli::cli_abort(
        c(
          "A shift starts or ends in an hour a daylight-saving change skipped or repeated \\
           on {length(bad)} night{?s}: {.val {bad}}.",
          "x" = "Its length in {.val {night$tz}} is not determined by its clock times.",
          "i" = "Add a {.field shift_hours} column with the real length, as \\
                 {.fn daylight_shifts} returns."
        ),
        class = "creel_error_period_length_window",
        call = call
      )
    }
    hours[ok] <- (e$t - s$t) / 3600
  }
  if ("shift_hours" %in% names(cal)) {
    given <- !is.na(cal$shift_hours)
    hours[given] <- cal$shift_hours[given]
  }
  hours
}
