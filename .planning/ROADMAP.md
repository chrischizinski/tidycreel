# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- ✅ **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (shipped 2026-02-16)
- ✅ **v0.4.0 Bus-Route Survey Support** — Phases 21-27 (shipped 2026-02-28)
- 🚧 **v0.5.0 Interview Data Model and Unextrapolated Summaries** — Phases 28-35 (in progress)

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
- [x] Phase 25: Bus-Route Harvest Estimation (2/2 plans) — completed 2026-02-24
- [x] Phase 26: Primary Source Validation (2/2 plans) — completed 2026-02-25
- [x] Phase 27: Documentation & Traceability (2/2 plans) — completed 2026-02-28

**Delivered:** Bus-route design constructor with nonuniform probabilities (πᵢ = p_site × p_period), enumeration expansion (n_counted/n_interviewed), effort/harvest estimators implementing Jones & Pollock (2012) Eq. 19.4-19.5, Malvestuto (1996) Box 20.6 reproduced exactly (E_hat = 847.5), complete workflow vignette and equation traceability document, 1,098 tests

See: [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md)

</details>

- ✅ **v0.5.0 Interview Data Model and Unextrapolated Summaries** — Phases 28–35 (shipped 2026-03-08) — See [.planning/milestones/v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md)

- ✅ **v0.6.0 Multiple Counts per PSU** — Phases 36–38 (shipped 2026-03-09)
  - [x] Phase 36 Plan 01: Multiple counts infrastructure — count_time_col, within-day aggregation, CNT-06 guard (2/2 plans complete)
  - [x] Phase 36 Plan 02: Within-day variance in estimate_effort() — Rasmussen two-stage formula, se_between/se_within columns (2/2 plans complete)
  - [x] Phase 37 Plan 01: Progressive count estimator — circuit_time, Ê_d computation, CNT-01/03/05/EFF-02 (1/1 plans complete)
  - [x] Phase 38 Plan 01: Roxygen fixes — add_counts() @examples for count_time_col and progressive, estimate_effort() @return for se_between/se_within (1/2 plans complete)
  - [x] Phase 38 Plan 02: flexible-count-estimation vignette — all three workflows, Pope et al. worked example, se_between/se_within interpretation table (1/1 plans complete)

- 🚧 **v0.7.0 Spatially Stratified Estimation** — Phases 39–42 (in progress — started 2026-03-10)
  - [x] Phase 39 Plan 01: add_sections() infrastructure — COMPLETE 2026-03-10
  - [x] Phase 39 Plan 02: Section test fixtures and failing stubs (SECT-01..05) (completed 2026-03-10)
  - [x] Phase 39 Plan 03: estimate_effort() section dispatch — rebuild_counts_survey, estimate_effort_sections, aggregate_section_totals (completed 2026-03-11)
  - [x] **Phase 40: Interview-Based Rate Estimators** (completed 2026-03-11)
  - [ ] **Phase 41: Product Estimators**
  - [ ] **Phase 42: Example Data and Vignette**

## Phase Details

### Phase 39: Section Effort Estimation

**Goal:** Users can call estimate_effort() on a sectioned design and receive per-section rows plus a correctly aggregated lake-wide total that accounts for cross-section covariance arising from shared day-level PSUs.

**Depends on:** Plan 39-01 (complete — add_sections() infrastructure shipped)

**Requirements:** SECT-01, SECT-02, SECT-03, SECT-04, SECT-05

**Plans:** 2/2 plans complete

Plans:
- [x] 39-01-PLAN.md — add_sections() infrastructure (COMPLETE)
- [ ] 39-02-PLAN.md — section test fixtures + failing stubs for SECT-01..05
- [ ] 39-03-PLAN.md — estimate_effort() section dispatch implementation

