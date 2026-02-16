# Requirements: tidycreel v0.4.0

**Defined:** 2026-02-16
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals

## v0.4.0 Requirements - Bus-Route Survey Support

Requirements for bus-route (nonuniform probability) creel survey estimation based on primary source methodology.

### Bus-Route Core Functionality

- [ ] **BUSRT-01**: System calculates inclusion probability πᵢ from sampling design (p_site × p_period), not site characteristics
- [ ] **BUSRT-02**: System applies enumeration expansion (n_counted / n_interviewed) to account for uncounted parties at busy sites
- [ ] **BUSRT-03**: System estimates effort using Jones & Pollock (2012) Eq. 19.4 general estimator
- [ ] **BUSRT-04**: System estimates harvest using Jones & Pollock (2012) Eq. 19.5 general estimator
- [ ] **BUSRT-05**: System supports nonuniform probability sampling where different sites/periods have different sampling probabilities
- [ ] **BUSRT-06**: creel_design() constructor accepts survey_type = "bus_route" with site and circuit specifications
- [ ] **BUSRT-07**: Design validation ensures site probabilities sum to 1.0 and all probabilities are in (0,1]
- [ ] **BUSRT-08**: add_interviews() joins sampling probabilities to interview data for bus-route designs
- [ ] **BUSRT-09**: estimate_effort() dispatches to bus-route estimator when design type is bus_route
- [ ] **BUSRT-10**: estimate_harvest() dispatches to bus-route estimator when design type is bus_route
- [ ] **BUSRT-11**: System provides variance estimation via survey package for bus-route estimates

### Validation & Correctness

- [ ] **VALID-01**: Implementation reproduces Malvestuto (1996) Box 20.6 Example 1 results exactly
- [ ] **VALID-02**: Enumeration expansion calculations match published methodology
- [ ] **VALID-03**: πᵢ calculation for two-stage sampling (site × period) produces correct values
- [ ] **VALID-04**: Progressive validation catches missing enumeration counts at data input time
- [ ] **VALID-05**: Integration tests verify complete bus-route workflow (design → data → estimation)

### Documentation & Traceability

- [ ] **DOCS-01**: Vignette explains what bus-route surveys are and when to use them
- [ ] **DOCS-02**: Vignette documents key concepts (inclusion probability, enumeration counts, two-stage sampling)
- [ ] **DOCS-03**: Vignette provides step-by-step walkthrough of using tidycreel code to generate bus-route estimates
- [ ] **DOCS-04**: Equation traceability document maps every line of code to source equation and page number
- [ ] **DOCS-05**: Documentation explains why tidycreel implementation is correct vs. existing packages

## Future Requirements

Deferred to v0.5.0+

### Multi-Species Support

- **MULTI-01**: Support multi-species catch/harvest estimation with covariance framework
- **MULTI-02**: Handle species-specific catch rates and correlations

### Advanced QA/QC

- **QA-01**: Diagnostic plots for interview data quality
- **QA-02**: Outlier detection and handling recommendations

## Out of Scope

Explicitly excluded from v0.4.0

| Feature | Reason |
|---------|--------|
| Hardcoded πᵢ values (like existing packages) | Statistically incorrect - defeats the purpose of correct implementation |
| Roving-roving design for effort estimation | 160x more bias than roving-access, not scientifically recommended |
| Backward compatibility with incorrect formulas | Breaking with incorrect methodology is intentional |
| Multi-species covariance in this milestone | Focus on correct single-species bus-route first, defer to v0.5.0 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUSRT-06 | Phase 21 | Pending |
| BUSRT-07 | Phase 21 | Pending |
| BUSRT-01 | Phase 22 | Pending |
| BUSRT-05 | Phase 22 | Pending |
| VALID-03 | Phase 22 | Pending |
| BUSRT-08 | Phase 23 | Pending |
| BUSRT-02 | Phase 23 | Pending |
| VALID-04 | Phase 23 | Pending |
| BUSRT-03 | Phase 24 | Pending |
| BUSRT-09 | Phase 24 | Pending |
| BUSRT-11 | Phase 24 | Pending |
| BUSRT-04 | Phase 25 | Pending |
| BUSRT-10 | Phase 25 | Pending |
| VALID-01 | Phase 26 | Pending |
| VALID-02 | Phase 26 | Pending |
| VALID-05 | Phase 26 | Pending |
| DOCS-01 | Phase 27 | Pending |
| DOCS-02 | Phase 27 | Pending |
| DOCS-03 | Phase 27 | Pending |
| DOCS-04 | Phase 27 | Pending |
| DOCS-05 | Phase 27 | Pending |

**Coverage:**
- v0.4.0 requirements: 21 total
- Mapped to phases: 21 (100% coverage)
- Unmapped: 0

**Phase Distribution:**
- Phase 21 (Bus-Route Design Foundation): 2 requirements
- Phase 22 (Inclusion Probability Calculation): 3 requirements
- Phase 23 (Data Integration): 3 requirements
- Phase 24 (Bus-Route Effort Estimation): 3 requirements
- Phase 25 (Bus-Route Harvest Estimation): 2 requirements
- Phase 26 (Primary Source Validation): 3 requirements
- Phase 27 (Documentation & Traceability): 5 requirements

---
*Requirements defined: 2026-02-16*
*Last updated: 2026-02-16 after roadmap creation with 100% coverage*
