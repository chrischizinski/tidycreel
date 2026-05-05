# Calculate camera-days required to achieve a target CV

Uses the stratified sample size formula from Cochran (1977) to determine
how many camera-days are needed to achieve a target coefficient of
variation on the camera-effort estimate, given pilot mean and variance
estimates per day-type stratum.

## Usage

``` r
creel_n_camera(cv_target, N_h, ybar_h, s2_h)
```

## Arguments

- cv_target:

  Numeric scalar. Target coefficient of variation for the camera-effort
  estimate (e.g., 0.20 for 20 percent). Must be in (0, 1\].

- N_h:

  Named numeric vector. Total available days per stratum (e.g.,
  `c(weekday = 65, weekend = 28)`). Values must be \>= 1.

- ybar_h:

  Numeric vector of same length as `N_h`. Pilot mean camera count per
  day per stratum. Values must be \>= 0.

- s2_h:

  Numeric vector of same length as `N_h`. Pilot variance of camera
  counts per day per stratum. Values must be \>= 0.

## Value

A named integer vector. Elements named after strata in `N_h` give the
camera-days required per stratum; element `"total"` gives the overall
sample size before proportional allocation.

## Details

Implements Cochran (1977) equation 5.25 under proportional allocation.
The finite-population correction (FPC) factor is intentionally omitted
(standard practice for pre-season planning where the goal is to
determine how many days to deploy cameras, not to assess precision of a
completed survey).

The per-stratum sample sizes `n_h` are computed from the total `n_total`
under proportional allocation:
`n_h = ceiling(n_total * N_h / sum(N_h))`. Because each stratum is
ceiling-ed independently, `sum(n_h)` may exceed `n_total`.

**Minimum camera-day check:** After computing `n_h`, the function
applies empirical minimums from Feltz-Middaugh (2025). Stratum names are
matched case-insensitively and partially:

- Names containing `"weekday"` require a minimum of 12 camera-days.

- Names containing `"weekend"` require a minimum of 7 camera-days.

- Names matching neither pattern trigger a generic advisory (no numeric
  floor — consult Feltz-Middaugh 2025 for the appropriate minimum).

When any stratum is below threshold (or is unclassified), a single
combined `cli_warn()` is emitted listing all affected strata with their
computed `n` and minimum side-by-side. No warning fires if all
classified strata meet or exceed their minimums and there are no
unclassified strata.

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

Feltz, C.J. and Middaugh, C.R. 2025. Minimum camera-day requirements for
reliable creel-camera effort estimation. North American Journal of
Fisheries Management. (in press)

## See also

[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
for the equivalent function for angler-contact sampling days.

Other "Planning & Sample Size":
[`audit_strata()`](https://chrischizinski.github.io/tidycreel/reference/audit_strata.md),
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
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
creel_n_camera(
  cv_target = 0.20,
  N_h = c(weekday = 65, weekend = 28),
  ybar_h = c(15, 20),
  s2_h = c(625, 900)
)
#> weekday weekend   total 
#>      27      12      38 
```
