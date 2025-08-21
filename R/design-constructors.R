#' Plot survey design coverage (temporal and spatial)
#'
#' Visualizes the distribution of interviews by date, shift block, and location using ggplot2.
#'
#' @param x A creel_design object
#' @param ... Additional arguments (ignored)
#' @return A ggplot object
#' @export
plot_design <- function(x, ...) {
  if (!inherits(x, "creel_design")) cli::cli_abort("Object must be a creel_design")
  interviews <- x$interviews
  # Try to get location, date, shift_block columns
  if (!all(c("date", "shift_block", "location") %in% names(interviews))) {
    cli::cli_abort(c(
      "x" = "Interviews are missing required columns for plotting.",
      "i" = "Required: 'date', 'shift_block', 'location'"
    ))
  }
  library(ggplot2)
  p <- ggplot(interviews, aes(x = date, fill = shift_block)) +
    geom_bar(position = "dodge") +
    facet_wrap(~location) +
    labs(
      title = "Survey Design Coverage",
      x = "Date",
      y = "Number of Interviews",
      fill = "Shift Block"
    ) +
    theme_minimal()
  return(p)
}
#' @section Design Assumptions:
#' - Random sampling within stratum: Each sampled unit is selected randomly within its stratum.
#' - Strata are correctly defined to reflect true variation in effort and catch.
#' - Complete coverage or known probabilities: All exiting anglers are interviewed, or inclusion probabilities are known.
#' - Nonresponse is random or accounted for.
#' - Effort and catch are accurately reported by anglers.
#' - No double-counting: Each angler or party is counted/interviewed only once per sampling unit.
#' - Replicate weights reflect true sampling variability.
#' Assumptions should be reviewed for each survey design. Violations may require adjustment or bias correction.
#' Print method for creel_design objects
#'
## Print method for creel_design objects
#'
#' Print a summary of a creel_design survey object
#'
#' @name print.creel_design
#' @title Print method for creel_design objects
#' @param x A creel_design object
#' @param ... Additional arguments (ignored)
#' @export
print.creel_design <- function(x, ...) {
  cat("<tidycreel survey design>\n")
  if (!is.null(x$design_type)) cat("Design type:", x$design_type, "\n")
  if (!is.null(x$metadata)) {
    cat("Created:", as.character(x$metadata$creation_time), "\n")
    if (!is.null(x$metadata$package_version)) cat("Package version:", as.character(x$metadata$package_version), "\n")
  }
  if (!is.null(x$strata_vars)) cat("Strata variables:", paste(x$strata_vars, collapse=", "), "\n")
  if (!is.null(x$design_weights)) cat("Design weights: [length=", length(x$design_weights), "]\n", sep="")
  invisible(x)
}

#' Summary method for creel_design objects
#'
#' @param object A creel_design object
#' @param ... Additional arguments (ignored)
#' @export
summary.creel_design <- function(object, ...) {
  out <- list(
    design_type = object$design_type,
    strata_vars = object$strata_vars,
    n_interviews = if (!is.null(object$interviews)) nrow(object$interviews) else NA,
    n_weights = if (!is.null(object$design_weights)) length(object$design_weights) else NA,
    metadata = object$metadata
  )
  class(out) <- "summary.creel_design"
  out
}

#' Print method for summary.creel_design objects
#'
#' @param x A summary.creel_design object
#' @param ... Additional arguments (ignored)
#' @export
print.summary.creel_design <- function(x, ...) {
  cat("<Summary of tidycreel survey design>\n")
  cat("Design type:", x$design_type, "\n")
  cat("Strata variables:", paste(x$strata_vars, collapse=", "), "\n")
  cat("Number of interviews:", x$n_interviews, "\n")
  cat("Number of weights:", x$n_weights, "\n")
  if (!is.null(x$metadata)) {
    cat("Created:", as.character(x$metadata$creation_time), "\n")
    if (!is.null(x$metadata$package_version)) cat("Package version:", as.character(x$metadata$package_version), "\n")
  }
  invisible(x)
}
#' Survey Design Constructors for Access-Point Creel Surveys
#'
#' These functions create survey design objects for different types of
#' access-point creel surveys, including standard access designs, roving
#' designs, and designs with replicate weights.
#'
#' @name design-constructors
#' @aliases design_access design_roving design_repweights
NULL

