# Phase 88: httr2 Hardening and API Fetch Methods — Research

**Researched:** 2026-05-09
**Domain:** httr2 HTTP client hardening, R S3 method dispatch, JSON-to-data-frame pipeline
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use best-guess NGPC field name candidates from STATE.md for uncertain fields. Mark each uncertain field with `# TODO: confirm field name with live API`. Phase 90 validates against live data.
- **D-02:** Known NGPC field names: `ii_UID` (interview join key), `iiUID` (no underscore — harvest/release length join key), `cd_Date` (date fields).
- **D-03:** Candidate angler count field in GetCountData: `ii_NumberAnglers` (TODO: confirm). `ir_Count` aggregation policy for release lengths unresolved — use a TODO and pick sensible default.
- **D-04:** No additional reference docs beyond STATE.md candidates.
- **D-05:** If `catch_uid` or `length_uid` absent from API JSON, synthesize as `seq_len(nrow(df))` inside each `fetch_*` method.
- **D-06:** Synthesis is conditional — only add `seq_len()` if the column is absent from the rename map result.
- **D-07:** Synthesis happens inside each `fetch_*` method, NOT inside `.api_fetch()`.
- **D-08:** Test using `httr2::local_mocked_responses()`. No httptest2.
- **D-09:** Required test coverage: happy path, empty response (`[]` → 0-row df with correct columns), non-2xx error (cli message with status + body), retry (429→200 succeeds; 429×3 aborts).
- **D-10:** Retry only on HTTP 429 and 503. Do not retry on 502 or other 5xx.
- **D-11:** Max 3 retries. Default exponential backoff (respects `Retry-After` on 429).
- **D-12:** Non-2xx errors: `cli::cli_abort()` with HTTP status, endpoint URL, and JSON error body (raw string if not JSON). Format: `"API request failed [404]"` / `"i Endpoint: ..."` / `"x {body}"`.
- **D-13:** Use `req_error(is_error = \(resp) FALSE)` to disable httr2 auto-errors, then check `resp_status()` manually and build the cli message.
- **D-14:** `httr2` moves from `Suggests` to `Imports` with floor `>= 1.0.0`. Remove `requireNamespace()` guard from `.api_fetch()`.

### Claude's Discretion

None specified — all implementation decisions locked in CONTEXT.md.

### Deferred Ideas (OUT OF SCOPE)

- `list_creels()` / `search_creels()` discovery generics (Phase 89)
- Real-data validation script (Phase 90)
- SQL Server fetch methods (Phase 69 territory)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| API-01 | `fetch_interviews()` on `creel_connection_api` returns canonical columns: `interview_uid`, `date`, `catch_count`, `effort`, `trip_status` | Rename map and effort arithmetic documented; `.parse_api_date()` verified |
| API-02 | `fetch_counts()` on `creel_connection_api` returns canonical columns: `date`, `angler_count` | Rename map documented; angler count field is TODO: confirm |
| API-03 | `fetch_catch()` on `creel_connection_api` returns canonical columns: `catch_uid`, `interview_uid`, `species`, `catch_count`, `catch_type` | Rename map from reference code confirmed; `catch_uid` synthesis per D-05 |
| API-04 | `fetch_harvest_lengths()` on `creel_connection_api` returns canonical columns: `length_uid`, `interview_uid`, `species`, `length_mm`, `length_type = "harvest"` | `iiUID` (no underscore) confirmed; constant injection and `length_uid` synthesis documented |
| API-05 | `fetch_release_lengths()` on `creel_connection_api` returns canonical columns: `length_uid`, `interview_uid`, `species`, `length_mm`, `length_type = "release"` | Same `iiUID` pattern; `ir_Count` TODO documented |
| API-06 | `.api_fetch()` returns structured human-readable error on non-2xx; retries up to 3× on 429/503 | httr2 `req_error()` + `req_retry()` API verified via Context7 and installed version 1.2.2 |
</phase_requirements>

---

## Summary

Phase 88 has two separable delivery areas. First, `.api_fetch()` in `creel-connection-api.R` needs two httr2 middleware additions: `req_error(is_error = \(resp) FALSE)` to disable httr2's automatic exception so we can build a `cli::cli_abort()` message ourselves, and `req_retry(max_tries = 3L)` which already retries on exactly 429 and 503 by default (verified against the installed httr2 1.2.2 source). The `requireNamespace()` guard is removed since `httr2` moves to `Imports`.

Second, five `fetch_*.creel_connection_api` S3 methods follow the established CSV pipeline pattern (read → rename → coerce → validate) but with hardcoded `api_rename_map` vectors instead of schema-mediated lookups. Each method calls `.api_fetch()`, applies its endpoint-specific rename map directly (not through `.rename_to_canonical()`), performs type coercion, synthesizes missing UID columns if needed, and calls the matching `validate_fetch_*()` function. The only method requiring field arithmetic is `fetch_interviews` — effort must be computed as `ii_TimeFishedHours + ii_TimeFishedMinutes / 60` before validation.

