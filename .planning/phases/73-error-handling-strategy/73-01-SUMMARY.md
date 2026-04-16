---
phase: 73-error-handling-strategy
plan: 01
subsystem: documentation
tags: [cli, rlang, error-handling, strategy, contributor-guide]

# Dependency graph
requires:
  - phase: 73-error-handling-strategy
    provides: "73-RESEARCH.md with complete source-based findings on error patterns and deviations"
provides:
  - "73-ERROR-STRATEGY.md declaring cli::cli_abort named-vector pattern as tidycreel canonical standard"
  - "Complete deviation inventory (D1-D4) with classifications and dispositions"
  - "Phase 74 baseline: canonical pattern reference for quality audit"
affects: [74-quality-audit, contributor-guide, code-review]

# Tech tracking
tech-stack:
  added: []
  patterns: ["cli::cli_abort named-vector convention declared canonical", "rlang::caller_env propagation pattern documented", "checkmate batch-collection validation pattern documented"]

key-files:
  created:
    - ".planning/phases/73-error-handling-strategy/73-ERROR-STRATEGY.md"
  modified: []

key-decisions:
  - "cli::cli_abort(c(unnamed-summary, x=problem, i=suggestion)) declared canonical tidycreel error handling pattern (368 call-sites, 30+ files)"
  - "D1/D2: stop(e) tryCatch re-raises are intentional idioms — must not be converted to cli_abort (would lose original condition class)"
  - "D3: rlang::warn(.frequency='once') is an approved exception — .frequency throttle not available in cli::cli_warn"
  - "D4: split-argument cli::cli_warn in validation-report.R is cosmetic, lowest priority"
  - "Named condition classes deferred to Phase 74 quality audit"

patterns-established:
  - "Canonical cli_abort: unnamed summary + x=problem + i=suggestion named vector"
  - "Caller-env propagation: error_call = rlang::caller_env() in internal helpers, passed down from public API"
  - "Batch-collection validation: checkmate collection before single cli_abort with complete failure list"

requirements-completed: []

# Metrics
duration: 12min
completed: 2026-04-15
---

# Phase 73 Plan 01: Error Handling Strategy Summary

**`cli::cli_abort` named-vector pattern declared canonical for tidycreel, with complete deviation inventory (D1-D4), approved exceptions documented, and Phase 74 baseline established**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-16T02:56:45Z
- **Completed:** 2026-04-16T03:08:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Declared `cli::cli_abort(c(...))` with the unnamed-summary / `"x"` = problem / `"i"` = suggestion named-vector structure as the tidycreel canonical error handling standard (368 call-sites across 30+ files)
- Documented all four deviations from canonical pattern with classifications: two intentional tryCatch re-raises (D1, D2), one approved exception for `.frequency` throttle (D3), one cosmetic deviation (D4)
- Explained the critical distinction between `stop(e)` re-raise (correct R idiom) and bare `stop("message")` guard (anti-pattern), preventing future "fix" regressions
- Documented caller-environment propagation pattern and batch-collection validation pattern as second and third canonical patterns
- Consolidated four low-priority recommendations (R1-R4) with WHAT/WHY/priority; explicitly deferred named condition classes to Phase 74

## Task Commits

1. **Task 1: Write 73-ERROR-STRATEGY.md** - `27a3788` (docs)

## Files Created/Modified

- `.planning/phases/73-error-handling-strategy/73-ERROR-STRATEGY.md` — Complete error handling strategy: canonical pattern declaration with copy-paste example, caller-env pattern, batch-collection pattern, deviation inventory D1-D4, stopifnot note, positive findings P1-P4, recommendations R1-R4

## Decisions Made

- `cli::cli_abort` named-vector convention is the tidycreel standard; contributors should copy the reference example in the document
- D1 and D2 (`stop(e)` re-raises) are explicitly classified as intentional — document explicitly distinguishes them from the bare `stop("message")` anti-pattern to prevent future misclassification
- D3 (`rlang::warn(.frequency = "once")`) is an approved exception because `cli::cli_warn` does not support `.frequency` — replacing it would silently lose the once-per-session suppression behavior
- Named condition classes are out of scope for Phase 73 and explicitly deferred to Phase 74

## Deviations from Plan

None — plan executed exactly as written. All eight document sections specified in the plan are present in the output document. The copy-paste example, deviation inventory, positive findings, and recommendations all match the plan specification.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 74 quality audit has a clear baseline: the canonical pattern is declared, all four deviations are classified, and Section 7 of the strategy document explicitly maps what Phase 74 inherits
- The strategy document can be linked directly from contributor documentation or CONTRIBUTING.md when that is created
- No blockers

---
*Phase: 73-error-handling-strategy*
*Completed: 2026-04-15*
