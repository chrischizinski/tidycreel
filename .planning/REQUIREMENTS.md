# Requirements: tidycreel

**Defined:** 2026-04-26
**Core Value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.

## v1.5.0 Requirements

### Estimators

- [x] **ESTIM-01**: `estimate_total_catch()` returns the same aggregate estimate as summing `estimate_total_catch(by = "species")` for multi-strata designs (INV-06 fix — stratified-sum)
- [ ] **ESTIM-02**: `estimate_exploitation_rate()` accepts tagged-fish count and creel-harvest data and returns an exploitation rate using the Pollock et al. formulation
- [ ] **ESTIM-03**: `estimate_exploitation_rate()` supports stratification by survey strata and returns stratum-level estimates
- [x] **ESTIM-04**: INV-06 quickcheck property test passes for multi-strata multi-species designs after fix
- [ ] **ESTIM-05**: `estimate_exploitation_rate()` is documented with a worked example in its Rd file

### Package Quality

- [ ] **QUAL-01**: Unused `lifecycle` import removed from DESCRIPTION and NAMESPACE
- [ ] **QUAL-02**: Package passes `urlchecker::url_check()` with no broken URLs
- [ ] **QUAL-03**: Package passes `rhub::rhub_check()` on Linux and macOS platforms
- [ ] **QUAL-04**: `goodpractice::gp()` findings addressed (WARNING-level and above)
- [ ] **QUAL-05**: rOpenSci software review issue opened at ropensci/software-review

### Documentation

- [ ] **DOCS-01**: pkgdown site includes a `tidycreel.connect` bridge article describing the companion package and linking to it

## Future Requirements

### Estimators

- **ESTIM-F01**: Exploitation-rate estimator supports Bayesian credible interval via Stan/brms
- **ESTIM-F02**: Multi-species joint covariance estimation via `survey::svyby(..., covmat=TRUE)`
- **ESTIM-F03**: Mark-recapture effort estimation (Petersen/Chapman applied to anglers)

### Documentation

- **DOCS-F01**: Standalone pkgdown site for `tidycreel.connect` companion package

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mark-recapture estimators (fish population) | Large scope; FSA wrappers sufficient; deferred to v1.6+ |
| Spatial/temporal random-effects estimators | Research complete in M022; no implementation commitment yet |
| Rcpp acceleration | M022 profiling: Taylor 1.5ms; bootstrap cost is in upstream survey::, not addressable here |
| creel_schema / generic DB interface | Companion package scope; schema contract frozen-but-informal |
| Mobile app or web UI | Web-first; no current demand |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ESTIM-01 | Phase 80 | Complete |
| ESTIM-04 | Phase 80 | Complete |
| ESTIM-02 | Phase 81 | Pending |
| ESTIM-03 | Phase 81 | Pending |
| ESTIM-05 | Phase 81 | Pending |
| QUAL-01 | Phase 82 | Pending |
| QUAL-02 | Phase 82 | Pending |
| QUAL-03 | Phase 82 | Pending |
| QUAL-04 | Phase 82 | Pending |
| DOCS-01 | Phase 82 | Pending |
| QUAL-05 | Phase 83 | Pending |

**Coverage:**
- v1.5.0 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0

---
*Requirements defined: 2026-04-26*
*Last updated: 2026-04-26 — traceability updated after M024 roadmap creation*
