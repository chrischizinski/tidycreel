
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tidycreel

<p align="center">

<img src="man/figures/tidycreel-hex.svg" alt="tidycreel hex sticker" width="250"/>
</p>

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R CMD
Check](https://github.com/chrischizinski/tidycreel/actions/workflows/r-check.yml/badge.svg)](https://github.com/chrischizinski/tidycreel/actions/workflows/r-check.yml)
[![lintr](https://github.com/chrischizinski/tidycreel/actions/workflows/lintr.yaml/badge.svg)](https://github.com/chrischizinski/tidycreel/actions/workflows/lintr.yaml)
<!-- badges: end -->

The goal of tidycreel is to provide a survey-first, tidy interface for
creel survey design and analysis. Estimators are built on the
`survey`/`svrepdesign` framework with vectorized, tidyverse data
workflows, delivering defensible estimates of effort, CPUE, catch, and
harvest.

## Installation

**tidycreel is distributed via GitHub only** (not submitted to CRAN).
Install the latest version with:

``` r
# install.packages("pak")
pak::pak("chrischizinski/tidycreel")

# Or using devtools/remotes
# install.packages("devtools")
devtools::install_github("chrischizinski/tidycreel")
```

## Example

Survey-first estimators using bundled toy data:

``` r
library(tidycreel)

# Load example data
interviews <- readr::read_csv(
  system.file("extdata/toy_interviews.csv", package = "tidycreel")
)
counts <- readr::read_csv(
  system.file("extdata/toy_counts.csv", package = "tidycreel")
)
calendar <- readr::read_csv(
  system.file("extdata/toy_calendar.csv", package = "tidycreel")
)

# Create day-PSU design from calendar
svy_day <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month")
)

# Estimate effort from instantaneous counts
est_effort(svy_day, counts, method = "instantaneous", by = c("location"))

# Estimate CPUE and catch from interview data
svy_int <- survey::svydesign(ids = ~1, weights = ~1, data = interviews)
est_cpue(svy_int, by = c("target_species"), response = "catch_total")
est_catch(svy_int, by = c("target_species"), response = "catch_kept")
```

## Effort Overview (Survey-First)

- Instantaneous and Progressive (roving) estimators aggregate to day ×
  group totals and use a day-PSU design for inference. See the vignette:

``` r
vignette("effort_survey_first", package = "tidycreel")
```

- Aerial snapshot counts with covariates, post-stratification, and
  calibration are covered here:

``` r
vignette("aerial", package = "tidycreel")
```

Tip: For replicate variance, convert your day design with
`survey::as.svrepdesign()` and pass it to the estimators.

## Guides and Vignettes

- Survey terms in creel context: a translator

``` r
vignette("survey_creel_terms", package = "tidycreel")
```

- Replicate designs (bootstrap/jackknife/BRR) for creel inference

``` r
vignette("replicate_designs_creel", package = "tidycreel")
```
