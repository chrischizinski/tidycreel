# Stack Research

**Domain:** R package — DB interface / companion package for creel survey data loading (v1.3.0)
**Researched:** 2026-04-06
**Confidence:** HIGH (DBI/odbc ecosystem versions verified on CRAN), HIGH (yaml/readr versions verified), MEDIUM (companion package S3 dispatch pattern — ecosystem standard but no authoritative single source)

---

## Context: Existing tidycreel Imports (do NOT re-add)

Already in `DESCRIPTION` Imports — zero additions needed for these in tidycreel itself:

| Package | Role |
|---------|------|
| checkmate | Input validation (`assert_*`) |
| cli | User-facing messages (`cli_abort`, `cli_warn`) |
| dplyr | Tidy data manipulation |
| lubridate | Date arithmetic |
| rlang | NSE / tidy eval, `abort()` conditions |
| scales | Formatting helpers |
| stats | Base R stats |
| survey | Design-based inference |
| tibble | Tibble construction |
| tidyselect | Tidy column selectors |

---

## Part 1: tidycreel (creel_schema S3 contract additions)

### No New Imports Required

The `creel_schema` S3 class is a pure data-structure contract — a named list with column maps, table identity, survey type tag, and version string. All constructor and validation logic uses packages already in Imports.

| Existing Import | Role in creel_schema |
|-----------------|----------------------|
| checkmate | `assert_names()`, `assert_subset()`, `assert_string()` in `validate_creel_schema()` |
| cli | `cli_abort()` with bulleted field lists for invalid column maps |
| rlang | `abort()` with classed conditions for programmatic error handling |

**S3 pattern to follow** (consistent with existing `creel_design`, `creel_estimates`, `creel_schedule`):

- `new_creel_schema()` — low-level constructor, minimal checks, assigns class
- `validate_creel_schema()` — full validation (column completeness, type checks, survey_type membership)
- `creel_schema()` — user-facing helper that calls both

No new `Imports` entries needed in tidycreel for this feature.

---

## Part 2: tidycreel.connect (new companion package)

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| DBI | >= 1.3.0 | Generic DB interface: `dbConnect()`, `dbGetQuery()`, `dbDisconnect()` | The canonical R DB abstraction layer; every DBMS backend implements it; version 1.3.0 released 2026-02-25; lets `creel_connect()` return a standard `DBIConnection` object so loaders are backend-agnostic |
| odbc | >= 1.6.4 | SQL Server ODBC driver backend for DBI | Current CRAN 1.6.4 (2025-12-06); DBI-compliant; ~10x faster than RODBC for bulk reads (C++ nanodbc backend); only actively maintained DBI-compliant SQL Server driver; RODBC is legacy and non-DBI-compliant |
| yaml | >= 2.3.12 | YAML config file parsing for connection and schema definitions | Current CRAN 2.3.12 (2025-12); `yaml::read_yaml()` returns a named list that maps naturally to `creel_schema` column-map structure; wraps libyaml (fast C parser); lightweight (0 R deps beyond base); no hidden filename conventions |
| readr | >= 2.1.6 | Flat file / CSV backend loader | Current CRAN 2.1.6 (2026-02-19); uses vroom engine internally for fast lazy indexing; returns tibbles compatible with tidycreel's tidy API; `cols()` spec enforces expected column types at read time |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dplyr | >= 1.1.0 | Column renaming (`rename_with()`), type coercion after load | `fetch_*()` applies column map from `creel_schema` to raw DB/CSV column names |
| tibble | >= 3.2.0 | `as_tibble()` for consistent return type from all `fetch_*()` | Companion package must match tidycreel's return contract (all data frames are tibbles) |
| cli | >= 3.6.0 | User-facing errors for missing config keys, connection failures, schema mismatches | `cli_abort()` with context; consistent error style with tidycreel |
| rlang | >= 1.1.0 | `abort()` with classed conditions | Lets downstream users catch `creel_connect_error` conditions programmatically |
| checkmate | >= 2.1.0 | Config list validation after YAML parse | `assert_list()`, `assert_string()` on parsed YAML before `creel_connect()` attempts connection |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| usethis | Package scaffolding: `create_package()`, `use_package()`, `use_testthat()` | Bootstrap companion package structure; sets up DESCRIPTION with correct Imports |
| testthat >= 3.0.0 | Unit and integration tests | Use RSQLite as CI test backend; mock SQL Server |
| RSQLite >= 2.3.0 (Suggests) | In-memory SQLite for CI tests | Lightweight DBI backend; spin up a test DB matching expected creel schema without SQL Server access; never Imports |
| withr >= 2.5.0 (Suggests) | Temporary files and env vars in tests | `withr::local_tempfile()` for flat-file backend tests; `withr::local_envvar()` for credential tests |
| mockery >= 0.4.4 (Suggests) | Mock `dbConnect()` / `dbGetQuery()` | Use sparingly — RSQLite is preferable when possible |

