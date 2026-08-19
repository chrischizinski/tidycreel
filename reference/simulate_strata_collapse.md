# Simulate the effect of collapsing strata on precision

Compares per-stratum RSE and DEFF before and after merging a set of
strata into a single combined stratum.

## Usage

``` r
simulate_strata_collapse(audit, merge_strata)
```

## Arguments

- audit:

  A `creel_strata_audit` object returned by
  [`audit_strata()`](https://chrischizinski.github.io/tidycreel/reference/audit_strata.md).

- merge_strata:

  Character vector. Names of strata to merge (must all appear in
  `audit$strata$stratum`).

## Value

A plain tibble (no S3 class) with columns: `state` (`"before"` or
`"after"`), `stratum`, `N_h`, `n_h`, `RSE`, `DEFF`, `meets_target`.

## Details

Merged strata are pooled using population-weighted means:

- `N_merged = sum(N_h[merge_strata])`

- `n_merged = sum(n_h[merge_strata])`

- `ybar_merged = sum(N_h * ybar_h) / N_merged` (population-weighted)

- `s2_merged = sum(n_h * s2_h) / n_merged` (sample-size-weighted pooled
  within-stratum variance)

RSE and DEFF for the merged stratum are computed using the same
FPC-corrected formulas as
[`audit_strata()`](https://chrischizinski.github.io/tidycreel/reference/audit_strata.md).
Unmerged strata appear identically in both `"before"` and `"after"`
rows.

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
[`reallocate_strata()`](https://chrischizinski.github.io/tidycreel/reference/reallocate_strata.md)

## Examples

``` r
audit <- audit_strata(
  c(early_season = 30, mid_season = 30, late_season = 20),
  n_h    = c(early_season = 10, mid_season = 12, late_season = 8),
  ybar_h = c(40, 45, 38),
  s2_h   = c(300, 320, 280)
)
simulate_strata_collapse(audit, merge_strata = c("early_season", "mid_season"))
#> # A tibble: 5 × 7
#>   state  stratum                   N_h   n_h    RSE  DEFF meets_target
#>   <chr>  <chr>                   <int> <int>  <dbl> <dbl> <lgl>       
#> 1 before early_season               30    10 0.112   3.17 TRUE        
#> 2 before mid_season                 30    12 0.0889  2.54 TRUE        
#> 3 before late_season                20     8 0.121   3.33 TRUE        
#> 4 after  early_season+mid_season    60    22 0.0704  1.42 TRUE        
#> 5 after  late_season                20     8 0.121   3.33 TRUE        
```
