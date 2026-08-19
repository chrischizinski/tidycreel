# Estimate total harvest from a mark-recapture population estimate

Computes a total harvest estimate and its uncertainty using the delta
method, given a closed-population angler population estimate from
[`estimate_angler_n`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md)
and a known harvest rate.

The point estimate is \\\hat{H} = \hat{N} \times r\\ where \\r\\ is the
harvest rate in fish per angler. The delta-method standard error is
\\SE(\hat{H}) = r \times SE(\hat{N})\\, propagating only the uncertainty
in \\\hat{N}\\ (harvest-rate uncertainty is not propagated in this
release).

## Usage

``` r
estimate_mr_harvest(
  angler_n,
  harvest_rate,
  harvest_rate_se = NULL,
  conf_level = 0.95,
  ci_method = c("logit", "delta", "bootstrap")
)
```

## Arguments

- angler_n:

  A `creel_estimates` object returned by
  [`estimate_angler_n`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md).

- harvest_rate:

  numeric scalar. Harvest per angler, in fish per angler, over the same
  period `angler_n` counts anglers for. Must be \\\> 0\\. This is a
  rate, not a proportion, and is not bounded above: a fishery averaging
  1.4 fish per angler is a legal value. In the notation of Hansen & Van
  Kirk (2018) eq. (1), \\H = N \cdot D \cdot V\\, this argument is the
  product \\D \times V\\ — mean days fished per angler times mean daily
  harvest per angler — not \\V\\ alone. Supply `harvest_rate_se` to
  propagate its uncertainty.

- harvest_rate_se:

  numeric scalar or `NULL`. The standard error of `harvest_rate`, on the
  same fish-per-angler scale. When supplied, the total variance is
  Goodman's (1960) product form, \\\hat{N}^2 \sigma_r^2 + r^2
  \sigma\_{\hat{N}}^2 - \sigma\_{\hat{N}}^2 \sigma_r^2\\, via the same
  helper the three `estimate_total_*()` functions already use.

  When `NULL` (default), the reported SE reflects uncertainty in
  \\\hat{N}\\ alone and is a **lower bound**; the function says so at
  runtime. The component is absent rather than zero, because a zero
  would be indistinguishable from having propagated the rate's error and
  found none. Rasmussen et al. (1998) draw the distinction explicitly:
  the subtractive product formula is the one for terms "estimated from a
  sample", and differs from the population formula "used when the terms
  in the product are known, not estimated".

  Supplying it also changes the confidence interval. The default `logit`
  interval scales the endpoints of the \\\hat{N}\\ interval by
  `harvest_rate`, which is exact only while that rate is a known
  positive constant. Once the rate is estimated those endpoints are
  themselves random, so the function falls back to a symmetric interval
  built from the full product SE.

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

The harvest rate is treated as a known constant. This is a
simplification made by this implementation, not by the cited method:
Hansen & Van Kirk (2018) estimate both factors of the rate, give each a
log-normal sampling distribution, and resample them alongside
\\\hat{N}\\ in the bootstrap that produces their harvest CIs. Holding
the rate fixed therefore makes the reported `se` a lower bound on the
true uncertainty. Propagation of harvest-rate uncertainty via a
two-source delta method is a planned future extension.

The delta-method interval is also symmetric, which for a mark-recapture
estimate is optimistic at the lower end and can place `ci_lower` below
zero when recaptures are few; see the same note under
[`estimate_angler_n`](https://chrischizinski.github.io/tidycreel/reference/estimate_angler_n.md).

## References

Hansen, J. M., & Van Kirk, R. W. (2018). A mark-recapture-based approach
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
#> ℹ `harvest_rate_se` was not supplied, so the reported SE excludes harvest-rate
#>   uncertainty.
#>   It reflects uncertainty in the abundance estimate alone and is a lower bound.
#>   Supply `harvest_rate_se` to propagate the rate's own error (Goodman 1960).
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
#> 1 total_harvest     326.  81.1     212.     600.
```
