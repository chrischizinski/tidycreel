# Architecture Research

**Domain:** tidycreel v1.3.0 — Generic DB Interface (creel_schema S3 + tidycreel.connect companion package)
**Researched:** 2026-04-06
**Confidence:** HIGH (grounded in direct codebase inspection of all 22 R source files, legacy CreelDataAccess scripts, DESCRIPTION, and the established v0.9.0 architecture baseline)

---

## Existing Architecture (v1.2.0 Baseline)

The three-layer architecture is proven across 65 phases and all five survey types.

```
┌─────────────────────────────────────────────────────────────────┐
│                         API Layer  (tidycreel)                   │
│                                                                  │
│  creel_design()   add_counts()   add_interviews()               │
│  add_catch()      add_lengths()  add_sections()                 │
│  compute_effort() preprocess_camera_timestamps()                │
│  summarize_*()    validate_incomplete_trips()                   │
│  generate_schedule()  creel_n_effort()  validate_design()       │
└──────────────────────────┬──────────────────────────────────────┘
                           │  creel_design S3 object
┌──────────────────────────▼──────────────────────────────────────┐
│                    Orchestration Layer  (tidycreel)              │
│                                                                  │
│  estimate_effort()      estimate_catch_rate()                   │
│  estimate_total_catch() estimate_total_harvest()                │
│  estimate_effort_aerial_glmm()  section dispatch                │
└──────────────────────────┬──────────────────────────────────────┘
                           │  survey.design2 / svydesign objects
┌──────────────────────────▼──────────────────────────────────────┐
│                      Survey Layer  (survey package)              │
│                                                                  │
│  survey::svydesign()   survey::svytotal()   survey::svyratio()  │
│  survey::svyby()       survey::svycontrast()                    │
└─────────────────────────────────────────────────────────────────┘
```

The package is currently **data-model agnostic**: users load data from any source and pass
plain data frames to `creel_design()`, `add_counts()`, `add_interviews()`, etc. Column
mapping is the user's responsibility on every call.

---

## New Architecture: v1.3.0 DB Interface Layer

Two new components extend the architecture without touching the existing three layers.

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    YAML Config File  (user-authored)                          │
│  creel.yml: backend, connection params, table names, column maps, survey type │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │  parsed by creel_connect()
┌─────────────────────────────────▼────────────────────────────────────────────┐
│              tidycreel.connect  (standalone companion package)                │
│                                                                              │
│  creel_connect(config_path)  →  creel_connection S3 object                  │
│    $backend     "sqlserver" | "csv"                                          │
│    $con         DBI connection (sqlserver) | NULL (csv)                      │
│    $schema      creel_schema object (from tidycreel)                         │
│    $config      raw parsed YAML list                                         │
│                                                                              │
│  fetch_counts(conn)      →  plain data.frame (canonical column names)        │
│  fetch_interviews(conn)  →  plain data.frame (canonical column names)        │
│  fetch_catch(conn)       →  plain data.frame (canonical column names)        │
│  fetch_harvest_lengths(conn)  →  plain data.frame (canonical column names)   │
│  fetch_release_lengths(conn)  →  plain data.frame (canonical column names)   │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │  plain data.frames (column-renamed)
┌─────────────────────────────────▼────────────────────────────────────────────┐
│              creel_schema S3 class  (tidycreel)                              │
│                                                                              │
│  new_creel_schema(tables, column_map, survey_type)                           │
│  validate_schema(schema)                                                     │
│  is_creel_schema(x)                                                          │
│                                                                              │
│  Defines the contract: canonical column names expected by add_*() functions  │
│  Lives in tidycreel.  tidycreel.connect imports it.                          │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │  creel_schema (carried inside creel_connection)
┌─────────────────────────────────▼────────────────────────────────────────────┐
│              Existing tidycreel API Layer  (unchanged)                        │
│                                                                              │
│  creel_design()   add_counts()   add_interviews()                            │
│  add_catch()      add_lengths()  add_sections()                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Boundaries

