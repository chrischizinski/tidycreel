# Architecture Research: tidycreel.connect API Fetch Methods + Creel Discovery

**Domain:** R package companion — REST API backend for creel survey data retrieval
**Researched:** 2026-05-09
**Confidence:** HIGH (direct codebase analysis, all source files read)

---

## Existing Architecture Baseline

The `tidycreel.connect` package is built on three interlocking mechanisms:

**S3 class hierarchy:**
```
creel_connection          (base class: list with $backend, $con, $schema, $status)
  creel_connection_csv    (subclass: $con = named list of file paths)
  creel_connection_api    (subclass: $con = list with base_url, creel_uids, uid_param, endpoints, auth)
  creel_connection_sqlserver  (subclass: $con = DBIConnection)
```

**Dispatch chain for every fetch_*() call:**
```
fetch_interviews(conn)              # exported generic: UseMethod("fetch_interviews")
  -> fetch_interviews.creel_connection_api(conn, ...)
       -> .api_fetch(conn$con, "interviews")   # HTTP GET, returns raw data.frame
       -> .rename_to_canonical(df, conn$schema, rename_map)  # column mapping
       -> type coercion block
       -> validate_fetch_interviews(df)         # abort on missing/wrong-type columns
       -> return df
```

**Three existing files own all current fetch logic:**
- `creel-connection-api.R` — `creel_connect_api()` constructor + `.api_fetch()` + `.parse_api_date()` + `.validate_api_auth()`
- `fetch-loaders.R` — all `fetch_*()` generics + CSV methods + SQL Server stubs
- `fetch-validators.R` — `validate_fetch_*()` per-table validators

**Key invariant:** `.api_fetch()` is deliberately field-agnostic. It does HTTP + JSON decoding only. Column semantics are owned by the method that calls it, not by the helper.

---

## System Overview

```
User code
    |
    | creel_connect_api(base_url, creel_uids, schema, auth)
    |
    v
creel_connection_api  (S3 object)
    $con:  base_url, creel_uids, uid_param, endpoints, auth
    $schema: creel_schema  (maps canonical names -> API field names)
    |
    | fetch_interviews(conn) / fetch_counts(conn) / ...
    |
    v
fetch_*.creel_connection_api  (method in fetch-loaders.R)
    |
    |-- .api_fetch(conn$con, endpoint_key)        [creel-connection-api.R]
    |       GET {base_url}/{endpoint}?{uid_param}={uids}
    |       add auth headers
    |       httr2::req_perform -> resp_body_json -> as.data.frame
    |
    |-- .rename_to_canonical(df, conn$schema, rename_map)
    |       maps API field names -> canonical tidycreel names
    |
    |-- type coercion (date, numeric, character)
    |
    |-- validate_fetch_*(df)                      [fetch-validators.R]
    |
    v
canonical data.frame (same shape as CSV path output)
    |
    v
tidycreel::add_interviews() / add_counts() / ...  (parent package)
```

**Discovery functions sit upstream of any connection object:**
```
list_creels(conn, ...)      \
search_creels(conn, ...)     > hit a discovery endpoint, return metadata data.frame
                            /
(no downstream fetch_* or add_* calls required)
```

---

## Component Responsibilities

