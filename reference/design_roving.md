# Create Roving Survey Design (lean container)

Constructs a lean container for roving creel surveys. It validates and
stores inputs plus descriptive metadata. Estimation of effort should use
survey-first estimators on counts (instantaneous or progressive) coupled
with a day-PSU design from [`as_day_svydesign()`](as_day_svydesign.md).
No ad-hoc weighting or embedded `svydesign` is created here.

## Usage

``` r
design_roving(
  interviews,
  counts,
  calendar,
  locations = NULL,
  strata_vars = c("date", "shift_block", "location"),
  effort_method = c("ratio", "calibrate"),
  coverage_correction = FALSE
)
```

## Arguments

- interviews:

  Tibble validated by [`validate_interviews()`](validate_interviews.md).

- counts:

  Tibble validated by [`validate_counts()`](validate_counts.md).

- calendar:

  Tibble validated by [`validate_calendar()`](validate_calendar.md).

- locations:

  Optional character vector; defaults to union of interview and count
  locations.

- strata_vars:

  Character vector describing stratification (e.g.,
  `c("date","shift_block","location")`). Missing columns are ignored.

- effort_method:

  Method for effort estimation. One of "ratio" or "calibrate".

- coverage_correction:

  Logical; whether to apply coverage correction for incomplete survey
  days. Default is FALSE.

## Value

A list with class `c("roving_design","creel_design","list")` containing
`design_type`, `interviews`, `counts`, `calendar`, `locations`,
`strata_vars`, and `metadata`.
