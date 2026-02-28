---
phase: 20-documentation-guidance
plan: 01
subsystem: documentation
tags: [vignette, incomplete-trips, validation, best-practices, colorado-csap]
dependency-graph:
  requires: [validate_incomplete_trips, estimate_cpue with use_trips, diagnostic mode]
  provides: [incomplete trip vignette, user guidance documentation]
  affects: [package documentation completeness, user decision-making]
tech-stack:
  added: [incomplete-trips.Rmd vignette]
  patterns: [rmarkdown vignettes, scientific rationale documentation, step-by-step workflows]
key-files:
  created:
    - vignettes/incomplete-trips.Rmd
  modified: []
decisions:
  - Vignette emphasizes complete trips as default and preferred approach
  - Strong warning section against pooling complete and incomplete trips
  - Two realistic examples (passing and failing validation) demonstrate practical usage
  - Decision tree provides clear guidance for when to use incomplete trips
  - TOST equivalence testing explained at appropriate technical depth
  - Trip duration for incomplete trips equals hours_fished (time interviewed, not total trip)
metrics:
  duration: 6 minutes
  tasks: 2
  commits: 1
  vignette-lines: 794
  files-modified: 1
  completed: 2026-02-15
---

# Phase 20 Plan 01: Incomplete Trip Documentation

**Comprehensive vignette documenting when and how to use incomplete trip estimation with scientific rationale, Colorado C-SAP best practices, and validation workflow.**

## Implementation Summary

Created `vignettes/incomplete-trips.Rmd`, a comprehensive 794-line vignette that guides users through the scientific rationale, best practices, and validation workflow for incomplete trip estimation. The vignette emphasizes that complete trips are the default and preferred approach (following Colorado C-SAP guidelines), while documenting when incomplete trip estimates can be scientifically valid with proper validation.

### Core Components

1. **Scientific Rationale Section**
   - Roving-access design theory (Pollock et al. 1994)
   - Why complete trips avoid length-of-stay bias
   - When incomplete trips might be considered (stationary catch rates)
   - Mean-of-ratios vs ratio-of-means estimators
   - Colorado C-SAP best practices (≥10% complete trip requirement)

2. **Strong Warning Against Pooling**
   - Dedicated callout section explaining why pooling is invalid
   - Different sampling probabilities for complete vs incomplete trips
   - Anti-pattern examples showing what NOT to do
   - Emphasis that package prevents auto-pooling by design

3. **Step-by-Step Validation Workflow**
   - Six-step process from data loading through decision-making
   - `validate_incomplete_trips()` usage with TOST explanation
   - Interpreting validation results (passed vs failed)
   - Viewing validation plots
   - Making informed decisions based on outcomes

4. **Realistic Examples**
   - **Passing validation**: Similar catch rates for both trip types (stationary scenario)
   - **Failing validation**: Different catch rates due to time-of-day effects (non-stationary)
   - Both examples include complete code, output interpretation, and recommended actions
   - Examples use 50-120 sample sizes appropriate for real surveys

5. **Additional Topics**
   - Diagnostic comparison mode (use_trips="diagnostic")
   - Grouped validation workflow (by= parameter)
   - Custom equivalence thresholds (tidycreel.equivalence_threshold option)
   - Trip truncation technical details
   - Mean-of-ratios variance estimation
   - Decision tree for determining when to use incomplete trips

### Documentation Structure

The vignette follows a logical progression:

1. Introduction → Why this vignette exists
2. Scientific Rationale → Theory and best practices
3. Colorado C-SAP → Industry standards
4. Pooling Warning → What NOT to do
5. When to Consider → Prerequisites
6. Validation Workflow → How to validate
7. Example: Passes → Successful validation
8. Example: Fails → Failed validation with recommendations
9. Diagnostic Mode → Research/exploration tool
10. Advanced Topics → Grouped validation, thresholds, truncation
11. Summary → Decision tree and recommendations

### Key Messages Emphasized

**Throughout the vignette:**
- Complete trips are default and preferred (mentioned 15+ times)
- Validation is REQUIRED before using incomplete trips (not optional)
- Package enforces best practices through API design
- TOST provides statistical evidence for equivalence
- Never pool complete and incomplete trips

**User decision framework:**
1. Check ≥10% complete trips (Colorado C-SAP)
2. Check ≥30 incomplete trips (sample size)
3. Run validation (`validate_incomplete_trips()`)
4. Interpret results (TOST p-values, equivalence)
5. Make informed decision (pass → can use, fail → stick with complete)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Example data needed day_type strata column in counts**
- **Found during:** First vignette render attempt
- **Issue:** add_counts() validation requires strata columns present in count data, examples only had date and effort_hours
- **Fix:** Added day_type column to counts data frames in both examples
- **Files modified:** vignettes/incomplete-trips.Rmd
- **Tracking:** Fixed inline during Task 1

**2. [Rule 3 - Blocking] Trip duration validation required for all interviews**
- **Found during:** Second vignette render attempt
- **Issue:** Initially set trip_duration = NA for incomplete trips, but add_interviews() validation requires trip_duration for all rows
- **Fix:** Set trip_duration = hours_fished for incomplete trips (time interviewed so far, not total trip time), matching pattern from example_interviews dataset
- **Files modified:** vignettes/incomplete-trips.Rmd
- **Tracking:** Fixed inline during Task 1

