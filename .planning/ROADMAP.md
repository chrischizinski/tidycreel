# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- ✅ **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (shipped 2026-02-16)
- ✅ **v0.4.0 Bus-Route Survey Support** — Phases 21-27 (shipped 2026-02-28)
- ✅ **v0.5.0 Interview Data Model and Unextrapolated Summaries** — Phases 28-35 (shipped 2026-03-08)
- ✅ **v0.6.0 Multiple Counts per PSU** — Phases 36-38 (shipped 2026-03-09)
- ✅ **v0.7.0 Spatially Stratified Estimation** — Phases 39-43 (shipped 2026-03-15)
- ✅ **v0.8.0 Non-Traditional Creel Designs** — Phases 44-47 (shipped 2026-03-22)
- ✅ **v0.9.0 Survey Planning & Quality of Life** — Phases 48-51 (shipped 2026-03-24)
- ✅ **v1.0.0 Package Website** — Phases 52-56 (shipped 2026-03-31)
- ✅ **v1.1.0 Planning Suite Completeness & Community Health** — Phases 57-59 (shipped 2026-04-02)
- ✅ **v1.2.0 Documentation, Visual Calendar & GLMM Aerial** — Phases 60-65 (shipped 2026-04-06)
- 🚧 **v1.3.0 Generic DB Interface** — Phases 66-70 (in progress)

## Phases

<details>
<summary>✅ v0.1.0 Foundation (Phases 1-7) — SHIPPED 2026-02-09</summary>

**Milestone Goal:** Establish package foundation with instantaneous count design and effort estimation, proving the three-layer architecture (API → Orchestration → Survey) works end-to-end.

- [x] Phase 1: Package Foundation (3/3 plans) — completed 2026-02-09
- [x] Phase 2: Design Constructor (2/2 plans) — completed 2026-02-09
- [x] Phase 3: Count Data Integration (2/2 plans) — completed 2026-02-09
- [x] Phase 4: Basic Effort Estimation (2/2 plans) — completed 2026-02-09
- [x] Phase 5: Grouped Estimation (1/1 plan) — completed 2026-02-09
- [x] Phase 6: Variance Methods (2/2 plans) — completed 2026-02-09
- [x] Phase 7: Documentation & Quality Assurance (2/2 plans) — completed 2026-02-09

**Delivered:** Three-layer architecture proven, design-centric API operational, progressive validation working, complete estimation capability with multiple variance methods, production-ready quality gates

