# Project Research Summary

**Project:** tidycreel v1.3.0 — Generic DB Interface
**Domain:** R package DB interface layer — creel_schema S3 contract + tidycreel.connect companion package
**Researched:** 2026-04-06
**Confidence:** HIGH

## Executive Summary

tidycreel v1.3.0 adds a config-driven database loading layer to an existing three-layer R package that already ships 1,864+ passing tests and five validated survey types. The architecture splits into two concerns: a `creel_schema` S3 class (column mapping contract) added to tidycreel core, and a new `tidycreel.connect` companion package that wraps DBI connections and CSV paths behind a uniform `creel_connect()` + `fetch_*()` API. The closest ecosystem precedents are CDMConnector (OMOP CDM) and easydb; the key architectural divergence from CDMConnector is that all fetches are eager (not lazy) because creel datasets fit in memory and the existing `survey::` estimation pipeline requires it. No existing tidycreel functions change their signatures.

The recommended approach is a four-phase build sequence driven by the dependency graph: `creel_schema` in tidycreel first (no external deps), then the tidycreel.connect package skeleton and YAML config layer, then the CSV backend (fully testable without a database), then the SQL Server ODBC backend last. This order keeps the existing 1,864-test suite green throughout and allows the companion package's CI to verify the entire fetch-to-estimation pipeline against fixture CSVs before any live database is involved.

The primary risk area is the SQL Server ODBC backend: platform-specific driver names, Windows-only integrated authentication, SQL DATE returning as character, and credential exposure in YAML config files are all high-impact pitfalls with silent failure modes. Every one of these pitfalls is addressed at the YAML config validation layer and the `fetch_*()` coercion layer — both of which must be implemented before the SQL Server backend is considered done. The flat file backend has its own traps (UTF-8 BOM from Excel exports, readr type-guessing of species codes), but these are lower-stakes and fully testable without infrastructure.

## Key Findings

### Recommended Stack

tidycreel itself requires no new `Imports` entries — `creel_schema` is implemented with base R plus the packages already in Imports (checkmate, cli, rlang). The companion package `tidycreel.connect` adds: `DBI >= 1.3.0` (generic DB interface, in Imports), `yaml >= 2.3.12` (YAML config parsing, in Imports), and the same supporting packages already used by tidycreel (dplyr, tibble, cli, rlang, checkmate). Both `odbc` and `readr` belong in `Suggests` — odbc because it requires system-level ODBC drivers that CSV-only users should not be forced to install, readr because base `read.csv()` is an acceptable fallback. Test infrastructure uses RSQLite as a DBI-compliant in-memory backend, withr for temp files and env vars, and mockery sparingly.

**Core technologies:**
- DBI >= 1.3.0 (Imports): generic DB interface — every backend implements its generics; enables backend-agnostic `fetch_*()` code
- yaml >= 2.3.12 (Imports): YAML config parsing — maps naturally to creel_schema named-list structure; no hidden filename conventions
- odbc >= 1.6.4 (Suggests): SQL Server ODBC driver — DBI-compliant, ~10x faster than RODBC; system deps make it Suggests-only
- readr >= 2.1.6 (Suggests): flat-file backend — vroom engine, tibble output, handles UTF-8 BOM correctly; Suggests allows CSV-only installs without system deps
- RSQLite >= 2.3.0 (Suggests/test): in-memory DBI test backend — eliminates SQL Server dependency from CI

**Do not use:** RODBC (not DBI-compliant), dbplyr in `fetch_*()` (lazy eval incompatible with survey design pipeline), pool (Shiny-oriented connection management), `:::` access to tidycreel internals.

### Expected Features

The MVP that enables a complete NGPC workflow is: `creel_schema` S3 class + validator in tidycreel, `ngpc_default_schema()` convenience constructor, `creel_connect()` for both SQL Server and flat-file backends, and all five `fetch_*()` loaders. Everything else — YAML-from-file constructor, print methods, DuckDB backend, survey type attribute tagging — is P2/P3 to add after the core path is validated.