| Component | File | Responsibility |
|-----------|------|----------------|
| `creel_connect_api()` | `creel-connection-api.R` | Constructor: validate inputs, resolve endpoints, call `new_creel_connection()` with `subclass = "creel_connection_api"` |
| `.api_fetch()` | `creel-connection-api.R` | HTTP GET + auth + JSON decode only. Field-agnostic. Returns raw data.frame |
| `.parse_api_date()` | `creel-connection-api.R` | Date parsing for ISO 8601 + MM/DD/YYYY formats — shared by all API methods |
| `fetch_*()` generics | `fetch-loaders.R` | `UseMethod()` dispatch entry points — one per table |
| `fetch_*.creel_connection_csv` | `fetch-loaders.R` | CSV path — read file, rename, coerce, validate |
| `fetch_*.creel_connection_api` | `fetch-loaders.R` | **NEW** — call `.api_fetch()`, rename, coerce, validate |
| `fetch_*.creel_connection_sqlserver` | `fetch-loaders.R` | Stub (Phase 69) |
| `.rename_to_canonical()` | `fetch-loaders.R` | Column name mapping using schema field specs — reused by API methods |
| `validate_fetch_*()` | `fetch-validators.R` | Post-rename type/presence checks — reused unchanged by API methods |
| `list_creels()` | NEW `creel-discovery.R` | Generic: `UseMethod("list_creels")` |
| `list_creels.creel_connection_api` | NEW `creel-discovery.R` | Hit discovery endpoint, return metadata data.frame |
| `search_creels()` | NEW `creel-discovery.R` | Generic: `UseMethod("search_creels")` |
| `search_creels.creel_connection_api` | NEW `creel-discovery.R` | Filter discovery results by name/date/location |

---

## Answers to the Three Design Questions

### Question 1: Should `list_creels()` and `search_creels()` be generics or standalone functions?

**Make them generics with S3 dispatch. Do not make them standalone functions.**

Rationale:

The entire package is built around dispatch by connection class. `fetch_interviews(conn)` is the model. A user who has a `creel_connection_api` object should be able to call `list_creels(conn)` on it — the same object they already have, no new arguments. This is the correct S3 pattern:

```r
list_creels <- function(conn, ...) UseMethod("list_creels")
list_creels.creel_connection_api <- function(conn, ...)  { ... }
list_creels.creel_connection_csv <- function(conn, ...)  {
  cli::cli_abort("list_creels() is not supported for CSV connections.")
}
```

A standalone function `list_creels(base_url, auth)` would duplicate the auth-building logic already encapsulated in `.api_fetch()`. It would also require users to track `base_url` and `auth` separately from the connection object they already hold, which is a worse API.

The CSV method should abort with a clear message rather than be omitted. Omitting it causes an unhelpful "no applicable method" error from S3.

**Discovery endpoint assumption:** The UNL/NGPC API likely exposes a top-level listing endpoint (e.g., `AnalysisData/GetCreelList` or similar) without a `uid_param`. The `list_creels.creel_connection_api` method should call `.api_fetch()` with a modified request that omits the `uid_param`, or use a dedicated lightweight HTTP helper. The cleanest approach is to add an optional `omit_uid_param = FALSE` argument to `.api_fetch()`, defaulting to its current behavior, so discovery can reuse all auth-building logic without duplication.

### Question 2: Where should API column renaming happen — inside each `fetch_*.creel_connection_api` method, or in `.api_fetch()`?

**Inside each `fetch_*.creel_connection_api` method. Do not move renaming into `.api_fetch()`.**

The existing pattern is explicit and unambiguous: `.api_fetch()` returns a raw data.frame with API field names. The calling method owns the rename map and the coercion logic. This separation has two benefits:

1. Different endpoints return different fields. A single rename point inside `.api_fetch()` would need per-endpoint knowledge, turning a field-agnostic helper into a field-aware dispatcher — which collapses the abstraction.
2. The `creel_schema` object (which holds the field name mappings) is on the `conn` object, not in `con_info` which is what `.api_fetch()` receives. Passing the schema into `.api_fetch()` just to do renaming there is wrong layering.

