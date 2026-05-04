---
gsd_state_version: 1.0
milestone: v1.6.0
milestone_name: Analytical Extensions II
status: in_progress
stopped_at: Phase 84 complete — ready to plan Phase 85
last_updated: "2026-05-03T00:00:00.000Z"
last_activity: 2026-05-03 — Phase 84 executed; impute_camera_counts() shipped; 2578 tests, 0 errors 0 warnings
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
  percent: 50
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** Phase 84 complete — Phase 85 (Mark-Recapture Harvest Estimators) next

## Current Position

Phase: 85 of 86 (Mark-Recapture Harvest Estimators) — not yet planned
Plan: — (not yet executed)
Status: Phase 84 complete; ready to discuss/plan Phase 85
Last activity: 2026-05-03 — Phase 84 executed (2 plans, 2 waves); impute_camera_counts() implemented, documented, tested; devtools::check() 0 errors 0 warnings; 2578 tests passing

Progress: [####      ] 50%

## Accumulated Context

### Decisions

- Jolly-Seber (MR-F01) deferred — output contract incompatible with `creel_estimates`; closed-population only in Phase 85
- GLMM tier (glmmTMB) is opt-in via `method = "glmm"` in Phase 84; GLM default has no new deps
- `audit_strata()` audits effort precision only in v1.6.0 — CPUE precision deferred to STRAT-F01
- `FSA` in Suggests only (guarded); `glmmTMB` in Suggests only (guarded); Imports unchanged
- creel_n_camera() is standalone (Phase 83 complete); power_creel(mode = "camera_n") remains deferred
- intercept-only GLM per stratum (`count ~ 1`) — `strata_col` has one unique value within each stratum subset; `count ~ strata_col` would fail with "contrasts need 2+ levels"

### Phase 83 Outcomes

- `creel_n_camera()` added to `R/power-sample-size.R` — Cochran (1977) eq. 5.25 with Feltz-Middaugh (2025) minimums
- `export(creel_n_camera)` in NAMESPACE; `man/creel_n_camera.Rd` created
- `_pkgdown.yml` updated: creel_n_camera between creel_n_effort and creel_n_cpue
- 10 test_that() blocks appended to tests/testthat/test-power-sample-size.R (CDES-01/02/03)
- devtools::check(): 0 errors | 0 warnings | 1 pre-existing note; 2556 tests passing
- Pre-existing vignette bug fixed: visualisation.Rmd boxplot column corrected

### Phase 84 Outcomes

- `impute_camera_counts()` added to `R/impute-camera-counts.R` (188 lines)
- GLM default (Poisson, Hartill 2016) + GLMM opt-in (nbinom2, Afrifa-Yamoah 2020)
- `glmmTMB` added to DESCRIPTION Suggests (alphabetical: between flexdashboard and hedgehog)
- `export(impute_camera_counts)` in NAMESPACE; `man/impute_camera_counts.Rd` created
- `_pkgdown.yml` updated: impute_camera_counts in Survey Design section (after est_effort_camera)
- 21 test_that() blocks in tests/testthat/test-impute-camera-counts.R covering CAMP-01 through CAMP-05
- devtools::check(): 0 errors | 0 warnings | 1 pre-existing note; 2578 tests passing

### Pending Todos

None.

### Blockers/Concerns

None. Package state: rcmdcheck 0 errors 0 warnings, 2578 tests passing.

## Session Continuity

Last session: 2026-05-03
Stopped at: Phase 84 complete
Resume file: .planning/phases/085-mark-recapture/085-CONTEXT.md (if exists, otherwise discuss first)