**Must have (table stakes):**
- `creel_schema` S3 class with `new_creel_schema()` + `validate_creel_schema()` — required by every downstream function; CDMConnector ecosystem precedent
- `ngpc_default_schema()` — zero-configuration path for primary user group; removes all boilerplate
- `creel_connect()` — fundamental entry point accepting DBI connection or CSV paths plus a `creel_schema`
- `fetch_interviews()`, `fetch_counts()`, `fetch_catch()`, `fetch_harvest_lengths()`, `fetch_release_lengths()` — five loaders block the estimation pipeline if missing
- SQL Server backend via odbc + Windows Authentication — NGPC production requirement
- Flat-file / CSV backend via readr — general-purpose viability and testability without live DB
- Validation on load (`validate_fetch_result()`) — catches schema mismatches at fetch time, not buried in estimator calls

**Should have (competitive):**
- `creel_connect_from_yaml()` — reduces connection boilerplate; add once core API is stable
- `print.creel_schema()` / `print.creel_connection()` — consistent with existing tidycreel print methods
- Survey type tag as `.survey_type` attribute on `fetch_*()` output — enables `creel_design()` dispatch without user re-specifying

**Defer (v2+):**
- Additional agency schemas (Wisconsin DNR, Minnesota DNR) — requires agency contribution
- Schema versioning — premature until schema drift is observed in practice
- `creel_schema` export to YAML (round-trip serialization)
- DuckDB flat-file backend — add only if users report CSV loading is slow
- REST API backend — out of scope; users should use existing CreelApiHelper.R

**Anti-features to reject explicitly:** auto-discover column mapping, plaintext credentials in YAML, `fetch_all()` mega-loader, dbplyr/lazy evaluation for fetch, SQL dialect translation, S4/R6 for `creel_schema`.

### Architecture Approach

The design adds two new layers below the existing tidycreel API layer without touching any of the 22 existing R source files (except `R/print-methods.R` and `R/data.R` for additive extensions only). The dependency direction is strictly one-way: `tidycreel.connect` imports `tidycreel`; `tidycreel` has no dependency on `tidycreel.connect`. `creel_schema` belongs in `tidycreel` (not in the companion package) because it is a contract about what `add_interviews()` etc. expect, and placing it in the companion package would create a circular dependency. The `fetch_*()` functions are thin adapters — they rename columns from source names to canonical names expected by `add_*()` and perform type coercion; no scientific logic lives in them.

**Major components:**
1. `creel_schema` S3 class (tidycreel, `R/creel-schema.R`) — stateless column/table mapping contract; carries `col_map`, `table_map`, `survey_type`, `version`; validates required columns for each survey type
2. `creel_connection` S3 object (tidycreel.connect) — carries live DBI connection or NULL (CSV), embedded `creel_schema`, backend tag; returned by `creel_connect()`; consumed by all `fetch_*()` functions
3. `fetch_*()` loaders (tidycreel.connect, one file per table) — dispatch on backend tag; apply column map; coerce types; return plain tibbles ready for `add_*()` without further renaming
4. YAML config layer (tidycreel.connect, `R/yaml-config.R`) — validates all required keys immediately after `read_yaml()`; never lets NULL propagate to `DBI::dbConnect()`
5. Backend internals (tidycreel.connect) — `.fetch_sqlserver()` and `.fetch_csv()` are separate internal helpers; adding a third backend requires only a new helper and a new dispatch branch in `fetch_*()`

### Critical Pitfalls

1. **ODBC driver name is platform-specific (DB-1)** — never hard-code; require `driver:` as a YAML key; document `odbc::odbcListDrivers()` for discovery; provide `creel_check_driver()` diagnostic. Prevents silent failures on macOS/Linux.

2. **Windows Integrated Authentication fails on macOS/Linux (DB-2)** — YAML must support separate `auth: windows_integrated` vs `auth: sql_password` modes; `creel_connect()` detects platform and aborts with a clear message when `windows_integrated` is requested on non-Windows.

