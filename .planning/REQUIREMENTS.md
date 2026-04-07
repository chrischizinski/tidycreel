# Requirements: tidycreel v1.3.0

**Defined:** 2026-04-06
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals

## v1 Requirements

Requirements for v1.3.0 — Generic DB Interface. Phases continue from 65 (last v1.2.0 phase).

### Schema Contract (in tidycreel)

- [x] **SCHEMA-01**: User can construct a `creel_schema` object specifying column name mappings, table names, and survey type via `creel_schema()`
- [x] **SCHEMA-02**: User can get a ready-to-use NGPC schema with zero configuration via `ngpc_default_schema()` _(Deferred — ngpc_default_schema() lives in a private NGPC-specific repo, not in the public tidycreel package)_
- [x] **SCHEMA-03**: `validate_creel_schema()` aborts with a clear `cli_abort()` error naming the missing columns when required columns for the specified survey type are absent from the mapping
- [x] **SCHEMA-04**: User can print a `creel_schema` object to see column mappings and survey type in a readable summary

### Connection & Config (in tidycreel.connect)

- [x] **CONNECT-01**: User can create a `creel_connection` by passing a DBI connection + `creel_schema` to `creel_connect()`
- [x] **CONNECT-02**: User can create a `creel_connection` by passing CSV file paths + `creel_schema` to `creel_connect()`
- [x] **CONNECT-03**: User can create a `creel_connection` from a YAML config file via `creel_connect_from_yaml()` with fail-fast validation of all keys and types before any connection attempt
- [x] **CONNECT-04**: YAML config credentials are loaded from environment variables, never stored as plain text
- [x] **CONNECT-05**: User can print a `creel_connection` to see backend type, schema summary, and connection status
- [x] **CONNECT-06**: User can check available ODBC drivers and verify SQL Server driver presence via `creel_check_driver()`

### Fetch Loaders (in tidycreel.connect)

- [ ] **FETCH-01**: User can load interview data ready for `add_interviews()` via `fetch_interviews(conn)`
- [ ] **FETCH-02**: User can load count data ready for `add_counts()` via `fetch_counts(conn)`
- [ ] **FETCH-03**: User can load catch data ready for `add_catch()` via `fetch_catch(conn)`
- [ ] **FETCH-04**: User can load harvest length data ready for `add_lengths()` via `fetch_harvest_lengths(conn)`
- [ ] **FETCH-05**: User can load release length data ready for `add_lengths()` via `fetch_release_lengths(conn)`
- [ ] **FETCH-06**: `fetch_*()` functions abort with a clear error naming the missing or mistyped columns when required columns are absent or wrong type after loading

### Backends (in tidycreel.connect)

- [ ] **BACKEND-01**: Flat file backend loads data from CSV files with explicit column types, stripping UTF-8 BOM and preventing species codes from being misclassified as numeric
- [ ] **BACKEND-02**: SQL Server backend detects platform and aborts with a clear error when Windows integrated auth is requested on macOS/Linux
- [ ] **BACKEND-03**: SQL Server backend explicitly coerces all date columns to R `Date` type after retrieval
- [ ] **BACKEND-04**: `odbc` package is only required at runtime for SQL Server backend; flat-file-only users can install and use tidycreel.connect without system ODBC libraries

### Documentation (tidycreel.connect)

- [ ] **DOCS-01**: tidycreel.connect ships a getting-started vignette demonstrating YAML config → `creel_connect()` → `fetch_interviews()` → `add_interviews()` end-to-end workflow
- [ ] **DOCS-02**: README includes platform-specific ODBC driver install instructions for Windows, macOS, and Linux

## v2 Requirements

Deferred to future release.

### Additional Backends

- **BACKEND-05**: SQLite backend via RSQLite — portable single-file DB for offline work
- **BACKEND-06**: REST API backend — CreelApiHelper.R endpoint pattern

### Extended Schema Support

- **SCHEMA-05**: Additional agency schemas (Wisconsin DNR, Minnesota DNR) — requires agency contribution
- **SCHEMA-06**: Schema round-trip serialization — export `creel_schema` to YAML

### Survey Type Integration

- **CONNECT-07**: `.survey_type` attribute on `fetch_*()` output enables `creel_design()` dispatch without user re-specifying

## Out of Scope

| Feature | Reason |
|---------|--------|
| Auto-discover column mapping | Fragile; column name variants across agencies require explicit mapping |
| Plain-text credentials in YAML | Security anti-pattern; env-var pattern is the standard |
| `fetch_all()` mega-loader | Forces all 5 tables into memory regardless of need; lazy loading preferred by caller |
| dbplyr / lazy evaluation in fetch_*() | Incompatible with survey:: pipeline which requires data in memory |
| DuckDB backend | Add only if users report CSV loading is slow (premature optimization) |
| S4 or R6 for creel_schema | S3 is consistent with existing tidycreel patterns |
| CRAN submission for tidycreel.connect | GitHub-only distribution for v1.3.0; CRAN is a future consideration |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCHEMA-01 | Phase 66 | Complete |
| SCHEMA-02 | Private repo (deferred) | Deferred |
| SCHEMA-03 | Phase 66 | Complete |
| SCHEMA-04 | Phase 66 | Complete |
| CONNECT-01 | Phase 67 | Complete |
| CONNECT-02 | Phase 67 | Complete |
| CONNECT-03 | Phase 67 | Complete |
| CONNECT-04 | Phase 67 | Complete |
| CONNECT-05 | Phase 67 | Complete |
| CONNECT-06 | Phase 67 | Complete |
| FETCH-01 | Phase 68 | Pending |
| FETCH-02 | Phase 68 | Pending |
| FETCH-03 | Phase 68 | Pending |
| FETCH-04 | Phase 68 | Pending |
| FETCH-05 | Phase 68 | Pending |
| FETCH-06 | Phase 68 | Pending |
| BACKEND-01 | Phase 68 | Pending |
| BACKEND-02 | Phase 69 | Pending |
| BACKEND-03 | Phase 69 | Pending |
| BACKEND-04 | Phase 68 | Pending |
| DOCS-01 | Phase 70 | Pending |
| DOCS-02 | Phase 70 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-04-06*
*Last updated: 2026-04-07 — SCHEMA-02 reassigned to private repo (deferred from Phase 66 per CONTEXT.md decision)*
