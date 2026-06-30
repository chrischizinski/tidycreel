---
output: github_document
---
<!-- Generated from README.Rmd — do not edit README.md directly -->

# tidycreel

<p align="center">
<img src="https://raw.githubusercontent.com/chrischizinski/tidycreel/main/man/figures/logo.png" alt="tidycreel hex sticker" width="200"/>
</p>

<!-- badges: start -->
[![R-CMD-check](https://github.com/chrischizinski/tidycreel/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/chrischizinski/tidycreel/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://img.shields.io/badge/pkgdown-live-1B4F72)](https://chrischizinski.github.io/tidycreel/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![Codecov test coverage](https://codecov.io/gh/chrischizinski/tidycreel/graph/badge.svg)](https://app.codecov.io/gh/chrischizinski/tidycreel)
[![Release](https://img.shields.io/badge/release-v2.5.0%20%22Creek%20Chub%22-4CAF50)](https://github.com/chrischizinski/tidycreel/releases)
<!-- badges: end -->

**Tidy Interface for Creel Survey Design, Estimation, and Reporting**

tidycreel provides a pipe-friendly interface for creel survey design, data management, estimation, visualisation, and reporting. Built on the [`survey`](https://cran.r-project.org/package=survey) package for design-based inference, it lets fisheries biologists work in creel vocabulary — dates, strata, counts, effort, catch, lengths, schedules — without managing survey-package internals directly.

## Installation

Install the development version from GitHub:

```r
# install.packages("pak")
pak::pak("chrischizinski/tidycreel")

# or with devtools
devtools::install_github("chrischizinski/tidycreel")
```

## Survey Types

<div class="row mt-4 mb-4">
<div class="col-md-4 mb-3">
<div class="card h-100 border-0 bg-light p-3">
<h5 class="text-primary">Instantaneous Count</h5>
<p class="small">Stratified effort estimation from periodic angler counts.</p>
<p class="small"><a href="https://chrischizinski.github.io/tidycreel/articles/tidycreel.html">Getting Started →</a></p>
</div>
</div>
<div class="col-md-4 mb-3">
<div class="card h-100 border-0 bg-light p-3">
<h5 class="text-primary">Bus-Route</h5>
<p class="small">PPS site selection with Horvitz-Thompson estimators and enumeration expansion.</p>
<p class="small"><a href="https://chrischizinski.github.io/tidycreel/articles/bus-route-surveys.html">Bus-Route vignette →</a></p>
</div>
</div>
<div class="col-md-4 mb-3">
<div class="card h-100 border-0 bg-light p-3">
<h5 class="text-primary">Ice Fishing</h5>
<p class="small">Degenerate bus-route design with certainty site sampling.</p>
<p class="small"><a href="https://chrischizinski.github.io/tidycreel/articles/ice-fishing.html">Ice Fishing vignette →</a></p>
</div>
</div>
<div class="col-md-4 mb-3">
<div class="card h-100 border-0 bg-light p-3">
<h5 class="text-primary">Camera-Monitored</h5>
<p class="small">Counter and ingress-egress preprocessing, NB GLMM count imputation, and camera effort indexing.</p>
<p class="small"><a href="https://chrischizinski.github.io/tidycreel/articles/camera-surveys.html">Camera Survey vignette →</a></p>
</div>
</div>
<div class="col-md-4 mb-3">
<div class="card h-100 border-0 bg-light p-3">
<h5 class="text-primary">Aerial Survey</h5>
<p class="small">Single-overflight effort estimation with calibrated open-hours scaling.</p>
<p class="small"><a href="https://chrischizinski.github.io/tidycreel/articles/aerial-surveys.html">Aerial vignette →</a> | <a href="https://chrischizinski.github.io/tidycreel/articles/aerial-glmm.html">GLMM variant →</a></p>
</div>
</div>
</div>

## Key Capabilities

- **Design-based inference** — wraps the `survey` package; biologists write creel vocabulary, not survey-package internals.
- **Single design entry point** — `creel_design()` dispatches to the correct workflow for each survey type.
- **Core estimation surface** — effort, catch rate, harvest rate, release rate, and total-catch estimators share a common API.
- **Extended estimation methods** — camera effort indexing, NB GLMM count imputation, weighted length distributions, mark-recapture population and harvest estimators (Petersen, Schnabel), and exploitation rate from tag returns (Pollock et al.).
- **Stratification auditing** — `audit_strata()`, `simulate_strata_collapse()`, and `reallocate_strata()` diagnose stratum weights, inclusion probabilities, and coverage; test collapse scenarios before committing to a redesign.
- **Validation and cleaning** — field-level validation, species standardisation, data-validation summaries, and toy datasets for examples.
- **Planning and QA** — schedule generation, count-window planning, completeness checks, sample-size tools, and power calculators.
- **Visualisation and reporting** — `autoplot()` methods, `theme_creel()`, `creel_palette()`, a Quarto Creel Report template scaffold, and the legacy flexdashboard scaffold.
- **Documentation and onboarding** — glossary, workflow vignettes, statistical-method articles, and a pkgdown site.

## Quick Start

### Instantaneous Count Survey

```r
library(tidycreel)

# 1. Define survey structure with tidy selectors
design <- creel_design(example_calendar, date = date, strata = day_type)

# 2. Attach count observations
design <- add_counts(design, example_counts)

# 3. Estimate effort with design-based variance
estimate_effort(design)
```

### Bus-Route Survey

```r
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

| If you want to… | Start here |
|---|---|
| Learn the package vocabulary | [Glossary](https://chrischizinski.github.io/tidycreel/articles/glossary.html) |
| See the main end-to-end workflow | [Getting Started](https://chrischizinski.github.io/tidycreel/articles/tidycreel.html) |
| Plan a season before sampling starts | [Survey Design Toolbox](https://chrischizinski.github.io/tidycreel/articles/survey-design-toolbox.html) |
| Estimate angler population or exploitation rate from tag data | [Mark-Recapture and Exploitation Rate](https://chrischizinski.github.io/tidycreel/articles/mark-recapture.html) |
| Understand plotting and output styling | [Visualisation](https://chrischizinski.github.io/tidycreel/articles/visualisation.html) and `theme_creel()` |
| Build a report/dashboard | Use the bundled Quarto Creel Report starter template, or open **R Markdown > From Template > Creel Dashboard** for the legacy scaffold |

## Functions at a Glance

### Survey Design
- **`creel_design()`** — single entry point; dispatches on `survey_type`.
- **`add_counts()`**, **`add_interviews()`**, **`add_catch()`**, **`add_lengths()`**, **`add_ages()`**, **`add_sections()`** — attach observation data.

### Estimation
- **`estimate_effort()`** — total effort with Taylor linearization, bootstrap, or jackknife variance.
- **`estimate_catch_rate()`**, **`estimate_harvest_rate()`**, **`estimate_release_rate()`** — ratio-based interview estimators.
- **`estimate_total_catch()`**, **`estimate_total_harvest()`**, **`estimate_total_release()`** — totals via delta-method propagation.
- **`est_effort_camera()`**, **`est_length_distribution()`**, **`est_mean_length()`**, **`est_age_distribution()`**, **`est_mean_age()`** — camera effort indexing and weighted size- and age-structure estimation.
- **`estimate_exploitation_rate()`** — exploitation rate from tag returns (Pollock et al.; simple and T-weighted stratified paths).
- **`estimate_angler_n()`** — Petersen and Schnabel mark-recapture population size estimators.
- **`estimate_mr_harvest()`** — population-scale total harvest from mark-recapture data.

### Validation and Diagnostics
- **`validate_creel_data()`**, **`validation_report()`**, **`standardize_species()`** — clean and validate real-world creel inputs.
- **`validate_incomplete_trips()`**, **`validate_design()`**, **`check_completeness()`**, **`compare_variance()`**, **`adjust_nonresponse()`** — QA and estimator diagnostics.
- **`audit_strata()`**, **`simulate_strata_collapse()`**, **`reallocate_strata()`** — stratification diagnostics; verify weights, simulate collapse scenarios, and rebalance allocations.

### Planning and Reporting
- **`generate_schedule()`**, **`generate_bus_schedule()`**, **`generate_count_times()`**, **`attach_count_times()`** — planning/scheduling helpers.
- **`creel_n_effort()`**, **`creel_n_cpue()`**, **`creel_n_camera()`**, **`creel_power()`**, **`cv_from_n()`** — sample-size and power tools.
- **`season_summary()`**, **`summary.creel_estimates()`**, **`write_estimates()`** — report-ready summary/export helpers.
- **`autoplot.creel_estimates()`**, **`autoplot.creel_schedule()`**, **`autoplot.creel_length_distribution()`**, **`theme_creel()`**, **`creel_palette()`** — visualisation helpers.

## Vignettes

### Get Started

| Vignette | Description |
|---|---|
| [Getting Started](https://chrischizinski.github.io/tidycreel/articles/tidycreel.html) | Core workflow: design → counts → effort estimation |
| [Glossary](https://chrischizinski.github.io/tidycreel/articles/glossary.html) | Plain-language guide to tidycreel terms and concepts |

### Survey Types

| Vignette | Description |
|---|---|
| [Bus-Route Surveys](https://chrischizinski.github.io/tidycreel/articles/bus-route-surveys.html) | PPS site selection with Horvitz-Thompson estimators |
| [Ice Fishing](https://chrischizinski.github.io/tidycreel/articles/ice-fishing.html) | Certainty-site (degenerate bus-route) design |
| [Camera Surveys](https://chrischizinski.github.io/tidycreel/articles/camera-surveys.html) | Counter and ingress-egress preprocessing, count imputation, camera effort |
| [Aerial Surveys](https://chrischizinski.github.io/tidycreel/articles/aerial-surveys.html) | Single-overflight effort with calibrated open-hours scaling |
| [Aerial GLMM](https://chrischizinski.github.io/tidycreel/articles/aerial-glmm.html) | Negative-binomial GLMM aerial effort (Askey 2018) |

### Estimation

| Vignette | Description |
|---|---|
| [Survey Integration](https://chrischizinski.github.io/tidycreel/articles/survey-tidycreel.html) | Using tidycreel alongside the `survey` package directly |
| [Interview Estimation](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.html) | CPUE, catch, and harvest from interview data |
| [Mark-Recapture and Exploitation Rate](https://chrischizinski.github.io/tidycreel/articles/mark-recapture.html) | Chapman, Petersen, Schnabel estimators; MR harvest; exploitation rate from tag returns |
| [Incomplete Trips](https://chrischizinski.github.io/tidycreel/articles/incomplete-trips.html) | When and how to use mean-of-ratios and TOST validation |
| [Flexible Count Estimation](https://chrischizinski.github.io/tidycreel/articles/flexible-count-estimation.html) | Non-standard count configurations and custom time windows |
| [Progressive Count Surveys](https://chrischizinski.github.io/tidycreel/articles/progressive-count-surveys.html) | Rolling and progressive count workflows |
| [Section Estimation](https://chrischizinski.github.io/tidycreel/articles/section-estimation.html) | Spatial section-level effort and catch estimation |
| [Temporal Extrapolation](https://chrischizinski.github.io/tidycreel/articles/temporal-extrapolation.html) | Extrapolating partial-season data to full-season estimates |

### Reporting & Planning

| Vignette | Description |
|---|---|
| [Unextrapolated Summaries](https://chrischizinski.github.io/tidycreel/articles/unextrapolated-summaries.html) | Raw interview summaries without season-level expansion |
| [Survey Design Toolbox](https://chrischizinski.github.io/tidycreel/articles/survey-design-toolbox.html) | Sample-size, power, scheduling, and pre-season planning tools |
| [Survey Scheduling](https://chrischizinski.github.io/tidycreel/articles/survey-scheduling.html) | Count windows, schedules, validation, and completeness checks |
| [Visualisation](https://chrischizinski.github.io/tidycreel/articles/visualisation.html) | Plotting patterns and output styling with `theme_creel()` |

### Statistical Methods

| Vignette | Description |
|---|---|
| [Effort Pipeline](https://chrischizinski.github.io/tidycreel/articles/effort-pipeline.html) | Statistical mechanics of the effort estimation pipeline |
| [Catch Pipeline](https://chrischizinski.github.io/tidycreel/articles/catch-pipeline.html) | Statistical mechanics of the catch estimation pipeline |
| [Replicate Designs](https://chrischizinski.github.io/tidycreel/articles/replicate-designs.html) | Variance workflows and replicate-design reasoning |
| [Bus-Route Equations](https://chrischizinski.github.io/tidycreel/articles/bus-route-equations.html) | Technical equation derivations for bus-route estimators |

### Ecosystem

| Vignette | Description |
|---|---|
| [tidycreel.connect](https://chrischizinski.github.io/tidycreel/articles/tidycreel-connect.html) | Database integration and reproducible data pipelines |

## Getting Help and Reporting Bugs

### Questions about usage

If you have questions about which survey type to use, how to interpret
results, or how to structure your data, the best place to start is
**GitHub Discussions**:

> https://github.com/chrischizinski/tidycreel/discussions

GitHub Discussions works like a threaded forum attached to the repository.
If you do not already have a GitHub account, you can create one for free at
https://github.com/signup — it only requires an email address. Once signed
in, click **New discussion**, select the **Q&A** category, and describe what
you are trying to do. Searching existing threads first is worth a moment;
your question may already have an answer.

### Reporting a bug or unexpected result

If a function returns an error, produces a result that does not look right,
or behaves differently from what the documentation describes, please open a
**GitHub Issue**:

> https://github.com/chrischizinski/tidycreel/issues

**Step-by-step for first-time GitHub users:**

1. Go to the Issues link above. If you are not signed in, click **Sign in**
   in the top-right corner (or **Sign up** if you do not yet have an account).
2. Click the green **New issue** button.
3. Select the **Bug report** template — it will open a pre-filled form.
4. Fill in each section of the form:
   - **Survey type** — which design you are using (`instantaneous`,
     `bus_route`, `ice`, `camera`, or `aerial`)
   - **tidycreel version** — run `packageVersion("tidycreel")` in R and
     paste the result (e.g., `1.6.0`)
   - **What you expected** — describe the output or behavior you expected
   - **What actually happened** — paste the full error message, or describe
     the result that does not look right
   - **Reproducible example** — a short R snippet that shows the problem
     (see below)
5. Click **Submit new issue** at the bottom of the form.

**Writing a reproducible example**

The single most useful thing you can include is a short, self-contained R
snippet that demonstrates the problem without needing your real data. Use
the package's built-in example datasets (`example_calendar`,
`example_counts`, `example_interviews`, etc.) wherever possible, or create a
small data frame that triggers the issue.

A good example looks like this:

```r
library(tidycreel)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)

# The call that produces the unexpected result
estimate_effort(design)
#> Error: ...  (paste the full error message here)
```

The snippet should run from scratch without any additional files or setup.
If reducing your data to a minimal example is not straightforward, share
what you have and describe the context — that is still very helpful. The
`reprex` package can automatically format and share R output if you want a
polished submission: install it with `install.packages("reprex")` and run
`reprex::reprex()` around your code.

For guidance on contributing code, requesting new features, or the
development workflow, see
[CONTRIBUTING.md](https://github.com/chrischizinski/tidycreel/blob/main/CONTRIBUTING.md).

## License

MIT License — see [LICENSE.md](LICENSE.md) for details.

## AI Use Acknowledgement

Artificial intelligence tools were used during the development of tidycreel,
primarily through Claude Code (Anthropic), with selected code and outputs
reviewed using Codex (OpenAI). These tools supported code refinement,
consistency across functions, GitHub Actions workflows, error checking, and
the development of testing infrastructure.

All functions and analytical outputs have been reviewed by the author team
and validated against real-world creel survey data and expected analytical
behavior. Despite these review and testing efforts, errors may still occur.
If you identify a problem or unexpected result, please
[submit an issue](https://github.com/chrischizinski/tidycreel/issues) so
that it can be reviewed and addressed.
