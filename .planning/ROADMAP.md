# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- ✅ **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (shipped 2026-02-16)
- ✅ **v0.4.0 Bus-Route Survey Support** — Phases 21-27 (shipped 2026-02-28)
- 🚧 **v0.5.0 Interview Data Model and Unextrapolated Summaries** — Phases 28-35 (in progress)

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
- [x] Phase 25: Bus-Route Harvest Estimation (2/2 plans) — completed 2026-02-24
- [x] Phase 26: Primary Source Validation (2/2 plans) — completed 2026-02-25
- [x] Phase 27: Documentation & Traceability (2/2 plans) — completed 2026-02-28

**Delivered:** Bus-route design constructor with nonuniform probabilities (πᵢ = p_site × p_period), enumeration expansion (n_counted/n_interviewed), effort/harvest estimators implementing Jones & Pollock (2012) Eq. 19.4-19.5, Malvestuto (1996) Box 20.6 reproduced exactly (E_hat = 847.5), complete workflow vignette and equation traceability document, 1,098 tests

See: [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md)

</details>

### 🚧 v0.5.0 Interview Data Model and Unextrapolated Summaries (In Progress)

**Milestone Goal:** Extend the interview data model to capture the full party-level creel record, add species catch and fish length data layers, deliver complete unextrapolated summary functions (interview tabulations, CWS/HWS rates, length frequencies), and extend extrapolated estimators to species-level grouping.

- [x] **Phase 28: Extended Interview Data Model** — Extend `add_interviews()` with angler type, method, species sought, party size, and refusal flag (completed 2026-03-01)
- [x] **Phase 29: Species Catch Data** — New `add_catch()` function for long-format species-level catch data (completed 2026-03-02)
- [x] **Phase 30: Length Frequency Data** — New `add_lengths()` function for individual and binned fish length data (completed 2026-03-02)
- [x] **Phase 31: Interview-Level Unextrapolated Summaries** — Raw tabulation functions: refusals, day type, angler type, method, species sought, successful parties, trip length (completed 2026-03-02)
- [x] **Phase 32: CWS/HWS Rates** — Caught-while-sought and harvested-while-sought rate functions from raw interview data (completed 2026-03-07)
- [x] **Phase 33: Length Frequency Summaries** — Length distribution functions for catch, harvest, and release (completed 2026-03-07)
- [ ] **Phase 34: Species-Level Extrapolated Estimates** — Extend `estimate_cpue()`, `estimate_total_catch()`, `estimate_total_harvest()` to species groupings; add `estimate_total_release()` and `estimate_release_rate()`
- [ ] **Phase 35: Documentation & Quality Assurance** — Unextrapolated summaries vignette, extended example datasets, complete roxygen2 docs

## Phase Details

### Phase 28: Extended Interview Data Model
**Goal**: Users can capture the full party-level interview record — angler type, method, species sought, party size, and refusal flag — via tidy selectors in `add_interviews()`, with full backward compatibility
**Depends on**: Phase 27 (existing `add_interviews()` API)
**Requirements**: INTV-01, INTV-02, INTV-03, INTV-04, INTV-05, INTV-06
**Success Criteria** (what must be TRUE):
  1. User can pass `angler_type`, `angler_method`, `species_sought`, `n_anglers`, and `refused` columns via tidy selectors in `add_interviews()` and retrieve them from the design object
  2. All five new parameters are optional — existing `add_interviews()` calls with no new arguments pass R CMD check and produce identical output to before
  3. `print.creel_design()` shows the extended interview fields when they are present
  4. R CMD check passes with 0 errors, 0 warnings; lintr finds 0 issues; all existing tests continue to pass
**Plans**: 2 plans
Plans:
- [x] 28-01-PLAN.md — Extend add_interviews() signature, resolution, storage, and print method in R/creel-design.R (completed 2026-03-01)
- [ ] 28-02-PLAN.md — Add make_extended_interviews() helper and 16 new tests in test-add-interviews.R

### Phase 28.1: Normalize CPUE HPUE by angler count (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 28
**Plans:** 2/2 plans complete

Plans:
- [x] TBD (run /gsd:plan-phase 28.1 to break down) (completed 2026-03-01)

