# Phase 88: httr2 Hardening and API Fetch Methods - Pattern Map

**Mapped:** 2026-05-09
**Files analyzed:** 8 (2 modified existing source, 1 modified DESCRIPTION, 2 new source, 4 extended/new test files)
**Analogs found:** 8 / 8

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tidycreel.connect/R/creel-connection-api.R` | service/utility | request-response | itself (in-place hardening) | exact |
| `tidycreel.connect/R/fetch-loaders.R` | service | request-response | itself — `fetch_*.creel_connection_csv` methods | exact |
| `tidycreel.connect/DESCRIPTION` | config | — | itself (in-place edit) | exact |
| `tidycreel.connect/tests/testthat/test-api-fetch.R` | test | request-response | `test-fetch-catch.R` | role-match |
| `tidycreel.connect/tests/testthat/helper-api.R` | test helper | — | `helper-csv.R` | role-match |
| `tidycreel.connect/tests/testthat/test-fetch-interviews.R` | test | request-response | itself (extend with API block) | exact |
| `tidycreel.connect/tests/testthat/test-fetch-counts.R` | test | request-response | itself (extend with API block) | exact |
| `tidycreel.connect/tests/testthat/test-fetch-catch.R` | test | request-response | itself (extend with API block) | exact |
| `tidycreel.connect/tests/testthat/test-fetch-lengths.R` | test | request-response | itself (extend with API block) | exact |

---

## Pattern Assignments

### `tidycreel.connect/R/creel-connection-api.R` — `.api_fetch()` hardening

**Analog:** itself — current `.api_fetch()` at lines 172–206 is the base; hardening is additive.

**Current implementation to replace** (lines 172–206):

```r
.api_fetch <- function(con_info, endpoint_key) {
  if (!requireNamespace("httr2", quietly = TRUE)) {          # REMOVE: D-14 drops this guard
    cli::cli_abort(c(
      "Package {.pkg httr2} is required for API connections.",
      "i" = "Install it with {.code install.packages('httr2')}."
    ))
  }

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

  resp   <- httr2::req_perform(req)                          # REPLACE these two lines
  result <- httr2::resp_body_json(resp, simplifyVector = TRUE)

  if (is.null(result) || (is.list(result) && length(result) == 0L)) {
    return(data.frame())
  }
  as.data.frame(result)
}
```

**Hardened pattern** — what replaces lines 199–206:

```r
  # D-13: disable httr2 auto-error; manual cli_abort() controls format
  req  <- httr2::req_error(req, is_error = \(resp) FALSE)
  # D-10, D-11: retry only on 429/503 (httr2 1.2.2 default), max 3 tries
  req  <- httr2::req_retry(req, max_tries = 3L)
  resp <- httr2::req_perform(req)

  status <- httr2::resp_status(resp)
  if (status >= 400L) {
    # D-12: human-readable error with status, endpoint path, and body
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
```

**cli_abort pattern** (source: lines 83–88 of `creel-connection-api.R` — same project style):

```r
cli::cli_abort(c(
  "{.arg schema} must be a {.cls creel_schema} object.",
  "i" = "Create one with {.fn tidycreel::creel_schema}."
))
```

---

### `tidycreel.connect/R/fetch-loaders.R` — five new `fetch_*.creel_connection_api` methods

**Analog:** `fetch_*.creel_connection_csv` methods in the same file (lines 46–227).

**Internal helper to add** (new, modelled after `.rename_to_canonical()` at lines 14–26):

```r
# Internal: rename raw NGPC API columns to canonical names using a hardcoded map.
# api_rename_map: named character vector where names = canonical names,
#   values = raw NGPC JSON field names (e.g., c(interview_uid = "ii_UID", date = "cd_Date")).
# Columns in api_rename_map but absent from df are silently dropped (same behaviour as
# .rename_to_canonical). Returns a plain data.frame with only matched canonical columns.
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
```

**CSV method pattern to mirror** (lines 46–64, `fetch_interviews.creel_connection_csv`):

```r
#' @export
fetch_interviews.creel_connection_csv <- function(conn, ...) {
  df <- .read_csv_safe(conn$con$interviews)
  rename_map <- c(
    interview_uid = "interview_uid_col",
    date          = "date_col",
    catch_count   = "catch_col",
    effort        = "effort_col",
    trip_status   = "trip_status_col"
  )
  df <- .rename_to_canonical(df, conn$schema, rename_map)
  if ("date" %in% names(df)) {
    df$date <- as.Date(df$date, tryFormats = c("%Y-%m-%d", "%m/%d/%Y"))
  }
  if ("catch_count" %in% names(df)) df$catch_count <- as.numeric(df$catch_count)
  if ("effort" %in% names(df)) df$effort <- as.numeric(df$effort)
  if ("trip_status" %in% names(df)) df$trip_status <- as.character(df$trip_status)
  validate_fetch_interviews(df) # nolint: object_usage_linter
  df
}
```

**API method structural pattern** — apply to all five methods, using `fetch_interviews` as the most complex exemplar:

```r
#' @export
fetch_interviews.creel_connection_api <- function(conn, ...) {
  raw_df <- .api_fetch(conn$con, "interviews")

  # Early return for empty API response — avoids logical-typed columns failing validation
  if (nrow(raw_df) == 0L) {
    return(data.frame(
      interview_uid = character(0),
      date          = as.Date(character(0)),
      catch_count   = numeric(0),
      effort        = numeric(0),
      trip_status   = character(0),
      stringsAsFactors = FALSE
    ))
  }

  # Hardcoded NGPC field names — do NOT route through creel_schema (CONTEXT.md constraint)
  api_rename_map <- c(
    interview_uid = "ii_UID",
    date          = "cd_Date",
    catch_count   = "Num",         # TODO: confirm field name with live API
    trip_status   = "ii_TripType"  # TODO: confirm field name with live API
  )
  df <- .rename_api_to_canonical(raw_df, api_rename_map)

  # Effort: arithmetic from two raw fields — only method requiring field arithmetic
  hours_col   <- "ii_TimeFishedHours"   # TODO: confirm field name with live API
  minutes_col <- "ii_TimeFishedMinutes" # TODO: confirm field name with live API
  if (hours_col %in% names(raw_df) && minutes_col %in% names(raw_df)) {
    df$effort <- as.numeric(raw_df[[hours_col]]) +
                 as.numeric(raw_df[[minutes_col]]) / 60
  }

  if ("date" %in% names(df))        df$date        <- .parse_api_date(df$date)
  if ("catch_count" %in% names(df)) df$catch_count <- as.numeric(df$catch_count)
  if ("trip_status" %in% names(df)) df$trip_status <- as.character(df$trip_status)

  validate_fetch_interviews(df) # nolint: object_usage_linter
  df
}
```

**UID synthesis pattern** (D-05, D-06 — for `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`):

```r
# After .rename_api_to_canonical() and before type coercion:
if (!"catch_uid" %in% names(df)) {
  df$catch_uid <- seq_len(nrow(df))
}
# Equivalent for length methods:
if (!"length_uid" %in% names(df)) {
  df$length_uid <- seq_len(nrow(df))
}
```

**Constant injection pattern** (for `fetch_harvest_lengths` and `fetch_release_lengths`):

```r
df$length_type <- "harvest"   # or "release" — no type flag comes from the API
```

**SQL Server stub pattern** (lines 67–69, 104–106 — add matching stub for API methods is NOT needed; API methods are being implemented, not stubbed. The SQL Server stub pattern is here for reference only):

```r
#' @export
fetch_interviews.creel_connection_sqlserver <- function(conn, ...) {
  cli::cli_abort("SQL Server fetch_interviews() not yet implemented (Phase 69).")
}
```

---

### `tidycreel.connect/DESCRIPTION` — promote httr2 to Imports

**Analog:** current DESCRIPTION (lines 1–27, read directly).

**Current Suggests block** (lines 21–27):

```
Suggests:
    config,
    duckdb,
    httr2,
    odbc,
    testthat (>= 3.0.0),
    withr
```

**Target state** — move `httr2` from Suggests to Imports with version floor:

```
Imports:
    cli,
    DBI,
    httr2 (>= 1.0.0),
    readr,
    tidycreel
Suggests:
    config,
    duckdb,
    odbc,
    testthat (>= 3.0.0),
    withr
```

Note: `httr2` does not appear in the current `Suggests` block by name — DESCRIPTION currently lists `config, duckdb, odbc, testthat (>= 3.0.0), withr`. The current `.api_fetch()` guards with `requireNamespace("httr2", ...)` implying it is a soft dep not yet declared. The edit is: add `httr2 (>= 1.0.0)` to `Imports`, no removal from Suggests needed.

---

### `tidycreel.connect/tests/testthat/helper-api.R` — new test helper

**Analog:** `helper-csv.R` (lines 1–201). The helper-csv.R pattern:
- Top-level comment naming the helper and its purpose
- Functions named `make_test_*()` using `withr::local_tempdir()` for scoped cleanup
- Returns the fixture object needed by tests

**Pattern to follow** (lines 1–7 of `helper-csv.R`):

```r
# Helper: write temporary CSV fixtures for CSV backend tests
# Returns a named list of file paths (interviews, counts, catch, harvest_lengths, release_lengths)

make_test_schema <- function() {
  tidycreel::creel_schema(
    survey_type       = "instantaneous",
    ...
  )
}
```

**API helper structure** — what `helper-api.R` must contain:

```r
# Helper: construct a creel_connection_api fixture for API backend tests.
# make_api_conn() returns a creel_connection_api object pointing at a dummy base_url.
# Tests wrap their calls in httr2::local_mocked_responses() to intercept HTTP.

make_api_conn <- function() {
  schema <- tidycreel::creel_schema(survey_type = "instantaneous")
  tidycreel.connect::creel_connect_api(
    base_url   = "http://test.example.com/api/",
    creel_uids = "test-uid-001",
    schema     = schema
  )
}
```

Note: `withr::local_tempdir` is NOT needed here — no temp files. The helper only constructs a connection object. Keep it minimal.

---

### `tidycreel.connect/tests/testthat/test-api-fetch.R` — new test file for API-06

**Analog:** `test-fetch-catch.R` (lines 1–39) — same single-file, multiple `test_that()` block pattern.

**File header pattern** (from `test-fetch-catch.R` line 1):

```r
# Tests for fetch_catch() — FETCH-03, FETCH-06, BACKEND-01
```

**API test file header:**

```r
# Tests for .api_fetch() hardening — API-06
```

**`local_mocked_responses()` — function mode** (happy path, 200 response):

```r
test_that(".api_fetch() returns data.frame on 200 response (API-06)", {
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      200,
      headers = "Content-Type: application/json",
      body    = charToRaw('[{"ii_UID":"A1","cd_Date":"2016-03-28","Num":2,"ii_TripType":"complete"}]')
    )
  })
  conn <- make_api_conn()
  result <- fetch_interviews(conn)
  expect_true(is.data.frame(result))
})
```

**`local_mocked_responses()` — error path** (404):

```r
test_that(".api_fetch() aborts with cli message on 404 (API-06)", {
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      404,
      headers = "Content-Type: application/json",
      body    = charToRaw('{"error":"Not Found"}')
    )
  })
  conn <- make_api_conn()
  expect_error(fetch_interviews(conn), "API request failed \\[404\\]")
})
```

**`local_mocked_responses()` — list mode for retry sequence** (429 → 200):

```r
test_that(".api_fetch() retries on 429 and succeeds on second attempt (API-06)", {
  httr2::local_mocked_responses(list(
    httr2::response(429, headers = "Content-Type: application/json", body = charToRaw("")),
    httr2::response(200, headers = "Content-Type: application/json",
      body = charToRaw('[{"ii_UID":"A1","cd_Date":"2016-03-28","Num":2,"ii_TripType":"complete"}]')
    )
  ))
  conn <- make_api_conn()
  expect_no_error(fetch_interviews(conn))
})
```

**`local_mocked_responses()` — list mode, exhaust retries** (429 × 3 → abort):

```r
test_that(".api_fetch() aborts after exhausting 3 retries on 429 (API-06)", {
  httr2::local_mocked_responses(list(
    httr2::response(429, headers = "Content-Type: application/json", body = charToRaw("")),
    httr2::response(429, headers = "Content-Type: application/json", body = charToRaw("")),
    httr2::response(429, headers = "Content-Type: application/json", body = charToRaw(""))
  ))
  conn <- make_api_conn()
  expect_error(fetch_interviews(conn), "API request failed")
})
```

---

### `test-fetch-interviews.R`, `test-fetch-counts.R`, `test-fetch-catch.R`, `test-fetch-lengths.R` — API method test blocks

**Analog:** the existing CSV blocks in each file (e.g., `test-fetch-catch.R` lines 3–16).

**Exact pattern to replicate for each API block:**

1. Happy path — canonical column names and correct types:

```r
test_that("fetch_catch.creel_connection_api() returns canonical columns (API-03)", {
  httr2::local_mocked_responses(function(req) {
    httr2::response(
      200,
      headers = "Content-Type: application/json",
      body    = charToRaw('[{"ii_UID":"A1","ir_Species":"86","Num":2,"CatchType":"harvested"}]')
    )
  })
  conn <- make_api_conn()
  result <- fetch_catch(conn)
  expect_true(is.data.frame(result))
  expect_equal(sort(names(result)), sort(c("catch_uid","interview_uid","species","catch_count","catch_type")))
  expect_true(is.character(result$species))
  expect_true(is.numeric(result$catch_count))
})
```

2. Empty response — 0-row df with correct column names:

```r
test_that("fetch_catch.creel_connection_api() handles empty API response (API-03)", {
  httr2::local_mocked_responses(function(req) {
    httr2::response(200, headers = "Content-Type: application/json", body = charToRaw("[]"))
  })
  conn <- make_api_conn()
  result <- fetch_catch(conn)
  expect_equal(nrow(result), 0L)
  expect_true("interview_uid" %in% names(result))
  expect_true("catch_uid" %in% names(result))
})
```

**Requirement ID mapping for test comments:**

| File | Req ID |
|------|--------|
| `test-fetch-interviews.R` | `API-01` |
| `test-fetch-counts.R` | `API-02` |
| `test-fetch-catch.R` | `API-03` |
| `test-fetch-lengths.R` (harvest) | `API-04` |
| `test-fetch-lengths.R` (release) | `API-05` |

---

## Shared Patterns

### cli error format
**Source:** `tidycreel.connect/R/creel-connection-api.R` lines 83–88 and 147–165
**Apply to:** `.api_fetch()` non-2xx handler, any new abort in fetch methods

```r
cli::cli_abort(c(
  "API request failed [{status}]",
  "i" = "Endpoint: {endpoint}",
  "x" = body_text
))
```

Bullets use `"i"` for informational context, `"x"` for the failing detail. This matches all existing `cli_abort()` calls in the file.

### Guarded coercion pattern
**Source:** `tidycreel.connect/R/fetch-loaders.R` lines 56–62 (and replicated in every CSV method)
**Apply to:** all five `fetch_*.creel_connection_api` methods

```r
if ("date" %in% names(df))        df$date        <- .parse_api_date(df$date)
if ("catch_count" %in% names(df)) df$catch_count <- as.numeric(df$catch_count)
if ("trip_status" %in% names(df)) df$trip_status <- as.character(df$trip_status)
```

The pattern is: `if (col %in% names(df))` guard before every coercion. Never coerce unconditionally. For API methods, replace `as.Date()` with `.parse_api_date()` (ISO-8601 datetime safe).

### validate_fetch_* call
**Source:** `tidycreel.connect/R/fetch-loaders.R` lines 62, 99, 140, 180, 220
**Apply to:** all five `fetch_*.creel_connection_api` methods — call immediately before `df` is returned, after all coercions

```r
validate_fetch_interviews(df) # nolint: object_usage_linter
df
```

The `# nolint: object_usage_linter` comment is required — the validator functions are defined in a separate file and the linter doesn't see the call.

### Test file header comment
**Source:** `test-fetch-catch.R` line 1, `test-fetch-interviews.R` line 1
**Apply to:** new `test-api-fetch.R` and all extended test files

```r
# Tests for <function>() — <REQ-ID>, <REQ-ID>
```

### local_mocked_responses scoping
**Source:** RESEARCH.md Pattern 5 (verified against httr2 1.2.2)
**Apply to:** all API test blocks

`httr2::local_mocked_responses()` is a withr-style scope that restores state when the `test_that()` block exits. Use `httr2::response()` (not `httr2::new_response()`) to build mock objects. Pass a single function for uniform responses; pass a list for ordered sequences.

---

## No Analog Found

All files in scope have direct analogs in the codebase. No files require falling back to RESEARCH.md patterns exclusively.

---

## Metadata

**Analog search scope:** `tidycreel.connect/R/`, `tidycreel.connect/tests/testthat/`
**Files read:** 9 (creel-connection-api.R, fetch-loaders.R, fetch-validators.R, DESCRIPTION, helper-csv.R, helper-db.R, test-fetch-interviews.R, test-fetch-catch.R, test-fetch-counts.R, test-fetch-lengths.R)
**Pattern extraction date:** 2026-05-09