Tests use `httr2::local_mocked_responses()` with inline `httr2::response()` objects built from `charToRaw()` JSON fixtures. The retry sequence test exploits the fact that `local_mocked_responses(list(...))` returns responses in order and falls back to 503 when the list is exhausted — useful for testing the 429×3 → abort scenario.

**Primary recommendation:** Implement `.api_fetch()` hardening first (API-06), then the five fetch methods top-down in the order listed in CONTEXT.md.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| HTTP execution and retry | `.api_fetch()` helper | — | Single thin HTTP layer; all fetch methods delegate to it |
| Error surfacing (non-2xx) | `.api_fetch()` helper | — | Centralized — avoids per-method error handling duplication |
| Field rename (API → canonical) | Each `fetch_*.creel_connection_api` method | — | Hardcoded per-method; schema is intentionally bypassed |
| Type coercion | Each `fetch_*.creel_connection_api` method | — | Same tier as CSV methods for parity |
| UID synthesis | Each `fetch_*.creel_connection_api` method | — | D-07 explicitly prohibits this in `.api_fetch()` |
| Column contract validation | `validate_fetch_*()` in `fetch-validators.R` | — | Shared with CSV path; already implemented |
| Date parsing | `.parse_api_date()` helper | — | Handles ISO-8601 datetime strings that `as.Date()` silently NAs |
| DESCRIPTION dependency declaration | `tidycreel.connect/DESCRIPTION` | — | `httr2` moves from `Suggests` to `Imports` |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| httr2 | 1.2.2 (installed); `>= 1.0.0` floor | HTTP client: `req_error()`, `req_retry()`, `local_mocked_responses()` | Official tidyverse HTTP client; `req_error()`/`req_retry()` API is stable since 1.0.0 |
| cli | (already in Imports) | Structured error messages with `cli_abort()` | Project standard; matches existing error formatting throughout `tidycreel.connect` |
| testthat | 3.3.2 (installed) | Test framework | Already in Suggests; edition 3 configured |
| withr | 3.0.2 (installed) | Test scoping (`local_mocked_responses` is withr-style) | Already in Suggests; used in existing helper-csv.R |

[VERIFIED: Rscript -e "packageVersion('httr2')" → 1.2.2]
[VERIFIED: Rscript -e "packageVersion('testthat')" → 3.3.2]
[VERIFIED: Rscript -e "packageVersion('withr')" → 3.0.2]

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| httr2::response() | — | Build mock responses in tests | Inside `local_mocked_responses()` blocks |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `httr2::local_mocked_responses()` | httptest2 | CONTEXT.md D-08 locks out httptest2; `local_mocked_responses()` is built into httr2 ≥ 1.0.0, no extra dependency |
| `req_error(is_error = \(resp) FALSE)` + manual check | `req_error(body = ...)` enrichment pattern | D-13 requires full control over the error format via `cli_abort()`, not httr2's built-in formatter |

**Installation:** No new packages — httr2 is already installed. DESCRIPTION change only:

```bash
# No install needed — httr2 1.2.2 already installed
# DESCRIPTION: move httr2 from Suggests to Imports with version floor
```

---

## Architecture Patterns

### System Architecture Diagram

```
fetch_interviews(conn)   fetch_counts(conn)   fetch_catch(conn)
fetch_harvest_lengths()  fetch_release_lengths()
          |
          | calls .api_fetch(con_info, endpoint_key)
          v
  ┌─────────────────────────────────────────────────────┐
  │              .api_fetch()                           │
  │  httr2::request(url)                               │
  │    |> req_url_query(uid_param = uid_str)           │
  │    |> req_auth_*()                (if auth)        │
  │    |> req_error(is_error = FALSE) (disable auto)  │
  │    |> req_retry(max_tries = 3)    (429, 503)      │
  │    |> req_perform()                               │
  │                                                    │
  │  if resp_status >= 400: cli_abort() with status   │
  │  else: resp_body_json(simplifyVector = TRUE)      │
  │        → data.frame (may be 0 rows if [] )        │
  └─────────────────────────────────────────────────────┘
          |
          | returns plain data.frame
          v
  per-method pipeline:
    1. apply hardcoded api_rename_map   (select + rename columns)
    2. synthesize missing UID columns   (seq_len if absent)
    3. inject constants                 (length_type = "harvest"/"release")
    4. coerce types                     (as.Date via .parse_api_date, as.numeric, as.character)
    5. validate_fetch_*()              (abort if contract violated)
    6. return canonical data.frame
```

### Recommended Project Structure

