# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- 📋 **v0.3.0 Advanced Interview Features** — (planned)

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

### 📋 v0.3.0 Advanced Interview Features (Planned)

**Scope:** Incomplete trip handling (roving design), multi-species support, advanced QA/QC diagnostics

- [ ] Phase 13: Incomplete trip estimation (mean-of-ratios with truncation)
- [ ] Phase 14: Multi-species framework with covariance
- [ ] Phase 15: QA/QC diagnostics for interview data

## Progress Summary

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 1-7 | v0.1.0 | 12/12 | ✅ Complete | 2026-02-09 |
| 8-12 | v0.2.0 | 10/10 | ✅ Complete | 2026-02-11 |
| 13+ | v0.3.0 | - | 📋 Planned | - |

**Overall:** 2 milestones shipped, 22 plans completed, all quality gates met

---
*Roadmap last updated: 2026-02-11 after v0.2.0 completion*
*See .planning/MILESTONES.md for full milestone history*
