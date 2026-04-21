# Ice Fishing Survey Analysis

## Overview

Ice fishing creel surveys share the same structure as bus-route surveys,
but with one important simplification: all access points are sampled
with certainty. Every angler leaving the lake must pass through the
single ice access point (the boat ramp area or designated ice-access
site), so there is no site-level subsampling. This means the site
inclusion probability is always `p_site = 1.0`, and the overall
inclusion probability reduces to just the period sampling probability:

$$\pi_{i} = p\_ site \times p\_ period = 1.0 \times p\_ period = p\_ period$$

Because of this, ice fishing surveys are implemented as a *degenerate*
bus-route design. All the bus-route Horvitz-Thompson estimators apply
unchanged — only the probability structure is simplified.

### Effort type distinction

Ice fishing surveys collect two distinct effort measures:

- **time_on_ice** — total hours the angler party was physically on the
  ice, including travel to the fishing hole, breaks, and social time.
  This is the easiest to record and most commonly used.
- **active_fishing_time** — hours spent with lines in the water,
  excluding travel, setup, and breaks. This captures actual fishing
  pressure more precisely but requires more careful interviewing.

The `effort_type` argument to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
controls which measure the design tracks and how the output column is
labeled in
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md):
`total_effort_hr_on_ice` for `"time_on_ice"` and
`total_effort_hr_active` for `"active_fishing_time"`.

### Shelter mode stratification

Ice anglers fish from open-air setups or enclosed dark-house shelters.
Catch rates and effort patterns differ between these groups — dark-house
anglers often target specific species and fish longer hours. The
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
function accepts a `by` argument to produce separate estimates for each
shelter type.

## Example Data

This vignette uses two built-in datasets representing a hypothetical
Nebraska ice fishing creel survey at Lake McConaughy in January-February
2024. All 12 sampling days are weekends — a common design choice since
ice fishing pressure is concentrated on Saturday and Sunday.

``` r
library(tidycreel)

data(example_ice_sampling_frame)
data(example_ice_interviews)

head(example_ice_sampling_frame)
#>         date day_type p_period
#> 1 2024-01-06  weekend     0.50
#> 2 2024-01-07  weekend     0.50
#> 3 2024-01-13  weekend     0.50
#> 4 2024-01-14  weekend     0.50
#> 5 2024-01-20  weekend     0.55
#> 6 2024-01-21  weekend     0.55
head(example_ice_interviews)
#>         date n_counted n_interviewed hours_on_ice active_fishing_hours
#> 1 2024-01-06        12             5          5.0                  4.0
#> 2 2024-01-06        12             4          6.5                  5.5
#> 3 2024-01-06        12             3          4.0                  3.5
#> 4 2024-01-06         8             3          3.5                  3.0
#> 5 2024-01-06         8             3          5.0                  4.0
#> 6 2024-01-06         8             2          7.0                  6.0
#>   walleye_catch perch_catch walleye_kept perch_kept trip_status shelter_mode
#> 1             2           5            1          3    complete         open
#> 2             0           8            0          5    complete         open
#> 3             1           3            1          2    complete         open
#> 4             3           0            2          0    complete   dark_house
#> 5             1           4            1          3  incomplete   dark_house
#> 6             0           6            0          4    complete   dark_house
```

The sampling frame records the survey calendar and the period sampling
probability (`p_period = 0.5` means each day had a 50% chance of being
sampled). The interview data contains 72 interviews with walleye and
perch catch, both effort measures, and the shelter type (`shelter_mode`)
for each angler party.

## Design Construction

Build an ice fishing design using
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
with `survey_type = "ice"`. The `effort_type` argument is required and
determines the column label in downstream output. We use
`p_period = 0.5` as a scalar (uniform period sampling probability across
all days).

``` r
design <- creel_design(
  example_ice_sampling_frame,
  date = date,
  strata = day_type,
  survey_type = "ice",
  effort_type = "time_on_ice",
  p_period = 0.5
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "ice"
#> Date column: date
#> Strata: day_type
#> Calendar: 12 days (2024-01-06 to 2024-02-11)
#> day_type: 1 level
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Ice Fishing Design ──
#> 
#> Effort type: time_on_ice
#> p_period (global): 0.5
```

Omitting `effort_type` or supplying an unrecognized value produces an
informative error:

``` r
creel_design(
  example_ice_sampling_frame,
  date = date,
  strata = day_type,
  survey_type = "ice"
)
#> Error in `creel_design()`:
#> ! `effort_type` is required for "ice" survey designs.
#> ✖ No `effort_type` supplied.
#> ℹ Valid values: "time_on_ice" and "active_fishing_time".
```

