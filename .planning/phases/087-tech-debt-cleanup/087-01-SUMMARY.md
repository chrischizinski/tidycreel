---
phase: 087-tech-debt-cleanup
plan: "01"
status: complete
completed: 2026-05-05
tests_before: 2661
tests_after: 2667
requirements: [AUDIT-CR01, AUDIT-CR02, AUDIT-W01, AUDIT-W02, AUDIT-W03, AUDIT-VERIF]
---

# Phase 87 Summary: v1.6.0 Tech Debt Cleanup

## What Was Done

Closed all 6 advisory items flagged in the v1.6.0 milestone audit.

### Task 1 — CR-02: Fixed "ZINB" documentation in impute_camera_counts()
- Removed "zero-inflated" from `@description`, `@param method`, and `rlang::check_installed()` reason string
- Implementation uses `glmmTMB::nbinom2` (plain NB GLMM) — docs now match
- Regenerated `man/impute_camera_counts.Rd`

### Task 2 — WARNING-01: Fixed variance_method mislabel in Petersen branch
- Changed `variance_method = "chapman"` to `variance_method = "petersen"` in Petersen branch of `estimate_angler_n()`

### Task 3 — WARNING-02: Guarded Schnabel ci_hi against lo_m = 0
- Added `cli::cli_warn()` when `lo_m == 0L` and explicit `ci_hi <- Inf` assignment
- Added Test X in `test-estimate-angler-n.R`: sum_m=1 input → warns + ci_hi=Inf

### Task 4 — WARNING-03: Added harvest_rate > 1 upper-bound test
- Added Test L in `test-estimate-mr-harvest.R`: harvest_rate=1.1 → error

### Task 5 — CR-01: Fixed .imputed false-positive logic
- Pre-imputation NA baseline (`.was_outage` temp column) captured before per-stratum loop
- `.imputed` now correctly marks only rows that were NA before and non-NA after
- Added CR-01 test in `test-impute-camera-counts.R`: non-operational row with pre-existing count → .imputed=FALSE

### Task 6 — AUDIT-VERIF: Generated Phase 86 VERIFICATION.md
- Retroactive VERIFICATION.md created from UAT + commit + test evidence
- Status: passed, 8/8 truths verified, STRAT-01..05 all satisfied

### Task 7 — Quality Gate
- `devtools::check()`: 0 errors, 0 warnings, 1 pre-existing NOTE (.codecov.yml, .env)
- Test count: 2667 (up from 2661; +6 new tests)

## Files Changed

- `R/impute-camera-counts.R` — CR-02 doc fix + CR-01 .imputed logic fix
- `R/creel-estimates-mark-recapture.R` — WARNING-01 mislabel + WARNING-02 ci_hi guard
- `man/impute_camera_counts.Rd` — regenerated
- `tests/testthat/test-estimate-angler-n.R` — Test X added
- `tests/testthat/test-estimate-mr-harvest.R` — Test L added
- `tests/testthat/test-impute-camera-counts.R` — CR-01 test added
- `.planning/phases/086-stratification-audit/086-VERIFICATION.md` — created
