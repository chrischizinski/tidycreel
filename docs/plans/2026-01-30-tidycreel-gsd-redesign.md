# tidycreel GSD Redesign

**Design Date:** 2026-01-30
**Status:** Validated Design
**Purpose:** Complete architectural redesign of tidycreel using GSD methodology

## Executive Summary

This document outlines a ground-up redesign of tidycreel as a domain-translator package for creel survey analysis, built on the R `survey` package foundation. The design prioritizes production workflows while supporting exploration, uses a design-centric API with tidy selectors, and employs GSD methodology for incremental development with continuous quality gates.

**Core Philosophy:** 90% of users work entirely in creel vocabulary (domain translation), 10% can access underlying survey objects for advanced work (escape hatches).

---

## 1. Architecture Overview

### Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│  User API Layer (Domain Translation)    │
│  - creel_design()                        │
│  - estimate_effort(), estimate_cpue()    │
│  - Creel vocabulary, tidy selectors      │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│  Orchestration Layer (Survey Bridge)     │
│  - Build svydesign/svrepdesign objects   │
│  - Manage multiple designs for hybrids   │
│  - Handle variance method selection      │
│  - Progressive validation                │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│  Survey Package (Statistical Engine)     │
│  - Design-based inference                │
│  - Variance estimation                   │
│  - Calibration, post-stratification      │
└─────────────────────────────────────────┘
```

**Key Principle:** Users interact with layer 1 using creel vocabulary. Layer 2 translates to survey package structures. Layer 3 handles statistical computation. Power users can access layers 2-3 via escape hatches.

### Design Types Supported

All creel survey designs need first-class support:
- Access-point counts (instantaneous)
- Roving/progressive counts
- Aerial surveys (with covariates, post-stratification)
- Bus route designs
- Interview-based designs
- Hybrid designs (combining multiple methods)
- Stratified designs (temporal and spatial)

### Workflow Support

The API must support:
- **Production reporting** (primary use case) - Standardized reports, fixed methods, automation
- **Linear pipelines** - Import → Validate → Design → Estimate → Report
- **Iterative refinement** - Import → Estimate → Check → Fix → Re-estimate
- **Exploratory analysis** - Slice data, compare estimates, visualize patterns

---

## 2. Core Objects & Data Structures

### Primary Objects

**1. `creel_design` (Central Object)**
- Created by `creel_design(calendar, ...)`
- Contains: calendar/sampling frame, design metadata, internal survey designs
- Methods: `add_*()`, `estimate_*()`, `validate()`, `as_survey_design()`
- S3 class with print/summary methods

**2. `creel_estimates` (Results)**
- Returned by `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()`
- Contains: estimates, standard errors, confidence intervals, sample sizes
- Attributes: variance method used, grouping variables, design metadata
- Can be piped to plotting functions

**3. `creel_validation` (QA/QC Results)**
- Returned by `validate()` or `qa_check_*()`
- Contains: validation results, warnings, data quality flags
- Can be converted to reports

### Data Inputs

User-provided data:
- **Calendar**: Sampling frame with dates, strata
- **Counts**: Effort count data (instantaneous, progressive, aerial, etc.)
- **Interviews**: Angler interview data (catch, effort, targeting)
- **Covariates**: Optional auxiliary data for calibration/post-stratification

All inputs use **tidy selectors** for column specification (bare names, no quotes).

---

## 3. User-Facing API Design

### Design Construction (Progressive Builder Pattern)

```r
# Start with calendar (sampling frame)
design <- creel_design(
  calendar,
  date = sample_date,
  strata = c(day_type, month),
  site = location_id
)

# Add data sources progressively
design <- design %>%
  add_counts(aerial_counts, method = "aerial",
             count = n_anglers, flight_id = flight) %>%
  add_interviews(interview_data,
                 catch = total_catch, effort = hours_fished) %>%
  add_covariates(weather_data, temp = temperature, wind = wind_speed)
