# (removed problematic assignment of subset)
#' Core Estimators for Creel Survey Analysis
#'
#' These functions provide design-based estimation of fishing effort,
#' catch per unit effort (CPUE), and harvest totals for creel surveys.
#' All estimators integrate with survey design objects created by the
#' design constructors.
#'
#' @name estimators
NULL

#' Estimate fishing effort (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#' 
#' This function is deprecated. Use the survey-first workflow with 
#' [as_day_svydesign()] and [est_effort()] instead.
#'
#' @param design Survey design object
#' @param by Grouping variables (optional)
#' @param total Whether to include totals
#' @param level Confidence level
#'
#' @return Throws an error directing users to the new workflow
#' @export
#'
#' @seealso [as_day_svydesign()], [est_effort()], `vignette("effort_survey_first", package = "tidycreel")`
estimate_effort <- function(design, by = NULL, total = TRUE, level = 0.95) {
  cli::cli_abort(c(
    "x" = "estimate_effort() is deprecated.",
    "i" = "Use the survey-first workflow: as_day_svydesign() + est_effort().",
    "i" = "See vignette('effort_survey_first', package = 'tidycreel') for examples."
  ))
}

#' Estimate catch per unit effort (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#' 
#' This function is deprecated. Use [est_cpue()] with a survey design instead.
#'
#' @param design Survey design object
#' @param by Grouping variables (optional)
#' @param species Species filter (optional)
#' @param type Type of catch ("number" or "weight")
#' @param level Confidence level
#'
#' @return Throws an error directing users to the new workflow
#' @export
#'
#' @seealso [est_cpue()], `vignette("cpue_catch", package = "tidycreel")`
estimate_cpue <- function(design, by = NULL, species = NULL, type = c("number", "weight"), level = 0.95) {
  cli::cli_abort(c(
    "x" = "estimate_cpue() is deprecated.",
    "i" = "Use est_cpue(svy_design, by = ..., response = 'catch_total').",
    "i" = "See vignette('cpue_catch', package = 'tidycreel') for examples."
  ))
}

#' Estimate harvest (deprecated)
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#' 
#' This function is deprecated. Use [est_catch()] with a survey design instead.
#'
#' @param design Survey design object
#' @param by Grouping variables (optional)
#' @param species Species filter (optional)
#' @param type Type of catch ("number" or "weight")
#' @param level Confidence level
#'
#' @return Throws an error directing users to the new workflow
#' @export
#'
#' @seealso [est_catch()], `vignette("cpue_catch", package = "tidycreel")`
estimate_harvest <- function(design, by = NULL, species = NULL, type = c("number", "weight"), level = 0.95) {
  cli::cli_abort(c(
    "x" = "estimate_harvest() is deprecated.",
    "i" = "Use est_catch(svy_design, by = ..., response = 'catch_kept').",
    "i" = "See vignette('cpue_catch', package = 'tidycreel') for examples."
  ))
}

#' Estimate Fishing Effort (survey-first wrapper)
#'
#' High-level convenience wrapper that delegates to the survey-first
#' instantaneous or progressive estimators. It ensures a valid day-level
#' survey design is available and passes it to the appropriate estimator.
#'
#' Effort is computed as day × group totals and combined using
#' `survey::svytotal`/`survey::svyby`, with variance from the survey design
#' (including replicate-weight designs via `svrepdesign`).
#'
#' @param design A day-level `svydesign`/`svrepdesign` or a `creel_design`
#'   that contains a `calendar` for constructing a day PSU design.
#' @param counts Data frame/tibble of counts appropriate for the chosen
#'   `method`.
#' @param method One of `"instantaneous"` (snapshot counts) or
#'   `"progressive"` (roving/pass-based counts).
#' @param by Character vector of grouping variables present in `counts`. If
#'   `NULL`, a best-effort default is used (e.g., `location`, `stratum`,
#'   `shift_block` where available).
#' @param day_id Day identifier (PSU) present in both `counts` and the survey
#'   design (default `"date"`).
#' @param covariates Optional character vector of additional grouping variables
#'   present in `counts`.
#' @param conf_level Confidence level for CIs (default 0.95).
#' @param ... Forwarded to the specific estimator.
#'
#' @return A tibble with group columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#'
#' @seealso [est_effort.instantaneous()], [est_effort.progressive()],
#'   [as_day_svydesign()], [survey::svydesign()], [survey::svrepdesign()].
#'
#' @examples
#' \dontrun{
#' # Load toy datasets
#' calendar <- read.csv(system.file("extdata", "toy_calendar.csv", package = "tidycreel"))
#' counts <- read.csv(system.file("extdata", "toy_counts.csv", package = "tidycreel"))
#'
#' # Build a day-level design from calendar
#' svy_day <- as_day_svydesign(calendar, day_id = "date",
#'   strata_vars = c("day_type", "month"))
#'
#' # Instantaneous effort by location
#' effort_est <- est_effort(svy_day, counts, method = "instantaneous", by = "location")
#' print(effort_est)
#' }
#' @export
est_effort <- function(design,
                       counts,
                       method = c('instantaneous', 'progressive'),
                       by = NULL,
                       day_id = "date",
                       covariates = NULL,
                       conf_level = 0.95,
                       ...) {
  method <- match.arg(method)

  # Derive a day-level svy design
  if (inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    svy_day <- design
  } else if (inherits(design, "creel_design")) {
    if (is.null(design$calendar)) {
      cli::cli_abort("creel_design must contain a $calendar to build a day-level survey design.")
    }
    cal <- design$calendar
    strata_vars <- intersect(c("day_type", "month", "season", "weekend"), names(cal))
    svy_day <- as_day_svydesign(cal, day_id = day_id, strata_vars = strata_vars)
  } else {
    cli::cli_abort("design must be a day-level svydesign/svrepdesign or a creel_design with $calendar.")
  }

  if (is.null(by)) {
    by <- intersect(c("location", "stratum", "shift_block"), names(counts))
  }

  if (method == 'instantaneous') {
    return(est_effort.instantaneous(
      counts = counts,
      by = by,
      minutes_col = c("interval_minutes", "count_duration", "flight_minutes"),
      total_minutes_col = c("total_minutes", "total_day_minutes", "block_total_minutes"),
      day_id = day_id,
      covariates = covariates,
      svy = svy_day,
      conf_level = conf_level
    ))
  }

  if (method == 'progressive') {
    return(est_effort.progressive(
      counts = counts,
      by = by,
      route_minutes_col = c("route_minutes", "circuit_minutes"),
      pass_id = c("pass_id", "circuit_id"),
      day_id = day_id,
      covariates = covariates,
      svy = svy_day,
      conf_level = conf_level
    ))
  }

  cli::cli_abort(paste0('Unknown method: ', method))
}

# Helper function to create survey design objects
create_survey_design <- function(design) {
  if (inherits(design, "repweights_design")) {
    # Use replicate weights design
    survey_design <- survey::svrepdesign(
      data = design$base_design$interviews,
      weights = design$base_design$design_weights,
      repweights = design$replicate_weights,
      type = switch(design$replicate_method,
        bootstrap = "bootstrap",
        jackknife = "JK1",
        brr = "BRR"
      ),
      scale = design$scale_factors,
      rscales = 1
    )
  } else {
    # Use standard survey design
    survey_design <- survey::svydesign(
      ids = ~1, # No clustering by default
      strata = as.formula(paste("~", paste(design$strata_vars, collapse = " + "))),
      data = design$interviews,
      weights = design$design_weights
    )
  }

  survey_design
}
