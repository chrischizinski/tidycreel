# Roadmap: tidycreel v2

## Overview

Building tidycreel v0.1.0 from the ground up as a domain-translator package for creel survey analysis. This milestone proves the three-layer architecture (API -> Orchestration -> Survey) by implementing the simplest design type (instantaneous counts) end-to-end. Seven phases progress from package scaffolding through core data structures, survey bridge construction, estimation capabilities, and final polish with comprehensive documentation.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Project Setup & Foundation** - Initialize package structure with quality gates
- [ ] **Phase 2: Core Data Structures** - Implement creel_design and creel_estimates S3 classes
- [ ] **Phase 3: Survey Bridge Layer** - Build internal svydesign construction for instantaneous counts
- [ ] **Phase 4: Basic Estimation** - Implement estimate_effort with total estimates
- [ ] **Phase 5: Grouped Estimation** - Add grouped estimation with tidy selectors
- [ ] **Phase 6: Variance Methods** - Enable variance method selection (Taylor, bootstrap, jackknife)
- [ ] **Phase 7: Polish & Documentation** - Complete documentation, vignettes, and reference tests

## Phase Details

### Phase 1: Project Setup & Foundation
**Goal**: Package structure passes R CMD check with continuous quality gates configured
**Depends on**: Nothing (first phase)
**Requirements**: PKG-01, PKG-02, PKG-03, PKG-04, PKG-05, PKG-06, DATA-07, DATA-08
**Success Criteria** (what must be TRUE):
  1. Empty package structure exists with DESCRIPTION, NAMESPACE, R/, tests/, man/
  2. R CMD check passes with no errors/warnings/notes
  3. GitHub Actions CI/CD runs R CMD check and test coverage on every push
  4. Pre-commit hooks enforce lintr and styler on all commits
  5. Data schemas validate calendar and count data structures
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md -- Clean v1 artifacts and scaffold v2 package
- [x] 01-02-PLAN.md -- Configure continuous quality gates (lintr, pre-commit, CI/CD)
- [x] 01-03-PLAN.md -- Data schema validators (TDD)

### Phase 2: Core Data Structures
**Goal**: creel_design and creel_estimates objects work with proper S3 methods
**Depends on**: Phase 1
**Requirements**: DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06, DSGN-01, DSGN-02, DSGN-03, DSGN-04, DSGN-07, DSGN-08
**Success Criteria** (what must be TRUE):
  1. User can create creel_design object from calendar data using tidy selectors
  2. creel_design object validates date column and strata columns at creation
  3. creel_design object prints with readable summary of design structure
  4. creel_estimates object prints with estimates, SEs, CIs in user-friendly format
  5. Tier 1 validation fails fast on missing columns or invalid dates
**Plans**: TBD

Plans:
- [ ] TBD during planning

### Phase 3: Survey Bridge Layer
**Goal**: Internal survey package designs construct correctly from creel data
**Depends on**: Phase 2
**Requirements**: DSGN-05, DSGN-06, DSGN-09, DSGN-10, TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. User can add instantaneous count data to creel_design using add_counts()
  2. Count data schema validates before acceptance
  3. Internal svydesign object constructs with day-PSU stratified design
  4. Internal survey design matches expected structure (testable via as_survey_design escape hatch)
**Plans**: TBD

Plans:
- [ ] TBD during planning

### Phase 4: Basic Estimation
**Goal**: Users can estimate total effort with standard errors and confidence intervals
**Depends on**: Phase 3
**Requirements**: EST-01, EST-02, EST-03, EST-04, EST-05, EST-06, EST-10, EST-13, EST-14, EST-15, TEST-03, TEST-06, TEST-07
**Success Criteria** (what must be TRUE):
  1. User can call estimate_effort() and receive creel_estimates object with point estimate, SE, CI, and sample size
  2. Estimates default to Taylor linearization variance method
  3. Variance method used is stored in result attributes for reproducibility
  4. Tier 2 validation warns on zero/negative effort values and sparse strata
  5. Estimates match manual survey package calculations (verified by reference tests)
**Plans**: TBD

Plans:
- [ ] TBD during planning

### Phase 5: Grouped Estimation
**Goal**: Users can estimate effort by grouping variables using tidy selectors
**Depends on**: Phase 4
**Requirements**: EST-07, EST-08, TEST-04
**Success Criteria** (what must be TRUE):
  1. User can specify grouping variables using by = with bare column names
  2. estimate_effort() returns group-wise estimates with correct variance
  3. Grouped results include sample sizes per group
**Plans**: TBD

Plans:
- [ ] TBD during planning

### Phase 6: Variance Methods
**Goal**: Users can control variance estimation method with clear defaults
**Depends on**: Phase 5
**Requirements**: EST-09, EST-11, EST-12, TEST-05
**Success Criteria** (what must be TRUE):
  1. User can specify variance = "bootstrap" or "jackknife" in estimate_effort()
  2. Bootstrap and jackknife variance methods produce reasonable estimates
  3. Integration tests verify full workflow from design creation through estimation
  4. Print methods show which variance method was used
**Plans**: TBD

Plans:
- [ ] TBD during planning

### Phase 7: Polish & Documentation
**Goal**: Package is documented, tested, and ready for v0.1.0 release
**Depends on**: Phase 6
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06, TEST-08, TEST-09, TEST-10, TEST-11
**Success Criteria** (what must be TRUE):
  1. All exported functions have roxygen2 documentation with examples
  2. Getting Started vignette demonstrates complete workflow from design to estimation
  3. Example datasets (calendar and counts) are included in package
  4. Vignettes render without errors
  5. Test coverage meets targets (85% overall, 95% for core estimation)
  6. All code passes lintr with project configuration
  7. R CMD check --as-cran passes with no issues
**Plans**: TBD

Plans:
- [ ] TBD during planning

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Project Setup & Foundation | 3/3 | ✓ Complete | 2026-02-01 |
| 2. Core Data Structures | 0/TBD | Not started | - |
| 3. Survey Bridge Layer | 0/TBD | Not started | - |
| 4. Basic Estimation | 0/TBD | Not started | - |
| 5. Grouped Estimation | 0/TBD | Not started | - |
| 6. Variance Methods | 0/TBD | Not started | - |
| 7. Polish & Documentation | 0/TBD | Not started | - |
