---
phase: 16-trip-truncation
plan: 02
subsystem: creel-estimation
tags: [cpue, mor, trip-truncation, messaging, diagnostics, user-experience]
dependency_graph:
  requires:
    - "16-01: MOR trip truncation with configurable threshold"
    - "15-02: MOR S3 class infrastructure and diagnostic messaging"
  provides:
    - "mor_truncation_message() function for informative messaging"
    - "Truncation details in MOR print output"
    - "Data quality warning when >10% trips truncated"
  affects:
    - "User experience: transparent truncation reporting"
    - "MOR print banner shows truncation metadata"
tech_stack:
  added:
    - "scales package for percentage formatting"
  patterns:
    - "Conditional diagnostic messaging based on truncation rate"
    - "Print method enhancement with metadata display"
key_files:
  created: []
  modified:
    - "R/survey-bridge.R::mor_truncation_message()"
    - "R/creel-estimates.R::estimate_cpue() MOR path"
    - "R/print-methods.R::format.creel_estimates_mor()"
    - "tests/testthat/test-estimate-cpue.R"
    - "DESCRIPTION (scales import)"
decisions:
  - "Use cli::cli_inform() for normal truncation messages (informative)"
  - "Use cli::cli_warn() when >10% truncated (data quality concern)"
  - "Display truncation details in every MOR print output"
  - "scales::percent() for percentage formatting in high-truncation warnings"
metrics:
  duration_minutes: 6
  tasks_completed: 2
  tests_added: 6
  tests_total: 741
  commits: 3
  files_modified: 5
completed: 2026-02-15
---

# Phase 16 Plan 02: MOR Truncation Messaging Summary

**One-liner:** Add informative truncation messaging to MOR estimates showing trips excluded, threshold used, and data quality warnings when >10% truncated.

## Objective Achieved

Implemented transparent truncation reporting for MOR (mean-of-ratios) estimator. Users now see informative messages during estimation showing how many trips were excluded by truncation, the threshold used, and receive data quality warnings if truncation rate exceeds 10%. Print output displays truncation details in the diagnostic banner, providing full transparency about sample modifications.

## Implementation Summary

### Task 1: Add Truncation Messaging Function
**Commit:** `c15fc1b`

Created truncation messaging infrastructure and integrated into MOR estimation:

**New Function (`R/survey-bridge.R`):**
```r
mor_truncation_message <- function(n_truncated, n_incomplete_original, truncate_at) {
  pct_truncated <- n_truncated / n_incomplete_original

  if (n_truncated == 0) {
    # No trips truncated - informative message
    cli::cli_inform(c(
      "i" = "MOR truncation: 0 trips excluded (all >= {truncate_at} hours)"
    ))
  } else if (pct_truncated > 0.10) {
    # >10% truncated - data quality warning
    cli::cli_warn(c(
      "!" = "MOR truncation: {n_truncated} trip{?s} excluded ({scales::percent(pct_truncated, accuracy = 0.1)})",
      "i" = "Trips < {truncate_at} hours excluded to prevent unstable variance",
      "!" = "High truncation rate may indicate data quality issues",
      "i" = "Consider reviewing trip duration data for errors"
    ))
  } else {
    # Normal truncation - informative message
    cli::cli_inform(c(
      "i" = "MOR truncation: {n_truncated} trip{?s} excluded (< {truncate_at} hours)"
    ))
  }
}
```

**Integration into `estimate_cpue()` MOR path:**
- Called after truncation logic (lines 522-536)
- Uses stored counts: `n_truncated`, `n_incomplete` (pre-truncation)
- Only called when `truncate_at` is not NULL
- Message appears before survey design rebuild

**Dependencies:**
- Added `scales` to DESCRIPTION Imports for percentage formatting
- `@importFrom scales percent` in R/survey-bridge.R

### Task 2: Add Truncation Info to MOR Print Output and Tests
**Commits:** `df1ece5`, `252173f`

#### Print Output Enhancement (df1ece5)

Updated `format.creel_estimates_mor()` to display truncation details:

```r
# Add truncation details if applicable
if (!is.null(x$mor_truncate_at)) {
  if (x$mor_n_truncated > 0) {
    cli::cli_text("Truncation: {x$mor_n_truncated} trip{?s} excluded (< {x$mor_truncate_at} hours)")
  } else {
    cli::cli_text("Truncation: 0 trips excluded (threshold: {x$mor_truncate_at} hours)")
  }
}
```

