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
#' @section Units and scale:
#' \describe{
#'   \item{\code{creel_warning_no_period_length}}{Instantaneous counts were
#'     expanded without a period length, so effort is the counts summed over
#'     days (angler-days for an angler count), not angler-hours.}
#'   \item{\code{creel_warning_no_party_size}}{No party size was given, so
#'     each interview counts as one angler. If interviews are parties, rates
#'     are per party-hour, not per angler-hour.}
#'   \item{\code{creel_warning_unit_mismatch}}{A rate and an effort may be in
#'     different units (party-hours and angler-hours), so their product may
#'     not be a total in fish.}
#'   \item{\code{creel_warning_camera_unit_ambiguous}}{Camera ratio
#'     calibration cannot tell angler-hours from party-hours.}
#'   \item{\code{creel_warning_catch_is_stratum_total}}{A catch total supplied
#'     to an exploitation rate is a stratum total.}
#'   \item{\code{creel_warning_p_period_coverage}}{The period lengths divided
#'     by `p_period` add to more than 24 hours a day; the period lengths may
#'     already include the probability, which would then be applied twice.}
#'   \item{\code{creel_warning_p_period_inferred}}{A schedule had periods but no
#'     `p_period` column, so the period sampling probability was inferred.}
#' }
#'
#' @section What an estimate covers:
#' \describe{
#'   \item{\code{creel_warning_missing_sections}}{One or more sections are
#'     missing from the count or interview data and are not in the estimate.}
#'   \item{\code{creel_warning_missing_rate_strata}}{Effort cells with no
#'     catch rate were left out of a total.}
#'   \item{\code{creel_warning_pooled_domain_mix}}{A total pools over domains
#'     the counts do not classify.}
#'   \item{\code{creel_warning_zero_catch_excluded}}{Trips that caught none of
#'     a species were left out, so the rate is among trips that caught it.}
#'   \item{\code{creel_warning_effort_excluded}}{Interviews with missing or
#'     zero effort were left out of a rate.}
#'   \item{\code{creel_warning_harvest_excluded}}{Interviews with missing
#'     harvest were left out of a harvest rate.}
#'   \item{\code{creel_warning_trip_duration_excluded}}{Interviews with a
#'     missing or non-positive trip duration were left out.}
#'   \item{\code{creel_warning_mor_truncation}}{10 percent or more of incomplete
#'     trips were shorter than `truncate_at` and left out of a mean-of-ratios
#'     rate (below 10 percent this is a message).}
#'   \item{\code{creel_warning_truncation_skipped}}{Mean-of-ratios truncation
#'     was not applied because the design has no trip duration.}
#'   \item{\code{creel_warning_truncation_disabled}}{`truncate_at = NULL` turned
#'     short-trip truncation off.}
#'   \item{\code{creel_warning_two_phase_rescale}}{Two-phase totals were
#'     rescaled onto the reported catch.}
#'   \item{\code{creel_warning_asymmetric_coverage}}{Count frames in a hybrid
#'     design cover different date-stratum cells.}
#' }
#'
#' @section Estimates that cannot be computed or may be unreliable:
#' \describe{
#'   \item{\code{creel_warning_all_counts_na}}{Every value in the count column
#'     is `NA`.}
#'   \item{\code{creel_warning_zero_fish_total}}{The estimated number of fish
#'     is zero or negative, so a mean or proportion cannot be computed.}
#'   \item{\code{creel_warning_no_recaptures}}{No tagged fish were recovered,
#'     overall or in a stratum, so the exploitation rate is estimated as 0.}
#'   \item{\code{creel_warning_exploitation_out_of_range}}{The exploitation
#'     rate is outside 0 to 1; its interval is clamped.}
#'   \item{\code{creel_warning_estimator_failed}}{One of the estimators being
#'     compared failed.}
#'   \item{\code{creel_warning_imputation_convergence}}{The camera-count
#'     imputation model did not converge in a stratum.}
#'   \item{\code{creel_warning_nonstandard_estimator}}{An unusual combination
#'     of `use_trips` and `estimator` was requested.}
#'   \item{\code{creel_warning_mor_incomplete_trips}}{A rate uses the
#'     mean-of-ratios estimator on incomplete trips; complete trips are
#'     preferred where available.}
#' }
#'
#' @section Standard errors and intervals:
#' \describe{
#'   \item{\code{creel_warning_bootstrap_ignores_strata}}{A bootstrap SE does
#'     not resample within the design strata.}
#'   \item{\code{creel_warning_bin_vcov_unavailable}}{Covariance between
#'     length bins is unavailable, so bins are treated as independent.}
#'   \item{\code{creel_warning_expansion_structure_unknown}}{Party-size
#'     expansion groups straddle the estimation cells unevenly, so the SE of
#'     the total cannot be combined from per-cell components.}
#'   \item{\code{creel_warning_trip_length_se_undefined}}{Too few trip
#'     durations to give an SE for the mean trip length.}
#'   \item{\code{creel_warning_single_interview_strata}}{Some strata have one
#'     interview, so their SE is undefined.}
#'   \item{\code{creel_warning_single_day_strata}}{Some strata have one
#'     sampled day, so their variance cannot be estimated.}
#'   \item{\code{creel_warning_camera_single_day}}{A stratum has one paired
#'     interview/count day, so its camera calibration SE is `NA`.}
#'   \item{\code{creel_warning_schnabel_ci_upper_unbounded}}{Too few
#'     recaptures for a finite Schnabel Poisson upper limit; `ci_upper` is a
#'     continuous-Poisson stand-in, not a measured bound.}
#'   \item{\code{creel_warning_tost_degenerate}}{Too few degrees of freedom to
#'     test equivalence of complete and incomplete trips.}
#'   \item{\code{creel_warning_se_divergence}}{Variance methods disagree by
#'     more than the threshold.}
#' }
#'
#' @section Sample size:
#' \describe{
#'   \item{\code{creel_warning_small_sample}}{Few interviews behind a rate,
#'     overall or in some groups.}
#'   \item{\code{creel_warning_thin_rate_cells}}{Rate cells in a total rest on
#'     few trips.}
#'   \item{\code{creel_warning_sparse_strata}}{Strata have fewer than three
#'     counts or interviews.}
#'   \item{\code{creel_warning_sparse_groups}}{Groups in a `by` breakdown have
#'     fewer than three observations.}
#'   \item{\code{creel_warning_regression_small_group}}{A group has fewer than
#'     three interviews for regression CPUE.}
#'   \item{\code{creel_warning_low_complete_pct}}{Few interviews are complete
#'     trips.}
#'   \item{\code{creel_warning_low_response_rate}}{Response rate below 50 percent in
#'     some strata.}
#' }
#'
#' @section Data checks:
#' \describe{
#'   \item{\code{creel_warning_count_validation}}{Count data failed a check
#'     and estimation continued.}
#'   \item{\code{creel_warning_interview_validation}}{Interview data failed a
#'     check and estimation continued.}
#'   \item{\code{creel_warning_repeated_sampling_units}}{Counts have repeated
#'     sampling units with no count time to tell them apart.}
#'   \item{\code{creel_warning_zero_counts}}{The count column has zeros.}
#'   \item{\code{creel_warning_negative_counts}}{The count column has negative
#'     values.}
#'   \item{\code{creel_warning_negative_catch}}{Interviews have negative
#'     catch.}
#'   \item{\code{creel_warning_negative_effort}}{Interviews have negative
#'     effort.}
#'   \item{\code{creel_warning_missing_effort}}{Interviews have missing
#'     effort.}
#'   \item{\code{creel_warning_short_trips}}{Interviews have effort under six
#'     minutes.}
#'   \item{\code{creel_warning_long_trip_duration}}{Trip durations over 48
#'     hours.}
#'   \item{\code{creel_warning_high_zero_catch}}{A high share of trips caught
#'     nothing, overall or of a species.}
#'   \item{\code{creel_warning_counted_not_interviewed}}{Parties were counted
#'     but none interviewed.}
#'   \item{\code{creel_warning_party_size_missing}}{Party size has missing
#'     values.}
#'   \item{\code{creel_warning_party_size_fractional}}{Party size has
#'     non-integer values.}
#'   \item{\code{creel_warning_release_count_fractional}}{A release count has
#'     non-integer values.}
#'   \item{\code{creel_warning_catch_unreconciled}}{Harvested plus released is
#'     less than caught for some species-interview pairs.}
#'   \item{\code{creel_warning_catch_totals_diverge}}{Catch-table totals
#'     differ from the interview catch column.}
#'   \item{\code{creel_warning_camera_negative_duration}}{Camera
#'     ingress-egress pairs with negative duration were dropped.}
#'   \item{\code{creel_warning_camera_imputed_counts}}{Some camera counts
#'     were imputed.}
#'   \item{\code{creel_warning_camera_na_counts}}{Some camera counts are
#'     `NA`.}
#'   \item{\code{creel_warning_high_missingness}}{High missingness in camera
#'     counts in some strata.}
#'   \item{\code{creel_warning_dates_coerced_na}}{Some dates could not be
#'     parsed and became `NA`.}
#'   \item{\code{creel_warning_species_unmatched}}{Some species values match
#'     no known species.}
#'   \item{\code{creel_warning_species_column_missing}}{The species column is
#'     missing, so the species coverage check was skipped.}
#'   \item{\code{creel_warning_unknown_label_collision}}{A column holds both
#'     unrecorded values and the literal label used for them.}
#' }
#'
#' @section Arguments and calls:
#' \describe{
#'   \item{\code{creel_warning_argument_ignored}}{An argument has no effect in
#'     this call.}
#'   \item{\code{creel_warning_design_type_mismatch}}{The design is not the
#'     type this function expects.}
#'   \item{\code{creel_warning_day_type_from_stratum}}{A stratum column is used
#'     as the day type.}
#'   \item{\code{creel_warning_internal_svydesign}}{The internal survey design
#'     was accessed; changing it can give wrong variances.}
#'   \item{\code{creel_warning_no_subdesigns}}{No survey sub-designs were
#'     found to adjust.}
#'   \item{\code{creel_warning_large_delta_pct}}{`delta_pct` looks like a
#'     percentage given as a whole number.}
#'   \item{\code{creel_warning_fragile_schedule}}{Special-period declarations
#'     produced a fragile schedule.}
#' }
#'
#' @name creel_warnings
NULL