3. **YAML implicit type coercion silently corrupts config values (YML-1)** — `trusted_connection: yes` is parsed as logical `TRUE`, not the string `"yes"`; validate types of every config key immediately after `read_yaml()` using `cli_abort()` that names the offending key and its actual R type.

4. **SQL DATE columns return as character from odbc, not as R Date (DB-4)** — documented long-standing issue in r-dbi/odbc; `fetch_*()` loaders must explicitly coerce all date columns with `as.Date()` after retrieval; tests must assert `is(result$cd_Date, "Date")`, not just non-null.

5. **odbc in Imports forces system ODBC library install for all users (S3-3)** — `odbc` must be in `Suggests`; use `rlang::check_installed("odbc")` at the top of the SQL Server backend path; flat-file-only users install without any system dependencies.

6. **tidycreel.connect using `:::` to access tidycreel internals (S3-4)** — `creel_schema` constructor must be a fully exported public API in tidycreel; companion package uses `@importFrom tidycreel creel_schema`; never uses `:::`.

7. **readr type-guessing misclassifies species codes and zero-padded identifiers (FF-3)** — always pass explicit `col_types` to `read_csv()`; `creel_schema` must carry a column-type mapping alongside the column-name mapping; test with leading-zero fixtures.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase A: creel_schema S3 Class in tidycreel

**Rationale:** `creel_schema` is the foundational dependency for all other phases. It must exist in tidycreel before tidycreel.connect can be created. It has no external dependencies (uses only base R + existing Imports). Completing this phase independently ships value to flat-file users who want schema validation without the companion package.

**Delivers:** `new_creel_schema()`, `creel_schema()`, `validate_creel_schema()`, `is_creel_schema()`, `CANONICAL_COLUMNS` constant, `ngpc_default_schema()`, `print.creel_schema()`. Tests for construction, validation errors, survey type tagging, print output.

**Addresses:** creel_schema S3 class (table stakes), validate_creel_schema(), ngpc_default_schema(), print.creel_schema()

**Avoids:** Circular dependency (creel_schema lives in tidycreel, not companion package); API breakage (plain S3 list, never applied as class on fetch_*() return values)

**Research flag:** Standard patterns — no research phase needed. Wickham AdvR §13 three-function S3 pattern is well-documented; existing `creel_design` and `creel_estimates` constructors in the codebase are direct models. Gap: canonical column names in `CANONICAL_COLUMNS` must be verified against live `add_interviews()`, `add_counts()`, `add_catch()`, `add_lengths()` signatures before implementation.

### Phase B: tidycreel.connect Package Skeleton + YAML Config Layer

**Rationale:** The YAML config format and its validation logic are where the most dangerous pitfalls live (credential exposure, NULL propagation, implicit type coercion). These must be designed and validated as a separate deliverable before any backend code is written — catching config errors at load time is the core UX promise of the package.

**Delivers:** Package scaffold (DESCRIPTION, NAMESPACE, testthat structure), `creel_connect()`, `new_creel_connection()`, `print.creel_connection()`, `.read_config()`, `.validate_config_keys()`. Tests for YAML parsing with temp files, missing key errors, type validation, credential env-var preference, backend tag assignment.

**Addresses:** creel_connect() constructor, creel_connect_from_yaml() (stub), fail-fast config validation, credential security

**Avoids:** YML-1 (implicit type coercion), YML-2 (NULL propagation), YML-3 (credential in YAML), S3-3 (odbc in Imports — DESCRIPTION must be correct before any backend code), S3-4 (circular dependency — one-way import direction established here), S3-2 (DBI S4 dispatch — NAMESPACE must be correct before any DBI method is written)

**Research flag:** Review rstudio/config `!expr` credential injection pattern during planning — the yaml package (not the config package) handles tag evaluation differently and the mechanism for R expression evaluation in YAML keys needs verification.

### Phase C: CSV Backend + fetch_*() Loaders

**Rationale:** The CSV backend is fully testable without network access or ODBC drivers, making it the right target for validating the entire fetch → rename → type-coerce → add_*() pipeline. Once CSV backend tests confirm that `fetch_interviews()` output flows into `add_interviews()` without modification, the SQL Server backend only needs to substitute the data source — the coercion and rename logic is already proven.

