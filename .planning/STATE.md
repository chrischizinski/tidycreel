# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.4.0 Bus-Route Survey Support

## Current Position

Phase: 23 of 27 (Data Integration)
Plan: 1 complete
Status: In progress — Phase 23 Plan 01 complete
Last activity: 2026-02-17 — Phase 23 Plan 01 (add_interviews() extended with n_counted/n_interviewed selectors, Tier 3 validation, pi_i join, .expansion computation) complete

Progress: [████████████░░░░░░░░] 64% (42/65+ plans complete across all milestones)

## Performance Metrics

**Velocity:**
- Total plans completed: 42
- v0.1.0 (Phases 1-7): 12 plans
- v0.2.0 (Phases 8-12): 10 plans
- v0.3.0 (Phases 13-20): 16 plans
- v0.4.0 (Phases 21-27): 4 plans

**By Milestone:**

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 | 1-7 | 12/12 | Complete | 2026-02-09 |
| v0.2.0 | 8-12 | 10/10 | Complete | 2026-02-11 |
| v0.3.0 | 13-20 | 16/16 | Complete | 2026-02-16 |
| v0.4.0 | 21-27 | 4/TBD | In progress | - |

**Quality Metrics (current):**
- Test coverage: ~90% (1000 tests)
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
- **Phase 22-01**: p_period uniformity tolerance is 1e-10 (tighter than p_site sum 1e-6) because p_period within a circuit must be identical; get_inclusion_probs() returns only 3 columns (site, circuit, .pi_i) for clean minimal API; long cli_abort error messages split via inline variables for lint compliance
- **Phase 22-02**: CLI {.cls} formatting adds angle brackets around class names in error messages — use partial "must be a" pattern not exact "must be a creel_design object" in expect_error(); make_br_sf_2circuit() defined at section scope for multi-circuit test helper locality
- **Phase 23-01**: validate_br_interviews_tier3 shortened from validate_bus_route_interviews_tier3 (36 chars) to 28 chars for lintr object_length_linter compliance; n_interviewed = 0 rows produce NA expansion (not error), warn only when n_counted > 0 and n_interviewed = 0; unmatched site+circuit causes hard error listing specific combos

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.

## Session Continuity

Last session: 2026-02-17
Stopped at: Phase 23 Plan 01 complete — add_interviews() bus-route extension (n_counted, n_interviewed, Tier 3 validation, pi_i join, .expansion, BUSRT-08, BUSRT-02, VALID-04)
Resume file: None

**Next step:** Phase 23 Plan 02 (get_enumeration_counts() accessor)

---
*State last updated: 2026-02-17 after Phase 23 Plan 01 complete*