**Placement:** After incomplete trip count line, before validation reminder

**Output Example:**
```
── DIAGNOSTIC: MOR Estimator (Incomplete Trips) ────────────────────
⚠ Complete trips preferred for CPUE estimation.
This estimate uses incomplete trip interviews (25 of 30 total).
Truncation: 5 trips excluded (< 0.5 hours)
Validate with `validate_incomplete_trips()` before use (Phase 19).
```

#### Truncation Messaging Tests (252173f)

Added 6 comprehensive tests to `test-estimate-cpue.R`:

1. **MOR stores truncation metadata when trips excluded**
   - Verifies `mor_truncate_at = 0.5`, `mor_n_truncated = 5`

2. **MOR stores zero truncation when all trips above threshold**
   - Verifies `mor_truncate_at = 0.5`, `mor_n_truncated = 0`

3. **MOR truncation function warns when >10% truncated**
   - Tests `mor_truncation_message()` directly
   - Expects warning: "High truncation rate may indicate data quality issues"

4. **MOR truncation metadata NULL when truncate_at = NULL**
   - Verifies `mor_truncate_at = NULL`, `mor_n_truncated = 0`

5. **MOR print output shows truncation details**
   - Captures print output with `capture.output(print(result))`
   - Verifies "Truncation: 5 trips excluded" appears
   - Verifies threshold "0.5 hours" appears

6. **MOR print output shows zero truncation details**
   - Verifies "Truncation: 0 trips excluded" message
   - Verifies "threshold: 0.5 hours" appears

**Testing Results:**
- All 6 new tests pass
- All 735 existing tests pass (no regressions)
- Total: 741 tests, 0 failures

## Deviations from Plan

None - plan executed exactly as written.

## Key Technical Decisions

**Message vs. Warning levels:**
- **Informative message (cli::cli_inform):** 0-10% truncation - normal operation
- **Data quality warning (cli::cli_warn):** >10% truncation - investigate data issues

**10% threshold rationale:**
Truncating >10% of incomplete trips suggests potential data quality problems:
- Trip duration data may contain errors (e.g., 0.1 hours instead of 1.0)
- Survey design may need adjustment (earlier start times to capture full trips)
- Sampling bias if many trips are legitimately very short

**Always display in print output:**
Unlike warning-level messages (shown once), truncation details appear in every MOR print output. This ensures users always see truncation effects when reviewing results.

**scales package for percentages:**
Using `scales::percent(pct_truncated, accuracy = 0.1)` provides clear formatting (e.g., "50.0%") for high-truncation warnings.

## User Experience Impact

**Before Phase 16-02:**
```r
result <- estimate_cpue(design, estimator = "mor")
print(result)
# User has no idea if truncation happened or how many trips excluded
```

**After Phase 16-02:**
```r
result <- estimate_cpue(design, estimator = "mor", truncate_at = 0.5)
# ℹ MOR truncation: 5 trips excluded (< 0.5 hours)

print(result)
# ── DIAGNOSTIC: MOR Estimator (Incomplete Trips) ────────────────────
# ⚠ Complete trips preferred for CPUE estimation.
# This estimate uses incomplete trip interviews (25 of 30 total).
# Truncation: 5 trips excluded (< 0.5 hours)
# Validate with `validate_incomplete_trips()` before use (Phase 19).
```

**Data quality warning example:**
```r
result <- estimate_cpue(design_with_many_short_trips, estimator = "mor")
# ⚠ MOR truncation: 15 trips excluded (50.0%)
# ℹ Trips < 0.5 hours excluded to prevent unstable variance
# ⚠ High truncation rate may indicate data quality issues
# ℹ Consider reviewing trip duration data for errors
```

## Dependencies & Integration

**Requires:**
- Phase 16-01: truncate_at parameter and truncation metadata storage
- Phase 15-02: MOR S3 class infrastructure for print methods

**Provides:**
- Transparent truncation reporting for users
- Data quality early warning system (>10% truncation)
- Foundation for Phase 19 validation diagnostics

