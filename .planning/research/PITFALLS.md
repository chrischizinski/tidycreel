# Pitfalls Research

**Domain:** Adding DBI-based companion package + S3 schema contract to an existing R package (tidycreel v1.3.0 — Generic DB Interface)
**Researched:** 2026-04-06
**Confidence:** HIGH for DBI/odbc and SQL Server driver pitfalls (verified against odbc GitHub issues, Microsoft Learn, r-dbi documentation); HIGH for YAML type coercion (yaml package docs, yaml12 announcement); HIGH for companion package dependency setup (r-pkgs.org 2e, DBI backend guide); MEDIUM for flat file edge cases and encoding (readr GitHub issues, multiple corroborating sources); MEDIUM for S3 contract versioning (Advanced R, Epiverse-TRACE community posts)

---

## Scope

This document focuses on pitfalls specific to **adding** v1.3.0 generic DB interface features to a package that already has:
- ~1,864 tests passing — any regression is immediately visible
- A well-defined three-layer architecture (API → Orchestration → survey::)
- `creel_schedule` and `creel_estimates` as existing S3 contracts
- Five survey types with strict column name and type conventions

The new additions are: (1) `creel_schema` S3 class in tidycreel, (2) `tidycreel.connect` companion package with `creel_connect()` and `fetch_*()` loaders, (3) SQL Server ODBC backend, (4) flat file/CSV backend, (5) YAML config format.

Pitfalls are organized into five groups: (1) SQL Server ODBC driver and connection, (2) SQL→R type coercion, (3) YAML config parsing and validation, (4) flat file backend edge cases, (5) S3 contract and companion package architecture.

---

## Critical Pitfalls

### Pitfall DB-1: ODBC Driver Name Differs by Platform and Installation Method

**What goes wrong:**
A connection string hard-coded with `Driver={ODBC Driver 18 for SQL Server}` works on the developer's Windows machine but fails on macOS or Linux where the driver is either absent, named differently (`{ODBC Driver 17 for SQL Server}` from a Homebrew install), or installed at a non-standard path. On ARM64 (M1/M2) Macs, driver support for SQL Server only arrived in Microsoft ODBC Driver 17.8. Older installations using iODBC as the driver manager instead of unixODBC cause architecture-mismatch errors that produce no useful error message.

**Why it happens:**
Connection string construction is typically tested on one platform and hard-coded. NGPC staff run Windows; biologists at other institutions may use macOS. The driver name is embedded as a string in configuration, not discovered at runtime.

**How to avoid:**
The YAML config and `creel_connect()` should never hard-code a driver name. Instead, provide `driver` as a required key in the YAML config with clear documentation that the value must match the system driver name exactly (discoverable via `odbc::odbcListDrivers()`). The companion package README must show the Homebrew install command (`HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql18 mssql-tools18`) for macOS and the Microsoft download link for Windows. Add a `creel_check_driver()` diagnostic function that calls `odbc::odbcListDrivers()` and prints available SQL Server drivers with instructions for installing any that are missing.

**Warning signs:**
- `Driver=` key in `creel_connect()` defaults are hard-coded to a specific version string
- README shows only a Windows connection example
- CI/CD matrix does not include macOS or Linux

**Phase to address:** `creel_connect()` implementation phase; driver docs required before any SQL Server test suite.

---

### Pitfall DB-2: Windows Integrated Authentication (Trusted_Connection) Does Not Work on macOS/Linux

**What goes wrong:**
NGPC users on Windows authenticate with `Trusted_Connection=Yes` (Kerberos/NTLM integrated auth), which requires no uid/pwd. When a biologist on macOS tries the same YAML config they received from a Windows colleague, the connection silently fails or returns a confusing `[08001] [Microsoft][ODBC Driver 18 for SQL Server]SSL Provider: [OpenSSL]` error. Integrated authentication over ODBC on non-Windows requires MIT Kerberos (`krb5`) configuration that most users will not have.

**Why it happens:**
NGPC YAML configs are written on Windows and shared directly. The `trusted = true` field in the config looks like a simple boolean toggle.

**How to avoid:**
The YAML config schema must have separate auth modes: `auth: windows_integrated` and `auth: sql_password`. The `creel_connect()` function must detect the platform and error immediately with a helpful message when `auth: windows_integrated` is requested on macOS/Linux: `"Windows Integrated Authentication requires Kerberos configuration on macOS/Linux. Use auth: sql_password with uid/pwd instead."`. Document in the README that the NGPC production connection uses Windows auth; test environments should use SQL auth with a service account.

**Warning signs:**
- YAML spec documents `trusted_connection: true` as a boolean without a platform note
- No test covering the macOS connection path
- `creel_connect()` constructs `Trusted_Connection=Yes` without a `Sys.info()["sysname"]` guard

**Phase to address:** YAML config schema phase (before connection implementation).