#' Create Access-Point Survey Design
#'
#' Constructs a survey design object for access-point creel surveys where
#' interviews are conducted at fixed access locations. This design assumes
#' complete coverage of exiting anglers during interview periods.
#'
#' @param interviews A tibble containing interview data validated by
#'   [validate_interviews()]. Must include columns for location, date,
#'   party_size, hours_fished, and effort_expansion.
#' @param calendar A tibble containing calendar data validated by
#'   [validate_calendar()]. Must include columns for date, stratum_id,
#'   target_sample, and actual_sample.
#' @param locations A character vector of sampling locations. If NULL,
#'   uses unique locations from interview data.
#' @param strata_vars Character vector of variables to use for stratification.
#'   Default is c("date", "shift_block").
#' @param weight_method Character specifying weight calculation method.
#'   Options: "standard" (default), "post_stratify", "calibrate".
#'
#' @return A list object of class "access_design" containing:
#'   \describe{
#'     \item{design_type}{Character: "access_point"}
#'     \item{interviews}{Validated interview data}
#'     \item{calendar}{Validated calendar data}
#'     \item{locations}{Sampling locations}
#'     \item{strata_vars}{Stratification variables}
#'     \item{weight_method}{Weight calculation method}
#'     \item{design_weights}{Calculated design weights}
#'     \item{metadata}{Additional metadata including creation time}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load example data
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv",
#'   package = "tidycreel"
#' ))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv",
#'   package = "tidycreel"
#' ))
#'
#' # Create access design
#' design <- design_access(
#'   interviews = interviews,
#'   calendar = calendar,
#'   strata_vars = c("date", "shift_block", "location")
#' )
#' }
design_access <- function(interviews, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block"),
                          weight_method = "standard") {
    # Validate inputs
    interviews <- validate_interviews(interviews)
    calendar <- validate_calendar(calendar)

    # Set locations
    if (is.null(locations)) {
      locations <- unique(interviews$location)
    }

    # --- Location-level mismatch check ---
    interview_locations <- unique(interviews$location)
    calendar_locations <- unique(calendar$location)
    missing_in_interviews <- setdiff(calendar_locations, interview_locations)
    missing_in_calendar <- setdiff(interview_locations, calendar_locations)
    if (length(missing_in_interviews) > 0 || length(missing_in_calendar) > 0) {
      cli::cli_abort(c(
        "x" = "Location mismatch detected between interviews and calendar.",
        if (length(missing_in_interviews) > 0) c("i" = paste0("In calendar, missing in interviews: ", paste(missing_in_interviews, collapse=", "))) else NULL,
        if (length(missing_in_calendar) > 0) c("i" = paste0("In interviews, missing in calendar: ", paste(missing_in_calendar, collapse=", "))) else NULL
      ))
    }

    # Validate weight method
    weight_method <- match.arg(weight_method,
      choices = c("standard", "post_stratify", "calibrate")
    )

    # --- Strata-level mismatch check ---
    interview_strata <- unique(interviews[strata_vars])
    calendar_strata <- unique(calendar[strata_vars])
    # Find missing strata in interviews (present in calendar, not in interviews)
    missing_in_interviews <- dplyr::anti_join(calendar_strata, interview_strata, by = strata_vars)
    # Find missing strata in calendar (present in interviews, not in calendar)
    missing_in_calendar <- dplyr::anti_join(interview_strata, calendar_strata, by = strata_vars)
    if (nrow(missing_in_interviews) > 0 || nrow(missing_in_calendar) > 0) {
      cli::cli_abort(c(
        "x" = "Strata mismatch detected between interviews and calendar.",
        if (nrow(missing_in_interviews) > 0) c("i" = "Some calendar strata are missing from interviews.") else NULL,
        if (nrow(missing_in_calendar) > 0) c("i" = "Some interview strata are missing from calendar.") else NULL
      ))
    }

    # Calculate design weights
    design_weights <- calculate_access_weights(
      interviews = interviews,
      calendar = calendar,
      strata_vars = strata_vars,
      weight_method = weight_method
    )
    interviews$design_weights <- design_weights

    # Build survey design object
    svy_design <- survey::svydesign(
      ids = ~1,
      strata = stats::as.formula(paste("~", paste(strata_vars, collapse = "+"))),
      weights = ~design_weights,
      data = interviews
    )

    # Create design object
    design <- list(
      design_type = "access_point",
      interviews = interviews,
      calendar = calendar,
      locations = locations,
      strata_vars = strata_vars,
      weight_method = weight_method,
      design_weights = design_weights,
      svy_design = svy_design,
      metadata = list(
        creation_time = Sys.time(),
        package_version = utils::packageVersion("tidycreel")
      )
    )

    class(design) <- c("access_design", "creel_design", "list")
    return(design)
}