The `.rename_to_canonical()` helper already exists in `fetch-loaders.R` and is used by all CSV methods. The API methods will call it identically:

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
  if ("date" %in% names(df)) df$date <- .parse_api_date(df$date)
  if ("catch_count" %in% names(df)) df$catch_count <- as.numeric(df$catch_count)
  if ("effort" %in% names(df)) df$effort <- as.numeric(df$effort)
  if ("trip_status" %in% names(df)) df$trip_status <- as.character(df$trip_status)
  validate_fetch_interviews(df)
  df
}
```

The only difference from the CSV method is:
- `conn$con$interviews` (path) replaced by `.api_fetch(conn$con, "interviews")` (HTTP call)
- `as.Date(..., tryFormats = ...)` replaced by `.parse_api_date()` (handles ISO 8601 T-format)

Everything else — the rename map, the coercions, the validator call — is identical. This is intentional: the output contract is the same regardless of backend.

### Question 3: Suggested build order for the 7 new items

The 5 fetch methods share the exact same structural template and have no inter-dependencies. The 2 discovery functions depend on a pattern decision (generic vs. standalone) that must be settled before writing the first one. The correct build order is:

**Step 1 — `fetch_interviews.creel_connection_api`** (in `fetch-loaders.R`)
The primary table. Establishes the API method template. Has the most columns and the date-parsing edge case. Once this passes tests, the remaining four are mechanical applications of the same pattern.

**Step 2 — `fetch_counts.creel_connection_api`** (in `fetch-loaders.R`)
Simplest table (2 canonical columns). Quick win. Confirms the template works for minimal schemas.

**Step 3 — `fetch_catch.creel_connection_api`** (in `fetch-loaders.R`)
Introduces species-as-character coercion (the NGPC integer species code edge case already in the CSV method). Important to replicate.

**Step 4 — `fetch_harvest_lengths.creel_connection_api`** (in `fetch-loaders.R`)
Step 5 — `fetch_release_lengths.creel_connection_api`** (in `fetch-loaders.R`)
These two share the same schema shape. Build them together in a single pass.

**Step 6 — `list_creels()` generic + `list_creels.creel_connection_api`** (new `creel-discovery.R`)
After all fetch methods are green, the HTTP plumbing is proven. `list_creels` is read-only and does not feed into any downstream fetch or estimation call. Establish the new file and the generic pattern here.

**Step 7 — `search_creels()` generic + `search_creels.creel_connection_api`** (in `creel-discovery.R`)
Depends on `list_creels` output (it filters or re-queries). Build last because its design depends on what `list_creels` actually returns from the API.

---

## Data Flow

### Fetch path (all 5 table methods)

```
User: fetch_interviews(conn)
    |
    | S3 dispatch on class(conn)[1] == "creel_connection_api"
    v
fetch_interviews.creel_connection_api(conn, ...)
    |
    |-- .api_fetch(conn$con, "interviews")
    |       build URL: conn$con$base_url + conn$con$endpoints[["interviews"]]
    |       add query param: conn$con$uid_param = paste(conn$con$creel_uids, ",")
    |       add auth header (bearer or api_key or none)
    |       httr2::req_perform() -> resp_body_json(simplifyVector=TRUE)
    |       return as.data.frame (API field names still intact)
    |
    |-- .rename_to_canonical(df, conn$schema, rename_map)
    |       looks up each canonical name -> schema field name -> API column name
    |       drops columns not in rename_map
    |       returns df with only canonical column names
    |
    |-- type coercions (.parse_api_date, as.numeric, as.character)
    |
    |-- validate_fetch_interviews(df)   [abort if columns missing or wrong type]
    |
    v
canonical data.frame — identical contract to CSV backend output
```

### Discovery path

```
User: list_creels(conn)
    |
    | S3 dispatch on "creel_connection_api"
    v
list_creels.creel_connection_api(conn, ...)
    |
    |-- .api_fetch_discovery(conn$con, endpoint_key = "creels")
    |       same auth logic as .api_fetch()
    |       omits uid_param (no creel selected yet)
    |       returns metadata data.frame: creel_uid, name, date_range, location, ...
    |
    v
metadata data.frame

User: search_creels(conn, name = "Lake X", year = 2024)
    |
    v
search_creels.creel_connection_api(conn, name, year, ...)
    |
    |-- list_creels(conn)   [or cache in conn$con if repeated calls are expensive]
    |-- filter by name/year/location predicates
    v
