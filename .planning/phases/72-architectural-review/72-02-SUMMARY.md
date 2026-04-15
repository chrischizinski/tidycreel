---
phase: 72-architectural-review
plan: "02"
subsystem: documentation
tags: [dependency-review, r-package, imports, scales, lubridate, ggplot2]

# Dependency graph
requires:
  - phase: 72-architectural-review
    provides: 72-RESEARCH.md with full call-site counts and dependency health assessments for all 11 Imports
provides:
  - "72-DEP-REVIEW.md: complete dependency review report for tidycreel v1.3.0 Imports"
affects: [future roadmap phases, package maintainers, CRAN submission planning]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Drop vs demote framing: 'drop' = remove from Imports entirely; 'demote' = move to Suggests with check_installed() guards"
    - "Single-call Import elimination: scales::percent() → sprintf() is the canonical example of this pattern"

key-files:
  created:
    - .planning/phases/72-architectural-review/72-DEP-REVIEW.md
  modified: []

key-decisions:
  - "scales is a DROP candidate: replace single scales::percent() call in survey-bridge.R line 1533 with sprintf('%.1f%%', pct_truncated * 100)"
  - "lubridate is a DEMOTE candidate: all 15 call-sites in scheduling/viz layers; fold removal into next scheduling refactor"
  - "ggplot2 demotion requires an explicit architectural decision: is visualisation core or optional? Document the answer."
  - "checkmate mixed-validation pattern is intentional (batch collection semantics) — document for contributors, not a bug"

patterns-established:
  - "Dependency risk rated on four axes: abandonment risk, API instability, transitive chain weight, version floor tightness"
  - "All 11 Imports assessed with explicit drop/demote verdicts and rationale"

requirements-completed: []

# Metrics
duration: 4min
completed: 2026-04-15
---

# Phase 72 Plan 02: Dependency Review Summary

**Complete dependency review report documenting all 11 tidycreel v1.3.0 Imports with risk ratings, drop/demote verdicts, and four prioritised recommendations including immediate `scales` elimination via one-line `sprintf()` replacement**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-15T20:45:27Z
- **Completed:** 2026-04-15T20:48:45Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Wrote complete 396-line dependency review report covering all 11 Imports-only packages
- Risk summary table with call-site counts, file counts, risk ratings, and explicit drop/demote verdicts for all 11 packages
- Drop/demote analysis section covering the three actionable candidates: `scales` (drop), `lubridate` (demote), `ggplot2` (demote/architectural decision)
- Four recommendations with WHAT/WHY/priority — `scales` drop marked highest priority with exact code replacement

## Task Commits

1. **Task 1: Write 72-DEP-REVIEW.md** — `d44b78c` (docs)

**Plan metadata:** (pending final commit)

## Files Created/Modified

- `.planning/phases/72-architectural-review/72-DEP-REVIEW.md` — Full dependency review report: executive summary, risk criteria, dependency inventory (11 packages), risk summary table, drop/demote analysis, positive findings, four recommendations

## Decisions Made

- `scales` is a clear DROP: a single `scales::percent()` call at `survey-bridge.R` line 1533 can be replaced with `sprintf("%.1f%%", pct_truncated * 100)`, eliminating one Import entirely
- `lubridate` demotion is medium priority: all 15 call-sites in scheduling/viz; base R equivalents exist but require ~15 careful substitutions; fold into next scheduling refactor
- `ggplot2` demotion requires an explicit architectural decision about whether visualisation is core or optional to the package; both options are valid but the choice should be documented
- `checkmate` mixed-validation pattern is intentional (batch collection semantics in `validate_br_interviews_tier3()` and `validate_ice_interviews_tier3()`) — worth documenting for contributors, not a defect

## Deviations from Plan

None — plan executed exactly as written. All required sections are present in the document. All 11 Imports covered. Three drop/demote candidates analysed. Four recommendations with WHAT/WHY/priority in consolidated section.

## Issues Encountered

`.planning/` directory is gitignored; `72-DEP-REVIEW.md` required `git add -f` to stage, consistent with how all other planning artifacts in this phase were committed.

## User Setup Required

None — no external service configuration required. This plan produces only a planning artifact document.

## Next Phase Readiness

- `72-DEP-REVIEW.md` is complete and ready for use in future roadmap planning
- Highest-priority actionable item (R1: drop `scales`) is ready to implement — one-line change in `survey-bridge.R`
- Phase 72 architectural review is now complete: both `72-ARCH-REVIEW.md` (plan 72-01) and `72-DEP-REVIEW.md` (plan 72-02) delivered

---
*Phase: 72-architectural-review*
*Completed: 2026-04-15*
