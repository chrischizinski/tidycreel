# Ice Fishing Survey Analysis

## Overview

Ice fishing creel surveys share the bus-route structure, but all access
points are sampled with certainty. Every angler leaving the lake must
pass through the single ice access point (the boat ramp area or
designated ice-access site), so there is no site-level subsampling. The
site inclusion probability is always `p_site = 1.0`, and the overall
inclusion probability reduces to just the period sampling probability:

``` math
\pi_i = p\_site \times p\_period = 1.0 \times p\_period = p\_period
```

In tidycreel, this is a *degenerate* bus-route design. The bus-route
Horvitz-Thompson estimators still apply; only the probability structure
is simpler.

### Effort type distinction

Ice fishing surveys collect two distinct effort measures:

- **time_on_ice** — total hours the angler party was physically on the
  ice, including travel to the fishing hole, breaks, and social time.
  This is the easiest to record and most commonly used.
- **active_fishing_time** — hours spent with lines in the water,
  excluding travel, setup, and breaks. This captures actual fishing
  pressure more precisely but requires more careful interviewing.

The `effort_type` argument to
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
controls which measure the design tracks, and adds a matching column to
the
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
output: `total_effort_hr_on_ice` for `"time_on_ice"` and
`total_effort_hr_active` for `"active_fishing_time"`. Both are aliases
of `estimate`, which is present on every design and is what generic code
should read.

### Shelter mode stratification

Ice anglers fish from open-air setups or enclosed dark-house shelters.
Catch rates and effort patterns differ between these groups — dark-house
anglers often target specific species and fish longer hours. The
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
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
#>   n_anglers
#> 1         2
#> 2         1
#> 3         3
#> 4         1
#> 5         1
#> 6         1
```

The sampling frame records the survey calendar, every day of which was
worked, and the period sampling probability: `p_period = 0.5` means that
on each worked day one of two periods (morning or afternoon) was
covered, so each interview stands for twice its share of that day. It is
a within-day probability, not the chance that a day was sampled; which
days were worked is recorded separately, in the calendar. The interview
data contains 72 interviews with walleye and perch catch, both effort
measures, and the shelter type (`shelter_mode`) for each angler party.

## Design Construction

Build an ice fishing design using
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
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
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
to attach the survey data to the design. For ice surveys, `n_counted`
and `n_interviewed` are required — they record how many parties were
counted at the access point versus how many were actually interviewed
during each visit, providing the enumeration expansion factor. Each row
is a party, so `n_anglers` gives its size: hours on the ice times party
size is the party’s angler-hours. Without it, effort would be in
party-hours.

``` r

design <- add_interviews(
  design,
  example_ice_interviews,
  catch         = walleye_catch,
  effort        = hours_on_ice,
  harvest       = walleye_kept,
  trip_status   = trip_status,
  n_counted     = n_counted,
  n_interviewed = n_interviewed,
  n_anglers     = n_anglers
)
#> ℹ 23 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 72 interviews: 60 complete (83%), 12 incomplete (17%)
```

## Effort Estimation

[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
dispatches through the bus-route Horvitz-Thompson estimator and returns
the total angler-hours with a standard error and confidence interval.
The effort column is returned twice: as `estimate`, the name every
design uses and the one generic code should read, and again under a name
recording the effort type – `total_effort_hr_on_ice` because the design
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
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 6
#>   estimate    se ci_lower ci_upper     n total_effort_hr_on_ice
#>      <dbl> <dbl>    <dbl>    <dbl> <int>                  <dbl>
#> 1    3819.  261.    3308.    4330.    72                  3819.
```

This is the total over the days worked. To expand to a season with days
that were not worked, give the calendar a logical column marking the
worked days and pass it as `creel_design(sampled = )`;
`target = "period_total"` then scales each stratum by its calendar days
over its worked days. Mark a worked day on which nobody was out as
worked too: it is a day of zero effort, and leaving it out would inflate
the season total.

To demonstrate the column-naming distinction, rebuild the design using
`effort_type = "active_fishing_time"` and the `active_fishing_hours`
column from the interview data. The effort-type column is then labeled
`total_effort_hr_active`; `estimate` is present either way.

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
  n_interviewed = n_interviewed,
  n_anglers     = n_anglers
))

