# Counts to Effort: Statistical Pipeline

## Introduction

This vignette explains *why* tidycreel’s effort estimates work the way
they do. It is written for creel biologists who know their surveys but
have not had to think carefully about sampling theory. By the end you
will understand three things:

1.  What a Primary Sampling Unit (PSU) is and why it matters for
    variance.
2.  How the Horvitz–Thompson estimator turns a sample of daily counts
    into a population total, and how the Rasmussen (1994) two-stage
    variance decomposes standard error into between-day and within-day
    components.
3.  How the progressive count estimator differs mechanically from the
    instantaneous count estimator.

Each concept is developed from first principles, illustrated with a
worked numeric example, and confirmed against
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
output.

------------------------------------------------------------------------

## What is a PSU?

In an instantaneous creel survey, the observer selects a random time on
a given day and records the number of anglers visible on the survey
section. Each **day × stratum combination** is treated as one sampling
unit. In survey-sampling language these units are called **Primary
Sampling Units** (PSUs).

Imagine a three-day survey with two day-type strata:

| Date       | Day type | PSU   |
|:-----------|:---------|:------|
| 2024-06-03 | weekday  | PSU-1 |
| 2024-06-03 | weekend  | PSU-2 |
| 2024-06-04 | weekday  | PSU-3 |
| 2024-06-04 | weekend  | PSU-4 |
| 2024-06-05 | weekday  | PSU-5 |
| 2024-06-05 | weekend  | PSU-6 |

Six PSUs formed by crossing 3 days × 2 strata.

Six PSUs in total — three per stratum. If the survey selected two
weekday PSUs and two weekend PSUs, the sample would contain four PSUs
out of six.

The population we want to estimate is the **season total** over all
$N_{h}$ PSUs in stratum $h$. The sample gives us observations on $n_{h}$
of those PSUs.

------------------------------------------------------------------------

## The Basic Effort Estimator

### Horvitz–Thompson form

For a stratified random sample, the Horvitz–Thompson (HT) estimator of
the population total is:

$$\widehat{E} = \sum\limits_{i \in s}\frac{y_{i}}{\pi_{i}}$$

- $y_{i}$ = observed count (number of anglers) on PSU $i$
- $\pi_{i}$ = inclusion probability for PSU $i$ (probability that PSU
  $i$ is selected into the sample)
- $s$ = the set of sampled PSUs

When sampling is done without replacement and all PSUs in a stratum are
equally likely to be chosen, the inclusion probability is
$\pi_{i} = n_{h}/N_{h}$. Substituting into the HT form and recognising
that the sum over $s_{h}$ covers $n_{h}$ PSUs gives the familiar
stratum-total estimator.

### Practical creel form

For stratum $h$ with $N_{h}$ total days and $n_{h}$ sampled days:

$${\widehat{E}}_{h} = \frac{N_{h}}{n_{h}}\sum\limits_{i \in s_{h}}y_{i}$$

- $N_{h}$ = total days available in stratum $h$ during the season
- $n_{h}$ = number of days actually sampled in stratum $h$
- $y_{i}$ = count (angler-hours or angler-trips) recorded on sampled day
  $i$
- $s_{h}$ = the set of sampled days in stratum $h$

The ratio $N_{h}/n_{h}$ is the **expansion factor**: if only one in
three days was sampled, each observed count represents three days worth
of effort in the population.

### Worked numeric

Stratum: “weekday”. $N = n = 3$ days sampled (all available days
observed). Counts: $y_{1} = 150,\; y_{2} = 230,\; y_{3} = 190$
angler-hours.

$${\widehat{E}}_{\text{weekday}} = \frac{3}{3} \times (150 + 230 + 190) = 1 \times 570 = 570{\mspace{6mu}\text{angler-hours}}$$

Confirming with R:

``` r
library(tidycreel)

calendar <- data.frame(
  date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05")),
  day_type = rep("weekday", 3),
  open_hours = rep(10, 3)
)
design <- creel_design(calendar, date = date, strata = day_type)

# n_anglers holds angler-hours (count × open hours already combined)
counts <- data.frame(
  date      = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05")),
  day_type  = rep("weekday", 3),
  n_anglers = c(150L, 230L, 190L)
)
design <- add_counts(design, counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
result <- estimate_effort(design)
result$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      570  69.3       69.3         0     272.     868.     3
```

