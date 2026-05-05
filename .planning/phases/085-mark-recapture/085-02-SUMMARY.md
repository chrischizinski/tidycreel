---
phase: 085-mark-recapture
plan: "02"
status: complete
completed: 2026-05-05
subsystem: estimation
tags: [mark-recapture, testing, testthat, quality-gate]
dependency_graph:
  requires: [085-01]
  provides: [MR-01, MR-02, MR-03, MR-04, MR-05, MR-06]
  affects: []
tech_stack:
  added: []
  patterns: [testthat-letter-labels, preamble-reference-values, expect_equal-tolerance-1e-10]
key_files:
  created:
    - tests/testthat/test-estimate-angler-n.R
    - tests/testthat/test-estimate-mr-harvest.R
  modified:
    - R/creel-estimates-mark-recapture.R
decisions:
  - Schnabel M guard moved inside method branch so M[1]=0 is permitted (first occasion always has 0 marked-at-large)
metrics:
  duration: 20m 23s
  completed: 2026-05-05
  tasks: 2
  files_created: 2
  files_modified: 1
---

# Phase 85 Plan 02: Mark-Recapture Tests Summary

## One-Liner

23-test estimate-angler-n suite (MR-01..MR-05) + 11-test estimate-mr-harvest suite (MR-06) with devtools::check() 0 errors 0 warnings.

## What Was Built

- **`tests/testthat/test-estimate-angler-n.R`** — 23 test_that blocks (Tests A–W) covering all Chapman, Petersen, and Schnabel behaviors plus MR-04 guard tests and MR-05 S3 smoke tests. 30 individual assertions, all passing.
- **`tests/testthat/test-estimate-mr-harvest.R`** — 11 test_that blocks (Tests A–K) covering MR-06 delta-method harvest, guard tests, and smoke test. 13 individual assertions, all passing.
- **Implementation fix in `R/creel-estimates-mark-recapture.R`** — moved M>0 guard inside the non-Schnabel branch so M[1]=0 is permitted for Schnabel (first occasion has 0 marked-at-large by definition). The length mismatch and K<2 guards now fire before any per-element value checks for Schnabel.

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: estimate-angler-n tests + implementation fix | 0e68a07 | tests/testthat/test-estimate-angler-n.R, R/creel-estimates-mark-recapture.R |
| Task 2: estimate-mr-harvest tests + quality gate | 729596f | tests/testthat/test-estimate-mr-harvest.R |

## Requirements Coverage

| Req ID | Tests | Status |
|--------|-------|--------|
| MR-01 | Tests A, B, C, D, E, F | PASS |
| MR-02 | Tests G, H, I, J | PASS |
| MR-03 | Tests K, L, M, N, O | PASS |
| MR-04 | Tests P, Q, R, S, T | PASS |
| MR-05 | Tests U, V, W | PASS |
| MR-06 | Tests A–K (harvest file) | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed M guard to permit Schnabel M[1]=0**
- **Found during:** Task 1 — Tests S (unequal lengths) and T (K<2) both failed because `any(M <= 0)` fired before the Schnabel-specific guards
- **Issue:** Wave 1 implementation placed `if (any(M <= 0)) cli_abort(...)` as a shared guard before the method branch. For Schnabel, M[1] is always 0 (no fish marked before the first sampling occasion). This is domain-correct behavior documented in D-02 as documentation-only (not enforced), but the guard violated it implicitly.
- **Fix:** Moved M validation inside the method branches: for non-Schnabel methods, `if (M <= 0) cli_abort(...)`; for Schnabel, `if (any(M < 0)) cli_abort(...)` (allows M[1]=0). The Schnabel length/K guards now run before any per-element value checks so they produce the correct error messages.
- **Files modified:** `R/creel-estimates-mark-recapture.R`
- **Commit:** 0e68a07

## Quality Gate

- `devtools::check(args=c("--no-manual","--as-cran"), error_on="warning")`: **0 errors | 0 warnings | 2 notes**
- Notes are pre-existing (.codecov.yml, .env hidden files; kairo.db top-level file) — not introduced by this phase.
- Total test count after this phase: 2601 tests (2578 + 23 new in estimate-angler-n file = 2601; note testthat counts individual assertions, not test_that blocks).

## Known Stubs

None. All test assertions use deterministic formula computations against the live implementation.

## Self-Check: PASSED

- `tests/testthat/test-estimate-angler-n.R` exists and has 23 test_that blocks (>= 20 required)
- `tests/testthat/test-estimate-mr-harvest.R` exists and has 11 test_that blocks (>= 10 required)
- `grep "N_hat_c"` present: Yes (Test A, B)
- `grep "N_hat_p"` present: Yes (Test G)
- `grep "N_hat_s"` present: Yes (Test K, L)
- `grep "too small for the Petersen"` present: Yes (Test H)
- `grep "same length"` present: Yes (Test S)
- `grep "Schnabel requires"` present: Yes (Test T)
- `grep "compare_designs"` present: Yes (Test U)
- `grep "autoplot"` present: Yes (Test V)
- `grep "expect_named.*parameter.*estimate.*se.*ci_lower.*ci_upper.*n"` present: Yes (Test F)
- `grep "expect_named.*parameter.*estimate.*se.*ci_lower.*ci_upper"` present: Yes (Test G harvest)
- `grep "creel_estimates"` present in harvest test: Yes (Test H, I)
- `grep "mark-recapture-harvest"` present: Yes (Test E)
- `devtools::test(filter='estimate-angler-n')`: PASS (0 failures, 0 errors)
- `devtools::test(filter='estimate-mr-harvest')`: PASS (0 failures, 0 errors)
- `devtools::check(error_on='warning')`: 0 errors | 0 warnings
- Commits 0e68a07 and 729596f exist in git log