| Component | Package | Responsibility | Communicates With |
|-----------|---------|----------------|-------------------|
| `creel_schema` S3 | tidycreel | Defines canonical column names, table identity, survey type tagging, validation | Used by tidycreel.connect; validates data before add_*() calls |
| `creel_connection` S3 | tidycreel.connect | Carries live connection (or NULL for CSV), parsed schema, backend tag | Returned by creel_connect(); consumed by fetch_*() functions |
| `creel_connect()` | tidycreel.connect | Reads YAML config, constructs DBI connection (SQL Server) or records CSV paths, wraps in creel_connection | Calls new_creel_schema() from tidycreel |
| `fetch_counts()` | tidycreel.connect | Executes query or reads CSV; applies column map from schema; returns plain data.frame | Reads creel_connection$schema; feeds add_counts() |
| `fetch_interviews()` | tidycreel.connect | Same pattern as fetch_counts | Feeds add_interviews() |
| `fetch_catch()` | tidycreel.connect | Same pattern | Feeds add_catch() |
| `fetch_harvest_lengths()` | tidycreel.connect | Same pattern | Feeds add_lengths() |
| `fetch_release_lengths()` | tidycreel.connect | Same pattern | Feeds add_lengths() |

---

## Dependency Direction (Circular Dependency Resolution)

The circular dependency risk is real: if tidycreel imports tidycreel.connect, and
tidycreel.connect imports tidycreel, R CMD check fails.

**Resolution: creel_schema lives in tidycreel. tidycreel.connect imports tidycreel. tidycreel does NOT import tidycreel.connect.**

```
tidycreel  (defines creel_schema, all add_*() functions)
    ▲
    │  Imports (one-way only)
    │
tidycreel.connect  (defines creel_connect, fetch_*())
```

This means:
- tidycreel can be installed and used standalone (current behavior preserved exactly).
- tidycreel.connect requires tidycreel as a dependency.
- No function in tidycreel calls any function in tidycreel.connect.
- The user wires the two packages together in their analysis script.

---

## Where creel_schema Lives

`creel_schema` belongs in **tidycreel**, not in tidycreel.connect, for three reasons:

1. The schema is a contract about what `add_interviews()`, `add_counts()`, `add_catch()`,
   and `add_lengths()` expect. It belongs next to those functions.
2. Users who never use a database (flat file, manual data prep) may still want
   `creel_schema` to document their column layout and validate it before passing to
   `add_interviews()`. Putting it in tidycreel makes it available without installing
   tidycreel.connect.
3. If creel_schema were in tidycreel.connect, then tidycreel would need to import
   tidycreel.connect to access it for validation — causing the circular dependency.

**Implementation in tidycreel:**
- `R/creel-schema.R` — new file
- `new_creel_schema(tables, column_map, survey_type)` — S3 constructor (internal)
- `creel_schema(...)` — user-facing constructor with validation
- `validate_schema(schema)` — checks column_map covers all required columns for the survey type
- `is_creel_schema(x)` — type predicate
- `print.creel_schema()` — in `R/print-methods.R`

---

## YAML Config Format

The config file is the user-facing interface to tidycreel.connect. It decouples connection
parameters from analysis code (reproducibility, security, portability).

```yaml
# creel.yml
backend: sqlserver          # "sqlserver" | "csv"

connection:
  server: "129.93.168.13"
  port: 1433
  database: "CreelData"
  uid: "CreelAnalysisBot"
  # pwd: sourced from CREEL_DB_PASS environment variable (never store in YAML)
  driver: "ODBC Driver 18 for SQL Server"
  encrypt: true
  trust_server_cert: true

survey_type: instantaneous   # passed to creel_schema()

tables:
  counts:     vwCombinedR_CountData
  interviews: vwCombinedR_InterviewData_wSupplemental
  catch:      vwCombinedR_CatchData
  harvest_lengths:  vwCombinedR_HarvestLengthData
  release_lengths:  vwCombinedR_ReleasedLengthData

creel_uids:
  - "90f5375c-afe0-e511-80bf-0050568372f9"

column_map:
  counts:
    date:    cd_Date
    period:  cd_Period
    section: cd_Section
    count:   cd_BoatAnglers       # or whatever the count column is
  interviews:
    date:          cd_Date
    period:        cd_Period
    section:       cd_Section
    catch:         ii_TotalCatch
    effort:        ii_TimeFishedHours
    trip_status:   ii_TripType
    n_anglers:     ii_NumberAnglers
    interview_uid: ii_UID
    refused:       ii_Refused
  catch:
    interview_uid: ii_UID
    species:       ir_Species
    count:         Num
    catch_type:    CatchType
  harvest_lengths:
    interview_uid: ii_UID
    species:       ih_Species
    length:        ihl_Length
  release_lengths:
    interview_uid: ii_UID
    species:       ir_Species
    length:        ir_LengthGroup
    count:         ir_Count
```