The `estimate` column (570) matches the by-hand result. With a single
count per day `se_within` is always 0 — there is no within-day
replication to estimate within-day variance.

------------------------------------------------------------------------

## Multiple Counts per Day: Rasmussen Two-Stage Variance

### Why replicate counts within a day?

When two observers (or the same observer on two circuits) count the same
section twice on the same day — once in the morning and once in the
afternoon — we have **replicated measurements** within each PSU. This
within-day replication does something useful: it separates measurement
noise from true day-to-day variation.

Without multiple counts per day, we cannot tell whether the variation
across days is caused by real differences in angler activity or by
random counting error. With replication we can decompose the total
variance into two components:

$$\text{SE}^{2}\left( \widehat{E} \right) = \text{SE}_{\text{between}}^{2} + \text{SE}_{\text{within}}^{2}$$

### Between-day component

The between-day component measures how much estimated effort varies from
one sampled PSU to the next. It is computed by treating the **within-day
mean** ${\bar{y}}_{i}$ (average of all counts on day $i$) as the
PSU-level observation and applying the standard variance-of-a-total
formula:

$$\text{SE}_{\text{between}}^{2} = \frac{N_{h}^{2}}{n_{h}} \cdot s_{\bar{y}}^{2}$$

- $N_{h}$ = total days available in stratum $h$
- $n_{h}$ = number of sampled days
- $s_{\bar{y}}^{2}$ = sample variance of the within-day means
  ${\bar{y}}_{i}$

In plain language: this is the variance you would report even with a
single count per day, using the daily mean in place of a single count.
It reflects how much effort differs from one day to the next.

### Within-day component

The within-day component measures how much counts vary *within* a single
day — that is, how much the morning count differs from the afternoon
count. The Rasmussen (1994) formula is:

$$\text{SE}_{\text{within}}^{2} = \frac{N_{h}^{2}}{n_{h}^{2}}\sum\limits_{i = 1}^{n_{h}}\frac{s_{d,i}^{2}}{k_{i}}$$

- $s_{d,i}^{2}$ = sample variance of counts on day $i$ across its
  $k_{i}$ circuits
- $k_{i}$ = number of counts (circuits) on day $i$

Equivalently, using the pooled formulation implemented in tidycreel:

$$\text{SE}_{\text{within}}^{2} = \frac{N_{h}}{k_{\text{avg}}} \cdot s_{\text{within}}^{2}$$

where
$s_{\text{within}}^{2} = \frac{\sum_{i}\text{SS}_{d,i}}{n_{h}\left( k_{\text{avg}} - 1 \right)}$
is the pooled within-day variance and
$\text{SS}_{d,i} = \sum_{j}\left( y_{ij} - {\bar{y}}_{i} \right)^{2}$ is
the sum of squared deviations within day $i$.

In plain language: this is how much counting error you are carrying
around. A large within-day component means the morning and afternoon
counts disagree substantially — the observer is seeing large swings in
angler activity within a single day, or measurement error is high.

### Worked numeric

Four weekdays are sampled ($N = n = 4$). Each day receives two counts
(morning `am` and afternoon `pm`):

| Day | am count | pm count | Daily mean ${\bar{y}}_{i}$ | $\text{SS}_{d,i}$ |
|-----|----------|----------|----------------------------|-------------------|
| 1   | 10       | 20       | 15                         | 50                |
| 2   | 20       | 30       | 25                         | 50                |
| 3   | 30       | 40       | 35                         | 50                |
| 4   | 40       | 50       | 45                         | 50                |

Grand mean of daily means: $\bar{\bar{y}} = (15 + 25 + 35 + 45)/4 = 30$

**Between-day SE (step by step):**

Sample variance of daily means:

$$s_{\bar{y}}^{2} = \frac{(15 - 30)^{2} + (25 - 30)^{2} + (35 - 30)^{2} + (45 - 30)^{2}}{4 - 1} = \frac{225 + 25 + 25 + 225}{3} = \frac{500}{3} \approx 166.67$$

Between-day variance (without finite-population correction, as in the
with-replacement design assumed by
[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)):

$$\text{SE}_{\text{between}}^{2} = \frac{N^{2}}{n} \cdot s_{\bar{y}}^{2} = \frac{16}{4} \times 166.67 = 4 \times 166.67 = 666.67$$

$$\text{SE}_{\text{between}} = \sqrt{666.67} \approx 25.82$$

**Within-day SE (step by step):**

$k_{\text{avg}} = 2$; all $\text{SS}_{d,i} = 50$:

$$s_{\text{within}}^{2} = \frac{\sum\text{SS}_{d,i}}{n \cdot \left( k_{\text{avg}} - 1 \right)} = \frac{50 + 50 + 50 + 50}{4 \times (2 - 1)} = \frac{200}{4} = 50$$

$$\text{SE}_{\text{within}}^{2} = \frac{N}{k_{\text{avg}}} \cdot s_{\text{within}}^{2} = \frac{4}{2} \times 50 = 100$$

$$\text{SE}_{\text{within}} = \sqrt{100} = 10$$

**Combined SE:**

$$\text{SE} = \sqrt{666.67 + 100} = \sqrt{766.67} \approx 27.70$$

Confirming with R:

``` r
calendar_m <- data.frame(
  date       = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
  day_type   = rep("weekday", 4),
  open_hours = rep(10, 4)
)
design_m <- creel_design(calendar_m, date = date, strata = day_type)

multi_counts <- data.frame(
  date = as.Date(rep(
    c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06"),
    each = 2
  )),
  day_type = rep("weekday", 8),
  count_time = rep(c("am", "pm"), 4),
  n_anglers = c(10L, 20L, 20L, 30L, 30L, 40L, 40L, 50L)
)
design_m <- add_counts(design_m, multi_counts, count_time_col = count_time)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
result_m <- estimate_effort(design_m)
result_m$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      120  27.7       25.8        10     31.9     208.     4
```

The R output confirms: `se_between` $\approx 25.82$, `se_within`
$= 10.00$, and `se` $\approx 27.70$ — matching the by-hand calculations
exactly.

### When does `se_within` matter?

`se_within` is small when angler activity is stable throughout the day.
It is large when fishing activity follows a strong temporal pattern —
for example, an active morning bite followed by a quiet midday and a
busy evening. If `se_within / se > 0.5`, within-day variation is the
dominant source of uncertainty, and collecting additional circuits per
day would improve precision more than adding more sampled days.

------------------------------------------------------------------------

## The Progressive Count Estimator

The progressive count is a distinct field method, not a variant of the
instantaneous count. Instead of taking a snapshot at a random moment,
the observer **traverses the entire survey section** and records every
angler encountered during the traversal. One pass of the section is
called a **circuit**.

Because the observer is moving rather than counting instantaneously, the
estimator formula and its interpretation differ.

### Formula and derivation

Let $C_{d}$ be the number of anglers encountered during one circuit on
day $d$, and let $T_{d}$ be the total hours the section is open on day
$d$.

$${\widehat{E}}_{d} = C_{d} \times T_{d}$$

- $C_{d}$ = progressive count (all anglers encountered during the
  circuit on day $d$)
- $T_{d}$ = total open hours on day $d$

**Why does $\tau$ cancel?** During a circuit of duration $\tau$ hours,
the observer encounters anglers at rate $C_{d}/\tau$ anglers per hour.
Over the full $T_{d}$ open hours, the total angler-hours is:

$${\widehat{E}}_{d} = \frac{C_{d}}{\tau} \times T_{d} \times \tau = C_{d} \times T_{d}$$

The circuit time $\tau$ appears in both numerator and denominator and
cancels exactly. The result is that a progressive count records total
angler-hours directly, with $\tau$ needed only to derive the expansion
factor internally.

### Worked numeric

