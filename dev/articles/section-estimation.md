# Spatially Stratified Estimation with Sections

## Introduction

A spatially stratified creel survey divides the lake into discrete
geographic sections — for example, North, Central, and South — each
managed as a separate reporting unit. Each section has its own observed
count data and its own set of angler interviews, so effort levels and
catch rates can differ materially between sections.

[`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md)
is the right tool when the survey design *explicitly* stratifies by
section: when different field crews patrol different areas, when
section-level estimates are required in the final report, or when the
lake is large enough that assuming uniform effort across the full water
body would be misleading. If you are simply curious about spatial
patterns but did not design the survey with sections in mind, use the
standard
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
workflow without
[`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md).

------------------------------------------------------------------------

## Building a Sectioned Design

``` r

library(tidycreel)

data(example_sections_calendar)
data(example_sections_counts)
data(example_sections_interviews)

sections_df <- data.frame(
  section = c("North", "Central", "South"),
  stringsAsFactors = FALSE
)

# effort_hours is already angler-hours for each section and day, not an
# instantaneous count, so it goes in through prep_counts_daily_effort()
section_effort <- prep_counts_daily_effort(example_sections_counts,
  date = date, strata = day_type, daily_effort = effort_hours,
  section = section
)

design <- creel_design(example_sections_calendar, date = date, strata = day_type)
design <- add_sections(design, sections_df, section_col = section)
design <- add_counts(design, section_effort)
design <- add_interviews(
  design, example_sections_interviews,
  catch = catch_total,
  effort = hours_fished,
  n_anglers = 1,
  harvest = catch_kept,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ Added 27 interviews: 27 complete (100%), 0 incomplete (0%)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 12 days (2024-06-03 to 2024-06-21)
#> day_type: 2 levels
#> Counts: 36 observations
#> PSU column: date
#> Count column: daily_effort
#> Party-size term: not carried
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: 27 observations
#> Type: "access"
#> Catch: catch_total
#> Effort: hours_fished
#> Harvest: catch_kept
#> Trip status: 27 complete, 0 incomplete
#> Survey: <survey.design2> (constructed)
#> Sections: 3 registered
#> North
#> Central
#> South
```

The design now shows three registered sections (North, Central, South).
All downstream estimators automatically detect sections and return
per-section output.

Two choices in that chunk matter for units:

- `example_sections_counts` already holds angler-hours per section-day,
  so it goes through
  [`prep_counts_daily_effort()`](https://chrischizinski.com/tidycreel/dev/reference/prep_counts_daily_effort.md).
  Given to
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  directly it would be read as instantaneous counts, with a warning that
  no period length was supplied. The effort printed below is in
  angler-hours as the data say, but the reported unit is `NA`: the
  package did not see how those angler-hours were made
  ([`vignette("unit-rules")`](https://chrischizinski.com/tidycreel/dev/articles/unit-rules.md)).
- The interview data record no party size. This page assumes one angler
  per interview with `n_anglers = 1`, so the catch rate is per
  angler-hour, the same unit as the effort it multiplies. With your own
  data, pass the party-size column instead.

------------------------------------------------------------------------

## Per-Section Effort Estimation

[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
detects the registered sections and returns one row per section plus a
`.lake_total` row that aggregates across sections. The lake-total
standard error accounts for cross-section covariance (described in the
Variance Aggregation section below).

``` r

effort_est <- estimate_effort(design)
print(effort_est$estimates)
#> # A tibble: 4 × 11
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 39.4       39.4          0    758.      934.    36
#> # ℹ 3 more variables: prop_of_lake_total <dbl>, se_prop_of_lake_total <dbl>,
#> #   data_available <lgl>
```

Central has the highest fishing effort among the three sections, while
South has the lowest. The `prop_of_lake_total` column shows each
section’s share of total angler-hours for the survey period, and
`se_prop_of_lake_total` its standard error, so shares can be compared
with the same regard for precision as the totals themselves. Both come
from one
[`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html)
call, which accounts for the correlation between a section’s total and
the lake-wide total that contains it. On the `.lake_total` row the share
is exactly 1 with a standard error of 0 — that row’s share of itself is
structural, not estimated.

------------------------------------------------------------------------

## Per-Section Catch Rate

Catch rate (CPUE, fish per angler-hour) is a ratio estimator. Ratios are
not additive across sections: you cannot average North’s rate and
South’s rate to produce a valid lake-wide CPUE. For this reason,
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
on a sectioned design returns one row per section with **no
`.lake_total` row**.

``` r

cpue_est <- estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=27, 100% of 27 interviews) [default]
print(cpue_est$estimates)
#> # A tibble: 3 × 7
#>   section estimate     se ci_lower ci_upper     n data_available
#>   <chr>      <dbl>  <dbl>    <dbl>    <dbl> <int> <lgl>         
#> 1 North       1.06 0.0710    0.922     1.20     9 TRUE          
#> 2 Central     1.51 0.0179    1.47      1.54     9 TRUE          
#> 3 South       2.45 0.0287    2.39      2.51     9 TRUE
```

**Notice there is no `.lake_total` row.** Catch rate is a ratio
estimator and ratios are not additive — South’s high catch rate cannot
simply be averaged with North’s low rate to produce a valid lake-wide
CPUE. To estimate the lake-wide catch rate, call
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
on a design without section registration.

``` r

# Lake-wide catch rate: an unsectioned design with the same interviews. A rate
# needs only interviews, so no counts are attached.
design_nosections <- creel_design(example_sections_calendar, date = date, strata = day_type)
design_nosections <- add_interviews(
  design_nosections, example_sections_interviews,
  catch = catch_total, effort = hours_fished, n_anglers = 1,
  harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ Added 27 interviews: 27 complete (100%), 0 incomplete (0%)
estimate_catch_rate(design_nosections)$estimates
#> ℹ Using complete trips for CPUE estimation
#>   (n=27, 100% of 27 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 27. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     1.77 0.118     1.54     2.00    27
```

This call warns that 27 interviews is a small sample for a ratio
estimator. It is: the example dataset is small so the page runs quickly.
The warning is about precision, and the standard error already reflects
it.

------------------------------------------------------------------------

## Per-Section and Lake-Wide Total Catch

Total catch combines effort and catch rate within each section:
`TC_i = E_i × CPUE_i`. The lake-wide total is `sum(TC_i)` — **not**
`E_total × CPUE_pooled`. With `aggregate_sections = TRUE` (the default),
a `.lake_total` row is appended to the output.

``` r

catch_est <- estimate_total_catch(design, aggregate_sections = TRUE)
#> Warning: 2 rate cells in "estimate_total_catch" rests on fewer than 10 trips.
#> • section=North, day_type=weekday: n=6
#> • section=North, day_type=weekend: n=3
#> ℹ The total multiplies each cell's effort by a rate built from that cell's
#>   trips alone; a ratio from so few trips is unstable, and the rate functions
#>   refuse a group this small.
#> ℹ Combine cells or collect more interviews. Totals warn here rather than refuse
#>   (GH #417).
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
print(catch_est$estimates)
#> # A tibble: 4 × 9
#>   section     estimate    se ci_lower ci_upper     n prop_of_lake_total
#>   <chr>          <dbl> <dbl>    <dbl>    <dbl> <int>              <dbl>
#> 1 North           285.  20.3     237.     333.     9              0.226
#> 2 Central         717.  30.1     646.     788.     9              0.569
#> 3 South           259.  22.8     205.     313.     9              0.205
#> 4 .lake_total    1261.  64.8    1126.    1396.     3              1    
#> # ℹ 2 more variables: se_prop_of_lake_total <dbl>, data_available <lgl>
```

The call warns that two rate cells rest on fewer than 10 trips. A
sectioned total builds a rate for each section within each day type, and
nine interviews per section split across two day types leave some cells
thin. With real data, collect more interviews or combine cells; here it
is a property of the small example.

South has a high catch rate but the lowest effort, which limits its
contribution to the lake total. Central has a moderate catch rate
combined with the highest effort, making it the largest contributor. The
`prop_of_lake_total` column shows each section’s share of the lake-wide
total catch, and `se_prop_of_lake_total` its standard error, so the
shares can be compared against their uncertainty rather than read as
exact. The error is derived from the same section variances the
`.lake_total` row’s own standard error is built from; the `.lake_total`
row reports `0`, because its share of itself is 1 by construction rather
than estimated.

``` r

harvest_est <- estimate_total_harvest(design, aggregate_sections = TRUE)
print(harvest_est$estimates)
#> # A tibble: 4 × 9
#>   section     estimate    se ci_lower ci_upper     n prop_of_lake_total
#>   <chr>          <dbl> <dbl>    <dbl>    <dbl> <int>              <dbl>
#> 1 North           166.  13.5     134.     198.     9              0.203
#> 2 Central         472.  23.3     416.     527.     9              0.576
#> 3 South           181.  15.9     143.     218.     9              0.221
#> 4 .lake_total     818.  44.4     726.     910.     3              1    
#> # ℹ 2 more variables: se_prop_of_lake_total <dbl>, data_available <lgl>
```

------------------------------------------------------------------------

## Variance Aggregation — Why `method = "correlated"` Is the Default

In a standard shared-calendar creel design, the field crew works the
entire lake on each survey day. Every section is counted and interviewed
on the same calendar days: if a day is sampled, all three sections are
observed; if a day is not sampled, none are.

Sharing survey days creates covariance between the sections’ sampling
errors. It is usually positive: a busy day is busy in every section, and
a quiet day quiet in all of them, so the section totals’ errors move
together. Positive covariance makes the lake-total standard error
**wider** than adding the section standard errors in quadrature, which
assumes they move independently. The `"correlated"` method includes the
covariance terms; `"independent"` leaves them out.

`method = "independent"` is appropriate only when sections are surveyed
by separate, uncoordinated crews — for example, when the South section
is run by Crew A on different days from the North section (Crew B). In
that case the sections have truly independent sampling errors and
Cochran (1977, §5.2) additivity applies: `SE_total = sqrt(sum(SE_h^2))`.

**Rule of thumb:** If your crew drives the entire lake on each survey
day, use the default `method = "correlated"`. If different sections have
separate, non-overlapping calendars, use `method = "independent"`.

``` r

# Default: accounts for cross-section covariance (shared-calendar designs)
estimate_effort(design, method = "correlated")$estimates
#> # A tibble: 4 × 11
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 39.4       39.4          0    758.      934.    36
#> # ℹ 3 more variables: prop_of_lake_total <dbl>, se_prop_of_lake_total <dbl>,
#> #   data_available <lgl>

# Alternative: Cochran 5.2 additivity (independent crews, non-overlapping calendars)
estimate_effort(design, method = "independent")$estimates
#> # A tibble: 4 × 11
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 24.4       24.4          0    792.      900.    36
#> # ℹ 3 more variables: prop_of_lake_total <dbl>, se_prop_of_lake_total <dbl>,
#> #   data_available <lgl>
```

The section rows are identical; only the `.lake_total` standard error
moves. On these shared days it is about 39 angler-hours with the
covariance and about 24 without it, so treating shared-calendar sections
as independent would understate the lake-total uncertainty by roughly a
third.

------------------------------------------------------------------------

## Missing Section Warning

If a registered section has no count data on any survey day,
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
produces an NA row with `data_available = FALSE` and emits a warning.
This prevents silent omission of sections that should have been
observed.

``` r

north_central_counts <- example_sections_counts[
  example_sections_counts$section != "South",
]

design_missing <- creel_design(example_sections_calendar, date = date, strata = day_type)
design_missing <- add_sections(design_missing, sections_df, section_col = section)
design_missing <- add_counts(
  design_missing,
  prep_counts_daily_effort(north_central_counts,
    date = date, strata = day_type, daily_effort = effort_hours,
    section = section
  )
)

estimate_effort(design_missing, missing_sections = "warn")$estimates
#> Warning: 1 missing section(s) in count data.
#> ! Section(s) not found: "South"
#> ℹ Inserting NA row(s) with data_available = FALSE.
#> # A tibble: 4 × 11
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269  12.3       12.3         0     242.     296.    12
#> 2 Central          472  19.0       19.0         0     430.     514.    12
#> 3 South             NA  NA         NA          NA      NA       NA      0
#> 4 .lake_total      741  31.1       31.1         0     672.     810.    24
#> # ℹ 3 more variables: prop_of_lake_total <dbl>, se_prop_of_lake_total <dbl>,
#> #   data_available <lgl>
```

To turn warnings into errors (for automated pipelines), use
`missing_sections = "error"`.