```
tidycreel.connect/
├── R/
│   ├── creel-connection-api.R   # .api_fetch() hardening goes here (existing file)
│   └── fetch-loaders.R          # 5 new fetch_*.creel_connection_api methods added here
├── DESCRIPTION                  # httr2 moves from Suggests to Imports
└── tests/testthat/
    ├── helper-api.R             # NEW: make_api_conn() and mock JSON helpers
    ├── test-api-fetch.R         # NEW: .api_fetch() hardening tests (API-06)
    ├── test-fetch-interviews.R  # EXTEND: add creel_connection_api test block
    ├── test-fetch-counts.R      # EXTEND: add creel_connection_api test block
    ├── test-fetch-catch.R       # EXTEND: add creel_connection_api test block
    └── test-fetch-lengths.R     # EXTEND: add creel_connection_api test blocks
```

### Pattern 1: `.api_fetch()` Hardening

**What:** Add `req_error()` + `req_retry()` and replace auto-error with manual `cli_abort()`.
**When to use:** Whenever `.api_fetch()` is called (all API fetch methods go through it).

```r
# Source: Context7 /r-lib/httr2 — req_error, req_retry

.api_fetch <- function(con_info, endpoint_key) {
  endpoint <- con_info$endpoints[[endpoint_key]]
  url      <- paste0(con_info$base_url, endpoint)
  uid_str  <- paste(con_info$creel_uids, collapse = ",")

  req <- httr2::request(url)
  query_args <- stats::setNames(list(uid_str), con_info$uid_param)
  req <- do.call(httr2::req_url_query, c(list(req), query_args))

  # Auth wiring unchanged
  auth <- con_info$auth
  if (!is.null(auth)) {
    if (auth$type == "bearer") {
      req <- httr2::req_auth_bearer_token(req, auth$token)
    } else if (auth$type == "api_key") {
      hdr      <- if (!is.null(auth$header) && nzchar(auth$header)) auth$header else "X-API-Key"
      hdr_args <- stats::setNames(list(auth$key), hdr)
      req      <- do.call(httr2::req_headers, c(list(req), hdr_args))
    }
  }

  # D-13: disable httr2 auto-error so we can build a cli_abort() message
  req  <- httr2::req_error(req, is_error = \(resp) FALSE)
  # D-10/D-11: retry on 429/503 (httr2 default), max 3 tries
  req  <- httr2::req_retry(req, max_tries = 3L)
  resp <- httr2::req_perform(req)

  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    # D-12: human-readable error with status, endpoint, and body
    body_text <- tryCatch(
      {
        b <- httr2::resp_body_json(resp, simplifyVector = FALSE)
        paste(utils::capture.output(str(b)), collapse = "\n")
      },
      error = function(e) httr2::resp_body_string(resp)
    )
    cli::cli_abort(c(
      "API request failed [{status}]",
      "i" = "Endpoint: {endpoint}",
      "x" = body_text
    ))
  }

  result <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  if (is.null(result) || (is.list(result) && length(result) == 0L)) {
    return(data.frame())
  }
  as.data.frame(result)
}
```

### Pattern 2: API S3 Method Pipeline

**What:** Each `fetch_*.creel_connection_api` follows read → rename → synthesize → coerce → validate.
**When to use:** All five new S3 methods.

```r
# Source: adapted from existing fetch_*.creel_connection_csv pattern in fetch-loaders.R

# Internal: rename raw API columns to canonical names using a hardcoded map.
# api_rename_map: named character vector where names = canonical names,
#   values = raw NGPC JSON field names (e.g., c(interview_uid = "ii_UID", date = "cd_Date")).
# Columns in rename map but absent from df are dropped (same behavior as .rename_to_canonical).
.rename_api_to_canonical <- function(df, api_rename_map) {
  keep <- character(0)
  for (canonical in names(api_rename_map)) {
    api_col <- api_rename_map[[canonical]]
    if (api_col %in% names(df)) {
      keep[[canonical]] <- api_col
    }
  }
  result <- df[, keep, drop = FALSE]
  names(result) <- names(keep)
  result
}

#' @export
fetch_interviews.creel_connection_api <- function(conn, ...) {
  raw_df <- .api_fetch(conn$con, "interviews")

  # Hardcoded NGPC field names — do NOT route through creel_schema
  api_rename_map <- c(
    interview_uid = "ii_UID",
    date          = "cd_Date",
    catch_count   = "Num",          # TODO: confirm field name with live API
    trip_status   = "ii_TripType"   # TODO: confirm field name with live API
  )
  df <- .rename_api_to_canonical(raw_df, api_rename_map)

  # Effort: arithmetic from two raw fields (only method with field arithmetic)
  hours_col   <- "ii_TimeFishedHours"   # TODO: confirm field name with live API
  minutes_col <- "ii_TimeFishedMinutes" # TODO: confirm field name with live API
  if (hours_col %in% names(raw_df) && minutes_col %in% names(raw_df)) {
    df$effort <- as.numeric(raw_df[[hours_col]]) +
                 as.numeric(raw_df[[minutes_col]]) / 60
  }

  if ("date" %in% names(df))         df$date         <- .parse_api_date(df$date)
  if ("catch_count" %in% names(df))  df$catch_count  <- as.numeric(df$catch_count)
  if ("trip_status" %in% names(df))  df$trip_status  <- as.character(df$trip_status)

  validate_fetch_interviews(df)
  df
}
```

