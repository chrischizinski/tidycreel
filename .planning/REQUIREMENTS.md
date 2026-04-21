# Requirements: tidycreel

**Defined:** 2026-04-19
**Milestone:** M023 — v1.4.0 Quality, Polish, and rOpenSci Readiness
**Core Value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.

## v1.4.0 Requirements

### Error Handling

- [x] **ERRH-01**: Named condition classes added at all 8 priority sites identified in 74-QUALITY-AUDIT.md

### API Surface

- [x] **API-01**: `lifecycle` badges applied to deprecated/experimental functions and `lifecycle` added to DESCRIPTION
- [x] **API-02**: `inst/CITATION` file created and populated
- [ ] **API-03**: `creel_summary_*` S3 subclass direction explicitly committed or documented as deferred with rationale

### Dependencies

- [x] **DEPS-01**: `scales` removed from Imports (one `sprintf()` replacement in survey-bridge.R)
- [x] **DEPS-02**: `lubridate` demoted to Suggests with `check_installed()` guards at all use sites

### Testing

- [ ] **TEST-01**: quickcheck property-based tests written for INV-01–06 (priority order: INV-04 → INV-01 → INV-02 → INV-06 → INV-03; INV-05 manual-review only)
- [x] **TEST-02**: `expect_snapshot()` adopted for 6 priority methods from 74-TESTING-STRATEGY.md
- [ ] **TEST-03**: Fresh `covr` run confirms coverage baseline; codecov threshold configured in CI

### Code Quality

- [ ] **CODE-01**: `@family` tags added across all R/ files (zero currently; enables pkgdown grouping)
- [x] **CODE-02**: `rlang::caller_env()` added to bus-route estimators (P3 gap from Phase 73 review)
- [x] **CODE-03**: `get_site_contributions()` relocated to correct architectural layer (A1 finding from 72-ARCH-REVIEW.md)

### Verification

- [ ] **VER-01**: Phase 70 human verification complete: vignette build passes and test suite green

## v1.5+ Requirements (Deferred)

### Analytical Extensions

- **EXT-01**: Exploitation rate estimator (build candidate confirmed in M022; no clean R wrapper exists yet)
- **EXT-02**: Multi-species joint covariance estimation (requires prototype before interface commitment)
- **EXT-03**: Mark-recapture estimators (large scope)
- **EXT-04**: Spatial/temporal random effects for non-aerial survey types

### Architecture

- **ARCH-01**: `creel.connect` schema contract formalization (3 companion package gaps must close first)
- **ARCH-02**: `ggplot2` Import vs Suggests architectural decision (is visualisation core or optional?)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Rcpp acceleration | DEFER — empirical profiling shows bootstrap cost is in upstream `survey::as.svrepdesign()`, not addressable in tidycreel |
| Mobile app / web UI | No current demand |
| INV-05 automated quickcheck | Manual-review-only — Taylor/bootstrap convergence not automatable via quickcheck |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ERRH-01 | Phase 76 | Complete |
| API-01 | Phase 76 | Complete |
| API-02 | Phase 76 | Complete |
| DEPS-01 | Phase 76 | Complete |
| DEPS-02 | Phase 77 | Complete |
| CODE-02 | Phase 77 | Complete |
| CODE-03 | Phase 77 | Complete |
| CODE-01 | Phase 78 | Pending |
| TEST-02 | Phase 78 | Complete |
| TEST-01 | Phase 79 | Pending |
| TEST-03 | Phase 79 | Pending |
| API-03 | Phase 80 | Pending |
| VER-01 | Phase 80 | Pending |

**Coverage:**
- v1.4.0 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-19*
*Last updated: 2026-04-19 — Traceability confirmed after roadmap creation*
