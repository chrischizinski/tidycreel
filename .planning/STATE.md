# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.4.0 Bus-Route Survey Support

## Current Position

Phase: 25 of 27 (Bus-Route Harvest Estimation)
Plan: 2 complete
Status: Phase 25 Plan 02 complete — bus-route harvest and total-catch test suites complete
Last activity: 2026-02-24 — Phase 25 Plan 02 (16 tests: harvest + total-catch bus-route) complete

Progress: [████████████░░░░░░░░] 71% (47/65+ plans complete across all milestones)

## Performance Metrics

**Velocity:**
- Total plans completed: 47
- v0.1.0 (Phases 1-7): 12 plans
- v0.2.0 (Phases 8-12): 10 plans
- v0.3.0 (Phases 13-20): 16 plans
- v0.4.0 (Phases 21-27): 9 plans

**By Milestone:**

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 | 1-7 | 12/12 | Complete | 2026-02-09 |
| v0.2.0 | 8-12 | 10/10 | Complete | 2026-02-11 |
| v0.3.0 | 13-20 | 16/16 | Complete | 2026-02-16 |
| v0.4.0 | 21-27 | 9/TBD | In progress | - |

**Quality Metrics (current):**
- Test coverage: ~90% (1066 tests)
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
- **Phase 23-02**: @examples and test helpers for bus-route interview tests require >= 4 calendar dates (>= 2 PSUs per stratum) for valid survey construction; bus-route accessor trio complete: get_sampling_frame() / get_inclusion_probs() / get_enumeration_counts()
- **Phase 24-01**: Bus-route dispatch placed BEFORE design$survey NULL check (bus-route uses interviews not counts, so design$survey is NULL for bus-route designs); NA expansion (n_counted>0, n_interviewed=0) excluded by na.rm=TRUE in sum() — statistically appropriate, cannot estimate effort without interview data; zero-effort sites (n_counted=0, n_interviewed=0) contribute 0 to sum; site_contributions attribute stored for Phase 26 Malvestuto validation traceability
- **Phase 24-02**: trip_duration omitted from bus-route test helpers (optional for add_interviews(); duration=0.0 fails Tier 2 validation); expect_no_message(suppressWarnings()) for verbose=FALSE test (survey::svydesign emits expected 'no weights' warning that is not a dispatch message); accessor quartet complete: get_sampling_frame() / get_inclusion_probs() / get_enumeration_counts() / get_site_contributions()
- **Phase 25-01**: Bus-route dispatch for estimate_harvest() placed BEFORE interview_survey NULL check (bus-route uses design$interviews not design$interview_survey); bus-route dispatch for estimate_total_catch() placed BEFORE validate_design_compatibility() (checks design$survey which is NULL for bus-route); verbose=FALSE passed to internal estimator after dispatch block emits message (prevents double-printing); br_build_estimates() shared helper eliminates duplication between harvest and catch estimators; incomplete trip path uses pi_i-weighted MOR (h_ratio_i = harvest/effort, contribution_i = h_ratio_i/pi_i)
- **Phase 25-02**: Interview dates spread across 4 calendar dates (not same date) so use_trips=incomplete filtering leaves >= 2 PSUs per stratum for survey::svydesign(); trip_status always included in interview data and always passed to add_interviews() (required parameter); make_br_harvest_design() requires date= and strata= args per creel_design() API

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.

## Session Continuity

Last session: 2026-02-24
Stopped at: Phase 25 Plan 02 complete — bus-route harvest + total-catch test suites (BUSRT-04, BUSRT-10)
Resume file: None

**Next step:** Phase 26 — Malvestuto Box 20.6 Validation

---
*State last updated: 2026-02-24 after Phase 25 Plan 02 complete*
