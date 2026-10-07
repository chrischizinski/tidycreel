#' Create a creel_schedule S3 object
#'
#' Constructor for the `creel_schedule` S3 class. Wraps a data frame with the
#' `creel_schedule` class attribute following the tibble-subclass pattern used
#' throughout the package.
#'
#' @param data A data frame to wrap as a `creel_schedule`.
#'
#' @return A data frame with class `c("creel_schedule", "data.frame")`.
#'
#' @examples
#' sched <- new_creel_schedule(data.frame(
#'   date      = as.Date(c("2024-06-01", "2024-06-08")),
#'   day_type  = c("weekend", "weekend"),
#'   sampled   = c(TRUE, TRUE)
#' ))
#' class(sched)
#'
#' @family "Scheduling"
#' @export
new_creel_schedule <- function(data) {
  stopifnot(is.data.frame(data))
  class(data) <- c("creel_schedule", "data.frame")
  data
}


#' Select sampled days using stratified random sampling
#'
#' Internal helper. Splits dates by day_type stratum, samples within each
#' stratum, and returns a logical vector indicating which dates were selected.
#'
#' @param all_dates A Date vector of all season dates.
#' @param day_types A character vector of day type labels (same length as
#'   `all_dates`).
#' @param n_days Named integer vector of days to sample per stratum, or scalar.
#'   Scalar is expanded uniformly across strata.
#' @param sampling_rate Named numeric vector of sampling fractions per stratum,
#'   or scalar. Scalar is expanded uniformly across strata.
#' @param valid_strata Optional character vector of allowed stratum labels for
#'   validating named `n_days` / `sampling_rate` inputs. Defaults to the actual
#'   observed strata in `day_types`.
#'
#' @return A logical vector of the same length as `all_dates` indicating
#'   sampled days.
#'
#' @noRd
select_sampled_days <- function(
  all_dates,
  day_types,
  n_days = NULL,
  sampling_rate = NULL,
  valid_strata = NULL
) {
  strata <- unique(day_types)
  if (is.null(valid_strata)) {
    valid_strata <- strata
  }

  # Expand scalar to named vector over strata
  if (!is.null(n_days) && is.null(names(n_days))) {
    n_days <- stats::setNames(rep(n_days, length(strata)), strata)
  }
  if (!is.null(sampling_rate) && is.null(names(sampling_rate))) {
    sampling_rate <- stats::setNames(rep(sampling_rate, length(strata)), strata)
  }

  # Validate that named vector keys match actual day types
  if (!is.null(n_days)) {
    bad <- setdiff(names(n_days), valid_strata)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Names in {.arg n_days} do not match day types in the season.",
        "x" = "Unmatched names: {.val {bad}}",
        "i" = "Season has day types: {.val {valid_strata}}"
      ))
    }
  }
  if (!is.null(sampling_rate)) {
    bad <- setdiff(names(sampling_rate), valid_strata)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Names in {.arg sampling_rate} do not match day types in the season.",
        "x" = "Unmatched names: {.val {bad}}",
        "i" = "Season has day types: {.val {valid_strata}}"
      ))
    }
  }

  sampled <- logical(length(all_dates))

  for (s in strata) {
    idx <- which(day_types == s)
    if (!is.null(n_days)) {
      n_s <- as.integer(n_days[[s]])
    } else {
      n_s <- round(length(idx) * sampling_rate[[s]])
    }
    n_s <- min(n_s, length(idx))
    if (n_s > 0) {
      sampled[sample(idx, n_s)] <- TRUE
    }
  }

  sampled
}

#' Expand a day-level data frame to one row per day x period
#'
#' Internal helper. Takes a data frame with at least `date` and `day_type`
#' columns and creates `n_periods` rows per date, adding a `period_id` column.
#'
#' @param base_df A data frame with `date` and `day_type` columns.
#' @param n_periods Integer number of periods per day.
#' @param period_labels Optional character vector of length `n_periods` for
#'   human-readable period names. If `NULL`, `period_id` is integer 1..n.
#' @param ordered_periods Logical. If `TRUE` and `period_labels` is supplied,
#'   `period_id` becomes an ordered factor preserving label order.
#'
#' @return A data frame with `n_periods` rows per input row and a `period_id`
#'   column.
#'
#' @noRd
expand_periods_impl <- function(base_df, n_periods, period_labels = NULL, ordered_periods = FALSE) {
  if (!is.null(period_labels) && length(period_labels) != n_periods) {
    cli::cli_abort(c(
      "Length of {.arg period_labels} must equal {.arg n_periods}.",
      "x" = "{.arg period_labels} has {length(period_labels)} elements;",
      " {.arg n_periods} is {n_periods}."
    ))
  }

  # Build period sequence
  if (is.null(period_labels)) {
    period_seq <- seq_len(n_periods)
  } else {
    period_seq <- period_labels
  }

  # Expand: one copy of base_df per period, then interleave rows by date
  expanded <- base_df[rep(seq_len(nrow(base_df)), each = n_periods), ]
  expanded$period_id <- rep(period_seq, times = nrow(base_df))
  rownames(expanded) <- NULL

  # Apply ordered factor if requested
  if (ordered_periods && !is.null(period_labels)) {
    expanded$period_id <- factor(
      expanded$period_id,
      levels = period_labels,
      ordered = TRUE
    )
  } else if (!is.null(period_labels)) {
    expanded$period_id <- as.character(expanded$period_id)
  } else {
    expanded$period_id <- as.integer(expanded$period_id)
  }

  expanded
}

#' Validate periods_per_day for generate_schedule()
#'
#' Internal (GH #385). `NULL` means every period is worked on every sampled
#' day (the behaviour before shifts were drawn).
#'
#' @return An integer in 1..n_periods.
#' @noRd
validate_periods_per_day <- function(periods_per_day, n_periods, expand_periods,
                                     call = rlang::caller_env()) {
  if (is.null(periods_per_day)) {
    return(as.integer(n_periods))
  }
  ok <- is.numeric(periods_per_day) && length(periods_per_day) == 1L &&
    !is.na(periods_per_day) && periods_per_day == round(periods_per_day) &&
    periods_per_day >= 1 && periods_per_day <= n_periods
  if (!ok) {
    cli::cli_abort(
      c(
        "{.arg periods_per_day} must be a whole number from 1 to {.arg n_periods} ({n_periods}).",
        "x" = "Got {.val {periods_per_day}}."
      ),
      call = call
    )
  }
  if (periods_per_day < n_periods && !expand_periods) {
    cli::cli_abort(
      c(
        "{.arg periods_per_day} below {.arg n_periods} needs {.code expand_periods = TRUE}.",
        "x" = "The drawn shifts are recorded as {.col period_id} rows, which {.code expand_periods = FALSE} drops.",
        "i" = "Without them the schedule cannot carry the selection probability the estimator needs."
      ),
      call = call
    )
  }
  as.integer(periods_per_day)
}

#' Draw which periods (shifts) are worked on each sampled day
#'
#' Internal (GH #385). The shift is a second-stage sample within the sampled
#' day. Every period has the same chance, `periods_per_day / n_periods`, of
#' being worked on any sampled day under both allocations, which is the
#' `p_period` the schedule records.
#'
#' - `"balanced"`: within each stratum, the days are put in random order and
#'   the periods dealt to them cyclically from a random permutation, so the
#'   number of days per period differs by at most one, and which periods get
#'   the extra day is random. The draws are then slightly dependent (negatively
#'   so), which the independent-draw variance treats conservatively.
#' - `"random"`: an independent draw of `periods_per_day` periods per day.
#'
#' @param strata Stratum label of each sampled day, in date order.
#' @return A list with one sorted integer vector of period indices per sampled
#'   day, in the order of `strata`.
#' @noRd
draw_period_assignment <- function(strata, n_periods, periods_per_day, allocation) {
  out <- vector("list", length(strata))
  if (identical(allocation, "random")) {
    for (i in seq_along(strata)) {
      out[[i]] <- sort(sample.int(n_periods, periods_per_day))
    }
    return(out)
  }
  for (s in unique(strata)) {
    idx <- which(strata == s)
    day_order <- idx[sample.int(length(idx))]
    perm <- sample.int(n_periods)
    for (j in seq_along(day_order)) {
      slots <- ((j - 1L) * periods_per_day + seq_len(periods_per_day) - 1L) %% n_periods + 1L
      out[[day_order[j]]] <- sort(perm[slots])
    }
  }
  out
}

#' Expand sampled days to their drawn periods
#'
#' Internal (GH #385). Each sampled day gets one row per drawn period, with
#' `p_period = periods_per_day / n_periods`. An unsampled day (present only
#' with `include_all = TRUE`) keeps a single row with `period_id` and
#' `p_period` `NA`: no shift was drawn for it.
#'
#' @noRd
expand_drawn_periods <- function(base, shifts, sampled, all_dates, n_periods, periods_per_day,
                                 period_labels, ordered_periods) {
  sampled_dates <- all_dates[sampled]
  pos <- match(base$date, sampled_dates)
  per_row <- lapply(pos, function(p) if (is.na(p)) NA_integer_ else shifts[[p]])
  rows <- rep(seq_len(nrow(base)), lengths(per_row))
  pid <- unlist(per_row, use.names = FALSE)
  expanded <- base[rows, , drop = FALSE]
  rownames(expanded) <- NULL

  if (is.null(period_labels)) {
    expanded$period_id <- as.integer(pid)
  } else {
    labelled <- period_labels[pid]
    expanded$period_id <- if (ordered_periods) {
      factor(labelled, levels = period_labels, ordered = TRUE)
    } else {
      as.character(labelled)
    }
  }
  expanded$p_period <- ifelse(is.na(pid), NA_real_, periods_per_day / n_periods)
  expanded
}

