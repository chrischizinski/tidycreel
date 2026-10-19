#' Warning classes
#'
#' @description
#' Every warning tidycreel raises has a class, so one warning can be handled
#' in one call without silencing the others. Each carries its own class,
#' `creel_warning_<fact>`, and the parent class `creel_warning`. A fact raised
#' in several places has one class wherever it is raised.
#'
#' Handle one warning for one call with [withCallingHandlers()]:
#'
#' ```r
#' withCallingHandlers(
#'   estimate_catch_rate(design),
#'   creel_warning_mor_truncation = function(w) invokeRestart("muffleWarning")
#' )
#' ```
#'
#' Prefer this to [suppressWarnings()], which also hides the warnings that
#' mean an estimate may be wrong: missing period length, rate and effort in
#' different units, sections or cells left out of a total. Errors have a
#' matching family, `creel_error_*`.
#'
#' Two classes were renamed to this pattern and keep their old names as well:
#' `creel_warn_two_phase_rescale` and `creel_warn_tost_degenerate`.
#'
#' Information that is not a warning (tier 3) is raised as a message, with a
#' class from the matching family `creel_message_<fact>` and the parent
#' `creel_message`; see the Messages section below.
#'
#' @section Tiers:
#' Each entry starts with its tier, which [get_warnings()] also reports:
#' \describe{
#'   \item{Tier 1}{The estimate may be wrong.}
#'   \item{Tier 2}{Data quality or precision: worth a look.}
#'   \item{Tier 3}{Information, raised as a message rather than a warning.}
#' }
#' Every warning and tier-3 message is also recorded on the design or estimate
#' the call returns; [get_warnings()] lists them.
#'
#' Tier 1 warnings print on every call. Tier 2 warnings print once per design:
#' the first time one is raised on a design it prints, and later repeats on
#' that design are recorded but not printed. A design is new each time
#' [creel_design()], an `add_*()` step or [adjust_nonresponse()] returns it,
#' so new data print again. Three facts about the design also print once per
#' design although their tier is not 2: \code{creel_warning_no_period_length},
#' \code{creel_warning_pooled_domain_mix} and the message
#' \code{creel_message_internal_svydesign}. Other tier-3 messages print on
#' every call.
#'
#' @section Units and scale:
#' \describe{
#'   \item{\code{creel_warning_no_period_length}}{Tier 1. Instantaneous counts
#'     were expanded without a period length, so effort is the counts summed
#'     over days (angler-days for an angler count), not angler-hours.}
#'   \item{\code{creel_warning_no_party_size}}{Tier 1. No party size was given,
#'     so each interview counts as one angler. If interviews are parties, rates
#'     are per party-hour, not per angler-hour.}
#'   \item{\code{creel_warning_unit_mismatch}}{Tier 1. A rate and an effort may
#'     be in different units (party-hours and angler-hours), so their product
#'     may not be a total in fish.}
#'   \item{\code{creel_warning_camera_unit_ambiguous}}{Tier 1. Camera ratio
#'     calibration cannot tell angler-hours from party-hours.}
#'   \item{\code{creel_warning_catch_is_stratum_total}}{Tier 1. A catch total
#'     supplied to an exploitation rate is a stratum total.}
#'   \item{\code{creel_warning_p_period_coverage}}{Tier 1. The period lengths
#'     divided by `p_period` add to more than 24 hours a day; the period lengths
#'     may already include the probability, which would then be applied twice.}
#'   \item{\code{creel_warning_p_period_inferred}}{Tier 1. A schedule had
#'     periods but no `p_period` column, so the period sampling probability was
#'     inferred.}
#' }
#'
#' @section What an estimate covers:
#' \describe{
#'   \item{\code{creel_warning_missing_sections}}{Tier 1. One or more sections
#'     are missing from the count or interview data and are not in the
#'     estimate.}
#'   \item{\code{creel_warning_missing_rate_strata}}{Tier 1. Effort cells with
#'     no catch rate were left out of a total.}
#'   \item{\code{creel_warning_pooled_domain_mix}}{Tier 1. A total pools over
#'     domains the counts do not classify.}
#'   \item{\code{creel_warning_zero_catch_excluded}}{Tier 1. Trips that caught
#'     none of a species were left out, so the rate is among trips that caught
#'     it.}
#'   \item{\code{creel_warning_effort_excluded}}{Tier 2. Interviews with missing
#'     or zero effort were left out of a rate.}
#'   \item{\code{creel_warning_harvest_excluded}}{Tier 2. Interviews with
#'     missing harvest were left out of a harvest rate.}
#'   \item{\code{creel_warning_trip_duration_excluded}}{Tier 2. Interviews with
#'     a missing or non-positive trip duration were left out.}
#'   \item{\code{creel_warning_mor_truncation}}{Tier 2. 10 percent or more of
#'     incomplete trips were shorter than `truncate_at` and left out of a
#'     mean-of-ratios rate (below 10 percent this is a message).}
#'   \item{\code{creel_warning_two_phase_rescale}}{Tier 1. Two-phase totals were
#'     rescaled onto the reported catch.}
#'   \item{\code{creel_warning_asymmetric_coverage}}{Tier 1. Count frames in a
#'     hybrid design cover different date-stratum cells.}
#' }
#'
#' @section Estimates that cannot be computed or may be unreliable:
#' \describe{
#'   \item{\code{creel_warning_all_counts_na}}{Tier 1. Every value in the count
#'     column is `NA`.}
#'   \item{\code{creel_warning_zero_fish_total}}{Tier 1. The estimated number of
#'     fish is zero or negative, so a mean or proportion cannot be computed.}
#'   \item{\code{creel_warning_no_recaptures}}{Tier 1. No tagged fish were
#'     recovered, overall or in a stratum, so the exploitation rate is estimated
#'     as 0.}
#'   \item{\code{creel_warning_exploitation_out_of_range}}{Tier 1. The
#'     exploitation rate is outside 0 to 1; its interval is clamped.}
#'   \item{\code{creel_warning_estimator_failed}}{Tier 1. One of the estimators
#'     being compared failed.}
#'   \item{\code{creel_warning_imputation_convergence}}{Tier 1. The camera-count
#'     imputation model did not converge in a stratum.}
#' }
#'
#' @section Standard errors and intervals:
#' \describe{
#'   \item{\code{creel_warning_bootstrap_ignores_strata}}{Tier 1. A bootstrap SE
#'     does not resample within the design strata.}
#'   \item{\code{creel_warning_bin_vcov_unavailable}}{Tier 1. Covariance between
#'     length bins is unavailable, so bins are treated as independent.}
#'   \item{\code{creel_warning_expansion_structure_unknown}}{Tier 1. Party-size
#'     expansion groups straddle the estimation cells unevenly, so the SE of the
#'     total cannot be combined from per-cell components.}
#'   \item{\code{creel_warning_lake_variance_negative}}{Tier 1. The sections'
#'     day samples overlap too unevenly to combine their effort covariances,
#'     so a sectioned total's lake-wide SE is NA.}
#'   \item{\code{creel_warning_trip_length_se_undefined}}{Tier 2. Too few trip
#'     durations to give an SE for the mean trip length.}
#'   \item{\code{creel_warning_single_interview_strata}}{Tier 2. Some strata
#'     have one interview, so their SE is undefined.}
#'   \item{\code{creel_warning_single_day_strata}}{Tier 2. Some strata have one
#'     sampled day, so their variance cannot be estimated.}
#'   \item{\code{creel_warning_camera_single_day}}{Tier 2. A stratum has one
#'     paired interview/count day, so its camera calibration SE is `NA`.}
#'   \item{\code{creel_warning_schnabel_ci_upper_unbounded}}{Tier 2. Too few
#'     recaptures for a finite Schnabel Poisson upper limit; `ci_upper` is a
#'     continuous-Poisson stand-in, not a measured bound.}
#'   \item{\code{creel_warning_tost_degenerate}}{Tier 2. Too few degrees of
#'     freedom to test equivalence of complete and incomplete trips.}
#'   \item{\code{creel_warning_se_divergence}}{Tier 2. Variance methods disagree
#'     by more than the threshold.}
#' }
#'
#' @section Sample size:
#' \describe{
#'   \item{\code{creel_warning_small_sample}}{Tier 2. Few interviews behind a
#'     rate, overall or in some groups.}
#'   \item{\code{creel_warning_thin_rate_cells}}{Tier 2. Rate cells in a total
#'     rest on few trips.}
#'   \item{\code{creel_warning_sparse_strata}}{Tier 2. Strata have fewer than
#'     three counts or interviews.}
#'   \item{\code{creel_warning_sparse_groups}}{Tier 2. Groups in a `by`
#'     breakdown have fewer than three observations.}
#'   \item{\code{creel_warning_regression_small_group}}{Tier 2. A group has
#'     fewer than three interviews for regression CPUE.}
#'   \item{\code{creel_warning_low_complete_pct}}{Tier 2. Few interviews are
#'     complete trips.}
#'   \item{\code{creel_warning_low_response_rate}}{Tier 2. Response rate below
#'     50 percent in some strata.}
#' }
#'
#' @section Data checks:
#' \describe{
#'   \item{\code{creel_warning_count_validation}}{Tier 2. Count data failed a
#'     check and estimation continued.}
#'   \item{\code{creel_warning_interview_validation}}{Tier 2. Interview data
#'     failed a check and estimation continued.}
#'   \item{\code{creel_warning_repeated_sampling_units}}{Tier 1. Counts have
#'     repeated sampling units with no count time to tell them apart.}
#'   \item{\code{creel_warning_negative_counts}}{Tier 2. The count column has
#'     negative values.}
#'   \item{\code{creel_warning_negative_catch}}{Tier 2. Interviews have negative
#'     catch.}
#'   \item{\code{creel_warning_negative_effort}}{Tier 2. Interviews have
#'     negative effort.}
#'   \item{\code{creel_warning_missing_effort}}{Tier 2. Interviews have missing
#'     effort.}
#'   \item{\code{creel_warning_short_trips}}{Tier 2. Interviews have effort
#'     under six minutes.}
#'   \item{\code{creel_warning_long_trip_duration}}{Tier 2. Trip durations over
#'     48 hours.}
#'   \item{\code{creel_warning_counted_not_interviewed}}{Tier 2. Parties were
#'     counted but none interviewed.}
#'   \item{\code{creel_warning_party_size_missing}}{Tier 2. Party size has
#'     missing values.}
#'   \item{\code{creel_warning_party_size_fractional}}{Tier 2. Party size has
#'     non-integer values.}
#'   \item{\code{creel_warning_release_count_fractional}}{Tier 2. A release
#'     count has non-integer values.}
#'   \item{\code{creel_warning_catch_unreconciled}}{Tier 2. Harvested plus
#'     released is less than caught for some species-interview pairs.}
#'   \item{\code{creel_warning_camera_negative_duration}}{Tier 2. Camera
#'     ingress-egress pairs with negative duration were dropped.}
#'   \item{\code{creel_warning_camera_imputed_counts}}{Tier 2. Some camera
#'     counts were imputed.}
#'   \item{\code{creel_warning_camera_na_counts}}{Tier 2. Some camera counts are
#'     `NA`.}
#'   \item{\code{creel_warning_high_missingness}}{Tier 2. High missingness in
#'     camera counts in some strata.}
#'   \item{\code{creel_warning_dates_coerced_na}}{Tier 1. Some dates could not
#'     be parsed and became `NA`.}
#'   \item{\code{creel_warning_species_unmatched}}{Tier 2. Some species values
#'     match no known species.}
#'   \item{\code{creel_warning_unknown_label_collision}}{Tier 1. A column holds
#'     both unrecorded values and the literal label used for them.}
#'   \item{\code{creel_warning_catch_totals_diverge}}{Tier 2. Catch-table totals
#'     differ from the interview catch column.}
#' }
#'
#' @section Arguments and calls:
#' \describe{
#'   \item{\code{creel_warning_circuit_time_ignored}}{Tier 1. `circuit_time` was
#'     given for instantaneous counts and is ignored; if the counts are
#'     progressive, effort is computed the wrong way.}
#'   \item{\code{creel_warning_design_type_mismatch}}{Tier 1. The design is not
#'     the type this function expects.}
#'   \item{\code{creel_warning_fragile_schedule}}{Tier 2. Special-period
#'     declarations produced a fragile schedule.}
#' }
#'
#' @section Messages (tier 3):
#' Information is raised as a message, not a warning. Each carries its own
#' class, `creel_message_<fact>`, and the parent class `creel_message`, and is
#' recorded like a warning, with tier 3. Silence one for one call with
#' `invokeRestart("muffleMessage")` in a `creel_message_<fact>` handler.
#' \describe{
#'   \item{\code{creel_message_argument_ignored}}{Tier 3. An argument has no
#'     effect in this call.}
#'   \item{\code{creel_message_day_type_from_stratum}}{Tier 3. A stratum column
#'     is used as the day type.}
#'   \item{\code{creel_message_high_zero_catch}}{Tier 3. A high share of trips
#'     caught nothing, overall or of a species.}
#'   \item{\code{creel_message_internal_svydesign}}{Tier 3. The internal survey
#'     design was accessed; changing it can give wrong variances.}
#'   \item{\code{creel_message_large_delta_pct}}{Tier 3. `delta_pct` looks like
#'     a percentage given as a whole number.}
#'   \item{\code{creel_message_mor_incomplete_trips}}{Tier 3. A rate uses the
#'     mean-of-ratios estimator on incomplete trips; complete trips are
#'     preferred where available.}
#'   \item{\code{creel_message_no_subdesigns}}{Tier 3. No survey sub-designs
#'     were found to adjust.}
#'   \item{\code{creel_message_nonstandard_estimator}}{Tier 3. An unusual
#'     combination of `use_trips` and `estimator` was requested.}
#'   \item{\code{creel_message_species_column_missing}}{Tier 3. The species
#'     column is missing, so the species coverage check was skipped.}
#'   \item{\code{creel_message_truncation_disabled}}{Tier 3. `truncate_at =
#'     NULL` turned short-trip truncation off.}
#'   \item{\code{creel_message_truncation_skipped}}{Tier 3. Mean-of-ratios
#'     truncation was not applied because the design has no trip duration.}
#'   \item{\code{creel_message_zero_counts}}{Tier 3. The count column has
#'     zeros.}
#'   \item{\code{creel_message_within_day_independent}}{Tier 3. Some units on
#'     a day were not counted at the same known occasions, so their within-day
#'     components are added as independent.}
#' }
#'
#' @name creel_warnings
NULL

