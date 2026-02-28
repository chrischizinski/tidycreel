---
gsd_state_version: 1.0
milestone: v0.1
milestone_name: milestone
status: unknown
last_updated: "2026-02-28T21:11:09.226Z"
progress:
  total_phases: 29
  completed_phases: 27
  total_plans: 51
  completed_plans: 51
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-16)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.4.0 Bus-Route Survey Support

## Current Position

Phase: 27 of 27 (Documentation & Traceability) — PHASE COMPLETE
Plan: 2 complete (ALL PLANS COMPLETE)
Status: Phase 27 Plan 02 complete — Equation traceability vignette (DOCS-04) + all 21 v0.4.0 requirements [x] in REQUIREMENTS.md
Last activity: 2026-02-28 — Phase 27 Plan 02 (vignette: bus-route-equations.Rmd, all 21 requirements complete) — v0.4.0 MILESTONE COMPLETE

Progress: [████████████████████] 100% (51/51 plans complete across v0.4.0 milestone)

## Performance Metrics

**Velocity:**
- Total plans completed: 50
- v0.1.0 (Phases 1-7): 12 plans
- v0.2.0 (Phases 8-12): 10 plans
- v0.3.0 (Phases 13-20): 16 plans
- v0.4.0 (Phases 21-27): 11 plans

**By Milestone:**

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 | 1-7 | 12/12 | Complete | 2026-02-09 |
| v0.2.0 | 8-12 | 10/10 | Complete | 2026-02-11 |
| v0.3.0 | 13-20 | 16/16 | Complete | 2026-02-16 |
| v0.4.0 | 21-27 | 12/12 | Complete | 2026-02-28 |

**Quality Metrics (current):**
- Test coverage: ~90% (1098 tests)
- R CMD check: 0 errors, 0 warnings
- lintr: 0 issues
| Phase 27 P02 | 7 | 2 tasks | 2 files |

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
- **Phase 26-01**: site_contributions column is "e_i_over_pi_i" (not "ratio"); bus-route effort method="total" (Horvitz-Thompson total, not "bus.route"/"horvitz"); Site D requires 2 interview rows to match n_interviewed=2; 15-row Box 20.6 helpers satisfy >= 2 PSU per stratum; VALID-01 golden value 287.5 and 847.5 verified to 1e-6
- **Phase 26-02**: Cross-validation uses ids=~1, strata=~day_type (mirrors implementation); HT contribution pre-computed as effort * .expansion / .pi_i before svydesign call; plan's ids=~site weights=~1/.pi_i approach was incorrect (gave 18.625 not 847.5); VALID-05 integration tests prove complete workflow
- **Phase 27-01**: trip_status="complete" required even for bus-route designs in add_interviews() call; vignette data row ordering matches validated test helper make_box20_6_example1() to produce E_hat=847.5; inline data (15 rows) cleaner than package dataset for this small example
- **Phase 27-02**: DOCS-04 satisfied by 8-section pure-markdown vignette with LaTeX math (no executable R chunks); all 21 v0.4.0 requirements marked complete in REQUIREMENTS.md after Phase 27 completion

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.

## Session Continuity

Last session: 2026-02-28
Stopped at: Phase 27 Plan 02 complete — v0.4.0 milestone (Bus-Route Survey Support) fully complete
Resume file: None

**Next step:** v0.4.0 is complete. All 21 requirements satisfied. Ready for v0.5.0 planning or release preparation.

---
*State last updated: 2026-02-28 after Phase 27 Plan 02 complete — v0.4.0 MILESTONE COMPLETE*
