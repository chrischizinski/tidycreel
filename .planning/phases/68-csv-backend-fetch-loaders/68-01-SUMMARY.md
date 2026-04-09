---
phase: 68-csv-backend-fetch-loaders
plan: "01"
subsystem: database
tags: [readr, s3, creel_connection, csv-backend, fetch-loaders, tidycreel.connect]

requires:
  - phase: 67-tidycreel-connect-package-connection-layer
    provides: creel_connection S3 class, creel_connect() constructor, helper-csv.R fixture

provides:
  - readr in DESCRIPTION Imports (CSV-only install path, no ODBC system libs)
  - S3 subclass creel_connection_csv on CSV connections for UseMethod() dispatch
  - S3 subclass creel_connection_sqlserver on DBI connections for UseMethod() dispatch
  - make_test_csv_bom() fixture for BOM-encoded Excel-style CSV testing
  - make_test_csv_numeric_species() fixture for integer species code testing
  - Failing skip() stubs for all five fetch_*() functions (13 stubs across 4 files)

affects:
  - 68-02 (Wave 2 fetch_* implementation — dispatches on creel_connection_csv subclass)
  - 68-03 (SQL Server loaders — dispatches on creel_connection_sqlserver)

tech-stack:
  added:
    - readr (Imports in tidycreel.connect/DESCRIPTION)
  patterns:
    - new_creel_connection() accepts optional subclass arg: c(subclass, "creel_connection")
    - skip("Wave 2: ...") stubs signal pending implementation for Wave 2 baseline tests
    - writeBin(c(as.raw(BOM_bytes), charToRaw(readr::format_csv(df))), path) for BOM CSV fixture

key-files:
  created:
    - tidycreel.connect/tests/testthat/test-fetch-interviews.R
    - tidycreel.connect/tests/testthat/test-fetch-counts.R
    - tidycreel.connect/tests/testthat/test-fetch-catch.R
    - tidycreel.connect/tests/testthat/test-fetch-lengths.R
  modified:
    - tidycreel.connect/DESCRIPTION
    - tidycreel.connect/R/creel-connection.R
    - tidycreel.connect/tests/testthat/helper-csv.R

key-decisions:
  - "readr added to Imports (not Suggests) so CSV-only users get it automatically without extra install steps"
  - "new_creel_connection() uses optional subclass arg — caller specifies the leaf class, base class always appended"
  - "BOM fixture uses writeBin + readr::format_csv() — simpler than file() + writeLines() approach"
  - "skip() stubs preferred over expect_error() stubs — clearly signals pending rather than expected failure"

patterns-established:
  - "S3 subclass pattern: c(subclass, 'creel_connection') enables UseMethod() dispatch to backend-specific fetch_*() methods"
  - "BOM CSV fixture pattern: writeBin(c(as.raw(BOM), charToRaw(readr::format_csv(df))), path)"

requirements-completed: [BACKEND-01, BACKEND-04]

duration: 9min
completed: 2026-04-07
---

# Phase 68 Plan 01: CSV Backend Prerequisites Summary

**readr added to DESCRIPTION Imports, creel_connection S3 subclasses added for UseMethod() dispatch, BOM/numeric-species fixtures added to helper-csv.R, and 13 skip() stubs written across 4 test files as Wave 2 baselines**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-07T18:19:13Z
- **Completed:** 2026-04-07T18:22:18Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added `readr` to DESCRIPTION Imports so CSV-only users install without ODBC system libraries
- Fixed `new_creel_connection()` to accept optional `subclass` arg, enabling UseMethod() dispatch to `creel_connection_csv` and `creel_connection_sqlserver` leaf classes
- Extended `helper-csv.R` with `make_test_csv_bom()` (UTF-8 BOM Excel-style) and `make_test_csv_numeric_species()` (integer species codes for NGPC SQL Server simulation)
- Created 4 test files with 13 `skip()` stubs covering FETCH-01 through FETCH-06 and BACKEND-01, providing unambiguous red baselines for Wave 2

## Task Commits

Each task was committed atomically:

1. **Task 1: Add readr to Imports and fix S3 subclasses on connection constructors** - `b7b29f9` (feat)
2. **Task 2: Extend helper-csv.R with BOM and numeric-species fixtures, write failing test stubs** - `cdbd494` (test)

**Plan metadata:** (see final commit)

## Files Created/Modified

- `tidycreel.connect/DESCRIPTION` - Added `readr` to Imports field (alphabetical order)
- `tidycreel.connect/R/creel-connection.R` - `new_creel_connection()` gains `subclass` arg; both callers updated
- `tidycreel.connect/tests/testthat/helper-csv.R` - Added `make_test_csv_bom()` and `make_test_csv_numeric_species()`
- `tidycreel.connect/tests/testthat/test-fetch-interviews.R` - 4 skip() stubs (FETCH-01, FETCH-06, BACKEND-01)
- `tidycreel.connect/tests/testthat/test-fetch-counts.R` - 2 skip() stubs (FETCH-02, FETCH-06)
- `tidycreel.connect/tests/testthat/test-fetch-catch.R` - 3 skip() stubs (FETCH-03, FETCH-06, BACKEND-01)
- `tidycreel.connect/tests/testthat/test-fetch-lengths.R` - 4 skip() stubs (FETCH-04, FETCH-05, FETCH-06, BACKEND-01)

## Decisions Made

- `readr` in Imports (not Suggests): CSV-only users should not need extra install steps to use the CSV backend
- `new_creel_connection()` accepts `subclass = NULL` as default, preserving backward compatibility while enabling leaf-class dispatch
- BOM fixture uses `writeBin(c(as.raw(BOM_bytes), charToRaw(readr::format_csv(df))), path)` — simpler than file() + writeLines() approach and avoids encoding inconsistencies
- `skip()` stubs preferred over `expect_error()` — clearly communicates "pending Wave 2 work" rather than "expected failure"

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Wave 2 (Plan 68-02) can now dispatch on `creel_connection_csv` subclass via UseMethod()
- All 13 test stubs are in place as red baselines; Wave 2 turns these green
- `make_test_csv_bom()` and `make_test_csv_numeric_species()` fixtures ready for immediate use
- Pre-existing 19 tests remain green; 14 total skips (1 pre-existing + 13 new stubs)

---
*Phase: 68-csv-backend-fetch-loaders*
*Completed: 2026-04-07*

## Self-Check: PASSED

All created files confirmed present. Both task commits (b7b29f9, cdbd494) verified in git history.
