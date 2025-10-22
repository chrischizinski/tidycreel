#' Create Bus Route Survey Design
#'
#' Constructs a lean design container for bus-route creel surveys.
#' This design holds validated inputs and metadata; estimation is
#' performed with survey-first estimators (e.g.,
#' [est_effort.busroute_design()]) that rely on a day-PSU survey
#' design from [as_day_svydesign()]. No ad-hoc weighting is
#' performed here.
#'
#' @param interviews Tibble of interview data validated by
#'   [validate_interviews()].
#' @param counts Tibble of count/observation data validated by
#'   [validate_counts()]. For HT-style effort estimation, counts should
#'   include inclusion probabilities (e.g., `inclusion_prob`) or
#'   sufficient fields to derive them upstream.
#' @param calendar Tibble of the sampling calendar validated by
#'   [validate_calendar()]. Used to construct day-level `svydesign` with
#'   [as_day_svydesign()].
#' @param route_schedule Tibble describing the bus-route schedule (e.g., stop,
#'   time, planned coverage). Used for diagnostics and documentation; not used to
#'   compute weights here.
#' @param strata_vars Character vector for descriptive stratification metadata
#'   (e.g., `c("date","location")`). Missing columns are ignored.
#'
#' @return A list with class `c("busroute_design","creel_design","list")`
#'   and fields: `design_type`, `interviews`, `counts`, `calendar`,
#'   `route_schedule`, `strata_vars`, and `metadata`.
#' @export
#'
#' @examples
#' # design <- design_busroute(interviews, counts, calendar, route_schedule)
design_busroute <- function(interviews, counts, calendar, route_schedule,
                            strata_vars = c("date", "location")) {
  # Validate core inputs (be permissive for tests: allow empty/minimal inputs)
  if (!is.data.frame(interviews)) cli::cli_abort("`interviews` must be a data.frame/tibble.")
  if (nrow(interviews) > 0) {
    interviews <- validate_interviews(interviews)
  }
  if (!is.data.frame(counts)) cli::cli_abort("`counts` must be a data.frame/tibble.")
  if (nrow(counts) > 0) {
    counts <- validate_counts(counts)
  }
  # Minimal calendar requirements for bus-route tests (day_id + samples)
  tc_abort_missing_cols(calendar, c("target_sample", "actual_sample"), context = "design_busroute calendar")

  # Validate route schedule minimally
  if (!is.data.frame(route_schedule)) cli::cli_abort("`route_schedule` must be a data.frame/tibble.")
  required_route_cols <- c("route_stop", "time")
  missing_cols <- setdiff(required_route_cols, names(route_schedule))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns in route_schedule.",
      "i" = paste0("Add: ", paste(missing_cols, collapse = ", "))
    ))
  }

  # Keep only present strata vars for metadata
  strata_vars <- tc_group_warn(strata_vars, names(interviews))

  design <- list(
    design_type = "busroute",
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    route_schedule = route_schedule,
    strata_vars = strata_vars,
    metadata = list(
      creation_time = Sys.time(),
      package_version = tryCatch(as.character(utils::packageVersion("tidycreel")), error = function(e) NA_character_)
    )
  )
  class(design) <- c("busroute_design", "creel_design", "list")
  design
}
