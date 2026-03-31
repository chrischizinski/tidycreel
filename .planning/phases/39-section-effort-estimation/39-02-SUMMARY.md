---
phase: 39-section-effort-estimation
plan: "02"
subsystem: testing
tags: [tdd, creel-estimates, sections, section-effort, red-phase]

requires:
  - phase: 39-01
    provides: add_sections() infrastructure with design$sections slot and section_col

provides:
  - Two test fixture helpers (make_3section_design_with_counts, make_section_design_with_missing_section) in test-estimate-effort.R
  - Seven failing test stubs (RED) covering SECT-01 through SECT-05 behaviors
  - Confirmed zero regression against 144 pre-existing estimate-effort tests

affects:
  - 39-03 (implements estimate_effort() section dispatch to pass these stubs GREEN)

tech-stack:
  added: []
  patterns:
    - "TDD RED pattern: stubs call estimate_effort() with aggregate_sections=TRUE, method=, missing_sections= which ERROR until Plan 39-03 adds the implementation"
    - "nolint: object_length_linter on function definitions > 30 chars per project convention"
    - "suppressWarnings() wraps add_counts() in fixtures to silence svydesign no-weights warning"

key-files:
  created: []
  modified:
    - tests/testthat/test-estimate-effort.R

key-decisions:
  - "add_sections() requires explicit section_col = section (unquoted tidy-select arg) — no default; fixtures use section_col = section"
  - "SECT-04 regression guard passes GREEN immediately (non-sectioned design, no new params used) — this is the expected correct behavior confirming backward compatibility"
  - "SECT-03b (expect_error for missing_sections='error') also passes GREEN because estimate_effort() throws 'unused argument' error — acceptable false-green, will become a stricter test once 39-03 implements the parameter"

patterns-established:
  - "Section fixture helpers use nolint: object_length_linter (names > 30 chars) per project convention"
  - "Section fixture calendar: 12 dates, 6 weekday + 6 weekend, 2 PSUs per stratum per section"
  - "Missing-section fixture: same 12-date calendar but counts for North + Central only; South registered but absent"

requirements-completed: [SECT-01, SECT-02, SECT-03, SECT-04, SECT-05]

duration: 5min
completed: "2026-03-10"
---

# Phase 39 Plan 02: Section Effort Test Fixtures and RED Stubs Summary

**TDD RED phase: seven failing test stubs covering SECT-01 through SECT-05 section effort behaviors, plus two fixture helpers that build 3-section creel designs with 36-row count datasets**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-10T23:41:54Z
- **Completed:** 2026-03-10T23:46:57Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added `make_3section_design_with_counts()`: 3-section (North/Central/South), 2-stratum design with 12 dates, 2 PSUs per stratum per section, 36 count rows total; effort varies materially across sections
- Added `make_section_design_with_missing_section()`: same calendar + registered sections but counts contain only North and Central; South is absent from count data
- Added 7 test stubs (RED) for all SECT requirements: SECT-01 (4-row result with section column), SECT-02a (correlated SE), SECT-02b (independent SE), SECT-03a (missing section warning + NA row), SECT-03b (missing_sections="error" abort), SECT-04 (regression guard), SECT-05 (prop_of_lake_total column)
- Confirmed 144 pre-existing estimate-effort tests continue to pass (zero regressions)

## Task Commits

Each task was committed atomically:

1. **Task 1 + Task 2: Section fixtures and SECT-01..05 stubs** - `26dac3e` (test)

_Note: Both tasks landed in a single commit because the pre-commit hook stash/restore cycle included the stub content from the working tree during the Task 1 commit._

**Plan metadata:** (committed with SUMMARY.md below)

## Files Created/Modified

- `tests/testthat/test-estimate-effort.R` - Added two section fixture helpers and seven SECT test stubs (RED)

## Decisions Made

- `add_sections()` requires `section_col = section` as an explicit unquoted tidy-select argument (no default); updated both fixtures accordingly after initial call without the arg failed with "Must select at least one item"
- SECT-04 regression guard is written to pass GREEN immediately — this is intentional and correct; the test confirms backward compatibility of non-sectioned designs
- Function names `make_3section_design_with_counts` and `make_section_design_with_missing_section` exceed 30 chars; suppress `object_length_linter` inline per project convention (same pattern as Phase 31-02)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed add_sections() call — section_col arg required**
- **Found during:** Task 1 (fixture verification)
- **Issue:** Initial `add_sections(design, sections_df)` call failed with "Must select at least one item" — the function requires an explicit `section_col = section` argument (no default)
- **Fix:** Added `section_col = section` to both fixture helpers
- **Files modified:** tests/testthat/test-estimate-effort.R
- **Verification:** Fixtures confirmed to build valid designs with `d1$sections$section` = c("North","Central","South")
- **Committed in:** 26dac3e (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in fixture construction)
**Impact on plan:** Required fix to use the correct API. No scope creep.

## Issues Encountered

- Pre-commit hook stash/restore cycle caused both task sets (fixtures + stubs) to be committed together in a single commit. Both tasks are present in 26dac3e. No content was lost.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 39-03 can implement `estimate_effort_sections()` and the section dispatch block to turn all 5 RED stubs GREEN
- The fixture helpers are ready to reuse in Plan 39-03 for GREEN verification
- Partial implementation changes to `R/creel-estimates.R` (unstaged — adding `aggregate_sections`, `method`, `missing_sections` params and section dispatch stub) are available in the working tree; Plan 39-03 should build on these

---
*Phase: 39-section-effort-estimation*
*Completed: 2026-03-10*
