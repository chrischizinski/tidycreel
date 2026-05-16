# Pitfalls Research: REST API Fetch Dispatch and Real-Data Integration

**Domain:** Adding REST API fetch methods to an existing R S3 dispatch system (tidycreel.connect) and running integration tests against real archived NGPC creel survey data (Calamus 2016 bus-route)
**Researched:** 2026-05-09
**Confidence:** HIGH — all pitfalls are grounded in reading the actual codebase, real CSV data, and NGPC legacy helper scripts

---

## Critical Pitfalls

### API-1: NGPC JSON Field Names Do Not Match Canonical Names or CSV Names

**What goes wrong:**
The NGPC API returns fields with the `ii_`, `cd_`, `ir_` prefix convention from the SQL view layer: `ii_UID`, `cd_Date`, `ir_Species`, `Num`, `CatchType`. The CSV implementation expects schema-mediated names, and the schema field mapping (`creel_schema`) uses keys like `interview_uid_col`, `date_col`, `species_col`, `catch_count_col`, `catch_type_col`. The API field names match neither the canonical names nor the schema config keys, so `.rename_to_canonical()` will produce a 0-column data frame and validation will immediately abort.

**Why it happens:**
The CSV path works because users configure the schema with their own column names (e.g., `date_col = "date"`). The API path has fixed server-side field names that users cannot configure. Without a hardcoded `api_rename_map` that translates `ii_UID` → `interview_uid`, `cd_Date` → `date`, `ir_Species` → `species`, `Num` → `catch_count`, `CatchType` → `catch_type`, the rename step produces an empty result.

**Confirmed mapping from `CreelDataAccess.R`:**

| API JSON field | Canonical name | fetch target |
|---|---|---|
| `ii_UID` | `interview_uid` | interviews, catch, lengths |
| `cd_Date` | `date` | interviews, counts |
| `ii_NumberAnglers` | `angler_count` | counts (via interview endpoint) |
| `ir_Species` | `species` | catch |
| `Num` | `catch_count` | catch |
| `CatchType` | `catch_type` | catch |
| `ihl_Length` | `length_mm` | harvest lengths |
| `ih_Species` | `species` | harvest lengths |
| `iiUID` | `interview_uid` | harvest/release lengths (note: no underscore) |

**Warning signs:** `fetch_interviews.creel_connection_api()` returns 0 rows without error; validation aborts with "column missing" for every canonical column name.

**Prevention:** The API `fetch_*` methods must use a hardcoded `api_rename_map` keyed directly on JSON field names, not on schema field keys. Do not route through `.rename_to_canonical()` — that function resolves field names through `schema[[field]]`, but the API field names are fixed server-side constants, not schema-configurable.

**Phase to address:** API fetch dispatch implementation phase, day one.

---

### API-2: ISO-8601 Datetime Strings Fail the Current Date Parser

**What goes wrong:**
`as.Date(x, tryFormats = c("%Y-%m-%d", "%m/%d/%Y"))` correctly parses date-only strings. But the NGPC API returns dates as `"2016-04-02T00:00:00"` (ISO-8601 datetime). The existing `.parse_api_date()` helper already handles this via `strptime(x[na_mask], "%Y-%m-%dT%H:%M:%S")`, but only if it is actually called. If the API fetch method reuses the CSV coercion pattern (`as.Date(df$date, tryFormats = ...)`) directly instead of calling `.parse_api_date()`, all dates become `NA` with no warning — `as.Date` on an unrecognized format returns NA silently when `tryFormats` exhausts.

**Confirmed by:** `CreelDataAccess.R` line 580 uses `as.Date(ymd_hms(start_end.dates))` specifically because the API returns datetimes, not dates.

**Warning signs:** Every `date` column value is `NA` after fetch; validation passes because `NA` has class `Date` after `as.Date(NA)`.

**Prevention:**
- The API `fetch_*` methods must call `.parse_api_date()` for date columns, not reuse the CSV `as.Date(..., tryFormats = ...)` pattern.
- Add a post-coercion check: if `sum(is.na(df$date)) == nrow(df) && nrow(df) > 0`, abort with a diagnostic showing one raw value before parsing.

**Phase to address:** API fetch dispatch implementation phase. Unit test with `"2016-04-02T00:00:00"` as input is the acceptance criterion.

---

### API-3: Empty JSON Array Returns 0-Row data.frame, Not Empty List — Guard is Wrong

**What goes wrong:**
The current `.api_fetch()` empty-response guard is:

```r
if (is.null(result) || (is.list(result) && length(result) == 0L)) {
  return(data.frame())
}
```

