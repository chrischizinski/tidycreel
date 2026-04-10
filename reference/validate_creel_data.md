# Validate creel survey data frames

Runs field-level schema and quality checks on counts and/or interview
data frames, returning a tidy results tibble with a pass/warn/fail
verdict per column check. A `print` method renders a colour-coded `cli`
summary.

## Usage

``` r
validate_creel_data(
  counts = NULL,
  interviews = NULL,
  na_threshold = 0.1,
  date_range = c(as.Date("1970-01-01"), as.Date("2100-12-31"))
)
```

## Arguments

- counts:

  A data frame of count (effort) observations, or `NULL` to skip.

- interviews:

  A data frame of interview observations, or `NULL` to skip.

- na_threshold:

  Numeric scalar in \\\[0, 1\]\\. Columns with an NA rate above this
  threshold receive a `"warn"` status. Default `0.10`.

- date_range:

  A length-2 `Date` vector giving the earliest and latest plausible
  dates. Default `c(as.Date("1970-01-01"), as.Date("2100-12-31"))`.

## Value

An object of class `creel_data_validation` - a tibble with columns:

- `table`:

  Which input was checked: `"counts"` or `"interviews"`.

- `column`:

  Column name.

- `check`:

  Short check label (e.g. `"na_rate"`, `"negative_values"`, `"type"`).

- `status`:

  `"pass"`, `"warn"`, or `"fail"`.

- `detail`:

  Human-readable detail string.

## Details

Checks performed for **every** column:

- Type check - column class is reported.

- NA rate - warns if \\\>\\ `na_threshold` (default 0.10) of values are
  `NA`.

Additional checks based on detected column role:

- **Date columns** - values must fall within `date_range` (defaults to
  1970-01-01 - 2100-12-31); warns on future dates.

- **Numeric columns** - warns if any value is negative (effort/count
  should be \\\ge 0\\).

- **Character/factor columns** - warns if any value is an empty string.

## See also

[`validate_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schedule.md)
for schedule-specific validation.

## Examples

``` r
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
res <- validate_creel_data(counts, interviews)
print(res)
#> 
#> ── Creel Data Validation ───────────────────────────────────────────────────────
#> 15 pass | 3 warn | 0 fail
#> 
#> 
#> ── Table: counts ──
#> 
#> ✔ date
#> ✔ type: class: Date
#> ✔ na_rate: 0 / 2 NA (0%)
#> ✔ date_range: all within 1970-01-01 - 2100-12-31
#> ✔ day_type
#> ✔ type: class: character
#> ✔ na_rate: 0 / 2 NA (0%)
#> ✔ empty_strings: none
#> ! count
#> ✔ type: class: integer
#> ⚠ na_rate: 1 / 2 NA (50%)
#> ✔ negative_values: none
#> 
#> 
#> ── Table: interviews ──
#> 
#> ✔ date
#> ✔ type: class: Date
#> ✔ na_rate: 0 / 2 NA (0%)
#> ✔ date_range: all within 1970-01-01 - 2100-12-31
#> ! fish_kept
#> ✔ type: class: integer
#> ✔ na_rate: 0 / 2 NA (0%)
#> ⚠ negative_values: 1 negative value(s)
#> ! species
#> ✔ type: class: character
#> ✔ na_rate: 0 / 2 NA (0%)
#> ⚠ empty_strings: 1 empty string(s)
#> 
```