### Pattern 3: UID Synthesis (D-05, D-06)

**What:** If `catch_uid` or `length_uid` are absent from the API response, synthesize them as `seq_len(nrow(df))` after the rename step.
**When to use:** `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`.

```r
# Source: CONTEXT.md D-05, D-06

# After .rename_api_to_canonical():
if (!"catch_uid" %in% names(df)) {
  df$catch_uid <- seq_len(nrow(df))
}
```

### Pattern 4: Constant Column Injection

**What:** Harvest/release length endpoints return no `length_type` flag — inject a constant.
**When to use:** `fetch_harvest_lengths` and `fetch_release_lengths`.

```r
df$length_type <- "harvest"   # or "release"
```

### Pattern 5: `local_mocked_responses()` for Tests

**What:** Replace real HTTP with controlled mock responses inside test blocks.
**When to use:** All API method tests and `.api_fetch()` hardening tests.

```r
# Source: Context7 /r-lib/httr2 — local_mocked_responses

library(httr2)

# Happy path: single mock returning a JSON array
test_that("fetch_catch.creel_connection_api() returns canonical columns", {
  local_mocked_responses(function(req) {
    response(200,
      headers = "Content-Type: application/json",
      body = charToRaw('[{"ii_UID":"A1","ir_Species":"86","Num":2,"CatchType":"harvested"}]')
    )
  })
  conn <- make_api_conn()
  result <- fetch_catch(conn)
  expect_true(is.data.frame(result))
  expect_equal(names(result), c("catch_uid", "interview_uid", "species", "catch_count", "catch_type"))
  expect_equal(result$interview_uid, "A1")
  expect_true(is.character(result$species))
})

# Retry test: 429 then 200 → succeeds
test_that(".api_fetch() retries on 429 and succeeds", {
  local_mocked_responses(list(
    response(429, headers = "Content-Type: application/json", body = charToRaw("[]")),
    response(200, headers = "Content-Type: application/json", body = charToRaw("[]"))
  ))
  conn <- make_api_conn()
  expect_no_error(fetch_catch(conn))
})

# Exhaust retries: 429 × list length → falls back to 503 (list exhausted behavior)
test_that(".api_fetch() aborts after exhausting retries", {
  local_mocked_responses(list(
    response(429, headers = "Content-Type: application/json", body = charToRaw("")),
    response(429, headers = "Content-Type: application/json", body = charToRaw("")),
    response(429, headers = "Content-Type: application/json", body = charToRaw(""))
  ))
  conn <- make_api_conn()
  expect_error(fetch_catch(conn), "API request failed")
})

# Empty response: [] → 0-row df with correct column names
test_that("fetch_catch.creel_connection_api() handles empty API response", {
  local_mocked_responses(function(req) {
    response(200, headers = "Content-Type: application/json", body = charToRaw("[]"))
  })
  conn <- make_api_conn()
  result <- fetch_catch(conn)
  expect_equal(nrow(result), 0L)
  expect_true("interview_uid" %in% names(result))
})
```

### Anti-Patterns to Avoid

- **Using `.rename_to_canonical(df, schema, rename_map)`** for API methods: it routes through `schema[[field]]` lookup and will produce a 0-column result because schema keys resolve CSV column names, not NGPC JSON field names. API methods must use `.rename_api_to_canonical(df, api_rename_map)` or inline the rename loop.
- **Using `as.Date()` directly on API date fields:** ISO-8601 datetime strings like `"2016-03-28T00:00:00"` silently become NA with `as.Date()` when no `tryFormats` includes the datetime format. Always call `.parse_api_date()`.
- **Sharing one global `api_rename_map` across all methods:** harvest/release lengths use `iiUID` (no underscore), interviews use `ii_UID`. A shared map silently drops `interview_uid` from length data.
- **Returning `data.frame()` with 0 columns from empty `[]` response:** When the API returns `[]`, `resp_body_json(simplifyVector = TRUE)` returns an empty list, so `.api_fetch()` returns `data.frame()`. The `fetch_*` method's rename step on a 0-column df will still produce 0-row output with the correct column names because `.rename_api_to_canonical()` iterates the rename_map, not the df columns.
- **Retrying on 404:** Only 429 and 503 are transient. `req_retry(max_tries = 3L)` with no `is_transient` override correctly retries only on 429 and 503 (httr2 1.2.2 default verified).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP retry with backoff | Custom retry loop | `httr2::req_retry(max_tries = 3L)` | Handles exponential backoff, `Retry-After` header parsing, circuit-breaking |
| HTTP mock in tests | Custom test server, httptest2 | `httr2::local_mocked_responses()` | Built into httr2 ≥ 1.0.0; no extra dependency; sequence and function modes |
| Date parsing from ISO-8601 | `as.Date()` with manual strptime | `.parse_api_date()` (already exists) | Already handles both `"YYYY-MM-DD"` and `"YYYY-MM-DDTHH:MM:SS"` formats |
| Column contract validation | Inline type checks | `validate_fetch_*()` (already exists) | Shared with CSV path; aborts with all failures in one message |

