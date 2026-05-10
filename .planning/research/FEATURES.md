# Feature Research

**Domain:** REST API fetch dispatch and creel discovery — tidycreel.connect API backend
**Researched:** 2026-05-09
**Confidence:** HIGH (all findings derived directly from NGPC reference implementation source code and existing tidycreel.connect source)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `fetch_interviews.creel_connection_api` | Parity with CSV backend; primary data ingestion path for all estimation workflows | MEDIUM | Map `ii_UID` → `interview_uid`, `cd_Date` → `date` (ISO datetime string via `.parse_api_date()`), `ii_TimeFishedHours + ii_TimeFishedMinutes/60` → `effort`, `ii_TripType` → `trip_status`. Effort requires field arithmetic — only fetch method that is not a pure rename. Reuse `.api_fetch()` and `validate_fetch_interviews()`. |
| `fetch_counts.creel_connection_api` | Parity with CSV backend; required for effort estimation and all instantaneous estimators | MEDIUM | Map `cd_Date` → `date`. The exact API field name for angler count is unconfirmed: the reference code returns `count.data` without a column selection. Must verify field name against live API or document the schema `count_col` lookup key as the resolution path. |
| `fetch_catch.creel_connection_api` | Parity with CSV backend; required for harvest and CPUE estimates | LOW | Reference: `select(ii_UID, ir_Species, Num, CatchType)`. Map `ii_UID` → `interview_uid`, `ir_Species` → `species` (coerce to character — NGPC stores integer species codes), `Num` → `catch_count`, `CatchType` → `catch_type`. See gap note on `catch_uid` below. |
| `fetch_harvest_lengths.creel_connection_api` | Parity with CSV backend; length-frequency data for size structure | LOW | Reference: `select(UID=iiUID, ih_Number, ih_Species, ihl_Length)`. Critical: field is `iiUID` not `ii_UID` (no underscore between `ii` and `UID`). Map `iiUID` → `interview_uid`, `ih_Species` → `species` (character), `ihl_Length` → `length_mm`. Inject constant `length_type = "harvest"` because the API returns no type flag. |
| `fetch_release_lengths.creel_connection_api` | Parity with CSV backend; release data for catch-and-release analysis | LOW | Reference: `select(UID=iiUID, ir_Species, ir_LengthGroup, ir_Count)`. Map `iiUID` → `interview_uid`, `ir_Species` → `species` (character), `ir_LengthGroup` → `length_mm`. Inject constant `length_type = "release"`. Note: `ir_Count` is a pre-aggregated count per length bin with no CSV equivalent — see gap note below. |
| `list_creels()` generic + `list_creels.creel_connection_api` | Discovery — users must find available creel UIDs before constructing a connection | LOW | `GET {base_url}/AnalysisData/GetAvailableCreels` with no UID params. Map `Creel_UID` → `creel_uid` (apply `toupper()` — API returns lowercase GUIDs; reference code explicitly corrects this), `Creel_Title` → `title`, `Creel_Description` → `description`, `Creel_Active` → `active` (logical). Returns a plain `data.frame`. |
| `search_creels()` generic + `search_creels.creel_connection_api` | Discovery — normal workflow for finding surveys by waterbody or survey name | LOW | `GET {base_url}/AnalysisData/GetMatchingCreels?searchText={text}`. Same return shape as `list_creels()`. Single `text` argument (character scalar); partial-match semantics handled server-side by the NGPC API. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| `data_complete` column in discovery functions | Lets analysts filter to surveys with finalized data before running estimates; prevents running analyses on in-progress surveys | LOW | `Creel_DataComplete` is returned by `GetAvailableCreels` and included in the reference `api_getAllCreels()` select. Map to `data_complete` (logical). Expose it so users can do `dplyr::filter(data_complete)` before building a connection. |
| Unified `effort` arithmetic inside `fetch_interviews` | Reference code returns `ii_TimeFishedHours` and `ii_TimeFishedMinutes` as separate fields; all tidycreel estimators expect `effort` in decimal hours | MEDIUM | Compute `effort = ii_TimeFishedHours + ii_TimeFishedMinutes / 60` inside the method. This is the only API fetch that involves field arithmetic rather than a pure rename. The CSV backend receives pre-computed effort, so this difference is backend-specific. |
| Synthesized `length_type` constant columns | API encodes catch type implicitly by endpoint called; canonical schema requires `length_type` column; validator will abort without it | LOW | Inject `length_type = "harvest"` for harvest lengths and `length_type = "release"` for release lengths as a constant character column post-rename, before validation. This keeps the canonical contract identical between CSV and API backends. |
| `comments` in discovery return | `Creel_Comments` is used by NGPC staff to record survey notes, caveats, and analyst contact info | LOW | Include as `comments` in `list_creels()` / `search_creels()` return shape. Treat as optional — may be `NA` for many surveys. Not in the validated canonical schema; just pass through. |
| `toupper()` normalization of `Creel_UID` | Reference code explicitly notes that the NGPC API returns GUIDs in lowercase, which breaks matching against uppercase UIDs stored in spreadsheets and databases | LOW | Apply `toupper()` to `creel_uid` in both discovery functions. The reference code does this manually after fetching; tidycreel.connect should do it transparently. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Auto-discovery on `creel_connect_api()` | Tempting to call `list_creels()` inside the constructor to validate UIDs at connection time | Adds a network round-trip at construction time, couples object creation to connectivity, complicates offline testing and vignette examples | Keep constructor offline. Let users call `list_creels()` explicitly before building a connection. |
| Automatic species code lookup join | `codes/GetSpeciesCodes` endpoint exists; tempting to auto-join human-readable names on every `fetch_catch()` call | Adds a second network call per fetch, couples fetch to a non-analysis endpoint, species codes are jurisdiction-specific and not part of the canonical schema | Keep species as character codes after `as.character()` coercion. Users who need labels fetch the lookup table separately. |
| `active_only` filter argument on `list_creels()` | Reference code filters `Creel_Active == TRUE` before building API setup objects | Removes discoverability of completed surveys that analysts need for retrospective analysis; filtering is trivially done by the user | Return all records unfiltered. Users filter with `dplyr::filter(active)` or base R subsetting. |
| Internal fetch result caching | Analysts sometimes want repeated calls to return the same data without re-fetching | Hidden state; stale data silently returned if a survey is updated mid-session; complex invalidation logic | Users assign fetch results to a variable. No internal cache. |
| Pagination arguments on discovery functions | General REST API design practice to add `limit` / `offset` | The NGPC `GetAvailableCreels` endpoint has no pagination; adding these arguments implies a capability that does not exist server-side | Return all records the API returns. Add pagination arguments if and when a future API version supports them. |
| Row-expansion of `ir_Count` in release lengths | The canonical `length_mm` schema implies one row per fish (as in harvest lengths); release lengths have one row per length group with a count | Silently exploding rows to match harvest structure changes data volume non-obviously and creates synthetic rows not present in the API response | Document the structural difference. Either accept the aggregated form (and update the validator expectation) or expand with a `cli_warn()` explaining that rows have been expanded. Do not silently expand. |

