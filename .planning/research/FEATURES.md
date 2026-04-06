# Feature Research

**Domain:** Config-driven DB loader with schema-column mapping for an R domain estimation package (tidycreel v1.3.0)
**Researched:** 2026-04-06
**Confidence:** HIGH for DBI/S3 ecosystem patterns (well-documented in official sources); MEDIUM for specific design decisions around creel_schema contract (no direct precedent; derived from CDMConnector + OHDSI OMOP patterns)

---

## Background: What This Milestone Is

tidycreel v1.3.0 splits the existing monolith into two concerns:

1. **`creel_schema` S3 class** (lives in `tidycreel`) — a portable contract object that carries: a named column-mapping vector (raw DB names → tidycreel canonical names), table identity strings (view/table names per backend), a survey_type tag, and validation rules checked at load time.

2. **`tidycreel.connect` companion package** — wraps a DBI connection (or CSV path) behind `creel_connect()`, providing `fetch_*()` loaders that apply the `creel_schema` contract and return data already renamed and validated so it can be handed directly to `creel_design()`.

The closest ecosystem precedents are:
- **CDMConnector** (OMOP CDM) — named list of lazy table references behind a `cdm_reference` S3 object; schema/table mapping via `cdmSchema` argument; `validate_cdm()` for structural checks
- **OHDSI DatabaseConnector** — uniform DBI-like surface across SQL Server, PostgreSQL, Oracle; SqlRender for dialect translation
- **easydb** — YAML config → `dbcnf` object → pipeline of `db_*()` functions with pipe-chaining
- **rstudio/config** — `config.yml` with `default:` block and `!expr Sys.getenv()` for credential injection; `config::get()` accessor

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features any R data-access companion package must provide. Missing these makes the package feel incomplete relative to CDMConnector, DatabaseConnector, and easydb.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `creel_schema()` constructor | Every domain package with DB integration needs a schema contract object; CDMConnector uses `cdm_reference`, OMOP uses `omop_cdm`; users expect to instantiate one and pass it around | MEDIUM | Returns an S3 object of class `creel_schema`; slots: `col_map` (named character vector, raw→canonical), `table_map` (named character vector, canonical_table→view_name), `survey_type`, `backend` tag; uses `new_creel_schema()` + `validate_creel_schema()` pattern per Wickham AdvR §13 |
| `validate_creel_schema()` | Column mapping and table identity must be verified before any data fetch; CDMConnector's `validate_cdm()` is the ecosystem precedent | LOW | Checks: all required canonical columns present in `col_map`; all required tables present in `table_map`; `survey_type` is one of the five tidycreel types; no duplicate raw names; returns structured list of pass/warn/fail items |
| `creel_connect()` constructor | Users need a single call to bind a connection to a schema contract; equivalent to `cdmFromCon()` in CDMConnector; both raw DBI and flat-file paths should work through the same interface | MEDIUM | Accepts: DBI connection OR directory path (flat-file), a `creel_schema` object; returns `creel_connection` S3 object; backend is tagged automatically (sql_server, flat_file); re-validates schema at construction |
| YAML config loading (`creel_connect_from_yaml()`) | The easydb and rstudio/config patterns show users expect YAML to replace argument lists for credentials and table names; config files also enable environment-specific production vs. test credentials | MEDIUM | Reads `creel.yml` via `yaml::read_yaml()`; top-level keys: `backend:`, `connection:`, `tables:`, `column_map:`, `survey_type:`; `!r` or raw R expressions evaluated for credentials (matching `config::get()` `!expr` convention); returns `creel_connection` object same as `creel_connect()` |
| `fetch_interviews()` | Interviews is the primary analysis table; every existing `add_interviews()` call needs this data; users expect a direct named fetch | MEDIUM | Queries the `interviews` view/table; applies `col_map` rename; returns a plain `tibble`; no class attached — output goes directly into `add_interviews()`; validates required canonical columns present after rename |
| `fetch_counts()` | Instantaneous counts drive effort estimation; missing this breaks the estimation pipeline | MEDIUM | Same pattern as `fetch_interviews()`; queries counts view; renames via `col_map`; validates required columns |
| `fetch_catch()` | Catch is a separate long-format table; required for `add_catch()` | MEDIUM | Same pattern; long format (one row per species per interview) is the expected output shape |
| `fetch_harvest_lengths()` | Individual fish lengths; required for `add_lengths(harvest_lengths = ...)` | MEDIUM | One row per fish format; individual length column required |
| `fetch_release_lengths()` | Release lengths; both individual and binned formats exist in NGPC DB; `add_lengths()` handles both | MEDIUM | Both individual and binned formats must work; detect format automatically and pass through as-is (format detection is already in `add_lengths()`) |
| SQL Server backend | NGPC production database is SQL Server; without this backend the package is useless for the primary user | HIGH | Uses `odbc::odbc()` + Windows Authentication (Trusted_Connection=yes) as the default NGPC connection mode; `DBI::dbGetQuery()` for fetch; view names are the NGPC defaults but overridable via `table_map` |
| Flat-file / CSV backend | Users working outside NGPC (other agencies, academic) will have CSV files; a flat-file backend makes the package viable as a general-purpose tool | MEDIUM | Uses `readr::read_csv()` or `data.table::fread()` for each table; `table_map` maps canonical table names to file paths; column rename applied identically to SQL backend |