```

### Estimation Functions (Verb-Based, Tidy-Friendly)

```r
# Estimate effort
effort <- design %>%
  estimate_effort(
    by = c(month, location),          # grouping with tidy selectors
    variance = "bootstrap",            # explicit or default
    conf_level = 0.95
  )

# Estimate CPUE
cpue <- design %>%
  estimate_cpue(
    by = target_species,
    response = catch_kept,             # vs catch_released
    variance = "taylor"                # or let it default
  )

# Estimate total harvest (combines effort + cpue)
harvest <- design %>%
  estimate_harvest(
    effort_from = "aerial",            # which data source
    cpue_from = "interview"
  )
```

### API Principles

- Pipe-friendly (`%>%` compatibility)
- Tidy selectors for columns (bare names, consistent with dplyr)
- Explicit grouping with `by = `
- Variance methods visible but with smart defaults
- Works interactively and in production scripts

---

## 4. Progressive Validation & Error Handling

### Three Validation Tiers

**Tier 1: Design Creation (Immediate, Fatal Errors)**
```r
design <- creel_design(calendar, date = sample_date, strata = day_type)
# Checks at creation:
# - Required columns exist
# - Date column is valid date format
# - No duplicate dates within strata
# - Calendar has at least one sampling day
# → Fails fast with clear error messages
```

**Tier 2: Estimation (Automatic Warnings)**
```r
effort <- design %>% estimate_effort()
# Checks during estimation:
# - Zero/negative effort values (warn + flag)
# - Sparse strata (< 3 observations, warn)
# - Missing data patterns (inform user)
# - Variance method compatibility (fallback with message)
# → Prints warnings but completes estimation
# → Stores warnings in results: attr(effort, "warnings")
```

**Tier 3: Deep Diagnostics (Optional, On-Demand)**
```r
# Explicit QA/QC checks
design %>% validate_data()  # Runs all checks, returns report

# Or individual checks for exploration
design %>% qa_check_effort()          # Outlier detection
design %>% qa_check_temporal()        # Coverage gaps
design %>% qa_check_spatial()         # Spatial balance
design %>% qa_check_zeros(threshold = 0.3)  # Zero inflation
```

### Error Philosophy

- **Error** = Cannot proceed (missing required data)
- **Warning** = Proceed with caution (data quality issue)
- **Message** = Informational (using default method)
- All validation results are **stored** in objects for reproducibility

---

## 5. Variance Estimation (Layered Approach)

### Progressive Disclosure of Complexity

```r
# Beginner - works, but shows what it's doing
effort <- estimate_effort(design, counts)
# Prints: "Using Taylor linearization (default for stratified designs)"

# Intermediate - explicit control
effort <- estimate_effort(design, counts, variance = "bootstrap")

# Advanced - full control
effort <- estimate_effort(design, counts,
                         variance = list(type = "bootstrap",
                                       replicates = 1000,
                                       method = "subbootstrap"))

# Power user - direct survey object manipulation
svy <- as_survey_design(design)
svy_custom <- survey::as.svrepdesign(svy, type = "JK1", ...)
estimate_effort(svy_custom, counts)
```

### Implementation Principles

1. **Defaults are visible** - Print methods show what variance method was used
2. **Attributes are stored** - Results include `attr(result, "variance_method")` for reproducibility
3. **Clear documentation** - Each design type documents its default variance method and why
4. **Easy override** - Single parameter to change method
5. **Escape hatch** - Can always drop to survey objects for full control

### Why Not Pure Automatic?

Scientific software requires:
- **Justification** - Users must explain their methods
- **Understanding** - Need to know tradeoffs (Taylor = fast but assumes normality; bootstrap = robust but slow)
- **Debugging** - When estimates seem wrong, must know what's happening

Pure automatic feels like magic. Magic is dangerous in science.

---

## 6. Hybrid Design Implementation

### User View (Simple)

```r
# Users see one unified design
lake_survey <- creel_design(calendar, date = date, strata = c(day_type, month)) %>%
  add_counts(aerial_counts, method = "aerial") %>%
  add_counts(bus_counts, method = "bus_route") %>%
  add_interviews(interviews)

