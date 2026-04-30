# Interviews to Catch: Statistical Pipeline

## Introduction

This vignette explains how creel interview data becomes a catch rate
estimate, and how that catch rate is combined with an effort estimate to
produce a total catch estimate with a meaningful measure of uncertainty.

The audience is a creel biologist who knows what catch rate and total
catch mean in practice, but may not be familiar with ratio estimators or
the delta method. Both topics are developed from first principles with
plain-language explanations alongside the formulas.

The pipeline has three stages:

1.  Interview data is collected: for each intercepted angler you record
    trip duration (hours fished) and catch.
2.  A catch rate (CPUE, catch per angler-hour) is estimated from the
    sample of interviews using a ratio estimator.
3.  Total catch is estimated as the product of estimated effort and
    estimated CPUE, with uncertainty propagated through the delta
    method.

## From Interviews to Catch Rate

Each creel interview captures two key numbers for a completed trip: the
angler’s total catch $`c_i`$ and the total time they spent fishing
$`h_i`$ (their trip duration in hours). Catch per unit effort (CPUE) is
catch per angler-hour.

The challenge is that we observe only a sample of anglers — those who
happened to be at count locations during sampling periods — not the full
population. We need to estimate the population-level CPUE from this
sample.

Two estimators are commonly used for this purpose.

### Ratio-of-Means (ROM)

The ratio-of-means estimator divides total sample catch by total sample
hours:

``` math
\hat{R}_{\text{ROM}} = \frac{\sum_{i=1}^{n} c_i}{\sum_{i=1}^{n} h_i}
```

where:

- $`c_i`$ is the catch of angler $`i`$
- $`h_i`$ is the trip duration (hours fished) of angler $`i`$
- $`n`$ is the number of interviews

Plain-language interpretation: **total catch in the sample divided by
total hours in the sample.**

ROM naturally down-weights anglers with very short trips. An angler who
fishes for 6 hours contributes six times as much to the denominator as
an angler who fishes for 1 hour, so longer-trip anglers appropriately
dominate the estimate when trip durations are variable.

### Mean-of-Ratios (MOR)

The mean-of-ratios estimator computes each angler’s individual catch
rate first, then averages across anglers:

``` math
\hat{R}_{\text{MOR}} = \frac{1}{n} \sum_{i=1}^{n} \frac{c_i}{h_i}
```

where:

- $`c_i / h_i`$ is the catch rate for angler $`i`$
- $`n`$ is the number of interviews

Plain-language interpretation: **the average of each angler’s individual
catch rate.**

MOR treats each angler as an equally weighted observation regardless of
how long they fished. Because each angler’s rate is computed before
averaging, MOR can also be applied to incomplete trips (anglers still on
the water at interview time), where you know catch so far and elapsed
time even though the trip has not finished.

### Side-by-Side Comparison

Consider ten anglers interviewed on a single survey day:

| Angler | Catch ($`c_i`$) | Hours ($`h_i`$) | Individual CPUE ($`c_i / h_i`$) |
|--------|-----------------|-----------------|---------------------------------|
| 1      | 2               | 4               | 0.50                            |
| 2      | 0               | 1               | 0.00                            |
| 3      | 6               | 3               | 2.00                            |
| 4      | 1               | 2               | 0.50                            |
| 5      | 3               | 2               | 1.50                            |
| 6      | 4               | 4               | 1.00                            |
| 7      | 0               | 2               | 0.00                            |
| 8      | 2               | 2               | 1.00                            |
| 9      | 1               | 1               | 1.00                            |
| 10     | 5               | 3               | 1.67                            |

**ROM by hand:**

``` math
\hat{R}_{\text{ROM}} = \frac{2+0+6+1+3+4+0+2+1+5}{4+1+3+2+2+4+2+2+1+3} = \frac{24}{24} = 1.00 \text{ fish/hr}
```

**MOR by hand:**

``` math
\hat{R}_{\text{MOR}} = \frac{0.50+0.00+2.00+0.50+1.50+1.00+0.00+1.00+1.00+1.67}{10} = \frac{9.17}{10} = 0.917 \text{ fish/hr}
```

The estimates differ because Anglers 2 and 7 each fished only 1–2 hours
with zero catch. Under ROM, their unproductive hours are diluted across
the 24 total hours in the sample (small influence). Under MOR, each
angler’s zero rate receives equal weight to every other angler (larger
influence on the average).

We can verify these arithmetic steps in R directly:

