# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- 🚧 **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (in progress)

## Phases

<details>
<summary>✅ v0.1.0 Foundation (Phases 1-7) — SHIPPED 2026-02-09</summary>

**Milestone Goal:** Establish package foundation with instantaneous count design and effort estimation, proving the three-layer architecture (API → Orchestration → Survey) works end-to-end.

### Phase 1: Package Foundation
- [x] 3/3 plans complete
- Package structure with CI/CD and quality gates
- R CMD check, lintr, testthat infrastructure

### Phase 2: Design Constructor
- [x] 2/2 plans complete
- creel_design() constructor with tidy selectors
- Progressive validation (Tier 1)

### Phase 3: Count Data Integration
- [x] 2/2 plans complete
- add_counts() for instantaneous count data
- Survey design construction (day-PSU)

### Phase 4: Basic Effort Estimation
- [x] 2/2 plans complete
- estimate_effort() returning estimates with SE/CI
- Reference tests vs manual survey calculations

### Phase 5: Grouped Estimation
- [x] 1/1 plan complete
- Grouped effort estimates with by= parameter

### Phase 6: Variance Methods
- [x] 2/2 plans complete
- Variance method control (Taylor, bootstrap, jackknife)

### Phase 7: Documentation & Quality Assurance
- [x] 2/2 plans complete
- Getting Started vignette
- 253 tests, 88.75% coverage

**Delivered:** Three-layer architecture proven, design-centric API operational, progressive validation working, complete estimation capability with multiple variance methods, production-ready quality gates

