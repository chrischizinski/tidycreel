# Generate a validation summary report

Runs
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md)
on `counts` and/or `interviews`, aggregates the results into a
human-readable summary tibble (one row per table x check type), and
optionally detects unrecognised species values via
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md).

## Usage

``` r
validation_report(
  counts = NULL,
  interviews = NULL,
  species_col = NULL,
  na_threshold = 0.1,
  date_range = c(as.Date("1970-01-01"), as.Date("2100-12-31"))
)
```

## Arguments

- counts:

  A data frame of count (effort) observations, or `NULL`.

- interviews:

  A data frame of interview observations, or `NULL`.

- species_col:

  Character scalar. If non-`NULL` and `interviews` is provided, calls
  [`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md)
  on this column and appends a `species_coverage` row showing the
  fraction of rows successfully matched to an AFS code. Default `NULL`
  (no species check).

- na_threshold:

  Passed to
  [`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md).
  Default `0.10`.

- date_range:

  Passed to
  [`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md).
  Default `c(as.Date("1970-01-01"), as.Date("2100-12-31"))`.

## Value

An object of class `creel_validation_report` - a data frame with
columns:

- `table`:

  Source table: `"counts"`, `"interviews"`, or `"species"`.

- `check`:

  Check type (e.g. `"na_rate"`, `"date_range"`).

- `n_pass`:

  Number of columns with `"pass"` status.

- `n_warn`:

  Number of columns with `"warn"` status.

- `n_fail`:

  Number of columns with `"fail"` status.

- `detail`:

  Comma-separated list of flagged columns, or `"all ok"`.

## Details

The returned object is a `creel_validation_report` - a data frame with a
custom `print` method that renders a colour-coded cli summary. It can be
exported with
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md).

## See also

[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
counts <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekend"),
  count    = c(10L, NA_integer_)
)
interviews <- data.frame(
  date      = as.Date(c("2024-06-01", "2024-06-02")),
  fish_kept = c(2L, -1L),
  species   = c("walleye", "")
)
rpt <- validation_report(counts, interviews, species_col = "species")
print(rpt)
} # }
```
