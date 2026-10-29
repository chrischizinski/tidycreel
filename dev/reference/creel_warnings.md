# Warning classes

Every warning tidycreel raises has a class, so one warning can be
handled in one call without silencing the others. Each carries its own
class, `creel_warning_<fact>`, and the parent class `creel_warning`. A
fact raised in several places has one class wherever it is raised.

Handle one warning for one call with
[`withCallingHandlers()`](https://rdrr.io/r/base/conditions.html):

    withCallingHandlers(
      estimate_catch_rate(design),
      creel_warning_mor_truncation = function(w) invokeRestart("muffleWarning")
    )

Prefer this to
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html), which also
hides the warnings that mean an estimate may be wrong: missing period
length, rate and effort in different units, sections or cells left out
of a total. Errors have a matching family, `creel_error_*`.

Two classes were renamed to this pattern and keep their old names as
well: `creel_warn_two_phase_rescale` and `creel_warn_tost_degenerate`.

Information that is not a warning (tier 3) is raised as a message, with
a class from the matching family `creel_message_<fact>` and the parent
`creel_message`; see the Messages section below.

## Tiers

Each entry starts with its tier, which
[`get_warnings()`](https://chrischizinski.com/tidycreel/dev/reference/get_warnings.md)
also reports:

- Tier 1:

  The estimate may be wrong.

- Tier 2:

  Data quality or precision: worth a look.

- Tier 3:

  Information, raised as a message rather than a warning.

Every warning and tier-3 message is also recorded on the design or
estimate the call returns;
[`get_warnings()`](https://chrischizinski.com/tidycreel/dev/reference/get_warnings.md)
lists them.

Tier 1 warnings print on every call. Tier 2 warnings print once per
design: the first time one is raised on a design it prints, and later
repeats on that design are recorded but not printed. A design is new
each time
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md),
an `add_*()` step or
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/dev/reference/adjust_nonresponse.md)
returns it, so new data print again. Three facts about the design also
print once per design although their tier is not 2:
`creel_warning_no_period_length`, `creel_warning_pooled_domain_mix` and
the message `creel_message_internal_svydesign`. Other tier-3 messages
print on every call.

## Units and scale

- `creel_warning_no_period_length`:

  Tier 1. Instantaneous counts were expanded without a period length, so
  effort is the counts summed over days (angler-days for an angler
  count), not angler-hours.

- `creel_warning_no_party_size`:

  Tier 1. No party size was given, so each interview counts as one
  angler. If interviews are parties, rates are per party-hour, not per
  angler-hour.

- `creel_warning_unit_mismatch`:

  Tier 1. A rate and an effort may be in different units (party-hours
  and angler-hours), so their product may not be a total in fish.

- `creel_warning_camera_unit_ambiguous`:

  Tier 1. Camera ratio calibration cannot tell angler-hours from
  party-hours.

- `creel_warning_catch_is_stratum_total`:

  Tier 1. A catch total supplied to an exploitation rate is a stratum
  total.

- `creel_warning_p_period_coverage`:

  Tier 1. The period lengths divided by `p_period` add to more than 24
  hours a day; the period lengths may already include the probability,
  which would then be applied twice.

- `creel_warning_p_period_inferred`:

  Tier 1. A schedule had periods but no `p_period` column, so the period
  sampling probability was inferred.

## What an estimate covers

- `creel_warning_missing_sections`:

  Tier 1. One or more sections are missing from the count or interview
  data and are not in the estimate.

- `creel_warning_missing_rate_strata`:

  Tier 1. Effort cells with no catch rate were left out of a total.

- `creel_warning_pooled_domain_mix`:

  Tier 1. A total pools over domains the counts do not classify.

- `creel_warning_zero_catch_excluded`:

  Tier 1. Trips that caught none of a species were left out, so the rate
  is among trips that caught it.

- `creel_warning_effort_excluded`:

  Tier 2. Interviews with missing or zero effort were left out of a
  rate.

- `creel_warning_harvest_excluded`:

  Tier 2. Interviews with missing harvest were left out of a harvest
  rate.

- `creel_warning_trip_duration_excluded`:

  Tier 2. Interviews with a missing or non-positive trip duration were
  left out.

- `creel_warning_mor_truncation`:

  Tier 2. 10 percent or more of incomplete trips were shorter than
  `truncate_at` and left out of a mean-of-ratios rate (below 10 percent
  this is a message).

- `creel_warning_two_phase_rescale`:

  Tier 1. Two-phase totals were rescaled onto the reported catch.