For the CSV backend, `tables` maps to file paths instead of SQL view names:

```yaml
backend: csv

tables:
  counts:           data/counts.csv
  interviews:       data/interviews.csv
  catch:            data/catch.csv
  harvest_lengths:  data/harvest_lengths.csv
  release_lengths:  data/release_lengths.csv
```

The `creel_uids` key applies only to the SQL Server backend (filters by `cd_CreelUID`).
CSV backend ignores it.

---

## Data Flow: YAML Config to add_*()

```
creel.yml
    │
    ▼
creel_connect("creel.yml")
    │  reads YAML
    │  validates required keys present
    │  if backend == "sqlserver":
    │    calls DBI::dbConnect(odbc::odbc(), ...) using connection block
    │  if backend == "csv":
    │    records file paths; $con <- NULL
    │  calls new_creel_schema(tables, column_map, survey_type)
    │
    └──▶ returns creel_connection S3:
           $backend  "sqlserver" | "csv"
           $con      DBI connection | NULL
           $schema   creel_schema object
           $config   raw YAML list (for debugging)

fetch_interviews(conn, ...)
    │  reads conn$schema$column_map$interviews
    │  reads conn$schema$tables$interviews (view name or file path)
    │  if backend == "sqlserver":
    │    builds SQL: SELECT [cols] FROM [view] WHERE cd_CreelUID IN (...)
    │    executes via DBI::dbGetQuery(conn$con, sql)
    │  if backend == "csv":
    │    calls readr::read_csv() or read.csv() on the path
    │  renames columns according to column_map (source name → canonical name)
    │  returns plain data.frame with canonical column names
    │
    └──▶ plain data.frame ready for add_interviews()

add_interviews(design,
               interviews = fetch_interviews(conn),
               catch      = <column name in data>,
               effort     = <column name in data>,
               trip_status = <column name in data>,
               ...)
    │  (unchanged — receives a plain data.frame, uses tidy selectors)
    └──▶ creel_design with interviews attached
```

The fetch_*() functions are **thin adapters**. They do not transform data values —
they only rename columns from source names to canonical names expected by add_*(). All
scientific logic remains in tidycreel.

---

## How the Connection Object Carries the Schema

`creel_connection` holds `$schema` (a `creel_schema` object) rather than just the
column map. This design enables:

1. `fetch_*()` functions look up their column map from `conn$schema$column_map[[table]]`
   without the caller passing anything extra.
2. `validate_schema()` can be called on `conn$schema` before any fetch to catch
   config errors early (missing required column mappings).
3. The schema is self-documenting: `print(conn$schema)` shows the user exactly what
   canonical names will be produced and what survey type the schema was tagged for.
4. Future `tidycreel.connect` extensions (REST API backend) add a new backend key
   without changing the schema contract.

---

## How fetch_*() Output Feeds add_*()

All five `add_*()` functions take a plain `data.frame` and use tidy selectors to
identify columns. The fetch_*() contract is: **return a data.frame with canonical
column names matching the selectors the user will pass to add_*()**.

Column name mapping is established in the YAML config and applied by fetch_*(). After
fetch_*() returns, the data frame is ready to pass without any further renaming.

### Canonical Names per Table

| fetch_*() function | Canonical output columns | Consumed by |
|-------------------|--------------------------|-------------|
| fetch_counts() | date, period, section, count (+ any extras) | add_counts(design, counts, psu=period, ...) |
| fetch_interviews() | date, period, section, catch, effort, trip_status, n_anglers, interview_uid, refused | add_interviews(design, interviews, catch=catch, effort=effort, trip_status=trip_status, ...) |
| fetch_catch() | interview_uid, species, count, catch_type | add_catch(design, data, catch_uid=..., interview_uid=interview_uid, species=species, count=count, catch_type=catch_type) |
| fetch_harvest_lengths() | interview_uid, species, length | add_lengths(design, data, ..., length_type="harvest") |
| fetch_release_lengths() | interview_uid, species, length, count | add_lengths(design, data, ..., length_type="release", release_format="binned"/"individual") |

