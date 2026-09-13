# Summarise creel survey estimates as a formatted table

`summary.creel_estimates()` converts a `creel_estimates` object into a
`creel_summary` table with human-readable column names, suitable for
display or export.

## Usage

``` r
# S3 method for class 'creel_estimates'
summary(object, digits = 4L, ...)
```

## Arguments

- object:

  A `creel_estimates` object returned by
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/reference/estimate_effort.md),
  [`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_catch_rate.md),
  [`estimate_harvest_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_harvest_rate.md),
  [`estimate_total_catch()`](https://chrischizinski.com/tidycreel/reference/estimate_total_catch.md),
  or
  [`estimate_total_harvest()`](https://chrischizinski.com/tidycreel/reference/estimate_total_harvest.md).

- digits:

  Integer number of significant digits for numeric columns (default: 4).

- ...:

  Additional arguments (currently ignored).

## Value

A `creel_summary` S3 object (a list) with components:

- table:

  A `data.frame` with columns: any grouping variables, `Estimate`, `SE`,
  `CI Lower`, `CI Upper`, `N`.

- method:

  Character string — the estimation method.

- variance_method:

  Character string — the variance method.

- conf_level:

  Numeric confidence level (e.g. 0.95).

## See also

[`estimate_effort()`](https://chrischizinski.com/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_catch_rate.md),
[`estimate_harvest_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_harvest_rate.md)

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/reference/check_completeness.md),
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
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.com/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/reference/write_estimates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
est <- estimate_effort(design)
summary(est)
as.data.frame(summary(est))
} # }
```
