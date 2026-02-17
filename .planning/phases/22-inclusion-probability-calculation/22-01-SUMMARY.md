---
phase: 22-inclusion-probability-calculation
plan: 01
subsystem: creel-design
tags: [bus-route, inclusion-probability, validation, pi_i, p_period, jones-pollock]

# Dependency graph
requires:
  - phase: 21-bus-route-design-foundation
    provides: creel_design() with bus_route slot, validate_creel_design(), get_sampling_frame()

provides:
  - p_period uniformity check in validate_creel_design() (tolerance 1e-10, per circuit)
  - Defensive pi_i range check in validate_creel_design() (must be in (0,1])
  - get_inclusion_probs(design) exported function returning site/circuit/.pi_i data frame
  - @references Jones & Pollock (2012) in creel_design() and get_inclusion_probs() roxygen
  - man/get_inclusion_probs.Rd and NAMESPACE export

affects:
  - 23-data-integration
  - 24-effort-estimation
  - 25-harvest-estimation
  - 26-validation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "p_period uniformity validated per circuit with tolerance 1e-10 (not 1e-6)"
    - "Defensive pi_i range check after probability computation: abort if out of (0,1]"
    - "get_inclusion_probs() follows exact same guard pattern as get_sampling_frame()"
    - "Inline min/max variables to satisfy 120-char line length limit in error messages"

key-files:
  created:
    - man/get_inclusion_probs.Rd
  modified:
    - R/creel-design.R
    - NAMESPACE
    - man/creel_design.Rd

key-decisions:
  - "p_period uniformity tolerance is 1e-10 (tighter than p_site sum tolerance of 1e-6) because p_period should be exactly identical within a circuit"
  - "Defensive pi_i range check placed after all validation in bus_route block so it always runs last"
  - "get_inclusion_probs() returns only 3 columns (site, circuit, .pi_i), not full sampling frame - clean API for downstream estimation"

patterns-established:
  - "Accessor functions for bus-route components follow get_sampling_frame() guard pattern"
  - "Long cli_abort error messages split into inline variables to satisfy line-length linter"

# Metrics
duration: 4min
completed: 2026-02-17
---

# Phase 22 Plan 01: Inclusion Probability Calculation Summary

**p_period uniformity validation, defensive pi_i range check, and get_inclusion_probs() accessor added to bus-route design infrastructure**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-17T04:27:45Z
- **Completed:** 2026-02-17T04:31:44Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added p_period must-be-constant-within-circuit validation to `validate_creel_design()` (tolerance 1e-10) — ensures the statistical requirement that p_period represents a circuit-level probability, not site-level
- Added defensive pi_i range check: aborts if any `.pi_i` value falls outside (0, 1] after computation
- Added `get_inclusion_probs()` exported accessor returning a clean 3-column data frame (site, circuit, .pi_i) for downstream estimation
- Added `@references` Jones & Pollock (2012) to `creel_design()` and `get_inclusion_probs()` roxygen docs
- 0 errors, 0 warnings in R CMD check; 0 lint issues

## Task Commits

Each task was committed atomically:

1. **Task 1: p_period uniformity validation and pi_i range check** - `f66bd1e` (feat)
2. **Task 2: get_inclusion_probs() exported accessor function** - `c74aac4` (feat)

## Files Created/Modified
- `R/creel-design.R` - Added p_period uniformity block and pi_i range check in `validate_creel_design()`; added `get_inclusion_probs()` function after `get_sampling_frame()`; added `@references` and Tier 1 Validation bullet to `creel_design()` roxygen
- `NAMESPACE` - Added `export(get_inclusion_probs)`
- `man/creel_design.Rd` - Regenerated with @references and new Tier 1 Validation bullet
- `man/get_inclusion_probs.Rd` - Created by devtools::document()

## Decisions Made
- p_period uniformity tolerance is 1e-10 (tighter than p_site sum tolerance of 1e-6) because p_period within a circuit should be truly identical, not just approximately equal
- `get_inclusion_probs()` returns only 3 columns — clean minimal API that gives downstream estimation exactly what it needs without exposing full sampling frame internals
- Long error message string split via inline variables (`p_min`/`p_max`) to satisfy the 120-character line length lint rule

## Deviations from Plan

**1. [Rule 1 - Bug] Lint fix: long line in error message split into inline variables**
- **Found during:** Task 1 (p_period uniformity validation)
- **Issue:** The cli_abort error message showing `min={round(min(circ_p_period), 8)}, max={round(max(circ_p_period), 8)}` was 153 characters — exceeded the 120-char limit enforced by `lintr::lint_package()`
- **Fix:** Extracted `p_min` and `p_max` as inline variables before the `cli::cli_abort()` call; decorated with `# nolint: object_usage_linter` since they're used inside glue strings
- **Files modified:** R/creel-design.R
- **Verification:** `lintr::lint_package()` returned 0 issues after fix
- **Committed in:** f66bd1e (Task 1 commit)

**2. [Rule 1 - Bug] roxygen @references square brackets misinterpreted as \link[]{}**
- **Found during:** Task 1 (creel_design() roxygen @references)
- **Issue:** Square bracket notation `[Eq. 19.4...]` in @references was being interpreted by roxygen2 as a cross-reference link, producing "Bad \link option" in check_man()
- **Fix:** Removed brackets; used plain prose with `\eqn{}` for the equation. Produces clean Rd with no issues.
- **Files modified:** R/creel-design.R, man/creel_design.Rd
- **Verification:** `devtools::check_man()` reported no issues
- **Committed in:** f66bd1e (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes required for lint compliance and clean documentation. No scope creep.

## Issues Encountered
- Pre-commit styler reformatted the `get_inclusion_probs()` example in roxygen (split the `creel_design(cal, ...)` call across lines). Re-staged and committed successfully on second attempt.

## Next Phase Readiness
- `get_inclusion_probs()` is ready for use by Phase 23 (data integration) and Phase 24-25 (estimation)
- Validation infrastructure is complete: p_site range, p_period range, p_site sum per circuit, p_period uniformity per circuit, pi_i range
- No blockers

## Self-Check: PASSED

- FOUND: R/creel-design.R
- FOUND: NAMESPACE
- FOUND: man/get_inclusion_probs.Rd
- FOUND: man/creel_design.Rd
- FOUND: .planning/phases/22-inclusion-probability-calculation/22-01-SUMMARY.md
- FOUND commit: f66bd1e (Task 1)
- FOUND commit: c74aac4 (Task 2)

---
*Phase: 22-inclusion-probability-calculation*
*Completed: 2026-02-17*