`httr2::resp_body_json(resp, simplifyVector = TRUE)` on an empty JSON array `[]` returns a `data.frame` with 0 rows and 0 columns — not a zero-length list. The guard checks `is.list(result) && length(result) == 0L`, but a 0-row data.frame is a list of 0-length vectors with `length(result) == 0L` only when it has 0 columns. A 0-row data.frame with named columns (which `simplifyVector` may produce from the schema) has `length() > 0`. The guard may either miss the empty case or pass through a structurally broken frame to downstream rename logic.

**Warning signs:** `fetch_harvest_lengths.creel_connection_api()` returns a data.frame with column names but 0 rows and no canonical columns; or it returns the guarded `data.frame()` (0 rows, 0 columns) which then fails validation because required columns are missing.

**Prevention:**
Replace the empty-response guard with:
```r
if (is.null(result) || (is.data.frame(result) && nrow(result) == 0L) ||
    (is.list(result) && !is.data.frame(result) && length(result) == 0L)) {
  return(data.frame())  # or a 0-row frame with the expected canonical columns
}
```
A better approach is to let validation handle the empty case: return a 0-row data.frame with correctly-named and correctly-typed canonical columns so the validator passes and the caller receives a structurally sound empty frame.

**Phase to address:** API fetch dispatch implementation phase. Requires an explicit test: mock an API response of `[]` and assert the return value has the expected column names and 0 rows.

---

### API-4: `simplifyVector = TRUE` Flattens Nested JSON Into Surprising Shapes

**What goes wrong:**
`httr2::resp_body_json(resp, simplifyVector = TRUE)` is equivalent to `jsonlite::fromJSON(simplifyVector = TRUE)`. When the top-level JSON is an array of objects with consistent scalar fields, this produces a nice data.frame. But if any field contains a nested array or object (e.g., a supplemental data field, a NULL value in one row), `simplifyVector` either promotes the column to a list-column or drops the row. A list-column in a data.frame will cause `names(df)` to include that column, but `as.numeric(df$catch_count)` on a list-column will silently return NAs for every element.

**Why it happens:**
The NGPC API fields include `NULL` values for refused/incomplete interviews (e.g., `catch_count` may be NULL for refused rows). jsonlite converts NULL array elements to NA in a numeric column, which is correct — but if mixed NULL and numeric types appear within a single column, `simplifyVector` sometimes produces a list-column instead.

**Warning signs:** `is.list(df$catch_count)` is TRUE after the API fetch; `as.numeric()` produces all-NA; validator reports type mismatch for catch_count.

**Prevention:**
After `as.data.frame(result)`, check each target column for list-column status before coercion:
```r
if (is.list(df$catch_count)) df$catch_count <- unlist(df$catch_count, use.names = FALSE)
```
This is safer than assuming scalar columns are always scalar.

**Phase to address:** API fetch dispatch implementation phase.

---

### API-5: `iiUID` vs `ii_UID` Field Name Inconsistency Across NGPC Endpoints

**What goes wrong:**
The NGPC harvest length and release length endpoints return `iiUID` (no underscore between `ii` and `UID`), while the interview endpoint returns `ii_UID` (with underscore). This is confirmed in `CreelDataAccess.R` lines 741 and 751: `select(UID = iiUID, ...)`. If the API rename map for `fetch_harvest_lengths` uses `"ii_UID"` (matching the interviews endpoint), the interview_uid column will be missing — silently, because `.rename_to_canonical()` drops columns not found in the frame.

**Warning signs:** `fetch_harvest_lengths.creel_connection_api()` returns a frame with no `interview_uid` column; validator aborts with "interview_uid: column missing".

**Prevention:**
Define separate, endpoint-specific API rename maps. Do not share a single global map across all `fetch_*` methods. Document the `iiUID` vs `ii_UID` inconsistency with an inline comment in the code.

**Phase to address:** API fetch dispatch implementation phase. Requires reading the live API response for each endpoint to confirm field names before implementation.

---

## Integration Testing Pitfalls

### INT-1: Calamus 2016 Interviews Are Intentionally Duplicated — Do Not Deduplicate

**What goes wrong:**
The Calamus 2016 interview CSV has each `interview_uid` appearing 2x or 4x (verified: 657 UIDs appear 4x, 41 UIDs appear 2x, 3 UIDs appear 1x). This is not a data error. The bus-route design produces one interview record per count period, and multi-count-period routes create multiple rows per interview. Deduplicating on `interview_uid` before passing to `add_interviews()` silently discards valid observations and produces understated effort estimates. Conversely, if the integration script naively passes the raw CSV to functions that do not expect multiple rows per UID, downstream aggregation will be wrong.

