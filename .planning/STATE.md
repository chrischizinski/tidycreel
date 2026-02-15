# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-14)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** Phase 15 - Mean-of-Ratios Estimator Core

## Current Position

Phase: 15 of 20 (Mean-of-Ratios Estimator Core)
Plan: 2 of 2 in current phase
Status: Complete
Last activity: 2026-02-15 — Completed 15-02 MOR diagnostic messaging

Progress: [█████████████░░░░░░░] 74% (27/36.7 plans estimated)

## Performance Metrics

**Velocity:**
- Total plans completed: 25
- v0.1.0 (Phases 1-7): 12 plans
- v0.2.0 (Phases 8-12): 10 plans
- v0.3.0 (Phases 13-20): 3 plans (in progress)

**By Milestone:**

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 | 1-7 | 12/12 | Complete | 2026-02-09 |
| v0.2.0 | 8-12 | 10/10 | Complete | 2026-02-11 |
| v0.3.0 | 13-20 | 5/TBD | In progress | - |

**Quality Metrics (v0.3.0 current):**
- Test coverage: TBD (718 tests)
- R CMD check: 0 errors, 0 warnings
- lintr: 0 issues

**Phase 13 Metrics:**

| Plan | Tasks | Duration | Tests Added | Files Modified | Completed |
|------|-------|----------|-------------|----------------|-----------|
| 13-01 | 2 | 17 min | 23 | 22 | 2026-02-14 |
| 13-02 | 2 | 6 min | 27 | 5 | 2026-02-14 |

**Phase 14 Metrics:**

| Plan | Tasks | Duration | Tests Added | Files Modified | Completed |
|------|-------|----------|-------------|----------------|-----------|
| 14-01 | 2 | 5 min | 7 | 2 | 2026-02-15 |

**Phase 15 Metrics:**

| Plan | Tasks | Duration | Tests Added | Files Modified | Completed |
|------|-------|----------|-------------|----------------|-----------|
| 15-01 | 2 | 11 min | 11 | 5 | 2026-02-15 |
| 15-02 | 2 | 6 min | 8 | 6 | 2026-02-15 |

## Accumulated Context

### Research Summary (v0.3.0 Planning Session)

**Key findings from literature and Colorado C-SAP:**
- Roving-access design (counts + complete trips only) is scientifically validated approach (Pollock et al.)
- Colorado C-SAP uses ONLY complete trips for estimation, requires ≥10% complete trip interviews
- Pooling complete + incomplete trips is statistically invalid (different sampling probabilities)
- Mean-of-ratios with truncation (20-30 min threshold) can work for incomplete trips BUT requires validation
- Incomplete trip interviews suffer from length-of-stay bias (longer trips oversampled)
- Nonstationary catch rates (catch rate changes during trip) cause bias in incomplete trip estimates

**Decision for v0.3.0:**
- Default to complete trips only (follows Colorado C-SAP best practice)
- Support incomplete trip estimation as diagnostic/research mode with clear warnings
- Never auto-pool complete + incomplete (scientifically invalid)

### Recent Decisions

- **Phase 15-02**: MOR class added BEFORE creel_estimates in class vector — Ensures S3 dispatch priority for custom format/print methods
- **Phase 15-02**: Warning issued on EVERY MOR call (not once-per-session) — Per CONTEXT.md locked decisions about diagnostic mode emphasis
- **Phase 15-01**: MOR uses survey::svymean() on individual catch/effort ratios (not svyratio) — Statistically appropriate for incomplete trip estimation
- **Phase 15-01**: MOR automatically filters to incomplete trips only — Ensures sample size validation and variance estimation use only incomplete trips
- **Phase 14-01**: Timezone validation only errors on explicit timezone mismatch — POSIXct handles system default mixed with explicit timezone correctly
- **Phase 14-01**: No code changes needed for overnight duration calculation — POSIXct difftime already handles overnight trips correctly
- **Phase 13-01**: trip_status is required parameter (breaking change) — Essential for downstream incomplete trip estimators
- **Phase 13-01**: Case-insensitive trip_status normalized to lowercase — Improves usability while maintaining data quality
- **Phase 13-01**: Mutually exclusive duration input methods — Prevents ambiguity and user error
- **Phase 12**: Coverage deviation accepted at 89.24% — Unreachable defensive error handling prevented by Tier 1 validation
- **Phase 11**: Manual delta method for product variance — Transparent formula Var(E×C) = E²·Var(C) + C²·Var(E)
- **Phase 10**: Shared validation for ratio estimators — validate_ratio_sample_size serves CPUE and harvest

See PROJECT.md Key Decisions table for complete history.

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.

## Session Continuity

Last session: 2026-02-15
Stopped at: Completed 15-02-PLAN.md (MOR diagnostic messaging and S3 class infrastructure)
Resume file: None

**Next step:** Phase 15 complete - proceed to Phase 16 (trip truncation) or pause for review