**Delivers:** `.fetch_csv()` internal helper, all five `fetch_*()` functions (CSV dispatch path), `validate_fetch_result()` internal, BOM-strip column name cleanup, explicit `col_types` specification, column-type map in `creel_schema`. Tests against fixture CSV files. Round-trip integration test: CSV fixture → `fetch_interviews()` → `add_interviews()`.

**Addresses:** fetch_interviews(), fetch_counts(), fetch_catch(), fetch_harvest_lengths(), fetch_release_lengths(), validation on load, flat-file backend (all table-stakes features)

**Avoids:** FF-1 (column name variants — column mapping is core, not add-on), FF-2 (BOM corruption — readr + defensive BOM-strip), FF-3 (readr type guessing — explicit col_types), S3-1 (creel_schema class never applied to fetch_*() return values)

**Research flag:** Standard patterns — no research phase needed. readr `col_types` specification is thoroughly documented; BOM handling is a known solved problem.

### Phase D: SQL Server ODBC Backend

**Rationale:** SQL Server is the production requirement for NGPC but depends on external infrastructure (ODBC driver, network, credentials). Building it last means all SQL-specific pitfalls are addressed in a contained phase with a fully locked public API. Integration tests are the only ones requiring external infrastructure.

**Delivers:** `.fetch_sqlserver()` internal helper, driver detection logic, creel_uid WHERE clause injection, explicit `as.Date()` coercion for all date columns, platform check for Windows auth mode, `creel_check_driver()` diagnostic function. Tests skipped when DB unreachable via `testthat::skip_if()`. Full integration test: YAML → `creel_connect()` → `fetch_interviews()` → `add_interviews()` against NGPC test DB.

**Addresses:** SQL Server backend (table stakes), Windows Authentication, creel_uid filtering

**Avoids:** DB-1 (driver name hard-coding), DB-2 (Windows auth on macOS/Linux), DB-3 (connection leaks in tests), DB-4 (SQL DATE as character), DB-5 (DATETIMEOFFSET), DB-6 (encoding/Latin1 collation)

**Research flag:** Needs planning attention — CI matrix for macOS/Linux SQL Server testing requires ODBC driver install steps that must be specified before implementation. NGPC database collation (Latin1 vs UTF-8) must be confirmed with NGPC DBA before the encoding coercion layer is written. creel_uid WHERE clause field name must be verified against live NGPC view schema.

### Phase E: Polish, Documentation, Getting-Started Vignette

**Rationale:** P2 features (YAML-from-file constructor, print method refinement, `.survey_type` attribute tagging) add convenience after the core path is validated. The getting-started vignette requires all four phases to be complete.

**Delivers:** `creel_connect_from_yaml()`, credential env-var documentation in README, `.survey_type` attribute on fetch_*() output, getting-started vignette (YAML → connect → fetch → add_*() workflow), README with platform-specific ODBC install instructions.

**Addresses:** creel_connect_from_yaml() (P2), survey type tagging (P2), print.creel_connection() refinement

**Research flag:** Standard documentation patterns — no research phase needed.

### Phase Ordering Rationale

- Phase A before everything: `creel_schema` is a compile-time dependency for tidycreel.connect and cannot be deferred
- Phase B before backends: YAML validation must be in place before any connection attempt is made; the config layer is the security and correctness boundary
- Phase C before Phase D: CSV backend validates the full fetch → rename → add_*() pipeline without infrastructure; SQL Server backend then substitutes only the data source
- Phase E last: polish and documentation require the entire API to be stable

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified on CRAN; DBI/odbc ecosystem is well-documented; version compatibility confirmed; odbc vs RODBC performance verified at odbc.r-dbi.org |
| Features | HIGH | CDMConnector and easydb as direct ecosystem precedents; feature set derived from clear dependency analysis; gap: canonical column names need verification against live add_*() signatures |
| Architecture | HIGH | Grounded in direct codebase inspection of all 22 R source files; dependency direction and component boundaries have no ambiguity; build order follows hard dependency graph |
| Pitfalls | HIGH | DB/ODBC pitfalls verified against odbc GitHub issues and Microsoft Learn; YAML coercion verified against yaml package docs; S3 contract pitfalls verified against r-pkgs.org 2e |

