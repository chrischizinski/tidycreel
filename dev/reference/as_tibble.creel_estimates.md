# Convert estimates to a tibble or data frame

Turns a `creel_estimates` result into a plain table that dplyr, tidyr
and ggplot2 accept, so a result can be filtered, joined, bound to other
results or written out like any other data.

## Usage

``` r
# S3 method for class 'creel_estimates'
as_tibble(x, ..., metadata = TRUE)

# S3 method for class 'creel_estimates'
as.data.frame(x, ..., metadata = TRUE)
```

## Arguments

- x:

  A `creel_estimates` object, as returned by the `estimate_*()`
  functions.

- ...:

  Unused by `as_tibble()`; passed to
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) by
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- metadata:

  If `TRUE` (the default), add the metadata columns described below. If
  `FALSE`, return the estimates table alone.

## Value

A tibble (`as_tibble()`) or data frame
([`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)) with
one row per estimate: the grouping columns, `estimate`, `se`,
`ci_lower`, `ci_upper`, `n` (`NA` where the estimator reports no sample
size) and any further columns the estimator reports. With
`metadata = TRUE` these columns follow:

- `method`:

  The estimation method, e.g. `"total"`.

- `estimator`:

  The rate estimator asked for, e.g. `"ratio-of-means"`. Present only on
  results whose function takes an estimator choice.

- `variance_method`:

  `"taylor"`, `"bootstrap"` or `"jackknife"`.

- `conf_level`:

  Confidence level of `ci_lower` and `ci_upper`.

- `effort_target`:

  What an effort or total estimate totals over, e.g. `"sampled_days"`.
  Present only on results that have one.

- `unit`:

  The unit of `estimate`, e.g. `"angler-hours"`. `NA` means the unit
  could not be derived from the data, not that there is none.

Standard-error components (`x$se_components`) are not returned as
columns, for the reason given in
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/tidy.creel_estimates.md):
read them from the object or from
[`print()`](https://rdrr.io/r/base/print.html).

A grouping column with the same name as a metadata column (a `by` column
called `unit`, say) is an error rather than being overwritten; use
`metadata = FALSE` and read the metadata from the object.

## Details

A `creel_estimates` object keeps what the numbers mean (the method, the
unit, the confidence level) beside its table rather than in attributes
on it, because an ordinary `select()` or
[`filter()`](https://rdrr.io/r/stats/filter.html) drops attributes
without a word. The conversion copies that metadata into columns, so it
travels with every row and is visible if it is dropped.

## See also

[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/tidy.creel_estimates.md)

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/dev/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/dev/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/dev/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/dev/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.com/tidycreel/dev/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.com/tidycreel/dev/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/dev/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.com/tidycreel/dev/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/dev/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/write_estimates.md)

## Examples

``` r
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
est <- estimate_effort(design, by = day_type)
#> Warning: Instantaneous counts were expanded without a period length.
#> ℹ No `period_length_col` was supplied to `add_counts()`, so the estimate is the
#>   count column summed over days.
#> ! If that column holds an instantaneous angler count, the result is in
#>   angler-days, not angler-hours.
#> ℹ Supply the period each count was randomised within: `add_counts(design,
#>   counts, period_length_col = <col>)`.
#> This warning is displayed once per session.

tibble::as_tibble(est)
#> # A tibble: 2 × 13
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n method
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr> 
#> 1 weekday      171.  9.67       9.67         0     150.     192.    10 total 
#> 2 weekend      202.  8.95       8.95         0     182.     221.     4 total 
#> # ℹ 4 more variables: variance_method <chr>, conf_level <dbl>,
#> #   effort_target <chr>, unit <chr>
as.data.frame(est, metadata = FALSE)
#>   day_type estimate       se se_between se_within ci_lower ci_upper  n
#> 1  weekday    170.6 9.673790   9.673790         0 149.5226 191.6774 10
#> 2  weekend    201.9 8.946321   8.946321         0 182.4076 221.3924  4
```
