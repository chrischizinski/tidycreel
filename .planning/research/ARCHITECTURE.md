# Architecture Research: Interview-Based Catch/Harvest Estimation

**Domain:** Creel survey analysis - interview-based catch/harvest estimation
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

Interview-based catch/harvest estimation integrates with the existing v0.1.0 instantaneous count architecture through a **parallel data stream** pattern. Count data flows through `add_counts()` to estimate effort; interview data will flow through `add_interviews()` to estimate CPUE. Both streams merge at the final estimation layer where **total catch = effort × CPUE** using delta method variance propagation.

**Key architectural insight:** Interview and count data are **statistically independent** but **functionally complementary**. They require separate survey design objects but coordinated variance estimation when combined.

## Integration with v0.1.0 Architecture

### Current v0.1.0 Flow (Effort Estimation)

```
User API Layer:
  creel_design(calendar) → add_counts(counts) → estimate_effort()

Survey Bridge Layer:
  construct_survey_design() → svydesign(day-PSU, stratified)

Survey Package Layer:
  svytotal() → Taylor variance
```

### New v0.2.0 Flow (Catch Estimation)

```
User API Layer:
  creel_design(calendar) → add_interviews(interviews) → estimate_cpue()
                                                      → estimate_catch()
                                                      → estimate_harvest()

Survey Bridge Layer:
  construct_interview_survey() → svydesign(interview-PSU, stratified)

Survey Package Layer:
  svyratio() or svymean() → Delta method variance
```

### Combined Flow (Total Catch)

```
User API Layer:
  design_with_counts ← add_counts(design, counts)
  design_with_both   ← add_interviews(design_with_counts, interviews)

  total_catch ← estimate_total_catch(design_with_both)

Statistical Layer:
  effort_estimate ← estimate_effort(design_with_both)
  cpue_estimate   ← estimate_cpue(design_with_both)

  total = effort × cpue
  var(total) = cpue² × var(effort) + effort² × var(cpue)  # Delta method
```

## System Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER API LAYER (Domain)                       │
├─────────────────────────────────────────────────────────────────┤
│  creel_design()  │  add_counts()  │  add_interviews()           │
│                  │                 │                              │
│  estimate_effort()  │  estimate_cpue()  │  estimate_catch()     │
│  estimate_harvest() │  estimate_total_catch()                   │
└────────┬──────────────────────┬────────────────────┬────────────┘
         │                      │                    │
┌────────┴──────────────────────┴────────────────────┴────────────┐
│              ORCHESTRATION LAYER (Survey Bridge)                 │
├─────────────────────────────────────────────────────────────────┤
│  construct_survey_design()  │  construct_interview_survey()     │
│  validate_counts_tier1()    │  validate_interviews_tier1()      │
│  warn_tier2_issues()        │  warn_tier2_interview_issues()    │
│  combine_variance()         │  delta_method_product()           │
└────────┬──────────────────────┬────────────────────┬────────────┘
         │                      │                    │
┌────────┴──────────────────────┴────────────────────┴────────────┐
│                 SURVEY PACKAGE LAYER (Statistics)                │
├─────────────────────────────────────────────────────────────────┤
│  svydesign()  │  svytotal()   │  svyratio()   │  svymean()     │
│  as.svrepdesign()  │  delta variance propagation                │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `add_interviews()` | Attach interview data to design, construct interview survey | Validates schema, creates survey.design2 for interviews |
| `estimate_cpue()` | Estimate catch per unit effort | Dispatches to ratio-of-means (svyratio) or mean-of-ratios (svymean) |
| `estimate_catch()` | Estimate total catch for a species | Calls estimate_cpue() for single species |
| `estimate_harvest()` | Estimate harvest per unit effort and total harvest | Same pattern as catch, filters to harvested fish only |
| `estimate_total_catch()` | Multiply effort × CPUE with variance | Combines estimates using delta method |
| `construct_interview_survey()` | Build svydesign from interview data | Day-PSU or interview-PSU depending on design |
| `delta_method_product()` | Variance of product of two estimates | var(E×C) = C²×var(E) + E²×var(C) |

## Data Flow Patterns

### Pattern 1: Parallel Data Streams

**What happens:** Count and interview data flow through separate validation and survey construction pipelines.

```
calendar
  ├─→ add_counts(counts)
  │     └─→ effort_survey (day-PSU stratified)
  │
  └─→ add_interviews(interviews)
        └─→ interview_survey (interview-PSU or day-PSU stratified)
```

