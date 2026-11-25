# Combine estimates from independent surveys

Sums two or more totals estimated from separate, independently sampled
surveys (two lakes, two seasons, day and night shifts drawn as separate
designs) into one total. The estimate is the sum of the parts, its
variance the sum of their variances, and its confidence interval uses
the Satterthwaite degrees of freedom (Satterthwaite 1946): \$\$\nu =
(\sum_i v_i)^2 / \sum_i (v_i^2 / \nu_i),\$\$ where \\v_i\\ is a part's
squared standard error and \\\nu_i\\ the degrees of freedom its own
interval used (`Inf` for a normal interval). Independent stratum totals
add, and so do their variances (Cochran 1977, ch. 5).

## Usage

``` r
combine_estimates(...)
```

## Arguments

- ...:

  Two or more `creel_estimates` objects, the parts.

## Value

A `creel_estimates` object with method `"combined-<quantity>"`, variance
method `"sum-of-independent"`, and the union of the parts' `provenance`,
so a combined estimate can itself be combined or compared and still be
checked.

## Details

Adding variances is right only when the parts share nothing estimated,
and a hand-made sum gives a plausible, too-small standard error whenever
they do. `combine_estimates()` therefore refuses, with a classed error,
when:

- the parts are not the same quantity: different estimate type, effort
  target, unit, grouping or confidence level, or an unknown (`NA`) unit;

- a part is a rate or a mean. A combined rate is combined catch divided
  by combined effort, a ratio, not a sum. Use
  [`compare_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/compare_estimates.md)
  to compare two rates;

- the parts share one party-size estimate or one aerial calibration
  component, read from `x$provenance`, or a part's provenance is
  unknown;

- one part's interviews (for rates and totals) or counts (for effort and
  totals) are all contained in another's – the same data behind both
  parts. A partial overlap raises the warning
  `creel_warning_combine_partial_overlap` with the number of shared
  rows;

- with `by`, a group is present in one part and absent from another. An
  absent group is unknown, not zero: supply a zero row if it is a real
  zero.

Overlapping coverage that the data cannot show – day and night windows
that overlap, two lakes sharing a section – is the user's
responsibility.

Supported quantities: effort and total catch, harvest and release,
including per-species tables. Refused, because the estimate does not
keep the data its independence would be checked against: sectioned
estimates, camera effort (its calibration interviews are an argument,
not part of the design), angler trips and mark-recapture harvest.

Rows are compared by what they record – date, count, effort, catch,
harvest, time, trip status, as the design maps them – not by column
name. A rate is also checked against its design's counts and their
party-size and calibration stamps: a rate pooled across strata is
weighted by count-based effort.

Rows whose estimate or standard error is unknown (`NA`) in any part are
unknown in the result. Named standard-error components are summed as
variances: absent where every part lacks them, `NA` where any part's is
unknown.

## References

Cochran, W. G. (1977). *Sampling Techniques*, 3rd ed. Wiley.

Satterthwaite, F. E. (1946). An approximate distribution of estimates of
variance components. *Biometrics Bulletin* 2(6): 110–114.

## See also

[`compare_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/compare_estimates.md)
for the difference of two estimates.

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.com/tidycreel/dev/reference/compare_cpue_estimators.md),
[`compare_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/compare_estimates.md),
[`est_age_distribution()`](https://chrischizinski.com/tidycreel/dev/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.com/tidycreel/dev/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.com/tidycreel/dev/reference/est_compliance.md),
[`est_effort_camera_mi()`](https://chrischizinski.com/tidycreel/dev/reference/est_effort_camera_mi.md),
[`est_length_distribution()`](https://chrischizinski.com/tidycreel/dev/reference/est_length_distribution.md),
[`est_mean_age()`](https://chrischizinski.com/tidycreel/dev/reference/est_mean_age.md),
[`est_mean_length()`](https://chrischizinski.com/tidycreel/dev/reference/est_mean_length.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
[`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md),
[`estimate_harvest_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_release.md)

## Examples

``` r
cal <- data.frame(
  date = as.Date("2024-06-01") + 0:9,
  day_type = rep(c("weekday", "weekday", "weekend", "weekend", "weekday"), 2)
)
sampled <- cal[c(1, 2, 3, 4, 6, 8), ]
# Angler counts on the sampled days of one lake, 8-hour fishing day
lake <- function(anglers) {
  d <- creel_design(cal, date = date, strata = day_type)
  d <- add_counts(
    d, data.frame(sampled, anglers = anglers, shift_hours = 8),
    period_length_col = shift_hours
  )
  estimate_effort(d)
}
north <- lake(c(12, 30, 9, 25, 14, 33))
south <- lake(c(4, 11, 6, 15, 5, 12))
both <- combine_estimates(north, south)
both$estimates
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    2283.  379.    1315.    3250.    12
```
