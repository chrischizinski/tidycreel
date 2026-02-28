# Stack Research: Interview-Based Catch/Harvest Estimation

**Domain:** R package - creel survey interview-based estimation (v0.2.0)
**Researched:** 2026-02-09
**Confidence:** HIGH

## Executive Summary

**NO new dependencies required** for interview-based catch/harvest estimation. The existing survey package (v4.4.2) provides all necessary ratio estimation capabilities via `svyratio()` and `svyby()`. Interview-based features (CPUE, total catch, harvest) are a **new application of existing infrastructure**, not new stack requirements.

## Existing Stack Remains Sufficient

### Core Foundation (Already in DESCRIPTION)

| Technology | Current Version | Purpose | Why Sufficient for v0.2.0 |
|------------|----------------|---------|---------------------------|
| R | >= 4.1.0 | Base environment | No new language features required |
| survey | 4.4.2 | Design-based inference | **`svyratio()` provides ratio-of-means and mean-of-ratios estimators for CPUE** |
| tidyselect | 1.2.1 | Column selection API | Already used in `by=` parameter, extends naturally to interview columns |
| dplyr | 1.1.4 | Data manipulation (internal) | May need for interview data joins, already available |
| rlang | 1.1.7 | Tidy evaluation | Already used for quosures, no additions needed |
| tibble | 3.3.0 | Data frame output | Already used for estimates, continues for CPUE/catch |
| checkmate | 2.3.2 | Progressive validation | Extends to interview data validation (Tier 1/2) |
| cli | 3.6.5 | User messages | Extends to interview-specific error guidance |

### Supporting Libraries (Already in DESCRIPTION)

| Library | Purpose | Interview Usage |
|---------|---------|-----------------|
| testthat | >= 3.0.0 | Unit testing | Reference tests for ratio estimation |
| knitr | Vignettes | Interview examples in vignettes |
| covr | Test coverage | Maintain 85%+ with new estimation functions |

## Survey Package Ratio Estimation Capabilities

The survey package **already provides** the statistical machinery needed for interview-based estimation:

### `svyratio()` - Core CPUE Estimator

**What it does:** Computes ratio estimators (y/x) with proper variance for complex survey designs. This is exactly CPUE = catch/effort.

**Design-based correctness:**
- Ratio-of-means: `svyratio(~catch, ~effort, design)` - preferred for complete trips
- Mean-of-ratios: `svymean(~I(catch/effort), design)` - alternative for some designs
- Variance via Taylor linearization (default), bootstrap, or jackknife (already implemented in v0.1.0)
- Handles stratification, clustering, and multi-stage designs automatically

**Integration with existing architecture:**
```r
# User API (new)
estimate_cpue(design_with_interviews, variance = "taylor")

# Orchestration layer (new function)
estimate_cpue_total <- function(design, variance_method, conf_level) {
  svy_design <- get_variance_design(design$survey, variance_method)  # Reuse Phase 6
  ratio_result <- survey::svyratio(~catch, ~effort, svy_design)
  # Extract and format as creel_estimates object
}
```

**No new dependencies needed** - `svyratio()` has been in survey package since early versions, stable API.

### `svyby()` - Grouped CPUE Estimation

**What it does:** Domain estimation for ratios - CPUE by stratum, species, location, etc.

**Already proven in v0.1.0:** Phase 5 uses `svyby()` for grouped effort estimation. Same pattern extends to grouped CPUE:
```r
svyby(~catch, by = ~stratum, design = svy, FUN = svyratio, denom = ~effort)
```

**No new capabilities required** - reuse Phase 5 architectural pattern.

## What NOT to Add

| Avoid | Why | Rationale |
|-------|-----|-----------|
| srvyr | Adds dplyr verbs for survey objects | **Not needed** - tidycreel already provides tidy API via tidyselect. Users never touch survey objects directly. Adding srvyr would be redundant and increase maintenance burden. |
| FSA (Fisheries Stock Assessment) | Species-specific analysis tools | **Out of scope** - tidycreel is survey statistics, not biological stock assessment. FSA functions (e.g., PSD, mortality) belong in domain-specific packages that build on tidycreel. |
| Hmisc | Data manipulation utilities | **Already have** - dplyr, checkmate, cli provide what we need. Hmisc is heavyweight and overlaps existing stack. |
| plyr | Legacy data manipulation | **Superseded by dplyr** - dplyr (already imported) is modern successor. plyr would add technical debt. |
| Custom ratio estimators | Reinventing survey package | **Anti-pattern** - survey package ratio estimation is peer-reviewed, tested, and correct. Reimplementing would introduce bugs and maintenance burden. |

## Architectural Integration Points

### Three-Layer Architecture (Proven in v0.1.0)

**Layer 1: User API** (NEW for v0.2.0)
- `add_interviews(design, interviews, psu = date)` - attach interview data to design
- `estimate_cpue(design, variance = "taylor", conf_level = 0.95)` - ratio estimation
- `estimate_catch(design, variance = "taylor", conf_level = 0.95)` - total catch = effort × CPUE
- `estimate_harvest(design, variance = "taylor", conf_level = 0.95)` - kept fish only

