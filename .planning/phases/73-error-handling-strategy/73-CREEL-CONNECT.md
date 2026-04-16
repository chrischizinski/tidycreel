# creel.connect Integration Surface Investigation — tidycreel v1.3.0

**Phase:** 73 — Error Handling Strategy & creel.connect Investigation
**Researched:** 2026-04-15
**Written:** 2026-04-15
**Status:** Complete

---

## Executive Summary

The tidycreel schema contract — `creel_schema()`, `validate_creel_schema()`, and the `creel_schema` S3 class — is stable, complete, and ready to support a companion package today. The `tidycreel.connect` companion package (a sub-directory in the repo, not on CRAN) is a proof-of-concept with three concrete gaps that would need to be resolved before the package could be activated for SQL Server workflows. PROJECT.md's designation of the companion package as "not current work" is accurate and appropriate: the schema contract is frozen-but-informal, the companion package has no active development or release plan, and the three gaps documented here are not scheduled for fix.

---

## Scope and Status

This document assesses the readiness of the integration surface between `tidycreel` and the `tidycreel.connect` companion package. It is a **readiness assessment**, not a risk audit and not a pure description of what exists.

**What is being assessed:**

- **The tidycreel side:** Exported functions in `R/creel-schema.R` — `creel_schema()`, `validate_creel_schema()`, `format.creel_schema()`, and `print.creel_schema()`. These are part of the main package, maintained, and covered by the existing test suite. The `creel_schema` S3 class they define is the integration surface a companion package must respect.

- **The tidycreel.connect side:** A sub-directory companion package at `tidycreel.connect/`. It has a real R package structure (DESCRIPTION, tests, vignettes) and version 0.1.0, but it is not on CRAN, not tested in CI alongside the main package, and not currently maintained per PROJECT.md.

**Not assessed here:** Dependency review of companion package imports (DBI, duckdb, flexdashboard) — explicitly out of scope for Phase 73.

---

## The tidycreel Schema Contract

### Exported Symbols

All schema contract functions live in `R/creel-schema.R`:

| Symbol | Type | Exported | Purpose |
|--------|------|----------|---------|
| `creel_schema()` | function | YES | Construct a column-mapping object |
| `validate_creel_schema()` | function | YES | Validate required columns are mapped |
| `format.creel_schema()` | S3 method | YES | Pretty-print schema |
| `print.creel_schema()` | S3 method | YES | Print method (calls `format`) |
| `CANONICAL_COLUMNS` | list | NO (internal) | Required-column registry per survey type |
| `COL_TO_TABLE` | list | NO (internal) | Display grouping for print output |
| `new_creel_schema()` | function | NO (internal) | Low-level constructor |

The exported surface (`creel_schema`, `validate_creel_schema`, `format.creel_schema`, `print.creel_schema`) is the contract a companion package can depend on.

### The creel_schema S3 Object

A `creel_schema` object has the following structure:

- **`$survey_type`** — one of `"instantaneous"`, `"bus_route"`, `"ice"`, `"camera"`, `"aerial"`, validated at construction via `match.arg()`
- **Four table-name slots:** `$interviews_table`, `$counts_table`, `$catch_table`, `$lengths_table` — all default `NULL`
- **25 column-mapping slots:** `$date_col`, `$catch_col`, `$effort_col`, `$trip_status_col`, `$count_col`, `$catch_uid_col`, `$interview_uid_col`, `$species_col`, `$catch_count_col`, `$catch_type_col`, `$length_uid_col`, `$length_mm_col`, `$length_type_col`, and 12 additional optional slots — all default `NULL`
- **Class:** `"creel_schema"`

### What validate_creel_schema() Enforces

`validate_creel_schema()` checks that all columns listed in `CANONICAL_COLUMNS[[survey_type]]` are non-NULL in the schema. The required column sets differ by survey type:

**For `instantaneous`, `bus_route`, and `ice` surveys (13 required columns):**
`date_col`, `catch_col`, `effort_col`, `trip_status_col`, `count_col`, `catch_uid_col`, `interview_uid_col`, `species_col`, `catch_count_col`, `catch_type_col`, `length_uid_col`, `length_mm_col`, `length_type_col`