``` r

# Ten-angler example
catch <- c(2, 0, 6, 1, 3, 4, 0, 2, 1, 5)
hours <- c(4, 1, 3, 2, 2, 4, 2, 2, 1, 3)

rom <- sum(catch) / sum(hours)
mor <- mean(catch / hours)

cat("ROM:", round(rom, 3), "fish/hr\n")
#> ROM: 1 fish/hr
cat("MOR:", round(mor, 3), "fish/hr\n")
#> MOR: 0.917 fish/hr
```

These match the by-hand calculations above.

Now confirm the ROM result with
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
from tidycreel:

``` r

library(tidycreel)

mini_calendar <- data.frame(
  date       = as.Date("2024-06-01"),
  day_type   = "weekday",
  open_time  = 6,
  close_time = 20
)

mini_counts <- data.frame(
  date       = as.Date("2024-06-01"),
  day_type   = "weekday",
  count_time = as.POSIXct("2024-06-01 10:00", tz = "UTC"),
  n_anglers  = 10
)

mini_interviews <- data.frame(
  date          = as.Date("2024-06-01"),
  catch_total   = c(2, 0, 6, 1, 3, 4, 0, 2, 1, 5),
  hours_fished  = c(4, 1, 3, 2, 2, 4, 2, 2, 1, 3),
  trip_status   = "complete",
  trip_duration = c(4, 1, 3, 2, 2, 4, 2, 2, 1, 3)
)

mini_design <- creel_design(mini_calendar, date = date, strata = day_type) |>
  add_counts(mini_counts) |>
  add_interviews(mini_interviews,
    catch         = catch_total,
    effort        = hours_fished,
    trip_status   = trip_status,
    trip_duration = trip_duration
  )
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 2 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> ℹ Added 10 interviews: 10 complete (100%), 0 incomplete (0%)

# ROM estimate (default estimator for complete trips)
rom_est <- estimate_catch_rate(mini_design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=10, 100% of 10 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 10. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(rom_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1        1 0.215    0.578     1.42    10
```

The `estimate` value matches the by-hand ROM result of 1.00 fish/hr.

**When to use each estimator:**

- **ROM** (`estimator = "ratio-of-means"`, the default) is appropriate
  for access-point creel surveys using complete trip interviews. Longer
  trips contribute proportionally more to the denominator, which
  correctly reflects the actual fishing-time distribution in the
  population. ROM is the default in tidycreel for instantaneous-count
  surveys following Pollock et al. (1994).

- **MOR** (`estimator = "mor"`) is appropriate when working with
  incomplete trips — anglers still fishing who are interviewed before
  their trip ends. Each angler’s elapsed catch rate is an independent
  observation of unknown final duration, so equal weighting is more
  defensible. In tidycreel, `estimator = "mor"` requires `trip_status`
  to include incomplete trips and will not run on a complete-only
  dataset.

In practice, ROM and MOR agree when trip durations are homogeneous. They
diverge most when a few anglers have very short or very long trips.

## From Catch Rate to Total Catch

Total catch is the product of estimated effort and estimated catch rate:

``` math
\hat{TC} = \hat{E} \times \hat{R}
```

where $`\hat{E}`$ is the estimated total angler-hours for the survey
period and $`\hat{R}`$ is the estimated catch rate (fish per
angler-hour). Both quantities are estimated with uncertainty, so the
uncertainty in their product requires special treatment.

### Delta Method Variance

The delta method is a general technique for approximating the variance
of a function of random variables by linearizing the function around the
estimates. For a product of two estimated quantities, the idea is: treat
each factor as fixed and ask how much the product would change if that
factor varied by its standard error. The variances from each factor,
scaled by the other factor, add up to give the total variance.

For a product of two independent estimates, the delta method gives:

``` math
\text{Var}(\hat{TC}) \approx \hat{E}^2 \cdot \text{Var}(\hat{R}) + \hat{R}^2 \cdot \text{Var}(\hat{E}) + 2\hat{E}\hat{R} \cdot \text{Cov}(\hat{E}, \hat{R})
```

where:

- $`\hat{E}`$ is the estimated effort
- $`\hat{R}`$ is the estimated catch rate (CPUE)
- $`\text{Var}(\hat{R})`$ is the variance of the catch rate estimate
- $`\text{Var}(\hat{E})`$ is the variance of the effort estimate
- $`\text{Cov}(\hat{E}, \hat{R})`$ is the covariance between effort and
  catch rate

**Interpreting the three terms:**