### Differentiators (Competitive Advantage)

Features that go beyond what agencies currently do (hand-crafted SQL queries, `RODBC::sqlQuery()` calls, legacy `CreelDataAccess.R` scripts) or what CRAN creel packages offer.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Schema portability — `creel_schema` travels with data | NGPC users can pass a `creel_schema` object to collaborators who have the same DB structure; they instantiate a `creel_connection` and the fetch just works; no environment-specific column renaming in analysis scripts | MEDIUM | `creel_schema` is a plain named-list S3 object with no connection state; serializable with `saveRDS()`; can be shipped as package-level data (e.g., `ngpc_schema`) |
| Built-in NGPC default schema | Providing `ngpc_default_schema()` as a built-in creel_schema removes all boilerplate for the primary user group; they call `creel_connect(con, ngpc_default_schema())` and fetch immediately | LOW | Hard-codes the NGPC view names and column name mappings documented in PROJECT.md; wrap in `ngpc_default_schema()` constructor; update path when NGPC view names change |
| Survey type tagging propagates through fetch | Every `fetch_*()` call knows the survey type from the `creel_schema`; returned tibble carries a `.survey_type` attribute; `creel_design()` can use it for dispatch without the user re-specifying | LOW | `.survey_type` attr is set on the tibble returned by each `fetch_*()`; does not add a column (avoids polluting data); consistent with existing R package pattern of S3 attributes as metadata |
| Validation on load, not at estimation time | Column validation at `fetch_*()` time produces a clear error message ("column `cd_Period` not found in col_map for table interviews") before the user is deep in an estimation call; better UX than a cryptic dplyr error 10 calls later | MEDIUM | `validate_fetch_result()` internal helper; checks required canonical columns present after rename; uses `cli_abort()` with column-level detail; consistent with existing tidycreel guard patterns |
| DuckDB flat-file path via `duckdb::duckdb_read_csv()` | DuckDB provides high-performance CSV reading with SQL query support; for large flat files it is substantially faster than `readr::read_csv()` and enables the same `DBI::dbGetQuery()` code path as SQL Server | MEDIUM (optional) | DuckDB in `Suggests`; use only when `backend = "duckdb_csv"`; enables SELECT/WHERE on flat files without loading the whole table; avoids a separate code path for large-file users |
| `print.creel_schema()` | Users need to inspect the schema before connecting; a structured print method showing survey_type, backend, table_map, and col_map summary is expected given tidycreel already has `print.creel_schedule()` | LOW | Shows: survey_type, backend, n tables in table_map, n columns in col_map; lists tables with canonical vs. mapped names; uses cli formatting consistent with tidycreel conventions |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Auto-discover column mapping from DB | Users want zero-configuration setup; "just connect and it works" | Column names vary between NGPC instances and other agency DBs; auto-discovery builds in assumptions that break silently on schema drift; defeats the purpose of the explicit `creel_schema` contract | Provide `ngpc_default_schema()` for the common case; make the mapping explicit and versioned so schema changes are caught at validation time, not estimation time |
| Credential storage in YAML | Convenience — one file with everything | Plain-text passwords in config files get committed to git; CRAN policy and security best practices both discourage it | Accept `!expr Sys.getenv("DB_PASSWORD")` and `!expr keyring::key_get("creel_db")` in YAML; document both approaches; never store literal passwords |
| `fetch_all()` mega-loader | One call to get all tables at once | Hides which tables are actually needed; pulls large length tables even for effort-only analyses; makes it impossible to add pre-fetch filters per table | Keep fetch functions separate; document the sequence `fetch_interviews() |> add_interviews()`, etc.; a wrapper is easy to write in user code |
| dbplyr / lazy evaluation for fetch | Familiar tidyverse pattern; "work at scale without loading into memory" | Creel analysis requires all data in memory for `survey::svydesign()`; lazy tables have no path to `creel_design()`; adds `dbplyr` dependency for no benefit; CDMConnector uses lazy eval because OMOP datasets are orders of magnitude larger than creel surveys | Use `DBI::dbGetQuery()` → `collect()` immediately; creel datasets (hundreds to thousands of rows) fit in memory trivially; keep the fetch simple |
| REST API backend | NGPC has a REST endpoint; some users will ask for it | REST authentication changes without notice; paging logic is fragile; the existing `CreelApiHelper.R` is already maintained separately; adding REST to `tidycreel.connect` creates a maintenance surface that competes with a dedicated API wrapper | Document that REST users should pull data with their existing `CreelApiHelper.R` and supply the resulting data frame to `add_interviews()` etc. directly |
| Multiple language / DBMS SQL dialect translation (SqlRender approach) | Portability across Oracle, PostgreSQL, SQL Server | NGPC is SQL Server; the only other backend needed is flat file; dialect translation (a la OHDSI SqlRender) is overkill for two backends; adds a Java dependency (RJDBC) or a translation layer | SQL Server via `odbc`; CSV/flat-file via `readr`; two backends, two code paths, no translation layer needed |
| S4 or R5/R6 class for `creel_schema` | R6 provides reference semantics and active bindings for "live" schema objects | S3 is sufficient for a stateless contract object; reference semantics add complexity without benefit when the schema does not change after construction; inconsistent with the rest of tidycreel (all S3) | Plain S3 list with `new_creel_schema()` + `validate_creel_schema()` per Wickham AdvR pattern; attributes carry all metadata; class vector enables dispatch |

