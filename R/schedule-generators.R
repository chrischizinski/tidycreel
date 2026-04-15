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
select_sampled_days <- function(all_dates, day_types, n_days = NULL,
                                sampling_rate = NULL, valid_strata = NULL) {
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
expand_periods_impl <- function(base_df, n_periods, period_labels = NULL,
                                ordered_periods = FALSE) {
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
  audit$crosses_boundary <- format(audit$source_start_date, "%Y-%m") != format(audit$source_end_date, "%Y-%m")

  allocation <- as.data.frame(table(final_stratum), stringsAsFactors = FALSE)
  names(allocation) <- c("final_stratum", "available_days")

  diag_rows <- list()
  all_strata <- unique(c(as.character(baseline_allocation$stratum), as.character(allocation$final_stratum)))
  for (stratum_name in all_strata) {
    baseline_days <- baseline_allocation$baseline_days[match(stratum_name, baseline_allocation$stratum)]
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
  special_periods = NULL
) {
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

  # Build season date sequence (lubridate DST-safe)
  all_dates <- seq(
    lubridate::ymd(start_date),
    lubridate::ymd(end_date),
    by = "1 day"
  )

  # Classify weekday vs weekend (week_start=1 => Mon=1 ... Sun=7)
  day_types <- ifelse(
    lubridate::wday(all_dates, week_start = 1) %in% c(6L, 7L),
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
        season_fully_rewritten, ,
      drop = FALSE
    ]
    if (nrow(blocking) > 0L) {
      b1 <- blocking[1, , drop = FALSE]
      cli::cli_abort(c(
        "Special-period declarations consumed a baseline stratum still requested for sampling.",
        "x" = paste0(
          "Stratum ", b1$stratum,
          " had ", b1$baseline_days, " baseline day(s) and ",
          b1$final_days, " remaining final day(s)."
        ),
        "i" = paste0(
          "Update {.arg n_days} or {.arg sampling_rate} to match",
          " the final strata after applying {.arg special_periods}."
        )
      ))
    }

    warnings <- diagnostics[
      diagnostics$severity == "warning" |
        (diagnostics$severity == "error" & diagnostics$stratum %in% requested_strata), ,
      drop = FALSE
    ]
    if (nrow(warnings) > 0L) {
      warn_labels <- paste0( # nolint: object_usage_linter.
        warnings$stratum,
        " (baseline=", warnings$baseline_days,
        ", final=", warnings$final_days, ")"
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

  # Stratified random sampling inside scoped RNG (no global mutation)
  sampled <- withr::with_seed(
    seed,
    select_sampled_days(
      all_dates,
      strata_for_sampling,
      n_days,
      sampling_rate,
      valid_strata = active_sampling_strata
    )
  )

  # Build base tibble with all season dates
  base <- tibble::tibble(
    date     = all_dates,
    day_type = day_types,
    sampled  = sampled
  )

  if (!is.null(special_periods)) {
    base$final_stratum <- special_info$final_stratum
    base$special_period_reason <- special_info$special_period_reason
  }

  if (!include_all) {
    base <- base[base$sampled, ]
  }

  # Expand periods (adds period_id column)
  if (expand_periods) {
    base <- expand_periods_impl(base, n_periods, period_labels, ordered_periods)
  }

  # Drop sampled column if not requested
  if (!include_all) {
    base$sampled <- NULL
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
#' @param mins Integer vector of minutes since midnight.
#' @return Character vector of "HH:MM" strings.
#' @noRd
format_min_to_hhmm <- function(mins) {
  h <- mins %/% 60L
  m <- mins %% 60L
  sprintf("%02d:%02d", h, m)
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
#'   Required for `strategy = "random"` and `"systematic"`.
#' @param strategy Character scalar. One of `"random"`, `"systematic"`, or
#'   `"fixed"`.
#' @param n_windows Positive integer. Number of count time windows. Required
#'   for `strategy = "random"` and `"systematic"`. The total span
#'   (`end_time - start_time` in minutes) must be evenly divisible by
#'   `n_windows`.
#' @param window_size Positive integer. Duration of each count window in
#'   minutes. Required for `strategy = "random"` and `"systematic"`.
#' @param min_gap Non-negative integer. Minimum gap (minutes) between windows.
#'   Required for `strategy = "random"` and `"systematic"`.
#'   `window_size + min_gap` must not exceed the stratum width
#'   (`total_span / n_windows`).
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
#' **Random strategy:** Each of the `n_windows` strata of equal length
#' `k = total_span / n_windows` receives one window with a uniformly random
#' start within `[stratum_start, stratum_start + k - window_size]`.
#'
#' **Systematic strategy (recommended):** A single random start `t1` is drawn
#' from `[start_min, start_min + k - window_size]`; all subsequent windows
#' begin at `t1 + (i-1) * k` for `i = 1, ..., n_windows`. This is the
#' design described in Pollock et al. (1994) and recommended by Colorado CPW
#' (2012).
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

  if (end_min <= start_min) {
    cli::cli_abort(c(
      "end_time must be after start_time.",
      "x" = "{.val {end_time}} is not after {.val {start_time}}."
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

  total_min <- end_min - start_min

  # Validate even divisibility
  if (total_min %% n_windows != 0L) {
    cli::cli_abort(c(
      "Span must divide evenly by n_windows.",
      "x" = "{total_min} min / {n_windows} = {total_min / n_windows} -- must be a whole number.",
      "i" = "Adjust n_windows or start/end time so the span divides evenly."
    ))
  }

  k <- total_min %/% n_windows

  # Validate window fits in stratum
  if (window_size + min_gap > k) {
    cli::cli_abort(c(
      "window_size + min_gap exceeds stratum length.",
      "x" = "Stratum is {k} min, but window_size + min_gap = {window_size + min_gap} min.",
      "i" = "Reduce n_windows, window_size, or min_gap."
    ))
  }

  # Generate windows
  t_starts <- withr::with_seed(seed, {
    if (strategy == "random") {
      vapply(seq_len(n_windows) - 1L, function(i) {
        stratum_start <- start_min + i * k
        sample(stratum_start:(stratum_start + k - window_size), 1L)
      }, integer(1))
    } else {
      # systematic
      t1 <- sample(start_min:(start_min + k - window_size), 1L)
      t1 + (seq_len(n_windows) - 1L) * k
    }
  })

  t_ends <- t_starts + window_size

  # Defensive check: all windows within bounds
  stopifnot(all(t_starts >= start_min), all(t_ends <= end_min))

  result <- data.frame(
    start_time = format_min_to_hhmm(t_starts),
    end_time = format_min_to_hhmm(t_ends),
    window_id = seq_len(n_windows),
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
#' @export
generate_bus_schedule <- function(schedule, sampling_frame, site, p_site,
                                  circuit = NULL, crew, seed = NULL) {
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
  result[["inclusion_prob"]] <- p_site_vals * p_period

  # Drop synthetic circuit column
  if (rlang::quo_is_null(circuit_quo)) {
    result[[".circuit_synth"]] <- NULL
  }

  tibble::as_tibble(result)
}

#' Attach count time windows to a daily sampling schedule
#'
#' Cross-joins a daily schedule produced by [generate_schedule()] with a
#' count-time template produced by [generate_count_times()], returning a
#' `creel_schedule` with one row per (date x period x count_window).
#'
#' @param schedule A `creel_schedule` from [generate_schedule()]. Must have a
#'   `date` column.
#' @param count_times A `creel_schedule` from [generate_count_times()]. Must
#'   have `start_time`, `end_time`, and `window_id` columns.
#'
#' @return A `creel_schedule` data frame with all columns from `schedule` plus
#'   `start_time`, `end_time`, and `window_id` from `count_times`.
#'   Row count equals `nrow(schedule) * nrow(count_times)`.
#'
#' @examples
#' sched <- generate_schedule(
#'   start_date = "2024-06-01", end_date = "2024-06-07",
#'   n_periods = 2, sampling_rate = 0.5, seed = 1
#' )
#' ct <- generate_count_times(
#'   start_time = "06:00", end_time = "14:00",
#'   strategy = "systematic", n_windows = 3,
#'   window_size = 30, min_gap = 10, seed = 1
#' )
#' attach_count_times(sched, ct)
#'
#' @export
attach_count_times <- function(schedule, count_times) {
  # Validate schedule
  if (!is.data.frame(schedule) || !"date" %in% names(schedule)) {
    cli::cli_abort(c(
      "{.arg schedule} must be a data frame with a {.col date} column.",
      "i" = "Use {.fn generate_schedule} to produce a valid schedule."
    ))
  }
  # Validate count_times
  required_ct <- c("start_time", "end_time", "window_id")
  missing_ct <- setdiff(required_ct, names(count_times))
  if (!is.data.frame(count_times) || length(missing_ct) > 0) {
    cli::cli_abort(c(
      "{.arg count_times} must be a data frame with columns {.val {required_ct}}.",
      "x" = "Missing: {.val {missing_ct}}",
      "i" = "Use {.fn generate_count_times} to produce a valid count-time template."
    ))
  }
  # Cross-join: each schedule row gets one copy per count window
  # merge() with no by columns performs a full cross-join
  result <- merge(schedule, count_times, by = NULL)
  # Restore intuitive row order: schedule rows primary, windows secondary
  result <- result[order(
    result$date,
    if ("period_id" %in% names(result)) result$period_id else seq_len(nrow(result)),
    result$window_id
  ), ]
  rownames(result) <- NULL
  new_creel_schedule(result)
}
