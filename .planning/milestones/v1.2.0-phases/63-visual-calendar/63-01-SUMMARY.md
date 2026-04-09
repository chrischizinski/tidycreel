---
phase: 63-visual-calendar
plan: 01
subsystem: ui
tags: [S3-methods, print, calendar, ascii, pandoc, knitr, creel_schedule]

requires:
  - phase: 60-version-packaging
    provides: creel_schedule S3 class and generate_schedule() generator

provides:
  - format.creel_schedule() — ASCII monthly calendar character vector
  - print.creel_schedule() — console calendar (replaces raw data frame dump)
  - knit_print.creel_schedule() — pandoc pipe-table for R Markdown / Quarto
  - make_day_abbrevs() — collision-resolving day-type abbreviation helper
  - build_cell_lookup() — date-to-cell-content mapping helper
  - build_month_grid() — ASCII/pandoc monthly calendar grid builder

affects:
  - 63.1-count-time-attach
  - any phase generating or displaying creel_schedule objects

tech-stack:
  added: []
  patterns:
    - "format/print split: format.X() builds character vector, print.X() calls cat(format(x), sep='\\n')"
    - "knit_print registered via @rawNamespace S3method(knitr::knit_print, creel_schedule)"
    - "Day-type abbreviation collision resolution: loop k from 2..max(nchar) until !anyDuplicated()"
    - "build_month_grid() accepts mode='ascii' or mode='pandoc' for dual output format support"

key-files:
  created:
    - R/schedule-print.R
    - tests/testthat/test-schedule-print.R
    - man/format.creel_schedule.Rd
    - man/print.creel_schedule.Rd
    - man/knit_print.creel_schedule.Rd
  modified:
    - R/schedule-generators.R
    - NAMESPACE

key-decisions:
  - "Removed old print.creel_schedule() from schedule-generators.R; new method in schedule-print.R fully replaces it with ASCII calendar grid"
  - "Used @rawNamespace S3method(knitr::knit_print, creel_schedule) instead of @exportS3Method because roxygen2 7.3.3 produced incorrect S3method(knitr,knit_print) entry"
  - "Cell width dynamically sized to max(max_content_width, 8L) for consistent ASCII columns across all week rows"
  - "Non-sampled dates always show date number only; sampled dates show abbreviation (+ circuit for bus-route)"

patterns-established:
  - "schedule-print.R: all print infrastructure in dedicated file separate from schedule-generators.R"
  - "build_cell_lookup(mode=) controls separator character (newline vs <br>) at lookup-build time"

requirements-completed:
  - CAL-01
  - CAL-02

duration: 9min
completed: 2026-04-05
---

# Phase 63 Plan 01: Visual Calendar Summary

**ASCII monthly calendar grid and pandoc pipe-table S3 methods for creel_schedule, with dynamic day-type abbreviation collision resolution (WEEKD/WEEKE at k=5)**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-05T15:42:37Z
- **Completed:** 2026-04-05T15:51:57Z
- **Tasks:** 3 (TDD: RED + GREEN + verify)
- **Files modified:** 5 (created 3, modified 2)

## Accomplishments

- `print(my_schedule)` now renders a formatted monthly ASCII calendar grid (Sun-Sat columns, one row per week) instead of raw data frame rows
- `knitr::knit_print()` renders pandoc pipe-tables with `### Month YYYY` headings for embedding in R Markdown / Quarto
- Dynamic abbreviation system resolves "weekday"/"weekend" collision at k=5 (WEEKD/WEEKE), extensible to any custom day-type labels
- Bus-route schedules show circuit assignments on a second line (console: newline, document: `<br>`)
- 31 tests covering all CAL-01 and CAL-02 behaviors; 0 failures, 0 warnings in R CMD check

## Task Commits

1. **Task 1: Write failing test scaffold** - `9cd308b` (test — RED phase)
2. **Task 2: Implement schedule-print.R** - `cbb8131` (feat — GREEN phase)

Task 3 (R CMD check verification) produced no new files; no additional commit needed.

## Files Created/Modified