The `catch_uid` required by `add_catch()` is a unique key on the catch table; fetch_catch()
can generate it via `seq_len(nrow(data))` if the source table has no natural row key, or
map from a source column via the column_map.

---

## Package Structure

### tidycreel (existing package — minimal changes)

```
R/
├── creel-design.R             # UNCHANGED
├── creel-estimates*.R         # UNCHANGED
├── creel-summaries.R          # UNCHANGED
├── creel-validation.R         # UNCHANGED
├── survey-bridge.R            # UNCHANGED
├── validate-schemas.R         # UNCHANGED
├── print-methods.R            # EXTEND — add print.creel_schema
├── data.R                     # EXTEND — document example schema if provided
│
└── creel-schema.R             # NEW — creel_schema S3 class
                               #   new_creel_schema()    (internal constructor)
                               #   creel_schema()        (user-facing)
                               #   validate_schema()
                               #   is_creel_schema()
                               #   CANONICAL_COLUMNS     (named list constant)
```

**DESCRIPTION changes:** No new `Imports`. `creel_schema` uses only base R.

### tidycreel.connect (new standalone package)

```
tidycreel.connect/
├── DESCRIPTION                # Imports: tidycreel, DBI, yaml, cli, rlang
│                              # Suggests: odbc, readr, testthat
├── NAMESPACE                  # roxygen2-generated
├── R/
│   ├── creel-connect.R        # creel_connect(), new_creel_connection(),
│   │                          #   is_creel_connection(), print.creel_connection()
│   ├── fetch-counts.R         # fetch_counts()
│   ├── fetch-interviews.R     # fetch_interviews()
│   ├── fetch-catch.R          # fetch_catch()
│   ├── fetch-lengths.R        # fetch_harvest_lengths(), fetch_release_lengths()
│   ├── backends-sqlserver.R   # .fetch_sqlserver() internal; driver detection
│   ├── backends-csv.R         # .fetch_csv() internal; read.csv / readr dispatch
│   ├── yaml-config.R          # .read_config(), .validate_config_keys()
│   └── tidycreel.connect-package.R
├── tests/
│   └── testthat/
│       ├── test-creel-connect.R       # YAML parsing, schema construction
│       ├── test-fetch-csv.R           # CSV backend (no DB required)
│       ├── test-fetch-sqlserver.R     # skipped if DB not available
│       └── helper-fixtures.R          # temp YAML files, example CSVs
└── vignettes/
    └── getting-started.Rmd    # YAML → creel_connect() → fetch_*() → add_*() workflow
```

**Dependency rationale:**
- `DBI` — in `Imports` (required for SQL path; harmless when backend is csv)
- `yaml` — in `Imports` (YAML config parsing; no alternatives considered)
- `odbc` — in `Suggests` (SQL Server ODBC driver; absent for CSV-only users)
- `readr` — in `Suggests` (faster CSV read; graceful fallback to read.csv if absent)
- `tidycreel` — in `Imports` (for `creel_schema`; one-way dependency)

---

## Build Order

Build order follows the dependency graph: creel_schema must exist in tidycreel before
tidycreel.connect can use it.

### Phase Sequence

**Phase A — creel_schema S3 in tidycreel** (no external dependencies)

- `R/creel-schema.R`: `creel_schema()`, `new_creel_schema()`, `validate_schema()`,
  `is_creel_schema()`, `CANONICAL_COLUMNS` constant
- `R/print-methods.R`: `print.creel_schema()`
- Tests: schema construction, validation (missing required columns → abort), survey type
  tagging, print output
- This phase completes and ships in tidycreel; tidycreel.connect can then depend on it

**Phase B — tidycreel.connect package skeleton + YAML config layer**

- Package creation: `usethis::create_package("tidycreel.connect")`
- `R/yaml-config.R`: `.read_config()`, `.validate_config_keys()` with clear error messages
  for missing required keys
- `R/creel-connect.R`: `creel_connect()`, `new_creel_connection()`, `print.creel_connection()`
- Tests: YAML parsing with temp files; missing key errors; CSV and sqlserver backend tags
  from config; schema embedded in connection object

