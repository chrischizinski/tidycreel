---
phase: 97
plan: "01"
subsystem: documentation
tags: [vignette, issue-template, test, tidycreel.connect, xlsx]
dependency_graph:
  requires: []
  provides: [DOC-02, DOC-03, TD-01]
  affects: [vignettes/tidycreel-connect.Rmd, .github/ISSUE_TEMPLATE/bug-report.yml, tests/testthat/test-write-estimates.R]
tech_stack:
  added: []
  patterns: [skip_if_not_installed guard, YAML field insertion]
key_files:
  modified:
    - vignettes/tidycreel-connect.Rmd
    - .github/ISSUE_TEMPLATE/bug-report.yml
    - tests/testthat/test-write-estimates.R
decisions:
  - "Used actual NAMESPACE exports from local tidycreel.connect clone to verify function names — GitHub repo is private"
  - "Vignette function inventory completely replaced: tc_connect/tc_validate API removed; creel_connect/fetch_* API documented"
  - "r_version grep count is 1 (not 2) because label uses 'R version' not 'r_version'; YAML validates cleanly and field order is correct"
metrics:
  duration_minutes: 15
  completed_date: "2026-05-25"
  tasks_completed: 3
  tasks_total: 3
---

# Phase 97 Plan 01: Documentation Polish and Tech Debt Summary

**One-liner:** Updated connect vignette with real API exports and install block, added r_version to bug report template, and added WRITE-11 xlsx round-trip test.

## Status

- Plan ID: 97-01
- Status: complete
- Tasks completed: 3/3
- Requirements closed: DOC-02, DOC-03, TD-01

## Key Changes

- **vignettes/tidycreel-connect.Rmd**: Added `## Installation` section with `remotes::install_github()` and `pak::pak()` immediately after "What is tidycreel.connect?". Removed all stale availability language ("not yet on CRAN", "not yet publicly available", "How to stay notified" section). Replaced the entire function inventory (which listed non-existent tc_* functions) with actual exported functions verified against the local NAMESPACE: `creel_connect`, `creel_connect_api`, `creel_connect_from_yaml`, `creel_check_driver`, `fetch_counts`, `fetch_interviews`, `fetch_catch`, `fetch_harvest_lengths`, `fetch_release_lengths`, `list_creels`, `search_creels`. Added CSV back-end usage example.

- **.github/ISSUE_TEMPLATE/bug-report.yml**: Inserted `r_version` input field (type: input, required: true) at position 3 — after `tidycreel_version`, before `expected`. Field order verified: survey_type → tidycreel_version → r_version → expected → actual → reprex → session_info → extra. YAML pre-commit hook passed.

- **tests/testthat/test-write-estimates.R**: Appended WRITE-11 test block. Guards with `skip_if_not_installed("writexl")` and `skip_if_not_installed("readxl")`. Uses `.make_eff()` helper, writes to `.xlsx` tempfile, asserts `file.exists(tmp)`, `expect_no_error(readxl::read_xlsx(tmp))`, and `nrow(readxl::read_xlsx(tmp)) == nrow(tidy(estimates))`.

## Verification Results

| Check | Command | Result |
|-------|---------|--------|
| Stale language removed | `grep -c "not yet on CRAN\|not yet publicly available..."` | 0 |
| install_github present | `grep -c "install_github\|pak::pak"` | 2 |
| Installation header | `grep -c "^## Installation"` | 1 |
| YAML field order | python3 regex id extraction | `['survey_type', 'tidycreel_version', 'r_version', 'expected', 'actual', 'reprex', 'session_info', 'extra']` |
| r_version in YAML | `grep -c "r_version"` | 1 (id field) |
| YAML validity | pre-commit check yaml hook | Passed |
| WRITE-11 exists | `grep -c "WRITE-11"` | 1 |
| Test suite | `devtools::test(filter='write-estimates')` | FAIL 0 / WARN 0 / SKIP 1 / PASS 17 |

Note on WRITE-11 skip: `writexl` is not installed in this environment, so WRITE-11 skips cleanly. WRITE-01 through WRITE-10 all pass.

## Commit Hashes

| Task | Commit | Message |
|------|--------|---------|
| Task 1 — DOC-02 | 8a5fe54 | feat(97-01): update tidycreel.connect vignette — install block + stale language removed (DOC-02) |
| Task 2 — DOC-03 | 0980dbb | feat(97-01): add r_version field to bug-report issue template (DOC-03) |
| Task 3 — TD-01 | 2e5bdcb | feat(97-01): add WRITE-11 xlsx round-trip test to test-write-estimates.R (TD-01) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Vignette function inventory replaced with actual exports**
- **Found during:** Task 1 — browsing local tidycreel.connect NAMESPACE
- **Issue:** The vignette listed tc_connect, tc_validate, tc_check_columns, tc_read_counts, tc_read_interviews, tc_read_catch, tc_write_estimates, tc_import_batch, tc_import_csv, tc_import_xlsx — none of these exist in the actual NAMESPACE. The real API uses a different naming convention.
- **Fix:** Replaced the entire "What tidycreel.connect will provide" section with documentation of actual exported functions from the NAMESPACE. Verified against local clone at /Users/cchizinski2/Dev/tidycreel/tidycreel.connect/NAMESPACE. GitHub repo was private (returned 404), so local clone was used for verification.
- **Files modified:** vignettes/tidycreel-connect.Rmd
- **Commit:** 8a5fe54

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary crossings introduced.

## Self-Check: PASSED

- vignettes/tidycreel-connect.Rmd: exists, 120+ lines, stale language = 0, install block present
- .github/ISSUE_TEMPLATE/bug-report.yml: exists, r_version field at position 3, YAML valid
- tests/testthat/test-write-estimates.R: exists, WRITE-11 block appended, test suite 0 failures
- All 3 commits verified in git log: 8a5fe54, 0980dbb, 2e5bdcb
