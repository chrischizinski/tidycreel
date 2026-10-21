# Season, Monthly and Annual Totals

## The task

A creel survey samples some of the days in a season. The number usually
reported is the effort or catch over **every** day of the season, and
often a total for each month. This page shows how to get both from one
design.

Two things have to be true for an estimate to cover unsampled days:

1.  **The calendar lists every day of the period**, sampled or not.
    tidycreel counts the days in each stratum from the calendar; the
    sampled days are the ones that have counts. A calendar of sampled
    days only has nothing to expand to.
2.  **You ask for the period**, with `target = "period_total"`. The
    default, `target = "sampled_days"`, is the total over the days that
    were sampled.

Each stratum’s mean daily effort is multiplied by the number of days in
that stratum, and the strata are added (the stratified estimator of
Pollock et al. 1994, Ch. 3).

## A simulated season

May to September, 153 days. Weekends were sampled at about half and
weekdays at about a third, with one instantaneous count on each sampled
day. The fishing day is 14 hours, and the count was made at a random
moment within it.

``` r

library(tidycreel)

set.seed(2024)
all_dates <- seq(as.Date("2024-05-01"), as.Date("2024-09-30"), by = "1 day")
day_type <- ifelse(as.integer(format(all_dates, "%u")) %in% 6:7, "weekend", "weekday")
month <- factor(month.name[as.integer(format(all_dates, "%m"))], levels = month.name[5:9])

# Every day of the season, sampled or not
season_calendar <- data.frame(date = all_dates, month = month, day_type = day_type)

sampled <- runif(length(all_dates)) < ifelse(day_type == "weekend", 0.5, 0.3)
s <- season_calendar[sampled, ]

# One instantaneous count per sampled day, made within a 14-hour fishing day
counts <- data.frame(
  date = s$date, month = s$month, day_type = s$day_type,
  anglers = pmax(round(ifelse(s$day_type == "weekend",
    rnorm(nrow(s), mean = 55, sd = 18),
    rnorm(nrow(s), mean = 28, sd = 12)
  )), 0),
  fishing_day = 14
)

table(s$month, s$day_type)
#>            
#>             weekday weekend
#>   May             7       3
#>   June            5       9
#>   July            6       6
#>   August         10       3
#>   September       6       6
```

## Season total

The strata are month and day type together, so that each month’s days
are their own strata. That is what lets the same design report months as
well as the season (next section).

``` r

design <- creel_design(season_calendar, date = date, strata = c(month, day_type))
design <- add_counts(design, counts,
  count_col = anglers,
  period_length_col = fishing_day
)

estimate_effort(design)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    34860 1604.      1604.         0   31639.   38081.    61
estimate_effort(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1   81407. 4233.      4233.         0   72909.   89904.    61
```

