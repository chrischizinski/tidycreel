# season-summary.R — Season summary assembly
# Phase 51: REPT-01

# ---- season_summary ----------------------------------------------------------

#' Assemble pre-computed creel estimates into a report-ready wide tibble
#'
#' Accepts a named list of pre-computed \code{creel_estimates} objects (from
#' \code{estimate_effort()}, \code{estimate_catch_rate()}, etc.) and joins them
#' into a single wide tibble — one row per stratum with all estimate types as
#' prefixed columns.
#'
#' \strong{Note:} \code{season_summary()} performs no re-estimation. All
#' statistical computations must be done before calling this function.
#'
#' @param estimates A named list of \code{creel_estimates} objects. Names become
#'   column prefixes in the wide tibble (e.g., \code{list(effort = ..., cpue = ...)}).
#' @param ... Reserved for future arguments.
#'
#' @return A \code{creel_season_summary} object (S3 list) with:
#'   \itemize{
#'     \item \code{$table}: A wide tibble — columns prefixed by list element name.
#'     \item \code{$names}: Character vector of input list element names.
#'     \item \code{$n_estimates}: Integer count of estimates assembled.
#'   }
#'
#' @examples
#' \dontrun{
#' result <- season_summary(list(effort = my_effort, cpue = my_cpue))
#' result$table
#' write_schedule(result$table, "season_2024.csv")
#' }
#'
#' @importFrom dplyr rename_with all_of left_join bind_cols
#' @importFrom cli cli_abort cli_format_method cli_h1 cli_text
#' @family "Reporting & Diagnostics"
#' @export
season_summary <- function(estimates, ...) {
  # Input guard: must be a named list
  is_named_list <- is.list(estimates) && !is.null(names(estimates))
  if (!is_named_list) {
    cli::cli_abort(
      c(
        "{.arg estimates} must be a named list of {.cls creel_estimates} objects.",
        "i" = "Provide names via {.code list(effort = ..., cpue = ...)}."
      )
    )
  }

  # Check each element is a creel_estimates object
  is_creel <- vapply(estimates, inherits, logical(1), "creel_estimates")
  if (!all(is_creel)) {
    bad <- names(estimates)[!is_creel] # nolint: object_usage_linter
    cli::cli_abort(
      c(
        "All elements of {.arg estimates} must be {.cls creel_estimates} objects.",
        "x" = "Element{?s} {.val {bad}} {?is/are} not {.cls creel_estimates}."
      )
    )
  }

  # by_vars consistency guard
  by_vars_list <- lapply(estimates, function(x) x$by_vars)
  first_by <- by_vars_list[[1]]
  all_consistent <- all(vapply(by_vars_list, function(bv) {
    identical(bv, first_by)
  }, logical(1)))
  if (!all_consistent) {
    cli::cli_abort(
      c(
        "All {.arg estimates} must have the same {.field by_vars} grouping structure.",
        "i" = "Pass estimates that were all computed with the same stratification variables."
      )
    )
  }

  strata_cols <- if (is.null(first_by)) character(0) else first_by

  # assemble_wide: prefix non-strata columns with the list element name
  prefix_rename <- function(nm, tbl) {
    value_cols <- setdiff(names(tbl), strata_cols)
    dplyr::rename_with(tbl, ~ paste0(nm, "_", .), .cols = dplyr::all_of(value_cols))
  }

  tables <- Map(prefix_rename, names(estimates), lapply(estimates, `[[`, "estimates"))

  # Join strategy: bind_cols when no strata (single-row tibbles), left_join otherwise
  wide <- if (length(strata_cols) == 0) {
    dplyr::bind_cols(tables)
  } else {
    Reduce(
      function(a, b) dplyr::left_join(a, b, by = intersect(names(a), names(b))),
      tables
    )
  }

  effort_targets <- vapply(estimates, function(x) {
    x$effort_target %||% NA_character_
  }, character(1))

  new_creel_season_summary(
    table          = wide,
    names          = names(estimates),
    n_estimates    = length(estimates),
    effort_targets = effort_targets
  )
}

# ---- new_creel_season_summary ------------------------------------------------

new_creel_season_summary <- function(table, names, n_estimates,
                                     effort_targets = character(0)) {
  structure(
    list(
      table = table,
      names = names,
      n_estimates = n_estimates,
      effort_targets = effort_targets
    ),
    class = "creel_season_summary"
  )
}

# ---- format / print ----------------------------------------------------------

#' Format a creel_season_summary object
#'
#' @param x A \code{creel_season_summary} object.
#' @param ... Additional arguments (unused).
#'
#' @return A character vector.
#'
#' @export
format.creel_season_summary <- function(x, ...) {
  n <- x$n_estimates # nolint: object_usage_linter
  nms <- paste(x$names, collapse = ", ") # nolint: object_usage_linter
  effort_targets <- x$effort_targets
  effort_target_lines <- if (length(effort_targets) > 0) {
    effort_targets <- effort_targets[!is.na(effort_targets)]
    if (length(effort_targets) > 0) {
      paste0(names(effort_targets), "=", unname(effort_targets))
    } else {
      character(0)
    }
  } else {
    character(0)
  }

  header <- cli::cli_format_method({
    cli::cli_h1("Season Summary")
    cli::cli_text("{n} estimate{?s}: {nms}")
    if (length(effort_target_lines) > 0) {
      cli::cli_text("Effort targets: {paste(effort_target_lines, collapse = ', ')}")
    }
    cli::cli_text("")
  })
  table_output <- utils::capture.output(print(x$table))
  c(header, table_output)
}

#' Print a creel_season_summary object
#'
#' @param x A \code{creel_season_summary} object.
#' @param ... Additional arguments passed to \code{format()}.
#'
#' @return \code{x}, invisibly.
#'
#' @export
print.creel_season_summary <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
