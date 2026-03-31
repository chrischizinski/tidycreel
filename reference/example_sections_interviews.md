# Example interview data for spatially stratified creel survey

Angler interview data for a 3-section lake (North, Central, South) with
9 interviews per section (27 total). Catch rates differ materially
across sections: South has approximately 2.5x the catch rate of North,
making this dataset suitable for demonstrating spatially stratified
estimation. The `catch_kept` column enables
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
in addition to
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
and
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md).

## Usage

``` r
example_sections_interviews
```

## Format

A data frame with 27 rows and 9 columns:

- date:

  Interview date (Date class), matching
  [example_sections_calendar](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md)

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`

- section:

  Section identifier: `"North"`, `"Central"`, or `"South"`

- catch_total:

  Integer total fish caught per interview

- catch_kept:

  Integer fish harvested (kept); always `<= catch_total`

- hours_fished:

  Numeric fishing effort in hours

- trip_status:

  Character trip completion status; `"complete"` for all 27 interviews

- trip_duration:

  Numeric trip duration in hours

- interview_id:

  Integer interview identifier (1 to 27)

## Source

Simulated data for package examples

## See also

[example_sections_calendar](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[example_sections_counts](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)

## Examples

``` r
data(example_sections_calendar)
data(example_sections_counts)
data(example_sections_interviews)

sections_df <- data.frame(
  section = c("North", "Central", "South"),
  stringsAsFactors = FALSE
)
design <- creel_design(example_sections_calendar, date = date, strata = day_type)
design <- add_sections(design, sections_df, section_col = section)
design <- suppressWarnings(add_counts(design, example_sections_counts))
design <- suppressWarnings(add_interviews(design, example_sections_interviews,
  catch = catch_total, effort = hours_fished,
  harvest = catch_kept,
  trip_status = trip_status, trip_duration = trip_duration
))
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 27 interviews: 27 complete (100%), 0 incomplete (0%)
estimate_total_catch(design, aggregate_sections = TRUE)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: product-total-catch-sections
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: section
#> 
#> # A tibble: 4 × 8
#>   section     estimate    se ci_lower ci_upper     n prop_of_lake_total
#>   <chr>          <dbl> <dbl>    <dbl>    <dbl> <int>              <dbl>
#> 1 North           285.  23.1     240.     331.     9              0.228
#> 2 Central         711.  29.9     653.     770.     9              0.567
#> 3 South           257.  22.7     213.     302.     9              0.205
#> 4 .lake_total    1254.  44.1    1156.    1352.     3              1    
#> # ℹ 1 more variable: data_available <lgl>
```
