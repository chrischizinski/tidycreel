---
phase: 19-diagnostic-validation-framework
plan: 02
subsystem: validation
tags: [visualization, base-graphics, scatter-plot, diagnostic-plots]
dependency-graph:
  requires: [validate_incomplete_trips, creel_tost_validation class, plot_data generation]
  provides: [scatter plot visualization, print method with plots, visual validation feedback]
  affects: [diagnostic mode workflow, validation user experience]
tech-stack:
  added: [base R graphics for validation plots]
  patterns: [plot generation in print methods, color-coded validation status]
key-files:
  created:
    - tests/testthat/test-print-validation.R
  modified:
    - R/validate-incomplete-trips.R
    - tests/testthat/test-validate-incomplete-trips.R
decisions:
  - Base R graphics used (no ggplot2 dependency) consistent with package patterns
  - Color scheme: blue for passed, red for failed validation
  - Square plot with equal axis ranges for clear y=x comparison
  - Failed points annotated with group labels for immediate attention
  - Error bars show confidence intervals for both complete and incomplete estimates
metrics:
  duration: 6 minutes
  tasks: 2
  commits: 3
  tests-added: 9
  files-modified: 3
  completed: 2026-02-15
---

# Phase 19 Plan 02: Validation Visualization and Print Methods

**Scatter plot visualization with error bars and failure annotations enables users to visually assess incomplete vs complete trip equivalence beyond statistical tests alone.**

## Implementation Summary

Extended the validation framework to generate and display scatter plots comparing incomplete vs complete trip CPUE estimates. The `print.creel_tost_validation` method now produces both formatted text output and a base R scatter plot showing the relationship between estimates with confidence interval error bars and clear visual indicators of equivalence test results.

### Core Components

1. **Plot Data Generation**
   - Added `plot_data` component to `creel_tost_validation` objects
   - Stores complete and incomplete estimates with CI bounds
   - Includes per-group passed status for annotation
   - Generates group labels for grouped validation
   - Supports both ungrouped and grouped plot structures

2. **Scatter Plot Visualization**
   - X-axis: complete trip CPUE estimates
   - Y-axis: incomplete trip CPUE estimates
   - Reference line: y=x diagonal showing perfect agreement
   - Error bars: horizontal (complete CI) and vertical (incomplete CI)
   - Color coding: blue for passed equivalence, red for failed
   - Annotations: failed points labeled with group names
   - Legend: clear interpretation guide

3. **Print Method Enhancement**
   - Displays formatted text output (existing functionality)
   - Generates and displays scatter plot using plot_data
   - Uses base R graphics (consistent with package - no ggplot2 dependency)
   - Square plot with equal axis ranges for clear comparison
   - Professional styling with appropriate margins and labels

### Visual Design Decisions

**Color Scheme:**
- Passed points: #0066CC (blue) - positive, calming
- Failed points: #CC0000 (red) - attention-grabbing, warning
- Reference line: gray50 (dashed) - neutral, guide

**Plot Features:**
- Title: "Validation: Incomplete vs Complete Trip Estimates"
- Error bars: 1.5pt width, color-matched to points
- Point size: 1.5 cex for visibility
- Failed point labels: positioned above points, bold red text
- Legend: top-left position, no border, concise labels

**Layout:**
- Square plot (equal x and y ranges) for accurate y=x assessment
- Extended margins (5, 5, 4, 2) to accommodate labels and title
- Horizontal axis labels (las=1) for readability

### User Workflow

```r
# Generate validation with visualization
result <- validate_incomplete_trips(design,
  catch = catch_total,
  effort = hours_fished
)

# Print displays both text and plot
print(result)
# Output:
# - TOST test results (text)
# - Recommendation (text)
# - Statistical details (text)
# - Scatter plot (graphic device)

# Grouped validation with per-group visualization
result_grouped <- validate_incomplete_trips(design,
  catch = catch_total,
  effort = hours_fished,
  by = location
)
print(result_grouped)
# Shows multiple points on scatter plot, one per group
# Failed groups clearly marked with red color and labels
```

## Task Commits

1. **Task 1: Add plot data generation** - `638b646` (test), `7a7cc8e` (feat)
   - RED: Added failing tests for plot_data component
   - GREEN: Implemented plot_data generation for both ungrouped and grouped validation
   - Stores estimates, CIs, passed status, and group labels

2. **Task 2: Create print methods for visualization** - `23c8e78` (feat)
   - Extended `print.creel_tost_validation` to generate scatter plots
   - Implemented base R graphics with error bars and annotations
   - Added comprehensive tests for print and format methods