**Warning signs:** Effort estimates are exactly 50% or 25% of expected reference values; interview N matches number of unique UIDs rather than total rows.

**Prevention:**
- The integration script must not call `dplyr::distinct(interview_uid)` or any deduplication on the interview data.
- Assert in the integration script: `nrow(interviews) > length(unique(interviews$interview_uid))` (bus-route data must have duplicates).
- Document at the top of the script: "Row count exceeds unique interview count — expected for bus-route data."

**Phase to address:** Integration script design phase, before any analysis code is written.

---

### INT-2: Catch Type "caught" Is a Third Value Beyond "harvested"/"released"

**What goes wrong:**
The Calamus 2016 catch CSV has three catch_type values: `"caught"`, `"harvested"`, `"released"`. The `fetch-validators.R` validator only checks that `catch_type` is character — it does not validate the value set. Downstream estimators that filter `catch_type == "harvested"` will silently miss catch rows where `catch_type == "caught"` (which may represent pre-standardization data where harvest vs release was not distinguished). An integration script that uses only `"harvested"` in filters will undercount harvest.

**Warning signs:** Harvest estimates are lower than reference values by exactly the number of `catch_type == "caught"` rows; no validation error is raised.

**Prevention:**
- Before filtering, summarize the distinct catch_type values in the integration script and confirm they match expected values.
- Add a validation step: `stopifnot(all(catch$catch_type %in% c("harvested", "released", "caught")))` — fail fast on unexpected values.
- Decide and document in the script whether `"caught"` rows are treated as harvest, released, or excluded. Do not silently exclude them.

**Phase to address:** Integration script implementation phase.

---

### INT-3: Species Code 86 Is a Real Code, Not a Truncated 862

**What goes wrong:**
The Calamus 2016 catch CSV contains species code `86` alongside `862`. Reading column headers and sample rows confirms `86` appears with valid counts and catch types for specific interview UIDs that have no `862` rows — it is a distinct species code (likely yellow bass, Morone mississippiensis, NGPC code 86), not a truncated `862` (sauger). An integration script that replaces or drops `86` assuming it is corrupt data will silently eliminate valid catch records.

**Why it happens:**
Three-digit NGPC codes that happen to share a two-digit prefix cause visual confusion. `86` and `860`, `862` can look like truncation artifacts in a numeric column but are distinct species.

**Warning signs:** Species `86` rows are missing from catch totals; total catch counts differ from reference report values.

**Prevention:**
- Always coerce species to character before any comparison: `as.character(species)` is already done in `fetch_catch.creel_connection_csv()` (line 137 of `fetch-loaders.R`).
- In the integration script, print `sort(unique(catch$species))` early and verify the full list against the NGPC species code table before any filtering or aggregation.
- Never filter species using numeric comparison (`species > 800`) on data that contains valid 2-digit codes.

**Phase to address:** Integration script implementation phase.

---

### INT-4: Refused Interviews Have No Refused Flag in the Standardized CSV

**What goes wrong:**
The Calamus 2016 interview CSV has a `refused` column that is `FALSE` for every row (confirmed: 0 TRUE values). Refused interviews were either excluded upstream in the standardization pipeline, or the bus-route design did not generate refused-interview rows in this export. An integration script that applies a refused-filter `filter(refused == FALSE)` will silently have no effect (appearing to work) — but if the integration is later used with a survey that does include refused rows, the filter becomes necessary and its absence will corrupt estimates.

**Warning signs:** Filtering `refused == FALSE` does not change row count; no tests cover the refused-interview code path.

**Prevention:**
- Write the integration script's refused filter defensively: include `filter(!refused)` even when the test data has no refused rows, and add a comment documenting why.
- Add a test fixture that includes at least one refused row to exercise the filter path, even if the Calamus 2016 data does not have any.

**Phase to address:** Integration script implementation and test design phases.

---

### INT-5: Integration Script That Fetches Live API Data Is Not a Repeatable Test

**What goes wrong:**
An integration script that calls `creel_connect_api(base_url = "http://creelsurvey.unl.edu/api/", ...)` and fetches data in real time will fail whenever the NGPC server is unavailable, slow, or returns different data (e.g., if historical records are corrected). This makes the script useless in CI and unreliable for regression testing.

**Why it happens:**
Real-data integration scripts conflate "test against real data" with "test against live API". The correct approach is to record a known-good API response once and use it as a fixture.

