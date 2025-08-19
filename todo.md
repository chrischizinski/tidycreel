# TODO — tidycreel

> Living checklist for the **tidycreel** R package.  
> **Rules of engagement:**  
> - After each task/phase, mark completed items (`[x]`) and append any newly discovered tasks under the relevant phase.  
> - Keep this file in sync with the plan doc (**Creel Package: Architecture & Delivery Plan**).  
> - Follow the tidyverse style guide, prefer vectorization, and build on `survey` (with a tidy interface and optional `surveyr` interop).  
> - Do not proceed to the next phase until all tasks in the current phase are complete (or explicitly deferred).

---

## Meta & Conventions
- [x] Define project scope and objectives  
  Done: Scope and objectives defined following CRAN-friendly, tidyverse style, vectorization-first, survey-based foundations.
- [ ] Adopt tidyverse style guide (https://style.tidyverse.org); enable `styler` + `lintr` pre-commit hooks.
- [ ] Document vectorization-first policy in CONTRIBUTING.
- [ ] Establish foundations: use `survey` for design objects & estimators; provide tidy wrappers; interop with `surveyr` where helpful.
- [ ] Add `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `LICENSE`, `CITATION.cff`, `codemeta.json`.
- [ ] Establish semantic versioning; add lifecycle badge.

---

## Phase 0 — Bootstrap & Scaffolding
_Do not proceed to Phase 1 until Phase 0 is complete._

### 0.1 Package Creation
- [x] Create package with `usethis::create_package("tidycreel")`
- [x] Set package metadata in DESCRIPTION (Title, Description, Authors@R, License, URL, BugReports)
- [x] Add package-level documentation with `usethis::use_package_doc()`

### 0.2 Git & GitHub Setup
- [x] Initialize Git repository with `usethis::use_git()`
- [x] Create GitHub repository (`tidycreel`) with `usethis::use_github()`
- [ ] Configure branch protections on main branch (require PR review, CI passing, disallow force-pushes)
- [ ] Add `.gitignore` for R package development
- [ ] Add `.gitignore` for R package development

### 0.3 Development Environment
- [x] Initialize renv with `renv::init()` (**Acceptance:** `renv.lock` created, committed)
- [ ] Install and configure key packages: usethis, devtools, testthat, pkgdown, lintr, styler
- [ ] Commit `renv.lock` to repository
- [ ] Set up `.Rbuildignore` with standard exclusions

### 0.4 CI/CD Configuration
- [ ] Add GitHub Actions workflow for R CMD check with `usethis::use_github_action_check_standard()`
- [ ] Configure lintr workflow with `usethis::use_github_action("lint")`
- [ ] Add pkgdown workflow with `usethis::use_github_action("pkgdown")`
- [ ] Test CI pipeline with initial commit

### 0.5 Code Quality & Style
- [ ] Configure lintr with `.lintr` file for tidyverse style
- [ ] Set up styler with `.Rproj` file for consistent formatting
- [ ] Add pre-commit hooks for style and lint checks
- [ ] Create `.Rproj` file for RStudio project

### 0.6 Documentation & Templates
- [ ] Add issue templates (bug report, feature request, estimator request)
- [ ] Create pull request template
- [ ] Write comprehensive README with badges and quickstart guide
- [ ] Add pkgdown configuration with `_pkgdown.yml`

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 1 — Data Model & Schemas
_Do not proceed to Phase 2 until Phase 1 is complete._

### 1.1 Schema Definition
- [ ] Define tidy schemas for: sampling calendar/strata, events/visits, interviews, instantaneous counts, auxiliary (sunrise/sunset, holidays), reference tables
- [ ] Create data validation functions: `validate_calendar()`, `validate_interviews()`, `validate_counts()`
- [ ] Document column requirements, types, and keys in roxygen

### 1.2 Toy Datasets
- [ ] Create toy datasets in `data/` directory
- [ ] Add example datasets to `inst/extdata/`
- [ ] Create data dictionaries for all datasets
- [ ] Document datasets with roxygen2

### 1.3 Validation Testing
- [ ] Test missing keys detection
- [ ] Test wrong data type validation
- [ ] Test duplicate ID detection
- [ ] Test invalid code validation (species/waterbody/mode)
- [ ] Test DST/leap-day handling in date-times

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 2 — Design Objects (`survey` foundations)
_Do not proceed to Phase 3 until Phase 2 is complete._

### 2.1 Design Constructors
- [ ] Implement `design_access()` → `survey::svydesign` with appropriate strata, PSUs, weights
- [ ] Implement `design_roving()` including instantaneous counts/expansion logic
- [ ] Implement `design_repweights()` → `svrepdesign` constructors (bootstrap/JK/BRR options)
- [ ] Create tidy wrappers that accept tibbles + `cols = c(...)` mapping

### 2.2 Helper Functions
- [ ] Add helpers for post-stratification/calibration where applicable
- [ ] Create design object attributes for metadata tracking
- [ ] Add print and summary methods for design objects

### 2.3 Interoperability
- [ ] Optional conversion helpers for `surveyr` idioms (without fragmenting API)
- [ ] Test surveyr compatibility functions

### 2.4 Testing
- [ ] Validate design functions against toy examples and `survey` outputs
- [ ] Confirm replicate-weight designs produce expected SEs

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 3 — Estimators (Design-based defaults)
_Do not proceed to Phase 4 until Phase 3 is complete._

### 3.1 Core Estimators
- [ ] Implement `estimate_effort()` (by strata, seasonal roll-ups)
- [ ] Implement `estimate_cpue()` (species/mode aware)
- [ ] Implement `estimate_harvest()` and trip totals
- [ ] Return schema: estimate, SE, CI, df/rep details, strata labels, assumptions metadata

### 3.2 Implementation Details
- [ ] Ensure vectorized, grouped calculations via `dplyr`
- [ ] Add metadata tracking for estimation assumptions
- [ ] Create summary and print methods for estimates

### 3.3 Testing
- [ ] Non-negativity tests
- [ ] Invariance to row order
- [ ] Scaling behavior checks
- [ ] Compare results against hand calculations and `survey::svymean/svytotal/svyratio`

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 4 — Variance & Uncertainty
_Do not proceed to Phase 5 until Phase 4 is complete._

### 4.1 Variance Methods
- [ ] Analytic SEs via `survey`
- [ ] Replicate-weight SEs (bootstrap/JK/BRR)
- [ ] Delta-method ratios when applicable
- [ ] Option for finite population corrections (FPC)

### 4.2 Bootstrap Helpers
- [ ] Create `bootstrap_*()` helpers (parallel-ready)
- [ ] Add reproducible seed management
- [ ] Implement parallel processing with `future`/`furrr`

### 4.3 Testing
- [ ] Compare analytic vs replicate SEs within tolerance
- [ ] Test small-sample behavior
- [ ] Edge-case tests: zero-effort/catch strata, empty strata, extreme outliers

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 5 — Validation & QC
_Do not proceed to Phase 6 until Phase 5 is complete._

### 5.1 QC Functions
- [ ] Implement `qc_time_gaps()` for temporal coverage
- [ ] Implement `qc_outliers()` for data quality detection
- [ ] Implement `qc_schema()` for schema validation
- [ ] Create warning/condition taxonomy with `.strict = TRUE` option

### 5.2 Reporting
- [ ] Create standard QC report `report_qc()` (Quarto template)
- [ ] Add QC report templates in `inst/templates/`
- [ ] Create snapshot tests for QC reports

### 5.3 Testing
- [ ] Snapshot tests for QC reports
- [ ] Deterministic behavior with set seeds
- [ ] Test strict mode enforcement

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 6 — Performance & Scaling
_Do not proceed to Phase 7 until Phase 6 is complete._

### 6.1 Benchmarking
- [ ] Create benchmarks with `bench`/`microbenchmark` (10^3…10^7 rows)
- [ ] Profile hotspots using `profvis`
- [ ] Ensure vectorized/grouped operations
- [ ] Consider `data.table` backend

### 6.2 Parallel Processing
- [ ] Implement parallel resampling via `future`/`furrr`
- [ ] Document RNG kind for reproducibility
- [ ] Add parallel examples

### 6.3 Testing
- [ ] Stress tests for memory pressure
- [ ] Performance thresholds in CI
- [ ] Scaling tests across data sizes

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 7 — Visualization & Reporting
_Do not proceed to Phase 8 until Phase 7 is complete._

### 7.1 Visualization
- [ ] Create `plot_*()` functions (effort trends, CPUE, harvest distributions)
- [ ] Add ggplot2 themes
- [ ] Create interactive options

### 7.2 Table Generation
- [ ] Create table helpers with `gt`/`flextable`
- [ ] Add customizable themes
- [ ] Implement rounding and sig figs

### 7.3 Report Templates
- [ ] Create Quarto templates in `inst/templates/`
- [ ] Add parameterized reports
- [ ] Create report generation functions

### 7.4 Testing
- [ ] Snapshot tests for plots and tables
- [ ] Test report generation with different parameters

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 8 — Documentation
_Do not proceed to Phase 9 until Phase 8 is complete._

### 8.1 Function Documentation
- [ ] Roxygen docs for all functions
- [ ] Cross-references between related functions
- [ ] Include mathematical formulas

### 8.2 Vignettes
- [ ] Intro & data model vignette
- [ ] Design vignette
- [ ] Estimation & variance vignette
- [ ] Model-based extensions vignette
- [ ] End-to-end vignette

### 8.3 Website
- [ ] Configure pkgdown site
- [ ] Add search functionality
- [ ] Create getting started guide
- [ ] Add news/changelog

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 9 — Testing Depth & Coverage
_Do not proceed to Phase 10 until Phase 9 is complete._

### 9.1 Unit Testing
- [ ] Tests for every exported function
- [ ] Test edge cases and error conditions
- [ ] Add warning tests

### 9.2 Property Testing
- [ ] Property-based tests for invariants
- [ ] Test estimator properties
- [ ] Test consistency across interfaces

### 9.3 Coverage
- [ ] Achieve ≥90% coverage with `covr`
- [ ] Add coverage badge
- [ ] Regular reporting
- [ ] Identify/test uncovered paths

### 9.4 Edge Cases
- [ ] Zero/near-zero counts
- [ ] Empty/single-day strata
- [ ] Missing shifts
- [ ] DST/leap-day transitions
- [ ] Duplicates/invalid codes
- [ ] Post-stratification mismatches
- [ ] FPC toggles
- [ ] Tiny bootstrap samples
- [ ] Large-N scaling

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 10 — CI/CD & Release
_Do not proceed to Phase 11 until Phase 10 is complete._

### 10.1 CI Configuration
- [ ] CI matrix: macOS/Windows/Ubuntu; R devel/release/oldrel
- [ ] Lintr/styler checks
- [ ] Pkgdown deploy on main; PR previews
- [ ] Add dependency checking

### 10.2 Release Process
- [ ] Release checklist (NEWS, version bump, revdep checks)
- [ ] rhub/winbuilder checks
- [ ] Zenodo DOI on GitHub release
- [ ] Release automation scripts

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 11 — Governance & Community
_Do not proceed to Phase 12 until Phase 11 is complete._

### 11.1 Documentation
- [ ] CONTRIBUTING with coding standards and rationale
- [ ] Security & data privacy notes
- [ ] Add code of conduct

### 11.2 Issue Management
- [ ] Issue triage labels
- [ ] Create issue templates
- [ ] Set up automated labeling

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 12 — Interop & Extensions (Optional)
_Do not proceed to Phase 13 until Phase 12 is complete (unless optional extensions deferred)._

### 12.1 Surveyr Integration
- [ ] Safe helpers for `surveyr` interop
- [ ] Test surveyr compatibility

### 12.2 Database Support
- [ ] DB connectors with `DBI`
- [ ] Add database examples
- [ ] Create database vignette

### 12.3 Reproducibility
- [ ] Targets pipeline example (`_targets.R`)
- [ ] Add targets integration tests
- [ ] Create targets vignette

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Phase 13 — Roadmap Tracking
- [ ] v0.1: MVP (schemas, design constructors, effort/CPUE/harvest + variance)
- [ ] v0.2: Replicate-weight variance, QC report, vignettes
- [ ] v0.3: Reporting templates, visualization, performance benchmarks
- [ ] v1.0: CRAN release, site, DOI, full docs

**Arising tasks:**
- [ ] Add new arising task (to be specified)

---

## Recurring Maintenance
- [ ] Update `todo.md`: close completed items; add new tasks
- [ ] Sync with plan doc; revise milestones
- [ ] Refresh `renv.lock`; re-run CI; update coverage/benchmarks
- [ ] Review open issues for labeling and prioritization