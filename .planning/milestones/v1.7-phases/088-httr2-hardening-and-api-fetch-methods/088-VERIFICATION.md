---
phase: 088-httr2-hardening-and-api-fetch-methods
verified: 2026-05-09T00:00:00Z
status: human_needed
score: 13/14 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Trigger a real 429 response from a staging API and confirm that a second successful request follows on the retry"
    expected: "fetch_interviews() or any fetch_*() call succeeds after the API returns 429 on the first attempt, with no error raised"
    why_human: "httr2::local_mocked_responses() intercepts at req_perform level before the internal retry loop in httr2 1.2.2, making it impossible to drive a 429-then-200 success sequence in unit tests. The is_transient predicate is wired correctly in code, but the positive retry path (SC4: 'retries up to 3 times before aborting') can only be exercised with a real or integration-level server."
---

# Phase 88: httr2 Hardening and API Fetch Methods Verification Report

**Phase Goal:** Users can call any `fetch_*()` method on a `creel_connection_api` object and receive canonical data
**Verified:** 2026-05-09
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `httr2` is declared in `Imports` (not `Suggests`) in `tidycreel.connect/DESCRIPTION` with floor `>= 1.0.0` | VERIFIED | Line 19: `httr2 (>= 1.0.0),` under `Imports:` block; not present in `Suggests` |
| 2 | `fetch_interviews()` returns a data frame with columns `interview_uid`, `date`, `catch_count`, `effort`, `trip_status` and effort computed as hours + minutes/60 | VERIFIED | `fetch_interviews.creel_connection_api()` at fetch-loaders.R:90-128; api_rename_map maps `ii_UID`, `cd_Date`, `Num`, `ii_TripType`; effort arithmetic at lines 117-119; test `expect_equal(result$effort, 2 + 30 / 60)` passes |
| 3 | `fetch_counts()` returns data frame with columns `date` (Date), `angler_count` (numeric) | VERIFIED | `fetch_counts.creel_connection_api()` at fetch-loaders.R:168-192; api_rename_map maps `cd_Date` and `ii_NumberAnglers`; test verifies types and `result$angler_count == 12` |
| 4 | `fetch_catch()` returns data frame with columns `catch_uid`, `interview_uid`, `species` (character), `catch_count`, `catch_type` | VERIFIED | `fetch_catch.creel_connection_api()` at fetch-loaders.R:236-271; `catch_uid` synthesized via `seq_len(nrow(df))`; species coerced with `as.character()`; test verifies `is.character(result$species)` and `result$species == "86"` |
| 5 | `fetch_harvest_lengths()` returns data frame with columns `length_uid`, `interview_uid`, `species`, `length_mm`, `length_type` where `length_type` is always `"harvest"` | VERIFIED | `fetch_harvest_lengths.creel_connection_api()` at fetch-loaders.R:314-351; `iiUID` (no underscore) used as join key; `df$length_type <- "harvest"` at line 344; test verifies `expect_equal(result$length_type, "harvest")` |
| 6 | `fetch_release_lengths()` returns data frame with columns `length_uid`, `interview_uid`, `species`, `length_mm`, `length_type` where `length_type` is always `"release"` | VERIFIED | `fetch_release_lengths.creel_connection_api()` at fetch-loaders.R:394-433; `iiUID` (no underscore) used as join key; `df$length_type <- "release"` at line 426; test verifies `expect_equal(result$length_type, "release")` |
| 7 | `.api_fetch()` aborts with a human-readable cli error message including HTTP status code when API returns a non-2xx response | VERIFIED | `cli::cli_abort(c("API request failed [{status}]", "i" = "Endpoint: {endpoint}", "x" = body_text))` at creel-connection-api.R:218-222; test `expect_error(fetch_interviews(conn), "API request failed \\[404\\]")` passes |
| 8 | `.api_fetch()` retries on 429/503 with explicit is_transient predicate | VERIFIED | `req_retry(req, max_tries = 3L, is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 503L))` at creel-connection-api.R:194-198; wiring confirmed in code |
| 9 | Retry abort on 3 × 429 responses is tested | VERIFIED | `test-api-fetch.R:43-51` — `httr2::local_mocked_responses(list(...three 429s...))` + `expect_error(fetch_interviews(conn), "API request failed")`; test passes |
| 10 | The `requireNamespace("httr2")` guard is absent from `.api_fetch()` | VERIFIED | `grep -v "^#" creel-connection-api.R \| grep requireNamespace` returns empty; no non-comment occurrences |
| 11 | `req_error(req, is_error = \(resp) FALSE)` disables httr2 auto-abort | VERIFIED | creel-connection-api.R line 200: `req <- httr2::req_error(req, is_error = \(resp) FALSE)` |
| 12 | All five methods return correctly-typed 0-row data frames for empty `[]` API responses | VERIFIED | Each method has `if (nrow(raw_df) == 0L) return(data.frame(...typed empty columns...))` early return; tests for all five verify `expect_equal(nrow(result), 0L)` and correct column types; 119 tests pass, 0 failures |
| 13 | Harvest and release length methods use `iiUID` (no underscore) as interview join key; catch and interviews use `ii_UID` | VERIFIED | fetch-loaders.R lines 332, 412: `interview_uid = "iiUID"` in length methods; lines 107, 253: `interview_uid = "ii_UID"` in interviews and catch methods |
| 14 | 429→200 retry success (positive retry path) verified by test | UNCERTAIN | Plan 088-01 specified a 429→200 retry-success test; SUMMARY 02 documents that this was replaced with an empty-array test due to httr2 1.2.2 architectural constraint (mocks intercept before retry loop). The `is_transient` predicate is correctly wired in production code but the positive retry path is unverifiable via unit test — requires human/integration verification |

