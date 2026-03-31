# Compute the expected CV achievable with a known sample size

Calculates the coefficient of variation attainable given a fixed sample
size, acting as the algebraic inverse of
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
(when `type = "effort"`) or
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)
(when `type = "cpue"`).

## Usage

``` r
cv_from_n(type = c("effort", "cpue"), n, ...)
```

## Arguments

- type:

  Character. Either `"effort"` or `"cpue"`. Selects the formula branch
  and required additional arguments.

- n:

  Integerish scalar (\>= 1). Available sample size (sampling days for
  `"effort"`, interviews for `"cpue"`).

- ...:

  Additional arguments passed to the relevant branch:

  **For `type = "effort"`:**

  - `N_h` — Named numeric vector; total available days per stratum (\>=
    1).

  - `ybar_h` — Numeric vector; pilot mean effort per day per stratum
    (\>= 0).

  - `s2_h` — Numeric vector; pilot variance of effort per day per
    stratum (\>= 0).

  **For `type = "cpue"`:**

  - `cv_catch` — Numeric scalar; pilot CV of catch per interview (\> 0).

  - `cv_effort` — Numeric scalar; pilot CV of effort per interview (\>
    0).

  - `rho` — Numeric scalar; pilot correlation between catch and effort,
    in \[-1, 1\]. Default is 0.

## Value

A numeric scalar (\> 0): the expected CV achievable at sample size `n`.

## Details

**Effort branch** (`type = "effort"`): \$\$CV = \frac{\sqrt{\sum_h N_h
s_h^2 / n}}{\sum_h N_h \bar{y}\_h}\$\$

This is the inverse of the Cochran (1977) stratified sample-size formula
implemented in
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md).

**CPUE branch** (`type = "cpue"`): \$\$CV = \sqrt{(CV\_{catch}^2 +
CV\_{effort}^2 - 2\rho \cdot CV\_{catch} \cdot CV\_{effort}) / n}\$\$

This is the inverse of the ratio-estimator formula implemented in
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md).

Because
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
and
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)
apply [`ceiling()`](https://rdrr.io/r/base/Round.html), the round-trip
property is `cv_from_n(type, n = creel_n_*(cv, ...), ...) <= cv` (the
recovered CV is at or below the target).

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

## See also

[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)

## Examples

``` r
# Effort round-trip
n_days <- creel_n_effort(0.20,
  N_h = c(weekday = 65, weekend = 28),
  ybar_h = c(50, 60), s2_h = c(400, 500)
)
cv_from_n("effort",
  n = n_days[["total"]],
  N_h = c(weekday = 65, weekend = 28),
  ybar_h = c(50, 60), s2_h = c(400, 500)
)
#> [1] 0.02028398

# CPUE round-trip
n_int <- creel_n_cpue(cv_catch = 0.8, cv_effort = 0.5, rho = 0, cv_target = 0.20)
cv_from_n("cpue", n = n_int, cv_catch = 0.8, cv_effort = 0.5, rho = 0)
#> [1] 0.1967121
```