---

## Installation (tidycreel.connect bootstrap)

```r
# Bootstrap companion package
usethis::create_package("tidycreel.connect")

# Core Imports
usethis::use_package("DBI",       min_version = "1.3.0")
usethis::use_package("odbc",      min_version = "1.6.4")
usethis::use_package("yaml",      min_version = "2.3.12")
usethis::use_package("readr",     min_version = "2.1.6")
usethis::use_package("dplyr",     min_version = "1.1.0")
usethis::use_package("tibble",    min_version = "3.2.0")
usethis::use_package("cli",       min_version = "3.6.0")
usethis::use_package("rlang",     min_version = "1.1.0")
usethis::use_package("checkmate", min_version = "2.1.0")

# Suggests (test + dev only)
usethis::use_package("RSQLite",  type = "Suggests")
usethis::use_package("withr",    type = "Suggests")
usethis::use_package("mockery",  type = "Suggests")
usethis::use_package("testthat", min_version = "3.0.0", type = "Suggests")
usethis::use_package("tidycreel", min_version = "1.3.0")  # declare dependency on parent
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| odbc | RODBC | Never for new code; RODBC is not DBI-compliant, returns plain data.frames not tibbles, no `dbGetQuery()` generics. Document as known alternative for users locked to legacy Windows RODBC installs, but do not support in tidycreel.connect |
| odbc | RPostgres / RMariaDB | Only if expanding beyond SQL Server to other DBMS; `creel_connect()` S3 dispatch accommodates them later without API change |
| yaml | config (rstudio/config) | Use `config` only if tidycreel.connect needs multi-environment profile switching (dev/prod/test YAML inheritance). For a static schema YAML defining column maps and connection params, `yaml` is simpler with no hidden `config.yml` filename convention to explain to users |
| yaml | configr | Never; last meaningful update ~2019 despite CRAN presence; inconsistent YAML/JSON edge cases reported |
| readr | vroom (direct) | `readr 2.1.6` already uses vroom's engine for `read_csv()` / `read_tsv()`; direct vroom dependency is redundant. Only add vroom directly if `vroom_fwf()` for fixed-width files is needed — not in current scope |
| readr | data.table::fread | Only if flat files grow to millions of rows AND tibble output is acceptable after coercion. Creel flat files are typically < 50k rows; readr performance is sufficient and output type is already tibble |
| DBI::dbGetQuery() | dbplyr | dbplyr translates dplyr verbs to SQL for lazy remote queries — correct for data exploration, wrong here. `fetch_*()` loaders run fixed known SQL against NGPC view names defined in the schema; using dbplyr couples loaders to dplyr's SQL translation layer without benefit |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| RODBC | Not DBI-compliant; returns data.frames not tibbles; being superseded; no `dbGetQuery()` interface | `DBI` + `odbc` |
| configr | Unmaintained since ~2019; inconsistent parsing edge cases | `yaml::read_yaml()` |
| dbplyr in fetch_*() | Adds lazy-query overhead to fixed-SQL loaders; misleads users into thinking queries are composable when they are not | `DBI::dbGetQuery()` with explicit SQL strings |
| httr2 / REST API calls | Explicitly out of scope per PROJECT.md ("Real-time/online data pull from creel API — package is data-model agnostic") | Flat file or direct ODBC |
| pool | Connection pooling for long-running Shiny apps; creel analysis is script-based | `DBI::dbConnect()` + explicit `on.exit(DBI::dbDisconnect())` |

---

## Stack Patterns by Variant

**SQL Server backend:**
- `creel_connect(config, backend = "sqlserver")` calls `DBI::dbConnect(odbc::odbc(), ...)` with server/database/driver from parsed YAML
- `fetch_interviews()` etc. call `DBI::dbGetQuery(conn, sql)` using view names from `creel_schema$table_map`
- Returns `creel_sqlserver_connection` S3 object containing the `DBIConnection` + `creel_schema`

**Flat file backend:**
- `creel_connect(config, backend = "flatfile")` resolves file paths from YAML; no actual DB connection opened
- `fetch_interviews()` calls `readr::read_csv(path, col_types = ...)` with types inferred from `creel_schema`
- Returns `creel_flatfile_connection` S3 object containing file paths + `creel_schema` (no `DBIConnection`)

**S3 dispatch pattern for `fetch_*()` — use this, not `if (backend == ...)` branching:**

```r
fetch_interviews <- function(conn, ...) {
  UseMethod("fetch_interviews")
}

