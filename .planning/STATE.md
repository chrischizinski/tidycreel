---
gsd_state_version: 1.0
milestone: v1.6.0
milestone_name: Analytical Extensions II
status: planning
stopped_at: roadmap created — ready to plan Phase 83
last_updated: "2026-05-02T00:00:00.000Z"
last_activity: 2026-05-02 — Roadmap created for v1.6.0 (Phases 83-86)
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** Phase 83 — Camera Design Helper (ready to plan)

## Current Position

Phase: 83 of 86 (Camera Design Helper)
Plan: — (not yet planned)
Status: Ready to plan
Last activity: 2026-05-02 — Roadmap created; 4 phases defined (83-86), 19 requirements mapped

Progress: [          ] 0%

## Accumulated Context

### Decisions

- Jolly-Seber (MR-F01) deferred — output contract incompatible with `creel_estimates`; closed-population only in Phase 85
- GLMM tier (glmmTMB) is opt-in via `method = "glmm"` in Phase 84; GLM default has no new deps
- `audit_strata()` audits effort precision only in v1.6.0 — CPUE precision deferred to STRAT-F01
- `FSA` in Suggests only (guarded); `glmmTMB` in Suggests only (guarded); Imports unchanged

### Pending Todos

None.

### Blockers/Concerns

None. Package state: rcmdcheck 0 errors 0 warnings, 2537+ tests passing, rhub Linux/macOS green.
OQ-5 open: `creel_n_camera()` standalone vs `power_creel()` mode — resolve at Phase 83 plan time.

## Session Continuity

Last session: 2026-05-02
Stopped at: Roadmap created for v1.6.0
Resume file: None