---

## Feature Dependencies

```
[ngpc_default_schema()]
    └──produces──> [creel_schema S3 object]
                       └──validates via──> [validate_creel_schema()]
                       └──required by──> [creel_connect()]
                       └──required by──> [creel_connect_from_yaml()]

[creel_connect() / creel_connect_from_yaml()]
    └──produces──> [creel_connection S3 object]
                       └──required by──> [fetch_interviews()]
                       └──required by──> [fetch_counts()]
                       └──required by──> [fetch_catch()]
                       └──required by──> [fetch_harvest_lengths()]
                       └──required by──> [fetch_release_lengths()]

[fetch_interviews()]  ── tibble ──> [add_interviews()]  (existing tidycreel API)
[fetch_counts()]      ── tibble ──> [add_counts()]      (existing tidycreel API)
[fetch_catch()]       ── tibble ──> [add_catch()]       (existing tidycreel API)
[fetch_harvest_lengths()]   ── tibble ──> [add_lengths()]  (existing tidycreel API)
[fetch_release_lengths()]   ── tibble ──> [add_lengths()]  (existing tidycreel API)

[creel_schema col_map]  ── rename ──> [all fetch_*() outputs]
[creel_schema table_map] ── view name resolution ──> [all fetch_*() SQL queries]
[creel_schema survey_type] ── .survey_type attr ──> [all fetch_*() tibble outputs]

[validate_creel_schema()]  ── prerequisite ──> [creel_connect()]
[validate_fetch_result()]  ── postcondition ──> [fetch_*() return value]
```

