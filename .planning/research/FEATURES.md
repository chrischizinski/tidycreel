# Feature Research: Interview-Based Catch and Harvest Estimation

**Domain:** Creel Survey Analysis - Interview-Based Estimation
**Researched:** 2026-02-09
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist for interview-based estimation. Missing these = incomplete catch/harvest analysis.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Add interview data to design | Parallel to `add_counts()` workflow; natural extension | LOW | Must accept complete trip interviews with catch and effort columns |
| CPUE estimation (catch per unit effort) | Core metric for catch rate; basis for total catch calculation | MEDIUM | Ratio-of-means for complete trips; requires survey::svyratio integration |
| Total catch estimation | Primary output: Effort × CPUE with variance propagation | MEDIUM | Delta method for product variance; automatic from existing effort + CPUE |
| Harvest vs release distinction | Standard creel survey output (catch_kept, catch_released) | LOW | Separate columns in interviews; same estimator applies to each |
| Standard error and confidence intervals | Scientific requirement; matches `estimate_effort()` pattern | LOW | Already established via survey package in v0.1.0 |
| Grouped estimation (by = parameter) | Established pattern from v0.1.0; expected for strata/species | MEDIUM | Must work with survey::svyby for CPUE ratios and grouped totals |
| Single species only (v0.2.0 scope) | Simplification for initial milestone; multi-species deferred | LOW | Dependency on existing grouped estimation; species as grouping variable comes later |

### Differentiators (Competitive Advantage)

Features that set tidycreel apart from manual survey package calculations or competitors.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Automatic variance propagation for total catch | Users don't hand-calculate delta method; tidycreel handles Effort × CPUE variance | MEDIUM | Core value: domain translation; survey package provides svycontrast for delta method |
| Unified design object workflow | Single `creel_design` object holds counts + interviews; coherent analysis | LOW | Extends v0.1.0 architecture; `add_interviews()` parallel to `add_counts()` |
| Progressive validation for interviews | Warn about incomplete trips in access design, missing effort values, extreme CPUE | MEDIUM | Tier 2 validation (warnings); helps users catch data issues early |
| Print methods showing estimator context | Output shows "Ratio-of-Means CPUE" vs "Mean-of-Ratios CPUE"; method transparency | LOW | Scientific software requirement; users must know which estimator was used |
| Variance method control (Taylor/bootstrap/jackknife) | Established in v0.1.0 for effort; extends to CPUE and total catch | LOW | Consistency across package; bootstrap for non-smooth statistics |
| Integration with existing effort estimates | `estimate_catch(design)` automatically uses effort from `estimate_effort(design)` | MEDIUM | Avoids user error in matching effort/CPUE; design object holds both |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems or scope creep.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic incomplete trip handling in v0.2.0 | Roving surveys are common | Mean-of-ratios requires trip truncation, length-bias correction; adds complexity | Defer to later milestone; start with complete trips only (access point design) |
| Multi-species estimation in v0.2.0 | Real surveys track multiple species | Species aggregation requires survey-based covariance handling; not trivial addition | Defer to v0.3.0; use grouped estimation with species as group variable initially |
| Automatic effort/CPUE matching across time periods | Seems convenient | Dangerous if time periods don't align; user should explicitly match | Require explicit design object; fail if effort not available |
| Built-in data validation/QA-QC | Seems helpful | Massive scope increase; QA/QC is separate workflow | Defer to v1.0.0; focus on estimation correctness first |
| Plotting/visualization in core functions | Users want to see catch trends | Violates separation of concerns; estimation ≠ visualization | Defer plots to separate package or v1.0.0; return tidy data for ggplot2 |
| Caught-while-seeking adjustments in v0.2.0 | Chapter describes targeted effort | Requires tracking target species, adjusting effort by targeting; complex domain logic | Defer to v0.3.0+; start with all-angler catch rates |
| Automatic species aggregation (black bass, panfish) | Common reporting categories | Survey-based aggregation with covariance; requires raw data + design; not post-hoc sum | Defer to v0.3.0; document correct aggregation approach |

## Feature Dependencies

