---
gsd_state_version: 1.0
milestone: v1.8.0
milestone_name: Exports, Bootstrap CIs, and API Hardening
status: shipped
stopped_at: Milestone v1.8.0 complete and archived
last_updated: "2026-05-23T00:00:00.000Z"
last_activity: 2026-05-23 -- v1.8.0 milestone closed; archive files created; git tag v1.8.0 pending
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 21
  completed_plans: 21
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-23)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** v1.8.0 SHIPPED — next milestone TBD

## Current Position

Phase: v1.8.0 complete
Plan: All 21 plans done across Phases 91–94; milestone archived
Status: Shipped
Last activity: 2026-05-23 -- Milestone close; ROADMAP.md collapsed; archive files created; REQUIREMENTS.md archived

## Previous Milestone Archive

All v1.8.0 work archived:

- `.planning/milestones/v1.8.0-ROADMAP.md` — full phase archive
- `.planning/milestones/v1.8.0-REQUIREMENTS.md` — all 12 requirements marked complete
- `.planning/milestones/v1.8.0-MILESTONE-AUDIT.md` — audit report (tech_debt — all requirements satisfied)
- `.planning/MILESTONES.md` — v1.8.0 entry added

## Tech Debt Carried to v1.9.0

| Item | REQ | Notes |
|------|-----|-------|
| `write_estimates()` xlsx path test | WRITE-11 | Code exists; `writexl` in Suggests; pattern from SCHED-03 not applied |
| Nyquist VALIDATION.md for Phases 92–94 | process | SUMMARY.md evidence sufficient; no blocker |

## Future Requirements (Deferred)

- **MR-F01**: Jolly-Seber open-population estimator — output contract incompatible with `creel_estimates`
- **CAMP-F01**: Multiple imputation via Rubin's rules — extends `impute_camera_counts()`
- **STRAT-F01**: CPUE precision audit in `audit_strata(type = "cpue")`
- **QUAL-05**: rOpenSci formal submission — deferred to undetermined future date

## Session Continuity

Last session: 2026-05-23
Stopped at: Milestone v1.8.0 close
Next: `/gsd:new-milestone` to start v1.9.0 requirements and roadmap
