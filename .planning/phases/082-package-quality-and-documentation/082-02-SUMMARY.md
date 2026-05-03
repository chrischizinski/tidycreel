---
phase: 082-package-quality-and-documentation
plan: "02"
subsystem: documentation
tags: [goodpractice, pkgdown, vignette, tidycreel.connect, vapply, sapply]

# Dependency graph
requires:
  - phase: 082-01
    provides: lifecycle import fix (rcmdcheck NOTE cleared)
provides:
  - goodpractice sapply → vapply fixes across 8 R source files
  - vignettes/tidycreel-connect.Rmd companion-package bridge article
  - Ecosystem nav section in _pkgdown.yml with tidycreel-connect entry
  - pkgdown site with tidycreel-connect article rendered to HTML
affects:
  - 082-03 (urlchecker, rhub)

# Tech tracking
tech-stack:
  added: [goodpractice (dev-only, not in DESCRIPTION)]
  patterns:
    - vapply(df, is.numeric, logical(1L)) preferred over sapply for type safety
    - vapply(list, `[[`, numeric(1L), col) for extracting named list elements

key-files:
  created:
    - vignettes/tidycreel-connect.Rmd
  modified:
    - _pkgdown.yml
    - R/autoplot-methods.R
    - R/creel-design.R
    - R/creel-estimates-aerial.R
    - R/creel-estimates-camera.R
    - R/creel-estimates-total-harvest.R
    - R/creel-estimates-total-release.R
    - R/creel-estimates.R
    - R/survey-bridge.R

key-decisions:
  - "goodpractice lintr_sapply_linter finding fixed by replacing all sapply() with vapply() across 8 files"
  - "T/F finding deferred: parameter T in estimate_exploitation_rate() uses canonical domain notation (Pollock et al. 1994); renaming would break public API, prohibited by phase constraints"
  - "cyclocomp finding deferred: creel_design (CC=74), estimate_catch_rate (CC=66), validate_trip_metadata (CC=65), format.creel_design (CC=56) all require refactoring estimator core logic"
  - "covr 86% deferred: at acceptable threshold set in M023 (85% Codecov); increasing coverage requires major test additions out of scope"
  - "long-lines finding deferred: 781+ instances across codebase; mass reformatting would obscure meaningful diffs and risk introducing bugs"
  - "rcmdcheck suggested-packages ERROR deferred: pre-existing from Phase 81; mitigated with _R_CHECK_FORCE_SUGGESTS_=false"

patterns-established:
  - "Ecosystem section in _pkgdown.yml: placed after Reference & Equations, before news:"
  - "Bridge/placeholder vignettes use eval = FALSE knitr option globally to prevent execution"

requirements-completed: [QUAL-04, DOCS-01]

# Metrics
duration: 24min
completed: 2026-04-28
---

# Phase 082 Plan 02: goodpractice Sweep and tidycreel.connect Bridge Article Summary

**vapply() type-safety sweep across 8 R source files; tidycreel.connect stub article published in new Ecosystem pkgdown nav section**

## Performance

- **Duration:** 24 min
- **Started:** 2026-04-28T01:43:08Z
- **Completed:** 2026-04-28T02:07:03Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Replaced all 14 `sapply()` calls with type-safe `vapply()` equivalents across 8 R source files; all 2537 tests continue to pass
- Created `vignettes/tidycreel-connect.Rmd` covering all four required areas: what the package is, how it relates to tidycreel, what it will provide, and how to stay notified
- Added an Ecosystem section to `_pkgdown.yml` (before `news:` key) with `tidycreel-connect` entry; pkgdown articles build without error and HTML is present at `docs/articles/tidycreel-connect.html`
- Documented five goodpractice findings as intentional deferrals (T/F parameter naming, cyclomatic complexity, line length, coverage, rcmdcheck suggested packages)

## Task Commits

Each task was committed atomically:

1. **Task 1: Run goodpractice and address WARNING-level findings** - `4070aaf` (fix)
2. **Task 2: Create vignettes/tidycreel-connect.Rmd and add Ecosystem section** - `8f08e0e` (feat)

**Plan metadata:** _(docs commit — see below)_

## Files Created/Modified

- `vignettes/tidycreel-connect.Rmd` — placeholder bridge article for tidycreel.connect companion package
- `_pkgdown.yml` — added Ecosystem section with tidycreel-connect article entry
- `R/autoplot-methods.R` — sapply → vapply (1 instance)
- `R/creel-design.R` — sapply → vapply (2 instances)
- `R/creel-estimates-aerial.R` — sapply → vapply (1 instance)
- `R/creel-estimates-camera.R` — sapply → vapply (1 instance)
- `R/creel-estimates-total-harvest.R` — sapply → vapply (5 instances)
- `R/creel-estimates-total-release.R` — sapply → vapply (5 instances)
- `R/creel-estimates.R` — sapply → vapply (3 instances)
- `R/survey-bridge.R` — sapply → vapply (1 instance)

## Decisions Made

- Fixed `lintr_sapply_linter` finding by replacing all `sapply()` calls with `vapply()` with explicit FUN.VALUE types; the pattern `vapply(df, is.numeric, logical(1L))` is now the established convention
- Deferred `truefalse_not_tf` finding for `estimate_exploitation_rate()`: the parameter `T` is canonical domain notation from Pollock et al. (1994) for "tagged fish released"; renaming to avoid the TRUE/FALSE shadow would be a breaking public API change explicitly prohibited by phase constraints
- Deferred `cyclocomp` finding (four functions with CC > 50): refactoring would require breaking up production estimators that are fully tested; not appropriate in a quality-sweep phase
- Deferred `covr` finding (86%): currently at the 85% Codecov threshold established in M023; major test additions are out of phase scope
- Deferred `lintr_line_length_linter` finding (781+ instances): mass reformatting would produce noisy diffs and introduce regression risk with no behaviour gain
- Deferred `rcmdcheck` suggested-packages ERROR: pre-existing from Phase 81; local dev uses `_R_CHECK_FORCE_SUGGESTS_=false`

## Deviations from Plan

### Auto-fixed Issues

None — the sapply → vapply replacement was explicit in the task plan. All other identified issues were assessed and either fixed (sapply) or documented as intentional deferrals per plan instructions.

---

**Total deviations:** 0 unplanned auto-fixes
**Impact on plan:** Plan executed as specified. Deferrals documented per task instructions.

## Issues Encountered

- `goodpractice` was not installed; installed automatically via `install.packages("goodpractice")` with its dependencies (`clisymbols`, `cyclocomp`). Not a blocker.
- `goodpractice::gp()` reports line number `:NA:NA` for the T/F finding — line-number precision is a known limitation of that check; confirmed via `lintr::lint_package(linters = list(lintr::T_and_F_symbol_linter()))` that the issue is the parameter `T` shadowing `TRUE`.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- goodpractice: one fixable finding resolved (sapply); five findings documented as intentional deferrals
- pkgdown site: Ecosystem section live with tidycreel-connect bridge article
- Ready for Phase 082-03: urlchecker URL validation and rhub CI checks

---
*Phase: 082-package-quality-and-documentation*
*Completed: 2026-04-28*
