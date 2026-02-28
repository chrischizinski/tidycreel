# Architectural Standards for tidycreel

## 🎯 Core Principle: Single Source of Truth

**RULE #1**: There shall be ONE and ONLY ONE way to compute variance in tidycreel.

All variance calculations MUST use `tc_compute_variance()`. No exceptions.

## Preventing Divergence: Enforcement Strategy

### 1. Replace, Don't Add

**WRONG** ❌:
```r
# Creating parallel implementations
est_effort.instantaneous()          # Old version
est_effort.instantaneous_rebuilt()  # New version  <- DIVERGENCE!
est_effort.instantaneous_enhanced() # Another version <- MORE DIVERGENCE!
```

**CORRECT** ✅:
```r
# Replace the old function entirely
est_effort.instantaneous()  # The ONLY version (rebuilt internally)
```

### 2. Deprecation Protocol

When rebuilding a function:

**Step 1**: Create `_v2` version for testing
```r
# R/est-effort-instantaneous-v2.R
est_effort.instantaneous_v2 <- function(...) {
  # New implementation
}
```

**Step 2**: Test thoroughly, ensure backward compatibility

**Step 3**: Replace original file COMPLETELY
```r
# R/est-effort-instantaneous.R
# DELETE OLD CODE ENTIRELY
# PASTE NEW CODE
est_effort.instantaneous <- function(...) {
  # New implementation (was _v2)
}
```

**Step 4**: Delete the `_v2` file
```bash
rm R/est-effort-instantaneous-v2.R
```

**NO PARALLEL VERSIONS ALLOWED**

### 3. Wrapper Function Ban

**BANNED PATTERN** ❌:
```r
# NO wrapper functions that add features
add_enhanced_variance <- function(result, ...) {
  # Wraps existing result
}

enhance_estimator <- function(estimator_function, ...) {
  # Wraps existing function
}
```

**REQUIRED PATTERN** ✅:
```r
# Features built-in to the function
est_effort.instantaneous <- function(
  ...,
  variance_method = "survey",      # Built-in
  decompose_variance = FALSE,      # Built-in
  design_diagnostics = FALSE       # Built-in
) {
  # All features implemented directly
}
```

### 4. Patch File Ban

**BANNED** ❌:
```r
# R/xxx-integration.R        <- No "integration" files
# R/xxx-enhanced.R           <- No "enhanced" files
# R/xxx-internals-access.R   <- No "internals access" files
# R/xxx-patch.R              <- No "patch" files
# R/xxx-wrapper.R            <- No "wrapper" files
```

**ALLOWED** ✅:
```r
# R/variance-engine.R        <- Core engine
# R/est-effort-xxx.R         <- Actual estimators
# R/survey-diagnostics.R     <- Core utilities
```

### 5. Mandatory Code Review Checklist

Before merging ANY PR, verify:

- [ ] Does this create a wrapper function? → **REJECT**
- [ ] Does this create an "enhanced" version? → **REJECT**
- [ ] Does this add a `-integration` or `-patch` file? → **REJECT**
- [ ] Does variance calculation bypass `tc_compute_variance()`? → **REJECT**
- [ ] Does this create parallel implementations? → **REJECT**
- [ ] Are all features built-in to the function? → **REQUIRE**
- [ ] Is there only ONE way to do this? → **REQUIRE**

### 6. File Naming Standards

**Core Infrastructure** (These define the architecture):
```
R/variance-engine.R                  ✅ Core variance calculations
R/variance-decomposition-engine.R    ✅ Core decomposition
R/survey-diagnostics.R               ✅ Core diagnostics
R/utils-survey.R                     ✅ Survey utilities
```

**Estimator Functions** (These use the infrastructure):
```
R/est-effort-instantaneous.R         ✅ Estimator implementation
R/est-effort-progressive.R           ✅ Estimator implementation
R/aggregate-cpue.R                   ✅ Estimator implementation
```

**BANNED Naming Patterns**:
```
R/xxx-integration.R                  ❌ BANNED
R/xxx-enhanced.R                     ❌ BANNED
R/xxx-wrapper.R                      ❌ BANNED
R/xxx-patch.R                        ❌ BANNED
R/xxx-internals-access.R            ❌ BANNED
R/xxx-helpers.R (unless truly generic) ⚠️ SUSPICIOUS
```

### 7. Function Naming Standards

**Core Infrastructure Functions**:
```r
tc_compute_variance()        ✅ Core engine function
tc_decompose_variance()      ✅ Core engine function
tc_design_diagnostics()      ✅ Core engine function
tc_extract_design_info()     ✅ Core utility function
```