**Layer 2: Orchestration** (EXTENDS Phase 4/5/6 patterns)
- Reuse `get_variance_design()` from Phase 6 (bootstrap/jackknife support)
- Reuse routing pattern from Phase 5 (`quo_is_null(by_quo)` for grouped vs ungrouped)
- Reuse validation pattern from Phase 3 (Tier 1: structure, Tier 2: data quality)
- NEW: Join interview data with count data on design keys (date, strata)
- NEW: Handle complete vs incomplete trip indicators (separate functions or parameter)

**Layer 3: Survey Package** (NO CHANGES)
- `svyratio()` - CPUE estimation
- `svyby()` - grouped CPUE estimation
- `svytotal()` - total catch (multiply CPUE × effort internally)
- `as.svrepdesign()` - variance method conversion (already used)

### Data Flow for Interview-Based Estimation

```
creel_design (Phase 2)
    ↓
+ add_counts() → design$counts, design$survey (Phase 3)
    ↓
+ add_interviews() → design$interviews (NEW Phase, v0.2.0)
    ↓ (join counts + interviews on date/strata)
    ↓
estimate_cpue() → svyratio(~catch, ~effort)
    ↓
estimate_catch() → svytotal(~catch) or CPUE × effort with delta method
    ↓
creel_estimates (Phase 4, extend with new methods)
```

## Installation

**NO changes required to DESCRIPTION Imports** - all capabilities already present.

```r
# Phase verification after implementing interview features
devtools::check()  # Should still pass with 0 errors, 0 warnings
sessionInfo()      # Verify no new package dependencies loaded
```

## Alternatives Considered

| Decision | Alternative | Why Alternative NOT Used |
|----------|-------------|--------------------------|
| Use survey::svyratio() | Implement custom ratio estimator | survey package implementation is peer-reviewed, handles edge cases, includes correct variance formulas. Custom implementation would be error-prone. |
| Reuse get_variance_design() | Add separate variance logic for CPUE | **DRY principle** - variance method (Taylor/bootstrap/jackknife) works identically for ratios. Reusing Phase 6 helper ensures consistency. |
| Add interviews via add_interviews() | Extend add_counts() with interview columns | **Separation of concerns** - counts and interviews are distinct data sources with different validation requirements. Separate functions maintain clarity. |
| No new dependencies | Add srvyr for dplyr-like survey API | tidycreel's value is domain translation (creel vocabulary), not dplyr verbs. srvyr would confuse the API (users would see survey objects). |

## What Makes Interview Estimation Different

Interview-based estimation is **NOT a stack change** - it's a **new application pattern** using existing survey package capabilities:

| Existing Pattern (v0.1.0) | Interview Pattern (v0.2.0) |
|---------------------------|----------------------------|
| `svytotal(~count, design)` | `svyratio(~catch, ~effort, design)` |
| Count variable auto-detected | Catch/effort variables specified by user or auto-detected |
| Single data source (counts) | Two data sources (counts + interviews), joined internally |
| Estimates: total, SE, CI | Estimates: ratio (CPUE), total (catch), SE, CI |
| Tier 2: zero counts, sparse strata | Tier 2: zero catch, incomplete trips, sparse interviews |

**Same infrastructure, different estimand.**

## Stack Patterns for Interview Features

### Pattern 1: Data Source Join (Orchestration Layer)

Interviews and counts reference the same design (date, strata). Orchestration layer joins them:

```r
# Internal to add_interviews()
design$counts  # Already has: date, strata, count
design$interviews  # New: date, strata, catch, effort, trip_complete

# Join on date + strata keys
combined <- merge(design$counts, design$interviews, by = c("date", "strata"))

# Update design$survey to include interview variables
design$survey <- survey::svydesign(
  ids = ~psu, strata = ~strata_interaction, data = combined, nest = TRUE
)
```

**No new packages needed** - base::merge() or dplyr::left_join() (already available).

### Pattern 2: Ratio Estimation (Survey Bridge Layer)

Reuse variance method pattern from Phase 6:

```r
# estimate_cpue_total() - internal function
estimate_cpue_total <- function(design, variance_method, conf_level) {
  svy_design <- get_variance_design(design$survey, variance_method)  # Phase 6 helper

  # survey::svyratio() - NO NEW DEPENDENCY
  ratio_result <- suppressWarnings(
    survey::svyratio(numerator = ~catch, denominator = ~effort, design = svy_design)
  )

  # Extract estimate, SE, CI
  cpue_estimate <- as.numeric(coef(ratio_result))
  cpue_se <- as.numeric(survey::SE(ratio_result))
  cpue_ci <- confint(ratio_result, level = conf_level)

  # Return creel_estimates object (Phase 4 S3 class)
  new_creel_estimates(
    estimates = tibble::tibble(
      cpue = cpue_estimate, se = cpue_se,
      ci_lower = cpue_ci[1,1], ci_upper = cpue_ci[1,2], n = nrow(design$interviews)
    ),
    method = "cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level
  )
}
```

