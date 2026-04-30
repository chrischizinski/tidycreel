# Bus-Route Surveys

## What is a Bus-Route Survey?

A bus-route survey visits multiple access points (sites) in a fixed
route, called a circuit. Unlike an access-point creel survey that
stations an interviewer at one location for the day, a bus-route crew
travels the circuit repeatedly, counting and interviewing anglers at
each site as they pass through.

Sites are not sampled uniformly. Instead, each site is assigned a
selection probability proportional to its expected fishing effort:
high-use sites appear in the sampling frame with higher probability and
are therefore visited more often, while low-use sites appear with lower
probability. This deliberate, probability-proportional-to-size design is
what makes valid inference possible.

Two types of data are collected during each visit:

- **Enumeration counts** — every angler party at the site is counted
  (`n_counted`).
- **Interviews** — a subset of parties is interviewed to collect effort
  and catch data (`n_interviewed`).

The ratio `n_counted / n_interviewed` (the enumeration expansion factor)
scales the interviewed catch and effort up to represent all parties at
the site, including those not interviewed. Without this expansion, busy
sites are systematically underrepresented in the total estimate.

The statistical framework follows Malvestuto et al. (1978) and Jones &
Pollock (2012, Chapter 19). tidycreel implements the general
Horvitz-Thompson estimators from that chapter directly.

## Key Concepts

### Inclusion Probability (πᵢ)

The inclusion probability πᵢ is the probability that a given sampling
unit (site × period combination) is included in the sample. For a
two-stage bus-route design:

``` math
\pi_i = p\_site_i \times p\_period
```

where `p_site` is the probability of selecting site *i* in a given pass,
and `p_period` is the probability that the period containing the visit
is sampled. Sites with higher expected effort get higher `p_site`
values, meaning they are selected more often — and correspondingly
receive a lower inverse-probability weight in the estimator.

**Critical point:** πᵢ is a property of the *sampling design*, not of
the site or the anglers. It is specified when you design the survey, not
computed from the interview data.

### Enumeration Counts

During each circuit pass, the crew counts every visible angler party at
the site (`n_counted`) and then interviews as many as possible
(`n_interviewed`). When not all parties are interviewed, the expansion
factor

``` math
\text{expansion} = \frac{n\_counted}{n\_interviewed}
```

rescales the interviewed data so it represents all parties. If all
parties are interviewed (n_counted = n_interviewed), the expansion is 1
and no adjustment is needed. This is the case in Malvestuto (1996) Box
20.6 Example 1, used in this vignette.

### Horvitz-Thompson Estimator

The total effort estimator (Jones & Pollock 2012, Eq. 19.4) is:

``` math
\hat{E} = \sum_i \frac{e_i}{\pi_i}
```

where $`e_i = \text{hours\_fished}_i \times \text{expansion}_i`$ is the
enumeration-expanded effort for interview *i*. Each site’s contribution
is weighted by the reciprocal of its inclusion probability. A site
sampled with probability 0.20 receives weight 5 — five times the weight
of a site sampled with probability 1.0. This inverse-probability
weighting is what makes the estimator statistically unbiased.

The harvest estimator (Jones & Pollock 2012, Eq. 19.5) follows the same
structure:

``` math
\hat{H} = \sum_i \frac{h_i}{\pi_i}
```

## A Note on Existing Implementations

Some R packages that support bus-route surveys hardcode $`\pi_i = 0.5`$
or compute the inclusion probability as `wait_time / circuit_time`.
Neither is the inclusion probability as defined by Horvitz-Thompson
theory or by Jones & Pollock (2012). Using an incorrect $`\pi_i`$
produces biased estimates whose magnitude of bias grows with the
heterogeneity of site probabilities.

tidycreel computes $`\pi_i = p\_site \times p\_period`$ directly from
the sampling frame you supply to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).
This matches the primary source definition in Jones & Pollock (2012,
p. 912) and the worked example in Malvestuto (1996, Box 20.6). The
implementation is validated against that published example in the
package test suite.

## Step-by-Step Example

We demonstrate the full bus-route workflow using the data from
Malvestuto (1996) Box 20.6, Example 1 — a four-site, single-circuit
survey with 15 interviews over four days.

### Step 1: Define the Sampling Design

The sampling frame specifies the four sites, their selection
probabilities (`p_site`), and the period sampling probability
(`p_period`). Site probabilities must sum to 1.0 within each circuit.