# Estimation just works
lake_survey %>% estimate_effort()  # Combines aerial + bus route
lake_survey %>% estimate_harvest() # Combines effort + interviews
```

### Internal Structure (Hidden)

```r
# creel_design object structure
<creel_design>
  calendar: tibble (sampling frame)
  components: list(
    aerial = list(
      data = <tibble>,
      design = <svydesign>,  # survey package object
      method = "aerial"
    ),
    bus_route = list(
      data = <tibble>,
      design = <svydesign>,
      method = "bus_route"
    ),
    interview = list(
      data = <tibble>,
      design = <svydesign>,
      method = "interview"
    )
  )
  metadata: list(primary_method = "aerial", created = ...)
  validated: TRUE/FALSE
```

### How Estimation Works

1. `estimate_effort()` identifies which components have effort data (aerial, bus_route)
2. Creates combined survey design using `survey::svyby()` or multi-stage approach
3. Computes estimates and combines appropriately (weighted average, post-stratification, etc.)
4. Returns unified `creel_estimates` object

### Key Principle

**Unified interface, modular internals** - Users don't manage multiple design objects. tidycreel orchestrates the complexity. Each data source maintains its own survey design internally.

---

## 7. Power User Escape Hatches

### Accessing Survey Objects

```r
# Get the underlying survey design(s)
svy <- as_survey_design(design)
# Returns: svydesign or svrepdesign object from survey package

# For hybrid designs, get specific components
svy_aerial <- extract_component(design, "aerial")
svy_interview <- extract_component(design, "interview")

# Advanced: manipulate survey object directly
svy_calibrated <- survey::calibrate(
  svy,
  formula = ~ sex + age_group,
  population = census_margins
)

# Pass modified survey object back to tidycreel
estimate_cpue(svy_calibrated, interviews)
```

### Method Dispatch (S3 Magic)

```r
# estimate_*() functions work with BOTH:
estimate_effort(creel_design_object, ...)  # S3: estimate_effort.creel_design
estimate_effort(svydesign_object, ...)     # S3: estimate_effort.survey.design

# This means power users can:
# 1. Extract survey design
# 2. Modify it with survey package functions
# 3. Pass it back to tidycreel estimators
```

### Introspection Functions

```r
# See what's inside a design
design %>% show_components()  # Lists: aerial, interview, bus_route
design %>% show_variance_info()  # Shows default variance methods per component
design %>% show_strata_summary()  # Sample sizes per stratum
```

### When to Use Escape Hatches

- Custom calibration/post-stratification not built into tidycreel
- Exotic variance methods (e.g., paired jackknife)
- Research/methods development
- Debugging estimation issues

**Philosophy:** 90% of users never need this, but 10% absolutely require it for edge cases.

---

## 8. Testing Strategy & Architecture Compliance

### Four Testing Layers

**1. Unit Tests (Component Isolation)**
```r
# Test individual functions in isolation
test_that("creel_design validates date column", {
  expect_error(
    creel_design(bad_calendar, date = not_a_date),
    "date column must be Date type"
  )
})