**Phase C — CSV backend fetch_*() functions**

- `R/backends-csv.R`: `.fetch_csv()` dispatch
- `R/fetch-*.R`: all five fetch functions, CSV path only
- Tests: use fixture CSV files in `tests/testthat/fixtures/`; verify column renaming;
  verify output is a plain data.frame; verify add_interviews() accepts fetch_interviews()
  output without further modification
- This phase can be verified without any database connection

**Phase D — SQL Server backend**

- `R/backends-sqlserver.R`: driver detection, DBI::dbGetQuery path, creel_uid filter
  injection into WHERE clause
- Tests: skipped automatically when DB is unreachable (use `testthat::skip_if()` + a
  connectivity check)
- Integration test: full YAML → creel_connect() → fetch_interviews() → add_interviews()
  round trip using the NGPC test database

**Why this order:**

- Phase A delivers creel_schema to tidycreel independently; biologists using flat files
  gain schema validation before the connect package exists.
- Phase B builds the package skeleton and YAML layer before any fetch logic, so config
  errors are caught at a well-defined boundary.
- Phase C (CSV) comes before SQL Server because it can be tested without network access or
  ODBC drivers; it validates the full fetch → rename → add_*() pipeline.
- Phase D adds the SQL Server backend last; its integration tests are the only ones that
  require external infrastructure.

---

## Architectural Patterns

### Pattern 1: Schema-First Column Mapping

**What:** All column renaming happens inside fetch_*(). The rest of the pipeline
(add_*() functions, estimators) never see source column names.

**When to use:** Every fetch_*() function.

**Trade-offs:** The schema is the single point of translation. Users debug one YAML
file, not scattered rename calls across their analysis scripts. The downside is that
the YAML column_map must be complete; fetch_*() should abort with an informative error
if a required canonical column has no mapping.

**Example:**

```r
# Internal logic inside fetch_interviews()
col_map <- conn$schema$column_map$interviews
raw <- .fetch_sqlserver(conn$con,
                        conn$schema$tables$interviews,
                        conn$config$creel_uids,
                        names(col_map))   # only fetch mapped source columns
dplyr::rename(raw, !!!setNames(names(col_map), unlist(col_map)))
# Result: data.frame with canonical names (date, period, catch, effort, ...)
```

### Pattern 2: Backend Dispatch Inside fetch_*()

**What:** Each fetch_*() function checks `conn$backend` and dispatches to an internal
helper (`.fetch_sqlserver()` or `.fetch_csv()`). The public function signature is
identical regardless of backend.

**When to use:** All five fetch_*() functions.

**Trade-offs:** Callers never need to know which backend is active. Adding a third
backend (REST API, Parquet) only requires adding a new `.fetch_rest()` helper and a
new dispatch branch — no changes to public API.

```r
fetch_interviews <- function(conn, ...) {
  validate_connection(conn)
  if (conn$backend == "sqlserver") {
    raw <- .fetch_sqlserver(conn$con,
                            conn$schema$tables$interviews,
                            conn$config$creel_uids,
                            ...)
  } else if (conn$backend == "csv") {
    raw <- .fetch_csv(conn$schema$tables$interviews, ...)
  } else {
    cli::cli_abort("Unknown backend: {.val {conn$backend}}")
  }
  .apply_column_map(raw, conn$schema$column_map$interviews)
}
```

### Pattern 3: Fail-Fast Config Validation

**What:** `creel_connect()` validates the YAML config completely before constructing
any connection. If required keys are missing or backend is unknown, it aborts with a
`cli_abort()` listing exactly which keys are missing.

**When to use:** `creel_connect()` only. Do not re-validate inside each fetch_*() call.

**Trade-offs:** Users see config errors immediately on `creel_connect()`, not buried
inside a fetch call. The connection object is either fully valid or does not exist.

### Pattern 4: Password via Environment Variable Only

**What:** Passwords are never stored in the YAML file. `creel_connect()` reads
`CREEL_DB_PASS` from the environment (or prompts interactively via getPass if the
env var is absent and an interactive session is detected). If neither is available and
the session is non-interactive, `creel_connect()` aborts.

**When to use:** SQL Server backend always.

**Trade-offs:** Prevents accidental credential commit. Consistent with
`CreelDataAccess_CJCedits.R` precedent. Documented prominently in the getting-started
vignette.