#' Create Roving Survey Design
#'
#' Constructs a survey design object for roving creel surveys where
#' interviews are conducted while moving between locations. This design
#' accounts for incomplete coverage and requires effort estimation.
#'
#' @param interviews A tibble containing interview data validated by
#'   [validate_interviews()]. Must include columns for location, date,
#'   time_start, time_end, party_size, hours_fished, and effort_expansion.
#' @param counts A tibble containing instantaneous count data validated by
#'   [validate_counts()]. Must include columns for location, date, time,
#'   anglers_count, and parties_count.
#' @param calendar A tibble containing calendar data validated by
#'   [validate_calendar()]. Must include columns for date, stratum_id,
#'   target_sample, and actual_sample.
#' @param locations A character vector of sampling locations. If NULL,
#'   uses union of locations from interview and count data.
#' @param strata_vars Character vector of variables to use for stratification.
#'   Default is c("date", "shift_block", "location").
#' @param effort_method Character specifying effort estimation method.
#'   Options: "ratio" (default), "calibrate", "model_based".
#' @param coverage_correction Logical, whether to apply coverage correction
#'   for incomplete spatial/temporal coverage. Default TRUE.
#'
#' @return A list object of class "roving_design" containing:
#'   \describe{
#'     \item{design_type}{Character: "roving"}
#'     \item{interviews}{Validated interview data}
#'     \item{counts}{Validated count data}
#'     \item{calendar}{Validated calendar data}
#'     \item{locations}{Sampling locations}
#'     \item{strata_vars}{Stratification variables}
#'     \item{effort_method}{Effort estimation method}
#'     \item{coverage_correction}{Whether coverage correction is applied}
#'     \item{design_weights}{Calculated design weights}
#'     \item{effort_estimates}{Estimated fishing effort by stratum}
#'     \item{metadata}{Additional metadata}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Load example data
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv",
#'   package = "tidycreel"
#' ))
#' counts <- readr::read_csv(system.file("extdata/toy_counts.csv",
#'   package = "tidycreel"
#' ))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv",
#'   package = "tidycreel"
#' ))
#'
#' # Create roving design
#' design <- design_roving(
#'   interviews = interviews,
#'   counts = counts,
#'   calendar = calendar,
#'   effort_method = "ratio"
#' )
#' }
design_roving <- function(interviews, counts, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location"),
                          effort_method = "ratio",
                          coverage_correction = TRUE) {
    # Validate inputs
    interviews <- validate_interviews(interviews)
    counts <- validate_counts(counts)
    calendar <- validate_calendar(calendar)

    # Set locations
    if (is.null(locations)) {
      locations <- union(unique(interviews$location), unique(counts$location))
    }

  # --- Location-level mismatch check ---
  interview_locations <- unique(interviews$location)
  count_locations <- unique(counts$location)
  calendar_locations <- unique(calendar$location)
  missing_in_interviews <- setdiff(calendar_locations, interview_locations)
  missing_in_counts <- setdiff(calendar_locations, count_locations)
  missing_in_calendar_from_interviews <- setdiff(interview_locations, calendar_locations)
  missing_in_calendar_from_counts <- setdiff(count_locations, calendar_locations)
  if (
    length(missing_in_interviews) > 0 ||
    length(missing_in_counts) > 0 ||
    length(missing_in_calendar_from_interviews) > 0 ||
    length(missing_in_calendar_from_counts) > 0
  ) {
    cli::cli_abort(c(
      "x" = "Location mismatch detected among interviews, counts, and calendar.",
      if (length(missing_in_interviews) > 0) c("i" = paste0("In calendar, missing in interviews: ", paste(missing_in_interviews, collapse=", "))) else NULL,
      if (length(missing_in_counts) > 0) c("i" = paste0("In calendar, missing in counts: ", paste(missing_in_counts, collapse=", "))) else NULL,
      if (length(missing_in_calendar_from_interviews) > 0) c("i" = paste0("In interviews, missing in calendar: ", paste(missing_in_calendar_from_interviews, collapse=", "))) else NULL,
      if (length(missing_in_calendar_from_counts) > 0) c("i" = paste0("In counts, missing in calendar: ", paste(missing_in_calendar_from_counts, collapse=", "))) else NULL
    ))
  }

  # --- Strata-level mismatch check ---
  interview_strata <- unique(interviews[strata_vars])
  count_strata <- unique(counts[strata_vars])
  calendar_strata <- unique(calendar[strata_vars])
  # Find missing strata in interviews (present in calendar, not in interviews)
  missing_in_interviews <- dplyr::anti_join(calendar_strata, interview_strata, by = strata_vars)
  # Find missing strata in counts (present in calendar, not in counts)
  missing_in_counts <- dplyr::anti_join(calendar_strata, count_strata, by = strata_vars)
  # Find missing strata in calendar (present in interviews or counts, not in calendar)
  missing_in_calendar_from_interviews <- dplyr::anti_join(interview_strata, calendar_strata, by = strata_vars)
  missing_in_calendar_from_counts <- dplyr::anti_join(count_strata, calendar_strata, by = strata_vars)
  if (
    nrow(missing_in_interviews) > 0 ||
    nrow(missing_in_counts) > 0 ||
    nrow(missing_in_calendar_from_interviews) > 0 ||
    nrow(missing_in_calendar_from_counts) > 0
  ) {
    cli::cli_abort(c(
      "x" = "Strata mismatch detected among interviews, counts, and calendar.",
      if (nrow(missing_in_interviews) > 0) c("i" = "Some calendar strata are missing from interviews.") else NULL,
      if (nrow(missing_in_counts) > 0) c("i" = "Some calendar strata are missing from counts.") else NULL,
      if (nrow(missing_in_calendar_from_interviews) > 0) c("i" = "Some interview strata are missing from calendar.") else NULL,
      if (nrow(missing_in_calendar_from_counts) > 0) c("i" = "Some count strata are missing from calendar.") else NULL
    ))
  }

  # Validate methods
  effort_method <- match.arg(
    effort_method,
    choices = c("ratio", "calibrate", "model_based")
  )

  # Calculate effort estimates
  effort_estimates <- calculate_roving_effort(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    strata_vars = strata_vars,
    effort_method = effort_method
  )

  # Calculate design weights
  design_weights <- calculate_roving_weights(
    interviews = interviews,
    effort_estimates = effort_estimates,
    strata_vars = strata_vars
  )
  interviews$design_weights <- design_weights

  # Build survey design object
  svy_design <- survey::svydesign(
    ids = ~1,
    strata = stats::as.formula(paste("~", paste(strata_vars, collapse = "+"))),
    weights = ~design_weights,
    data = interviews
  )

  # Create design object
  design <- list(
    design_type = "roving",
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    effort_method = effort_method,
    coverage_correction = coverage_correction,
    design_weights = design_weights,
    effort_estimates = effort_estimates,
    svy_design = svy_design,
    metadata = list(
      creation_time = Sys.time(),
      package_version = utils::packageVersion("tidycreel")
    )
  )

  class(design) <- c("roving_design", "creel_design", "list")
  design
}

