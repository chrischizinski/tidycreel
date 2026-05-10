# Stack Research: tidycreel.connect — API Fetch Methods and Creel Discovery

**Domain:** R package HTTP API client layer (REST GET dispatch, S3 generics, creel discovery)
**Researched:** 2026-05-09
**Scope:** NEW capabilities only — five S3 dispatch methods for `creel_connection_api`, plus `list_creels()` / `search_creels()` generics with API implementations. Existing validated infrastructure (constructor, `.api_fetch()`, `.validate_api_auth()`, `.parse_api_date()`, CSV methods) not re-evaluated.
**Confidence:** HIGH (httr2 docs verified via official r-lib.org reference pages and CRAN; jsonlite relationship confirmed via source inspection)

---

## Existing Imports in tidycreel.connect (Do Not Change)

```
cli, DBI, readr, tidycreel
```

`httr2` is present in `Suggests` only. This is the most important stack decision below.

---

## Decision 1: Move httr2 from Suggests to Imports

**Current state:** `httr2` is in `Suggests` with a runtime `requireNamespace("httr2", quietly = TRUE)` guard inside `.api_fetch()`.

**Recommendation: Move `httr2` to Imports.**

Rationale: The five new `fetch_*.creel_connection_api` methods are the primary value-add of this milestone. Every one of them calls `.api_fetch()`, which calls `httr2::request()`, `httr2::req_url_query()`, `httr2::req_perform()`, and `httr2::resp_body_json()`. The `requireNamespace` guard was appropriate when httr2 was speculative infrastructure; it is now the core load path. Keeping it in Suggests forces every user of the API backend to have httr2 available anyway, while adding a runtime abort that provides no real protection — a user who chose `creel_connect_api()` has already committed to needing httr2.

The `requireNamespace` guard in `.api_fetch()` should be removed once httr2 is promoted to Imports. The guard was defensive scaffolding, not a long-term design intent.

**Version floor:** `httr2 >= 1.0.0`

Version 1.0.0 (November 2023) was the first stable public API release. It introduced `req_perform_iterative()`, solidified `req_error()` and `req_retry()`, and established the pipeable builder pattern that the existing code uses. The current CRAN release is 1.2.2 (December 2025), which includes a stable (no longer experimental) `req_perform_iterative()` as of 1.1.0.

---

## Decision 2: No Additional Packages for JSON Field Mapping

**Question asked:** Is any additional R package needed for JSON field renaming (e.g., `janitor`)?

**Answer: No.**

The existing `.rename_to_canonical()` function in `fetch-loaders.R` already handles the mapping of API-supplied column names to tidycreel canonical names via the `rename_map` named character vector + `schema` field lookup. This pattern is proven across all five CSV methods.

`janitor::clean_names()` is a bulk normalisation tool (converts arbitrary column names to snake_case). It is the wrong tool here because the API field names are known, stable, and specific — the NGPC creel API returns named JSON objects with fixed field names. A declarative `rename_map` in each S3 dispatch method (mirroring the CSV methods exactly) is the correct pattern.

`httr2::resp_body_json(resp, simplifyVector = TRUE)` returns a `data.frame`-coercible list when the JSON is a flat array of objects. `as.data.frame(result)` produces the raw API-named frame, then `.rename_to_canonical()` does the mapping. No additional package is needed in this chain.

Do NOT add `janitor` to Imports or Suggests for this milestone.

---

## Decision 3: httr2 Built-in JSON Parsing (resp_body_json) vs jsonlite Directly

**Recommendation: Use `httr2::resp_body_json()` with `simplifyVector = TRUE` — exactly as already implemented in `.api_fetch()`.**

`resp_body_json()` delegates to `jsonlite::fromJSON()` under the hood. The `simplifyVector = TRUE` argument is passed through to `jsonlite`, which coerces JSON arrays of objects to R `data.frame` directly. This is confirmed by the httr2 source (`R/resp-body.R`).

There is no reason to call `jsonlite::fromJSON()` directly — it would bypass httr2's content-type validation (controlled by `check_type = TRUE` by default), bypass httr2's response body cache (second parse of the same response is free), and require adding `jsonlite` to Imports explicitly. The httr2 path gives all of this for free because httr2 already depends on jsonlite.

**Practical note on `check_type`:** The NGPC API may not always return `Content-Type: application/json`. If integration tests expose a content-type mismatch, the correct fix is `resp_body_json(resp, check_type = FALSE, simplifyVector = TRUE)` — not switching to raw jsonlite. This is a one-argument change localised to `.api_fetch()`.

Do NOT add `jsonlite` to the DESCRIPTION — it is a transitive dependency of httr2 and must not be declared explicitly.

---

## Decision 4: httr2 Error Handling Pattern (req_error)

**Recommendation: Add `req_error()` with a body-extracting callback to `.api_fetch()`.**

The current `.api_fetch()` implementation calls `httr2::req_perform(req)` without any `req_error()` modifier. By default, httr2 converts all 4xx and 5xx responses into R errors with class `c("httr2_http_NNN", "httr2_http", "httr2_error")`. This is correct base behaviour, but the error messages are bare HTTP status descriptions.

