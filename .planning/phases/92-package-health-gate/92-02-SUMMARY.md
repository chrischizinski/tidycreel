---
phase: "92-package-health-gate"
plan: "02"
subsystem: tidycreel.connect
tags: [vignette, description, knitr, rmarkdown, smoke-test, qual-02]
dependency_graph:
  requires: []
  provides: [QUAL-02-part1, VignetteBuilder-fix, vignette-smoke-test]
  affects: [tidycreel.connect]
tech_stack:
  added: []
  patterns: [knitr-vignette-smoke-test, rmarkdown-render-expect_no_error]
key_files:
  created:
    - tidycreel.connect/tests/testthat/test-vignette-render.R
  modified:
    - tidycreel.connect/DESCRIPTION
    - tidycreel.connect/vignettes/getting-started.Rmd
decisions:
  - "Used bank_anglers_col in vignette schema/CSV to match Phase 91 counts schema refactor"
  - "Smoke test uses normalizePath fallback to locate vignette from source tree (dev context)"
metrics:
  duration: "~10 min"
  completed: "2026-05-17"
  tasks_completed: 3
  files_modified: 3
---

# Phase 92 Plan 02: VignetteBuilder Fix and Vignette Smoke Test Summary

**One-liner:** Added `VignetteBuilder: knitr`, `knitr`/`rmarkdown` Suggests, fixed Phase 91-broken counts chunk in vignette, and added `rmarkdown::render()` smoke test.

## What Was Done

**Task 1 — DESCRIPTION update (D-05, D-06):**
Added `knitr` and `rmarkdown` to the `Suggests` block in alphabetical order (after `duckdb`, before `odbc`) and added `VignetteBuilder: knitr` as a new field after `Suggests` and before `Config/testthat/edition: 3`. No other DESCRIPTION fields changed.

**Task 2 — Vignette content pass (D-07):**
Running `knitr::knit()` on the vignette before any edits revealed a failure in the `fetch` chunk: `fetch_counts()` validation failed because the toy counts CSV used the column name `AnglerCount` (via `count_col`), but Phase 91 refactored `fetch_counts.creel_connection_csv` to use `bank_anglers_col` exclusively. The fix was minimal:
- Changed `count_col = "AnglerCount"` to `bank_anglers_col = "BankAnglers"` in the `schema` eval=TRUE chunk.
- Changed the toy counts CSV `data.frame` to use `BankAnglers = 12L` instead of `AnglerCount = 12L`.
- All eval=FALSE chunks were left unchanged. No prose was rewritten.

After the fix, `knitr::knit()` exits 0.

**Task 3 — Vignette smoke test (D-12):**
Created `tidycreel.connect/tests/testthat/test-vignette-render.R` with one `test_that` block. The test:
- Skips if `knitr` or `rmarkdown` not installed.
- Locates the vignette via `normalizePath` relative to `testthat::test_path()`.
- Calls `rmarkdown::render()` with `output_format = "rmarkdown::html_vignette"`, `envir = new.env()`, `quiet = TRUE`.
- Asserts `expect_no_error(...)`.
- Cleans up the rendered output via `on.exit(unlink(out_file), add = TRUE)`.

## Test Results

```
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]   (filter = "vignette-render")
[ FAIL 0 | WARN 0 | SKIP 10 | PASS 154 ] (full tidycreel.connect suite)
```

The 10 skips are pre-existing: `odbc`, `config`, `duckdb` not installed in the test environment.

## Commits

- `5659394`: `feat(92-02): add VignetteBuilder + knitr/rmarkdown Suggests, fix vignette, add smoke test`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Phase 91 schema breakage in vignette eval=TRUE counts chunk**
- **Found during:** Task 2 (vignette knit verification)
- **Issue:** `fetch_counts()` was refactored in Phase 91 to use `bank_anglers_col` instead of `count_col`. The vignette's toy CSV and schema still used the old `count_col = "AnglerCount"` / `AnglerCount = 12L` pattern, causing a validation failure.
- **Fix:** Changed `count_col` to `bank_anglers_col` in the schema chunk and updated the toy CSV column name to `BankAnglers`. Minimum edit — no prose or eval=FALSE chunks touched.
- **Files modified:** `tidycreel.connect/vignettes/getting-started.Rmd`
- **Commit:** `5659394`

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED
