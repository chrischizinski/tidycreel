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
#' @export
season_summary <- function(estimates, ...) {
  NULL
}
