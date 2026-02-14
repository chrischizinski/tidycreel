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
| TRIP-01 | TBD | Pending |
| TRIP-02 | TBD | Pending |
| TRIP-03 | TBD | Pending |
| TRIP-04 | TBD | Pending |
| TRIP-05 | TBD | Pending |
| MOR-01 | TBD | Pending |
| MOR-02 | TBD | Pending |
| MOR-03 | TBD | Pending |
| MOR-04 | TBD | Pending |
| MOR-05 | TBD | Pending |
| MOR-06 | TBD | Pending |
| VALID-01 | TBD | Pending |
| VALID-02 | TBD | Pending |
| VALID-03 | TBD | Pending |
| VALID-04 | TBD | Pending |
| API-01 | TBD | Pending |
| API-02 | TBD | Pending |
| API-03 | TBD | Pending |
| API-04 | TBD | Pending |
| DOC-01 | TBD | Pending |
| DOC-02 | TBD | Pending |
| DOC-03 | TBD | Pending |
| DOC-04 | TBD | Pending |

**Coverage:**
- v0.3.0 requirements: 23 total
- Mapped to phases: 0 (roadmap not yet created)
- Unmapped: 23 ⚠️

---
*Requirements defined: 2026-02-14*
*Last updated: 2026-02-14 after initial definition*
