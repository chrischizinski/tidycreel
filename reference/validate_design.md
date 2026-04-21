# Validate a proposed creel survey design against sample size targets

Pre-season design check: runs creel_n_effort() and creel_n_cpue() per
stratum and returns a pass/warn/fail status report.

## Usage

``` r
validate_design(
  N_h,
  ybar_h,
  s2_h,
  n_proposed,
  cv_target,
  type = c("effort", "cpue"),
  cv_catch = NULL,
  cv_effort = NULL,
  rho = 0
)
```

## Arguments

- N_h:

  Named numeric vector. Total available sampling days per stratum.

- ybar_h:

  Numeric vector (same length as N_h). Pilot mean effort per day per
  stratum.

- s2_h:

  Numeric vector (same length as N_h). Pilot variance of effort per
  stratum.

- n_proposed:

  Named integer vector (same length as N_h). Proposed sampling days per
  stratum.

- cv_target:

  Numeric scalar. Target CV for the effort estimate.

- type:

  Character. One of "effort" or "cpue". Default "effort".

- cv_catch:

  Numeric scalar. Required when type = "cpue".

- cv_effort:

  Numeric scalar. Required when type = "cpue".

- rho:

  Numeric scalar. Correlation between catch and effort. Default 0.

## Value

A creel_design_report object (S3 list) with:

- \$results:

  tibble with columns stratum, status, n_proposed, n_required,
  cv_actual, cv_target, message

- \$passed:

  logical – TRUE if all strata status == "pass"

- \$survey_type:

  character

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)
