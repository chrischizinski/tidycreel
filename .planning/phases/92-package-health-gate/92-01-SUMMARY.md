---
phase: "92-package-health-gate"
plan: "01"
subsystem: validation
tags: [guard, validation, QUAL-01, base-R]
dependency_graph:
  requires: []
  provides: [QUAL-01-guard]
  affects: [inst/validation/calamus-2016-validation.R]
tech_stack:
  added: []
  patterns: [base-R WD guard, withr::with_dir test isolation]
key_files:
  created:
    - tests/testthat/test-validation-guard.R
  modified:
    - inst/validation/calamus-2016-validation.R
decisions:
  - "Use dirname(system.file(package='tidycreel')) to resolve package root in tests because devtools::load_all() sets system.file to inst/"
  - "Block 2 guard test uses tryCatch + grepl rather than expect_error(invert=TRUE) — invert is not a real testthat parameter"
  - "succeed() branch handles the case where the script runs to completion without error"
metrics:
  duration: "8 minutes"
  completed: "2026-05-17"
  tasks_completed: 2
  files_changed: 2
---

# Phase 92 Plan 01: WD Guard for Calamus 2016 Validation Script Summary

Working-directory guard added to `inst/validation/calamus-2016-validation.R` (QUAL-01) with two passing testthat tests confirming the guard fires from wrong directories and passes silently from the package root.

## What Was Done

**Task 1 — Add WD guard to calamus-2016-validation.R**

The existing header comment's soft note ("Assume working directory is package root") was replaced with a hard MUST requirement. A `file.exists("DESCRIPTION")` guard block was inserted as the first executable statement — before `suppressPackageStartupMessages()`. The guard uses only base-R and calls `stop()` with a message containing "DESCRIPTION" so tests and humans can identify it unambiguously.

**Task 2 — Create test-validation-guard.R**

Two `test_that` blocks:

1. Sources the script from `tempdir()` (no DESCRIPTION) via `withr::with_dir()` — `expect_error(..., "DESCRIPTION")` confirms the guard fires.
2. Sources the script from the actual package root via `withr::with_dir()` — `tryCatch` captures any error and asserts its message does NOT match "DESCRIPTION". In practice, the full validation ran to completion (PASS) confirming the guard is transparent when conditions are correct.

## Files Changed

| File | Change |
|------|--------|
| `inst/validation/calamus-2016-validation.R` | Header comment hardened; `if (!file.exists("DESCRIPTION")) stop(...)` added before `suppressPackageStartupMessages()` |
| `tests/testthat/test-validation-guard.R` | New file; 2 tests |

## Test Results

```
devtools::test(filter='validation-guard')
[ FAIL 0 | WARN 2 | SKIP 0 | PASS 2 ]
```

The 2 warnings are from the validation script itself (no `weights` supplied for svydesign, zero-catch interviews) — not test failures. These are pre-existing conditions in the fixture data.

Full suite: `[ FAIL 0 | WARN 534 | SKIP 5 | PASS 2670 ]` (was 2668 + 2 new).

## Deviations from Plan

**1. [Rule 1 - Bug] `expect_error(invert=TRUE)` is not a valid testthat parameter**

- **Found during:** Task 2 implementation
- **Issue:** The plan spec referenced `expect_error(..., "DESCRIPTION", invert = TRUE)` but `testthat::expect_error()` has no `invert` argument (signature: `regexp, class, ..., inherit, info, label`).
- **Fix:** Used `tryCatch` + `grepl` + `expect_false` pattern for Block 2, with a `succeed()` branch for the no-error case.
- **Files modified:** `tests/testthat/test-validation-guard.R`

**2. [Rule 1 - Bug] `system.file(package="tidycreel")` returns `inst/` under devtools::load_all()**

- **Found during:** Task 2 first test run
- **Issue:** Block 2 resolved package root as `system.file(package="tidycreel")` — which returns `inst/` when the package is loaded via `load_all()`, not the actual project root.
- **Fix:** Used `dirname(system.file(package="tidycreel"))` to navigate one level up to the true package root containing DESCRIPTION.
- **Files modified:** `tests/testthat/test-validation-guard.R`

## Commits

| Hash | Message |
|------|---------|
| 409f4f8 | feat(92-01): add WD guard to calamus-2016-validation.R (QUAL-01) |

## Self-Check: PASSED

- `inst/validation/calamus-2016-validation.R` — file exists and contains guard
- `tests/testthat/test-validation-guard.R` — file exists with 2 test_that blocks
- Commit 409f4f8 — confirmed in git log
- 2670 tests passing, 0 failures
