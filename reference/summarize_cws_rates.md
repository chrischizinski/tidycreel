# Compute caught-while-sought (CWS) rates by group

Computes mean caught-while-sought rates (fish per angler-hour) for
anglers targeting each species. For each interview, the rate is:
`caught_count / angler_effort` where `caught_count` is the total number
of fish caught of the species the angler was seeking, and
`angler_effort` is angler-hours (effort x n_anglers, standardized at
design time by
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)).

## Usage

``` r
summarize_cws_rates(design, by = NULL, conf_level = 0.95)
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  (with `species_sought`) and species catch data attached via
  [`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md).

- by:

  Optional tidy selector for grouping columns from `design$interviews`.
  Common choices: `by = species_sought` (CWS-03),
  `by = c(month, species_sought)` (CWS-02),
  `by = c(month, angler_type, species_sought)` (CWS-01). When `NULL`,
  returns a single overall rate across all interviews.

- conf_level:

  Numeric confidence level for the t-interval. Default 0.95.

## Value

A `data.frame` with class `c("creel_summary_cws_rates", "data.frame")`
and columns: grouping columns (if any), `N` (integer, interviews per
group), `mean_rate` (numeric, mean fish/angler-hour), `se` (numeric,
standard error), `ci_lower`, `ci_upper`.

## Details

**Interview-based summary, not pressure-weighted.** This function
computes a simple arithmetic mean over sampled interviews. It does NOT
apply survey weighting by sampling effort or effort stratum. For
pressure-weighted extrapolated estimates use
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md).

The catch filter ensures only species the angler was targeting are
counted (i.e., rows in `design$catch` where `catch_type == "caught"` and
`species == species_sought`).

## See also

[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)

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
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_catch)
d <- creel_design(example_calendar, date = date, strata = day_type)
d <- add_interviews(d, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, species_sought = species_sought
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
d <- add_catch(d, example_catch,
  catch_uid = interview_id, interview_uid = interview_id,
  species = species, count = count, catch_type = catch_type
)
summarize_cws_rates(d, by = species_sought)
#>   species_sought  N mean_rate        se    ci_lower  ci_upper
#> 1           bass  6 0.2083333 0.2083333 -0.32720455 0.7438712
#> 2        panfish  5 0.4666667 0.4666667 -0.82900772 1.7623410
#> 3        walleye 11 0.7835498 0.3359583  0.03498793 1.5321116
```
