# design-validator.R — Pre-season design validation and post-season completeness checking
# Phase 50: VALID-01 (validate_design) and QUAL-01 (check_completeness)

# Internal threshold constants (documented, not yet enforced until Plan 02)
WARN_CV_BUFFER <- 1.2 # nolint: object_name_linter — warn if cv_actual <= cv_target * WARN_CV_BUFFER but n < n_required

# ---- validate_design --------------------------------------------------------

#' Validate a proposed creel survey design against sample size targets
#'
#' Pre-season design check: runs creel_n_effort() and creel_n_cpue() per
#' stratum and returns a pass/warn/fail status report.
#'
#' @param N_h Named numeric vector. Total available sampling days per stratum.
#' @param ybar_h Numeric vector (same length as N_h). Pilot mean effort per day per stratum.
#' @param s2_h Numeric vector (same length as N_h). Pilot variance of effort per stratum.
#' @param n_proposed Named integer vector (same length as N_h). Proposed sampling days per stratum.
#' @param cv_target Numeric scalar. Target CV for the effort estimate.
#' @param type Character. One of "effort" or "cpue". Default "effort".
#' @param cv_catch Numeric scalar. Required when type = "cpue".
#' @param cv_effort Numeric scalar. Required when type = "cpue".
#' @param rho Numeric scalar. Correlation between catch and effort. Default 0.
#'
#' @return A creel_design_report object (S3 list) with:
#'   \describe{
#'     \item{$results}{tibble with columns stratum, status, n_proposed,
#'       n_required, cv_actual, cv_target, message}
#'     \item{$passed}{logical — TRUE if all strata status == "pass"}
#'     \item{$survey_type}{character}
#'   }
#'
#' @export
validate_design <- function(
  # nolint: object_name_linter
  N_h, ybar_h, s2_h, n_proposed, cv_target, # nolint: object_name_linter
  type = c("effort", "cpue"),
  cv_catch = NULL, cv_effort = NULL, rho = 0
) {
  NULL
}

# ---- check_completeness -----------------------------------------------------

#' Check post-season data completeness for a creel design
#'
#' Dispatches by survey_type to avoid false-positive warnings on aerial and
#' camera designs that do not collect interview data.
#'
#' @param design A creel_design object with counts (and optionally interviews) attached.
#' @param n_min Integer scalar >= 1. Interview threshold below which a stratum is flagged
#'   as low-n. Default 10L.
#'
#' @return A creel_completeness_report object (S3 list) with:
#'   \describe{
#'     \item{$missing_days}{tibble of calendar rows with no count data}
#'     \item{$low_n_strata}{tibble of strata below n_min, or NULL for aerial/camera}
#'     \item{$refusals}{creel_summary_refusals object or NULL}
#'     \item{$n_min}{integer threshold used}
#'     \item{$survey_type}{character}
#'     \item{$passed}{logical — TRUE if no missing days and no low-n strata}
#'   }
#'
#' @export
check_completeness <- function(design, n_min = 10L) {
  NULL
}
