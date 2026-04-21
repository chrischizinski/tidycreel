# Unextrapolated Interview Summaries

## Introduction

Creel surveys produce two types of summary products: **unextrapolated
summaries** and **extrapolated estimates**. This vignette covers
unextrapolated summaries — raw tabulations of interview records that
describe the composition of interviewed parties without applying
survey-design weighting.

**When to use unextrapolated summaries:**

- Describing who was interviewed (angler type, method, species sought)
- Checking for refusals and participation rates
- Examining trip-length distributions
- Computing catch-while-sought and harvest-while-sought rates as quality
  indicators

**Important caveat:** All unextrapolated functions are
*interview-weighted*, not *pressure-weighted*. A day with many anglers
and few interviews has the same weight as a day with few anglers and
many interviews. For pressure-weighted, design-correct estimates, use
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
and related functions described in the “Interview-Based Catch
Estimation” vignette.

## Build the Design

Start by assembling a complete design using all v0.5.0 data layers:

``` r
library(tidycreel)

# Load example datasets
data(example_calendar)
data(example_counts)
data(example_interviews)
data(example_catch)
data(example_lengths)

# Step 1: Define the survey calendar and stratification
design <- creel_design(example_calendar, date = date, strata = day_type)

# Step 2: Attach instantaneous count observations
design <- add_counts(design, example_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

# Step 3: Attach interview records (all extended v0.5.0 fields)
design <- add_interviews(design, example_interviews,
  catch          = catch_total,
  effort         = hours_fished,
  harvest        = catch_kept,
  trip_status    = trip_status,
  trip_duration  = trip_duration,
  angler_type    = angler_type,
  angler_method  = angler_method,
  species_sought = species_sought,
  n_anglers      = n_anglers,
  refused        = refused
)

# Step 4: Attach species-level catch data
design <- add_catch(design, example_catch,
  catch_uid     = interview_id,
  interview_uid = interview_id,
  species       = species,
  count         = count,
  catch_type    = catch_type
)

# Step 5: Attach fish length data (individual harvest + binned release)
design <- add_lengths(design, example_lengths,
  length_uid     = interview_id,
  interview_uid  = interview_id,
  species        = species,
  length         = length,
  length_type    = length_type,
  count          = count,
  release_format = "binned"
)

print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: 14 observations
#> PSU column: date
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: 22 observations
#> Type: "access"
#> Catch: catch_total
#> Effort: hours_fished
#> Harvest: catch_kept
#> Trip status: 17 complete, 5 incomplete
#> Angler type: angler_type
#> Angler method: angler_method
#> Species sought: species_sought
#> Party size: n_anglers
#> Refused: refused
#> Survey: <survey.design2> (constructed)
#> Catch Data: 42 rows, 3 species
#> caught: 8, harvested: 17, released: 17
#> Length Data: 20 rows, 3 species, length: 155–512 mm
#> harvest: 14 individual
#> release: 6 binned
#> Sections: "none"
```

The [`print()`](https://rdrr.io/r/base/print.html) output shows all five
data layers: calendar, counts, interviews, catch, and lengths.

## Interview Participation

Use
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md)
to understand how many potential interviewees declined to participate.
High refusal rates can bias estimates if refusers differ systematically
from participants.

``` r
summarize_refusals(design)
#>   month participation  N percent
#> 1  June      accepted 22     100
```

All 22 interviews in `example_interviews` were accepted (no refusals).
In field surveys, a refusal rate above 20% warrants investigation.

## Interview Composition

Seven tabulation functions describe the composition of the interview
sample.

### Day Type

``` r
summarize_by_day_type(design)
#>   month day_type  N percent
#> 1  June  weekday 13    59.1
#> 2  June  weekend  9    40.9
```

### Angler Type

``` r
summarize_by_angler_type(design)
#>   month angler_type  N percent
#> 1  June        bank 13    59.1
#> 2  June        boat  9    40.9
```

### Fishing Method

``` r
summarize_by_method(design)
#>   month     method  N percent
#> 1  June artificial  7    31.8
#> 2  June       bait 10    45.5
#> 3  June        fly  5    22.7
```

### Species Sought

``` r
summarize_by_species_sought(design)
#>   month species  N percent
#> 1  June    bass  6    27.3
#> 2  June panfish  5    22.7
#> 3  June walleye 11    50.0
```

### Successful Parties

