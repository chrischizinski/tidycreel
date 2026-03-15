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
- 📋 **v0.8.0** — TBD (planning next)

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

## Progress Summary

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 Foundation | 1-7 | 12/12 | ✅ Complete | 2026-02-09 |
| v0.2.0 Interview-Based Estimation | 8-12 | 10/10 | ✅ Complete | 2026-02-11 |
| v0.3.0 Incomplete Trips & Validation | 13-20 | 16/16 | ✅ Complete | 2026-02-16 |
| v0.4.0 Bus-Route Survey Support | 21-27 | 14/14 | ✅ Complete | 2026-02-28 |
| v0.5.0 Interview Data Model | 28-35 | 18/18 | ✅ Complete | 2026-03-08 |
| v0.6.0 Multiple Counts per PSU | 36-38 | 5/5 | ✅ Complete | 2026-03-09 |
| v0.7.0 Spatially Stratified Estimation | 39-43 | 9/9 | ✅ Complete | 2026-03-15 |

**Overall:** 7 milestones shipped, 43 phases complete, 84 plans complete

---
*Roadmap last updated: 2026-03-15 — v0.7.0 milestone archived*
*See .planning/milestones/ for full milestone archives*