```
[add_interviews()]
    └──requires──> [creel_design object from add_counts()]
                       └──requires──> [creel_design() constructor]

[estimate_cpue()]
    └──requires──> [add_interviews() has run]
                       └──requires──> [survey::svyratio for ratio-of-means]
                              └──requires──> [catch and effort columns validated]

[estimate_catch()]
    └──requires──> [estimate_effort() has run]
    └──requires──> [estimate_cpue() has run OR CPUE provided externally]
                       └──requires──> [delta method variance via survey::svycontrast]

[Grouped estimation (by = parameter)]
    └──enhances──> [estimate_cpue() with survey::svyby]
    └──enhances──> [estimate_catch() with grouped effort and CPUE]

[Variance method control (bootstrap/jackknife)]
    └──extends──> [variance infrastructure from v0.1.0]
                       └──requires──> [get_variance_design() helper from Phase 6]

[Incomplete trip handling]
    └──conflicts──> [v0.2.0 scope: complete trips only]
    └──deferred to──> [v0.3.0 roving design milestone]
```

### Dependency Notes

- **add_interviews() requires existing design:** Design object must have counts before adding interviews (effort estimation foundation)
- **estimate_catch() requires both effort and CPUE:** Total catch = Effort × CPUE; both must exist before calculating product
- **Grouped estimation extends patterns from v0.1.0:** survey::svyby already proven for effort; same pattern applies to CPUE and total catch
- **Complete trips only in v0.2.0:** Incomplete trip handling (mean-of-ratios, truncation) deferred to avoid scope creep
- **Single species scope:** Multi-species aggregation requires covariance handling; deferred to v0.3.0

## MVP Definition

### Launch With (v0.2.0)

Minimum viable interview-based estimation — what's needed to calculate catch and harvest from complete trip interviews.

- [x] **add_interviews()** — Add interview data to creel_design object (parallel to add_counts())
  - Essential: Extends design-centric workflow; interviews attached to same design object as counts
  - Implementation: Validate catch columns, effort column, trip completeness flag; store in design$interviews

- [x] **estimate_cpue()** — Catch per unit effort with ratio-of-means estimator
  - Essential: Core catch rate metric; basis for total catch calculation
  - Implementation: survey::svyratio(~catch_total, ~hours_fished); return standard estimate tibble

- [x] **estimate_catch()** — Total catch via Effort × CPUE with variance propagation
  - Essential: Primary deliverable for v0.2.0; what users need from interview data
  - Implementation: Delta method for product variance; survey::svycontrast or manual calculation

- [x] **Grouped CPUE and catch** — by = parameter for stratified/species-level estimates
  - Essential: Matches v0.1.0 pattern; users expect grouped estimation everywhere
  - Implementation: survey::svyby for grouped ratios; grouped delta method for total catch

- [x] **Harvest vs release estimation** — Separate estimates for catch_kept and catch_released
  - Essential: Standard creel survey output; manage harvest regulations
  - Implementation: Same estimator, different response columns; catch_total = kept + released

- [x] **Complete trip interviews only** — Access point design pattern
  - Essential: Simplifies v0.2.0 scope; avoids incomplete trip complexity
  - Implementation: Validate trip_complete flag; warn/error if incomplete trips detected

### Add After Validation (v0.2.x)

Features to add once core estimation is working and validated.

- [ ] **Incomplete trip handling (mean-of-ratios)** — Trigger: User requests or roving design common
  - Adds roving survey support; requires trip truncation (<30 min) and length-bias awareness
  - Defer to v0.3.0 if scope grows beyond complete trips

- [ ] **External CPUE input to estimate_catch()** — Trigger: Users have CPUE from other sources (aerial-access design)
  - Allows complemented designs (effort from aerial counts, CPUE from interviews)
  - Implementation: Accept CPUE tibble OR estimate internally from design

- [ ] **Diagnostic output for extreme CPUE values** — Trigger: Users report unrealistic catch rates
  - Tier 3 validation: Flag outliers, suggest truncation, check for data entry errors
  - Defer to v1.0.0 QA/QC milestone

### Future Consideration (v0.3.0+)

Features to defer until core interview-based estimation is proven.