#' Create Survey Design with Replicate Weights
#'
#' Constructs a survey design object that incorporates replicate weights
#' for variance estimation. Supports both access-point and roving designs
#' with bootstrap or jackknife replicate weights.
#'
#' @param base_design A creel design object created by [design_access()] or
#'   [design_roving()].
#' @param replicates Integer specifying number of replicate weights to create.
#'   Default is 100 for bootstrap, or determined by design for jackknife.
#' @param method Character specifying replicate weight method.
#'   Options: "bootstrap" (default), "jackknife", "brr" (balanced repeated replication).
#' @param strata_var Character specifying stratification variable for
#'   replicate creation. If NULL, uses strata from base design.
#' @param cluster_var Character specifying cluster variable for
#'   replicate creation. If NULL, uses location as cluster.
#' @param seed Integer random seed for reproducibility.
#'
#' @return A list object of class "repweights_design" containing:
#'   \describe{
#'     \item{base_design}{Original design object}
#'     \item{replicate_weights}{Matrix of replicate weights}
#'     \item{replicate_method}{Method used to create replicates}
#'     \item{replicates}{Number of replicates}
#'     \item{scale_factors}{Scaling factors for variance estimation}
#'     \item{metadata}{Additional metadata including creation time and seed}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create base design
#' interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv",
#'   package = "tidycreel"
#' ))
#' calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv",
#'   package = "tidycreel"
#' ))
#'
#' base_design <- design_access(interviews = interviews, calendar = calendar)
#'
#' # Add replicate weights
#' rep_design <- design_repweights(
#'   base_design = base_design,
#'   replicates = 50,
#'   method = "bootstrap",
#'   seed = 12345
#' )
#' }
design_repweights <- function(base_design, replicates = NULL,
                              method = "bootstrap", strata_var = NULL,
                              cluster_var = NULL, seed = NULL) {
  # Validate base design
  if (!inherits(base_design, "creel_design")) {
    cli::cli_abort("{.arg base_design} must be a creel design object")
  }

  # Set method

  method <- match.arg(method, choices = c("bootstrap", "jackknife", "brr"))

  # Set seed if provided
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Determine replicates if not specified
  if (is.null(replicates)) {
    replicates <- switch(method,
      bootstrap = 100,
      jackknife = nrow(base_design$interviews),
      brr = max(4, 4 * ceiling(log2(nrow(base_design$interviews))))
    )
  }

  # Set stratification and clustering variables
  if (is.null(strata_var)) {
    strata_var <- base_design$strata_vars
  }
  if (is.null(cluster_var)) {
    cluster_var <- "location"
  }

  # Create replicate weights
  replicate_weights <- create_replicate_weights(
    base_design = base_design,
    replicates = replicates,
    method = method,
    strata_var = strata_var,
    cluster_var = cluster_var
  )

  # Compute scale factor(s) and build svrepdesign
  scale_factors <- calculate_scale_factors(method, replicates, base_design)

  # Prepare data with a materialized weight column expected by survey
  data_rep <- base_design$interviews
  data_rep$design_weights <- base_design$design_weights

  # Map method to survey::svrepdesign type names
  sv_type <- switch(method,
    bootstrap = "bootstrap",
    jackknife = "JK1",
    brr = "BRR"
  )

  svy_design <- survey::svrepdesign(
    weights = ~design_weights,
    repweights = replicate_weights,
    type = sv_type,
    data = data_rep,
    scale = scale_factors,
    combined.weights = TRUE
  )

  # Return repweights design object
  design <- list(
    base_design = base_design,
    replicate_weights = replicate_weights,
    replicate_method = method,
    replicates = replicates,
    scale_factors = scale_factors,
    svy_design = svy_design,
    metadata = list(
      creation_time = Sys.time(),
      seed = seed,
      package_version = utils::packageVersion("tidycreel")
    )
  )

  class(design) <- c("repweights_design", "creel_design", "list")
  return(design)
}