**Pattern already proven in Phase 4 (estimate_effort_total) - just different survey function.**

### Pattern 3: Delta Method for Total Catch

Total catch = effort × CPUE requires delta method for variance (product of two random variables).

**Survey package already handles this** via `predict.svyratio()`:

```r
# Total catch estimation
total_effort <- svytotal(~count, design)  # Phase 4 logic
cpue <- svyratio(~catch, ~effort, design)  # Phase 8 logic

# Delta method for variance of product (effort × CPUE)
total_catch <- predict(cpue, total = total_effort)
# Returns point estimate + SE accounting for covariance
```

**No new dependency** - delta method built into survey::predict.svyratio().

## Version Compatibility

| Package | Current | Required | Notes |
|---------|---------|----------|-------|
| survey | 4.4.2 | >= 4.0 | svyratio() stable since early versions; 4.4.2 includes performance improvements |
| tidyselect | 1.2.1 | >= 1.2.0 | Already specified in DESCRIPTION; no change needed |
| dplyr | 1.1.4 | No min specified | May use for interview/count joins; already in Imports (via tibble pipeline) |
| rlang | 1.1.7 | No min specified | Already used for quosures; no new requirements |
| checkmate | 2.3.2 | No min specified | Extends to interview validation; compatible with existing patterns |
| cli | 3.6.5 | No min specified | Extends to interview error messages; compatible with existing patterns |

**No version bumps required** - all packages at compatible current versions.

## Verification Checklist

Before committing v0.2.0 stack decisions:

- [x] Confirmed survey::svyratio() provides ratio-of-means estimation (CPUE)
- [x] Confirmed survey::svyby() works with svyratio() for grouped CPUE
- [x] Confirmed get_variance_design() from Phase 6 applies to ratio estimation
- [x] Confirmed delta method available via predict.svyratio() for total catch
- [x] Verified no new Imports needed in DESCRIPTION
- [x] Checked all current package versions are compatible
- [x] Confirmed three-layer architecture extends naturally to interviews
- [x] Validated pattern reuse from Phases 3-6 (validation, routing, variance)

## Rationale Summary

**Why zero new dependencies:**

1. **survey::svyratio() is exactly CPUE estimation** - ratio of two survey variables with correct variance. This is the peer-reviewed, tested implementation used across epidemiology, economics, and fisheries statistics.

2. **Phase 6 already abstracts variance methods** - `get_variance_design()` converts to bootstrap/jackknife for any estimator. Ratios work identically to totals.

3. **Phase 5 already patterns grouped estimation** - `svyby()` with domain estimation extends from totals to ratios via FUN parameter.

4. **Phase 3 already patterns data attachment** - `add_counts()` established the pattern of attaching data → constructing survey design. `add_interviews()` follows identical pattern with join step.

5. **Existing validation framework extends** - Tier 1 (structure), Tier 2 (data quality) already established in Phases 3-4. Interview validation adds checks (e.g., "trip_complete missing", "negative catch") using existing checkmate + cli infrastructure.

**The value of v0.2.0 is in domain translation, not new statistical capabilities.** Users call `estimate_cpue()` using creel vocabulary; package translates to `svyratio(~catch, ~effort)` and formats results with creel context (CPUE in fish/hour, total catch with SE/CI). The survey package already has the math.

## Sources

**HIGH Confidence (Official R Package Documentation):**
- [R: Ratio estimation - survey package](https://r-survey.r-forge.r-project.org/survey/html/svyratio.html) - svyratio() documentation
- [Package 'survey' August 28, 2025](https://cran.r-project.org/web/packages/survey/survey.pdf) - Current CRAN version reference
- [Survey analysis in R](https://r-survey.r-forge.r-project.org/survey/) - Survey package homepage
- [How can I do ratio estimation with survey data? | R FAQ](https://stats.oarc.ucla.edu/r/faq/how-can-i-do-ratio-estimation-with-survey-data/) - UCLA practical guide

**MEDIUM Confidence (Domain Literature):**
- Creel foundations document (tidycreel repository) - Confirms ratio-of-means for CPUE
- Creel effort estimation methods (tidycreel repository) - Describes survey package patterns
- Sample interviews.csv (tidycreel repository) - Shows data structure: catch, effort, trip_complete

**Package Versions (Verified via installed packages 2026-02-09):**
- survey: 4.4.2
- tidyselect: 1.2.1
- dplyr: 1.1.4
- rlang: 1.1.7
- tibble: 3.3.0
- checkmate: 2.3.2
- cli: 3.6.5

---
*Stack research for: tidycreel v0.2.0 interview-based estimation*
*Researched: 2026-02-09*
*Conclusion: NO new dependencies required - existing survey package provides all needed capabilities*
