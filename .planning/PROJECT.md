# tidycreel

## What This Is

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. It gives fisheries biologists a tidy, domain-level interface over design-based survey workflows, so they can work in creel vocabulary instead of survey-package internals.

## Core Value

A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.

## Current Milestone: v1.7.0 — API Connection & Real-Data Validation

**Goal:** Complete the tidycreel.connect API backend so users can fetch creel data from any compatible REST service, and validate the full estimation pipeline against known real-world outputs from the Calamus 2016 archive.

**Target features:**
- `fetch_*` dispatch for `creel_connection_api` — implement the five missing S3 methods (interviews, counts, catch, harvest_lengths, release_lengths) that call `.api_fetch()`, rename to canonical columns, and validate
- `list_creels()` + `search_creels()` — discover available survey UIDs from an API before connecting
- Calamus 2016 integration script — standalone R script running the full bus-route workflow on real NGPC data and validating estimates against archived comparison CSVs

## Current State

**Package version:** `1.6.0` (shipped 2026-05-06, PR #54 merged, git tag v1.6.0)
**v1.7.0 in progress:** Phase 88 complete (httr2 hardening, 5 fetch_* methods); Phase 89 complete (2026-05-10) — `list_creels()`, `search_creels()` discovery generics, 142 tests pass.

v1.6.0 complete: 5 phases (83–87), 9 plans, 19/19 requirements satisfied, 2667 tests, 0 errors 0 warnings. Ships `creel_n_camera()`, `impute_camera_counts()`, `estimate_angler_n()`, `estimate_mr_harvest()`, `audit_strata()`, `simulate_strata_collapse()`, `reallocate_strata()`. All 6 advisory items from internal review closed in Phase 87. Mark-recapture vignette added. See `.planning/milestones/v1.6-ROADMAP.md` for full archive.

## Previous State (M023 / v1.4.0 — archived)

What was validated in this milestone:
- rOpenSci blocker set closed: named condition classes, lifecycle badges, `inst/CITATION`, and `scales` removal
- dependency cleanup and caller-context propagation landed (`lubridate` demotion, `caller_env()`, `get_site_contributions()` relocation)
- pkgdown/reference quality work landed (`@family` grouping and snapshot coverage for the three priority print methods)
- property-based tests and a CI-backed coverage gate landed (`quickcheck`, Codecov, documented `86.27%` local baseline)

Important release-surface note:
- the package still reports `Version: 1.3.0`
- this was a local planning closeout, not a git-tagged `v1.4.0` release
- version bump, release commit, and tag creation remain explicit follow-up work

## Previous State (M024 / v1.5.0 — archived)

What was validated in this milestone:
- `estimate_exploitation_rate()` with delta-method SE and stratified path (Pollock et al. moment estimator)
- INV-06 stratified-sum fix for `estimate_total_catch()`
- `lifecycle` import cleanup, `urlchecker` green, `goodpractice` sapply→vapply sweep (14 sites)
- `rhub` v2 GitHub Actions CI (ubuntu-release + macos-release green)
- `tidycreel.connect` bridge article on pkgdown site

## Current Package State

**Package version:** `1.3.0`

**Supported survey types:**
- instantaneous count
- bus-route
- ice fishing
- camera
- aerial
- aerial GLMM workflow
- hybrid access/roving

**Current user-facing surface:**
- survey design construction via `creel_design()`
- count/interview/catch/length/section registration
- effort, catch-rate, harvest-rate, release-rate, total-catch, and length-distribution estimators
- total-harvest and total-release HT estimators for bus-route and ice designs (`estimate_total_harvest_br()`, `estimate_total_release_br()`)
- nonresponse adjustment and variance comparison helpers
- pre-survey sample-size and power analysis via `power_creel()`
- multi-design comparison via `compare_designs()`
- unextrapolated trip/catch/length summaries
- planning tools for schedules, count windows, completeness checks, and sample-size/power calculations
- `autoplot()` methods for estimates, schedules, and length distributions
- package-standard plotting helpers via `theme_creel()` and `creel_palette()`
- glossary vignette, planning/estimation/reporting vignettes, and pkgdown site
- flexdashboard report template scaffold under `inst/rmarkdown/templates/creel-dashboard/`
- calendar-defined special-period scheduling via `special_periods` arg in `generate_schedule()`
- profiling harness in `inst/profiling/` (4 scripts; fixtures gitignored)

## Current Verification Baseline

The package currently closes its local gate with:
- `pkgdown::build_site()` completing successfully
- `rcmdcheck::rcmdcheck(args = c('--no-manual', '--as-cran'), error_on = 'warning')` passing with **0 errors** and **0 warnings**
- Pre-push hook runs `rcmdcheck` locally — matches CI gate

## Requirements

### Validated

- ✓ Bus-route/ice HT estimators complete — M022 (estimate_total_harvest_br, estimate_total_release_br, ice dispatch in estimate_harvest_rate)
- ✓ Architectural review and dependency analysis — M022 (72-ARCH-REVIEW.md, 72-DEP-REVIEW.md; all 11 Imports assessed)
- ✓ Error handling strategy codified — M022 (cli::cli_abort named-vector convention, D1–D4 deviation inventory)
- ✓ Quality bar assessed against tidyverse/rOpenSci standards — M022 (87% coverage, 28 verdicts, R1–R8 recommendations)
- ✓ Performance profiling with empirical Rcpp go/no-go — M022 (DEFER; Taylor 1.5ms, bootstrap 54× slower — upstream survey:: cost)
- ✓ Property-based testing invariants specified — M022 (INV-01–06, quickcheck adoption plan)
- ✓ Analytical extension research documented — M022 (multi-species, spatial, temporal, mark-recapture build-vs-wrap assessments)

### Validated in M024 / v1.5.0

- ✓ `estimate_total_catch()` stratified-sum fix (INV-06) — v1.5.0 (combined-ratio replaced; 24/24 quickcheck invariants pass)
- ✓ `estimate_exploitation_rate()` — v1.5.0 (Pollock et al. moment estimator, delta-method SE, [0,1]-clamped CI)
- ✓ `estimate_exploitation_rate()` stratified path — v1.5.0 (T-weighted aggregate `.overall` row, internal helper pattern)
- ✓ Unused `lifecycle` import removed — v1.5.0 (`@importFrom lifecycle badge` in R/tidycreel-package.R)
- ✓ `urlchecker::url_check()` passes — v1.5.0 (24 URLs; sole 403 is valid DOI behind Oxford Academic bot-protection)
- ✓ `rhub::rhub_check()` green on Linux and macOS — v1.5.0 (ubuntu-release, macos-release via GitHub Actions)
- ✓ `goodpractice::gp()` WARNING-level findings addressed — v1.5.0 (14 sapply→vapply; cyclocomp/T-F/line-length deferred as intentional)
- ✓ `tidycreel.connect` bridge article on pkgdown — v1.5.0 (vignettes/tidycreel-connect.Rmd, Ecosystem nav section)

### Validated in M023 / v1.4.0

- ✓ Named condition classes at 8 priority sites
- ✓ `lifecycle` formalization and `inst/CITATION`
- ✓ `scales` dropped from Imports/NAMESPACE
- ✓ `lubridate` demoted to Suggests with install guards
- ✓ `rlang::caller_env()` threaded through bus-route estimators
- ✓ quickcheck property-based tests for the implemented priority invariants
- ✓ `@family` tags across the exported surface
- ✓ `expect_snapshot()` adoption for the three priority print methods
- ✓ `get_site_contributions()` relocation to the estimation layer
- ✓ fresh local coverage baseline plus Codecov CI threshold

### Validated in v1.6.0

- ✓ `creel_n_camera()` — Cochran (1977) stratified camera-day sample size with Feltz-Middaugh (2025) minimum warnings — v1.6.0
- ✓ `impute_camera_counts()` — Poisson GLM (default) + NB GLMM opt-in imputation for camera outages, `.imputed` flag, CAMP-01..05 — v1.6.0
- ✓ `estimate_angler_n()` — Chapman/Petersen/Schnabel closed-population estimators with input guards and `creel_estimates` S3 output — v1.6.0
- ✓ `estimate_mr_harvest()` — delta-method harvest propagation from N_hat uncertainty — v1.6.0
- ✓ `audit_strata()` — per-stratum RSE, DEFF, meets-target audit from `creel_design` or pilot statistics — v1.6.0
- ✓ `simulate_strata_collapse()` — before/after precision comparison for proposed strata merges — v1.6.0
- ✓ `reallocate_strata()` — Neyman-optimal reallocation of fixed sampling budget — v1.6.0

### Active (v1.7.0)

- [ ] **API-01**: User can call `fetch_interviews()` on a `creel_connection_api` object and receive a canonical data frame
- [ ] **API-02**: User can call `fetch_counts()` on a `creel_connection_api` object and receive a canonical data frame
- [ ] **API-03**: User can call `fetch_catch()` on a `creel_connection_api` object and receive a canonical data frame
- [ ] **API-04**: User can call `fetch_harvest_lengths()` and `fetch_release_lengths()` on a `creel_connection_api` object
- [ ] **API-05**: User can call `list_creels()` to retrieve all available surveys from an API
- [ ] **API-06**: User can call `search_creels()` with a keyword to find matching surveys from an API
- [ ] **REAL-01**: Integration script runs Calamus 2016 bus-route data through the full estimation pipeline and reports whether estimates match archived comparison outputs

### Out of Scope

- Mobile app or web UI — web-first approach; no current demand
- Multi-species joint covariance estimation — deferred (requires prototype before interface commitment; see 71-ANALYTICAL-EXTENSIONS-RESEARCH.md)
- Jolly-Seber open-population mark-recapture (MR-F01) — output contract incompatible with `creel_estimates`; requires new S3 class; deferred
- Multiple imputation via Rubin's rules (CAMP-F01) — extends `impute_camera_counts()`; deferred
- CPUE precision audit in `audit_strata()` (STRAT-F01) — deferred to future milestone
- `power_creel(mode = "camera_n")` — `creel_n_camera()` is standalone; power_creel integration deferred
- Spatial and temporal random effects for non-aerial types — deferred (research complete; no implementation commitment)
- Rcpp acceleration — DEFER recommendation (empirical: only bootstrap is slow; bootstrap cost is in upstream `survey::as.svrepdesign()`, not addressable in tidycreel)
- `creel_schema` / `tidycreel.connect` / generic DB interface — NOT current work; companion package has 3 concrete gaps; schema contract is frozen-but-informal
- rOpenSci formal submission — deferred from v1.5.0 to undetermined future date
## Key Decisions

| Decision | Outcome | Milestone |
|----------|---------|-----------|
| Ice designs are degenerate bus-routes | `estimate_harvest_rate()` dispatches ice to bus-route HT path | M022 |
| intersect() guard for synthetic ice columns | Applied consistently across all site_table constructions | M022 |
| `cli::cli_abort` named-vector convention | Canonical across 368 call-sites; D1/D2 stop(e) re-raises are intentional idioms | M022 |
| D3 `rlang::warn(.frequency='once')` | Approved exception — .frequency not available in cli::cli_warn | M022 |
| checkmate batch-collection validation | Intentional semantics — document for contributors | M022 |
| creel.connect schema contract | READY (frozen-but-informal); companion package NOT READY (3 gaps) | M022 |
| Named condition classes | MEDIUM priority for v1.4.0 — 8 priority sites identified | M022 |
| quickcheck for property-based testing | Locked decision (CRAN; not rapidcheck which is C++ only) | M022 |
| Rcpp go/no-go | DEFER — Taylor 1.5ms, bootstrap 54× slower but cost is in upstream survey:: | M022 |
| ggplot2 in Imports | Requires explicit architectural decision (is visualisation core or optional?) before demotion | M022 |
| `scales` drop | HIGH — single sprintf() replacement at one call-site in survey-bridge.R | M022 |
| INV-05 (Taylor/bootstrap convergence) | Manual-review-only — no automated quickcheck implementation | M022 |
| Stratified-sum product estimator for total catch | Per-stratum `E_h × CPUE_h` summed; combined-ratio was incorrect for multi-strata | M024 |
| `estimate_exploitation_rate()` scalar input pattern | Takes pre-computed summary stats — no `creel_design` dependency | M024 |
| Stratified path as internal helper | `.estimate_exploitation_rate_stratified()` not exported; router guard at top of main function | M024 |
| `@importFrom lifecycle badge` in package-level file | Single declaration in R/tidycreel-package.R covers all usages | M024 |
| goodpractice T/F deferral | Parameter `T` is canonical Pollock et al. domain notation; renaming breaks public API | M024 |
| rhub v2 GitHub Actions | GitHub Actions-based; results auditable by rOpenSci reviewers; Windows deferred | M024 |
| rOpenSci submission descoped | QUAL-05 deferred from v1.5.0 to undetermined future date | M024 |
| GLMM tier opt-in via `method = "glmm"` | `glmmTMB` in Suggests only (guarded); GLM default keeps Imports unchanged | v1.6.0 |
| Intercept-only GLM per stratum | `count ~ 1` (not `count ~ strata_col`) — single unique value per stratum subset at model time | v1.6.0 |
| Jolly-Seber deferred | Output contract incompatible with `creel_estimates`; closed-population only in Phase 85 | v1.6.0 |
| `audit_strata()` effort-precision only | CPUE precision deferred to STRAT-F01 — keeps scope contained | v1.6.0 |
| `variance_method` labels corrected | Petersen branch uses `"petersen"`, not `"chapman"` — fixed in Phase 87 | v1.6.0 |
| `.imputed` logic refined | Pre-imputation NA baseline captured before loop; only marks rows that were NA-before and non-NA-after | v1.6.0 |

## Constraints

- Preserve the existing package API unless a change is clearly justified and documented.
- Keep `pkgdown::build_site()` and `rcmdcheck` as the closing verification contract.
- Do not take any outward-facing release action without explicit human confirmation.
- Prefer release-surface truthfulness and integration proof over cosmetic editing.

---
## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-09 — v1.6.0 milestone complete and archived*
