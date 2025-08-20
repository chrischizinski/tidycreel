# (removed problematic assignment of subset)
#' Core Estimators for Creel Survey Analysis
#'
#' These functions provide design-based estimation of fishing effort,
#' catch per unit effort (CPUE), and harvest totals for creel surveys.
#' All estimators integrate with survey design objects created by the
#' design constructors.
#'
#' @name estimators
#' @aliases estimate_effort estimate_cpue estimate_harvest
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
  # Validate design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a creel design object")
  }

  # Set default grouping variables
  if (is.null(by)) {
    by <- design$strata_vars
  }

  # Calculate effort for each interview
  interviews <- design$interviews
  interviews$effort_observed <- interviews$hours_fished * interviews$party_size

  # Create survey design object
  survey_design <- create_survey_design(design)

  # Group by specified variables
  if (length(by) > 0) {
    group_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    estimates <- survey::svyby(
      ~effort_observed,
      group_formula,
      survey_design,
      survey::svytotal,
      na.rm = TRUE,
      vartype = c("se", "ci"),
      level = level
    )

    # Convert to tibble
    result <- tibble::as_tibble(estimates) %>%
      dplyr::rename(
        effort_estimate = effort_observed,
        effort_se = se,
        effort_lower = `2.5 %`,
        effort_upper = `97.5 %`
      ) %>%
      dplyr::mutate(
        group_vars = purrr::pmap(
          dplyr::across(all_of(by)),
          ~ list(...)
        ),
        n = as.integer(.$count),
        design_type = design$design_type,
        estimation_method = "survey_design"
      ) %>%
      dplyr::select(
        group_vars, n, effort_estimate, effort_se,
        effort_lower, effort_upper, design_type, estimation_method
      )
  } else {
    # Overall total only
    total_est <- survey::svytotal(~effort_observed, survey_design,
      na.rm = TRUE, level = level
    )

    result <- tibble::tibble(
      group_vars = list(NULL),
      n = nrow(interviews),
      effort_estimate = as.numeric(total_est[1, 1]),
      effort_se = as.numeric(sqrt(survey::vcov(total_est)[1, 1])),
      effort_lower = as.numeric(confint(total_est)[1, 1]),
      effort_upper = as.numeric(confint(total_est)[2, 1]),
      design_type = design$design_type,
      estimation_method = "survey_design"
    )
  }

  # Add total if requested and grouping is used
  if (total && length(by) > 0) {
    total_result <- estimate_effort(design, by = NULL, total = FALSE, level = level)
    result <- dplyr::bind_rows(result, total_result)
  }

  return(result)
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
  # Validate design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a creel design object")
  }

  type <- match.arg(type, c("number", "weight"))

  # Filter interviews if species specified
  interviews <- design$interviews
  if (!is.null(species)) {
    interviews <- interviews[interviews$target_species %in% species, ]
    if (nrow(interviews) == 0) {
      cli::cli_warn("No interviews found for specified species")
      return(tibble::tibble())
    }
  }

  # Calculate catch and effort for each interview
  interviews$effort_observed <- interviews$hours_fished * interviews$party_size

  if (type == "number") {
    interviews$catch_observed <- interviews$catch_total
  } else {
    interviews$catch_observed <- interviews$weight_total
  }

  # Create survey design object
  survey_design <- create_survey_design(design)

  # Group by specified variables
  if (length(by) > 0) {
    group_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    estimates <- survey::svyby(
      ~catch_observed,
      group_formula,
      survey_design,
      survey::svyratio,
      denominator = ~effort_observed,
      na.rm = TRUE,
      vartype = c("se", "ci"),
      level = level
    )

    # Convert to tibble
    result <- tibble::as_tibble(estimates) %>%
      dplyr::rename(
        cpue_estimate = catch_observed,
        cpue_se = se,
        cpue_lower = `2.5 %`,
        cpue_upper = `97.5 %`
      ) %>%
      dplyr::mutate(
        group_vars = purrr::pmap(
          dplyr::across(all_of(by)),
          ~ list(...)
        ),
        n = as.integer(.$count),
        species = if (is.null(species)) "all" else paste(species, collapse = ", "),
        type = type,
        design_type = design$design_type
      ) %>%
      dplyr::select(
        group_vars, n, cpue_estimate, cpue_se,
        cpue_lower, cpue_upper, species, type, design_type
      )
  } else {
    # Overall CPUE
    ratio_est <- survey::svyratio(
      ~catch_observed,
      ~effort_observed,
      survey_design,
      na.rm = TRUE,
      level = level
    )

    result <- tibble::tibble(
      group_vars = list(NULL),
      n = nrow(interviews),
      cpue_estimate = as.numeric(ratio_est[1]),
      cpue_se = as.numeric(sqrt(survey::vcov(ratio_est)[1, 1])),
      cpue_lower = as.numeric(confint(ratio_est)[1, 1]),
      cpue_upper = as.numeric(confint(ratio_est)[2, 1]),
      species = if (is.null(species)) "all" else paste(species, collapse = ", "),
      type = type,
      design_type = design$design_type
    )
  }

  return(result)
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
  # Validate design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a creel design object")
  }

  type <- match.arg(type, c("number", "weight"))

  # Filter interviews if species specified
  interviews <- design$interviews
  if (!is.null(species)) {
    interviews <- interviews[interviews$target_species %in% species, ]
    if (nrow(interviews) == 0) {
      cli::cli_warn("No interviews found for specified species")
      return(tibble::tibble())
    }
  }

  # Calculate harvest for each interview
  if (type == "number") {
    interviews$harvest_observed <- interviews$catch_kept
  } else {
    # Weight-based harvest - approximate as proportion of total weight
    interviews$harvest_observed <- interviews$weight_total *
      (interviews$catch_kept / pmax(interviews$catch_total, 1))
  }

  # Create survey design object
  survey_design <- create_survey_design(design)

  # Group by specified variables
  if (length(by) > 0) {
    group_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    estimates <- survey::svyby(
      ~harvest_observed,
      group_formula,
      survey_design,
      survey::svytotal,
      na.rm = TRUE,
      vartype = c("se", "ci"),
      level = level
    )

    # Convert to tibble
    result <- tibble::as_tibble(estimates) %>%
      dplyr::rename(
        harvest_estimate = harvest_observed,
        harvest_se = se,
        harvest_lower = `2.5 %`,
        harvest_upper = `97.5 %`
      ) %>%
      dplyr::mutate(
        group_vars = purrr::pmap(
          dplyr::across(all_of(by)),
          ~ list(...)
        ),
        n = as.integer(.$count),
        species = if (is.null(species)) "all" else paste(species, collapse = ", "),
        type = type,
        design_type = design$design_type
      ) %>%
      dplyr::select(
        group_vars, n, harvest_estimate, harvest_se,
        harvest_lower, harvest_upper, species, type, design_type
      )
  } else {
    # Overall harvest
    total_est <- survey::svytotal(~harvest_observed, survey_design,
      na.rm = TRUE, level = level
    )

    result <- tibble::tibble(
      group_vars = list(NULL),
      n = nrow(interviews),
      harvest_estimate = as.numeric(total_est[1, 1]),
      harvest_se = as.numeric(sqrt(survey::vcov(total_est)[1, 1])),
      harvest_lower = as.numeric(confint(total_est)[1, 1]),
      harvest_upper = as.numeric(confint(total_est)[2, 1]),
      species = if (is.null(species)) "all" else paste(species, collapse = ", "),
      type = type,
      design_type = design$design_type
    )
  }

  return(result)
}