- [ ] **Multi-species estimation** — Why defer: Requires survey-based covariance, species aggregation framework
- [ ] **Caught-while-seeking adjustments** — Why defer: Complex domain logic; requires target species tracking
- [ ] **Species aggregation helpers** — Why defer: Must handle covariance correctly; not simple post-hoc addition
- [ ] **Trip length distribution analysis** — Why defer: Useful but not core estimation; analytics feature
- [ ] **Party size adjustments** — Why defer: Trip vs angler-level estimation adds complexity

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| add_interviews() | HIGH | LOW | P1 |
| estimate_cpue() (ratio-of-means) | HIGH | MEDIUM | P1 |
| estimate_catch() (total) | HIGH | MEDIUM | P1 |
| Grouped CPUE and catch (by = ) | HIGH | MEDIUM | P1 |
| Harvest vs release distinction | HIGH | LOW | P1 |
| Complete trip validation | HIGH | LOW | P1 |
| Variance propagation (delta method) | HIGH | MEDIUM | P1 |
| Variance method control (bootstrap/jackknife) | MEDIUM | LOW | P1 |
| Print methods showing estimator | MEDIUM | LOW | P2 |
| Progressive validation (warnings) | MEDIUM | MEDIUM | P2 |
| External CPUE input | MEDIUM | LOW | P2 |
| Incomplete trip handling (mean-of-ratios) | HIGH | HIGH | P3 (defer to v0.3.0) |
| Multi-species estimation | MEDIUM | HIGH | P3 (defer to v0.3.0) |
| Species aggregation framework | MEDIUM | HIGH | P3 (defer to v0.3.0) |
| Caught-while-seeking | LOW | HIGH | P3 (defer to v0.3.0+) |

**Priority key:**
- P1: Must have for v0.2.0 launch (complete trip interview estimation)
- P2: Should have when possible (enhances usability, consistent with v0.1.0)
- P3: Defer to future milestones (scope control, complexity management)

## Estimator Analysis: Ratio-of-Means vs Mean-of-Ratios

### Context: Complete vs Incomplete Trips

**Access Point Design (Complete Trips):**
- Anglers interviewed at exit/boat ramp after finishing fishing
- All anglers have equal probability of being sampled (unbiased sampling)
- **Recommended Estimator:** Ratio-of-Means (R₁)

**Roving Design (Incomplete Trips):**
- Anglers interviewed while actively fishing (mid-trip)
- Sampling probability ∝ trip length (length-biased sampling)
- **Recommended Estimator:** Mean-of-Ratios (R₂) with trip truncation

### Mathematical Foundation

**Ratio-of-Means (R₁):**
```
CPUE = (Σ catch_i) / (Σ effort_i)
Var(R₁) ≈ (1/E²) [Var(C) + R₁²·Var(E) - 2·R₁·Cov(C,E)]
```
- **Properties:** Unbiased for complete trips; lower variance than mean-of-ratios
- **Implementation:** survey::svyratio(~catch_total, ~hours_fished, design)

**Mean-of-Ratios (R₂):**
```
CPUE = mean(catch_i / effort_i)
Var(R₂) = Var(catch_i / effort_i) / n
```
- **Properties:** Unbiased for incomplete trips with truncation; requires filtering short trips (<30 min)
- **Implementation:** survey::svymean(~I(catch_total/hours_fished), design)

### Decision Matrix for v0.2.0

| Survey Design | Trip Status | v0.2.0 Support | Estimator | Notes |
|---------------|-------------|----------------|-----------|-------|
| Access Point | Complete | ✓ YES | Ratio-of-Means | Primary focus; standard complete-trip interviews |
| Roving | Incomplete | ✗ DEFER | Mean-of-Ratios + truncation | Deferred to v0.3.0; requires trip length handling |
| Hybrid (both) | Mixed | ✗ DEFER | Combined estimator | Deferred to v0.3.0+; complex weighting |
| Aerial-Access | Complete | ✓ YES | Ratio-of-Means | External CPUE feature (P2); same estimator |

### Simulation Evidence (from Pollock et al. 1997, Rasmussen et al. 1998)

**Access Point Design:**
| Estimator | Bias | RMSE | Recommended? |
|-----------|------|------|--------------|
| Ratio-of-Means | ~0% | 0.15 | ✓ YES (standard) |
| Mean-of-Ratios | ~0% | 0.18 | OK (slightly higher variance) |

**Roving Design (Incomplete Trips):**
| Estimator | Truncation | Bias | RMSE | Recommended? |
|-----------|------------|------|------|--------------|
| Ratio-of-Means | None | **-15%** | 0.22 | ✗ BIASED |
| Mean-of-Ratios | None | ~0% | **0.45** | ✗ HUGE VARIANCE |
| Mean-of-Ratios | 30 min | ~0% | 0.17 | ✓ YES |

