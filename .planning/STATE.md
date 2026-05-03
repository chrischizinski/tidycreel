---
gsd_state_version: 1.0
milestone: v1.6.0
milestone_name: Analytical Extensions II
status: in_progress
stopped_at: Phase 83 complete — ready to plan Phase 84
last_updated: "2026-05-03T00:00:00.000Z"
last_activity: 2026-05-03 — Phase 83 executed; creel_n_camera() shipped; 2556 tests, 0 errors 0 warnings
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
  percent: 25
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** Phase 83 complete — Phase 84 (Camera Missing Data Imputation) next

## Current Position

Phase: 84 of 86 (Camera Missing Data Imputation) — not yet planned
Plan: — (not yet executed)
Status: Phase 83 complete; ready to discuss/plan Phase 84
Last activity: 2026-05-03 — Phase 83 executed (2 plans, 2 waves); creel_n_camera() implemented, documented, tested; devtools::check() 0 errors 0 warnings; 2556 tests passing

Progress: [##        ] 25%

## Accumulated Context

### Decisions

- Jolly-Seber (MR-F01) deferred — output contract incompatible with `creel_estimates`; closed-population only in Phase 85
- GLMM tier (glmmTMB) is opt-in via `method = "glmm"` in Phase 84; GLM default has no new deps
- `audit_strata()` audits effort precision only in v1.6.0 — CPUE precision deferred to STRAT-F01
- `FSA` in Suggests only (guarded); `glmmTMB` in Suggests only (guarded); Imports unchanged
- creel_n_camera() is standalone (Phase 83 complete); power_creel(mode = "camera_n") remains deferred

### Phase 83 Outcomes

- `creel_n_camera()` added to `R/power-sample-size.R` — Cochran (1977) eq. 5.25 with Feltz-Middaugh (2025) minimums
- `export(creel_n_camera)` in NAMESPACE; `man/creel_n_camera.Rd` created
- `_pkgdown.yml` updated: creel_n_camera between creel_n_effort and creel_n_cpue
- 10 test_that() blocks appended to tests/testthat/test-power-sample-size.R (CDES-01/02/03)
- devtools::check(): 0 errors | 0 warnings | 1 pre-existing note; 2556 tests passing
- Pre-existing vignette bug fixed: visualisation.Rmd boxplot column corrected

### Pending Todos

None.

### Blockers/Concerns

None. Package state: rcmdcheck 0 errors 0 warnings, 2556 tests passing.

## Session Continuity

Last session: 2026-05-03
Stopped at: Phase 83 complete
Resume file: .planning/phases/084-camera-missing-data/084-CONTEXT.md (if exists, otherwise discuss first)
