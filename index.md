# tidycreel

![tidycreel hex
sticker](https://raw.githubusercontent.com/chrischizinski/tidycreel/main/man/figures/logo.png)

**Tidy Interface for Creel Survey Design, Estimation, and Reporting**

tidycreel provides a pipe-friendly interface for creel survey design,
data management, estimation, visualisation, and reporting. Built on the
[`survey`](https://cran.r-project.org/package=survey) package for
design-based inference, it lets fisheries biologists work in creel
vocabulary — dates, strata, counts, effort, catch, lengths, schedules —
without managing survey-package internals directly.

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

PPS site selection with Horvitz-Thompson estimators and enumeration
expansion.

##### Ice Fishing

Degenerate bus-route design with certainty site sampling.

##### Camera-Monitored

Counter and ingress-egress preprocessing plus camera effort indexing.

##### Aerial Survey

Single-overflight effort estimation with calibrated open-hours scaling.

## Key Capabilities

- **Design-based inference** — wraps the `survey` package; biologists
  write creel vocabulary, not survey-package internals.
- **Single design entry point** —
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  dispatches to the correct workflow for each survey type.
- **Core estimation surface** — effort, catch rate, harvest rate,
  release rate, and total-catch estimators share a common API.
- **Extended estimation methods** — includes camera effort indexing,
  weighted length distributions, and variance comparison helpers.
- **Validation and cleaning** — field-level validation, species
  standardisation, data-validation summaries, and toy datasets for
  examples.
- **Planning and QA** — schedule generation, count-window planning,
  completeness checks, sample-size tools, and power calculators.
- **Visualisation and reporting** — `autoplot()` methods,
  [`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md),
  [`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md),
  and a flexdashboard report template scaffold.
- **Documentation and onboarding** — glossary, workflow vignettes,
  statistical-method articles, and a pkgdown site.

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

## Where to Start

| If you want to…                        | Start here                                                                                                                                                                         |
|----------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Learn the package vocabulary           | [Glossary](https://chrischizinski.github.io/tidycreel/articles/glossary.html)                                                                                                      |
| See the main end-to-end workflow       | [Getting Started](https://chrischizinski.github.io/tidycreel/articles/tidycreel.html)                                                                                              |
| Plan a season before sampling starts   | [Survey Design Toolbox](https://chrischizinski.github.io/tidycreel/articles/survey-design-toolbox.html)                                                                            |
| Understand plotting and output styling | [Visualisation](https://chrischizinski.github.io/tidycreel/articles/visualisation.html) and [`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md) |
| Build a report/dashboard               | Install the package, then open **R Markdown \> From Template \> Creel Dashboard** in RStudio                                                                                       |

## Functions at a Glance

### Survey Design

- **[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)**
  — single entry point; dispatches on `survey_type`.
- **[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)**,
  **[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)**,
  **[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)**,
  **[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md)**,
  **[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)**
  — attach observation data.

### Estimation

- **[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)**
  — total effort with Taylor linearization, bootstrap, or jackknife
  variance.
- **[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)**,
  **[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)**,
  **[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)**
  — ratio-based interview estimators.
- **[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)**,
  **[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)**,
  **[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)**
  — totals via delta-method propagation.
- **[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)**,
  **[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)**
  — camera effort indexing and weighted size-structure estimation.

### Validation and Diagnostics

- **[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md)**,
  **[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md)**,
  **[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md)**
  — clean and validate real-world creel inputs.
- **[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md)**,
  **[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md)**,
  **[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md)**,
  **[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md)**,
  **[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md)**
  — QA and estimator diagnostics.

### Planning and Reporting

- **[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)**,
  **[`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md)**,
  **[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md)**,
  **[`attach_count_times()`](https://chrischizinski.github.io/tidycreel/reference/attach_count_times.md)**
  — planning/scheduling helpers.
- **[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md)**,
  **[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md)**,
  **[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)**,
  **[`cv_from_n()`](https://chrischizinski.github.io/tidycreel/reference/cv_from_n.md)**
  — sample-size and power tools.
- **[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)**,
  **[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md)**,
  **[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)**
  — report-ready summary/export helpers.
- **[`autoplot.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_estimates.md)**,
  **[`autoplot.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_schedule.md)**,
  **[`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md)**,
  **[`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)**,
  **[`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md)**
  — visualisation helpers.

## Selected Vignettes

| Vignette                                                                                                | Description                                                   |
|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| [Getting Started](https://chrischizinski.github.io/tidycreel/articles/tidycreel.html)                   | Core workflow: design → counts → effort estimation            |
| [Glossary](https://chrischizinski.github.io/tidycreel/articles/glossary.html)                           | Plain-language guide to tidycreel terms and concepts          |
| [Survey Design Toolbox](https://chrischizinski.github.io/tidycreel/articles/survey-design-toolbox.html) | Sample-size, power, scheduling, and pre-season planning tools |
| [Survey Scheduling](https://chrischizinski.github.io/tidycreel/articles/survey-scheduling.html)         | Count windows, schedules, validation, and completeness checks |
| [Visualisation](https://chrischizinski.github.io/tidycreel/articles/visualisation.html)                 | Plotting patterns and output styling                          |
| [Interview Estimation](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.html)   | CPUE, catch, and harvest from interview data                  |
| [Incomplete Trips](https://chrischizinski.github.io/tidycreel/articles/incomplete-trips.html)           | When and how to use mean-of-ratios and TOST validation        |
| [Replicate Designs](https://chrischizinski.github.io/tidycreel/articles/replicate-designs.html)         | Variance workflows and replicate-design reasoning             |

## License

MIT License — see
[LICENSE.md](https://chrischizinski.github.io/tidycreel/LICENSE.md) for
details.