---

## NGPC API Field Rename Maps (Authoritative Reference)

These are the hardcoded `api_rename_map` vectors for each method. The source is `CreelDataAccess.R` v3.2.1 (NGPC reference implementation) cross-referenced with STATE.md.

### `fetch_interviews` — `AnalysisData/GetInterviewData`

```r
api_rename_map <- c(
  interview_uid = "ii_UID",
  date          = "cd_Date",
  catch_count   = "Num",          # TODO: confirm field name with live API
  trip_status   = "ii_TripType"   # TODO: confirm field name with live API
)
# Effort requires arithmetic — NOT in the rename map:
# effort = ii_TimeFishedHours + ii_TimeFishedMinutes / 60
# (TODO: confirm both field names with live API)
```

[ASSUMED: `Num` for `catch_count` and `ii_TripType` for `trip_status` — source: STATE.md candidates, not confirmed against live API]
[ASSUMED: `ii_TimeFishedHours` and `ii_TimeFishedMinutes` — source: STATE.md / FEATURES.md candidates]

### `fetch_counts` — `AnalysisData/GetCountData`

```r
api_rename_map <- c(
  date         = "cd_Date",
  angler_count = "ii_NumberAnglers"  # TODO: confirm field name with live API
)
```

[ASSUMED: `ii_NumberAnglers` for `angler_count` — source: STATE.md candidate, not confirmed]

### `fetch_catch` — `AnalysisData/GetCatchData`

```r
api_rename_map <- c(
  interview_uid = "ii_UID",
  species       = "ir_Species",
  catch_count   = "Num",
  catch_type    = "CatchType"
)
# catch_uid: synthesize as seq_len(nrow(df)) if absent (D-05)
```

[CITED: FEATURES.md reference code `select(ii_UID, ir_Species, Num, CatchType)` — sourced from CreelDataAccess.R]

### `fetch_harvest_lengths` — `AnalysisData/GetHarvestLengthData`

```r
api_rename_map <- c(
  interview_uid = "iiUID",       # NOTE: no underscore — differs from ii_UID in interviews
  species       = "ih_Species",
  length_mm     = "ihl_Length"
)
# length_uid: synthesize as seq_len(nrow(df)) if absent (D-05)
# length_type: inject constant "harvest" (API returns no type flag)
```

[CITED: FEATURES.md reference code `select(UID=iiUID, ih_Number, ih_Species, ihl_Length)` — sourced from CreelDataAccess.R]

### `fetch_release_lengths` — `AnalysisData/GetReleaseLengthData`

```r
api_rename_map <- c(
  interview_uid = "iiUID",       # NOTE: no underscore — same as harvest lengths
  species       = "ir_Species",
  length_mm     = "ir_LengthGroup"
)
# length_uid: synthesize as seq_len(nrow(df)) if absent (D-05)
# length_type: inject constant "release"
# ir_Count: raw count per record — rename and coerce as numeric; add TODO if aggregation needed
```

[CITED: FEATURES.md reference code `select(UID=iiUID, ir_Species, ir_LengthGroup, ir_Count)` — sourced from CreelDataAccess.R]

---

## Common Pitfalls

### Pitfall 1: Routing API Field Names Through `creel_schema`

**What goes wrong:** Calling `.rename_to_canonical(df, schema, rename_map)` in an API method produces a 0-column result and immediate validation failure.
**Why it happens:** `.rename_to_canonical()` does `csv_col <- schema[[field]]` to resolve field names — this returns the user's CSV column name, not the NGPC JSON field name. The JSON field (`ii_UID`) will never match a schema key (`interview_uid_col`).
**How to avoid:** Use `.rename_api_to_canonical(df, api_rename_map)` with the hardcoded NGPC field names as values.
**Warning signs:** Validation error "interview_uid (any): column missing" on a non-empty JSON response.

### Pitfall 2: `iiUID` vs `ii_UID` Mismatch

**What goes wrong:** Harvest/release length records silently lose their `interview_uid` column.
**Why it happens:** The interview endpoint uses `ii_UID` (underscore between `ii` and `UID`); the harvest/release length endpoints use `iiUID` (no underscore). Using the interview map for length methods means `iiUID` is not found in the rename map, so `interview_uid` is absent from the result.
**How to avoid:** Define separate `api_rename_map` per method. The length methods must use `interview_uid = "iiUID"`.
**Warning signs:** Validation passes (because `interview_uid = "any"` accepts any type including NULL) but join to interview table produces 0 rows.

