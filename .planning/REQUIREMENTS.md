# Requirements: tidycreel v0.9.0

**Defined:** 2026-03-22
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals.

## v0.9.0 Requirements

### Schedule Generation

- [ ] **SCHED-01**: User can generate a sampling calendar given season start/end dates, weekday/weekend day split, number of periods per day, and sampling intensity (total days or %) as a tidy tibble
- [ ] **SCHED-02**: User can generate a bus-route schedule given a sampling calendar plus circuit definitions, sites per circuit, crew size, and randomization seed — output is a tibble with `inclusion_prob` columns ready for `creel_design(survey_type = "bus_route")`
- [x] **SCHED-03**: User can export any schedule tibble to CSV (base R) or xlsx (writexl, optional) for field use
- [x] **SCHED-04**: User can read a previously saved schedule file back into R as a validated `creel_schedule` object with correct column types, ready to pass to `creel_design()`

### Power and Sample Size

- [ ] **POWER-01**: User can calculate the number of sampling days required to achieve a target CV on effort estimates using the stratified McCormick & Quist (2017) formula
- [ ] **POWER-02**: User can calculate the number of interviews required to achieve a target CV on CPUE estimates using the Cochran (1977) ratio estimator variance formula
- [ ] **POWER-03**: User can calculate the statistical power to detect a specified percentage change in CPUE between two seasons given alpha, historical CV, and sample size
- [ ] **POWER-04**: User can calculate the expected CV given a known sample size (inverse of POWER-01 and POWER-02)

### Design Validation

- [ ] **VALID-01**: User can run a pre-season design check that returns a pass/warn/fail status per stratum by calling `creel_n_effort()` and `creel_n_cpue()` internally against a proposed sampling frame

### Data Quality

- [ ] **QUAL-01**: User can check post-season data completeness in a single call that reports missing sampling days, low-sample strata (below user-specified n threshold), and refusal rates — dispatched by survey type to avoid false positives on aerial/ice designs

### Season Reporting

- [ ] **REPT-01**: User can assemble a named list of pre-computed `creel_estimates` outputs into a single report-ready wide tibble containing effort, catch rate, and total catch/harvest columns

## Future Requirements

### Schedule Generation

- **SCHED-F01**: User can generate a large-lake schedule with multi-section routing and paired crew allocation (equal-probability rotating design only) — deferred to v1.0+

### Power and Sample Size

- **POWER-F01**: User can calculate Neyman optimal stratum allocation given per-stratum variance estimates and total sample size budget — deferred until base planning tools prove adoptable

## Out of Scope

| Feature | Reason |
|---------|--------|
| Full PDF/Word report rendering | Opinionated template with high maintenance burden; `season_summary()` tibble is the deliverable — users render |
| Automatic pilot data extraction from current season | Circular: same-season data to size same-season sample produces invalid CV estimates |
| Interactive Shiny scheduler | Out of scope; tidy tibble output is pipe-friendly and can feed any user-built Shiny app |
| Monte Carlo simulation | Duplicates `AnglerCreelSurveySimulation` (CRAN); analytical calculators are more direct for target users |
| Large-lake scheduler (constraint optimization) | NP-hard assignment problem; not v0.9.0 scope — bounded equal-probability design only when eventually built |
| `pointblank` / `pwr` as Imports | Unnecessary dependency footprint; `dplyr` + `cli` cover completeness; `stats::` covers power |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCHED-01 | Phase 48 | Pending |
| SCHED-02 | Phase 48 | Pending |
| SCHED-03 | Phase 48 | Complete |
| SCHED-04 | Phase 48 | Complete |
| POWER-01 | Phase 49 | Pending |
| POWER-02 | Phase 49 | Pending |
| POWER-03 | Phase 49 | Pending |
| POWER-04 | Phase 49 | Pending |
| VALID-01 | Phase 50 | Pending |
| QUAL-01  | Phase 50 | Pending |
| REPT-01  | Phase 51 | Pending |

**Coverage:**
- v0.9.0 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-22*
*Last updated: 2026-03-22 — traceability complete after roadmap creation*