### Dependency Notes

- **`creel_schema` is stateless and must exist before any connection:** It carries no DB credentials or connection state. It is the schema contract, not the connection. Construction order is always: schema first, then connection.
- **`creel_connect()` validates the schema at construction time:** This is the correct place for the DBI table existence check (`DBI::dbExistsTable()`), not at fetch time, consistent with CDMConnector's `cdmFromCon()` approach.
- **All `fetch_*()` functions depend on `col_map` from the schema:** The rename step (`dplyr::rename_with()` or `setNames()`) is the only place column translation happens. Downstream tidycreel functions (`add_interviews()` etc.) must not know about or accept raw DB column names.
- **`add_interviews()` / `add_counts()` / `add_catch()` / `add_lengths()` are unchanged:** v1.3.0 adds a data loading layer in front of the existing estimation API. The existing API must not require modification to accept `fetch_*()` output. If columns in the fetch output do not match what `add_interviews()` expects, the `col_map` is wrong — fix it in the schema, not in `add_interviews()`.
- **Flat-file and SQL backends share the same `fetch_*()` function signatures:** Backend dispatch happens inside `fetch_*()` via the `backend` tag on the `creel_connection`; the user sees the same API regardless.

---

## MVP Definition

### Launch With (v1.3.0)

Minimum that enables a complete NGPC workflow: connect → fetch all five tables → pipe into `creel_design()`.

- [ ] `creel_schema` S3 class with `new_creel_schema()` + `validate_creel_schema()` in tidycreel core — without the schema contract, the companion package has no anchor
- [ ] `ngpc_default_schema()` convenience constructor — primary user group needs zero-configuration path
- [ ] `creel_connect()` accepting a DBI connection + `creel_schema` — fundamental entry point for SQL Server users
- [ ] `fetch_interviews()` — primary analysis table; estimation pipeline is blocked without it
- [ ] `fetch_counts()` — effort estimation blocked without it
- [ ] `fetch_catch()` — catch/harvest/release estimation blocked without it
- [ ] `fetch_harvest_lengths()` — length analysis blocked without it
- [ ] `fetch_release_lengths()` — release length analysis blocked without it
- [ ] SQL Server backend via `odbc::odbc()` with Windows Authentication — NGPC production requirement
- [ ] Flat-file / CSV backend via `readr::read_csv()` — general-purpose viability; also needed for testing without a live DB

### Add After Validation (v1.3.x)

Features to add once the core fetch-and-rename loop is confirmed working.

- [ ] `creel_connect_from_yaml()` — reduces boilerplate; add once core API is stable and YAML schema is defined from real usage
- [ ] `print.creel_schema()` / `print.creel_connection()` — polish; add once classes are stable
- [ ] DuckDB flat-file backend — performance optimization; add only if users report CSV loading is slow
- [ ] Survey type tagging via `.survey_type` attribute on `fetch_*()` output — convenience feature; add after core fetch path is validated

### Future Consideration (v2+)

