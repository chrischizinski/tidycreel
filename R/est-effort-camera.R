# est_effort_camera() ---------------------------------------------------------

#' Estimate angler effort from camera/time-lapse count data
#'
#' Estimates total angler-hours from a camera-based creel survey design.
#' Two estimation modes are supported:
#'
#' * **Ratio calibration** (recommended, when interview data are available):
#'   Per-stratum calibration ratios (mean interview effort / mean camera count
#'   during the interview period) scale raw camera counts to angler-hours.
#'   Variance is estimated via Taylor linearisation or replicate weights.
#'
#' * **Raw count expansion** (fallback): Camera ingress counts are multiplied
#'   by `h_open` (fishable hours per day).  Use when no interview data are
#'   available.
#'
#' @section Uncertainty the standard error does not cover:
#'
#' Two cases are reported rather than absorbed, because in both the returned
#' standard error would otherwise understate what is known:
#'
#' * A stratum with a single paired interview/count day gives its calibration
#'   ratio no measurable spread. That variance is unknown rather than zero, so
#'   it is carried as `NA` and the combined standard error and confidence
#'   interval are `NA` too; a warning names the stratum. Add a second matched
#'   interview day in that stratum to recover a standard error.
#'
#' * Counts flagged `.imputed` by [impute_camera_counts()] enter the estimator
#'   as observations. The imputation model's prediction uncertainty is not
#'   propagated, and model predictions vary less than real counts, so the
#'   between-day component is understated as well. A warning reports how many
#'   days were imputed; the standard error is a lower bound.
#'
#' @section Within-day variance:
#'
#' When counts arrive through `add_counts(count_time_col = )`, several counts
#' on one day are averaged into a daily mean and the within-day components
#' (`ss_d`, `k_d`) are stored on the design. Both paths of this function read
#' them and report the Rasmussen (1998) within-day term as `se_within`,
#' scaling it by the stratum's calibration ratio on the ratio path and by
#' `h_open` on the raw path.
#'
#' `se_within` is `0` only when there is genuinely nothing to measure -- one
#' count per day, where the component is nil by construction rather than
#' unknown. It was previously reported as a literal `0` in every case, while
#' the measured components sat unread on the design, so a design with real
#' within-day spread received the same standard error as one with none.
#'
#' @section One count row per day on the calibration path:
#'
#' Ratio calibration pairs each interview day to that day's camera count, so it
#' requires the counts table to hold exactly one row per day (per stratum). A
#' repeated day is refused rather than averaged: two counts on one date are
#' either sub-period snapshots or a data error, and the estimator cannot tell
#' which. Before this was checked, a repeated date entered both sides of the
#' calibration ratio twice and **moved the point estimate**, not merely the
#' standard error.
#'
#' If the counts are genuine sub-daily observations, pass `count_time_col` to
#' [add_counts()], which averages them into one row per day and retains the
#' within-day variance. Otherwise remove the repeated rows. Raw count expansion
#' (`interviews = NULL`) does no pairing and is not subject to this requirement.
#'
#' @param design A `creel_design` object created with
#'   `creel_design(..., survey_type = "camera")` and counts attached via
#'   `add_counts()`.
#' @param interviews Optional data frame of angler interview records for ratio
#'   calibration.  Must contain `effort_col` and every column in
#'   `design$strata_cols`: the calibration ratio is estimated within each
#'   stratum the design declares, so a missing stratum column is an error
#'   rather than a coarser calibration.  When `NULL`, falls back to raw count
#'   expansion and `h_open` is required.
#' @param effort_col Character scalar.  Column in `interviews` containing
#'   per-trip effort in hours. Default `"hours_fished"`.
#' @param n_anglers Optional party size for the ratio-calibration path. Either a
#'   character scalar naming a column in `interviews`, or a single positive
#'   number stating a constant party size (`n_anglers = 1` for individual-level
#'   interviews).
#'
#'   The calibration ratio cancels the camera counts, so the estimate inherits
#'   whatever unit `effort_col` holds. Supplying `n_anglers` makes this function
#'   perform the party-size multiplication, so the result is angler-hours and is
#'   labelled as such. Omitting it leaves the estimate in the unit of the column
#'   you supplied, which the package cannot identify: the unit is reported as
#'   unknown and a warning names the ambiguity. Default `NULL`.
#' @param intercept_col Character scalar or `NULL`.  Column in the count data
#'   representing the camera count during the interview interception period.
#'   Default `NULL` (auto-detects the first numeric count column).
#' @param h_open Numeric scalar.  Fishable hours per day.  Required when
#'   `interviews = NULL`. Default `NULL`.
#' @param calibration Pass the string `"none"` to run the raw-count expansion
#'   path without any calibration. Required to reach that path, because
#'   expanding a raw camera count by `h_open` alone silently assumes each
#'   counted object contributes exactly one angler-hour per hour open — a
#'   calibration of 1 that was never measured (GH #158).
#'
#'   Under the opt-out the point estimate uses that assumption and the reported
#'   SE is `NA`: the `calibration` component is present-and-unknown rather than
#'   absent, because the correction applies and was simply not measured. It is
#'   never `0`, which would be indistinguishable from having propagated the
#'   calibration's uncertainty and found none.
#'
#'   Supplying `interviews` instead uses the ratio-calibration path, which
#'   estimates hours of effort per camera count per stratum and propagates that
#'   ratio's variance. Prefer it whenever interview data exist.
#' @param variance Character.  Variance method: `"taylor"` (default) or
#'   `"replicate"`.
#' @param conf_level Numeric confidence level. Default `0.95`.
#'
#' @return A `creel_estimates` object with columns `estimate`, `se`,
#'   `se_between`, `se_within`, `ci_lower`, `ci_upper`, `n`.
#'
#' @references
#'   Hartill, B.W., Cryer, M., and Morrison, M.A. 2020. Camera-based creel
#'   surveys: estimating fishing effort and catch rates from ingress-egress
#'   camera counts. Fisheries Research 231:105706.
#'   \doi{10.1016/j.fishres.2020.105706}
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#' data(example_camera_counts)
#' data(example_camera_interviews)
#'
#' cal <- data.frame(
#'   date     = unique(example_camera_counts$date),
#'   day_type = unique(example_camera_counts[, c("date", "day_type")])[["day_type"]]
#' )
#' design <- creel_design(cal,
#'   date = date, strata = day_type,
#'   survey_type = "camera", camera_mode = "counter"
#' )
#'
#' # Filter to operational rows
#' ops <- example_camera_counts[
#'   example_camera_counts$camera_status == "operational",
#' ]
#' design <- add_counts(design, ops)
#'
#' # Ratio calibration using interview hours. `example_camera_interviews` has no
#' # party-size column, so this warns and reports an unknown unit: the estimate
#' # is in whatever unit `hours_fished` holds, which the package cannot tell.
#' est <- est_effort_camera(design, interviews = example_camera_interviews)
#' print(est)
#'
#' # With party sizes the function does the normalisation itself, so the result
#' # is angler-hours and is labelled as such.
#' ints <- example_camera_interviews
#' ints$party_size <- 2
#' est_ah <- est_effort_camera(design, interviews = ints, n_anglers = "party_size")
#' print(est_ah)
#' }
#'
#' @family "Survey Design"
#' @export
est_effort_camera <- function(
  # nolint: object_name_linter
  design,
  interviews = NULL,
  effort_col = "hours_fished",
  n_anglers = NULL,
  intercept_col = NULL,
  h_open = NULL,
  calibration = NULL,
  variance = c("taylor", "replicate"),
  conf_level = 0.95
) {
  variance <- match.arg(variance)

  if (!inherits(design, "creel_design")) {
    cli::cli_abort(
      "{.arg design} must be a {.cls creel_design} object."
    )
  }
  bad_type <- !is.null(design$design_type) &&
    !identical(design$design_type, "camera")
  if (bad_type) {
    cli::cli_warn(
      "{.arg design} has {.field design_type} = {.val {design$design_type}}, not {.val camera}. Proceeding anyway."
    )
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
    cli::cli_abort(
      "{.arg conf_level} must be a number in (0, 1). Got {.val {conf_level}}."
    )
  }

  estimate_effort_camera( # nolint: object_usage_linter
    design = design,
    interviews = interviews,
    effort_col = effort_col,
    n_anglers = n_anglers,
    intercept_col = intercept_col,
    h_open = h_open,
    calibration = calibration,
    variance_method = variance,
    conf_level = conf_level
  )
}
