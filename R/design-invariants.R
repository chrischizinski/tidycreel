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

# Fields that name one or more columns of design$counts. Two count fields are
# not here because add_counts() consumes their column: period_length_col is
# multiplied into the count and dropped, and count_time_col stays only in
# design$within_day_counts once within-day counts are collapsed to one row per
# day.
design_count_column_fields <- c("count_col", "psu_col", "unit_cols")

# Fields that name one or more columns of design$interviews.
design_interview_column_fields <- c(
  "catch_col", "effort_col", "harvest_col", "trip_status_col",
  "trip_duration_col", "trip_start_col", "interview_time_col",
  "angler_effort_col", "n_anglers_col", "angler_type_col",
  "angler_method_col", "species_sought_col", "n_counted_col",
  "n_interviewed_col"
)

#' Check that each column a design names is in the table it names
#'
#' @param design A creel_design.
#' @param tables Which tables to check: `"counts"`, `"interviews"`, or both.
#' @param call Environment for the error's call.
#' @return `design`, invisibly. Aborts with class
#'   `creel_error_design_column_missing` naming the field and the column.
#' @keywords internal
#' @noRd
check_design_columns <- function(design, tables = c("counts", "interviews"),
                                 call = rlang::caller_env()) {
  if ("counts" %in% tables) {
    check_table_columns(design, "counts", design_count_column_fields, call)
  }
  if ("interviews" %in% tables) {
    check_table_columns(design, "interviews", design_interview_column_fields, call)
  }
  invisible(design)
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
