---
phase: 21-bus-route-design-foundation
plan: 01
subsystem: creel-design
tags: [bus-route, creel-design, nonuniform-probability, sampling-frame, pi-i, rlang, tidyselect, cli]

# Dependency graph
requires:
  - phase: 20-incomplete-trips
    provides: creel_design S3 object structure and validate_creel_design() Tier 1 validation pattern
provides:
  - "creel_design(survey_type = 'bus_route') constructor accepting sampling_frame with p_site, p_period, circuit"
  - "Precomputed pi_i = p_site * p_period in bus_route$data$.pi_i at construction time"
  - "Tier 1 validation: p_site/p_period in (0,1], p_site sums to 1.0 per circuit (1e-6 tolerance)"
  - "bus_route slot in creel_design object: data, site_col, circuit_col, p_site_col, p_period_col, pi_i_col"
  - "Single-circuit default: .circuit = '.default' when circuit column omitted"
  - "Backward-compatible: existing instantaneous designs unchanged, bus_route = NULL"
affects:
  - phase: 21-bus-route-design-foundation (plan 02: tests for this constructor)
  - phase: 22-bus-route-design-validation
  - phase: 23-bus-route-data-integration
  - phase: 24-bus-route-estimation
  - phase: 25-bus-route-estimation-advanced

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "survey_type parameter defaults to design_type for backward compatibility"
    - "Bus_route slot stores resolved sampling frame + column name mappings as named list"
    - "p_period resolved by tryCatch: try column selector first, fall back to scalar numeric eval"
    - "Default circuit .default used when circuit column omitted (single-circuit shorthand)"
    - "nolint: object_usage_linter on cli interpolation variables (false positive pattern)"

key-files:
  created: []
  modified:
    - R/creel-design.R
    - man/creel_design.Rd

key-decisions:
  - "survey_type defaults to design_type to preserve backward compatibility (existing design_type = 'instantaneous' calls unchanged)"
  - "pi_i precomputed at construction time (not lazily at estimation), stored in bus_route$data$.pi_i"
  - "p_period resolved via tryCatch: column selector tried first, scalar numeric as fallback"
  - "Circuit column optional: omitting creates .circuit = '.default' for single-circuit designs"
  - "bus_route validation happens in validate_creel_design() after existing Tier 1 checks"

patterns-established:
  - "bus_route slot: list(data, site_col, circuit_col, p_site_col, p_period_col, pi_i_col) structure"
  - "Conditional site resolution: for bus_route, site selects from sampling_frame; for instantaneous, from calendar"

# Metrics
duration: 3min
completed: 2026-02-17
---

# Phase 21 Plan 01: Bus-Route Design Constructor Summary

**creel_design() extended with survey_type = 'bus_route' support: tidy selector API for sampling_frame, precomputed pi_i = p_site * p_period, Tier 1 validation for probability constraints per circuit**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-17T03:42:57Z
- **Completed:** 2026-02-17T03:46:39Z
- **Tasks:** 1 (single task plan)
- **Files modified:** 2

## Accomplishments

- Extended `creel_design()` to accept `survey_type = "bus_route"` with a `sampling_frame` data frame specifying sites, circuits, and sampling probabilities
- Implemented correct πᵢ = p_site × p_period computation at construction time (Jones & Pollock 2012 BUSRT-06/07)
- Added Tier 1 validation: `p_site`/`p_period` values must be in (0, 1]; `p_site` values must sum to 1.0 per circuit within 1e-6 floating-point tolerance
- All 935 existing tests continue to pass; 0 new linting issues; `devtools::check_man()` clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Add survey_type parameter and bus_route branch to creel_design()** - `6bd56d8` (feat)

## Files Created/Modified

- `/Users/cchizinski2/Dev/tidycreel/R/creel-design.R` - Extended creel_design() with bus_route branch, new_creel_design() bus_route slot, validate_creel_design() probability checks, updated roxygen docs
- `/Users/cchizinski2/Dev/tidycreel/man/creel_design.Rd` - Auto-generated from updated roxygen (new params, return value, examples, Tier 1 Validation section)

## Decisions Made

- **survey_type defaults to design_type**: `survey_type = design_type` in the function signature means all existing calls using `design_type = "instantaneous"` work unchanged. `survey_type` is the new canonical parameter.
- **p_period resolution via tryCatch**: The `p_period` argument is tried as a column selector first (via `resolve_single_col`). If that fails, it is evaluated as a scalar numeric. This allows both `p_period = my_col` (column) and `p_period = 0.5` (scalar) to work naturally without requiring users to know the difference.
- **pi_i precomputed at construction**: `pi_i = p_site * p_period` is computed during `creel_design()` and stored in `bus_route$data$.pi_i`, not lazily computed at estimation time. This follows the "fail fast" pattern of the existing design and ensures estimation functions have the correct probability already available.
- **circuit defaults to .default**: When the `circuit` parameter is omitted, the code adds a `.circuit` column with value `".default"` to all rows. This keeps the internal data structure consistent regardless of whether the user has single or multi-circuit designs.
- **bus_route slot is NULL for non-bus_route designs**: Clean null-check pattern; existing code that doesn't check for bus_route will never encounter the new field.

## Deviations from Plan

None - plan executed exactly as written.

The one minor auto-action was adding `# nolint: object_usage_linter` comments to suppress lintr false positives on `bad` variables used inside CLI string interpolation (`{bad}` in `cli_abort`). This is a standard tidycreel pattern used elsewhere in the codebase.

## Issues Encountered

- Pre-commit hook (`styler`) reformatted the `tryCatch` block from inline brace style to multi-line style after the first commit attempt. Staged and re-committed the styled file cleanly on the second attempt. All pre-commit hooks passed on the second commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `creel_design(survey_type = "bus_route")` constructor is complete and validated
- `design$bus_route$data$.pi_i` contains precomputed inclusion probabilities ready for Phase 22-24 estimators
- `design$bus_route$circuit_col`, `$site_col`, `$p_site_col`, `$p_period_col` provide the resolved column mapping for downstream use
- Phase 22 (bus-route validation tests) can now write tests against this constructor
- Phase 23 (data integration: `add_interviews` with enumeration counts) needs `bus_route$data` to join interview records to their circuit probabilities

---
*Phase: 21-bus-route-design-foundation*
*Completed: 2026-02-17*
