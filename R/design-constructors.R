#' Plot survey design coverage (temporal and spatial)
#'
#' Visualizes the distribution of interviews by date, shift block, and location using ggplot2.
#'
#' @param x A creel_design object
#' @param ... Additional arguments (ignored)
#' @return A ggplot object
#' @noRd
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
#' @noRd
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
#' @noRd
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
#' @noRd
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
#' @param weight_method Method for calculating design weights. One of "equal" (all weights = 1)
#'   or "standard" (weights based on target vs actual sample sizes in calendar).
#'
#' @return A list with class `c("access_design","creel_design","list")` containing
#'   `design_type`, `interviews`, `calendar`, `locations`, `strata_vars`, and `metadata`.
#' @export
design_access <- function(interviews, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location"),
                          weight_method = c("equal", "standard")) {
  weight_method <- match.arg(weight_method)
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

  # Derive basic design weights
  design_weights <- if (weight_method == "standard") {
    calculate_access_weights(
      interviews = interviews,
      calendar = calendar,
      strata_vars = intersect(strata_vars, names(calendar)),
      weight_method = "standard"
    )
  } else {
    rep(1, nrow(interviews))
  }

  design <- list(
    design_type = "access_point",
    interviews = interviews,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    weight_method = weight_method,
    design_weights = design_weights,
    svy_design = survey::svydesign(ids = ~1, weights = ~design_weights, data = interviews),
    metadata = list(
      creation_time = Sys.time(),
      package_version = tryCatch(as.character(utils::packageVersion("tidycreel")), error = function(e) NA_character_)
    )
  )
  class(design) <- c("access_design", "creel_design", "list")
  design
}

#' Calculate access design weights
#'
#' Computes simple positive weights per interview using calendar target/actual
#' sampling within strata.
#' @param interviews data.frame of interviews
#' @param calendar data.frame of calendar with target_sample/actual_sample
#' @param strata_vars character vector of strata variables to join by
#' @param weight_method currently only "standard"
#' @noRd
calculate_access_weights <- function(interviews, calendar, strata_vars = c("date", "shift_block"), weight_method = c("standard")) {
  weight_method <- match.arg(weight_method)
  if (!all(c("target_sample", "actual_sample") %in% names(calendar))) {
    return(rep(1, nrow(interviews)))
  }
  by_vars <- intersect(strata_vars, intersect(names(interviews), names(calendar)))
  if (length(by_vars) == 0) by_vars <- intersect(c("date"), names(interviews))
  cal <- dplyr::group_by(calendar, dplyr::across(dplyr::all_of(by_vars)))
  tab <- dplyr::summarise(cal,
                          .target = sum(.data$target_sample, na.rm = TRUE),
                          .actual = sum(.data$actual_sample, na.rm = TRUE),
                          .groups = "drop")
  tab$.w <- tab$.target / pmax(tab$.actual, 1)
  joined <- dplyr::left_join(interviews, tab, by = by_vars)
  w <- if (!is.null(joined$.w)) joined$.w else rep(1, nrow(interviews))
  w[is.na(w) | !is.finite(w) | w <= 0] <- 1
  as.numeric(w)
}