- `creel_warning_asymmetric_coverage`:

  Tier 1. Count frames in a hybrid design cover different date-stratum
  cells.

## Estimates that cannot be computed or may be unreliable

- `creel_warning_all_counts_na`:

  Tier 1. Every value in the count column is `NA`.

- `creel_warning_zero_fish_total`:

  Tier 1. The estimated number of fish is zero or negative, so a mean or
  proportion cannot be computed.

- `creel_warning_no_recaptures`:

  Tier 1. No tagged fish were recovered, overall or in a stratum, so the
  exploitation rate is estimated as 0.

- `creel_warning_exploitation_out_of_range`:

  Tier 1. The exploitation rate is outside 0 to 1; its interval is
  clamped.

- `creel_warning_estimator_failed`:

  Tier 1. One of the estimators being compared failed.

- `creel_warning_imputation_convergence`:

  Tier 1. The camera-count imputation model did not converge in a
  stratum.

## Standard errors and intervals

- `creel_warning_bootstrap_ignores_strata`:

  Tier 1. A bootstrap SE does not resample within the design strata.

- `creel_warning_bin_vcov_unavailable`:

  Tier 1. Covariance between length bins is unavailable, so bins are
  treated as independent.

- `creel_warning_expansion_structure_unknown`:

  Tier 1. Party-size expansion groups straddle the estimation cells
  unevenly, so the SE of the total cannot be combined from per-cell
  components.

- `creel_warning_section_covariance_invalid`:

  Tier 1. The sections' day samples overlap too unevenly for their
  effort covariances to form a valid variance, so a sectioned total's
  lake-wide SE and the sections' share SEs are NA.

- `creel_warning_trip_length_se_undefined`:

  Tier 2. Too few trip durations to give an SE for the mean trip length.

- `creel_warning_single_interview_strata`:

  Tier 2. Some strata have one interview, so their SE is undefined.

- `creel_warning_single_day_strata`:

  Tier 2. Some strata have one sampled day, so their variance cannot be
  estimated.

- `creel_warning_camera_single_day`:

  Tier 2. A stratum has one paired interview/count day, so its camera
  calibration SE is `NA`.

- `creel_warning_schnabel_ci_upper_unbounded`:

  Tier 2. Too few recaptures for a finite Schnabel Poisson upper limit;
  `ci_upper` is a continuous-Poisson stand-in, not a measured bound.

- `creel_warning_tost_degenerate`:

  Tier 2. Too few degrees of freedom to test equivalence of complete and
  incomplete trips.

- `creel_warning_se_divergence`:

  Tier 2. Variance methods disagree by more than the threshold.

## Sample size

- `creel_warning_small_sample`:

  Tier 2. Few interviews behind a rate, overall or in some groups.

- `creel_warning_thin_rate_cells`:

  Tier 2. Rate cells in a total rest on few trips.

- `creel_warning_sparse_strata`:

  Tier 2. Strata have fewer than three counts or interviews.

- `creel_warning_sparse_groups`:

  Tier 2. Groups in a `by` breakdown have fewer than three observations.

- `creel_warning_regression_small_group`:

  Tier 2. A group has fewer than three interviews for regression CPUE.

- `creel_warning_low_complete_pct`:

  Tier 2. Few interviews are complete trips.

- `creel_warning_low_response_rate`:

  Tier 2. Response rate below 50 percent in some strata.

## Data checks

- `creel_warning_count_validation`:

  Tier 2. Count data failed a check and estimation continued.

- `creel_warning_interview_validation`:

  Tier 2. Interview data failed a check and estimation continued.

- `creel_warning_repeated_sampling_units`:

  Tier 1. Counts have repeated sampling units with no count time to tell
  them apart.