---

## Data Flow Diagram: Full Season Analysis with DB Backend

```
creel.yml  (YAML config)
    │
    ▼
creel_connect("creel.yml")          # tidycreel.connect
    │                               # returns creel_connection
    ├──▶ fetch_counts(conn)         # plain data.frame, canonical cols
    ├──▶ fetch_interviews(conn)     # plain data.frame, canonical cols
    ├──▶ fetch_catch(conn)          # plain data.frame, canonical cols
    ├──▶ fetch_harvest_lengths(conn)# plain data.frame, canonical cols
    └──▶ fetch_release_lengths(conn)# plain data.frame, canonical cols
              │
              │  (all plain data.frames; no creel_design yet)
              ▼
creel_design(calendar, date=date, strata=day_type)   # tidycreel (unchanged)
    │
add_counts(design, counts=fetch_counts(conn))
    │
add_sections(design, sections_df)
    │
add_interviews(design,
               interviews = fetch_interviews(conn),
               catch      = catch,
               effort     = effort,
               trip_status = trip_status,
               n_anglers  = n_anglers)
    │
add_catch(design,
          data           = fetch_catch(conn),
          interview_uid  = interview_uid,
          species        = species,
          count          = count,
          catch_type     = catch_type)
    │
add_lengths(design,
            data           = fetch_harvest_lengths(conn),
            interview_uid  = interview_uid,
            species        = species,
            length         = length,
            length_type    = "harvest")
    │
add_lengths(design2,
            data           = fetch_release_lengths(conn),
            interview_uid  = interview_uid,
            species        = species,
            length         = length,
            count          = count,
            length_type    = "release",
            release_format = "binned")
    │
    ▼
estimate_effort()   estimate_catch_rate()   estimate_total_catch()
    │                        (tidycreel — all unchanged)
    ▼
season_summary() / write_schedule() / etc.
```

---

## Integration Points: New vs Modified Components

| Component | Status | Package | Files | Regression Risk |
|-----------|--------|---------|-------|-----------------|
| `creel_schema` S3 | NEW | tidycreel | `R/creel-schema.R` (new) | None — additive |
| `print.creel_schema()` | NEW | tidycreel | `R/print-methods.R` (extend) | None — additive S3 method |
| tidycreel.connect package | NEW | tidycreel.connect | entire new package | None — separate package |
| `creel_connect()` | NEW | tidycreel.connect | `R/creel-connect.R` | None |
| `fetch_counts()` | NEW | tidycreel.connect | `R/fetch-counts.R` | None |
| `fetch_interviews()` | NEW | tidycreel.connect | `R/fetch-interviews.R` | None |
| `fetch_catch()` | NEW | tidycreel.connect | `R/fetch-catch.R` | None |
| `fetch_harvest_lengths()` | NEW | tidycreel.connect | `R/fetch-lengths.R` | None |
| `fetch_release_lengths()` | NEW | tidycreel.connect | `R/fetch-lengths.R` | None |
| `creel-design.R` | UNCHANGED | tidycreel | — | None |
| All estimation files | UNCHANGED | tidycreel | — | None |
| `add_interviews()` signature | UNCHANGED | tidycreel | — | None — fetch_*() feeds existing params |
| DESCRIPTION (tidycreel) | UNCHANGED | tidycreel | — | None — no new Imports needed |

---

## Anti-Patterns

### Anti-Pattern 1: creel_schema in tidycreel.connect

**What people do:** Put creel_schema in the companion package because "it's a DB
interface concern."

**Why it's wrong:** Creates a circular dependency. tidycreel's add_*() functions would
need to import tidycreel.connect for schema validation. Also means standalone tidycreel
users (flat file workflows) cannot use creel_schema for their own column validation.

**Do this instead:** creel_schema belongs in tidycreel. It is a contract about what
add_*() expects. tidycreel.connect imports it one-way.

### Anti-Pattern 2: fetch_*() Calls add_*() Internally

**What people do:** Have `fetch_and_load_interviews(conn, design)` call `add_interviews()`
internally and return a new creel_design.

**Why it's wrong:** Removes the user's ability to inspect, filter, or transform the
raw data frame before attaching it. Also couples tidycreel.connect to the creel_design
constructor arguments (which are tidy selectors, not strings), making the API fragile.

