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

#' Create Access-Point Survey Design (lean container)
#'
#' Constructs a lean container for access-point creel surveys. It validates and
#' stores inputs plus descriptive metadata. Estimation uses survey-first
#' estimators and day-PSU designs built via [as_day_svydesign()]. No ad-hoc
#' weighting or embedded `svydesign` is created here.
#'
#' @param interviews Tibble of interview data validated by [validate_interviews()].
#' @param calendar Tibble of sampling calendar validated by [validate_calendar()].
#' @param locations Optional character vector of sampling locations; defaults to
#'   unique locations in `interviews`.
#' @param strata_vars Character vector of variables describing stratification
#'   (e.g., `c("date","shift_block","location")`). Missing columns are ignored.
#'
#' @return A list with class `c("access_design","creel_design","list")` containing
#'   `design_type`, `interviews`, `calendar`, `locations`, `strata_vars`, and `metadata`.
#' @export
design_access <- function(interviews, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location")) {
  interviews <- validate_interviews(interviews)
  calendar <- validate_calendar(calendar)

  if (is.null(locations)) locations <- unique(interviews$location)

  # Basic location/strata checks for early detection
  if ("location" %in% names(calendar)) {
    interview_locations <- unique(interviews$location)
    calendar_locations <- unique(calendar$location)
    missing_in_interviews <- setdiff(calendar_locations, interview_locations)
    missing_in_calendar <- setdiff(interview_locations, calendar_locations)
    if (length(missing_in_interviews) > 0 || length(missing_in_calendar) > 0) {
      cli::cli_warn("Access design: interview/calendar location sets differ; verify sampling frame.")
    }
  }

  strata_vars <- tc_group_warn(strata_vars, names(interviews))

  design <- list(
    design_type = "access_point",
    interviews = interviews,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    metadata = list(
      creation_time = Sys.time(),
      package_version = tryCatch(as.character(utils::packageVersion("tidycreel")), error = function(e) NA_character_)
    )
  )
  class(design) <- c("access_design", "creel_design", "list")
  design
}

#' Create Roving Survey Design (lean container)
#'
#' Constructs a lean container for roving creel surveys. It validates and stores
#' inputs plus descriptive metadata. Estimation of effort should use
#' survey-first estimators on counts (instantaneous or progressive) coupled with
#' a day-PSU design from [as_day_svydesign()]. No ad-hoc weighting or embedded
#' `svydesign` is created here.
#'
#' @param interviews Tibble validated by [validate_interviews()].
#' @param counts Tibble validated by [validate_counts()].
#' @param calendar Tibble validated by [validate_calendar()].
#' @param locations Optional character vector; defaults to union of interview and
#'   count locations.
#' @param strata_vars Character vector describing stratification (e.g.,
#'   `c("date","shift_block","location")`). Missing columns are ignored.
#'
#' @return A list with class `c("roving_design","creel_design","list")` containing
#'   `design_type`, `interviews`, `counts`, `calendar`, `locations`, `strata_vars`, and `metadata`.
#' @export
design_roving <- function(interviews, counts, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location")) {
  interviews <- validate_interviews(interviews)
  counts <- validate_counts(counts)
  calendar <- validate_calendar(calendar)

  if (is.null(locations)) {
    locations <- union(unique(interviews$location), unique(counts$location))
  }

  # Light consistency checks; warn instead of aborting to allow flexible inputs
  if ("location" %in% names(calendar)) {
    interview_locations <- unique(interviews$location)
    count_locations <- unique(counts$location)
    calendar_locations <- unique(calendar$location)
    if (!all(calendar_locations %in% union(interview_locations, count_locations))) {
      cli::cli_warn("Roving design: some calendar locations are not in interviews/counts; verify sampling frame.")
    }
  }

  strata_vars <- tc_group_warn(strata_vars, names(interviews))

  design <- list(
    design_type = "roving",
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    metadata = list(
      creation_time = Sys.time(),
      package_version = tryCatch(as.character(utils::packageVersion("tidycreel")), error = function(e) NA_character_)
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
design_repweights <- function(...) {
  cli::cli_abort(c(
    "x" = "design_repweights() is deprecated and has been removed.",
    "i" = "Use replicate-weight designs built directly with survey::svrepdesign() on day-PSU designs (see as_day_svydesign)."
  ))
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
  cli::cli_abort(c(
    "x" = "as_svrep_design() is deprecated.",
    "i" = "Construct replicate designs with survey::svrepdesign() using the output of as_day_svydesign()."
  ))
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
## Deprecated: access weight calculators removed (use as_day_svydesign + survey)

#' Calculate Roving Effort Estimates
#'
#' Internal function to estimate fishing effort for roving surveys.
#'
#' @keywords internal
## Deprecated: roving effort calculators removed (use survey-first estimators)

#' Calculate Roving Design Weights
#'
#' Internal function to calculate design weights for roving surveys.
#'
#' @keywords internal
## Deprecated: roving weight calculators removed

#' Create Replicate Weights
#'
#' Internal function to create replicate weights for variance estimation.
#'
#' @keywords internal
## Deprecated: custom replicate weight generators removed (use survey::svrepdesign)

#' Calculate Scale Factors
#'
#' Internal function to calculate scale factors for replicate weights.
#'
#' @keywords internal
## Deprecated: scale factor helper removed
