---
gsd_state_version: 1.0
milestone: v1.7.0
milestone_name: API Connection & Real-Data Validation
status: active
stopped_at: Phase 89 — complete (2026-05-10)
last_updated: "2026-05-10T22:00:00.000Z"
last_activity: 2026-05-10 -- Phase 89 complete (list_creels, search_creels, 142 tests pass)
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 5
  completed_plans: 5
  percent: 67
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-09)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** v1.7.0 — API Connection & Real-Data Validation

## Current Position

Phase: 90 — Real-Data Validation
Plan: —
Status: Not started (ready to plan)
Last activity: 2026-05-10 — Phase 89 complete (2/2 plans; 142 tests pass)

Progress: [######----] 67% (2/3 phases complete)

## Phase Summary

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 88 | Users can call any `fetch_*` method on a `creel_connection_api` and receive canonical data | API-01 – API-06 | Complete (2026-05-09) |
| 89 | Users can discover available surveys; non-API connections get clean errors | API-07, API-08 | Complete (2026-05-10) |
| 90 | Standalone script validates full pipeline against Calamus 2016 reference outputs | REAL-01 | Not started |

## Accumulated Context

### v1.6.0 Archive

All v1.6.0 work is archived:
- `.planning/milestones/v1.6-ROADMAP.md` — full phase archive
- `.planning/milestones/v1.6-REQUIREMENTS.md` — all 19 requirements marked complete
- `.planning/MILESTONES.md` — milestone entry added

### v1.7.0 Technical Context

Key decisions carried into this milestone from research:

- `httr2` promoted from `Suggests` to `Imports` in `tidycreel.connect/DESCRIPTION` (floor `>= 1.0.0`)
- API field names are NGPC-fixed, not schema-mediated — each `fetch_*` method uses a hardcoded `api_rename_map`, never schema key lookups
- `iiUID` (no underscore) is the harvest/release length join key vs `ii_UID` for interviews — wrong map silently drops `interview_uid`
- ISO-8601 datetime fields silently become NA with `as.Date()` — `.parse_api_date()` must be called in all API methods
- Empty JSON array (`[]`) returns 0-row data.frame from `resp_body_json(simplifyVector = TRUE)` — current empty-response guard in `.api_fetch()` must be fixed
- Bus-route interviews are intentionally duplicated (2x/4x rows per `interview_uid` in Calamus 2016) — no deduplication
- `catch_type` in Calamus 2016 has three values: "harvested", "released", "caught"
- Species code `86` is valid and distinct from `862`

### Implementation File Targets

- `.api_fetch()` hardening: `tidycreel.connect/R/creel-connection-api.R`
- Five new S3 methods: `tidycreel.connect/R/fetch-loaders.R`
- New discovery generics: `tidycreel.connect/R/creel-discovery.R` (new file)
- Integration script: `inst/validation/calamus-2016-validation.R` (new file)

### Phase 89 Decisions (from 89-CONTEXT.md)

- D-01: `GetAvailableCreels` called with no UID filter — `.api_fetch()` extended with `no_uid_filter = FALSE` parameter; `list_creels.creel_connection_api()` passes `no_uid_filter = TRUE` to skip UID query injection
- D-02: Discovery endpoint key added to `.default_api_endpoints()` as `discovery = "AnalysisData/GetAvailableCreels"` with `# TODO: confirm endpoint path` comment
- D-03: NGPC discovery JSON field names unknown — hardcoded TODO-placeholder rename map in `list_creels.creel_connection_api()`
- D-04: `search_creels()` is client-side — calls `list_creels(conn)` then filters with `grepl(keyword, ..., ignore.case = TRUE)`
- D-05: Search covers `title` and `description` only (not `comments`)
- D-06: Case-insensitive matching (`ignore.case = TRUE`)
- D-07: Not-supported error pattern uses `.fn` and `.cls` cli inline markup; permanent (not "not yet implemented")

### Research Flags (Live API Unknowns)

- Exact JSON field name for angler count in `GetCountData` (candidate: `ii_NumberAnglers`) — deferred to Phase 90
- Discovery pagination — if `GetAvailableCreels` returns paginated results — deferred to Phase 90
- All discovery `api_rename_map` field names have TODO comments; confirm with live API during Phase 90

### Future Requirements (Carry-Forward from v1.6.0)

These remain deferred and are not in scope for v1.7.0:
- **MR-F01**: Jolly-Seber open-population estimator — output contract incompatible with `creel_estimates`
- **CAMP-F01**: Multiple imputation via Rubin's rules
- **STRAT-F01**: CPUE precision audit in `audit_strata(type = "cpue")`
- **QUAL-05**: rOpenSci formal submission — deferred to undetermined future date

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-05-10
Stopped at: Phase 89 complete
Resume: Run `/gsd-plan-phase 90` to plan Phase 90 (Real-Data Validation)
