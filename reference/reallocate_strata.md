# Compute Neyman-optimal sample allocation across strata

Given a fixed total sampling budget, allocates days across strata using
the Neyman optimal allocation formula (Cochran 1977 eq. 5.24), which
assigns more days to strata with larger variability and more calendar
days.

## Usage

``` r
reallocate_strata(n_total, N_h, s2_h)
```

## Arguments

- n_total:

  Positive integer. Total sampling days available across all strata.

- N_h:

  Named numeric vector. Total available days per stratum. Values must be
  \>= 1.

- s2_h:

  Numeric vector of the same length as `N_h`. Pilot variance of effort
  per day per stratum. Values must be \>= 0.

## Value

A named integer vector. Elements named after strata in `N_h` give the
Neyman-optimal sampling days per stratum.

## Details

Neyman allocation:
`n_h = ceiling(n_total * (N_h * sqrt(s2_h)) / sum(N_h * sqrt(s2_h)))`.

Because each stratum's allocation is ceiling-ed independently, the sum
of returned values may slightly exceed `n_total`.

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

## See also

Other "Planning & Sample Size":
[`audit_strata()`](https://chrischizinski.github.io/tidycreel/reference/audit_strata.md),
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md),
[`optimal_n()`](https://chrischizinski.github.io/tidycreel/reference/optimal_n.md),
[`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md),
[`simulate_strata_collapse()`](https://chrischizinski.github.io/tidycreel/reference/simulate_strata_collapse.md)

## Examples

``` r
reallocate_strata(
  n_total = 36,
  N_h     = c(weekday = 65, weekend = 28),
  s2_h    = c(400, 500)
)
#> weekday weekend 
#>      25      12 
```