**Architectural notes:**
- `aggregate_section_totals()` must implement `svyby(covmat=TRUE)` + `svycontrast()` as the default path — NOT naive Cochran 5.2 additivity. Cochran 5.2 (`method = "independent"`) is available only for genuinely independent section designs where sections share no day-level PSUs.
- `rebuild_counts_survey()` helper (new, analogous to existing `rebuild_interview_survey()`) filters counts to one section and rebuilds a fresh svydesign so per-section SE uses that section's own PSU count as denominator.
- Every section-aware code path begins with `if (is.null(design$sections))` to leave all existing designs unchanged.
- Missing sections produce an NA row with `data_available = FALSE` and a `cli_warn()` before estimation begins.
- `prop_of_lake_total` derived from full-design `svytotal`, not from `sum(section_estimates)`.

**Success Criteria** (what must be TRUE):
  1. User calls `estimate_effort(design)` on a 3-section design and receives one row per section plus one `.lake_total` row, all in a single tibble
  2. The `.lake_total` SE is computed via `svyby(covmat=TRUE)` + `svycontrast()`, not by summing squared per-section SEs
  3. A design without `add_sections()` produces results byte-for-byte identical to pre-v0.7.0 behavior (zero regressions in 1,400+ existing tests)
  4. Calling `estimate_effort()` when a registered section has no observations produces an NA row with `data_available = FALSE` and a warning message
  5. Each section row includes a `prop_of_lake_total` column derived from the full-design lake estimate

---

### Phase 40: Interview-Based Rate Estimators

**Goal:** Rename `estimate_cpue()` → `estimate_catch_rate()` and `estimate_harvest()` → `estimate_harvest_rate()` for API consistency, then add section dispatch to all three rate estimators (`estimate_catch_rate()`, `estimate_harvest_rate()`, `estimate_release_rate()`) so users receive per-section rate rows. No lake-total row is produced — rates are not additive across sections.

**Depends on:** Phase 39 (shared infrastructure helpers — rebuild_counts_survey, aggregate_section_totals, bind_section_results, validate_section_estimation_prerequisites)

**Requirements:** RATE-01, RATE-02, RATE-03

**Architectural notes:**
- `estimate_cpue()` renamed to `estimate_catch_rate()` and `estimate_harvest()` renamed to `estimate_harvest_rate()` — breaking change in v0.7.0, no deprecated wrappers (Plan 40-01 complete).
- All three rate estimators with section dispatch MUST NOT produce a `.lake_total` row. Rates are not additive. Lake-wide rates require a separate unsectioned call. This is enforced by design, not convention.
- `rebuild_interview_survey()` already exists and is reused directly for per-section interview subsetting — same pattern as Phase 39's `rebuild_counts_survey()`.
- `missing_sections` guard applies to interview data: registered sections absent from interview data produce an NA row and a `cli_warn()` before estimation.

**Success Criteria** (what must be TRUE):
  1. `estimate_cpue()` and `estimate_harvest()` no longer exist; `estimate_catch_rate()` and `estimate_harvest_rate()` are exported and documented
  2. User calls `estimate_catch_rate(design)` on a 3-section design and receives exactly three per-section rows — no `.lake_total` row — with a doc-referenced explanation that lake-wide catch rate requires a separate unpooled call
  3. User calls `estimate_harvest_rate(design)` on a sectioned design and receives one row per registered section
  4. User calls `estimate_release_rate(design)` on a sectioned design and receives one row per registered section
  5. A registered section absent from interview data produces an NA row with `data_available = FALSE` and a warning for all three rate estimators

**Plans:** 2/2 plans complete

Plans:
- [x] 40-01-PLAN.md — function rename: estimate_cpue() → estimate_catch_rate(), estimate_harvest() → estimate_harvest_rate() (complete)
- [ ] 40-02-PLAN.md — section dispatch for all three rate estimators (estimate_catch_rate, estimate_harvest_rate, estimate_release_rate)

---

### Phase 41: Product Estimators

**Goal:** Users can call estimate_total_catch(), estimate_total_harvest(), and estimate_total_release() on a sectioned design and receive per-section totals plus a lake-wide aggregate row computed as the sum of per-section products, not as effort-total times pooled-CPUE.

**Depends on:** Phase 39 (per-section effort), Phase 40 (per-section rates)

**Requirements:** PROD-01, PROD-02