effort_aft <- estimate_effort(design_aft)
print(effort_aft)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 6
#>   estimate    se ci_lower ci_upper     n total_effort_hr_active
#>      <dbl> <dbl>    <dbl>    <dbl> <int>                  <dbl>
#> 1    3148.  216.    2725.    3571.    72                  3148.
```

Active fishing hours are shorter than time-on-ice because they exclude
travel, setup, and breaks. The difference between the two estimates
reflects the non-fishing portion of each trip.

## Shelter Mode Stratification

Pass `by = shelter_mode` to
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
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
#> Unit: angler-hours
#> 
#> # A tibble: 2 × 8
#>   shelter_mode estimate    se ci_lower ci_upper proportion     n
#>   <chr>           <dbl> <dbl>    <dbl>    <dbl>      <dbl> <int>
#> 1 dark_house      1867.  122.    1627.    2106.      0.489    36
#> 2 open            1952.  216.    1529.    2375.      0.511    36
#> # ℹ 1 more variable: total_effort_hr_on_ice <dbl>
```

The `proportion` column shows each shelter group’s share of total
effort. Dark-house anglers tend to fish longer hours on average, which
can make their proportional effort contribution larger than their share
of party counts alone would suggest.

## Catch Rate Estimation

[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
computes the ratio-of-means CPUE (fish per angler-hour) using the catch
and effort columns specified in
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md).
By default, only complete trips are used to avoid the well-known
incomplete-trip bias in effort-based catch rates.

``` r

cpue_est <- estimate_catch_rate(design)
print(cpue_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/angler-hour
#> 
#> # A tibble: 1 × 5
#>   estimate      se ci_lower ci_upper     n
#>      <dbl>   <dbl>    <dbl>    <dbl> <int>
#> 1    0.121 0.00828    0.104    0.137    60
```

The `estimate` column is walleye per angler-hour on the ice, with a
standard error and 95% confidence interval. The `n` column counts the
number of complete interviews used in the ratio.

## Total Catch Estimation

On instantaneous designs
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
multiplies a catch rate by a total effort estimate, but ice designs take
the bus-route dispatch instead and form no such product. The total is a
direct Horvitz-Thompson sum over the interviewed parties, each party’s
catch divided by its inclusion probability $`\pi_i`$; there is no CPUE
term and no effort term. The method is reported as `ht-total-catch`
rather than `product-total-catch`.

Only completed trips enter the sum. A party still fishing has caught
some of its eventual catch, so counting it would expand a partial catch
under the inclusion probability of a finished trip. Of the 72
interviews, the 60 complete ones contribute and the 12 incomplete ones
are dropped — which is why the `n` column below reads 60. For the same
reason `use_trips = "all"` is refused on ice and bus-route designs;
incomplete trips support a rate, via
`estimate_catch_rate(use_trips = "incomplete")`, not a total.

``` r

total_catch_est <- estimate_total_catch(design)
print(total_catch_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Horvitz-Thompson)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: fish
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     398.  20.6     358.     439.    60
```

The `estimate` column is the projected total walleye catch across the
entire survey period. The standard error and 95% confidence interval
come from Taylor linearization on the Horvitz-Thompson sum, not from the
delta method — there is no product of two estimates here whose
uncertainty would need propagating.

## Results as Data

Each estimate converts to a tibble with its method, variance method and
unit as columns, and plots with its confidence interval:

``` r

tibble::as_tibble(effort_by_shelter)
#> # A tibble: 2 × 13
#>   shelter_mode estimate    se ci_lower ci_upper proportion     n
#>   <chr>           <dbl> <dbl>    <dbl>    <dbl>      <dbl> <int>
#> 1 dark_house      1867.  122.    1627.    2106.      0.489    36
#> 2 open            1952.  216.    1529.    2375.      0.511    36
#> # ℹ 6 more variables: total_effort_hr_on_ice <dbl>, method <chr>,
#> #   variance_method <chr>, conf_level <dbl>, effort_target <chr>, unit <chr>

ggplot2::autoplot(effort_by_shelter)
```

![Effort estimates for open and dark-house anglers with 95 percent
confidence intervals.](ice-fishing_files/figure-html/results-1.png)

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational angler survey
  methods: estimation of effort, harvest, and released catch. Chapter 19
  in *Fisheries Techniques* (3rd ed.), pp. 883-919. American Fisheries
  Society.

- Malvestuto, S. P. (1996). Sampling the recreational creel. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591-623. American Fisheries
  Society.