**Score:** 13/14 truths verified (Truth 14 UNCERTAIN — routed to human verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tidycreel.connect/DESCRIPTION` | `httr2 (>= 1.0.0)` in Imports | VERIFIED | Confirmed at line 19 |
| `tidycreel.connect/R/creel-connection-api.R` | Hardened `.api_fetch()` with req_error + req_retry + cli_abort | VERIFIED | All three wired; no requireNamespace guard |
| `tidycreel.connect/R/fetch-loaders.R` | Five `fetch_*.creel_connection_api` S3 methods + `.rename_api_to_canonical()` | VERIFIED | All six additions present; 434 lines; methods wired as S3 methods |
| `tidycreel.connect/tests/testthat/helper-api.R` | `make_api_conn()` fixture constructor | VERIFIED | 12-line file; function returns `creel_connection_api` |
| `tidycreel.connect/tests/testthat/test-api-fetch.R` | 4 API-06 test cases | VERIFIED | 4 test_that blocks; all use `local_mocked_responses` |
| `tidycreel.connect/tests/testthat/test-fetch-interviews.R` | 2 API-01 test blocks appended | VERIFIED | Lines 64-100; happy path + empty response |
| `tidycreel.connect/tests/testthat/test-fetch-counts.R` | 2 API-02 test blocks appended | VERIFIED | Lines 23-52; happy path + empty response |
| `tidycreel.connect/tests/testthat/test-fetch-catch.R` | 2 API-03 test blocks appended | VERIFIED | Lines 41-75; happy path + empty response |
| `tidycreel.connect/tests/testthat/test-fetch-lengths.R` | 4 API-04/API-05 test blocks appended | VERIFIED | Lines 54-123; 2 harvest + 2 release |
| `tidycreel.connect/NAMESPACE` | S3method registrations for all 5 API methods | VERIFIED | Lines 3, 6, 9, 12, 15 register all five `creel_connection_api` methods |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `.api_fetch()` | `httr2::req_retry` | `req_retry(req, max_tries = 3L, is_transient = ...)` before `req_perform` | WIRED | creel-connection-api.R:194-198 |
| `.api_fetch()` | `httr2::req_error` | `req_error(req, is_error = \(resp) FALSE)` before `req_perform` | WIRED | creel-connection-api.R:200 |
| `.api_fetch()` | `cli::cli_abort` | status >= 400 branch with "API request failed [{status}]" format | WIRED | creel-connection-api.R:218-222 |
| `fetch_interviews.creel_connection_api` | `.api_fetch(conn$con, "interviews")` | direct call | WIRED | fetch-loaders.R:91 |
| `fetch_interviews.creel_connection_api` | `validate_fetch_interviews(df)` | called before return | WIRED | fetch-loaders.R:126 |
| `fetch_harvest_lengths.creel_connection_api` | `iiUID` (no underscore) | `interview_uid = "iiUID"` in api_rename_map | WIRED | fetch-loaders.R:332 |
| `fetch_release_lengths.creel_connection_api` | `iiUID` (no underscore) | `interview_uid = "iiUID"` in api_rename_map | WIRED | fetch-loaders.R:412 |
| `fetch_catch.creel_connection_api` | `catch_uid` synthesis | `if (!"catch_uid" %in% names(df)) df$catch_uid <- seq_len(nrow(df))` | WIRED | fetch-loaders.R:261-263 |
| `fetch_harvest_lengths.creel_connection_api` | `length_type` constant injection | `df$length_type <- "harvest"` after rename | WIRED | fetch-loaders.R:344 |
| `fetch_release_lengths.creel_connection_api` | `length_type` constant injection | `df$length_type <- "release"` after rename | WIRED | fetch-loaders.R:426 |
| `test-api-fetch.R` | `make_api_conn()` | helper-api.R auto-sourced by testthat | WIRED | All 4 test blocks call `make_api_conn()` |

### Data-Flow Trace (Level 4)

Not applicable: all fetch methods obtain data from mocked HTTP responses in tests; no static returns in production paths. Each method calls `.api_fetch()` which calls `httr2::resp_body_json(resp, simplifyVector = TRUE)` on a live HTTP response and returns a real data frame (not static/empty).

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full test suite passes with 0 failures | `Rscript -e "devtools::load_all('.'); devtools::test(pkg = 'tidycreel.connect')"` | `FAIL 0 \| WARN 0 \| SKIP 10 \| PASS 119` | PASS |
| `requireNamespace` guard absent | `grep -v "^#" creel-connection-api.R \| grep requireNamespace` | (empty output) | PASS |
| `req_retry` with `is_transient` present | `grep "is_transient" creel-connection-api.R` | Line 197 matches | PASS |
| `iiUID` used in length methods | `grep "iiUID" fetch-loaders.R` | Lines 332, 412 confirm both length methods use `iiUID` | PASS |
| All 5 S3 methods registered in NAMESPACE | `grep "creel_connection_api" tidycreel.connect/NAMESPACE` | 5 S3method lines | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| API-01 | 088-02 | `fetch_interviews()` returns canonical columns including computed effort | SATISFIED | `fetch_interviews.creel_connection_api` wired; 2 passing tests in test-fetch-interviews.R |
| API-02 | 088-02 | `fetch_counts()` returns canonical columns | SATISFIED | `fetch_counts.creel_connection_api` wired; 2 passing tests in test-fetch-counts.R |
| API-03 | 088-03 | `fetch_catch()` returns canonical columns with synthesized `catch_uid` | SATISFIED | `fetch_catch.creel_connection_api` wired; 2 passing tests in test-fetch-catch.R |
| API-04 | 088-03 | `fetch_harvest_lengths()` returns canonical columns with `length_type = "harvest"` | SATISFIED | `fetch_harvest_lengths.creel_connection_api` wired; 2 passing tests in test-fetch-lengths.R |
| API-05 | 088-03 | `fetch_release_lengths()` returns canonical columns with `length_type = "release"` | SATISFIED | `fetch_release_lengths.creel_connection_api` wired; 2 passing tests in test-fetch-lengths.R |
| API-06 | 088-01 | `.api_fetch()` surfaces structured errors and retries on 429/503 | PARTIALLY SATISFIED | Error path (non-2xx cli_abort), abort-on-exhaust (3 × 429), and transient predicate wiring are all verified. Positive retry path (429→200 success) is not verifiable via unit test due to httr2 mock architecture — routed to human verification |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `fetch-loaders.R` | 109, 110, 115, 116, 183, 255 | `# TODO: confirm field name with live API` on NGPC field names | Info | Expected and documented; field names unconfirmed with live API; to be resolved in Phase 90 real-data validation |

No blockers found. TODO comments are domain-intentional (NGPC field names are unconfirmed pending Phase 90) and do not affect test coverage with mocked responses.

### Human Verification Required

#### 1. Positive Retry Path (429 → 200 Success)

**Test:** Using a staging NGPC API (or a local mock server such as WireMock configured to return 429 on the first request and 200 on the second), call `fetch_interviews()` via a `creel_connection_api` connection.

**Expected:** The call succeeds — no error is raised — and a valid data frame with canonical columns is returned. The retry fires automatically without any user action.

**Why human:** `httr2::local_mocked_responses()` intercepts HTTP calls at the `req_perform` level before httr2's internal retry loop (`req_perform1` via curl). List-based response sequences in unit tests cannot drive the retry mechanism in httr2 1.2.2. The `is_transient` predicate (`httr2::resp_status(resp) %in% c(429L, 503L)`) is correctly wired in production code, but the positive path (retry succeeds) can only be exercised end-to-end with a real or integration-level server. ROADMAP SC4 states: "When the API returns a 429 or 503 status, `.api_fetch()` retries up to 3 times before aborting." The abort path is verified; the success path requires human confirmation.

---

### Summary

Phase 88 is substantively complete. All five `fetch_*.creel_connection_api` S3 methods exist, are wired, and produce the correct canonical columns with correct types. The HTTP layer is hardened: `req_retry` with an explicit `is_transient` predicate is wired before `req_perform`, `req_error` disables httr2 auto-abort, and `cli_abort` produces structured error messages. httr2 is a hard `Imports` dependency. 119 tests pass with 0 failures.

The single outstanding item is the positive retry path (429→200 success) — documented as an architectural constraint of httr2's mock system in SUMMARY 02, with the `is_transient` wiring confirmed in code. A human must exercise this path against a real or integration-level server before the phase can be considered fully passing.

---

_Verified: 2026-05-09_
_Verifier: Claude (gsd-verifier)_
