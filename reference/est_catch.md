# Catch/Harvest Total Estimator (survey-first)

Design-based estimation of total catch or harvest from interview data
using the `survey` package. Returns tidy totals by groups with standard
errors and Wald confidence intervals.

## Usage

``` r
est_catch(
  design,
  by = NULL,
  response = c("catch_total", "catch_kept", "weight_total"),
  conf_level = 0.95
)
```

## Arguments

- design:

  A `svydesign`/`svrepdesign` over interviews, or a `creel_design` with
  `interviews` (an equal-weight design is constructed if needed, with a
  warning).

- by:

  Character vector of grouping variables in the interview data.

- response:

  One of `"catch_total"`, `"catch_kept"`, or `"weight_total"`.
  Determines the total being estimated.

- conf_level:

  Confidence level for Wald CIs (default 0.95).

## Value

Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
`n`, `method`, and a `diagnostics` list-column.

## See also

[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html),
[`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html).
