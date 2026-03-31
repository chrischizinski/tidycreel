# Flexible Count Estimation

## Introduction

Creel surveys estimate angler effort — the total angler-hours or
angler-trips on a waterbody during a survey period. The count data
collected in the field can take two forms:

- **Instantaneous counts** (Hoenig et al. 1993): At a random time within
  the survey period, an observer records the number of anglers visible
  on a section. Effort is estimated as count × total open hours.

- **Progressive counts** (Pope et al., in press): An observer travels
  the entire section (one “circuit”) and records the number of anglers
  encountered along the way. Effort is estimated as count × circuit
  travel time × section open hours / circuit travel time, i.e., Ê_d = C
  × τ × (T_d / τ) = C × T_d where τ is circuit travel time and T_d is
  the total open hours on day d.

In addition, observers may complete **multiple counts per day** (e.g.,
morning and afternoon circuits). When multiple counts are recorded per
sampling unit (PSU), tidycreel aggregates them automatically and
decomposes variance into a between-day component and a within-day
component via the Rasmussen (1994) two-stage formula.

This vignette demonstrates all three workflows using inline data.

## Single Count per Day (Instantaneous Baseline)

The classic workflow records one instantaneous count per PSU (day ×
stratum).

``` r
library(tidycreel)

# Survey calendar: four days, two strata
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  open_hours = rep(10, 4)
)

design <- creel_design(calendar, date = date, strata = day_type)

# One count per day
counts <- data.frame(
  date      = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type  = c("weekday", "weekday", "weekend", "weekend"),
  n_anglers = c(15L, 23L, 45L, 52L)
)

design <- add_counts(design, counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
result <- estimate_effort(design)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
result$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      135  10.6       10.6         0     89.3     181.     4
```

With a single count per day, `se_within` is always zero — there is no
within-day replication to estimate within-day variance. The `se` column
equals `se_between`.

## Multiple Counts per Day

When observers complete multiple circuits on the same day, each circuit
is a sub-sample within the PSU. Supply the circuit identifier column via
`count_time_col`.

``` r
# Two circuits per day: morning ("am") and afternoon ("pm")
calendar_m <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  open_hours = rep(10, 4)
)

design_m <- creel_design(calendar_m, date = date, strata = day_type)

multi_counts <- data.frame(
  date = as.Date(rep(c(
    "2024-06-01", "2024-06-02",
    "2024-06-03", "2024-06-04"
  ), each = 2)),
  day_type = rep(c("weekday", "weekday", "weekend", "weekend"), each = 2),
  count_time = rep(c("am", "pm"), 4),
  n_anglers = c(12L, 18L, 20L, 26L, 40L, 50L, 48L, 56L)
)

design_m <- add_counts(design_m, multi_counts, count_time_col = count_time)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
result_m <- estimate_effort(design_m)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
result_m$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      135  13.1       10.6      7.68     78.6     191.     4
```

The output tibble now contains nonzero `se_within` values. Total
variance is `se^2 = se_between^2 + se_within^2` (combined in
quadrature). When within-day angler counts vary substantially between
circuits, `se_within` can be the dominant variance component.

### When does `se_within` matter?

`se_within` is small when counts are stable throughout the day (e.g., a
lake where angler density is roughly constant). It is large when
activity patterns are strongly bimodal (e.g., a river with a morning
bite and an evening bite but few mid-day anglers). Collecting multiple
counts per day is most valuable when such within-day variation is
expected and needs to be quantified rather than assumed away.

## Progressive Count Type

Progressive surveys replace a spot-check count with a complete traversal
of the section. The observer counts every angler encountered during one
circuit of duration τ hours. The estimator is:

$${\widehat{E}}_{d} = C_{d} \times T_{d}$$

where C_d is the count on day d and T_d is the total open hours on day d
(the `period_length_col` argument). The circuit time τ cancels
algebraically; it is only needed internally to compute the expansion
factor κ = T_d / τ.

``` r
calendar_p <- data.frame(
  date       = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type   = c("weekday", "weekday", "weekend", "weekend"),
  open_hours = rep(8, 4)
)

design_p <- creel_design(calendar_p, date = date, strata = day_type)

prog_counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  n_anglers = c(15L, 23L, 45L, 52L),
  shift_hours = rep(8, 4)
)

design_p <- add_counts(
  design_p, prog_counts,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

result_p <- estimate_effort(design_p)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
result_p$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     1080  85.0       85.0         0     714.    1446.     4
```

### Worked example (Pope et al.)

Pope et al. (in press) give a worked example with C = 234 anglers
encountered during a 2-hour circuit (τ = 2 h) on a day with 8 open hours
(T_d = 8 h):

$${\widehat{E}}_{d} = 234 \times 8 = 1,872{\mspace{6mu}\text{angler-hours}}$$

The code below reproduces this per-day calculation for a two-day survey.
The processed design’s `$counts` slot stores the expanded per-day effort
(Ê_d), so we can confirm the first-day value equals 1,872 angler-hours
directly.

``` r
# Reproduce Pope et al. per-day calculation
cal_pope <- data.frame(
  date       = as.Date(c("2024-06-01", "2024-06-02")),
  day_type   = c("weekday", "weekday"),
  open_hours = c(8, 8)
)
design_pope <- creel_design(cal_pope, date = date, strata = day_type)

cnt_pope <- data.frame(
  date        = as.Date(c("2024-06-01", "2024-06-02")),
  day_type    = c("weekday", "weekday"),
  n_anglers   = c(234L, 200L),
  shift_hours = c(8, 8)
)

design_pope <- add_counts(
  design_pope, cnt_pope,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

# Per-day Ê_d values stored in the design (first day = 1,872 angler-hours)
design_pope$counts
#>         date day_type n_anglers
#> 1 2024-06-01  weekday      1872
#> 2 2024-06-02  weekday      1600
```

The `n_anglers` column in `design_pope$counts` shows 1,872 for June 1st
— matching the Pope et al. formula exactly.

## Interpreting `se_between` and `se_within`

| Column       | Source                                                                                             | Zero when                |
|--------------|----------------------------------------------------------------------------------------------------|--------------------------|
| `se_between` | Between-PSU variance via [`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) | Never (always estimated) |
| `se_within`  | Rasmussen (1994) two-stage within-day formula                                                      | Single count per PSU     |
| `se`         | Combined SE: `sqrt(se_between^2 + se_within^2)`                                                    | Never                    |

**Practical guidance:**

- If you collect one count per PSU, `se_within = 0` and
  `se = se_between`. The classical creel estimator is recovered exactly.

- If you collect multiple counts per PSU, monitor the ratio
  `se_within / se`. A large ratio (\> 0.5) indicates substantial
  within-day variation and suggests that daily sampling intensity
  (number of circuits) is a meaningful driver of precision.

- For progressive surveys, the estimator variance structure is the same
  as for instantaneous counts. The key difference is in how the
  single-PSU effort Ê_d is calculated.

## References

- Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
  Scheduling counts in the instantaneous and progressive count methods
  for estimating sportfishing effort. *North American Journal of
  Fisheries Management*, 13, 723–736.

- Rasmussen, P. W. (1994). Two-stage variance estimation for creel
  surveys. Cited in Su, Y.-S., and Liu, P. (2025), equations 17–18.

- Su, Y.-S., and Liu, P. (2025). Flexible creel survey estimators.
  *Canadian Journal of Fisheries and Aquatic Sciences*, 82, 1–27.