**Conclusion for v0.2.0:** Start with ratio-of-means for complete trips only. Add mean-of-ratios in v0.3.0 when roving designs are implemented.

## Workflow Analysis

### User Workflow: Access Point Design (v0.2.0 Focus)

```r
# 1. Create design with counts
design <- creel_design(
  counts_data,
  survey_type = "access_point",
  strata = day_type,
  psu = day
)

# 2. Add count data (effort foundation)
design <- design %>%
  add_counts(
    count_type = "instantaneous",
    count = n_anglers,
    count_start = start_time,
    count_duration = duration
  )

# 3. Add interview data (catch foundation)
design <- design %>%
  add_interviews(
    interviews_data,
    catch_total = catch,
    catch_kept = harvested,
    catch_released = released,
    effort = hours_fished,
    trip_complete = TRUE  # Access point interviews
  )

# 4. Estimate effort (existing v0.1.0 capability)
effort_est <- estimate_effort(design, by = day_type)

# 5. Estimate CPUE (NEW v0.2.0)
cpue_est <- estimate_cpue(design, response = "catch_kept", by = day_type)

# 6. Estimate total catch (NEW v0.2.0)
catch_est <- estimate_catch(design, response = "catch_kept", by = day_type)

# Result: Total harvest with SE and CI, grouped by day_type
```

### Expected Output Format (Consistency with v0.1.0)

**estimate_cpue() output:**
```r
# A tibble: 2 × 7
  day_type  estimate    se ci_low ci_high     n method
  <chr>        <dbl> <dbl>  <dbl>   <dbl> <int> <chr>
1 weekday       2.13 0.045   2.04    2.22   100 cpue_ratio_of_means
2 weekend       3.45 0.067   3.32    3.58   150 cpue_ratio_of_means
```

**estimate_catch() output:**
```r
# A tibble: 2 × 8
  day_type  estimate    se ci_low ci_high     n method              variance_method
  <chr>        <dbl> <dbl>  <dbl>   <dbl> <int> <chr>               <chr>
1 weekday     15420  1250  12970   17870   100 total_catch_product taylor
2 weekend     28350  2140  24150   32550   150 total_catch_product taylor
```

### Variance Propagation: Delta Method

**Product of Two Estimates:**
```
Total Catch (C) = Effort (E) × CPUE (R)
Var(C) = E² · Var(R) + R² · Var(E) + 2·E·R·Cov(E,R)
```

**Implementation via survey package:**
- **Option A:** survey::svycontrast with custom expression (preferred)
- **Option B:** Manual calculation using effort and CPUE variance-covariance matrix

**Covariance Handling:**
- If effort and CPUE estimated from same survey: Cov(E,R) may be non-zero
- If effort from aerial counts, CPUE from interviews: Assume Cov(E,R) = 0 (independent)
- v0.2.0 simplification: Assume independent (conservative); add covariance in v0.3.0 if needed

## Existing Package Comparisons

### Survey Package (base R survey)
| Feature | Survey Package | tidycreel v0.2.0 |
|---------|---------------|------------------|
| CPUE estimation | survey::svyratio manually | estimate_cpue() with domain translation |
| Total catch | Manual Effort × CPUE + delta method | estimate_catch() automatic variance propagation |
| Grouped estimation | survey::svyby with ratio formula | by = parameter in estimate_cpue/catch |
| Variance methods | Taylor, bootstrap, jackknife via svrepdesign | Same, but transparent variance = parameter |
| Domain vocabulary | PSU, FPC, calibration weights (survey jargon) | Creel survey domain (counts, interviews, effort, CPUE) |

**tidycreel advantage:** Users never write svyratio formulas; design object holds all context; automatic variance propagation for products.

### AnglerCreelSurveySimulation Package
| Feature | AnglerCreelSurveySimulation | tidycreel v0.2.0 |
|---------|----------------------------|------------------|
| Focus | Simulation and power analysis | Estimation from real data |
| CPUE estimation | Simulation-based | Design-based inference (survey package) |
| Catch estimation | Conceptual models | Statistical estimates with SE/CI |
| Roving surveys | Simulation support | Deferred to v0.3.0 (complete trips only in v0.2.0) |

**Complementary:** Simulation package useful for survey planning; tidycreel for analyzing collected data.

## Technical Specifications

### add_interviews() Function Signature

