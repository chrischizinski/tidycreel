# Flag outliers in a creel interview data column

`flag_outliers()` identifies extreme values in a numeric column of a
data frame using Tukey's IQR fence method. Flagged rows are annotated
with `is_outlier`, `outlier_reason`, `fence_low`, and `fence_high`
columns. A `cli` summary of flagged rows is emitted.

## Usage

``` r
flag_outliers(data, col, k = 1.5, na.rm = TRUE)
```

## Arguments

- data:

  A `data.frame` containing the column to check.

- col:

  Bare column name (unquoted) to check for outliers.

- k:

  Numeric IQR multiplier (default: 1.5). Larger values produce wider
  fences and fewer flags. Tukey's standard values are 1.5 (mild
  outliers) and 3.0 (extreme outliers).

- na.rm:

  Logical. Remove `NA` values before computing quantiles (default:
  `TRUE`).

## Value

The input `data` with four additional columns appended:

- is_outlier:

  Logical — `TRUE` if the row is outside the fence.

- outlier_reason:

  Character — brief description of why it is flagged (e.g.
  `"above fence_high (23.5)"`), or `""` if not flagged.

- fence_low:

  Numeric — lower fence value (same for all rows). `NA` when `n < 4`.

- fence_high:

  Numeric — upper fence value (same for all rows). `NA` when `n < 4`.

## Details

**Method:** Tukey's IQR fence. \$\$\text{fence\\low} = Q_1 - k \times
IQR\$\$ \$\$\text{fence\\high} = Q_3 + k \times IQR\$\$

Values below `fence_low` or above `fence_high` are flagged. When
`n < 4`, there is insufficient data to estimate the IQR reliably; fences
are set to `NA` and no rows are flagged.

## See also

[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
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
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

## Examples

``` r
df <- data.frame(
  interview_id = 1:8,
  effort = c(1.0, 1.5, 2.0, 1.8, 1.2, 1.9, 2.1, 15.0)
)
flag_outliers(df, col = effort)
#> ℹ 1 of 8 values flagged as outliers in effort (k = 1.5, fence: [0.525, 2.925]).
#>   interview_id effort is_outlier           outlier_reason fence_low fence_high
#> 1            1    1.0      FALSE                              0.525      2.925
#> 2            2    1.5      FALSE                              0.525      2.925
#> 3            3    2.0      FALSE                              0.525      2.925
#> 4            4    1.8      FALSE                              0.525      2.925
#> 5            5    1.2      FALSE                              0.525      2.925
#> 6            6    1.9      FALSE                              0.525      2.925
#> 7            7    2.1      FALSE                              0.525      2.925
#> 8            8   15.0       TRUE above fence_high (2.925)     0.525      2.925
```