**Why parallel:** Count and interview data have different structures, validation rules, and PSU definitions. Keeping streams separate until final estimation maintains clarity and allows independent use.

**Storage pattern:** `creel_design` object stores both:
- `$counts` and `$effort_survey` (from add_counts)
- `$interviews` and `$interview_survey` (from add_interviews)

### Pattern 2: Ratio Estimator Selection

**Access Point Design (Complete Trips):**
```
estimate_cpue(mode = "ratio_of_means")
  ↓
svyratio(~catch, ~effort, design)
  ↓
Ratio = Σcatch / Σeffort
var(Ratio) via delta method
```

**Roving Design (Incomplete Trips):**
```
interviews_truncated ← filter(interviews, effort >= 0.5)
  ↓
estimate_cpue(mode = "mean_of_ratios")
  ↓
svymean(~I(catch/effort), design)
  ↓
Mean = mean(catch/effort)
var(Mean) = var(catch/effort) / n
```

**Decision logic:**
- Access point (complete trips) → ratio-of-means (unbiased, lower variance)
- Roving (incomplete trips) → mean-of-ratios with truncation (unbiased after truncation)

**Statistical basis:**
- Ratio-of-means is biased for roving because sampling probability ∝ trip length
- Mean-of-ratios is unbiased but has infinite variance without truncation (extreme ratios from short trips)

### Pattern 3: Variance Propagation for Products

**Problem:** Total catch = Effort × CPUE, both are random variables with variance.

**Solution:** Delta method for products of independent estimates.

```r
# Effort estimate
E_hat <- estimate_effort(design)
E <- E_hat$estimate
var_E <- E_hat$se^2

# CPUE estimate
C_hat <- estimate_cpue(design)
C <- C_hat$estimate
var_C <- C_hat$se^2

# Total catch
Total <- E * C
var_Total <- (C^2 * var_E) + (E^2 * var_C)
se_Total <- sqrt(var_Total)
```

**Independence assumption:** Count and interview data collected independently (different sampling processes). If not independent, add covariance term: `+ 2*E*C*cov(E,C)`.

### Pattern 4: Survey Design Coordination

**Stratification must match** between count and interview surveys for valid combination:

```r
# CORRECT: Same strata
count_design <- svydesign(
  ids = ~date,
  strata = ~interaction(day_type, season),
  data = counts
)

interview_design <- svydesign(
  ids = ~interview_id,
  strata = ~interaction(day_type, season),  # SAME strata definition
  data = interviews
)
```

**Validation:** `estimate_total_catch()` must verify strata alignment before combining.

## Integration Points

### New Components for v0.2.0

| Component | Purpose | Dependencies | Location |
|-----------|---------|--------------|----------|
| `add_interviews()` | Attach interview data to design | creel_design, validate_interview_schema | `R/creel-design.R` (extend) |
| `estimate_cpue()` | Estimate catch per unit effort | survey::svyratio, survey::svymean | `R/creel-estimates-interviews.R` (new) |
| `estimate_catch()` | Species-specific catch totals | estimate_cpue | `R/creel-estimates-interviews.R` (new) |
| `estimate_harvest()` | Harvest totals | estimate_cpue | `R/creel-estimates-interviews.R` (new) |
| `estimate_total_catch()` | Combine effort × CPUE | estimate_effort, estimate_cpue | `R/creel-estimates-combined.R` (new) |
| `construct_interview_survey()` | Build interview svydesign | survey::svydesign | `R/survey-bridge.R` (extend) |
| `validate_interview_schema()` | Tier 1 validation for interviews | validate_calendar_schema | `R/creel-validation.R` (extend) |
| `delta_method_product()` | Variance of E × C | Base R | `R/variance-utils.R` (new) |

### Modified Components from v0.1.0

| Component | Modification | Why |
|-----------|--------------|-----|
| `creel_design` S3 class | Add `$interviews`, `$interview_survey` slots | Store interview data parallel to counts |
| `print.creel_design()` | Show interview data summary | User visibility |
| `validate_counts_tier1()` | No change | Counts and interviews validated separately |
| `estimate_effort()` | No change | Works independently of interviews |

### No Changes Required

| Component | Reason |
|-----------|--------|
| `creel_design()` constructor | Only calendar needed at creation |
| `construct_survey_design()` | Specific to count data |
| Survey variance methods (bootstrap, jackknife) | Applied at individual estimate level |
| `as_survey_design()` escape hatch | May need `which = c("counts", "interviews")` parameter |

