# Ground-Up Survey Package Integration Design

## Design Philosophy

**CORE PRINCIPLE**: Survey package integration should be NATIVE to tidycreel functions, not bolted on through wrappers or enhancement layers.

## Architecture Overview

### 1. Core Variance Engine (`R/variance-engine.R`)

A single, centralized variance calculation engine that ALL estimators use:

```r
#' Core Variance Calculation Engine
#'
#' Single source of truth for ALL variance calculations in tidycreel.
#' Replaces ad-hoc variance calculations scattered across estimators.
#'
#' @param design Survey design object
#' @param response Response variable (formula or character)
#' @param method Variance estimation method:
#'   - "survey" (default): Standard survey package variance
#'   - "svyrecvar": survey:::svyrecvar (most accurate for complex designs)
#'   - "bootstrap": Bootstrap resampling
#'   - "jackknife": Jackknife resampling
#'   - "linearization": Taylor linearization
#' @param by Grouping variables for stratified estimation
#' @param conf_level Confidence level (default 0.95)
#' @param n_replicates For bootstrap/jackknife (default 1000)
#'
#' @return List with: estimate, variance, se, ci_lower, ci_upper, deff, method_info
#' @keywords internal
tc_compute_variance <- function(design,
                                response,
                                method = "survey",
                                by = NULL,
                                conf_level = 0.95,
                                n_replicates = 1000) {

  # Single implementation that ALL estimators call
  # Handles ALL variance methods internally
  # Returns consistent output structure
}
```

### 2. Rebuilt Core Estimators

Each estimator function rebuilt with native survey integration:

```r
#' Instantaneous Effort Estimator (Rebuilt)
#'
#' NOW WITH NATIVE SURVEY INTEGRATION - NO WRAPPERS
#'
#' @param counts Count data
#' @param by Grouping variables
#' @param svy Survey design
#' @param variance_method Variance method: "survey", "svyrecvar", "bootstrap", "jackknife"
#' @param decompose_variance Logical, whether to decompose variance components
#' @param design_diagnostics Logical, whether to compute design diagnostics
#' @param conf_level Confidence level
#'
#' @return Tibble with COMPLETE variance information built-in
est_effort.instantaneous <- function(
  counts,
  by = c("date", "location"),
  svy = NULL,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  conf_level = 0.95,
  ...
) {

  # 1. Data preparation (existing logic)
  day_totals <- ...

  # 2. Survey design handling (existing logic)
  if (is.null(svy)) {
    svy <- as_day_svydesign(day_totals, ...)
  }

  # 3. CORE VARIANCE CALCULATION using tc_compute_variance()
  # This is where the magic happens - ONE unified call
  variance_result <- tc_compute_variance(
    design = svy,
    response = "effort_day",
    method = variance_method,
    by = by,
    conf_level = conf_level
  )

  # 4. Variance decomposition if requested
  if (decompose_variance) {
    variance_result$decomposition <- tc_decompose_variance(
      design = svy,
      response = "effort_day",
      cluster_vars = c("stratum", day_id)
    )
  }

  # 5. Design diagnostics if requested
  if (design_diagnostics) {
    variance_result$diagnostics <- tc_design_diagnostics(svy)
  }

  # 6. Return clean, comprehensive result
  result <- tibble(
    !!!by_cols,
    estimate = variance_result$estimate,
    se = variance_result$se,
    ci_low = variance_result$ci_lower,
    ci_high = variance_result$ci_upper,
    deff = variance_result$deff,
    n = ...,
    method = variance_method,
    variance_info = list(variance_result)
  )

  class(result) <- c("tc_estimate", "tbl_df", "tbl", "data.frame")
  return(result)
}
```

### 3. Unified Helper Functions (`R/survey-utils.R`)

All survey package interactions centralized:

```r
# Core variance engine
tc_compute_variance()      # THE variance calculation function

# Variance methods (called by tc_compute_variance)
.tc_variance_survey()      # Standard survey package
.tc_variance_svyrecvar()   # survey:::svyrecvar
.tc_variance_bootstrap()   # Bootstrap resampling
.tc_variance_jackknife()   # Jackknife resampling

# Decomposition
tc_decompose_variance()    # Variance component decomposition

# Diagnostics
tc_design_diagnostics()    # Design quality assessment
tc_calculate_deff()        # Design effects

# Survey internals access
.tc_access_svyrecvar()     # Access survey:::svyrecvar
.tc_access_multistage()    # Access survey:::multistage
.tc_access_onestage()      # Access survey:::onestage
```

## Implementation Strategy

### Phase 1: Core Infrastructure (Week 1)

**1.1 Create Core Variance Engine** (`R/variance-engine.R`)
```r
# tc_compute_variance() - THE variance function
# .tc_variance_survey()
# .tc_variance_svyrecvar()
# .tc_variance_bootstrap()
# .tc_variance_jackknife()
```

**1.2 Create Decomposition Engine** (`R/variance-decomposition-engine.R`)
```r
# tc_decompose_variance() - rebuilt from ground up
# .tc_decompose_components()
# .tc_calculate_icc()
# .tc_optimal_allocation()
```

**1.3 Create Diagnostics Engine** (`R/survey-diagnostics.R`)
```r
# tc_design_diagnostics()
# tc_calculate_deff()
# tc_extract_design_info()
```

### Phase 2: Rebuild Core Estimators (Week 2-3)

**2.1 Rebuild Effort Estimators**
- `est_effort.instantaneous()` - REBUILT with native integration
- `est_effort.progressive()` - REBUILT with native integration
- `est_effort.aerial()` - REBUILT with native integration
- `est_effort.busroute_design()` - REBUILT with native integration

**2.2 Rebuild CPUE/Harvest Estimators**
- `aggregate_cpue()` - REBUILT with native integration
- `est_cpue()` - REBUILT with native integration
- `est_total_harvest()` - REBUILT with native integration

**Key Changes to Each Estimator:**
1. Add `variance_method` parameter
2. Add `decompose_variance` parameter
3. Add `design_diagnostics` parameter
4. Replace direct `survey::svytotal()` calls with `tc_compute_variance()`
5. Add variance decomposition logic if requested
6. Add diagnostics logic if requested
7. Return comprehensive results with variance_info list-column

### Phase 3: Clean Up (Week 4)

**3.1 Remove Patch Files**
Delete all temporary integration files:
- `R/survey-enhanced-integration.R` ❌
- `R/estimators-integration.R` ❌
- `R/survey-internals-integration.R` ❌
- `R/survey-internals-integration-fixed.R` ❌
- `R/survey-integration-example.R` ❌
- `R/survey-integration-phase2-example.R` ❌
- `R/estimators-enhanced.R` ❌
- All integration demo files ❌

**3.2 Update Documentation**
- Comprehensive vignette: "Advanced Variance Methods in tidycreel"
- Update all estimator documentation
- Create migration guide from old "wrapper" approach

**3.3 Comprehensive Testing**
- Test all variance methods with real data
- Compare results with survey package directly
- Validate variance decomposition accuracy
- Test all estimators with all variance methods

## API Design

### User-Facing API (Clean & Intuitive)

**Basic Usage (Default):**
```r
# Standard variance (current behavior maintained)
result <- est_effort.instantaneous(counts, svy = design)
```

**Advanced Variance Methods:**
```r
# Bootstrap variance
result <- est_effort.instantaneous(
  counts,
  svy = design,
  variance_method = "bootstrap",
  n_replicates = 2000
)

# Survey internals (most accurate)
result <- est_effort.instantaneous(
  counts,
  svy = design,
  variance_method = "svyrecvar"
)
```