fetch_interviews.creel_sqlserver_connection <- function(conn, ...) {
  DBI::dbGetQuery(conn$connection,
    sprintf("SELECT * FROM %s", conn$schema$table_map[["interviews"]]))
}

fetch_interviews.creel_flatfile_connection <- function(conn, ...) {
  readr::read_csv(conn$paths[["interviews"]],
    col_types = build_col_spec(conn$schema, "interviews"))
}
```

This is idiomatic R — no branching inside every loader, each backend is independently testable.

---

## Integration with Existing tidycreel API

`creel_schema` in tidycreel is the translation contract:

| Field | Type | Content |
|-------|------|---------|
| `$column_map` | named character vector | canonical name → actual DB/file column name |
| `$table_map` | named character vector | canonical table name → actual view/file name |
| `$survey_type` | string | one of: `instantaneous`, `bus_route`, `ice`, `camera`, `aerial` |
| `$version` | string | schema version for forward compatibility |

`fetch_*()` in tidycreel.connect reads raw DB/file columns and renames to canonical names using `creel_schema$column_map`. The returned tibble has the same column names that `add_interviews()`, `add_counts()`, `add_catch()`, `add_lengths()` already expect — zero API change in tidycreel.

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| DBI 1.3.0 | odbc 1.6.4 | odbc implements DBI generics; tested combination; no known incompatibility |
| odbc 1.6.4 | R >= 4.1.0 | Matches tidycreel's existing `Depends: R (>= 4.1.0)` |
| readr 2.1.6 | R >= 4.1.0 | vroom engine requires R >= 3.6; 4.1.0 is fine |
| yaml 2.3.12 | R >= 3.0.0 | No conflict with any existing tidycreel dep |
| RSQLite (test only) | DBI 1.3.0 | RSQLite is the canonical DBI test backend; maintained by r-dbi team |

---

## Sources

- [DBI 1.3.0 CRAN page](https://cran.r-project.org/package=DBI) — version 1.3.0 confirmed 2026-02-25. HIGH confidence.
- [odbc 1.6.4 CRAN page](https://cran.r-project.org/web/packages/odbc/index.html) — version 1.6.4 confirmed 2025-12-06. HIGH confidence.
- [odbc official site](https://odbc.r-dbi.org/) — DBI compliance, SQL Server connection pattern, performance vs RODBC confirmed. HIGH confidence.
- [Posit Solutions: Using an ODBC driver](https://solutions.posit.co/connections/db/r-packages/odbc/) — SQL Server connection code pattern. HIGH confidence.
- [yaml 2.3.12 CRAN page](https://cran.r-project.org/package=yaml) — version 2.3.12 confirmed December 2025. HIGH confidence.
- [readr 2.1.6 CRAN page](https://cran.r-project.org/package=readr) — version 2.1.6 confirmed 2026-02-19. HIGH confidence.
- [dbplyr new-backend vignette](https://dbplyr.tidyverse.org/articles/new-backend.html) — confirmed dbplyr is for lazy SQL translation, not fixed-SQL loaders. MEDIUM confidence (architecture decision).
- [rstudio/config GitHub](https://github.com/rstudio/config) — confirmed config package is environment-switching focused, not schema-definition focused. MEDIUM confidence.
- [pool 1.0.4 CRAN page](https://cran.r-project.org/web/packages/pool/pool.pdf) — version 1.0.4 July 2025; confirmed pool is Shiny-oriented connection management, not needed for analysis scripts. HIGH confidence.
- [RODBC CRAN page](https://cran.r-project.org/package=RODBC) — version 1.3-26.1 December 2025; confirmed non-DBI-compliant interface. HIGH confidence.
- WebSearch: odbc vs RODBC performance — MEDIUM confidence (multiple concordant sources; benchmark at odbc.r-dbi.org authoritative).

---
*Stack research for: tidycreel v1.3.0 Generic DB Interface (creel_schema S3 + tidycreel.connect)*
*Researched: 2026-04-06*