**For `camera` and `aerial` surveys (2 required columns):**
`date_col`, `count_col`

Error messages from `validate_creel_schema()` follow the canonical `cli::cli_abort` named-vector pattern, listing missing columns with actionable guidance.

### Copy-Paste Constructor Example

```r
schema <- creel_schema(
  survey_type      = "instantaneous",
  interviews_table = "vwInterviews",
  counts_table     = "vwCounts",
  date_col         = "SurveyDate",
  catch_col        = "TotalCatch",
  effort_col       = "EffortHours",
  trip_status_col  = "TripStatus",
  count_col        = "AnglerCount"
)
validate_creel_schema(schema)  # aborts with informative list of missing columns if any required slot is NULL
```

---

## The tidycreel.connect Side

### Function Inventory

| Function | Backend | CSV Status | SQL Server Status |
|----------|---------|------------|-------------------|
| `creel_connect(con, schema)` | DBI + CSV dispatch | Implemented | Methods implemented; SQL Server fetch stubs out |
| `creel_connect_from_yaml(path, config)` | YAML → CSV or sqlserver | Implemented | Implemented (with schema slot mismatch — see Gap 1) |
| `creel_check_driver()` | ODBC diagnostic | n/a | Implemented |
| `fetch_interviews(conn, ...)` | S3 generic | Implemented | `cli_abort("not yet implemented")` |
| `fetch_counts(conn, ...)` | S3 generic | Implemented | `cli_abort("not yet implemented")` |
| `fetch_catch(conn, ...)` | S3 generic | Implemented | `cli_abort("not yet implemented")` |
| `fetch_harvest_lengths(conn, ...)` | S3 generic | Implemented | `cli_abort("not yet implemented")` |
| `fetch_release_lengths(conn, ...)` | S3 generic | Implemented | `cli_abort("not yet implemented")` |

### The creel_connection S3 Class

`creel_connect()` returns a `creel_connection` object. Two subclasses handle backend dispatch:

- `creel_connection_csv` — used when `con` is a named list of CSV file paths
- `creel_connection_sqlserver` — used when `con` is a DBI connection to a SQL Server instance

S3 dispatch on these subclasses routes each `fetch_*()` call to the correct backend method. This design pattern — clean separation of backends via S3 subclasses — is the right architecture for a multi-backend fetch layer.

### The Usable Path Today

The **CSV fetch path is fully functional.** All five `fetch_*()` generics (`fetch_interviews`, `fetch_counts`, `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`) have working `creel_connection_csv` methods. File-based creel workflows using `tidycreel.connect` with CSV inputs work today.

---

## Integration Gaps

Three concrete gaps exist between the tidycreel schema contract and the `tidycreel.connect` companion package. All three are frozen implementation gaps consistent with "not current work" status. None of them affect the usability of the main `tidycreel` package.

### Gap 1: lengths_table Slot Mismatch (Schema Field Mismatch)

**What the schema defines:** `creel_schema()` has a single `lengths_table` slot for specifying the table holding length data.

**What the YAML builder expects:** `creel-connect-yaml.R` references `harvest_lengths_table` and `release_lengths_table` as separate schema fields:

```r
# creel-connect-yaml.R lines 144–148
table_keys <- c(
  "interviews_table", "counts_table", "catch_table",
  "harvest_lengths_table", "release_lengths_table"  # neither slot exists in creel_schema()
)
for (k in table_keys) {
  if (!is.null(cfg$schema[[k]])) schema_args[[k]] <- cfg$schema[[k]]
}
```

`creel_schema()` accepts no `harvest_lengths_table` or `release_lengths_table` parameters. Passing them via the YAML builder will produce an unused-argument error at connection time.

**Compounding the gap:** The `lengths_table` slot in `creel_schema()` is not consumed by any existing `fetch_*()` implementation. The CSV backend's `fetch_harvest_lengths()` and `fetch_release_lengths()` read from `conn$con$harvest_lengths` and `conn$con$release_lengths` respectively — path keys set on the connection object, not table names from the schema. The schema's `lengths_table` slot is currently unused by any code path.

