---
plan: 088-03
phase: 088-httr2-hardening-and-api-fetch-methods
status: complete
requirements: [API-03, API-04, API-05]
---

## Summary

Implemented the final three API fetch methods: `fetch_catch`, `fetch_harvest_lengths`, and `fetch_release_lengths` for `creel_connection_api`. All three use UID synthesis (absent from API) and the length methods inject a constant `length_type` value. Phase 88 is now feature-complete.

## What Was Built

**fetch-loaders.R additions:**

`fetch_catch.creel_connection_api()`:
- api_rename_map: `ii_UID → interview_uid`, `ir_Species → species`, `Num → catch_count`, `CatchType → catch_type`
- `catch_uid` synthesized via `seq_len(nrow(df))` (absent from API response, D-05/D-06)
- species coerced to character (API may return integer species codes like 86)
- Early 0-row typed return for `[]` response

`fetch_harvest_lengths.creel_connection_api()`:
- api_rename_map: `iiUID → interview_uid` (no underscore — critical pitfall), `ih_Species → species`, `ihl_Length → length_mm`
- `length_uid` synthesized via `seq_len(nrow(df))`
- `length_type` injected as constant `"harvest"` (no flag in API response)
- Early 0-row typed return

`fetch_release_lengths.creel_connection_api()`:
- api_rename_map: `iiUID → interview_uid` (no underscore), `ir_Species → species`, `ir_LengthGroup → length_mm`
- `ir_Count` dropped silently (no canonical target; TODO for Phase 90 live validation)
- `length_uid` synthesized via `seq_len(nrow(df))`
- `length_type` injected as constant `"release"`
- Early 0-row typed return

**NAMESPACE** regenerated: added `S3method(fetch_harvest_lengths,creel_connection_api)` and `S3method(fetch_release_lengths,creel_connection_api)`.

**Tests:**

`test-fetch-catch.R` (2 new API-03 tests):
- Happy path: all 5 canonical columns, species = "86" as character, catch_uid present
- Empty: 0-row with correct column types

`test-fetch-lengths.R` (4 new tests):
- API-04 happy path: length_type = "harvest", iiUID used as interview_uid
- API-04 empty: 0-row with length_type column
- API-05 happy path: length_type = "release", ir_Count column dropped
- API-05 empty: 0-row with length_type column

## Deviations

None. All changes match plan specification exactly.

## Self-Check: PASSED

- `fetch_catch.creel_connection_api` uses `ii_UID` (with underscore) for interview join ✓
- `fetch_harvest_lengths.creel_connection_api` uses `iiUID` (no underscore) — critical distinction ✓
- `fetch_release_lengths.creel_connection_api` uses `iiUID` (no underscore) ✓
- `length_uid` and `catch_uid` synthesized via `seq_len(nrow(df))` ✓
- `length_type` constants "harvest"/"release" injected ✓
- Full test suite: 119 pass, 0 fail, 10 skip (duckdb/config not installed — expected) ✓
