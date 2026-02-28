# Legacy Constructor Removal

## What This Is

Completing the legacy constructor removal work in the tidycreel R package by deleting deprecated function stubs and cleaning up archived code, preparing the phase2/remove-legacy-constructors branch for merge to main.

## Core Value

Clean API with no legacy baggage - only the new `est_*()` functions exposed to users, with no confusing deprecated stubs in NAMESPACE.

## Requirements

### Validated

- ✓ New API functions exist and work (`est_effort()`, `est_cpue()`, `est_catch()`) — existing
- ✓ Architectural standards documented — existing
- ✓ Comprehensive test suite in place — existing

### Active

- [ ] Remove deprecated function stubs from `R/estimators.R` (`estimate_effort()`, `estimate_cpue()`, `estimate_harvest()`)
- [ ] Clean up NAMESPACE (remove old function exports)
- [ ] Delete `old_code/` directory and archived files
- [ ] Verify all tests still pass after removal
- [ ] Run R CMD check with no errors or warnings
- [ ] Ensure branch is ready to merge to main

### Out of Scope

- Addressing other technical debt (variance file complexity, zero-effort handling) — future work
- Adding new features or estimation methods — future work
- Deprecation warnings or migration vignettes — not needed, never released

## Context

**Codebase state:**
- Mature R package for creel survey analysis (design-based survey estimation)
- Branch: `phase2/remove-legacy-constructors`
- Old API used `estimate_*()` naming, new API uses `est_*()` naming
- Deprecated stubs exist in `R/estimators.R` that immediately abort with redirect messages
- `old_code/` directory contains 100KB+ of archived code from previous development phases

**Why this matters:**
- Package has never been publicly released, so no backward compatibility concerns
- Clean removal prevents confusion in NAMESPACE and documentation
- Removes dead code that could confuse future contributors

**Existing architecture:**
- Layered survey analysis framework with strict separation of concerns
- Single source of truth for variance via `tc_compute_variance()`
- Schema-driven data validation
- Comprehensive test coverage with testthat edition 3

## Constraints

- **R package standards**: Must pass R CMD check with no errors/warnings
- **Test coverage**: Must maintain existing test coverage (1%+ threshold, aim for high coverage on core functions)
- **Architectural compliance**: Must follow patterns documented in `ARCHITECTURAL_STANDARDS.md`
- **Timeline**: None - work at sustainable pace

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Remove deprecated stubs completely | Package never released, no users to migrate | — Pending |
| Clean old_code/ directory | Dead code confuses contributors, takes up space | — Pending |
| No deprecation cycle | No public users exist yet | — Pending |

---
*Last updated: 2026-01-27 after initialization*
