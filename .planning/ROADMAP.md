# Roadmap: tidycreel

## Overview

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. Milestones are archived into `.planning/milestones/` to keep the live roadmap short and focused on whatever comes next.

## Milestones

- ✅ **M022 — Comprehensive Project Evaluation and Future Planning** — Phases 70-75 (shipped 2026-04-19)
- ✅ **M023 / v1.4.0 Quality, Polish, and rOpenSci Readiness** — Phases 76-79 (local closeout 2026-04-23) — see [.planning/milestones/v1.4-ROADMAP.md](milestones/v1.4-ROADMAP.md)
- 🚧 **M024 / v1.5.0 Analytical Extensions and rOpenSci Submission** — Phases 80-83 (in progress) — see [.planning/milestones/v1.5-ROADMAP.md](milestones/v1.5-ROADMAP.md)

## Phases

- [x] **Phase 80: INV-06 Fix and Quickcheck Proof** - Correct the stratified-sum inconsistency in `estimate_total_catch()` and verify it with the INV-06 property test (completed 2026-04-27)
- [ ] **Phase 81: Exploitation-Rate Estimator** - Implement, stratify, and document `estimate_exploitation_rate()` using the Pollock et al. formulation
- [ ] **Phase 82: Package Quality and Documentation** - Remove the unused `lifecycle` import, pass urlchecker/rhub/goodpractice checks, and add the tidycreel.connect bridge article
- [ ] **Phase 83: rOpenSci Submission** - Open the software-review issue and close out the milestone

## Phase Details

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
- [ ] 080-01-PLAN.md — Fix estimate_total_catch_ungrouped() and estimate_total_catch_grouped() to use the stratified-sum estimator
- [ ] 080-02-PLAN.md — Update multispecies generator with weekday/weekend calendar and confirm INV-06 passes under generated inputs

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
- [ ] 081-01-PLAN.md — implement estimate_exploitation_rate() unstratified path with TDD (ESTIM-02)
- [ ] 081-02-PLAN.md — add stratified path and complete Roxygen docs with @examples (ESTIM-03, ESTIM-05)
- [ ] 081-03-PLAN.md — integration gate: quickcheck invariants, rcmdcheck, pkgdown reference (ESTIM-05)

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
**Plans**: TBD

Plans:
- [ ] 82-01: Remove `lifecycle` from DESCRIPTION/NAMESPACE and confirm rcmdcheck note is gone
- [ ] 82-02: Run urlchecker and fix any broken URLs
- [ ] 82-03: Run rhub checks and address any platform-specific findings
- [ ] 82-04: Run goodpractice and address WARNING-level findings
- [ ] 82-05: Write and publish the tidycreel.connect bridge article on the pkgdown site

### Phase 83: rOpenSci Submission
**Goal**: The package is formally submitted to rOpenSci software review and the M024 milestone is closed out
**Depends on**: Phase 82 (all quality gates passed)
**Requirements**: QUAL-05
**Success Criteria** (what must be TRUE):
  1. A pre-submission enquiry or software-review issue is opened at ropensci/software-review with the package URL and scope description
  2. The issue number is recorded in `.planning/PROJECT.md`
  3. M024 milestone planning documents are marked complete and archived
**Plans**: TBD

Plans:
- [ ] 83-01: Complete rOpenSci pre-submission checklist, open the software-review issue, and close out M024

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 80. INV-06 Fix and Quickcheck Proof | 2/2 | Complete    | 2026-04-27 | - |
| 81. Exploitation-Rate Estimator | M024 / v1.5.0 | 0/3 | Not started | - |
| 82. Package Quality and Documentation | M024 / v1.5.0 | 0/5 | Not started | - |
| 83. rOpenSci Submission | M024 / v1.5.0 | 0/1 | Not started | - |
