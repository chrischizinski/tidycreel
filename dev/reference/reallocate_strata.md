# Compute Neyman-optimal sample allocation across strata

Given a fixed total sampling budget, allocates days across strata using
the Neyman optimal allocation formula (Cochran 1977 eq. 5.24), which
assigns more days to strata with larger variability and more calendar
days.

## Usage

``` r
reallocate_strata(n_total, N_h, s2_h, min_n = 2L)
```

## Arguments

- n_total:

  Positive integer. Total sampling days available across all strata.
  Must be at least `sum(pmin(min_n, N_h))` and at most `sum(N_h)`.

- N_h:

  Named numeric vector. Total available days per stratum: whole numbers
  \>= 1.

- s2_h:

  Numeric vector of the same length as `N_h`. Pilot variance of effort
  per day per stratum. Values must be \>= 0.

- min_n:

  Positive integer. The fewest days any stratum may get, so its variance
  can be estimated. Default `2`. A stratum with fewer days than `min_n`
  is sampled completely.

## Value

A named integer vector. Elements named after strata in `N_h` give the
Neyman-optimal sampling days per stratum.

## Details

Neyman allocation (Cochran 1977 eq. 5.24) gives stratum \\h\\ the share
\\n \\ N_h s_h / \sum N_h s_h\\ of the `n_total` days. The result is a
plan the season can carry out:

- **No stratum gets more days than it has, and every stratum gets at
  least `min_n`** (or all its days, if it has fewer), so its variance
  can be estimated. The share is \\\lambda N_h s_h\\ clamped to that
  range, with \\\lambda\\ chosen so the shares spend `n_total`: a
  stratum held at its cap or floor frees or takes days, and the others
  absorb them in proportion to their Neyman weights. This is the Neyman
  allocation with bounds. Strata with zero pilot variance stay at the
  floor unless every other stratum is full.

- **The days sum to `n_total` exactly.** Shares are rounded by largest
  remainder: each stratum gets the whole part of its share, and the days
  left over go to the largest fractional parts.

An `n_total` larger than the season (`sum(N_h)`) or too small to give
every stratum its floor is refused. Before tidycreel 9.0.0 each share
was rounded up independently and nothing was capped, so the plan could
exceed both the budget and a stratum's days (GH \#384).

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

## See also

Other "Planning & Sample Size":
[`audit_strata()`](https://chrischizinski.com/tidycreel/dev/reference/audit_strata.md),
[`compare_designs()`](https://chrischizinski.com/tidycreel/dev/reference/compare_designs.md),
[`creel_n_camera()`](https://chrischizinski.com/tidycreel/dev/reference/creel_n_camera.md),
[`creel_n_cpue()`](https://chrischizinski.com/tidycreel/dev/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.com/tidycreel/dev/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.com/tidycreel/dev/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.com/tidycreel/dev/reference/cv_from_n.md),
[`optimal_n()`](https://chrischizinski.com/tidycreel/dev/reference/optimal_n.md),
[`power_creel()`](https://chrischizinski.com/tidycreel/dev/reference/power_creel.md),
[`simulate_strata_collapse()`](https://chrischizinski.com/tidycreel/dev/reference/simulate_strata_collapse.md)

## Examples

``` r
reallocate_strata(
  n_total = 36,
  N_h     = c(weekday = 65, weekend = 28),
  s2_h    = c(400, 500)
)
#> weekday weekend 
#>      24      12 
```
