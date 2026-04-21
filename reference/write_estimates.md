# Export creel survey estimates to a file

Writes a `creel_estimates` or `creel_summary` object to a CSV or xlsx
file. For CSV, a three-line comment block is prepended containing the
estimation method, variance method, confidence level, and generation
timestamp. For xlsx, the data are written directly (Excel does not
support comment rows).

## Usage

``` r
write_estimates(
  x,
  path,
  format = c("auto", "csv", "xlsx"),
  overwrite = FALSE,
  ...
)
```

## Arguments

- x:

  A `creel_estimates` or `creel_summary` object.

- path:

  File path for the output. The extension (`.csv` or `.xlsx`) determines
  the format; alternatively, use the `format` argument to override.

- format:

  One of `"csv"` (default) or `"xlsx"`. When `"csv"`, a comment header
  is prepended. When `"xlsx"`,
  [`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
  is used behind an
  [`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html)
  guard.

- overwrite:

  Logical; if `FALSE` (default) an error is raised when `path` already
  exists.

- ...:

  Currently unused; reserved for future arguments.

## Value

`path`, returned invisibly.

## Details

**CSV format** — The output file begins with comment lines starting with
`#` that record survey metadata:

    # Survey estimates — tidycreel
    # Method: Total Effort | Taylor linearization | 95% CI
    # Generated: 2024-06-15 09:32:11 UTC
    Estimate,SE,CI Lower,CI Upper,N
    372.5,13.18,343.8,401.2,14

These lines can be skipped when reading back with
`utils::read.csv(path, comment.char = "#")`.

**xlsx format** — The data are written without a comment header since
Excel does not natively support comment rows. Row 1 will be the column
headers.

## See also

[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)

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
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md)

## Examples

``` r
data("example_counts")
data("example_interviews")
cal <- unique(example_counts[, c("date", "day_type")])
design <- suppressWarnings(
  creel_design(cal, date = date, strata = day_type) # nolint
)
design <- suppressWarnings(add_counts(design, example_counts))
design <- suppressWarnings(
  add_interviews(
    design, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
eff <- suppressWarnings(estimate_effort(design))

tmp <- tempfile(fileext = ".csv")
write_estimates(eff, tmp)

# Read back (skipping comment lines)
out <- utils::read.csv(tmp, comment.char = "#")
out
#>   Estimate    SE CI.Lower CI.Upper  N
#> 1    372.5 13.18    343.8    401.2 14
```
