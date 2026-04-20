---
phase: 76-ropensci-blockers
plan: "01"
subsystem: testing
tags: [lifecycle, scales, citation, bibentry, usethis, testthat]

requires: []
provides:
  - inst/CITATION with bibentry() sourced from DESCRIPTION metadata
  - lifecycle in DESCRIPTION Imports; scales removed from Imports
  - man/figures/ lifecycle badge SVGs (experimental, stable, deprecated, superseded)
  - test-citation.R with 3 passing citation tests
  - test-survey-bridge-percent.R stub (2 RED tests targeting Plan 03 scales removal)
affects:
  - 76-02
  - 76-03
  - 76-04
  - 76-05

tech-stack:
  added: [lifecycle]
  patterns:
    - "inst/CITATION uses bibentry() with metadata sourced from DESCRIPTION, not CITATION.cff"
    - "Wave 0 test stubs: write failing tests first, close them in implementation plan"

key-files:
  created:
    - inst/CITATION
    - tests/testthat/test-citation.R
    - tests/testthat/test-survey-bridge-percent.R
    - man/figures/lifecycle-experimental.svg
    - man/figures/lifecycle-stable.svg
    - man/figures/lifecycle-deprecated.svg
    - man/figures/lifecycle-superseded.svg
  modified:
    - DESCRIPTION

key-decisions:
  - "CITATION.cff has placeholder data — all citation metadata sourced from DESCRIPTION"
  - "test-survey-bridge-percent.R is intentionally RED until Plan 03 replaces scales::percent()"
  - "usethis::use_lifecycle() auto-adds importFrom directive to R/tidycreel-package.R (not actioned — Plan 03 handles roxygen)"

patterns-established:
  - "Wave 0 stubs: test files written before implementation so Plan 03 has a red-to-green target"
  - "bibentry() CITATION pattern: use packageVersion() and Sys.Date() for dynamic metadata"

requirements-completed: [API-01, API-02, DEPS-01]

duration: 2min
completed: "2026-04-20"
---

# Phase 76 Plan 01: Foundation — CITATION, lifecycle, and percent stubs

**lifecycle added to DESCRIPTION Imports (scales removed), inst/CITATION with bibentry(), lifecycle SVGs copied, and RED test stubs for Plan 03 scales removal**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-20T02:32:02Z
- **Completed:** 2026-04-20T02:34:00Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments
- Replaced `scales` with `lifecycle` in DESCRIPTION Imports (prerequisite for all Wave 1 plans)
- Created inst/CITATION with bibentry() using correct author metadata from DESCRIPTION (not CITATION.cff which has placeholder data)
- Copied lifecycle badge SVGs to man/figures/ via `usethis::use_lifecycle()` (required before Plan 03 can add `@lifecycle` tags)
- Wrote 3 passing tests for `citation("tidycreel")` return value, author name, and URL
- Wrote 2 RED test stubs targeting `mor_truncation_message()` sprintf percent formatting — will turn green in Plan 03

## Task Commits

Each task was committed atomically:

1. **Task 1: Edit DESCRIPTION and run usethis::use_lifecycle()** - `86f7509` (chore)
2. **Task 2: Create inst/CITATION and test-citation.R stub** - `ab2824f` (feat)
3. **Task 3: Create test-survey-bridge-percent.R stub** - `612effc` (test)

## Files Created/Modified
- `DESCRIPTION` - lifecycle added to Imports; scales removed
- `inst/CITATION` - bibentry() with author, ORCID, version, URL
- `tests/testthat/test-citation.R` - 3 passing citation tests
- `tests/testthat/test-survey-bridge-percent.R` - 2 RED stubs for scales removal
- `man/figures/lifecycle-experimental.svg` - lifecycle badge (new)
- `man/figures/lifecycle-stable.svg` - lifecycle badge (new)
- `man/figures/lifecycle-deprecated.svg` - lifecycle badge (new)
- `man/figures/lifecycle-superseded.svg` - lifecycle badge (new)

## Decisions Made
- CITATION.cff has placeholder data — all metadata sourced exclusively from DESCRIPTION
- test-survey-bridge-percent.R stubs are deliberately RED; Plan 03 closes them
- `usethis::use_lifecycle()` printed a directive to add `@importFrom lifecycle deprecated` to `R/tidycreel-package.R`; that roxygen step is deferred to Plan 03 when `devtools::document()` is run

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DESCRIPTION is ready for Wave 1 plans: lifecycle available, scales gone
- Lifecycle SVGs present — Plan 03 can safely add `lifecycle::badge()` inline tags
- test-survey-bridge-percent.R provides a regression target for Plan 03 scales::percent() replacement
- All success criteria met: citation() works, DESCRIPTION correct, SVGs present, 3 citation tests pass

---
*Phase: 76-ropensci-blockers*
*Completed: 2026-04-20*
