# Design steps (GH #438)
#
# A design stores processed tables: counts averaged within each day (and, on a
# night design, moved to their night), interviews joined to the calendar.
# Rebuilding from those would replay processed data through code that expects
# raw data. So creel_design() and each add_*() also record a STEP: the
# function, the arguments the user supplied resolved to plain values (column
# names, numbers, strings), and the table as given. write_design() writes the
# steps; read_design() runs them again with the installed tidycreel, so a
# design saved before a fix is rebuilt with the fix.
#
# Only SUPPLIED arguments are recorded: some functions behave differently when
# an argument is missing (add_interviews() checks missing(n_anglers)), and
# replaying a default as if it had been given would change that.

#' Names of the arguments a call supplied
#'
#' @param call The `match.call()` of the recording function.
#' @param data_args Arguments that carry tables or the design, never recorded.
#' @keywords internal
#' @noRd
supplied_arg_names <- function(call, data_args) {
  setdiff(names(as.list(call))[-1], data_args)
}

#' Append a step to a design
#'
#' @param design The design being returned.
#' @param fn Name of the function that built this step.
#' @param args Named list of every recordable argument, resolved.
#' @param supplied Names of the arguments the caller supplied.
#' @param table_arg Name of the table argument (e.g. `"counts"`).
#' @param table The table as given (after ungrouping).
#' @param extra Named list of further tables the step was given, by argument
#'   name (a bus-route or ice `sampling_frame`); `NULL` when there are none.
#' @keywords internal
#' @noRd
record_step <- function(design, fn, args, supplied, table_arg, table, extra = NULL) {
  args <- args[intersect(names(args), supplied)]
  args <- args[!vapply(args, is.null, logical(1))]
  step <- list(fn = fn, args = args, table_arg = table_arg, table = table)
  extra <- extra[intersect(names(extra), supplied)]
  extra <- extra[!vapply(extra, is.null, logical(1))]
  if (length(extra)) step$extra <- extra
  design$steps <- c(design$steps, list(step))
  design
}