```r
add_interviews(
  design,                          # creel_design object
  interviews_data,                 # Interview data (tibble/data.frame)
  catch_total = catch,             # Tidy selector for total catch
  catch_kept = NULL,               # Optional: harvested fish
  catch_released = NULL,           # Optional: released fish
  effort = hours_fished,           # Effort column (hours)
  trip_complete = TRUE,            # Logical or column name
  validate = c("fast", "thorough", "skip")
)
```

**Validation Checks (Tier 1 - fail fast):**
- Interviews data is tibble/data.frame
- Catch and effort columns exist and are numeric
- Effort > 0 for all rows (no zero/negative effort)
- No NA values in required columns (catch, effort)
- If trip_complete = FALSE, error (incomplete trips not supported in v0.2.0)

**Validation Checks (Tier 2 - warn):**
- Extreme CPUE values (> 20 fish/hour suggests data error)
- Effort > 12 hours (unusually long trips)
- Catch without effort or effort without catch (suggest data issue)

### estimate_cpue() Function Signature

```r
estimate_cpue(
  design,                          # creel_design object with interviews
  response = "catch_total",        # Column for numerator
  effort_col = "hours_fished",     # Column for denominator
  by = NULL,                       # Grouping variables (tidy selector)
  variance = "taylor",             # Variance method (taylor/bootstrap/jackknife)
  conf_level = 0.95                # Confidence level
)
```

**Returns:** Tibble with columns:
- [grouping_vars if by specified]
- estimate (CPUE value)
- se (standard error)
- ci_low, ci_high (confidence limits)
- n (sample size)
- method ("cpue_ratio_of_means" for v0.2.0)
- variance_method ("taylor", "bootstrap", or "jackknife")

**Implementation:**
- Extract survey design from design$survey (already constructed in add_counts)
- Call survey::svyratio(~response, ~effort_col, design$survey)
- Apply variance method via get_variance_design() (established in v0.1.0)
- Format results in standard tidycreel output structure
- If by specified, use survey::svyby with svyratio as FUN

### estimate_catch() Function Signature

```r
estimate_catch(
  design,                          # creel_design object
  response = "catch_total",        # Same as used in estimate_cpue
  by = NULL,                       # Grouping variables
  effort_est = NULL,               # Optional: pre-computed effort
  cpue_est = NULL,                 # Optional: pre-computed CPUE
  variance = "taylor",             # Variance method
  conf_level = 0.95                # Confidence level
)
```

**Behavior:**
- If effort_est NULL: Call estimate_effort(design, by = by, variance = variance)
- If cpue_est NULL: Call estimate_cpue(design, response = response, by = by, variance = variance)
- Calculate total catch = effort × CPUE for each group
- Propagate variance using delta method: Var(E × R) = E²·Var(R) + R²·Var(E)
- Assume Cov(E,R) = 0 in v0.2.0 (conservative; independent surveys)

**Returns:** Same structure as estimate_cpue, but:
- estimate is total catch (not rate)
- method is "total_catch_product"

## Data Requirements

### Interview Data Schema

**Required Columns:**
- **catch_total** (or user-specified): Numeric, count of fish caught (kept + released)
- **effort** (hours_fished): Numeric, time spent fishing in hours
- **Grouping variables** (if by specified): day_type, location, etc.

**Optional Columns:**
- **catch_kept**: Numeric, fish harvested/kept
- **catch_released**: Numeric, fish released
- **trip_complete**: Logical, whether trip finished (must be TRUE in v0.2.0)
- **trip_id**: Identifier for interview/party
- **party_size**: Number of anglers in party (for later party-level adjustments)

**Data Validation Rules:**
- catch_total >= 0 (non-negative counts)
- effort > 0 (positive hours; no zero-effort interviews)
- If catch_kept and catch_released provided: catch_total ≈ catch_kept + catch_released (warn if mismatch)
- NA values not allowed in catch or effort (fail fast)

### Example Interview Data Structure

```r
interviews_data <- tibble(
  interview_id = 1:200,
  date = sample(seq.Date(as.Date("2024-05-01"), as.Date("2024-08-31"), by = "day"), 200, replace = TRUE),
  day_type = rep(c("weekday", "weekend"), 100),
  catch_total = rpois(200, lambda = 5),
  catch_kept = rpois(200, lambda = 2),
  catch_released = rpois(200, lambda = 3),
  hours_fished = rgamma(200, shape = 4, rate = 1),
  trip_complete = TRUE
)
```