#' Extract survey design object from a creel_design
#'
#' This helper bridges tidycreel design objects to the survey package.
#' It returns the embedded `survey::svydesign` or `survey::svrepdesign` object for downstream analysis.
#'
#' @param design A `creel_design` object (or subclass)
#' @return A `survey::svydesign` or `survey::svrepdesign` object
#' @details
#' This function provides a clear, pipe-friendly way to access the underlying survey design object
#' created by tidycreel constructors. Use this for analysis with survey or srvyr functions.
#'
#' - For access-point, roving, and bus route designs, returns a `survey::svydesign`.
#' - For replicate weights designs, returns a `survey::svrepdesign`.
#' - Raises an error if no embedded survey design is found.
#'
#' @examples
#' access_design <- design_access(
#'   interviews = read.csv("sample_data/toy_interviews.csv"),
#'   calendar = read.csv("sample_data/toy_calendar.csv")
#' )
#' svy <- as_survey_design(access_design)
#' summary(svy)
#'
#' @export
as_survey_design <- function(design) {
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("Input must be a creel_design object (from tidycreel)")
  }
  if (!is.null(design$svy_design)) {
    return(design$svy_design)
  }
  cli::cli_abort("No embedded survey design found in this object.")
}

#' Extract replicate weights survey design from a repweights_design
#'
#' Returns the embedded `survey::svrepdesign` object for bootstrap/jackknife/BRR designs.
#'
#' @param design A `repweights_design` object
#' @return A `survey::svrepdesign` object
#' @details
#' Use this helper for advanced variance estimation and resampling-based inference.
#' Raises an error if no embedded svrepdesign is found.
#'
#' @examples
#' rep_design <- design_repweights(
#'   base_design = access_design,
#'   method = "bootstrap"
#' )
#' svyrep <- as_svrep_design(rep_design)
#' summary(svyrep)
#'
#' @export
as_svrep_design <- function(design) {
  if (!inherits(design, "repweights_design")) {
    cli::cli_abort("Input must be a repweights_design object (from tidycreel)")
  }
  if (!is.null(design$svy_design)) {
    return(design$svy_design)
  }
  cli::cli_abort("No embedded svrepdesign found in this object.")
}


