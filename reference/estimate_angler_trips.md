# Estimate angler trips from extrapolated effort

Computes estimated angler trips (angler days) by dividing extrapolated
angler-hours effort by the mean trip length per stratum, with Delta
Method variance propagation (Powell 2007). This is a composable
estimator: the effort object must be pre-computed via
[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
before calling this function.

## Usage

``` r
estimate_angler_trips(effort, design, conf_level = 0.95, ...)
```

## Arguments

- effort:

  A `creel_estimates` object returned by
  [`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
  Must have a numeric `estimate` column and a `se` column in
  `effort$estimates`.

- design:

  A `creel_design` object with interview data containing a trip duration
  column (set via `add_interviews(trip_duration = ...)`). Used to
  compute per-stratum mean trip length.

- conf_level:

  Confidence level for confidence intervals. Default 0.95.

- ...:

  Reserved for future arguments.

## Value

A `creel_estimates` object with `method = "angler-trips"` and
`variance_method = "delta"`. The `estimates` tibble contains:

- by_vars columns:

  Any grouping columns from the effort object (if grouped).

- estimate:

  Estimated angler trips per stratum (effort / mean trip length).

- se:

  Standard error via Delta Method variance propagation.

- ci_lower:

  Lower confidence interval bound.

- ci_upper:

  Upper confidence interval bound.

- n:

  Number of interviews contributing to mean trip length per stratum.

For grouped effort, an `.overall` row is appended with
`estimate = sum(stratum trips)` and `se` propagated by addition in
quadrature.

## References

Powell, L. A. (2007). Approximating variance of demographic parameters
using the delta method. *Journal of Wildlife Management*, 71(3),
1018-1024.

## See also

[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_exploitation_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)
