# Example sampling frame for ice fishing creel survey

A minimal sampling frame for a Nebraska ice fishing creel survey at Lake
McConaughy. Contains 12 weekend sampling days across January-February
2024. Ice fishing surveys are a degenerate bus-route design where all
access points are sampled with certainty (`p_site = 1.0`), so only the
period sampling probability (`p_period`) is specified.

## Usage

``` r
example_ice_sampling_frame
```

## Format

A data frame with 12 rows and 3 columns:

- date:

  Survey date (Date class), January-February 2024

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`

- p_period:

  Numeric period sampling probability in `(0, 1]`. The probability that
  a given period is included in the sample.

## Source

Simulated data based on Nebraska ice fishing survey protocols.

## See also

[example_ice_interviews](https://chrischizinski.github.io/tidycreel/reference/example_ice_interviews.md)
for matching interview data,
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
for ice survey design construction

## Examples

``` r
data(example_ice_sampling_frame)
head(example_ice_sampling_frame)
#>         date day_type p_period
#> 1 2024-01-06  weekend     0.50
#> 2 2024-01-07  weekend     0.50
#> 3 2024-01-13  weekend     0.50
#> 4 2024-01-14  weekend     0.50
#> 5 2024-01-20  weekend     0.55
#> 6 2024-01-21  weekend     0.55

# Build an ice fishing design with scalar period sampling probability
design <- creel_design(
  example_ice_sampling_frame,
  date = date,
  strata = day_type,
  survey_type = "ice",
  effort_type = "time_on_ice",
  p_period = 0.5
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "ice"
#> Date column: date
#> Strata: day_type
#> Calendar: 12 days (2024-01-06 to 2024-02-11)
#> day_type: 1 level
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Ice Fishing Design ──
#> 
#> Effort type: time_on_ice
#> p_period (global): 0.5
```