**Overall confidence:** HIGH

### Gaps to Address

- **Canonical column names in add_*() signatures:** FEATURES.md explicitly flags this as "the single most important implementation verification step." The column names listed are based on PROJECT.md descriptions, not confirmed against live source code. Phase A plan must read the actual `add_interviews()`, `add_counts()`, `add_catch()`, and `add_lengths()` function signatures before specifying `CANONICAL_COLUMNS`.

- **YAML `!expr` support in the yaml package:** The rstudio/config `!expr Sys.getenv()` pattern is documented for the config package. The yaml package may handle custom YAML tags differently. Verify during Phase B planning whether `yaml::read_yaml()` supports `!expr` tags natively or whether credential injection must use a different mechanism.

- **NGPC database collation and encoding:** PITFALLS.md DB-6 notes the NGPC database may use Latin1/Windows-1252 collation. Actual collation must be confirmed with the NGPC DBA before the SQL Server backend is considered complete.

- **creel_uid WHERE clause field name:** ARCHITECTURE.md shows `creel_uids` as a list of UUIDs injected into SQL WHERE clauses, but the actual view column name (`cd_CreelUID`?) needs verification against live NGPC view schema before Phase D implementation.

## Sources

### Primary (HIGH confidence)

- tidycreel v1.2.0 source — all 22 R files inspected; existing S3 patterns, add_*() signatures, creel_design constructor
- [DBI 1.3.0 CRAN](https://cran.r-project.org/package=DBI) — version confirmed 2026-02-25
- [odbc 1.6.4 CRAN](https://cran.r-project.org/web/packages/odbc/index.html) — version confirmed 2025-12-06; DBI compliance and SQL Server performance confirmed
- [odbc official site](https://odbc.r-dbi.org/) — connection patterns, driver issues
- [readr 2.1.6 CRAN](https://cran.r-project.org/package=readr) — version confirmed 2026-02-19
- [yaml 2.3.12 CRAN](https://cran.r-project.org/package=yaml) — version confirmed December 2025
- [Advanced R §13 S3 (Wickham)](https://adv-r.hadley.nz/s3.html) — three-function S3 constructor pattern
- [rstudio/config GitHub](https://github.com/rstudio/config) — YAML credential injection pattern
- [DBI Introduction vignette](https://cran.r-project.org/web/packages/DBI/vignettes/DBI.html) — dbConnect/dbGetQuery/dbDisconnect pattern
- [R for Data Science 2e §21 Databases](https://r4ds.hadley.nz/databases.html) — lazy vs. eager collect() decision
- [R Packages 2e §7](https://r-pkgs.org/dependencies-mindset-background.html) — companion package dependency direction
- Legacy CreelDataAccess.R / CreelDataAccess_CJCedits.R — five SQL view names confirmed; DBI+odbc connection pattern; env-var password handling

### Secondary (MEDIUM confidence)

- [CDMConnector Getting Started vignette](https://cran.r-project.org/web/packages/CDMConnector/vignettes/a01_getting-started.html) — cdm_reference S3 pattern; validate_cdm(); lazy vs. eager divergence
- [Securing Credentials — db.rstudio.com](https://edgararuiz.github.io/db.rstudio.com/best-practices/managing-credentials.html) — credential management hierarchy
- [easydb GitHub](https://github.com/EricEdwardBryant/easydb) — YAML config → connection object → pipeline pattern
- [OHDSI DatabaseConnector](https://github.com/OHDSI/DatabaseConnector) — uniform DBI surface across backends
- r-dbi/odbc GitHub issues #11, #61, #207, #67, #437 — SQL DATE character return; DATETIMEOFFSET; encoding issues
- readr GitHub issues #500, #263 — UTF-8 BOM handling in Excel-exported CSVs

---
*Research completed: 2026-04-06*
*Ready for roadmap: yes*
