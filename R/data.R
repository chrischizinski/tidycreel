#' Example Roving Survey Interview Data
#'
#' Simulated roving creel survey data with incomplete trip interviews.
#' Designed to demonstrate `est_cpue_roving()` with length-bias correction.
#'
#' @format A tibble with 50 rows and 7 columns:
#' \describe{
#'   \item{interview_id}{Unique interview identifier (1-50)}
#'   \item{location}{Fishing location: "River" or "Lake"}
#'   \item{target_species}{Target species: "Trout" or "Bass"}
#'   \item{catch_total}{Total fish caught at time of interview (count)}
#'   \item{catch_kept}{Fish kept at time of interview (count, <= catch_total)}
#'   \item{hours_fished}{Observed effort at interview time (hours, 0.5-8.0)}
#'   \item{total_hours_planned}{Total planned trip effort (hours, >= hours_fished)}
#' }
#'
#' @details
#' This dataset simulates 50 roving (on-site) interviews conducted during
#' incomplete fishing trips. Key features:
#'
#' - **Incomplete trips**: All interviews occurred while anglers were still fishing,
#'   so `hours_fished` represents effort-to-date, not complete trip effort.
#' - **Length-bias sampling**: Longer trips have higher probability of being sampled
#'   (Robson 1961). The Pollock et al. (1997) correction uses `total_hours_planned`
#'   to adjust for this bias.
#' - **Realistic variation**: Catch rates vary by location (River: ~1 fish/hr,
#'   Lake: ~1.5 fish/hr) with natural Poisson variation.
#'
#' @section Usage:
#' Use with `est_cpue_roving()` to estimate CPUE accounting for incomplete trips:
#'
#' ```r
#' library(survey)
#'
#' # Basic CPUE estimate without length-bias correction
#' svy <- svydesign(ids = ~1, data = roving_survey)
#' est_cpue_roving(svy, length_bias_correction = "none")
#'
#' # CPUE with Pollock correction for length-bias
#' est_cpue_roving(
#'   svy,
#'   length_bias_correction = "pollock",
#'   total_trip_effort_col = "total_hours_planned"
#' )
#'
#' # Grouped estimates by location
#' est_cpue_roving(
#'   svy,
#'   by = "location",
#'   length_bias_correction = "pollock",
#'   total_trip_effort_col = "total_hours_planned"
#' )
#' ```
#'
#' @source Simulated data generated in `data-raw/roving_survey.R`
#'
#' @references
#' Pollock, K. H., C. M. Jones, and T. L. Brown. 1997. Angler survey methods
#' and their applications in fisheries management. American Fisheries Society,
#' Special Publication 25, Bethesda, Maryland.
#'
#' Robson, D. S. 1961. On the statistical theory of a roving creel census of
#' fishermen. Biometrics 17:415-437.
#'
#' @seealso [est_cpue_roving()] for estimation from roving survey data.
#'
#' @examples
#' # Load and examine the data
#' data(roving_survey)
#' head(roving_survey)
#'
#' # Summary statistics
#' summary(roving_survey)
#'
#' # Basic CPUE estimation
#' library(survey)
#' svy <- svydesign(ids = ~1, data = roving_survey)
#' est_cpue_roving(svy, length_bias_correction = "none")
#'
"roving_survey"