# Tier of each warning class, read by get_warnings() (GH #496). The tiers
# are the judgment posted on #496 and accepted 2026-10-12. A class raised in
# the code but missing here fails tests/testthat/test-warning-classes.R.
creel_warning_tiers <- c(
  # Tier 1
  creel_warning_all_counts_na = 1L,
  creel_warning_asymmetric_coverage = 1L,
  creel_warning_bin_vcov_unavailable = 1L,
  creel_warning_bootstrap_ignores_strata = 1L,
  creel_warning_camera_unit_ambiguous = 1L,
  creel_warning_catch_is_stratum_total = 1L,
  creel_warning_circuit_time_ignored = 1L,
  creel_warning_dates_coerced_na = 1L,
  creel_warning_design_type_mismatch = 1L,
  creel_warning_estimator_failed = 1L,
  creel_warning_expansion_structure_unknown = 1L,
  creel_warning_exploitation_out_of_range = 1L,
  creel_warning_imputation_convergence = 1L,
  creel_warning_lake_variance_negative = 1L,
  creel_warning_missing_rate_strata = 1L,
  creel_warning_missing_sections = 1L,
  creel_warning_no_party_size = 1L,
  creel_warning_no_period_length = 1L,
  creel_warning_no_recaptures = 1L,
  creel_warning_p_period_coverage = 1L,
  creel_warning_p_period_inferred = 1L,
  creel_warning_pooled_domain_mix = 1L,
  creel_warning_repeated_sampling_units = 1L,
  creel_warning_two_phase_rescale = 1L,
  creel_warning_unit_mismatch = 1L,
  creel_warning_unknown_label_collision = 1L,
  creel_warning_zero_catch_excluded = 1L,
  creel_warning_zero_fish_total = 1L,
  # Tier 2
  creel_warning_camera_imputed_counts = 2L,
  creel_warning_camera_na_counts = 2L,
  creel_warning_camera_negative_duration = 2L,
  creel_warning_camera_single_day = 2L,
  creel_warning_catch_totals_diverge = 2L,
  creel_warning_catch_unreconciled = 2L,
  creel_warning_count_validation = 2L,
  creel_warning_counted_not_interviewed = 2L,
  creel_warning_effort_excluded = 2L,
  creel_warning_fragile_schedule = 2L,
  creel_warning_harvest_excluded = 2L,
  creel_warning_high_missingness = 2L,
  creel_warning_interview_validation = 2L,
  creel_warning_long_trip_duration = 2L,
  creel_warning_low_complete_pct = 2L,
  creel_warning_low_response_rate = 2L,
  creel_warning_missing_effort = 2L,
  creel_warning_mor_truncation = 2L,
  creel_warning_negative_catch = 2L,
  creel_warning_negative_counts = 2L,
  creel_warning_negative_effort = 2L,
  creel_warning_party_size_fractional = 2L,
  creel_warning_party_size_missing = 2L,
  creel_warning_regression_small_group = 2L,
  creel_warning_release_count_fractional = 2L,
  creel_warning_schnabel_ci_upper_unbounded = 2L,
  creel_warning_se_divergence = 2L,
  creel_warning_short_trips = 2L,
  creel_warning_single_day_strata = 2L,
  creel_warning_single_interview_strata = 2L,
  creel_warning_small_sample = 2L,
  creel_warning_sparse_groups = 2L,
  creel_warning_sparse_strata = 2L,
  creel_warning_species_unmatched = 2L,
  creel_warning_thin_rate_cells = 2L,
  creel_warning_tost_degenerate = 2L,
  creel_warning_trip_duration_excluded = 2L,
  creel_warning_trip_length_se_undefined = 2L,
  # Tier 3
  creel_message_argument_ignored = 3L,
  creel_message_day_type_from_stratum = 3L,
  creel_message_high_zero_catch = 3L,
  creel_message_internal_svydesign = 3L,
  creel_message_large_delta_pct = 3L,
  creel_message_mor_incomplete_trips = 3L,
  creel_message_no_subdesigns = 3L,
  creel_message_nonstandard_estimator = 3L,
  creel_message_species_column_missing = 3L,
  creel_message_truncation_disabled = 3L,
  creel_message_truncation_skipped = 3L,
  creel_message_zero_counts = 3L,
  creel_message_within_day_independent = 3L
)

# Classes that print once per design rather than on every call (GH #496): all
# of tier 2, plus the three design facts that used `.frequency = "once"`. A
# period length, a domain missing from the counts, or reaching into the survey
# object is true of the design, not of one estimate, so repeating it on every
# estimate adds nothing; once per session hid it on a different design.
creel_warning_once_per_design <- c(
  names(creel_warning_tiers)[creel_warning_tiers == 2L],
  "creel_warning_no_period_length",
  "creel_warning_pooled_domain_mix",
  "creel_message_internal_svydesign"
)

# The functions that build or rebuild a design. A warning raised inside one
# is about the data it is attaching, so it is not checked against the input
# design's record: adding new data to the same design must print again. A test
# in test-get-warnings.R keeps this list equal to the functions that record a
# design.
creel_design_builders <- c(
  "creel_design", "add_counts", "add_sections", "add_interviews",
  "add_catch", "add_lengths", "add_ages", "adjust_nonresponse"
)
