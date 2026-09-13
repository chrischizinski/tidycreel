# Assemble pre-computed creel estimates into a report-ready wide tibble

Accepts a named list of pre-computed `creel_estimates` objects (from
[`estimate_effort()`](https://chrischizinski.com/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_catch_rate.md),
etc.) and joins them into a single wide tibble — one row per stratum
with all estimate types as prefixed columns.

## Usage

``` r
season_summary(estimates, ...)
```

## Arguments

- estimates:

  A named list of `creel_estimates` objects. Names become column
  prefixes in the wide tibble (e.g., `list(effort = ..., cpue = ...)`).

- ...:

  Reserved for future arguments.

## Value

A `creel_season_summary` object (S3 list) with:

- `$table`: A wide tibble — columns prefixed by list element name.

- `$names`: Character vector of input list element names.

- `$n_estimates`: Integer count of estimates assembled.

## Details

**Note:** `season_summary()` performs no re-estimation. All statistical
computations must be done before calling this function.

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/reference/flag_outliers.md),
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

## Examples

``` r
data(example_calendar)
data(example_counts)
data(example_interviews)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

result <- season_summary(list(
  effort     = estimate_effort(design),
  catch_rate = estimate_catch_rate(design)
))
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
result$table
#> # A tibble: 1 × 12
#>   effort_estimate effort_se effort_se_between effort_se_within effort_ci_lower
#>             <dbl>     <dbl>             <dbl>            <dbl>           <dbl>
#> 1            372.      13.2              13.2                0            344.
#> # ℹ 7 more variables: effort_ci_upper <dbl>, effort_n <int>,
#> #   catch_rate_estimate <dbl>, catch_rate_se <dbl>, catch_rate_ci_lower <dbl>,
#> #   catch_rate_ci_upper <dbl>, catch_rate_n <int>
result$n_estimates
#> [1] 2
```