### Pitfall 3: `as.Date()` on ISO-8601 Datetime Strings

**What goes wrong:** Date columns become all-NA when the API returns `"2016-03-28T00:00:00"`.
**Why it happens:** `as.Date()` with `tryFormats = c("%Y-%m-%d", "%m/%d/%Y")` does not attempt `strptime()` with `%T`. The presence of `T` makes the string unparseable, and `as.Date()` silently returns NA with a warning.
**How to avoid:** Always call `.parse_api_date()` on API date fields — it already handles both forms.
**Warning signs:** `validate_fetch_interviews()` passes but `result$date` is all NA; R warning about "NAs introduced by coercion".

### Pitfall 4: Empty `[]` → 0-Column `data.frame()` Propagation

**What goes wrong:** An API returning `[]` causes `.api_fetch()` to return `data.frame()` (0 columns, 0 rows). The rename step on this 0-column frame produces a 0-row frame with the correct column names (because `.rename_api_to_canonical()` iterates the map, not the frame). Validation then aborts because the columns have type `logical` (empty vectors default to `logical`) but validators expect `numeric`, `character`, or `Date`.
**Why it happens:** `data.frame()[, character(0), drop = FALSE]` gives 0 columns, but after renaming with a map that yields no matches, the result is a 0-row frame constructed from named empty vectors — their types are `logical` by default in R.
**How to avoid:** After the rename step, if `nrow(df) == 0L`, coerce each column to its expected type before calling validate. Or: check for empty result immediately after `.api_fetch()` and return a typed 0-row data.frame early.
**Warning signs:** Validation aborts with "date (Date): found logical" on empty API responses in tests.

### Pitfall 5: `req_retry` Default Retry Count Warning

**What goes wrong:** Calling `req_retry(req, max_tries = NULL)` (omitting the argument) triggers a console message "Setting max_tries = 2" and uses only 2 retries instead of the required 3.
**Why it happens:** `req_retry()` requires either `max_tries` or `max_seconds` to be set. When both are NULL, httr2 1.2.2 defaults to 2 and emits a `cli_inform()`.
**How to avoid:** Always pass `max_tries = 3L` explicitly.
**Warning signs:** Console output "Setting max_tries = 2." during tests.

### Pitfall 6: `.api_fetch()` Error Handling Interaction with `req_retry`

**What goes wrong:** When `req_error(is_error = FALSE)` is set, httr2 does not raise errors for 4xx/5xx — meaning `req_retry` will not trigger retries on these status codes by default, because `req_retry`'s `retry_on_failure` defaults to `FALSE` (retries on errors, not non-error 4xx responses).
**Why it happens:** `req_retry()`'s default `is_transient` checks `resp_status(resp) %in% c(429, 503)`. This works on the response object regardless of `req_error` suppression — it checks the HTTP status, not whether an R error was raised.
**How to avoid:** Verify with the installed httr2 source (confirmed above): the default `is_transient` predicate checks response status directly — it is NOT gated on `req_error()`. The combination of `req_error(is_error = FALSE)` + `req_retry(max_tries = 3L)` works correctly: retries trigger on 429/503 status, and the post-perform status check in `.api_fetch()` handles the final non-2xx response.
**Warning signs:** Integration tests that mock 429→200 sequences fail because the retry never triggers.

---

## Code Examples

### `.api_fetch()` full hardened implementation

```r
# Source: Context7 /r-lib/httr2 — req_error, req_retry, resp_status, resp_body_json
.api_fetch <- function(con_info, endpoint_key) {
  endpoint <- con_info$endpoints[[endpoint_key]]
  url      <- paste0(con_info$base_url, endpoint)
  uid_str  <- paste(con_info$creel_uids, collapse = ",")

  req        <- httr2::request(url)
  query_args <- stats::setNames(list(uid_str), con_info$uid_param)
  req        <- do.call(httr2::req_url_query, c(list(req), query_args))

  auth <- con_info$auth
  if (!is.null(auth)) {
    if (auth$type == "bearer") {
      req <- httr2::req_auth_bearer_token(req, auth$token)
    } else if (auth$type == "api_key") {
      hdr      <- if (!is.null(auth$header) && nzchar(auth$header)) auth$header else "X-API-Key"
      hdr_args <- stats::setNames(list(auth$key), hdr)
      req      <- do.call(httr2::req_headers, c(list(req), hdr_args))
    }
  }

  req  <- httr2::req_error(req, is_error = \(resp) FALSE)  # D-13
  req  <- httr2::req_retry(req, max_tries = 3L)             # D-10, D-11
  resp <- httr2::req_perform(req)

  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    body_text <- tryCatch(
      {
        b <- httr2::resp_body_json(resp, simplifyVector = FALSE)
        paste(utils::capture.output(utils::str(b)), collapse = "\n")
      },
      error = function(e) httr2::resp_body_string(resp)
    )
    cli::cli_abort(c(
      "API request failed [{status}]",
      "i" = "Endpoint: {endpoint}",
      "x" = body_text
    ))
  }

  result <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  if (is.null(result) || (is.list(result) && length(result) == 0L)) {
    return(data.frame())
  }
  as.data.frame(result)
}
```