## Recommended Build Order

Based on dependencies and v0.1.0 foundation:

1. **Phase 1: Interview Schema and Validation**
   - `validate_interview_schema()` (Tier 1)
   - `warn_tier2_interview_issues()` (Tier 2)
   - Tests: schema validation, NA detection, data quality warnings

2. **Phase 2: add_interviews() Integration**
   - Extend `creel_design` S3 class with interview slots
   - `add_interviews()` function (mirrors `add_counts()` pattern)
   - `construct_interview_survey()` (survey bridge)
   - Tests: interview attachment, survey construction, immutability

3. **Phase 3: CPUE Estimation (Single Mode)**
   - `estimate_cpue()` with `mode = "ratio_of_means"` only
   - Survey bridge to `survey::svyratio()`
   - Grouped estimation support (by parameter)
   - Tests: reference tests vs manual svyratio, grouped estimation

4. **Phase 4: CPUE Estimation (Both Modes)**
   - Add `mode = "mean_of_ratios"` to `estimate_cpue()`
   - Survey bridge to `survey::svymean(~I(catch/effort))`
   - Documentation: when to use which mode, truncation warning
   - Tests: both modes, truncation effects, reference tests

5. **Phase 5: Catch and Harvest Wrappers**
   - `estimate_catch()` (species-specific CPUE wrapper)
   - `estimate_harvest()` (filters to harvested only)
   - Tests: filtering logic, metadata preservation

6. **Phase 6: Combined Estimation (Effort × CPUE)**
   - `delta_method_product()` variance utility
   - `estimate_total_catch()` combining effort and CPUE
   - Strata alignment validation
   - Tests: variance propagation, independence assumption, reference tests

7. **Phase 7: Documentation and Examples**
   - Vignette: "Interview-Based Estimation"
   - Example datasets: access point and roving interviews
   - Ratio estimator guide integration
   - Tests: vignette rendering, examples run

**Dependency reasoning:**
- Can't estimate CPUE without interviews → Phase 2 before 3
- Can't combine estimates without both working → Phases 3-5 before 6
- Single mode before complexity → ratio-of-means (Phase 3) before mean-of-ratios (Phase 4)
- Core functionality before wrappers → CPUE (Phases 3-4) before catch/harvest (Phase 5)

## Architectural Patterns

### Pattern 1: Dual Survey Object Storage

**What:** Store separate survey.design2 objects for counts and interviews in the same creel_design container.

**When to use:** When two data sources have different PSU structures but share calendar/strata.

**Trade-offs:**
- **Pro:** Clean separation, independent validation, can use either alone
- **Pro:** Matches statistical reality (different sampling units)
- **Con:** More complex object structure, must coordinate strata

**Example:**
```r
design <- creel_design(calendar, date = date, strata = day_type)

design2 <- design %>%
  add_counts(counts, psu = "date") %>%
  add_interviews(interviews, psu = "interview_id")

# Two independent survey objects
design2$effort_survey    # day-PSU design for counts
design2$interview_survey # interview-PSU design for interviews
```

### Pattern 2: Mode-Based Dispatch

**What:** Single function (`estimate_cpue`) with `mode` parameter that dispatches to different survey functions.

**When to use:** When same statistical quantity (CPUE) has different estimators for different designs.

**Trade-offs:**
- **Pro:** User-friendly single entry point, mode documented in result
- **Pro:** Forces explicit choice (no hidden defaults for critical decision)
- **Con:** Function must handle two different return structures from survey package

**Example:**
```r
estimate_cpue <- function(design, mode = c("ratio_of_means", "mean_of_ratios")) {
  mode <- match.arg(mode)

  if (mode == "ratio_of_means") {
    # survey::svyratio() returns svyratio object
    svy_result <- survey::svyratio(~catch, ~effort, design$interview_survey)
    estimate <- coef(svy_result)
    se <- SE(svy_result)
  } else {
    # survey::svymean() returns svystat object
    design$interviews$cpue <- design$interviews$catch / design$interviews$effort
    svy_result <- survey::svymean(~cpue, design$interview_survey)
    estimate <- coef(svy_result)
    se <- SE(svy_result)
  }

  # Normalize to common output format
  new_creel_estimates(...)
}
```

### Pattern 3: Delta Method Variance Factory