### Phase 29: Species Catch Data
**Goal**: Users can attach long-format species-level catch data to a creel design via `add_catch()`, with validation that interview IDs are matched and catch type values and harvest/catch relationships are correct
**Depends on**: Phase 28
**Requirements**: CATCH-01, CATCH-02, CATCH-03, CATCH-04, CATCH-05
**Success Criteria** (what must be TRUE):
  1. User can call `add_catch(design, data, uid = ii_UID, species = ir_Species, count = Num, catch_type = CatchType)` using tidy selectors and inspect the attached data
  2. `add_catch()` throws an informative error when interview IDs in catch data do not appear in the design's interview records
  3. `add_catch()` throws an informative error when `catch_type` contains values outside {caught, harvested, released}
  4. `add_catch()` throws an informative error when harvested count exceeds caught count for any species-interview combination
  5. `print.creel_design()` summary shows attached catch data (species count, row count)
**Plans**: 3 plans

Plans:
- [ ] 29-01-PLAN.md — Extend example_interviews (UID + 5 Phase 28 fields) and create example_catch dataset
- [ ] 29-02-PLAN.md — Implement add_catch() in R/creel-design.R with all validation logic
- [ ] 29-03-PLAN.md — Add Catch Data section to format.creel_design() and write test-add-catch.R

### Phase 30: Length Frequency Data
**Goal**: Users can attach fish length data — both individual harvest measurements and release data in individual or binned format — via `add_lengths()`, with validation and design-level inspection
**Depends on**: Phase 28
**Requirements**: LEN-01, LEN-02, LEN-03, LEN-04, LEN-05
**Success Criteria** (what must be TRUE):
  1. User can attach harvest length data (one row per fish: interview ID, species, length) with `add_lengths()` using tidy selectors
  2. User can attach release length data in individual-measurement format or length-group format (interview ID, species, length_group, count) — both accepted by the same function
  3. `add_lengths()` throws an informative error when interview IDs in length data do not match interviews in the design
  4. `add_lengths()` throws an informative error when length values are non-positive or non-numeric
  5. `print.creel_design()` summary shows attached length data (format, species count, row count)
**Plans**: 1 plan

Plans:
- [x] 30-01-PLAN.md — example_lengths dataset, add_lengths() implementation, Length Data print section, test-add-lengths.R (completed 2026-03-02)

### Phase 31: Interview-Level Unextrapolated Summaries
**Goal**: Users can tabulate raw interview records into the seven standard unextrapolated summary tables (refusals, day type, angler type, method, species sought, successful parties, trip length), each returning a tidy tibble with consistent column names
**Depends on**: Phase 28, Phase 29
**Requirements**: USUM-01, USUM-02, USUM-03, USUM-04, USUM-05, USUM-06, USUM-07, USUM-08
**Success Criteria** (what must be TRUE):
  1. `summarize_refusals(design)` returns a tibble with columns month, participation, N, percent — one row per month × accepted/refused combination
  2. `summarize_by_day_type()`, `summarize_by_angler_type()`, `summarize_by_method()`, `summarize_by_species_sought()` each return a tibble with columns month, grouping_variable, N, percent
  3. `summarize_successful_parties(design)` returns a tibble with columns angler_type, species_sought, N_successful, N_total, percent
  4. `summarize_by_trip_length(design)` returns a tibble with columns trip_length_bin, N, percent
  5. All seven functions return objects with an informative class attribute; R CMD check passes and all tests pass
**Plans**: 2 plans

Plans:
- [x] 31-01-PLAN.md — Create R/creel-summaries.R with all 7 summarize_*() functions, roxygen2 docs, NAMESPACE exports (completed 2026-03-02)
- [x] 31-02-PLAN.md — Write tests/testthat/test-creel-summaries.R with 41 tests for all 7 functions (completed 2026-03-02)

### Phase 32: CWS/HWS Rates
**Goal**: Users can compute caught-while-sought (CWS) and harvested-while-sought (HWS) rates from raw interview data, collapsed to three levels of grouping, with documented limitations about interview-weighted (not pressure-weighted) interpretation
**Depends on**: Phase 29 (catch data), Phase 28 (species sought field)
**Requirements**: CWS-01, CWS-02, CWS-03, CWS-04, CWS-05, CWS-06
**Success Criteria** (what must be TRUE):
  1. `summarize_cws_rates(design)` returns mean CWS rate, variance, and N broken out by month × angler type × species sought (full cross)
  2. `summarize_cws_rates()` supports collapsing across angler type (month × species) and collapsing across both (species only) via a grouping argument or separate calls
  3. `summarize_hws_rates(design)` returns HWS rates by month × species sought and by species sought only
  4. Function documentation explicitly states these rates are weighted by number of interviews, not by fishing pressure, and cautions against direct management use
  5. R CMD check passes and all tests pass