See: [.planning/milestones/v0.1.0-ROADMAP.md](milestones/v0.1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.2.0 Interview-Based Estimation (Phases 8-12) — SHIPPED 2026-02-11</summary>

**Milestone Goal:** Enable catch and harvest estimation by adding interview data analysis to existing instantaneous count design foundation.

- [x] Phase 8: Interview Data Integration (2/2 plans) — completed 2026-02-11
- [x] Phase 9: CPUE Estimation (2/2 plans) — completed 2026-02-11
- [x] Phase 10: Catch and Harvest Estimation (2/2 plans) — completed 2026-02-11
- [x] Phase 11: Total Catch Estimation (2/2 plans) — completed 2026-02-11
- [x] Phase 12: Documentation and Quality Assurance (2/2 plans) — completed 2026-02-11

**Delivered:** Interview data integration, ratio-of-means CPUE/harvest estimation, total catch/harvest with delta method variance, comprehensive documentation, 89.24% test coverage

See: [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.3.0 Incomplete Trips & Validation (Phases 13-20) — SHIPPED 2026-02-16</summary>

**Milestone Goal:** Enable scientifically valid incomplete trip estimation with complete trip focus, following Colorado C-SAP best practices and Pollock et al. roving-access design principles.

- [x] Phase 13: Trip Status Infrastructure (2/2 plans) — completed 2026-02-16
- [x] Phase 14: Overnight Trip Duration (1/1 plan) — completed 2026-02-16
- [x] Phase 15: Mean-of-Ratios Estimator Core (2/2 plans) — completed 2026-02-16
- [x] Phase 16: Trip Truncation (2/2 plans) — completed 2026-02-16
- [x] Phase 17: Complete Trip Defaults (2/2 plans) — completed 2026-02-16
- [x] Phase 18: Sample Size Warnings (2/2 plans) — completed 2026-02-16
- [x] Phase 19: Diagnostic Validation Framework (2/2 plans) — completed 2026-02-16
- [x] Phase 20: Documentation & Guidance (2/2 plans) — completed 2026-02-16

**Delivered:** Trip metadata infrastructure, mean-of-ratios estimator with truncation, complete trip defaults, TOST validation framework, sample size warnings, comprehensive 794-line documentation vignette

See: [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.4.0 Bus-Route Survey Support (Phases 21-27) — SHIPPED 2026-02-28</summary>

**Milestone Goal:** Implement statistically correct bus-route (nonuniform probability) estimation based on Jones & Pollock (2012) and Malvestuto et al. (1978) — making tidycreel the ONLY R package with correct bus-route estimation.

- [x] Phase 21: Bus-Route Design Foundation (2/2 plans) — completed 2026-02-17
- [x] Phase 22: Inclusion Probability Calculation (2/2 plans) — completed 2026-02-17
- [x] Phase 23: Data Integration (2/2 plans) — completed 2026-02-17
- [x] Phase 24: Bus-Route Effort Estimation (2/2 plans) — completed 2026-02-24
- [x] Phase 25: Bus-Route Harvest Estimation (2/2 plans) — completed 2026-02-28
- [x] Phase 26: Primary Source Validation (2/2 plans) — completed 2026-02-25
- [x] Phase 27: Documentation & Traceability (2/2 plans) — completed 2026-02-28

**Delivered:** Bus-route design constructor with nonuniform probabilities (πᵢ = p_site × p_period), enumeration expansion, effort/harvest estimators implementing Jones & Pollock (2012) Eq. 19.4-19.5, Malvestuto (1996) Box 20.6 reproduced exactly, complete workflow vignette, 1,098 tests

See: [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.5.0 Interview Data Model and Unextrapolated Summaries (Phases 28-35) — SHIPPED 2026-03-08</summary>

- [x] Phase 28: Extended Interview Data Model (2/2 plans) — completed 2026-03-08
- [x] Phase 28.1: Normalize CPUE/HPUE by Angler Count (2/2 plans) — completed 2026-03-08
- [x] Phase 29: Species Catch Data (3/3 plans) — completed 2026-03-08
- [x] Phase 30: Length Frequency Data (1/1 plan) — completed 2026-03-08
- [x] Phase 31: Interview-Level Unextrapolated Summaries (2/2 plans) — completed 2026-03-08
- [x] Phase 32: CWS/HWS Rates (2/2 plans) — completed 2026-03-08
- [x] Phase 33: Length Frequency Summaries (2/2 plans) — completed 2026-03-08
- [x] Phase 34: Species-Level Extrapolated Estimates (2/2 plans) — completed 2026-03-08
- [x] Phase 35: Documentation & Quality Assurance (2/2 plans) — completed 2026-03-08

**Delivered:** add_catch(), add_lengths(), seven interview-level summary functions, CWS/HWS rates, length frequency distributions, species-level estimation, estimate_total_release() / estimate_release_rate()

See: [.planning/milestones/v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.6.0 Multiple Counts per PSU (Phases 36-38) — SHIPPED 2026-03-09</summary>

- [x] Phase 36: Multiple Counts per Day (2/2 plans) — completed 2026-03-09
- [x] Phase 37: Progressive Count Estimator (1/1 plan) — completed 2026-03-09
- [x] Phase 38: Documentation & Quality Assurance (2/2 plans) — completed 2026-03-09

**Delivered:** count_time_col support, within-day aggregation with Rasmussen two-stage variance (se_between/se_within), progressive count estimator with circuit_time, flexible-count-estimation vignette

See: [.planning/milestones/v0.6.0-ROADMAP.md](milestones/v0.6.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.7.0 Spatially Stratified Estimation (Phases 39-43) — SHIPPED 2026-03-15</summary>

**Milestone Goal:** Enable per-section estimation so biologists can get effort, catch rates, and totals broken down by named spatial zones, with correct correlated-domain variance when combining sections into lake-wide totals.

- [x] Phase 39: Section Effort Estimation (3/3 plans) — completed 2026-03-11
- [x] Phase 40: Interview-Based Rate Estimators (2/2 plans) — completed 2026-03-11
- [x] Phase 41: Product Estimators (2/2 plans) — completed 2026-03-14
- [x] Phase 42: Example Data and Vignette (2/2 plans) — completed 2026-03-14
- [x] Phase 43: v0.7.0 Tech Debt Cleanup (1/1 plan) — completed 2026-03-15

**Delivered:** add_sections() infrastructure, estimate_effort() section dispatch with svyby(covmat=TRUE) + svycontrast() aggregation, estimate_catch_rate() / estimate_harvest_rate() / estimate_release_rate() renamed and section-aware, estimate_total_catch() / estimate_total_harvest() / estimate_total_release() section dispatch with sum(TC_i) lake total, missing_sections guard on all estimators, example_sections_* datasets, section-estimation vignette, 1588 tests

See: [.planning/milestones/v0.7.0-ROADMAP.md](milestones/v0.7.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.8.0 Non-Traditional Creel Designs (Phases 44-47) — SHIPPED 2026-03-22</summary>

**Milestone Goal:** Extend tidycreel to support ice fishing, remote camera, and aerial creel survey designs as first-class `survey_type` values within the existing `creel_design()` entry point and three-layer architecture.

- [x] Phase 44: Design Type Enum and Validation (2/2 plans) — completed 2026-03-15
- [x] Phase 45: Ice Fishing Survey Support (3/3 plans) — completed 2026-03-16
- [x] Phase 46: Remote Camera Survey Support (3/3 plans) — completed 2026-03-16
- [x] Phase 47: Aerial Survey Support (3/3 plans) — completed 2026-03-22

**Delivered:** VALID_SURVEY_TYPES enum guard, ice fishing (p_site=1.0, effort_type, shelter_mode stratification), remote camera (counter + ingress-egress modes, camera_status gap handling, preprocess_camera_timestamps()), aerial survey (estimate_effort_aerial() svytotal × h_open/v, visibility correction, numeric validation), six example datasets, three workflow vignettes, 1696 tests

See: [.planning/milestones/v0.8.0-ROADMAP.md](milestones/v0.8.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.9.0 Survey Planning & Quality of Life (Phases 48-51) — SHIPPED 2026-03-24</summary>

**Milestone Goal:** Add pre-season planning tools (schedule generators, sample size calculators, design validator) and post-season diagnostics (completeness checker, season summary) around the existing five-survey-type estimation pipeline.

- [x] Phase 48: Schedule Generators (3/3 plans) — completed 2026-03-23
- [x] Phase 49: Power and Sample Size (2/2 plans) — completed 2026-03-24
- [x] Phase 50: Design Validator and Completeness Checker (3/3 plans) — completed 2026-03-24
- [x] Phase 51: Season Summary (2/2 plans) — completed 2026-03-24

**Delivered:** `generate_schedule()` + `generate_bus_schedule()` sampling frame generators with CSV/xlsx I/O; `creel_n_effort()` + `creel_n_cpue()` Cochran sample-size calculators; `creel_power()` + `cv_from_n()` power/inverse suite; `validate_design()` pre-season pass/warn/fail report; `check_completeness()` post-season data quality checker with survey-type dispatch; `season_summary()` wide-tibble assembler with `creel_season_summary` S3 class

See: [.planning/milestones/v0.9.0-ROADMAP.md](milestones/v0.9.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0.0 Package Website (Phases 52-56) — SHIPPED 2026-03-31</summary>

**Milestone Goal:** Ship a polished, workflow-driven pkgdown website with a custom Bootstrap 5 theme and automated GitHub Pages deployment. No new R functions; all work is infrastructure and presentation.

- [x] Phase 52: Hex Sticker (1/1 plan) — completed 2026-03-30
- [x] Phase 53: Foundation & Theme (2/2 plans) — completed 2026-03-26
- [x] Phase 54: Home Page & Reference (2/2 plans) — completed 2026-03-27
- [x] Phase 55: Navigation & Articles (1/1 plan) — completed 2026-03-30
- [x] Phase 56: Deployment (2/2 plans) — completed 2026-03-31

**Delivered:** Bootstrap 5 pkgdown theme (bslib + Google Fonts + custom extra.css), polished README home page with badges and feature highlights, grouped reference index (46 exports + 15 datasets), workflow-driven navbar (5 sections), GitHub Actions CI/CD auto-deploy to GitHub Pages, live site at https://chrischizinski.github.io/tidycreel

See: [.planning/milestones/v1.0.0-ROADMAP.md](milestones/v1.0.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1.0 Planning Suite Completeness & Community Health (Phases 57-59) — SHIPPED 2026-04-02</summary>

**Milestone Goal:** Extend the planning suite with within-day count time generation, close the v0.9.0 vignette gap, and add structured community contribution tooling so external contributors know how to engage with the project.

- [x] Phase 57: Count Time Generator (1/1 plan) — completed 2026-04-02
- [x] Phase 58: Survey Scheduling Vignette (1/1 plan) — completed 2026-04-02
- [x] Phase 59: Community Health Files (2/2 plans) — completed 2026-04-02

**Delivered:** `generate_count_times()` with random/systematic/fixed strategies and 26 tests; `survey-scheduling.Rmd` extended with full pre/post-season narrative; GitHub issue templates (bug + feature request), `config.yml` Discussions routing, `CONTRIBUTING.md` rewrite

See: [.planning/milestones/v1.1.0-ROADMAP.md](milestones/v1.1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2.0 Documentation, Visual Calendar & GLMM Aerial (Phases 60-65) — SHIPPED 2026-04-06</summary>

**Milestone Goal:** Deliver four concept-first vignettes, document-embeddable schedule calendar output, and a GLMM-based aerial effort estimator for non-random flight timing.

- [x] Phase 60: Housekeeping (1/1 plan) — completed 2026-04-03
- [x] Phase 61: survey <-> tidycreel Vignette (1/1 plan) — completed 2026-04-04
- [x] Phase 62: Estimation Pipeline Vignettes (2/2 plans) — completed 2026-04-05
- [x] Phase 63: Visual Calendar (1/1 plan) — completed 2026-04-05
- [x] Phase 63.1: Attach Count Times to Daily Schedule (1/1 plan) — completed 2026-04-05
- [x] Phase 64: GLMM Aerial Estimator (2/2 plans) — completed 2026-04-05
- [x] Phase 65: pkgdown Reference Completeness & GLMM Documentation Polish (1/1 plan) — completed 2026-04-06

**Delivered:** 4 vignettes (survey-tidycreel, effort-pipeline, catch-pipeline, aerial-glmm), `print.creel_schedule()` + `knit_print.creel_schedule()` S3 methods, `attach_count_times()`, `estimate_effort_aerial_glmm()` (lme4, Askey 2018), `example_aerial_glmm_counts` dataset, complete pkgdown reference index — 45 files, +5,496/-84 lines

See: [.planning/milestones/v1.2.0-ROADMAP.md](milestones/v1.2.0-ROADMAP.md)

</details>

---

### 🚧 v1.3.0 Generic DB Interface (In Progress)

**Milestone Goal:** Define a `creel_schema` S3 contract in tidycreel and bootstrap a companion package `tidycreel.connect` that loads data from any backend into tidycreel-ready form via a YAML config file.

**Packages:** Phases 66 modifies **tidycreel**. Phases 67-70 create and modify **tidycreel.connect**.

- [x] **Phase 66: creel_schema S3 Class** - `creel_schema()`, `validate_creel_schema()`, `print.creel_schema()` in tidycreel (completed 2026-04-07)
- [ ] **Phase 67: tidycreel.connect Package + Connection Layer** - Package scaffold, `creel_connect()`, `creel_connect_from_yaml()`, YAML config validation, `creel_check_driver()`
- [ ] **Phase 68: CSV Backend + fetch_*() Loaders** - Flat-file backend, all five `fetch_*()` functions, `validate_fetch_result()`, BOM handling, explicit column types
- [ ] **Phase 69: SQL Server ODBC Backend** - `.fetch_sqlserver()`, platform auth guard, `as.Date()` coercion, driver detection
- [ ] **Phase 70: Documentation** - Getting-started vignette + platform ODBC install instructions in README

## Phase Details

### Phase 66: creel_schema S3 Class
**Package:** tidycreel
**Goal:** Users can define and validate a column-mapping contract that connects any data source to the tidycreel estimation API
**Depends on:** Nothing (no external deps; uses only existing tidycreel Imports)
**Requirements:** SCHEMA-01, SCHEMA-03, SCHEMA-04 (SCHEMA-02 removed — ngpc_default_schema() deferred to private repo)
**Success Criteria** (what must be TRUE):
  1. User can construct a `creel_schema` object via `creel_schema()` specifying column mappings, table names, and survey type
  2. When required columns are missing from a schema, `validate_creel_schema()` aborts with a `cli_abort()` error naming the missing columns by name
  3. User can print a `creel_schema` object and see column mappings and survey type in a readable summary
**Plans:** 2/2 plans complete
Plans:
- [ ] 66-01-PLAN.md — creel_schema() constructor, validate_creel_schema(), print/format methods, make_test_db() DuckDB fixture

### Phase 67: tidycreel.connect Package + Connection Layer
**Package:** tidycreel.connect (new)
**Goal:** Users can create a validated database connection from either programmatic arguments or a YAML config file, with credentials loaded from environment variables and fail-fast validation before any connection is attempted
**Depends on:** Phase 66 (creel_schema must exist as a public API before tidycreel.connect can import it)
**Requirements:** CONNECT-01, CONNECT-02, CONNECT-03, CONNECT-04, CONNECT-05, CONNECT-06
**Success Criteria** (what must be TRUE):
  1. User can create a `creel_connection` by passing a DBI connection + `creel_schema` to `creel_connect()`
  2. User can create a `creel_connection` by passing CSV file paths + `creel_schema` to `creel_connect()`
  3. User can create a `creel_connection` from a YAML config file via `creel_connect_from_yaml()`, with all config keys and types validated before any connection is attempted
  4. YAML config never stores credentials as plain text; credentials are read from environment variables
  5. User can print a `creel_connection` and see backend type, schema summary, and connection status
  6. User can call `creel_check_driver()` to see available ODBC drivers and verify SQL Server driver presence
**Plans:** 2/4 plans executed
Plans:
- [ ] 67-01-PLAN.md — Package scaffold, stub R files, failing test stubs (Wave 0)
- [ ] 67-02-PLAN.md — creel_connect() DBI+CSV backends, print.creel_connection() (CONNECT-01, 02, 05)
- [ ] 67-03-PLAN.md — creel_connect_from_yaml(), YAML pre-validation (CONNECT-03, 04)
- [ ] 67-04-PLAN.md — creel_check_driver() ODBC diagnostic (CONNECT-06)

### Phase 68: CSV Backend + fetch_*() Loaders
**Package:** tidycreel.connect
**Goal:** Users can load all five creel tables from CSV files into tibbles that flow directly into `add_interviews()`, `add_counts()`, `add_catch()`, and `add_lengths()` without modification, with clear errors when columns are missing or mistyped
**Depends on:** Phase 67 (creel_connection object must exist before fetch_*() can dispatch on it)
**Requirements:** FETCH-01, FETCH-02, FETCH-03, FETCH-04, FETCH-05, FETCH-06, BACKEND-01, BACKEND-04
**Success Criteria** (what must be TRUE):
  1. User can call `fetch_interviews(conn)` with a CSV-backed connection and get a tibble ready for `add_interviews()` with correct column names and types
  2. User can call `fetch_counts(conn)`, `fetch_catch(conn)`, `fetch_harvest_lengths(conn)`, and `fetch_release_lengths(conn)` with a CSV-backed connection and get tibbles ready for the corresponding `add_*()` functions
  3. CSV files exported from Excel (with UTF-8 BOM) load correctly without corrupted column names or misclassified species codes
  4. When required columns are absent or have wrong type after loading, `fetch_*()` aborts with a clear error naming the missing or mistyped column
  5. Users who only need the flat-file backend can install tidycreel.connect without system ODBC libraries
**Plans:** TBD

### Phase 69: SQL Server ODBC Backend
**Package:** tidycreel.connect
**Goal:** Users with access to the NGPC SQL Server creel database can load all five creel tables using Windows Authentication or SQL password auth, with correct R types on all columns
**Depends on:** Phase 68 (fetch_*() loaders and validate_fetch_result() must exist; SQL Server backend adds a new dispatch branch to existing functions)
**Requirements:** BACKEND-02, BACKEND-03
**Success Criteria** (what must be TRUE):
  1. User can call `fetch_interviews(conn)` with a SQL Server-backed connection and get a tibble with date columns typed as R `Date` (not character)
  2. When Windows integrated authentication is requested on macOS or Linux, `creel_connect()` aborts immediately with a clear error message before attempting any connection
  3. SQL Server backend integration tests are skipped automatically when the NGPC database is unreachable, so CI passes without live database access
**Plans:** TBD

### Phase 70: Documentation
**Package:** tidycreel.connect
**Goal:** Users new to tidycreel.connect can follow a single vignette to go from YAML config to a complete creel analysis, and users on any platform can find OS-specific ODBC driver install instructions in the README
**Depends on:** Phase 69 (full API must be stable before documentation can demonstrate the complete workflow)
**Requirements:** DOCS-01, DOCS-02
**Success Criteria** (what must be TRUE):
  1. The getting-started vignette demonstrates a complete end-to-end workflow: YAML config → `creel_connect_from_yaml()` → `fetch_interviews()` → `add_interviews()` with a runnable example using fixture data
  2. The README includes platform-specific ODBC driver installation instructions for Windows, macOS, and Linux
**Plans:** TBD

## Progress

**Execution Order:** 66 → 67 → 68 → 69 → 70

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-65 | v0.1.0–v1.2.0 | 126/126 | Complete | 2026-04-06 |
| 66. creel_schema S3 Class | 2/2 | Complete   | 2026-04-07 | - |
| 67. tidycreel.connect Package + Connection Layer | 2/4 | In Progress|  | - |
| 68. CSV Backend + fetch_*() Loaders | v1.3.0 | 0/TBD | Not started | - |
| 69. SQL Server ODBC Backend | v1.3.0 | 0/TBD | Not started | - |
| 70. Documentation | v1.3.0 | 0/TBD | Not started | - |

---

*Roadmap last updated: 2026-04-07 — Phase 67 planned (4 plans)*
*See .planning/milestones/ for archived milestone roadmaps*
