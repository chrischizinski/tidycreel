# Example effort counts for spatially stratified creel survey

Daily effort observations for a 3-section lake (North, Central, South)
covering 12 survey dates. Each section has one row per date (36 rows
total). Effort varies materially by section: Central has the highest
angler traffic, South the lowest. Use with
[`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md)
and
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).

## Usage

``` r
example_sections_counts
```

## Format

A data frame with 36 rows and 4 columns:

- date:

  Survey date (Date class), the sampled days of
  [example_sections_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md)

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`

- section:

  Section identifier: `"North"`, `"Central"`, or `"South"`

- effort_hours:

  Numeric angler-hours observed on the section for that date

## Source

Simulated data for package examples

## Details

As with
[example_counts](https://chrischizinski.com/tidycreel/dev/reference/example_counts.md),
the effort column holds angler-hours rather than raw angler counts; see
that dataset for why the distinction matters to
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md).
Pass it through
[`prep_counts_daily_effort()`](https://chrischizinski.com/tidycreel/dev/reference/prep_counts_daily_effort.md)
with `section = section`, as in the example, so it is attached as
effort.

## See also

[example_sections_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[example_sections_interviews](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
[`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md),
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.com/tidycreel/dev/reference/creel_counts_toy.md),
[`creel_interviews_toy`](https://chrischizinski.com/tidycreel/dev/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_aerial_counts.md),
[`example_aerial_glmm_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_aerial_glmm_counts.md),
[`example_aerial_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_aerial_interviews.md),
[`example_ages`](https://chrischizinski.com/tidycreel/dev/reference/example_ages.md),
[`example_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_calendar.md),
[`example_camera_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_camera_counts.md),
[`example_camera_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.com/tidycreel/dev/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.com/tidycreel/dev/reference/example_catch.md),
[`example_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_counts.md),
[`example_ice_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.com/tidycreel/dev/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.com/tidycreel/dev/reference/example_lengths.md),
[`example_roving_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_roving_interviews.md),
[`example_season_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
[`example_season_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md),
[`example_season_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md)

## Examples

``` r
data(example_sections_calendar)
data(example_sections_counts)

sections_df <- data.frame(
  section = c("North", "Central", "South"),
  stringsAsFactors = FALSE
)
design <- creel_design(example_sections_calendar, date = date, strata = day_type)
design <- add_sections(design, sections_df, section_col = section)
# effort_hours is already effort per section-day: mark it as such
counts <- prep_counts_daily_effort(example_sections_counts,
  date = date, strata = day_type, daily_effort = effort_hours,
  section = section
)
design <- add_counts(design, counts)
estimate_effort(design)
#> ℹ Expanding 12 sampled units carrying 36 count rows between them.
#> ℹ Rows sharing a date are summed into it first: the expansion factor is days
#>   over days, not rows over rows.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: total-sections
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> 
#> # A tibble: 4 × 12
#>   section   estimate    se se_between se_within ci_lower ci_upper     n se_basis
#>   <chr>        <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>   
#> 1 North         414.  21.6       21.6         0     365.     462.    12 between…
#> 2 Central       731   33.3       33.3         0     657.     805.    12 between…
#> 3 South         166.  16.1       16.1         0     130.     201.    12 between…
#> 4 .lake_to…    1310.  69.3       69.3         0    1156.    1465.    36 between…
#> # ℹ 3 more variables: prop_of_lake_total <dbl>, se_prop_of_lake_total <dbl>,
#> #   data_available <lgl>
```
