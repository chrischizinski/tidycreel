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
- 📋 **v0.8.0 Non-Traditional Creel Designs** — Phases 44-47 (in progress)

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

### v0.8.0 Non-Traditional Creel Designs (Phases 44-47)

**Milestone Goal:** Extend tidycreel to support ice fishing, remote camera, and aerial creel survey designs as first-class `survey_type` values within the existing `creel_design()` entry point and three-layer architecture.

- [x] **Phase 44: Design Type Enum and Validation** - Lock dispatch enum with cli_abort() guard; register ice, camera, and aerial as valid survey_type values with Tier 1 validation (completed 2026-03-15)
- [ ] **Phase 45: Ice Fishing Survey Support** - Complete ice fishing design with p_site = 1.0 enforcement, effort definition flexibility, shelter-mode stratification, and interview-based estimation
- [ ] **Phase 46: Remote Camera Survey Support** - Counter and ingress-egress modes, camera_status gap handling, interview-based estimation, and documented example dataset
- [ ] **Phase 47: Aerial Survey Support** - estimate_effort_aerial() with ratio estimator and delta method variance, visibility correction, Malvestuto validation, and vignette

## Phase Details

### Phase 44: Design Type Enum and Validation
**Goal**: The dispatch layer is closed against unknown survey types — any unrecognized `survey_type` aborts with a clear error, and ice, camera, and aerial are registered with type-specific Tier 1 validation before any estimation code is written
**Depends on**: Phase 43 (v0.7.0 shipped)
**Requirements**: INFRA-01, INFRA-02, INFRA-03
**Success Criteria** (what must be TRUE):
  1. `creel_design(survey_type = "ice")`, `"camera"`, and `"aerial"` each construct without error when required parameters are supplied
  2. `creel_design(survey_type = "unknown_type")` aborts immediately with a `cli_abort()` message naming the unrecognized type — no silent fall-through to wrong estimators
  3. All 1,588 existing tests pass after enum registration blocks are added
  4. Each new survey type enforces its Tier 1 required parameters at construction time — missing required columns abort at `creel_design()`, not at estimation time
**Plans**: 2 plans

Plans:
- [ ] 44-01-PLAN.md — TDD: VALID_SURVEY_TYPES enum guard and ice/camera/aerial constructor stubs (INFRA-01, INFRA-02)
- [ ] 44-02-PLAN.md — Full regression suite and quality gates (INFRA-03)

### Phase 45: Ice Fishing Survey Support
**Goal**: Biologists can run a complete ice fishing creel survey analysis — from design construction through effort estimation and catch rate / total catch estimation — using the existing `creel_design()` entry point and interview workflow
**Depends on**: Phase 44
**Requirements**: ICE-01, ICE-02, ICE-03, ICE-04
**Success Criteria** (what must be TRUE):
  1. `estimate_effort()` on an ice fishing design routes through the bus-route infrastructure with `p_site = 1.0` enforced automatically — no manual inclusion probability calculation needed
  2. A biologist can supply either time-on-ice or active-fishing-time as the effort column and obtain correctly labeled estimates — the distinction is enforced by documentation and the `angler_effort_col` parameter
  3. `estimate_effort(by = shelter_mode)` (or equivalent grouping variable) produces per-shelter stratum effort estimates using the existing `by =` mechanism
  4. After `add_interviews()`, `estimate_catch_rate()` and `estimate_total_catch()` produce valid estimates on an ice fishing design, confirming interview compatibility
**Plans**: TBD

### Phase 46: Remote Camera Survey Support
**Goal**: Biologists can estimate effort from camera-based access-point data in either counter mode or ingress-egress mode, handle non-random camera failures as informative gaps rather than missing data, and run the full interview-based estimation workflow on a camera design
**Depends on**: Phase 44
**Requirements**: CAM-01, CAM-02, CAM-03, CAM-04, CAM-05
**Success Criteria** (what must be TRUE):
  1. Counter mode: daily ingress counts route through the existing access-point effort path and produce effort estimates equivalent to what a human-counted access-point survey would produce
  2. Ingress-egress mode: timestamp pairs are accumulated to daily effort via `difftime()` preprocessing before entering the estimation path — users supply raw timestamp pairs and receive effort estimates
  3. A `camera_status` column classifies non-random failures (battery, memory, occlusion) separately from random missingness handled by `missing_sections` — informative gaps are not imputed as zero effort
  4. After `add_interviews()`, `estimate_catch_rate()` and `estimate_total_catch()` produce valid estimates on a camera design, confirming interview compatibility
  5. An example dataset covering both counter and ingress-egress sub-modes and at least one non-random gap is documented and ships with the package
**Plans**: TBD

### Phase 47: Aerial Survey Support
**Goal**: Biologists can estimate total angler effort from aerial instantaneous counts using the correct expansion formula, with delta method variance, an optional visibility correction factor, and verification against the Malvestuto (1996) worked example — and can run the full interview-based estimation workflow on an aerial design
**Depends on**: Phase 44
**Requirements**: AIR-01, AIR-02, AIR-03, AIR-04, AIR-05, AIR-06
**Success Criteria** (what must be TRUE):
  1. `estimate_effort()` on an aerial design applies the expansion formula `N_counted × H_open × mean_trip_duration` — the raw angler count is never returned as effort without expansion
  2. The effort estimate includes delta method variance that correctly propagates uncertainty from both the angler count and the mean trip duration components
  3. A biologist can supply a visibility correction factor (e.g., 0.85) as a calibration parameter and receive corrected effort estimates — the correction is applied before variance propagation
  4. The aerial estimator reproduces the Malvestuto (1996) Box 20.6 worked example within numerical tolerance (same validation strategy used for bus-route in Phase 26)
  5. After `add_interviews()`, `estimate_catch_rate()` and `estimate_total_catch()` produce valid estimates on an aerial design, confirming interview compatibility
  6. An example dataset and vignette ship with the package demonstrating the complete aerial workflow from design construction through total catch estimation
**Plans**: TBD

## Progress Summary

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 44. Design Type Enum and Validation | 2/2 | Complete   | 2026-03-15 |
| 45. Ice Fishing Survey Support | 0/TBD | Not started | - |
| 46. Remote Camera Survey Support | 0/TBD | Not started | - |
| 47. Aerial Survey Support | 0/TBD | Not started | - |

**Overall (v0.8.0):** 0/4 phases complete

---
*Roadmap last updated: 2026-03-15 — Phase 44 planned (2 plans)*
*See .planning/milestones/ for archived milestone roadmaps*
