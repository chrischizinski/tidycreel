# Survey Scheduling: Count and Interview Periods

## Overview

A well-structured sampling schedule ensures that creel survey estimates
of effort, catch, and CPUE are unbiased and representative of the full
survey season.
[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)
builds a stratified random sampling calendar from season boundaries and
a target sampling intensity — producing the count-period framework that
drives the tidycreel estimation pipeline.

## The Count Period Framework

Every tidycreel design rests on a calendar of **count periods** — the
discrete time slots during which field crews collect data. A count
period is defined by:

- **Date**: the survey date
- **Period**: the time-of-day window (e.g., “Morning”, “Afternoon”)
- **Stratum**: the day type (weekday vs. weekend)

Interviews and angler counts are both collected during count periods.
The schedule you generate defines exactly which days and periods will be
sampled.

## Building a Basic Schedule

The minimal inputs are season boundaries, the number of periods per day,
and sampling intensity. The example below builds a schedule for a
May–September creel season with morning and afternoon count periods,
sampling 30% of weekdays and 50% of weekends.

``` r
library(tidycreel)

sched <- generate_schedule(
  start_date    = "2024-05-01",
  end_date      = "2024-09-30",
  n_periods     = 2,
  period_labels = c("Morning", "Afternoon"),
  sampling_rate = c(weekday = 0.30, weekend = 0.50),
  seed          = 42
)

head(sched, 8)
#>         date day_type period_id
#> 1 2024-05-03  weekday   Morning
#> 2 2024-05-03  weekday Afternoon
#> 3 2024-05-05  weekend   Morning
#> 4 2024-05-05  weekend Afternoon
#> 5 2024-05-07  weekday   Morning
#> 6 2024-05-07  weekday Afternoon
#> 7 2024-05-10  weekday   Morning
#> 8 2024-05-10  weekday Afternoon
```

The result is a `creel_schedule` object with `date`, `day_type`, and
`period_id` columns. Period labels replace integer IDs with
human-readable names.

``` r
# Counts of scheduled days by stratum
table(sched$day_type)
#> 
#> weekday weekend 
#>      66      44
```

## Visualising Sampled vs. Unsampled Days

Pass `include_all = TRUE` to return every day of the season with a
`sampled` indicator. This is useful for checking seasonal coverage and
communicating the design to stakeholders.

``` r
sched_full <- generate_schedule(
  start_date    = "2024-05-01",
  end_date      = "2024-09-30",
  n_periods     = 1,
  sampling_rate = c(weekday = 0.30, weekend = 0.50),
  include_all   = TRUE,
  seed          = 42
)

# Sampled proportion by stratum
table(sched_full$day_type, sched_full$sampled)
#>          
#>           FALSE TRUE
#>   weekday    76   33
#>   weekend    22   22
```

The sampled days are drawn by stratified random sampling within each
stratum, so weekday and weekend sampling fractions match the requested
rates.

## Three-Period Schedules

Some surveys divide the day into three periods — morning, midday, and
evening — to capture temporal patterns in angler activity (e.g., a
morning and evening peak with low midday use).

``` r
sched3 <- generate_schedule(
  start_date    = "2024-06-01",
  end_date      = "2024-08-31",
  n_periods     = 3,
  period_labels = c("Morning", "Midday", "Evening"),
  sampling_rate = c(weekday = 0.40, weekend = 0.60),
  seed          = 101
)

head(sched3, 9)
#>         date day_type period_id
#> 1 2024-06-02  weekend   Morning
#> 2 2024-06-02  weekend    Midday
#> 3 2024-06-02  weekend   Evening
#> 4 2024-06-08  weekend   Morning
#> 5 2024-06-08  weekend    Midday
#> 6 2024-06-08  weekend   Evening
#> 7 2024-06-09  weekend   Morning
#> 8 2024-06-09  weekend    Midday
#> 9 2024-06-09  weekend   Evening
```

## Reproducibility with `seed`

The `seed` argument ensures that the same calendar is produced every
time. This is important when the schedule is pre-printed for field use
and must match what the estimators will use.

