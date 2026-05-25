# Compute effort density as angler-hours per acre

Divides all effort estimate columns in a pre-computed `creel_estimates`
object by a surface area scalar (`acres`), producing angler-hours per
acre. Standard error propagates linearly because `acres` is a constant
(not a random variable), so no Delta Method is needed:
`se_per_acre = se_effort / acres`.

This is a composable estimator: the effort object must be pre-computed
via
[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
before calling this function.

## Usage

``` r
estimate_effort_per_acre(effort, acres, ...)
```

## Arguments

- effort:

  A `creel_estimates` object returned by
  [`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
  Must contain `estimate`, `se`, `ci_lower`, and `ci_upper` columns in
  `effort$estimates`.

- acres:

  A single positive numeric scalar giving the total lake surface area in
  acres. All effort estimate columns are divided by this value.

- ...:

  Reserved for future arguments.

## Value

A `creel_estimates` object with `method = "effort-per-acre"`. The
`estimates` tibble has the same rows as the input but with `estimate`,
`se`, `ci_lower`, `ci_upper` (and `se_between`, `se_within` when present
in the input) all divided by `acres`. Grouping columns (`by_vars`) and
`n` are carried through unchanged. `variance_method` and `conf_level`
are inherited from the input effort object.

## See also

[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_angler_trips`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_trips.md)
