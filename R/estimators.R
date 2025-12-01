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

#' Estimate Fishing Effort
#'
#' Estimates total fishing effort (angler-hours or party-hours) by strata
#' and overall, using the survey design weights. Supports both access-point
#' and roving survey designs.
#'
#' @param design A creel design object created by \code{\link{design_access}},
#'   \code{\link{design_roving}}, or \code{\link{design_repweights}}.
#' @param by Character vector of variables to group estimates by. Default
#'   is the strata variables defined in the design.
#' @param total Logical, whether to include overall total estimate in addition
#'   to grouped estimates. Default TRUE.
#' @param level Confidence level for confidence intervals. Default 0.95.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{group_vars}{Grouping variables as a list column}
#'     \item{n}{Number of interviews in group}
#'     \item{effort_estimate}{Estimated total effort}
#'     \item{effort_se}{Standard error of effort estimate}
#'     \item{effort_lower}{Lower confidence limit}
#'     \item{effort_upper}{Upper confidence limit}
#'     \item{design_type}{Type of survey design used}
#'     \item{estimation_method}{Method used for estimation}
#'   }
#'
#' @importFrom stats as.formula
#' @export
#'
#' @examples
#' \dontrun{
#' # Create design
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv",
#'   package = "tidycreel"
#' ))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv",
#'   package = "tidycreel"
#' ))
#'
#' design <- design_access(interviews = interviews, calendar = calendar)
#'
#' # Estimate effort by date
#' effort_by_date <- estimate_effort(design, by = "date")
#'
#' # Estimate effort by location and mode
#' effort_by_location_mode <- estimate_effort(design, by = c("location", "mode"))
#' }
estimate_effort <- function(design, by = NULL, total = TRUE, level = 0.95) {
  cli::cli_abort(c(
    "x" = "estimate_effort() is deprecated.",
    "i" = "Use est_effort(design, counts, method = 'instantaneous' | 'progressive').",
    "i" = "See vignettes for the new survey-first workflow."
  ))
}

#' Estimate Catch Per Unit Effort (CPUE)
#'
#' Estimates catch per unit effort by species, mode, or other grouping variables.
#' Supports both number-based (fish per hour) and weight-based (kg per hour) CPUE.
#'
#' @param design A creel design object created by \code{\link{design_access}},
#'   \code{\link{design_roving}}, or \code{\link{design_repweights}}.
#' @param by Character vector of variables to group estimates by. Default
#'   is to estimate overall CPUE.
#' @param species Character vector of species to include. If NULL, includes
#'   all species in the data.
#' @param type Character, either "number" (fish per hour) or "weight"
#'   (kg per hour). Default "number".
#' @param level Confidence level for confidence intervals. Default 0.95.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{group_vars}{Grouping variables as a list column}
#'     \item{n}{Number of interviews in group}
#'     \item{cpue_estimate}{Estimated CPUE}
#'     \item{cpue_se}{Standard error of CPUE estimate}
#'     \item{cpue_lower}{Lower confidence limit}
#'     \item{cpue_upper}{Upper confidence limit}
#'     \item{species}{Species included in estimate}
#'     \item{type}{Type of CPUE (number or weight)}
#'     \item{design_type}{Type of survey design used}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Estimate CPUE by species
#' cpue_by_species <- estimate_cpue(design, by = "target_species")
#'
#' # Estimate weight-based CPUE for bass
#' bass_cpue_weight <- estimate_cpue(design, species = "bass", type = "weight")
#' }
estimate_cpue <- function(design, by = NULL, species = NULL, type = c("number", "weight"), level = 0.95) {
  cli::cli_abort(c(
    "x" = "estimate_cpue() is deprecated.",
    "i" = "Planned replacement: survey-first CPUE via svyratio with tidy returns (coming next)."
  ))
}

#' Estimate Total Harvest
#'
#' Estimates total harvest (catch kept) by species, mode, or other grouping
#' variables. Supports both number-based (count) and weight-based (kg) harvest.
#'
#' @param design A creel design object created by \code{\link{design_access}},
#'   \code{\link{design_roving}}, or \code{\link{design_repweights}}.
#' @param by Character vector of variables to group estimates by. Default
#'   is to estimate overall harvest.
#' @param species Character vector of species to include. If NULL, includes
#'   all species in the data.
#' @param type Character, either "number" (count) or "weight" (kg).
#'   Default "number".
#' @param level Confidence level for confidence intervals. Default 0.95.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{group_vars}{Grouping variables as a list column}
#'     \item{n}{Number of interviews in group}
#'     \item{harvest_estimate}{Estimated total harvest}
#'     \item{harvest_se}{Standard error of harvest estimate}
#'     \item{harvest_lower}{Lower confidence limit}
#'     \item{harvest_upper}{Upper confidence limit}
#'     \item{species}{Species included in estimate}
#'     \item{type}{Type of harvest (number or weight)}
#'     \item{design_type}{Type of survey design used}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Estimate harvest by species
#' harvest_by_species <- estimate_harvest(design, by = "target_species")
#'
#' # Estimate weight-based harvest for walleye
#' walleye_harvest_weight <- estimate_harvest(design, species = "walleye", type = "weight")
#' }
estimate_harvest <- function(design, by = NULL, species = NULL, type = c("number", "weight"), level = 0.95) {
  cli::cli_abort(c(
    "x" = "estimate_harvest() is deprecated.",
    "i" = "Planned replacement: survey-first catch/harvest estimators aligned with new outputs."
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
#' # Build a day-level design from a calendar
#' svy_day <- as_day_svydesign(calendar, day_id = "date",
#'   strata_vars = c("day_type","month"))
#'
#' # Instantaneous effort by location
#' est_effort(svy_day, counts_inst, method = "instantaneous", by = "location")
#'
#' # Progressive effort by location
#' est_effort(svy_day, counts_roving, method = "progressive", by = "location")
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
