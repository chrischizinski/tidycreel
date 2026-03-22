---
phase: 47-aerial-survey-support
plan: 01
subsystem: estimation
tags: [aerial, creel-design, survey, svytotal, effort-estimation, tdd]

# Dependency graph
requires:
  - phase: 46-remote-camera-survey-support
    provides: camera constructor pattern (camera_mode required param) and creel_design dispatch architecture
  - phase: 44-infra
    provides: VALID_SURVEY_TYPES enum with aerial stub
provides:
  - creel_design(survey_type = "aerial", h_open = N) constructor with h_open required and visibility_correction optional
  - estimate_effort_aerial() internal function using svytotal x h_over_v (no delta method)
  - aerial dispatch block in estimate_effort() after bus_route/ice path
  - AIR-04 test fixture skeleton (skipped, awaiting Malvestuto Box 20.6 values)
affects:
  - 47-02 (catch rate / interview path for aerial — uses design$aerial slot)
  - 47-03 (aerial example datasets and vignette)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - aerial effort = svytotal(~count_var, design$survey) x (h_open / visibility_correction) — linear scaling, no delta method
    - h_over_v = design$aerial$h_open / (design$aerial$visibility_correction %||% 1.0)
    - se_between = SE(svytotal) x h_over_v; se = sqrt(se_between^2 + var_within x h_over_v^2)
    - visibility_correction defaults to 1.0 (no correction) when NULL

key-files:
  created:
    - R/creel-estimates-aerial.R
  modified:
    - R/creel-design.R
    - R/creel-estimates.R
    - tests/testthat/test-creel-design.R
    - tests/testthat/test-estimate-effort.R
    - tests/testthat/test-primary-source-validation.R

key-decisions:
  - "Aerial effort uses svytotal x h_over_v (linear scaling) — not delta method; h_open and v are fixed calibration constants, so SE(E) = SE(svytotal) x h_over_v exactly"
  - "L_bar (mean trip duration) does NOT appear in aerial effort formula — interviews not required for effort; L_bar is only used in catch rate estimation (AIR-05, Plan 02)"
  - "visibility_correction defaults to 1.0 (NULL treated as no correction) — consistent with Pollock et al. 1994 sec.15.6.1"
  - "estimate_effort_aerial() mirrors estimate_effort_total() with h_over_v multiplier — within-day Rasmussen component scaled by h_over_v^2"
  - "AIR-04 Malvestuto Box 20.6 validation test remains skipped pending human checkpoint; fixture skeleton committed with stop() placeholder"

patterns-established:
  - "Aerial dispatch: add design type to NULL-survey guard exclusion list, then insert dedicated dispatch block after bus_route/ice return"
  - "Calibration constant scaling: estimate = svytotal x k; se_between = SE(svytotal) x k; var_within scaled by k^2"

requirements-completed:
  - AIR-01
  - AIR-02
  - AIR-03

# Metrics
duration: 8min
completed: 2026-03-22
---

# Phase 47 Plan 01: Aerial Constructor and Effort Estimator Summary

**Aerial effort estimation via svytotal x (h_open / v) with h_open required constructor validation and visibility_correction in (0, 1]; AIR-04 fixture skeleton skipped pending Malvestuto Box 20.6 human checkpoint**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-22T14:53:44Z
- **Completed:** 2026-03-22T15:01:17Z
- **Tasks:** TDD cycle (WAVE 0 RED + GREEN) completed; 1 checkpoint reached
- **Files modified:** 5

## Accomplishments

- creel_design() extended with h_open (required) and visibility_correction (optional, (0,1]) parameters for aerial surveys
- New R/creel-estimates-aerial.R with estimate_effort_aerial() using survey::svytotal() scaled by h_over_v — no delta method
- Aerial dispatch block added in estimate_effort() after bus_route/ice path; 'aerial' added to NULL-survey guard exclusion list
- 17 new tests for AIR-01/02/03 (constructor validation, effort dispatch, SE formula, visibility correction scaling) — all passing
- AIR-04 test skeleton with skip() and FILL_* placeholder committed; awaiting Malvestuto (1996) Box 20.6 aerial values
- 1678 total tests passing (1 skip)

## Task Commits

TDD cycle with per-phase commits:

1. **WAVE 0 RED — Failing aerial tests** - `65f285e` (test)
2. **GREEN — Constructor + estimator + dispatch** - `995c0da` (feat)

## Files Created/Modified

- `R/creel-estimates-aerial.R` — New internal function estimate_effort_aerial(); mirrors estimate_effort_total() with h_over_v scaling
- `R/creel-design.R` — Added h_open/visibility_correction params to signature; replaced aerial stub with full validation; aerial print section
- `R/creel-estimates.R` — Added 'aerial' to NULL-survey guard; inserted aerial dispatch block after bus_route/ice block
- `tests/testthat/test-creel-design.R` — 7 new AIR-01/02/03 constructor tests; updated existing aerial test to supply h_open = 14
- `tests/testthat/test-estimate-effort.R` — 6 new AIR-01/02/03 effort estimation tests
- `tests/testthat/test-primary-source-validation.R` — AIR-04 make_aerial_box20_6() skeleton with skip() placeholder

## Decisions Made

- Aerial effort uses svytotal x h_over_v (linear scaling, not delta method) — confirmed by Pollock et al. 1994 sec.15.6.1 and correction in project_phase47_aerial_correction.md
- L_bar is not used in aerial effort; interviews not required for estimate_effort() on aerial designs
- visibility_correction == NULL treated as 1.0 (no correction), consistent with published formula
- estimate_effort_aerial() mirrors estimate_effort_total() including within-day Rasmussen variance component scaled by h_over_v^2

## Deviations from Plan

None — plan executed exactly as written (with corrections from project_phase47_aerial_correction.md applied).

## Issues Encountered

- styler and lintr disagreed on indentation in multi-condition if() in aerial constructor; resolved by extracting condition into a named boolean variable (vc_bad)

## Checkpoint: AIR-04 Malvestuto Box 20.6

**Status:** REACHED — awaiting human input

The aerial estimator (AIR-01/AIR-02/AIR-03) is fully implemented and tested. The AIR-04 primary source validation test is skipped with a stop() placeholder in make_aerial_box20_6().

**To complete AIR-04:**
1. Obtain Malvestuto (1996) Box 20.6 aerial example values (N_counted, H_open, v, E_hat)
2. Replace the stop() placeholder in make_aerial_box20_6() with the real fixture
3. Remove the skip() from the test_that block
4. Run devtools::test(filter = "primary-source") to confirm E_hat matches within 1e-6

**If Box 20.6 has no aerial example:** Report that and provide alternate primary source values (Pollock et al. 1994 or constructed numeric example from formula).

## Next Phase Readiness

- Phase 47-02 (catch rate / interview path) can proceed — design$aerial$h_open slot is available
- Phase 47-03 (example datasets + vignette) can proceed after 47-02
- AIR-04 requires human checkpoint before test can be finalized

---
*Phase: 47-aerial-survey-support*
*Completed: 2026-03-22*
