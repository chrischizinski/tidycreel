# Audit per-stratum effort precision from a completed creel design or pilot statistics

`audit_strata()` is an S3 generic. Two methods are provided:

- `audit_strata.creel_design()` extracts stratum summaries from a
  completed design object and computes per-stratum RSE, DEFF, and
  meets-target flag.

- `audit_strata.default()` accepts pilot summary statistics (N_h, n_h,
  ybar_h, s2_h) directly.

## Usage

``` r
audit_strata(x, ...)

# S3 method for class 'creel_design'
audit_strata(x, rse_target = 0.2, ...)

# Default S3 method
audit_strata(x, n_h, ybar_h, s2_h, rse_target = 0.2, ...)
```

## Arguments

- x:

  A `creel_design` object (for the `creel_design` method) or a named
  numeric vector `N_h` of total available days per stratum (for the
  `default` method).

- ...:

  Additional arguments passed to methods.

- rse_target:

  Numeric scalar. Target relative standard error threshold. Default 0.20
  (20 percent). Must be in (0, 1\].

- n_h:

  Named numeric vector of the same length as `x`. Observed sample counts
  per stratum. Values must be \>= 1.

- ybar_h:

  Numeric vector of the same length as `x`. Observed mean effort per day
  per stratum. Values must be \>= 0.

- s2_h:

  Numeric vector of the same length as `x`. Observed variance of effort
  per day per stratum. Values must be \>= 0.

## Value

A `creel_strata_audit` S3 object. See `audit_strata.default()` for the
complete field description.

A `creel_strata_audit` S3 object — a named list with fields:

- `$strata`:

  Tibble with columns: `stratum`, `N_h`, `n_h`, `ybar_h`, `s2_h`, `RSE`,
  `DEFF`, `meets_target`.

- `$rse_target`:

  Scalar. The RSE threshold supplied by the caller.

- `$n_total`:

  Integer. Total sampled days across all strata.

- `$deff`:

  Scalar. Aggregate design effect (Var_strat / Var_SRS).

## Details

The per-stratum RSE (relative standard error, equivalent to CV) is
computed with the finite-population correction (FPC):

`RSE_h = sqrt((1 - n_h / N_h) * s2_h / n_h) / ybar_h`

When `n_h = 1` for any stratum,
[`var()`](https://rdrr.io/r/stats/cor.html) cannot be estimated; RSE,
DEFF, and `meets_target` are set to `NA` for those strata and a warning
is issued. The function continues processing valid strata.

The per-stratum design effect (DEFF_h) compares the actual stratum
variance to the pooled-SRS variance baseline:

`DEFF_h = ((1 - n_h/N_h) * s2_h / n_h) / ((1 - n/N) * s2_overall / n)`

where `n = sum(n_h)`, `N = sum(N_h)`, and
`s2_overall = sum(N_h * s2_h) / sum(N_h)` (N_h-weighted pooled
within-stratum variance). The aggregate DEFF stored in `$deff` is
`Var_strat / Var_SRS` (Cochran 1977).

## References

Cochran, W.G. 1977. Sampling Techniques, 3rd ed. Wiley, New York.

McCormick, J.L. and Quist, M.C. 2017. Sample size estimation for on-site
creel surveys. North American Journal of Fisheries Management
37:970-983.
[doi:10.1080/02755947.2017.1342723](https://doi.org/10.1080/02755947.2017.1342723)

## See also

Other "Planning & Sample Size":
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md),
[`optimal_n()`](https://chrischizinski.github.io/tidycreel/reference/optimal_n.md),
[`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md),
[`reallocate_strata()`](https://chrischizinski.github.io/tidycreel/reference/reallocate_strata.md),
[`simulate_strata_collapse()`](https://chrischizinski.github.io/tidycreel/reference/simulate_strata_collapse.md)

Other "Planning & Sample Size":
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md),
[`creel_n_camera()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_camera.md),
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
# Two-stratum weekday/weekend pilot example
audit <- audit_strata(
  c(weekday = 65, weekend = 28),
  n_h    = c(weekday = 22, weekend = 14),
  ybar_h = c(50, 60),
  s2_h   = c(400, 500),
  rse_target = 0.20
)
audit$strata
#> # A tibble: 2 × 8
#>   stratum   N_h   n_h ybar_h  s2_h    RSE  DEFF meets_target
#>   <chr>   <int> <int>  <dbl> <dbl>  <dbl> <dbl> <lgl>       
#> 1 weekday    65    22     50   400 0.0694  1.64 TRUE        
#> 2 weekend    28    14     60   500 0.0704  2.44 TRUE        
audit$deff
#> [1] 1.023445
```
