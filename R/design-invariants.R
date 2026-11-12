# Cross-field invariants of a creel_design (GH #594 Part A) ----
#
# A creel_design is a plain list. Each add_*() records which column of the
# table it attached holds each quantity (count_col, catch_col, ...), and every
# estimator reads the table through those names. A user can still edit
# design$counts or design$interviews afterwards. Editing values is fine: the
# estimators rebuild their survey from the current table and follow the edit.
# Dropping or renaming a column the design names is not: the estimators failed
# with "object 'catch_total' not found", or ran on without the column.
#
# The check runs at the end of add_counts() and add_interviews(), where it
# cannot fail through the public API (every column is checked at attach), and
# at the start of the estimators, which is where an edit made after the last
# add_*() is caught.

# The fields that name columns, by the table the column must be in.
#
# counts: two count fields are not here because add_counts() consumes their
# column: period_length_col is multiplied into the count and dropped, and
# count_time_col stays only in design$within_day_counts once within-day counts
# are collapsed to one row per day.
#
# interviews: the *_interview_uid_col fields of catch, lengths and ages name
# the interview-side join key, so they are checked against the interviews.
#
# sections: section_col must also be a column of every counts and interview
# table; check_design_sections() checks that, and the values.
design_column_fields <- list(
  counts = c("count_col", "psu_col", "unit_cols"),
  interviews = c(
    "catch_col", "effort_col", "harvest_col", "trip_status_col",
    "trip_duration_col", "trip_start_col", "interview_time_col",
    "angler_effort_col", "n_anglers_col", "angler_type_col",
    "angler_method_col", "species_sought_col", "n_counted_col",
    "n_interviewed_col", "catch_interview_uid_col",
    "lengths_interview_uid_col", "ages_interview_uid_col"
  ),
  catch = c("catch_uid_col", "catch_species_col", "catch_count_col", "catch_type_col"),
  lengths = c(
    "lengths_uid_col", "lengths_species_col", "lengths_length_col",
    "lengths_type_col", "lengths_count_col"
  ),
  ages = c("ages_uid_col", "ages_species_col", "ages_age_col", "ages_type_col"),
  sections = c(
    "section_col", "section_description_col", "section_area_col",
    "section_shoreline_col"
  )
)

#' Check that each column a design names is in the table it names
#'
#' With `"sections"` among `tables`, also checks that every counts and
#' interview table carries the section column and holds only registered
#' sections (see `check_design_sections()`).
#'
#' @param design A creel_design.
#' @param tables Which tables to check; names of `design_column_fields`.
#' @param call Environment for the error's call.
#' @return `design`, invisibly. Aborts with class
#'   `creel_error_design_column_missing` naming the field and the column, or
#'   `creel_error_design_section_unregistered`.
#' @keywords internal
#' @noRd
check_design_columns <- function(design, tables = names(design_column_fields),
                                 call = rlang::caller_env()) {
  for (table in tables) {
    check_table_columns(design, table, design_column_fields[[table]], call)
  }
  if ("sections" %in% tables) {
    check_design_sections(design, call)
  }
  invisible(design)
}

#' Check that a sectioned design's data carry registered sections
#'
#' The checks add_sections(), add_counts() and add_interviews() make at
#' attach, re-run on the design as it is now. A direct edit that dropped a
#' section from design$sections, relabelled one in the counts, or renamed the
#' section column gave totals that disagreed about what the lake is, or a
#' lake total of 0 (GH #594). Counts or interviews with no section column at
#' all were let through at attach and gave the same 0.
#'
#' @inheritParams check_design_columns
#' @return `NULL`, invisibly.
#' @keywords internal
#' @noRd
check_design_sections <- function(design, call) {
  sections <- design[["sections"]]
  # add_sections() refuses bus-route and ice designs (GH #638), as it does
  # aerial, so every design with sections reaches the checks below.
  if (!is.data.frame(sections)) {
    return(invisible(NULL))
  }
  section_col <- design[["section_col"]]
  if (!is.character(section_col) || length(section_col) != 1L) {
    cli::cli_abort(
      c(
        "The design has sections but no section column.",
        "x" = "{.field design$section_col} is missing, though {.code design$sections} is set.",
        "i" = "Restore it, or register the sections again on a fresh {.fn creel_design}."
      ),
      class = c("creel_error_design_column_missing", "creel_error"),
      call = call
    )
  }
  if (!section_col %in% names(sections)) {
    return(invisible(NULL)) # check_table_columns() names this one
  }
  registered <- sections[[section_col]]
  tables <- c("counts", "interviews", "refused_interviews", "excluded_interviews")
  for (table in tables) {
    data <- design[[table]]
    if (!is.data.frame(data)) {
      next
    }
    if (!section_col %in% names(data)) {
      cli::cli_abort(
        c(
          "The design has sections, but its {.field {table}} table has no section column.",
          "x" = "{.code design${table}} has no column {.val {section_col}}.",
          "i" = paste(
            "A sectioned design splits every table by section. Add the",
            "column, or build the design without {.fn add_sections}."
          )
        ),
        class = c("creel_error_design_column_missing", "creel_error"),
        call = call
      )
    }
    unregistered <- setdiff(unique(data[[section_col]]), registered)
    if (length(unregistered) > 0L) {
      cli::cli_abort(
        c(
          "The design's {.field {table}} table has a section it does not register.",
          "x" = "Not in {.code design$sections}: {.val {unregistered}}.",
          "i" = "Registered sections: {.val {registered}}.",
          "i" = paste(
            "Was a section dropped from {.code design$sections} or relabelled",
            "after it was attached? Restore it, or attach the edited tables to",
            "a fresh {.fn creel_design}."
          )
        ),
        class = c("creel_error_design_section_unregistered", "creel_error"),
        call = call
      )
    }
  }
  invisible(NULL)
}

check_table_columns <- function(design, table, fields, call) {
  data <- design[[table]]
  if (!is.data.frame(data)) {
    return(invisible(NULL))
  }
  for (field in fields) {
    cols <- design[[field]]
    if (!is.character(cols) || length(cols) == 0L) {
      next
    }
    missing <- setdiff(cols, names(data))
    if (length(missing) > 0L) {
      cli::cli_abort(
        c(
          "The design names a column its {.field {table}} table does not have.",
          "x" = paste(
            "{.field design${field}} is {.val {missing}}, which is not a",
            "column of {.code design${table}}."
          ),
          "i" = paste(
            "Was the column dropped or renamed after it was attached?",
            "Restore it, or attach the edited table to a fresh",
            "{.fn creel_design}."
          )
        ),
        class = c("creel_error_design_column_missing", "creel_error"),
        call = call
      )
    }
  }
  invisible(NULL)
}
