# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- ✅ **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (shipped 2026-02-16)
- 🚧 **v0.4.0 Bus-Route Survey Support** — Phases 21-27 (in progress)

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

### 🚧 v0.4.0 Bus-Route Survey Support (In Progress)

**Milestone Goal:** Implement statistically correct bus-route (nonuniform probability) estimation based on Jones & Pollock (2012) and Malvestuto et al. (1978) — making tidycreel the ONLY R package with correct bus-route estimation.

#### Phase 21: Bus-Route Design Foundation
**Goal**: Users can specify bus-route survey designs with nonuniform sampling probabilities
**Depends on**: Phase 20 (v0.3.0 complete)
**Requirements**: BUSRT-06, BUSRT-07
**Success Criteria** (what must be TRUE):
  1. creel_design() accepts survey_type = "bus_route" with site and circuit specifications
  2. Site probabilities sum to 1.0 within each circuit (validated at design time)
  3. All sampling probabilities are in (0,1] range (validated at design time)
  4. Design validation fails fast with clear messages when probabilities invalid
**Plans**: 2 plans

Plans:
- [ ] 21-01-PLAN.md — Extend creel_design() with survey_type = "bus_route", sampling_frame validation, pi_i precomputation
- [ ] 21-02-PLAN.md — Bus-Route print section, get_sampling_frame() helper, and comprehensive tests

#### Phase 22: Inclusion Probability Calculation
**Goal**: System correctly calculates inclusion probabilities (πᵢ) from sampling design, not site characteristics
**Depends on**: Phase 21
**Requirements**: BUSRT-01, BUSRT-05, VALID-03
**Success Criteria** (what must be TRUE):
  1. πᵢ calculated as p_site × p_period from sampling design specification
  2. πᵢ varies by sampling design, not by site wait times or interview timing
  3. Two-stage sampling (site × period) produces correct probability products
  4. Implementation matches primary source definition from Jones & Pollock (2012)
**Plans**: 2 plans

Plans:
- [ ] 22-01-PLAN.md — p_period uniformity validation, defensive pi_i range check, get_inclusion_probs() accessor, @references
- [ ] 22-02-PLAN.md — Golden tests (hand-computed pi_i), validation tests, get_inclusion_probs() unit tests, property tests

#### Phase 23: Data Integration
**Goal**: Interview data integrates with bus-route designs including enumeration counts and probability joins
**Depends on**: Phase 22
**Requirements**: BUSRT-08, BUSRT-02, VALID-04
**Success Criteria** (what must be TRUE):
  1. add_interviews() joins sampling probabilities (πᵢ) to interview records
  2. Enumeration counts (n_counted, n_interviewed) required for bus-route surveys
  3. Progressive validation catches missing enumeration counts at data input time
  4. Expansion factor (n_counted / n_interviewed) calculated correctly
**Plans**: 2 plans

Plans:
- [ ] 23-01-PLAN.md — Extend add_interviews() with n_counted/n_interviewed selectors, Tier 3 bus-route validation, pi_i join, .expansion computation
- [ ] 23-02-PLAN.md — get_enumeration_counts() accessor, print Enumeration Counts section, comprehensive tests

#### Phase 24: Bus-Route Effort Estimation
**Goal**: Users can estimate fishing effort from bus-route surveys using Jones & Pollock Eq. 19.4
**Depends on**: Phase 23
**Requirements**: BUSRT-03, BUSRT-09, BUSRT-11
**Success Criteria** (what must be TRUE):
  1. estimate_effort() dispatches to bus-route estimator when design type is bus_route
  2. Effort calculated as sum(e_i / πᵢ) following Jones & Pollock (2012) Eq. 19.4 exactly
  3. Enumeration expansion applied before inverse probability weighting
  4. Variance estimation via survey package produces correct standard errors
**Plans**: 2 plans

Plans:
- [ ] 24-01-PLAN.md — Bus-route effort estimator core (estimate_effort_br) implementing Eq. 19.4; estimate_effort() dispatch + verbose= parameter
- [ ] 24-02-PLAN.md — get_site_contributions() accessor; full bus-route effort estimation test suite