## Attaching Interview Data

Use
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
to attach the survey data to the design. For ice surveys, `n_counted`
and `n_interviewed` are required — they record how many parties were
counted at the access point versus how many were actually interviewed
during each visit, providing the enumeration expansion factor.

``` r
design <- add_interviews(
  design,
  example_ice_interviews,
  catch         = walleye_catch,
  effort        = hours_on_ice,
  harvest       = walleye_kept,
  trip_status   = trip_status,
  n_counted     = n_counted,
  n_interviewed = n_interviewed
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 23 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> ℹ Added 72 interviews: 60 complete (83%), 12 incomplete (17%)
```

## Effort Estimation

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
dispatches through the bus-route Horvitz-Thompson estimator and returns
the total angler-hours with a standard error and confidence interval.
The output column is labeled `total_effort_hr_on_ice` because the design
was built with `effort_type = "time_on_ice"`.

``` r
effort_est <- estimate_effort(design)
print(effort_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   total_effort_hr_on_ice    se ci_lower ci_upper     n
#>                    <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1                  2406.  107.    2196.    2615.    72
```

To demonstrate the column-naming distinction, rebuild the design using
`effort_type = "active_fishing_time"` and the `active_fishing_hours`
column from the interview data. The output column is then labeled
`total_effort_hr_active`.

``` r
design_aft <- creel_design(
  example_ice_sampling_frame,
  date        = date,
  strata      = day_type,
  survey_type = "ice",
  effort_type = "active_fishing_time",
  p_period    = 0.5
)

design_aft <- suppressMessages(add_interviews(
  design_aft,
  example_ice_interviews,
  catch         = walleye_catch,
  effort        = active_fishing_hours,
  harvest       = walleye_kept,
  trip_status   = trip_status,
  n_counted     = n_counted,
  n_interviewed = n_interviewed
))
#> Warning: 23 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.

effort_aft <- estimate_effort(design_aft)
print(effort_aft)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   total_effort_hr_active    se ci_lower ci_upper     n
#>                    <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1                  1990.  93.1    1808.    2173.    72
```

Active fishing hours are shorter than time-on-ice because they exclude
travel, setup, and breaks. The difference between the two estimates
reflects the non-fishing portion of each trip.

## Shelter Mode Stratification

Pass `by = shelter_mode` to
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
to produce separate effort estimates for open-air anglers and dark-house
anglers. This uses the same Horvitz-Thompson framework with the
interview data split by the grouping variable.

``` r
effort_by_shelter <- estimate_effort(design, by = shelter_mode)
print(effort_by_shelter)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: shelter_mode
#> Effort target: sampled_days
#> 
#> # A tibble: 2 × 7
#>   shelter_mode total_effort_hr_on_ice    se ci_lower ci_upper proportion     n
#>   <chr>                         <dbl> <dbl>    <dbl>    <dbl>      <dbl> <dbl>
#> 1 dark_house                    1250.  179.     900.    1601.      0.520    36
#> 2 open                          1156.  142.     878.    1434.      0.480    36
```

The `proportion` column shows each shelter group’s share of total
effort. Dark-house anglers tend to fish longer hours on average, which
can make their proportional effort contribution larger than their share
of party counts alone would suggest.

## Catch Rate Estimation

[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
computes the ratio-of-means CPUE (fish per angler-hour) using the catch
and effort columns specified in
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
By default, only complete trips are used to avoid the well-known
incomplete-trip bias in effort-based catch rates.

``` r
cpue_est <- estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=60, 83.3% of 72 interviews) [default]
print(cpue_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.216 0.0258    0.165    0.266    60
```

The `estimate` column is walleye per hour-on-ice, with a standard error
and 95% confidence interval. The `n` column counts the number of
complete interviews used in the ratio.

## Total Catch Estimation

[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
multiplies the CPUE estimate by the total effort estimate to produce a
total fish catch estimate. It uses all interviews (complete and
incomplete) for the effort component and only complete trips for the
catch rate, following standard creel survey methodology.

``` r
total_catch_est <- estimate_total_catch(design)
print(total_catch_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     477.  46.3     386.     567.    72
```

The `estimate` column is the projected total walleye catch across the
entire survey period, with a standard error and 95% confidence interval
computed via the delta method.

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883-919. American Fisheries Society.

- Malvestuto, S. P. (1996). Sampling the recreational angler. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591-623. American Fisheries
  Society.
