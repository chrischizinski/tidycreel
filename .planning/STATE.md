---
gsd_state_version: 1.0
milestone: v1.8.0
milestone_name: — Exports, Bootstrap CIs, and API Hardening
status: executing
stopped_at: v1.8.0 requirements defined; roadmap creation next
last_updated: "2026-05-16"
last_activity: 2026-05-16 -- Phase 91 complete; all 3 plans done; 153 connect tests, 2668 main tests
progress:
  total_phases: 7
  completed_phases: 4
  total_plans: 11
  completed_plans: 11
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-16)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** Phase 91 — API Security and Hardening

## Current Position

Phase: 91 (API Security and Hardening) — COMPLETE
Plan: 3 of 3
Status: Phase 91 complete; all plans done; 153 connect + 2668 main tests pass
Last activity: 2026-05-16 -- Phase 91 complete

## Previous Milestone Archive

All v1.7.0 work archived:

- `.planning/milestones/v1.7-ROADMAP.md` — full phase archive
- `.planning/milestones/v1.7-REQUIREMENTS.md` — all 9 requirements marked complete
- `.planning/milestones/v1.7.0-MILESTONE-AUDIT.md` — audit report (tech_debt)
- `.planning/MILESTONES.md` — milestone entry added

## Carry-Forward Tech Debt (addressed in v1.8.0)

| Item | Phase | Priority | v1.8.0 REQ |
|------|-------|----------|------------|
| NGPC discovery field names unconfirmed (TODO stubs) | 89 | High | API-09 |
| `list_creels()` silent 0-column return guard (WR-01) | 89 | Medium | API-10 |
| Bus-route API E2E gap (`n_counted`/`n_interviewed` missing) | 88 | Medium | API-11 |
| Validation script working-directory guard (W-01) | 90 | Low | QUAL-01 |
| Pre-existing rcmdcheck warnings (non-ASCII, VignetteBuilder) | 89 | Medium | QUAL-02 |
| `@param endpoints` doc omits `"discovery"` key (WR-02) | 89 | Low | (folded into API-09) |

## Future Requirements (Deferred)

- **MR-F01**: Jolly-Seber open-population estimator — output contract incompatible with `creel_estimates`
- **CAMP-F01**: Multiple imputation via Rubin's rules — extends `impute_camera_counts()`
- **STRAT-F01**: CPUE precision audit in `audit_strata(type = "cpue")`
- **QUAL-05**: rOpenSci formal submission — deferred to undetermined future date

## Session Continuity

Last session: 2026-05-16
Stopped at: Phase 91 complete (all 3 plans: SEC-01 security audit, API-10 tibble fix, API-09+API-11 counts schema refactor)
Resume: Phase 91 complete — next phase TBD based on v1.8.0 roadmap