#### Phase 25: Bus-Route Harvest Estimation
**Goal**: Users can estimate harvest and catch from bus-route surveys using Jones & Pollock Eq. 19.5
**Depends on**: Phase 24
**Requirements**: BUSRT-04, BUSRT-10
**Success Criteria** (what must be TRUE):
  1. estimate_harvest() dispatches to bus-route estimator when design type is bus_route
  2. Harvest calculated as sum(h_i / πᵢ) following Jones & Pollock (2012) Eq. 19.5 exactly
  3. Incomplete trip handling works correctly for bus-route surveys
  4. Grouped estimation (by species, stratum) produces correct stratified estimates
**Plans**: 2 plans

Plans:
- [ ] 25-01-PLAN.md — estimate_harvest_br() and estimate_total_catch_br() core; estimate_harvest() and estimate_total_catch() bus-route dispatch with verbose= and use_trips=
- [ ] 25-02-PLAN.md — Full bus-route harvest and total-catch test suites (harvest: 10 tests, total-catch: 6 tests)

#### Phase 26: Primary Source Validation
**Goal**: Implementation reproduces published examples from primary sources exactly
**Depends on**: Phase 25
**Requirements**: VALID-01, VALID-02, VALID-05
**Success Criteria** (what must be TRUE):
  1. Malvestuto (1996) Box 20.6 Example 1 reproduced exactly (Site C: 57.5/0.20 = 287.5)
  2. Enumeration expansion calculations match published methodology
  3. Integration tests verify complete workflow (design → data → estimation)
  4. Reference tests prove estimates match manual survey package calculations
**Plans**: 2 plans

Plans:
- [ ] 26-01-PLAN.md — Box 20.6 Example 1 (no expansion) and Example 2 (enumeration expansion) primary source correctness tests
- [ ] 26-02-PLAN.md — Integration tests (complete workflow) and survey package cross-validation for effort and harvest

#### Phase 27: Documentation & Traceability
**Goal**: Users understand when and how to use bus-route surveys correctly with full equation traceability
**Depends on**: Phase 26
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05
**Success Criteria** (what must be TRUE):
  1. Vignette explains what bus-route surveys are and when to use them vs other designs
  2. Key concepts (inclusion probability, enumeration counts, two-stage sampling) documented clearly
  3. Step-by-step walkthrough shows complete tidycreel workflow for bus-route estimation
  4. Equation traceability document maps every line of code to source equation and page number
  5. Documentation explains why tidycreel implementation is correct vs existing packages (Pope, AnglerCreelSurveySimulation)
**Plans**: TBD

Plans:
- [ ] TBD

## Progress Summary

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 Foundation | 1-7 | 12/12 | ✅ Complete | 2026-02-09 |
| v0.2.0 Interview-Based Estimation | 8-12 | 10/10 | ✅ Complete | 2026-02-11 |
| v0.3.0 Incomplete Trips & Validation | 13-20 | 16/16 | ✅ Complete | 2026-02-16 |
| v0.4.0 Bus-Route Survey Support | 21-27 | 0/TBD | 🚧 Planning | - |

**Overall:** 3 milestones shipped, 20 phases complete, 38 plans executed

**v0.4.0 Progress:**

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 21. Bus-Route Design Foundation | 0/2 | Complete    | 2026-02-17 |
| 22. Inclusion Probability Calculation | 0/2 | Complete    | 2026-02-17 |
| 23. Data Integration | 0/2 | Complete    | 2026-02-17 |
| 24. Bus-Route Effort Estimation | 0/TBD | Not started | - |
| 25. Bus-Route Harvest Estimation | 2/2 | Complete    | 2026-02-24 |
| 26. Primary Source Validation | 2/2 | Complete    | 2026-02-25 |
| 27. Documentation & Traceability | 1/2 | In Progress|  |

---
*Roadmap last updated: 2026-02-25 after Phase 26 planning*
*See .planning/MILESTONES.md for full milestone history*
