# Check post-season data completeness for a creel design

Dispatches by survey_type to avoid false-positive warnings on aerial and
camera designs that do not collect interview data.

## Usage

``` r
check_completeness(design, n_min = 10L)
```

## Arguments

- design:

  A creel_design object with counts (and optionally interviews)
  attached.

- n_min:

  Integer scalar \>= 1. Interview threshold below which a stratum is
  flagged as low-n. Default 10L.

## Value

A creel_completeness_report object (S3 list) with:

- \$missing_days:

  data.frame of calendar rows with no count data

- \$low_n_strata:

  data.frame of strata below n_min, or NULL for aerial/camera

- \$refusals:

  creel_summary_refusals object or NULL

- \$n_min:

  integer threshold used

- \$survey_type:

  character

- \$passed:

  logical – TRUE if no missing days and no low-n strata

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/reference/adjust_nonresponse.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.com/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.com/tidycreel/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.com/tidycreel/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.com/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.com/tidycreel/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.com/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.com/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.com/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.com/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.com/tidycreel/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.com/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.com/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.com/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.com/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.com/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/reference/write_estimates.md)
