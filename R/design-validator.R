# design-validator.R -- Pre-season design validation and post-season completeness checking
# Phase 50: VALID-01 (validate_design) and QUAL-01 (check_completeness)

# Internal threshold constants (documented, not yet enforced until Plan 02)
WARN_CV_BUFFER <- 1.2 # nolint: object_name_linter -- warn if cv_actual <= cv_target * WARN_CV_BUFFER but n < n_required

# ---- internal constructors --------------------------------------------------

new_creel_design_report <- function(results, passed, survey_type) {
  structure(
    list(results = results, passed = passed, survey_type = survey_type),
    class = "creel_design_report"
  )
}

# ---- validate_design --------------------------------------------------------

#' Validate a proposed creel survey design against sample size targets
#'
#' Pre-season design check: runs creel_n_effort() and creel_n_cpue() per
#' stratum and returns a pass/warn/fail status report.
#'
#' @param N_h Named numeric vector. Total available sampling days per stratum.
#' @param ybar_h Numeric vector (same length as N_h). Pilot mean effort per day per stratum.
#' @param s2_h Numeric vector (same length as N_h). Pilot variance of effort per stratum.
#' @param n_proposed Named integer vector (same length as N_h). Proposed sampling days per stratum.
#' @param cv_target Numeric scalar. Target CV for the effort estimate.
#' @param type Character. One of "effort" or "cpue". Default "effort".
#' @param cv_catch Numeric scalar. Required when type = "cpue".
#' @param cv_effort Numeric scalar. Required when type = "cpue".
#' @param rho Numeric scalar. Correlation between catch and effort. Default 0.
#'
#' @return A creel_design_report object (S3 list) with:
#'   \describe{
#'     \item{$results}{tibble with columns stratum, status, n_proposed,
#'       n_required, cv_actual, cv_target, message}
#'     \item{$passed}{logical -- TRUE if all strata status == "pass"}
#'     \item{$survey_type}{character}
#'   }
#'
#' @examples
#' validate_design(
#'   N_h        = c(weekday = 65L, weekend = 28L),
#'   ybar_h     = c(weekday = 50, weekend = 60),
#'   s2_h       = c(weekday = 400, weekend = 500),
#'   n_proposed = c(weekday = 20L, weekend = 12L),
#'   cv_target  = 0.15
#' )
#'
#' @family "Reporting & Diagnostics"
#' @export
validate_design <- function(
  # nolint: object_name_linter
  N_h,
  ybar_h,
  s2_h,
  n_proposed,
  cv_target, # nolint: object_name_linter
  type = c("effort", "cpue"),
  cv_catch = NULL,
  cv_effort = NULL,
  rho = 0
) {
  type <- match.arg(type)

  # Input validation
  checkmate::assert_numeric(N_h, lower = 1, min.len = 1, names = "named") # nolint: object_name_linter
  checkmate::assert_numeric(ybar_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_numeric(s2_h, lower = 0, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_integerish(n_proposed, lower = 1, len = length(N_h)) # nolint: object_name_linter
  checkmate::assert_number(cv_target, lower = 1e-6, upper = 1.0)

  # CPUE-specific argument validation
  if (type == "cpue") {
    checkmate::assert_number(cv_catch, lower = 1e-6)
    checkmate::assert_number(cv_effort, lower = 1e-6)
    checkmate::assert_number(rho, lower = -1.0, upper = 1.0)
  }

  strata_names <- names(N_h)

  # Re-key ybar_h, s2_h, n_proposed to N_h's stratum order so positional
  # indexing below is correct even if the caller supplied named-but-reordered vectors.
  if (!is.null(names(ybar_h))) {
    ybar_h <- ybar_h[strata_names]
  }
  if (!is.null(names(s2_h))) {
    s2_h <- s2_h[strata_names]
  }
  if (!is.null(names(n_proposed))) {
    n_proposed <- n_proposed[strata_names]
  }

  # Per-stratum calculations -- delegate entirely to Phase 49 functions
  if (type == "effort") {
    n_req_all <- creel_n_effort(
      # nolint: object_usage_linter
      cv_target = cv_target, # nolint: object_name_linter
      N_h = N_h,
      ybar_h = ybar_h,
      s2_h = s2_h
    )
    n_required_vec <- n_req_all[strata_names]
    cv_actual_vec <- vapply(
      seq_along(N_h),
      function(i) {
        cv_from_n(
          "effort", # nolint: object_usage_linter
          n = n_proposed[[i]],
          N_h = N_h[i],
          ybar_h = ybar_h[i],
          s2_h = s2_h[i]
        )
      },
      numeric(1)
    )
  } else {
    # CPUE: single overall n (no per-stratum breakdown in creel_n_cpue)
    n_required_scalar <- creel_n_cpue(
      # nolint: object_usage_linter
      cv_catch = cv_catch,
      cv_effort = cv_effort,
      rho = rho,
      cv_target = cv_target
    )
    n_required_vec <- rep(n_required_scalar, length(N_h))
    cv_actual_vec <- vapply(
      n_proposed,
      function(n) {
        cv_from_n("cpue", n = n, cv_catch = cv_catch, cv_effort = cv_effort, rho = rho) # nolint: object_usage_linter
      },
      numeric(1)
    )
  }

  # Status logic: pass / warn / fail
  status_vec <- dplyr::case_when(
    n_proposed >= n_required_vec ~ "pass",
    cv_actual_vec <= cv_target * WARN_CV_BUFFER ~ "warn",
    TRUE ~ "fail"
  )

  # Build results tibble
  results <- tibble::tibble(
    stratum = strata_names,
    status = status_vec,
    n_proposed = as.integer(n_proposed),
    n_required = as.integer(n_required_vec),
    cv_actual = round(cv_actual_vec, 4),
    cv_target = cv_target,
    message = dplyr::case_when(
      status_vec == "pass" ~ paste0(
        "Proposed n meets or exceeds required n (",
        n_required_vec,
        ")"
      ),
      status_vec == "warn" ~ paste0(
        "Proposed n below required (",
        n_required_vec,
        ") but CV within ",
        WARN_CV_BUFFER,
        "x target"
      ),
      TRUE ~ paste0("Proposed n well below required (", n_required_vec, ")")
    )
  )

  new_creel_design_report(
    results = results,
    passed = all(status_vec == "pass"),
    survey_type = type
  )
}

# ---- S3 methods for creel_design_report -------------------------------------

#' Format creel_design_report for printing
#'
#' @param x A creel_design_report object
#' @param ... Additional arguments (currently ignored)
#' @return Character vector with formatted output
#' @export
format.creel_design_report <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_h1("Design Validation Report")
    cli::cli_text("Type: {x$survey_type}")
    if (x$passed) {
      cli::cli_alert_success("All strata PASSED")
    } else {
      cli::cli_alert_danger("One or more strata FAILED or WARNED")
    }
    cli::cli_text("")
    for (i in seq_len(nrow(x$results))) {
      r <- x$results[i, ]
      cv_a <- round(r$cv_actual, 3) # nolint: object_usage_linter
      cv_t <- r$cv_target # nolint: object_usage_linter
      n_p <- r$n_proposed # nolint: object_usage_linter
      n_r <- r$n_required # nolint: object_usage_linter
      s <- r$stratum # nolint: object_usage_linter
      if (r$status == "pass") {
        cli::cli_alert_success("{s}: n={n_p} >= {n_r} required (CV {cv_a} vs target {cv_t})")
      } else if (r$status == "warn") {
        cli::cli_alert_warning("{s}: n={n_p} < {n_r} required but CV {cv_a} near target {cv_t}")
      } else {
        cli::cli_alert_danger("{s}: n={n_p} << {n_r} required (CV {cv_a} vs target {cv_t})")
      }
    }
  })
}