## Files Created/Modified

- `R/validate-incomplete-trips.R` - Added plot_data generation, extended print method with scatter plot
- `tests/testthat/test-validate-incomplete-trips.R` - Tests for plot_data structure (ungrouped, grouped, CIs, passed status)
- `tests/testthat/test-print-validation.R` - Tests for format/print methods and output content

## Deviations from Plan

None - plan executed exactly as written. All success criteria met:

- [x] validate_incomplete_trips() returns creel_tost_validation object with plot_data component
- [x] Plot_data has correct structure for ungrouped estimation
- [x] Plot_data has correct structure for grouped estimation
- [x] Plot includes y=x reference line, error bars for CIs, annotations for failures
- [x] Print method displays plot and comprehensive results
- [x] Statistical detail table shows estimates, SEs, CIs, n for both trip types
- [x] Recommendation text is clear and actionable based on test results
- [x] All tests pass (107 validation tests total: 98 from Task 1, 9 from Task 2)
- [x] R CMD check clean (0 errors, 0 warnings, 1 acceptable note)
- [x] lintr clean for new code

## Quality Checks

**Test Coverage:**
- 9 new tests for print/format methods
- Tests verify character output, plot generation, content inclusion
- Tests cover both ungrouped and grouped scenarios
- All 107 validation-related tests passing

**R CMD Check:**
- 0 errors ✔
- 0 warnings ✔
- 1 note (acceptable - .serena directory)

**lintr:**
- 0 issues for new code ✔

## Integration Points

**Upstream Dependencies:**
- Requires validate_incomplete_trips() from Phase 19-01
- Requires creel_tost_validation S3 class from Phase 19-01
- Uses TOST test results from Phase 19-01

**Downstream Impacts:**
- Completes Phase 19 validation framework
- Enhances diagnostic mode user experience (Phase 17)
- Provides visual validation tool for incomplete trip decisions
- Referenced in MOR print method guidance

## Technical Notes

**Base R Graphics Choice:**
Package consistently avoids ggplot2 dependency. Base graphics provide:
- No additional dependencies
- Sufficient for diagnostic plots
- Familiar to R users
- Fast rendering

**Plot Data Storage:**
Base R plots cannot be stored as objects (unlike ggplot2). Solution:
- Store plot_data (estimates, CIs, passed status) in validation object
- Regenerate plot in print method using stored data
- Ensures plot always reflects current validation results

**Color Accessibility:**
Blue/red scheme chosen for:
- High contrast (visible in grayscale)
- Standard meaning (blue = good, red = warning)
- Avoids red-green colorblindness issues

**Square Plot Rationale:**
Equal axis ranges ensure y=x reference line is truly 45 degrees, making visual assessment of agreement accurate. Without equal ranges, visually "on the line" points might not be equivalent.

## Commits

| Commit | Message | Files |
|--------|---------|-------|
| 638b646 | test(19-02): add failing tests for plot data generation | tests/testthat/test-validate-incomplete-trips.R |
| 7a7cc8e | feat(19-02): add plot data generation to validate_incomplete_trips | R/validate-incomplete-trips.R, tests/testthat/test-validate-incomplete-trips.R |
| 23c8e78 | feat(19-02): add scatter plot to print.creel_tost_validation | R/validate-incomplete-trips.R, tests/testthat/test-print-validation.R |

## Self-Check: PASSED

**Files created:**
- [x] tests/testthat/test-print-validation.R exists

**Files modified:**
- [x] R/validate-incomplete-trips.R contains plot_data generation
- [x] R/validate-incomplete-trips.R contains scatter plot in print method
- [x] tests/testthat/test-validate-incomplete-trips.R contains plot_data tests

**Commits exist:**
- [x] 638b646 (RED phase - plot data tests)
- [x] 7a7cc8e (GREEN phase - plot data implementation)
- [x] 23c8e78 (print method with plots)

**Functionality verified:**
- [x] plot_data component exists in validation objects
- [x] plot_data structure correct for ungrouped validation
- [x] plot_data structure correct for grouped validation (with labels)
- [x] print method generates scatter plot
- [x] Plot includes y=x reference line
- [x] Plot shows error bars (CI bounds)
- [x] Plot annotates failed points
- [x] Color coding works (blue passed, red failed)
- [x] All 107 validation tests pass
- [x] R CMD check clean
- [x] lintr clean

All success criteria met. Plan 19-02 complete.

---
*Phase: 19-diagnostic-validation-framework*
*Completed: 2026-02-15*
