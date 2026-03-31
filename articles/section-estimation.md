# Spatially Stratified Estimation with Sections

## Introduction

A spatially stratified creel survey divides the lake into discrete
geographic sections — for example, North, Central, and South — each
managed as a separate reporting unit. Each section has its own observed
count data and its own set of angler interviews, so effort levels and
catch rates can differ materially between sections.

[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
is the right tool when the survey design *explicitly* stratifies by
section: when different field crews patrol different areas, when
section-level estimates are required in the final report, or when the
lake is large enough that assuming uniform effort across the full water
body would be misleading. If you are simply curious about spatial
patterns but did not design the survey with sections in mind, use the
standard
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
workflow without
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md).

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

design <- creel_design(example_sections_calendar, date = date, strata = day_type)
design <- add_sections(design, sections_df, section_col = section)
design <- add_counts(design, example_sections_counts)
design <- add_interviews(
  design, example_sections_interviews,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
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

------------------------------------------------------------------------

## Per-Section Effort Estimation

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
detects the registered sections and returns one row per section plus a
`.lake_total` row that aggregates across sections. The lake-total
standard error accounts for cross-section covariance (described in the
Variance Aggregation section below).

``` r
effort_est <- estimate_effort(design)
print(effort_est$estimates)
#> # A tibble: 4 × 10
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 39.4       NA           NA    758.      934.    36
#> # ℹ 2 more variables: prop_of_lake_total <dbl>, data_available <lgl>
```

Central has the highest fishing effort among the three sections, while
South has the lowest. The `prop_of_lake_total` column shows each
section’s share of total angler-hours for the survey period.

------------------------------------------------------------------------

## Per-Section Catch Rate

Catch rate (CPUE, fish per angler-hour) is a ratio estimator. Ratios are
not additive across sections: you cannot average North’s rate and
South’s rate to produce a valid lake-wide CPUE. For this reason,
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
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

> **Notice there is no `.lake_total` row.** Catch rate is a ratio
> estimator and ratios are not additive — South’s high catch rate cannot
> simply be averaged with North’s low rate to produce a valid lake-wide
> CPUE. To estimate the lake-wide catch rate, call
> [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
> on a design without section registration.

``` r
# Lake-wide catch rate: build an unsectioned design using the same data
design_nosections <- creel_design(example_sections_calendar, date = date, strata = day_type)
design_nosections <- add_counts(design_nosections, example_sections_counts)
design_nosections <- add_interviews(
  design_nosections, example_sections_interviews,
  catch = catch_total, effort = hours_fished,
  harvest = catch_kept, trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 27 interviews: 27 complete (100%), 0 incomplete (0%)
estimate_catch_rate(design_nosections)$estimates
#> ℹ Using complete trips for CPUE estimation
#>   (n=27, 100% of 27 interviews) [default]
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     1.77 0.118     1.54     2.00    27
```

------------------------------------------------------------------------

## Per-Section and Lake-Wide Total Catch

Total catch combines effort and catch rate within each section:
`TC_i = E_i × CPUE_i`. The lake-wide total is `sum(TC_i)` — **not**
`E_total × CPUE_pooled`. With `aggregate_sections = TRUE` (the default),
a `.lake_total` row is appended to the output.

``` r
catch_est <- estimate_total_catch(design, aggregate_sections = TRUE)
print(catch_est$estimates)
#> # A tibble: 4 × 8
#>   section     estimate    se ci_lower ci_upper     n prop_of_lake_total
#>   <chr>          <dbl> <dbl>    <dbl>    <dbl> <int>              <dbl>
#> 1 North           285.  23.1     240.     331.     9              0.228
#> 2 Central         711.  29.9     653.     770.     9              0.567
#> 3 South           257.  22.7     213.     302.     9              0.205
#> 4 .lake_total    1254.  44.1    1156.    1352.     3              1    
#> # ℹ 1 more variable: data_available <lgl>
```

South has a high catch rate but the lowest effort, which limits its
contribution to the lake total. Central has a moderate catch rate
combined with the highest effort, making it the largest contributor. The
`prop_of_lake_total` column shows each section’s percentage contribution
to the lake-wide total catch.

``` r
harvest_est <- estimate_total_harvest(design, aggregate_sections = TRUE)
print(harvest_est$estimates)
#> # A tibble: 4 × 8
#>   section     estimate    se ci_lower ci_upper     n prop_of_lake_total
#>   <chr>          <dbl> <dbl>    <dbl>    <dbl> <int>              <dbl>
#> 1 North           165.  15.8     134.     196.     9              0.204
#> 2 Central         466.  23.8     419.     512.     9              0.576
#> 3 South           178.  15.9     147.     210.     9              0.221
#> 4 .lake_total     809.  32.7     736.     882.     3              1    
#> # ℹ 1 more variable: data_available <lgl>
```

------------------------------------------------------------------------

## Variance Aggregation — Why `method = "correlated"` Is the Default

In a standard shared-calendar creel design, the field crew works the
entire lake on each survey day. Every section is counted and interviewed
on the same calendar days: if a day is sampled, all three sections are
observed; if a day is not sampled, none are.

Sharing survey days creates cross-section covariance in the sampling
errors. In practice this covariance tends to be negative: on high-effort
days all sections run high together, and on low-effort days they run low
together. The shared-calendar variance formula accounts for this
covariance and produces a narrower lake-total standard error than simply
adding the section standard errors in quadrature.

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
#> # A tibble: 4 × 10
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 39.4       NA           NA    758.      934.    36
#> # ℹ 2 more variables: prop_of_lake_total <dbl>, data_available <lgl>

# Alternative: Cochran 5.2 additivity (independent crews, non-overlapping calendars)
estimate_effort(design, method = "independent")$estimates
#> # A tibble: 4 × 10
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 24.4       NA           NA    792.      900.    36
#> # ℹ 2 more variables: prop_of_lake_total <dbl>, data_available <lgl>
```

------------------------------------------------------------------------

## Missing Section Warning

If a registered section has no count data on any survey day,
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
produces an NA row with `data_available = FALSE` and emits a warning.
This prevents silent omission of sections that should have been
observed.

``` r
north_central_counts <- example_sections_counts[
  example_sections_counts$section != "South",
]

design_missing <- creel_design(example_sections_calendar, date = date, strata = day_type)
design_missing <- add_sections(design_missing, sections_df, section_col = section)
design_missing <- suppressWarnings(add_counts(design_missing, north_central_counts))

estimate_effort(design_missing, missing_sections = "warn")$estimates
#> Warning: 1 missing section(s) in count data.
#> ! Section(s) not found: "South"
#> ℹ Inserting NA row(s) with data_available = FALSE.
#> # A tibble: 4 × 10
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269  12.3       12.3         0     242.     296.    12
#> 2 Central          472  19.0       19.0         0     430.     514.    12
#> 3 South             NA  NA         NA          NA      NA       NA      0
#> 4 .lake_total      741  31.1       NA          NA     672.     810.    24
#> # ℹ 2 more variables: prop_of_lake_total <dbl>, data_available <lgl>
```

To turn warnings into errors (for automated pipelines), use
`missing_sections = "error"`.