#' Print creel_design_report
#'
#' @param x A creel_design_report object
#' @param ... Additional arguments passed to format
#' @return The input object, invisibly
#' @export
print.creel_design_report <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

# ---- check_completeness internals -------------------------------------------

new_creel_completeness_report <- function(
  missing_days,
  low_n_strata,
  refusals,
  n_min,
  survey_type,
  missing_days_checked = TRUE,
  schedule_source = NA_character_,
  coverage = NULL
) {
  passed <- (!missing_days_checked || nrow(missing_days) == 0L) &&
    (is.null(low_n_strata) || nrow(low_n_strata) == 0L)
  structure(
    list(
      missing_days = missing_days,
      missing_days_checked = missing_days_checked,
      schedule_source = schedule_source,
      coverage = coverage,
      low_n_strata = low_n_strata,
      refusals = refusals,
      n_min = n_min,
      survey_type = survey_type,
      passed = passed
    ),
    class = "creel_completeness_report"
  )
}

#' The days the survey scheduled, from a schedule or the sampled register
#'
#' Internal (GH #391). A day missing from the counts is missing data only if it
#' was scheduled: in a sampled design most calendar days are meant to have no
#' counts.
#'
#' @return A list: `dates` (Date vector, or NULL when no schedule is known) and
#'   `source` ("schedule", "sampled register" or NA).
#' @keywords internal
#' @noRd
scheduled_days <- function(design, schedule, call = rlang::caller_env()) {
  date_col <- design$date_col
  if (!is.null(schedule)) {
    if (!is.data.frame(schedule)) {
      cli::cli_abort(
        c(
          "{.arg schedule} must be a data frame of scheduled days.",
          "x" = "It is {.cls {class(schedule)[1]}}.",
          "i" = "Pass the {.cls creel_schedule} from {.fn generate_schedule} or a data frame with a date column."
        ),
        class = "creel_error_schedule_invalid",
        call = call
      )
    }
    col <- if (date_col %in% names(schedule)) date_col else if ("date" %in% names(schedule)) "date" else NULL
    if (is.null(col)) {
      looked <- unique(c(date_col, "date")) # nolint: object_usage_linter
      cli::cli_abort(
        c(
          "{.arg schedule} has no date column.",
          "x" = "Looked for {.field {looked}}.",
          "i" = "Name the scheduled dates {.field {date_col}}."
        ),
        class = "creel_error_schedule_invalid",
        call = call
      )
    }
    keep <- if (is.logical(schedule[["sampled"]])) schedule[["sampled"]] %in% TRUE else rep(TRUE, nrow(schedule))
    dates <- unique(as.Date(schedule[[col]][keep]))
    outside <- sort(dates[!dates %in% as.Date(design$calendar[[date_col]])])
    if (length(outside) > 0L) {
      shown <- format(utils::head(outside, 5L)) # nolint: object_usage_linter
      cli::cli_abort(
        c(
          "{length(outside)} scheduled date{?s} {?is/are} not in the design calendar.",
          "x" = "Not in the calendar: {.val {shown}}.",
          "i" = "The schedule and the calendar must describe the same season."
        ),
        class = "creel_error_schedule_invalid",
        call = call
      )
    }
    return(list(dates = dates, source = "schedule"))
  }
  if (!is.null(design$sampled_col)) {
    cal <- design$calendar
    worked <- cal[[design$date_col]][cal[[design$sampled_col]] %in% TRUE]
    return(list(dates = unique(as.Date(worked)), source = "sampled register"))
  }
  list(dates = NULL, source = NA_character_)
}

