# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- ✅ **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (shipped 2026-02-16)

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

<details>
<summary>✅ v0.3.0 Incomplete Trips & Validation (Phases 13-20) — SHIPPED 2026-02-16</summary>

**Milestone Goal:** Enable scientifically valid incomplete trip estimation with complete trip focus, following Colorado C-SAP best practices and Pollock et al. roving-access design principles.

### Phase 13: Trip Status Infrastructure
- [x] 2/2 plans complete
- trip_status and trip_duration parameters with comprehensive validation
- Case-insensitive normalization, mutually exclusive duration inputs
- summarize_trips() diagnostic function

### Phase 14: Overnight Trip Duration
- [x] 1/1 plan complete
- Overnight trip duration calculation across multiple days
- Timezone validation for trip_start and interview_time

### Phase 15: Mean-of-Ratios Estimator Core
- [x] 2/2 plans complete
- MOR estimator via survey::svymean on individual catch/effort ratios
- estimator="mor" parameter with automatic incomplete trip filtering
- Sample size validation (n<10 error, n<30 warning) for MOR
- creel_estimates_mor S3 class with diagnostic messaging

### Phase 16: Trip Truncation
- [x] 2/2 plans complete
- truncate_at parameter (default 0.5 hours per Hoenig et al.)
- Truncation messaging with >10% threshold warnings
- Correct variance computation with truncated samples

### Phase 17: Complete Trip Defaults
- [x] 2/2 plans complete
- use_trips parameter ("complete", "incomplete", "diagnostic")
- Complete trips as default following Colorado C-SAP best practices
- Diagnostic comparison mode for side-by-side evaluation

### Phase 18: Sample Size Warnings
- [x] 2/2 plans complete
- Warnings when <10% complete trips (Pollock et al. threshold)
- Colorado C-SAP and Pollock et al. best practice references
- Per-group warnings for grouped estimation

### Phase 19: Diagnostic Validation Framework
- [x] 2/2 plans complete
- validate_incomplete_trips() with TOST equivalence testing
- ±20% default threshold for ecological field data
- Validation scatter plots with y=x reference line
- creel_tost_validation S3 class with detailed print methods

### Phase 20: Documentation & Guidance
- [x] 2/2 plans complete
- 794-line incomplete trips vignette with scientific rationale
- Colorado C-SAP best practices and validation workflow guide
- Strong warnings against pooling complete + incomplete trips
- Decision tree for when to use incomplete trip estimation

**Delivered:** Trip metadata infrastructure, mean-of-ratios estimator with truncation, complete trip defaults, TOST validation framework, sample size warnings, comprehensive 794-line documentation vignette

See: [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md)

</details>

## Progress Summary

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 Foundation | 1-7 | 12/12 | ✅ Complete | 2026-02-09 |
| v0.2.0 Interview-Based Estimation | 8-12 | 10/10 | ✅ Complete | 2026-02-11 |
| v0.3.0 Incomplete Trips & Validation | 13-20 | 16/16 | ✅ Complete | 2026-02-16 |

**Overall:** 3 milestones shipped, 20 phases complete, 38 plans executed

---
*Roadmap last updated: 2026-02-16 after v0.3.0 milestone completion*
*See .planning/MILESTONES.md for full milestone history*
