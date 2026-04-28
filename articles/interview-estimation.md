# Interview-Based Catch Estimation

## Introduction

This vignette extends the effort estimation workflow covered in “Getting
Started with tidycreel” to interview-based catch and harvest estimation.
The complete workflow involves five steps:

1.  **Design**: Define your survey calendar and stratification
2.  **Counts**: Attach instantaneous count observations
3.  **Interviews**: Attach complete trip interview data
4.  **CPUE**: Estimate catch per unit effort
5.  **Total Catch**: Combine effort and CPUE estimates

The package uses ratio-of-means estimation for catch per unit effort
(CPUE), which is appropriate for access point surveys with complete trip
interviews. This estimator accounts for the correlation between catch
and effort within each interview.

## Survey Design and Count Data

We start with the same design and count data workflow from the “Getting
Started” vignette:

``` r
library(tidycreel)

# Load example calendar and counts
data(example_calendar)
data(example_counts)

# Create design with counts
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

# Estimate total effort
effort_est <- estimate_effort(design)
print(effort_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     372.  13.2       13.2         0     344.     401.    14
```

The effort estimate provides the total angler-hours for the survey
period, which we’ll combine with CPUE to estimate total catch.

## Adding Interview Data

Next, we attach interview data containing catch and effort for complete
trips:

``` r
# Load example interview data
data(example_interviews)
head(example_interviews)
#>         date hours_fished catch_total catch_kept trip_status trip_duration
#> 1 2024-06-01          2.0           5          2    complete           2.0
#> 2 2024-06-01          3.5           8          5    complete           3.5
#> 3 2024-06-02          1.5           2          1    complete           1.5
#> 4 2024-06-02          2.0           3          2  incomplete           1.0
#> 5 2024-06-03          2.5           6          3    complete           2.5
#> 6 2024-06-03          4.0          12          8    complete           4.0
#>   interview_id angler_type angler_method species_sought n_anglers refused
#> 1            1        bank          bait        walleye         2   FALSE
#> 2            2        boat    artificial        walleye         1   FALSE
#> 3            3        bank          bait           bass         3   FALSE
#> 4            4        bank           fly        panfish         2   FALSE
#> 5            5        boat    artificial        walleye         1   FALSE
#> 6            6        boat          bait           bass         4   FALSE

# Attach interviews to the design
design <- add_interviews(design, example_interviews,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: 14 observations
#> PSU column: date
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: 22 observations
#> Type: "access"
#> Catch: catch_total
#> Effort: hours_fished
#> Harvest: catch_kept
#> Trip status: 17 complete, 5 incomplete
#> Survey: <survey.design2> (constructed)
#> Sections: "none"
```

The
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
function maps the interview data columns to the design structure. The
design now shows both count and interview data attached. Interview data
is treated as a parallel data stream to count data—the two datasets do
not need to align on specific dates.

## Estimating CPUE

With interview data attached, we can estimate catch per unit effort:

``` r
# Estimate CPUE
cpue_est <- estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(cpue_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     2.29 0.114     2.06     2.51    17
```

The CPUE estimate uses a ratio-of-means estimator: total catch divided
by total effort across all interviews. This estimator is appropriate for
access point surveys because it accounts for the correlation between
catch and effort within each trip. The variance is computed using the
delta method, accounting for the covariance between numerator and
denominator.

