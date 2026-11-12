# The fields of a creel_design (GH #594 Part B) ----
#
# A creel_design is a plain list, and R reads a missing list element as NULL.
# The package reads NULL as "not attached", so a misspelled field name looked
# exactly like a table that was never attached: adjust_nonresponse() read
# design$counts_survey, a field no step sets, and its count branch never ran
# (#633). R's `$` also matches a prefix, so design$strata_col silently read
# strata_cols.
#
# `$`, `[[` and `[` on a creel_design therefore check the name against this
# list, and so do `$<-` and `[[<-`: a field that could be set but not read back
# would fail late. A known field that is not set yet still reads as NULL; any
# other name is an error. Matching is exact.
#
# The list is the set of fields the package sets, observed by logging every
# read and write across the test suite (2026-11-12) and checked against the
# assignments in R/. A new field must be added here, or reading it errors.

creel_design_fields <- c(
  # creel_design() / new_creel_design()
  "calendar", "date_col", "strata_cols", "site_col", "design_type",
  "bus_route", "ice", "camera", "aerial", "night", "sampled_col",
  "derived_frame_cols", "steps", "warnings", "warning_id",
  # add_counts()
  "counts", "survey", "circuit_time", "count_calendar_dates", "count_col",
  "count_time_col", "count_type", "counts_are_effort", "effort_unit",
  "excluded_counts", "expansion", "n_counts_per_psu", "p_period",
  "period_length_col", "psu_col", "unit_cols", "validation",
  "within_day_counts", "within_day_var",
  # add_interviews()
  "interviews", "interview_survey", "angler_effort_col", "angler_method_col",
  "angler_type_col", "catch_col", "effort_col", "harvest_col",
  "interview_time_col", "interview_type", "n_anglers_col",
  "n_anglers_supplied", "n_counted_col", "n_interviewed_col", "refused_col",
  "refused_interviews", "excluded_interviews", "species_sought_col",
  "trip_duration_col", "trip_duration_derived", "trip_start_col",
  "trip_status_col",
  # add_sections()
  "sections", "section_col", "section_description_col", "section_area_col",
  "section_shoreline_col", "shared_count_times",
  # add_catch()
  "catch", "catch_uid_col", "catch_interview_uid_col", "catch_species_col",
  "catch_count_col", "catch_type_col",
  # add_lengths()
  "lengths", "lengths_uid_col", "lengths_interview_uid_col",
  "lengths_species_col", "lengths_length_col", "lengths_type_col",
  "lengths_count_col", "lengths_release_format", "lengths_release_bin_unit",
  "lengths_release_bin_width",
  # add_ages()
  "ages", "ages_uid_col", "ages_interview_uid_col", "ages_species_col",
  "ages_age_col", "ages_type_col",
  # set by the estimators on their working copy of the design
  "mor_n_incomplete", "mor_n_total", "mor_n_truncated", "mor_truncate_at",
  "mor_use_trips", "total_estimator", "total_excluded", "total_missing_rate",
  "total_mortr", "total_target"
)

check_design_field <- function(name, call) {
  if (name %in% creel_design_fields) {
    return(invisible(NULL))
  }
  close <- if (is.na(name)) {
    character(0)
  } else {
    creel_design_fields[utils::adist(name, creel_design_fields) <= 2]
  }
  cli::cli_abort(
    c(
      "{.val {name}} is not a field of a {.cls creel_design}.",
      if (length(close) > 0L) c("i" = "Did you mean {.or {.val {close}}}?"),
      "i" = paste(
        "A table that is not attached yet reads as {.code NULL}; a name that",
        "is not a field at all is an error, so a typo cannot pass for one."
      )
    ),
    class = c("creel_error_design_unknown_field", "creel_error"),
    call = call
  )
}

#' @export
`$.creel_design` <- function(x, name) {
  check_design_field(name, call = rlang::caller_env())
  .subset2(x, name)
}

#' @export
`[[.creel_design` <- function(x, i, ...) {
  if (is.character(i) && length(i) == 1L) {
    check_design_field(i, call = rlang::caller_env())
  }
  .subset2(x, i, ...)
}

#' @export
`[.creel_design` <- function(x, i, ...) {
  if (!missing(i) && is.character(i)) {
    for (name in i) check_design_field(name, call = rlang::caller_env())
  }
  NextMethod()
}

#' @export
`$<-.creel_design` <- function(x, name, value) {
  check_design_field(name, call = rlang::caller_env())
  NextMethod()
}

#' @export
`[[<-.creel_design` <- function(x, i, value) {
  if (is.character(i) && length(i) == 1L) {
    check_design_field(i, call = rlang::caller_env())
  }
  NextMethod()
}
