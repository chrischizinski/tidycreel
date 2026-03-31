# Assemble pre-computed creel estimates into a report-ready wide tibble

Accepts a named list of pre-computed `creel_estimates` objects (from
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
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

## Examples

``` r
if (FALSE) { # \dontrun{
result <- season_summary(list(effort = my_effort, cpue = my_cpue))
result$table
write_schedule(result$table, "season_2024.csv")
} # }
```
