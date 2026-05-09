# Roadmap: tidycreel

## Overview

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. Milestones are archived into `.planning/milestones/` to keep the live roadmap short and focused on whatever comes next.

## Milestones

- ✅ **M022 — Comprehensive Project Evaluation and Future Planning** — Phases 70-75 (shipped 2026-04-19)
- ✅ **M023 / v1.4.0 Quality, Polish, and rOpenSci Readiness** — Phases 76-79 (local closeout 2026-04-23) — see [.planning/milestones/v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)
- ✅ **M024 / v1.5.0 Analytical Extensions and rOpenSci Submission** — Phases 80-82 (shipped 2026-04-28) — see [.planning/milestones/v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)
- ✅ **v1.6.0 — Analytical Extensions II** — Phases 83–87 (shipped 2026-05-06) — see [.planning/milestones/v1.6-ROADMAP.md](milestones/v1.6-ROADMAP.md)
- 📋 **v1.7.0 — API Connection & Real-Data Validation** — Phases 88–90 (in progress)

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

### v1.7.0 — API Connection & Real-Data Validation (Phases 88–90)

- [ ] **Phase 88: httr2 Hardening and API Fetch Methods** — Harden `.api_fetch()` with `req_error`/`req_retry` and implement all five `fetch_*.creel_connection_api` S3 methods with hardcoded field rename maps
- [ ] **Phase 89: Discovery Generics** — Add `list_creels()` and `search_creels()` generics with API implementations and CSV/SQL stubs in a new `creel-discovery.R` file
- [ ] **Phase 90: Real-Data Validation** — Integration script in `inst/validation/` runs the full bus-route pipeline on Calamus 2016 archived data and reports whether estimates match archived reference outputs

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

### Phase 88: httr2 Hardening and API Fetch Methods
**Goal**: Users can call any `fetch_*` method on a `creel_connection_api` object and receive a canonical data frame, backed by an HTTP layer that surfaces structured errors and retries on transient failures
**Depends on**: Phase 87 (stable v1.6.0 baseline; existing `.api_fetch()` infrastructure in `tidycreel.connect`)
**Requirements**: API-01, API-02, API-03, API-04, API-05, API-06
**Success Criteria** (what must be TRUE):
  1. `fetch_interviews()` on a `creel_connection_api` object returns a data frame with columns `interview_uid`, `date`, `catch_count`, `effort`, `trip_status` and effort computed as hours + minutes/60
  2. `fetch_counts()`, `fetch_catch()`, `fetch_harvest_lengths()`, and `fetch_release_lengths()` each return data frames with their respective canonical columns as specified in requirements API-02 through API-05
  3. When the API returns a non-2xx response, `.api_fetch()` aborts with a human-readable cli error message that includes the HTTP status code and API-provided error body
  4. When the API returns a 429 or 503 status, `.api_fetch()` retries up to 3 times before aborting
  5. `httr2` is declared in `Imports` (not `Suggests`) in `tidycreel.connect/DESCRIPTION` with floor `>= 1.0.0`
**Plans**: 3 plans

Plans:
- [ ] 088-01-PLAN.md — Promote httr2 to Imports, harden .api_fetch() with req_error/req_retry/cli_abort, write helper-api.R and test-api-fetch.R (API-06)
- [ ] 088-02-PLAN.md — Add fetch_interviews.creel_connection_api and fetch_counts.creel_connection_api with tests (API-01, API-02)
- [ ] 088-03-PLAN.md — Add fetch_catch, fetch_harvest_lengths, fetch_release_lengths API methods with tests (API-03, API-04, API-05)

### Phase 89: Discovery Generics
**Goal**: Users can discover available surveys on a connected API before fetching data, and receive a clean "not supported" error when calling discovery functions on CSV or SQL Server connections
**Depends on**: Phase 88 (hardened `.api_fetch()` auth and error infrastructure)
**Requirements**: API-07, API-08
**Success Criteria** (what must be TRUE):
  1. `list_creels()` on a `creel_connection_api` object returns a data frame with columns `creel_uid`, `title`, `description`, `active`, `data_complete`, `comments` containing all surveys available on the connected API
  2. `search_creels(conn, keyword)` returns the same column shape as `list_creels()` filtered to surveys matching the keyword string
  3. Calling `list_creels()` or `search_creels()` on a CSV or SQL Server connection object produces a cli error message indicating the method is not supported for that connection type (no "no applicable method" crash)
**Plans**: TBD

### Phase 90: Real-Data Validation
**Goal**: A standalone script demonstrates end-to-end correctness of the estimation pipeline on real survey data, confirming that effort, catch, and harvest estimates match archived reference values from the Calamus 2016 bus-route survey
**Depends on**: Phase 88 (canonical fetch output used as pipeline input)
**Requirements**: REAL-01
**Success Criteria** (what must be TRUE):
  1. Running `inst/validation/calamus-2016-validation.R` completes without error using the archived Calamus 2016 CSV fixtures
  2. The script reports whether effort, catch, and harvest estimates are within acceptable tolerance of the archived reference comparison outputs, printing a pass/fail summary to the console
  3. The script handles the known Calamus 2016 data characteristics without silent errors: intentionally duplicated interview UIDs, three-value `catch_type` including "caught", species code `86` as distinct from `862`
  4. The script is offline-capable (uses static fixture files, not live API calls) so it can run in CI without network access
**Plans**: TBD

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
| 88. httr2 Hardening and API Fetch Methods | v1.7.0 | 0/3 | Not started | — |
| 89. Discovery Generics | v1.7.0 | 0/? | Not started | — |
| 90. Real-Data Validation | v1.7.0 | 0/? | Not started | — |
