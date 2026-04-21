# Calculate interviews required to achieve a target CV on CPUE

Determines the number of interviews needed to achieve a target
coefficient of variation on a CPUE (catch-per-unit-effort) ratio
estimate, using the ratio-estimator variance approximation from Cochran
(1977).

## Usage

``` r
creel_n_cpue(cv_catch, cv_effort, rho = 0, cv_target)
```

## Arguments

- cv_catch:

  Numeric scalar. Pilot coefficient of variation of catch per interview
  (the numerator of the CPUE ratio). Must be \> 0.

- cv_effort:

  Numeric scalar. Pilot coefficient of variation of effort per interview
  (the denominator of the CPUE ratio). Must be \> 0.

- rho:

  Numeric scalar. Pilot correlation between catch and effort per
  interview. Must be in \[-1, 1\]. Default is 0 (conservative;
  over-estimates required n when catch and effort are positively
  correlated).

- cv_target:

  Numeric scalar. Target coefficient of variation for the CPUE estimate.
  Must be in (0, 1\].

## Value

An integer scalar (\>= 1): number of interviews required.

## Details

Implements the ratio-estimator variance approximation from Cochran
(1977, Chapter 6) parameterised in terms of coefficients of variation
rather than raw variances, which is more natural for pre-season
planning:

\$\$n = \left\lceil \frac{CV\_{catch}^2 + CV\_{effort}^2 - 2 \rho \cdot
CV\_{catch} \cdot CV\_{effort}}{CV\_{target}^2} \right\rceil\$\$

Setting `rho = 0` (the default) is conservative: it over-estimates the
required sample size when catch and effort are positively correlated.
Users with pilot data should supply the observed correlation to obtain a
less conservative estimate.

The result is floored at 1L to ensure at least one interview is
recommended.

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.
Chapter 6 (ratio estimator variance approximation).

## See also

Other "Planning & Sample Size":
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md),
[`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md)

## Examples

``` r
# rho = 0 (conservative, no pilot correlation data)
creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)
#> [1] 23

# With known positive correlation (smaller n)
creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0.5, cv_target = 0.20)
#> [1] 13
```