1.  $`\hat{E}^2 \cdot \text{Var}(\hat{R})`$ — How much of the
    total-catch uncertainty comes from imprecise catch-rate estimation,
    treating effort as if it were known exactly.

2.  $`\hat{R}^2 \cdot \text{Var}(\hat{E})`$ — How much of the
    total-catch uncertainty comes from imprecise effort estimation,
    treating catch rate as if it were known exactly.

3.  $`2\hat{E}\hat{R} \cdot \text{Cov}(\hat{E}, \hat{R})`$ — A
    covariance adjustment. This term is usually small. tidycreel assumes
    zero covariance between the effort and catch-rate samples because
    counts and interviews are collected through independent sampling
    processes, so this term vanishes and the formula simplifies to the
    first two terms only.

### Worked Numeric Example

Suppose effort estimation on this survey day produced an estimate of
$`\hat{E} = 40`$ angler-hours with $`\text{SE}(\hat{E}) = 8`$ (so
$`\text{Var}(\hat{E}) = 64`$), and the ROM catch rate estimate from the
ten-angler sample is $`\hat{R} = 1.00`$ fish/hr with
$`\text{SE}(\hat{R}) = 0.30`$ (so $`\text{Var}(\hat{R}) = 0.09`$).

**Term 1** (catch-rate uncertainty):

``` math
\hat{E}^2 \cdot \text{Var}(\hat{R}) = 40^2 \times 0.09 = 1600 \times 0.09 = 144
```

**Term 2** (effort uncertainty):

``` math
\hat{R}^2 \cdot \text{Var}(\hat{E}) = 1.00^2 \times 64 = 1 \times 64 = 64
```

**Total variance** (covariance term is zero):

``` math
\text{Var}(\hat{TC}) \approx 144 + 64 = 208
```

``` math
\text{SE}(\hat{TC}) = \sqrt{208} \approx 14.4 \text{ fish}
```

**Total catch estimate:** $`\hat{TC} = 40 \times 1.00 = 40`$ fish, with
SE $`\approx`$ 14.4 fish (CV $`\approx`$ 36%).

In this example, Term 1 contributes 144 / 208 = 69% of the total
variance, so catch-rate imprecision (from the small interview sample of
ten anglers) is the dominant source of uncertainty. Collecting more
interviews would reduce the CV more than increasing count precision
would.

We can confirm this structure using the package’s example datasets,
which span a full survey season and provide enough sampling days for
variance estimation:

``` r

data(example_calendar)
data(example_counts)
data(example_interviews)

season_design <- creel_design(example_calendar, date = date, strata = day_type) |>
  add_counts(example_counts) |>
  add_interviews(example_interviews,
    catch         = catch_total,
    effort        = hours_fished,
    trip_status   = trip_status,
    trip_duration = trip_duration
  )
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

total <- estimate_total_catch(season_design)
print(total)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     858.  48.4     763.     953.    17
```

The `estimate` column is $`\hat{E} \times \hat{R}`$. The `se` column is
the delta method standard error combining uncertainty from both the
effort estimate (counts variance) and the catch rate estimate
(interviews variance). Dividing `se` by `estimate` gives the CV, which
you can compare to your target precision.

## Summary

Creel interview data flows through the following pipeline to produce a
total catch estimate with a quantified uncertainty:

1.  **Interviews to catch rate:** The ratio-of-means (ROM) estimator
    divides total sample catch by total sample hours. It is the default
    for instantaneous-count surveys because it correctly weights anglers
    by trip length. The mean-of-ratios (MOR) estimator treats each
    angler equally and is used in tidycreel when analyzing incomplete
    trips via `estimator = "mor"`.

2.  **Catch rate to total catch:** Total catch is effort multiplied by
    catch rate. The delta method propagates uncertainty from both the
    effort estimate and the catch-rate estimate into the total catch SE.
    Examining which term dominates tells you whether collecting more
    counts or more interviews would most efficiently reduce total catch
    uncertainty.

By default, tidycreel uses ROM following Pollock et al. (1994) for
instantaneous-count surveys with complete trip interviews.

## See Also

For the full API walkthrough using real survey data, see
[Interview-Based
Estimation](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.md).

## References

Pollock, K.H., Jones, C.M., and Brown, T.L. (1994). *Angler Survey
Methods and Their Applications in Fisheries Management*. American
Fisheries Society Special Publication 25. Bethesda, Maryland.

Bence, J.R., and Smith, K.D. (1999). An age-structured model with
density-dependent recruitment applied to the Lake Michigan alewife
stock. *Transactions of the American Fisheries Society*, 128(2),
265–284.
