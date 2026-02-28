# Phase 26: Primary Source Validation - Context

**Gathered:** 2026-02-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Write validation tests that prove tidycreel correctly reproduces published results from
Malvestuto (1996) Box 20.6 — the canonical primary source for bus-route creel survey estimation.
Tests cover: Box 20.6 Example 1 (no expansion), Box 20.6 Example 2 (enumeration expansion),
integration tests for the complete workflow (design → data → estimation), and cross-validation
against manual `survey` package calculations.

This phase writes tests, not new features. The implementation was delivered in Phases 22–25.

</domain>

<decisions>
## Implementation Decisions

### Test data encoding
- Inline data frames inside the test file — no shared fixture files, no package dataset
- Build test objects via `creel_design()` + `add_interviews()` — validates the full data
  pipeline, not just the estimator math
- Separate helpers for Example 1 (`make_box20_6_example1()`) and Example 2
  (`make_box20_6_example2()`) — maps 1:1 to distinct published examples
- Per-test citation comments citing the exact page (e.g., `# Malvestuto 1996, Box 20.6, p. 614`)

### Published source coverage
- Malvestuto (1996) Box 20.6 only — Malvestuto 1978 Table 1 deferred (CVs, not exact values)
- Integration test uses Box 20.6 data — no separate synthetic dataset needed
- No additional Jones & Pollock validation — Phase 25 already covers Eq. 19.5 golden test
- Include effort validation alongside harvest/catch — Box 20.6 covers effort and the
  Malvestuto citation strengthens the effort estimator's traceability

### Test file organization
- New dedicated file: `tests/testthat/test-primary-source-validation.R`
- Placed in standard `tests/testthat/` — picked up automatically by `devtools::test()`
- Sections organized by example: `# Malvestuto Box 20.6 Example 1 ----`,
  `# Malvestuto Box 20.6 Example 2 (enumeration expansion) ----`, `# Integration ----`
- Separate `test_that()` blocks per estimator for effort and harvest — clear failure messages

### Survey package cross-validation
- Compare both point estimates AND SE against a manually-constructed `survey::svydesign()` +
  `survey::svytotal()` call — proves the variance machinery is wired correctly
- Tolerance: `1e-6` for point estimates, `1e-3` for SE (SE may differ slightly due to
  finite-population correction differences)
- Cross-validation tests in `test-primary-source-validation.R` (not a separate file)
- Cover both effort and harvest in cross-validation

### Claude's Discretion
- Exact data values for Example 2 (enumeration expansion ratios, which sites have
  n_counted > n_interviewed)
- Whether to add a section header/comment block summarizing the PRIMARY_SOURCE_ANALYSIS
  findings at the top of the test file
- lintr-compliant comment style for citations

</decisions>

<specifics>
## Specific Ideas

- Box 20.6 Example 1 key value: Site C: 57.5 / 0.20 = **287.5** angler-hours (VALID-01)
- Box 20.6 Example 2 adds enumeration expansion: 24 counted / 11 interviewed at Site C
  (expansion = 24/11 ≈ 2.182) — VALID-02
- The `# Malvestuto 1996, Box 20.6, p. 614` citation style used in every golden-test
  comment (same style as `# Jones & Pollock 2012, Eq. 19.5, p. 912` in Phase 25 tests)
- The file name `test-primary-source-validation.R` should make it obvious to any reader
  that these are correctness proofs against published literature, not behavioral tests

</specifics>

<deferred>
## Deferred Ideas

- Malvestuto et al. (1978) Table 1 validation (monthly West Point Reservoir estimates
  with CVs) — deferred, not exact-value reproducible in the same way as Box 20.6

</deferred>

---

*Phase: 26-primary-source-validation*
*Context gathered: 2026-02-24*
