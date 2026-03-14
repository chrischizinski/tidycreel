# Requirements: tidycreel v0.7.0 — Spatially Stratified Estimation

**Milestone:** v0.7.0
**Defined:** 2026-03-10
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals

---

## v0.7.0 Requirements

### Section Estimation Infrastructure

- [x] **SECT-01**: User can call `estimate_effort()` on a sectioned design and receive per-section effort rows with correct section-level SE
- [x] **SECT-02**: User can set `aggregate_sections = TRUE` (default) to receive a `.lake_total` row computed via `svycontrast()` that accounts for cross-section covariance; `method = "correlated"` (default) uses `svyby(covmat=TRUE)` + `svycontrast()`, `method = "independent"` uses Cochran 5.2 additivity for genuinely independent section designs
- [x] **SECT-03**: User can set `missing_sections = "warn"` (default) or `"error"` — registered sections absent from data produce an NA row (`data_available = FALSE`) and a `cli_warn()` before estimation
- [x] **SECT-04**: Designs without `add_sections()` produce identical results to current behavior (zero regressions in 1,400+ existing tests)
- [x] **SECT-05**: Per-section result includes a `prop_of_lake_total` column derived from the full-design lake total (not `sum(section_estimates)`)

### Interview-Based Rate Estimators

- [x] **RATE-01**: `estimate_cpue()` renamed to `estimate_catch_rate()` and `estimate_harvest()` renamed to `estimate_harvest_rate()` — breaking change in v0.7.0, no deprecated wrappers; user can call `estimate_catch_rate()` on a sectioned design and receive per-section catch rate rows only — no `.lake_total` row (rate is not additive; documented behavior)
- [x] **RATE-02**: User can call `estimate_harvest_rate()` and `estimate_release_rate()` on a sectioned design and receive per-section rate rows
- [x] **RATE-03**: Missing sections in interview data follow the same `missing_sections` guard as effort

### Product Estimators

- [x] **PROD-01**: User can call `estimate_total_catch()`, `estimate_total_harvest()`, `estimate_total_release()` on a sectioned design and receive per-section totals with delta-method SE
- [x] **PROD-02**: `aggregate_sections = TRUE` produces a `.lake_total` row by summing `TC_i = E_i × CPUE_i` per section — not `E_total × CPUE_pooled`

### Example Data and Documentation

- [ ] **DOCS-01**: A 3-section example dataset is included showing material variation across sections (different effort levels and catch rates across sections)
- [ ] **DOCS-02**: A vignette "Spatially stratified estimation with sections" demonstrates the full workflow and explains the correlated-domains vs. independent-strata variance decision

---

## Future Requirements (v0.8.0+)

- Section metadata (area_ha, shoreline_km) joinable into result tibbles — deferred to v0.8.0
- Aerial survey support with area-weighted per-section estimation — requires area in estimator formula
- Per-section TOST incomplete trip validation — single-lake pooled test sufficient for now

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| Section metadata (area_ha, shoreline_km) in results | Deferred to v0.8.0 — not needed for core estimation |
| Aerial survey area-weighted estimation | Requires area in estimator formula; architectural change for v0.8.0 |
| Per-section TOST incomplete trip validation | Single-lake pooled test is sufficient; low priority |
| Effort-weighted lake-wide CPUE row | Rate is not additive; lake-wide CPUE requires separate unpooled call |

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| SECT-01 | Phase 39 | In progress |
| SECT-02 | Phase 39 | In progress |
| SECT-03 | Phase 39 | In progress |
| SECT-04 | Phase 39 | In progress |
| SECT-05 | Phase 39 | In progress |
| RATE-01 | Phase 40 | Complete |
| RATE-02 | Phase 40 | Complete |
| RATE-03 | Phase 40 | Complete |
| PROD-01 | Phase 41 | Complete |
| PROD-02 | Phase 41 | Complete |
| DOCS-01 | Phase 42 | Pending |
| DOCS-02 | Phase 42 | Pending |

**Coverage:**
- v0.7.0 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-10*
*Last updated: 2026-03-10 — traceability filled by roadmapper*
