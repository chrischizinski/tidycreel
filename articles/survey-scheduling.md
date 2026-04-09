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
```

### May 2024

| Sun   | Mon | Tue   | Wed | Thu | Fri   | Sat |
|-------|-----|-------|-----|-----|-------|-----|
|       |     |       | 01  | 02  | WEEKD | 04  |
| WEEKE | 06  | WEEKD | 08  | 09  | WEEKD | 11  |
| 12    | 13  | 14    | 15  | 16  | 17    | 18  |
| 19    | 20  | 21    | 22  | 23  | 24    | 25  |
| 26    | 27  | 28    | 29  | 30  | 31    |     |

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
```

### June 2024

| Sun | Mon | Tue | Wed | Thu | Fri | Sat |
|-----|-----|-----|-----|-----|-----|-----|
|     |     |     |     |     |     | 01  |
| WE  | 03  | 04  | 05  | 06  | 07  | WE  |
| WE  | 10  | 11  | 12  | 13  | 14  | 15  |
| 16  | 17  | 18  | 19  | 20  | 21  | 22  |
| 23  | 24  | 25  | 26  | 27  | 28  | 29  |
| 30  |     |     |     |     |     |     |

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

## Within-Day Count Time Scheduling

Counts are the primary effort estimator in creel surveys: the number of
anglers observed during each count window is used to estimate total
angler-hours. When those count windows fall in the day matters —
clustered or poorly spaced windows can introduce bias into effort
estimates. Pollock et al. (1994) describe three strategies for placing
count time windows within the survey day: random, systematic, and fixed.
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
implements all three.

### Random Strategy

With the random strategy, `n_windows` non-overlapping windows are drawn
uniformly at random from the available survey hours. `window_size` sets
the duration (minutes) of each window and `min_gap` enforces a minimum
separation (minutes) between consecutive windows to prevent back-to-back
counts.

``` r
library(tidycreel)
ct_random <- generate_count_times(
  start_time  = "06:00",
  end_time    = "14:00",
  strategy    = "random",
  n_windows   = 4,
  window_size = 30,
  min_gap     = 10,
  seed        = 42
)
ct_random
```

*(no date column to render calendar)*

`n_windows` is the total number of count windows to place in the day,
`window_size` is how long each window lasts in minutes, and `min_gap` is
the minimum idle time between the end of one window and the start of the
next.

### Systematic Strategy

The systematic strategy uses the Pollock et al. (1994) model: the day is
divided into `n_windows` equal-length strata and one window is placed at
a random start within the first stratum; subsequent windows begin at
t₁+k, t₁+2k, and so on, where k is the stratum length. This ensures even
spacing across the day. Systematic sampling is preferred by many
agencies (Colorado CPW 2012) because it avoids the clustered count times
that can occur by chance under random placement.

``` r
ct_systematic <- generate_count_times(
  start_time  = "06:00",
  end_time    = "14:00",
  strategy    = "systematic",
  n_windows   = 4,
  window_size = 30,
  min_gap     = 10,
  seed        = 42
)
ct_systematic
```

*(no date column to render calendar)*

### Fixed Strategy

Use the fixed strategy when count time windows are defined by
regulation, permit conditions, or a prior-season protocol that must be
replicated exactly. Supply a `data.frame` with `start_time` and
`end_time` columns and
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
wraps them in a `creel_schedule` object without any random placement.

``` r
fw <- data.frame(
  start_time = c("07:00", "09:30", "12:00"),
  end_time = c("07:30", "10:00", "12:30"),
  stringsAsFactors = FALSE
)
ct_fixed <- generate_count_times(strategy = "fixed", fixed_windows = fw)
ct_fixed
```

*(no date column to render calendar)*

### Exporting Count Time Schedules

[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
returns a `creel_schedule` object, the same class returned by
[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md).
It therefore passes directly to
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
for field printing without any conversion step.

``` r
write_schedule(ct_systematic, "count_times_2024.csv")
```

## Combining the Daily Schedule with Count Time Windows

[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)
and
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)
each return a separate `creel_schedule`. Before field dispatch,
biologists need a single table — one row per (date x period x count
window) — that tells each crew exactly when to count.
[`attach_count_times()`](https://chrischizinski.github.io/tidycreel/reference/attach_count_times.md)
performs the cross-join in one step.

``` r
sched <- generate_schedule(
  start_date = "2024-06-01", end_date = "2024-06-07",
  n_periods = 2,
  sampling_rate = c(weekday = 0.5, weekend = 0.8),
  seed = 42
)
ct <- generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "systematic", n_windows = 3,
  window_size = 30, min_gap = 10,
  seed = 42
)
field_schedule <- attach_count_times(sched, ct)
field_schedule
```

### June 2024

| Sun   | Mon   | Tue | Wed | Thu | Fri   | Sat   |
|-------|-------|-----|-----|-----|-------|-------|
|       |       |     |     |     |       | WEEKE |
| WEEKE | WEEKD | 04  | 05  | 06  | WEEKD | 08    |
| 09    | 10    | 11  | 12  | 13  | 14    | 15    |
| 16    | 17    | 18  | 19  | 20  | 21    | 22    |
| 23    | 24    | 25  | 26  | 27  | 28    | 29    |
| 30    |       |     |     |     |       |       |

The result has `nrow(sched) * nrow(ct)` rows — every sampled day-period
combination appears once per count window. Pass `field_schedule`
directly to
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
to produce a printable field dispatch sheet.

## Validating the Design Before the Season

After building a schedule,
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md)
checks whether the proposed sampling intensity is sufficient to meet a
target coefficient of variation (CV) — catching under-sampling problems
before the season starts rather than discovering them in the post-season
analysis. It uses the same pilot mean and variance inputs as
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)
and compares the proposed day counts against the minimum required sample
size per stratum.

