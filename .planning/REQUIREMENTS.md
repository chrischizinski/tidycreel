# Requirements: tidycreel v1.6.0 — Analytical Extensions II

**Defined:** 2026-05-02
**Core Value:** A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.

## v1.6.0 Requirements

### Camera Missing Data Imputation

- [ ] **CAMP-01**: User can call `impute_camera_counts()` on a data frame with a status column and receive a complete count frame with outage rows filled using a day-type GLM (Hartill 2016)
- [ ] **CAMP-02**: User can opt into zero-inflated GLMM imputation (Afrifa-Yamoah 2020) via `method = "glmm"`, guarded by `rlang::check_installed("glmmTMB")`
- [ ] **CAMP-03**: `impute_camera_counts()` output is schema-compatible with `add_counts()`, enabling the full `impute → add_counts → est_effort_camera()` chain without manual intervention
- [ ] **CAMP-04**: Function warns via `cli_warn()` when the missing fraction in any stratum exceeds 50% (Afrifa-Yamoah 2020 reliability threshold)
- [ ] **CAMP-05**: Function aborts with an informative message when an entire stratum has no observed counts (imputation requires at least some observed data)

### Camera Design Helper

- [ ] **CDES-01**: User can compute required camera-days per stratum for a target CV using `creel_n_camera()` with the stratified Cochran (1977) formula
- [ ] **CDES-02**: `creel_n_camera()` warns when computed n falls below the Feltz-Middaugh (2025) empirical minimums (~12 weekday + ~7 weekend days)
- [ ] **CDES-03**: Output is a named integer vector per stratum plus a `"total"` element, consistent with `creel_n_effort()` shape

### Mark-Recapture Harvest (closed-population)

- [ ] **MR-01**: User can estimate angler population size N from a single mark-recapture occasion using Chapman correction (default) via `estimate_angler_n()`
- [ ] **MR-02**: User can request the unadjusted Petersen estimator when m ≥ 7 via `method = "petersen"`
- [ ] **MR-03**: User can estimate N across multiple sampling occasions using the Schnabel estimator via `method = "schnabel"`
- [ ] **MR-04**: Function aborts with informative `cli_abort()` messages on impossible inputs: m = 0, m > n, m > M
- [ ] **MR-05**: `estimate_angler_n()` returns a `creel_estimates` S3 object compatible with `compare_designs()` and `autoplot()`
- [ ] **MR-06**: User can propagate N_hat uncertainty through to total harvest via `estimate_mr_harvest()` using the delta-method SE (Hansen & Van Kirk 2018)

### Stratification Audit (effort precision)

- [ ] **STRAT-01**: User can audit per-stratum effort precision from a completed survey (`creel_design`) or from pilot summary statistics (`N_h`, `ybar_h`, `s2_h`) via `audit_strata()`
- [ ] **STRAT-02**: User can simulate collapsing strata via `simulate_strata_collapse()` to compare precision before and after a proposed merge
- [ ] **STRAT-03**: User can compute Neyman-optimal reallocation of a fixed sampling budget via `reallocate_strata(n_total, N_h, s2_h)`
- [ ] **STRAT-04**: `audit_strata()` returns a `creel_strata_audit` S3 object with per-stratum RSE, n, and a meets-target flag
- [ ] **STRAT-05**: Design effect (DEFF) is included in `creel_strata_audit` output to quantify the value of the current stratification scheme

## Future Requirements

### Mark-Recapture (open population)

- **MR-F01**: User can estimate population size for open populations using Jolly-Seber via `estimate_angler_n_open()` (requires `FSA`; output needs dedicated S3 class)

### Camera Imputation (multiple imputation)

- **CAMP-F01**: User can request M imputed datasets for proper variance propagation via Rubin's rules (extends `impute_camera_counts()` with `m` argument)

### Stratification Audit (CPUE precision)

- **STRAT-F01**: `audit_strata()` audits CPUE precision in addition to effort precision via `type = "cpue"` argument

## Out of Scope

| Feature | Reason |
|---------|--------|
| Jolly-Seber open-population mark-recapture | Output contract incompatible with `creel_estimates`; requires a new S3 class and wider scope — deferred to future milestone (MR-F01) |
| Bayesian joint estimation | Integrating creel + camera + other data sources via Stan/JAGS — large scope, no current demand |
| Landscape-scale spatial effort (unsurveyed lakes) | Out of single-system scope; deferred per M022 research |
| Social-ecological / human dimensions | Motivations, values, economics — explicitly excluded from project scope |
| Off-site vs. on-site estimate reconciliation | No tools for reconciling on/off-site estimates — deferred |
| Drone-specific aerial workflow | Aerial GLMM exists; drone specifics are not meaningfully different in the current design |
| Automatic imputation inside `est_effort_camera()` | Imputation changes the data and must be an explicit user action with visible diagnostics — anti-feature |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CDES-01 | Phase 83 | Pending |
| CDES-02 | Phase 83 | Pending |
| CDES-03 | Phase 83 | Pending |
| CAMP-01 | Phase 84 | Pending |
| CAMP-02 | Phase 84 | Pending |
| CAMP-03 | Phase 84 | Pending |
| CAMP-04 | Phase 84 | Pending |
| CAMP-05 | Phase 84 | Pending |
| MR-01 | Phase 85 | Pending |
| MR-02 | Phase 85 | Pending |
| MR-03 | Phase 85 | Pending |
| MR-04 | Phase 85 | Pending |
| MR-05 | Phase 85 | Pending |
| MR-06 | Phase 85 | Pending |
| STRAT-01 | Phase 86 | Pending |
| STRAT-02 | Phase 86 | Pending |
| STRAT-03 | Phase 86 | Pending |
| STRAT-04 | Phase 86 | Pending |
| STRAT-05 | Phase 86 | Pending |

**Coverage:**
- v1.6.0 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-02*
*Last updated: 2026-05-02 after initial definition*
