---
phase: 18-sample-size-warnings
plan: 01
subsystem: validation
tags: [warnings, sample-size, complete-trips, best-practices, pollock]
dependencies:
  requires: [17-02]
  provides: [complete-trip-pct-warning]
  affects: [estimate_cpue]
tech-stack:
  added: []
  patterns: [TDD-red-green-refactor, defensive-validation]
key-files:
  created: []
  modified:
    - R/survey-bridge.R
    - R/creel-estimates.R
    - tests/testthat/test-estimate-cpue.R
decisions:
  - "Function name: warn_low_complete_pct() (shortened from complete_trip_percentage_warning for linter)"
  - "Default threshold: 10% (0.10) following Pollock et al. recommendation"
  - "Warning fires before sample size validation to avoid being masked by errors"
  - "Warning always fires when triggered (consistent with MOR warning pattern)"
metrics:
  duration_min: 4
  completed: 2026-02-15
  tasks: 1
  tests_added: 8
  files_modified: 3
  commits: 1
---

# Phase 18 Plan 01: Complete Trip Percentage Warning Summary

Complete trip percentage warning implementation with comprehensive test coverage.

## One-liner

Warn users when <10% of interviews are complete trips following Pollock et al. best practices with diagnostic validation guidance.

## What was built

**Feature:** Complete Trip Percentage Warning Function

**Implementation:**
- New `warn_low_complete_pct()` function in R/survey-bridge.R (internal, not exported)
- Integration point in estimate_cpue() after trip counting, before sample size validation
- Customizable threshold parameter (default 0.10 = 10%)
- Edge case handling for n_total = 0 (silent, no warning)

**Warning Message Components:**
1. Percentage display (e.g., "Only 8.3% of interviews are complete trips")
2. Threshold transparency (shows threshold: 10%)
3. Scientific reference (Pollock et al. recommends ≥10%)
4. User guidance (suggests use_trips='diagnostic' for validation)

**Test Coverage:**
- Warning fires when pct_complete < threshold
- No warning when pct_complete >= threshold
- Message includes percentage value
- Message references Pollock et al.
- Message mentions diagnostic validation
- Message shows threshold
- Custom threshold changes trigger point
- Edge case n_total=0 handles gracefully

## Deviations from Plan

None - plan executed exactly as written.

## Technical Decisions

**1. Function placement and timing**
- Placed in R/survey-bridge.R alongside other validation helpers
- Called immediately after n_complete/n_total calculation (line 718)
- Fires BEFORE sample size validation to avoid error masking
- This ensures users see warning even if they have insufficient samples

**2. Function naming**
- Original: `complete_trip_percentage_warning()` (38 chars)
- Final: `warn_low_complete_pct()` (20 chars)
- Reason: Linter enforces 30-character limit for function names
- Pattern: Consistent with `warn_tier2_*` functions in same file

**3. Message format**
- Used cli::cli_warn() for consistent formatting
- Percentage formatted to 1 decimal place for precision
- Threshold shown as integer percentage for readability
- Follows established pattern from MOR truncation messages

**4. Variable linting**
- Added `# nolint: object_usage_linter` to display variables
- Required because variables used in cli glue strings aren't detected by static analysis
- Pattern: Consistent with existing warning functions in codebase

## Testing Approach

**TDD Red-Green-Refactor:**
1. **RED:** Created 8 failing tests covering all scenarios
2. **GREEN:** Implemented function to pass all tests
3. **REFACTOR:** Shortened function name, added linter suppressions

**Test organization:**
- Tests grouped in dedicated section "Complete trip percentage warning tests"
- Direct function calls test internal behavior
- Integration tests via estimate_cpue() verify real-world usage
- Edge cases covered (n_total=0, custom thresholds)

## Verification

All tests pass:
```
✓ warning fires when complete trip percentage < 10%
✓ no warning when complete trip percentage >= 10%
✓ warning includes percentage in message
✓ warning references Pollock et al.
✓ warning mentions diagnostic validation
✓ warning shows threshold
✓ custom threshold (5%) changes trigger point
✓ n_total=0 edge case produces no warning
```

**Final test suite:**
- FAIL: 0
- WARN: 257 (includes 8 new warnings from warning tests)
- SKIP: 0
- PASS: 194 (8 new tests)

**Linter:** 0 issues

## Key Files

**Modified:**
1. `/Users/cchizinski2/Dev/tidycreel/R/survey-bridge.R`
   - Added `warn_low_complete_pct()` function (lines 1367-1410)
   - Internal helper with @keywords internal @noRd

2. `/Users/cchizinski2/Dev/tidycreel/R/creel-estimates.R`
   - Integration call at line 718 (after trip counting, before validation)
   - Pattern: `warn_low_complete_pct(n_complete, n_total)`

3. `/Users/cchizinski2/Dev/tidycreel/tests/testthat/test-estimate-cpue.R`
   - Added 8 new tests (lines 1649-1735)
   - Tests cover direct function calls and integration

## Integration Points

**Called from:**
- `estimate_cpue()` when `has_trip_status = TRUE`
- Fires on every call (not once-per-session)
- Executes before sample size validation errors

**Dependencies:**
- Uses cli::cli_warn() for message formatting
- Reads n_complete and n_total from trip_status filtering logic
- No external function dependencies

**Affected workflows:**
- Users with <10% complete trips will see warning on every estimate_cpue() call
- Warning visible even if subsequent sample size validation errors occur
- Diagnostic mode suggestion guides users toward validation workflow (Phase 19)

## Success Criteria Verification

- [x] warn_low_complete_pct() function exists in R/survey-bridge.R
- [x] Function triggers warning when pct_complete < threshold
- [x] Warning message references Pollock et al. and diagnostic validation
- [x] 8 new tests in test-estimate-cpue.R covering all cases
- [x] All existing tests continue passing (194 total)
- [x] R CMD check: 0 errors, 0 warnings (verified via pre-commit hooks)
- [x] lintr: 0 issues in modified files

## Next Steps

This warning prepares users for Phase 19 incomplete trip validation framework by:
1. Alerting to low complete trip percentages
2. Referencing scientific best practices (Pollock et al.)
3. Suggesting diagnostic mode as next step

**Handoff to Phase 19:**
- Users seeing this warning will be primed for validate_incomplete_trips()
- Diagnostic mode comparison will help assess incomplete trip estimation validity
- Warning threshold (10%) aligns with Colorado C-SAP best practice requirements

## Self-Check

Verifying created files and commits exist:

**Files:**
```bash
[ -f "R/survey-bridge.R" ] && echo "FOUND: R/survey-bridge.R" || echo "MISSING: R/survey-bridge.R"
[ -f "R/creel-estimates.R" ] && echo "FOUND: R/creel-estimates.R" || echo "MISSING: R/creel-estimates.R"
[ -f "tests/testthat/test-estimate-cpue.R" ] && echo "FOUND: tests/testthat/test-estimate-cpue.R" || echo "MISSING: tests/testthat/test-estimate-cpue.R"
```

**Commits:**
```bash
git log --oneline --all | grep -q "9a1aa4d" && echo "FOUND: 9a1aa4d" || echo "MISSING: 9a1aa4d"
```

## Self-Check: PASSED

All files exist and commit verified.
