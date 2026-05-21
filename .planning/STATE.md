---
gsd_state_version: 1.0
milestone: v1.8.0
milestone_name: Exports, Bootstrap CIs, and API Hardening
status: executing
stopped_at: Phase 94 complete
last_updated: "2026-05-20T22:00:00.000Z"
last_activity: 2026-05-20 -- Phase 94 complete; bootstrap CIs for all 4 estimators; 2729 tests pass, rcmdcheck 0 warnings
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 21
  completed_plans: 19
  percent: 90
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-16)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** All v1.8.0 phases (91–94) COMPLETE — ready for milestone close

## Current Position

Phase: 94 (Bootstrap Confidence Intervals) — COMPLETE
Plan: all three plans done; bootstrap CIs in estimate_total_harvest(), estimate_total_catch(), estimate_angler_n(), estimate_mr_harvest()
Status: Ready to execute
Last activity: 2026-05-20 -- Phase 93 planning complete

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

## Accumulated Decisions (Phase 92)

- validation scripts must guard `devtools::load_all()` with `isNamespaceLoaded()` — prevents namespace corruption when sourced during R CMD check test suite
- Use `--` (ASCII) not `—` escape for em dashes in R source comments; `\uXXXX` only works inside R string literals
- `_R_CHECK_FORCE_SUGGESTS_=FALSE` required locally for rcmdcheck when optional Suggests are not installed

## Session Continuity

Last session: 2026-05-20T15:34:01.988Z
Stopped at: Phase 93 context gathered
Next: Phase 93 (Reporting Exports) — /gsd:plan-phase 93