# Helper functions for weight calculations
#' Ensure Shift Block
#'
#' Internal helper function to create shift_block if missing.
#'
#' @keywords internal
.tc_ensure_shift_block <- function(data) {
  if (!"shift_block" %in% names(data)) {
    data$shift_block <- lubridate::hour(data$time_start)
    data$shift_block <- ifelse(data$shift_block < 12, "morning",
                               ifelse(data$shift_block < 17, "afternoon", "evening"))
  }
  return(data)
}

#' Calculate Access Design Weights
#'
#' Internal function to calculate design weights for access-point surveys.
#'
#' @keywords internal
calculate_access_weights <- function(interviews, calendar, strata_vars, weight_method) {
  interviews <- .tc_ensure_shift_block(interviews)
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)

  # Calculate base weights
  calendar_strata <- interaction(calendar[strata_vars], drop = TRUE)
  target_counts <- tapply(calendar$target_sample, calendar_strata, sum)
  actual_counts <- tapply(calendar$actual_sample, calendar_strata, sum)

  # Base weight is ratio of target to actual
  base_weights <- target_counts[strata_id] / actual_counts[strata_id]

  # Apply effort expansion
  weights <- base_weights * interviews$effort_expansion

  # Post-stratification adjustment if requested
  if (weight_method == "post_stratify") {
    # Simple post-stratification to known totals
    post_strata <- tapply(weights, strata_id, sum)
    adjustment <- target_counts / post_strata
    weights <- weights * adjustment[strata_id]
  }

  return(weights)
}

