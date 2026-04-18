---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 74 — Quality Bar Assessment
current_plan: Not started
status: unknown
last_updated: "2026-04-18T19:24:39.824Z"
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 8
  completed_plans: 8
---

# GSD State

**Milestone:** M022 — Comprehensive Project Evaluation and Future Planning
**Current phase:** 74 — Quality Bar Assessment
**Phase status:** in progress — plans 74-01 and 74-02 complete

**Current Plan:** Not started
**Last session:** 2026-04-18T17:12:00.000Z

## Decisions

- Ice designs are degenerate bus-routes: `estimate_harvest_rate()` dispatches ice to the bus-route HT path (implemented in 70-01).
- Total harvest/release for bus-route/ice implement the HT variant (Eq. 19.5): sum of expanded harvest/release divided by pi_i (implemented in 70-01).
- intersect() guard applied consistently for synthetic ice columns in all site_table constructions.
- estimate_total_release_br() reuses estimate_release_build_data() to join .release_count to interviews.
- Phases 71-75 are evaluation/research phases — they produce documents, not code.
- Phase 71-01: research document is purely a planning artifact; no design decisions or implementation commitments were made. Mark-recapture scoped to v1.5+. Multi-species joint variance requires prototype before interface commitment. Exploitation rate estimator is a genuine build candidate (no clean existing R wrapper).
- Phase 72-01: architectural review is complete. All four findings are low/medium severity — package architecture is structurally sound. get_site_contributions() file placement (A1, medium) is the only actionable structural fix. creel_summary_* subclasses without S3 methods (A4) require a commit-to-one-direction decision. Six positive findings (P1-P6) document patterns to preserve.
- Phase 72-02: dependency review is complete. scales is a DROP candidate (one-line sprintf replacement for single call-site in survey-bridge.R). lubridate is a DEMOTE candidate (all 15 call-sites in scheduling/viz; fold removal into next scheduling refactor). ggplot2 demotion requires an explicit architectural decision (is visualisation core or optional?). checkmate mixed-validation pattern is intentional batch-collection semantics — document for contributors.
- Phase 73-01: error handling strategy complete. cli::cli_abort named-vector convention declared canonical (368 calls, 30+ files). D1/D2 stop(e) re-raises are intentional idioms — must not convert to cli_abort. D3 rlang::warn(.frequency='once') is approved exception — .frequency not available in cli::cli_warn. D4 split-arg cli::cli_warn in validation-report.R is cosmetic. Named condition classes deferred to Phase 74.
- Phase 73-02: creel.connect investigation complete. Schema contract (creel_schema, validate_creel_schema) is READY — stable, complete, production-quality. Companion package SQL Server path is NOT READY: three concrete gaps (lengths_table slot mismatch, SQL Server stubs, vignette divergence). PROJECT.md "not current work" tension resolved: schema contract is frozen-but-informal; companion package is proof-of-concept with no active development.
- Phase 74-01: quality audit complete. tidycreel v1.3.0 achieves 87% code coverage (above rOpenSci 75% minimum). All three CI platforms confirmed (Windows + macOS + Linux). Named condition classes are MEDIUM priority for v1.4.0 — 8 priority sites identified. lifecycle formalization (R1), inst/CITATION (R2), and codecov threshold (R3) are HIGH priority pre-rOpenSci-submission blockers. Zero @family tags across all R/ files (R5, MEDIUM). design-validator.R at 56.8% is the most significant coverage gap.
- Phase 74-02: testing strategy complete. Snapshot policy stated as explicit rule: use expect_snapshot() for formatted text output only (print/format/autoplot), never for numeric estimates. 6 property-based domain invariants documented; quickcheck (CRAN) identified as R package (not rapidcheck, which is C++ only). Implementation deferred to Phase 75 or v1.4.0. Integration test pattern named and codified. _snaps/ empty-but-present gap documented with 6 priority methods for adoption.

## Blockers

- None

## Completed Phases (this milestone)

- S01 (PROJECT.md refresh) — complete 2026-04-15

## Recently Completed Milestones

- M019-pdfsz5: Standardized prep layers, explicit effort domains, species diagnostics
- M020-iuribi: High-use strata statistical design contract
- M021-pau0ov: Scheduler and analysis support for calendar-defined high-use strata