### `local_mocked_responses()` — 404 error test

```r
# Source: Context7 /r-lib/httr2 — local_mocked_responses
test_that(".api_fetch() aborts on 404 with cli message containing status and endpoint", {
  local_mocked_responses(function(req) {
    response(404,
      headers = "Content-Type: application/json",
      body    = charToRaw('{"error":"Not Found"}')
    )
  })
  conn <- make_api_conn()
  expect_error(fetch_interviews(conn), "API request failed \\[404\\]")
})
```

### `local_mocked_responses()` — sequence for retry test

```r
# Source: Context7 /r-lib/httr2 — local_mocked_responses list mode
test_that(".api_fetch() retries on 429 and succeeds on second attempt", {
  # list mode: responses returned in order; list exhausted → 503
  local_mocked_responses(list(
    response(429, headers = "Content-Type: application/json", body = charToRaw("")),
    response(200,
      headers = "Content-Type: application/json",
      body    = charToRaw('[{"ii_UID":"A","Num":0,"CatchType":"harvested","ir_Species":"86","cd_Date":"2016-01-01"}]')
    )
  ))
  conn <- make_api_conn()
  expect_no_error(fetch_interviews(conn))
})
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `requireNamespace("httr2", ...)` guard in `.api_fetch()` | `httr2` in `Imports`; no guard needed | This phase (D-14) | Cleaner; httr2 functions callable without qualification guard |
| `httr2` in `Suggests` | `httr2 >= 1.0.0` in `Imports` | This phase | httr2 is now a required dependency for `tidycreel.connect` |
| No retry or error customization in `.api_fetch()` | `req_retry(max_tries = 3L)` + `req_error(is_error = FALSE)` | This phase | Transient failures auto-retry; errors surface human-readable messages |

**Deprecated/outdated:**
- `requireNamespace("httr2", quietly = TRUE)` guard: removed — replaced by `Imports` declaration.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | API field for catch count in GetInterviewData is `"Num"` | NGPC Field Rename Maps | Wrong field name → `catch_count` missing → validation abort |
| A2 | API field for trip status in GetInterviewData is `"ii_TripType"` | NGPC Field Rename Maps | Wrong field name → `trip_status` missing → validation abort |
| A3 | Effort fields are `"ii_TimeFishedHours"` and `"ii_TimeFishedMinutes"` | NGPC Field Rename Maps | Wrong names → `effort` becomes NA → validation abort |
| A4 | Angler count field in GetCountData is `"ii_NumberAnglers"` | NGPC Field Rename Maps | Wrong field → `angler_count` missing → validation abort |
| A5 | `ir_Count` in release lengths is a raw count per record (no aggregation needed in fetch method) | NGPC Field Rename Maps | If pre-aggregated per length bin, fetch method may need row expansion |

All `[ASSUMED]` claims are marked TODO in the rename maps. Phase 90 live-data validation will resolve these.

---

## Open Questions (RESOLVED)

1. **Empty `[]` → 0-row df with correct column types**
   - What we know: `.api_fetch()` returns `data.frame()` (0 columns) for `[]`; rename step on 0-column df produces 0-row df with correct column names but `logical` types for all columns.
   - What's unclear: Does `validate_fetch_*()` abort on a 0-row df where `date` is `logical`? The validator calls `inherits(df[[col]], "Date")` which is `FALSE` for `logical`.
   - Recommendation: Add an early-return guard in each `fetch_*` method after `.api_fetch()`: if `nrow(raw_df) == 0L`, construct and return a typed 0-row df directly without calling rename/coerce/validate pipeline. This is the cleanest solution.

2. **`ir_Count` aggregation policy for release lengths**
   - What we know: The reference code selects `ir_Count` as a column from the API; it appears to be a per-record count per length bin.
   - What's unclear: Whether `ir_Count` should be renamed to a canonical column or used only for row expansion.
   - Recommendation: Rename `ir_Count` → no canonical target (it has no equivalent in the CSV path). Per D-03, add a TODO comment and treat it as a non-canonical column that is dropped after the rename step, unless the planner decides otherwise.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| httr2 | `.api_fetch()` hardening, all API tests | ✓ | 1.2.2 | — |
| testthat | Test suite | ✓ | 3.3.2 | — |
| withr | Test helpers | ✓ | 3.0.2 | — |
| cli | Error messages | ✓ | (in Imports) | — |

[VERIFIED: all versions confirmed via `Rscript -e "packageVersion()"` calls]

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.3.2 |
| Config file | `tidycreel.connect/DESCRIPTION` — `Config/testthat/edition: 3` |
| Quick run command | `devtools::test(pkg = "tidycreel.connect", filter = "api")` |
| Full suite command | `devtools::test(pkg = "tidycreel.connect")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| API-01 | `fetch_interviews()` returns canonical columns with correct types | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-interviews")` | ❌ Wave 0 (new block in existing file) |
| API-02 | `fetch_counts()` returns canonical columns with correct types | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-counts")` | ❌ Wave 0 |
| API-03 | `fetch_catch()` returns canonical columns including synthesized `catch_uid` | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-catch")` | ❌ Wave 0 |
| API-04 | `fetch_harvest_lengths()` returns canonical columns with `length_type = "harvest"` | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-lengths")` | ❌ Wave 0 |
| API-05 | `fetch_release_lengths()` returns canonical columns with `length_type = "release"` | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-lengths")` | ❌ Wave 0 |
| API-06 | `.api_fetch()` aborts on non-2xx; retries on 429/503 up to 3× | unit | `devtools::test(pkg = "tidycreel.connect", filter = "api-fetch")` | ❌ Wave 0 (new file) |