**Warning signs:** Integration script has no `httr2` mocking or recorded fixture; it requires a live network connection to run.

**Prevention:**
- Use `httr2::with_mock_responses()` (httr2 >= 1.0.0) or record a fixture with `httptest2` to replay real API responses without live network access.
- Alternatively, store the Calamus 2016 API JSON responses as static fixture files and load them with `httr2::response_json()` in tests.
- The integration script for comparison against the reference report (Calamus 2016 standardized CSVs) should be a separate, offline-capable script that uses the CSV backend, not the API backend.

**Phase to address:** Integration test design phase.

---

### INT-6: S3 Dispatch Reaches Wrong Method When Subclass Is Not First in Class Vector

**What goes wrong:**
`new_creel_connection()` constructs the class vector as `c(subclass, "creel_connection")`, putting the subclass first. This is correct. But if any code path calls `class(conn) <- "creel_connection"` (stripping the subclass), or if `inherits(conn, "creel_connection_api")` is used instead of `is()` dispatch, a `fetch_interviews(conn)` call will dispatch to the `UseMethod` default, which typically errors. Silent wrong-method dispatch happens when `creel_connection_api` is not the first class and R finds `fetch_interviews.creel_connection` (if it exists) or produces "no applicable method" instead of the expected API method.

**Warning signs:** `fetch_interviews(api_conn)` errors with "no applicable method for 'fetch_interviews' applied to an object of class 'creel_connection'"; or silently dispatches to the CSV method and fails on `conn$con$interviews` which is NULL for API connections.

**Prevention:**
- Add a `stopifnot(inherits(conn, "creel_connection_api"))` assertion at the top of each `fetch_*.creel_connection_api` method.
- Write a test: `expect_s3_class(conn, "creel_connection_api")` and `expect_true("creel_connection_api" == class(conn)[[1]])`.

**Phase to address:** API fetch dispatch implementation phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|---|---|---|---|
| Reusing CSV `rename_to_canonical` for API fields by adding API names to `creel_schema` | Avoids new code path | Schema becomes a dump for two different naming conventions; user-facing schema docs become confusing | Never — API field names are fixed server-side constants, not user config |
| Hardcoding Calamus UID in integration script | Faster first test | Script becomes un-runnable if that UID is retired from the API | Never — parameterize the UID |
| Using `tryCatch(fromJSON(url))` instead of httr2 for quick API reads | Fewer dependencies | No retry, no timeout, no auth — breaks for any non-public API | Never in package code; acceptable in throwaway exploration scripts |
| Omitting `skip_if_offline()` from API tests | Simpler test setup | Tests fail in CI without network; maintainers waste time debugging connectivity | Never in `testthat` files; add the guard |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|---|---|---|
| NGPC API date fields | Parse with `as.Date(x, tryFormats = ...)` | Call `.parse_api_date(x)` which handles `"T00:00:00"` suffix |
| NGPC catch endpoint | Map `"Num"` → `catch_count` via schema field | Use hardcoded API rename map; schema keys do not resolve to `"Num"` |
| NGPC length endpoints | Use same rename map as interview endpoint | `iiUID` (no underscore) in length endpoints vs `ii_UID` in interview endpoint |
| Empty API response for lengths | Guard on `length(result) == 0` | Check `is.data.frame(result) && nrow(result) == 0` — `simplifyVector` returns 0-row frame, not 0-length list |
| Calamus 2016 multi-row interviews | Deduplicate on interview_uid | Pass all rows to `add_interviews()`; deduplication is not correct for bus-route data |
| Species code handling | Numeric comparison or filtering | Always coerce to character first; `86` and `862` are distinct valid codes |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|---|---|---|---|
| Fetching all five endpoints in sequence in a single blocking call | 5–30 s wall time for large surveys; no progress feedback | Fetch one endpoint at a time; surface per-endpoint timing via `cli::cli_inform()` | Any survey with >1000 interviews |
| No timeout on `httr2::req_perform()` | Hangs indefinitely if server is slow | Add `httr2::req_timeout(req, seconds = 30)` | Any CI run against the live NGPC server |
| Re-fetching the same endpoint multiple times within one analysis | N × API latency for N re-runs | Cache the response with `memoise` or store result in a local variable | Interactive development sessions |

---

## "Looks Done But Isn't" Checklist

