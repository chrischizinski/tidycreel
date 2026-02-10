# Roadmap: tidycreel v0.2.0

## Overview

Interview-based estimation extends tidycreel's proven v0.1.0 foundation (instantaneous counts for effort) with parallel interview data stream for catch and harvest analysis. Users attach interview data to existing creel_design objects, estimate catch per unit effort (CPUE) using ratio-of-means estimator for complete trips, and combine effort × CPUE for total catch with automatic delta method variance propagation. This milestone establishes the architecture for interview-based estimation (access point design pattern) while deferring incomplete trip handling (roving design) to v0.3.0.

## Milestones

- v0.1.0 Foundation - Phases 1-7 (shipped 2026-02-09)
- v0.2.0 Interview-Based Estimation - Phases 8-12 (in progress)

## Phases

<details>
<summary>v0.1.0 Foundation (Phases 1-7) - SHIPPED 2026-02-09</summary>

### Phase 1: Package Foundation
**Goal**: Package structure with CI/CD and quality gates
**Requirements**: Setup, structure, CI/CD configuration
**Success Criteria**:
  1. Package passes R CMD check with 0 errors/warnings
  2. lintr pre-commit hooks enforcing code quality
  3. testthat infrastructure configured
**Plans**: 3 plans

Plans:
- [x] 01-01: Package scaffolding
- [x] 01-02: Quality gates
- [x] 01-03: CI/CD

### Phase 2: Design Constructor
**Goal**: creel_design() constructor with tidy selectors
**Requirements**: Design object creation, column specification
**Success Criteria**:
  1. User can create creel_design with tidy selectors
  2. Design object validates calendar structure
**Plans**: 2 plans

Plans:
- [x] 02-01: Constructor implementation
- [x] 02-02: Validation tier 1

### Phase 3: Count Data Integration
**Goal**: add_counts() for instantaneous count data
**Requirements**: Count data attachment, PSU specification
**Success Criteria**:
  1. User can attach count data to design object
  2. System constructs survey design with day-PSU
**Plans**: 2 plans

Plans:
- [x] 03-01: add_counts() implementation
- [x] 03-02: Survey design construction

### Phase 4: Basic Effort Estimation
**Goal**: estimate_effort() returning estimates with SE/CI
**Requirements**: Total effort estimation, survey bridge
**Success Criteria**:
  1. User can estimate total effort with confidence intervals
  2. Estimates match manual survey package calculations
**Plans**: 2 plans

Plans:
- [x] 04-01: estimate_effort() core
- [x] 04-02: Reference tests

### Phase 5: Grouped Estimation
**Goal**: Grouped effort estimates with by= parameter
**Requirements**: Stratum-specific estimation
**Success Criteria**:
  1. User can estimate effort by stratum or other grouping variables
  2. Grouped estimates sum to total estimate
**Plans**: 1 plan

Plans:
- [x] 05-01: Grouped estimation

### Phase 6: Variance Methods
**Goal**: Variance method control (Taylor, bootstrap, jackknife)
**Requirements**: Multiple variance estimation methods
**Success Criteria**:
  1. User can specify variance method explicitly
  2. Bootstrap and jackknife produce reasonable estimates
**Plans**: 2 plans

Plans:
- [x] 06-01: Variance method infrastructure
- [x] 06-02: Bootstrap and jackknife

### Phase 7: Documentation & Quality Assurance
**Goal**: Production-ready package with complete documentation
**Requirements**: Vignettes, examples, test coverage, R CMD check
**Success Criteria**:
  1. Package passes R CMD check --as-cran with 0 errors/warnings
  2. Test coverage >=85% overall, >=95% for core estimation
  3. Getting Started vignette demonstrates complete workflow
**Plans**: 2 plans

Plans:
- [x] 07-01: Documentation and vignettes
- [x] 07-02: Quality assurance

</details>

### v0.2.0 Interview-Based Estimation (In Progress)

**Milestone Goal:** Enable catch and harvest estimation by adding interview data analysis to existing instantaneous count design foundation.

#### Phase 8: Interview Data Integration
**Goal**: Users can attach interview data to existing creel_design objects with complete trip validation
**Depends on**: Phase 7 (v0.1.0 complete)
**Requirements**: INTV-01, INTV-02, INTV-03, INTV-04, INTV-05, INTV-06, QUAL-01, QUAL-03
**Success Criteria** (what must be TRUE):
  1. User can attach interview data to creel_design using add_interviews() with tidy selectors
  2. System validates interview data structure (required columns, valid types) at creation time
  3. System constructs interview survey design object with shared calendar stratification
  4. System detects interview type (access point complete trips) and stores in design metadata
  5. System warns for interview data quality issues (missing effort, extreme values)
**Plans**: 2 plans

Plans:
- [ ] 08-01-PLAN.md -- Core add_interviews() function, validation infrastructure, and interview survey construction
- [ ] 08-02-PLAN.md -- Tier 2 data quality warnings, example interview dataset, and quality assurance

