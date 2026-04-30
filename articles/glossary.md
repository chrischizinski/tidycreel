# Glossary of Creel Survey Terms

This glossary collects the core terms that appear throughout tidycreel’s
functions, vignettes, and printed outputs. It is meant to be a quick
reference: plain-language definitions first, then pointers to where each
concept appears in the package workflow.

``` r

library(tidycreel)
```

## Survey design terms

### Creel survey

A **creel survey** is a survey of anglers, angling effort, and fish
catch. In practice this means some combination of calendars, count
observations, interviews, and species-level catch or length data
collected over a defined season.

### Design

A **design** is the survey structure that tells tidycreel what was
sampled, when it was sampled, and how observations should be grouped for
estimation. In this package, the design starts with
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
and is then enriched with additional data layers such as counts,
interviews, catch, or lengths.

### Calendar

The **calendar** is the table of dates and strata used to define the
survey frame. It answers the question: *what days were in scope for the
survey?*

### Stratum / strata

A **stratum** is a grouping variable used to divide the survey into more
homogeneous sampling units — for example `weekday` versus `weekend`.
**Strata** help estimation and planning by allowing different parts of
the survey to have different effort levels, variances, or sample sizes.

### PSU (Primary Sampling Unit)

A **PSU** is the primary unit that is sampled for design-based
inference. In many tidycreel workflows the PSU is the **day**, but in
some designs it may be a site-day or another higher-level sampling unit.
Variance estimators depend on having enough PSUs per stratum.

### Survey type

The **survey type** identifies the data-collection design. tidycreel
currently supports types such as `instantaneous`, `bus_route`, `ice`,
`camera`, and `aerial`. The survey type determines which estimation path
is used under the hood.

## Data layer terms

### Count data

**Count data** are effort-related observations attached with
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
For instantaneous surveys this is often the observed angler count or
angler-hours at a sampled moment.

### Interview data

**Interview data** are party-level observations attached with
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
These records typically include catch, effort, trip status, and optional
metadata such as angler type, method, or species sought.

### Catch data

**Catch data** are species-level rows attached with
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md).
They expand interview totals into a long format so species-specific
rates and totals can be estimated.

### Length data

**Length data** are fish-size observations attached with
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).
These may be stored as individual fish lengths or as pre-binned release
lengths, depending on the field workflow.

### Section

A **section** is a spatial subdivision of the fishery, registered with
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md).
Section-aware estimators let you estimate effort or catch for each part
of a lake or river separately.

## Effort and catch terms

### Effort

**Effort** is the amount of fishing activity. In tidycreel this is often
measured in **angler-hours**. Effort can be observed directly in count
data, reported in interviews, or estimated over an entire season.

### Angler-hours

**Angler-hours** are hours fished multiplied by the number of anglers.
This is a standard effort unit for creel work because it combines trip
duration and party size into one comparable measure.

### Catch rate

A **catch rate** is catch per unit of effort. In tidycreel this surface
is exposed through
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md).

### Harvest rate

A **harvest rate** is harvested fish per unit of effort. In tidycreel
this is estimated with
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).

### Release rate

A **release rate** is released fish per unit of effort. In tidycreel
this is estimated with
[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md).

### CPUE / HPUE

**CPUE** means **catch per unit effort**. **HPUE** means **harvest per
unit effort**. These are common fisheries abbreviations, but tidycreel’s
exported function names use the more explicit
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
and
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).

### Total catch / total harvest / total release

These are **season-scale totals** that combine estimated effort with
estimated rates. tidycreel provides
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
and
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
for these products.

## Trip-status and interview terms

### Complete trip

A **complete trip** is an interview where the angler has finished
fishing. These records provide a full accounting of effort and catch for
the trip.

### Incomplete trip

An **incomplete trip** is an interview conducted before the angler has
finished fishing. These interviews can still be useful, but they require
more care when estimating rates because the trip outcome is only
partially observed.

### Refusal

A **refusal** is a sampled angler or party who declines to be
interviewed. Refusals matter because high refusal rates can bias
summaries and estimates if participants differ systematically from
non-participants.