#' Validate the shift-times table for generate_schedule()
#'
#' Internal (GH #385). One row per period: `period_id` (matching
#' `period_labels`, or 1..n_periods without labels), `start_time` and
#' `end_time` as "HH:MM". Times are read on the survey-day clock that starts at
#' `day_start` (GH #407): with `day_start = "12:00"`, 19:30-00:30 and
#' 00:30-06:00 are the two halves of one night. A shift must end after it
#' starts on that clock, i.e. inside one survey day. An optional `hours`
#' column (as from daylight_shifts()) is the real elapsed length, which on a
#' daylight-saving night differs from the clock length by an hour; it is kept
#' as `shift_hours`.
#'
#' @return A data frame with `key` (character period id), `shift_start`,
#'   `shift_end`, and `shift_hours` when `hours` was given.
#' @noRd
validate_periods_table <- function(periods, n_periods, period_labels, ds = 0L, call = rlang::caller_env()) {
  needed <- c("period_id", "start_time", "end_time")
  if (!is.data.frame(periods) || !all(needed %in% names(periods))) {
    cli::cli_abort(
      c(
        "{.arg periods} must be a data frame with columns {.val {needed}}.",
        "x" = "Missing: {.val {setdiff(needed, names(periods))}}."
      ),
      call = call
    )
  }
  expected <- if (is.null(period_labels)) as.character(seq_len(n_periods)) else as.character(period_labels)
  key <- as.character(periods$period_id)
  # With a date column the shift times vary by day (daylight shifts, #368):
  # one row per date and period.
  by_date <- "date" %in% names(periods)
  if (by_date) {
    pdate <- tryCatch(as.Date(periods$date), error = function(e) rep(as.Date(NA), nrow(periods)))
    if (anyNA(pdate)) {
      cli::cli_abort("{.field date} in {.arg periods} must be dates with no missing values.", call = call)
    }
    if (!all(key %in% expected)) {
      cli::cli_abort(
        c(
          "{.arg periods} has periods the schedule does not.",
          "x" = "Expected {.val {expected}}; got {.val {unique(key[!key %in% expected])}}."
        ),
        call = call
      )
    }
    full_key <- paste(pdate, key)
    if (anyDuplicated(full_key)) {
      cli::cli_abort(
        "{.arg periods} must have one row per date and period; {.val {full_key[duplicated(full_key)]}} repeat{?s}.",
        call = call
      )
    }
  } else if (anyDuplicated(key) || !setequal(key, expected)) {
    cli::cli_abort(
      c(
        "{.arg periods} must have exactly one row per period.",
        "x" = "Expected {.val {expected}}; got {.val {key}}."
      ),
      call = call
    )
  }
  label <- if (by_date) paste(pdate, key) else key # nolint: object_usage_linter
  hhmm <- "^([01][0-9]|2[0-3]):[0-5][0-9]$"
  start <- as.character(periods$start_time)
  end <- as.character(periods$end_time)
  bad_fmt <- !grepl(hhmm, start) | !grepl(hhmm, end)
  if (any(bad_fmt)) {
    cli::cli_abort(
      c(
        "Shift times in {.arg periods} must be \"HH:MM\" (00:00 to 23:59).",
        "x" = "Period{?s} {.val {label[bad_fmt]}} {?has/have} an unreadable time."
      ),
      call = call
    )
  }
  start_min <- survey_min(vapply(start, parse_hhmm_to_min, integer(1)), ds)
  end_min <- survey_min(vapply(end, parse_hhmm_to_min, integer(1)), ds, end = TRUE)
  wraps <- end_min <= start_min
  if (any(wraps)) {
    cli::cli_abort(
      c(
        "Shift{?s} {.val {label[wraps]}} end{?s/} at or before {?its/their} start on the survey day.",
        "x" = "With {.code day_start = \"{format_min_to_hhmm(ds)}\"} a survey day runs from \\
               {format_min_to_hhmm(ds)} to {format_min_to_hhmm(ds)} the next day, and each shift \\
               must fall inside one.",
        "i" = "For night shifts that cross midnight, set {.arg day_start} to a time no shift \\
               spans, e.g. {.val 12:00}."
      ),
      call = call
    )
  }
  if (by_date) {
    key <- paste(pdate, key)
  }
  out <- data.frame(key = key, shift_start = start, shift_end = end, stringsAsFactors = FALSE)
  if ("hours" %in% names(periods)) {
    hrs <- suppressWarnings(as.numeric(periods$hours))
    clock <- (end_min - start_min) / 60
    # Elapsed time differs from the clock length only by a daylight-saving
    # change (one hour); anything else is a table that disagrees with itself.
    bad <- is.na(hrs) | hrs <= 0 | abs(hrs - clock) > 1 + 1e-8
    if (any(bad)) {
      cli::cli_abort(
        c(
          "{.field hours} in {.arg periods} must be the shift's length.",
          "x" = "Period{?s} {.val {label[bad]}} {?has/have} {.field hours} missing, not positive, \\
                 or more than an hour from the {.field start_time}-{.field end_time} length."
        ),
        call = call
      )
    }
    out$shift_hours <- hrs
  }
  attr(out, "by_date") <- by_date
  out
}

#' Attach each row's shift start and end times
#'
#' Internal (GH #385). Columns, not an attribute, so the times survive a
#' write_schedule() / read_schedule() round trip.
#'
#' @noRd
attach_shift_times <- function(base, periods, call = rlang::caller_env()) {
  by_date <- isTRUE(attr(periods, "by_date"))
  key <- if (by_date) paste(as.Date(base$date), base$period_id) else as.character(base$period_id)
  i <- match(key, periods$key)
  # A worked shift on a date the table does not cover has no times: refused,
  # not left blank, because its count windows and length check need them.
  worked <- !is.na(base$period_id)
  # An unsampled day of an include_all schedule can carry period ids (every
  # period expanded) without being worked; it needs no shift times.
  if ("sampled" %in% names(base)) worked <- worked & base$sampled %in% TRUE
  missing <- worked & is.na(i)
  if (any(missing)) {
    bad <- unique(as.character(base$date[missing])) # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "{.arg periods} has no shift times for {length(bad)} worked date{?s}: {.val {bad}}.",
        "i" = "A date-specific {.arg periods} table (e.g. from {.fn daylight_shifts}) must cover every \\
               worked date."
      ),
      call = call
    )
  }
  base$shift_start <- periods$shift_start[i]
  base$shift_end <- periods$shift_end[i]
  if ("shift_hours" %in% names(periods)) {
    base$shift_hours <- periods$shift_hours[i]
  }
  base
}

#' Resolve calendar-defined special periods to day-level stratum assignments
#'
#' @param all_dates Date vector for the full schedule season.
#' @param day_types Character vector of baseline day-type labels.
#' @param special_periods NULL or data frame with start_date, end_date, label,
#'   and optional reason columns.
#'
#' @return List with final_stratum, special_period_reason, and audit data.
#' @noRd
resolve_special_periods <- function(all_dates, day_types, special_periods = NULL) {
  if (is.null(special_periods)) {
    return(list(
      final_stratum = day_types,
      special_period_reason = rep(NA_character_, length(all_dates)),
      audit = NULL,
      allocation = NULL,
      baseline_allocation = NULL,
      diagnostics = NULL
    ))
  }

  if (!is.data.frame(special_periods)) {
    cli::cli_abort(c(
      "{.arg special_periods} must be a data frame or NULL.",
      "x" = "Received {.cls {class(special_periods)}}."
    ))
  }

  required_cols <- c("start_date", "end_date", "label")
  missing_cols <- setdiff(required_cols, names(special_periods))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "{.arg special_periods} is missing required columns.",
      "x" = "Missing: {.val {missing_cols}}"
    ))
  }

  if (!"reason" %in% names(special_periods)) {
    special_periods$reason <- NA_character_
  }

  starts <- as.Date(special_periods$start_date)
  ends <- as.Date(special_periods$end_date)
  if (any(is.na(starts)) || any(is.na(ends))) {
    cli::cli_abort(c(
      "{.arg special_periods} contains invalid dates.",
      "x" = "All {.col start_date} and {.col end_date} values must coerce to Date."
    ))
  }

  bad_range <- which(ends < starts)
  if (length(bad_range) > 0) {
    i <- bad_range[[1]] # nolint: object_usage_linter
    cli::cli_abort(c(
      "Special period end_date must be on or after start_date.",
      "x" = "Row {i}: {.val {starts[[i]]}} to {.val {ends[[i]]}} is invalid."
    ))
  }

  expanded_list <- vector("list", nrow(special_periods))
  for (i in seq_len(nrow(special_periods))) {
    expanded_dates <- seq(starts[[i]], ends[[i]], by = "1 day")
    expanded_list[[i]] <- data.frame(
      date = expanded_dates,
      label = as.character(special_periods$label[[i]]),
      reason = as.character(special_periods$reason[[i]]),
      source_start_date = starts[[i]],
      source_end_date = ends[[i]],
      stringsAsFactors = FALSE
    )
  }

  expanded <- do.call(rbind, expanded_list)
  expanded <- expanded[expanded$date %in% all_dates, , drop = FALSE]

  baseline_allocation <- as.data.frame(table(day_types), stringsAsFactors = FALSE)
  names(baseline_allocation) <- c("stratum", "baseline_days")

  if (nrow(expanded) == 0) {
    allocation <- baseline_allocation
    names(allocation) <- c("final_stratum", "available_days")
    return(list(
      final_stratum = day_types,
      special_period_reason = rep(NA_character_, length(all_dates)),
      audit = data.frame(),
      allocation = allocation,
      baseline_allocation = baseline_allocation,
      diagnostics = data.frame(
        severity = character(),
        issue = character(),
        stratum = character(),
        baseline_days = integer(),
        final_days = integer(),
        stringsAsFactors = FALSE
      )
    ))
  }

  dup_dates <- unique(expanded$date[duplicated(expanded$date)])
  if (length(dup_dates) > 0) {
    for (dup_date in dup_dates) {
      rows <- expanded[expanded$date == dup_date, , drop = FALSE]
      if (length(unique(rows$label)) > 1) {
        cli::cli_abort(c(
          "Special periods overlap on the same civil date.",
          "x" = "Date {.val {dup_date}} resolves to multiple labels: {.val {unique(rows$label)}}.",
          "i" = "Each civil date must resolve to exactly one final stratum label."
        ))
      }
    }
    expanded <- expanded[!duplicated(expanded$date), , drop = FALSE]
  }

  final_stratum <- day_types
  special_reason <- rep(NA_character_, length(all_dates))
  match_idx <- match(expanded$date, all_dates)
  final_stratum[match_idx] <- expanded$label
  special_reason[match_idx] <- expanded$reason

  audit <- data.frame(
    date = all_dates[match_idx],
    label = expanded$label,
    reason = expanded$reason,
    source_start_date = expanded$source_start_date,
    source_end_date = expanded$source_end_date,
    stringsAsFactors = FALSE
  )
  audit$crosses_boundary <- format(audit$source_start_date, "%Y-%m") !=
    format(audit$source_end_date, "%Y-%m")

  allocation <- as.data.frame(table(final_stratum), stringsAsFactors = FALSE)
  names(allocation) <- c("final_stratum", "available_days")

  diag_rows <- list()
  all_strata <- unique(c(
    as.character(baseline_allocation$stratum),
    as.character(allocation$final_stratum)
  ))
  for (stratum_name in all_strata) {
    baseline_days <- baseline_allocation$baseline_days[match(
      stratum_name,
      baseline_allocation$stratum
    )]
    final_days <- allocation$available_days[match(stratum_name, allocation$final_stratum)]
    baseline_days[is.na(baseline_days)] <- 0L
    final_days[is.na(final_days)] <- 0L

    if (baseline_days > 0L && final_days == 0L) {
      diag_rows[[length(diag_rows) + 1L]] <- data.frame(
        severity = "error",
        issue = "baseline stratum fully consumed by special-period assignments",
        stratum = stratum_name,
        baseline_days = as.integer(baseline_days),
        final_days = as.integer(final_days),
        stringsAsFactors = FALSE
      )
    } else if (final_days <= 1L) {
      diag_rows[[length(diag_rows) + 1L]] <- data.frame(
        severity = "warning",
        issue = "fragile stratum with only one available day after special-period assignment",
        stratum = stratum_name,
        baseline_days = as.integer(baseline_days),
        final_days = as.integer(final_days),
        stringsAsFactors = FALSE
      )
    }
  }

  diagnostics <- if (length(diag_rows) > 0L) {
    do.call(rbind, diag_rows)
  } else {
    data.frame(
      severity = character(),
      issue = character(),
      stratum = character(),
      baseline_days = integer(),
      final_days = integer(),
      stringsAsFactors = FALSE
    )
  }

  list(
    final_stratum = final_stratum,
    special_period_reason = special_reason,
    audit = audit,
    allocation = allocation,
    baseline_allocation = baseline_allocation,
    diagnostics = diagnostics
  )
}