**What:** Reusable utility function for variance of products/ratios using delta method.

**When to use:** Combining two independent estimates (effort × CPUE, catch / effort, etc.).

**Trade-offs:**
- **Pro:** Single implementation, tested once, used everywhere
- **Pro:** Documents statistical method explicitly
- **Con:** Assumes independence (must validate)

**Example:**
```r
delta_method_product <- function(est1, se1, est2, se2, covariance = 0) {
  # Var(X*Y) = Y² Var(X) + X² Var(Y) + 2XY Cov(X,Y)
  var1 <- se1^2
  var2 <- se2^2

  var_product <- (est2^2 * var1) + (est1^2 * var2) + (2 * est1 * est2 * covariance)
  se_product <- sqrt(var_product)

  list(estimate = est1 * est2, se = se_product)
}

# Usage
effort <- estimate_effort(design)
cpue <- estimate_cpue(design)

total_catch <- delta_method_product(
  effort$estimate, effort$se,
  cpue$estimate, cpue$se
)
```

### Pattern 4: Progressive Enhancement of creel_design

**What:** Design object gains capabilities as data is added, but never loses information.

**When to use:** Workflow where users incrementally add data sources.

**Trade-offs:**
- **Pro:** Supports exploratory workflow (add counts, check effort, add interviews, check CPUE)
- **Pro:** Immutable operations (each addition returns new object)
- **Con:** Multiple versions of design object in workspace

**Example:**
```r
# Start with calendar only
design <- creel_design(calendar, date = date, strata = day_type)

# Can't estimate yet
try(estimate_effort(design))  # Error: no counts

# Add counts → enables effort estimation
design_with_counts <- add_counts(design, counts)
estimate_effort(design_with_counts)  # ✓ Works

# Can't estimate CPUE yet
try(estimate_cpue(design_with_counts))  # Error: no interviews

# Add interviews → enables CPUE and total catch
design_complete <- add_interviews(design_with_counts, interviews)
estimate_cpue(design_complete)  # ✓ Works
estimate_total_catch(design_complete)  # ✓ Works
```

## Anti-Patterns

### Anti-Pattern 1: Combining Incompatible Strata

**What people might do:** Use different stratification for counts and interviews.

**Why it's wrong:** Total catch = Effort × CPUE requires estimates from same strata to multiply correctly. If effort is stratified by day_type and CPUE by season, the product is undefined.

**Do this instead:**
```r
# CORRECT: Enforce same strata
validate_strata_match <- function(design) {
  if (!is.null(design$counts) && !is.null(design$interviews)) {
    count_strata <- attr(design$effort_survey, "strata")
    interview_strata <- attr(design$interview_survey, "strata")

    if (!identical(count_strata, interview_strata)) {
      cli::cli_abort(c(
        "Strata must match between counts and interviews",
        "x" = "Count strata: {count_strata}",
        "x" = "Interview strata: {interview_strata}"
      ))
    }
  }
}
```

### Anti-Pattern 2: Using ratio-of-means for Roving Interviews

**What people might do:** Default to ratio-of-means (simpler, lower variance) for all interview types.

**Why it's wrong:** Roving interviews have sampling probability ∝ trip length. Ratio-of-means overweights long trips, causing -15% to -30% bias.

**Do this instead:**
```r
# Enforce correct estimator based on design type
estimate_cpue <- function(design, mode = NULL) {
  if (is.null(mode)) {
    # Auto-detect from design type
    mode <- if (design$design_type == "roving") {
      cli::cli_warn(c(
        "Roving design detected",
        "!" = "Using mean-of-ratios estimator",
        "i" = "Truncate short trips (<30 min) before calling estimate_cpue()"
      ))
      "mean_of_ratios"
    } else {
      "ratio_of_means"
    }
  }
  # ... rest of function
}
```

### Anti-Pattern 3: Forgetting Trip Truncation

**What people might do:** Apply mean-of-ratios to unfiltered roving data.

**Why it's wrong:** Very short incomplete trips create extreme catch/effort ratios (e.g., 1 fish / 0.1 hours = 10 fish/hour), leading to infinite variance and unstable estimates.

