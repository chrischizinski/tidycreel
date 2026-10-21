# Progressive Count Surveys

## Overview

A progressive count survey replaces the random spot-check of an
instantaneous count with a complete traversal of the access corridor.
The observer drives or walks the entire shoreline, access road, or boat
ramp circuit — counting every angler encountered along the way. This
vignette demonstrates the full progressive count workflow: scheduling,
data collection structure, effort estimation, and catch estimation.

## Instantaneous vs. Progressive Counts

| Feature | Instantaneous | Progressive |
|----|----|----|
| Observer visits | One spot at a random time | Full circuit of the section |
| Count meaning | Anglers visible at a moment | Anglers encountered during circuit |
| Estimator | $`\hat{E}_d = C \times T_d`$ | $`\hat{E}_d = C \times T_d`$ |
| Additional input | — | `circuit_time` (τ) and `period_length_col` ($`T_d`$) |
| Circuit time τ | Not needed | Required (cancels algebraically) |

The estimators are algebraically identical once the progressive count
formula is expanded:
$`\hat{E}_d = C \times \tau \times (T_d / \tau) = C \times T_d`$. The
circuit time $`\tau`$ cancels, so only the raw count $`C`$ and the total
open hours $`T_d`$ enter the final calculation. Nevertheless, $`\tau`$
must be supplied to
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
as a check that the field protocol (circuit duration) is documented.

## When to Use Progressive Counts

Progressive counts are preferred when:

- Anglers are spread along a linear corridor (river, canal, reservoir
  shoreline road) and a single spot-check would miss substantial
  activity
- The access route is fully enumerable in one traverse within a count
  period
- The observer can travel the circuit faster than anglers move between
  fishing spots (see the conditions below — this is a requirement of the
  method, not a preference)

Instantaneous counts are preferred when:

- The waterbody is large and a complete traverse is impractical
- Multiple sections are counted simultaneously by separate crews
- Observer presence along the circuit might disturb anglers or alert
  them to upcoming interviews

## Conditions for an Unbiased Estimate

$`\hat{E}_d = C \times T_d`$ is unbiased only when the field protocol
satisfies three conditions (Hoenig et al. 1993, p. 725). They are
properties of how the count is *collected*, so no check inside
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
can confirm them — they are the analyst’s responsibility:

1.  **The starting location on the circuit is chosen randomly.** Always
    beginning at the boat ramp biases the count toward whatever is
    happening there at that hour.
