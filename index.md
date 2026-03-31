# tidycreel

![tidycreel hex
sticker](https://raw.githubusercontent.com/chrischizinski/tidycreel/main/man/figures/logo.png)

**Tidy Interface for Creel Survey Design and Analysis**

tidycreel provides a pipe-friendly interface for creel survey design,
data management, estimation, and reporting. Built on the
[`survey`](https://cran.r-project.org/package=survey) package for robust
design-based inference, it lets fisheries biologists work in domain
vocabulary — dates, strata, counts, effort — without managing survey
design internals directly.

## Installation

Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("chrischizinski/tidycreel")

# or with devtools
devtools::install_github("chrischizinski/tidycreel")
```

## Survey Types

##### Instantaneous Count

Stratified effort estimation from periodic angler counts.

##### Bus-Route

PPS site selection with Horvitz-Thompson estimators (Malvestuto 1978).

##### Ice Fishing

Degenerate bus-route design with certainty site sampling.

##### Camera-Monitored

Counter and ingress-egress timestamp preprocessing.

##### Aerial Survey

Single-overflight effort with calibrated open-hours scaling.

## Key Capabilities

- **Design-based inference** — wraps the `survey` package; biologists
  write creel vocabulary, not survey package internals
- **Single entry point** —
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  dispatches to the correct estimator for each survey type
- **Incomplete trip handling** — TOST equivalence testing validates
  whether incomplete trips can be pooled
- **Sample size and power** —
  [`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
  [`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
  and
  [`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
  plan surveys before data collection
- **Season summaries** —
  [`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)
  assembles estimates across strata or survey periods into a wide tibble

## Quick Start

### Instantaneous Count Survey

``` r
library(tidycreel)

# 1. Define survey structure with tidy selectors
design <- creel_design(example_calendar, date = date, strata = day_type)

# 2. Attach count observations
design <- add_counts(design, example_counts)

# 3. Estimate effort with design-based variance
estimate_effort(design)
```

### Bus-Route Survey

``` r
# Probability-proportional-to-size site selection
design <- creel_design(
  example_calendar,
  date = date,
  strata = day_type,
  survey_type = "bus_route",
  sampling_frame = my_site_frame,
  site = site_id
)

design <- add_interviews(design, interview_data,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept
)

estimate_catch_rate(design)
```

## Functions at a Glance

### Survey Design

- **[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)**
  — single entry point; dispatches on `survey_type` (instantaneous,
  bus_route, ice, camera, aerial)
- **[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)**,
  **[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)**,
  **[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)**,
  **[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)**,
  **[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)**
  — attach observation data

### Estimation

- **[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)**
  — total effort with Taylor linearization, bootstrap, or jackknife
  variance
- **[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)**
  /
  **[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)**
  — ratio-based rates from interview data
- **[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)**
  /
  **[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)**
  — totals via delta method variance propagation

### Planning

- **[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)**,
  **[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)**,
  **[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)**
  — sample size and power analysis
- **[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)**,
  **[`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md)**
  — sampling frame generators

### Diagnostics

- **[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md)**,
  **[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md)**,
  **[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)**
  — pre- and post-season QA

## Vignettes

| Vignette                                                                                              | Description                                              |
|-------------------------------------------------------------------------------------------------------|----------------------------------------------------------|
| [Getting Started](https://chrischizinski.github.io/tidycreel/articles/tidycreel.html)                 | Core workflow: design → counts → effort estimation       |
| [Bus-Route Surveys](https://chrischizinski.github.io/tidycreel/articles/bus-route-surveys.html)       | PPS site selection, enumeration expansion, HT estimators |
| [Bus-Route Equations](https://chrischizinski.github.io/tidycreel/articles/bus-route-equations.html)   | Statistical derivations and formulas                     |
| [Interview Estimation](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.html) | CPUE, catch, and harvest from interview data             |
| [Incomplete Trips](https://chrischizinski.github.io/tidycreel/articles/incomplete-trips.html)         | When and how to use mean-of-ratios; TOST validation      |

## License

MIT License — see
[LICENSE.md](https://chrischizinski.github.io/tidycreel/LICENSE.md) for
details.
