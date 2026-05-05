---
gsd_state_version: 1.0
milestone: v1.6.0
milestone_name: Analytical Extensions II
status: complete
stopped_at: Phase 86 complete — all plans executed, rcmdcheck 0 errors 0 warnings
last_updated: "2026-05-05T00:00:00.000Z"
last_activity: 2026-05-05 -- Phase 86 complete (STRAT-01..STRAT-05 satisfied)
progress:
  total_phases: 7
  completed_phases: 7
  total_plans: 16
  completed_plans: 16
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-02)

**Core value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.
**Current focus:** v1.6.0 milestone complete — ready for verification and PR

## Current Position

Phase: 86 of 86 (Stratification Audit) — COMPLETE
Plan: 086-02 complete
Status: Milestone v1.6.0 complete — ready for verification + PR
Last activity: 2026-05-05 -- Phase 86 complete (STRAT-01..STRAT-05 satisfied)

Progress: [##########] 100%

## Accumulated Context

### Decisions

- Jolly-Seber (MR-F01) deferred — output contract incompatible with `creel_estimates`; closed-population only in Phase 85
- GLMM tier (glmmTMB) is opt-in via `method = "glmm"` in Phase 84; GLM default has no new deps
- `audit_strata()` audits effort precision only in v1.6.0 — CPUE precision deferred to STRAT-F01
- `FSA` in Suggests only (guarded); `glmmTMB` in Suggests only (guarded); Imports unchanged
- creel_n_camera() is standalone (Phase 83 complete); power_creel(mode = "camera_n") remains deferred
- intercept-only GLM per stratum (`count ~ 1`) — `strata_col` has one unique value within each stratum subset; `count ~ strata_col` would fail with "contrasts need 2+ levels"

### Phase 83 Outcomes

- `creel_n_camera()` added to `R/power-sample-size.R` — Cochran (1977) eq. 5.25 with Feltz-Middaugh (2025) minimums
- `export(creel_n_camera)` in NAMESPACE; `man/creel_n_camera.Rd` created
- `_pkgdown.yml` updated: creel_n_camera between creel_n_effort and creel_n_cpue
- 10 test_that() blocks appended to tests/testthat/test-power-sample-size.R (CDES-01/02/03)
- devtools::check(): 0 errors | 0 warnings | 1 pre-existing note; 2556 tests passing
- Pre-existing vignette bug fixed: visualisation.Rmd boxplot column corrected

### Phase 84 Outcomes

- `impute_camera_counts()` added to `R/impute-camera-counts.R` (188 lines)
- GLM default (Poisson, Hartill 2016) + GLMM opt-in (nbinom2, Afrifa-Yamoah 2020)
- `glmmTMB` added to DESCRIPTION Suggests (alphabetical: between flexdashboard and hedgehog)
- `export(impute_camera_counts)` in NAMESPACE; `man/impute_camera_counts.Rd` created
- `_pkgdown.yml` updated: impute_camera_counts in Survey Design section (after est_effort_camera)
- 21 test_that() blocks in tests/testthat/test-impute-camera-counts.R covering CAMP-01 through CAMP-05
- devtools::check(): 0 errors | 0 warnings | 1 pre-existing note; 2578 tests passing

### Phase 85 Outcomes

- `estimate_angler_n()` added to `R/creel-estimates-mark-recapture.R` (311 lines)
- Chapman (default), Petersen, and Schnabel closed-population estimators
- `estimate_mr_harvest()` delta-method harvest propagation: H = N_hat × rate; SE = rate × se_N
- All input guards: m=0, m>n, m>M, Petersen m<7, Schnabel K<2, Schnabel unequal vector lengths
- Schnabel Poisson CI branch (sum_m < 50) and normal CI branch (sum_m >= 50) both implemented
- Bug found and fixed: `any(M <= 0)` guard moved inside method branches to allow Schnabel M[1]=0
- `export(estimate_angler_n)` and `export(estimate_mr_harvest)` in NAMESPACE; both Rd files created
- `_pkgdown.yml` updated: both functions in Estimation section after estimate_exploitation_rate
- 23 test_that() blocks in test-estimate-angler-n.R (MR-01..MR-05)
- 11 test_that() blocks in test-estimate-mr-harvest.R (MR-06)
- devtools::check(): 0 errors | 0 warnings | 1 pre-existing note; 2624 tests passing
- Code review: 3 advisory warnings (variance_method mislabel in Petersen, Schnabel ci_hi unguarded for lo_m=0, Test J missing upper harvest_rate bound) — tracked in 085-REVIEW.md

### Phase 86 Outcomes

- `audit_strata()` S3 generic added to `R/strata-audit.R` — `creel_design` and `default` methods; returns `creel_strata_audit` with per-stratum RSE, DEFF, meets_target
- `simulate_strata_collapse(audit, merge_strata)` before/after long tibble for strata merge evaluation
- `reallocate_strata(n_total, N_h, s2_h)` Neyman-optimal named integer vector allocation
- `export(audit_strata)`, `S3method(audit_strata,creel_design)`, `S3method(audit_strata,default)`, `export(simulate_strata_collapse)`, `export(reallocate_strata)` in NAMESPACE
- `man/audit_strata.Rd`, `man/simulate_strata_collapse.Rd`, `man/reallocate_strata.Rd` generated
- `_pkgdown.yml` updated: three functions in Planning & Sample Size section (between cv_from_n and compare_designs)
- 37 test_that() blocks in test-strata-audit.R (Tests A–X + creel_design fixture)
- rcmdcheck 0 errors 0 warnings; 2661 tests passing
- cli_abort pluralization fix: removed `{?s}` from simulate_strata_collapse error message (post_process_plurals)
- ignore_attr = TRUE in expect_equal for named-vector tibble subset assertions

### Pending Todos

None.

### Blockers/Concerns

None. Package state: rcmdcheck 0 errors 0 warnings, 2661 tests passing.

## Session Continuity

Last session: 2026-05-05
Stopped at: Phase 86 complete — all 16 plans executed
Resume file: None — milestone v1.6.0 complete; next step is verification + PR
