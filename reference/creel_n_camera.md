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
camera-days required per stratum; element `"total"` gives Cochran's
overall sample size *before* proportional allocation, and `"allocated"`
the sum of the per-stratum values actually returned. Budget against
`"allocated"`; see
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
for why the two differ.

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

**Feltz-Middaugh (2025) empirical benchmark.** That study reports the
camera-day schedules at which a low-frequency time-lapse deployment
performed acceptably. Its two headline scenarios are, per **month**:

- *well-performing* (under 20 percent error in at least 80 percent of
  simulations): 12 weekdays and 7 weekend days, both at 1 count/day;

- *best-performing* (under 10 percent error in at least 80 percent of
  simulations): 18 weekdays at 2 counts/day and 8 weekend days at 4
  counts/day.

These are reported here as design context, not applied as a check. The
function cannot judge a computed `n_h` against them: `N_h` is the whole
survey period rather than a month, nothing here knows the counts per day
the schedule assumes, the error bands are fixed by the study rather than
taken from `cv_target`, and the simulations measured boat-trailer counts
on six Arkansas reservoirs, whereas `ybar_h` and `s2_h` are whatever the
caller piloted. Compare against them by hand, after converting to the
same units.

Earlier versions warned when `n_h` fell below 12 or 7, choosing which
benchmark to apply by matching the substring `"weekday"` or `"weekend"`
in the stratum name. That comparison was between a period-scale
allocation and a per-month recommendation, so it under-fired by roughly
the number of months in the survey (#234). No sample size ever changed:
the check only ever emitted a warning.

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

Feltz, C.J. and Middaugh, C.R. 2025. Improving efficiency of estimating
angler effort using low-frequency time-lapse camera data. North American
Journal of Fisheries Management 45:322-332.

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
[`optimal_n()`](https://chrischizinski.github.io/tidycreel/reference/optimal_n.md),
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
#>   weekday   weekend     total allocated 
#>        27        12        38        39 
```