# Test survey design construction
test_that("aerial design creates correct svydesign object", {
  design <- creel_design(calendar, ...) %>% add_counts(aerial, method = "aerial")
  svy <- extract_component(design, "aerial")
  expect_s3_class(svy, "survey.design")
  expect_equal(svy$strata, expected_strata)
})
```

**2. Integration Tests (Component Interaction)**
```r
# Test full workflows
test_that("aerial + interview hybrid produces correct harvest estimate", {
  design <- creel_design(calendar, ...) %>%
    add_counts(aerial, method = "aerial") %>%
    add_interviews(interviews)

  harvest <- estimate_harvest(design)

  expect_s3_class(harvest, "creel_estimates")
  expect_true(all(harvest$estimate > 0))
  expect_true(all(harvest$se > 0))
})
```

**3. Validation Tests (Data Quality)**
```r
# Test progressive validation catches issues
test_that("zero effort values generate warnings", {
  expect_warning(
    estimate_effort(design_with_zeros),
    "Zero effort values detected"
  )
})
```

**4. Reference Tests (Statistical Correctness)**
```r
# Compare against known results from survey package
test_that("instantaneous effort matches manual survey calculation", {
  # Build survey design manually
  manual_svy <- survey::svydesign(...)
  manual_est <- survey::svymean(~effort, manual_svy)

  # Build with tidycreel
  tidycreel_est <- creel_design(...) %>% estimate_effort()

  # Should match exactly
  expect_equal(tidycreel_est$estimate, coef(manual_est), tolerance = 1e-10)
})
```

### Test Coverage Goals

- **Core estimation functions:** 95%+ coverage
- **Validation functions:** 90%+ coverage
- **Helper/utility functions:** 80%+ coverage
- **Overall package:** 85%+ coverage

---

## 9. Code Quality Gates & Continuous Verification

### Pre-Commit Hooks

```r
# .git/hooks/pre-commit (via usethis::use_git_hook())
#!/bin/bash
# Run lintr on staged R files
Rscript -e "lintr::lint_dir('R')" || exit 1
Rscript -e "styler::style_dir('R', dry = 'on')" || exit 1
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/quality-check.yml
- name: Lint code
  run: Rscript -e "lintr::lint_package()"

- name: Check code style
  run: Rscript -e "styler::style_pkg(dry = 'on')"

- name: R CMD check
  run: rcmdcheck::rcmdcheck(error_on = "warning")
