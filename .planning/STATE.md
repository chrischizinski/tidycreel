# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-30)

**Core value:** Creel biologists work in domain vocabulary without understanding survey statistics
**Current focus:** Phase 4 - Basic Estimation

## Current Position

Phase: 4 of 7 (Basic Estimation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-02-08 — Phase 3 complete and verified

Progress: [██████░░░░] 43%

## Performance Metrics

**Velocity:**
- Total plans completed: 7
- Average duration: 126 min (note: 02-01 includes system pauses)
- Total execution time: 15.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | 21 min | 7 min |
| 02 | 2 | 844 min* | 422 min |
| 03 | 2 | 9 min | 4.5 min |

*Note: 02-01 wall-clock time includes system pauses; actual work ~30-40 min; 02-02 actual work ~4 min

**Recent Trend:**
- Last 3 plans: 02-02 (4 min), 03-01 (5 min), 03-02 (4 min)
- Trend: TDD plans with clear specs execute quickly; Phase 3 completed in 9 min total

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

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-02-09
Stopped at: Completed 03-02-PLAN.md - as_survey_design() escape hatch for power users
Resume file: None
