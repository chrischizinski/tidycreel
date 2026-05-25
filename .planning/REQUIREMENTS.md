# Requirements — tidycreel v1.9.0

**Milestone:** v1.9.0 — Report Completeness and Documentation Polish
**Created:** 2026-05-24
**Status:** Active

---

## Report Output (RPT)

- [x] **RPT-01**: Biologist can estimate angler trips (angler days) by calling `estimate_angler_trips()`, which computes effort ÷ mean trip length per stratum with Delta Method variance propagation (Powell 2007), returning a `creel_estimates` object.
- [ ] **RPT-02**: Biologist can compute effort density by calling `estimate_effort_per_acre(design, acres)`, which divides the extrapolated effort estimate by the supplied surface acreage and returns angler-hours per acre by stratum/month.
- [ ] **RPT-03**: Biologist can summarize boat composition by calling `summarize_boat_composition(design)`, which computes `c_AnglerBoats / (c_AnglerBoats + c_NonAngBoats)` from raw count data and returns % angler boats by month and day type.
- [ ] **RPT-04**: Biologist can tabulate interview origin by calling `summarize_by_zip(design)`, which returns count and % of interviews by zip code from the `ii_ZipCode` interview field.
- [ ] **RPT-05**: Biologist can tabulate interview origin by calling `summarize_by_county(design)`, which maps `ii_ZipCode` to county via `zipcodeR` (Suggests) and returns count and % of interviews by county.

## Documentation (DOC)

- [ ] **DOC-01**: pkgdown site rebuilt at v1.9.0 — site header shows correct package version (not stale "1.4.0"); version bump in DESCRIPTION committed and tagged.
- [ ] **DOC-02**: tidycreel.connect bridge article exists on the main `tidycreel` pkgdown site, explaining what the companion package does, how to install it, and linking to its documentation.
- [ ] **DOC-03**: `.github/ISSUE_TEMPLATE/` contains `bug_report.yml` (fields: description, reprex, R version, tidycreel version, survey type dropdown, expected vs actual) and `feature_request.yml` (fields: problem, proposed solution, use case, survey types affected).

## Tech Debt (TD)

- [ ] **TD-01**: `write_estimates()` xlsx export path has a passing test using `skip_if_not_installed("writexl")` pattern (WRITE-11 carry-forward from v1.8.0).

---

## Future Requirements (Deferred)

- **MR-F01**: Jolly-Seber open-population mark-recapture — output contract incompatible with `creel_estimates`; requires new S3 class.
- **CAMP-F01**: Multiple imputation via Rubin's rules — extends `impute_camera_counts()`.
- **STRAT-F01**: CPUE precision audit in `audit_strata(type = "cpue")`.
- **DOCS-F02**: Quarto guide/book for applied creel survey workflows (separate from pkgdown).
- **SIM-F01**: Nebraska-parameterized empirical creel data simulator.
- **QUAL-05**: rOpenSci formal submission — deferred to undetermined future date.
- **RPT-F01**: Supplemental questions summary — `summarize_supplemental()` for arbitrary question/answer pairs from API code tables.

## Out of Scope

- tidycreel.connect separate pkgdown site — bridge article (DOC-02) addresses discoverability; full separate site deferred until connect surface stabilizes.
- `summarize_by_county()` with bundled NE lookup or user-supplied crosswalk — using `zipcodeR` (DOC-01 decision).
- Count time generator — `generate_count_times()` was implemented in a prior milestone; the 2026-03-30 todo was stale and has been closed.

---

## Traceability

| REQ | Phase |
|-----|-------|
| RPT-01 | Phase 95 |
| RPT-02 | Phase 95 |
| RPT-03 | Phase 96 |
| RPT-04 | Phase 96 |
| RPT-05 | Phase 96 |
| DOC-01 | Phase 97 |
| DOC-02 | Phase 97 |
| DOC-03 | Phase 97 |
| TD-01  | Phase 97 |

---

*Last updated: 2026-05-24*