- `creel_warning_na_counts`:

  Tier 2. Some counts are `NA`; the effort estimate will be `NA` unless
  they are filled or excluded with `missing_count = "exclude"` (GH
  \#561). Not raised on camera designs, which report the gap at
  estimation (`creel_warning_camera_na_counts`).

- `creel_warning_negative_counts`:

  Tier 2. The count column has negative values.

- `creel_warning_negative_catch`:

  Tier 2. Interviews have negative catch.

- `creel_warning_negative_effort`:

  Tier 2. Interviews have negative effort.

- `creel_warning_missing_effort`:

  Tier 2. Interviews have missing effort.

- `creel_warning_short_trips`:

  Tier 2. Interviews have effort under six minutes.

- `creel_warning_long_trip_duration`:

  Tier 2. Trip durations over 48 hours.

- `creel_warning_counted_not_interviewed`:

  Tier 2. Parties were counted but none interviewed.

- `creel_warning_party_size_missing`:

  Tier 2. Party size has missing values.

- `creel_warning_party_size_fractional`:

  Tier 2. Party size has non-integer values.

- `creel_warning_release_count_fractional`:

  Tier 2. A release count has non-integer values.

- `creel_warning_catch_unreconciled`:

  Tier 2. Harvested plus released is less than caught for some
  species-interview pairs.

- `creel_warning_camera_negative_duration`:

  Tier 2. Camera ingress-egress pairs with negative duration were
  dropped.

- `creel_warning_camera_imputed_counts`:

  Tier 2. Some camera counts were imputed.

- `creel_warning_camera_na_counts`:

  Tier 2. Some camera counts are `NA`.

- `creel_warning_high_missingness`:

  Tier 2. High missingness in camera counts in some strata.

- `creel_warning_dates_coerced_na`:

  Tier 1. Some dates could not be parsed and became `NA`.

- `creel_warning_species_unmatched`:

  Tier 2. Some species values match no known species.

- `creel_warning_unknown_label_collision`:

  Tier 1. A column holds both unrecorded values and the literal label
  used for them.

- `creel_warning_catch_totals_diverge`:

  Tier 2. Catch-table totals differ from the interview catch column.

## Arguments and calls

- `creel_warning_circuit_time_ignored`:

  Tier 1. `circuit_time` was given for instantaneous counts and is
  ignored; if the counts are progressive, effort is computed the wrong
  way.

- `creel_warning_design_type_mismatch`:

  Tier 1. The design is not the type this function expects.

- `creel_warning_fragile_schedule`:

  Tier 2. Special-period declarations produced a fragile schedule.

## Messages (tier 3)

Information is raised as a message, not a warning. Each carries its own
class, `creel_message_<fact>`, and the parent class `creel_message`, and
is recorded like a warning, with tier 3. Silence one for one call with
`invokeRestart("muffleMessage")` in a `creel_message_<fact>` handler.

- `creel_message_angler_type_label`:

  Tier 3. A `value_maps` target for `angler_type` differs from `"bank"`
  or `"boat"` only in case or spacing (GH \#563).

- `creel_message_argument_ignored`:

  Tier 3. An argument has no effect in this call.

- `creel_message_day_type_from_stratum`:

  Tier 3. A stratum column is used as the day type.

- `creel_message_high_zero_catch`:

  Tier 3. A high share of trips caught nothing, overall or of a species.

- `creel_message_internal_svydesign`:

  Tier 3. The internal survey design was accessed; changing it can give
  wrong variances.

- `creel_message_large_delta_pct`:

  Tier 3. `delta_pct` looks like a percentage given as a whole number.

- `creel_message_mor_incomplete_trips`:

  Tier 3. A rate uses the mean-of-ratios estimator on incomplete trips;
  complete trips are preferred where available.

- `creel_message_na_counts_excluded`:

  Tier 3. Count rows with an `NA` count were dropped on request
  (`missing_count = "exclude"`).

- `creel_message_no_trip_status_records_dropped`:

  Tier 3. Catch, length or age rows of interviews set aside for having
  no trip status were dropped (GH \#561).

- `creel_message_no_trip_status_excluded`:

  Tier 3. Interviews with no trip status were set aside on request
  (`missing_trip_status = "exclude"`, GH \#561).

- `creel_message_no_subdesigns`:

  Tier 3. No survey sub-designs were found to adjust.

- `creel_message_nonstandard_estimator`:

  Tier 3. An unusual combination of `use_trips` and `estimator` was
  requested.

- `creel_message_refused_interviews_set_aside`:

  Tier 3. Interviews marked refused were set aside: their catch and
  effort are unknown, so no estimate uses them (GH \#557).

- `creel_message_refused_records_dropped`:

  Tier 3. Catch, length or age rows of refused interviews were dropped
  (GH \#557).

- `creel_message_species_column_missing`:

  Tier 3. The species column is missing, so the species coverage check
  was skipped.

- `creel_message_truncation_disabled`:

  Tier 3. `truncate_at = NULL` turned short-trip truncation off.

- `creel_message_truncation_skipped`:

  Tier 3. Mean-of-ratios truncation was not applied because the design
  has no trip duration.

- `creel_message_zero_counts`:

  Tier 3. The count column has zeros.

- `creel_message_within_day_independent`:

  Tier 3. Some units on a day were not counted at the same known
  occasions, so their within-day components are added as independent.