``` r

library(tidycreel)

# Sampling frame: 4 sites, 1 circuit
# p_site values are proportional to expected fishing effort at each site
sampling_frame <- data.frame(
  site     = c("A", "B", "C", "D"),
  circuit  = "circ1",
  p_site   = c(0.30, 0.25, 0.40, 0.05), # must sum to 1.0
  p_period = 0.50 # uniform period sampling
)
# Inclusion probability: pi_i = p_site * p_period
# Site A: 0.30 * 0.50 = 0.15
# Site B: 0.25 * 0.50 = 0.125
# Site C: 0.40 * 0.50 = 0.20
# Site D: 0.05 * 0.50 = 0.025

# Survey calendar: 4 weekdays
calendar <- data.frame(
  date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = "weekday"
)

# Build the bus-route design
design <- creel_design(
  calendar,
  date = date,
  strata = day_type,
  survey_type = "bus_route",
  sampling_frame = sampling_frame,
  site = site,
  circuit = circuit,
  p_site = p_site,
  p_period = p_period
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "bus_route"
#> Date column: date
#> Strata: day_type
#> Calendar: 4 days (2024-06-01 to 2024-06-04)
#> day_type: 1 level
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Bus-Route Design ──
#> 
#> Sites: 4, Circuits: 1
#> Sampling probabilities (pi_i = p_site * p_period):
#> A [circ1]: p_site=0.3, p_period=0.5, pi_i=0.15
#> B [circ1]: p_site=0.25, p_period=0.5, pi_i=0.125
#> C [circ1]: p_site=0.4, p_period=0.5, pi_i=0.2
#> D [circ1]: p_site=0.05, p_period=0.5, pi_i=0.025
```

The design object stores the sampling frame and precomputes πᵢ for each
site×circuit combination. Site C has the highest selection probability
(p_site = 0.40) and therefore the highest πᵢ (0.20), which means its
interviews will carry lower inverse-probability weight than Site D’s (πᵢ
= 0.025).

### Step 2: Attach Interview Data

Each row of interview data represents one interviewed party. The
`n_counted` and `n_interviewed` columns record how many parties were at
the site vs. how many were actually interviewed. In this example both
are equal (no expansion needed), but the columns must still be supplied
for bus-route designs.

``` r

# 15 interviews across 4 sites and 4 days
# Site A: 4 interviews (all 4 parties interviewed)
# Site B: 3 interviews (all 3 parties)
# Site C: 6 interviews (all 6 parties) — highest effort site
# Site D: 2 interviews (all 2 parties)
interviews_raw <- data.frame(
  date = as.Date(c(
    "2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02", # Site A
    "2024-06-01", "2024-06-02", "2024-06-03", # Site B
    "2024-06-01", "2024-06-02", "2024-06-03", # Site C (rows 1-3)
    "2024-06-03", "2024-06-04", # Site C (rows 4-5)
    "2024-06-03", "2024-06-04", # Site D
    "2024-06-03" # Site C (row 6)
  )),
  day_type = "weekday",
  site = c(
    "A", "A", "A", "A",
    "B", "B", "B",
    "C", "C", "C",
    "C", "C",
    "D", "D",
    "C"
  ),
  circuit = "circ1",
  hours_fished = c(
    7.5, 7.5, 7.5, 7.5, # Site A: 4 x 7.5 = 30 h total
    20.0 / 3, 20.0 / 3, 20.0 / 3, # Site B: 3 x 6.67 = 20 h total
    57.5 / 6, 57.5 / 6, 57.5 / 6, # Site C rows 1-3
    57.5 / 6, 57.5 / 6, # Site C rows 4-5
    2.5, 2.5, # Site D: 2 x 2.5 = 5 h total
    57.5 / 6 # Site C row 6: total = 57.5 h
  ),
  fish_kept = c(
    1L, 0L, 1L, 0L,
    1L, 0L, 1L,
    1L, 1L, 0L,
    1L, 0L,
    0L, 0L,
    1L
  ),
  fish_caught = c(
    2L, 1L, 1L, 1L,
    2L, 1L, 1L,
    2L, 1L, 1L,
    1L, 1L,
    1L, 1L,
    1L
  ),
  n_counted = c(
    4L, 4L, 4L, 4L,
    3L, 3L, 3L,
    6L, 6L, 6L,
    6L, 6L,
    2L, 2L,
    6L
  ),
  n_interviewed = c(
    4L, 4L, 4L, 4L,
    3L, 3L, 3L,
    6L, 6L, 6L,
    6L, 6L,
    2L, 2L,
    6L
  ),
  trip_status = "complete"
)

# Attach interviews — pi_i is joined automatically from the sampling frame
design <- add_interviews(
  design,
  interviews_raw,
  effort        = hours_fished,
  catch         = fish_caught,
  harvest       = fish_kept,
  n_counted     = n_counted,
  n_interviewed = n_interviewed,
  trip_status   = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 15 interviews: 15 complete (100%), 0 incomplete (0%)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "bus_route"
#> Date column: date
#> Strata: day_type
#> Calendar: 4 days (2024-06-01 to 2024-06-04)
#> day_type: 1 level
#> Counts: "none"
#> Interviews: 15 observations
#> Type: "access"
#> Catch: fish_caught
#> Effort: hours_fished
#> Harvest: fish_kept
#> Trip status: 15 complete, 0 incomplete
#> Survey: <survey.design2> (constructed)
#> Sections: "none"
#> 
#> ── Bus-Route Design ──
#> 
#> Sites: 4, Circuits: 1
#> Sampling probabilities (pi_i = p_site * p_period):
#> A [circ1]: p_site=0.3, p_period=0.5, pi_i=0.15
#> B [circ1]: p_site=0.25, p_period=0.5, pi_i=0.125
#> C [circ1]: p_site=0.4, p_period=0.5, pi_i=0.2
#> D [circ1]: p_site=0.05, p_period=0.5, pi_i=0.025
#> 
#> ── Enumeration Counts ──
#> 
#> (n_counted observed, n_interviewed interviewed, expansion =
#> n_counted/n_interviewed)
#> A [circ1]: counted=16, interviewed=16, expansion=1
#> B [circ1]: counted=9, interviewed=9, expansion=1
#> C [circ1]: counted=36, interviewed=36, expansion=1
#> D [circ1]: counted=4, interviewed=4, expansion=1
```

