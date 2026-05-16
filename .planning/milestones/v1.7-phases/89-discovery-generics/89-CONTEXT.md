# Phase 89: Discovery Generics - Context

**Gathered:** 2026-05-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 89 delivers two new S3 generics — `list_creels()` and `search_creels()` — in a new `tidycreel.connect/R/creel-discovery.R` file. The API methods call `GetAvailableCreels` to return all surveys available on the connected REST endpoint. CSV and SQL Server connections get permanent "not supported" errors. This phase does not add pagination, authentication changes, or any new column contracts beyond the six required columns.

</domain>

<decisions>
## Implementation Decisions

### Discovery Endpoint Behavior
- **D-01:** `GetAvailableCreels` is called with **no UID filter** — it returns all surveys available on the API, regardless of the `creel_uids` stored in the connection object. Discovery is about finding UIDs before you know which surveys to connect to.
- **D-02:** The endpoint path `GetAvailableCreels` is a TODO candidate — add to `tidycreel.connect/R/creel-connection-api.R`'s `.default_api_endpoints()` with a `# TODO: confirm endpoint path` comment if the exact path is uncertain from NGPC docs.
- **D-03:** NGPC raw JSON field names for the discovery response are unknown — use best-guess TODO placeholders in the hardcoded `api_rename_map`, same approach as Phase 88 D-01. Each uncertain field gets a `# TODO: confirm field name with live API` comment.

### search_creels() Filter Strategy
- **D-04:** `search_creels(conn, keyword)` is implemented **client-side**: call `list_creels(conn)` then filter with `grepl(keyword, ..., ignore.case = TRUE)` across `title` and `description` columns. No extra API round trip; no dependency on server-side keyword support.
- **D-05:** The keyword search covers `title` and `description` columns only. `comments` is not searched (too noisy). A survey matches if the keyword appears in either column.
- **D-06:** Matching is case-insensitive (`ignore.case = TRUE`).

### Not-Supported Error Messages
- **D-07:** CSV and SQL Server connections get a permanent "not supported" error (not "not yet implemented"). The error is method-specific and directs the user to `creel_connect_api()`:
  ```r
  cli::cli_abort(c(
    "{.fn list_creels} is not supported for {.cls creel_connection_csv} connections.",
    "i" = "Use {.fn creel_connect_api} to connect to a REST API that supports discovery."
  ))
  ```
  Same pattern for `search_creels()`, substituting the function name. SQL Server connection uses `{.cls creel_connection_sqlserver}`.

### Claude's Discretion
- Column type coercion for `active` and `data_complete` (logical vs integer from JSON) — Claude decides based on the JSON response shape.
- Whether to add a discovery endpoint entry to `.default_api_endpoints()` or construct the URL directly in `list_creels.creel_connection_api()`.
- Exact TODO candidate field name guesses for the `api_rename_map`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — API-07 and API-08 define the canonical column contract (`creel_uid`, `title`, `description`, `active`, `data_complete`, `comments`) and `search_creels()` signature
- `.planning/ROADMAP.md` — Phase 89 success criteria (verbatim acceptance tests)

### State and Technical Context
- `.planning/STATE.md` §"v1.7.0 Technical Context" — hardcoded rename map pattern, `.api_fetch()` infrastructure, `GetAvailableCreels` endpoint hint, discovery pagination note

### Existing Implementation (Phase 88 deliverables)
- `tidycreel.connect/R/creel-connection-api.R` — `.api_fetch()` (hardened), `.default_api_endpoints()`, `.parse_api_date()`, `.validate_api_auth()` — the HTTP layer `list_creels.creel_connection_api()` will call
- `tidycreel.connect/R/fetch-loaders.R` — `.rename_api_to_canonical()` utility and all five `fetch_*.creel_connection_api` methods — follow the same generic + S3 method pattern
- `tidycreel.connect/R/creel-connection.R` — `new_creel_connection()` and connection subclasses (`creel_connection_api`, `creel_connection_csv`, `creel_connection_sqlserver`) — method dispatch targets
- `tidycreel.connect/tests/testthat/helper-api.R` — test helper for mock API fixtures — reuse in `test-discovery.R`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.api_fetch(con_info, endpoint_key)` in `creel-connection-api.R`: `list_creels.creel_connection_api()` calls this with a discovery endpoint key (e.g., `"discovery"` or `"list_creels"`). Pass `conn$con` as `con_info`.
- `.rename_api_to_canonical(df, api_rename_map)` in `fetch-loaders.R`: use the same utility to rename raw NGPC JSON fields to canonical names (`creel_uid`, `title`, etc.)
- `helper-api.R` mock fixtures: reuse the `httr2::local_mocked_responses()` pattern for `test-discovery.R`

### Established Patterns
- Generic declaration: `list_creels <- function(conn, ...) UseMethod("list_creels")` — matches `fetch_*` pattern
- S3 method naming: `list_creels.creel_connection_api <- function(conn, ...) { ... }`
- Not-supported stubs: `list_creels.creel_connection_csv` and `list_creels.creel_connection_sqlserver` both call `cli::cli_abort()` with the permanent not-supported message
- `@export` on the generic and all three S3 methods
- `conn$con` holds the connection info list (`base_url`, `creel_uids`, `endpoints`, `auth`, `uid_param`)

### Integration Points
- New file: `tidycreel.connect/R/creel-discovery.R` — generics and all S3 methods live here
- If a discovery endpoint key is added to `.default_api_endpoints()`, update `creel-connection-api.R` and the `endpoints` arg validation in `creel_connect_api()`
- Tests: `tidycreel.connect/tests/testthat/test-discovery.R`

</code_context>

<specifics>
## Specific Ideas

- `list_creels.creel_connection_api()` calls `.api_fetch(conn$con, "discovery")` — the endpoint key name ("discovery") can be anything consistent; what matters is it maps to the `GetAvailableCreels` path in `con$endpoints`
- `search_creels(conn, keyword)` signature: `keyword` is a single character string. Validate with `cli::cli_abort()` if not a non-empty string.
- The TODO-placeholder field name candidates for the rename map: `creel_uid` ← likely `cr_UID` or `Creel_UID`; `title` ← likely `Creel_Name` or `sr_Title`; `active` and `data_complete` ← unknown; `comments` ← likely `sr_Comments` or `Creel_Comments`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 89-Discovery Generics*
*Context gathered: 2026-05-10*
