# Phase 79: Property-Based Testing and Coverage Gate - Context

**Gathered:** 2026-04-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Write quickcheck property-based tests for domain invariants INV-04, INV-01, INV-02, INV-06, and INV-03 (in that priority order; INV-05 is manual-review only and is NOT automated). Run `covr::package_coverage()` to confirm the ~87% coverage baseline, configure a `test-coverage.yaml` CI workflow that uploads results to codecov.io, and enforce an 85% threshold via `.codecov.yml`. Add a codecov badge to README. No behaviour changes to package code.

</domain>

<decisions>
## Implementation Decisions

### Test file organization
- One file: `tests/testthat/test-invariants.R` — all 5 invariants in a single dedicated file
- Matches the Phase 78 pattern (`test-snapshots.R` for all snapshot tests)
- `library(quickcheck)` at the top of the file — standard testthat convention, matches INV spec sketches
- Tests run on every CI check — no `skip_on_ci()`, no iteration reduction; quickcheck default (100) is fast enough

### Generator design
- Shared generators extracted to `tests/testthat/helper-generators.R`
- testthat auto-loads `helper-*.R` files — no `source()` needed; consistent with existing `helper-db.R`
- Build fresh `gen_*` functions designed for quickcheck's API — do NOT source or copy from `inst/profiling/`
- The INV spec generator sketches serve as design inspiration, not copy-paste source
- All design-construction helpers for INV-03 (`build_ice_design()`, `build_br_degenerate_design()`) also go in `helper-generators.R` — consistent placement, keeps `test-invariants.R` clean

### codecov integration
- Use codecov.io service: add `.codecov.yml` to repo root with `coverage_threshold: 85`
- Add a separate `test-coverage.yaml` GitHub Actions workflow (r-lib/actions standard pattern)
- Do NOT add a covr step to the existing `R-CMD-check.yaml` — keep check job focused; coverage runs independently
- Threshold: **85%** (2 percentage points below confirmed ~87% baseline — headroom for noise, blocks large regressions)

### Coverage baseline recording
- Record confirmed baseline as a comment in `test-coverage.yaml`: `# Coverage baseline confirmed 2026-04-21: 87.X%`
- Add codecov badge to `README.md` and `README.Rmd` alongside the existing R-CMD-check badge

### Claude's Discretion
- Exact generator parameter ranges (n_min, n_sites, n_species values)
- Exact floating-point tolerance values for INV-03 and INV-06 (1e-6 from spec is a reasonable starting point)
- `.codecov.yml` patch vs project coverage settings (project threshold is the priority)
- `test-coverage.yaml` trigger branches (main + PRs is standard)
- Whether to add `quickcheck` to DESCRIPTION Suggests during this phase

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/testthat/helper-db.R` — establishes the `helper-*.R` auto-loading pattern; `helper-generators.R` follows this convention
- `inst/profiling/00-generate-fixtures.R` — contains `build_br_design()` parameterized by n_sites/n_days/n_species/n_interviews; serves as design reference for fresh generator implementations
- `.github/workflows/R-CMD-check.yaml` — existing CI workflow to leave untouched; new `test-coverage.yaml` is a sibling file
- `tests/testthat/test-snapshots.R` — established the one-file-per-concern PBT pattern in Phase 78

### Established Patterns
- testthat `helper-*.R` auto-loading: all files matching `helper-*.R` in `tests/testthat/` are sourced before any test runs — no explicit `source()` needed
- `covr` is already in DESCRIPTION (Suggests); no new entry needed for covr itself
- `quickcheck` is NOT yet in DESCRIPTION — needs to be added to Suggests as part of this phase

### Integration Points
- `tests/testthat/test-invariants.R` — new file; sits alongside existing test files
- `tests/testthat/helper-generators.R` — new helper; auto-loaded by testthat
- `.github/workflows/test-coverage.yaml` — new workflow; sibling to `R-CMD-check.yaml`
- `.codecov.yml` — new file at repo root
- `README.md` + `README.Rmd` — badge addition only, no content changes

</code_context>

<specifics>
## Specific Ideas

- The INV spec in `.planning/milestones/M022-phases/75-performance-optimization/75-TESTING-INVARIANTS.md` contains generator sketches for all 6 invariants — use as the authoritative design reference for `helper-generators.R`
- Priority implementation order is locked: INV-04 → INV-01 → INV-02 → INV-06 → INV-03 (from REQUIREMENTS.md TEST-01)
- INV-03 is the most complex: requires both `build_ice_design()` and `build_br_degenerate_design()` helpers plus the `intersect()` guard pattern for synthetic ice columns (Phase 70-01 contract)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 79-property-based-testing-and-coverage-gate*
*Context gathered: 2026-04-21*
