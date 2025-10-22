
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tidycreel

<p align="center">

<img src="man/figures/hex.png" alt="tidycreel hex sticker" width="250"/>
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

**tidycreel is distributed via GitHub only** (not submitted to CRAN). Install the latest version with:

``` r
# install.packages("pak")
pak::pak("chrischizinski/tidycreel")

# Or using devtools/remotes
# install.packages("devtools")
devtools::install_github("chrischizinski/tidycreel")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(tidycreel)
## basic example code
```

What is special about using `README.Rmd` instead of just `README.md`?
You can include R chunks like so:

``` r
summary(cars)
#>      speed           dist
#>  Min.   : 4.0   Min.   :  2.00
#>  1st Qu.:12.0   1st Qu.: 26.00
#>  Median :15.0   Median : 36.00
#>  Mean   :15.4   Mean   : 42.98
#>  3rd Qu.:19.0   3rd Qu.: 56.00
#>  Max.   :25.0   Max.   :120.00
```

You’ll still need to render `README.Rmd` regularly, to keep `README.md`
up-to-date. `devtools::build_readme()` is handy for this.

You can also embed plots, for example:

<img src="man/figures/README-pressure-1.png" width="100%" />

In that case, don’t forget to commit and push the resulting figure
files, so they display on GitHub and CRAN.

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
