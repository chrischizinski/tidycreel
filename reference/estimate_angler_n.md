# Estimate angler population size via closed-population mark-recapture

Computes a closed-population mark-recapture estimate of total angler
population size (N_hat) using one of three estimators:

- **Chapman** (default, `method = "chapman"`): A bias-corrected version
  of the Petersen estimator recommended when recaptures are small.
  \\\hat{N} = \frac{(M+1)(n+1)}{(m+1)} - 1\\

- **Petersen** (`method = "petersen"`): The unadjusted Lincoln-Petersen
  estimator. Requires at least 7 recaptures (\\m \geq 7\\) to avoid
  large positive bias; use Chapman for smaller recapture counts.
  \\\hat{N} = \frac{M \cdot n}{m}\\

- **Schnabel** (`method = "schnabel"`): A multi-occasion weighted
  estimator for \\K \geq 2\\ sampling occasions. \\\hat{N} = \frac{\sum
  M_k n_k}{\sum m_k}\\ CI uses the Poisson branch when \\\sum m_k \<
  50\\ and the normal approximation on \\1/\hat{N}\\ otherwise.

## Usage

``` r
estimate_angler_n(M, n, m, method = "chapman", conf_level = 0.95)
```

## Arguments

- M:

  integer or numeric. Number of marked animals released (first sample).
  For `method = "schnabel"`, a vector of cumulative marked-at-large
  counts before each sampling occasion (`M[1] = 0`).

- n:

  integer or numeric. Number captured in second sample. For Schnabel, a
  vector of per-occasion catch counts (same length as `M`).

- m:

  integer or numeric. Number of recaptures. Scalar for Chapman and
  Petersen; vector (same length as `M`) for Schnabel.

- method:

  character(1). One of `"chapman"` (default), `"petersen"`, or
  `"schnabel"`.

- conf_level:

  numeric. Confidence level for the CI. Default `0.95`.

## Value

A `creel_estimates` S3 object with `method = "mark-recapture-chapman"`
(or petersen/schnabel) and an `estimates` tibble with columns:
`parameter`, `estimate`, `se`, `ci_lower`, `ci_upper`, `n` (total
recaptures).

## References

Hansen, M. J., & Van Kirk, R. W. (2018). A mark-recapture-based approach
for estimating angler harvest. *North American Journal of Fisheries
Management*, 38(2), 400–410.
[doi:10.1002/nafm.10038](https://doi.org/10.1002/nafm.10038)

## See also

Other Estimation:
[`estimate_exploitation_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_exploitation_rate.md),
[`estimate_mr_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_mr_harvest.md)

## Examples

``` r
# Chapman (default) — bias-corrected Petersen
result <- estimate_angler_n(M = 200L, n = 50L, m = 10L)
print(result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-chapman
#> Variance: chapman
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         931.  232.     477.    1385.    10

# Petersen — requires m >= 7
result_p <- estimate_angler_n(M = 200L, n = 50L, m = 10L, method = "petersen")
print(result_p)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-petersen
#> Variance: petersen
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         1000  283.     446.    1554.    10

# Schnabel — multi-occasion with parallel vectors
result_s <- estimate_angler_n(
  M = c(0L, 47L, 91L, 131L),
  n = c(50L, 50L, 50L, 50L),
  m = c(0L,  4L,  6L,  8L),
  method = "schnabel"
)
print(result_s)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: mark-recapture-schnabel
#> Variance: delta
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 6
#>   parameter estimate    se ci_lower ci_upper     n
#>   <chr>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 N_hat         747.  176.     498.     1345    18
```