filtered metadata data.frame
```

---

## File Structure Changes

```
tidycreel.connect/R/
├── creel-connection.R          # unchanged
├── creel-connection-api.R      # add .api_fetch_discovery() helper (or extend .api_fetch)
├── creel-connect-yaml.R        # unchanged
├── fetch-loaders.R             # ADD: fetch_*.creel_connection_api for all 5 tables
├── fetch-validators.R          # unchanged — all validators reused as-is
├── print-methods.R             # unchanged
├── creel-check-driver.R        # unchanged
└── creel-discovery.R           # NEW: list_creels(), search_creels() generics + api methods
```

The 5 API fetch methods go inside `fetch-loaders.R` immediately after their corresponding CSV methods. This keeps the three dispatch targets for each generic in one place, mirroring how the SQL Server stubs are already placed.

`creel-discovery.R` is a new file because discovery functions are not fetch functions — they operate before a `creel_connection_api` is fully configured (no `creel_uids` filter applied), and they return metadata rather than survey data.

---

## Architectural Patterns

### Pattern 1: Backend-agnostic output contract

**What:** Every `fetch_*()` method, regardless of backend, returns a data.frame with the same canonical column names, types, and ordering. The `validate_fetch_*()` functions enforce this contract.

**When to use:** All 5 new API methods must follow this. The API method is "correct" when `all.equal(fetch_interviews(api_conn), fetch_interviews(csv_conn))` is TRUE for equivalent data.

**Example:** Reuse the exact same `rename_map` constant that the CSV method uses. If the API uses a different field name for the same concept, that mapping lives in the `creel_schema` object, not in the method body.

### Pattern 2: creel_schema as the single source of column name truth

**What:** The `creel_schema` object (`conn$schema`) stores the mapping from canonical names to backend-specific field names. The `rename_map` in each fetch method uses schema field keys (e.g., `"date_col"`, `"catch_col"`) — not literal API column names.

**When to use:** Always. Never hard-code API field names inside a fetch method. If the API field name for `date` changes between API versions, only the `creel_schema` definition changes, not the fetch methods.

**Implication for API methods:** If the UNL/NGPC API uses field names that differ from what the CSV schema currently defines, add new schema field keys (e.g., `"api_date_col"`) rather than branching inside the method. Alternatively, if the API field names exactly match the CSV field names in the schema, the rename maps are identical and no schema changes are needed.

### Pattern 3: Fail-fast validation after every backend

**What:** `validate_fetch_*()` is called at the end of every method, after rename and coerce. It aborts with a structured error listing all failures at once.

**When to use:** All 5 API methods must call the validator exactly as the CSV methods do. Do not add API-specific validators — the output contract is the same.

### Pattern 4: Internal helpers do not depend on creel_connection

**What:** `.api_fetch()` takes `con_info` (the `$con` list element), not the full `conn` object. `.rename_to_canonical()` takes a schema, not a connection. This keeps helpers testable without constructing a full connection object.

**When to use:** Any new internal helper should accept the minimum required data, not the whole `conn`. For `.api_fetch_discovery()`, pass `conn$con` — same as `.api_fetch()`.

---

## Anti-Patterns

### Anti-Pattern 1: Renaming inside .api_fetch()

**What people do:** Add a `rename_map` parameter to `.api_fetch()` and do the column rename inside the HTTP helper, so each method body is shorter.

**Why it's wrong:** `.api_fetch()` is field-agnostic by design. Adding rename logic couples it to the schema and to per-endpoint field knowledge. It also prevents using `.api_fetch()` for discovery endpoints that have different (or no) canonical mappings.

**Do this instead:** Keep `.api_fetch()` returning raw API field names. Each `fetch_*.creel_connection_api` method owns its rename map.

### Anti-Pattern 2: Standalone discovery functions that bypass dispatch

**What people do:** Export `list_creels(base_url, auth)` and `search_creels(base_url, auth, ...)` as ordinary functions, not generics.

**Why it's wrong:** Duplicates auth-building logic. Breaks the mental model — users already have a `conn` object with auth embedded; requiring them to re-supply `base_url` and `auth` separately is redundant and error-prone. Also prevents CSV-connection methods from giving a clean "not supported" error.

**Do this instead:** `UseMethod("list_creels")` dispatched on the connection object.

### Anti-Pattern 3: Hard-coding API field names in fetch methods

**What people do:** Write `rename_map <- c(date = "SurveyDate", ...)` with the literal API column name instead of going through the schema.

**Why it's wrong:** When the API version changes or a different agency deploys the same software with different field names, every fetch method body must be edited. The `creel_schema` object exists precisely to isolate field-name variation.

**Do this instead:** `rename_map <- c(date = "date_col", ...)` and let `.rename_to_canonical()` look up `schema[["date_col"]]` to get the API-side name.

### Anti-Pattern 4: Adding discovery endpoint to the `endpoints` list in creel_connect_api()

**What people do:** Add `"creels"` to `.default_api_endpoints()` and pass `creel_uids` to the discovery call.

**Why it's wrong:** The discovery endpoint is not a per-creel data endpoint. It does not take `uid_param`. Including it in `endpoints` implies it participates in the UID-filtered query pattern, which it does not. It also means users who override endpoints in `creel_connect_api()` would need to override the discovery endpoint too.

**Do this instead:** Treat the discovery endpoint as a separate concern. Store it in `conn$con` only if the API requires a custom path (default: a sensible convention). The `.api_fetch_discovery()` helper builds the URL from `conn$con$base_url` directly, without `uid_param`.

---

## Integration Points

### Existing components reused unchanged

| Component | Reused by | Notes |
|-----------|-----------|-------|
| `.api_fetch(conn$con, key)` | All 5 `fetch_*.creel_connection_api` methods | Only date-parsing and rename differ |
| `.parse_api_date()` | All 5 API methods that have a date column | Use instead of `as.Date(..., tryFormats)` |
| `.rename_to_canonical(df, schema, map)` | All 5 API methods | Identical call to CSV methods |
| `validate_fetch_*(df)` | All 5 API methods | Called identically; returns same errors |
| `new_creel_connection()` | Not changed by this work | Constructor already handles API subclass |

### New internal helper needed

`.api_fetch_discovery(con_info, endpoint)` — like `.api_fetch()` but without `uid_param` query parameter. Simplest implementation: extract the auth-building block from `.api_fetch()` into a shared `.build_authed_request(req, auth)` helper, then have both `.api_fetch()` and `.api_fetch_discovery()` call it. This eliminates the only auth logic duplication risk.

### Boundary: creel_connection_api -> creel_schema

The `creel_schema` object on the connection carries the column name mapping. The API methods read `conn$schema` exactly as CSV methods do. No schema changes are required unless the UNL/NGPC API uses field names not currently represented by any schema key (e.g., if the API returns `"SurveyDate"` but the schema only has `"date_col"` mapped to `"Date"`). Verify actual API response field names against schema keys before finalizing rename maps.

### Boundary: tidycreel.connect -> tidycreel (parent package)

The output of `fetch_*.creel_connection_api` feeds `tidycreel::add_interviews()`, `add_counts()`, etc. These functions validate their input independently. The API methods produce the same canonical output as CSV methods, so no parent package changes are needed.

---

## Sources

All findings based on direct analysis of the tidycreel.connect codebase:
- `tidycreel.connect/R/creel-connection-api.R` — constructor, `.api_fetch()`, auth validation, `.parse_api_date()`
- `tidycreel.connect/R/fetch-loaders.R` — generics, CSV methods, SQL Server stubs, `.rename_to_canonical()`
- `tidycreel.connect/R/fetch-validators.R` — `validate_fetch_*()` functions, `.validate_fetch()` helper
- `tidycreel.connect/R/creel-connection.R` — `new_creel_connection()`, class hierarchy
- `tidycreel.connect/R/creel-connect-yaml.R` — YAML constructor, backend branching pattern
- `tidycreel.connect/R/print-methods.R` — `format.creel_connection()`, backend branching pattern
- `.planning/research/ARCHITECTURE.md` (v1.6.0) — prior S3 class patterns and naming conventions
