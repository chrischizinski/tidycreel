---
phase: 05-grouped-estimation
plan: 01
subsystem: creel-estimates
tags: [grouped-estimation, svyby, tidy-eval, domain-estimation, phase-5]
dependencies:
  requires: [04-01]
  provides: [grouped-effort-estimation, by-parameter, svyby-integration]
  affects: [estimate_effort, creel_estimates]
tech-stack:
  added: []
  patterns: [survey-svyby, tidyselect-eval, tidy-evaluation-routing]
key-files:
  created: []
  modified:
    - R/creel-estimates.R
    - R/survey-bridge.R
    - tests/testthat/test-estimate-effort.R
    - tests/testthat/test-creel-estimates.R
    - man/estimate_effort.Rd
decisions:
  - "Use survey::svyby() internally for grouped estimation (not manual split-apply-combine)"
  - "Accept by = parameter with tidy selectors (bare names, c(), tidyselect helpers)"
  - "Return grouped tibble with group columns first, then estimate/se/ci/n"
  - "Route to estimate_effort_total() vs estimate_effort_grouped() based on quo_is_null(by_quo)"
  - "Preserve Phase 4 behavior when by = NULL for backward compatibility"
  - "Use keep.names = FALSE in svyby() for consistent column naming (se, ci_l, ci_u)"
  - "Extract group sample sizes via aggregate() on design$counts"
metrics:
  duration: 8
  tasks: 2
  tests: 14
  files: 5
  commits: 2
  completed: "2026-02-09T15:52:14Z"
---

# Phase 5 Plan 1: Grouped Estimation Summary

**One-liner:** Added grouped estimation to `estimate_effort()` via `by = ` parameter accepting tidy selectors, using `survey::svyby()` internally for correct domain variance estimation

## What Was Built

Implemented grouped estimation capability for `estimate_effort()`, enabling users to compute effort estimates by subgroups (e.g., by day_type, by location, by month) using familiar tidy syntax. This is Phase 5's core value-add: moving from single total estimates to subpopulation analysis.

### Key Features

1. **`by = ` parameter with tidy evaluation**
   - Accepts bare column names: `by = day_type`
   - Accepts multiple columns: `by = c(day_type, location)`
   - Accepts tidyselect helpers: `by = starts_with("day")`
   - `by = NULL` (default) preserves Phase 4 ungrouped behavior

2. **Correct domain variance estimation**
   - Uses `survey::svyby()` internally (not naive subsetting)
   - Accounts for full survey design when computing group variances
   - Avoids underestimating variance (common pitfall of manual subsetting)

3. **Grouped result structure**
   - Group columns first (preserving original types from design$counts)
   - Then estimate, se, ci_lower, ci_upper, n
   - One row per group combination
   - Sample sizes calculated per group

4. **Enhanced print output**
   - Shows "Grouped by: day_type, location" when grouped
   - No grouping line for ungrouped results (backward compat)

5. **Tier 2 group validation**
   - Warns if any group has < 3 observations (sparse group warning)
   - Follows same warning pattern as sparse strata validation

## Implementation Details

### Architecture Changes

**Routing logic in `estimate_effort()`:**
```r
by_quo <- rlang::enquo(by)

if (rlang::quo_is_null(by_quo)) {
  return(estimate_effort_total(design, conf_level))  # Phase 4 path
} else {
  by_vars <- resolve_by_cols(by_quo, design)
  return(estimate_effort_grouped(design, by_vars, conf_level))  # Phase 5 path
}
```

**Key internal functions:**
- `estimate_effort_total()`: Extracted Phase 4 ungrouped logic (using `survey::svytotal()`)
- `estimate_effort_grouped()`: New grouped logic (using `survey::svyby()`)
- `warn_tier2_group_issues()`: Validates group sample sizes

### Technical Decisions

**Decision 1: Use `survey::svyby()` not manual grouping**
- **Why:** Correct domain variance estimation requires using full survey design
- **Alternative rejected:** Manual split-apply-combine would underestimate variance
- **Impact:** Results mathematically correct, matches manual survey package calculations

**Decision 2: `keep.names = FALSE` in svyby()**
- **Why:** Consistent column naming regardless of variable name
- **Result:** Columns are `se`, `ci_l`, `ci_u` (not `se.effort_hours`, etc.)
- **Impact:** Simpler column extraction in result transformation

**Decision 3: Preserve backward compatibility**
- **Why:** Phase 4 users expect `estimate_effort(design)` to work unchanged
- **Result:** `by = NULL` default maintains Phase 4 behavior exactly
- **Impact:** Zero breaking changes for existing code

**Decision 4: Group columns ordered first**
- **Why:** Matches dplyr `group_by()` + `summarize()` mental model
- **Result:** `day_type, estimate, se, ci_lower, ci_upper, n`
- **Impact:** Natural reading order for grouped results

## Deviations from Plan

None - plan executed exactly as written.

## Testing

### Test Coverage

**14 new tests added (all passing):**
- 6 basic behavior tests (grouped class, column order, row count, multiple groups, sample sizes, backward compat)
- 2 tidy selector tests (starts_with helper, error on nonexistent column)
- 2 print/format tests (shows "Grouped by" when grouped, omits when ungrouped)
- 1 Tier 2 validation test (warns on sparse groups)
- 3 reference tests (point estimates, SEs, CIs match manual `survey::svyby()`)

