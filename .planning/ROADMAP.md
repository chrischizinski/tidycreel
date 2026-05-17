# Roadmap: tidycreel

## Overview

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. Milestones are archived into `.planning/milestones/` to keep the live roadmap short and focused on whatever comes next.

## Milestones

- ✅ **M022 — Comprehensive Project Evaluation and Future Planning** — Phases 70-75 (shipped 2026-04-19)
- ✅ **M023 / v1.4.0 Quality, Polish, and rOpenSci Readiness** — Phases 76-79 (local closeout 2026-04-23) — see [.planning/milestones/v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)
- ✅ **M024 / v1.5.0 Analytical Extensions and rOpenSci Submission** — Phases 80-82 (shipped 2026-04-28) — see [.planning/milestones/v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6.0 — Analytical Extensions II** — Phases 83–87 (shipped 2026-05-06) — see [.planning/milestones/v1.6-ROADMAP.md](milestones/v1.6-ROADMAP.md)
- ✅ **v1.7.0 — API Connection & Real-Data Validation** — Phases 88–90 (shipped 2026-05-11) — see [.planning/milestones/v1.7-ROADMAP.md](milestones/v1.7-ROADMAP.md)
- 🔄 **v1.8.0 — Exports, Bootstrap CIs, and API Hardening** — Phases 91–94 (in progress)

## Phases

<details>
<summary>✅ v1.5.0 Analytical Extensions (Phases 80-82) - SHIPPED 2026-04-28</summary>

- [x] **Phase 80: INV-06 Fix and Quickcheck Proof** - Correct the stratified-sum inconsistency in `estimate_total_catch()` and verify it with the INV-06 property test (completed 2026-04-27)
- [x] **Phase 81: Exploitation-Rate Estimator** - Implement, stratify, and document `estimate_exploitation_rate()` using the Pollock et al. formulation (completed 2026-04-27)
- [x] **Phase 82: Package Quality and Documentation** - Remove the unused `lifecycle` import, pass urlchecker/rhub/goodpractice checks, and add the tidycreel.connect bridge article (completed 2026-04-28)

</details>

<details>
<summary>✅ v1.6.0 Analytical Extensions II (Phases 83–87) — SHIPPED 2026-05-06</summary>

- [x] **Phase 83: Camera Design Helper** — Implement `creel_n_camera()` for per-stratum camera-day sample size using the Cochran CV formula (completed 2026-05-03)
- [x] **Phase 84: Camera Missing Data Imputation** — Implement `impute_camera_counts()` with a GLM default tier and opt-in GLMM tier, schema-compatible with `add_counts()` (completed 2026-05-03)
- [x] **Phase 85: Mark-Recapture Harvest Estimators** — Implement `estimate_angler_n()` (Chapman/Petersen/Schnabel) and `estimate_mr_harvest()` for closed-population harvest estimation (completed 2026-05-04)
- [x] **Phase 86: Stratification Audit** — Implement `audit_strata()`, `simulate_strata_collapse()`, and `reallocate_strata()` for effort-precision-driven design evaluation (completed 2026-05-05)
- [x] **Phase 87: v1.6.0 Tech Debt Cleanup** — Close 6 advisory items: NB GLMM doc correction, Petersen variance_method label, Schnabel ci_hi guard, harvest_rate > 1 test, .imputed logic fix, Phase 86 VERIFICATION.md (completed 2026-05-05)

</details>

<details>
<summary>✅ v1.7.0 API Connection & Real-Data Validation (Phases 88–90) — SHIPPED 2026-05-11</summary>

- [x] **Phase 88: httr2 Hardening and API Fetch Methods** — Harden `.api_fetch()` with `req_error`/`req_retry` and implement all five `fetch_*.creel_connection_api` S3 methods with hardcoded field rename maps (completed 2026-05-09)
- [x] **Phase 89: Discovery Generics** — Add `list_creels()` and `search_creels()` generics with API implementations and CSV/SQL stubs in a new `creel-discovery.R` file (completed 2026-05-10)
- [x] **Phase 90: Real-Data Validation** — Integration script in `inst/validation/` runs the full bus-route pipeline on Calamus 2016 archived data and reports whether estimates match archived reference outputs (completed 2026-05-11)

</details>

### v1.8.0 — Exports, Bootstrap CIs, and API Hardening (Phases 91–94)

- [ ] **Phase 91: API Security and Hardening** — Audit `tidycreel.connect` for credential exposure and injection risks; confirm NGPC discovery field names; close `list_creels()` 0-column guard; patch `fetch_counts()` bus-route E2E gap
- [ ] **Phase 92: Package Health Gate** — Add working-directory guard to the Calamus 2016 validation script; resolve all rcmdcheck warnings so the 0-warnings gate holds before new code lands
- [ ] **Phase 93: Reporting Exports** — Implement `tidy()` S3 method for `creel_estimates` objects and `write_estimates()` CSV/Excel file-write helpers
- [ ] **Phase 94: Bootstrap Confidence Intervals** — Add `ci_method = "bootstrap"` to `estimate_total_harvest_br()`, `estimate_total_catch()`, `estimate_angler_n()`, and `estimate_mr_harvest()`

## Phase Details

<details>
<summary>✅ v1.5.0 Phase Details (Phases 80-82)</summary>

### Phase 80: INV-06 Fix and Quickcheck Proof

**Goal**: `estimate_total_catch()` returns consistent aggregate estimates across single and stratified-sum paths, proved by a passing quickcheck invariant
**Depends on**: M023 / Phase 79 (quickcheck infrastructure, INV-06 test scaffold)
**Requirements**: ESTIM-01, ESTIM-04
**Success Criteria** (what must be TRUE):

  1. `estimate_total_catch()` aggregate result equals the sum of `estimate_total_catch(by = "species")` for multi-strata multi-species designs
  2. The INV-06 quickcheck property test passes for multi-strata multi-species generated inputs
  3. `rcmdcheck` passes with 0 errors and 0 warnings after the fix

**Plans**: 2 plans

Plans:

- [x] 080-01-PLAN.md — Fix estimate_total_catch_ungrouped() and estimate_total_catch_grouped() to use the stratified-sum estimator
- [x] 080-02-PLAN.md — Update multispecies generator with weekday/weekend calendar and confirm INV-06 passes under generated inputs

### Phase 81: Exploitation-Rate Estimator

**Goal**: Biologists can call `estimate_exploitation_rate()` with tagged-fish counts and creel-harvest data and receive stratum-level and aggregate exploitation-rate estimates documented with a worked example
**Depends on**: Phase 80 (clean estimator baseline)
**Requirements**: ESTIM-02, ESTIM-03, ESTIM-05
**Success Criteria** (what must be TRUE):

  1. `estimate_exploitation_rate()` accepts tagged-fish count and creel-harvest data and returns an exploitation rate using the Pollock et al. formulation
  2. `estimate_exploitation_rate()` returns stratum-level estimates when stratification is requested
  3. The Rd file for `estimate_exploitation_rate()` contains a self-contained worked example that runs without error under `devtools::check()`
  4. `pkgdown::build_site()` completes without error and the new function appears in the reference index

**Plans**: 3 plans

Plans:

- [x] 081-01-PLAN.md — implement estimate_exploitation_rate() unstratified path with TDD (ESTIM-02)
- [x] 081-02-PLAN.md — add stratified path and complete Roxygen docs with @examples (ESTIM-03, ESTIM-05)
- [x] 081-03-PLAN.md — integration gate: quickcheck invariants, rcmdcheck, pkgdown reference (ESTIM-05)

### Phase 82: Package Quality and Documentation

**Goal**: The package passes all pre-submission quality checks (urlchecker, rhub, goodpractice), the unused `lifecycle` import is removed, and the pkgdown site includes the tidycreel.connect bridge article
**Depends on**: Phase 81 (complete exported surface before quality sweep)
**Requirements**: QUAL-01, QUAL-02, QUAL-03, QUAL-04, DOCS-01
**Success Criteria** (what must be TRUE):

  1. `rcmdcheck` passes with 0 errors, 0 warnings, and no NOTE for an unused `lifecycle` import
  2. `urlchecker::url_check()` returns no broken URLs
  3. `rhub::rhub_check()` completes without errors on Linux and macOS platforms
  4. `goodpractice::gp()` findings at WARNING level and above are addressed
  5. The pkgdown site contains a `tidycreel.connect` bridge article that describes the companion package and links to it

**Plans**: 5 plans

Plans:

- [x] 082-01-PLAN.md — Remove `lifecycle` from DESCRIPTION/NAMESPACE and confirm rcmdcheck note is gone
- [x] 082-02-PLAN.md — Run urlchecker and fix any broken URLs
- [x] 082-03-PLAN.md — Run rhub checks and address any platform-specific findings
- [x] 082-04-PLAN.md — Run goodpractice and address WARNING-level findings
- [x] 082-05-PLAN.md — Write and publish the tidycreel.connect bridge article on the pkgdown site

</details>

_(v1.6.0 phase details archived — see [.planning/milestones/v1.6-ROADMAP.md](milestones/v1.6-ROADMAP.md))_

_(v1.7.0 phase details archived — see [.planning/milestones/v1.7-ROADMAP.md](milestones/v1.7-ROADMAP.md))_

---

### Phase 91: API Security and Hardening

**Goal**: `tidycreel.connect` connection and credential handling has no token-exposure or injection risks, NGPC discovery field names are confirmed in all rename maps, `list_creels()` returns a correctly-structured empty tibble on no-results, and `fetch_counts()` delivers `n_counted`/`n_interviewed` for bus-route API connections
**Depends on**: Phase 90 (v1.7.0 baseline — httr2 hardening, discovery generics, validation script in place)
**Requirements**: SEC-01, API-09, API-10, API-11
**Success Criteria** (what must be TRUE):

  1. A reviewer reading `tidycreel.connect` connection, credential-loading, and token-passing code finds no plaintext credential logging, no un-sanitized user input interpolated into URLs or SQL strings, and credentials sourced only from environment variables or a YAML file with documented permissions guidance
  2. All 6 `api_rename_map` entries in `creel-discovery.R` have TODO stubs replaced with confirmed NGPC field names and a confirming test or inline comment citing the source
  3. `list_creels(conn)` called against an API that returns zero surveys produces a zero-row tibble with the expected column names (not a 0-column tibble or NULL)
  4. `fetch_counts(conn, creel_id)` for a bus-route survey returns a data frame that includes both `n_counted` and `n_interviewed` columns with non-NA values where the API provides them
  5. All existing tests for `list_creels()`, `search_creels()`, and `fetch_counts()` continue to pass after the changes

**Plans**: 3 plans

Plans:

- [ ] 091-01-PLAN.md — SEC-01 security audit: audit and annotate credential handling in 4 tidycreel.connect source files
- [ ] 091-02-PLAN.md — API-10 empty tibble guard: fix list_creels() empty-return to tibble, add tibble to DESCRIPTION, update test
- [ ] 091-03-PLAN.md — API-09 + API-11 field confirmation: probe script, replace TODO stubs, add n_counted/n_interviewed to fetch_counts

---

### Phase 92: Package Health Gate

**Goal**: The package and its validation script pass all quality gates cleanly — `rcmdcheck` reports 0 warnings and the Calamus 2016 validation script runs correctly regardless of the working directory it is invoked from
**Depends on**: Phase 91 (API hardening complete; no new warnings introduced before gate is closed)
**Requirements**: QUAL-01, QUAL-02
**Success Criteria** (what must be TRUE):

  1. `inst/validation/calamus-2016-validation.R` executed via `Rscript path/to/script` from any working directory sets its own working directory or uses `here`/path-relative logic so all fixture file paths resolve without manual `setwd()`
  2. `rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "warning")` exits with 0 errors and 0 warnings across both the main package and `tidycreel.connect`
  3. The non-ASCII character warning (if in tidycreel.connect) is resolved by replacing the offending character or adding a `\uXXXX` escape
  4. The VignetteBuilder warning is resolved by either adding the correct `VignetteBuilder:` field to DESCRIPTION or removing the vignette infrastructure that triggers it

**Plans**: 3 plans

Plans:
**Wave 1**

- [x] 92-01-PLAN.md — QUAL-01: WD guard in calamus-2016-validation.R + test-validation-guard.R
- [x] 92-02-PLAN.md — QUAL-02: VignetteBuilder + knitr/rmarkdown Suggests in tidycreel.connect/DESCRIPTION + vignette smoke test

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 92-03-PLAN.md — QUAL-01+02 gate: rcmdcheck both packages confirm 0 errors, 0 warnings

---

### Phase 93: Reporting Exports

**Goal**: Analysts can extract a flat tibble from any `creel_estimates` object via `tidy()` and write estimates directly to CSV or Excel via `write_estimates()`, enabling reproducible reporting without manual coercion
**Depends on**: Phase 92 (clean rcmdcheck baseline before adding new exported functions)
**Requirements**: EXPORT-01, EXPORT-02
**Success Criteria** (what must be TRUE):

  1. `tidy(estimates)` called on any object with class `creel_estimates` returns a tibble where each row is one estimate and columns include at minimum the estimate value, SE, and CI bounds — no list-columns, no nested data frames
  2. `tidy()` works consistently across all estimator outputs that return `creel_estimates` objects: `estimate_total_harvest_br()`, `estimate_total_catch()`, `estimate_angler_n()`, `estimate_mr_harvest()`, and `estimate_exploitation_rate()`
  3. `write_estimates(estimates, path = "out.csv")` writes a CSV that, when read back with `read.csv()`, contains the same rows and columns as `tidy(estimates)`
  4. `write_estimates(estimates, path = "out.xlsx")` writes an Excel file when the `openxlsx` or `writexl` package is available (guarded with an informative error if not installed)
  5. `rcmdcheck` continues to pass with 0 warnings after the new exports and their Rd documentation are added

**Plans**: TBD
**UI hint**: no

---

### Phase 94: Bootstrap Confidence Intervals

**Goal**: Analysts can request bootstrap CIs from the four primary estimators by passing `ci_method = "bootstrap"`, giving interval estimates that do not rely on delta-method normality assumptions
**Depends on**: Phase 93 (EXPORT surface complete; `tidy()` output is verifiable test target for bootstrap CI columns)
**Requirements**: BOOT-01, BOOT-02, BOOT-03, BOOT-04
**Success Criteria** (what must be TRUE):

  1. `estimate_total_harvest_br(design, ci_method = "bootstrap")` returns a `creel_estimates` object whose `tidy()` output includes `ci_lo_boot` and `ci_hi_boot` columns alongside the existing delta-method columns
  2. `estimate_total_catch(design, ci_method = "bootstrap")` returns bootstrap CI columns under the same contract
  3. `estimate_angler_n(design, ci_method = "bootstrap")` returns bootstrap CI columns; the bootstrap samples the mark-recapture counts rather than survey replicates
  4. `estimate_mr_harvest(design, ci_method = "bootstrap")` propagates bootstrap uncertainty from `estimate_angler_n()` through the harvest calculation
  5. All four functions with `ci_method = "delta"` (the default) produce results numerically identical to their pre-bootstrap-CI outputs, confirmed by snapshot tests

**Plans**: TBD

---

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 80. INV-06 Fix and Quickcheck Proof | v1.5.0 | 2/2 | Complete | 2026-04-27 |
| 81. Exploitation-Rate Estimator | v1.5.0 | 3/3 | Complete | 2026-04-27 |
| 82. Package Quality and Documentation | v1.5.0 | 5/5 | Complete | 2026-04-28 |
| 83. Camera Design Helper | v1.6.0 | 2/2 | Complete | 2026-05-03 |
| 84. Camera Missing Data Imputation | v1.6.0 | 2/2 | Complete | 2026-05-03 |
| 85. Mark-Recapture Harvest Estimators | v1.6.0 | 2/2 | Complete | 2026-05-04 |
| 86. Stratification Audit | v1.6.0 | 2/2 | Complete | 2026-05-05 |
| 87. v1.6.0 Tech Debt Cleanup | v1.6.0 | 1/1 | Complete | 2026-05-05 |
| 88. httr2 Hardening and API Fetch Methods | v1.7.0 | 3/3 | Complete | 2026-05-09 |
| 89. Discovery Generics | v1.7.0 | 2/2 | Complete | 2026-05-10 |
| 90. Real-Data Validation | v1.7.0 | 2/2 | Complete | 2026-05-11 |
| 91. API Security and Hardening | v1.8.0 | 0/3 | Not started | - |
| 92. Package Health Gate | v1.8.0 | 2/3 | In Progress|  |
| 93. Reporting Exports | v1.8.0 | 0/TBD | Not started | - |
| 94. Bootstrap Confidence Intervals | v1.8.0 | 0/TBD | Not started | - |