**Plans**: TBD

### Phase 33: Length Frequency Summaries
**Goal**: Users can compute length frequency distributions (N, percent, cumulative percent by length bin) for catch, harvest, and release separately, with configurable bin width, handling both individual-measurement and pre-binned release formats
**Depends on**: Phase 30 (length data)
**Requirements**: LFREQ-01, LFREQ-02, LFREQ-03, LFREQ-04, LFREQ-05
**Success Criteria** (what must be TRUE):
  1. `summarize_length_freq(design, type = "catch")` returns a tibble with columns length_bin, N, percent, cumulative_percent for all fish (caught)
  2. `summarize_length_freq(design, type = "harvest")` and `type = "release"` return the same structure for harvested and released fish respectively
  3. User can specify bin width (e.g., `bin_width = 10`) and the function applies it; default bin width is 1 unit
  4. `summarize_length_freq()` correctly handles both individual-measurement release length format and pre-binned length-group format without requiring the user to specify which format is present
  5. R CMD check passes and all tests pass
**Plans**: TBD

### Phase 34: Species-Level Extrapolated Estimates
**Goal**: Users can compute extrapolated catch, harvest, and release estimates broken down by species (and species × month, species × angler type, etc.) using `add_catch()` data, plus a new `estimate_total_release()` function and `estimate_release_rate()`
**Depends on**: Phase 29 (catch data), Phase 27 (existing extrapolated estimators)
**Requirements**: XEST-01, XEST-02, XEST-03, XEST-04, XEST-05, XEST-06, XEST-07, XEST-08, XEST-09, XEST-10, XEST-11
**Success Criteria** (what must be TRUE):
  1. `estimate_cpue(design, by = species)` returns estimate, SE, and CI per species; grouping by month × species, angler type × species, and month × angler type × species all work via tidy selectors
  2. `estimate_total_catch(design, by = species)` and `estimate_total_harvest(design, by = species)` return extrapolated totals per species, combining effort estimate × catch rate with delta method variance
  3. `estimate_total_release(design)` and `estimate_release_rate(design)` exist and return results analogous to their harvest counterparts, supporting species-level grouping
  4. All new grouping combinations produce tibbles with consistent columns (estimate, SE, lower_ci, upper_ci) matching existing function output structure
  5. R CMD check passes and all tests pass; existing estimator calls without species grouping continue to produce identical results (backward compatibility preserved)
**Plans**: TBD

### Phase 35: Documentation & Quality Assurance
**Goal**: All new v0.5.0 functions are fully documented with roxygen2, extended example datasets support species-level examples, and a new vignette demonstrates the complete unextrapolated workflow end-to-end
**Depends on**: Phase 28, Phase 29, Phase 30, Phase 31, Phase 32, Phase 33, Phase 34
**Requirements**: DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. A new vignette "Unextrapolated Summaries" renders without error and demonstrates: extended `add_interviews()` → `add_catch()` → `add_lengths()` → all seven `summarize_*()` functions → CWS/HWS rates → length frequencies
  2. Package example datasets include species-level catch data and fish length data sufficient to run all new function examples
  3. All new functions (`add_catch()`, `add_lengths()`, all `summarize_*()` functions) have complete roxygen2 docs with `@param`, `@return`, `@examples` that pass `R CMD check --as-cran`
  4. R CMD check 0 errors, 0 warnings; lintr 0 issues; test coverage at or above ~90% (~1,200+ tests total)
**Plans**: TBD

## Progress Summary

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 Foundation | 1-7 | 12/12 | ✅ Complete | 2026-02-09 |
| v0.2.0 Interview-Based Estimation | 8-12 | 10/10 | ✅ Complete | 2026-02-11 |
| v0.3.0 Incomplete Trips & Validation | 13-20 | 16/16 | ✅ Complete | 2026-02-16 |
| v0.4.0 Bus-Route Survey Support | 21-27 | 14/14 | ✅ Complete | 2026-02-28 |
| v0.5.0 Interview Data Model and Unextrapolated Summaries | 28-35 | 1/TBD | 🚧 In progress | - |

**Overall:** 4 milestones shipped, 32 phases complete, 54 plans executed; 8 phases planned for v0.5.0

---
*Roadmap last updated: 2026-03-07 — Phase 33 complete (summarize_length_freq(), 47 tests, handles individual + pre-binned release formats)*
*See .planning/MILESTONES.md for full milestone history*