## Feature Dependencies

```
creel_connect_api() [constructor — already built]
    └──required by──> fetch_interviews.creel_connection_api
    └──required by──> fetch_counts.creel_connection_api
    └──required by──> fetch_catch.creel_connection_api
    └──required by──> fetch_harvest_lengths.creel_connection_api
    └──required by──> fetch_release_lengths.creel_connection_api

.api_fetch() [HTTP helper — already built in creel-connection-api.R]
    └──required by──> all five fetch_*.creel_connection_api methods

.parse_api_date() [date coercion helper — already built in creel-connection-api.R]
    └──required by──> fetch_interviews.creel_connection_api
    └──required by──> fetch_counts.creel_connection_api

validate_fetch_*() [validators — already built in fetch-validators.R]
    └──required by──> all five fetch_*.creel_connection_api methods

list_creels() [new generic]
    └──required by──> list_creels.creel_connection_api

search_creels() [new generic]
    └──required by──> search_creels.creel_connection_api

list_creels.creel_connection_api
    ──enhances──> creel_connect_api() [helps users find UIDs to pass as creel_uids]

search_creels.creel_connection_api
    ──enhances──> creel_connect_api() [same; text-filtered discovery]
```

### Dependency Notes

- **All five `fetch_*` methods require `.api_fetch()`:** The HTTP GET helper is already implemented and handles URL construction, UID parameter encoding, and all three auth modes. Each fetch method calls `.api_fetch(conn$con, "endpoint_key")` and receives a plain `data.frame`.
- **`fetch_interviews` and `fetch_counts` require `.parse_api_date()`:** Dates from the API arrive as ISO 8601 datetime strings (`"YYYY-MM-DDTHH:MM:SS"`); `.parse_api_date()` handles both that format and bare `"YYYY-MM-DD"` strings.
- **`fetch_harvest_lengths` and `fetch_release_lengths` require synthesized `length_type`:** Neither API endpoint returns a `length_type` column. The constant must be injected after the rename step, before `validate_fetch_*()` runs, because the validators require the column.
- **`list_creels` and `search_creels` are independent of all five fetch methods:** They call a different endpoint with no UID param and return discovery metadata, not analysis data. They can be developed and tested independently of the fetch dispatch work.
- **`fetch_interviews` has a unique arithmetic dependency:** The effort calculation `ii_TimeFishedHours + ii_TimeFishedMinutes / 60` must happen before `validate_fetch_interviews()` checks for a numeric `effort` column. The raw API fields should not appear in the returned data frame.

