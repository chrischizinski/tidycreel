# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Creel biologists work in domain vocabulary without understanding survey statistics
**Current focus:** Phase 6 complete — ready for Phase 7 (Polish & Documentation)

## Current Position

Phase: 6 of 7 (Variance Methods)
Plan: 1 of 1 in current phase
Status: Phase 6 complete
Last activity: 2026-02-09 — Completed Phase 6 (variance method selection with bootstrap/jackknife)

Progress: [█████████░] 86%

## Performance Metrics

**Velocity:**
- Total plans completed: 10
- Average duration: 93 min (note: 02-01 includes system pauses)
- Total execution time: 15.5 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | 21 min | 7 min |
| 02 | 2 | 844 min* | 422 min |
| 03 | 2 | 9 min | 4.5 min |
| 04 | 1 | 11 min | 11 min |
| 05 | 1 | 8 min | 8 min |
| 06 | 1 | 14 min | 14 min |

*Note: 02-01 wall-clock time includes system pauses; actual work ~30-40 min; 02-02 actual work ~4 min

**Recent Trend:**
- Last 3 plans: 04-01 (11 min), 05-01 (8 min), 06-01 (14 min)
- Trend: TDD with comprehensive reference tests continues to execute efficiently; Phase 6 Plan 1 completed in 14 min

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Three-layer architecture (API → Orchestration → Survey): Separates domain translation from statistics
- Design-centric API: Everything flows through creel_design object
- Start from empty package: Clean slate faster than refactoring v1
- Build instantaneous counts first: Simplest design type proves architecture

**From 01-01:**
- Minimal Phase 1 dependencies only (checkmate, cli, rlang) - other packages added incrementally
- Placeholder test prevents testthat errors in empty package
- V1 development artifacts excluded via .Rbuildignore rather than deleted
- Removed Maintainer field from DESCRIPTION (auto-generated from Authors@R)

**From 01-02:**
- Use main branch of lorenzwalthert/precommit to avoid digest 0.6.36 compilation errors
- Exclude scripts/ and renv/ from pre-commit lint and dependency checks
- Tidyverse style defaults with 120-char line length for all package code
- GitHub Actions triggers on both main and v2-foundation branches for CI/CD

**From 01-03:**
- TDD pattern established (RED-GREEN commits) for tidycreel v2 development
- Schema validators are internal (@keywords internal, @noRd) - not exported
- Validators check structure/types only, not column names (tidy selectors in later phases)
- checkmate::makeAssertCollection used to accumulate all errors before aborting
- cli::cli_abort provides formatted error messages with bullets

**From 02-01:**
- Layered validation (schema → tidyselect → Tier 1) works correctly and catches errors at appropriate level
- nolint comments needed for cli glue variables (false positives from lintr object_usage_linter)
- tidyselect added to Imports for tidy column selection API
- creel_design S3 class uses constructor/validator/helper pattern from Advanced R
- cli::cli_format_method() provides rich formatted output for print methods

**From 02-02:**
- Internal constructors (new_*) marked @keywords internal @noRd - not user-facing yet
- creel_validation$passed computed automatically - TRUE only when all checks have status="pass"
- S3 class pattern: new_* constructor with stopifnot validation, format using cli, print calling format
- TDD RED → GREEN → REFACTOR pattern produces clean, well-tested code efficiently

**From 03-01:**
- PSU column specified in add_counts() only, not creel_design() - PSU is meaningful only when count data present
- Eager survey construction catches design errors when user has context about data being added
- Lonely PSU errors deferred to estimation phase - survey::svydesign() only errors during variance computation
- Multiple strata combined via interaction() to create single stratification factor
- Domain error wrapping: survey package errors wrapped with cli::cli_abort and domain-specific guidance

**From 03-02:**
- Once-per-session warnings use rlang::warn with .frequency = "once" and .frequency_id for scoping
- R's copy-on-modify semantics provide mutation protection without explicit deep copy
- Escape hatches for power users include educational warnings about recommended alternatives
- Integration tests compare tidycreel output with manual survey package construction to verify correctness

**From 04-01:**
- Count variable auto-detected as first numeric column excluding design metadata (date, strata, PSU)
- Tier 2 validation issues warnings (not errors) for data quality problems: zero/negative values, sparse strata
- Survey package "no weights" warnings suppressed - expected behavior for equal-probability-within-strata designs
- Phase 4 hardcodes Taylor linearization variance - bootstrap/jackknife deferred to Phase 6
- Reference tests verify tidycreel estimates match manual survey::svytotal with tolerance = 1e-10

**From 05-01:**
- Grouped estimation uses survey::svyby() internally for correct domain variance (not naive subsetting)
- by = parameter accepts tidy selectors: bare names, c(), starts_with() and other tidyselect helpers
- Routing logic: quo_is_null(by_quo) → estimate_effort_total() vs estimate_effort_grouped()
- Grouped results have group columns first, then estimate/se/ci_lower/ci_upper/n (dplyr-like structure)
- keep.names = FALSE in svyby() produces consistent column names: se, ci_l, ci_u (not se.var_name)
- Tier 2 validation extended for groups: warns if any group has < 3 observations (sparse groups)
- Reference tests with tolerance = 1e-10 verify grouped estimates match manual survey::svyby() exactly
- Phase 5 maintains perfect backward compatibility: estimate_effort(design) works identically to Phase 4

**From 06-01:**
- estimate_effort() gains variance parameter with values "taylor" (default), "bootstrap", "jackknife"
- get_variance_design() internal helper converts designs for bootstrap/jackknife via as.svrepdesign()
- Bootstrap uses 500 replicates (fixed, no user-facing parameter) per research recommendation
- Jackknife uses type="auto" (survey package selects JKn vs JK1 based on design)
- Taylor remains default (appropriate for most smooth statistics, backward compatible)
- variance_method parameter flows through estimate_effort() → internal functions → new_creel_estimates()
- Bootstrap and jackknife work with grouped estimation (same svyby routing)
- Reference tests verify bootstrap/jackknife match manual survey package calculations (tolerance 1e-10)
- Pre-existing Rd warnings from Phase 4 persist (known issue, does not affect functionality)

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-02-09
Stopped at: Completed 06-01-PLAN.md - variance method selection (bootstrap, jackknife) via as.svrepdesign()
Resume file: None
