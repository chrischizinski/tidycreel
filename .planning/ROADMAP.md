# Roadmap — tidycreel

## Milestones

- ✅ **M022 — Comprehensive Project Evaluation** — Phases 70–75 (shipped 2026-04-19)
- 🚧 **M023 — Quality, Polish, and rOpenSci Readiness** — Phases 76–80 (in progress)

## Phases

<details>
<summary>✅ M022 — Comprehensive Project Evaluation (Phases 70–75) — SHIPPED 2026-04-19</summary>

- [x] Phase 70: Core Estimator Completeness — Bus-route, Aerial, Ice (1/1 plans) — completed 2026-04-15
- [x] Phase 71: Future Analytical Needs — Multi-species & Beyond (1/1 plans) — completed 2026-04-15
- [x] Phase 72: Architectural Principles & Dependency Review (2/2 plans) — completed 2026-04-16
- [x] Phase 73: Error Handling Strategy & creel.connect Investigation (2/2 plans) — completed 2026-04-17
- [x] Phase 74: Quality Bar Assessment — Tidyverse Quality & Testing Strategy (2/2 plans) — completed 2026-04-18
- [x] Phase 75: Performance Optimization — Rcpp Opportunity Identification (3/3 plans) — completed 2026-04-19

Full archive: [.planning/milestones/M022-ROADMAP.md](milestones/M022-ROADMAP.md)

</details>

### 🚧 M023 — Quality, Polish, and rOpenSci Readiness (In Progress)

**Milestone Goal:** Close all rOpenSci pre-submission blockers, reduce dependency footprint, adopt property-based testing, and resolve outstanding architectural decisions to make tidycreel v1.4.0 submission-ready.

- [x] **Phase 76: rOpenSci Blockers** — Named condition classes, lifecycle badges, CITATION, and scales removal (completed 2026-04-20)
- [x] **Phase 77: Dependency Reduction and Caller Context** — lubridate demotion, rlang::caller_env() in bus-route estimators, get_site_contributions() relocation (completed 2026-04-20)
- [ ] **Phase 78: Code Quality and Snapshot Testing** — @family tags across R/, expect_snapshot() adoption for 6 priority methods
- [ ] **Phase 79: Property-Based Testing and Coverage Gate** — quickcheck tests for INV-01–06, covr baseline, codecov threshold in CI
- [ ] **Phase 80: Architecture Decision and Human Verification** — creel_summary_* S3 direction committed, Phase 70 human verification complete

## Phase Details

### Phase 76: rOpenSci Blockers
**Goal**: All HIGH-priority rOpenSci pre-submission blockers are resolved — named condition classes exist at all 8 sites, lifecycle badges are applied, inst/CITATION is populated, and the scales dependency is dropped
**Depends on**: Phase 75 (M022 complete)
**Requirements**: ERRH-01, API-01, API-02, DEPS-01
**Success Criteria** (what must be TRUE):
  1. Each of the 8 priority cli::cli_abort call-sites uses a named condition class (e.g., `.internal_error_name_class`), verifiable by inspecting the R/ source
  2. `lifecycle` is listed in DESCRIPTION Imports and at least one deprecated/experimental function carries a `@lifecycle` badge visible in its rendered Rd page
  3. `inst/CITATION` exists and returns a valid citation via `citation("tidycreel")`
  4. `scales` is absent from DESCRIPTION Imports and the one `sprintf()` replacement in survey-bridge.R is in plain base R; `rcmdcheck` passes with 0 errors/warnings
**Plans**: 4 plans
Plans:
- [ ] 76-01-PLAN.md — Infrastructure: DESCRIPTION edits, lifecycle SVGs, inst/CITATION, test stubs
- [ ] 76-02-PLAN.md — Named condition classes at all 8 cli_abort sites + paired test updates
- [ ] 76-03-PLAN.md — lifecycle badges on 3 functions + scales::percent() replacement
- [ ] 76-04-PLAN.md — Integration gate: rcmdcheck + full test suite + visual badge verification