## MVP Definition

### Launch With (v1 — this milestone)

Minimum needed to make `creel_connection_api` fully functional end-to-end.

- [ ] `fetch_interviews.creel_connection_api` — without this the API backend produces no usable data; it is the entry point for all estimation workflows
- [ ] `fetch_counts.creel_connection_api` — required by `creel_n_effort()` and all instantaneous estimators
- [ ] `fetch_catch.creel_connection_api` — required for any harvest or CPUE estimate
- [ ] `fetch_harvest_lengths.creel_connection_api` — required for length-frequency workflows; constant `length_type` injection is part of this method
- [ ] `fetch_release_lengths.creel_connection_api` — same as above for releases
- [ ] `list_creels()` generic + `list_creels.creel_connection_api` — users cannot construct a connection without knowing valid UIDs; discovery is a prerequisite
- [ ] `search_creels()` generic + `search_creels.creel_connection_api` — text search is the normal operational workflow for finding surveys by waterbody name

### Add After Validation (v1.x)

- [ ] `list_creels.creel_connection_csv` informative stub — makes the generic safe to call on a CSV connection with a clear `cli_abort()` rather than a dispatch miss error
- [ ] `search_creels.creel_connection_csv` stub — same reason
- [ ] `list_creels.creel_connection_sqlserver` stub — parallel to above for SQL Server backend

### Future Consideration (v2+)

- [ ] `fetch_*` methods for `creel_connection_sqlserver` — Phase 69 stub territory; not this milestone
- [ ] Code table accessors (`fetch_species_codes()`, `fetch_waterbody_codes()`) — the `codes/` endpoints exist in the NGPC API but tidycreel does not consume code tables internally; useful only for label-joining workflows outside the package

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `fetch_interviews.creel_connection_api` | HIGH | MEDIUM (effort arithmetic, datetime parsing) | P1 |
| `fetch_counts.creel_connection_api` | HIGH | MEDIUM (angler count field name unconfirmed — needs live API verification) | P1 |
| `fetch_catch.creel_connection_api` | HIGH | LOW (all field names confirmed from reference) | P1 |
| `fetch_harvest_lengths.creel_connection_api` | HIGH | LOW (field names confirmed; `iiUID` asymmetry documented; constant injection simple) | P1 |
| `fetch_release_lengths.creel_connection_api` | HIGH | LOW (same as harvest; `ir_Count` aggregation gap documented) | P1 |
| `list_creels()` generic + API method | HIGH | LOW (no UID param; 5-column rename; `toupper()` fix) | P1 |
| `search_creels()` generic + API method | HIGH | LOW (same structure as `list_creels`; one extra `text` argument) | P1 |
| `data_complete` in discovery return | MEDIUM | LOW (already returned by API; include in rename map) | P2 |
| `comments` in discovery return | LOW | LOW (passthrough; NA-tolerant) | P2 |
| CSV / SQL Server stubs for list/search generics | LOW | LOW | P2 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Canonical Column Mapping Reference