- [ ] Additional agency schemas (Wisconsin DNR, Minnesota DNR) — defer; requires those agencies to contribute or confirm their column names
- [ ] Schema versioning (creel_schema v1 vs v2) — defer; premature until schema drift is observed in practice
- [ ] `creel_schema` export to YAML (round-trip serialization) — defer; useful for sharing schemas but not needed for core workflow

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `creel_schema` S3 class + constructor + validator | HIGH | MEDIUM | P1 |
| `ngpc_default_schema()` | HIGH | LOW | P1 |
| `creel_connect()` — SQL Server + flat file | HIGH | MEDIUM | P1 |
| `fetch_interviews()` | HIGH | LOW | P1 |
| `fetch_counts()` | HIGH | LOW | P1 |
| `fetch_catch()` | HIGH | LOW | P1 |
| `fetch_harvest_lengths()` | HIGH | LOW | P1 |
| `fetch_release_lengths()` | HIGH | LOW | P1 |
| Validation on load (`validate_fetch_result()`) | HIGH | LOW | P1 |
| `creel_connect_from_yaml()` | MEDIUM | MEDIUM | P2 |
| `print.creel_schema()` / `print.creel_connection()` | MEDIUM | LOW | P2 |
| Survey type tag on `fetch_*()` output | LOW | LOW | P2 |
| DuckDB flat-file backend | LOW | MEDIUM | P3 |
| Additional agency default schemas | MEDIUM | LOW (per schema) | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Ecosystem Pattern Analysis

### CDMConnector Pattern (OMOP Common Data Model) — PRIMARY REFERENCE

CDMConnector is the closest ecosystem precedent. Key patterns to adopt:

| Pattern | CDMConnector | tidycreel.connect adaptation |
|---------|--------------|------------------------------|
| Connection constructor | `cdmFromCon(con, cdmSchema, writeSchema, cdmName)` | `creel_connect(con, schema)` — no write schema needed |
| Schema object | `cdm_reference` S3 (named list of lazy tbls + metadata) | `creel_connection` S3 (DBI connection + creel_schema + backend tag) |
| Table access | `cdm$person`, `cdm$observation` via `$` | `fetch_interviews(conn)`, `fetch_counts(conn)` via explicit functions |
| Validation | `validate_cdm()` returns structured report | `validate_creel_schema()` returns pass/warn/fail list |
| Multi-backend | DuckDB, PostgreSQL, SQL Server, Snowflake, Redshift | SQL Server, flat file (DuckDB optional) |
| Lazy vs. eager | Lazy — designed for million-row clinical datasets | Eager — creel datasets are small; `DBI::dbGetQuery()` immediately |

Key divergence from CDMConnector: tidycreel.connect uses **eager fetch** (not lazy `tbl(con, "tablename")`). Creel datasets are hundreds to thousands of rows. Eager fetch simplifies the code path, eliminates the `dbplyr` dependency, and returns plain tibbles that flow directly into existing `add_*()` functions.

### rstudio/config YAML Pattern

The `config` package YAML format is the R ecosystem standard for environment-specific credentials. Adopt its conventions exactly:

```yaml
# creel.yml — example structure
default:
  backend: flat_file
  tables:
    interviews: data/interviews.csv
    counts: data/counts.csv
    catch: data/catch.csv
    harvest_lengths: data/harvest_lengths.csv
    release_lengths: data/release_lengths.csv
  survey_type: instantaneous

production:
  backend: sql_server
  connection:
    driver: "ODBC Driver 17 for SQL Server"
    server: !expr Sys.getenv("CREEL_DB_SERVER")
    database: !expr Sys.getenv("CREEL_DB_NAME")
    trusted_connection: "yes"
  tables:
    interviews: vwCombinedR_InterviewData_wSupplemental
    counts: vwCombinedR_CountData
    catch: vwCombinedR_CatchData
    harvest_lengths: vwCombinedR_HarvestLengthData
    release_lengths: vwCombinedR_ReleasedLengthData
  survey_type: instantaneous
```

Active environment controlled by `R_CONFIG_ACTIVE` env var (default = "default"); `production` activates on deployment. Credentials via `!expr Sys.getenv()` or `!expr keyring::key_get()` — never literal passwords.

### S3 Contract Pattern (Wickham AdvR §13)

The `creel_schema` S3 class should follow the three-function canonical pattern:

