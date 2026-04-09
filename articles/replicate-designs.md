# Variance Methods: Taylor, Bootstrap, and Jackknife

tidycreel exposes three variance estimation methods through the
`variance` argument of
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
and related functions:

| `variance =`  | Description                           | Requires                         |
|---------------|---------------------------------------|----------------------------------|
| `"taylor"`    | Taylor linearization (default)        | ≥ 2 PSUs per stratum recommended |
| `"bootstrap"` | Bootstrap resampling (500 replicates) | ≥ 2 PSUs per stratum             |
| `"jackknife"` | Delete-one jackknife                  | ≥ 2 PSUs per stratum             |

``` r
library(tidycreel)
```

------------------------------------------------------------------------

## 1 Building a design for the examples

All three methods work on the same `creel_design` object. Here we use
the bundled `example_counts` and `example_interviews` datasets, which
have 10 sampled weekdays and 4 sampled weekends.

``` r
data("example_counts")
data("example_interviews")

cal <- unique(example_counts[, c("date", "day_type")])
design <- creel_design(cal, date = date, strata = day_type)
design <- add_counts(design, example_counts)
design <- add_interviews(
  design, example_interviews,
  catch = catch_total,
  effort = hours_fished,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
```

------------------------------------------------------------------------

## 2 Comparing the three variance methods

Pass `variance = "..."` to any estimator. The point estimate is
identical across methods; only the SE and CI change.

``` r
eff_taylor <- estimate_effort(design, variance = "taylor")
eff_bootstrap <- estimate_effort(design, variance = "bootstrap")
eff_jackknife <- estimate_effort(design, variance = "jackknife")

# Summarise all three for comparison
rbind(
  as.data.frame(summary(eff_taylor)),
  as.data.frame(summary(eff_bootstrap)),
  as.data.frame(summary(eff_jackknife))
)
#>   Estimate    SE CI Lower CI Upper  N
#> 1    372.5 13.18    343.8    401.2 14
#> 2    372.5 13.20    343.7    401.3 14
#> 3    372.5 13.18    343.8    401.2 14
```

With 10–14 PSUs per stratum the three methods produce very similar
standard errors. This convergence is expected: bootstrap and jackknife
are asymptotically equivalent to Taylor linearization for simple
probability samples.

------------------------------------------------------------------------

## 3 When to use each method

### Taylor linearization (`"taylor"`, default)

- **Use when**: stratum-level variance is dominated by between-day
  variability and the sampling design is a straightforward stratified
  random sample of days.
- **Advantage**: fastest; closed-form analytic variance formula; no
  randomness.
- **Limitation**: relies on large-sample approximations; can be less
  reliable for highly skewed count distributions or very small strata.

### Bootstrap (`"bootstrap"`)

- **Use when**: count distributions are highly skewed, the design is
  complex, or you want variance that is robust to distributional
  assumptions.
- **Advantage**: makes no distributional assumption; captures nonlinear
  variance propagation.
- **Limitation**: stochastic (set a seed in your script for
  reproducibility); slower (500 replicates by default); requires ≥ 2
  PSUs per stratum.

### Jackknife (`"jackknife"`)

- **Use when**: you prefer a deterministic, delete-one variance estimate
  that is slightly more conservative than Taylor for small samples.
- **Advantage**: deterministic; often more stable than bootstrap with
  small PSU counts.
- **Limitation**: also requires ≥ 2 PSUs per stratum; not appropriate
  for designs with unequal inclusion probabilities unless the correct
  jackknife weights are applied.

------------------------------------------------------------------------

## 4 Grouped estimates

All three methods work with the `by` argument.

``` r
eff_grp_taylor <- estimate_effort(design, by = day_type, variance = "taylor")
eff_grp_bootstrap <- estimate_effort(design, by = day_type, variance = "bootstrap")

rbind(
  cbind(method = "taylor", as.data.frame(summary(eff_grp_taylor))),
  cbind(method = "bootstrap", as.data.frame(summary(eff_grp_bootstrap)))
)
#>      method day_type Estimate     SE CI Lower CI Upper  N
#> 1    taylor  weekday    170.6  9.674    149.5    191.7 10
#> 2    taylor  weekend    201.9  8.946    182.4    221.4  4
#> 3 bootstrap  weekday    170.6 10.230    148.3    192.9 10
#> 4 bootstrap  weekend    201.9  8.604    183.2    220.6  4
```

------------------------------------------------------------------------

## 5 Single-PSU diagnostic

All three variance methods require at least **2 PSUs (sampled days) per
stratum**. When a stratum has only 1 sampled day, tidycreel raises a
structured error naming the stratum:

``` r
# Build a minimal design with 1 sampled day per stratum
dates_1psu <- c(as.Date("2024-06-03"), as.Date("2024-06-08"))
cal_1psu <- data.frame(date = dates_1psu, day_type = c("weekday", "weekend"))
d_1psu <- creel_design(cal_1psu, date = date, strata = day_type)
counts_1psu <- data.frame(
  date     = dates_1psu,
  day_type = c("weekday", "weekend"),
  count    = c(10L, 15L)
)
d_1psu <- add_counts(d_1psu, counts_1psu)

# Taylor linearization raises an error when variance cannot be estimated
estimate_effort(d_1psu, variance = "jackknife")
#> Error in `value[[3L]]()`:
#> ! Stratum "weekday" has only 1 PSU — jackknife variance cannot be
#>   estimated.
#> ✖ A stratum must have at least 2 PSUs for jackknife resampling.
#> ℹ Increase the sampling rate for stratum "weekday", or use `variance =
#>   'taylor'`.
```

The error message names the problematic stratum (`"weekday"`) and
suggests either increasing the sampling rate or switching to
`variance = "taylor"` which can still produce a point estimate via the
lonely-PSU adjustment.

------------------------------------------------------------------------

## 6 Summary

| Method    | Deterministic   | Min PSUs                   | Speed                 | When to prefer                                        |
|:----------|:----------------|:---------------------------|:----------------------|:------------------------------------------------------|
| taylor    | Yes             | 1 (with lonely-PSU adjust) | Fast                  | Default; simple designs                               |
| bootstrap | No (stochastic) | 2                          | Slow (500 replicates) | Skewed counts; complex designs                        |
| jackknife | Yes             | 2                          | Moderate              | Small samples; deterministic alternative to bootstrap |

Variance method comparison