For the five fetch methods and the discovery functions, the API may return structured JSON error bodies (common in REST APIs). The recommended pattern:

```r
req <- httr2::req_error(req, body = function(resp) {
  body <- tryCatch(
    httr2::resp_body_json(resp, check_type = FALSE),
    error = function(e) NULL
  )
  if (!is.null(body$message)) body$message
  else if (!is.null(body$error)) body$error
  else NULL
})
```

This adds the API's own error message text (when present) to the R error condition body, which dramatically improves debugging. The `tryCatch` wrapper handles cases where the error response is not JSON (e.g. a 502 from a proxy returning HTML).

This change is localised to `.api_fetch()` — all five fetch methods and discovery functions benefit without changes to their own implementations.

**Error class interception:** For `list_creels()` / `search_creels()`, a 404 from `/api/creels` means "no creels found" rather than a bug. These discovery functions should handle the 404 case explicitly:

```r
resp <- tryCatch(
  httr2::req_perform(req),
  httr2_http_404 = function(e) NULL
)
if (is.null(resp)) return(data.frame())
```

This uses the httr2 error class hierarchy (`httr2_http_404`) directly with `tryCatch`, which is the httr2-idiomatic pattern.

---

## Decision 5: Retry — Add req_retry to .api_fetch

**Recommendation: Add `req_retry(max_tries = 3)` to `.api_fetch()`.**

The default httr2 retry behaviour (when activated via `max_tries`) retries on 429 ("too many requests") and 503 ("service unavailable") with truncated exponential backoff with full jitter (random wait between 1 second and min(2^try, 60) seconds). This is the correct default for a government/academic REST API that may have occasional transient availability issues.

`req_retry()` requires `max_tries` or `max_seconds` to be set — the function is a no-op otherwise. `max_tries = 3` (total attempts = 3, retries = 2) is conservative and appropriate for interactive R sessions where the user would rather get a fast failure than wait indefinitely.

Add as a single line in `.api_fetch()` before `req_perform()`:

```r
req <- httr2::req_retry(req, max_tries = 3L)
```

No custom `is_transient` override is needed unless integration testing reveals the NGPC API uses non-standard transient status codes.