**Estimator Functions**:
```r
est_effort.instantaneous()   ✅ User-facing estimator
est_effort.progressive()     ✅ User-facing estimator
aggregate_cpue()             ✅ User-facing estimator
```

**BANNED Function Patterns**:
```r
add_enhanced_*()             ❌ BANNED (wrapper)
enhance_*()                  ❌ BANNED (wrapper)
*_enhanced()                 ❌ BANNED (creates parallel version)
*_with_internals()           ❌ BANNED (creates parallel version)
*_integration()              ❌ BANNED (patch approach)
```

### 8. Code Pattern Enforcement

**Every Estimator MUST Follow This Pattern**:

```r
est_[method].[type] <- function(
  # Data parameters
  data,
  by = ...,

  # Survey design
  svy = NULL,

  # Standard parameters
  conf_level = 0.95,

  # BUILT-IN variance features
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
) {

  # 1. Input validation
  # 2. Data preparation
  # 3. Survey design handling

  # 4. MANDATORY: Use tc_compute_variance()
  variance_result <- tc_compute_variance(
    design = design,
    response = response_var,
    method = variance_method,
    by = by,
    conf_level = conf_level,
    n_replicates = n_replicates
  )

  # 5. OPTIONAL: Decomposition if requested
  if (decompose_variance) {
    variance_result$decomposition <- tc_decompose_variance(...)
  }

  # 6. OPTIONAL: Diagnostics if requested
  if (design_diagnostics) {
    variance_result$diagnostics <- tc_design_diagnostics(...)
  }

  # 7. Build standard output with variance_info
  result <- tibble(
    ...,
    estimate = variance_result$estimate,
    se = variance_result$se,
    ci_low = variance_result$ci_lower,
    ci_high = variance_result$ci_upper,
    deff = variance_result$deff,
    variance_info = list(variance_result)
  )

  return(result)
}
```

**ANY deviation from this pattern should be questioned.**

### 9. Testing Requirements

**Test That Enforces Architecture**:

```r
test_that("all estimators use tc_compute_variance", {
  # This test FORCES use of core engine

  # Mock tc_compute_variance to track calls
  call_count <- 0
  mockery::stub(
    est_effort.instantaneous,
    "tc_compute_variance",
    function(...) {
      call_count <<- call_count + 1
      # Return mock result
    }
  )

  # Call estimator
  result <- est_effort.instantaneous(data, svy = design)

  # MUST have called tc_compute_variance
  expect_true(call_count > 0,
    "Estimator must use tc_compute_variance(), not direct survey calls"
  )
})
```

**Test ALL Estimators This Way**:
```r
# tests/testthat/test-architectural-compliance.R

test_that("est_effort.instantaneous uses core engine", {
  verify_uses_core_engine("est_effort.instantaneous")
})

test_that("est_effort.progressive uses core engine", {
  verify_uses_core_engine("est_effort.progressive")
})

# ... for ALL estimators
```

### 10. Documentation Requirements

**Every Estimator Documentation MUST Include**:

```r
#' @details
#' ## Variance Estimation
#'
#' This function uses the core tidycreel variance engine (`tc_compute_variance()`)
#' to ensure consistent, accurate variance estimation across all methods.
#'
#' Available variance methods:
#' - `"survey"`: Standard survey package variance (default)
#' - `"svyrecvar"`: Survey package internals (maximum accuracy)
#' - `"bootstrap"`: Bootstrap resampling
#' - `"jackknife"`: Jackknife resampling
#'
#' ## Architecture Note
#'
#' All tidycreel estimators follow a unified architecture:
#' 1. Data preparation
#' 2. Survey design handling
#' 3. **Core variance calculation via `tc_compute_variance()`**
#' 4. Optional variance decomposition
#' 5. Optional design diagnostics
#' 6. Standardized output with `variance_info`
```

### 11. Git Pre-commit Hook

**`.git/hooks/pre-commit`**:
```bash
#!/bin/bash

# Check for banned patterns
echo "Checking for architectural violations..."

# Check for banned file names
if git diff --cached --name-only | grep -E "integration|enhanced|wrapper|patch|internals-access"; then
    echo "❌ ERROR: Banned file naming pattern detected"
    echo "Files with 'integration', 'enhanced', 'wrapper', 'patch', or 'internals-access' are not allowed"
    exit 1
fi

# Check for banned function patterns in R files
if git diff --cached --name-only | grep "\.R$"; then
    if git diff --cached | grep -E "add_enhanced_|enhance_|_enhanced\(|_with_internals\(|_integration\("; then
        echo "❌ ERROR: Banned function naming pattern detected"
        echo "Wrapper functions like 'add_enhanced_*', 'enhance_*' are not allowed"
        echo "Features must be built-in to estimator functions"
        exit 1
    fi
fi

echo "✅ Architectural standards check passed"
```

