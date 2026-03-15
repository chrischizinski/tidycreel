# Milestones

## v0.7.0 Spatially Stratified Estimation (Shipped: 2026-03-15)

**Phases completed:** 5 phases, 9 plans, 0 tasks

**Key accomplishments:**
- (none recorded)

---

## v0.4.0 Bus-Route Survey Support (Shipped: 2026-02-28)

**Phases completed:** 29 phases, 51 plans, 14 tasks

**Key accomplishments:**
- (none recorded)

---

## v0.1.0 Foundation - Instantaneous Counts (Shipped: 2026-02-09)

**Phases completed:** 7 phases, 12 plans
**Quality metrics:** 253 tests, 88.75% coverage, 0 lintr issues, R CMD check clean
**Code delivered:** 1,600 LOC R

**Key accomplishments:**
- Three-layer architecture (API → Orchestration → Survey) proven working end-to-end
- Design-centric API with tidy selectors operational — creel_design() as single entry point
- Progressive validation system (Tier 1 fail-fast + Tier 2 warnings + escape hatches)
- Complete estimation capability — total and grouped estimates with Taylor/bootstrap/jackknife variance
- Production-ready quality gates — zero lintr issues, R CMD check passing, comprehensive test coverage
- Full documentation suite — roxygen2 docs, example datasets, Getting Started vignette

---

## v0.2.0 Interview-Based Estimation (Shipped: 2026-02-11)

**Phases completed:** 5 phases (8-12), 10 plans
**Quality metrics:** 610 tests, 89.24% coverage, 0 lintr issues, R CMD check clean
**Code delivered:** 8,599 LOC R total (+~2,500 LOC for interview features)

**Key accomplishments:**
- Interview data integration with add_interviews() using tidy selectors for catch, effort, and harvest
- Ratio-of-means CPUE and harvest estimation via survey::svyratio with sample size validation
- Total catch and harvest estimation combining effort × CPUE with delta method variance propagation
- Comprehensive documentation with interview-based estimation vignette demonstrating complete workflow
- 89.24% test coverage with 610 tests passing, all quality gates met (R CMD check clean, lintr 0 issues)

---

## v0.3.0 Incomplete Trips & Validation (Shipped: 2026-02-16)

**Phases completed:** 8 phases (13-20), 16 plans
**Quality metrics:** 718 tests, ~90% coverage, 0 lintr issues, R CMD check clean
**Code delivered:** 15,756 LOC R total

**Key accomplishments:**
- Trip metadata infrastructure with trip_status and trip_duration validation following TDD
- Mean-of-ratios (MOR) estimator for incomplete trips via survey::svymean on individual catch/effort ratios
- Complete trip defaults prioritizing scientifically valid roving-access design (Colorado C-SAP)
- TOST equivalence testing framework to statistically validate incomplete vs. complete trip comparability
- Sample size warnings when <10% complete trips with Colorado C-SAP and Pollock et al. references
- 794-line comprehensive vignette with scientific rationale, best practices, and validation workflow guide

---