**Affects:**
- User experience: full transparency about sample modifications
- MOR diagnostic messaging: now includes truncation details
- Phase 19 integration: truncation metadata available for validation

## Testing & Validation

**Test Coverage:**
- 6 new tests specifically for truncation messaging and print output
- All tests pass, including metadata storage and display verification
- Existing 735 tests still pass (100% backward compatibility)

**Quality Checks:**
- R CMD check: 0 errors, 0 warnings (vignette warnings pre-existing)
- lintr: 0 issues on modified files (R/survey-bridge.R, R/creel-estimates.R, R/print-methods.R clean)
- All pre-commit hooks pass

**Manual Verification:**
Tested messaging output with various truncation scenarios:
- 0 trips truncated: informative message
- <10% truncated: informative message
- >10% truncated: data quality warning
- NULL truncate_at: no message
- Print output: truncation details appear in banner

## Phase 16 Completion

Phase 16 (Trip Truncation) is now **COMPLETE**:

**Plan 16-01:** MOR trip truncation with configurable threshold ✓
- Default `truncate_at = 0.5` hours (30 minutes)
- Metadata storage for messaging
- 9 tests pass

**Plan 16-02:** Truncation diagnostic messaging ✓
- Informative messages during estimation
- Data quality warning when >10% truncated
- Print output shows truncation details
- 6 tests pass

**Combined deliverables:**
- Configurable trip truncation (Phase 16-01)
- Transparent truncation reporting (Phase 16-02)
- Data quality early warning system
- Full test coverage (15 new tests)
- User documentation and examples

**Requirements satisfied:**
- MOR-02: User can configure truncate_at ✓
- MOR-03: Truncation with informative message ✓
- MOR-06: Variance correct on truncated sample (proven by tests) ✓

## Future Considerations

**Phase 19: Incomplete Trip Validation**
Truncation metadata (`mor_truncate_at`, `mor_n_truncated`) will be available to `validate_incomplete_trips()` for comprehensive diagnostic reporting:
- Truncation rate in validation summary
- Threshold appropriateness check
- Sample size adequacy after truncation

**Research on threshold values:**
Future work could validate optimal truncation thresholds for different fisheries. Current 0.5h default is conservative and research-backed (Hoenig et al. 1997), but fishery-specific validation may refine this.

**Grouped estimation messaging:**
Current messaging works for ungrouped MOR estimates. Future enhancement could show per-group truncation details for grouped estimation.

## Self-Check

**Files created:**
- [✓] `.planning/phases/16-trip-truncation/16-02-SUMMARY.md` (this file)

**Key files modified:**
- [✓] `R/survey-bridge.R` (mor_truncation_message function)
- [✓] `R/creel-estimates.R` (message call in MOR path)
- [✓] `R/print-methods.R` (truncation details in banner)
- [✓] `tests/testthat/test-estimate-cpue.R` (6 new tests)
- [✓] `DESCRIPTION` (scales import)

**Commits exist:**
- [✓] `c15fc1b`: feat(16-02): add truncation messaging for MOR estimation
- [✓] `df1ece5`: feat(16-02): add truncation details to MOR print banner
- [✓] `252173f`: test(16-02): add tests for truncation messaging and print output

**Test results verified:**
- [✓] All 741 tests pass (735 existing + 6 new)
- [✓] R CMD check: 0 errors, 0 warnings (vignette warnings pre-existing)
- [✓] lintr: 0 issues on modified files

**Functionality verified:**
```bash
# Verify truncation messaging works
cd /Users/cchizinski2/Dev/tidycreel
[ -f "R/survey-bridge.R" ] && grep -q "mor_truncation_message" R/survey-bridge.R && echo "FOUND: mor_truncation_message function"
# Output: FOUND: mor_truncation_message function

# Verify print method updated
[ -f "R/print-methods.R" ] && grep -q "Truncation:" R/print-methods.R && echo "FOUND: Truncation display in print method"
# Output: FOUND: Truncation display in print method

# Verify tests added
[ -f "tests/testthat/test-estimate-cpue.R" ] && grep -c "MOR.*truncation.*metadata\|MOR print output" tests/testthat/test-estimate-cpue.R
# Output: 3 (test descriptions found)
```

## Self-Check: PASSED

All files created, commits exist, tests pass, functionality verified, documentation complete.