**Do this instead:** fetch_*() returns a plain data.frame. The user calls add_*() with
the tidy selectors they want. The separation is explicit and testable.

### Anti-Pattern 3: Column Renaming Inside add_*()

**What people do:** Accept a `creel_schema` argument in `add_interviews()` and do
column renaming inside the add function.

**Why it's wrong:** Breaks the existing API (every current caller would break). The
add_*() functions are stable across 65 phases. Changing their signatures now introduces
unnecessary regression risk for users not using the DB interface.

**Do this instead:** Renaming happens exclusively in fetch_*(). By the time data reaches
add_*(), column names are already canonical.

### Anti-Pattern 4: Storing Password in YAML

**What people do:** Add a `password:` key to creel.yml for convenience.

**Why it's wrong:** The config file is typically committed to version control or shared.
A plaintext password in YAML is a credential exposure risk.

**Do this instead:** Document the environment variable (`CREEL_DB_PASS`) in the
getting-started vignette. creel_connect() prompts interactively for a password when
the env var is absent and the session is interactive. Fail fast with a clear message
in non-interactive sessions.

### Anti-Pattern 5: tidycreel.connect Imports odbc Unconditionally

**What people do:** Add `odbc` to `Imports` in DESCRIPTION.

**Why it's wrong:** odbc requires platform-specific ODBC drivers installed at the OS
level. Users using only the CSV backend (e.g., biologists without network access to the
SQL Server) would be forced to install odbc and its drivers needlessly, and R CMD check
would warn on systems without those drivers.

**Do this instead:** Put `odbc` in `Suggests`. Use `rlang::check_installed("odbc")`
inside `.fetch_sqlserver()`. CSV backend users are unaffected.

---

## Scaling Considerations

This package ecosystem serves single-season creel analyses by individual biologists.
Scale in the web-service sense is irrelevant. The relevant scaling axes are:

| Concern | Current (1 creel, 1 season) | Multi-creel (5-10 at once) | Production automation (scheduled) |
|---------|----------------------------|---------------------------|-----------------------------------|
| Connection management | creel_connect() creates one connection per call | Re-use conn across multiple fetch_*() calls; avoid reconnecting per fetch | Add creel_disconnect() that calls DBI::dbDisconnect(); use on.exit() guard |
| creel_uid filtering | Single UUID in config | List of UUIDs supported in YAML already | No change needed |
| Column map complexity | One map per 5 tables | Config file grows; YAML anchors (&alias) can reduce duplication | yaml package handles YAML anchors transparently |
| CSV backend performance | read.csv adequate for creel data volumes (thousands of rows) | readr::read_csv faster; already in Suggests | No architectural change |

---

## Sources

- tidycreel v1.2.0 source: all 22 R files inspected directly (2026-04-06)
- tidycreel DESCRIPTION (verified 2026-04-06) — current Imports/Suggests footprint
- `R/creel-design.R` — creel_design S3 slots; add_interviews(), add_catch(), add_lengths() signatures with tidy selector conventions (lines 1541-1556, 2916-2921, 3152-3160)
- `R/validate-schemas.R` — existing S3 validation pattern (guard-first with checkmate collection)
- `R/creel-estimates.R` — new_creel_estimates() constructor as model for new_creel_schema()
- Legacy `CreelDataAccess.R` — five SQL views: vwCombinedR_CountData, vwCombinedR_InterviewData_wSupplemental, vwCombinedR_CatchData, vwCombinedR_HarvestLengthData, vwCombinedR_ReleasedLengthData; source column names confirmed
- Legacy `CreelDataAccess_CJCedits.R` — DBI + odbc connection pattern; driver detection; env-var password handling (verified 2026-04-06)
- Legacy `CreelApiHelper.R` — five data endpoints for REST backend (future reference only)
- DBI package: https://dbi.r-dbi.org/ — standard interface for R database connections
- yaml package (CRAN): https://cran.r-project.org/package=yaml — YAML parsing in R; no significant alternatives for this use case
- R Packages (2e) ch. 7 — companion package / dependency direction conventions: https://r-pkgs.org/dependencies-mindset-background.html

---

*Architecture research for: tidycreel v1.3.0 Generic DB Interface*
*Researched: 2026-04-06*
