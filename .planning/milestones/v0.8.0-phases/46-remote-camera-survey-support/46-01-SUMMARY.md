---
phase: 46-remote-camera-survey-support
plan: 01
subsystem: creel-design
tags: [camera, creel_design, add_counts, estimate_effort, preprocess_camera_timestamps, tdd]

# Dependency graph
requires:
  - phase: 45-ice-fishing-survey-support
    provides: "Ice constructor pattern (effort_type validation), estimate_effort ice dispatch — mirrors exact same validation pattern for camera_mode"
  - phase: 44-infra
    provides: "VALID_SURVEY_TYPES enum lock; camera stub list(survey_type='camera')"

provides:
  - "creel_design(survey_type='camera', camera_mode='counter'|'ingress_egress') — fully validated camera constructor"
  - "preprocess_camera_timestamps() — ingress-egress POSIXct pair → daily_effort_hours data frame"
  - "Camera print method section in format.creel_design()"
  - "Counter-mode and ingress-egress camera flows through standard add_counts() + estimate_effort() path"

affects:
  - "46-02: camera vignette plan — depends on this constructor and preprocess_camera_timestamps()"
  - "Phase 47 (aerial) — mirrors same constructor validation pattern"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "camera_mode validation mirrors ice effort_type pattern: valid_camera_modes <- c(...); cli_abort if NULL or not in valid set"
    - "preprocess_camera_timestamps() uses rlang::as_name(rlang::enquo()) for non-standard evaluation of column selectors"
    - "Ingress-egress preprocessing uses stats::aggregate() for date-level summing with na.rm=TRUE"
    - "Camera standard path: add_counts() populates design$survey → estimate_effort() standard instantaneous path; no new dispatch needed"

key-files:
  created: []
  modified:
    - "R/creel-design.R — camera_mode param, camera stub replacement, format.creel_design() camera section, preprocess_camera_timestamps()"
    - "tests/testthat/test-creel-design.R — CAM-01/CAM-02/CAM-03 constructor and preprocessing tests appended"
    - "tests/testthat/test-estimate-effort.R — CAM-01/CAM-02/CAM-03 effort dispatch tests appended"

key-decisions:
  - "camera_mode is required at construction time (no default) — omitting aborts with informative message naming valid values (counter, ingress_egress)"
  - "preprocess_camera_timestamps() uses rlang::as_name(rlang::enquo()) — consistent with compute_effort() NSE pattern in same file"
  - "Camera uses standard instantaneous path through add_counts() + estimate_effort() with no new dispatch guard — camera NOT added to bus_route/ice special path"
  - "Count data fixtures require strata columns from design (day_type) — validate_counts_tier1 enforces this"

patterns-established:
  - "Camera preprocessing: preprocess_camera_timestamps(timestamps, date_col, ingress_col, egress_col) -> data.frame(date, daily_effort_hours)"
  - "Negative duration handling: cli_warn() with count of bad rows, set to NA_real_, excluded from sum via na.rm=TRUE"

requirements-completed: [CAM-01, CAM-02, CAM-03]

# Metrics
duration: 6min
completed: 2026-03-16
---

# Phase 46 Plan 01: Camera Constructor Summary

**Camera constructor with camera_mode validation (counter/ingress_egress), preprocess_camera_timestamps() helper, and counter/ingress-egress effort estimation via standard add_counts() path**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-16T01:59:16Z
- **Completed:** 2026-03-16T02:05:32Z
- **Tasks:** 2 (RED + GREEN; REFACTOR = no changes needed)
- **Files modified:** 3

## Accomplishments

- Filled the Phase 44 camera stub with full camera_mode validation (aborts on NULL or unknown mode; names valid values in error)
- Added preprocess_camera_timestamps() for ingress-egress mode — converts POSIXct pairs to date-level effort hours with negative-duration warning
- Camera print method section appended to format.creel_design()
- 1645 tests passing (23 net new tests: +14 creel-design, +9 estimate-effort)

## Task Commits

1. **RED — Failing camera tests** - `c9eb250` (test)
2. **GREEN — Camera constructor + preprocess_camera_timestamps()** - `2c19108` (feat)

*TDD plan: RED commit then GREEN commit; lintr/styler via pre-commit on both commits (all passed).*

## Files Created/Modified

- `R/creel-design.R` — Added camera_mode parameter to creel_design() signature; replaced camera stub with camera_mode validation; added camera slot construction; added camera section to format.creel_design(); appended preprocess_camera_timestamps() function
- `tests/testthat/test-creel-design.R` — Updated existing camera test to supply camera_mode = "counter"; appended CAM-01/CAM-02 constructor + preprocessing blocks
- `tests/testthat/test-estimate-effort.R` — Appended CAM-01/CAM-02/CAM-03 effort dispatch blocks

## Decisions Made

- camera_mode required (no default) — follows same enforcement pattern as ice effort_type
- Camera uses standard instantaneous add_counts() + estimate_effort() path — no new dispatch guard needed (camera not in c("bus_route", "ice") special branch)
- preprocess_camera_timestamps() uses rlang::as_name(rlang::enquo()) NSE — consistent with existing compute_effort() pattern in the same file
- Count fixture data must include strata columns (day_type) — validate_counts_tier1 enforces strata alignment

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] add_counts() does not accept a count = column selector**
- **Found during:** GREEN task (CAM-01 effort dispatch test)
- **Issue:** Tests written with `add_counts(design, counts, count = angler_count)` but add_counts() has no `count` parameter — it auto-detects the first numeric column
- **Fix:** Removed `count = ...` argument from all three camera add_counts() calls; added `day_type` strata column to count fixtures (validate_counts_tier1 requires it)
- **Files modified:** tests/testthat/test-estimate-effort.R
- **Verification:** All 3 CAM effort tests pass
- **Committed in:** 2c19108 (GREEN commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in test fixture, corrected inline)
**Impact on plan:** Fixture fix was necessary for correctness. No scope creep.

## Issues Encountered

None beyond the auto-fixed fixture issue above.

## Next Phase Readiness

- CAM-01, CAM-02, CAM-03 constructor + preprocessing complete and tested
- 46-02 (camera vignette) can proceed: creel_design(camera_mode=), preprocess_camera_timestamps(), and estimate_effort() path all verified
- camera_status gap-exclusion pattern documented via CAM-03 test (filter before add_counts())

---
*Phase: 46-remote-camera-survey-support*
*Completed: 2026-03-16*
