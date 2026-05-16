# Project Research Summary

**Project:** tidycreel.connect — API Connection & Real-Data Validation
**Domain:** R package REST API client + real-data integration testing
**Researched:** 2026-05-09
**Confidence:** HIGH

## Executive Summary

The v1.7.0 milestone completes `tidycreel.connect`'s API backend by implementing five S3 dispatch methods (`fetch_interviews`, `fetch_counts`, `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`) for the `creel_connection_api` class, plus two new discovery generics (`list_creels`, `search_creels`). The package already has working infrastructure: constructor, `.api_fetch()` HTTP helper, `.parse_api_date()`, and validators. The new methods slot directly into the existing S3 dispatch chain — each calls `.api_fetch()`, renames columns via a hardcoded `api_rename_map`, coerces types, and delegates to the same validators used by CSV methods.

The primary technical decision is promoting `httr2` from `Suggests` to `Imports` (floor `>= 1.0.0`) and adding `req_error()` plus `req_retry(max_tries = 3L)` to `.api_fetch()`. No new packages are needed. The critical architectural constraint: API fetch methods must use **hardcoded `api_rename_map` values** with literal NGPC JSON field names (`"ii_UID"`, `"cd_Date"`, `"iiUID"`) rather than routing through the schema lookup — schema keys resolve CSV column names, not API field names. This is the single point most likely to cause silent failures if missed.

The real-data validation component (Calamus 2016 bus-route survey) surfaces four integration gotchas: bus-route interview data has intentional multi-row UIDs (do not deduplicate), `catch_type` includes a third value `"caught"` beyond harvested/released, species code `86` is valid and distinct from `862`, and refused interviews are absent from this export but filters must be written defensively. The integration script must be offline-capable using static JSON fixtures for CI safety.

## Key Findings

### Recommended Stack

One DESCRIPTION change: `httr2` moves from `Suggests` to `Imports` with floor `>= 1.0.0`. Three new httr2 call sites added to `.api_fetch()`: `req_error(body = fn)` for structured API error extraction, `req_retry(max_tries = 3L)` for transient failure resilience, and `resp_body_json(check_type = FALSE)` as a conditional fallback for non-standard Content-Type responses.

**Core technologies:**
- `httr2 >= 1.0.0` (promoted to Imports): All HTTP — request building, auth, JSON decode, error propagation, retry
- `cli` (already in Imports): All user-facing messages and abort conditions
- `jsonlite` (transitive via httr2, do not declare): JSON parsing via `resp_body_json(simplifyVector = TRUE)`

Rejected: `janitor` (bulk snake_case is wrong for known stable API field names); explicit `jsonlite` in DESCRIPTION (transitive dep, maintenance burden).

### Expected Features

All seven items are P1 — no deferral possible without leaving the API backend non-functional.

**Must have (table stakes):**
- `fetch_interviews.creel_connection_api` — effort arithmetic: `ii_TimeFishedHours + ii_TimeFishedMinutes / 60`; only method requiring field arithmetic beyond pure rename
- `fetch_counts.creel_connection_api` — `angler_count` field candidate: `ii_NumberAnglers` (needs live API verification)
- `fetch_catch.creel_connection_api` — species integer codes coerced to character; `catch_uid` may need synthesis if absent from API response
- `fetch_harvest_lengths.creel_connection_api` — `iiUID` field (no underscore vs interviews); `length_type = "harvest"` constant injected post-rename
- `fetch_release_lengths.creel_connection_api` — same `iiUID`; `ir_Count` aggregation policy must be decided before implementation
- `list_creels()` — `GetAvailableCreels` endpoint; `toupper()` on GUID; returns `creel_uid`, `title`, `description`, `active`, `data_complete`, `comments`
- `search_creels()` — `GetMatchingCreels?searchText={text}`; same return shape as `list_creels`

**Should have (add during this milestone):**
- CSV/SQL Server stubs for `list_creels`/`search_creels` generics (prevents cryptic "no applicable method" errors)

**Defer:**
- `fetch_*` for `creel_connection_sqlserver`; code table accessors; auto-discovery in constructor

### Architecture Approach

All new code fits within three target files. The five `fetch_*.creel_connection_api` methods go into `fetch-loaders.R` immediately after their CSV counterparts. A new `creel-discovery.R` holds the two generics and their API implementations plus CSV stubs. A new `.api_fetch_discovery()` internal helper (same auth logic as `.api_fetch()`, minus `uid_param`) should be backed by a shared `.build_authed_request()` extractor to avoid auth logic duplication.

**Major components:**
1. `.api_fetch()` in `creel-connection-api.R` — field-agnostic HTTP GET + JSON decode (receives `req_error`, `req_retry`, corrected empty-response guard)
2. `fetch_*.creel_connection_api` in `fetch-loaders.R` — per-table hardcoded `api_rename_map`, coerce, validate
3. `creel-discovery.R` (new) — `list_creels()` and `search_creels()` generics with API implementations and CSV stubs

### Critical Pitfalls

