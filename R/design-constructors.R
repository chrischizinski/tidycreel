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
#' @export
design_access <- function(interviews, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location"),
                          weight_method = c("equal", "standard")) {
  cli::cli_abort(c(
    "x" = "design_access() is deprecated.",
    "i" = "Use the survey-first workflow: as_day_svydesign() for day-PSU designs.",
    "i" = "See vignette('effort_survey_first', package = 'tidycreel') for examples."
  ))
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

#' @export
design_roving <- function(interviews, counts, calendar, locations = NULL,
                          strata_vars = c("date", "shift_block", "location"),
                          effort_method = c("ratio", "calibrate"),
                          coverage_correction = FALSE) {
  cli::cli_abort(c(
    "x" = "design_roving() is deprecated.",
    "i" = "Use the survey-first workflow: as_day_svydesign() + est_effort.progressive().",
    "i" = "See vignette('effort_survey_first', package = 'tidycreel') for examples."
  ))
}

#' @noRd
design_repweights <- function(base_design, method = c("bootstrap", "jackknife", "brr"), replicates = 50, seed = NULL) {
  cli::cli_abort(c(
    "x" = "design_repweights() is deprecated.",
    "i" = "Use survey::as.svrepdesign() on day-PSU designs instead.",
    "i" = "See vignette('replicate_designs_creel', package = 'tidycreel') for examples."
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
