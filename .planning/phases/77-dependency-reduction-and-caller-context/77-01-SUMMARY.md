---
phase: 77-dependency-reduction-and-caller-context
plan: 01
subsystem: dependencies
tags: [lubridate, rlang, check_installed, DESCRIPTION, Suggests, Imports]

# Dependency graph
requires:
  - phase: 76-ropensci-blockers
    provides: Named conditions, lifecycle badges, CITATION, scales removal — all rOpenSci blockers closed
provides:
  - lubridate demoted from Imports to Suggests in DESCRIPTION
  - rlang::check_installed("lubridate") guards at 4 user-visible entry points
  - DEPS-02 requirement satisfied
affects:
  - 77-02 (caller_env changes — same phase)
  - 78-family-and-snapshots
  - rOpenSci submission readiness

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "rlang::check_installed() bare form (no reason arg) for soft-dependency guards at function entry points"
    - "TDD RED-GREEN cycle for DESCRIPTION structure + source-file guard validation"

key-files:
  created:
    - tests/testthat/test-lubridate-guards.R
  modified:
    - DESCRIPTION
    - R/schedule-generators.R
    - R/schedule-print.R
    - R/autoplot-methods.R

key-decisions:
  - "lubridate guard uses bare rlang::check_installed('lubridate') with no reason argument — per locked plan decision"
  - "Suggests entry keeps version constraint lubridate (>= 1.9.0) carried over from Imports"
  - "knit_print.creel_schedule() receives its own lubridate guard after the existing knitr guard — callers guarded, internal build_month_grid() left unguarded"
  - "Guard tests use skip_if() when R/ source files absent so they pass cleanly under both devtools::test() and R CMD check"

patterns-established:
  - "Soft-dependency pattern: package in Suggests + rlang::check_installed() at every user-visible entry point that calls it"

requirements-completed:
  - DEPS-02

# Metrics
duration: 20min
completed: 2026-04-20
---

# Phase 77 Plan 01: Dependency Reduction — lubridate Demotion Summary

**lubridate demoted from Imports to Suggests with rlang::check_installed() guards at 4 user-visible entry points (generate_schedule, format.creel_schedule, knit_print.creel_schedule, autoplot.creel_schedule)**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-04-20T19:56:05Z
- **Completed:** 2026-04-20T20:16:00Z
- **Tasks:** 2
- **Files modified:** 5 (DESCRIPTION, 3 R source files, 1 test file)

## Accomplishments

- Moved `lubridate (>= 1.9.0)` from `Imports:` to `Suggests:` in DESCRIPTION — users who do not use schedule visualisation no longer require lubridate installed
- Added `rlang::check_installed("lubridate")` (bare form, no reason arg) at the top of `generate_schedule()`, `format.creel_schedule()`, `knit_print.creel_schedule()`, and `autoplot.creel_schedule()`
- Full test suite (2528 tests) passes with 0 failures; rcmdcheck reports 0 errors, 0 warnings
- TDD RED-GREEN cycle: 5 failing tests written first, then implementation made them pass; guard tests skip cleanly under R CMD check installed context

## Task Commits

Each task was committed atomically:

1. **Task 1 (TDD RED): Failing tests for lubridate demotion** - `f3c4197` (test)
2. **Task 1 (TDD GREEN): Demote lubridate and add guards** - `f0a9dbf` (feat)
3. **Task 1 (Fix): Resilient guard tests for R CMD check** - `46cdccb` (test)
4. **Task 2: Full test suite + rcmdcheck verification** — no additional commit (verification only)

## Files Created/Modified

- `DESCRIPTION` — lubridate moved from Imports to Suggests; Suggests entries re-sorted alphabetically
- `R/schedule-generators.R` — `rlang::check_installed("lubridate")` added as first line of `generate_schedule()` body
- `R/schedule-print.R` — guard added at `format.creel_schedule()` entry; second guard added at `knit_print.creel_schedule()` entry after existing knitr guard
- `R/autoplot-methods.R` — `rlang::check_installed("lubridate")` added as first line of `autoplot.creel_schedule()` body
- `tests/testthat/test-lubridate-guards.R` — 5 DEPS-02 tests: DESCRIPTION structure + 3 source-file guard checks (skip when source absent)

## Decisions Made

- Bare `rlang::check_installed("lubridate")` form used (no `reason` argument) — per locked decision in plan frontmatter
- `build_month_grid()` left without its own guard — it is an internal helper called only from guarded entry points
- Guard tests use `skip_if(!file.exists(src))` so they run under `devtools::test()` and skip gracefully under `R CMD check` (where source R/ files are not present in the installed temp build)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Guard tests failed under R CMD check (source files absent)**
- **Found during:** Task 2 (rcmdcheck run)
- **Issue:** `testthat::test_path(".")` in guard tests resolved to a temp check directory where R/ source files do not exist, causing `readLines()` errors
- **Fix:** Rewrote `pkg_root()` helper to walk up the directory tree; added `skip_if(!file.exists(src))` for source-file guard tests
- **Files modified:** `tests/testthat/test-lubridate-guards.R`
- **Verification:** `devtools::test()` — 5 PASS; `rcmdcheck` — 0 errors 0 warnings
- **Committed in:** `46cdccb`

---

**Total deviations:** 1 auto-fixed (Rule 1 — test infrastructure fix for installed-package context)
**Impact on plan:** Required fix for clean rcmdcheck. No scope creep; tests validate the same correctness properties.

## Issues Encountered

- `here::here()` used in initial test draft was not in DESCRIPTION — replaced with `testthat::test_path()` + directory walker approach that needs no additional package dependency

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- DEPS-02 requirement fully satisfied
- lubridate soft-dependency pattern established for use in any future schedule-related functions
- Phase 77 Plan 02 (caller_env / `caller_env` context passing) can proceed

---
*Phase: 77-dependency-reduction-and-caller-context*
*Completed: 2026-04-20*