[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md)
counts parties that caught at least one fish of their target species (as
recorded in catch data), broken down by angler type and species sought.

``` r
summarize_successful_parties(design)
#>   angler_type species_sought N_total N_successful percent
#> 1        bank           bass       5            0     0.0
#> 2        bank        panfish       3            1    33.3
#> 3        bank        walleye       5            3    60.0
#> 4        boat           bass       1            1   100.0
#> 5        boat        panfish       2            0     0.0
#> 6        boat        walleye       6            1    16.7
```

### Trip Length Distribution

``` r
summarize_by_trip_length(design)
#>    trip_length_bin N percent
#> 1            [0,1) 2     9.1
#> 2            [1,2) 5    22.7
#> 3            [2,3) 8    36.4
#> 4            [3,4) 4    18.2
#> 5            [4,5) 3    13.6
#> 6            [5,6) 0     0.0
#> 7            [6,7) 0     0.0
#> 8            [7,8) 0     0.0
#> 9            [8,9) 0     0.0
#> 10          [9,10) 0     0.0
#> 11             10+ 0     0.0
```

The trip-length distribution is useful for detecting outliers and
understanding effort patterns.

## Catch-While-Sought (CWS) and Harvest-While-Sought (HWS) Rates

CWS and HWS rates measure the proportion of interviews where anglers
targeting a species actually caught (CWS) or kept (HWS) that species.
These are useful quality indicators and input parameters for population
models, but should **not** be treated as pressure-weighted catch rates
for management use — they reflect the interview sample composition, not
fishing pressure across the survey period.

### CWS Rates by Species Sought

``` r
summarize_cws_rates(design, by = species_sought)
#>   species_sought  N  mean_rate         se    ci_lower  ci_upper
#> 1           bass  6 0.05208333 0.05208333 -0.08180114 0.1859678
#> 2        panfish  5 0.23333333 0.23333333 -0.41450386 0.8811705
#> 3        walleye 11 0.46158009 0.23247889 -0.05641517 0.9795753
```

### CWS Rates Collapsed Across All Groupings

``` r
summarize_cws_rates(design, by = NULL)
#>    N mean_rate        se   ci_lower  ci_upper
#> 1 22 0.2980249 0.1298807 0.02792314 0.5681266
```

### HWS Rates

``` r
summarize_hws_rates(design, by = species_sought)
#>   species_sought  N mean_rate        se    ci_lower  ci_upper
#> 1           bass  6 0.0312500 0.0312500 -0.04908068 0.1115807
#> 2        panfish  5 0.1333333 0.1333333 -0.23685935 0.5035260
#> 3        walleye 11 0.3887987 0.1322997  0.09401668 0.6835807
```

**Interpretation guidance:** CWS and HWS rates \> 1.0 are possible when
anglers catch multiple fish of the target species in a single interview.
A CWS rate of 0.6 means 60% of interviews targeting that species
resulted in at least one catch.

## Length Frequency Distributions

Length data attached via
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)
can be summarized by catch type and species.

### Harvest Lengths

``` r
summarize_length_freq(design, type = "harvest", by = species, bin_width = 25)
#>   species length_bin N percent cumulative_percent
#> 1    bass  [225,250) 1    25.0               25.0
#> 2    bass  [250,275) 1    25.0               50.0
#> 3    bass  [275,300) 2    50.0              100.0
#> 4 panfish  [150,175) 2   100.0              100.0
#> 5 walleye  [375,400) 2    25.0               25.0
#> 6 walleye  [400,425) 3    37.5               62.5
#> 7 walleye  [475,500) 1    12.5               75.0
#> 8 walleye  [500,525) 2    25.0              100.0
```

### Release Lengths

Release lengths in `example_lengths` are stored in pre-binned format.
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md)
handles this automatically:

``` r
summarize_length_freq(design, type = "release", by = species)
#>   species length_bin N percent cumulative_percent
#> 1    bass  [275,276) 4    44.4               44.4
#> 2    bass  [325,326) 5    55.6              100.0
#> 3 panfish  [175,176) 6    66.7               66.7
#> 4 panfish  [225,226) 3    33.3              100.0
#> 5 walleye  [375,376) 2    40.0               40.0
#> 6 walleye  [425,426) 3    60.0              100.0
```

### All-Catch Lengths