- [ ] **API fetch returns data:** Verify `nrow(result) > 0` with a known non-empty survey UID — a 0-row return with no error looks like success but may be a rename failure.
- [ ] **Date column is Date class:** `inherits(result$date, "Date")` — NA coercion from ISO-8601 datetime is silent.
- [ ] **Species is character:** `is.character(result$species)` — `simplifyVector` may return integer codes as integer class, which breaks downstream character comparisons.
- [ ] **catch_type values documented:** Print `unique(catch$catch_type)` and confirm against expected set before any downstream filter.
- [ ] **Empty endpoint handled:** Test with a UID for a survey that has no harvest lengths (common for zero-harvest surveys) — the handler must return a valid 0-row frame, not error.
- [ ] **S3 dispatch verified:** `methods("fetch_interviews")` lists `fetch_interviews.creel_connection_api` and it is the one dispatched, not the CSV method.
- [ ] **Integration script is offline-capable:** Remove the live API call or wrap with `skip_if_offline()`; script must run in CI without network.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---|---|---|
| API-1 (wrong rename map) | LOW | Add hardcoded `api_rename_map` per endpoint; no schema changes needed |
| API-2 (date NA coercion) | LOW | Replace `as.Date(df$date, tryFormats)` with `.parse_api_date(df$date)` in API methods |
| API-3 (empty response guard) | LOW | Fix the `is.data.frame && nrow == 0` guard; add unit test |
| API-5 (`iiUID` mismatch) | LOW | Fix rename map for length endpoints; unit test with fixture |
| INT-1 (interview deduplication) | MEDIUM | Identify all downstream aggregations that assumed unique UIDs; re-run and compare to reference values |
| INT-3 (species code 86 dropped) | MEDIUM | Add back the dropped rows; re-run catch totals; compare to reference report |
| INT-5 (live API in CI) | MEDIUM | Record fixture responses with `httptest2`; replay in tests |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---|---|---|
| API-1 (field name mismatch) | API fetch method implementation | `fetch_interviews()` on a real UID returns correct column names and >0 rows |
| API-2 (ISO-8601 date parsing) | API fetch method implementation | Unit test: `.parse_api_date("2016-04-02T00:00:00")` returns `as.Date("2016-04-02")` |
| API-3 (empty response guard) | API fetch method implementation | Mock empty JSON array; assert 0-row frame with correct columns |
| API-4 (list-columns from NULL fields) | API fetch method implementation | Test with fixture containing NULL-valued fields in JSON |
| API-5 (`iiUID` mismatch) | API fetch method implementation | Read live (or recorded) length endpoint; confirm `iiUID` field name |
| INT-1 (interview deduplication) | Integration script design | `nrow(interviews) > length(unique(interviews$interview_uid))` assertion passes |
| INT-2 (catch type "caught") | Integration script implementation | `unique(catch$catch_type)` printed and documented; filter logic handles all three values |
| INT-3 (species code 86) | Integration script implementation | Species code inventory printed at script start; 86 appears in output catch totals |
| INT-4 (refused filter) | Integration script implementation + test fixtures | At least one refused-row fixture exists; filter is tested |
| INT-5 (live API in tests) | Integration test design | `skip_if_offline()` present; CI passes without network access |
| INT-6 (dispatch to wrong method) | API fetch method implementation | `class(api_conn)[[1]] == "creel_connection_api"` assertion in constructor test |

---

## Sources

- Codebase: `/Users/cchizinski2/Dev/tidycreel/tidycreel.connect/R/creel-connection-api.R` — `.api_fetch()` empty-response guard and `.parse_api_date()` implementation
- Codebase: `/Users/cchizinski2/Dev/tidycreel/tidycreel.connect/R/fetch-loaders.R` — `.rename_to_canonical()` and CSV method implementations
- Legacy NGPC helper: `/Users/cchizinski2/Desktop/creel_test_TEMP/run_calamus_2016/CreelDataAccess.R` — authoritative source for NGPC API field names (`ii_UID`, `cd_Date`, `ir_Species`, `Num`, `CatchType`, `iiUID` for length endpoints)
- Calamus 2016 interview CSV: interview_uid appears 2x/4x per UID (bus-route multi-row design); zero refused rows in this export
- Calamus 2016 catch CSV: species codes 86, 178, 300, 350, 360, 420, 430, 520, 620, 645, 830, 850, 862; catch_type values "caught", "harvested", "released"
- httr2 `simplifyVector` behavior: equivalent to `jsonlite::fromJSON(simplifyVector = TRUE)`; empty JSON array returns 0-row data.frame, not 0-length list

---
*Pitfalls research for: REST API fetch dispatch and real-data integration (tidycreel v1.7.0 milestone)*
*Researched: 2026-05-09*