Derived directly from `CreelApiHelper.R` (v3.0, 2018-05-04) and cross-checked against `CreelDataAccess.R` (v3.2.1, 2021-05-11).

### `fetch_interviews` — endpoint: `AnalysisData/GetInterviewData`

| API Field | Canonical Name | Type | Notes |
|-----------|----------------|------|-------|
| `ii_UID` | `interview_uid` | any | GUID string |
| `cd_Date` | `date` | Date | ISO datetime string; use `.parse_api_date()` |
| `ii_TimeFishedHours + ii_TimeFishedMinutes / 60` | `effort` | numeric | Arithmetic — no direct one-to-one field; both raw fields are dropped from output |
| `ii_TripType` | `trip_status` | character | Integer code from API; coerce to character |

### `fetch_counts` — endpoint: `AnalysisData/GetCountData`

| API Field | Canonical Name | Type | Notes |
|-----------|----------------|------|-------|
| `cd_Date` | `date` | Date | Use `.parse_api_date()` |
| TBD — needs live API inspection | `angler_count` | numeric | Reference code returns `count.data` without a column selection; exact field name unconfirmed |

### `fetch_catch` — endpoint: `AnalysisData/GetCatchData`

| API Field | Canonical Name | Type | Notes |
|-----------|----------------|------|-------|
| `ii_UID` | `interview_uid` | any | |
| `ir_Species` | `species` | character | Integer code in NGPC; `as.character()` required |
| `Num` | `catch_count` | numeric | |
| `CatchType` | `catch_type` | character | `"H"` or `"R"` in NGPC data |
| TBD | `catch_uid` | any | Validator requires this column; reference code does not select a per-catch UID — needs live API inspection to confirm whether one exists |

### `fetch_harvest_lengths` — endpoint: `AnalysisData/GetHarvestLengthData`

| API Field | Canonical Name | Type | Notes |
|-----------|----------------|------|-------|
| `iiUID` | `interview_uid` | any | **No underscore** between `ii` and `UID` — differs from interview endpoint's `ii_UID` |
| `ih_Species` | `species` | character | `as.character()` required |
| `ihl_Length` | `length_mm` | numeric | Raw mm measurement |
| (synthesized constant) | `length_type` | character | `"harvest"` — not present in API response |
| TBD | `length_uid` | any | Validator requires this column; reference code does not select a per-row length UID |

### `fetch_release_lengths` — endpoint: `AnalysisData/GetReleaseLengthData`

| API Field | Canonical Name | Type | Notes |
|-----------|----------------|------|-------|
| `iiUID` | `interview_uid` | any | Same asymmetry as harvest lengths |
| `ir_Species` | `species` | character | `as.character()` required |
| `ir_LengthGroup` | `length_mm` | numeric | Size bin, not raw measurement — maps to same canonical column |
| `ir_Count` | (no canonical equivalent) | numeric | Pre-aggregated count of fish per length group; CSV backend has one row per fish — structural mismatch must be resolved |
| (synthesized constant) | `length_type` | character | `"release"` — not present in API response |
| TBD | `length_uid` | any | Same gap as harvest lengths |

### `list_creels` / `search_creels` — endpoints: `AnalysisData/GetAvailableCreels` and `AnalysisData/GetMatchingCreels`

| API Field | Canonical Name | Type | Notes |
|-----------|----------------|------|-------|
| `Creel_UID` | `creel_uid` | character | API returns lowercase GUIDs; apply `toupper()` |
| `Creel_Title` | `title` | character | |
| `Creel_Description` | `description` | character | May be `NA` |
| `Creel_Active` | `active` | logical | JSON parse may return logical or integer; coerce with `as.logical()` |
| `Creel_DataComplete` | `data_complete` | logical | Same coercion as `active` |
| `Creel_Comments` | `comments` | character | Optional passthrough; many surveys will have `NA` |

`search_creels` takes one additional argument: `text` (non-empty character scalar), passed as `?searchText={text}`.

Both functions return a plain `data.frame`, one row per creel, with the six columns above.

## Open Implementation Gaps

These unknowns require resolution during implementation.

