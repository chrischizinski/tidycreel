# Roadmap: tidycreel

## Overview

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. Milestones are archived into `.planning/milestones/` to keep the live roadmap short and focused on whatever comes next.

## Milestones

- ✅ **M022 — Comprehensive Project Evaluation and Future Planning** — Phases 70-75 (shipped 2026-04-19)
- ✅ **M023 / v1.4.0 Quality, Polish, and rOpenSci Readiness** — Phases 76-79 (local closeout 2026-04-23) — see [.planning/milestones/v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)
- ✅ **M024 / v1.5.0 Analytical Extensions and rOpenSci Submission** — Phases 80-82 (shipped 2026-04-28) — see [.planning/milestones/v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)
- 🚧 **v1.6.0 — Analytical Extensions II** — Phases 83-86 (in progress)

## Phases

<details>
<summary>✅ v1.5.0 Analytical Extensions (Phases 80-82) - SHIPPED 2026-04-28</summary>

- [x] **Phase 80: INV-06 Fix and Quickcheck Proof** - Correct the stratified-sum inconsistency in `estimate_total_catch()` and verify it with the INV-06 property test (completed 2026-04-27)
- [x] **Phase 81: Exploitation-Rate Estimator** - Implement, stratify, and document `estimate_exploitation_rate()` using the Pollock et al. formulation (completed 2026-04-27)
- [x] **Phase 82: Package Quality and Documentation** - Remove the unused `lifecycle` import, pass urlchecker/rhub/goodpractice checks, and add the tidycreel.connect bridge article (completed 2026-04-28)

</details>

### v1.6.0 Analytical Extensions II

- [ ] **Phase 83: Camera Design Helper** - Implement `creel_n_camera()` for per-stratum camera-day sample size using the Cochran CV formula
- [ ] **Phase 84: Camera Missing Data Imputation** - Implement `impute_camera_counts()` with a GLM default tier and opt-in GLMM tier, schema-compatible with `add_counts()`
- [ ] **Phase 85: Mark-Recapture Harvest Estimators** - Implement `estimate_angler_n()` (Chapman/Petersen/Schnabel) and `estimate_mr_harvest()` for closed-population harvest estimation
- [ ] **Phase 86: Stratification Audit** - Implement `audit_strata()`, `simulate_strata_collapse()`, and `reallocate_strata()` for effort-precision-driven design evaluation

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

### Phase 83: Camera Design Helper
**Goal**: Biologists can compute required camera-days per stratum for a target CV using `creel_n_camera()`, with output that matches the shape of `creel_n_effort()` and warns on empirically-grounded minimums
**Depends on**: Phase 82 (clean package baseline)
**Requirements**: CDES-01, CDES-02, CDES-03
**Success Criteria** (what must be TRUE):
  1. User can call `creel_n_camera(cv_target, N_h, ybar_h, s2_h)` and receive a named integer vector of required camera-days per stratum plus a `"total"` element
  2. Output shape is consistent with `creel_n_effort()` — same vector structure, same naming convention
  3. A `cli_warn()` message appears when any stratum's computed n falls below the Feltz-Middaugh (2025) empirical minimums (~12 weekday, ~7 weekend)
  4. `rcmdcheck` passes with 0 errors and 0 warnings after the addition
**Plans**: 2 plans

Plans:
- [ ] 083-01-PLAN.md — Implement creel_n_camera() in R/power-sample-size.R, run devtools::document(), and add to _pkgdown.yml
- [ ] 083-02-PLAN.md — Append creel_n_camera test block to test-power-sample-size.R and run devtools::check() quality gate