#' Calendar days and counted days per stratum
#'
#' Internal (GH #391).
#'
#' @keywords internal
#' @noRd
sampling_coverage <- function(design) {
  strata_cols <- intersect(design$strata_cols %||% character(0), names(design$calendar))
  pop <- stratum_population_days(design$calendar, strata_cols, design$date_col) # nolint: object_usage_linter
  if (is.null(design$counts)) {
    pop$n_counted <- NA_integer_
  } else {
    counted <- design$counts |>
      dplyr::distinct(dplyr::across(dplyr::all_of(c(strata_cols, design$date_col)))) |>
      dplyr::count(dplyr::across(dplyr::all_of(strata_cols)), name = "n_counted")
    pop <- dplyr::left_join(pop, counted, by = strata_cols)
    # A calendar stratum with no count rows had no counted day: a count of
    # days, so its absence is zero days.
    pop$n_counted[is.na(pop$n_counted)] <- 0L
  }
  names(pop)[names(pop) == ".N_avail"] <- "n_calendar"
  as.data.frame(pop)
}

find_missing_days <- function(design, scheduled) {
  keep_cols <- intersect(c(design$date_col, design$strata_cols), names(design$calendar))
  cal <- design$calendar
  sched <- cal[as.Date(cal[[design$date_col]]) %in% scheduled, keep_cols, drop = FALSE]
  if (is.null(design$counts)) {
    return(unique(sched))
  }
  count_dates <- as.Date(unique(design$counts[[design$date_col]]))
  unique(sched[!as.Date(sched[[design$date_col]]) %in% count_dates, , drop = FALSE])
}

find_low_n_strata <- function(design, n_min) {
  interviews <- design$interviews
  strata_cols <- intersect(design$strata_cols, names(interviews))
  if (length(strata_cols) == 0L) {
    return(data.frame(
      key = character(0),
      n_observed = integer(0),
      stringsAsFactors = FALSE
    ))
  }
  # Build composite stratum key across all strata columns (multi-stratum safe)
  key <- do.call(paste, c(interviews[strata_cols], sep = "|"))
  n_per_stratum <- as.data.frame(table(key = key), stringsAsFactors = FALSE)
  names(n_per_stratum)[names(n_per_stratum) == "Freq"] <- "n_observed"
  n_per_stratum$n_observed <- as.integer(n_per_stratum$n_observed)
  n_per_stratum[n_per_stratum$n_observed < n_min, , drop = FALSE]
}

# ---- check_completeness -----------------------------------------------------

#' Check post-season data completeness for a creel design
#'
#' Dispatches by survey_type to avoid false-positive warnings on aerial and
#' camera designs that do not collect interview data.
#'
#' @param design A creel_design object with counts (and optionally interviews) attached.
#' @param n_min Integer scalar >= 1. Interview threshold below which a stratum is flagged
#'   as low-n. Default 10L.
#' @param schedule The days the survey scheduled: the schedule from
#'   [generate_schedule()], or any data frame with the design's date column (or
#'   `date`). A logical `sampled` column, when present, keeps its `TRUE` rows.
#'   A missing day is a scheduled day with no counts: in a sampled design most
#'   calendar days are meant to have none, so without a schedule the
#'   missing-day check is not run (GH #391). A bus-route or ice design's
#'   `sampled` register is used when no schedule is given.
#'
#' @return A creel_completeness_report object (S3 list) with:
#'   \describe{
#'     \item{$missing_days}{data.frame of scheduled days with no count data;
#'       zero rows when the check was not run}
#'     \item{$missing_days_checked}{logical -- FALSE when no schedule was known
#'       or no counts are attached}
#'     \item{$schedule_source}{`"schedule"`, `"sampled register"` or `NA`}
#'     \item{$coverage}{data.frame of calendar days (`n_calendar`) and counted
#'       days (`n_counted`) per stratum}
#'     \item{$low_n_strata}{data.frame of strata below n_min, or NULL for aerial/camera}
#'     \item{$refusals}{creel_summary_refusals object or NULL}
#'     \item{$n_min}{integer threshold used}
#'     \item{$survey_type}{character}
#'     \item{$passed}{logical -- TRUE if no missing scheduled days (when
#'       checked) and no low-n strata}
#'   }
#'
#' @examples
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' check_completeness(design)
#'
#' # With the schedule, a scheduled day that was not counted is reported
#' sched <- data.frame(date = example_calendar$date[1:15])
#' check_completeness(design, schedule = sched)
#'
#' @family "Reporting & Diagnostics"
#' @export
check_completeness <- function(design, n_min = 10L, schedule = NULL) {
  # Guard 1: type check
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(
      c(
        "{.arg design} must be a {.cls creel_design} object.",
        "x" = "{.arg design} is {.cls {class(design)[1]}}.",
        "i" = "Create a design with {.fn creel_design} and attach data."
      ),
      class = "creel_error_design_validation"
    )
  }
  # Guard 2/3: n_min range
  checkmate::assert_integerish(n_min, lower = 1L, len = 1L)
  n_min <- as.integer(n_min)

  # Missing days: scheduled days with no counts, all survey types (GH #391).
  sched <- scheduled_days(design, schedule)
  # A missing day is a scheduled day without counts, so the check needs both.
  # Bus-route and ice designs often carry no counts at all: their effort comes
  # from interviews, and a worked day with nobody fishing leaves none.
  missing_days_checked <- !is.null(sched$dates) && !is.null(design$counts)
  missing_days <- if (missing_days_checked) {
    find_missing_days(design, sched$dates)
  } else {
    keep_cols <- intersect(c(design$date_col, design$strata_cols), names(design$calendar))
    design$calendar[0L, keep_cols, drop = FALSE]
  }

  # Interview-based checks: NOT for aerial or camera
  # Guard: design$interview_survey is NULL for aerial and camera
  low_n_strata <- NULL
  if (!is.null(design$interview_survey) && !is.null(design$interviews)) {
    low_n_strata <- find_low_n_strata(design, n_min)
  }

  # Refusal rates: only if refused_col recorded AND interviews present
  refusals <- NULL
  has_interviews_for_refusals <- !is.null(design$interview_survey) && !is.null(design$interviews)
  if (!is.null(design$refused_col) && has_interviews_for_refusals) {
    refusals <- summarize_refusals(design) # nolint: object_usage_linter
  }

  survey_type <- design$design_type
  if (is.null(survey_type)) {
    survey_type <- "instantaneous"
  }

  new_creel_completeness_report(
    missing_days = missing_days,
    low_n_strata = low_n_strata,
    refusals = refusals,
    n_min = n_min,
    survey_type = survey_type,
    missing_days_checked = missing_days_checked,
    schedule_source = sched$source,
    coverage = sampling_coverage(design)
  )
}

