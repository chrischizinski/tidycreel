---
gsd_state_version: 1.0
milestone: v1.5.0
milestone_name: Analytical Extensions
status: complete
stopped_at: v1.5.0 milestone archived — 3 phases, 8 plans complete
last_updated: "2026-04-28T00:00:00.000Z"
last_activity: 2026-04-28 — v1.5.0 milestone archived (Phases 80–82)
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 8
  completed_plans: 8
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-28)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** Planning next milestone

## Current Position

Phase: 82 of 82 (Package Quality and Documentation)
Plan: 3 of 3 in current phase
Status: Milestone complete — ready for `/gsd:new-milestone`
Last activity: 2026-04-28 — v1.5.0 milestone archived (Phases 80–82)

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: ~10 min/plan
- Total execution time: ~1.3 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 80 INV-06 Fix | 2 | ~35 min | ~18 min |
| 81 Exploitation Rate | 3 | ~20 min | ~7 min |
| 82 Quality + Docs | 3 | ~59 min | ~20 min |

*Updated after each plan completion*
| Phase 80-inv-06-fix-and-quickcheck-proof P01 | 525627 | 2 tasks | 4 files |
| Phase 80-inv-06-fix-and-quickcheck-proof P02 | 5 | 2 tasks | 1 files |
| Phase 081-exploitation-rate-estimator P01 | 220 | 2 tasks | 3 files |
| Phase 081-exploitation-rate-estimator P02 | 238 | 2 tasks | 2 files |
| Phase 081-exploitation-rate-estimator P03 | 720 | 2 tasks | 5 files |
| Phase 081-exploitation-rate-estimator P03 | 15 | 3 tasks | 5 files |
| Phase 082-package-quality-and-documentation P01 | 5 | 2 tasks | 3 files |
| Phase 082-package-quality-and-documentation P02 | 1440 | 2 tasks | 10 files |
| Phase 082-package-quality-and-documentation P03 | 30 | 2 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
v1.5.0 decisions:

- M022: quickcheck locked (CRAN; not rapidcheck)
- M023: Codecov threshold set at 85% against 86.27% local baseline
- M024: INV-06 fix uses stratified-sum path (not combined-ratio)
- M024: `lifecycle` import removal deferred from M023; now QUAL-01 in Phase 82
- Stratified-sum product estimator: per-stratum E_h × CPUE_h summed (not pooled E × CPUE)
- [Phase 80]: INV-06 fix uses stratified-sum path via compute_stratum_product_sum() with strata_cols for both ungrouped and grouped total catch
- [Phase 80]: cpue_for_stratum_product() helper filters complete trips before estimate_cpue_grouped() to avoid NSE issues with public API
- [Phase 80-inv-06-fix-and-quickcheck-proof]: rep_len() alternating weekday/weekend cycle preferred over format()-based detection: simpler, deterministic, guarantees both strata for n_days >= 2
- estimate_exploitation_rate() takes scalar inputs — no creel_design dependency
- [Phase 081-exploitation-rate-estimator]: estimate_exploitation_rate() takes scalar inputs — no creel_design object needed (pre-computed summary stats)
- [Phase 081-exploitation-rate-estimator]: Tests use regexp matching for errors/warnings because cli_error/cli_warning classes not present in cli 3.6.6
- Stratified path via internal .estimate_exploitation_rate_stratified() helper; router guard at top of main function
- [Phase 081-exploitation-rate-estimator]: Stratified path uses internal .estimate_exploitation_rate_stratified() helper (not exported); router guard at top of main function
- [Phase 081-exploitation-rate-estimator]: Vectorised pmax/pmin for per-stratum CI clamp; scalar max/min for .overall row
- [Phase 081-03]: quickcheck API: for_all() / integer_bounded(left=, right=) / double_bounded(left=, right=)
- [Phase 081-03]: rcmdcheck gate: _R_CHECK_FORCE_SUGGESTS_=false for local dev; 2 pre-existing NOTEs are known and deferred
- @importFrom lifecycle badge in R/tidycreel-package.R (single package-level declaration)
- [Phase 082-01]: @importFrom lifecycle badge placed in R/tidycreel-package.R (package-level); DOI 10.1002/nafm.10010 403 is Oxford Academic bot-protection, left in place
- goodpractice T/F deferral: parameter T is canonical Pollock et al. domain notation; renaming breaks public API
- [Phase 082-package-quality-and-documentation]: vapply(df, is.numeric, logical(1L)) replaces sapply for type safety across R sources
- [Phase 082-package-quality-and-documentation]: goodpractice T/F finding deferred: parameter T in estimate_exploitation_rate() is canonical domain notation (Pollock 1994); renaming breaks public API
- [Phase 082-package-quality-and-documentation]: goodpractice cyclocomp/covr/line-length/rcmdcheck findings deferred as intentional per phase constraints
- rhub v2 (GitHub Actions-based); ubuntu-release and macos-release confirmed green
- rOpenSci submission (QUAL-05) deferred from v1.5.0 to undetermined future date

### Pending Todos

None.

### Blockers/Concerns

None. Package state: rcmdcheck 0 errors 0 warnings, 2537+ tests passing, rhub Linux/macOS green.

## Session Continuity

Last session: 2026-04-28
Stopped at: v1.5.0 milestone archived
Resume file: None
