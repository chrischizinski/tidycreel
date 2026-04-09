# Compare Taylor linearization vs. replicate variance for creel estimates

Takes a `creel_estimates` object produced with `variance = "taylor"` and
re-estimates using replicate weights (bootstrap or jackknife) to produce
a side-by-side comparison of standard errors. A `cli_warn()` is issued
for any row where the two SEs diverge by more than
`divergence_threshold`.

## Usage

``` r
compare_variance(
  x,
  replicate_method = c("bootstrap", "jackknife"),
  conf_level = 0.95,
  divergence_threshold = 0.1,
  ...
)
```

## Arguments

- x:

  A `creel_estimates` object with `variance_method = "taylor"`. Must
  have been created with a `design` stored in `x$design`.

- replicate_method:

  Character. Replicate variance method to use for comparison. One of
  `"bootstrap"` (default) or `"jackknife"`.

- conf_level:

  Numeric confidence level (default: 0.95). Passed to the replicate
  estimation call.

- divergence_threshold:

  Numeric. Fraction by which replicate SE may differ from Taylor SE
  before a warning is issued (default: 0.10 = 10\\ A warning fires for
  any group where
  `|se_replicate / se_taylor - 1| > divergence_threshold`.

- ...:

  Additional arguments passed to the underlying estimator.

## Value

A `creel_variance_comparison` S3 object (a tibble subclass) with
columns:

- se_taylor:

  Taylor linearization SE from the original estimate.

- se_replicate:

  Replicate-weight SE from the re-estimation.

- divergence_ratio:

  Ratio `se_replicate / se_taylor`. `NA` when `se_taylor == 0`.

- diverges_flag:

  Logical. `TRUE` when `|divergence_ratio - 1| > divergence_threshold`.

Group columns (if any) are preserved. The full tibble is returned
invisibly via [`print()`](https://rdrr.io/r/base/print.html). Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) or
standard tibble methods for further processing.

## Method

The function extracts the Taylor SE from `x$estimates$se`, then calls
the same estimator that produced `x` (resolved via `x$method`) with
`variance = replicate_method`. The re-estimation uses `x$design` and the
grouping variables from `x$by_vars`.

Divergence is computed as: \$\$ratio = se\_{replicate} /
se\_{taylor}\$\$ \$\$diverges = \|ratio - 1\| \> threshold\$\$

A ratio substantially different from 1 indicates that the Taylor
approximation may be unreliable for this design (e.g., sparse strata,
non-linear estimator). Replication-based variance is generally more
robust but slower to compute.

## References

Wolter, K.M. 2007. Introduction to Variance Estimation, 2nd ed.
Springer.

Lumley, T. 2010. Complex Surveys: A Guide to Analysis Using R. Wiley.

## Examples

``` r
data("example_counts", package = "tidycreel")
data("example_interviews", package = "tidycreel")
cal <- unique(example_counts[, c("date", "day_type")])
design <- creel_design(cal, date = date, strata = day_type)
design <- suppressWarnings(add_counts(design, example_counts))
design <- suppressWarnings(add_interviews(
  design, example_interviews,
  catch = catch_total, effort = hours_fished,
  trip_status = trip_status, trip_duration = trip_duration
))
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
taylor_est <- suppressWarnings(estimate_catch_rate(design))
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
cmp <- suppressWarnings(compare_variance(taylor_est))
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 100% of 17 interviews) [default]
print(cmp)
#> 
#> ── Variance Comparison: Taylor vs. bootstrap ───────────────────────────────────
#> Divergence threshold: 10%
#> ✔ All rows within threshold.
#> 
#> # A tibble: 1 × 4
#>   se_taylor se_replicate divergence_ratio diverges_flag
#>       <dbl>        <dbl>            <dbl> <lgl>        
#> 1     0.114        0.115             1.01 FALSE        
```