#### Phase 9: CPUE Estimation
**Goal**: Users can estimate catch per unit effort with ratio-of-means estimator for complete trip interviews
**Depends on**: Phase 8
**Requirements**: CPUE-01, CPUE-02, CPUE-03, CPUE-04, CPUE-05, CPUE-06, QUAL-02
**Success Criteria** (what must be TRUE):
  1. User can estimate CPUE with standard errors and confidence intervals
  2. System uses ratio-of-means estimator (svyratio) for access point interviews
  3. User can estimate grouped CPUE using by= parameter (by stratum or other variables)
  4. System validates sufficient sample size (warns if n<30, errors if n<10 per group)
  5. User can control variance method (Taylor, bootstrap, jackknife) for CPUE estimation
  6. System output clearly indicates estimator used ("Ratio-of-Means CPUE")
**Plans**: 2 plans

Plans:
- [ ] 09-01-PLAN.md -- Core estimate_cpue() with ratio-of-means estimation, sample size validation, grouped estimation, and reference tests (TDD)
- [ ] 09-02-PLAN.md -- Format display update, variance method tests, zero-effort handling, integration tests, and quality assurance

#### Phase 10: Catch and Harvest Estimation
**Goal**: Users can estimate species-specific catch and harvest rates using CPUE infrastructure
**Depends on**: Phase 9
**Requirements**: HARV-01, HARV-02, HARV-03, HARV-04
**Success Criteria** (what must be TRUE):
  1. User can estimate catch per unit effort for single species fisheries
  2. User can estimate harvest per unit effort (HPUE) separately from total catch
  3. System distinguishes between caught (total) and kept (harvest) fish
  4. System validates catch_kept <= catch_total consistency
**Plans**: 2 plans

Plans:
- [x] 10-01-PLAN.md -- Ratio-of-means HPUE estimation with TDD, shared sample size validation, and reference tests
- [x] 10-02-PLAN.md -- HPUE format display, zero-effort filtering, NA harvest handling, variance method tests, and quality assurance

#### Phase 11: Total Catch Estimation
**Goal**: Users can estimate total catch by combining effort and CPUE with correct variance propagation
**Depends on**: Phase 10
**Requirements**: TCATCH-01, TCATCH-02, TCATCH-03, TCATCH-04, TCATCH-05
**Success Criteria** (what must be TRUE):
  1. User can estimate total catch by combining effort x CPUE estimates
  2. System propagates variance correctly using delta method (not naive product variance)
  3. System validates design compatibility between count and interview data
  4. User can estimate grouped total catch (by stratum or other variables)
  5. System handles single species fisheries (v0.2.0 scope constraint)
**Plans**: 2 plans

Plans:
- [ ] 11-01-PLAN.md -- Core estimate_total_catch() and estimate_total_harvest() with delta method variance via svycontrast (TDD)
- [ ] 11-02-PLAN.md -- Format display tests, variance method tests, integration tests, and quality assurance

#### Phase 12: Documentation and Quality Assurance
**Goal**: Production-ready interview estimation with comprehensive documentation and test coverage
**Depends on**: Phase 11
**Requirements**: QUAL-04, QUAL-05, QUAL-06, QUAL-07, QUAL-08
**Success Criteria** (what must be TRUE):
  1. Interview-based estimation vignette demonstrates complete workflow (counts -> interviews -> total catch)
  2. Example datasets include interview data for access point complete trips
  3. All functions pass R CMD check with 0 errors/warnings
  4. Test coverage >=85% overall, >=95% for core CPUE and total catch estimation functions
  5. All code passes lintr with 0 issues
**Plans**: TBD

Plans:
- [ ] 12-01: TBD
- [ ] 12-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 8 -> 9 -> 10 -> 11 -> 12

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Package Foundation | v0.1.0 | 3/3 | Complete | 2026-02-09 |
| 2. Design Constructor | v0.1.0 | 2/2 | Complete | 2026-02-09 |
| 3. Count Data Integration | v0.1.0 | 2/2 | Complete | 2026-02-09 |
| 4. Basic Effort Estimation | v0.1.0 | 2/2 | Complete | 2026-02-09 |
| 5. Grouped Estimation | v0.1.0 | 1/1 | Complete | 2026-02-09 |
| 6. Variance Methods | v0.1.0 | 2/2 | Complete | 2026-02-09 |
| 7. Documentation & QA | v0.1.0 | 2/2 | Complete | 2026-02-09 |
| 8. Interview Data Integration | v0.2.0 | 2/2 | Complete | 2026-02-09 |
| 9. CPUE Estimation | v0.2.0 | 2/2 | Complete | 2026-02-10 |
| 10. Catch and Harvest Estimation | v0.2.0 | 2/2 | Complete | 2026-02-10 |
| 11. Total Catch Estimation | v0.2.0 | 2/2 | Complete | 2026-02-10 |
| 12. Documentation and Quality Assurance | v0.2.0 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-09*
*Last updated: 2026-02-10 13:47 UTC*