The first estimate is the effort on the 61 sampled days. The second is
the season total, about 81,400 angler-hours: the number to report. The
unit is angler-hours because each count was given the 14-hour period it
was made in (`period_length_col`);
[`vignette("unit-rules")`](https://chrischizinski.com/tidycreel/dev/articles/unit-rules.md)
explains why the unit is derived rather than assumed.

## Monthly totals

Because each month is made of its own strata, a monthly total is the sum
of that month’s strata. Ask for it with `by = month`:

``` r

monthly_effort <- estimate_effort(design, by = month, target = "period_total")
monthly_effort
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: month
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 5 × 8
#>   month     estimate    se se_between se_within ci_lower ci_upper     n
#>   <fct>        <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 May         16882  2046.      2046.         0   12774.   20990.    10
#> 2 June        16878. 2523.      2523.         0   11813.   21943.    14
#> 3 July        17397. 1518.      1518.         0   14349.   20446.    12
#> 4 August      18735. 2029.      2029.         0   14662.   22808.    13
#> 5 September   11515   971.       971.         0    9566.   13464.    12
```

The months add up to the season total, and their standard errors add in
quadrature to the season’s, because strata are sampled independently:

``` r

monthly <- tibble::as_tibble(monthly_effort)
c(sum = sum(monthly$estimate), se = sqrt(sum(monthly$se^2)))
#>       sum        se 
#> 81406.911  4232.692
```

### Why strata, not a `by` over a season design

Stratifying by month is a design choice, and it changes the season total
a little. With day type as the only stratum the same counts give:

``` r

design_dt <- creel_design(season_calendar, date = date, strata = day_type)
design_dt <- add_counts(design_dt, counts,
  count_col = anglers,
  period_length_col = fishing_day
)
estimate_effort(design_dt, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1   81017. 3870.      3870.         0   73273.   88761.    61
```

about 81,000 instead of 81,400. Neither is wrong. With month strata,
each month’s mean is expanded by that month’s own number of days, so a
month whose sampled days happened to run busy is not averaged into the
quiet ones. Stratify by month when the sampling was planned month by
month, or when monthly totals are needed; then the months are strata and
they add up exactly.

## Catch totals

Interviews attach to the same design. The simulated anglers fish alone,
so `n_anglers = 1`; that makes the rate fish per angler-hour, the same
unit as the effort it multiplies.

``` r

set.seed(2025)
n_per_day <- 4L
n_int <- nrow(s) * n_per_day
interviews <- data.frame(
  date = rep(s$date, each = n_per_day),
  month = rep(s$month, each = n_per_day),
  day_type = rep(s$day_type, each = n_per_day),
  trip_status = "complete",
  hours_fished = pmax(round(rnorm(n_int, mean = 3.5, sd = 1.2), 1), 0.5)
)
interviews$catch_total <- rpois(n_int, lambda = 0.5 * interviews$hours_fished)
interviews$catch_kept <- pmin(rpois(n_int, lambda = 0.6), interviews$catch_total)

design <- add_interviews(design, interviews,
  trip_status = trip_status,
  catch = catch_total,
  effort = hours_fished,
  n_anglers = 1,
  harvest = catch_kept
)
#> ℹ 47 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 244 interviews: 244 complete (100%), 0 incomplete (0%)

monthly_catch <- estimate_total_catch(design, by = month, target = "period_total")
monthly_catch
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: month
#> Effort target: period_total
#> Unit: fish
#> 
#> # A tibble: 5 × 6
#>   month     estimate    se ci_lower ci_upper     n
#>   <fct>        <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 August      11982. 1980.    8004.   15960.    52
#> 2 July         7763. 1026.    5698.    9829.    48
#> 3 June         8407. 1554.    5292.   11522.    56
#> 4 May          8340. 1480.    5343.   11336.    40
#> 5 September    5875.  872.    4119.    7631.    48
estimate_total_catch(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: fish
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1   42367. 3216.   36032.   48702.   244
```

Each month’s catch is that month’s effort times its catch rate, stratum
by stratum, and the months again add to the season total.

## One table for the report

[`season_summary()`](https://chrischizinski.com/tidycreel/dev/reference/season_summary.md)
joins several estimates on their grouping columns into one wide table:

``` r

report <- season_summary(list(effort = monthly_effort, catch = monthly_catch))
report$table
#> # A tibble: 5 × 13
#>   month     effort_estimate effort_se effort_se_between effort_se_within
#>   <fct>               <dbl>     <dbl>             <dbl>            <dbl>
#> 1 May                16882      2046.             2046.                0
#> 2 June               16878.     2523.             2523.                0
#> 3 July               17397.     1518.             1518.                0
#> 4 August             18735.     2029.             2029.                0
#> 5 September          11515       971.              971.                0
#> # ℹ 8 more variables: effort_ci_lower <dbl>, effort_ci_upper <dbl>,
#> #   effort_n <int>, catch_estimate <dbl>, catch_se <dbl>, catch_ci_lower <dbl>,
#> #   catch_ci_upper <dbl>, catch_n <int>
```

To write it out, use any writer for data frames, or
[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md)
with the format named:

``` r

write_schedule(report$table, "season_2024.csv")
write_schedule(report$table, "season_2024.xlsx", format = "xlsx")
```

[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md)
does not read the format from the file name, so an `.xlsx` name without
`format = "xlsx"` gets CSV text.

## Several years

Build one design per year, each with that year’s full calendar, and
report the years side by side. Years are separate surveys, so their
totals are independent and can be compared or added like strata.

``` r

year_effort <- lapply(split(all_years_calendar, all_years_calendar$year), function(cal) {
  cnt <- all_years_counts[all_years_counts$date %in% cal$date, ]
  creel_design(cal, date = date, strata = day_type) |>
    add_counts(cnt, count_col = anglers, period_length_col = fishing_day) |>
    estimate_effort(target = "period_total")
})
season_summary(year_effort)$table
```

## Summary

| Goal | Call |
|----|----|
| Effort on the sampled days | `estimate_effort(design)` |
| Season total | full calendar, then `estimate_effort(design, target = "period_total")` |
| Monthly totals that add to the season | `strata = c(month, day_type)`, then `by = month, target = "period_total"` |
| Catch or harvest totals | the same `by` and `target` on [`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md) / [`estimate_total_harvest()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_harvest.md) |
| A report table | `season_summary(list(...))$table` |

## References

- Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
  Methods and Their Applications in Fisheries Management*. American
  Fisheries Society Special Publication 25. Bethesda, Maryland.
