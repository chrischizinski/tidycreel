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

#' Print method for creel_schedule objects
#'
#' Prints a one-line summary showing row count, column count, number of sampled
#' days, and number of periods before delegating to `NextMethod()`.
#'
#' @param x A `creel_schedule` object.
#' @param ... Additional arguments passed to `NextMethod()`.
#'
#' @return Invisibly returns `x`.
#'
#' @export
print.creel_schedule <- function(x, ...) {
  cli::cli_text(
    "# A creel_schedule: {nrow(x)} rows x {ncol(x)} cols ",
    "({if ('date' %in% names(x)) length(unique(x$date)) else NA_integer_} days, ",
    "{if ('period_id' %in% names(x)) length(unique(x$period_id)) else 1L} periods)"
  )
  NextMethod()
  invisible(x)
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
#'
#' @return A logical vector of the same length as `all_dates` indicating
#'   sampled days.
#'
#' @noRd
select_sampled_days <- function(all_dates, day_types, n_days = NULL,
                                sampling_rate = NULL) {
  strata <- unique(day_types)

  # Expand scalar to named vector over strata
  if (!is.null(n_days) && is.null(names(n_days))) {
    n_days <- stats::setNames(rep(n_days, length(strata)), strata)
  }
  if (!is.null(sampling_rate) && is.null(names(sampling_rate))) {
    sampling_rate <- stats::setNames(rep(sampling_rate, length(strata)), strata)
  }

  # Validate that named vector keys match actual day types
  if (!is.null(n_days)) {
    bad <- setdiff(names(n_days), strata)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Names in {.arg n_days} do not match day types in the season.",
        "x" = "Unmatched names: {.val {bad}}",
        "i" = "Season has day types: {.val {strata}}"
      ))
    }
  }
  if (!is.null(sampling_rate)) {
    bad <- setdiff(names(sampling_rate), strata)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "Names in {.arg sampling_rate} do not match day types in the season.",
        "x" = "Unmatched names: {.val {bad}}",
        "i" = "Season has day types: {.val {strata}}"
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
#'
#' @return A `creel_schedule` data frame with columns:
#'   - `date` (Date): Sampled (or all) dates.
#'   - `day_type` (character): "weekday" or "weekend".
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
  seed
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

  # Stratified random sampling inside scoped RNG (no global mutation)
  sampled <- withr::with_seed(
    seed,
    select_sampled_days(all_dates, day_types, n_days, sampling_rate)
  )

  # Build base tibble with all season dates
  base <- tibble::tibble(
    date     = all_dates,
    day_type = day_types,
    sampled  = sampled
  )

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

  new_creel_schedule(base)
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