**Phase 4 tests (16) still pass** - backward compatibility verified.

**Total: 197 tests pass, 0 failures**

### Reference Test Verification

Reference tests prove correctness by comparing tidycreel output to manual `survey::svyby()` calculations:

```r
# Manual calculation
manual_result <- survey::svyby(~effort_hours, ~day_type, svy, survey::svytotal, vartype = c("se", "ci"))

# Comparison
expect_equal(result$estimates$estimate, manual_result$effort_hours, tolerance = 1e-10)
expect_equal(result$estimates$se, manual_result$se, tolerance = 1e-10)
expect_equal(result$estimates$ci_lower, manual_result$ci_l, tolerance = 1e-10)
```

All comparisons pass with tolerance `1e-10` (numerical precision limit).

## Files Modified

### Production Code

**R/creel-estimates.R** (major changes)
- Modified `estimate_effort()` signature to add `by = NULL` parameter
- Added tidy evaluation routing logic (`rlang::enquo()`, `tidyselect::eval_select()`)
- Created `estimate_effort_total()` (extracted Phase 4 logic)
- Created `estimate_effort_grouped()` (new Phase 5 logic using `svyby()`)
- Updated `new_creel_estimates()` to accept `by_vars` parameter
- Updated `format.creel_estimates()` to show "Grouped by" line

**R/survey-bridge.R** (minor addition)
- Added `warn_tier2_group_issues()` for sparse group validation
- Follows same pattern as `warn_tier2_issues()` sparse strata warnings

### Tests

**tests/testthat/test-estimate-effort.R** (major additions)
- Added `make_test_design_with_groups()` test helper (16 dates, 2 day_types, 2 periods)
- Added 14 new grouped estimation tests
- Fixed reference test column names (`se` not `se.effort_hours`)

**tests/testthat/test-creel-estimates.R** (minor update)
- Updated constructor test to expect `by_vars` in result structure
- Added `expect_null(result$by_vars)` to defaults test

### Documentation

**man/estimate_effort.Rd** (regenerated)
- Added `@param by` documentation
- Updated `@return` to mention grouped results
- Updated `@details` to explain grouped estimation and `svyby()` usage
- Added grouped examples

## Commits

1. **3261dac** `test(05-01): add failing tests for grouped estimation`
   - 14 new tests covering grouped behavior, tidy selectors, print, validation, reference tests
   - Test helper `make_test_design_with_groups()` creates design with grouping variables
   - All existing Phase 4 tests (16) still pass
   - All new Phase 5 tests (11 ran before max failures) fail with "unused argument (by = ...)"

2. **d64ca8d** `feat(05-01): implement grouped estimation with by parameter`
   - Implement all production code for grouped estimation
   - All 197 tests pass (62 estimate_effort tests including 14 new grouped tests)
   - Reference tests verify grouped estimates match manual `survey::svyby()` calculations
   - R CMD check passes (pre-existing Rd warnings from Phase 4 noted)

## Performance Metrics

- **Duration:** 8 minutes (plan start to summary completion)
- **Tasks completed:** 2 of 2 (TDD RED → GREEN)
- **Tests added:** 14 (grouped estimation tests)
- **Files modified:** 5 (2 production, 2 test, 1 doc)
- **Commits:** 2 (RED commit, GREEN commit)
- **Lines added:** ~320 (code + tests)

## Requirements Satisfied

From .planning/ROADMAP.md:

- **EST-07:** `estimate_effort()` with `by = ` parameter ✅
  - Accepts bare column names, multiple columns, tidyselect helpers
  - Returns grouped tibble with group columns + estimate/se/ci/n

- **EST-08:** Reference tests for grouped estimates ✅
  - 3 reference tests verify point estimates, SEs, CIs match manual `survey::svyby()`
  - Tolerance `1e-10` ensures numerical precision

- **TEST-04:** Grouped estimation tests ✅
  - 14 comprehensive tests covering behavior, selectors, print, validation, correctness

## Known Issues

None. All functionality works as specified.

## Next Steps

**Phase 5 Plan 2** (next): Extend grouped estimation to variance components (when applicable).

**Phase 6** (future): Add bootstrap and jackknife variance methods, which should work seamlessly with grouped estimation since `svyby()` is variance-method-agnostic.

## Self-Check

Verifying all claims in summary:

**Created files exist:** N/A (no new files created, only modifications)

**Modified files exist:**
```bash
$ ls -l R/creel-estimates.R R/survey-bridge.R tests/testthat/test-estimate-effort.R
```
✅ All modified files exist

**Commits exist:**
```bash
$ git log --oneline -2
d64ca8d feat(05-01): implement grouped estimation with by parameter
3261dac test(05-01): add failing tests for grouped estimation
```
✅ Both commits found

**Tests pass:**
```bash
$ Rscript -e "devtools::test()" | tail -3
[ FAIL 0 | WARN 52 | SKIP 0 | PASS 197 ]
```
✅ All 197 tests pass

## Self-Check: PASSED

All claimed files, commits, and tests verified.
