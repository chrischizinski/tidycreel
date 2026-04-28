# Progressive Count Surveys

## Overview

A progressive count survey replaces the random spot-check of an
instantaneous count with a complete traversal of the access corridor.
The observer drives or walks the entire shoreline, access road, or boat
ramp circuit — counting every angler encountered along the way. This
vignette demonstrates the full progressive count workflow: scheduling,
data collection structure, effort estimation, and catch estimation.

## Instantaneous vs. Progressive Counts

| Feature          | Instantaneous                        | Progressive                                          |
|------------------|--------------------------------------|------------------------------------------------------|
| Observer visits  | One spot at a random time            | Full circuit of the section                          |
| Count meaning    | Anglers visible at a moment          | Anglers encountered during circuit                   |
| Estimator        | ${\widehat{E}}_{d} = C \times T_{d}$ | ${\widehat{E}}_{d} = C \times T_{d}$                 |
| Additional input | —                                    | `circuit_time` (τ) and `period_length_col` ($T_{d}$) |
| Circuit time τ   | Not needed                           | Required (cancels algebraically)                     |

The estimators are algebraically identical once the progressive count
formula is expanded:
${\widehat{E}}_{d} = C \times \tau \times \left( T_{d}/\tau \right) = C \times T_{d}$.
The circuit time $\tau$ cancels, so only the raw count $C$ and the total
open hours $T_{d}$ enter the final calculation. Nevertheless, $\tau$
must be supplied to
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
as a check that the field protocol (circuit duration) is documented.

## When to Use Progressive Counts

Progressive counts are preferred when:

- Anglers are spread along a linear corridor (river, canal, reservoir
  shoreline road) and a single spot-check would miss substantial
  activity
- The access route is fully enumerable in one traverse within a count
  period
- Observer movement is fast relative to angler turnover (circuit time \<
  30% of $T_{d}$)

Instantaneous counts are preferred when:

- The waterbody is large and a complete traverse is impractical
- Multiple sections are counted simultaneously by separate crews
- Observer presence along the circuit might disturb anglers or alert
  them to upcoming interviews

## Data Requirements

A progressive count dataset needs:

1.  **Calendar** — sampled dates with `day_type` and `open_hours`
    ($T_{d}$)
2.  **Count data** — one row per sampled day with raw angler count ($C$)
    and a column recording $T_{d}$ (the same `open_hours` value, or an
    observed value if the site closed early)
3.  **`circuit_time`** — a single numeric value (hours) for the
    traversal duration $\tau$

## A Complete Example

### Survey Setup

We survey a 25-km reservoir access road over a 4-week season
(July–July). A single crew completes the full circuit in 2 hours
($\tau = 2$ h). The access road is open 10 hours per day.

``` r
library(tidycreel)

# Four-week season: 10 weekdays, 8 weekend days sampled
calendar <- data.frame(
  date = as.Date(c(
    # Weekdays
    "2024-07-01", "2024-07-02", "2024-07-03", "2024-07-04", "2024-07-05",
    "2024-07-09", "2024-07-10", "2024-07-11", "2024-07-12", "2024-07-16",
    # Weekends
    "2024-07-06", "2024-07-07", "2024-07-13", "2024-07-14",
    "2024-07-20", "2024-07-21", "2024-07-27", "2024-07-28"
  )),
  day_type = c(rep("weekday", 10), rep("weekend", 8)),
  open_hours = 10
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

Specify `count_type = "progressive"`, the circuit time $\tau$ in hours,
and the column holding $T_{d}$:

``` r
design <- add_counts(
  design, counts,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

# Per-day expanded effort (C × T_d) stored in design$counts
head(design$counts, 4)
#>         date day_type n_anglers
#> 1 2024-07-01  weekday       180
#> 2 2024-07-02  weekday       220
#> 3 2024-07-03  weekday       150
#> 4 2024-07-04  weekday       120
```

The `n_anglers` column now holds ${\widehat{E}}_{d} = C \times T_{d}$,
not the raw count. For the first day (18 anglers × 10 hours = 180
angler-hours):

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

The `estimate` column is the stratified total angler-hours for the
4-week season. The `se` column is the standard error of that total;
`se_within` is always zero for progressive surveys because there is only
one circuit per day (no within-day replication).

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
  harvest = catch_kept
)
#> Warning: 10 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
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
#> 1    3846.  305.    3248.    4445.   120
```

[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
multiplies the effort estimate by the CPUE estimate and propagates
uncertainty via the delta method, producing a season-total catch with a
combined standard error.

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
#> 1     989.  121.     752.    1225.   120
```

## Pope et al. Worked Example

Pope et al. (in press) give the canonical calculation: $C = 234$ anglers
encountered during a $\tau = 2$ h circuit on a day with $T_{d} = 8$ open
hours.

$${\widehat{E}}_{d} = 234 \times 8 = 1,872{\mspace{6mu}\text{angler-hours}}$$

``` r
cal_pope <- data.frame(
  date       = as.Date(c("2024-06-01", "2024-06-02")),
  day_type   = c("weekday", "weekday"),
  open_hours = c(8, 8)
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
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

# First-day Ê_d = 234 × 8 = 1,872 angler-hours
des_pope$counts
#>         date day_type n_anglers
#> 1 2024-06-01  weekday      1872
#> 2 2024-06-02  weekday      1600
```

## Multiple Periods per Day

Some progressive surveys run two circuits per day (e.g., morning and
evening). This creates multiple counts per PSU (day), and tidycreel
decomposes variance into between-day and within-day components via the
Rasmussen (1994) two-stage formula.

For the morning–evening case, use `count_time_col` to identify the
circuit within each day:

``` r
# Two circuits per day (morning and evening traversals)
cal_2p <- data.frame(
  date       = rep(as.Date(c("2024-07-01", "2024-07-02", "2024-07-06", "2024-07-07")), 1),
  day_type   = c("weekday", "weekday", "weekend", "weekend"),
  open_hours = 12
)
des_2p <- creel_design(cal_2p, date = date, strata = day_type)

cnt_2p <- data.frame(
  date = rep(as.Date(c(
    "2024-07-01", "2024-07-02",
    "2024-07-06", "2024-07-07"
  )), each = 2),
  day_type = rep(c("weekday", "weekday", "weekend", "weekend"), each = 2),
  count_time = rep(c("am", "pm"), 4),
  n_anglers = c(22L, 18L, 20L, 24L, 55L, 48L, 62L, 58L),
  shift_hours = 12
)

# Note: count_time_col for within-day identification
des_2p <- add_counts(des_2p, cnt_2p, count_time_col = count_time)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

est_2p <- estimate_effort(des_2p)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
est_2p$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     154.  10.0       8.73      4.92     110.     197.     4
```

The `se_within` column is now non-zero, reflecting variability between
the morning and evening circuits within each day.

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

- Pope, K. L., Wilde, G. R., and Gabelhouse, D. W. Jr. (in press). Creel
  Surveys. Chapter 17 in *Fisheries Techniques*, 4th ed. American
  Fisheries Society, Bethesda, MD.

- Rasmussen, P. W. (1994). Two-stage variance estimation for creel
  surveys.

- Su, Y.-S., and Liu, P. (2025). Flexible creel survey estimators.
  *Canadian Journal of Fisheries and Aquatic Sciences*, 82, 1–27.