### Sampling Rate

- **Per task commit:** `devtools::test(pkg = "tidycreel.connect", filter = "api")`
- **Per wave merge:** `devtools::test(pkg = "tidycreel.connect")`
- **Phase gate:** Full suite green + `rcmdcheck::rcmdcheck("tidycreel.connect", args = "--no-manual")` 0 errors, 0 warnings before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tidycreel.connect/tests/testthat/test-api-fetch.R` — covers API-06
- [ ] `tidycreel.connect/tests/testthat/helper-api.R` — `make_api_conn()` helper for API tests
- [ ] API test blocks in `test-fetch-interviews.R`, `test-fetch-counts.R`, `test-fetch-catch.R`, `test-fetch-lengths.R` — cover API-01 through API-05

---

## Security Domain

> `security_enforcement` not explicitly set to `false` in config.json — section included.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `httr2::req_auth_bearer_token()` / `httr2::req_headers()` — already implemented in `.api_fetch()`; no changes needed |
| V3 Session Management | no | Stateless REST API; no session tokens |
| V4 Access Control | no | Access control is server-side; client only sends UID list |
| V5 Input Validation | yes | `uid_param` and `creel_uids` validated in `creel_connect_api()` constructor; API response validated by `validate_fetch_*()` |
| V6 Cryptography | no | No new cryptographic operations; token storage is user's responsibility (env vars) |

### Known Threat Patterns for httr2 + R

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Bearer token in plain string | Information Disclosure | Project convention: `Sys.getenv("CREEL_API_TOKEN")` — do not hardcode in source |
| Unbounded retry amplification | Denial of Service | `max_tries = 3L` cap; exponential backoff with `Retry-After` respect |
| JSON injection via `creel_uids` | Tampering | UIDs are passed as a query parameter value (percent-encoded by `req_url_query()`); no shell or SQL injection path |

---

## Sources

### Primary (HIGH confidence)

- Context7 `/r-lib/httr2` — `req_error()`, `req_retry()`, `local_mocked_responses()`, `response()`, `resp_body_json()`, `resp_status()` API verified
- `Rscript -e "packageVersion('httr2')"` → 1.2.2 — installed version confirmed
- `Rscript -e "deparse(body(req_retry))"` → default `max_tries = 2` when NULL; explicit `3L` required
- `getFromNamespace('retry_is_transient', 'httr2')` → default retries on `resp_status(resp) %in% c(429, 503)` — exactly matches D-10

### Secondary (MEDIUM confidence)

- `.planning/research/FEATURES.md` — NGPC field rename maps derived from CreelDataAccess.R reference code
- `.planning/research/PITFALLS.md` — `iiUID` vs `ii_UID` asymmetry, empty array guard, date parsing pitfalls
- `.planning/research/SUMMARY.md` — effort arithmetic formula `ii_TimeFishedHours + ii_TimeFishedMinutes / 60`

### Tertiary (LOW confidence)

- STATE.md candidates for unconfirmed field names (`ii_NumberAnglers`, `ii_TripType`, `Num` for catch_count) — marked [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — httr2 1.2.2 installed; all key functions verified via Context7 and R source inspection
- Architecture: HIGH — pipeline pattern directly mirrors existing CSV methods; `.api_fetch()` change is additive only
- NGPC field rename maps: MEDIUM for confirmed fields (CreelDataAccess.R reference), LOW for TODO-flagged fields
- Pitfalls: HIGH — all pitfalls verified against httr2 source or existing codebase behavior

**Research date:** 2026-05-09
**Valid until:** 2026-08-09 (httr2 is stable; API field names require live validation in Phase 90)
