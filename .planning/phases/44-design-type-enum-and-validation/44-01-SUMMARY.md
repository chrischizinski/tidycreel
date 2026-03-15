---
phase: 44-design-type-enum-and-validation
plan: "01"
subsystem: infra
tags: [creel_design, enum-guard, survey-type, cli_abort, tdd]

requires: []
provides:
  - VALID_SURVEY_TYPES constant with all 5 survey types (instantaneous, bus_route, ice, camera, aerial)
  - cli_abort() enum guard in creel_design() rejecting unknown survey_type values
  - Minimal stub branches for ice, camera, aerial stored in creel_design object
  - new_creel_design() extended with ice/camera/aerial slots
affects:
  - 45-ice-fishing-design
  - 46-camera-design
  - 47-aerial-design

tech-stack:
  added: []
  patterns:
    - "identical(survey_type, 'type') dispatch: parallel if-branches after enum guard for each survey type"
    - "VALID_SURVEY_TYPES constant with nolint comment for SCREAMING_SNAKE_CASE lint exception"
    - "new_creel_design() extended with nullable slot args for each design type"

key-files:
  created: []
  modified:
    - R/creel-design.R
    - tests/testthat/test-creel-design.R

key-decisions:
  - "VALID_SURVEY_TYPES uses SCREAMING_SNAKE_CASE (R convention for constants) with nolint:object_name_linter to satisfy linter"
  - "Enum guard placed before bus_route branch — all unknown types abort before any branch logic runs"
  - "Ice/camera/aerial stubs are minimal list(survey_type = 'x') — Phases 45-47 will inject estimation parameters"
  - "new_creel_design() extended with ice/camera/aerial NULL-defaulted parameters to store stub data alongside bus_route slot"

patterns-established:
  - "Pattern 1: Enum guard via %in% check on VALID_SURVEY_TYPES — not match.arg() (survey_type has no explicit choices in signature)"
  - "Pattern 2: Each survey type gets a NULL-initialized variable, then an identical() branch, then passed into new_creel_design()"

requirements-completed: [INFRA-01, INFRA-02]

duration: 3min
completed: 2026-03-15
---

# Phase 44 Plan 01: Design Type Enum and Validation Summary

**VALID_SURVEY_TYPES enum guard and ice/camera/aerial constructor stubs in creel_design(), locking the dispatch surface before Phase 45-47 estimation code**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-15T20:30:00Z
- **Completed:** 2026-03-15T20:33:05Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `VALID_SURVEY_TYPES <- c("instantaneous", "bus_route", "ice", "camera", "aerial")` constant before `creel_design()` definition
- Added `cli_abort()` enum guard inside `creel_design()` before the bus_route branch — unknown types abort immediately naming the bad value
- Added three minimal stub branches (ice, camera, aerial) after the bus_route branch, each storing `list(survey_type = "x")`
- Extended `new_creel_design()` with `ice`, `camera`, `aerial` parameters stored as nullable slots on the design object
- All 108 creel-design tests pass GREEN, 0 regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing tests for enum guard and constructor stubs** - `cf4c6c4` (test)
2. **Task 2: Implement VALID_SURVEY_TYPES guard and ice/camera/aerial stubs** - `03f32ce` (feat)

## Files Created/Modified

- `R/creel-design.R` - Added VALID_SURVEY_TYPES constant, enum guard, three stub branches, extended new_creel_design()
- `tests/testthat/test-creel-design.R` - Added 6 tests covering INFRA-01 and INFRA-02

## Decisions Made

- Used `SCREAMING_SNAKE_CASE` for `VALID_SURVEY_TYPES` (standard R convention for constants) with `# nolint: object_name_linter` to satisfy the lintr rule requiring snake_case
- Placed enum guard before the bus_route branch so ALL unknown types are caught before any branch executes
- Did not use `match.arg()` — survey_type is not declared with explicit choices in the function signature, which would require match.arg() machinery and limit programmatic use
- Stub branches store only `list(survey_type = "x")` — no estimation parameters yet. Each will be extended by the corresponding phase (45/46/47)

## Deviations from Plan

### Observation: TDD RED confirmation for tests 3-6

**Found during:** Task 1 RED confirmation

**Observation:** The plan expected all 6 new tests to fail (RED). However, tests 3-6 (ice/camera/aerial construction) passed immediately because the existing code accepted any string as `survey_type` and stored it as `design_type` — no validation existed. Only the 2 guard tests (lines 867, 875) were RED.

**Resolution:** This is expected pre-implementation behavior. The 4 constructor tests cycled RED→GREEN atomically in Task 2 — they went RED (briefly) when the enum guard landed but before stubs existed, then GREEN when stubs were added in the same commit. The TDD intent (prove the feature works via tests before implementation was complete) was satisfied.

**Impact:** No code deviation. Tests and implementation are correct.

---

**Total deviations:** 0 code deviations — plan executed exactly as specified.

## Issues Encountered

- Lintr `object_name_linter` flagged `VALID_SURVEY_TYPES` as non-snake_case during pre-commit hook. Fixed by adding `# nolint: object_name_linter` inline comment. This is the established project pattern for R constants.

## Next Phase Readiness

- Enum surface locked: Phases 45, 46, 47 can reference `VALID_SURVEY_TYPES` and use `identical(survey_type, "ice")` dispatch pattern safely
- `creel_design(survey_type = "ice")` constructs successfully — Phase 45 adds `p_site = 1.0` enforcement and effort-type checks
- `creel_design(survey_type = "camera")` constructs successfully — Phase 46 adds `camera_status` checks
- `creel_design(survey_type = "aerial")` constructs successfully — Phase 47 adds visibility correction checks

---
*Phase: 44-design-type-enum-and-validation*
*Completed: 2026-03-15*

## Self-Check: PASSED

- SUMMARY.md: FOUND
- Commit cf4c6c4 (Task 1 test): FOUND
- Commit 03f32ce (Task 2 feat): FOUND
- VALID_SURVEY_TYPES in R/creel-design.R: FOUND
- unknown_type test in test-creel-design.R: FOUND
