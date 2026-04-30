# tidycreel

## What This Is

tidycreel is an R package for creel survey design, data preparation, estimation, visualisation, and reporting. It gives fisheries biologists a tidy, domain-level interface over design-based survey workflows, so they can work in creel vocabulary instead of survey-package internals.

## Core Value

A biologist should be able to go from survey design to package-ready estimates, plots, summaries, and documentation without stitching together a custom analysis stack.

## Current State

**Package version:** `1.3.0` (version bump, release commit, and tag pending — no outward-facing release yet)

v1.5.0 planning complete (Phases 80–82 shipped 2026-04-28). No active milestone defined. Next milestone cycle starts with `/gsd:new-milestone`.

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

## Next Milestone Goals

No active milestone is defined yet.

Recommended starting points for the next planning cycle:
- decide the real release path for `v1.4.0` versus a later version bump
- resolve the remaining `rcmdcheck` housekeeping note for unused `lifecycle` import
- decide whether `tidycreel.connect` gets a bridge page on the main site or its own pkgdown site
- choose whether deferred analytical work (multi-species covariance, mark-recapture, exploitation-rate estimation) becomes active or remains out of scope

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

### Active

(None — no active milestone. Start next cycle with `/gsd:new-milestone`.)

### Out of Scope

- Mobile app or web UI — web-first approach; no current demand
- Multi-species joint covariance estimation — deferred (requires prototype before interface commitment; see 71-ANALYTICAL-EXTENSIONS-RESEARCH.md)
- Mark-recapture estimators — deferred (large scope; see 71-ANALYTICAL-EXTENSIONS-RESEARCH.md)
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

## Constraints

- Preserve the existing package API unless a change is clearly justified and documented.
- Keep `pkgdown::build_site()` and `rcmdcheck` as the closing verification contract.
- Do not take any outward-facing release action without explicit human confirmation.
- Prefer release-surface truthfulness and integration proof over cosmetic editing.

---
*Last updated: 2026-04-28 after v1.5.0 milestone*
