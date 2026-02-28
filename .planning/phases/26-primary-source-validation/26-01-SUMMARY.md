---
phase: 26-primary-source-validation
plan: 01
subsystem: testing
tags: [testthat, bus-route, Malvestuto, Horvitz-Thompson, jones-pollock, validation]

# Dependency graph
requires:
  - phase: 24-01
    provides: estimate_effort_br(), site_contributions attribute with e_i/pi_i/e_i_over_pi_i columns
  - phase: 23-02
    provides: get_enumeration_counts() accessor, .expansion column in interview data
  - phase: 22-01
    provides: get_inclusion_probs(), pi_i = p_site * p_period calculation
provides:
  - Box 20.6 Example 1 primary source validation (VALID-01): Site C = 287.5, E_hat = 847.5
  - Box 20.6 Example 2 enumeration expansion validation (VALID-02): E_hat increases with expansion
  - make_box20_6_example1() helper: 4-site bus-route design, no expansion, E_hat = 847.5
  - make_box20_6_example2() helper: same design with Site C expansion 24/11
  - 14 new correctness-proof tests in test-primary-source-validation.R
affects:
  - phase-26-02-integration (uses same helper pattern for integration tests)
  - phase-27-documentation (cite VALID-01/VALID-02 passing as correctness proof)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Section-scope test helpers (make_box20_6_example1/2) per Phase 21-02 / 22-02 convention
    - Correctness proof tests: hand-computed golden values verified to tolerance 1e-6
    - site_contributions attribute accessed via attr(result, "site_contributions") for row-level audit
    - Citation comments on golden-value assertions: # Malvestuto 1996, Box 20.6, p. 614
    - 15 interview rows spread across 4 dates (4A + 3B + 6C + 2D = 15) satisfying PSU requirement

key-files:
  created:
    - tests/testthat/test-primary-source-validation.R
  modified: []

key-decisions:
  - "Site D requires 2 interview rows (not 1) to represent n_interviewed=2; each row contributes e_i=2.5*1/0.025=100, sum=200"
  - "method='total' is the correct value for bus-route effort estimates (not 'horvitz' or 'bus-route')"
  - "e_i_over_pi_i is the column name in site_contributions for effort (not 'ratio')"
  - "15 rows total (4+3+6+2) satisfy >= 2 PSU per stratum for survey::svydesign() variance"

patterns-established:
  - "Primary source validation: use helper functions named make_box20_6_exampleN() at section scope"
  - "Golden arithmetic: verify both individual site contributions AND total E_hat to 1e-6"
  - "Enumeration expansion verified via get_enumeration_counts() .expansion column, not via estimate"

requirements-completed: [VALID-01, VALID-02]

# Metrics
duration: 9min
completed: 2026-02-25
---

# Phase 26 Plan 01: Malvestuto Box 20.6 Primary Source Validation Summary

**Correctness proofs verifying tidycreel exactly reproduces Malvestuto (1996) Box 20.6 canonical
bus-route benchmarks: Site C = 287.5 angler-hours (VALID-01) and enumeration expansion increases
E_hat (VALID-02), both validated to 1e-6 tolerance**

## Performance

- **Duration:** 9 min
- **Started:** 2026-02-25T19:23:50Z
- **Completed:** 2026-02-25T19:32:26Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created test-primary-source-validation.R with 14 correctness-proof tests (FAIL 0)
- VALID-01: Site C contribution = 57.5/0.20 = 287.5 verified to tolerance 1e-6
- VALID-01: E_hat = 847.5 (200+160+287.5+200) verified exactly against hand-computed value
- VALID-02: E_hat(Example 2) > E_hat(Example 1) proved via expect_gt()
- VALID-02: Site C expansion 24/11 verified in get_enumeration_counts()
- VALID-02: Site C contribution with expansion = (57.5 * 24/11) / 0.20 verified to 1e-6
- Full test suite grows from 1066 to 1080 tests, FAIL = 0, lintr 0 issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Malvestuto Box 20.6 primary source validation tests** - `4a0d5c0` (test)

**Plan metadata:** (final commit, see below)

## Files Created/Modified
- `tests/testthat/test-primary-source-validation.R` - Box 20.6 Example 1 and Example 2 sections
  (328 lines: 2 section-scope helpers + 9 Example 1 tests + 5 Example 2 tests)

## Decisions Made
- Site D requires 2 interview rows (one per interviewed angler) to correctly represent
  n_interviewed=2; each contributes 2.5*1/0.025=100 to total, summing to 200
- method="total" is the correct field value for bus-route effort estimates (implementation
  uses new_creel_estimates(method="total")), not "horvitz" or "bus.route" as plan suggested
- site_contributions column is "e_i_over_pi_i" (not "ratio") per Phase 24-01 implementation
- 15 interview rows total (4A+3B+6C+2D) spread across 4 calendar dates satisfies >= 2 PSUs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Site D interview count (1 row vs 2 rows required)**
- **Found during:** Task 1 (TDD Green phase — test E_hat=847.5 failed with actual=747.5)
- **Issue:** Initial data had only 1 interview row for Site D (2.5 hours), giving contribution
  of 100 instead of 200; Site D n_interviewed=2 requires 2 rows (n_interviewed=2 anglers)
- **Fix:** Added second Site D row (date="2024-06-03", hours_fished=2.5, n_counted=2,
  n_interviewed=2) to reach correct total effort 5.0 and contribution 200
- **Files modified:** tests/testthat/test-primary-source-validation.R
- **Verification:** FAIL 0, E_hat = 847.5 to 1e-6
- **Committed in:** 4a0d5c0 (Task 1 commit)

**2. [Rule 1 - Bug] Corrected test assertions to match actual implementation column names**
- **Found during:** Task 1 (plan specified "ratio" column, actual is "e_i_over_pi_i")
- **Issue:** Plan's implementation spec referenced sc$ratio and method "bus.route|horvitz|ht";
  actual implementation uses e_i_over_pi_i and method="total" per Phase 24-01 decisions
- **Fix:** Tests use correct column name (e_i_over_pi_i) and check method="total"
- **Files modified:** tests/testthat/test-primary-source-validation.R
- **Verification:** FAIL 0, lintr 0 issues
- **Committed in:** 4a0d5c0 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs)
**Impact on plan:** Both fixes necessary for tests to pass; golden arithmetic preserved;
no scope creep.

## Issues Encountered
- testthat not installed globally; installed to site-library to enable test execution
- First run showed E_hat=747.5 instead of 847.5 due to missing Site D row (fixed inline)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 26 Plan 01 complete: primary source validation tests established
- VALID-01 and VALID-02 requirements satisfied with correctness proofs
- Phase 26 Plan 02 (integration testing) can proceed
- site_contributions attribute and get_enumeration_counts() accessor verified via tests
- make_box20_6_example1()/make_box20_6_example2() helpers available for Phase 26 Plan 02

## Self-Check: PASSED

- FOUND: tests/testthat/test-primary-source-validation.R
- FOUND: .planning/phases/26-primary-source-validation/26-01-SUMMARY.md
- FOUND: commit 4a0d5c0 (Task 1)

---
*Phase: 26-primary-source-validation*
*Completed: 2026-02-25*