**Do this instead:**
```r
# Add validation in estimate_cpue()
if (mode == "mean_of_ratios") {
  min_effort <- min(design$interviews$effort, na.rm = TRUE)
  if (min_effort < 0.3) {  # Less than ~20 minutes
    cli::cli_warn(c(
      "Very short trips detected (minimum: {round(min_effort, 2)} hours)",
      "!" = "Mean-of-ratios estimator requires truncation of short trips",
      "i" = "Filter trips <0.5 hours before estimation",
      "i" = "Example: interviews %>% filter(effort >= 0.5)"
    ))
  }
}
```

### Anti-Pattern 4: Assuming Covariance = 0 Without Verification

**What people might do:** Always use `delta_method_product(cov = 0)` for effort × CPUE.

**Why it's wrong:** If count and interview data are collected by the same clerk on the same days, they may be correlated (e.g., high effort days also have high CPUE due to weather).

**Do this instead:**
```r
# Document independence assumption
estimate_total_catch <- function(design) {
  # Check if data sources are independent
  count_dates <- unique(design$counts$date)
  interview_dates <- unique(design$interviews$date)
  overlap <- intersect(count_dates, interview_dates)

  if (length(overlap) / length(union(count_dates, interview_dates)) > 0.7) {
    cli::cli_warn(c(
      "Substantial overlap between count and interview dates",
      "!" = "Estimates may be correlated",
      "i" = "Assuming independence (cov = 0) may underestimate variance",
      "i" = "Consider bootstrap variance for combined estimate"
    ))
  }

  # Proceed with delta method (independence assumption)
  delta_method_product(effort, cpue, covariance = 0)
}
```

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-100 interviews | Single species, simple strata (weekday/weekend) sufficient. In-memory processing. |
| 100-1000 interviews | Multiple species, complex strata (day_type × season × location). Pre-filter by species before estimation. |
| 1000+ interviews | Multi-site surveys, long time series. Consider data.table for aggregation before survey package. Cache survey objects. |

### Performance Bottlenecks

1. **First bottleneck:** `svyratio()` with bootstrap variance on large datasets (1000+ interviews).
   - **Fix:** Default to Taylor variance, use bootstrap only when needed.
   - **Warning:** Add message if nrow(interviews) > 500 and variance = "bootstrap".

2. **Second bottleneck:** Multiple species estimation (looping over 10+ species).
   - **Fix:** Vectorize where possible, use `by` parameter for species-grouped estimation.
   - **Pattern:** `estimate_catch(design, by = c(day_type, species))`

3. **Memory bottleneck:** Storing replicate weights for bootstrap with both count and interview surveys.
   - **Fix:** Generate replicates on-demand rather than storing in object.
   - **Pattern:** `get_variance_design()` creates svrepdesign when needed, not in add_interviews().

## Sources

**HIGH confidence sources:**

1. [Creel Survey Catch Rate Estimation](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) - Simulation package demonstrating CPUE methods
2. [Measurement Error in Angler Creel Surveys](https://www.tandfonline.com/doi/full/10.1080/02755947.2014.996689) - Ratio estimator comparison
3. [Effect of Survey Design on Catch Estimates](https://pubs.usgs.gov/publication/70038918) - Ratio-of-means vs mean-of-ratios evidence
4. [Survey Package Ratio Estimation](https://r-survey.r-forge.r-project.org/survey/html/svyratio.html) - R implementation reference
5. [Delta Method Tutorial](https://cran.r-project.org/web/packages/modmarg/vignettes/delta-method.html) - Variance of transformed parameters
6. **tidycreel v0.1.0 architecture** - `/.planning/codebase/ARCHITECTURE.md` (existing foundation)
7. **Creel foundations document** - `/creel_foundations.md` (domain knowledge)
8. **Creel effort methods** - `/creel_effort_estimation_methods.md` (complementary designs)
9. **Ratio estimators guide** - `/inst/RATIO_ESTIMATORS_GUIDE.md` (user-facing documentation)
10. **Creel chapter** - `/creel_chapter.md` (peer-reviewed fisheries textbook)

**MEDIUM confidence sources:**

- [Survey Package Covariances](https://www.practicalsignificance.com/posts/survey-covariances-using-influence-functions/) - Linearization methods for covariance

**Research gaps:**
- Covariance estimation between effort and CPUE when data sources overlap (assume independence for v0.2.0, document limitation)
- Bootstrap variance for combined estimates (defer to later milestone)
- Multi-species estimation patterns (defer to v0.3.0)

---
*Architecture research for: tidycreel v0.2.0 interview-based estimation*
*Researched: 2026-02-09*
*Confidence: HIGH (survey package methods well-established, v0.1.0 patterns proven)*