``` r
report <- validate_design(
  N_h        = c(weekday = 132, weekend = 52),
  ybar_h     = c(weekday = 280, weekend = 550),
  s2_h       = c(weekday = 14400, weekend = 32400),
  n_proposed = c(weekday = 40L, weekend = 26L),
  cv_target  = 0.15
)
report
#> 
#> ── Design Validation Report ────────────────────────────────────────────────────
#> Type: effort
#> ✔ All strata PASSED
#> 
#> ✔ weekday: n=40 >= 6 required (CV 0.006 vs target 0.15)
#> ✔ weekend: n=26 >= 2 required (CV 0.009 vs target 0.15)
```

`report$results` shows the per-stratum status (pass / warn / fail), the
proposed sample size, the required sample size, and the achieved CV at
the proposed intensity. `report$passed` is `TRUE` only when all strata
pass — use this as a go/no-go gate before printing field schedules.

``` r
report$results
#> # A tibble: 2 × 7
#>   stratum status n_proposed n_required cv_actual cv_target message              
#>   <chr>   <chr>       <int>      <int>     <dbl>     <dbl> <chr>                
#> 1 weekday pass           40          6    0.0059      0.15 Proposed n meets or …
#> 2 weekend pass           26          2    0.0089      0.15 Proposed n meets or …
```

## Checking Data Completeness After the Season

[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md)
runs post-season on a `creel_design` with survey data attached, flagging
missing sampling days and strata with too few interviews to produce
reliable estimates. It is the first diagnostic step before running
estimators — resolving completeness issues early avoids propagating gaps
into effort or CPUE estimates.

``` r
data(example_calendar)
data(example_counts)
data(example_interviews)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
design <- add_interviews(design, example_interviews,
  catch        = catch_total,
  effort       = hours_fished,
  trip_status  = trip_status
)
comp <- check_completeness(design)
comp
#> 
#> ── Completeness Report ─────────────────────────────────────────────────────────
#> Survey type: instantaneous | n_min threshold: 10
#> ✖ Completeness issues found
#> 
#> 
#> ── Missing Days ──
#> 
#> ✔ No missing sampling days
#> 
#> ── Low-n Strata (threshold: 10) ──
#> 
#> ! 1 stratum/strata below n_min=10
#> 
#> ── Refusal Rates ──
#> 
#> (not recorded or not applicable)
```

`comp$passed` returns `TRUE` if no issues were found. When `FALSE`,
`comp$missing_days` identifies dates that appear in the schedule but
have no count data, and `comp$low_n_strata` identifies strata where the
interview count is below the minimum threshold (`n_min`, default 10).

## Assembling the Season Summary

[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)
accepts a named list of `creel_estimates` objects — the outputs of
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
and related functions — and joins them into a single wide tibble for
reporting or export. It performs no re-estimation; it is purely an
assembly step that makes it easy to view all key metrics side by side.

``` r
# Run estimators first (see the tidycreel workflow vignette)
effort <- estimate_effort(design)
cpue <- estimate_catch_rate(design)

# Assemble the season summary
summary_tbl <- season_summary(list(effort = effort, cpue = cpue))
summary_tbl$table
```

The full estimation workflow — building the design, attaching counts and
interviews, and running the estimators — is covered in the main
tidycreel vignette.
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)
is the final step that wraps pre-computed results for export or
reporting.

``` r
write_schedule(summary_tbl$table, "season_2024_summary.xlsx")
```

[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
accepts any data frame or tibble, so the season summary table exports to
CSV or xlsx with a single call.

## References

- Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
  Scheduling counts in the instantaneous and progressive count methods
  for estimating sportfishing effort. *North American Journal of
  Fisheries Management*, 13, 723–736.

- Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
  Methods and Their Applications in Fisheries Management*. American
  Fisheries Society, Bethesda, MD.