### Species sought

**Species sought** is the primary species an angler reports targeting.
This is used in summaries such as caught-while-sought and
harvested-while-sought rates.

## Estimation terms

### Design-based inference

**Design-based inference** means uncertainty is computed from the
sampling design rather than from a fully specified population model.
tidycreel relies on the `survey` package for this work.

### Weighted estimate

A **weighted estimate** adjusts observed data according to the survey
design so that sampled observations represent the broader fishery
correctly. In this package, estimators such as
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
or
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
use the internal survey design rather than simple raw tabulations.

### Unextrapolated summary

An **unextrapolated summary** describes the sample as observed, without
survey-design weighting. Examples include
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md)
and
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md).

### Extrapolated estimate

An **extrapolated estimate** projects from the sample to the broader
survey period or population using the survey design. Examples include
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
and
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md).

### Variance

**Variance** is the sampling variability of an estimate. In practical
terms it measures how much the estimate would vary across repeated
samples under the same design.

### Standard error (SE)

The **standard error** is the square root of the variance. It is the
most common uncertainty value shown next to an estimate.

### Confidence interval (CI)

A **confidence interval** is a range of plausible values for the
quantity being estimated, given the sample and the assumed estimation
method.

### Relative standard error (RSE)

**Relative standard error** is the standard error divided by the
estimate, usually expressed as a proportion. It is a common precision
target in survey planning.

## Planning terms

### Sample size planning

**Sample size planning** means deciding how many days, interviews, or
other sampling units are needed before the survey begins. tidycreel
provides
[`power_creel()`](https://chrischizinski.github.io/tidycreel/reference/power_creel.md),
[`creel_n_effort()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_effort.md),
[`creel_n_cpue()`](https://chrischizinski.github.io/tidycreel/reference/creel_n_cpue.md),
and
[`creel_power()`](https://chrischizinski.github.io/tidycreel/reference/creel_power.md)
for this work.

### Power

**Power** is the probability that a study will detect a meaningful
change when that change is truly present. In tidycreel this is typically
used for planning a future comparison in catch rate.

### Design comparison

A **design comparison** is a side-by-side comparison of estimates or
precision from alternative survey designs or alternative variance
methods.
[`compare_designs()`](https://chrischizinski.github.io/tidycreel/reference/compare_designs.md)
provides this surface.

### Hybrid design

A **hybrid design** combines more than one observation mode in the same
survey frame — for example fixed access-point counts plus roving-route
counts.
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md)
creates this kind of combined design object.

## Survey-type terms

### Instantaneous count survey

An **instantaneous count survey** samples counts at selected moments and
uses those observations to estimate total effort over a season.

### Progressive count survey

A **progressive count survey** moves through a route or circuit over
time rather than taking one instantaneous snapshot. tidycreel handles
this through
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
plus progressive-count logic in the effort pipeline.

### Bus-route survey

A **bus-route survey** samples access points or circuits with known
inclusion probabilities and uses Horvitz-Thompson style expansion to
estimate totals.

### Camera survey

A **camera survey** uses automated image or timestamp data to index or
estimate fishing effort. tidycreel supports both counter-style and
ingress-egress camera workflows.

### Aerial survey

An **aerial survey** estimates effort from counts collected during
overflights. The package supports both simple aerial estimation and a
GLMM-based correction path for non-random flight timing.

## Where to go next

Use this glossary as a map to the rest of the package:

- [`vignette("tidycreel")`](https://chrischizinski.github.io/tidycreel/articles/tidycreel.md)
  for the core workflow
- [`vignette("interview-estimation")`](https://chrischizinski.github.io/tidycreel/articles/interview-estimation.md)
  for interview-based estimators
- [`vignette("unextrapolated-summaries")`](https://chrischizinski.github.io/tidycreel/articles/unextrapolated-summaries.md)
  for raw interview summaries
- [`vignette("survey-design-toolbox")`](https://chrischizinski.github.io/tidycreel/articles/survey-design-toolbox.md)
  for planning and design comparison tools
- [`?creel_design`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  for the main entry point into the analysis pipeline
