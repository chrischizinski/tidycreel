#' tidycreel: Tools for creel survey design, estimation, and reporting
#'
#' (One-sentence summary goes here.)
#'
#' @importFrom dplyr %>% desc
#' @importFrom graphics hist
#' @importFrom stats aggregate aov complete.cases cor mad median quantile sd setNames var vcov
#' @importFrom utils getFromNamespace head tail
#' @keywords internal
"_PACKAGE"

# Suppress R CMD check notes
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    # Core data columns
    ".", "catch_total", "catch_kept", "catch_released", "hours_fished",
    "party_size", "effort_expansion", "anglers_count", "parties_count",
    "target_sample", "actual_sample", "date", "time_start", "time_end",
    "location", "mode", "shift_block", "stratum_id", "weekend", "holiday",
    # Internal computed columns
    ".interview_id", "aggregated_catch", "adj_count", "sd_count",
    # Variance decomposition columns
    "deff", "variance_info", "variance", "component", "proportion",
    "ci_lower", "ci_upper", "cluster_level", "design_effect", "icc",
    # QA check columns
    "n_zeros", "n_interviews", "n_samples", "success_rate", "count",
    # User data columns (common names)
    "interviewer", "species", "trip_complete"
  ))
}