1. **API field names are NGPC-fixed, not schema-mediated** — `ii_UID`, `cd_Date`, `Num`, `CatchType`, `iiUID` — use hardcoded per-method `api_rename_map`, never schema key lookups
2. **ISO-8601 datetime silently becomes NA** — `as.Date("2016-04-02T00:00:00")` returns NA; must call `.parse_api_date()` in all API methods; validator passes because NA has class Date
3. **`iiUID` vs `ii_UID`** — harvest/release length endpoints use `iiUID` (no underscore); wrong rename map silently drops `interview_uid`
4. **Empty JSON array guard is wrong** — `resp_body_json(simplifyVector = TRUE)` on `[]` returns 0-row data.frame, not zero-length list; current guard will fail to catch this case
5. **Bus-route interviews are intentionally duplicated** — Calamus 2016 has 2x/4x rows per `interview_uid`; deduplication silently produces effort estimates 50–75% too low

## Implications for Roadmap

Based on research, suggested phase structure (continuing from Phase 87):

### Phase 88: httr2 Hardening + API Fetch Methods
**Rationale:** The five fetch methods are the core deliverable and share a single template. All five API pitfalls occur here. Hardening `.api_fetch()` first provides a foundation all five methods inherit automatically.
**Delivers:** Fully functional `creel_connection_api` backend. Any tidycreel workflow that works on CSV connections works on API connections after this phase.
**Addresses:** httr2 promotion, `req_error` + `req_retry`, empty-response guard fix, all five `fetch_*.creel_connection_api` methods with hardcoded `api_rename_map`, `length_type` injection, `catch_uid`/`length_uid` gap resolution.
**Avoids:** API-1 (field name mismatch), API-2 (date NA), API-3 (empty guard), API-5 (`iiUID`).
**Build order within phase:** `fetch_interviews` first (template + most complex), `fetch_counts`, `fetch_catch`, then `fetch_harvest_lengths` + `fetch_release_lengths` together.

### Phase 89: Discovery Generics
**Rationale:** Reuses hardened HTTP plumbing from Phase 88. Discovery functions are architecturally distinct from fetch methods — building after Phase 88 ensures auth bugs are already fixed.
**Delivers:** `creel-discovery.R` with `list_creels()` and `search_creels()` generics, API implementations, CSV stubs.
**Addresses:** `toupper()` GUID normalization, `data_complete` + `comments` in return shape, CSV stubs for clean "not supported" errors.
**Avoids:** standalone function anti-pattern; auto-discovery in constructor.

### Phase 90: Real-Data Validation (Calamus 2016 Integration)
**Rationale:** Integration against Calamus 2016 archived CSV data validates the full estimation pipeline against known real-world outputs.
**Delivers:** Integration script comparing CSV backend output against reference report values; offline-capable mock-response fixtures.
**Addresses:** INT-1 (multi-row interview assertion), INT-2 (`catch_type` "caught"), INT-3 (species code inventory), INT-4 (refused-interview defensive filter), INT-5 (offline/fixture-based CI safety).

### Phase Ordering Rationale

- Phase 88 before Phase 89: `.api_fetch_discovery()` inherits hardened auth logic from Phase 88
- Phase 88 before Phase 90: Integration validation is only meaningful once fetch methods return correct canonical output
- Phase 89 and Phase 90 are largely independent after Phase 88 is complete

### Research Flags

Within-phase unknowns requiring live API inspection during Phase 88 implementation:
- Exact JSON field name for angler count in `GetCountData` (candidate: `ii_NumberAnglers`)
- Whether `catch_uid` and `length_uid` exist in API responses (absent from reference code)
- `ir_Count` aggregation policy for release lengths — decide before `fetch_release_lengths` is written

All three phases have well-documented patterns — existing CSV methods are the direct implementation template.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | httr2 docs verified via r-lib.org official reference; CRAN version confirmed |
| Features | HIGH | Field mappings derived directly from NGPC `CreelApiHelper.R` and `CreelDataAccess.R` |
| Architecture | HIGH | Direct codebase analysis of all `tidycreel.connect` R files |
| Pitfalls | HIGH | Calamus 2016 CSV inspected directly; NGPC legacy code read; httr2 `simplifyVector` behavior confirmed |

**Overall confidence: HIGH**

### Gaps to Address During Implementation

- **`angler_count` field name:** Inspect live `GetCountData` response. Candidate: `ii_NumberAnglers`.
- **`catch_uid` / `length_uid` existence:** Inspect live API response. If absent, synthesize with `cli_warn()`.
- **`ir_Count` aggregation policy:** Decide before `fetch_release_lengths` is written — do not silently expand rows.
- **Discovery pagination:** If `GetAvailableCreels` returns paginated results, add `req_perform_iterative()`.

## Sources

### Primary (HIGH confidence)
- `CreelApiHelper.R` v3.0 (NGPC, 2018-05-04) — authoritative API field names, endpoint paths, discovery shapes
- `CreelDataAccess.R` v3.2.1 (NGPC, 2021-05-11) — SQL view column selections, `iiUID` vs `ii_UID` confirmation
- `tidycreel.connect` source files — existing implementation baseline
- httr2 official reference (r-lib.org): `req_error`, `req_retry`, `req_perform_iterative`, `resp_body_raw`
- Calamus 2016 archive CSVs — bus-route multi-row UID, three-value `catch_type`, species code `86`

### Secondary (MEDIUM confidence)
- httr2 wrapping APIs vignette — patterns for building API client packages

---
*Research completed: 2026-05-09*
*Ready for roadmap: yes*