[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
joins πᵢ from the sampling frame to each interview row (stored as
`.pi_i`) and computes the enumeration expansion factor
(`.expansion = n_counted / n_interviewed`). These are used internally by
the estimation functions.

### Step 3: Estimate Effort

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
dispatches to the bus-route estimator and computes
$`\hat{E} = \sum(e_i / \pi_i)`$.

``` r

# Estimate total angler-hours
effort_est <- estimate_effort(design)
print(effort_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     848.  68.9     713.     982.    15

# Inspect per-site contributions to the total
site_contribs <- get_site_contributions(effort_est)
print(site_contribs)
#> # A tibble: 15 × 5
#>    site  circuit   e_i  pi_i e_i_over_pi_i
#>    <chr> <chr>   <dbl> <dbl>         <dbl>
#>  1 A     circ1    7.5  0.15           50  
#>  2 A     circ1    7.5  0.15           50  
#>  3 A     circ1    7.5  0.15           50  
#>  4 A     circ1    7.5  0.15           50  
#>  5 B     circ1    6.67 0.125          53.3
#>  6 B     circ1    6.67 0.125          53.3
#>  7 B     circ1    6.67 0.125          53.3
#>  8 C     circ1    9.58 0.2            47.9
#>  9 C     circ1    9.58 0.2            47.9
#> 10 C     circ1    9.58 0.2            47.9
#> 11 C     circ1    9.58 0.2            47.9
#> 12 C     circ1    9.58 0.2            47.9
#> 13 D     circ1    2.5  0.025         100  
#> 14 D     circ1    2.5  0.025         100  
#> 15 C     circ1    9.58 0.2            47.9
```

The site contributions table shows exactly how each site’s effort feeds
into the total. Site C (πᵢ = 0.20, total effort = 57.5 h) contributes
57.5 / 0.20 = 287.5 angler-hours to the total — the largest single-site
contribution, reflecting its high effort despite the relatively frequent
sampling.

Site D (πᵢ = 0.025, total effort = 5 h) contributes 5 / 0.025 = 200
angler-hours. Though Site D has little observed effort, its low sampling
probability means it represents a much larger population of fishing
activity.

The total E_hat = 847.5 angler-hours matches Malvestuto (1996) Box 20.6
Example 1 exactly.

### Step 4: Estimate Harvest

[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
applies the same Horvitz-Thompson logic to fish kept.

``` r

# Estimate total fish kept (harvest)
harvest_est <- estimate_harvest_rate(design)
print(harvest_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     49.3  12.9     24.1     74.6    15

# Estimate total catch (kept + released)
catch_est <- estimate_total_catch(design)
print(catch_est)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     180.  45.7     90.7     270.    15
```

## Validation

The effort estimate above (E_hat = 847.5 angler-hours) reproduces the
published result from Malvestuto (1996) Box 20.6 Example 1 exactly. This
agreement is verified by the package test suite in
`tests/testthat/test-primary-source-validation.R`. Each of the four site
contributions matches:

| Site      | e_i (h) | πᵢ    | e_i / πᵢ  |
|-----------|---------|-------|-----------|
| A         | 30.0    | 0.150 | 200.0     |
| B         | 20.0    | 0.125 | 160.0     |
| C         | 57.5    | 0.200 | 287.5     |
| D         | 5.0     | 0.025 | 200.0     |
| **Total** |         |       | **847.5** |

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883–919. American Fisheries Society.

- Malvestuto, S. P. (1996). Sampling the recreational angler. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591–623. American Fisheries
  Society.

- Malvestuto, S. P., Davies, W. D., & Shelton, W. L. (1978). An
  evaluation of the roving creel survey with nonuniform probability
  sampling. *Transactions of the American Fisheries Society*, 107(2),
  255–262.
