# Requirements — v1.8.0 Exports, Bootstrap CIs, and API Hardening

**Milestone:** v1.8.0
**Status:** Active — roadmap defined
**Last updated:** 2026-05-16

---

## v1 Requirements

### Reporting Exports (EXPORT)

- [ ] **EXPORT-01**: Analyst can call `tidy(estimates)` to get a flat tibble from any `creel_estimates` object
- [ ] **EXPORT-02**: Analyst can call `write_estimates(estimates, path)` to write estimates to CSV or Excel

### Bootstrap Confidence Intervals (BOOT)

- [ ] **BOOT-01**: `estimate_total_harvest_br()` supports `ci_method = "bootstrap"` returning bootstrap CI alongside delta-method SE
- [ ] **BOOT-02**: `estimate_total_catch()` supports `ci_method = "bootstrap"`
- [ ] **BOOT-03**: `estimate_angler_n()` supports `ci_method = "bootstrap"`
- [ ] **BOOT-04**: `estimate_mr_harvest()` supports `ci_method = "bootstrap"`

### API Hardening (API)

- [x] **API-09**: NGPC discovery field names confirmed and TODO stubs resolved in all 6 `api_rename_map` entries
- [x] **API-10**: `list_creels()` returns empty tibble with correct column structure when no surveys found
- [x] **API-11**: `fetch_counts()` returns `n_counted` and `n_interviewed` for bus-route API connections

### Quality / Package Health (QUAL)

- [x] **QUAL-01**: Validation script `calamus-2016-validation.R` has working-directory guard so it runs correctly from any context
- [x] **QUAL-02**: `rcmdcheck` passes with 0 warnings (non-ASCII character and VignetteBuilder warnings resolved)

### Security (SEC)

- [x] **SEC-01**: `tidycreel.connect` API connection and YAML-credential code reviewed for security issues (token exposure, injection, credential storage patterns)

---

## Future Requirements (Deferred)

- **MR-F01**: Jolly-Seber open-population estimator — output contract incompatible with `creel_estimates`; requires new S3 class
- **CAMP-F01**: Multiple imputation via Rubin's rules — extends `impute_camera_counts()`
- **STRAT-F01**: CPUE precision audit in `audit_strata(type = "cpue")`
- **QUAL-05**: rOpenSci formal submission — deferred to undetermined future date

---

## Out of Scope

- Bootstrap CI for `estimate_exploitation_rate()` — delta-method SE sufficient; bootstrap path requires survey design object not always available
- `power_creel(mode = "camera_n")` integration — `creel_n_camera()` is standalone; deferred
- Spatial/temporal random effects for non-aerial types — research complete; no implementation commitment
- Full YAML-defined SQL connection pooling — schema contract frozen-but-informal; companion package gaps not in scope
- Multi-species joint covariance estimation — requires prototype before interface commitment

---

## Traceability

| Requirement | Phase | Plan |
|-------------|-------|------|
| SEC-01 | Phase 91 | TBD |
| API-09 | Phase 91 | TBD |
| API-10 | Phase 91 | TBD |
| API-11 | Phase 91 | TBD |
| QUAL-01 | Phase 92 | TBD |
| QUAL-02 | Phase 92 | TBD |
| EXPORT-01 | Phase 93 | TBD |
| EXPORT-02 | Phase 93 | TBD |
| BOOT-01 | Phase 94 | TBD |
| BOOT-02 | Phase 94 | TBD |
| BOOT-03 | Phase 94 | TBD |
| BOOT-04 | Phase 94 | TBD |
