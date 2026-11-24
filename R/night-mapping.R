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
    creel_abort(
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
    creel_abort(
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
      creel_abort(
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
    creel_abort(
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
    creel_abort(
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
#' or the two disagree about the day. It must carry the design's time zone.
#'
#' @return The survey dates (Date), one per record.
#' @keywords internal
#' @noRd
night_survey_dates <- function(dates, times, night, what, time_arg, call = rlang::caller_env()) {
  if (is.null(times)) {
    creel_abort(
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
    # A POSIXct with no zone is read in the computer's zone, which is not the
    # water's: refused rather than read in either.
    if (!nzchar(zone)) {
      creel_abort(
        c(
          "The {what} times are POSIXct with no time zone.",
          "x" = "Their clock would be read in this computer's zone, not the design's \\
                 ({.val {night$tz}}).",
          "i" = "Create them with {.code tz = \"{night$tz}\"}, or give the times as {.val HH:MM}."
        ),
        class = "creel_error_night_tz_mismatch",
        call = call
      )
    }
    if (!identical(zone, night$tz)) {
      creel_abort(
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
        creel_abort(
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
    creel_abort(
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
#' A design that names its register (`creel_design(sampled = )`, GH #591)
#' answers the question itself: that column decides alone (GH #630), so a
#' literal `sampled` or `p_period` column meaning something else cannot
#' overrule it.
#'
#' @keywords internal
#' @noRd
calendar_worked_rows <- function(cal, sampled_col = NULL) {
  if (!is.null(sampled_col)) {
    return(cal[[sampled_col]] %in% TRUE)
  }
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
  worked <- calendar_worked_rows(cal, design$sampled_col)
  if (is.null(worked)) {
    return(invisible(NULL))
  }
  cal_date <- design$date_col
  rec_day <- format(records[[date_col]])
  sampled <- rec_day %in% format(cal[[cal_date]][worked])
  if (!all(sampled)) {
    bad <- unique(rec_day[!sampled]) # nolint: object_usage_linter
    creel_abort(
      c(
        "{sum(!sampled)} {what}{?s} map{?s/} to {length(bad)} night{?s} the schedule did not \\
         sample: {.val {bad}}.",
        "i" = "Records carry their calendar date: a 00:45 record belongs to the night before. \\
               A record already dated by its night is moved back a day too far."
      ),
      class = c("creel_error_night_record_unsampled", "creel_error_record_unworked_day"),
      call = call
    )
  }
  if ("period_id" %in% names(records) && "period_id" %in% names(cal)) {
    rec_key <- paste(rec_day, as.character(records$period_id), sep = " / ")
    cal_key <- paste(format(cal[[cal_date]][worked]), as.character(cal$period_id[worked]), sep = " / ")
    off <- !is.na(records$period_id) & !rec_key %in% cal_key
    if (any(off)) {
      bad <- unique(rec_key[off]) # nolint: object_usage_linter
      creel_abort(
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

#' Refuse interviews dated on a day the schedule did not sample (day designs)
#'
#' Internal (GH #454). The day-design twin of [check_night_records_worked()].
#' A calendar that records which days were worked (`p_period`, `period_id` or
#' `sampled`, as `generate_schedule(include_all = TRUE)` writes it) says which
#' days were drawn. An interview on any other day was not selected by the
#' design, yet it joined its stratum and entered the rate and every total
#' built on it with no message. Counts on such days were already refused. The
#' interviews are the user's to resolve -- drop them or correct their dates --
#' so they are refused, never dropped. A calendar with none of those columns
#' marks no day as unsampled and is not checked.
#'
#' @keywords internal
#' @noRd
check_day_records_worked <- function(records, design, date_col, what, call = rlang::caller_env()) {
  cal <- design$calendar
  worked <- calendar_worked_rows(cal, design$sampled_col)
  if (is.null(worked)) {
    return(invisible(NULL))
  }
  rec_day <- format(records[[date_col]])
  sampled <- rec_day %in% format(cal[[design$date_col]][worked])
  if (!all(sampled)) {
    bad <- sort(unique(rec_day[!sampled]))
    shown <- utils::head(bad, 10L) # nolint: object_usage_linter
    n_rec <- sum(!sampled) # nolint: object_usage_linter
    more <- if (length(bad) > 10L) ", ..." else "" # nolint: object_usage_linter
    # A refused or excluded row is never weighted; it is counted in its table.
    why <- if (identical(what, "interview")) { # nolint: object_usage_linter
      "an interview the design did not select cannot be weighted with the ones it did."
    } else {
      "each is counted in the {what} table by its date, and the design did not select that date."
    }
    creel_abort(
      c(
        "{n_rec} {what}{cli::qty(n_rec)}{?s} {?is/are} dated on {length(bad)} \
         day{?s} the schedule did not sample: {.val {shown}}{more}.",
        "x" = "The calendar marks which days were worked, and these were not drawn.",
        "i" = paste("Correct the dates, or drop these {what}s before attaching them:", why)
      ),
      class = c("creel_error_interview_unsampled_day", "creel_error_record_unworked_day", "creel_error"),
      call = call
    )
  }
  invisible(NULL)
}

#' Refuse interviews on a day or night the schedule did not work
#'
#' Internal (GH #630). Kept, refused and excluded interviews all pass through
#' here: a refused or excluded row never enters a rate, but it is counted in
#' the refusal and exclusion tables, and a row dated on an unworked day is a
#' data error there too. Night designs map rows before they are split, so
#' every row already carries its night date.
#'
#' @keywords internal
#' @noRd
check_interviews_worked <- function(records, design, date_col, what = "interview",
                                    call = rlang::caller_env()) {
  # Interview days drawn separately from count days (GH #628): the interview
  # register decides alone. It is a day register, so a night design's shift
  # labels are not compared with the count shifts either.
  if (!is.null(design$interview_sampled_col)) {
    return(check_interview_register(records, design, date_col, what, call = call))
  }
  if (!is.null(design$night)) {
    check_night_records_worked(records, design, date_col, what, call = call)
  } else {
    check_day_records_worked(records, design, date_col, what, call = call)
  }
}

#' Records timed outside every worked shift of their survey day
#'
#' Internal (GH #426). A calendar drawn with shift times (`shift_start`,
#' `shift_end`) says when each sampled day was worked. A record whose clock
#' time falls outside every worked shift of its day, by more than `slack`
#' minutes, was not taken in a drawn shift. The caller decides what that means:
#' a count is expanded by the probability of the shift it was taken in, so one
#' outside it is refused; an interview only has to share the stratum, so one
#' outside it is a coverage question, not an error.
#'
#' Records already carry their survey date (night designs map them first).
#' Times are read as `"HH:MM"` / `"HH:MM:SS"` or POSIXct (on its own clock).
#' A `count_time_col` may hold labels rather than clock times (`"AM"`,
#' `1`, `2`): if no time is a clock time, nothing is checked. A column that
#' mixes clock times with values that are not is refused, since skipping it
#' would hide every count it should catch.
#' A record with no time, or on a day with no worked shift window, is not
#' checked here; unworked days are refused elsewhere.
#'
#' @param times The records' time column, or `NULL`.
#' @param date_col The records' (survey) date column.
#' @param slack Minutes allowed either side of a shift.
#' @param what,time_arg For the message when the times are mixed.
#' @return `NULL` when the check does not apply, otherwise a list: `rows`, the
#'   indices of records outside every window (possibly empty), `key`, each
#'   record's day key, `label`, a `"key HH:MM"` label per record, and
#'   `windows`, the worked shifts of each day as `"HH:MM-HH:MM"` text, named
#'   by day key.
#' @keywords internal
#' @noRd
shift_window_outside <- function(records, times, design, date_col, what, time_arg,
                                 slack = 15L, call = rlang::caller_env()) {
  cal <- design$calendar
  if (is.null(times) || nrow(records) == 0L ||
        design$design_type %in% c("bus_route", "ice", "aerial") ||
        !all(c("shift_start", "shift_end") %in% names(cal)) ||
        !date_col %in% names(records)) {
    return(NULL)
  }
  clock <- clock_minutes(times)
  if (is.null(clock)) {
    return(NULL)
  }
  unread <- !is.na(times) & is.na(clock)
  if (any(unread)) {
    creel_abort(
      c(
        "{sum(unread)} {what} time{?s} in {.arg {time_arg}} cannot be read as a clock time.",
        "x" = "First: {.val {as.character(times[which(unread)[1]])}}.",
        "i" = "The other times are clock times, which are checked against the schedule's \\
               worked shifts. Give each as {.val HH:MM}, or {.val NA} when it is unknown."
      ),
      class = "creel_error_invalid_input",
      call = call
    )
  }
  worked <- calendar_worked_rows(cal, design$sampled_col)
  if (!is.null(worked)) cal <- cal[worked, , drop = FALSE]

  ds <- if (is.null(design$night)) 0L else design$night$day_start_min
  st <- clock_minutes(as.character(cal$shift_start), strict = FALSE)
  en <- clock_minutes(as.character(cal$shift_end), strict = FALSE)
  s_off <- survey_min(st, ds) # nolint: object_usage_linter
  e_off <- survey_min(en, ds, end = TRUE) # nolint: object_usage_linter
  # A window that leaves its survey day is refused where shift lengths are
  # read (add_counts); here it simply has no inside.
  ok <- !is.na(s_off) & !is.na(e_off) & e_off > s_off
  if (!any(ok)) {
    return(NULL)
  }

  sec <- design$section_col
  by_sec <- !is.null(sec) && sec %in% names(cal) && sec %in% names(records)
  day_key <- function(df, dcol) {
    k <- format(df[[dcol]])
    if (by_sec) paste(k, as.character(df[[sec]]), sep = " / ") else k
  }
  cal_key <- day_key(cal, design$date_col)[ok]
  rec_key <- day_key(records, date_col)
  windows <- tapply(
    paste0(format_min_to_hhmm(st[ok]), "-", format_min_to_hhmm(en[ok])), # nolint: object_usage_linter
    cal_key, function(w) paste(unique(w), collapse = ", ")
  )

  r_off <- survey_min(clock, ds) # nolint: object_usage_linter
  label <- paste(rec_key, format_min_to_hhmm(clock)) # nolint: object_usage_linter
  idx <- which(!is.na(r_off) & rec_key %in% cal_key)
  if (length(idx) == 0L) {
    return(list(rows = integer(0), key = rec_key, label = label, windows = windows))
  }
  pairs <- merge(
    data.frame(i = idx, key = rec_key[idx], t = r_off[idx]),
    data.frame(key = cal_key, s = s_off[ok] - slack, e = e_off[ok] + slack),
    by = "key"
  )
  inside <- tapply(pairs$t >= pairs$s & pairs$t <= pairs$e, pairs$i, any)
  list(
    rows = sort(as.integer(names(inside)[!inside])),
    key = rec_key,
    label = label,
    windows = windows
  )
}

#' Clock times as minutes since midnight
#'
#' Internal (GH #426). `"HH:MM"`, `"H:MM"`, `"HH:MM:SS"` or POSIXct (read on
#' its own clock). A value that is not a clock time becomes `NA`. With
#' `strict`, `NULL` when no non-missing value is a clock time (the column holds
#' labels) or the column is neither text nor date-time.
#'
#' @keywords internal
#' @noRd
clock_minutes <- function(x, strict = TRUE) {
  if (inherits(x, "POSIXt")) {
    lt <- as.POSIXlt(x)
    return(as.integer(lt$hour * 60L + lt$min))
  }
  if (!is.character(x) && !is.factor(x)) {
    return(if (strict) NULL else rep(NA_integer_, length(x)))
  }
  x <- as.character(x)
  good <- !is.na(x) & grepl("^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$", x)
  if (strict && !any(good)) {
    return(NULL)
  }
  out <- rep(NA_integer_, length(x))
  hm <- strsplit(x[good], ":", fixed = TRUE)
  out[good] <- vapply(hm, function(p) as.integer(p[1]) * 60L + as.integer(p[2]), integer(1))
  out
}

#' Refuse interviews on a day the interview register did not schedule
#'
#' Internal (GH #628). Records already carry their survey date (night designs
#' map them first).
#'
#' @keywords internal
#' @noRd
check_interview_register <- function(records, design, date_col, what, call = rlang::caller_env()) {
  cal <- design$calendar
  col <- design$interview_sampled_col
  # A calendar with a row per section and day may schedule interviews in one
  # section and not another, so the section is part of the day when both
  # tables carry it.
  sec <- design$section_col
  by_sec <- !is.null(sec) && sec %in% names(cal) && sec %in% names(records)
  key <- function(df, dcol) {
    k <- format(df[[dcol]])
    if (by_sec) paste(k, as.character(df[[sec]]), sep = " / ") else k
  }
  days <- key(cal, design$date_col)[cal[[col]] %in% TRUE]
  rec_day <- key(records, date_col)
  off <- !is.na(records[[date_col]]) & !rec_day %in% days
  if (any(off)) {
    bad <- sort(unique(rec_day[off]))
    shown <- utils::head(bad, 10L) # nolint: object_usage_linter
    more <- if (length(bad) > 10L) ", ..." else "" # nolint: object_usage_linter
    n_rec <- sum(off) # nolint: object_usage_linter
    n_day <- length(bad) # nolint: object_usage_linter
    # A refused or excluded row is never weighted; it is counted in its table.
    why <- if (identical(what, "interview")) { # nolint: object_usage_linter
      "An interview the design did not select cannot be weighted with the ones it did."
    } else {
      "Each is counted in the {what} table by its date, and the design did not select that date."
    }
    creel_abort(
      c(
        "{n_rec} {what}{cli::qty(n_rec)}{?s} {?is/are} dated on {n_day} {cli::qty(n_day)}day{?s} \\
         the calendar's {.field {col}} column does not mark as an interview day: \\
         {.val {shown}}{more}.",
        "x" = why,
        "i" = "Mark {cli::qty(n_day)}{?it/them} {.val {TRUE}} in {.field {col}}, or correct the \\
               {what} dates."
      ),
      class = c("creel_error_interview_register", "creel_error_record_unworked_day", "creel_error"),
      call = call
    )
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
    creel_abort(
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
    # A row whose shift_hours is given does not need its clock times resolved;
    # one whose shift_hours is NA does, as if the column were absent.
    if ("shift_hours" %in% names(cal)) amb <- amb & is.na(cal$shift_hours[ok])
    if (any(amb)) {
      bad <- unique(format(cal[[date_col]][ok][amb])) # nolint: object_usage_linter
      creel_abort(
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
