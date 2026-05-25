# Roadmap: tidycreel

## Overview

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. Milestones are archived into `.planning/milestones/` to keep the live roadmap short and focused on whatever comes next.

## Milestones

- ✅ **M022 — Comprehensive Project Evaluation and Future Planning** — Phases 70-75 (shipped 2026-04-19)
- ✅ **M023 / v1.4.0 Quality, Polish, and rOpenSci Readiness** — Phases 76-79 (local closeout 2026-04-23) — see [.planning/milestones/v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)
- ✅ **M024 / v1.5.0 Analytical Extensions and rOpenSci Submission** — Phases 80-82 (shipped 2026-04-28) — see [.planning/milestones/v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6.0 — Analytical Extensions II** — Phases 83–87 (shipped 2026-05-06) — see [.planning/milestones/v1.6-ROADMAP.md](milestones/v1.6-ROADMAP.md)
- ✅ **v1.7.0 — API Connection & Real-Data Validation** — Phases 88–90 (shipped 2026-05-11) — see [.planning/milestones/v1.7-ROADMAP.md](milestones/v1.7-ROADMAP.md)
- ✅ **v1.8.0 — Exports, Bootstrap CIs, and API Hardening** — Phases 91–94 (shipped 2026-05-23) — see [.planning/milestones/v1.8.0-ROADMAP.md](milestones/v1.8.0-ROADMAP.md)
- **v1.9.0 — Report Completeness and Documentation Polish** — Phases 95–97 (active)

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

<details>
<summary>✅ v1.8.0 Exports, Bootstrap CIs, and API Hardening (Phases 91–94) — SHIPPED 2026-05-23</summary>

- [x] **Phase 91: API Security and Hardening** — Audit `tidycreel.connect` for credential exposure and injection risks; confirm NGPC discovery field names; close `list_creels()` 0-column guard; patch `fetch_counts()` bus-route E2E gap
- [x] **Phase 92: Package Health Gate** — Add working-directory guard to the Calamus 2016 validation script; resolve all rcmdcheck warnings so the 0-warnings gate holds before new code lands
- [x] **Phase 93: Reporting Exports** — Implement `tidy()` S3 method for `creel_estimates` objects and `write_estimates()` CSV/Excel file-write helpers
- [x] **Phase 94: Bootstrap Confidence Intervals** — Add `ci_method = "bootstrap"` to `estimate_total_harvest_br()`, `estimate_total_catch()`, `estimate_angler_n()`, and `estimate_mr_harvest()`

</details>

### v1.9.0 — Report Completeness and Documentation Polish

- [x] **Phase 95: Trip and Density Estimators** — Implement `estimate_angler_trips()` (effort / mean trip length, Delta Method SE) and `estimate_effort_per_acre()` (effort density wrapper), both returning `creel_estimates` objects (completed 2026-05-24)
- [ ] **Phase 96: Geographic Summary Functions** — Implement `summarize_boat_composition()`, `summarize_by_zip()`, and `summarize_by_county()` for NGPC standard report tabulations
- [ ] **Phase 97: Documentation Polish and Tech Debt** — Rebuild pkgdown at v1.9.0, confirm/update tidycreel.connect bridge article, add GitHub issue templates, and close the WRITE-11 xlsx test carry-forward

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

_(v1.8.0 phase details archived — see [.planning/milestones/v1.8.0-ROADMAP.md](milestones/v1.8.0-ROADMAP.md))_

---

### Phase 95: Trip and Density Estimators

**Goal**: Biologists can derive angler trip counts and effort density from an existing creel design using two new `creel_estimates`-returning functions
**Depends on**: Phase 94 (creel_estimates S3 class and bootstrap infrastructure complete)
**Requirements**: RPT-01, RPT-02
**Success Criteria** (what must be TRUE):

  1. Biologist can call `estimate_angler_trips(effort, design, conf_level = 0.95, ...)` and receive a `creel_estimates` object with per-stratum trip estimates computed as effort / mean trip length with Delta Method SE
  2. Biologist can call `estimate_effort_per_acre(effort, acres)` and receive angler-hours per acre by stratum, derived from the extrapolated effort estimate
  3. Both functions return objects that pass `inherits(result, "creel_estimates")` and are compatible with `tidy()` and `write_estimates()`
  4. `rcmdcheck` passes with 0 errors and 0 warnings after the new functions land

**Plans**: 2 plans

Plans:

- [x] 095-01-PLAN.md — implement estimate_angler_trips() with Delta Method SE and per-stratum .overall row
- [ ] 095-02-PLAN.md — implement estimate_effort_per_acre() and run rcmdcheck gate

---

### Phase 96: Geographic Summary Functions

**Goal**: Biologists can produce the three NGPC standard composition and origin summary tables — boat composition, zip-code origin, and county origin — directly from a creel design object
**Depends on**: Phase 95 (stable creel_design conventions confirmed in current milestone)
**Requirements**: RPT-03, RPT-04, RPT-05
**Success Criteria** (what must be TRUE):

  1. Biologist can call `summarize_boat_composition(design)` and receive a tibble of % angler boats by month and day type, computed from `c_AnglerBoats / (c_AnglerBoats + c_NonAngBoats)` in raw count data
  2. Biologist can call `summarize_by_zip(design)` and receive a tibble of interview count and percentage by zip code, derived from the `ii_ZipCode` interview field
  3. Biologist can call `summarize_by_county(design)` and receive a tibble of interview count and percentage by county, with zip-to-county mapping via `zipcodeR`; function emits a clear `cli_abort` when `zipcodeR` is not installed
  4. All three functions return plain tibbles (not `creel_estimates`), consistent with existing `summarize_*` conventions in the package
  5. `rcmdcheck` passes with 0 errors and 0 warnings after the new functions land

**Plans**: 2 plans

Plans:

**Wave 1**

- [ ] 96-01-PLAN.md — summarize_boat_composition() with three-guard pattern, schema-based column lookup, month x day_type grouping

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 96-02-PLAN.md — summarize_by_zip() and summarize_by_county() with Unknown row handling, zipcodeR guard, rcmdcheck gate

---

### Phase 97: Documentation Polish and Tech Debt

**Goal**: The pkgdown site reflects v1.9.0, the connect bridge article is present and accurate, GitHub issue templates exist, and the WRITE-11 xlsx test carry-forward is closed
**Depends on**: Phase 96 (all new functions landed so pkgdown rebuild captures the full v1.9.0 surface)
**Requirements**: DOC-01, DOC-02, DOC-03, TD-01
**Success Criteria** (what must be TRUE):

  1. `pkgdown::build_site()` completes without error and the site header shows the v1.9.0 version string (not stale "1.4.0"); DESCRIPTION version is bumped and committed
  2. The pkgdown site contains a tidycreel.connect bridge article explaining the companion package, how to install it, and linking to its documentation
  3. `.github/ISSUE_TEMPLATE/bug_report.yml` and `.github/ISSUE_TEMPLATE/feature_request.yml` exist with the specified fields; both validate as correct YAML
  4. `write_estimates()` xlsx path has a passing test using `skip_if_not_installed("writexl")`, and the test exercises the actual Excel write path

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
| 91. API Security and Hardening | v1.8.0 | 3/3 | Complete | 2026-05-16 |
| 92. Package Health Gate | v1.8.0 | 3/3 | Complete | 2026-05-20 |
| 93. Reporting Exports | v1.8.0 | 2/2 | Complete | 2026-05-20 |
| 94. Bootstrap Confidence Intervals | v1.8.0 | 3/3 | Complete | 2026-05-20 |
| 95. Trip and Density Estimators | v1.9.0 | 1/2 | In Progress|  |
| 96. Geographic Summary Functions | v1.9.0 | 0/2 | Not started | - |
| 97. Documentation Polish and Tech Debt | v1.9.0 | 0/TBD | Not started | - |