#' Estimate fishing effort from survey data
#'
#' Supports both instantaneous (snapshot) and progressive (interval) count methods.
#' Returns a tibble with effort estimates, standard errors, confidence intervals, and metadata.
#'
#' @param design Survey design object (creel_design or svydesign)
#' @param counts Data frame or tibble with count data (must include time, count, party_size, stratum, etc.)
#' @param method Character string: 'instantaneous' or 'progressive'
#' @param ... Additional arguments for future extensibility
#' @param by Character vector of variables to group by. Default NULL, which uses the strata variables.
#' @param conf_level Confidence level for confidence intervals. Default 0.95.
#'
#' @return Tibble/data.frame with columns: stratum, estimate, SE, CI_low, CI_high, n, method, diagnostics
#' @examples
#' # Example usage:
#' # est_effort(design, counts, method = 'instantaneous')
#' # est_effort(design, counts, method = 'progressive')
#' @export
est_effort <- function(design, counts, method = c('instantaneous', 'progressive'), by = NULL, conf_level = 0.95, ...) {
  method <- match.arg(method)

  # Extract survey design object if input is creel_design
  if (inherits(design, "creel_design")) {
    svy <- as_survey_design(design)
    design_type <- design$design_type
    strata_vars <- design$strata_vars
    metadata <- design$metadata
  } else if (inherits(design, "svydesign")) {
    svy <- design
    design_type <- "svydesign"
    strata_vars <- NULL
    metadata <- NULL
  } else {
    stop("Input 'design' must be a creel_design or svydesign object.")
  }

  # Determine grouping variables
  if (is.null(by)) {
    by <- strata_vars
  }
  if (is.null(by) || length(by) == 0) {
    by <- "stratum"
  }

  # Validate counts input
  required_cols <- c("time", "count", "party_size")
  missing_cols <- setdiff(required_cols, names(counts))
  if (length(missing_cols) > 0) {
    stop("Counts data is missing required columns: ", paste(missing_cols, collapse=", "))
  }

  # Group by user-specified or design strata
  grouped <- counts %>%
    dplyr::group_by(across(all_of(by))) %>%
    dplyr::summarise(
      mean_count = mean(count, na.rm = TRUE),
      sd_count = sd(count, na.rm = TRUE),
      min_count = min(count, na.rm = TRUE),
      max_count = max(count, na.rm = TRUE),
      n_counts = dplyr::n(),
      mean_party_size = mean(party_size, na.rm = TRUE),
      time_interval = max(time, na.rm = TRUE) - min(time, na.rm = TRUE)
    )

  if (method == 'instantaneous') {
    # Effort: mean count × time interval / mean party size
    grouped <- grouped %>%
      dplyr::mutate(
        effort_estimate = mean_count * time_interval / mean_party_size
      )
    # Variance estimation using survey package
    # For each group, use svymean for count and propagate variance
    se_list <- lapply(split(counts, counts[by]), function(df) {
      if (nrow(df) > 0) {
  idx <- Reduce(`&`, lapply(by, function(v) svy$variables[[v]] == df[[v]][1]))
  svy_g <- subset(svy, idx)
        est <- tryCatch(survey::svymean(~count, svy_g, na.rm=TRUE), error=function(e) NA)
        se <- if (!is.na(est[1])) as.numeric(attr(est, "var"))^0.5 else NA_real_
        ci <- if (!is.na(est[1])) as.numeric(confint(est, level=conf_level)) else c(NA_real_, NA_real_)
        list(se=se, ci_low=ci[1], ci_high=ci[2])
      } else {
        list(se=NA_real_, ci_low=NA_real_, ci_high=NA_real_)
      }
    })
    grouped$effort_se <- vapply(se_list, function(x) x$se, numeric(1))
    grouped$effort_ci_low <- vapply(se_list, function(x) x$ci_low, numeric(1))
    grouped$effort_ci_high <- vapply(se_list, function(x) x$ci_high, numeric(1))
    return(grouped)
  } else if (method == 'progressive') {
    progressive_effort <- counts %>%
      dplyr::group_by(across(all_of(by))) %>%
      dplyr::arrange(time) %>%
      dplyr::mutate(
        interval = dplyr::lead(time) - time
      ) %>%
      dplyr::summarise(
        effort_estimate = sum(count * interval, na.rm = TRUE) / mean(party_size, na.rm = TRUE),
        n_counts = dplyr::n(),
        mean_count = mean(count, na.rm = TRUE),
        sd_count = sd(count, na.rm = TRUE),
        min_count = min(count, na.rm = TRUE),
        max_count = max(count, na.rm = TRUE)
      )
    # Variance estimation placeholder (similar logic as above)
    progressive_effort <- progressive_effort %>%
      dplyr::mutate(
        effort_se = NA_real_,
        effort_ci_low = NA_real_,
        effort_ci_high = NA_real_
      )
    return(progressive_effort)
  } else {
    stop('Unknown method: ', method)
  }
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