**Variance Decomposition:**
```r
# With decomposition
result <- est_effort.instantaneous(
  counts,
  svy = design,
  variance_method = "svyrecvar",
  decompose_variance = TRUE  # Adds variance components
)

# Access decomposition
result$variance_info[[1]]$decomposition
```

**Complete Analysis:**
```r
# Everything together
result <- est_effort.instantaneous(
  counts,
  svy = design,
  variance_method = "svyrecvar",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)

# Rich output with all information
print(result)
summary(result)
plot(result)  # Variance component plots
```

## Output Structure

All estimators return consistent structure:

```r
tibble(
  # Grouping columns (date, location, etc.)
  ...,

  # Core estimates
  estimate = <numeric>,
  se = <numeric>,
  ci_low = <numeric>,
  ci_high = <numeric>,

  # Design information
  deff = <numeric>,
  n = <integer>,

  # Method metadata
  method = <character>,

  # Complete variance information (list-column)
  variance_info = list(
    variance = <numeric>,
    method = <character>,
    method_details = list(...),
    decomposition = <data.frame> or NULL,
    diagnostics = <list> or NULL,
    design_effects = <data.frame>,
    ...
  )
)
```

## Benefits of Ground-Up Approach

### 1. **Simplicity**
- ONE function call, not multiple wrappers
- Clear, intuitive parameters
- Consistent API across all estimators

### 2. **Performance**
- No wrapper overhead
- Optimized variance calculations
- Efficient internals access

### 3. **Maintainability**
- Single variance engine to maintain
- No coordination between wrapper layers
- Clear code organization

### 4. **Extensibility**
- Easy to add new variance methods
- Easy to add new estimators
- Clean extension points

### 5. **User Experience**
- Natural parameter names
- Comprehensive documentation
- Rich, informative output

## Migration Path

### For Users

**Old Approach (Patch):**
```r
# Compute base estimate
base_result <- est_effort.instantaneous(counts, svy = design)

# Add enhanced variance (wrapper)
enhanced <- add_enhanced_variance(
  base_result,
  design,
  "effort",
  variance_method = "svyrecvar"
)
```

**New Approach (Native):**
```r
# Everything in one call
result <- est_effort.instantaneous(
  counts,
  svy = design,
  variance_method = "svyrecvar"
)
```

### For Developers

**Old Structure:**
```
Core Estimator
  ↓
Wrapper Function (add_enhanced_variance)
  ↓
Survey Internals
  ↓
Survey Package
```

**New Structure:**
```
Core Estimator (with native parameters)
  ↓
Core Variance Engine (tc_compute_variance)
  ↓
Survey Package (internals and public API)
```

## Success Criteria

### Technical
- ✅ Zero wrapper functions
- ✅ All estimators use tc_compute_variance()
- ✅ All variance methods work for all estimators
- ✅ Variance decomposition integrated natively
- ✅ Design diagnostics integrated natively
- ✅ 100% backward compatible (default behavior unchanged)

### User Experience
- ✅ Single function call for advanced features
- ✅ Intuitive parameter names
- ✅ Rich, informative output
- ✅ Comprehensive documentation
- ✅ Clear migration guide

### Code Quality
- ✅ DRY (Don't Repeat Yourself) - ONE variance engine
- ✅ Clean architecture (no wrappers)
- ✅ Well-tested (>90% coverage)
- ✅ Fully documented

## Next Steps

1. **Create `R/variance-engine.R`** with `tc_compute_variance()`
2. **Create `R/variance-decomposition-engine.R`** rebuilt from scratch
3. **Create `R/survey-diagnostics.R`** for design diagnostics
4. **Rebuild `est_effort.instantaneous()`** as proof of concept
5. **Test and validate** the new approach
6. **Rebuild remaining estimators** following the same pattern
7. **Delete all patch files**
8. **Comprehensive testing and documentation**

---

*This design ensures tidycreel has world-class survey package integration built into its DNA, not bolted on as an afterthought.*