**Gap 1 — `angler_count` field name in GetCountData:** The reference code calls `fromJSON(myApis$data$counts)` with no column selection — it returns the entire count table. The canonical field for angler count is unknown without inspecting a live API response or the SQL view definition (`vwCombinedR_CountData`). The implementation should use the connection's `schema$count_col` as the lookup key (consistent with the CSV backend approach) and include clear documentation of the expected API field name once confirmed.

**Gap 2 — `catch_uid` absence:** The `validate_fetch_catch()` validator requires a `catch_uid` column (type `"any"`). The reference code `select(ii_UID, ir_Species, Num, CatchType)` does not include a per-catch-row UID. Options in priority order: (a) inspect live API to confirm whether a catch UID field exists but was not selected in the reference code; (b) if no UID exists, synthesize as `paste0(interview_uid, "_", seq_len(nrow(df)))` with a `cli_warn()` noting the synthesis; (c) update the validator to make `catch_uid` optional for the API backend.

**Gap 3 — `length_uid` absence:** Same issue as `catch_uid`, affecting both `fetch_harvest_lengths` and `fetch_release_lengths`. Same resolution priority.

**Gap 4 — `ir_Count` aggregation in release lengths:** The CSV backend's `validate_fetch_release_lengths()` validates `length_mm` and `length_type` but says nothing about `ir_Count`. The API returns one row per length group with a count, while harvest lengths have one row per fish. Two acceptable resolutions: (a) accept the aggregated form as-is and document that release lengths from the API are aggregated (the downstream `add_lengths()` function must handle both forms); (b) expand rows by `ir_Count` before validation with a `cli_warn()`. Do not silently expand. This gap requires a decision before implementation begins.

## Competitor Analysis

No direct competitors in the R package ecosystem for NGPC-specific creel REST API integration. The reference implementation is the prior art.

| Feature | Reference Implementation (`CreelApiHelper.R` v3.0) | tidycreel.connect (this milestone) |
|---------|-----------------------------------------------------|-------------------------------------|
| HTTP fetch | `jsonlite::fromJSON(url)` — no auth, no error handling, crashes on HTTP errors | `httr2` with bearer/api_key auth, HTTP error propagation via `req_perform()` |
| Column naming | Raw API field names returned directly (`ii_UID`, `Num`, `iiUID`) | Canonical tidycreel names (`interview_uid`, `catch_count`) |
| Type coercion | Implicit or missing (species codes left as integer in some paths) | Explicit per-column coercion with `cli_abort()` validation |
| Discovery | `api_getAllCreels()` returns raw data frame with PascalCase field names | `list_creels()` returns renamed canonical data frame with `toupper()` fix applied |
| Search | `api_searchForCreels(apiBase, text)` — API base passed as first argument | `search_creels(conn, text)` — connection-scoped, auth-aware |
| Error messages | None — R errors or silent data corruption | `cli_abort()` with actionable messages following tidycreel conventions |
| Date parsing | `as.Date(ymd_hms(cd_Date))` via lubridate | `.parse_api_date()` handles both ISO datetime and bare date formats without lubridate dependency |

## Sources

- `/Users/cchizinski2/Desktop/creel_test_TEMP/creel/CreelApiHelper.R` — NGPC reference implementation, v3.0 (modified 2018-05-04). PRIMARY source for all API field names, endpoint paths, and discovery function shapes.
- `/Users/cchizinski2/Desktop/creel_test_TEMP/creel/CreelDataAccess.R` — NGPC data access layer, v3.2.1 (modified 2021-05-11). Confirms field names via SQL view column selections and API path for the SQL Server backend.
- `/Users/cchizinski2/Dev/tidycreel/tidycreel.connect/R/fetch-loaders.R` — Existing CSV backend. Defines canonical column names, rename_map pattern, and type coercion conventions that API methods must match.
- `/Users/cchizinski2/Dev/tidycreel/tidycreel.connect/R/fetch-validators.R` — Existing validation contracts. Defines required columns and required types that all `fetch_*` methods must satisfy.
- `/Users/cchizinski2/Dev/tidycreel/tidycreel.connect/R/creel-connection-api.R` — Existing API constructor. Provides `.api_fetch()`, `.parse_api_date()`, `.default_api_endpoints()`, and auth validation that fetch dispatch methods build on.

---
*Feature research for: tidycreel.connect REST API fetch dispatch and creel discovery*
*Researched: 2026-05-09*