# ---- S3 methods for creel_completeness_report --------------------------------

#' Format creel_completeness_report for printing
#'
#' @param x A creel_completeness_report object
#' @param ... Additional arguments (currently ignored)
#' @return Character vector with formatted output
#' @export
format.creel_completeness_report <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_h1("Completeness Report")
    cli::cli_text("Survey type: {x$survey_type} | n_min threshold: {x$n_min}")
    if (x$passed) {
      cli::cli_alert_success("No completeness issues detected")
    } else {
      cli::cli_alert_danger("Completeness issues found")
    }
    cli::cli_text("")

    # Coverage and missing scheduled days (GH #391)
    cli::cli_h2("Sampled Days")
    if (!is.null(x$coverage)) {
      cov <- x$coverage
      lab_cols <- setdiff(names(cov), c("n_calendar", "n_counted"))
      labs <- if (length(lab_cols) == 0L) "all" else do.call(paste, c(cov[lab_cols], sep = " / "))
      for (i in seq_len(nrow(cov))) {
        lab <- labs[[i]] # nolint: object_usage_linter
        cnt <- cov$n_counted[[i]] # nolint: object_usage_linter
        tot <- cov$n_calendar[[i]] # nolint: object_usage_linter
        cli::cli_text("{lab}: {cnt} of {tot} calendar day{?s} counted")
      }
    }
    if (!isTRUE(x$missing_days_checked) && !is.na(x$schedule_source)) {
      cli::cli_alert_info("Missing scheduled days: not checked, because no counts are attached.")
    } else if (!isTRUE(x$missing_days_checked)) {
      cli::cli_alert_info(paste(
        "Missing scheduled days: not checked. Pass the schedule",
        "({.code schedule = }) to find scheduled days with no counts;",
        "unsampled calendar days are not missing data."
      ))
    } else if (nrow(x$missing_days) == 0L) {
      src <- x$schedule_source # nolint: object_usage_linter
      cli::cli_alert_success("Every scheduled day has counts (from the {src})")
    } else {
      n_miss <- nrow(x$missing_days) # nolint: object_usage_linter
      src <- x$schedule_source # nolint: object_usage_linter
      cli::cli_alert_warning("{n_miss} scheduled day{?s} with no count data (from the {src})")
    }

    # Low-n strata section
    cli::cli_h2("Low-n Strata (threshold: {x$n_min})")
    if (is.null(x$low_n_strata)) {
      stype <- x$survey_type # nolint: object_usage_linter
      cli::cli_text("(not applicable for {stype} design)")
    } else if (nrow(x$low_n_strata) == 0L) {
      cli::cli_alert_success("All strata meet n_min threshold")
    } else {
      n_low <- nrow(x$low_n_strata) # nolint: object_usage_linter
      nmin <- x$n_min # nolint: object_usage_linter
      cli::cli_alert_warning("{n_low} stratum/strata below n_min={nmin}")
    }

    # Refusals section
    cli::cli_h2("Refusal Rates")
    if (is.null(x$refusals)) {
      cli::cli_text("(not recorded or not applicable)")
    } else {
      cli::cli_text("Refusal data available \u2014 use $refusals for full breakdown")
    }
  })
}

#' Print creel_completeness_report
#'
#' @param x A creel_completeness_report object
#' @param ... Additional arguments passed to format
#' @return The input object, invisibly
#' @export
print.creel_completeness_report <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
