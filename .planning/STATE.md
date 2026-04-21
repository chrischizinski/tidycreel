---
gsd_state_version: 1.0
milestone: v1.4
milestone_name: milestone
status: planning
stopped_at: Completed 78-01-PLAN.md — @family tags for all 111 user-facing exports
last_updated: "2026-04-21T01:31:02Z"
last_activity: 2026-04-19 — Roadmap created for M023 (Phases 76–80)
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 7
  completed_plans: 7
  percent: 0
---

# GSD State

**Milestone:** M023 — Quality, Polish, and rOpenSci Readiness — v1.4.0
**Status:** Ready to plan

**Last session:** 2026-04-20T20:20:35.689Z

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-19)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** Phase 76 — rOpenSci Blockers (ready to plan)

## Current Position

Phase: 78 of 80 (Code Quality and Snapshot Testing)
Plan: 01 complete — @family tags for pkgdown reference grouping
Status: In progress (Phase 78 Plan 01 complete)
Last activity: 2026-04-21 — Phase 78-01 complete: @family tags on 111 exports, 92 Rd files updated

Progress: [████░░░░░░] 40% (2/5 phases complete, Phase 78 in progress)

## Performance Metrics

**Velocity:**
- Total plans completed: 0 (this milestone)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*
| Phase 76-ropensci-blockers P01 | 2 | 3 tasks | 8 files |
| Phase 76-ropensci-blockers P02 | 639 | 3 tasks | 13 files |
| Phase 76-ropensci-blockers P03 | 15 | 2 tasks | 8 files |
| Phase 76-ropensci-blockers P04 | 10 | 2 tasks | 0 files |
| Phase 77-dependency-reduction-and-caller-context P01 | 11min | 2 tasks | 5 files |
| Phase 77-dependency-reduction-and-caller-context P02 | 8min | 2 tasks | 3 files |
| Phase 77-dependency-reduction-and-caller-context P03 | 5min | 2 tasks | 0 files |
| Phase 78-code-quality-and-snapshot-testing P01 | 45min | 2 tasks | 134 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- M022: Named condition classes — MEDIUM priority, 8 sites identified (now HIGH for v1.4.0 rOpenSci submission)
- M022: quickcheck locked (CRAN); not rapidcheck (C++ only)
- M022: INV-05 manual-review only — do not automate via quickcheck
- M022: scales drop — single sprintf() at one call-site in survey-bridge.R
- M022: D3 rlang::warn(.frequency='once') — approved exception, document for contributors
- [Phase 76-01]: CITATION.cff has placeholder data — all citation metadata sourced from DESCRIPTION
- [Phase 76-01]: test-survey-bridge-percent.R stubs are deliberately RED — Plan 03 closes them
- [Phase 76-02]: Named condition classes: all 8 priority sites covered plus 4 auto-extended sites; creel_error_invalid_input covers both missing-input guards and probability validation
- [Phase 76-03]: Boundary condition for mor_truncation_message warning changed from >0.10 to >=0.10 to match test expectations (10% triggers warning)
- [Phase 76-03]: nolint: object_usage_linter applied to pct_label — lintr cannot detect variable use inside cli glue strings
- [Phase 76-ropensci-blockers]: Phase 76-04: Lifecycle badge SVG visual verification approved — renders as colored pill badge in pkgdown docs for estimate_effort_aerial_glmm, as_hybrid_svydesign, and compare_designs
- [Phase 77-01]: lubridate guard uses bare rlang::check_installed('lubridate') with no reason argument — per locked plan decision
- [Phase 77-01]: Soft-dependency pattern established: package in Suggests + rlang::check_installed() at every user-visible entry point that calls it
- [Phase 77-02]: get_site_contributions() relocated to creel-estimates-utils.R (Layer 2) — consumes creel_estimates, not creel_design objects
- [Phase 77-02]: caller_env thread pattern: call = rlang::caller_env() as last param + call = call in all cli_abort() calls, including recursive calls in estimate_harvest_br()
- [Phase 77-dependency-reduction-and-caller-context]: Phase 77 changes confirmed green: lubridate in Suggests, caller_env threaded, get_site_contributions relocated — no regressions
- [Phase 78-01]: @family tag for autoplot.* methods: these ARE user-facing exports and DO receive @family (not skipped like print.*/format.*/as.data.frame.*)
- [Phase 78-01]: summary.creel_estimates in creel-summaries.R (not creel-estimates.R) receives @family Reporting & Diagnostics — the one summary.* exception
- [Phase 78-01]: preprocess_camera_timestamps lives in creel-design.R (not survey-bridge.R); @family Camera Survey added there

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-04-21
Stopped at: Completed 78-01-PLAN.md — @family tags for all 111 user-facing exports
Resume file: .planning/phases/78-code-quality-and-snapshot-testing/78-01-SUMMARY.md