**Install it**:
```bash
chmod +x .git/hooks/pre-commit
```

### 12. CI/CD Enforcement

**`.github/workflows/architectural-compliance.yml`**:
```yaml
name: Architectural Compliance

on: [pull_request]

jobs:
  check-architecture:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Check for banned file patterns
        run: |
          if find R/ -name "*-integration.R" -o -name "*-enhanced.R" -o -name "*-wrapper.R" -o -name "*-patch.R"; then
            echo "❌ Banned file naming patterns detected"
            exit 1
          fi

      - name: Check for wrapper functions
        run: |
          if grep -r "add_enhanced_\|enhance_\|_enhanced(\|_with_internals(" R/; then
            echo "❌ Banned function patterns detected"
            exit 1
          fi

      - name: Check estimators use core engine
        run: |
          # Check that est_* functions call tc_compute_variance
          for file in R/est-*.R; do
            if ! grep -q "tc_compute_variance" "$file"; then
              echo "❌ $file does not use tc_compute_variance()"
              exit 1
            fi
          done

      - name: All checks passed
        run: echo "✅ Architectural compliance verified"
```

### 13. CONTRIBUTING.md Guidelines

**Add to `CONTRIBUTING.md`**:

```markdown
## Architectural Standards

### Single Source of Truth
All variance calculations MUST use `tc_compute_variance()`. Do not:
- Create wrapper functions
- Add "enhanced" versions of existing functions
- Create parallel implementations
- Bypass the core variance engine

### Adding Features
Features should be added as BUILT-IN parameters to estimator functions:

✅ **CORRECT**:
```r
est_effort.instantaneous(
  ...,
  variance_method = "bootstrap"  # Built-in parameter
)
```

❌ **WRONG**:
```r
result <- est_effort.instantaneous(...)
result_enhanced <- add_bootstrap_variance(result)  # Wrapper function
```

### File Organization
- Core infrastructure: `R/variance-engine.R`, `R/variance-decomposition-engine.R`
- Estimators: `R/est-*.R`, `R/aggregate-*.R`
- NO files named: `*-integration.R`, `*-enhanced.R`, `*-wrapper.R`, `*-patch.R`

### Code Review Requirements
PRs will be rejected if they:
- Create wrapper functions
- Bypass `tc_compute_variance()`
- Create parallel implementations
- Add banned file naming patterns
```

### 14. Immediate Cleanup Checklist

**After rebuilding all estimators, execute this cleanup**:

```bash
#!/bin/bash
# cleanup-patches.sh

echo "🧹 Cleaning up patch files..."

# Delete ALL patch/integration/wrapper files
rm -v R/survey-enhanced-integration.R
rm -v R/estimators-integration.R
rm -v R/survey-internals-integration.R
rm -v R/survey-internals-integration-fixed.R
rm -v R/survey-integration-example.R
rm -v R/survey-integration-phase2-example.R
rm -v R/estimators-enhanced.R

# Delete demo/example files
rm -v INTEGRATION_DEMONSTRATION.R
rm -v SIMPLE_DEMO.R
rm -v R/survey-enhanced-integration-demo.R

# Delete old planning docs
rm -v SURVEY_INTEGRATION_PLAN.md
rm -v CURRENT_INTEGRATION_STATUS.md
rm -v IMMEDIATE_ACTIONS.md

echo "✅ Cleanup complete"
echo "⚠️  Verify git status before committing"
```

## Summary: Preventing Divergence

### The Golden Rules

1. **ONE function per feature** - No parallel implementations
2. **NO wrappers** - Features built-in to functions
3. **ONE variance engine** - `tc_compute_variance()` is the ONLY way
4. **Replace, don't add** - When rebuilding, replace the original
5. **Enforce in CI/CD** - Automated checks prevent violations
6. **Test architecture** - Tests verify use of core engine
7. **Document standards** - Clear guidelines in CONTRIBUTING.md
8. **Pre-commit hooks** - Catch violations before commit
9. **Code review checklist** - Manual verification
10. **Delete patches** - Clean up old approaches completely

### Enforcement Layers

1. **Pre-commit hook** - First line of defense
2. **CI/CD checks** - Automated verification
3. **Unit tests** - Verify architectural compliance
4. **Code review** - Human verification
5. **Documentation** - Clear standards

### Success Criteria

✅ All estimators use `tc_compute_variance()`
✅ No wrapper functions exist
✅ No "integration" or "patch" files exist
✅ No parallel implementations exist
✅ CI/CD enforces architectural standards
✅ Tests verify compliance
✅ Documentation is clear

---

**By following these standards, divergence becomes IMPOSSIBLE rather than unlikely.**
