---
gsd_state_version: 1.0
milestone: v1.7.0
milestone_name: API Connection & Real-Data Validation
status: active
stopped_at: Phase 88 — context gathered, ready for planning
last_updated: "2026-05-09T00:00:00.000Z"
last_activity: 2026-05-09 -- Phase 88 context gathered via discuss-phase
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-09)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** v1.7.0 — API Connection & Real-Data Validation

## Current Position

Phase: 88 — httr2 Hardening and API Fetch Methods
Plan: —
Status: Not started
Last activity: 2026-05-09 — Roadmap written; Phase 88 is next

Progress: [----------] 0% (0/3 phases complete)

## Phase Summary

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 88 | Users can call any `fetch_*` method on a `creel_connection_api` and receive canonical data | API-01 – API-06 | Not started |
| 89 | Users can discover available surveys; non-API connections get clean errors | API-07, API-08 | Not started |
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

### Research Flags (Live API Unknowns)

These require live API inspection during Phase 88 implementation:
- Exact JSON field name for angler count in `GetCountData` (candidate: `ii_NumberAnglers`)
- Whether `catch_uid` and `length_uid` exist in API responses (absent from reference code; may need synthesis)
- `ir_Count` aggregation policy for release lengths — decide before `fetch_release_lengths` is written
- Discovery pagination — if `GetAvailableCreels` returns paginated results, add `req_perform_iterative()`

### Future Requirements (Carry-Forward from v1.6.0)

These remain deferred and are not in scope for v1.7.0:
- **MR-F01**: Jolly-Seber open-population estimator — output contract incompatible with `creel_estimates`
- **CAMP-F01**: Multiple imputation via Rubin's rules
- **STRAT-F01**: CPUE precision audit in `audit_strata(type = "cpue")`
- **QUAL-05**: rOpenSci formal submission — deferred to undetermined future date

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-05-09
Stopped at: Roadmap created — Phase 88 not yet started
Resume: Run `/gsd-plan-phase 88` to begin Phase 88 planning
