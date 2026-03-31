# Calculate sampling days required to achieve a target CV on effort

Uses the stratified sample size formula from McCormick & Quist (2017) to
determine how many sampling days are needed to achieve a target
coefficient of variation on the effort estimate, given pilot variance
estimates per day-type stratum.

## Usage

``` r
creel_n_effort(cv_target, N_h, ybar_h, s2_h)
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

## Value

A named integer vector. Elements named after strata in `N_h` give the
sampling days required per stratum; element `"total"` gives the overall
sample size before proportional allocation.

## Details

Implements Cochran (1977) equation 5.25 under proportional allocation,
as applied to creel surveys by McCormick & Quist (2017). The
finite-population correction (FPC) factor is intentionally omitted
(standard practice for pre-season planning where the goal is to
determine how many days to sample, not to assess precision of a
completed survey).

The per-stratum sample sizes `n_h` are computed from the total `n_total`
under proportional allocation:
`n_h = ceiling(n_total * N_h / sum(N_h))`. Because each stratum is
ceiling-ed independently, `sum(n_h)` may exceed `n_total`.

## References

McCormick, J.L. and Quist, M.C. 2017. Sample size estimation for on-site
creel surveys. North American Journal of Fisheries Management
37:970-983.
[doi:10.1080/02755947.2017.1342723](https://doi.org/10.1080/02755947.2017.1342723)

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

## Examples

``` r
# Two-stratum weekday/weekend example
creel_n_effort(
  cv_target = 0.20,
  N_h = c(weekday = 65, weekend = 28),
  ybar_h = c(50, 60),
  s2_h = c(400, 500)
)
#> weekday weekend   total 
#>       3       2       4 
```
