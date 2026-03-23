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
- 🚧 **v0.9.0 Survey Planning & Quality of Life** — Phases 48-51 (in progress)

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

### 🚧 v0.9.0 Survey Planning & Quality of Life (In Progress)

**Milestone Goal:** Add pre-season planning tools (schedule generators, sample size calculators, design validator) and post-season diagnostics (completeness checker, season summary) around the existing five-survey-type estimation pipeline.

## Phase Details

### Phase 48: Schedule Generators
**Goal**: Biologists can generate a verified sampling calendar and bus-route schedule from season parameters, then export either for field use
**Depends on**: Nothing (no dependency on other v0.9.0 phases; all downstream planning tools depend on this)
**Requirements**: SCHED-01, SCHED-02, SCHED-03, SCHED-04
**Success Criteria** (what must be TRUE):
  1. User can call `generate_schedule()` with season dates, day-type split, period count, and sampling intensity and receive a tidy tibble with `date`, `day_type`, and `period_id` columns
  2. User can pipe a schedule tibble into `generate_bus_schedule()` with circuit definitions and crew size and receive a tibble with `inclusion_prob` columns that passes directly to `creel_design(survey_type = "bus_route")`
  3. User can call `write_schedule()` on any schedule tibble and produce a CSV file (base R, no dependencies) or xlsx file (writexl, when installed)
  4. User can call `read_schedule()` on a previously saved CSV or xlsx file and receive a validated `creel_schedule` object with correct column types (Date, character day_type, etc.) ready to pass to `creel_design()`
  5. A schedule tibble round-trips through write → read → `creel_design()` without column name or type errors
**Plans**: 3 plans

Plans:
- [ ] 48-01-PLAN.md — DESCRIPTION updates, test scaffolds, generate_schedule() (SCHED-01)
- [ ] 48-02-PLAN.md — generate_bus_schedule() (SCHED-02)
- [ ] 48-03-PLAN.md — write_schedule() + read_schedule() + round-trip (SCHED-03, SCHED-04)

### Phase 49: Power and Sample Size
**Goal**: Biologists can calculate required sample sizes and statistical power from survey design parameters using published creel survey formulas, before any data collection begins
**Depends on**: Nothing (analytically independent; no creel_design dependency)
**Requirements**: POWER-01, POWER-02, POWER-03, POWER-04
**Success Criteria** (what must be TRUE):
  1. User can call `creel_n_effort()` with a target CV and stratum parameters and receive the number of sampling days required, reproducing McCormick & Quist (2017) Table 2 benchmark values numerically
  2. User can call `creel_n_cpue()` with a target CV and ratio estimator variance inputs and receive the number of interviews required, using the Cochran (1977) eq. 6.13 formula
  3. User can call `creel_power()` with alpha, historical CV, sample size, and a target percent CPUE change and receive estimated statistical power for detecting that change between two seasons
  4. User can call `cv_from_n()` with a known sample size and receive the expected CV — the inverse calculation of both effort and CPUE sample size functions
**Plans**: TBD

### Phase 50: Design Validator and Completeness Checker
**Goal**: Biologists can validate a proposed design before the season starts and diagnose data gaps after the season ends, both in a single function call
**Depends on**: Phase 49 (validate_design calls creel_n_effort() and creel_n_cpue() internally)
**Requirements**: VALID-01, QUAL-01
**Success Criteria** (what must be TRUE):
  1. User can call `validate_design()` with a proposed sampling frame and receive a tibble with pass/warn/fail status per stratum — no duplication of the CV formula from Phase 49
  2. User can call `check_completeness()` on a completed creel_design and receive a report of missing sampling days, strata below a user-specified n threshold, and refusal rates — dispatched by survey_type so aerial and ice designs produce zero false-positive flags
  3. All five survey types (instantaneous, bus_route, ice, camera, aerial) pass through `check_completeness()` without triggering warnings on legitimate survey-type-specific NA patterns
**Plans**: TBD

### Phase 51: Season Summary
**Goal**: Biologists can assemble a full season's pre-computed estimates into a single report-ready wide tibble without re-deriving any values from raw data
**Depends on**: Phase 50 (print method conventions established in Phase 50 inform the companion season summary print method)
**Requirements**: REPT-01
**Success Criteria** (what must be TRUE):
  1. User can call `season_summary()` with a named list of pre-computed `creel_estimates` objects and receive a single wide tibble containing effort, catch rate, and total catch/harvest columns
  2. The wide tibble values match numerically the individual `estimate_*()` outputs that were passed in — no re-estimation from raw data
  3. The season summary tibble exports correctly to CSV and xlsx via `write_schedule()` with numeric column types preserved on round-trip read
**Plans**: TBD

## Progress

**Execution Order:**
Phases 48 and 49 are parallel-capable (no mutual dependency). Phase 50 follows Phase 49. Phase 51 follows Phase 50.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 44. Design Type Enum and Validation | v0.8.0 | 2/2 | Complete | 2026-03-15 |
| 45. Ice Fishing Survey Support | v0.8.0 | 3/3 | Complete | 2026-03-16 |
| 46. Remote Camera Survey Support | v0.8.0 | 3/3 | Complete | 2026-03-16 |
| 47. Aerial Survey Support | v0.8.0 | 3/3 | Complete | 2026-03-22 |
| 48. Schedule Generators | 2/3 | In Progress|  | - |
| 49. Power and Sample Size | v0.9.0 | 0/TBD | Not started | - |
| 50. Design Validator and Completeness Checker | v0.9.0 | 0/TBD | Not started | - |
| 51. Season Summary | v0.9.0 | 0/TBD | Not started | - |

---
*Roadmap last updated: 2026-03-23 — Phase 48 planned (3 plans)*
*See .planning/milestones/ for archived milestone roadmaps*
