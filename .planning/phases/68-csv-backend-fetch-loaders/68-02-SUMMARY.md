---
phase: 68-csv-backend-fetch-loaders
plan: "02"
subsystem: database
tags: [readr, s3, fetch-loaders, fetch-validators, csv-backend, tidycreel.connect]

requires:
  - phase: 68-01
    provides: creel_connection_csv S3 subclass, BOM/numeric-species fixtures, skip() stubs

provides:
  - Five validate_fetch_*() internal helpers in fetch-validators.R
  - Five fetch_*() public generics + CSV methods + SQL Server stubs in fetch-loaders.R
  - NAMESPACE exports for all five fetch_*() functions
  - Five man/*.Rd documentation files
  - Real test assertions replacing all 13 skip() stubs

affects:
  - 69 (SQL Server loaders — overrides creel_connection_sqlserver stub methods)

tech-stack:
  added: []
  patterns:
    - ".check_col() + .validate_fetch() internal helpers: collect ALL failures before one cli_abort()"
    - ".rename_to_canonical() base R rename: df[, keep, drop=FALSE]; names(result) <- names(keep)"
    - ".read_csv_safe(): readr::read_csv(show_col_types=FALSE, progress=FALSE) — native BOM stripping"
    - "make_test_schema() in helper-csv.R shared across all four fetch test files"
    - "# nolint: object_usage_linter on validate_fetch_*() calls (internal functions)"

key-files:
  created:
    - tidycreel.connect/R/fetch-validators.R
    - tidycreel.connect/R/fetch-loaders.R
    - tidycreel.connect/man/fetch_interviews.Rd
    - tidycreel.connect/man/fetch_counts.Rd
    - tidycreel.connect/man/fetch_catch.Rd
    - tidycreel.connect/man/fetch_harvest_lengths.Rd
    - tidycreel.connect/man/fetch_release_lengths.Rd
  modified:
    - tidycreel.connect/NAMESPACE
    - tidycreel.connect/tests/testthat/helper-csv.R
    - tidycreel.connect/tests/testthat/test-fetch-interviews.R
    - tidycreel.connect/tests/testthat/test-fetch-counts.R
    - tidycreel.connect/tests/testthat/test-fetch-catch.R
    - tidycreel.connect/tests/testthat/test-fetch-lengths.R

key-decisions:
  - "catch_col (not catch_count_col) is the schema field for interviews catch count — plan had wrong field name; verified from creel-schema.R"
  - "count_col (not angler_count_col) is the schema field for counts angler count — plan had wrong field name"
  - "make_test_schema() placed in helper-csv.R (not per-file) so all four fetch test files share it"
  - "interview_uid added to all three CSV fixtures — validate_fetch_interviews requires it (any type)"
  - "# nolint: object_usage_linter on validate_fetch_*() calls — @noRd helpers not visible to lintr"
  - "Non-ASCII warning in creel-connect-yaml.R (Phase 67 em-dashes) is pre-existing; deferred to deferred-items.md"

requirements-completed: [FETCH-01, FETCH-02, FETCH-03, FETCH-04, FETCH-05, FETCH-06, BACKEND-01, BACKEND-04]

duration: 5min
completed: 2026-04-07
---

# Phase 68 Plan 02: CSV Backend Fetch Loaders Summary

**Five fetch_*() generics with creel_connection_csv methods and SQL Server stubs, plus five validate_fetch_*() internal validators — all 13 skip() stubs replaced with real assertions, 71 tests pass**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-07T18:25:42Z
- **Completed:** 2026-04-07T18:30:xx Z
- **Tasks:** 2
- **Files modified:** 14

## Accomplishments

- Created `fetch-validators.R` with five `@noRd` helpers (`validate_fetch_interviews`, `validate_fetch_counts`, `validate_fetch_catch`, `validate_fetch_harvest_lengths`, `validate_fetch_release_lengths`) — each collects all column failures before a single `cli_abort()`
- Created `fetch-loaders.R` with five exported generics dispatching to `creel_connection_csv` CSV methods and `creel_connection_sqlserver` stubs that abort "not yet implemented (Phase 69)"
- `.read_csv_safe()` uses native readr BOM stripping (no locale argument needed)
- `.rename_to_canonical()` renames and selects only schema-mapped canonical columns; extra CSV columns dropped
- Species coerced to `as.character()` after rename in `fetch_catch()`, `fetch_harvest_lengths()`, `fetch_release_lengths()` for NGPC integer species code compatibility
- Ran `devtools::document()` to generate NAMESPACE exports and five `man/*.Rd` files
- Replaced all 13 `skip()` stubs with real assertions; 71 tests pass, 1 pre-existing skip

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement fetch-validators.R and replace skip() stubs** - `9811765` (test)
2. **Task 2: Implement fetch-loaders.R, NAMESPACE, man pages** - `9d0e177` (feat)

**Plan metadata:** (see final commit)

## Files Created/Modified

- `tidycreel.connect/R/fetch-validators.R` — five `@noRd` validate helpers
- `tidycreel.connect/R/fetch-loaders.R` — five exported generics, CSV methods, SQL Server stubs
- `tidycreel.connect/NAMESPACE` — five new S3method() and export() entries
- `tidycreel.connect/man/fetch_interviews.Rd`, `fetch_counts.Rd`, `fetch_catch.Rd`, `fetch_harvest_lengths.Rd`, `fetch_release_lengths.Rd` — roxygen2 documentation
- `tidycreel.connect/tests/testthat/helper-csv.R` — added `make_test_schema()` and `interview_uid` column to all three fixtures
- `tidycreel.connect/tests/testthat/test-fetch-interviews.R` — 4 real assertions (FETCH-01, FETCH-06, BACKEND-01)
- `tidycreel.connect/tests/testthat/test-fetch-counts.R` — 2 real assertions (FETCH-02, FETCH-06)
- `tidycreel.connect/tests/testthat/test-fetch-catch.R` — 3 real assertions (FETCH-03, FETCH-06, BACKEND-01)
- `tidycreel.connect/tests/testthat/test-fetch-lengths.R` — 4 real assertions (FETCH-04, FETCH-05, FETCH-06, BACKEND-01)

## Decisions Made

- `catch_col` (not `catch_count_col`) is the schema field for interviews catch count; `count_col` (not `angler_count_col`) is the schema field for counts angler count — the plan had incorrect field names; confirmed from `tidycreel/R/creel-schema.R`
- `make_test_schema()` placed in `helper-csv.R` shared helper (not per-file) so all four test files can use it without duplication
- `interview_uid` column added to all three CSV fixtures (`make_test_csv`, `make_test_csv_bom`, `make_test_csv_numeric_species`) since `validate_fetch_interviews()` requires it (`"any"` type check — presence only)
- `# nolint: object_usage_linter` added at the five `validate_fetch_*()` call sites in `fetch-loaders.R` — `@noRd` internal helpers are not visible to lintr's namespace checker

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected schema field names in rename_map**

- **Found during:** Task 2 — verified creel-schema.R before writing rename maps (as plan instructed)
- **Issue:** Plan specified `catch_count_col` for interviews and `angler_count_col` for counts, but `creel_schema()` uses `catch_col` and `count_col` respectively
- **Fix:** Used `catch_col` for `catch_count` in interviews rename map; `count_col` for `angler_count` in counts rename map
- **Files modified:** `tidycreel.connect/R/fetch-loaders.R`
- **Commit:** 9d0e177

**2. [Rule 3 - Blocking] Added # nolint: object_usage_linter to validate_fetch_*() calls**

- **Found during:** Task 2 — pre-commit lintr hook blocked commit
- **Issue:** Lintr `object_usage_linter` reports `@noRd` internal functions as "no visible global function definition"
- **Fix:** Added `# nolint: object_usage_linter` comment at each of the five call sites
- **Files modified:** `tidycreel.connect/R/fetch-loaders.R`
- **Commit:** 9d0e177

## Deferred Issues

**Pre-existing: Non-ASCII characters in `creel-connect-yaml.R` (Phase 67)**

Em-dash characters (`—`) in comments trigger R CMD check WARNING. Documented in `deferred-items.md`. No behavioral impact; not related to Phase 68 changes.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Phase 68 Completion

Phase 68 is now complete. Both plans delivered:
- Plan 01: readr in Imports, subclass dispatch, BOM/numeric-species fixtures, skip() stubs
- Plan 02: five validators, five loaders, five SQL Server stubs, all tests green

---
*Phase: 68-csv-backend-fetch-loaders*
*Completed: 2026-04-07*
