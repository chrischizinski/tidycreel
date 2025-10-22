#' tidycreel: Tools for creel survey design, estimation, and reporting
#'
#' (One-sentence summary goes here.)
#'
#' @keywords internal
"_PACKAGE"

# Suppress R CMD check notes
if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    ".", "catch_total", "catch_kept", "catch_released", "hours_fished",
    "party_size", "effort_expansion", "anglers_count", "parties_count",
    "target_sample", "actual_sample", "date", "time_start", "time_end",
    "location", "mode", "shift_block", "stratum_id", "weekend", "holiday"
  ))
}