Both issues were discovered through vignette rendering (TDD for documentation) and fixed immediately before committing.

## Quality Checks

**Vignette Rendering:**
- [x] Renders successfully to HTML without errors
- [x] All code chunks execute successfully
- [x] 33 code chunks total (mix of eval=TRUE and eval=FALSE)
- [x] Output file: 136KB HTML

**R CMD Check:**
- [x] 0 errors ✔
- [x] 0 warnings ✔
- [x] 3 notes (all acceptable: .serena dir, dev version, HTML Tidy)
- [x] Vignette builds during package check
- [x] Re-building of vignette outputs passes

**Vignette Integration:**
- [x] Appears in `vignette(package = "tidycreel")` index
- [x] Title: "Incomplete Trip Estimation"
- [x] Accessible via `vignette("incomplete-trips")`
- [x] All cross-references resolve (?validate_incomplete_trips, ?estimate_cpue, etc.)
- [x] VignetteIndexEntry metadata correct
- [x] VignetteEngine is knitr::rmarkdown
- [x] VignetteEncoding is UTF-8

**Content Completeness:**
- [x] Scientific rationale section (DOC-01) ✔
- [x] Colorado C-SAP best practices (DOC-02) ✔
- [x] Strong pooling warning (DOC-03) ✔
- [x] Step-by-step validation workflow (DOC-04) ✔
- [x] Passing validation example with full workflow ✔
- [x] Failing validation example with recommendations ✔
- [x] Diagnostic mode documentation ✔
- [x] Grouped validation documentation ✔
- [x] Technical details (TOST, thresholds, truncation) ✔
- [x] Decision tree / summary recommendations ✔

**Line Count:**
- [x] 794 lines (exceeds 200 minimum by 397%)

## Integration Points

**Upstream Dependencies:**
- Requires `validate_incomplete_trips()` from Phase 19-01
- Requires diagnostic mode from Phase 17-02
- Requires MOR estimator with truncation from Phases 15-16
- Requires trip_status field from Phase 13
- Requires use_trips parameter from Phase 17-01

**Downstream Impacts:**
- Completes user-facing documentation for v0.3.0 incomplete trip features
- Provides scientific justification for API design decisions
- Enables informed decision-making about incomplete trip usage
- Supports Phase 20-02 (print method enhancements) by establishing terminology

**Citation Context:**
- Pollock et al. 1994 (roving-access design)
- Hoenig et al. 1997 (truncation thresholds)
- Colorado C-SAP protocols (≥10% complete trips)
- Phase 17, 18, 19 documentation (technical implementation)

## Technical Notes

**Vignette Best Practices:**
- Uses `library(tidycreel)` in setup chunk
- Uses `set.seed()` for reproducible examples
- Uses native pipe `|>` for consistency
- Code chunks use `collapse=TRUE, comment="#>"` for clean output
- Realistic sample sizes (n=45-120) appropriate for field surveys
- Both passing and failing scenarios use different seeds for variety

**Example Data Patterns:**
- Passing scenario: CPUE ~2.4 for complete, ~2.35 for incomplete (~3% difference)
- Failing scenario: CPUE ~3.0 for complete, ~2.0 for incomplete (~33% difference)
- Trip duration for incomplete trips equals hours_fished (current fishing time, not projected total)
- All examples include both complete and incomplete trips with realistic distributions

**Cross-Reference Style:**
- Function references: `?validate_incomplete_trips`, `?estimate_cpue`
- Vignette references: "Interview-Based Catch Estimation" vignette
- Phase references: Phase 17, 18, 19 (with context)
- External citations: Author Year format (Pollock et al. 1994)

## Commits

| Commit | Message | Files |
|--------|---------|-------|
| 4b87172 | feat(20-01): create incomplete trip estimation vignette | vignettes/incomplete-trips.Rmd |

## Self-Check: PASSED

**Files created:**
- [x] vignettes/incomplete-trips.Rmd exists (794 lines)
- [x] vignettes/incomplete-trips.html rendered successfully (136KB)

**Commits exist:**
- [x] 4b87172 (vignette creation)

**Functionality verified:**
- [x] Vignette renders without errors
- [x] All code chunks execute successfully
- [x] R CMD check passes (0 errors, 0 warnings)
- [x] Vignette appears in package index
- [x] Cross-references resolve correctly
- [x] Scientific rationale section present
- [x] Colorado C-SAP section present
- [x] Pooling warning prominent
- [x] Validation workflow documented
- [x] Passing example with interpretation
- [x] Failing example with recommendations
- [x] Decision tree provided

**Content requirements (from PLAN.md):**
- [x] Must-have truths all satisfied:
  - User can read vignette explaining when incomplete trip estimation is valid
  - User understands Colorado C-SAP best practice (complete trips default)
  - User sees explicit warnings against pooling
  - User can follow validation workflow with validate_incomplete_trips()
  - User sees realistic passing and failing examples

- [x] Artifact requirements satisfied:
  - vignettes/incomplete-trips.Rmd created
  - Min 200 lines (actual: 794 lines)
  - Contains "Scientific Rationale"
  - Contains "Colorado C-SAP"
  - Contains "validate_incomplete_trips"
  - Contains "TOST"

- [x] Key links verified:
  - vignette → validate_incomplete_trips() workflow ✔
  - vignette → estimate_cpue() use_trips parameter ✔

All success criteria met. Plan 20-01 complete.
