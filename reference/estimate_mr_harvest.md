# Estimate total harvest from a mark-recapture population estimate

Computes a total harvest estimate and its uncertainty using the delta
method, given a closed-population angler population estimate from
[`estimate_angler_n`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
and a known harvest rate.

The point estimate is \\\hat{H} = \hat{N} \times r\\ where \\r\\ is the
harvest rate (proportion of anglers that harvested fish). The
delta-method standard error is \\SE(\hat{H}) = r \times SE(\hat{N})\\,
propagating only the uncertainty in \\\hat{N}\\ (harvest-rate
uncertainty is not propagated in this release).

## Usage

``` r
estimate_mr_harvest(
  angler_n,
  harvest_rate,
  conf_level = 0.95,
  ci_method = c("delta", "bootstrap")
)
```

## Arguments

- angler_n:

  A `creel_estimates` object returned by
  [`estimate_angler_n`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md).

- harvest_rate:

  numeric scalar. Proportion of anglers that harvested fish. Must be in
  \\(0, 1\]\\. Uncertainty in the harvest rate is not propagated (see
  Details).

- conf_level:

  numeric. Confidence level for the CI. Default `0.95`.

- ci_method:

  character(1). CI construction method: `"delta"` (default) uses the
  analytic delta-method formula; `"bootstrap"` propagates the bootstrap
  samples stored in `attr(angler_n, "boot_samples")` (produced by
  calling `estimate_angler_n(..., ci_method = "bootstrap")` first).

## Value

A `creel_estimates` S3 object with `method = "mark-recapture-harvest"`
and an `estimates` tibble with columns: `parameter`, `estimate`, `se`,
`ci_lower`, `ci_upper`.

## Details

The harvest rate is treated as a known constant in this implementation
(Hansen & Van Kirk 2018, D-04). Propagation of harvest-rate uncertainty
via a two-source delta method is a planned future extension.

## References

Hansen, M. J., & Van Kirk, R. W. (2018). A mark-recapture-based approach
for estimating angler harvest. *North American Journal of Fisheries
Management*, 38(2), 400–410.
[doi:10.1002/nafm.10038](https://doi.org/10.1002/nafm.10038)

## See also

Other Estimation:
[`estimate_angler_n()`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md),
[`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md)

## Examples

``` r
# Step 1: estimate angler population
result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)

# Step 2: compute total harvest
harvest <- estimate_mr_harvest(angler_n = result, harvest_rate = 0.35)
print(harvest)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-harvest
#> Variance: delta
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   parameter     estimate    se ci_lower ci_upper
#>   <chr>            <dbl> <dbl>    <dbl>    <dbl>
#> 1 total_harvest     326.  81.1     167.     485.
```