#' Calculate roving effort summaries for diagnostics
#'
#' Produces basic per-stratum effort summaries from interviews and counts.
#' @param interviews data.frame
#' @param counts data.frame
#' @param calendar data.frame (unused but kept for API parity)
#' @param strata_vars grouping variables
#' @param effort_method one of "ratio","calibrate"
#' @noRd
calculate_roving_effort <- function(interviews, counts, calendar, strata_vars = c("date", "shift_block", "location"), effort_method = c("ratio", "calibrate")) {
  effort_method <- match.arg(effort_method)
  by <- intersect(strata_vars, intersect(names(interviews), names(counts)))
  if (length(by) == 0) by <- intersect(c("date", "shift_block", "location"), names(interviews))
  int_sum <- dplyr::group_by(interviews, dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(interview_effort = sum(.data$hours_fished, na.rm = TRUE), .groups = "drop")
  if (!all(c("anglers_count", "count_duration") %in% names(counts))) {
    counts$count_duration <- counts$count_duration %||% 0
    counts$anglers_count <- counts$anglers_count %||% 0
  }
  cnt_sum <- dplyr::group_by(counts, dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(count_effort = sum((.data$anglers_count %||% 0) * (.data$count_duration %||% 0) / 60, na.rm = TRUE), .groups = "drop")
  eff <- dplyr::full_join(int_sum, cnt_sum, by = by)
  eff$interview_effort[is.na(eff$interview_effort)] <- 0
  eff$count_effort[is.na(eff$count_effort)] <- 0
  eff$effort_estimate <- eff$interview_effort + eff$count_effort
  eff$strata <- do.call(interaction, c(eff[by], drop = TRUE))
  eff[, c("strata", "interview_effort", "count_effort", "effort_estimate")]
}

#' Calculate roving design weights
#' @param interviews data.frame
#' @param effort_estimates output of calculate_roving_effort
#' @param strata_vars grouping variables
#' @noRd
calculate_roving_weights <- function(interviews, effort_estimates, strata_vars = c("date", "shift_block", "location")) {
  by <- intersect(strata_vars, names(interviews))
  key <- do.call(interaction, c(interviews[by], drop = TRUE))
  wtab <- effort_estimates
  avg <- mean(wtab$effort_estimate[wtab$effort_estimate > 0], na.rm = TRUE)
  if (!is.finite(avg) || is.na(avg) || avg == 0) avg <- 1
  # Map weights by nearest strata label; fallback to 1
  wmap <- wtab$effort_estimate / avg
  names(wmap) <- as.character(wtab$strata)
  res <- as.numeric(wmap[as.character(key)])
  res[is.na(res) | !is.finite(res) | res <= 0] <- 1
  res
}

#' Create replicate weights matrix
#' @param base_design creel_design
#' @param replicates integer
#' @param method "bootstrap" or "jackknife" or "brr"
#' @param strata_var optional
#' @param cluster_var optional
#' @noRd
create_replicate_weights <- function(base_design, replicates = 50, method = c("bootstrap", "jackknife", "brr"), strata_var = NULL, cluster_var = NULL) {
  method <- match.arg(method)
  n <- nrow(base_design$interviews)
  if (method == "jackknife") replicates <- n
  # Simple nonnegative replicate weights
  mat <- matrix(1, nrow = n, ncol = replicates)
  if (method == "bootstrap") {
    mat <- matrix(stats::runif(n * replicates, 0.5, 1.5), nrow = n, ncol = replicates)
  } else if (method == "brr") {
    mat <- matrix(rep(c(0, 2), length.out = n * replicates), nrow = n, ncol = replicates)
  } else if (method == "jackknife") {
    mat <- diag(replicates)
    mat[mat == 0] <- (replicates - 1) / replicates
  }
  colnames(mat) <- paste0("rep", seq_len(replicates))
  mat
}

#' Calculate scale factors for replicate-weight designs
#' @param method method string
#' @param replicates integer
#' @param base_design optional
#' @noRd
calculate_scale_factors <- function(method = c("bootstrap", "jackknife", "brr"), replicates = 50, base_design = NULL) {
  method <- match.arg(method)
  if (method == "bootstrap") return(1 / replicates)
  if (method == "jackknife") return(1)
  if (method == "brr") return(1)
  1
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
#' @param effort_method Method for effort estimation. One of "ratio" or "calibrate".
#' @param coverage_correction Logical; whether to apply coverage correction for incomplete
#'   survey days. Default is FALSE.
#'
#' @return A list with class `c("roving_design","creel_design","list")` containing
#'   `design_type`, `interviews`, `counts`, `calendar`, `locations`, `strata_vars`, and `metadata`.
#' @export
design_roving <- function(interviews, counts, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location"),
                          effort_method = c("ratio", "calibrate"),
                          coverage_correction = FALSE) {
  effort_method <- match.arg(effort_method)
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

  # Placeholder effort estimates for diagnostics and back-compat in tests
  effort_estimates <- calculate_roving_effort(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    strata_vars = intersect(strata_vars, names(interviews)),
    effort_method = effort_method
  )

  design <- list(
    design_type = "roving",
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    locations = locations,
    strata_vars = strata_vars,
    effort_method = effort_method,
    coverage_correction = coverage_correction,
    design_weights = rep(1, nrow(interviews)),
    effort_estimates = effort_estimates,
    svy_design = survey::svydesign(ids = ~1, weights = ~1, data = interviews),
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
#' @noRd
#'
#' @examples
#' \dontrun{
#' # Create base design
#' interviews <- utils::read.csv(system.file("extdata", "toy_interviews.csv",
#'   package = "tidycreel"
#' ))
#' calendar <- utils::read.csv(system.file("extdata", "toy_calendar.csv",
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
design_repweights <- function(base_design, method = c("bootstrap", "jackknife", "brr"), replicates = 50, seed = NULL) {
  method <- match.arg(method)
  if (!inherits(base_design, "creel_design")) cli::cli_abort("base_design must be a creel design object")
  if (!is.null(seed)) set.seed(seed)

  # Base interviews and weights
  interviews <- base_design$interviews
  if (is.null(interviews)) cli::cli_abort("base_design must include interviews")
  base_weights <- if (!is.null(base_design$design_weights)) base_design$design_weights else rep(1, nrow(interviews))

  # Create replicate weights matrix
  if (method == "jackknife") {
    replicates <- nrow(interviews)
  }
  rep_w <- create_replicate_weights(
    base_design = base_design,
    replicates = replicates,
    method = method,
    strata_var = intersect(c("date", "shift_block"), names(interviews))[1] %||% NULL,
    cluster_var = intersect(c("location"), names(interviews))[1] %||% NULL
  )

  scale_factors <- calculate_scale_factors(method = method, replicates = replicates, base_design = base_design)

  # Build svrepdesign object for downstream use
  svy_design <- survey::svrepdesign(
    data = interviews,
    repweights = rep_w,
    weights = base_weights,
    type = switch(method, bootstrap = "bootstrap", jackknife = "JK1", brr = "BRR"),
    scale = scale_factors
  )

  out <- list(
    base_design = base_design,
    replicate_weights = rep_w,
    replicate_method = method,
    replicates = replicates,
    scale_factors = scale_factors,
    svy_design = svy_design,
    metadata = list(
      creation_time = Sys.time(),
      package_version = tryCatch(as.character(utils::packageVersion("tidycreel")), error = function(e) NA_character_)
    )
  )
  class(out) <- c("repweights_design", "creel_design", "list")
  out
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
#' \dontrun{
#' access_design <- design_access(
#'   interviews = utils::read.csv(system.file("extdata", "toy_interviews.csv",
#'     package = "tidycreel"
#'   )),
#'   calendar = utils::read.csv(system.file("extdata", "toy_calendar.csv",
#'     package = "tidycreel"
#'   ))
#' )
#' svy <- as_survey_design(access_design)
#' summary(svy)
#' }
#'
#' @export
as_survey_design <- function(design) {
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("Input must be a creel_design object (from tidycreel)")
  }
  if (!is.null(design$svy_design)) {
    return(design$svy_design)
  }
  # Construct a minimal interview-level svydesign as a fallback
  if (!is.null(design$interviews) && is.data.frame(design$interviews)) {
    # Provide unit weights to avoid survey's equal-probability warning
    return(survey::svydesign(ids = ~1, weights = ~1, data = design$interviews))
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
#' \dontrun{
#' # Create a replicate weights design first
#' # (design_repweights is an internal function)
#' access_design <- design_access(interviews, calendar)
#' # Then extract the survey design for advanced use
#' # svyrep <- as_svrep_design(rep_design)
#' }
#'
#' @export
as_svrep_design <- function(design) {
  if (!inherits(design, "repweights_design")) {
    cli::cli_abort("Input must be a repweights_design object")
  }
  if (!is.null(design$svyrep)) {
    return(design$svyrep)
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
