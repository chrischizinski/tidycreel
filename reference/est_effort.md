# Estimate Fishing Effort (survey-first wrapper)

High-level convenience wrapper that delegates to the survey-first
instantaneous or progressive estimators. It ensures a valid day-level
survey design is available and passes it to the appropriate estimator.

## Usage

``` r
est_effort(
  design,
  counts,
  method = c("instantaneous", "progressive"),
  by = NULL,
  day_id = "date",
  covariates = NULL,
  conf_level = 0.95,
  ...
)
```

## Arguments

- design:

  A day-level `svydesign`/`svrepdesign` or a `creel_design` that
  contains a `calendar` for constructing a day PSU design.

- counts:

  Data frame/tibble of counts appropriate for the chosen `method`.

- method:

  One of `"instantaneous"` (snapshot counts) or `"progressive"`
  (roving/pass-based counts).

- by:

  Character vector of grouping variables present in `counts`. If `NULL`,
  a best-effort default is used (e.g., `location`, `stratum`,
  `shift_block` where available).

- day_id:

  Day identifier (PSU) present in both `counts` and the survey design
  (default `"date"`).

- covariates:

  Optional character vector of additional grouping variables present in
  `counts`.

- conf_level:

  Confidence level for CIs (default 0.95).

- ...:

  Forwarded to the specific estimator.

## Value

A tibble with group columns, `estimate`, `se`, `ci_low`, `ci_high`, `n`,
`method`, and a `diagnostics` list-column.

## Details

Effort is computed as day × group totals and combined using
[`survey::svytotal`](https://rdrr.io/pkg/survey/man/surveysummary.html)/[`survey::svyby`](https://rdrr.io/pkg/survey/man/svyby.html),
with variance from the survey design (including replicate-weight designs
via `svrepdesign`).

## See also

[`est_effort.instantaneous()`](est_effort.instantaneous.md),
[`est_effort.progressive()`](est_effort.progressive.md),
[`as_day_svydesign()`](as_day_svydesign.md),
[`survey::svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html),
[`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html).

## Examples

``` r
if (FALSE) { # \dontrun{
# Build a day-level design from a calendar
svy_day <- as_day_svydesign(calendar, day_id = "date",
  strata_vars = c("day_type","month"))

# Instantaneous effort by location
est_effort(svy_day, counts_inst, method = "instantaneous", by = "location")

# Progressive effort by location
est_effort(svy_day, counts_roving, method = "progressive", by = "location")
} # }
```