**Practical impact:** Zero while "not current work" status holds. The YAML-configured SQL Server workflow is not exposed to users, and no user is expected to encounter this error. When activation is planned, this must be the first issue resolved — the direction (unify to `lengths_table` or split to `harvest_lengths_table`/`release_lengths_table`) requires a deliberate design decision.

### Gap 2: SQL Server fetch_*() Methods Are Stubs

All five SQL Server fetch methods abort immediately:

```r
fetch_interviews.creel_connection_sqlserver <- function(conn, ...) {
  cli::cli_abort("not yet implemented")
}
# ... same for fetch_counts, fetch_catch, fetch_harvest_lengths, fetch_release_lengths
```

The DBI / SQL Server backend is non-functional. This is the core functional gap for any organization relying on SQL Server as their creel database backend. The dispatch infrastructure is in place; the implementations are missing.

**Practical impact:** Zero while "not current work" status holds. No SQL Server workflow is exposed or documented as working.

### Gap 3: Vignette Documents a Non-Existent API

The getting-started vignette demonstrates:

```r
conn <- creel_connect(dbi_con, schema, auth_type = "password")
```

The actual `creel_connect()` signature is `creel_connect(con, schema)` — no `auth_type` parameter exists or has ever existed. The vignette was written ahead of implementation and reflects a planned (but unimplemented) API.

**Practical impact:** A contributor or user who follows the vignette to establish a SQL Server connection will hit an immediate error. This is a documentation gap, not an implementation gap — the fix requires only correcting the vignette, not writing new code. However, it signals that the companion package has not been tested against its own documentation.

---

## Resolving the PROJECT.md Tension

PROJECT.md states: *"The `creel_schema` / `tidycreel.connect` / generic DB interface line is not current in this repository."*

This statement covers two distinct things that should not be conflated:

**The tidycreel schema contract (creel_schema.R) is stable and maintained.** `creel_schema()` and `validate_creel_schema()` are exported, documented, tested, and production-quality. The S3 class they define has not changed, is relied upon by the companion package, and will not change without a deliberate decision. These functions are safe to use and safe to build on. "Not current work" does not apply to the schema contract in the main package.

**The tidycreel.connect companion package is a proof-of-concept.** It resides in a sub-directory, is not on CRAN, is not tested in CI with the main package, and has no active development or release plan. "Not current work" applies in full to this package. The three gaps documented above are frozen, not scheduled for resolution.

**What "not current work" means for the integration surface:**

- The schema contract is frozen-but-informal: it will not change without a deliberate activation decision, but it is also not under active evolution. It should be treated as stable but not under a formal versioning guarantee.
- Activating the companion package would require: (1) resolving the `lengths_table` slot mismatch, (2) implementing SQL Server `fetch_*()` methods, (3) correcting the vignette. These are near-term feasible tasks — they are not architectural problems, and none requires restructuring the main package.
- There is no reason to remove `creel_schema()` or `validate_creel_schema()` from the main package. They are complete, coherent, and the natural anchor point for any future companion package.

---

## Positive Findings

**P1: Schema construction and validation logic is complete and production-quality.**
`creel_schema()` and `validate_creel_schema()` are not stubs. The constructor validates `survey_type` via `match.arg()`, the `CANONICAL_COLUMNS` registry correctly encodes per-survey-type column requirements, and `validate_creel_schema()` produces informative errors listing every missing column. These functions are ready for production use today.

**P2: Error messages in validate_creel_schema() follow the canonical cli::cli_abort pattern.**
The validation errors in `creel-schema.R` use the unnamed-summary / `"x"` = problem / `"i"` = suggestion named-vector structure consistently with the rest of tidycreel. A contributor adding new column requirements to `CANONICAL_COLUMNS` will find the existing pattern clear to follow.

**P3: S3 backend dispatch is the right design pattern for the companion package.**
The `creel_connection_csv` and `creel_connection_sqlserver` subclasses with S3 dispatch on `fetch_*()` generics cleanly separates the CSV and DBI backends. When SQL Server methods are implemented, they slot in without touching the CSV path. This is the architecture to preserve.

**P4: The CSV fetch path is fully implemented and usable today.**
All five `fetch_*()` generics have working CSV methods. A creel survey program using flat-file data (CSV exports from their database) can use `tidycreel.connect` today with `creel_connect_from_yaml()` pointing to a CSV-backed config. This is the one immediately deployable workflow in the companion package.