```
new_creel_schema(col_map, table_map, survey_type, backend = "unknown")
    → bare constructor; no input coercion; checks types only

validate_creel_schema(schema)
    → full structural check; returns schema invisibly on success; cli_abort() on failure

creel_schema(col_map, table_map, survey_type, backend = "unknown")
    → user-facing helper; calls new_ then validate_; coerces character vectors
```

`col_map` is a named character vector: `c(raw_col_name = "canonical_tidycreel_name", ...)`. Direction is raw → canonical (same direction as `dplyr::rename()`). This is the same direction as `setNames(x, new_names)` and `rename_with()` lookup tables.

---

## Integration Points with Existing tidycreel API

The following existing functions are the downstream consumers of `fetch_*()` output. Their expected column names define the required canonical names in `creel_schema$col_map`:

| Fetch function | Feeds | Required canonical columns |
|----------------|-------|---------------------------|
| `fetch_interviews()` | `add_interviews()` | `date`, `period`, `section`, `n_anglers`, `trip_type`, `time_fished_hours`, `refused`, `interview_id` |
| `fetch_counts()` | `add_counts()` | `date`, `period`, `section`, `count`, `angler_type` |
| `fetch_catch()` | `add_catch()` | `interview_id`, `species`, `n`, `catch_type` |
| `fetch_harvest_lengths()` | `add_lengths()` | `interview_id`, `species`, `length_mm` |
| `fetch_release_lengths()` | `add_lengths()` | `interview_id`, `species`, `length_group` OR `length_mm`, `n` |

The exact canonical column names must be confirmed by reading the current `add_interviews()`, `add_counts()`, `add_catch()`, and `add_lengths()` function signatures from the tidycreel source before implementing. These may differ from the names listed above, which are based on the data model description in PROJECT.md.

**This is the single most important implementation verification step for v1.3.0.** Getting the canonical column names wrong means every fetch silently fails validation or produces wrong joins.

---

## Sources

- [CDMConnector Getting Started vignette](https://cran.r-project.org/web/packages/CDMConnector/vignettes/a01_getting-started.html) — cdm_reference S3 object; cdmFromCon() pattern; validate_cdm() approach
- [CDMConnector GitHub (darwin-eu)](https://github.com/darwin-eu/CDMConnector) — named list of table references as connection contract; MEDIUM confidence (observed from vignette; source not fully read)
- [Advanced R §13 S3 (Wickham)](https://adv-r.hadley.nz/s3.html) — new_/validate_/helper() three-function pattern; constructor attributes; HIGH confidence
- [rstudio/config GitHub](https://github.com/rstudio/config) — YAML environment config with !expr for credentials; R_CONFIG_ACTIVE env var; HIGH confidence
- [Securing Credentials — db.rstudio.com](https://edgararuiz.github.io/db.rstudio.com/best-practices/managing-credentials.html) — credential management hierarchy; keyring + config + envvar patterns; MEDIUM confidence
- [DBI Introduction vignette](https://cran.r-project.org/web/packages/DBI/vignettes/DBI.html) — dbConnect / dbGetQuery / dbDisconnect pattern; HIGH confidence
- [easydb GitHub (EricEdwardBryant)](https://github.com/EricEdwardBryant/easydb) — YAML config → dbcnf object → db_* pipeline; pipe-chaining pattern; MEDIUM confidence
- [OHDSI DatabaseConnector](https://github.com/OHDSI/DatabaseConnector) — uniform DBI surface across SQL Server / PostgreSQL / Oracle; schema-agnostic fetch pattern; MEDIUM confidence
- [R for Data Science 2e §21 Databases](https://r4ds.hadley.nz/databases.html) — lazy vs. eager collect() decision; DBI backend pattern; HIGH confidence
- tidycreel PROJECT.md — NGPC view names, column names, table structure; HIGH confidence (primary source)

---

*Feature research for: tidycreel v1.3.0 — Generic DB interface (creel_schema S3 + tidycreel.connect)*
*Researched: 2026-04-06*
