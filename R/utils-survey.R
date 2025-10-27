#' Extract Interview Survey Design
#'
#' Extracts the survey design object for interview data from various input types.
#' Handles both direct survey design objects and creel_design objects.
#'
#' @param design Either a survey design object (`svydesign`/`svrepdesign`) or
#'   a `creel_design` object containing interview survey design
#'
#' @return Survey design object for interview data
#' @keywords internal
#' @noRd
tc_interview_svy <- function(design) {
  # If it's already a survey design, return it
  if (inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    return(design)
  }

  # If it's a creel_design, extract the survey design component
  if (inherits(design, "creel_design")) {
    if (!is.null(design$svy_design)) {
      return(design$svy_design)
    } else if (!is.null(design$interviews)) {
      # Fallback: create simple design from interviews if svy_design missing
      cli::cli_warn(c(
        "!" = "creel_design missing svy_design component",
        "i" = "Creating simple unweighted design from interviews"
      ))
      return(survey::svydesign(ids = ~1, data = design$interviews, weights = ~1))
    }
  }

  # If we get here, we don't know how to handle this object
  cli::cli_abort(c(
    "x" = "Cannot extract interview survey design from object of class {.cls {class(design)}}",
    "i" = "Provide either a survey design object or a creel_design object"
  ))
}

#' Extract Standard Errors from Survey Estimates
#'
#' Utility function to extract standard errors from survey package estimates
#' using the preferred method (survey::SE) with fallback to variance attributes.
#'
#' @param est Survey estimate object from `survey::svyby()` or similar
#' @param n_rows Expected number of rows in the output (for validation)
#'
#' @return Numeric vector of standard errors, or NA if extraction fails
#' @keywords internal
#' @noRd
tc_extract_se <- function(est, n_rows) {
  # Try survey::SE first (preferred method)
  se_try <- try(suppressWarnings(as.numeric(survey::SE(est))), silent = TRUE)

  if (!inherits(se_try, "try-error") && length(se_try) == n_rows) {
    return(se_try)
  }

  # Fallback: extract from variance attribute
  V <- attr(est, "var")
  if (!is.null(V) && length(V) > 0) {
    return(sqrt(diag(V)))
  }

  # If all else fails, return NA
  rep(NA_real_, n_rows)
}