## Confidence Levels

**Sources and Attribution:**

### HIGH Confidence (Context7, Official Docs, Published Literature)
- **Ratio-of-means for complete trips:** Pollock et al. (1994) *Angler Survey Methods*, gold standard reference
- **Mean-of-ratios for incomplete trips:** Pollock et al. (1997) *North American Journal of Fisheries Management* 17(1):11-19
- **Bias in roving surveys:** Confirmed by simulation studies (Rasmussen et al. 1998, Jones et al. 1995)
- **Delta method variance:** Standard survey statistics (Cochran 1977, survey package documentation)
- **Trip truncation threshold:** 30 minutes minimum (0.5 hours) from Hoenig et al. (1997) *Biometrics* 53:306-317

### MEDIUM Confidence (Multiple Sources, Community Practice)
- **Table stakes features:** Based on existing creel survey software patterns and user expectations
- **Variance method control:** Extension of v0.1.0 proven patterns; consistent API design
- **Progressive validation tiers:** Architecture pattern from v0.1.0; applies to interviews similarly
- **Grouped estimation priority:** Common use case in creel surveys (by strata, by species)

### LOW Confidence (Design Decisions, Future Features)
- **Incomplete trip deferral to v0.3.0:** Reasonable scope control, but timeline uncertain
- **Covariance assumption (Cov(E,R) = 0):** Conservative simplification; may need revision in v0.3.0
- **External CPUE input as P2:** Useful for complemented designs, but demand unclear

## Sources

### Primary Literature (HIGH confidence)
- [Pollock, K.H., Jones, C.M., & Brown, T.M. (1994). *Angler Survey Methods and their Applications in Fisheries Management*. American Fisheries Society Special Publication 25](https://www.researchgate.net/publication/313949781_Creel_Surveys)
- [Pollock, K.H., Hoenig, J.M., Jones, C.M., Robson, D.S., & Greene, C.J. (1997). Catch Rate Estimation for Roving and Access Point Surveys. *North American Journal of Fisheries Management* 17(1):11-19](https://www.academia.edu/80439796/Catch_Rate_Estimation_for_Roving_and_Access_Point_Surveys)
- [Rasmussen, P.W., Staggs, M.D., Beard, T.D., & Newman, S.P. (1998). Bias and confidence interval coverage of creel survey estimators evaluated by simulation. *Transactions of the American Fisheries Society* 127:469-480](https://fisheries.org/doi/9781934874295-ch19/)
- [Hoenig, J.M., Jones, C.M., Pollock, K.H., Robson, D.S., & Wade, D.L. (1997). Calculation of catch rate and total catch in roving surveys of anglers. *Biometrics* 53:306-317](https://www.researchgate.net/publication/241729832_Catch_Rate_Estimation_for_Roving_and_Access_Point_Surveys)

### Technical Documentation (HIGH confidence)
- [R survey package documentation: svyratio, svycontrast, variance estimation](https://cran.r-project.org/web/packages/survey/)
- tidycreel v0.1.0 codebase: R/creel-estimates.R, R/survey-bridge.R (variance infrastructure)
- tidycreel RATIO_ESTIMATORS_GUIDE.md (internal package documentation)
- TOTAL_HARVEST_DESIGN.md (design document for total catch estimation)

### Domain Research (MEDIUM-HIGH confidence)
- creel_chapter.md (Chapter 17: Creel Surveys, *Analysis and Interpretation of Freshwater Fisheries Data*, 2nd Edition)
- CHAPTER_GAP_ANALYSIS.md (comprehensive feature comparison with textbook chapter)
- creel_foundations.md (statistical foundations and R package design recommendations)
- [NOAA Fisheries: CPUE Modeling Best Practices](https://www.fisheries.noaa.gov/resource/peer-reviewed-research/catch-unit-effort-modelling-stock-assessment-summary-good-practices)

### Complementary Packages (MEDIUM confidence)
- [AnglerCreelSurveySimulation: Creel survey simulation tools](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html)
- [Bayesian integration of multiple creel survey data sources (ScienceDirect 2023)](https://www.sciencedirect.com/science/article/pii/S0165783623003259)

---
*Feature research for: tidycreel v0.2.0 interview-based estimation*
*Researched: 2026-02-09*
*Confidence: HIGH for core estimation methods, MEDIUM for scope decisions, LOW for future feature timelines*
