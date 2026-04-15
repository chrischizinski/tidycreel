---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 71 — Future Analytical Needs
current_plan: Not started
status: unknown
last_updated: "2026-04-15T20:00:44.077Z"
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 2
  completed_plans: 2
---

# GSD State

**Milestone:** M022 — Comprehensive Project Evaluation and Future Planning
**Current phase:** 71 — Future Analytical Needs
**Phase status:** complete — plan 71-01 complete

**Current Plan:** Not started
**Last session:** 2026-04-15T18:34:01Z

## Decisions

- Ice designs are degenerate bus-routes: `estimate_harvest_rate()` dispatches ice to the bus-route HT path (implemented in 70-01).
- Total harvest/release for bus-route/ice implement the HT variant (Eq. 19.5): sum of expanded harvest/release divided by pi_i (implemented in 70-01).
- intersect() guard applied consistently for synthetic ice columns in all site_table constructions.
- estimate_total_release_br() reuses estimate_release_build_data() to join .release_count to interviews.
- Phases 71-75 are evaluation/research phases — they produce documents, not code.
- Phase 71-01: research document is purely a planning artifact; no design decisions or implementation commitments were made. Mark-recapture scoped to v1.5+. Multi-species joint variance requires prototype before interface commitment. Exploitation rate estimator is a genuine build candidate (no clean existing R wrapper).

## Blockers

- None

## Completed Phases (this milestone)

- S01 (PROJECT.md refresh) — complete 2026-04-15

## Recently Completed Milestones

- M019-pdfsz5: Standardized prep layers, explicit effort domains, species diagnostics
- M020-iuribi: High-use strata statistical design contract
- M021-pau0ov: Scheduler and analysis support for calendar-defined high-use strata
