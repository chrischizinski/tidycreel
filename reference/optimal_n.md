# Calculate sampling days required under Neyman-optimal allocation

Determines how many sampling days are needed to achieve a target
coefficient of variation on the effort estimate, then allocates those
days across strata using Neyman (optimal) allocation. Unlike
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
which distributes days proportionally to stratum size, this function
concentrates days in strata with higher between-day variance, minimising
total days for a given precision.

## Usage

``` r
optimal_n(cv_target, N_h, ybar_h, s2_h, cost_ratio = 1)
```

## Arguments

- cv_target:

  Numeric scalar. Target coefficient of variation for the effort
  estimate (e.g., 0.20 for 20 percent). Must be in (0, 1\].

- N_h:

  Named numeric vector. Total available days per stratum (e.g.,
  `c(weekday = 65, weekend = 28)`). Values must be \>= 1.

- ybar_h:

  Numeric vector of same length as `N_h`. Pilot mean effort per day per
  stratum (e.g., angler-hours per day). Values must be \>= 0.

- s2_h:

  Numeric vector of same length as `N_h`. Pilot variance of effort per
  day per stratum. Values must be \>= 0.

- cost_ratio:

  Numeric scalar or named numeric vector of same length as `N_h`.
  Relative cost of sampling one day in each stratum. Default `1` (equal
  costs). When costs differ across strata, days are preferentially
  allocated to cheaper, high-variance strata. Values must be \> 0.

## Value

A named integer vector. Elements named after strata in `N_h` give the
optimal sampling days per stratum; element `"total"` gives the overall
sample size before allocation.

## Details

**Total sample size** uses the cost-generalised Cochran (1977) formula
(eq. 5.25 / 5.34 with finite-population correction):

\$\$n = \left\lceil \frac{A \cdot C}{V_0 + \sum_h N_h s_h^2}
\right\rceil\$\$

where \\A = \sum_h N_h s_h / \sqrt{c_h}\\, \\C = \sum_h N_h s_h
\sqrt{c_h}\\, \\V_0 = (CV\_{target} \cdot \hat{E})^2\\, \\\hat{E} =
\sum_h N_h \bar{y}\_h\\, and \\s_h = \sqrt{s_h^2}\\. When all \\c_h =
1\\ (equal costs) this reduces to \\(\sum_h N_h s_h)^2 / (V_0 + \sum_h
N_h s_h^2)\\, identical to
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md).

**Per-stratum allocation** uses the cost-adjusted Neyman formula
(Cochran 1977 eq. 5.30):

\$\$n_h = \left\lceil n \cdot \frac{N_h s_h / \sqrt{c_h}}{\sum_h N_h s_h
/ \sqrt{c_h}} \right\rceil\$\$

where \\c_h\\ is the relative sampling cost for stratum \\h\\. With
equal costs (`cost_ratio = 1`), this reduces to the standard Neyman
formula \\n_h \propto N_h s_h\\.

Because each stratum is ceiling-ed independently, `sum(n_h)` may
slightly exceed `n_total`.

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

McCormick, J.L. and Quist, M.C. 2017. Sample size estimation for on-site
creel surveys. North American Journal of Fisheries Management
37:970-983.
[doi:10.1080/02755947.2017.1342723](https://doi.org/10.1080/02755947.2017.1342723)

## See also

[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
for proportional allocation,
[`reallocate_strata()`](https://chrischizinski.github.io/tidycreel/reference/reallocate_strata.md)
to re-allocate a fixed day budget.

Other "Planning & Sample Size":
[`audit_strata()`](https://chrischizinski.github.io/tidycreel/reference/audit_strata.md),
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md),
[`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md),
[`reallocate_strata()`](https://chrischizinski.github.io/tidycreel/reference/reallocate_strata.md),
[`simulate_strata_collapse()`](https://chrischizinski.github.io/tidycreel/reference/simulate_strata_collapse.md)

## Examples

``` r
# Two-stratum weekday/weekend example
optimal_n(
  cv_target = 0.20,
  N_h   = c(weekday = 65, weekend = 28),
  ybar_h = c(50, 60),
  s2_h   = c(400, 500)
)
#> weekday weekend   total 
#>       3       2       4 

# Weekend sampling costs twice as much -- shift days toward weekdays
optimal_n(
  cv_target  = 0.20,
  N_h        = c(weekday = 65, weekend = 28),
  ybar_h     = c(50, 60),
  s2_h       = c(400, 500),
  cost_ratio = c(weekday = 1, weekend = 2)
)
#> weekday weekend   total 
#>       3       2       4 
```
