# Create Bus Route Survey Design

Constructs a lean design container for bus-route creel surveys. This
design holds validated inputs and metadata; estimation is performed with
survey-first estimators (e.g.,
[`est_effort.busroute_design()`](est_effort.busroute_design.md)) that
rely on a day-PSU survey design from
[`as_day_svydesign()`](as_day_svydesign.md). No ad-hoc weighting is
performed here.

## Usage

``` r
design_busroute(
  interviews,
  counts,
  calendar,
  route_schedule,
  strata_vars = c("date", "location")
)
```

## Arguments

- interviews:

  Tibble of interview data validated by
  [`validate_interviews()`](validate_interviews.md).

- counts:

  Tibble of count/observation data validated by
  [`validate_counts()`](validate_counts.md). For HT-style effort
  estimation, counts should include inclusion probabilities (e.g.,
  `inclusion_prob`) or sufficient fields to derive them upstream.

- calendar:

  Tibble of the sampling calendar validated by
  [`validate_calendar()`](validate_calendar.md). Used to construct
  day-level `svydesign` with
  [`as_day_svydesign()`](as_day_svydesign.md).

- route_schedule:

  Tibble describing the bus-route schedule (e.g., stop, time, planned
  coverage). Used for diagnostics and documentation; not used to compute
  weights here.

- strata_vars:

  Character vector for descriptive stratification metadata (e.g.,
  `c("date","location")`). Missing columns are ignored.

## Value

A list with class `c("busroute_design","creel_design","list")` and
fields: `design_type`, `interviews`, `counts`, `calendar`,
`route_schedule`, `strata_vars`, and `metadata`.

## Examples

``` r
# design <- design_busroute(interviews, counts, calendar, route_schedule)
```
