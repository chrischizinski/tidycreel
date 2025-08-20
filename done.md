# tidycreel Development Roadmap – Expanded ToDo

This roadmap outlines the phases, tasks, and substeps required to build the **tidycreel** package for creel survey analysis.

---

## Phase 1 – Critical Fixes & Core Infrastructure
- [ ] Set up `renv` for reproducible environments
- [ ] Add `.gitignore` for build artifacts and local configs
- [ ] Create core package structure with `usethis::create_package()`
- [ ] Configure `DESCRIPTION` and `NAMESPACE`
- [ ] Add GitHub Actions CI workflow for R CMD check
- [ ] Automated schema test runner (run all validation functions in a single call)
- [ ] Create `sample_data/` folder with minimal datasets for testing
- [ ] Lock `renv` snapshot and record R version for reproducibility

---

## Phase 2 – Survey Design Objects
- [ ] Implement `creel_design()` constructor
- [ ] Store metadata: strata definitions, probabilities, sampling frame sizes
- [ ] Define S3 class `creel_design`
- [ ] Document assumptions (e.g., random sampling within stratum)
- [ ] Add `plot_design()` to visualize survey structure
- [ ] Write conversion helpers (`creel_design` → `survey::svydesign`)

---

## Phase 3 – Estimation Core
- [ ] Implement `est_effort()` with support for instantaneous/progressive counts
- [ ] Implement `est_cpue()` with ratio-of-means vs. mean-of-ratios handling
- [ ] Implement `est_catch()` (catch/harvest by species)
- [ ] Output: tibble with estimate, SE, CI, metadata

---

## Phase 4 – Bias Corrections & Variance Estimation
- [ ] Implement incomplete-trip corrections
- [ ] Address targeted vs. non-targeted species
- [ ] Incorporate nonresponse adjustments
- [ ] Implement analytical variance for ratio estimators
- [ ] Compare bootstrap vs. jackknife performance
- [ ] Add option for Taylor linearization (consistent with `survey` package)

---

## Phase 5 – Support for Survey Designs
- [ ] Access-point design support
- [ ] Roving design support (roving-access, roving-roving)
- [ ] Aerial survey integration
- [ ] Hybrid designs (e.g., access-point + roving)
- [ ] Functions for unequal probability sampling
- [ ] Provide vignette on survey design trade-offs

---

## Phase 6 – Data Validation & Cleaning
- [ ] Validate input tables for required fields
- [ ] Standardize coding (species codes, effort units)
- [ ] Handle missing values with warnings
- [ ] Flagging function (`flag_outliers()`) for extreme CPUE/effort
- [ ] Auto-report of validation results (summary tibble + export option)

---

## Phase 7 – Output & Reporting
- [ ] Implement `summary.creel_estimate()` with formatted tables
- [ ] Export estimates to CSV/Excel with metadata
- [ ] Provide APA-style table output helper
- [ ] Add plots: effort trends, CPUE by stratum, harvest composition
- [ ] Build `ggplot2` themes for consistent output
- [ ] Provide example dashboards (flexdashboard/Shiny stub)

---

## Phase 8 – Documentation & Training
- [ ] Write function documentation with examples
- [ ] Create vignettes for access-point, roving, aerial designs
- [ ] Provide references to foundational literature
- [ ] Glossary of terms (effort, CPUE, harvest)
- [ ] “Common pitfalls” vignette
- [ ] Annotated example workflow: raw → validation → estimates → report

---

## Phase 9 – Testing & QA/QC
- [ ] Unit tests with `testthat`
- [ ] Coverage reporting via `covr`
- [ ] Continuous integration: enforce test pass/fail
- [ ] Test edge cases (empty data, single stratum, large datasets)

---

## Phase 10 – Simulation & Scheduling Tools
- [ ] Implement creel scheduling helper functions
- [ ] Provide simulation framework for survey design evaluation
- [ ] Include variance decomposition (between vs. within strata)
- [ ] Sensitivity analysis tools (effect of sample size, allocation choices)
- [ ] Visualization functions for simulated sampling calendars

---

## Phase 11 – Advanced Features
- [ ] Domain estimation for subgroups (species, regions)
- [ ] Multi-stage sampling handling
- [ ] Integration with GIS for mapping
- [ ] Support for off-site or marine survey extensions

---

## Phase 12 – Production Infrastructure
- [ ] Benchmark suite for performance with large datasets
- [ ] Security review (PII obfuscation for real creel data)
- [ ] Add Dockerfile for reproducible deployments
- [ ] Demo vignette showing Docker + `renv` workflow

---

## Phase 13 – Release & Dissemination
- [ ] Prepare CRAN submission
- [ ] Build pkgdown site
- [ ] Write blog post / announcement
- [ ] Training materials and workshop slide deck