**Architectural notes:**
- Lake-wide aggregate = `sum(TC_i)` where `TC_i = E_i * CPUE_i` per section. Never `E_total * CPUE_pooled`.
- Delta method variance is unchanged from the existing lake-level implementation — only the inputs change (section-filtered designs).
- Cross-design covariance between the count-based effort design and the interview-based CPUE design is not identified; zero-covariance assumption applies (same as lake-level estimator) and must be documented explicitly.
- `prop_of_lake_total` uses the lake-wide estimate from the full-design `svytotal` as denominator, not `sum(section_estimates)`.

**Success Criteria** (what must be TRUE):
  1. User calls `estimate_total_catch(design)` on a 3-section design and receives one row per section plus one `.lake_total` row
  2. The `.lake_total` catch estimate equals `sum(E_i * CPUE_i)` across sections — not `E_total * CPUE_pooled` — and matches hand-calculation within floating point tolerance
  3. User calls `estimate_total_harvest(design)` and `estimate_total_release(design)` on a sectioned design and each returns per-section rows plus a correctly aggregated `.lake_total` row

**Plans:** 2 plans

Plans:
- [ ] 41-01-PLAN.md — section test fixtures and failing stubs (PROD-01/02)
- [ ] 41-02-PLAN.md — section dispatch implementation for all three product estimators

---

### Phase 42: Example Data and Vignette

**Goal:** Users have a realistic 3-section example dataset showing material variation across sections, and a vignette explaining the complete spatially stratified workflow including the correlated-domains vs. independent-strata variance decision.

**Depends on:** Phase 39, Phase 40, Phase 41 (all estimation functions must work before documenting them)

**Requirements:** DOCS-01, DOCS-02

**Architectural notes:**
- Dataset must show material variation across sections (different effort levels, different catch rates) to exercise the aggregation path and the missing-section warning path — not uniform sections that provide no meaningful coverage.
- Vignette must explain the variance aggregation decision in terms biologists understand (not just survey-package internals): why `method = "correlated"` is the default for standard NGPC shared-calendar designs, and when `method = "independent"` is appropriate.

**Success Criteria** (what must be TRUE):
  1. `data(example_sections_creel)` (or equivalent) loads a 3-section example dataset with materially different effort levels and catch rates across sections
  2. The vignette runs end-to-end with `devtools::build_vignettes()` and demonstrates: per-section effort, per-section CPUE (no lake-total row), per-section and lake-total catch, and the missing-section warning path
  3. The vignette explains in plain language why `method = "correlated"` is the correct default for shared-calendar field crew designs and what `method = "independent"` means

**Plans:** TBD

---

## Progress Summary

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 39. Section Effort Estimation | 2/2 | Complete    | 2026-03-11 |
| 40. Interview-Based Rate Estimators | 2/2 | Complete    | 2026-03-12 |
| 41. Product Estimators | 0/2 | Not started | — |
| 42. Example Data and Vignette | 0/? | Not started | — |

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 Foundation | 1-7 | 12/12 | ✅ Complete | 2026-02-09 |
| v0.2.0 Interview-Based Estimation | 8-12 | 10/10 | ✅ Complete | 2026-02-11 |
| v0.3.0 Incomplete Trips & Validation | 13-20 | 16/16 | ✅ Complete | 2026-02-16 |
| v0.4.0 Bus-Route Survey Support | 21-27 | 14/14 | ✅ Complete | 2026-02-28 |
| v0.5.0 Interview Data Model and Unextrapolated Summaries | 28-35 | 18/18 | ✅ Complete | 2026-03-08 |
| v0.6.0 Multiple Counts per PSU | 36–38 | 5/5 | ✅ Complete | 2026-03-09 |
| v0.7.0 Spatially Stratified Estimation | 39–42 | 1/? | 🚧 In progress | — |

**Overall:** 6 milestones shipped, 38 phases complete; v0.7.0 Phase 39 in progress

---
*Roadmap last updated: 2026-03-12 — Phase 41 plans created*
*See .planning/milestones/ for full milestone archives*
