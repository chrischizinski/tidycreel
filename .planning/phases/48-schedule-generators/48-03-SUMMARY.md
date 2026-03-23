---
phase: 48-schedule-generators
plan: "03"
subsystem: schedule-io
tags: [r-package, file-io, csv, xlsx, readxl, writexl, creel_schedule, date-coercion]

requires:
  - phase: 48-01
    provides: new_creel_schedule(), validate_creel_schedule(), generate_schedule()

provides:
  - write_schedule() — exports creel_schedule to CSV (base R) or xlsx (writexl)
  - read_schedule() — reads CSV/xlsx into validated creel_schedule with type coercion
  - coerce_to_date() — internal helper: Date, POSIXct, numeric serial, ISO/Excel character
  - coerce_schedule_columns() — shared coercion layer (no format-specific branches)

affects:
  - 48-04
  - 49-validate-design
  - 51-print-methods

tech-stack:
  added: []
  patterns:
    - "Read all columns as text first (colClasses='character' / col_types='text'), then call coerce_schedule_columns() — identical path for CSV and xlsx"
    - "rlang::check_installed() guard for optional Suggests packages (writexl, readxl)"
    - "# nolint: object_usage_linter on cross-file internal calls"
    - "Treat literal 'NA' strings from write.csv as NA_character_ before type coercion"
    - "Character Excel serials (pure-digit strings from readxl col_types='text') handled in coerce_to_date via grepl('^[0-9]+$')"

key-files:
  created:
    - R/schedule-io.R
    - man/read_schedule.Rd
    - man/write_schedule.Rd
  modified:
    - tests/testthat/test-schedule-io.R
    - NAMESPACE

key-decisions:
  - "coerce_to_date() checks for pure-digit character strings (Excel serials from readxl col_types='text') before ISO parse — avoids charToDate error"
  - "coerce_schedule_columns() normalises literal 'NA' strings back to NA_character_ for both date and day_type (write.csv artifact)"
  - "# nolint: object_usage_linter used on validate_creel_schedule() and new_creel_schedule() cross-file calls — same pattern as creel-design.R"

patterns-established:
  - "Text-first read then coerce: all schedule files read with colClasses/col_types='character', then coerce_schedule_columns() handles types uniformly"
  - "Excel serial character detection: grepl('^[0-9]+$', x) before as.Date() prevents charToDate errors on readxl text output"

requirements-completed:
  - SCHED-03
  - SCHED-04

duration: 72min
completed: 2026-03-23
---

# Phase 48 Plan 03: Schedule I/O Summary

**write_schedule()/read_schedule() with Excel-resilient date coercion — full CSV/xlsx round-trip to creel_design() verified**

## Performance

- **Duration:** 72 min
- **Started:** 2026-03-23T19:42:50Z
- **Completed:** 2026-03-23T20:55:00Z
- **Tasks:** 1/1
- **Files modified:** 5

## Accomplishments

- `write_schedule()` exports creel_schedule to CSV (utils::write.csv, no extra deps) or xlsx (writexl behind check_installed guard); returns invisible(path)
- `read_schedule()` reads CSV or xlsx, reads all columns as text, applies shared `coerce_schedule_columns()`, validates with `validate_creel_schedule()`, wraps with `new_creel_schedule()`
- `coerce_to_date()` handles Date passthrough, POSIXct/lt, numeric Excel serials (origin 1899-12-30), character ISO strings, and character Excel serial strings (from readxl col_types="text")
- Round-trip verified: generate_schedule -> write_schedule (CSV) -> read_schedule -> creel_design() succeeds with correct column types
- All 24 SCHED-03 and SCHED-04 tests pass; full suite FAIL 0 | SKIP 1 | PASS 1762

## Task Commits

1. **Task 1: write_schedule() and read_schedule() with round-trip tests** - `b36210f` (feat)

## Files Created/Modified

- `R/schedule-io.R` — write_schedule(), read_schedule(), coerce_schedule_columns(), coerce_to_date()
- `tests/testthat/test-schedule-io.R` — 24 activated tests (SCHED-03 and SCHED-04; skip removed)
- `NAMESPACE` — write_schedule, read_schedule, validate_creel_schedule exports updated
- `man/read_schedule.Rd` — generated roxygen documentation
- `man/write_schedule.Rd` — generated roxygen documentation

## Decisions Made

- Character Excel serials (pure-digit strings produced by `readxl::read_excel(col_types = "text")`) are detected via `grepl("^[0-9]+$", x)` before ISO date parsing — prevents `charToDate` error
- Literal `"NA"` strings written by `utils::write.csv` for `NA_character_` values are converted back to `NA_character_` in `coerce_schedule_columns()` for both `date` and `day_type` columns
- `# nolint: object_usage_linter` applied to cross-file internal calls (`validate_creel_schedule`, `new_creel_schedule`) — consistent with pattern in `creel-design.R`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Excel serial character strings from readxl col_types="text"**
- **Found during:** Task 1 (GREEN phase, xlsx round-trip test)
- **Issue:** `readxl::read_excel(col_types = "text")` returns date cells as character strings of Excel serial numbers (e.g., `"45444"`), not as ISO strings. `as.Date("45444")` triggers `charToDate` error.
- **Fix:** Added `grepl("^[0-9]+$", x)` check in `coerce_to_date()` before ISO parse; convert to integer and apply `origin = "1899-12-30"` for these values
- **Files modified:** R/schedule-io.R
- **Verification:** SCHED-04 xlsx round-trip test passes; `result$date` is class Date with correct values
- **Committed in:** b36210f

**2. [Rule 1 - Bug] Literal "NA" strings from write.csv not coerced to NA_character_**
- **Found during:** Task 1 (GREEN phase, day_type=NA validation test)
- **Issue:** `utils::write.csv` serialises `NA_character_` as the string `"NA"`. When read back with `colClasses = "character"`, `coerce_to_date("NA")` triggers `charToDate` error and `as.character("NA")` passes through as non-NA to `validate_creel_schedule`, bypassing the NA check
- **Fix:** Added `x[!is.na(x) & x == "NA"] <- NA_character_` in `coerce_to_date()` and analogous guard in `coerce_schedule_columns()` for `day_type`
- **Files modified:** R/schedule-io.R
- **Verification:** SCHED-04 day_type=NA_character_ validation test triggers expected cli_abort
- **Committed in:** b36210f

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs in read-back coercion)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered

- lintr `object_usage_linter` blocked first commit attempt — cross-file internal function calls `validate_creel_schedule()` and `new_creel_schedule()` flagged as "no visible global function definition". Fixed with `# nolint: object_usage_linter` comments (same pattern as `creel-design.R:261`).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SCHED-03 and SCHED-04 complete; schedule I/O layer fully implemented
- Phase 48 Wave 2 complete when Plan 02 also finishes
- Phase 49 (validate_design) can proceed independently; uses creel_design() not schedule I/O
- readxl round-trip tested with writexl-written xlsx files (date serialisation confirmed)

---
*Phase: 48-schedule-generators*
*Completed: 2026-03-23*
