# Phase 88: httr2 Hardening and API Fetch Methods - Context

**Gathered:** 2026-05-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 88 delivers two things:
1. **HTTP hardening:** `.api_fetch()` gets `req_error()` and `req_retry()` so it surfaces structured errors and retries on transient failures (429/503).
2. **API S3 methods:** Five `fetch_*.creel_connection_api` S3 methods with hardcoded NGPC field rename maps — `fetch_interviews`, `fetch_counts`, `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`.

Out of scope: discovery generics (`list_creels`, `search_creels` — Phase 89), real-data validation script (Phase 90), SQL Server methods (Phase 69 territory).

</domain>

<decisions>
## Implementation Decisions

### Unknown API Field Names
- **D-01:** Use best-guess candidates from STATE.md for all uncertain field names. Mark each uncertain field with a `# TODO: confirm field name with live API` comment in the rename map. Phase 90 validates these against Calamus 2016 live data.
- **D-02:** Known NGPC field name decisions from STATE.md: `ii_UID` for interview join key, `iiUID` (no underscore) for harvest/release length join key, `cd_Date` for date fields.
- **D-03:** Candidate for angler count in `GetCountData`: `ii_NumberAnglers` (TODO: confirm). `ir_Count` aggregation policy for release lengths is unresolved — use a TODO and pick sensible default.
- **D-04:** No additional reference docs beyond STATE.md candidates — all field-name knowledge is in `.planning/STATE.md`.

### UID Synthesis (catch_uid / length_uid)
- **D-05:** If `catch_uid` or `length_uid` are absent from the API JSON response, synthesize them as `seq_len(nrow(df))` inside each `fetch_*.creel_connection_api` method. Keeps the canonical column contract intact so downstream code works identically for CSV and API paths.
- **D-06:** Synthesis is conditional: only add `seq_len()` if the column is absent from the rename map result. Never overwrite a column that the API does return.
- **D-07:** Synthesis happens inside each `fetch_*` method, NOT inside `.api_fetch()`. `.api_fetch()` stays a thin HTTP layer with no knowledge of column contracts.

### Test Strategy
- **D-08:** Test API methods using `httr2::local_mocked_responses()` (httr2's built-in mock facility). No extra test dependencies — no httptest2.
- **D-09:** Test coverage required for all five `fetch_*` methods and `.api_fetch()` hardening:
  - Happy path: canonical column names and types returned from mock JSON fixture
  - Empty response: API returns `[]` → method returns a 0-row data frame with correct column names (not a 0-column `data.frame()`)
  - Non-2xx error: mock returns 404/500 → `.api_fetch()` aborts with a `cli::cli_abort()` message including HTTP status and error body
  - Retry behavior: mock returns 429 then 200 → succeeds; mock returns 429 three times → aborts

### req_retry and Error Handling
- **D-10:** Retry only on HTTP 429 (rate limited) and 503 (service unavailable). Do not retry on 502 or other 5xx codes.
- **D-11:** Max 3 retries. Use httr2's default exponential backoff (respects `Retry-After` headers on 429 if present). No fixed delay override.
- **D-12:** Non-2xx errors: `cli::cli_abort()` with HTTP status code, endpoint URL, and JSON error body pretty-printed. If the body is not JSON, include it as a raw string. Pattern:
  ```
  API request failed [404]
  i Endpoint: AnalysisData/GetInterviewData
  x {parsed or raw error body}
  ```
- **D-13:** Use `httr2::req_error()` to disable httr2's automatic HTTP error, then `httr2::resp_status()` to check and build the cli message. This gives full control over the error format.

### httr2 Dependency Promotion
- **D-14:** `httr2` promoted from `Suggests` to `Imports` in `tidycreel.connect/DESCRIPTION` with floor `>= 1.0.0`. Remove the `requireNamespace("httr2", quietly = TRUE)` guard from `.api_fetch()` — it is no longer a soft dependency.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — API-01 through API-06 define canonical column contracts for all five fetch methods; API-06 defines error/retry requirements
- `.planning/ROADMAP.md` — Phase 88 success criteria (verbatim acceptance tests)

### State and Technical Context
- `.planning/STATE.md` §"v1.7.0 Technical Context" — NGPC-fixed field names, `iiUID` vs `ii_UID` distinction, `.parse_api_date()` requirement, empty-array guard note, Calamus 2016 data characteristics

### Existing Implementation
- `tidycreel.connect/R/creel-connection-api.R` — current `.api_fetch()`, `.parse_api_date()`, auth helpers, default endpoint paths — the file being hardened
- `tidycreel.connect/R/fetch-loaders.R` — existing CSV S3 methods; new API methods follow the same pipeline pattern (read → rename → coerce → validate)
- `tidycreel.connect/R/fetch-validators.R` — `validate_fetch_*()` functions that all fetch methods must call; canonical column contracts are enforced here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.api_fetch(con_info, endpoint_key)` in `creel-connection-api.R`: existing HTTP layer to harden — add `req_error()` + `req_retry()` and fix the 0-column empty-response guard
- `.parse_api_date(x)` in `creel-connection-api.R`: already handles ISO-8601 datetime — must be called in all API `fetch_*` methods instead of `as.Date()`
- `.rename_to_canonical(df, schema, rename_map)` in `fetch-loaders.R`: existing utility BUT API methods use hardcoded field maps (NOT schema-mediated). API methods must inline their rename step or use a new `.rename_api_to_canonical(df, api_rename_map)` variant that takes raw API column names directly.
- `validate_fetch_*()` functions in `fetch-validators.R`: called at end of every fetch method — API methods must call these too

### Established Patterns
- Each `fetch_*.creel_connection_csv` method follows: read → rename → coerce → validate. API methods follow the same pipeline.
- `creel_connection_api` objects store `con$endpoints`, `con$auth`, `con$base_url`, `con$creel_uids`, `con$uid_param` — all accessible inside `fetch_*.creel_connection_api(conn, ...)` via `conn$con`.
- httr2 auth is already wired in `.api_fetch()` for bearer and api_key types — no changes needed to auth handling.

### Integration Points
- New `fetch_*.creel_connection_api` methods go in `tidycreel.connect/R/fetch-loaders.R` alongside existing CSV methods (same file, each method family grouped together)
- `tidycreel.connect/DESCRIPTION` — `httr2` moves from `Suggests` to `Imports`
- Tests go in `tidycreel.connect/tests/testthat/` following the existing `test-fetch-*.R` naming convention

### Critical Constraint
- **Do NOT route API field names through `creel_schema` keys.** Each `fetch_*.creel_connection_api` method uses a hardcoded `api_rename_map` where names = canonical names and values = raw NGPC JSON field names (e.g., `c(interview_uid = "ii_UID", date = "cd_Date", ...)`). The schema is ignored for API connections.

</code_context>

<specifics>
## Specific Ideas

- The empty-response guard in `.api_fetch()` currently returns `data.frame()` (0 columns). This must be fixed: after the rename map is applied inside each `fetch_*` method, an absent column is synthesized or NAs are added — so the guard in `.api_fetch()` can stay as-is (returning 0-row raw data.frame). The `fetch_*` method's rename step will produce 0-row output with correct columns. Verify this logic holds when writing the plan.
- `ir_Count` for release lengths: if it's a raw count per record (not aggregated), no aggregation is needed in the fetch method — just rename and coerce. Add a TODO if uncertain.
- The five API methods can be implemented top-to-bottom in order: `fetch_interviews` (most complex, has effort computation), `fetch_counts`, `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 88 — httr2 Hardening and API Fetch Methods*
*Context gathered: 2026-05-09*