```

### Phase Completion Checklist (GSD Verification)

Every phase must pass:

- [ ] All tests pass (`devtools::test()`)
- [ ] R CMD check passes with no warnings (`devtools::check()`)
- [ ] Code passes lintr with project rules (`lintr::lint_package()`)
- [ ] Code coverage maintained/improved (`covr::package_coverage()`)
- [ ] Documentation builds (`devtools::document()`)
- [ ] Vignettes render (`devtools::build_vignettes()`)
- [ ] Atomic commit created with descriptive message

### Project-Specific .lintr Configuration

```r
# .lintr
linters: linters_with_defaults(
  line_length_linter(120),              # Allow longer lines for R
  object_name_linter = NULL,            # Allow snake_case (tidyverse style)
  cyclocomp_linter(25),                 # Complexity threshold
  commented_code_linter = NULL          # Allow commented examples
)
exclusions: list(
  "tests/testthat.R",
  "R/zzz-compat-stubs.R"
)
```

### GSD Integration

- lintr runs **before** each atomic commit
- CI catches issues **before** PR review
- Failed quality checks **block** phase completion
- No "cleanup phases" - quality is continuous

---

## 10. GSD Development Strategy

### Milestone Structure (Version-Based)

**v0.1.0 - Foundation (Simplest Design Type)**
- Goal: Single design type (instantaneous counts) working end-to-end
- Proves the three-layer architecture works
- Establishes testing patterns
- Duration: ~4-6 phases, 2-3 weeks

**v0.2.0 - Core Expansion (Common Designs)**
- Goal: Add roving, aerial, interview designs
- Each design type is a separate phase
- Reuses foundation architecture
- Duration: ~6-8 phases, 3-4 weeks

**v0.3.0 - Hybrid & Advanced (Complexity)**
- Goal: Hybrid designs, calibration, advanced variance
- Builds on proven foundation
- Duration: ~5-7 phases, 2-3 weeks

**v1.0.0 - Production Ready**
- Goal: All QA/QC, documentation, performance optimization
- Polish for release
- Duration: ~4-6 phases, 2-3 weeks

**Key Principle:** Each milestone delivers working software that solves real problems, even if incomplete.

### v0.1.0 Phase Breakdown (Concrete Example)

**Phase 1: Project Setup & Foundation**
- Initialize package structure (`usethis::create_package()`)
- Set up lintr, styler, pre-commit hooks
- Configure CI/CD (GitHub Actions)
- Create `.planning/` structure
- Define data schemas for calendar + counts
- **Verification:** Empty package passes R CMD check + lintr
- **Duration:** 1 day

**Phase 2: Core Data Structures**
- Implement `creel_design` S3 class
- Basic constructor: `creel_design(calendar, date, strata)`
- Tier 1 validation (date column, required fields)
- Print and summary methods
- **Verification:** Can create design object, tests pass, lintr clean
- **Duration:** 2-3 days

**Phase 3: Survey Bridge Layer**
- Implement `add_counts()` for instantaneous method
- Build `svydesign` object internally from calendar + counts
- Day-PSU design construction (stratified by date)
- **Verification:** Internal survey object is correct, tests against survey package
- **Duration:** 2-3 days

**Phase 4: Basic Estimation**
- Implement `estimate_effort()` for instantaneous counts
- No grouping yet (total estimates only)
- Return `creel_estimates` object with SE and CI
- Tier 2 validation (warn on zeros, sparse strata)
- **Verification:** Estimates match manual survey calculations
- **Duration:** 3 days

**Phase 5: Grouped Estimation**
- Add `by = ` parameter to `estimate_effort()`
- Implement tidy selectors
- Group-wise estimates with variance
- **Verification:** Grouped estimates correct, tests pass
- **Duration:** 2-3 days

**Phase 6: Variance Methods**
- Add `variance = ` parameter (default = "taylor")
- Implement bootstrap, jackknife fallbacks
- Store variance method in results
- **Verification:** Multiple variance methods produce reasonable results
- **Duration:** 3 days

**Phase 7: Polish & Documentation**
- Write vignette: "Getting Started with Instantaneous Counts"
- Add example datasets
- Complete function documentation
- **Verification:** R CMD check --as-cran passes, vignettes render
- **Duration:** 2 days

**Each phase characteristics:**
- 1-3 days of focused work
- Atomic commits at completion
- Full test coverage for new code
- Passes lintr and R CMD check
- Builds on previous phases without breaking them

---

## 11. Package Dependencies & Performance

### Core Dependencies

**Required:**
- `survey` - Statistical engine for design-based inference
- `dplyr` - Data manipulation
- `tidyr` - Data tidying
- `rlang` - Tidy evaluation for selectors
- `tibble` - Modern data frames
- `cli` - User-facing messages and errors

**Suggested:**
- `testthat` (>= 3.0.0) - Testing framework
- `covr` - Test coverage
- `lintr` - Code quality
- `styler` - Code formatting
- `pkgdown` - Documentation website
- `bench` - Performance benchmarking

### Performance Considerations

**Design Principles:**
- Lazy evaluation where possible (don't compute until needed)
- Cache survey designs within creel_design objects
- Avoid repeated computation of strata summaries
- Use data.table for large datasets (optional, via user choice)

**Benchmarking Strategy:**
- Include performance tests in test suite
- Flag regressions in CI/CD
- Document performance characteristics in vignettes

---

## 12. Migration Path from Current tidycreel

### For Existing Users (if package were released)

The redesign would require:
1. **Function renaming:** `est_effort()` → `estimate_effort()` (minor)
2. **API change:** Move to design-centric workflow
3. **Data schema:** Adopt tidy selectors

**Migration vignette would show:**
```r
# Old API
svy_day <- as_day_svydesign(calendar, day_id = "date", strata_vars = c("day_type", "month"))
est_effort(svy_day, counts, method = "instantaneous", by = c("location"))

# New API
design <- creel_design(calendar, date = date, strata = c(day_type, month)) %>%
  add_counts(counts, method = "instantaneous")