``` r
summarize_length_freq(design, type = "catch", by = species, bin_width = 25)
#>    species length_bin N percent cumulative_percent
#> 1     bass  [225,250) 1     7.7                7.7
#> 2     bass  [250,275) 1     7.7               15.4
#> 3     bass  [275,300) 6    46.2               61.6
#> 4     bass  [325,350) 5    38.5              100.1
#> 5  panfish  [150,175) 2    18.2               18.2
#> 6  panfish  [175,200) 6    54.5               72.7
#> 7  panfish  [225,250) 3    27.3              100.0
#> 8  walleye  [375,400) 4    30.8               30.8
#> 9  walleye  [400,425) 3    23.1               53.9
#> 10 walleye  [425,450) 3    23.1               77.0
#> 11 walleye  [475,500) 1     7.7               84.7
#> 12 walleye  [500,525) 2    15.4              100.1
```

## Extrapolated Species-Level Estimates

For design-correct, pressure-weighted estimates broken down by species,
use the extrapolated estimators. These combine effort estimates (from
count data) with species-specific catch rates (from interview + catch
data) using the ratio-of-means estimator.

### Catch Per Unit Effort by Species

``` r
estimate_catch_rate(design, by = species)
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: ratio-of-means-cpue-species
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> 
#> # A tibble: 3 × 6
#>   species estimate     se ci_lower ci_upper     n
#>   <chr>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1 bass      0.0930 0.0494 -0.00386    0.190    17
#> 2 panfish   0      0       0          0        17
#> 3 walleye   0.307  0.118   0.0748     0.539    17
```

### Total Catch by Species

``` r
estimate_total_catch(design, by = species)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> Effort target: sampled_days
#> 
#> # A tibble: 3 × 6
#>   species estimate    se ci_lower ci_upper     n
#>   <chr>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 bass        23.7  10.9     2.40     45.0    22
#> 2 panfish     16.6  17.0   -16.8      49.9    22
#> 3 walleye     95.5  41.7    13.8     177.     22
```

### Total Harvest by Species

``` r
estimate_total_harvest(design, by = species)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Harvest (Effort × HPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> Effort target: sampled_days
#> 
#> # A tibble: 3 × 6
#>   species estimate    se ci_lower ci_upper     n
#>   <chr>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 bass        33.5  11.7    10.5      56.5    22
#> 2 panfish     24.3  11.8     1.17     47.4    22
#> 3 walleye    121.   26.6    68.6     173.     22
```

### Release Rate and Total Releases by Species

``` r
estimate_release_rate(design, by = species)
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Small sample size for CPUE estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Small sample size for CPUE estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: ratio-of-means-rpue
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> 
#> # A tibble: 3 × 6
#>   species estimate     se ci_lower ci_upper     n
#>   <chr>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1 bass      0.0949 0.0352  0.0259    0.164     22
#> 2 panfish   0.0395 0.0252 -0.00982   0.0889    22
#> 3 walleye   0.134  0.0340  0.0678    0.201     22
estimate_total_release(design, by = species)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: product-total-release
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> Effort target: sampled_days
#> 
#> # A tibble: 3 × 6
#>   species estimate    se ci_lower ci_upper     n
#>   <chr>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 bass        32.4 12.3      8.24     56.6    22
#> 2 panfish     14.5  8.02    -1.20     30.2    22
#> 3 walleye     56.3 15.8     25.3      87.3    22
```

For grouped estimates combining calendar strata with species, use
`by = c(day_type, species)`. See
[`vignette("interview-estimation")`](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.md)
for the complete extrapolated estimation workflow.

## Summary

| Function                                                                                                                 | Data required                        | Output                               |
|--------------------------------------------------------------------------------------------------------------------------|--------------------------------------|--------------------------------------|
| [`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md)                     | refused field                        | month × participation × N × %        |
| [`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md)               | strata                               | month × day_type × N × %             |
| [`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md)         | angler_type                          | month × angler_type × N × %          |
| [`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md)                   | angler_method                        | month × method × N × %               |
| [`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md)   | species_sought                       | month × species × N × %              |
| [`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md) | catch + angler_type + species_sought | angler_type × species × success rate |
| [`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md)         | trip_duration                        | bin × N × %                          |
| [`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md)                   | catch + species_sought               | CWS rate ± SE by grouping            |
| [`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md)                   | catch + species_sought               | HWS rate ± SE by grouping            |
| [`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md)               | lengths                              | bin × N × % × cumulative %           |