---

### Pitfall DB-3: Connection Objects Leaking Across Test Runs

**What goes wrong:**
If a `creel_connect()` call in a test opens a DBI connection that is never closed (no `on.exit(DBI::dbDisconnect(con))` or `withr::defer`), subsequent tests that attempt a new connection to the same SQL Server instance may exhaust the connection pool or fail with `"too many connections"`. On macOS with unixODBC, a leaked connection often holds a file descriptor lock that causes the next `dbConnect()` call to hang indefinitely.

**Why it happens:**
Tests with early `stop()` or `expect_error()` branches exit before the cleanup code runs if teardown is not wrapped in `on.exit()`. DBI connections are not garbage-collected automatically.

**How to avoid:**
All tests that open a connection must use `withr::local_db_connection()` (from the `withr` package) or explicitly wrap connection teardown in `on.exit(DBI::dbDisconnect(con), add = TRUE)` at the top of the test function. The `fetch_*()` functions must themselves close any internally opened connections before returning — or document explicitly that the caller-supplied `con` argument is not closed by the function (caller owns lifecycle). Use `DBI::dbIsValid(con)` guards in helper functions.

**Warning signs:**
- Tests open connections with `creel_connect()` without a matching `dbDisconnect()`
- `on.exit()` appears after other side-effecting calls rather than immediately after `dbConnect()`
- CI runs pass locally but hang or time out on the CI runner

**Phase to address:** SQL Server backend phase; test infrastructure established first.

---

### Pitfall DB-4: SQL DATE Columns Return as Character in R, Not as Date

