# Create Access-Point Survey Design (lean container)

Constructs a lean container for access-point creel surveys. It validates
and stores inputs plus descriptive metadata. Estimation uses
survey-first estimators and day-PSU designs built via
[`as_day_svydesign()`](as_day_svydesign.md). No ad-hoc weighting or
embedded `svydesign` is created here.

## Usage

``` r
design_access(
  interviews,
  calendar,
  locations = NULL,
  strata_vars = c("date", "shift_block", "location"),
  weight_method = c("equal", "standard")
)
```

## Arguments

- interviews:

  Tibble of interview data validated by
  [`validate_interviews()`](validate_interviews.md).

- calendar:

  Tibble of sampling calendar validated by
  [`validate_calendar()`](validate_calendar.md).

- locations:

  Optional character vector of sampling locations; defaults to unique
  locations in `interviews`.

- strata_vars:

  Character vector of variables describing stratification (e.g.,
  `c("date","shift_block","location")`). Missing columns are ignored.

- weight_method:

  Method for calculating design weights. One of "equal" (all weights
  = 1) or "standard" (weights based on target vs actual sample sizes in
  calendar).

## Value

A list with class `c("access_design","creel_design","list")` containing
`design_type`, `interviews`, `calendar`, `locations`, `strata_vars`, and
`metadata`.
