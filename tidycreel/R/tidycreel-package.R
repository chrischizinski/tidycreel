#' tidycreel: Survey Design and Analysis for Access-Point Creel Surveys
#'
#' @description
#' Provides comprehensive tools for designing and analyzing access-point creel
#' surveys in recreational fisheries. Includes functions for survey design
#' construction, data validation, effort estimation, catch rate estimation,
#' and variance estimation with replicate weights.
#'
#' @section Survey Design Constructors:
#' The package provides three main survey design constructors:
#' \describe{
#'   \item{\code{\link{design_access}}}{Create access-point survey designs}
#'   \item{\code{\link{design_roving}}}{Create roving survey designs}
#'   \item{\code{\link{design_repweights}}}{Add replicate weights for variance estimation}
#' }
#'
#' @section Data Validation:
#' All survey design constructors include built-in validation for:
#' \itemize{
#'   \item Interview data (\code{\link{validate_interviews}})
#'   \item Count data (\code{\link{validate_counts}})
#'   \item Calendar data (\code{\link{validate_calendar}})
#' }
#'
#' @section Key Features:
#' \itemize{
#'   \item Support for access-point and roving survey designs
#'   \item Built-in data validation and schema checking
#'   \item Replicate weights for variance estimation (bootstrap, jackknife, BRR)
#'   \item Effort estimation for roving surveys
#'   \item Post-stratification and calibration options
#'   \item Comprehensive documentation and examples
#' }
#'
#' @docType package
#' @name tidycreel
#' @aliases tidycreel-package
NULL

# Suppress R CMD check notes
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    ".", "catch_total", "catch_kept", "catch_released", "hours_fished",
    "party_size", "effort_expansion", "anglers_count", "parties_count",
    "target_sample", "actual_sample", "date", "time_start", "time_end",
    "location", "mode", "shift_block", "stratum_id", "weekend", "holiday"
  ))
}