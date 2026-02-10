# Requirements: Legacy Constructor Removal

**Defined:** 2026-01-27
**Core Value:** Clean API with no legacy baggage - only new `est_*()` functions exposed to users

## v1 Requirements

Requirements for completing the legacy constructor removal work.

### Code Removal

- [ ] **REM-01**: Remove `@export` tags from deprecated functions in `R/estimators.R`
- [ ] **REM-02**: Regenerate NAMESPACE via `devtools::document()` to remove deprecated exports
- [ ] **REM-03**: Delete deprecated function definitions from `R/estimators.R` (`estimate_effort()`, `estimate_cpue()`, `estimate_harvest()`)
- [ ] **REM-04**: Delete `old_code/` directory containing archived legacy files (~187KB)
- [ ] **REM-05**: Remove helper function `create_survey_design()` if unused by current API

### Pre-Removal Verification

- [ ] **VER-01**: Search for references to deprecated functions in `tests/` directory
- [ ] **VER-02**: Search for references to deprecated functions in `vignettes/` directory
- [ ] **VER-03**: Search for references to `old_code/` in documentation
- [ ] **VER-04**: Establish baseline test coverage with `covr::package_coverage()`

### Post-Removal Verification

- [ ] **VER-05**: Run `devtools::check()` (R CMD check) with no errors or warnings
- [ ] **VER-06**: Run full test suite with `devtools::test()` - all tests pass
- [ ] **VER-07**: Build vignettes successfully with no errors
- [ ] **VER-08**: Verify test coverage maintained or improved

### Documentation

- [ ] **DOC-01**: Update NEWS.md with removal notice for deprecated functions
- [ ] **DOC-02**: Verify README.md uses only current API (`est_*` functions)
- [ ] **DOC-03**: Verify vignettes use only current API
- [ ] **DOC-04**: Check for orphaned .Rd files in `man/` directory

## Out of Scope

Explicitly excluded from this work.

| Feature | Reason |
|---------|--------|
| Deprecation warnings or lifecycle badges | Package never released - no users to migrate |
| Migration vignette | Comprehensive getting-started vignettes already exist with current API |
| Addressing other technical debt (variance complexity, zero-effort handling) | Separate work to tackle in future |
| Adding new features or estimation methods | Separate work to tackle in future |
| Version bump to 1.0.0 | Separate decision after this work merges |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REM-01 | Pending | Pending |
| REM-02 | Pending | Pending |
| REM-03 | Pending | Pending |
| REM-04 | Pending | Pending |
| REM-05 | Pending | Pending |
| VER-01 | Pending | Pending |
| VER-02 | Pending | Pending |
| VER-03 | Pending | Pending |
| VER-04 | Pending | Pending |
| VER-05 | Pending | Pending |
| VER-06 | Pending | Pending |
| VER-07 | Pending | Pending |
| VER-08 | Pending | Pending |
| DOC-01 | Pending | Pending |
| DOC-02 | Pending | Pending |
| DOC-03 | Pending | Pending |
| DOC-04 | Pending | Pending |

**Coverage:**
- v1 requirements: 17 total
- Mapped to phases: 0 (pending roadmap creation)
- Unmapped: 17 ⚠️

---
*Requirements defined: 2026-01-27*
*Last updated: 2026-01-27 after initial definition*
