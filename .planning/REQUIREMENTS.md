# Requirements: tidycreel v0.3.0

**Defined:** 2026-02-14
**Core Value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals

## v0.3.0 Requirements

Requirements for incomplete trip support with complete trip prioritization (roving-access design).

### Trip Status Management

- [ ] **TRIP-01**: User can specify trip completion status (complete vs. incomplete) in interview data
- [ ] **TRIP-02**: User can provide trip start time and interview time (calculate duration)
- [ ] **TRIP-03**: User can provide trip duration directly (alternative input format)
- [ ] **TRIP-04**: Package correctly calculates trip duration for overnight trips spanning multiple days
- [ ] **TRIP-05**: Package validates trip status field and warns about missing/invalid values

### Incomplete Trip Estimation (Mean-of-Ratios)

- [ ] **MOR-01**: User can estimate CPUE from incomplete trips using mean-of-ratios estimator
- [ ] **MOR-02**: User can configure minimum trip duration threshold (default 20-30 min per Hoenig et al.)
- [ ] **MOR-03**: Package truncates incomplete trips shorter than threshold with informative message
- [ ] **MOR-04**: Package validates sample size for MOR estimation (error n<10, warn n<30)
- [ ] **MOR-05**: User can select variance method for MOR (Taylor, bootstrap, jackknife)
- [ ] **MOR-06**: Package computes variance correctly for MOR estimator with truncation

### Diagnostic Validation

- [ ] **VALID-01**: User can compare complete vs. incomplete trip estimates side-by-side
- [ ] **VALID-02**: Package performs statistical test for difference between complete and incomplete estimates
- [ ] **VALID-03**: User can generate validation plot (incomplete vs. complete scatter with y=x reference)
- [ ] **VALID-04**: Package produces diagnostic report with interpretation guidance

### API Design & Defaults

- [ ] **API-01**: `estimate_cpue()` uses complete trips only by default (roving-access design)
- [ ] **API-02**: Package warns when < 10% of interviews are complete trips (Colorado C-SAP threshold)
- [ ] **API-03**: User can explicitly specify `use_trips = "complete"/"incomplete"/"diagnostic"` parameter
- [ ] **API-04**: Package messages reference Colorado C-SAP and Pollock et al. best practices

### Documentation & Guidance

- [ ] **DOC-01**: Incomplete trips vignette explains when and how to use incomplete trip estimation
- [ ] **DOC-02**: Example demonstrates Colorado C-SAP best practices (complete trips prioritized)
- [ ] **DOC-03**: Documentation strongly warns against pooling complete + incomplete interviews
- [ ] **DOC-04**: Step-by-step validation workflow guide for testing incomplete trip assumptions

## Future Requirements (v0.4.0+)

Deferred to future releases.

### Bus-Route Design

- **BUS-01**: Bus-route design with systematic access point coverage
- **BUS-02**: Time-scheduled routes with multiple access points
- **BUS-03**: Bus-route specific estimation methods

### Multi-Species Support

- **MULTI-01**: Multi-species catch data with species-specific CPUE
- **MULTI-02**: Covariance between species catch rates
- **MULTI-03**: Total catch across species with correct variance

## Out of Scope

Explicitly excluded from all versions.

| Feature | Reason |
|---------|--------|
| Auto-pooling complete + incomplete trips | Scientifically invalid per Pollock et al. - different sampling probabilities |
| Roving-roving design (effort from roving) | Science shows 160x more bias than roving-access - not recommended |
| Incomplete trips as default | Colorado C-SAP and best practice use complete trips; incomplete is diagnostic |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRIP-01 | Phase 13 | Pending |
| TRIP-02 | Phase 13 | Pending |
| TRIP-03 | Phase 13 | Pending |
| TRIP-04 | Phase 14 | Pending |
| TRIP-05 | Phase 13 | Pending |
| MOR-01 | Phase 15 | Pending |
| MOR-02 | Phase 16 | Pending |
| MOR-03 | Phase 16 | Pending |
| MOR-04 | Phase 15 | Pending |
| MOR-05 | Phase 15 | Pending |
| MOR-06 | Phase 16 | Pending |
| VALID-01 | Phase 19 | Pending |
| VALID-02 | Phase 19 | Pending |
| VALID-03 | Phase 19 | Pending |
| VALID-04 | Phase 19 | Pending |
| API-01 | Phase 17 | Pending |
| API-02 | Phase 18 | Pending |
| API-03 | Phase 17 | Pending |
| API-04 | Phase 18 | Pending |
| DOC-01 | Phase 20 | Pending |
| DOC-02 | Phase 20 | Pending |
| DOC-03 | Phase 20 | Pending |
| DOC-04 | Phase 20 | Pending |

**Coverage:**
- v0.3.0 requirements: 23 total
- Mapped to phases: 23/23 (100%)
- Unmapped: 0

**Phase distribution:**
- Phase 13: 4 requirements (TRIP-01, TRIP-02, TRIP-03, TRIP-05)
- Phase 14: 1 requirement (TRIP-04)
- Phase 15: 3 requirements (MOR-01, MOR-04, MOR-05)
- Phase 16: 3 requirements (MOR-02, MOR-03, MOR-06)
- Phase 17: 2 requirements (API-01, API-03)
- Phase 18: 2 requirements (API-02, API-04)
- Phase 19: 4 requirements (VALID-01, VALID-02, VALID-03, VALID-04)
- Phase 20: 4 requirements (DOC-01, DOC-02, DOC-03, DOC-04)

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-14 after roadmap creation*