Three weekdays; circuit time $\tau = 2$ hours; section open $T_{d} = 8$
hours each day. Counts: $C_{1} = 15$, $C_{2} = 20$, $C_{3} = 25$.

| Day | $C_{d}$ | $T_{d}$ | ${\widehat{E}}_{d} = C_{d} \times T_{d}$ |
|-----|---------|---------|------------------------------------------|
| 1   | 15      | 8       | 120                                      |
| 2   | 20      | 8       | 160                                      |
| 3   | 25      | 8       | 200                                      |

Season total (N = n = 3):
$\widehat{E} = (3/3) \times (120 + 160 + 200) = 480$ angler-hours.

Confirming with R (note:
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
stores the expanded ${\widehat{E}}_{d}$ values in the `n_anglers` column
automatically):

``` r
calendar_p <- data.frame(
  date       = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05")),
  day_type   = rep("weekday", 3),
  open_hours = rep(8, 3)
)
design_p <- creel_design(calendar_p, date = date, strata = day_type)

prog_counts <- data.frame(
  date        = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05")),
  day_type    = rep("weekday", 3),
  n_anglers   = c(15L, 20L, 25L),
  shift_hours = rep(8, 3)
)
design_p <- add_counts(
  design_p, prog_counts,
  count_type = "progressive",
  circuit_time = 2,
  period_length_col = shift_hours
)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

# Per-day Ê_d values stored after C × T expansion
design_p$counts
#>         date day_type n_anglers
#> 1 2024-06-03  weekday       120
#> 2 2024-06-04  weekday       160
#> 3 2024-06-05  weekday       200

result_p <- estimate_effort(design_p)
result_p$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      480  69.3       69.3         0     182.     778.     3
```

The `n_anglers` column shows 120, 160, 200 — the pre-expanded daily
totals — and the season total is 480 angler-hours, matching the by-hand
calculation.

------------------------------------------------------------------------

## Summary

Three estimator pathways are available for instantaneous creel surveys:

| Scenario                | Data collected            | Key formula                                                       | `se_within`                           |
|-------------------------|---------------------------|-------------------------------------------------------------------|---------------------------------------|
| Single count per day    | One count per PSU         | ${\widehat{E}}_{h} = \left( N_{h}/n_{h} \right)\sum y_{i}$        | Always 0                              |
| Multiple counts per day | $k \geq 2$ counts per PSU | ${\widehat{E}}_{h} = \left( N_{h}/n_{h} \right)\sum{\bar{y}}_{i}$ | Nonzero; measures within-day variance |
| Progressive count       | One circuit per day       | ${\widehat{E}}_{d} = C_{d} \times T_{d}$                          | Always 0                              |

**Single count per day** is the classical creel estimator. All variance
is between-day variation; there is no within-day component to estimate.

**Multiple counts per day** (Rasmussen two-stage) adds a within-day
variance component. Use this design when angler activity patterns within
a day are uncertain or known to vary substantially. Monitor the ratio
`se_within / se`: a value above 0.5 means that adding circuits per day
improves precision more than adding sampled days.

**Progressive counts** are appropriate when the section is long enough
that a spot-check count would miss part of the angler population. The
$C \times T$ formula recovers total angler-hours without needing $\tau$
in the final estimate. Variance structure is the same as for
single-count instantaneous surveys.

------------------------------------------------------------------------

## References

- Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
  Scheduling counts in the instantaneous and progressive count methods
  for estimating sportfishing effort. *North American Journal of
  Fisheries Management*, 13, 723–736.

- Pope, S. L., et al. (in press). Progressive count methods for creel
  surveys.

- Rasmussen, P. W. (1994). Two-stage variance estimation for creel
  surveys with multiple counts per sampling unit. Cited in Su, Y.-S.,
  and Liu, P. (2025), equations 17–18.

- Su, Y.-S., and Liu, P. (2025). Flexible creel survey estimators.
  *Canadian Journal of Fisheries and Aquatic Sciences*, 82, 1–27.

------------------------------------------------------------------------

For the API walkthrough showing these functions on your own data, see
[Flexible Count
Estimation](https://chrischizinski.github.io/tidycreel/articles/flexible-count-estimation.md).