**What goes wrong:**
`cd_Date` in the NGPC interview view is a SQL DATE column. When fetched with `DBI::dbGetQuery()` through the odbc ODBC driver, SQL DATE columns return as `character` (not `Date`) in R — a long-standing documented issue in r-dbi/odbc (issues #11 and #61). Code that then calls `as.Date(cd_Date)` works when the column is already a string like `"2024-06-15"` but fails silently if the ODBC driver returns it with a locale-specific format on some Windows configurations.

**Why it happens:**
The odbc driver maps SQL DATE to R character when the column type is pure DATE (no time component). DATETIME and DATETIME2 columns return as POSIXct. Developers test with DATETIME and assume DATE will behave the same way.

**How to avoid:**
The `fetch_interviews()` function must explicitly coerce `cd_Date` to `Date` after retrieval, regardless of what the driver returns: `interviews$cd_Date <- as.Date(interviews$cd_Date)`. Apply the same coercion to all known date columns in all five creel tables. Document the expected R type for each column in the `creel_schema` object so the coercion layer can be schema-driven rather than column-name-hard-coded. Test by checking `class(fetched_data$cd_Date) == "Date"` in the test suite, not just that the column is non-null.

**Warning signs:**
- `fetch_*()` function returns data without explicit type coercion layer
- Tests check `!is.null(result$cd_Date)` but not `is(result$cd_Date, "Date")`
- `creel_schema` documents column types as informational only, not enforced

**Phase to address:** `fetch_*()` loader phase; coercion must be validated before any downstream estimator test.

---

### Pitfall DB-5: DATETIMEOFFSET and Timezone-Aware Columns Return as Unparseable String

**What goes wrong:**
SQL Server `DATETIMEOFFSET` columns (including some `DATETIME2` fields with explicit timezone offset stored as strings) return from odbc as a verbose string such as `"2024-06-15 09:30:00.0000000 -05:00"`, which `as.POSIXct()` cannot parse without explicit format specification. This has been reported and is unresolved in r-dbi/odbc (issue #207). If any NGPC view column is stored as DATETIMEOFFSET, the default fetch will produce character vectors in R that silently pass downstream into text operations and break any date arithmetic.

**Why it happens:**
DATETIMEOFFSET is uncommon in older SQL Server databases; developers discover it only when testing against production data. The fix requires parsing format strings that differ by SQL Server version.

**How to avoid:**
In the `creel_schema` definition for the SQL Server backend, flag any known DATETIMEOFFSET columns and apply `lubridate::parse_date_time()` with `orders = c("Ymd HMS z", "Ymd HMS")` after fetch. Test explicitly with a fixture that includes a DATETIMEOFFSET value. Add a note in the schema about SQL Server timezone behavior. If no NGPC views use DATETIMEOFFSET today, add a guard in `fetch_*()` that raises a warning (not error) when a character column contains an offset-like pattern: `grepl("[+-][0-9]{2}:[0-9]{2}$", x)`.

**Warning signs:**
- `cd_Date` or any timestamp column is class `character` in post-fetch data
- No timezone-aware test fixture
- `lubridate` is not listed in the companion package dependencies

**Phase to address:** `fetch_*()` loader phase.

---

### Pitfall DB-6: VARCHAR Columns Return with Wrong Encoding (Latin1 vs UTF-8)

**What goes wrong:**
The odbc driver marks all fetched character strings as UTF-8 in R regardless of the actual SQL Server database collation. If the NGPC database uses a Latin1/Windows-1252 collation (common in older SQL Server installations), extended characters in species names, angler comments, or zip codes may be corrupted. The symptom is garbled characters for non-ASCII input — typically appearing as `<U+FFFD>` replacement characters or mojibake — but only when the source data contains those characters, making it easy to miss in testing with ASCII-only fixture data.

**Why it happens:**
odbc issues #67 and #437 document this: the driver marks all returns as UTF-8 but the underlying ODBC layer may have performed a codepage 1252 → UTF-8 conversion with lossy substitutions. Testing with ASCII fixture data never triggers the path.

**How to avoid:**
Include at least one non-ASCII string in the test fixture (e.g., a species name with a diacritic character or a zip code with a leading zero stored as character). The `creel_schema` for the SQL Server backend should note the expected encoding. If the NGPC database is Latin1, apply `iconv(x, from = "latin1", to = "UTF-8")` in the `fetch_*()` coercion layer for all character columns. Verify with NGPC DBA what the database collation actually is before assuming.

**Warning signs:**
- No non-ASCII characters in any test fixture for the SQL Server backend
- `fetch_interviews()` has no encoding coercion in its post-fetch step
- `creel_schema` does not document expected encoding

**Phase to address:** `fetch_*()` loader phase; encoding test fixture must be established before the first fetch function is considered complete.

---

## Critical Pitfalls (YAML and Config)

### Pitfall YML-1: YAML Implicit Type Coercion Silently Corrupts Config Values

**What goes wrong:**
The R `yaml` package (versions prior to the new `yaml12` package announced January 2026) uses YAML 1.1 rules. Under YAML 1.1, the values `yes`, `no`, `on`, `off`, `true`, `false` are all parsed as logical `TRUE`/`FALSE`. A user who writes `trusted_connection: yes` intends the string `"yes"` for the ODBC connection string but receives `TRUE` (logical) in R. Similarly, a value like `timeout: 1:30` is parsed as `90` (sexagesimal) in YAML 1.1, not as the string `"1:30"`. These silent conversions produce confusing downstream errors ("connection string argument must be character, not logical").

**Why it happens:**
YAML's implicit typing rules are not intuitive to non-YAML-expert users. Biologists writing a config file copy examples and modify values without understanding that bare `yes`/`no` are reserved words.

**How to avoid:**
After `yaml::read_yaml()`, the `creel_connect()` validation layer must type-check every expected key before use. Use explicit `stopifnot(is.character(config$driver))` or a structured validation pass with `cli::cli_abort()` messages that name the offending key and its actual R type. Provide a worked YAML example in the README that uses quoted strings for all connection string values (`driver: "ODBC Driver 18 for SQL Server"`) and explain why quotes are required. Do not rely on user-written YAML to preserve the correct type without validation.

**Warning signs:**
- Validation layer checks key presence but not key type
- README shows bare `yes`/`no`/`true`/`false` without quoting in YAML connection examples
- No test feeding a `trusted_connection: yes` (unquoted) config through the validator

**Phase to address:** YAML config schema + validation phase (before `creel_connect()` implementation).

---

### Pitfall YML-2: Missing Required Keys Produce Unhelpful NULL Propagation

**What goes wrong:**
`yaml::read_yaml()` returns a named list. Accessing a missing key returns `NULL` without any error. If `creel_connect()` builds a connection string by pasting config values, a missing `server` key silently becomes `NULL`, which `paste()` converts to the string `"NULL"`, producing a connection string like `Server=NULL;Database=creel` that fails at connection time with a cryptic ODBC error — not at config-read time with a clear message.

**Why it happens:**
R's `NULL` propagation and `paste(NULL)` returning `""` are well-known R behaviors but create a gap between "config loaded successfully" and "config contains all required values." Developers often add validation as an afterthought rather than as the first thing after `read_yaml()`.

**How to avoid:**
Write a `validate_creel_config()` internal function that checks for all required keys by backend type immediately after `yaml::read_yaml()`. Required keys for the SQL Server backend: `backend`, `driver`, `server`, `database`, `auth`. Required keys for the flat file backend: `backend`, `interviews_path`, `catch_path`, `harvest_lengths_path`, `release_lengths_path`. Raise a structured `cli::cli_abort()` error listing all missing keys at once (not one at a time). Never let `NULL` values from a missing key reach `DBI::dbConnect()` or `read.csv()`.

**Warning signs:**
- Connection function directly uses `config$server` without a prior is-null check
- Error messages mention "SQL Server" at connection time rather than "config validation" at load time
- Required-key list is not documented alongside the YAML schema

**Phase to address:** YAML config schema + validation phase.

---

### Pitfall YML-3: YAML Config Contains Plain-Text Credentials Committed to Version Control

**What goes wrong:**
A YAML config file with `uid: biologist_user` and `pwd: Phishingbait1!` is exactly the kind of file users commit to GitHub — either by accident or because no one told them not to. Even if the repository is private, credential exposure in version control is permanent (git history). For a package targeting fisheries agencies, the SQL Server instance is likely a production database with real data.

**Why it happens:**
Biologists are not software developers. The concept of "never commit credentials" is not part of their training. If the package README shows an example config with `uid` and `pwd` fields, users will fill them in and save the file in their project directory.

**How to avoid:**
The YAML config must support credential injection from environment variables: the values for `uid` and `pwd` should be read from `Sys.getenv("CREEL_UID")` and `Sys.getenv("CREEL_PWD")` by default, with the YAML config keys serving as the override. Document the env-var pattern first in the README; show the YAML fields as the fallback. Add a `creel_connect()` warning when `uid` or `pwd` is found in the YAML file directly: `"Credentials found in YAML config. Consider using environment variables CREEL_UID and CREEL_PWD instead."`. A companion `.Rprofile` example showing `Sys.setenv(CREEL_UID = ..., CREEL_PWD = ...)` should be in the README. Never include credentials in test fixtures that could be committed.

**Warning signs:**
- Example YAML in README/vignette has `uid:` and `pwd:` keys with placeholder strings that users will fill in
- No mention of environment variables in the connection documentation
- `creel_connect()` reads `uid`/`pwd` from config without checking env vars first

**Phase to address:** YAML config schema phase (first decision in the companion package design).

---

## Critical Pitfalls (S3 Contract and Companion Package)

### Pitfall S3-1: creel_schema Contract Added to tidycreel Core Breaks Existing Downstream Code

**What goes wrong:**
`creel_schema` is an S3 class added to the core `tidycreel` package. If any existing function that previously returned a plain list or data frame is now returned as a `creel_schema` object, code written against the previous API breaks. The most dangerous form: a `fetch_interviews()` function that returns a `creel_schema`-annotated tibble, where `inherits(result, "data.frame")` is still `TRUE` but `is.list(result)` unexpectedly changes or the `attr()` vector changes, causing downstream `identical()` or `all.equal()` checks in user scripts to fail silently.

**Why it happens:**
Annotating return values with S3 classes feels like a non-breaking addition ("it's still a data frame"). But any code that calls `class(result)` or `attributes(result)` will now receive a different answer. CRAN reverse dependency checks do not cover internal user scripts.

**How to avoid:**
`creel_schema` must be a **separate** S3 class applied only to the config/mapping object itself — never applied as an additional class on the data frames returned by `fetch_*()` loaders. The `fetch_*()` functions return plain tibbles (with the same column names and types that `add_interviews()`, `add_catch()`, etc. already expect) — no new S3 annotation on the data. The schema object is used only internally to drive coercion and validation, not as a return type annotation. This keeps the existing `creel_design()` entry point unchanged.

**Warning signs:**
- `fetch_interviews()` returns an object where `class(result)[1]` is not `"tbl_df"`
- `creel_schema` is listed in the class vector of any data frame returned to the user
- Any existing function in tidycreel has its return class changed as part of the v1.3.0 work

**Phase to address:** `creel_schema` design phase (before any implementation starts).

---

### Pitfall S3-2: S4 vs S3 Method Dispatch Confusion in DBI Backend Implementation

**What goes wrong:**
DBI uses S4 generics (`setMethod()`). A custom DBI backend for `tidycreel.connect` that registers methods as S3 (`method.class <- function(...)`) instead of S4 (`setMethod("dbConnect", "CreelSqlServerDriver", ...)`) will cause R CMD check NOTEs, method dispatch failures, and confusing behavior when DBI dispatch falls through to the default method. The odbc package itself internally copies S4 method implementations "to avoid S4 dispatch NOTEs."

**Why it happens:**
The DBI backend implementation guide uses S4 (`setClass`, `setMethod`). Developers more comfortable with S3 may write S3 methods that appear to work interactively but fail under formal dispatch.

**How to avoid:**
Follow the official DBI backend implementation guide exactly: define driver and connection classes with `setClass()`, register all DBI methods with `setMethod()`. The `tidycreel.connect` package must import `methods` in DESCRIPTION `Imports:` and call `methods::setClass()` not plain S3. Run `R CMD check --as-cran` and treat any NOTE about S4 generics as an error. Review the existing `odbc` package source code as a reference implementation.

**Warning signs:**
- `NAMESPACE` file contains `S3method(dbConnect, CreelSqlServerDriver)` instead of `exportMethods(dbConnect)`
- `methods` package is not in `Imports:` in DESCRIPTION
- R CMD check produces NOTE about "no visible global function definition for setClass"

**Phase to address:** Companion package skeleton phase (DESCRIPTION and NAMESPACE must be correct before any DBI method is written).

---

### Pitfall S3-3: Companion Package DBI/odbc in Imports Forces Heavy Install for All Users

**What goes wrong:**
If `DBI` and `odbc` are in `tidycreel.connect`'s `Imports:`, they install unconditionally for every user who installs `tidycreel.connect` — including users who only want the flat file backend. The `odbc` package requires system-level ODBC libraries (`unixodbc-dev` on Linux), which will fail to compile in environments where those libraries are absent (cloud environments, minimal Docker images, Windows without ODBC installed).

**Why it happens:**
`Imports:` is the path of least resistance. `Suggests:` requires every call to an optional dependency to be wrapped with a runtime check. This extra ceremony feels like overhead.

**How to avoid:**
`DBI` belongs in `Imports:` (it is a pure R interface package with no system dependencies). `odbc` belongs in `Suggests:` with a runtime `rlang::check_installed("odbc", reason = "to use the SQL Server backend")` check at the top of `creel_connect()` when the backend is SQL Server. This allows users who only need the flat file backend to install `tidycreel.connect` without any system ODBC library dependency. The flat file backend has no system dependencies beyond `readr` (or base R's `read.csv()`).

**Warning signs:**
- `odbc` appears in `Imports:` in `tidycreel.connect/DESCRIPTION`
- No conditional `requireNamespace("odbc")` check before SQL Server backend code executes
- CI matrix does not test the flat file backend path without `odbc` installed

**Phase to address:** Companion package skeleton phase (DESCRIPTION must be finalized before any backend code is written).

---

### Pitfall S3-4: tidycreel.connect Importing from tidycreel Creates a Circular Dependency Risk

**What goes wrong:**
`tidycreel.connect` calls internal tidycreel functions to coerce loaded data into `add_interviews()`-compatible form. If it does this by `:::` into tidycreel internals, it (a) triggers R CMD check NOTEs, (b) breaks whenever tidycreel refactors those internals, and (c) creates a hidden circular coupling where the companion package's behavior is determined by undocumented internals rather than the public API. Worse: if tidycreel later also adds `tidycreel.connect` to `Suggests:`, the dependency graph becomes circular and CRAN will reject one or both packages.

**Why it happens:**
The `creel_schema` column mapping is defined in tidycreel. The companion package needs to use it. Reaching into tidycreel internals is the path of least resistance when the schema is not yet a public API.

**How to avoid:**
The `creel_schema` S3 class and its constructor must be a fully public, exported API in tidycreel. `tidycreel.connect` imports `creel_schema` via the normal `@importFrom tidycreel creel_schema` mechanism. `tidycreel.connect` never uses `:::`. The dependency direction is one-way: `tidycreel.connect` depends on `tidycreel`; `tidycreel` has no dependency on `tidycreel.connect` (not even in `Suggests:`). This is the standard pattern: dbplyr depends on dplyr, not the reverse.

**Warning signs:**
- Any `tidycreel:::` usage in `tidycreel.connect/R/` files
- `tidycreel.connect` appears in `tidycreel/DESCRIPTION` under any field
- `creel_schema` constructor is not exported from tidycreel

**Phase to address:** `creel_schema` design phase; must be settled before companion package skeleton is created.

---

## Critical Pitfalls (Flat File Backend)

### Pitfall FF-1: Column Name Variants in User-Supplied CSVs Break the Flat File Backend

**What goes wrong:**
The NGPC database view columns have exact names: `cd_Date`, `cd_Period`, `cd_Section`, `ii_UID`, etc. Users who export CSVs manually may rename columns (e.g., `date` instead of `cd_Date`, `section_id` instead of `cd_Section`), or the column names may differ between NGPC database versions. A flat file backend that requires exact column names will fail for most real-world CSV files with a confusing "column not found" error that gives the user no guidance on what the file should look like.

**Why it happens:**
Column name requirements that seem obvious to the developer are not obvious to the biologist who exported the file from a slightly different query or a different database version.

**How to avoid:**
The `creel_schema` YAML config must allow column name mapping: a `columns:` section that maps canonical tidycreel column names to the actual column names in the user's file. The `fetch_*()` loaders use this mapping to rename columns after reading, before any validation. The YAML config template for the flat file backend must show all five-table column mappings with the NGPC defaults pre-filled. When a required column is missing after mapping, the error must name the canonical column, the mapped name, and the actual columns present in the file.

**Warning signs:**
- `fetch_interviews()` flat file path uses `dplyr::select(cd_Date, cd_Period, ...)` without a prior rename step from column mapping
- YAML config for flat file backend has no `columns:` section
- Error message when a column is missing shows only the canonical name, not the mapped name

**Phase to address:** `creel_schema` design phase (column mapping is a core schema feature, not a flat file add-on).

---

### Pitfall FF-2: UTF-8 BOM in Excel-Exported CSVs Corrupts the First Column Name

**What goes wrong:**
Excel on Windows saves CSV files with a UTF-8 BOM (Byte Order Mark: `\xEF\xBB\xBF` prepended to the file). When `readr::read_csv()` reads such a file, the BOM is stripped. When `utils::read.csv()` reads it on Windows, the BOM may or may not be stripped depending on R version. The practical consequence: the first column name becomes `\xef\xbb\xbfcd_Date` (with the BOM embedded) instead of `cd_Date`, and the column lookup silently fails. This is a documented open issue in `readr` (GitHub issues #500 and #263) that has persisted for years.

**Why it happens:**
NGPC staff save CSV exports via Excel. They do not know that the file contains a BOM. The problem is invisible in Excel and in most text editors on Windows.

**How to avoid:**
The flat file backend's read path must use `readr::read_csv()` (which handles BOM correctly) rather than `utils::read.csv()`. In addition, after reading, apply a defensive BOM-strip to all column names: `names(df) <- gsub("^\xef\xbb\xbf", "", names(df))`. Test with an actual Excel-exported CSV (or a fixture that prepends a BOM) to confirm the column names are clean.

**Warning signs:**
- Flat file backend uses `utils::read.csv()` or `base::read.table()` instead of `readr::read_csv()`
- No BOM-strip post-processing on column names
- Tests use programmatically generated CSV fixtures (never trigger BOM path)

**Phase to address:** Flat file backend phase.

---

### Pitfall FF-3: readr Type Guessing Misclassifies Numeric Species Codes and Zero-Padded Zip Codes

**What goes wrong:**
`readr::read_csv()` guesses column types from the first 1000 rows by default. If `ir_Species` contains values like `"1"`, `"2"`, `"15"`, readr infers `integer`. The value `"0"` for a species code is then read as `0L` (integer), not `"0"` (character) — which matters when that code is joined against a species lookup table keyed by character. Similarly, zip codes like `"07042"` are read as `7042L` (losing the leading zero). Both errors are silent: the read succeeds, but downstream joins find zero matches.

**Why it happens:**
readr's type guessing is heuristically correct for the common case but wrong for identifier-type columns that happen to look numeric. The NGPC data model stores species codes and zip codes as character in the database but they arrive in CSV as digit strings.

**How to avoid:**
The flat file backend must pass explicit column type specifications to `readr::read_csv()` via the `col_types` argument. The `creel_schema` object for the flat file backend must carry a column-type mapping alongside the column-name mapping. Required character columns that look numeric: `ir_Species`, `ih_Species`, `ii_ZipCode`, any `*_code` column. Never rely on readr's default type guessing for identifier columns. Test with a fixture that includes leading-zero zip codes and single-digit species codes.

**Warning signs:**
- `fetch_*()` calls `readr::read_csv(path)` without `col_types` argument
- `creel_schema` has a column-name mapping but no column-type mapping
- Test fixture only uses multi-digit codes that would not lose information if converted to integer

**Phase to address:** Flat file backend phase; column-type spec must be established before any fetch function is considered complete.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-code `Driver={ODBC Driver 18 for SQL Server}` | Works immediately on dev machine | Fails on macOS, Linux, older Windows installs; breaks on driver version upgrade | Never — make `driver` a required config key |
| Put `odbc` in `Imports:` | No conditional-load ceremony | Forces ODBC system library install for flat-file-only users; breaks CI on non-Windows | Never — put in `Suggests:` with runtime check |
| Skip YAML config type validation | Faster to implement | `NULL` propagation produces cryptic ODBC errors far from the config read site | Never |
| Use `:::` to reach tidycreel internals from `tidycreel.connect` | Avoids exporting schema internals | Breaks on every internal refactor; R CMD check NOTE; CRAN rejection risk | Never |
| Apply `creel_schema` class to `fetch_*()` return values | Feels like a consistent API | Breaks existing `class(result)` checks in user code; violates existing API contract | Never — schema class on the mapping object only |
| `utils::read.csv()` for flat file backend | Zero new dependency | Silent BOM corruption of first column name; no encoding control | Never — use `readr::read_csv()` with explicit `col_types` |
| Skip column-type spec in `read_csv()` | Faster to write | Species codes and zip codes silently become integers, losing leading zeros and breaking joins | Never |
| Store plain-text passwords in YAML example | Easy for users to copy | Users commit credentials to version control | Never — env vars first, YAML override second |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| SQL Server ODBC on macOS | Hard-code Windows driver name | Require `driver:` as a YAML config key; document `odbc::odbcListDrivers()` for discovery |
| SQL DATE → R | Assume same behavior as DATETIME | Explicitly coerce `as.Date()` after every `dbGetQuery()` |
| YAML `yes`/`no` | Expect string, receive logical TRUE/FALSE | Type-validate every config value immediately after `yaml::read_yaml()` |
| Missing YAML key | Expect error, receive NULL | `validate_creel_config()` checks all required keys before any connection attempt |
| Excel CSV → column names | First column has BOM prefix | `readr::read_csv()` + defensive `gsub("^\xef\xbb\xbf", "", names(df))` |
| Species codes in CSV | Expect character, readr guesses integer | Always pass `col_types` to `read_csv()` for all identifier columns |
| tidycreel.connect → tidycreel | Use `:::` for internal schema access | Export `creel_schema` as public API; use `@importFrom` |
| DBI S4 dispatch | Register methods as S3 | Use `setClass()` / `setMethod()` throughout; `methods` in `Imports:` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Fetching all columns from wide interview view | Slow query on large NGPC databases (interview view has 60+ supplemental columns) | Add `columns:` projection to `fetch_interviews()` — only select columns needed by tidycreel | Any survey with 10K+ interviews on slow VPN |
| Reading entire multi-year CSV at once | Long startup, large memory use | Document that flat file backend expects per-season files; add `year` filter arg | CSVs with 50K+ rows |
| `odbc::dbFetch()` with no `n` argument | Unbounded result set on large tables | Use `dbGetQuery()` with `WHERE` clause; document that `fetch_*()` functions accept a date range filter | Tables with historical multi-year data |

---

## "Looks Done But Isn't" Checklist

- [ ] **SQL Server backend:** `cd_Date` returns as R `Date` class, not `character` — verify `is(fetched$cd_Date, "Date")` in test, not just `!is.null()`
- [ ] **SQL Server backend:** Connection test covers macOS with unixODBC, not just Windows — verify CI matrix
- [ ] **YAML validation:** Config with a missing required key fails at load time with a message that names the missing key — verify with a negative test
- [ ] **YAML validation:** Config with `trusted_connection: yes` (unquoted) raises a type error, not a silent TRUE — verify with a type-check test
- [ ] **Credentials:** `creel_connect()` prefers env vars for uid/pwd and warns when credentials are found in YAML — verify warning is emitted in test
- [ ] **Flat file backend:** Column name BOM-strip is applied after `read_csv()` — verify with a BOM-containing fixture file
- [ ] **Flat file backend:** Species code `"01"` reads back as `"01"` (character), not `1L` — verify with a leading-zero fixture
- [ ] **S3 contract:** `class(fetch_interviews(...))[1]` is `"tbl_df"`, not `"creel_schema"` or any new class — verify existing `add_interviews()` tests still pass with loaded data
- [ ] **Companion package:** `odbc` is in `Suggests:`, not `Imports:` — verify `DESCRIPTION`; flat file backend tests pass without `odbc` installed
- [ ] **DBI backend:** All DBI methods use `setMethod()` (S4), not S3 dispatch — verify NAMESPACE has `exportMethods()` not `S3method()`
- [ ] **Connection lifecycle:** Every test that opens a connection uses `on.exit(DBI::dbDisconnect(con), add = TRUE)` or `withr::local_db_connection()` — verify no leaked connections in CI

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Hard-coded driver name shipped to users | MEDIUM — patch release needed | Make `driver` a required YAML config key; add `creel_check_driver()` diagnostic; update README |
| SQL DATE returning as character reaches downstream estimators | HIGH — silent type errors in all date-based estimates | Add coercion layer to all `fetch_*()` functions; add type-check tests; patch release |
| YAML type coercion corrupts connection string values | MEDIUM — add `validate_creel_config()` as patch; no data loss | Type-validate all keys; add negative-test suite |
| Plain-text credentials in committed YAML example | HIGH — credential rotation required; git history audit | Rotate credentials; rewrite README with env-var pattern; `git filter-repo` to scrub history |
| `odbc` in `Imports:` prevents flat-file-only install | LOW — move to `Suggests:`; wrap with runtime check | Update DESCRIPTION; add `rlang::check_installed()`; patch release |
| `:::` usage in companion package caught by CRAN check | MEDIUM — must export `creel_schema` constructor as public API | Export constructor; update companion package `@importFrom`; resubmit |
| BOM corruption of CSV column names in production | MEDIUM — data loads but joins fail silently | Add BOM-strip; add BOM fixture test; patch release |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| DB-1: Platform ODBC driver name mismatch | `creel_connect()` implementation phase | CI matrix includes macOS; `driver:` is required config key |
| DB-2: Windows auth fails on macOS/Linux | YAML config schema phase | Platform guard in `creel_connect()`; negative test on macOS |
| DB-3: Connection leaks in tests | SQL Server backend phase (test infra) | All tests use `on.exit(dbDisconnect)` or `withr::local_db_connection()` |
| DB-4: SQL DATE returns as character | `fetch_*()` loader phase | `is(result$cd_Date, "Date")` assertion in test |
| DB-5: DATETIMEOFFSET returns as unparseable string | `fetch_*()` loader phase | Timestamp fixture with timezone offset parses correctly |
| DB-6: VARCHAR encoding corruption | `fetch_*()` loader phase | Non-ASCII character in test fixture round-trips correctly |
| YML-1: Implicit YAML type coercion | YAML config schema phase | Negative test: `trusted_connection: yes` raises type error |
| YML-2: Missing required keys produce NULL | YAML config schema phase | Negative test: missing `server:` fails at config validation, not connection |
| YML-3: Plain-text credentials in YAML | YAML config schema phase (first decision) | `creel_connect()` warns when uid/pwd in config; env vars documented first |
| S3-1: creel_schema class on data frames breaks existing API | `creel_schema` design phase | Existing `add_interviews()` test suite passes with `fetch_*()` output |
| S3-2: S3 vs S4 DBI dispatch confusion | Companion package skeleton phase | NAMESPACE has `exportMethods()`; R CMD check 0 NOTEs |
| S3-3: `odbc` in `Imports:` | Companion package skeleton phase | `DESCRIPTION` check; flat file tests pass without `odbc` |
| S3-4: Circular dependency via `:::` | `creel_schema` design phase | No `:::` in companion package; `creel_schema` exported from tidycreel |
| FF-1: Column name variants in user CSVs | `creel_schema` design phase | Column mapping in YAML tested with renamed fixture |
| FF-2: UTF-8 BOM corrupts first column name | Flat file backend phase | BOM-containing fixture reads clean column names |
| FF-3: readr type guessing misclassifies codes | Flat file backend phase | Leading-zero species code and zip code read as character |

---

## Sources

- [r-dbi/odbc GitHub issue #11: DATE column type is Character](https://github.com/r-dbi/odbc/issues/11) — DB-4 primary source
- [r-dbi/odbc GitHub issue #61: dbGetQuery Dates as Characters SQL Server](https://github.com/r-dbi/odbc/issues/61) — DB-4 corroboration
- [r-dbi/odbc GitHub issue #207: datetimeoffset unsupported](https://github.com/r-dbi/odbc/issues/207) — DB-5 primary source
- [r-dbi/odbc GitHub issue #437: odbc returns garbaged letters for varchar](https://github.com/r-dbi/odbc/issues/437) — DB-6 primary source
- [r-dbi/odbc GitHub issue #474: ODBC Driver 17 for SQL Server file not found M1 Mac](https://github.com/r-dbi/odbc/issues/474) — DB-1 ARM64 evidence
- [Microsoft Learn: Install Microsoft ODBC Driver for SQL Server (macOS)](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/install-microsoft-odbc-driver-sql-server-macos) — DB-1 ARM64 support confirmation (17.8+)
- [Microsoft Learn: Using Integrated Authentication — ODBC Driver for SQL Server](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication) — DB-2 platform limitation
- [Microsoft Learn: Known Issues in the ODBC Driver on Linux and macOS](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/known-issues-in-this-version-of-the-driver) — DB-1, DB-2 authoritative
- [odbc package: Installing and Configuring Drivers](https://odbc.r-dbi.org/articles/setup.html) — DB-1 driver discovery via `odbcListDrivers()`
- [tidyverse/readr GitHub issue #500: Files encoded with UTF-8 BOM not supported](https://github.com/tidyverse/readr/issues/500) — FF-2 primary source
- [tidyverse/readr GitHub issue #263: Support for UTF-8-BOM](https://github.com/tidyverse/readr/issues/263) — FF-2 corroboration
- [yaml12: YAML 1.2 for R — Tidyverse blog, January 2026](https://tidyverse.org/blog/2026/01/yaml12-0-1-0/) — YML-1 YAML 1.1 implicit coercion behavior confirmed
- [R Packages (2e): Dependencies in Practice](https://r-pkgs.org/dependencies-in-practice.html) — S3-3 Imports vs. Suggests; conditional `requireNamespace()` pattern
- [DBI: Implementing a new backend](https://dbi.r-dbi.org/articles/backend.html) — S3-2 S4 dispatch requirement
- [Advanced R: S3](https://adv-r.hadley.nz/s3.html) — S3-1 class contract and breaking change risks
- [Epiverse-TRACE: Convert Your R Function to an S3 Generic — Pitfalls](https://epiverse-trace.github.io/posts/s3-generic/) — S3-1 class method dispatch conflicts
- [GitGuardian: Remediating ODBC Connection String Leaks](https://www.gitguardian.com/remediation/odbc-connection-string) — YML-3 credential exposure in version control

---
*Pitfalls research for: tidycreel v1.3.0 — Generic DB Interface (creel_schema S3 + tidycreel.connect companion package)*
*Researched: 2026-04-06*