### Phase 77: Dependency Reduction and Caller Context
**Goal**: lubridate is no longer a hard dependency, bus-route estimators surface correct call context in error messages, and get_site_contributions() lives in its correct architectural layer
**Depends on**: Phase 76
**Requirements**: DEPS-02, CODE-02, CODE-03
**Success Criteria** (what must be TRUE):
  1. `lubridate` is listed under Suggests (not Imports) in DESCRIPTION; all use sites are guarded with `rlang::check_installed("lubridate")` and errors surface a clear install prompt when the package is absent
  2. `rlang::caller_env()` is passed through all bus-route estimator internal helpers so that user-facing error messages cite the user's call frame, not an internal function name
  3. `get_site_contributions()` is defined in the architectural layer identified in 72-ARCH-REVIEW.md (A1 finding); its previous location is removed
  4. `rcmdcheck` continues to pass with 0 errors/warnings after the moves
**Plans**: 3 plans
Plans:
- [ ] 77-01-PLAN.md — lubridate demotion: DESCRIPTION + check_installed guards at 4 entry points
- [ ] 77-02-PLAN.md — caller_env threading in 5 bus-route internals + get_site_contributions() relocation
- [ ] 77-03-PLAN.md — Integration gate: full test suite + rcmdcheck + human verification

### Phase 78: Code Quality and Snapshot Testing
**Goal**: Every exported function has a @family tag enabling pkgdown grouping, and expect_snapshot() covers the 6 priority output methods identified in 74-TESTING-STRATEGY.md
**Depends on**: Phase 77
**Requirements**: CODE-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. Every file in R/ that contains exported functions has at least one `@family` tag; `pkgdown::build_site()` produces grouped function reference pages
  2. Snapshot tests exist for each of the 6 priority methods listed in 74-TESTING-STRATEGY.md; snapshots are committed and pass on a clean `devtools::test()` run
  3. No existing tests are broken; overall test count is the same or higher than before this phase
**Plans**: TBD

### Phase 79: Property-Based Testing and Coverage Gate
**Goal**: quickcheck property-based tests exercise domain invariants INV-01 through INV-06 (excluding INV-05 which is manual-review only), and a codecov threshold is enforced in CI at the confirmed coverage baseline
**Depends on**: Phase 78
**Requirements**: TEST-01, TEST-03
**Success Criteria** (what must be TRUE):
  1. quickcheck tests are written and passing for INV-04, INV-01, INV-02, INV-06, and INV-03 (in that priority order); each test exercises randomized inputs that trigger the invariant
  2. A fresh `covr::package_coverage()` run confirms the coverage baseline (expected ~87%); the result is recorded in a comment or CI artifact
  3. A codecov threshold is configured in `.github/workflows/` (or equivalent CI config) such that coverage drops below the baseline cause CI to fail
  4. `rcmdcheck` and `devtools::test()` both pass after adding the new tests
**Plans**: TBD

### Phase 80: Architecture Decision and Human Verification
**Goal**: The creel_summary_* S3 subclass direction is formally committed or deferred with documented rationale, and Phase 70's deferred human verification is completed — vignette build and test suite both confirmed green
**Depends on**: Phase 79
**Requirements**: API-03, VER-01
**Success Criteria** (what must be TRUE):
  1. A written decision record exists (in PROJECT.md Key Decisions or a phase plan) stating whether creel_summary_* will adopt S3 subclasses in v1.4.0 or v1.5.0, with explicit rationale
  2. `pkgdown::build_site()` completes without errors or warnings and the deployed site renders all vignette pages correctly
  3. `rcmdcheck::rcmdcheck(args = c('--no-manual', '--as-cran'), error_on = 'warning')` reports 0 errors and 0 warnings
  4. `devtools::test()` reports 0 failures and 0 errors across the full test suite (2477+ tests)
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 70. Core Estimator Completeness | M022 | 1/1 | Complete | 2026-04-15 |
| 71. Future Analytical Needs | M022 | 1/1 | Complete | 2026-04-15 |
| 72. Architectural Review | M022 | 2/2 | Complete | 2026-04-16 |
| 73. Error Handling Strategy | M022 | 2/2 | Complete | 2026-04-17 |
| 74. Quality Bar Assessment | M022 | 2/2 | Complete | 2026-04-18 |
| 75. Performance Optimization | M022 | 3/3 | Complete | 2026-04-19 |
| 76. rOpenSci Blockers | 4/4 | Complete    | 2026-04-20 | - |
| 77. Dependency Reduction and Caller Context | 3/3 | Complete   | 2026-04-20 | - |
| 78. Code Quality and Snapshot Testing | M023 | 0/TBD | Not started | - |
| 79. Property-Based Testing and Coverage Gate | M023 | 0/TBD | Not started | - |
| 80. Architecture Decision and Human Verification | M023 | 0/TBD | Not started | - |