### Phase 84: Camera Missing Data Imputation
**Goal**: Biologists can call `impute_camera_counts()` on a camera count frame with a status column and receive a complete, schema-compatible frame ready to pass directly into `add_counts()`, with diagnostics for high-missingness strata
**Depends on**: Phase 83 (camera vocabulary established)
**Requirements**: CAMP-01, CAMP-02, CAMP-03, CAMP-04, CAMP-05
**Success Criteria** (what must be TRUE):
  1. User can call `impute_camera_counts(data, method = "glm")` and receive a filled count frame where outage rows are imputed using a day-type GLM (Hartill 2016)
  2. User can call `impute_camera_counts(data, method = "glmm")` and the function installs / requests `glmmTMB` via `rlang::check_installed()` before applying the ZINB GLMM (Afrifa-Yamoah 2020)
  3. The output data frame passes directly into `add_counts()` without column manipulation — the full `impute → add_counts → est_effort_camera()` chain runs without error
  4. A `cli_warn()` fires when the missing fraction in any stratum exceeds 50%
  5. The function aborts with an informative `cli_abort()` message when an entire stratum contains no observed counts
**Plans**: TBD

### Phase 85: Mark-Recapture Harvest Estimators
**Goal**: Biologists can estimate angler population size from mark-recapture data using Chapman (default), Petersen, or Schnabel estimators via `estimate_angler_n()`, and can propagate that uncertainty into total harvest via `estimate_mr_harvest()`
**Depends on**: Phase 82 (clean estimator baseline; no hard dependency on 83-84)
**Requirements**: MR-01, MR-02, MR-03, MR-04, MR-05, MR-06
**Success Criteria** (what must be TRUE):
  1. User can call `estimate_angler_n(M, n, m)` with the Chapman correction (default) and receive a population size estimate with SE and CI
  2. User can request the unadjusted Petersen estimator via `method = "petersen"` when recaptures m >= 7
  3. User can pass multi-occasion data and request the Schnabel estimator via `method = "schnabel"`
  4. The function aborts with informative `cli_abort()` messages on impossible inputs (m = 0, m > n, m > M)
  5. Return value is a `creel_estimates` S3 object — `compare_designs()` and `autoplot()` work without modification
  6. User can call `estimate_mr_harvest(N_hat, se_N, harvest_rate)` and receive total harvest with delta-method SE propagated from N_hat uncertainty
**Plans**: TBD

### Phase 86: Stratification Audit
**Goal**: Biologists can evaluate per-stratum effort precision from a completed creel design or pilot summary statistics, simulate strata merges, and compute Neyman-optimal reallocation of a fixed sampling budget
**Depends on**: Phase 82 (clean package baseline; no hard dependency on 83-85)
**Requirements**: STRAT-01, STRAT-02, STRAT-03, STRAT-04, STRAT-05
**Success Criteria** (what must be TRUE):
  1. User can call `audit_strata(creel_design)` or `audit_strata(N_h, ybar_h, s2_h)` and receive per-stratum RSE, n, a meets-target flag, and DEFF in a `creel_strata_audit` S3 object
  2. User can call `simulate_strata_collapse(audit, merge_strata)` specifying strata to merge and receive a before/after precision comparison as a tibble
  3. User can call `reallocate_strata(n_total, N_h, s2_h)` and receive Neyman-optimal sample counts per stratum as a named vector
  4. `creel_strata_audit` output includes DEFF to quantify the value of the current stratification scheme relative to simple random sampling
  5. `rcmdcheck` passes with 0 errors and 0 warnings after all three functions are added
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 80. INV-06 Fix and Quickcheck Proof | v1.5.0 | 2/2 | Complete | 2026-04-27 |
| 81. Exploitation-Rate Estimator | v1.5.0 | 3/3 | Complete | 2026-04-27 |
| 82. Package Quality and Documentation | v1.5.0 | 5/5 | Complete | 2026-04-28 |
| 83. Camera Design Helper | v1.6.0 | 0/2 | Not started | - |
| 84. Camera Missing Data Imputation | v1.6.0 | 0/TBD | Not started | - |
| 85. Mark-Recapture Harvest Estimators | v1.6.0 | 0/TBD | Not started | - |
| 86. Stratification Audit | v1.6.0 | 0/TBD | Not started | - |