See: [.planning/milestones/v0.1.0-ROADMAP.md](milestones/v0.1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.2.0 Interview-Based Estimation (Phases 8-12) — SHIPPED 2026-02-11</summary>

**Milestone Goal:** Enable catch and harvest estimation by adding interview data analysis to existing instantaneous count design foundation.

### Phase 8: Interview Data Integration
- [x] 2/2 plans complete
- add_interviews() with tidy selectors for catch, effort, harvest
- Tier 1/2 validation, interview survey construction (ids=~1)
- example_interviews dataset (22 interviews, access point complete trips)

### Phase 9: CPUE Estimation
- [x] 2/2 plans complete
- estimate_cpue() with ratio-of-means estimator (survey::svyratio)
- Sample size validation (n<10 error, n<30 warning)
- Grouped estimation support, variance method integration

### Phase 10: Catch and Harvest Estimation
- [x] 2/2 plans complete
- estimate_harvest() for harvest per unit effort (HPUE)
- Shared validate_ratio_sample_size() for CPUE and harvest
- Reference tests proving correctness (tolerance 1e-10)

### Phase 11: Total Catch Estimation
- [x] 2/2 plans complete
- estimate_total_catch() and estimate_total_harvest()
- Delta method variance propagation (Var(E×C) = E²·Var(C) + C²·Var(E))
- Design compatibility validation

### Phase 12: Documentation and Quality Assurance
- [x] 2/2 plans complete
- Interview-based estimation vignette (complete workflow)
- 610 tests, 89.24% coverage (exceeds 85% target)
- R CMD check clean, lintr 0 issues

**Delivered:** Interview data integration, ratio-of-means CPUE/harvest estimation, total catch/harvest with delta method variance, comprehensive documentation, 89.24% test coverage

See: [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md)

</details>

### 🚧 v0.3.0 Incomplete Trips & Validation (In Progress)

**Milestone Goal:** Enable scientifically valid incomplete trip estimation with complete trip focus, following Colorado C-SAP best practices and Pollock et al. roving-access design principles.

- [x] **Phase 13: Trip Status Infrastructure** - Handle trip completion status and duration inputs (completed 2026-02-14)
- [x] **Phase 14: Overnight Trip Duration** - Calculate trip duration for multi-day trips (completed 2026-02-15)
- [x] **Phase 15: Mean-of-Ratios Estimator Core** - MOR estimation with sample size validation (completed 2026-02-15)
- [x] **Phase 16: Trip Truncation** - Threshold-based truncation for short trips (completed 2026-02-15)
- [x] **Phase 17: Complete Trip Defaults** - Prioritize complete trips in API (completed 2026-02-15)
- [x] **Phase 18: Sample Size Warnings** - Colorado C-SAP warnings and guidance (completed 2026-02-15)
- [ ] **Phase 19: Diagnostic Validation Framework** - Compare complete vs incomplete estimates
- [ ] **Phase 20: Documentation & Guidance** - Vignette and best practices guide

## Phase Details

### Phase 13: Trip Status Infrastructure
**Goal**: Users can specify trip completion status and duration in interview data
**Depends on**: Phase 12 (Interview-Based Estimation complete)
**Requirements**: TRIP-01, TRIP-02, TRIP-03, TRIP-05
**Success Criteria** (what must be TRUE):
  1. User can provide trip_status field (complete/incomplete) in add_interviews()
  2. User can provide trip_start and interview_time to calculate duration automatically
  3. User can provide trip_duration directly as alternative to calculated duration
  4. Package validates trip_status field and warns about missing or invalid values
  5. Interview data object stores trip metadata for downstream estimators
**Plans**: 2 plans

Plans:
- [x] 13-01-PLAN.md — Trip metadata parameters in add_interviews() with validation (TDD)
- [x] 13-02-PLAN.md — Example data update and summarize_trips() diagnostic function

### Phase 14: Overnight Trip Duration
**Goal**: Package correctly calculates trip duration for trips spanning multiple days
**Depends on**: Phase 13
**Requirements**: TRIP-04
**Success Criteria** (what must be TRUE):
  1. Package calculates correct duration for trips starting one day and ending the next
  2. Package handles time zones correctly in duration calculation
  3. Package validates that interview_time occurs after trip_start
  4. Overnight trip durations appear correct in diagnostic output
**Plans**: 1 plan

Plans:
- [ ] 14-01-PLAN.md — Overnight trip duration tests and timezone validation (TDD)

### Phase 15: Mean-of-Ratios Estimator Core
**Goal**: Users can estimate CPUE from incomplete trips using mean-of-ratios estimator
**Depends on**: Phase 14
**Requirements**: MOR-01, MOR-04, MOR-05
**Success Criteria** (what must be TRUE):
  1. User can call estimate_cpue() with estimator="mor" parameter to use MOR estimation
  2. MOR estimator produces CPUE estimates with SE and CI for incomplete trips
  3. Package validates sample size for MOR estimation (error if n<10, warn if n<30)
  4. User can select variance method for MOR (Taylor, bootstrap, jackknife)
  5. MOR estimates use survey::svymean with incomplete-trip-filtered design
**Plans**: 2 plans

Plans:
- [ ] 15-01-PLAN.md — Core MOR implementation with estimator parameter and validation (TDD)
- [ ] 15-02-PLAN.md — MOR S3 class and diagnostic messaging for Phase 19 integration

### Phase 16: Trip Truncation
**Goal**: Package truncates incomplete trips shorter than minimum threshold with correct variance
**Depends on**: Phase 15
**Requirements**: MOR-02, MOR-03, MOR-06
**Success Criteria** (what must be TRUE):
  1. User can configure minimum trip duration threshold via truncate_at parameter
  2. Package defaults to 20-30 minute threshold per Hoenig et al. recommendations
  3. Package excludes trips shorter than threshold from MOR estimation with informative message
  4. Package computes variance correctly for MOR estimator with truncated sample
  5. Truncation message reports number of trips excluded and threshold used
**Plans**: 2 plans

Plans:
- [ ] 16-01-PLAN.md — Core truncation parameter and filtering (TDD)
- [ ] 16-02-PLAN.md — Truncation messaging and variance verification

### Phase 17: Complete Trip Defaults
**Goal**: estimate_cpue() prioritizes complete trips by default following roving-access design
**Depends on**: Phase 16
**Requirements**: API-01, API-03
**Success Criteria** (what must be TRUE):
  1. estimate_cpue() uses complete trips only by default (use_trips = "complete")
  2. User can explicitly specify use_trips parameter ("complete", "incomplete", "diagnostic")
  3. Package messages clearly indicate which trip type is being used
  4. Existing estimate_cpue() behavior unchanged when trip_status not provided
**Plans**: 2 plans

Plans:
- [ ] 17-01-PLAN.md — Core use_trips parameter with complete/incomplete filtering and validation (TDD)
- [ ] 17-02-PLAN.md — Diagnostic comparison mode and informative messaging

### Phase 18: Sample Size Warnings
**Goal**: Package warns when complete trip sample size is insufficient per Pollock et al. roving-access design guidance
**Depends on**: Phase 17
**Requirements**: API-02, API-04
**Success Criteria** (what must be TRUE):
  1. Package warns when <10% of interviews are complete trips (Pollock et al. threshold)
  2. Warning messages reference Pollock et al. best practices for roving-access designs
  3. Warning includes percentage of complete trips for transparency
  4. Messages guide users toward diagnostic validation when complete sample is small
**Plans**: 2 plans

Plans:
- [ ] 18-01-PLAN.md — Complete trip percentage warning function with tests (TDD)
- [ ] 18-02-PLAN.md — Integration into estimate_cpue with package option and per-group warnings

### Phase 19: Diagnostic Validation Framework
**Goal**: Users can compare complete vs incomplete trip estimates with statistical tests
**Depends on**: Phase 18
**Requirements**: VALID-01, VALID-02, VALID-03, VALID-04
**Success Criteria** (what must be TRUE):
  1. User can call validate_incomplete_trips() to compare complete vs incomplete estimates
  2. Function performs TOST equivalence test for overall and per-group comparisons
  3. Function produces validation plot (incomplete vs complete scatter with y=x reference line)
  4. Function returns diagnostic report with test statistics and actionable recommendation on failure
  5. Report provides guidance on next steps when validation fails (detailed explanation of when incomplete trips are valid deferred to Phase 20 vignette)
**Plans**: 2 plans

Plans:
- [ ] 19-01-PLAN.md — TOST equivalence testing framework with configurable threshold (TDD)
- [ ] 19-02-PLAN.md — Validation plots and print methods with statistical detail

### Phase 20: Documentation & Guidance
**Goal**: Complete documentation explaining when and how to use incomplete trip estimation
**Depends on**: Phase 19
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04
**Success Criteria** (what must be TRUE):
  1. Incomplete trips vignette explains scientific rationale and when to use MOR estimator
  2. Vignette demonstrates Colorado C-SAP best practices with complete trips prioritized
  3. Documentation strongly warns against pooling complete and incomplete interviews
  4. Step-by-step validation workflow guide shows how to test incomplete trip assumptions
  5. Examples use realistic data demonstrating both valid and invalid incomplete trip scenarios
**Plans**: TBD

Plans:
- [ ] 20-01: TBD
- [ ] 20-02: TBD

## Progress Summary

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 1-7 | v0.1.0 | 12/12 | ✅ Complete | 2026-02-09 |
| 8-12 | v0.2.0 | 10/10 | ✅ Complete | 2026-02-11 |
| 13. Trip Status Infrastructure | v0.3.0 | 2/2 | ✅ Complete | 2026-02-14 |
| 14. Overnight Trip Duration | v0.3.0 | Complete    | 2026-02-15 | - |
| 15. Mean-of-Ratios Estimator Core | v0.3.0 | Complete    | 2026-02-15 | - |
| 16. Trip Truncation | v0.3.0 | Complete    | 2026-02-15 | - |
| 17. Complete Trip Defaults | v0.3.0 | Complete    | 2026-02-15 | - |
| 18. Sample Size Warnings | v0.3.0 | Complete    | 2026-02-15 | - |
| 19. Diagnostic Validation Framework | v0.3.0 | 0/2 | Ready to execute | - |
| 20. Documentation & Guidance | v0.3.0 | 0/TBD | Not started | - |

**Overall:** 2 milestones shipped (22 plans), v0.3.0 in progress (8 phases, 6 phases complete)

---
*Roadmap last updated: 2026-02-14 for v0.3.0 milestone*
*See .planning/MILESTONES.md for full milestone history*
