---
output: github_document
---

# tidycreel

<p align="center">
  <img src="https://raw.githubusercontent.com/chrischizinski/tidycreel/main/man/figures/tidycreel-hex.png" alt="tidycreel hex sticker" width="200"/>
</p>

<p align="center">
[![R-CMD-check](https://github.com/chrischizinski/tidycreel/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chrischizinski/tidycreel/actions/workflows/R-CMD-check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
</p>

**Tidy Interface for Creel Survey Design and Analysis**

tidycreel provides a pipe-friendly interface for creel survey design, data management, estimation, and reporting. Built on the [`survey`](https://cran.r-project.org/package=survey) package for robust design-based inference, it lets fisheries biologists work in domain vocabulary — dates, strata, counts, effort — without managing survey design internals directly.

## Installation

Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("chrischizinski/tidycreel")

# or with devtools
devtools::install_github("chrischizinski/tidycreel")
```

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

estimate_cpue(design)
```

## Features

### Survey Design

- **`creel_design()`** — single entry point with tidy selectors; supports instantaneous count and bus-route survey types
- **`add_counts()`** — attach instantaneous count observations with data validation against the design
- **`add_interviews()`** — attach angler interview data with tidy selectors for catch, effort, harvest, and trip metadata

### Estimation

- **`estimate_effort()`** — total and grouped effort with Taylor linearization, bootstrap, or jackknife variance
- **`estimate_cpue()`** — CPUE via ratio-of-means (default) or mean-of-ratios (for incomplete trips)
- **`estimate_harvest()`** — harvest rate estimation from interview data
- **`estimate_total_catch()`** / **`estimate_total_harvest()`** — expansion to totals with delta method variance propagation

### Bus-Route Surveys

- Horvitz-Thompson estimators following Malvestuto et al. (1978) and Jones & Pollock (2012, Ch. 19)
- Enumeration expansion that scales interviewed catch/effort to all anglers at each site
- Helpers: `get_enumeration_counts()`, `get_inclusion_probs()`, `get_sampling_frame()`, `get_site_contributions()`

### Incomplete Trips & Validation

- **`summarize_trips()`** — summarize trip status, duration, and completeness across interviews
- **`validate_incomplete_trips()`** — TOST equivalence testing to validate incomplete vs. complete trip comparability
- Sample size warnings when \< 10% of interviews are complete trips, following Colorado C-SAP best practices

### Survey Package Integration

- **`as_survey_design()`** — extract the underlying `survey` design object for advanced use

## Vignettes

| Vignette | Description |
|---|---|
| [Getting Started](https://chrischizinski.github.io/tidycreel/articles/tidycreel.html) | Core workflow: design → counts → effort estimation |
| [Bus-Route Surveys](https://chrischizinski.github.io/tidycreel/articles/bus-route-surveys.html) | PPS site selection, enumeration expansion, HT estimators |
| [Bus-Route Equations](https://chrischizinski.github.io/tidycreel/articles/bus-route-equations.html) | Statistical derivations and formulas |
| [Interview Estimation](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.html) | CPUE, catch, and harvest from interview data |
| [Incomplete Trips](https://chrischizinski.github.io/tidycreel/articles/incomplete-trips.html) | When and how to use mean-of-ratios; TOST validation |

## License

MIT License — see [LICENSE.md](LICENSE.md) for details.