``` r
sched_a <- generate_schedule("2024-06-01", "2024-06-30",
  n_periods = 1,
  sampling_rate = 0.4, seed = 99
)
sched_b <- generate_schedule("2024-06-01", "2024-06-30",
  n_periods = 1,
  sampling_rate = 0.4, seed = 99
)

identical(sched_a, sched_b)
#> [1] TRUE
```

## Saving and Sharing the Schedule

[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
exports to CSV (for any spreadsheet application) or xlsx (for direct
field printing).
[`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md)
reloads the file with correct column types, so the schedule round-trips
without type coercion issues.

``` r
# Save for field crews
write_schedule(sched, "count_schedule_2024.csv")
write_schedule(sched, "count_schedule_2024.xlsx")

# Reload — column types are preserved automatically
sched_reload <- read_schedule("count_schedule_2024.csv")
identical(sched, sched_reload)
```

## Linking the Schedule to a Design

Pass the schedule directly to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).
The schedule’s stratum structure informs the survey weights used by all
downstream estimators.

``` r
design <- creel_design(sched, date = date, strata = day_type)
design
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 110 days (2024-05-03 to 2024-09-30)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```

## Count Period Scheduling vs. Interview Scheduling

In standard access-point creel surveys, **interviews happen during count
periods** — the same field crew that counts anglers also approaches them
for interviews. The count schedule therefore governs both collection
activities.

There is no separate “interview schedule.” The set of available
interviews is the set of interviews collected on sampled count-period
days.

## Bus-Route Scheduling

For bus-route designs,
[`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md)
converts a count schedule and a site-level sampling frame into a
complete bus-route sampling frame with inclusion probabilities. Each
site’s probability of being visited in a given period is:

$$\pi_{i} = p_{site} \times p_{period}\quad\text{where}\quad p_{period} = \frac{\text{crew}}{n_{circuits}}$$

``` r
# Site-level selection probabilities (must sum to 1.0)
site_frame <- data.frame(
  site_id = c("North Bay", "South Cove", "Dock Area", "Main Channel"),
  p_site  = c(0.35, 0.25, 0.25, 0.15)
)

# Build bus-route sampling frame using the count schedule
bus_frame <- generate_bus_schedule(
  schedule       = sched,
  sampling_frame = site_frame,
  site           = site_id,
  p_site         = p_site,
  crew           = 1
)

bus_frame
#> # A tibble: 4 × 4
#>   site_id      p_site p_period inclusion_prob
#>   <chr>         <dbl>    <dbl>          <dbl>
#> 1 North Bay      0.35        1           0.35
#> 2 South Cove     0.25        1           0.25
#> 3 Dock Area      0.25        1           0.25
#> 4 Main Channel   0.15        1           0.15
```

The `inclusion_prob` column is the per-site overall inclusion
probability across the season. This frame passes directly to
`creel_design(survey_type = "bus_route", ...)`.

## Sampling Rate Guidance

The right sampling intensity depends on the target precision for the
survey. As a starting point:

| Survey length         | Typical weekday rate | Typical weekend rate |
|-----------------------|----------------------|----------------------|
| Short (\< 8 weeks)    | 0.40–0.60            | 0.60–0.80            |
| Standard (8–20 weeks) | 0.25–0.40            | 0.40–0.60            |
| Long (\> 20 weeks)    | 0.15–0.25            | 0.25–0.40            |

Higher rates on weekends reflect greater angler activity and higher
stratum variance. Use
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
or
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
to select rates based on a CV target rather than rule of thumb.

``` r
# Effort sample size to achieve CV ≤ 0.15
# N_h: total days per stratum in a 184-day season
# ybar_h: pilot mean daily effort (angler-hours) per stratum
# s2_h: pilot variance of daily effort per stratum
creel_n_effort(
  cv_target = 0.15,
  N_h = c(weekday = 132, weekend = 52),
  ybar_h = c(weekday = 280, weekend = 550),
  s2_h = c(weekday = 14400, weekend = 32400)
)
#> weekday weekend   total 
#>       6       2       7
```

## References

- Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
  Scheduling counts in the instantaneous and progressive count methods
  for estimating sportfishing effort. *North American Journal of
  Fisheries Management*, 13, 723–736.

- Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
  Methods and Their Applications in Fisheries Management*. American
  Fisheries Society, Bethesda, MD.