#' Generate a creel survey sampling schedule
#'
#' Generates a stratified random sampling calendar for a creel survey season.
#' The season is divided into `weekday` and `weekend` strata, and days are
#' randomly selected within each stratum. Output is a `creel_schedule` tibble
#' ready to pass to [creel_design()].
#'
#' @param start_date Character or Date. First day of the survey season
#'   (ISO 8601 "YYYY-MM-DD").
#' @param end_date Character or Date. Last day of the survey season
#'   (ISO 8601 "YYYY-MM-DD").
#' @param n_periods Integer. Number of sampling periods per day.
#' @param n_days Named integer vector of days to sample per stratum (e.g.,
#'   `c(weekday = 20, weekend = 10)`), or a scalar applied uniformly to all
#'   strata. Mutually exclusive with `sampling_rate`.
#' @param sampling_rate Named numeric vector of sampling fractions per stratum
#'   (e.g., `c(weekday = 0.3, weekend = 0.6)`), or a scalar applied uniformly
#'   to all strata. Mutually exclusive with `n_days`.
#' @param period_labels Optional character vector of length `n_periods` with
#'   human-readable period names. When supplied, `period_id` is character (or
#'   ordered factor if `ordered_periods = TRUE`).
#' @param expand_periods Logical (default `TRUE`). If `TRUE`, output has one
#'   row per sampled day x period (nrow = sampled_days * n_periods). If
#'   `FALSE`, output has one row per sampled day and `period_id` is omitted.
#' @param include_all Logical (default `FALSE`). If `TRUE`, all season dates
#'   are returned with a `sampled` logical column. If `FALSE`, only sampled
#'   dates are returned.
#' @param ordered_periods Logical (default `FALSE`). If `TRUE` and
#'   `period_labels` is supplied, `period_id` is an ordered factor preserving
#'   label order.
#' @param period_intensity Not yet implemented. Must be `NULL`.
#' @param seed Integer seed for reproducible random day selection. Uses
#'   [withr::with_seed()] to avoid mutating global RNG state.
#' @param special_periods Optional data frame declaring calendar-defined special
#'   periods. Must contain `start_date`, `end_date`, and `label` columns, with
#'   optional `reason`. Periods are expanded to day-level assignments before
#'   sampling so boundary-crossing periods are split by civil date.
#' @param periods_per_day Integer. How many of the `n_periods` periods
#'   (shifts) are worked on each sampled day. `NULL` (default) means all of
#'   them, as before. With fewer, the worked periods are drawn at random for
#'   each sampled day and each row records its selection probability in
#'   `p_period` (`periods_per_day / n_periods`), e.g. one of two shifts gives
#'   `p_period = 0.5`. Needs `expand_periods = TRUE`.
#' @param period_allocation How the worked periods are drawn when
#'   `periods_per_day < n_periods`. `"balanced"` (default): within each
#'   stratum the periods are dealt to the sampled days in random order, so the
#'   number of days per period differs by at most one (e.g. 5 morning + 5
#'   evening over 10 weekdays). `"random"`: an independent draw for each day.
#'   Under both, every period has the same chance, `p_period`, of being worked
#'   on any sampled day. The variance estimators treat the draws as
#'   independent, which is conservative for `"balanced"`.
#' @param periods Optional data frame of shift times: `period_id` (one row per
#'   period, matching `period_labels`, or 1 to `n_periods`), `start_time` and
#'   `end_time` as `"HH:MM"`. Adds `shift_start` and `shift_end` to every row.
#'   With a `date` column the times vary by day -- one row per date and period,
#'   covering every worked date -- as returned by [daylight_shifts()] for
#'   shifts bounded by sunrise and sunset. Times are read on the survey-day
#'   clock that starts at `day_start`, and each shift must fall inside one
#'   survey day. An optional `hours` column (as [daylight_shifts()] returns)
#'   gives each shift's real elapsed length and is kept as `shift_hours`; it
#'   differs from the clock length only across a daylight-saving change.
#' @param day_start Clock time (`"HH:MM"`) at which a survey day begins.
#'   The default `"00:00"` is the calendar day, as before. For night creels
#'   whose shifts cross midnight, choose a time no shift spans, e.g. `"12:00"`:
#'   then 19:30-00:30 and 00:30-06:00 are the two halves of one night, dated
#'   by the date the night starts. A shift time earlier than `day_start` is on
#'   the next calendar day. The schedule records it in a `day_start` column.
#'   Used as the calendar of [creel_design()], it makes a night design, which
#'   maps counts and interviews to the night they belong to.
#' @param weekend_days Day names (full or three-letter English, any case) whose
#'   survey days form the `weekend` stratum. `NULL` (default) means Saturday
#'   and Sunday, and is only allowed when `day_start = "00:00"`: a night is
#'   dated by the day it starts, so with that default a Friday night would be
#'   a weekday, and agencies differ on which nights are the weekend (e.g.
#'   `c("Friday", "Saturday")`).
#'
#' @return A `creel_schedule` data frame with columns:
#'   - `date` (Date): Sampled (or all) dates.
#'   - `day_type` (character): Baseline "weekday" or "weekend" classification.
#'   - `final_stratum` (character): Present when `special_periods` is supplied;
#'     gives the final stratum used for day selection.
#'   - `special_period_reason` (character): Present when `special_periods` is
#'     supplied; gives the optional reason for the special-period assignment.
#'   - `period_id` (integer, character, or ordered factor): Period within day.
#'     Absent when `expand_periods = FALSE`.
#'   - `p_period` (numeric): Probability that the period was the one worked
#'     that day: `1` when every period is worked, `periods_per_day /
#'     n_periods` when they are drawn, `NA` on unsampled days. Absent when
#'     `expand_periods = FALSE`.
#'   - `shift_start`, `shift_end` (character, "HH:MM"): Present when `periods`
#'     is supplied.
#'   - `shift_hours` (numeric): Present when `periods` has an `hours` column.
#'   - `day_start` (character, "HH:MM"): Present when `day_start` is not
#'     `"00:00"`.
#'   - `sampled` (logical): Present only when `include_all = TRUE`.
#'
#' @examples
#' # Basic schedule with stratified sampling rates
#' sched <- generate_schedule(
#'   start_date = "2024-06-01",
#'   end_date = "2024-08-31",
#'   n_periods = 2,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed = 42
#' )
#'
#' # Use result with creel_design()
#' creel_design(sched, date = date, strata = day_type)
#'
#' # One of two shifts worked on each sampled day, drawn at random
#' shifts <- generate_schedule(
#'   start_date = "2024-06-01",
#'   end_date = "2024-08-31",
#'   n_periods = 2,
#'   period_labels = c("AM", "PM"),
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   periods_per_day = 1,
#'   periods = data.frame(
#'     period_id = c("AM", "PM"),
#'     start_time = c("06:00", "13:00"),
#'     end_time = c("13:00", "20:00")
#'   ),
#'   seed = 42
#' )
#' head(shifts)
#'
#' @family "Scheduling"
#' @export
generate_schedule <- function(
  start_date,
  end_date,
  n_periods,
  n_days = NULL,
  sampling_rate = NULL,
  period_labels = NULL,
  expand_periods = TRUE,
  include_all = FALSE,
  ordered_periods = FALSE,
  period_intensity = NULL,
  seed,
  special_periods = NULL,
  periods_per_day = NULL,
  period_allocation = c("balanced", "random"),
  periods = NULL,
  day_start = "00:00",
  weekend_days = NULL
) {
  rlang::check_installed("lubridate")
  ds <- parse_day_start(day_start)
  weekend_wday <- resolve_weekend_days(weekend_days, ds)
  # Validate mutually-exclusive intensity args
  if (!is.null(n_days) && !is.null(sampling_rate)) {
    cli::cli_abort(c(
      "Supply {.arg n_days} or {.arg sampling_rate}, not both.",
      "x" = "Both arguments were non-NULL."
    ))
  }

  # Validate at least one intensity arg supplied
  if (is.null(n_days) && is.null(sampling_rate)) {
    cli::cli_abort(c(
      "Supply either {.arg n_days} or {.arg sampling_rate}.",
      "x" = "Both arguments were NULL."
    ))
  }

  # period_intensity not yet implemented
  if (!is.null(period_intensity)) {
    cli::cli_abort(c(
      "{.arg period_intensity} is not yet implemented.",
      "i" = "Leave {.arg period_intensity} as NULL for now."
    ))
  }

  if (!is.numeric(n_periods) || length(n_periods) != 1L || is.na(n_periods) ||
        n_periods < 1 || n_periods != round(n_periods)) {
    cli::cli_abort(c(
      "{.arg n_periods} must be a whole number of at least 1.",
      "x" = "Got {.val {n_periods}}."
    ))
  }
  period_allocation <- rlang::arg_match(period_allocation)
  periods_per_day <- validate_periods_per_day(periods_per_day, n_periods, expand_periods)
  if (!is.null(periods)) {
    if (!expand_periods) {
      cli::cli_abort(c(
        "{.arg periods} needs {.code expand_periods = TRUE}.",
        "x" = "Shift times are attached per period, and {.code expand_periods = FALSE} drops periods."
      ))
    }
    periods <- validate_periods_table(periods, n_periods, period_labels, ds)
  }

  # Build season date sequence (lubridate DST-safe)
  all_dates <- seq(
    lubridate::ymd(start_date),
    lubridate::ymd(end_date),
    by = "1 day"
  )

  # Classify weekday vs weekend (week_start=1 => Mon=1 ... Sun=7). A night
  # survey day is dated by the date it starts, so its day type is that date's
  # unless weekend_days says otherwise (GH #407).
  day_types <- ifelse(
    lubridate::wday(all_dates, week_start = 1) %in% weekend_wday,
    "weekend",
    "weekday"
  )

  # Apply calendar-defined special-period assignments before sampling
  special_info <- resolve_special_periods(all_dates, day_types, special_periods)
  strata_for_sampling <- special_info$final_stratum

  requested_strata <- NULL
  if (!is.null(n_days) && !is.null(names(n_days))) {
    requested_strata <- names(n_days)
  }
  if (!is.null(sampling_rate) && !is.null(names(sampling_rate))) {
    requested_strata <- unique(c(requested_strata, names(sampling_rate)))
  }

  diagnostics <- special_info$diagnostics
  if (!is.null(special_periods) && nrow(diagnostics) > 0L) {
    baseline_labels <- unique(day_types)
    final_labels <- unique(strata_for_sampling)
    season_fully_rewritten <- !any(final_labels %in% baseline_labels)

    blocking <- diagnostics[
      diagnostics$severity == "error" &
        diagnostics$stratum %in% requested_strata &
        season_fully_rewritten,
      ,
      drop = FALSE
    ]
    if (nrow(blocking) > 0L) {
      b1 <- blocking[1, , drop = FALSE]
      cli::cli_abort(c(
        "Special-period declarations consumed a baseline stratum still requested for sampling.",
        "x" = paste0(
          "Stratum ",
          b1$stratum,
          " had ",
          b1$baseline_days,
          " baseline day(s) and ",
          b1$final_days,
          " remaining final day(s)."
        ),
        "i" = paste0(
          "Update {.arg n_days} or {.arg sampling_rate} to match",
          " the final strata after applying {.arg special_periods}."
        )
      ))
    }

    warnings <- diagnostics[
      diagnostics$severity == "warning" |
        (diagnostics$severity == "error" & diagnostics$stratum %in% requested_strata),
      ,
      drop = FALSE
    ]
    if (nrow(warnings) > 0L) {
      warn_labels <- paste0(
        # nolint: object_usage_linter.
        warnings$stratum,
        " (baseline=",
        warnings$baseline_days,
        ", final=",
        warnings$final_days,
        ")"
      )
      cli::cli_warn(c(
        "Special-period declarations produced a fragile schedule design.",
        "i" = "Affected strata: {.val {warn_labels}}",
        "i" = paste0(
          "Inspect the {.val special_period_diagnostics} attribute",
          " or print the schedule for details."
        )
      ))
    }
  }

  active_sampling_strata <- unique(strata_for_sampling)
  if (!is.null(n_days) && !is.null(names(n_days))) {
    n_days <- n_days[names(n_days) %in% active_sampling_strata]
  }
  if (!is.null(sampling_rate) && !is.null(names(sampling_rate))) {
    sampling_rate <- sampling_rate[names(sampling_rate) %in% active_sampling_strata]
  }

  # Stratified random sampling inside scoped RNG (no global mutation). The
  # shift draw (GH #385) runs AFTER the day selection inside the same seeded
  # block, so a given seed selects the same days as before shifts existed.
  draws <- withr::with_seed(
    seed,
    {
      sampled_days <- select_sampled_days(
        all_dates,
        strata_for_sampling,
        n_days,
        sampling_rate,
        valid_strata = active_sampling_strata
      )
      shift_draw <- if (periods_per_day < n_periods) {
        draw_period_assignment(
          strata_for_sampling[sampled_days], n_periods, periods_per_day, period_allocation
        )
      } else {
        NULL
      }
      list(sampled = sampled_days, shifts = shift_draw)
    }
  )
  sampled <- draws$sampled

  # Build base tibble with all season dates
  base <- tibble::tibble(
    date = all_dates,
    day_type = day_types,
    sampled = sampled
  )

  if (!is.null(special_periods)) {
    base$final_stratum <- special_info$final_stratum
    base$special_period_reason <- special_info$special_period_reason
  }

  if (!include_all) {
    base <- base[base$sampled, ]
  }

  # Expand periods (adds period_id column). With every period worked on every
  # sampled day, each was certain to be counted: p_period = 1. With a shift
  # draw, each sampled day carries only its drawn periods (GH #385).
  if (expand_periods) {
    if (is.null(draws$shifts)) {
      base <- expand_periods_impl(base, n_periods, period_labels, ordered_periods)
      # Unsampled days (include_all = TRUE) were not worked: no probability.
      base$p_period <- if ("sampled" %in% names(base)) ifelse(base$sampled, 1, NA_real_) else 1
    } else {
      base <- expand_drawn_periods(
        base, draws$shifts, sampled, all_dates, n_periods, periods_per_day,
        period_labels, ordered_periods
      )
    }
    if (!is.null(periods)) {
      base <- attach_shift_times(base, periods)
    }
  }

  # Drop sampled column if not requested
  if (!include_all) {
    base$sampled <- NULL
  }

  # A column, so it survives write_schedule() / read_schedule(); only when the
  # survey day does not start at midnight, so day schedules are unchanged.
  if (ds != 0L) {
    base$day_start <- day_start
  }

  result <- new_creel_schedule(base)

  if (!is.null(special_periods)) {
    audit <- special_info$audit
    if (nrow(audit) > 0) {
      audit$sampled <- sampled[match(audit$date, all_dates)]
    } else {
      audit$sampled <- logical(0)
    }
    attr(result, "special_period_audit") <- audit
    attr(result, "special_period_allocation") <- special_info$allocation
    attr(result, "special_period_baseline_allocation") <- special_info$baseline_allocation
    attr(result, "special_period_diagnostics") <- special_info$diagnostics
  }

  result
}

