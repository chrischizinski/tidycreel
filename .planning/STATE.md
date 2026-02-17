# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.4.0 Bus-Route Survey Support

## Current Position

Phase: 21 of 27 (Bus-Route Design Foundation)
Plan: 2 complete
Status: In progress — Phase 21 Plan 02 complete
Last activity: 2026-02-17 — Phase 21 Plan 02 (format.creel_design Bus-Route section + get_sampling_frame + tests) complete

Progress: [████████████░░░░░░░░] 60% (39/65+ plans complete across all milestones)

## Performance Metrics

**Velocity:**
- Total plans completed: 39
- v0.1.0 (Phases 1-7): 12 plans
- v0.2.0 (Phases 8-12): 10 plans
- v0.3.0 (Phases 13-20): 16 plans
- v0.4.0 (Phases 21-27): 1 plan

**By Milestone:**

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 | 1-7 | 12/12 | Complete | 2026-02-09 |
| v0.2.0 | 8-12 | 10/10 | Complete | 2026-02-11 |
| v0.3.0 | 13-20 | 16/16 | Complete | 2026-02-16 |
| v0.4.0 | 21-27 | 2/TBD | In progress | - |

**Quality Metrics (current):**
- Test coverage: ~90% (972 tests)
- R CMD check: 0 errors, 0 warnings
- lintr: 0 issues

## Accumulated Context

### v0.4.0 Bus-Route Survey Support

**Milestone Goal:** Implement statistically correct bus-route (nonuniform probability) creel survey estimation based on primary source methodology from Jones & Pollock (2012) and Malvestuto et al. (1978).

**Critical Insight from Primary Source Analysis:**
All existing R implementations (Pope, AnglerCreelSurveySimulation, Su & Liu) fundamentally misunderstand what πᵢ (inclusion probability) represents. They treat it as "interview probability" or "site characteristics" when it is actually the inclusion probability determined by the sampling design.

**Key Implementation Requirements:**
1. πᵢ = p_site × p_period (from sampling design, NOT site characteristics)
2. Enumeration expansion (n_counted / n_interviewed) — missing from ALL existing code
3. Jones & Pollock (2012) Eq. 19.4-19.5 exact implementation
4. Validation against Malvestuto (1996) Box 20.6 published examples

**tidycreel will be the ONLY R package with correct bus-route estimation.**

### Phase Structure (7 phases, 21 requirements)

**Phase 21-22: Foundation (BUSRT-06, BUSRT-07, BUSRT-01, BUSRT-05, VALID-03)**
- Bus-route design constructor with nonuniform probabilities
- Correct πᵢ calculation from sampling design

**Phase 23: Data Integration (BUSRT-08, BUSRT-02, VALID-04)**
- Interview data with enumeration counts
- Progressive validation

**Phase 24-25: Estimation (BUSRT-03, BUSRT-04, BUSRT-09, BUSRT-10, BUSRT-11)**
- Effort and harvest estimators following primary sources exactly
- Dispatch logic for bus-route designs

**Phase 26: Validation (VALID-01, VALID-02, VALID-05)**
- Reproduce Malvestuto Box 20.6 exactly
- Integration testing

**Phase 27: Documentation (DOCS-01 to DOCS-05)**
- Comprehensive vignette
- Equation traceability mapping

### Recent Decisions

See PROJECT.md Key Decisions table for complete history. Recent decisions from v0.3.0:

- **Phase 19**: TOST equivalence testing chosen for incomplete trip validation (standard bioequivalence approach)
- **Phase 17**: Complete trip defaults following Colorado C-SAP best practices
- **Phase 15**: MOR uses survey::svymean on individual ratios (statistically appropriate for incomplete trips)
- **Phase 13**: trip_status required parameter (breaking change for downstream estimators)

v0.4.0 decisions:

- **Phase 21-01**: survey_type defaults to design_type for backward compatibility; pi_i precomputed at construction time (not lazily); p_period resolved via tryCatch (column selector first, scalar fallback); circuit defaults to .default when omitted; bus_route slot is NULL for non-bus_route designs
- **Phase 21-02**: Bus-Route section placed after Interviews block in format.creel_design(); 10-row truncation cap for print output; get_sampling_frame() placed after print.creel_design() for method grouping; test helpers make_br_sf/make_br_cal defined at section scope

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.

## Session Continuity

Last session: 2026-02-17
Stopped at: Phase 21 Plan 02 complete — format.creel_design Bus-Route section, get_sampling_frame(), and tests
Resume file: None

**Next step:** Continue Phase 21 Plan 03 (if exists) or Phase 22

---
*State last updated: 2026-02-17 after Phase 21 Plan 02 complete*
