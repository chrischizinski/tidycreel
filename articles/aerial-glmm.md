# GLMM Aerial Effort Estimation

## When to Use the GLMM Estimator

If your pilot always flies at the same time of day — say, 10 AM — your
instantaneous count systematically over- or under-represents total daily
effort. Early-morning flights catch fewer anglers than are present at
peak hours; late-afternoon flights may miss early starters entirely.
When flight timing is non-random, the simple expansion (count × h_open /
v) inherits this temporal bias.

The GLMM approach (Askey et al. 2018) models how angler counts change
through the day using a quadratic hour effect and a day-level random
intercept: `count ~ poly(hour, 2) + (1 | date)`. Once the diurnal curve
is estimated, the model integrates predicted counts across the full
open-water window — correcting for wherever in the curve the actual
flight fell.

**When to use the GLMM estimator:**

1.  Flights always occur in the same part of the day (fixed morning or
    afternoon schedule).
2.  You have multiple overflights per day across several days (minimum
    8–10 survey days recommended for stable random-effect estimation).

**When to use the simple estimator:**

1.  Flight timing is randomly assigned across the open-water window.
2.  You have only one count per day.

For the basic aerial workflow without GLMM correction, see the [aerial
surveys
vignette](https://chrischizinski.github.io/tidycreel/articles/aerial-surveys.md).

## Example Data

The `example_aerial_glmm_counts` dataset contains 12 survey days with 4
overflights per day at fixed hours (7, 10, 13, and 16 hours), producing
48 observations. Angler counts follow a diurnal curve with day-level
Poisson variability — representative of a scenario where a fixed
morning-to-afternoon flight schedule is used throughout the season.

``` r
library(tidycreel)
data(example_aerial_glmm_counts)
head(example_aerial_glmm_counts)
#>         date day_type n_anglers time_of_flight
#> 1 2024-06-03  weekday         3              7
#> 2 2024-06-03  weekday        30             10
#> 3 2024-06-03  weekday        65             13
#> 4 2024-06-03  weekday        50             16
#> 5 2024-06-06  weekday         5              7
#> 6 2024-06-06  weekday        15             10
```

The four columns are `date`, `day_type`, `n_anglers` (instantaneous
count), and `time_of_flight` (decimal hour of each overflight).

## Building the Aerial Design

Build an aerial `creel_design` from the survey dates and attach the
count data. The `h_open = 14` argument specifies the number of hours the
fishery is open each day — this enters the final expansion after the
diurnal curve is integrated.

``` r
aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
aerial_cal <- aerial_cal[order(aerial_cal$date), ]

design <- creel_design(
  aerial_cal,
  date        = date,
  strata      = day_type,
  survey_type = "aerial",
  h_open      = 14
)

design <- add_counts(design, example_aerial_glmm_counts)
#> Warning in add_counts(design, example_aerial_glmm_counts): Duplicate PSU values detected in count data.
#> ℹ Found 36 duplicate value(s) in column date.
#> ℹ If multiple counts were taken per day, specify `count_time_col`.
#> ℹ Example: `add_counts(design, counts, count_time_col = count_time)`
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "aerial"
#> Date column: date
#> Strata: day_type
#> Calendar: 12 days (2024-06-03 to 2024-07-06)
#> day_type: 2 levels
#> Counts: 48 observations
#> PSU column: date
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Aerial Survey Design ──
#> 
#> Hours open (h_open): 14
```

## GLMM Effort Estimation

Call
[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md)
with `time_col = time_of_flight`. The default model fits a
negative-binomial GLMM with a quadratic temporal effect and a day-level
random intercept:

``` r
glmm_result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
#> Warning in theta.ml(Y, mu, weights = object@resp$weights, limit = limit, :
#> iteration limit reached
print(glmm_result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    4399.  381.       381.        NA    3653.    5146.    48
```

The model fits the diurnal count curve over all 48 observations, then
numerically integrates the predicted mean count across the full
open-water window (from 0.5 hours before the earliest flight to 0.5
hours after the latest). The integrated area is scaled by
`h_open / visibility_correction` to convert counts to angler-hours.

## Variance and Confidence Intervals

Two variance methods are available.

**Delta method (default):** Propagates the fixed-effect covariance
matrix from `lme4::vcov()` to the derived integral via a gradient
vector. This is fast and analytic, and is the default when
`boot = FALSE`.

**Parametric bootstrap:**
[`lme4::bootMer()`](https://rdrr.io/pkg/lme4/man/bootMer.html) re-fits
the model under parametric resampling `nsim` times and uses the SD of
the resulting totals as the SE. This method can give more accurate CIs
for skewed count distributions. Use it for final production analyses;
the delta method is appropriate for exploratory work.

``` r
# Bootstrap CIs — use nboot = 500 for production analyses
glmm_boot <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  boot = TRUE,
  nboot = 100L
)
print(glmm_boot)
```

## Downstream Estimation

GLMM effort feeds directly into the standard downstream estimators.
Attach interview data and call
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
and
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
on the same design object.

``` r
# Build a complementary design with matching interview dates
aerial_int_cal <- unique(example_aerial_counts[, c("date", "day_type")])
aerial_int_cal <- aerial_int_cal[order(aerial_int_cal$date), ]

design_int <- creel_design(
  aerial_int_cal,
  date        = date,
  strata      = day_type,
  survey_type = "aerial",
  h_open      = 14
)
design_int <- add_counts(design_int, example_aerial_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
design_int <- add_interviews(design_int, example_aerial_interviews,
  catch       = walleye_catch,
  effort      = hours_fished,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 15 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> ℹ Added 48 interviews: 48 complete (100%), 0 incomplete (0%)
catch_rate <- estimate_catch_rate(design_int)
#> ℹ Using complete trips for CPUE estimation
#>   (n=48, 100% of 48 interviews) [default]
print(catch_rate)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.413 0.0601    0.295    0.531    48

total_catch <- estimate_total_catch(design_int)
#> ℹ Using complete trips for CPUE estimation
#>   (n=48, 100% of 48 interviews) [default]
print(total_catch)
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
#> 1    3681.  601.    2504.    4859.    48
```

## Comparison: Simple vs. GLMM Estimator

Both estimators are applied to the same design. The simple estimator
treats each overflight count as a representative sample of the full
open-water window and expands by `h_open / v` directly. The GLMM
estimator corrects for the fixed-hour flight schedule by integrating the
fitted diurnal curve.

``` r
# Simple aerial estimator — no diurnal correction
simple_result <- estimate_effort(design)

# GLMM result from above
# glmm_result already computed

# Side-by-side comparison
comparison <- rbind(
  data.frame(
    method = "GLMM",
    estimate = glmm_result$estimates$estimate,
    se = glmm_result$estimates$se,
    ci_lower = glmm_result$estimates$ci_lower,
    ci_upper = glmm_result$estimates$ci_upper,
    stringsAsFactors = FALSE
  ),
  data.frame(
    method = "Simple",
    estimate = simple_result$estimates$estimate,
    se = simple_result$estimates$se,
    ci_lower = simple_result$estimates$ci_lower,
    ci_upper = simple_result$estimates$ci_upper,
    stringsAsFactors = FALSE
  )
)

print(comparison)
#>   method  estimate        se  ci_lower  ci_upper
#> 1   GLMM  4399.453  380.6978  3653.299  5145.607
#> 2 Simple 20370.000 1891.0861 16156.398 24583.602
```

The GLMM estimate corrects for the fact that all flights occurred at
fixed hours (7, 10, 13, 16). The simple estimator treats each count as
representative of the full open-water window, which inflates or deflates
the total depending on where the peak falls in the diurnal curve.

## Custom Formula

For surveys where a linear temporal term is sufficient — or where the
analyst prefers to control the model structure directly — pass a custom
`formula`. The formula must reference the actual count column
(`n_anglers`) and the time column by its exact name in the data.

``` r
glmm_linear <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  formula  = n_anglers ~ time_of_flight + (1 | date)
)
#> boundary (singular) fit: see help('isSingular')
print(glmm_linear)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    4282.  374.       374.        NA    3548.    5015.    48
```

A linear temporal term reduces flexibility but can improve stability
when only a few survey days are available. Use the default quadratic
formula when you have 8 or more survey days.

## References

- Askey, P. J., Parkinson, E. A., Rehill, P., & Post, J. R. (2018).
  Correcting for non-random flight timing in aerial creel surveys using
  a generalized linear mixed model. *North American Journal of Fisheries
  Management*, 38(5), 1204–1215. <https://doi.org/10.1002/nafm.10010>

- Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883–919. American Fisheries Society.