Do NOT use `req_throttle()` by default. Throttling is appropriate for high-volume batch clients. tidycreel.connect fetch calls are interactive and low-frequency (one survey's worth of data per call).

---

## Decision 6: Pagination — Not Needed for Fetch Methods

**Question asked:** Are new httr2 pagination patterns needed?

**Answer: No, with one conditional note.**

The NGPC creel API as described in the existing constructor uses a single GET with `?Creel_UIDs=uid1,uid2,...` that returns all records for those survey UIDs in a single JSON array. This is a bulk-data-by-key pattern, not a paginated listing API. `req_perform_iterative()` and the `iterate_with_offset()` / `iterate_with_cursor()` / `iterate_with_link_url()` helpers are not needed for the five fetch methods.

**Conditional note for `list_creels()` / `search_creels()`:** Discovery endpoints (`/api/creels`, `/api/creels?q=search_term`) may return paginated listings if the API has many surveys. If integration testing reveals a `Link` header or a `nextPage` cursor in the response body, add `req_perform_iterative()` with `iterate_with_link_url()` (Link header) or a custom `next_req` function (cursor). This is a single-function addition to the discovery implementation — it does not affect the five fetch methods.

`req_perform_iterative()` is stable (no longer experimental as of httr2 1.1.0, September 2024).

---

## Recommended Stack: What Actually Changes

### DESCRIPTION Changes

| Package | Change | Version Floor | Rationale |
|---------|--------|--------------|-----------|
| `httr2` | Move from Suggests → **Imports** | `>= 1.0.0` | API backend is now primary path; runtime guard pattern becomes misleading overhead |

### No New Packages

| Considered | Verdict | Reason |
|------------|---------|--------|
| `jsonlite` (explicit) | Reject | Transitive via httr2; `resp_body_json()` already delegates to it |
| `janitor` | Reject | Bulk snake_case normalisation; the declarative `rename_map` pattern already handles known API field names precisely |
| `purrr` | Reject | The existing `lapply`/`vapply` patterns in the package are sufficient; no functional pipeline complexity in fetch dispatch |
| `curl` (explicit) | Reject | Transitive via httr2; never needed directly |

### httr2 Functions Used (New to Existing Surface)

| Function | Where | Purpose |
|----------|-------|---------|
| `req_error(body = fn)` | `.api_fetch()` | Extract API error message text into R condition body |
| `req_retry(max_tries = 3L)` | `.api_fetch()` | Retry on 429/503 with exponential backoff |
| `resp_body_json(check_type = FALSE)` | `.api_fetch()` (conditional) | Fallback if API returns non-standard Content-Type |
| `req_perform_iterative()` | discovery functions (conditional) | Pagination for `list_creels()` if API is paginated |
| `iterate_with_link_url()` | discovery functions (conditional) | Link-header pagination helper |

All other httr2 calls (`request()`, `req_url_query()`, `req_auth_bearer_token()`, `req_headers()`, `req_perform()`, `resp_body_json()`) are already present in `.api_fetch()` — no change needed.

---

## Integration Pattern: Five S3 Dispatch Methods

Each `fetch_*.creel_connection_api` method follows the CSV method structure exactly, substituting `.api_fetch()` for `.read_csv_safe()`:

```r
fetch_interviews.creel_connection_api <- function(conn, ...) {
  df <- .api_fetch(conn$con, "interviews")
  rename_map <- c(
    interview_uid = "interview_uid_col",
    date          = "date_col",
    catch_count   = "catch_col",
    effort        = "effort_col",
    trip_status   = "trip_status_col"
  )
  df <- .rename_to_canonical(df, conn$schema, rename_map)
  if ("date" %in% names(df))        df$date        <- .parse_api_date(df$date)
  if ("catch_count" %in% names(df)) df$catch_count <- as.numeric(df$catch_count)
  if ("effort" %in% names(df))      df$effort      <- as.numeric(df$effort)
  if ("trip_status" %in% names(df)) df$trip_status <- as.character(df$trip_status)
  validate_fetch_interviews(df)
  df
}
```

The rename_map field names (`"interview_uid_col"`, `"date_col"`, etc.) must be verified against the actual JSON field names the NGPC API returns — these may differ from the CSV column names stored in the schema. If the API returns PascalCase fields (`InterviewUID`, `Date`) while the schema stores CSV column names in a different convention, a separate API-specific rename map is needed that maps canonical names directly to JSON field names, bypassing the schema lookup. This is the primary integration risk and requires inspection of a real API response during implementation.

---

## Integration Pattern: list_creels / search_creels Generics

```r
# Generic
list_creels <- function(conn, ...) UseMethod("list_creels")
search_creels <- function(conn, query, ...) UseMethod("search_creels")

# API implementation
list_creels.creel_connection_api <- function(conn, ...) {
  # GET {base_url}/creels (or conn$con$endpoints$creels if configurable)
  # Returns data.frame with columns: creel_uid, name, start_date, end_date, survey_type
}

search_creels.creel_connection_api <- function(conn, query, ...) {
  # GET {base_url}/creels?q={query}
  # Returns subset matching query string
}
```

The endpoint paths for discovery (`/creels`) need a new entry in `.default_api_endpoints()` and a new `endpoints` slot in the constructor. This is a backwards-compatible extension — existing `creel_connect_api()` callers are unaffected.

---

## What NOT to Add

| Technology | Why Not |
|------------|---------|
| `httr` (v1) | Superseded; httr2 is the current standard and is already a dependency |
| `crul` | httr2 equivalent; no reason to introduce a second HTTP client |
| `RCurl` | Low-level; requires manual response parsing; superseded by httr2 |
| `jsonlite` in DESCRIPTION | Transitive via httr2; explicit declaration adds no value, creates maintenance burden |
| `janitor` | Bulk normalisation; wrong tool for known, stable API field names |
| `req_throttle()` | Rate limiting for high-volume batch clients; inappropriate default for interactive one-survey fetch calls |

---

## Version Compatibility

| Package | Version Floor | Reason |
|---------|--------------|--------|
| `httr2` | `>= 1.0.0` | First stable API; `req_error()`, `req_retry()` present and stable |
| R | `>= 4.1.0` | Matches existing DESCRIPTION; `|>` native pipe not used (existing code uses base syntax) |

httr2 1.1.0 (September 2024) made `req_perform_iterative()` stable (removed experimental flag). If discovery pagination is needed, require `>= 1.1.0`. For the five fetch methods alone, `>= 1.0.0` is sufficient.

---

## Sources

- httr2 reference — req_error: https://httr2.r-lib.org/reference/req_error.html (HIGH confidence)
- httr2 reference — req_retry: https://httr2.r-lib.org/reference/req_retry.html (HIGH confidence)
- httr2 reference — req_perform_iterative: https://httr2.r-lib.org/reference/req_perform_iterative.html (HIGH confidence)
- httr2 reference — iterate_with_offset: https://httr2.r-lib.org/reference/iterate_with_offset.html (HIGH confidence)
- httr2 reference — resp_body_raw (includes resp_body_json signature): https://httr2.r-lib.org/reference/resp_body_raw.html (HIGH confidence)
- httr2 source resp-body.R confirming jsonlite delegation: https://github.com/r-lib/httr2/blob/main/R/resp-body.R (HIGH confidence)
- httr2 CRAN page — version 1.2.2 confirmed: https://cran.r-project.org/package=httr2 (HIGH confidence)
- httr2 changelog — 1.1.0 req_perform_iterative stable: https://httr2.r-lib.org/news/index.html (HIGH confidence)
- httr2 wrapping APIs vignette: https://httr2.r-lib.org/articles/wrapping-apis.html (HIGH confidence)

---

*Stack research for: tidycreel.connect API fetch methods and creel discovery*
*Researched: 2026-05-09*