---

## Readiness Verdict

| Component | Verdict | Rationale |
|-----------|---------|-----------|
| **tidycreel schema contract** (`creel_schema()`, `validate_creel_schema()`, `creel_schema` S3 class) | **READY** | Complete, stable, tested, production-quality. Safe to rely on. |
| **tidycreel.connect companion package (CSV path)** | **USABLE** | All five CSV fetch methods implemented and functional. |
| **tidycreel.connect companion package (SQL Server path)** | **NOT READY** | All five SQL Server fetch methods are stubs. YAML builder has schema field mismatch. Vignette documents a non-existent API. Three concrete gaps must be resolved before this path can be released or relied upon. |

**Summary:** The tidycreel schema contract is ready to anchor a companion package. The companion package itself needs three targeted fixes before it can support SQL Server workflows. None of the gaps require architectural changes to the main package.

---

## Recommendations

### R1 — Fix the lengths_table slot mismatch (medium priority, if activation is planned)

**WHAT:** Decide whether to (a) add `harvest_lengths_table` and `release_lengths_table` parameters to `creel_schema()` (splitting the single `lengths_table` slot), or (b) update the YAML builder in `creel-connect-yaml.R` to use `lengths_table` (unifying to the existing slot). Pick one direction and make both packages consistent.

**WHY:** This is a breaking gap — a YAML-configured SQL Server workflow will fail at connection time with an unused-argument error. It must be resolved before any other companion package work, because all other SQL Server work builds on the connection step.

**Priority:** Medium — only relevant if activation is planned; zero impact while "not current work" status holds.

---

### R2 — Implement the five SQL Server fetch_*() methods (medium priority, if activation is planned)

**WHAT:** Implement `fetch_interviews.creel_connection_sqlserver`, `fetch_counts.creel_connection_sqlserver`, `fetch_catch.creel_connection_sqlserver`, `fetch_harvest_lengths.creel_connection_sqlserver`, and `fetch_release_lengths.creel_connection_sqlserver`. These are the core functional gap for the DBI backend.

**WHY:** The SQL Server path is the primary use case for a companion package in an agency setting — most creel programs store their data in a database, not CSV files. Until these methods are implemented, the companion package is a CSV-only tool.

**Priority:** Medium — only relevant if activation is planned. The S3 dispatch infrastructure is already in place; this is an implementation task, not a design task.

---

### R3 — Correct the getting-started vignette (low priority)

**WHAT:** Update `tidycreel.connect/vignettes/getting-started.Rmd` to remove the non-existent `auth_type` parameter from the `creel_connect()` call and bring the demonstrated API in line with the actual function signature.

**WHY:** Any contributor or user who follows the vignette to set up a SQL Server connection will hit an immediate error. This is a documentation-only fix with no implementation dependency — it can be made independently of R1 and R2.

**Priority:** Low. The SQL Server path is non-functional regardless, so the vignette error is not the binding constraint. However, it is a one-line fix.

---

### R4 — Document companion package dependency implications before activation (informational)

**WHAT:** Before beginning activation work, conduct a dependency review of `tidycreel.connect`'s imports (DBI, odbc, duckdb, flexdashboard) to assess CRAN policy compliance, system dependency requirements, and whether any imports should be `Suggests` vs `Imports`.

**WHY:** The companion package carries heavier system dependencies than the main package (ODBC drivers, potentially `flexdashboard` for reporting). These have implications for CRAN submission, cross-platform compatibility, and maintenance burden. This review is a prerequisite for activation planning but is out of scope for Phase 73.

**Priority:** Informational — acts as a gate check before committing to activation. No action needed while "not current work" status holds.

---

*Sources: `R/creel-schema.R`, `tidycreel.connect/R/creel-connection.R`, `tidycreel.connect/R/fetch-loaders.R`, `tidycreel.connect/R/creel-connect-yaml.R`, `tidycreel.connect/vignettes/getting-started.Rmd`, `.planning/PROJECT.md` — all findings drawn directly from `73-RESEARCH.md`.*
