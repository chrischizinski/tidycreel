---
phase: 74-quality-bar-assessment
plan: "02"
subsystem: testing
tags: [testthat, snapshot, property-based, quickcheck, vdiffr, expect_snapshot]

requires:
  - phase: 74-quality-bar-assessment
    provides: 74-RESEARCH.md with test infrastructure state, domain invariants, pitfalls, and contributor-facing context

provides:
  - "74-TESTING-STRATEGY.md: contributor decision guide for choosing test type in tidycreel"
  - "Explicit snapshot policy: use for formatted text output, never for numeric estimates"
  - "6 property-based domain invariants named and assessed for quickcheck implementation"
  - "Integration test pattern named and codified"
  - "_snaps/ gap (zero expect_snapshot() calls) documented with 6 priority methods"
  - "Named condition class testing guidance with cross-reference to 74-QUALITY-AUDIT.md"

affects:
  - "74-quality-bar-assessment (74-01-PLAN produces QUALITY-AUDIT.md that this cross-references)"
  - "Future Phase 75 or v1.4.0 snapshot adoption and property-based testing phases"
  - "Any contributor adding print/format/autoplot tests"

tech-stack:
  added: []
  patterns:
    - "Snapshot policy: expect_snapshot() for formatted text output only; tolerance-based expect_equal() for numeric estimates"
    - "Property-based testing recommendation: quickcheck (CRAN, hedgehog wrapper) not rapidcheck (C++ only)"
    - "Integration test pattern: design construction -> add_counts -> estimate -> assert with tolerance"

key-files:
  created:
    - ".planning/phases/74-quality-bar-assessment/74-TESTING-STRATEGY.md"
  modified: []

key-decisions:
  - "Phase 74 testing strategy: snapshot policy is explicit rule (not suggestion) — formatted text output only, never numeric estimates"
  - "Property-based testing implementation deferred to Phase 75 or v1.4.0; 6 invariants documented as specification"
  - "quickcheck is the R property-based testing package (wraps hedgehog, CRAN); rapidcheck is C++ only and cannot be used from R"
  - "Named condition class testing guidance cross-references 74-QUALITY-AUDIT.md; no action until named classes are implemented"

patterns-established:
  - "Testing decision guide format: each test type has WHEN/WHEN NOT/pattern/examples"
  - "Positive findings documented alongside gaps (P1-P5 preserved patterns)"
  - "Pitfalls section with warning signs and prevention guidance"
  - "Recommendations consolidated at end with WHAT/WHY/priority/slot"

requirements-completed: []

duration: 2min
completed: 2026-04-18
---

# Phase 74 Plan 02: Testing Strategy Summary

**Contributor decision guide for tidycreel v1.3.0 testing — snapshot policy, 6 property-based domain invariants, and integration test pattern codified**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-18T17:02:06Z
- **Completed:** 2026-04-18T17:04:37Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Wrote complete 74-TESTING-STRATEGY.md as a contributor decision guide covering all four test types (unit, snapshot, integration, property-based)
- Stated explicit snapshot policy as a rule: use `expect_snapshot()` for formatted text output only, never for numeric estimates; documented the `_snaps/` empty-but-present gap and 6 priority adoption methods
- Listed 6 property-based domain invariants for creel estimation and assessed quickcheck as the R implementation package (not rapidcheck which is C++ only); recommended Phase 75 or v1.4.0 for implementation
- Named and codified the integration test pattern already in use throughout the codebase
- Cross-referenced 74-QUALITY-AUDIT.md for named condition class guidance with before/after code examples
- Documented 5 positive infrastructure findings (P1-P5) and 4 common pitfalls with prevention guidance
- Produced prioritised recommendations R1-R5 with WHAT, WHY, priority, and implementation slot

## Task Commits

1. **Task 1: Write 74-TESTING-STRATEGY.md** - `98e1766` (docs)

## Files Created/Modified

- `.planning/phases/74-quality-bar-assessment/74-TESTING-STRATEGY.md` - Complete external testing strategy and contributor decision guide

## Decisions Made

- Snapshot policy stated as explicit package-wide rule (not a suggestion): `expect_snapshot()` for formatted text output only; tolerance-based `expect_equal()` for all numeric quantities
- Property-based testing implementation deferred to Phase 75 or v1.4.0; invariants documented now as specification for future implementation
- `quickcheck` (CRAN, wraps hedgehog) identified as the R property-based testing package; `rapidcheck` is C++ only and has no R interface
- Named condition class testing guidance limited to cross-reference and before/after code example; no action until 74-QUALITY-AUDIT.md R4 is implemented

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Document-only phase.

## Next Phase Readiness

- 74-TESTING-STRATEGY.md is complete and usable as a contributor decision guide
- 74-01-PLAN (QUALITY-AUDIT.md) is the sibling plan in this phase; it can be executed independently
- Phase 75 or v1.4.0 snapshot adoption phase has a concrete starting point (6 priority methods listed in Section 2.2)
- Property-based testing has a concrete specification (6 invariants) ready for implementation

---
*Phase: 74-quality-bar-assessment*
*Completed: 2026-04-18*