design %>% estimate_effort(by = location)
```

### For Current Development

Since the package has never been released:
- No backward compatibility required
- Clean slate for API design
- Can make breaking changes without deprecation cycle

---

## 13. Success Criteria

### Technical Success

- [ ] All design types implemented and tested
- [ ] Test coverage > 85% overall, > 95% for core functions
- [ ] R CMD check passes with no errors/warnings/notes
- [ ] All code passes lintr
- [ ] Vignettes render and examples run
- [ ] Performance acceptable (< 1 second for typical survey with 100 days)

### User Success

- [ ] Beginners can run basic analyses without understanding survey package
- [ ] Production users can automate reports
- [ ] Power users can access survey objects for advanced work
- [ ] Documentation is clear and comprehensive
- [ ] Error messages are helpful and actionable

### Process Success

- [ ] GSD workflow maintained throughout (atomic commits, phase verification)
- [ ] Code quality gates never skipped
- [ ] Each milestone delivers working, usable software
- [ ] Team can onboard new contributors easily

---

## 14. Open Questions & Future Work

### Open Questions (To Be Resolved During Development)

1. **Plotting/Visualization:** Built into tidycreel or separate package (tidycreel.plot)?
2. **Performance:** When to offer data.table backend for large surveys?
3. **Caching:** Should designs cache computed results or always recompute?
4. **Version compatibility:** How far back to support older R and survey package versions?

### Future Work (Post v1.0.0)

- Interactive Shiny app for survey design and estimation
- Integration with spatial data (sf package)
- Machine learning for effort prediction
- Advanced diagnostics and model selection tools
- Database integration (DBI/dbplyr) for large-scale surveys

---

## Appendix A: Comparison with Current tidycreel

### What Changes

| Current | Redesign | Rationale |
|---------|----------|-----------|
| `est_effort()` | `estimate_effort()` | More explicit, less abbreviation |
| `as_day_svydesign()` | Internal to `creel_design()` | Hide survey package complexity |
| Survey object in user code | Design object in user code | Domain translation |
| Separate count/interview functions | Unified design with `add_*()` | Cleaner hybrid support |
| Manual schema validation | Progressive validation | Better UX |

### What Stays the Same

- Built on `survey` package foundation ✓
- Design-based inference approach ✓
- Support for replicate variance ✓
- Comprehensive QA/QC checks ✓
- Test-driven development ✓

### Architecture Improvements

- **Clearer separation of concerns** - Three explicit layers
- **Better extensibility** - Easy to add new design types
- **Improved testability** - Each layer tested independently
- **More maintainable** - Modular internals, clean interfaces
- **GSD-friendly** - Designed for incremental development

---

## Appendix B: Key Architectural Insights

### Why Domain Translation Matters

Creel biologists think in terms of:
- "I flew 10 aerial surveys in July"
- "I interviewed 50 anglers at the boat ramp"
- "What's the total harvest of walleye this season?"

They don't think in terms of:
- "Primary sampling units"
- "Finite population corrections"
- "Calibration weights"

The survey package is excellent for statisticians. tidycreel makes it accessible to domain experts.

### Why Survey Package as Foundation

Don't reinvent the wheel. The `survey` package:
- Is mature, well-tested, and peer-reviewed
- Handles complex variance estimation correctly
- Supports calibration, post-stratification, and other advanced methods
- Is maintained by Thomas Lumley (world expert in survey statistics)

tidycreel adds value by providing domain-specific vocabulary and workflows, not by reimplementing survey statistics.

### Why Design-Centric API

In real-world creel surveys:
- You design the survey first (sampling frame, strata, methods)
- You collect data according to that design
- You estimate based on the design

The API reflects this reality. The design object is the source of truth, and all estimation flows from it.

### Why Progressive Validation

Different users need different levels of validation:
- **Beginners:** Need automatic checks to prevent obvious mistakes
- **Production users:** Need fast, reliable checks that don't slow down reports
- **Explorers:** Need deep diagnostics to understand data quality issues
- **Power users:** Need to bypass validation for custom workflows

Progressive validation serves all users without compromising any use case.

---

**End of Design Document**

*This design represents a validated architectural vision for tidycreel. Implementation would proceed incrementally using GSD methodology, with each phase building on proven foundations.*