2.  **The direction of travel is chosen randomly** from the two
    alternatives.
    [`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md)
    draws this for you and returns it in the `direction` column — it is
    a field instruction, not decoration.
3.  **The observer travels faster than the anglers move** while those
    anglers are fishing. If anglers can outpace the observer they may be
    counted twice or missed.

Two further cautions from the same paper:

- **Do not interrupt the circuit to conduct interviews.** The derivation
  assumes constant travel speed; stopping to interview breaks it and is
  one of the four errors Hoenig et al. single out. Interview on a
  separate pass.
- **The count estimates angler-days of effort, not the number of
  trips.** Reading $`C`$ as a trip count “results in a negative bias
  that can be severe” (Hoenig et al. 1993). $`C`$ counts anglers
  present, and an angler fishing all day is counted once per circuit —
  not once per trip.

Scheduling the circuit start correctly is the fourth condition, and it
is the subject of the section below.

## Data Requirements

A progressive count dataset needs:

1.  **Calendar** — sampled dates with `day_type`. The calendar carries
    no hours column:
    [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
    reads only the date and the strata, so $`T_d`$ must travel with the
    counts.
2.  **Count data** — one row per sampled day with raw angler count
    ($`C`$) and a column recording $`T_d`$, passed as
    `period_length_col`. This is the only place the estimator looks for
    the open hours.
3.  **`circuit_time`** — a single numeric value (hours) for the
    traversal duration $`\tau`$

## A Complete Example

### Survey Setup

We survey a 25-km reservoir access road on 18 sampled days in July. A
single crew completes the full circuit in 2 hours ($`\tau = 2`$ h). The
access road is open 10 hours per day. The calendar below lists only the
sampled days, so the totals on this page are totals over those days;
[`vignette("temporal-extrapolation")`](https://chrischizinski.com/tidycreel/dev/articles/temporal-extrapolation.md)
shows how to expand to a whole season.

``` r

library(tidycreel)

# 18 sampled days: 10 weekdays and 8 weekend days
calendar <- data.frame(
  date = as.Date(c(
    # Weekdays
    "2024-07-01", "2024-07-02", "2024-07-03", "2024-07-04", "2024-07-05",
    "2024-07-09", "2024-07-10", "2024-07-11", "2024-07-12", "2024-07-16",
    # Weekends
    "2024-07-06", "2024-07-07", "2024-07-13", "2024-07-14",
    "2024-07-20", "2024-07-21", "2024-07-27", "2024-07-28"
  )),
  day_type = c(rep("weekday", 10), rep("weekend", 8))
)

design <- creel_design(calendar, date = date, strata = day_type)
design
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 18 days (2024-07-01 to 2024-07-28)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```

### Scheduling Circuit Start Times

Before field work begins, randomise the circuit start time for each
survey day using
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md).
This ensures the count is unbiased with respect to time-of-day effort
patterns. Two strategies are available:

- `"discrete"` (default): start drawn from the valid τ-aligned offsets —
  avoids mid-day over-representation caused by the common error.
  Requires to be a whole number, and aborts if it is not; adjust
  `circuit_time` or the open hours to make it one.
- `"wraparound"`: start drawn from ; circuit may wrap past the end of
  the survey day. Carries **no** divisibility requirement.

The whole-number requirement belongs to `"discrete"` alone, because that
scheme partitions the day into non-overlapping blocks and samples one.
Under `"wraparound"` the count window slides freely, so is an ordinary
ratio rather than a count of blocks and need not be a whole number.

This is why
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
does not check it. Both schemes give every moment of the day equal
probability of being observed, so both are estimated by the same ; a
divisibility check in the estimator would reject perfectly valid
wraparound designs. The constraint is enforced where it applies — at
scheduling time, by
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md).

``` r

starts <- generate_progressive_start(
  open_start    = "06:00",
  open_end      = "16:00",
  circuit_time  = 2,          # τ = 2 h; T = 10 h → k = 5 valid starts
  strategy      = "discrete",
  n             = nrow(calendar),
  seed          = 42
)
starts
```

*(no date column to render calendar)*

The returned `creel_schedule` records `circuit_start`, `circuit_end`,
`is_wrapped`, and `direction` (`"forward"` / `"reverse"`) for each
survey day. Record the scheduled start and direction in your field
protocol — both are required for unbiased estimation.

### Count Data

Each row is one circuit traversal per sampled day. The `shift_hours`
column records the actual open hours for that day (here always 10, but
could vary if a site closed early due to weather).

``` r

set.seed(7)
counts <- data.frame(
  date = calendar$date,
  day_type = calendar$day_type,
  n_anglers = c(
    # Weekday counts: moderate activity
    18L, 22L, 15L, 12L, 25L, 20L, 17L, 14L, 23L, 19L,
    # Weekend counts: higher activity
    48L, 55L, 42L, 61L, 53L, 47L, 58L, 64L
  ),
  shift_hours = 10
)
```

### Attaching Progressive Counts

Specify `count_type = "progressive"`, the circuit time $`\tau`$ in
hours, and the column holding $`T_d`$:

``` r

design <- add_counts(
  design, counts,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)

# Per-day expanded effort (C × T_d) stored in design$counts
head(design$counts, 4)
#>         date day_type n_anglers
#> 1 2024-07-01  weekday       180
#> 2 2024-07-02  weekday       220
#> 3 2024-07-03  weekday       150
#> 4 2024-07-04  weekday       120
```

The `n_anglers` column now holds $`\hat{E}_d = C \times T_d`$, not the
raw count. For the first day (18 anglers × 10 hours = 180 angler-hours):

``` r

# Verify: C × T_d = 18 × 10 = 180
design$counts$n_anglers[1]
#> [1] 180
```

### Effort Estimation

``` r

effort <- estimate_effort(design)
effort$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     6130  249.       249.         0    5601.    6659.    18
```

The `estimate` column is the stratified total angler-hours over the 18
sampled days, and `se` its standard error. With one circuit per day
`se_within` is reported as 0. That does not mean effort was steady
through the day: the day-to-day term contains the within-day variation,
but with one circuit per day it cannot be separated out, so the 0 stands
for “not estimated”.

### Adding Interviews

Interviews are collected during or after the circuit traversal. Attach
them exactly as in any other survey type:

``` r

set.seed(7)
n_int <- 120 # interviews collected across the season

int_dates <- sample(calendar$date, n_int, replace = TRUE)
catch_total <- rpois(n_int, lambda = 2.1)
interviews <- data.frame(
  date = int_dates,
  day_type = calendar$day_type[match(int_dates, calendar$date)],
  trip_status = "complete",
  hours_fished = round(pmax(rnorm(n_int, mean = 3.8, sd = 1.3), 0.5), 1),
  catch_total = catch_total,
  catch_kept = pmin(rpois(n_int, lambda = 0.7), catch_total)
)

design <- add_interviews(
  design, interviews,
  trip_status = trip_status,
  catch = catch_total,
  effort = hours_fished,
  n_anglers = 1, # every interview is a single angler
  harvest = catch_kept
)
```

### Catch Rate and Total Catch

``` r

cpue <- estimate_catch_rate(design)
cpue$estimates
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.606 0.0389    0.530    0.682   120

total_catch <- estimate_total_catch(design)
total_catch$estimates
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    3846.  305.    3243.    4450.   120
```

[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
multiplies each day type’s effort by that day type’s catch rate and adds
the products. Its standard error combines the two estimates’ variances,
treating effort and rate as independent;
[`vignette("catch-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/catch-pipeline.md)
explains the formula and that assumption.

### Harvest Rate and Total Harvest

``` r

harvest_rate <- estimate_harvest_rate(design)
harvest_rate$estimates
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.161 0.0186    0.125    0.198   120

total_harvest <- estimate_total_harvest(design)
total_harvest$estimates
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     966.  129.     711.    1222.   120
```

## Pope et al. Worked Example

Pope et al. (Chapter 17 draft) give the calculation: $`C = 234`$ anglers
encountered during a $`\tau = 2`$ h circuit on a day with $`T_d = 8`$
open hours.

``` math
\hat{E}_d = 234 \times 8 = 1{,}872 \text{ angler-hours}
```

``` r

cal_pope <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02")),
  day_type = c("weekday", "weekday")
)
des_pope <- creel_design(cal_pope, date = date, strata = day_type)

cnt_pope <- data.frame(
  date        = as.Date(c("2024-06-01", "2024-06-02")),
  day_type    = c("weekday", "weekday"),
  n_anglers   = c(234L, 200L),
  shift_hours = c(8, 8)
)
des_pope <- add_counts(
  des_pope, cnt_pope,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)

# First-day Ê_d = 234 × 8 = 1,872 angler-hours
des_pope$counts
#>         date day_type n_anglers
#> 1 2024-06-01  weekday      1872
#> 2 2024-06-02  weekday      1600
```

## Multiple Periods per Day

Some progressive surveys run two circuits per day (e.g., morning and
evening). This creates several counts per day, the sampling unit, and
tidycreel splits the variance into a between-day and a within-day term:
Cochran’s (1977) two-stage variance, as Pope et al. (Chapter 17 draft)
apply it to creel counts.

Name the circuit within each day with `count_time_col`, alongside the
progressive arguments. Each day’s effort is then the mean of its
circuits’ $`C \times T_d`$:

``` r

# Two circuits per day (morning and evening traversals), three days per day type
days_2p <- as.Date(c(
  "2024-07-01", "2024-07-02", "2024-07-03",
  "2024-07-06", "2024-07-07", "2024-07-13"
))
cal_2p <- data.frame(
  date     = days_2p,
  day_type = rep(c("weekday", "weekend"), each = 3)
)
des_2p <- creel_design(cal_2p, date = date, strata = day_type)

cnt_2p <- data.frame(
  date        = rep(days_2p, each = 2),
  day_type    = rep(c("weekday", "weekend"), each = 6),
  count_time  = rep(c("am", "pm"), 6),
  n_anglers   = c(22L, 18L, 20L, 24L, 17L, 21L, 55L, 48L, 62L, 58L, 51L, 57L),
  shift_hours = 10
)

des_2p <- add_counts(des_2p, cnt_2p,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours,
  count_time_col = count_time
)

est_2p <- estimate_effort(des_2p)
est_2p$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     2265  101.       80.2      61.0    1985.    2545.     6
```

`se_within` is now estimated, from the differences between each day’s
morning and evening circuits, and the total is in angler-hours.

## Assemble a Summary Report

``` r

summary_tbl <- season_summary(list(
  effort  = effort,
  catch   = total_catch,
  harvest = total_harvest
))

summary_tbl$table
#> # A tibble: 1 × 17
#>   effort_estimate effort_se effort_se_between effort_se_within effort_ci_lower
#>             <dbl>     <dbl>             <dbl>            <dbl>           <dbl>
#> 1            6130      249.              249.                0           5601.
#> # ℹ 12 more variables: effort_ci_upper <dbl>, effort_n <int>,
#> #   catch_estimate <dbl>, catch_se <dbl>, catch_ci_lower <dbl>,
#> #   catch_ci_upper <dbl>, catch_n <int>, harvest_estimate <dbl>,
#> #   harvest_se <dbl>, harvest_ci_lower <dbl>, harvest_ci_upper <dbl>,
#> #   harvest_n <int>
```

## References

- Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
  Scheduling counts in the instantaneous and progressive count methods
  for estimating sportfishing effort. *North American Journal of
  Fisheries Management*, 13, 723–736.

- Pope, K. L., et al. Creel surveys. Chapter 17 (unpublished draft).

- Cochran, W. G. (1977). *Sampling Techniques*, 3rd edition. Wiley, New
  York.