#' Calculate Roving Effort Estimates
#'
#' Internal function to estimate fishing effort for roving surveys.
#'
#' @keywords internal
calculate_roving_effort <- function(interviews, counts, calendar, strata_vars, effort_method) {
  # Create strata identifier
  strata_vars <- c("date", "shift_block", "day_type")
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)
  count_strata_id <- interaction(counts[strata_vars], drop = TRUE)

  # Calculate effort rates from interviews
  effort_rates <- tapply(
    interviews$hours_fished * interviews$party_size,
    strata_id,
    sum
  )

  # Calculate count-based effort estimates
  count_totals <- tapply(
    counts$anglers_count,
    count_strata_id,
    function(x) sum(x) * 60 / mean(counts$count_duration)
  )

  # Merge effort estimates
  effort_df <- data.frame(
    strata = names(effort_rates),
    interview_effort = as.numeric(effort_rates),
    count_effort = as.numeric(count_totals[names(effort_rates)])
  )

  # Calculate final effort estimates based on method
  if (effort_method == "ratio") {
    effort_df$effort_estimate <- effort_df$interview_effort *
      (effort_df$count_effort / effort_df$interview_effort)
  } else {
    # For now, use ratio method as default
    effort_df$effort_estimate <- effort_df$interview_effort *
      (effort_df$count_effort / effort_df$interview_effort)
  }

  return(effort_df)
}

#' Calculate Roving Design Weights
#'
#' Internal function to calculate design weights for roving surveys.
#'
#' @keywords internal
calculate_roving_weights <- function(interviews, effort_estimates, strata_vars) {
  # Create strata identifier
  strata_id <- interaction(interviews[strata_vars], drop = TRUE)

  # Get effort estimates for each interview
  effort_lookup <- setNames(
    effort_estimates$effort_estimate,
    effort_estimates$strata
  )

  total_effort <- effort_lookup[strata_id]
  party_hours <- interviews$hours_fished * interviews$party_size

  # Weight is ratio of total effort to observed effort
  weights <- total_effort / party_hours

  weights
}

#' Create Replicate Weights
#'
#' Internal function to create replicate weights for variance estimation.
#'
#' @keywords internal
create_replicate_weights <- function(base_design, replicates, method,
                                     strata_var, cluster_var) {
  base_design$interviews <- .tc_ensure_shift_block(base_design$interviews)
  n <- nrow(base_design$interviews)
  weights <- base_design$design_weights

  # Initialize replicate weight matrix
  rep_weights <- matrix(NA, nrow = n, ncol = replicates)

  if (method == "bootstrap") {
    # Bootstrap resampling
    for (i in 1:replicates) {
      bootstrap_indices <- sample(1:n, replace = TRUE)
      rep_weights[, i] <- weights * (tabulate(bootstrap_indices, nbins = n) + 1)
    }
  } else if (method == "jackknife") {
    # Jackknife resampling
    for (i in 1:replicates) {
      jackknife_weights <- weights * (n / (n - 1))
      jackknife_weights[i] <- 0
      rep_weights[, i] <- jackknife_weights
    }
  } else {
    # BRR - placeholder for now
    rep_weights <- matrix(weights, nrow = n, ncol = replicates)
  }

  rep_weights
}

#' Calculate Scale Factors
#'
#' Internal function to calculate scale factors for replicate weights.
#'
#' @keywords internal
calculate_scale_factors <- function(method, replicates, base_design) {
  scale_factors <- switch(method,
    bootstrap = 1 / replicates,
    jackknife = (replicates - 1) / replicates,
    brr = 1 / replicates
  )

  scale_factors
}
