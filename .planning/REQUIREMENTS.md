# Requirements: tidycreel

**Defined:** 2026-02-09
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals

## v0.2.0 Requirements - Interview-Based Estimation

Requirements for interview-based catch and harvest estimation (single species, complete trips).

### Interview Data Management

- [ ] **INTV-01**: User can attach interview data to existing creel_design object
- [ ] **INTV-02**: User specifies interview columns using tidy selectors (catch, effort, trip_complete)
- [ ] **INTV-03**: System validates interview data structure (Tier 1: required columns, valid types)
- [ ] **INTV-04**: System validates interview data quality (Tier 2: warnings for missing effort, extreme values)
- [ ] **INTV-05**: System constructs interview survey design with shared calendar stratification
- [ ] **INTV-06**: System detects interview type (access point complete trips for v0.2.0)

### Catch Rate Estimation (CPUE)

- [ ] **CPUE-01**: User can estimate catch per unit effort (CPUE) with SE and CI
- [ ] **CPUE-02**: System uses ratio-of-means estimator for complete trip interviews
- [ ] **CPUE-03**: User can estimate grouped CPUE using `by =` parameter (by stratum or other variables)
- [ ] **CPUE-04**: System validates sufficient sample size (warn if n<30, error if n<10 per group)
- [ ] **CPUE-05**: User can control variance method (Taylor, bootstrap, jackknife) for CPUE estimation
- [ ] **CPUE-06**: System output clearly indicates estimator used ("Ratio-of-Means CPUE")

### Total Catch Estimation

- [ ] **TCATCH-01**: User can estimate total catch by combining effort and CPUE estimates
- [ ] **TCATCH-02**: System propagates variance correctly using delta method (not naive addition)
- [ ] **TCATCH-03**: System validates design compatibility between count and interview data
- [ ] **TCATCH-04**: User can estimate grouped total catch (by stratum or other variables)
- [ ] **TCATCH-05**: System handles single species fisheries (v0.2.0 scope constraint)

### Harvest Estimation

- [ ] **HARV-01**: User can estimate harvest per unit effort (HPUE) for fish kept
- [ ] **HARV-02**: User can estimate total harvest by combining effort and HPUE
- [ ] **HARV-03**: System distinguishes between caught (total) and kept (harvest) fish
- [ ] **HARV-04**: System validates catch_kept ≤ catch_total consistency

### Quality & Usability

- [ ] **QUAL-01**: System provides progressive validation (Tier 1 errors, Tier 2 warnings)
- [ ] **QUAL-02**: System integrates with existing variance method infrastructure from v0.1.0
- [ ] **QUAL-03**: System maintains design-centric API (everything through creel_design object)
- [ ] **QUAL-04**: Documentation includes interview-based estimation vignette with examples
- [ ] **QUAL-05**: Example datasets include interview data (access point complete trips)
- [ ] **QUAL-06**: All functions pass R CMD check with 0 errors/warnings
- [ ] **QUAL-07**: Test coverage ≥85% overall, ≥95% for core estimation functions
- [ ] **QUAL-08**: All code passes lintr with 0 issues

## v2 Requirements - Advanced Interview Features

Deferred to future releases (v0.3.0+). Tracked but not in current roadmap.

### Incomplete Trip Handling

- **ROVING-01**: User can analyze incomplete trip interviews (roving design)
- **ROVING-02**: System uses mean-of-ratios estimator with trip truncation (<30 min)
- **ROVING-03**: System detects and warns about bag limit bias in roving surveys
- **ROVING-04**: System handles mixed complete/incomplete trips in same survey

### Multi-Species Support

- **MULTI-01**: User can analyze multi-species fisheries with species-specific estimates
- **MULTI-02**: System handles species aggregation with proper covariance
- **MULTI-03**: User can estimate catch by target species (caught-while-seeking)

### Advanced Features

- **ADV-01**: System estimates covariance between effort and CPUE (when non-independent)
- **ADV-02**: User can apply interview sampling weights for complex designs
- **ADV-03**: System provides QA/QC diagnostics for interview data quality

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Incomplete trip handling in v0.2.0 | Complexity of mean-of-ratios with truncation; defer to v0.3.0 after complete trips proven |
| Multi-species fisheries in v0.2.0 | Requires covariance framework; single species sufficient for architecture validation |
| Caught-while-seeking tracking | Complex domain logic; defer to v0.3.0 with multi-species support |
| Other count design types (roving, aerial, bus route) | v0.2.0 focuses on interview layer only; count design expansion in separate milestone |
| Backward compatibility with tidycreel v1 | Package never released; v2 is clean slate |
| Stock assessment features (FSA integration) | Out of domain; tidycreel is survey statistics, not biological assessment |
| Visualization/plotting functions | Deferred to v1.0.0 or separate package |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INTV-01 | Phase 8 | Pending |
| INTV-02 | Phase 8 | Pending |
| INTV-03 | Phase 8 | Pending |
| INTV-04 | Phase 8 | Pending |
| INTV-05 | Phase 8 | Pending |
| INTV-06 | Phase 8 | Pending |
| CPUE-01 | Phase 9 | Pending |
| CPUE-02 | Phase 9 | Pending |
| CPUE-03 | Phase 9 | Pending |
| CPUE-04 | Phase 9 | Pending |
| CPUE-05 | Phase 9 | Pending |
| CPUE-06 | Phase 9 | Pending |
| HARV-01 | Phase 10 | Pending |
| HARV-02 | Phase 10 | Pending |
| HARV-03 | Phase 10 | Pending |
| HARV-04 | Phase 10 | Pending |
| TCATCH-01 | Phase 11 | Pending |
| TCATCH-02 | Phase 11 | Pending |
| TCATCH-03 | Phase 11 | Pending |
| TCATCH-04 | Phase 11 | Pending |
| TCATCH-05 | Phase 11 | Pending |
| QUAL-01 | Phase 8 | Pending |
| QUAL-02 | Phase 9 | Pending |
| QUAL-03 | Phase 8 | Pending |
| QUAL-04 | Phase 12 | Pending |
| QUAL-05 | Phase 12 | Pending |
| QUAL-06 | Phase 12 | Pending |
| QUAL-07 | Phase 12 | Pending |
| QUAL-08 | Phase 12 | Pending |

**Coverage:**
- v0.2.0 requirements: 29 total
- Mapped to phases: 29 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-02-09*
*Last updated: 2026-02-09 after roadmap creation*