- `R/schedule-print.R` — All print infrastructure: make_day_abbrevs(), build_cell_lookup(), build_month_grid(), format.creel_schedule(), print.creel_schedule(), knit_print.creel_schedule()
- `R/schedule-generators.R` — Removed old print.creel_schedule() block (replaced by schedule-print.R)
- `NAMESPACE` — Added S3method(format,creel_schedule), S3method(knitr::knit_print,creel_schedule), S3method(print,creel_schedule)
- `tests/testthat/test-schedule-print.R` — 31 expectations covering CAL-01 (ASCII) and CAL-02 (pandoc) behaviors

## Decisions Made

- Used `@rawNamespace S3method(knitr::knit_print, creel_schedule)` because `@exportS3Method knitr knit_print` in roxygen2 7.3.3 produces `S3method(knitr,knit_print)` (wrong — treats "knitr" as class name, not package).
- Dynamic abbreviation loop (k=2..max_label_length) ensures extensibility: any custom day-type labels abbreviate without hardcoding.
- `build_month_grid(mode=)` centralizes ASCII/pandoc divergence at one call site; `build_cell_lookup(mode=)` sets the cell separator at lookup time so grid builder gets pre-formatted strings.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed subscript out-of-bounds in build_month_grid cell lookup**
- **Found during:** Task 2 (implementation)
- **Issue:** `cell_lookup[[key]]` with `[[` throws "subscript out of bounds" when key absent from named vector; affects all non-sampled date slots
- **Fix:** Changed to `cell_lookup[key]` (single bracket) which returns `NA` when key absent
- **Files modified:** R/schedule-print.R
- **Verification:** format.creel_schedule() renders without error; non-sampled dates show date number
- **Committed in:** cbb8131 (Task 2 commit)

**2. [Rule 1 - Bug] Fixed vapply type mismatch in .build_ascii_grid for empty cells**
- **Found during:** Task 2 (implementation)
- **Issue:** `max(nchar(cl))` returns `-Inf` (double) for empty padding cells; `vapply(..., integer(1))` rejects doubles
- **Fix:** Added guard: if cell is empty, return `0L` instead of calling max on empty vector
- **Files modified:** R/schedule-print.R
- **Verification:** ASCII grid renders correctly including padding cells
- **Committed in:** cbb8131 (Task 2 commit)

**3. [Rule 1 - Bug] Fixed NAMESPACE entry for knit_print.creel_schedule**
- **Found during:** Task 2 (devtools::document())
- **Issue:** `@exportS3Method knitr knit_print` generated `S3method(knitr,knit_print)` instead of `S3method(knitr::knit_print,creel_schedule)`; R reported "S3 method 'knitr.knit_print' was declared in NAMESPACE but not found" on load
- **Fix:** Replaced `@exportS3Method` with `@rawNamespace S3method(knitr::knit_print, creel_schedule)`
- **Files modified:** R/schedule-print.R, NAMESPACE
- **Verification:** devtools::load_all() no longer warns; knitr::knit_print(sched) dispatches correctly
- **Committed in:** cbb8131 (Task 2 commit)

**4. [Rule 1 - Bug] Updated test to match actual pandoc separator format**
- **Found during:** Task 2 (test run)
- **Issue:** Test expected `|---|` but build_month_grid(mode="pandoc") generates `|-----|`; test failed
- **Fix:** Updated expect_match to `|--` (valid pandoc separator prefix, matches actual output)
- **Files modified:** tests/testthat/test-schedule-print.R
- **Verification:** All 31 tests pass
- **Committed in:** cbb8131 (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All fixes necessary for correctness. No scope creep. Plan executed as designed.

## Issues Encountered

- `@exportS3Method knitr knit_print` roxygen2 tag generates incorrect NAMESPACE format in roxygen2 7.3.3; resolved with `@rawNamespace` directive. This is a quirk of how roxygen2 parses the package::generic notation for external generics.

## Next Phase Readiness

- `print(my_schedule)` and `knitr::knit_print(my_schedule)` are fully functional; ready for Phase 63.1 (count-time attachment) which will add count time windows to the schedule display
- NAMESPACE correctly registers both format and knit_print S3 methods

---
*Phase: 63-visual-calendar*
*Completed: 2026-04-05*
