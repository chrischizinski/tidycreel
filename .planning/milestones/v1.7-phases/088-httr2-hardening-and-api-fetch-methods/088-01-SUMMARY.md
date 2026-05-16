---
plan: 088-01
phase: 088-httr2-hardening-and-api-fetch-methods
status: complete
requirements: [API-06]
---

## Summary

Promoted `httr2` from a soft suggestion to a hard import, hardened `.api_fetch()` with structured error handling and retry logic, and created the test scaffold that all API method tests depend on.

## What Was Built

**DESCRIPTION** — `httr2 (>= 1.0.0)` added to `Imports` (between DBI and readr alphabetically). Removed from `Suggests` (it was not there; no action needed).

**creel-connection-api.R** — `.api_fetch()` rewritten:
- Removed `requireNamespace("httr2")` guard block
- Added `req_error(req, is_error = \(resp) FALSE)` to disable httr2 auto-abort
- Added `req_retry(req, max_tries = 3L)` for 429/503 retry (httr2 default backoff)
- Added `status >= 400L` branch with `cli_abort("API request failed [{status}]", "i" = "Endpoint: {endpoint}", "x" = body_text)`

**helper-api.R** — `make_api_conn()` fixture returns a `creel_connection_api` pointing at `http://test.example.com/api/` with `creel_uids = "test-uid-001"`.

**test-api-fetch.R** — 4 test cases via `httr2::local_mocked_responses()`:
1. 200 response → `is.data.frame(result)` passes
2. 404 response → `cli_abort("API request failed [404]")` thrown
3. 429→200 sequence → no error (retry succeeds)
4. 429×3 sequence → `cli_abort("API request failed")` thrown

## Deviations

None. All changes match plan specification.

## Notes

The 4 tests in `test-api-fetch.R` call `fetch_interviews(conn)` which dispatches to `fetch_interviews.creel_connection_api`. That method is added in Plan 088-02. The test scaffold is complete but full passage requires Plan 088-02 to be executed first.

Existing CSV-backend test suite: 54 tests passed, 0 failures, 3 skipped (duckdb not installed — expected).

## Self-Check: PASSED

Key files:
- `tidycreel.connect/DESCRIPTION` — `httr2 (>= 1.0.0)` in Imports ✓
- `tidycreel.connect/R/creel-connection-api.R` — req_error + req_retry + cli_abort ✓
- `tidycreel.connect/tests/testthat/helper-api.R` — make_api_conn() ✓
- `tidycreel.connect/tests/testthat/test-api-fetch.R` — 4 API-06 test cases ✓

Commits: `feat(088-01)` (DESCRIPTION + creel-connection-api.R), `test(088-01)` (helper-api.R + test-api-fetch.R)
