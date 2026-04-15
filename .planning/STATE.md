---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 70 — Core Estimator Completeness (Bus-route, Aerial, Ice)
current_plan: Not started
status: unknown
last_updated: "2026-04-15T02:55:54.689Z"
progress:
  total_phases: 6
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
---

# GSD State

**Milestone:** M022 — Comprehensive Project Evaluation and Future Planning
**Current phase:** 70 — Core Estimator Completeness (Bus-route, Aerial, Ice)
**Phase status:** in_progress — plan 70-01 complete

**Current Plan:** Not started
**Last session:** 2026-04-15 — Stopped at: Completed 70-01-PLAN.md

## Decisions

- Ice designs are degenerate bus-routes: `estimate_harvest_rate()` dispatches ice to the bus-route HT path (implemented in 70-01).
- Total harvest/release for bus-route/ice implement the HT variant (Eq. 19.5): sum of expanded harvest/release divided by pi_i (implemented in 70-01).
- intersect() guard applied consistently for synthetic ice columns in all site_table constructions.
- estimate_total_release_br() reuses estimate_release_build_data() to join .release_count to interviews.
- Phases 71-75 are evaluation/research phases — they produce documents, not code.

## Blockers

- None

## Completed Phases (this milestone)

- S01 (PROJECT.md refresh) — complete 2026-04-15

## Recently Completed Milestones

- M019-pdfsz5: Standardized prep layers, explicit effort domains, species diagnostics
- M020-iuribi: High-use strata statistical design contract
- M021-pau0ov: Scheduler and analysis support for calendar-defined high-use strata