#' Which days of the week are weekend survey days
#'
#' Internal (GH #407). Returns ISO weekday numbers (Monday = 1 ... Sunday = 7).
#' The default, Saturday and Sunday, holds only when the survey day is the
#' calendar day. A night survey day is dated by the date it starts, so with the
#' default a Friday night would be a weekday; agencies differ (many count
#' Friday and Saturday nights as the weekend), so it must be given.
#'
#' @noRd
resolve_weekend_days <- function(weekend_days, ds, call = rlang::caller_env()) {
  full <- c("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
  if (is.null(weekend_days)) {
    if (ds != 0L) {
      cli::cli_abort(
        c(
          "{.arg weekend_days} is required when {.arg day_start} is not {.val 00:00}.",
          "x" = "A survey day is dated by the date it starts, so a Friday night is dated Friday, \\
                 and which nights count as the weekend differs between agencies.",
          "i" = "Name them, e.g. {.code weekend_days = c(\"Friday\", \"Saturday\")}."
        ),
        call = call
      )
    }
    return(c(6L, 7L))
  }
  if (!is.character(weekend_days) || anyNA(weekend_days)) {
    cli::cli_abort("{.arg weekend_days} must be day names, e.g. {.val Saturday}.", call = call)
  }
  key <- tolower(weekend_days)
  idx <- match(key, full)
  short <- is.na(idx) & nchar(key) == 3L
  idx[short] <- match(key[short], substr(full, 1L, 3L))
  if (anyNA(idx)) {
    cli::cli_abort(
      c(
        "{.arg weekend_days} must be English day names (full or three letters).",
        "x" = "Not recognised: {.val {weekend_days[is.na(idx)]}}."
      ),
      call = call
    )
  }
  sort(unique(idx))
}

#' Convert HH:MM string to integer minutes since midnight
#'
#' @param hhmm A character scalar matching "HH:MM".
#' @return Integer minutes since midnight.
#' @noRd
parse_hhmm_to_min <- function(hhmm) {
  parts <- strsplit(hhmm, ":", fixed = TRUE)[[1]]
  as.integer(parts[1]) * 60L + as.integer(parts[2])
}

#' Convert integer minutes since midnight to HH:MM string
#'
#' Minutes past 24 h (a time on the next calendar day) wrap to the clock.
#'
#' @param mins Integer vector of minutes since midnight.
#' @return Character vector of "HH:MM" strings.
#' @noRd
format_min_to_hhmm <- function(mins) {
  mins <- mins %% 1440L
  h <- mins %/% 60L
  m <- mins %% 60L
  sprintf("%02d:%02d", h, m)
}

#' Validate a survey-day start time and return it in minutes
#'
#' Internal (GH #407). `day_start` is the clock time a survey day begins:
#' `"00:00"` is the calendar day; `"12:00"` makes Fri 19:30 to Sat 06:00 one
#' survey day, dated Friday.
#'
#' @noRd
parse_day_start <- function(day_start, call = rlang::caller_env()) {
  hhmm <- "^([01][0-9]|2[0-3]):[0-5][0-9]$"
  if (!is.character(day_start) || length(day_start) != 1L || is.na(day_start) ||
        !grepl(hhmm, day_start)) {
    cli::cli_abort(
      c(
        "{.arg day_start} must be one clock time as {.val HH:MM}.",
        "x" = "Got {.val {day_start}}."
      ),
      call = call
    )
  }
  parse_hhmm_to_min(day_start)
}

#' Clock minutes to minutes since the survey day began
#'
#' Internal (GH #407). With `day_start` at `ds` minutes, a clock time `t` lies
#' `(t - ds) mod 1440` minutes into the survey day, so a time before
#' `day_start` is on the next calendar day. An END at the day's boundary is
#' the end of the survey day (1440), not its start; with `ds = 0` that makes
#' a shift ending `"00:00"` end at midnight. Times of day only: the length of
#' a night that crosses a daylight-saving change is not its clock length (see
#' `shift_hours`).
#'
#' @param clock_min Integer minutes since midnight (may be `NA`).
#' @param ds Survey-day start in minutes since midnight.
#' @param end Whether these are end times.
#' @noRd
survey_min <- function(clock_min, ds, end = FALSE) {
  off <- (clock_min - ds) %% 1440L
  if (end) off[!is.na(off) & off == 0L] <- 1440L
  off
}

#' The survey-day start a schedule was built with, in minutes
#'
#' Internal (GH #407). Read from the `day_start` column, which
#' generate_schedule() adds only when the day does not start at midnight, so a
#' schedule without it (every schedule before #407) starts at `"00:00"`.
#'
#' @noRd
schedule_day_start <- function(schedule, call = rlang::caller_env()) {
  if (!"day_start" %in% names(schedule)) {
    return(0L)
  }
  ds <- unique(as.character(schedule$day_start))
  if (length(ds) != 1L) {
    cli::cli_abort(
      c(
        "The schedule's {.field day_start} must be one clock time for every row.",
        "x" = "Got {.val {ds}}."
      ),
      call = call
    )
  }
  parse_day_start(ds, call = call)
}

#' Generate within-day count time windows
#'
#' Generates count time windows for a creel survey day using one of three
#' strategies: random (stratified random placement within equal-width strata),
#' systematic (random start in first stratum with fixed spacing thereafter,
#' preferred per Pollock et al. 1994 and Colorado CPW 2012), or fixed
#' (user-supplied non-overlapping windows).
#'
#' Output is a `creel_schedule` data frame compatible with [write_schedule()].
#'
#' @param start_time Character. Survey-day start time in `"HH:MM"` format.
#'   Required for `strategy = "random"` and `"systematic"`.
#' @param end_time Character. Survey-day end time in `"HH:MM"` format.
#'   Required for `strategy = "random"` and `"systematic"`. Must be after
#'   `start_time`; for a night that crosses midnight, use
#'   [attach_count_times()] on a schedule built with
#'   `generate_schedule(day_start = )`.
#' @param strategy Character scalar. One of `"random"`, `"systematic"`, or
#'   `"fixed"`.
#' @param n_windows Positive integer. Number of count time windows. Required
#'   for `strategy = "random"` and `"systematic"`. The total span
#'   (`end_time - start_time` in minutes) must be evenly divisible by
#'   `n_windows`.
#' @param window_size Positive integer. Duration of each count window in
#'   minutes. Required for `strategy = "random"` and `"systematic"`.
#' @param min_gap Non-negative integer, minutes. Required for
#'   `strategy = "random"` and `"systematic"`. `window_size + min_gap` must
#'   not exceed the stratum width (`total_span / n_windows`). With
#'   `"systematic"` every gap is then at least `min_gap`. With `"random"` it is
#'   only this fit check: each count's start is drawn uniformly over its whole
#'   stratum, without holding back room for the gap (which would leave parts
#'   of the span no count could reach), so neighbouring counts can be closer
#'   than `min_gap` (but never so close that their slots overlap). Use
#'   `"systematic"` when spacing must be guaranteed.
#' @param fixed_windows A data frame with `start_time` and `end_time` columns
#'   (character `"HH:MM"`). Required for `strategy = "fixed"`. Windows must be
#'   non-overlapping.
#' @param seed Integer seed for reproducible window placement. Passed to
#'   [withr::with_seed()]. Applies to `"random"` and `"systematic"` strategies.
#'   Has no effect for `"fixed"` strategy.
#'
#' @return A `creel_schedule` data frame with columns:
#'   - `start_time` (character `"HH:MM"`): Window start time.
#'   - `end_time`   (character `"HH:MM"`): Window end time.
#'   - `window_id`  (integer, 1-based, ordered by start time): Window index.
#'
#' @details
#' The start of each window is the count instant: crews count at the start of
#' the slot, and `window_size` is how long the count keeps them busy. Starts are
#' drawn over the whole of each stratum, so every minute of the span is
#' close to equally likely to be counted. One crew cannot run two counts at
#' once, so a random draw whose slots overlap is redrawn (delaying the second
#' count instead would move its instant and bias effort); this makes instants
#' just after a stratum boundary slightly less likely than elsewhere.
#' Systematic starts never overlap. A start late in the last stratum makes the
#' last slot end after the span, which is fine: the count instant is inside
#' it. Before #432 starts were drawn only where the whole slot fitted, so the
#' last `window_size` minutes of each stratum were never counted.
#'
#' **Random strategy:** Each of the `n_windows` strata of equal length
#' `k = total_span / n_windows` receives one window with a uniformly random
#' start within `[stratum_start, stratum_start + k)`.
#'
#' **Systematic strategy (recommended):** A single random start `t1` is drawn
#' from `[start_min, start_min + k)`; all subsequent windows begin at
#' `t1 + (i-1) * k` for `i = 1, ..., n_windows`. This is the design described
#' in Pollock et al. (1994) and recommended by Colorado CPW (2012).
#'
#' **Fixed strategy:** Windows are taken exactly as supplied after sorting by
#' start time. Overlapping windows trigger an error.
#'
#' @examples
#' # Random strategy
#' generate_count_times(
#'   start_time = "06:00", end_time = "14:00",
#'   strategy = "random", n_windows = 4, window_size = 30, min_gap = 10,
#'   seed = 42
#' )
#'
#' # Systematic strategy (preferred; Pollock et al. 1994)
#' generate_count_times(
#'   start_time = "06:00", end_time = "14:00",
#'   strategy = "systematic", n_windows = 4, window_size = 30, min_gap = 10,
#'   seed = 42
#' )
#'
#' # Fixed strategy
#' fw <- data.frame(
#'   start_time = c("07:00", "09:00", "11:00"),
#'   end_time = c("07:30", "09:30", "11:30"),
#'   stringsAsFactors = FALSE
#' )
#' generate_count_times(strategy = "fixed", fixed_windows = fw)
#'
#' @family "Scheduling"
#' @export
generate_count_times <- function(
  start_time = NULL,
  end_time = NULL,
  strategy,
  n_windows = NULL,
  window_size = NULL,
  min_gap = NULL,
  fixed_windows = NULL,
  seed = NULL
) {
  # Validate strategy
  valid_strategies <- c("random", "systematic", "fixed")
  if (missing(strategy)) {
    cli::cli_abort(c(
      "Unknown strategy.",
      "x" = "{.arg strategy} is required.",
      "i" = "Must be one of: {.val {valid_strategies}}"
    ))
  }
  if (!strategy %in% valid_strategies) {
    cli::cli_abort(c(
      "Unknown strategy.",
      "x" = "{.val {strategy}} is not a valid strategy.",
      "i" = "Must be one of: {.val {valid_strategies}}"
    ))
  }

  # Fixed strategy path
  if (strategy == "fixed") {
    if (is.null(fixed_windows) || !is.data.frame(fixed_windows)) {
      cli::cli_abort(c(
        "{.arg fixed_windows} must be a data frame when {.arg strategy} is {.val fixed}.",
        "x" = "{.arg fixed_windows} is {.cls {class(fixed_windows)}}."
      ))
    }
    missing_cols <- setdiff(c("start_time", "end_time"), names(fixed_windows))
    if (length(missing_cols) > 0) {
      cli::cli_abort(c(
        "{.arg fixed_windows} is missing required columns.",
        "x" = "Missing: {.val {missing_cols}}"
      ))
    }

    fw_starts <- vapply(fixed_windows$start_time, parse_hhmm_to_min, integer(1))
    fw_ends <- vapply(fixed_windows$end_time, parse_hhmm_to_min, integer(1))

    # Sort by start time
    ord <- order(fw_starts)
    fw_starts <- fw_starts[ord]
    fw_ends <- fw_ends[ord]
    fw_sorted <- fixed_windows[ord, , drop = FALSE]

    # Check non-overlapping
    if (length(fw_ends) > 1) {
      overlap_idx <- which(fw_ends[-length(fw_ends)] > fw_starts[-1])
      if (length(overlap_idx) > 0) {
        i1 <- overlap_idx[1] # nolint: object_usage_linter
        cli::cli_abort(c(
          "Windows in {.arg fixed_windows} must not overlap.",
          "x" = "Overlap between window {i1} and window {i1 + 1L}.",
          "i" = "Window {i1}: {fw_sorted$start_time[i1]}--{fw_sorted$end_time[i1]}",
          "i" = "Window {i1 + 1L}: {fw_sorted$start_time[i1 + 1L]}--{fw_sorted$end_time[i1 + 1L]}"
        ))
      }
    }

    result <- data.frame(
      start_time = fw_sorted$start_time,
      end_time = fw_sorted$end_time,
      window_id = seq_len(nrow(fw_sorted)),
      stringsAsFactors = FALSE
    )
    return(new_creel_schedule(result))
  }

  # Random / systematic -- validate time inputs
  hhmm_re <- "^[0-2][0-9]:[0-5][0-9]$"
  if (!grepl(hhmm_re, start_time) || !grepl(hhmm_re, end_time)) {
    cli::cli_abort(c(
      "start_time and end_time must be in HH:MM format.",
      "x" = "Received start_time={.val {start_time}}, end_time={.val {end_time}}."
    ))
  }

  start_min <- parse_hhmm_to_min(start_time)
  end_min <- parse_hhmm_to_min(end_time)

  # A night span is drawn through attach_count_times() on a schedule built
  # with day_start (GH #407), where the crossing is declared; here an end at
  # or before the start stays an error, so swapped times are caught.
  if (end_min <= start_min) {
    cli::cli_abort(c(
      "end_time must be after start_time.",
      "x" = "{.val {end_time}} is not after {.val {start_time}}.",
      "i" = "For a night that crosses midnight, use {.fn attach_count_times} on a schedule \\
             from {.code generate_schedule(day_start = )}."
    ))
  }

  # Validate required args
  for (arg_name in c("n_windows", "window_size", "min_gap")) {
    val <- get(arg_name)
    if (is.null(val)) {
      cli::cli_abort(
        c("{.arg {arg_name}} is required for strategy {.val {strategy}}."),
        call = rlang::caller_env()
      )
    }
  }

  n_windows <- as.integer(n_windows)
  window_size <- as.integer(window_size)
  min_gap <- as.integer(min_gap)

  check_window_spacing(start_min, end_min, n_windows, window_size, min_gap)
  t_starts <- with_optional_seed(seed, {
    draw_day_starts(start_min, end_min, strategy, n_windows, window_size, min_gap)[[1]]
  })
  check_slots_before_midnight(list(t_starts), "1", window_size)

  result <- data.frame(
    start_time = format_min_to_hhmm(t_starts),
    end_time = format_min_to_hhmm(t_starts + window_size),
    window_id = seq_len(n_windows),
    stringsAsFactors = FALSE
  )
  new_creel_schedule(result)
}

#' Check that n_windows count windows fit a span
#'
#' The span is split into `n_windows` equal strata of `k` minutes, and each
#' must hold a window plus the gap to the next.
#'
#' @return `k`, the stratum length in minutes, invisibly.
#' @noRd
check_window_spacing <- function(start_min, end_min, n_windows, window_size, min_gap,
                                 where = NULL, require_even = TRUE, call = rlang::caller_env()) {
  bad_arg <- function(x, min) length(x) != 1L || is.na(x) || x < min
  if (bad_arg(n_windows, 1L) || bad_arg(window_size, 1L) || bad_arg(min_gap, 0L)) {
    cli::cli_abort(c(
      "Count windows need {.arg n_windows} >= 1, {.arg window_size} >= 1 and {.arg min_gap} >= 0.",
      "x" = "Got n_windows = {n_windows}, window_size = {window_size}, min_gap = {min_gap}."
    ), call = call)
  }
  total_min <- end_min - start_min
  # generate_count_times() keeps its documented whole-minute strata; per-day
  # draws inside a shift do not, because a shift bounded by sunrise or sunset
  # has an arbitrary length (#368): its strata then differ by at most a minute.
  if (require_even && total_min %% n_windows != 0L) {
    cli::cli_abort(c(
      "Span must divide evenly by n_windows{where}.",
      "x" = "{total_min} min / {n_windows} = {total_min / n_windows} -- must be a whole number.",
      "i" = "Adjust n_windows or start/end time so the span divides evenly."
    ), call = call)
  }
  k <- (end_min - start_min) / n_windows
  # The gap separates windows; a single window needs only to fit.
  gap <- if (n_windows > 1L) min_gap else 0L
  if (window_size + gap > k) {
    cli::cli_abort(c(
      "window_size + min_gap exceeds stratum length{where}.",
      "x" = "Stratum is {round(k, 1)} min, but window_size + min_gap = {window_size + min_gap} min.",
      "i" = "Reduce n_windows, window_size, or min_gap."
    ), call = call)
  }
  invisible(k)
}

#' Evaluate code under a seed, or the session RNG when there is none
#'
#' `withr::with_seed(NULL, ...)` warns that `.Random.seed` is NULL.
#'
#' @noRd
with_optional_seed <- function(seed, code) {
  if (is.null(seed)) code else withr::with_seed(seed, code)
}

#' Draw count-window start times within a span
#'
#' Uses the current RNG state; callers seed it. Assumes
#' check_window_spacing() has passed.
#'
#' The window start is the count instant (crews count at the start of the
#' slot; #432), so it is drawn over the WHOLE stratum, as in Pollock et al.
#' ch. 11: every minute of the span is equally likely to be a count instant.
#' The slot (`window_size`) is only the time the crew is busy, so it may run
#' into the next stratum or past the span end; draw_day_starts() redraws a day
#' whose slots overlap. Drawing only where the whole slot fits left the last `window_size`
#' minutes of every stratum with no chance of being counted.
#'
#' Random: one start uniform in each equal stratum. Neighbouring counts can be
#' closer than `min_gap` (Pollock et al.'s noted drawback of random times);
#' holding back room for the gap pinned counts in place and left hours no
#' count could reach (#385 review), so it is not done. Systematic: one start
#' uniform in the first stratum, then every `k` minutes; the gap between slots
#' is `k - window_size >= min_gap`.
#'
#' @return Integer start times, minutes since midnight.
#' @noRd
draw_window_starts <- function(start_min, end_min, strategy, n_windows, window_size, min_gap) {
  # Continuous instants over strata of equal real length; the caller floors
  # them to the minute. Every minute of the span then has exactly the same
  # chance of being a count instant even when the span does not divide evenly
  # by n_windows (a daylight shift, #368): whole-minute strata of 210 and 211
  # minutes gave the minutes of the shorter one more weight, which the
  # unweighted daily mean in add_counts() does not undo.
  width <- (end_min - start_min) / n_windows
  lower <- start_min + (seq_len(n_windows) - 1L) * width
  if (strategy == "random") {
    lower + stats::runif(n_windows) * width
  } else {
    lower + stats::runif(1L) * width
  }
}

#' Draw one day's count starts, redrawing until one crew can make them all
#'
#' A start drawn late in a stratum makes its slot run into the next count
#' (#432), and one crew cannot count twice at once. Delaying the second count
#' would move its instant to `max(drawn, previous end)`, which is no longer
#' uniform and biases effort (#432 review), so the whole day is redrawn
#' instead (user decision 2026-10-05). The price: instants just after a
#' stratum boundary are slightly less likely than elsewhere. Systematic
#' starts never overlap within a span (spacing `k >= window_size`), so only
#' adjacent shifts on one day can trigger a redraw.
#'
#' @param span_start,span_end Integer vectors, one element per shift worked
#'   that day.
#' @return A list of integer start vectors, one per shift.
#' @noRd
draw_day_starts <- function(span_start, span_end, strategy, n_windows, window_size, min_gap,
                            call = rlang::caller_env()) {
  # Instants are continuous until they are floored to the clock minute the
  # crew works to; overlap is judged on those minutes. Judging it on the
  # continuous values rejected draws whose minute slots did not overlap
  # (06:01.9 and 06:02.1 with 1-minute slots), which skewed minute chances
  # (#368 review).
  to_minutes <- function(st) lapply(st, function(x) as.integer(floor(x)))
  feasible <- function(st) {
    all_st <- sort(unlist(to_minutes(st)))
    length(all_st) < 2L || all(all_st[-1] >= all_st[-length(all_st)] + window_size)
  }
  for (attempt in seq_len(1000L)) {
    st <- lapply(seq_along(span_start), function(j) {
      draw_window_starts(span_start[j], span_end[j], strategy, n_windows, window_size, min_gap)
    })
    if (feasible(st)) {
      return(to_minutes(st))
    }
  }
  # Dense days (slots nearly filling their strata) are rarely feasible by
  # chance: 10 one-hour slots in 10 h succeed about once in 2 million draws.
  # The feasible random draws form a convex set (each start inside its own
  # stratum, each at least window_size after the previous), so a Gibbs
  # sampler over it targets the same distribution as rejection -- uniform over
  # the feasible draws -- without waiting for luck (#432 review).
  if (strategy == "random") {
    st <- gibbs_day_starts(span_start, span_end, n_windows, window_size)
    if (!is.null(st)) {
      return(to_minutes(st))
    }
  }
  cli::cli_abort(c(
    "Could not draw count times that one crew can make without overlapping slots.",
    "x" = "No feasible draw found: two counts always fell within {window_size} minutes of each other.",
    "i" = "Check that the day's shifts do not overlap, shorten {.arg window_size}, or use fewer windows."
  ), call = call)
}

#' Gibbs sampler over a day's feasible random count starts
#'
#' Each continuous start lies in its own stratum `[a_j, a_j + width)`, and
#' its floored minute must be at least `window_size` after the previous one. Starting from the
#' stratum starts (feasible when every stratum holds a slot and the shifts do
#' not overlap), each sweep redraws every start uniformly between its
#' neighbours' limits.
#'
#' @return A list of numeric (continuous) start vectors, one per shift, or
#'   `NULL` when the stratum starts are themselves infeasible.
#' @noRd
gibbs_day_starts <- function(span_start, span_end, n_windows, window_size, sweeps = 200L) {
  shift <- rep(seq_along(span_start), each = n_windows)
  width <- rep((span_end - span_start) / n_windows, each = n_windows)
  lo <- unlist(lapply(seq_along(span_start), function(j) {
    span_start[j] + (seq_len(n_windows) - 1L) * (span_end[j] - span_start[j]) / n_windows
  }))
  hi <- lo + width
  ord <- order(lo)
  lo <- lo[ord]
  hi <- hi[ord]
  s <- lo
  m <- length(s)
  if (m > 1L && any(s[-1] < s[-m] + window_size)) {
    return(NULL)
  }
  for (sweep in seq_len(sweeps)) {
    for (j in seq_len(m)) {
      # Feasibility is on floored minutes: floor(s_j) >= floor(s_j-1) + w and
      # floor(s_j+1) >= floor(s_j) + w, i.e. s_j in
      # [floor(s_j-1) + w, floor(s_j+1) - w + 1).
      a <- if (j > 1L) max(lo[j], floor(s[j - 1L]) + window_size) else lo[j]
      b <- if (j < m) min(hi[j], floor(s[j + 1L]) - window_size + 1) else hi[j]
      s[j] <- stats::runif(1L, a, b)
    }
  }
  s[ord] <- s
  lapply(seq_along(span_start), function(j) sort(s[shift == j]))
}

#' Refuse count slots that would run past the end of the survey day
#'
#' Starts are minutes since the survey day began (GH #407), so the day ends at
#' `limit` (1440); with `day_start = "00:00"` that is midnight. A slot running
#' into the next survey day would be a count of that day.
#'
#' @param starts List of integer start vectors (one per worked shift).
#' @param day The date of each element of `starts`, for counting days.
#' @noRd
check_slots_before_midnight <- function(starts, day, window_size, limit = 1440L, call = rlang::caller_env()) {
  past <- vapply(starts, function(st) any(st + window_size > limit), logical(1))
  if (any(past)) {
    n_days <- length(unique(day[past])) # nolint: object_usage_linter
    cli::cli_abort(c(
      "A count slot would run past the end of the survey day on {n_days} day{?s}.",
      "x" = "A slot running into the next survey day would count that day.",
      "i" = "Shorten {.arg window_size}, or end the counting span earlier."
    ), call = call)
  }
  invisible(NULL)
}

#' Schedule progressive count circuit start times
#'
#' Generates randomised start times for progressive count surveys following
#' Hoenig et al. (1993). Two scheduling strategies are supported:
#'
#' - `"discrete"` (recommended): The survey period T must be an integer multiple
#'   of the circuit time \eqn{\tau}. A start time is drawn uniformly from
#'   \eqn{\{0, \tau, 2\tau, \ldots, (k-1)\tau\}} where \eqn{k = T/\tau}. The
#'   starting *location* and *direction* of travel must both be randomised;
#'   direction is returned in the output and must be recorded in the field protocol.
#'
#' - `"wraparound"`: A start time is drawn from \eqn{U[0, T)}. If the circuit
#'   would extend past the end of the survey period it wraps to the beginning
#'   of the day (`is_wrapped = TRUE`). Starting location need not be randomised,
#'   though direction still must be.
#'
#' @section Common scheduling error:
#' Drawing the start time from \eqn{U[0, T - \tau]} is **biased** -- it makes
#' the middle of the survey day over-represented, introducing bias toward
#' mid-day effort patterns. Both strategies here avoid this error.
#'
#' @param open_start Character. Survey-day opening time in `"HH:MM"` format.
#' @param open_end   Character. Survey-day closing time in `"HH:MM"` format.
#'   Must be later than `open_start`.
#' @param circuit_time Positive numeric. Duration of one circuit traversal
#'   \eqn{\tau} in hours. Must be shorter than the survey period T.
#' @param strategy Character scalar. `"discrete"` (default) or `"wraparound"`.
#'   For `"discrete"`, T / `circuit_time` must be a whole number
#'   (within 0.001 h tolerance).
#' @param n Positive integer. Number of survey days to schedule. Returns one
#'   row per day.
#' @param seed Optional integer. Passed to [withr::with_seed()] for
#'   reproducible scheduling. Has no effect when `NULL`.
#'
#' @return A `creel_schedule` data frame with columns:
#'   - `circuit_start` (character `"HH:MM"`): Scheduled circuit start time.
#'   - `circuit_end`   (character `"HH:MM"`): Scheduled circuit end time.
#'     For `"wraparound"` this may be earlier than `circuit_start` when the
#'     circuit crosses the end of the survey period.
#'   - `is_wrapped`    (logical): `TRUE` when circuit wraps around the
#'     end of the survey period. Always `FALSE` for `"discrete"`.
#'   - `direction`     (character): `"forward"` or `"reverse"`. Must be
#'     implemented in the field protocol for unbiased estimation.
#'
#' @references Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H.
#'   (1993). Scheduling counts in the instantaneous and progressive count
#'   methods for estimating sportfishing effort.
#'   *North American Journal of Fisheries Management*, **13**, 723--736.
#'
#' @examples
#' # Discrete strategy: T = 10 h, tau = 2 h -> k = 5 valid start times
#' generate_progressive_start(
#'   open_start = "06:00", open_end = "16:00",
#'   circuit_time = 2, strategy = "discrete", n = 5, seed = 42
#' )
#'
#' # Wraparound strategy: start drawn from U[0, T)
#' generate_progressive_start(
#'   open_start = "06:00", open_end = "16:00",
#'   circuit_time = 2, strategy = "wraparound", n = 5, seed = 42
#' )
#'
#' @family "Scheduling"
#' @export
generate_progressive_start <- function(
  open_start,
  open_end,
  circuit_time,
  strategy = c("discrete", "wraparound"),
  n = 1L,
  seed = NULL
) {
  strategy <- match.arg(strategy)

  hhmm_re <- "^[0-2][0-9]:[0-5][0-9]$"
  if (!grepl(hhmm_re, open_start) || !grepl(hhmm_re, open_end)) {
    cli::cli_abort(c(
      "{.arg open_start} and {.arg open_end} must be in HH:MM format.",
      "x" = "Received open_start={.val {open_start}}, open_end={.val {open_end}}."
    ))
  }

  start_min <- parse_hhmm_to_min(open_start)
  end_min   <- parse_hhmm_to_min(open_end)
  T_min     <- end_min - start_min

  if (T_min <= 0) {
    cli::cli_abort(c(
      "{.arg open_end} must be later than {.arg open_start}.",
      "x" = "open_start={.val {open_start}}, open_end={.val {open_end}}."
    ))
  }

  if (!is.numeric(circuit_time) || length(circuit_time) != 1L || circuit_time <= 0) {
    cli::cli_abort(c(
      "{.arg circuit_time} must be a single positive number (hours).",
      "x" = "Got {.val {circuit_time}}."
    ))
  }
  tau_min <- circuit_time * 60

  if (tau_min >= T_min) {
    cli::cli_abort(c(
      "{.arg circuit_time} must be shorter than the survey period.",
      "x" = "circuit_time = {circuit_time} h; T = {T_min / 60} h.",
      "i" = "The circuit must complete within (or wrap within) the survey day."
    ))
  }

  if (!is.numeric(n) || length(n) != 1L || n < 1L || n != round(n)) {
    cli::cli_abort("{.arg n} must be a single positive integer.")
  }
  n <- as.integer(n)

  do_draw <- function() {
    if (strategy == "discrete") {
      k_raw <- T_min / tau_min
      if (abs(k_raw - round(k_raw)) > 0.001) {
        cli::cli_abort(c(
          "For {.val discrete} strategy, T must be an integer multiple of {.arg circuit_time}.",
          "x" = "T = {T_min / 60} h, circuit_time = {circuit_time} h, T/tau = {round(k_raw, 3)}.",
          "i" = "Adjust {.arg open_start}/{.arg open_end}/{.arg circuit_time} so T/tau is a whole number.",
          "i" = "Or use {.code strategy = 'wraparound'} which has no divisibility requirement."
        ))
      }
      k <- round(k_raw)
      offsets <- (sample.int(k, n, replace = TRUE) - 1L) * tau_min
    } else {
      offsets <- runif(n, min = 0, max = T_min)
    }
    dirs <- sample(c("forward", "reverse"), n, replace = TRUE)
    list(offsets = offsets, dirs = dirs)
  }

  drawn <- if (!is.null(seed)) withr::with_seed(seed, do_draw()) else do_draw()

  abs_start <- start_min + drawn$offsets
  abs_end   <- abs_start + tau_min
  is_wrapped <- abs_end > end_min
  # Wrapped end: wraps back to open_start + overflow past open_end
  abs_end_adj <- ifelse(is_wrapped, start_min + (abs_end - end_min), abs_end)

  result <- data.frame(
    circuit_start = format_min_to_hhmm(as.integer(round(abs_start))),
    circuit_end   = format_min_to_hhmm(as.integer(round(abs_end_adj))),
    is_wrapped    = is_wrapped,
    direction     = drawn$dirs,
    stringsAsFactors = FALSE
  )
  new_creel_schedule(result)
}

#' Generate a bus-route sampling frame
#'
#' @description
#' Converts a creel schedule calendar and circuit definitions into a
#' sampling frame tibble with `inclusion_prob` and `p_period` columns
#' ready for `creel_design(survey_type = "bus_route")`.
#'
#' Inclusion probability formula: `inclusion_prob = p_site * p_period`
#' where `p_period = crew / n_circuits`.
#'
#' `n_circuits` is the number of distinct circuit values in `sampling_frame`
#' (or 1 when `circuit` is `NULL`). `crew` is the number of field crews
#' deployed simultaneously.
#'
#' @param schedule A `creel_schedule` tibble from [generate_schedule()].
#'   Currently unused in computation but required to ensure the caller
#'   has built a valid schedule before constructing the sampling frame.
#' @param sampling_frame A data frame with site and p_site columns (and
#'   optionally circuit).
#' @param site Column in `sampling_frame` giving site identifiers
#'   (tidy selector: bare name, quoted string, or tidyselect helper).
#' @param p_site Column in `sampling_frame` giving per-site selection
#'   probability within the circuit. Values must sum to 1.0 per circuit
#'   (tolerance 1e-6).
#' @param circuit Optional column giving circuit assignment. If `NULL`,
#'   all sites are treated as a single circuit.
#' @param crew Integer scalar: number of crews in the field simultaneously.
#' @param seed Optional integer seed (reserved for future randomised
#'   designs; currently unused as the function is deterministic).
#'
#' @return A tibble: `sampling_frame` columns plus `p_period` and
#'   `inclusion_prob`. `inclusion_prob = p_site * p_period`.
#'
#' @examples
#' sched <- generate_schedule(
#'   start_date    = "2024-06-01",
#'   end_date      = "2024-06-14",
#'   n_periods     = 1,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed          = 42
#' )
#' frame <- data.frame(
#'   site   = c("A", "B", "C"),
#'   p_site = c(0.4, 0.3, 0.3),
#'   stringsAsFactors = FALSE
#' )
#' generate_bus_schedule(sched, frame, site = site, p_site = p_site, crew = 2)
#'
#' @family "Scheduling"
#' @export
generate_bus_schedule <- function(
  schedule,
  sampling_frame,
  site,
  p_site,
  circuit = NULL,
  crew,
  seed = NULL
) {
  # Capture tidy selectors
  site_quo <- rlang::enquo(site)
  p_site_quo <- rlang::enquo(p_site)
  circuit_quo <- rlang::enquo(circuit)

  # Resolve required column names (site_col validates presence; p_site_col used for indexing)
  site_col <- resolve_single_col(site_quo, sampling_frame, "site", rlang::caller_env()) # nolint: object_usage_linter
  p_site_col <- resolve_single_col(p_site_quo, sampling_frame, "p_site", rlang::caller_env()) # nolint: object_usage_linter

  # Build working copy
  result <- tibble::as_tibble(sampling_frame)

  # Resolve or synthesise circuit column
  if (rlang::quo_is_null(circuit_quo)) {
    result[[".circuit_synth"]] <- "circuit_1"
    circuit_col <- ".circuit_synth"
  } else {
    circuit_col <- resolve_single_col(circuit_quo, sampling_frame, "circuit", rlang::caller_env()) # nolint: object_usage_linter
  }

  # Validate p_site sums to 1.0 within each circuit
  circuit_vals <- result[[circuit_col]]
  p_site_vals <- result[[p_site_col]]

  circuit_sums <- tapply(p_site_vals, circuit_vals, sum)
  violating <- names(circuit_sums[abs(circuit_sums - 1.0) > 1e-6])

  if (length(violating) > 0) {
    cli::cli_abort(c(
      "{.arg p_site} values must sum to 1.0 within each circuit (tolerance 1e-6).",
      "x" = "{length(violating)} circuit{?s} with invalid sums: {.val {violating}}.",
      "i" = "Sums: {paste(paste0(violating, '=', round(circuit_sums[violating], 6)), collapse = ', ')}"
    ))
  }

  # Compute n_circuits and p_period
  n_circuits <- length(unique(circuit_vals))
  p_period <- crew / n_circuits

  # Add columns to output
  result[["p_period"]] <- p_period
  inclusion_probs <- p_site_vals * p_period
  result[["inclusion_prob"]] <- inclusion_probs

  bad_sites <- which(inclusion_probs > 1)
  if (length(bad_sites) > 0L) {
    cli::cli_abort(c(
      "Inclusion probabilities exceed 1 for {length(bad_sites)} site{?s}.",
      "x" = "crew={crew}, n_circuits={n_circuits}, p_period={p_period}; max p_site={max(p_site_vals[bad_sites])}.",
      "i" = "Reduce {.arg crew} or increase circuits so that p_site * (crew / n_circuits) <= 1 for all sites."
    ))
  }

  # Drop synthetic circuit column
  if (rlang::quo_is_null(circuit_quo)) {
    result[[".circuit_synth"]] <- NULL
  }

  tibble::as_tibble(result)
}

#' Attach count time windows to a daily sampling schedule
#'
#' Gives each sampled day (and each worked shift) its count windows. Two ways:
#'
#' - **Draw new windows for each day** (pass `n_windows`, `window_size`,
#'   `min_gap`): every day gets its own random placement, inside that day's
#'   shift when the schedule carries shift times (from
#'   [generate_schedule()]`(periods = )`), otherwise inside `start_time` --
#'   `end_time`. Instantaneous-count effort assumes the count times are random
#'   on *each* sampled day; the same clock times every day sample any
#'   time-of-day pattern in pressure the same way, which never averages out
#'   and understates the within-day variance (#385).
#' - **Copy one template to every day** (pass `count_times` from
#'   [generate_count_times()]): the same windows on every day, for fixed-time
#'   protocols. With shift times in the schedule, every window must start
#'   inside each day's shift (the start is the count instant; the slot may run
#'   past the shift end).
#'
#' @param schedule A `creel_schedule` from [generate_schedule()] or
#'   [read_schedule()]. Must have a `date` column.
#' @param count_times Optional `creel_schedule` from [generate_count_times()]
#'   with `start_time`, `end_time` and `window_id`, copied to every row. Give
#'   this or the drawing arguments, not both.
#' @param n_windows,window_size,min_gap Number of windows per day (or shift),
#'   window length and minimum gap between windows, in minutes. Required to
#'   draw windows. The span (shift or `start_time`--`end_time`) is split into
#'   `n_windows` strata of equal length, which need not be whole minutes (a
#'   sunrise-bounded shift from [daylight_shifts()] rarely divides evenly):
#'   count instants are drawn continuously and rounded down to the minute, so
#'   every minute has the same chance. Each stratum must hold
#'   `window_size + min_gap`. `min_gap` is guaranteed between windows only
#'   with `"systematic"` (see `strategy`).
#' @param strategy `"random"` (default; one count start uniform over each
#'   equal stratum -- neighbouring counts can be closer than `min_gap`; a day
#'   whose slots would overlap is redrawn, checked across all of that day's
#'   shifts because one crew works the day),
#'   `"systematic"` (a random start in the first stratum, then every stratum
#'   length, so gaps are at least `min_gap`; a fresh start each day, as in
#'   Pollock et al. 1994), or `"fixed"` (the clock times in `fixed_windows`).
#' @param fixed_windows For `strategy = "fixed"`: a data frame of `start_time`
#'   and `end_time` (`"HH:MM"`). With shift times in the schedule it must also
#'   carry `period_id`, giving each shift its own windows, and every window
#'   must start inside its shift.
#' @param start_time,end_time The day's counting span (`"HH:MM"`), used to
#'   draw windows when the schedule has no shift times. Not allowed when it
#'   does: the shift is the span.
#' @param seed Optional integer seed. The same seed gives the same windows.
#'
#' @return A `creel_schedule` with all columns from `schedule` plus
#'   `start_time`, `end_time` and `window_id`, one row per (schedule row x
#'   count window). Unsampled rows of a schedule made with `include_all = TRUE`
#'   keep one row with missing windows when windows are drawn.
#'
#' @examples
#' # Per-day windows inside each day's drawn shift
#' sched <- generate_schedule(
#'   start_date = "2024-06-01", end_date = "2024-06-07",
#'   n_periods = 2, sampling_rate = 0.5, seed = 1,
#'   periods_per_day = 1,
#'   periods = data.frame(
#'     period_id = 1:2, start_time = c("06:00", "13:00"), end_time = c("13:00", "20:00")
#'   )
#' )
#' attach_count_times(sched, n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
#'
#' # The same template on every day (a fixed-time protocol)
#' sched2 <- generate_schedule(
#'   start_date = "2024-06-01", end_date = "2024-06-07",
#'   n_periods = 2, sampling_rate = 0.5, seed = 1
#' )
#' ct <- generate_count_times(
#'   start_time = "06:00", end_time = "14:00",
#'   strategy = "systematic", n_windows = 3,
#'   window_size = 30, min_gap = 10, seed = 1
#' )
#' attach_count_times(sched2, ct)
#'
#' @family "Scheduling"
#' @export
attach_count_times <- function(
  schedule,
  count_times = NULL,
  n_windows = NULL,
  window_size = NULL,
  min_gap = NULL,
  strategy = c("random", "systematic", "fixed"),
  fixed_windows = NULL,
  start_time = NULL,
  end_time = NULL,
  seed = NULL
) {
  # Validate schedule
  if (!is.data.frame(schedule) || !"date" %in% names(schedule)) {
    cli::cli_abort(c(
      "{.arg schedule} must be a data frame with a {.col date} column.",
      "i" = "Use {.fn generate_schedule} to produce a valid schedule."
    ))
  }
  if (any(c("window_id", "start_time", "end_time") %in% names(schedule))) {
    cli::cli_abort(c(
      "{.arg schedule} already has count windows.",
      "i" = "Attach count times to the schedule from {.fn generate_schedule}, once."
    ))
  }
  strategy <- match.arg(strategy)
  drawing <- !is.null(n_windows) || !is.null(window_size) || !is.null(min_gap) ||
    !is.null(fixed_windows) || !is.null(start_time) || !is.null(end_time)
  has_shift_times <- all(c("shift_start", "shift_end") %in% names(schedule))

  if (!is.null(count_times)) {
    if (drawing) {
      cli::cli_abort(c(
        "Give {.arg count_times} or the arguments to draw windows, not both.",
        "i" = "{.arg count_times} copies one template to every day; {.arg n_windows} etc. \\
               draw new windows for each day."
      ))
    }
    return(attach_count_template(schedule, count_times, has_shift_times))
  }
  if (!drawing) {
    cli::cli_abort(c(
      "Nothing to attach.",
      "i" = "Draw windows for each day with {.arg n_windows}, {.arg window_size} and {.arg min_gap}, \\
             or copy one template with {.arg count_times}."
    ))
  }

  samples_shifts <- "p_period" %in% names(schedule) && any(schedule$p_period < 1, na.rm = TRUE)
  if (!has_shift_times) {
    if (samples_shifts) {
      cli::cli_abort(c(
        "The schedule draws shifts but has no shift times.",
        "x" = "Count windows must fall inside each day's shift, and the schedule does not say \\
               when its shifts are.",
        "i" = "Regenerate it with {.code generate_schedule(periods = )} giving each shift's \\
               {.field start_time} and {.field end_time}."
      ))
    }
    if (strategy != "fixed" && (is.null(start_time) || is.null(end_time))) {
      cli::cli_abort(c(
        "{.arg start_time} and {.arg end_time} are required: the schedule has no shift times.",
        "i" = "They give the span each day's windows are drawn in."
      ))
    }
  } else if (!is.null(start_time) || !is.null(end_time)) {
    cli::cli_abort(c(
      "{.arg start_time} / {.arg end_time} cannot be used: the schedule has shift times.",
      "i" = "Each day's windows are drawn inside that day's shift."
    ))
  }

  hhmm_re <- "^([01][0-9]|2[0-3]):[0-5][0-9]$"
  to_min <- function(x) {
    x <- as.character(x)
    out <- rep(NA_integer_, length(x))
    ok <- !is.na(x) & grepl(hhmm_re, x)
    out[ok] <- vapply(x[ok], parse_hhmm_to_min, integer(1), USE.NAMES = FALSE)
    if (any(!is.na(x) & !ok)) {
      cli::cli_abort("Times must be {.val HH:MM} (00:00 to 23:59).", call = rlang::caller_env(2))
    }
    out
  }
  # Spans and windows are drawn in minutes since the survey day began, so a
  # night that crosses midnight is one interval; written back as clock times
  # (GH #407). With day_start "00:00" these are minutes since midnight.
  ds <- schedule_day_start(schedule)
  if (has_shift_times) {
    span_start <- survey_min(to_min(schedule$shift_start), ds)
    span_end <- survey_min(to_min(schedule$shift_end), ds, end = TRUE)
  } else {
    span_start <- rep(if (is.null(start_time)) NA_integer_ else survey_min(to_min(start_time), ds), nrow(schedule))
    span_end <- rep(if (is.null(end_time)) NA_integer_ else survey_min(to_min(end_time), ds, end = TRUE),
                    nrow(schedule))
  }
  # Days the schedule did not sample get no windows.
  idle <- rep(FALSE, nrow(schedule))
  if ("sampled" %in% names(schedule)) idle <- idle | !(schedule$sampled %in% TRUE)
  if ("period_id" %in% names(schedule)) idle <- idle | is.na(schedule$period_id)
  span_start[idle] <- NA_integer_
  span_end[idle] <- NA_integer_
  crosses <- !is.na(span_start) & !is.na(span_end) & span_end <= span_start
  if (any(crosses)) {
    cli::cli_abort(c(
      "A counting span ends at or before it starts on {sum(crosses)} row{?s}.",
      "x" = "Each span must fall inside one survey day, which starts at \\
             {.val {format_min_to_hhmm(ds)}}.",
      "i" = "For night shifts, build the schedule with {.code generate_schedule(day_start = )}."
    ))
  }

  if (strategy == "fixed") {
    windows <- fixed_windows_by_row(schedule, fixed_windows, has_shift_times,
                                    span_start, span_end, idle, to_min, ds)
    # A fixed window may run past its shift end (the start is the count
    # instant, #432), so check every window of a date together: one crew
    # works the day and cannot count twice at once.
    # Without shift times every row of a date carries the same day-level
    # windows, so there is nothing across shifts to compare.
    used <- if (has_shift_times) which(!vapply(windows, is.null, logical(1))) else integer(0)
    clash <- tapply(used, as.character(schedule$date[used]), function(rows) {
      w <- do.call(rbind, windows[rows])
      w <- w[order(w$start), , drop = FALSE]
      nrow(w) > 1L && any(w$start[-1] < w$end[-nrow(w)])
    })
    if (any(clash)) {
      bad <- names(clash)[clash] # nolint: object_usage_linter
      cli::cli_abort(c(
        "Fixed count windows overlap across shifts on {length(bad)} day{?s}: {.val {bad}}.",
        "x" = "One crew cannot run two counts at once.",
        "i" = "Move a window so each ends before the next one starts."
      ))
    }
  } else {
    for (arg_name in c("n_windows", "window_size", "min_gap")) {
      if (is.null(get(arg_name))) {
        cli::cli_abort("{.arg {arg_name}} is required to draw count windows.")
      }
    }
    n_windows <- as.integer(n_windows)
    window_size <- as.integer(window_size)
    min_gap <- as.integer(min_gap)
    worked <- which(!is.na(span_start) & !is.na(span_end))
    for (i in worked) {
      check_window_spacing(span_start[i], span_end[i], n_windows, window_size, min_gap,
                           where = paste0(" on ", schedule$date[i]), require_even = FALSE,
                           call = rlang::current_env())
    }
    # One seeded stream, drawn date by date in schedule order: the same seed
    # and schedule give the same windows. All of a date's shifts are drawn
    # together, so a slot running past one shift's end is checked against the
    # next shift's counts (one crew works the day).
    day <- as.character(schedule$date[worked])
    starts <- vector("list", length(worked))
    with_optional_seed(seed, {
      for (d in unique(day)) {
        rows <- which(day == d)
        starts[rows] <- draw_day_starts(span_start[worked[rows]], span_end[worked[rows]],
                                        strategy, n_windows, window_size, min_gap)
      }
    })
    check_slots_before_midnight(starts, day, window_size)
    windows <- vector("list", nrow(schedule))
    windows[worked] <- lapply(starts, function(st) {
      data.frame(start = st, end = st + window_size)
    })
  }

  rows <- lapply(seq_len(nrow(schedule)), function(i) {
    w <- windows[[i]]
    base <- schedule[i, , drop = FALSE]
    if (is.null(w) || nrow(w) == 0L) {
      base$start_time <- NA_character_
      base$end_time <- NA_character_
      base$window_id <- NA_integer_
      return(base)
    }
    out <- base[rep(1L, nrow(w)), , drop = FALSE]
    out$start_time <- format_min_to_hhmm(as.integer(w$start) + ds)
    out$end_time <- format_min_to_hhmm(as.integer(w$end) + ds)
    out$window_id <- seq_len(nrow(w))
    out
  })
  result <- if (length(rows) == 0L) {
    empty <- schedule[0, , drop = FALSE]
    empty$start_time <- character(0)
    empty$end_time <- character(0)
    empty$window_id <- integer(0)
    empty
  } else {
    do.call(rbind, rows)
  }
  rownames(result) <- NULL
  new_creel_schedule(result)
}

#' Copy one count-time template to every schedule row
#'
#' The behaviour of attach_count_times() before #385, plus a check that every
#' window falls inside each row's shift when the schedule has shift times.
#'
#' @noRd
attach_count_template <- function(schedule, count_times, has_shift_times, call = rlang::caller_env()) {
  required_ct <- c("start_time", "end_time", "window_id")
  missing_ct <- setdiff(required_ct, names(count_times))
  if (!is.data.frame(count_times) || length(missing_ct) > 0) {
    cli::cli_abort(c(
      "{.arg count_times} must be a data frame with columns {.val {required_ct}}.",
      "x" = "Missing: {.val {missing_ct}}",
      "i" = "Use {.fn generate_count_times} to produce a valid count-time template."
    ), call = call)
  }
  if (has_shift_times) {
    # On the survey-day clock (GH #407).
    ds <- schedule_day_start(schedule, call = call)
    w_start <- survey_min(vapply(as.character(count_times$start_time), parse_hhmm_to_min, integer(1)), ds)
    worked <- !is.na(schedule$shift_start) & !is.na(schedule$shift_end)
    outside <- vapply(which(worked), function(i) {
      s0 <- survey_min(parse_hhmm_to_min(as.character(schedule$shift_start[i])), ds)
      s1 <- survey_min(parse_hhmm_to_min(as.character(schedule$shift_end[i])), ds, end = TRUE)
      # The start is the count instant (#432); the slot after it may run on.
      any(w_start < s0 | w_start >= s1)
    }, logical(1))
    if (any(outside)) {
      bad <- unique(as.character(schedule$date[which(worked)[outside]])) # nolint: object_usage_linter
      cli::cli_abort(c(
        "Template count times fall outside the shift on {length(bad)} day{?s}: {.val {bad}}.",
        "x" = "A count outside the shift worked that day is not a count of that shift.",
        "i" = "Draw windows inside each day's shift with {.arg n_windows}, {.arg window_size} \\
               and {.arg min_gap} instead of a template."
      ), call = call)
    }
  }
  # Cross-join: each schedule row gets one copy per count window
  # merge() with no by columns performs a full cross-join
  result <- merge(schedule, count_times, by = NULL)
  # Restore intuitive row order: schedule rows primary, windows secondary
  result <- result[
    order(
      result$date,
      if ("period_id" %in% names(result)) result$period_id else seq_len(nrow(result)),
      result$window_id
    ),
  ]
  rownames(result) <- NULL
  new_creel_schedule(result)
}

#' Fixed clock-time windows for each schedule row
#'
#' With shift times, `fixed_windows` carries `period_id` and each row takes its
#' shift's windows, which must start inside the shift. Without, every worked row
#' takes all of them.
#'
#' @noRd
fixed_windows_by_row <- function(schedule, fixed_windows, has_shift_times, span_start, span_end,
                                 idle, to_min, ds = 0L, call = rlang::caller_env()) {
  if (!is.data.frame(fixed_windows) || !all(c("start_time", "end_time") %in% names(fixed_windows))) {
    cli::cli_abort(
      "{.arg fixed_windows} must be a data frame with {.field start_time} and {.field end_time}.",
      call = call
    )
  }
  if (has_shift_times && !"period_id" %in% names(fixed_windows)) {
    cli::cli_abort(c(
      "{.arg fixed_windows} needs a {.field period_id} column: the schedule has shifts.",
      "i" = "Give each shift its own clock times, e.g. the AM shift counts at 08:00 and 11:00."
    ), call = call)
  }
  # On the survey-day clock, like the spans (GH #407).
  fw_start <- survey_min(to_min(fixed_windows$start_time), ds)
  fw_end <- survey_min(to_min(fixed_windows$end_time), ds, end = TRUE)
  if (anyNA(fw_start) || anyNA(fw_end) || any(fw_end <= fw_start)) {
    cli::cli_abort("Every fixed window needs a start before its end.", call = call)
  }
  group <- if (has_shift_times) as.character(fixed_windows$period_id) else rep("all", nrow(fixed_windows))
  for (g in unique(group)) {
    o <- order(fw_start[group == g])
    st <- fw_start[group == g][o]
    en <- fw_end[group == g][o]
    if (length(st) > 1L && any(en[-length(en)] > st[-1])) {
      cli::cli_abort("Windows in {.arg fixed_windows} must not overlap.", call = call)
    }
  }
  lapply(seq_len(nrow(schedule)), function(i) {
    if (idle[i] || (has_shift_times && is.na(span_start[i]))) {
      return(NULL)
    }
    take <- if (has_shift_times) group == as.character(schedule$period_id[i]) else rep(TRUE, length(group))
    w <- data.frame(start = fw_start[take], end = fw_end[take])
    w <- w[order(w$start), , drop = FALSE]
    if (!has_shift_times && !is.na(span_start[i]) &&
          any(w$start < span_start[i] | w$start >= span_end[i])) {
      cli::cli_abort(
        "A fixed window falls outside {.arg start_time} -- {.arg end_time}.",
        call = call
      )
    }
    if (nrow(w) == 0L) {
      cli::cli_abort(
        "{.arg fixed_windows} has no windows for shift {.val {schedule$period_id[i]}}.",
        call = call
      )
    }
    if (has_shift_times && any(w$start < span_start[i] | w$start >= span_end[i])) {
      cli::cli_abort(c(
        "A fixed window for shift {.val {schedule$period_id[i]}} falls outside the shift.",
        "x" = "The shift runs {schedule$shift_start[i]} to {schedule$shift_end[i]}."
      ), call = call)
    }
    w
  })
}