For details on the ratio-of-means formula and variance calculation, see
[`?estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md).

## Estimating Total Catch

We can combine the effort and CPUE estimates to compute total catch:

``` r
# Estimate total catch
total_catch_est <- estimate_total_catch(design)
print(total_catch_est)
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

The total catch estimate multiplies the effort and CPUE estimates. The
variance is computed using the delta method with the formula:

Var(E × C) = E² Var(C) + C² Var(E)

This formula assumes independence between the count and interview data
streams, which is appropriate since they are collected through separate
sampling processes. See
[`?estimate_total_catch`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
for more details on the variance propagation.

## Estimating Harvest

The package distinguishes between total catch (all fish caught) and
harvest (fish kept). We can estimate harvest per unit effort (HPUE) and
total harvest:

``` r
# Estimate HPUE
hpue_est <- estimate_harvest_rate(design)
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(hpue_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means HPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     1.36 0.101     1.16     1.56    22

# Estimate total harvest
total_harvest_est <- estimate_total_harvest(design)
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(total_harvest_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Harvest (Effort × HPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     508.  41.8     426.     590.    22
```

Harvest estimation uses the same ratio-of-means approach as CPUE, but
with the harvest column (`catch_kept`) as the numerator. As expected,
total harvest is lower than total catch since not all caught fish are
kept.

## Grouped Estimation

Like effort estimation, CPUE and total catch functions support grouped
estimation using the `by` parameter:

``` r
# Estimate CPUE by day_type (not evaluated - example data too small)
cpue_by_day <- estimate_catch_rate(design, by = day_type)

# Estimate total catch by day_type
total_catch_by_day <- estimate_total_catch(design, by = day_type)
```

Note: The example data has insufficient interview sample sizes for
grouped estimation (weekend n=9, weekday n=13). Ratio estimation
requires at least 10 observations per group for stability. In real
surveys, aim for at least 30 interviews per stratum for reliable grouped
estimates.

## Variance Methods

Like effort estimation, CPUE estimation supports multiple variance
methods. The default is Taylor linearization, but bootstrap and
jackknife are also available:

``` r
# Bootstrap variance estimation
set.seed(42) # For reproducibility
cpue_boot <- estimate_catch_rate(design, variance = "bootstrap")
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Jackknife variance estimation
cpue_jk <- estimate_catch_rate(design, variance = "jackknife")
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
```

All three methods produce similar results for these data. Use bootstrap
or jackknife when you want to verify Taylor linearization assumptions or
when working with complex grouped estimates.

**When to use each method:**

- **Taylor linearization** (default): Computationally efficient and
  appropriate for most smooth statistics. This is the recommended
  default.
- **Bootstrap**: Use when working with non-smooth statistics or when you
  want to verify Taylor linearization assumptions. More computationally
  intensive.
- **Jackknife**: Alternative resampling method that is deterministic
  (unlike bootstrap). Useful for verification or when bootstrap is too
  slow.

## Complete Workflow Example

Here’s the full pipeline in a single workflow:

``` r
# Load data
data(example_calendar)
data(example_counts)
data(example_interviews)

# Build design and attach data
complete_design <- creel_design(example_calendar, date = date, strata = day_type) |>
  add_counts(example_counts) |>
  add_interviews(example_interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = trip_duration
  )
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

# Compute all estimates
effort <- estimate_effort(complete_design)
cpue <- estimate_catch_rate(complete_design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
hpue <- estimate_harvest_rate(complete_design)
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
total_catch <- estimate_total_catch(complete_design)
total_harvest <- estimate_total_harvest(complete_design)
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Print key results
print(effort)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     372.  13.2       13.2         0     344.     401.    14
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
#> 1     858.  48.4     763.     953.    17
print(total_harvest)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Harvest (Effort × HPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     508.  41.8     426.     590.    22
```

This demonstrates the complete v0.2.0 workflow from survey design
through total catch and harvest estimation.

## Working with Incomplete Trips

This vignette demonstrates the default workflow using complete trips,
which is the recommended approach following Pollock et al. (1994)
roving-access design principles.

For situations where you have incomplete trip interviews and want to
explore using them for estimation, see the **Incomplete Trip
Estimation** vignette
([`vignette("incomplete-trips", package = "tidycreel")`](https://chrischizinski.github.io/tidycreel/articles/incomplete-trips.md)).
That vignette covers:

- When incomplete trip estimation is scientifically valid
- How to validate incomplete trip estimates using TOST equivalence
  testing
- Step-by-step workflow with
  [`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md)
- Examples of passing and failing validation scenarios
- Why you should NEVER pool complete and incomplete trips

**Important:** The package defaults to complete trips only. Incomplete
trip estimation requires explicit opt-in via the `use_trips` parameter
in
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
and should only be used after validation with
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md).

## Next Steps

For more details on interview-based estimation functions, see:

- [`?add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md) -
  Attach interview data to a design
- [`?estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md) -
  Estimate catch per unit effort
- [`?estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md) -
  Estimate harvest per unit effort
- [`?estimate_total_catch`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md) -
  Estimate total catch
- [`?estimate_total_harvest`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md) -
  Estimate total harvest
- [`?example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md) -
  Example interview dataset

For the effort estimation workflow, see the “Getting Started with
tidycreel” vignette.
