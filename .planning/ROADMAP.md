# Roadmap: tidycreel

## Overview

tidycreel v2 is a ground-up redesign providing domain translation for creel survey analysis. Built on the R `survey` package foundation, it provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally.

## Milestones

- ✅ **v0.1.0 Foundation** — Phases 1-7 (shipped 2026-02-09)
- ✅ **v0.2.0 Interview-Based Estimation** — Phases 8-12 (shipped 2026-02-11)
- ✅ **v0.3.0 Incomplete Trips & Validation** — Phases 13-20 (shipped 2026-02-16)
- ✅ **v0.4.0 Bus-Route Survey Support** — Phases 21-27 (shipped 2026-02-28)
- ✅ **v0.5.0 Interview Data Model and Unextrapolated Summaries** — Phases 28-35 (shipped 2026-03-08)
- ✅ **v0.6.0 Multiple Counts per PSU** — Phases 36-38 (shipped 2026-03-09)
- ✅ **v0.7.0 Spatially Stratified Estimation** — Phases 39-43 (shipped 2026-03-15)
- ✅ **v0.8.0 Non-Traditional Creel Designs** — Phases 44-47 (shipped 2026-03-22)
- ✅ **v0.9.0 Survey Planning & Quality of Life** — Phases 48-51 (shipped 2026-03-24)
- 🚧 **v1.0.0 Package Website** — Phases 52-56 (in progress)

## Phases

<details>
<summary>✅ v0.1.0 Foundation (Phases 1-7) — SHIPPED 2026-02-09</summary>

**Milestone Goal:** Establish package foundation with instantaneous count design and effort estimation, proving the three-layer architecture (API → Orchestration → Survey) works end-to-end.

- [x] Phase 1: Package Foundation (3/3 plans) — completed 2026-02-09
- [x] Phase 2: Design Constructor (2/2 plans) — completed 2026-02-09
- [x] Phase 3: Count Data Integration (2/2 plans) — completed 2026-02-09
- [x] Phase 4: Basic Effort Estimation (2/2 plans) — completed 2026-02-09
- [x] Phase 5: Grouped Estimation (1/1 plan) — completed 2026-02-09
- [x] Phase 6: Variance Methods (2/2 plans) — completed 2026-02-09
- [x] Phase 7: Documentation & Quality Assurance (2/2 plans) — completed 2026-02-09

**Delivered:** Three-layer architecture proven, design-centric API operational, progressive validation working, complete estimation capability with multiple variance methods, production-ready quality gates

See: [.planning/milestones/v0.1.0-ROADMAP.md](milestones/v0.1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.2.0 Interview-Based Estimation (Phases 8-12) — SHIPPED 2026-02-11</summary>

**Milestone Goal:** Enable catch and harvest estimation by adding interview data analysis to existing instantaneous count design foundation.

- [x] Phase 8: Interview Data Integration (2/2 plans) — completed 2026-02-11
- [x] Phase 9: CPUE Estimation (2/2 plans) — completed 2026-02-11
- [x] Phase 10: Catch and Harvest Estimation (2/2 plans) — completed 2026-02-11
- [x] Phase 11: Total Catch Estimation (2/2 plans) — completed 2026-02-11
- [x] Phase 12: Documentation and Quality Assurance (2/2 plans) — completed 2026-02-11

**Delivered:** Interview data integration, ratio-of-means CPUE/harvest estimation, total catch/harvest with delta method variance, comprehensive documentation, 89.24% test coverage

See: [.planning/milestones/v0.2.0-ROADMAP.md](milestones/v0.2.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.3.0 Incomplete Trips & Validation (Phases 13-20) — SHIPPED 2026-02-16</summary>

**Milestone Goal:** Enable scientifically valid incomplete trip estimation with complete trip focus, following Colorado C-SAP best practices and Pollock et al. roving-access design principles.

- [x] Phase 13: Trip Status Infrastructure (2/2 plans) — completed 2026-02-16
- [x] Phase 14: Overnight Trip Duration (1/1 plan) — completed 2026-02-16
- [x] Phase 15: Mean-of-Ratios Estimator Core (2/2 plans) — completed 2026-02-16
- [x] Phase 16: Trip Truncation (2/2 plans) — completed 2026-02-16
- [x] Phase 17: Complete Trip Defaults (2/2 plans) — completed 2026-02-16
- [x] Phase 18: Sample Size Warnings (2/2 plans) — completed 2026-02-16
- [x] Phase 19: Diagnostic Validation Framework (2/2 plans) — completed 2026-02-16
- [x] Phase 20: Documentation & Guidance (2/2 plans) — completed 2026-02-16

**Delivered:** Trip metadata infrastructure, mean-of-ratios estimator with truncation, complete trip defaults, TOST validation framework, sample size warnings, comprehensive 794-line documentation vignette

See: [.planning/milestones/v0.3.0-ROADMAP.md](milestones/v0.3.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.4.0 Bus-Route Survey Support (Phases 21-27) — SHIPPED 2026-02-28</summary>

**Milestone Goal:** Implement statistically correct bus-route (nonuniform probability) estimation based on Jones & Pollock (2012) and Malvestuto et al. (1978) — making tidycreel the ONLY R package with correct bus-route estimation.

- [x] Phase 21: Bus-Route Design Foundation (2/2 plans) — completed 2026-02-17
- [x] Phase 22: Inclusion Probability Calculation (2/2 plans) — completed 2026-02-17
- [x] Phase 23: Data Integration (2/2 plans) — completed 2026-02-17
- [x] Phase 24: Bus-Route Effort Estimation (2/2 plans) — completed 2026-02-24
- [x] Phase 25: Bus-Route Harvest Estimation (2/2 plans) — completed 2026-02-28
- [x] Phase 26: Primary Source Validation (2/2 plans) — completed 2026-02-25
- [x] Phase 27: Documentation & Traceability (2/2 plans) — completed 2026-02-28

**Delivered:** Bus-route design constructor with nonuniform probabilities (πᵢ = p_site × p_period), enumeration expansion, effort/harvest estimators implementing Jones & Pollock (2012) Eq. 19.4-19.5, Malvestuto (1996) Box 20.6 reproduced exactly, complete workflow vignette, 1,098 tests

See: [.planning/milestones/v0.4.0-ROADMAP.md](milestones/v0.4.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.5.0 Interview Data Model and Unextrapolated Summaries (Phases 28-35) — SHIPPED 2026-03-08</summary>

- [x] Phase 28: Extended Interview Data Model (2/2 plans) — completed 2026-03-08
- [x] Phase 28.1: Normalize CPUE/HPUE by Angler Count (2/2 plans) — completed 2026-03-08
- [x] Phase 29: Species Catch Data (3/3 plans) — completed 2026-03-08
- [x] Phase 30: Length Frequency Data (1/1 plan) — completed 2026-03-08
- [x] Phase 31: Interview-Level Unextrapolated Summaries (2/2 plans) — completed 2026-03-08
- [x] Phase 32: CWS/HWS Rates (2/2 plans) — completed 2026-03-08
- [x] Phase 33: Length Frequency Summaries (2/2 plans) — completed 2026-03-08
- [x] Phase 34: Species-Level Extrapolated Estimates (2/2 plans) — completed 2026-03-08
- [x] Phase 35: Documentation & Quality Assurance (2/2 plans) — completed 2026-03-08

**Delivered:** add_catch(), add_lengths(), seven interview-level summary functions, CWS/HWS rates, length frequency distributions, species-level estimation, estimate_total_release() / estimate_release_rate()

See: [.planning/milestones/v0.5.0-ROADMAP.md](milestones/v0.5.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.6.0 Multiple Counts per PSU (Phases 36-38) — SHIPPED 2026-03-09</summary>

- [x] Phase 36: Multiple Counts per Day (2/2 plans) — completed 2026-03-09
- [x] Phase 37: Progressive Count Estimator (1/1 plan) — completed 2026-03-09
- [x] Phase 38: Documentation & Quality Assurance (2/2 plans) — completed 2026-03-09

**Delivered:** count_time_col support, within-day aggregation with Rasmussen two-stage variance (se_between/se_within), progressive count estimator with circuit_time, flexible-count-estimation vignette

See: [.planning/milestones/v0.6.0-ROADMAP.md](milestones/v0.6.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.7.0 Spatially Stratified Estimation (Phases 39-43) — SHIPPED 2026-03-15</summary>

**Milestone Goal:** Enable per-section estimation so biologists can get effort, catch rates, and totals broken down by named spatial zones, with correct correlated-domain variance when combining sections into lake-wide totals.

- [x] Phase 39: Section Effort Estimation (3/3 plans) — completed 2026-03-11
- [x] Phase 40: Interview-Based Rate Estimators (2/2 plans) — completed 2026-03-11
- [x] Phase 41: Product Estimators (2/2 plans) — completed 2026-03-14
- [x] Phase 42: Example Data and Vignette (2/2 plans) — completed 2026-03-14
- [x] Phase 43: v0.7.0 Tech Debt Cleanup (1/1 plan) — completed 2026-03-15

**Delivered:** add_sections() infrastructure, estimate_effort() section dispatch with svyby(covmat=TRUE) + svycontrast() aggregation, estimate_catch_rate() / estimate_harvest_rate() / estimate_release_rate() renamed and section-aware, estimate_total_catch() / estimate_total_harvest() / estimate_total_release() section dispatch with sum(TC_i) lake total, missing_sections guard on all estimators, example_sections_* datasets, section-estimation vignette, 1588 tests

See: [.planning/milestones/v0.7.0-ROADMAP.md](milestones/v0.7.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.8.0 Non-Traditional Creel Designs (Phases 44-47) — SHIPPED 2026-03-22</summary>

**Milestone Goal:** Extend tidycreel to support ice fishing, remote camera, and aerial creel survey designs as first-class `survey_type` values within the existing `creel_design()` entry point and three-layer architecture.

- [x] Phase 44: Design Type Enum and Validation (2/2 plans) — completed 2026-03-15
- [x] Phase 45: Ice Fishing Survey Support (3/3 plans) — completed 2026-03-16
- [x] Phase 46: Remote Camera Survey Support (3/3 plans) — completed 2026-03-16
- [x] Phase 47: Aerial Survey Support (3/3 plans) — completed 2026-03-22

**Delivered:** VALID_SURVEY_TYPES enum guard, ice fishing (p_site=1.0, effort_type, shelter_mode stratification), remote camera (counter + ingress-egress modes, camera_status gap handling, preprocess_camera_timestamps()), aerial survey (estimate_effort_aerial() svytotal × h_open/v, visibility correction, numeric validation), six example datasets, three workflow vignettes, 1696 tests

See: [.planning/milestones/v0.8.0-ROADMAP.md](milestones/v0.8.0-ROADMAP.md)

</details>

<details>
<summary>✅ v0.9.0 Survey Planning & Quality of Life (Phases 48-51) — SHIPPED 2026-03-24</summary>

**Milestone Goal:** Add pre-season planning tools (schedule generators, sample size calculators, design validator) and post-season diagnostics (completeness checker, season summary) around the existing five-survey-type estimation pipeline.

- [x] Phase 48: Schedule Generators (3/3 plans) — completed 2026-03-23
- [x] Phase 49: Power and Sample Size (2/2 plans) — completed 2026-03-24
- [x] Phase 50: Design Validator and Completeness Checker (3/3 plans) — completed 2026-03-24
- [x] Phase 51: Season Summary (2/2 plans) — completed 2026-03-24

**Delivered:** `generate_schedule()` + `generate_bus_schedule()` sampling frame generators with CSV/xlsx I/O; `creel_n_effort()` + `creel_n_cpue()` Cochran sample-size calculators; `creel_power()` + `cv_from_n()` power/inverse suite; `validate_design()` pre-season pass/warn/fail report; `check_completeness()` post-season data quality checker with survey-type dispatch; `season_summary()` wide-tibble assembler with `creel_season_summary` S3 class

See: [.planning/milestones/v0.9.0-ROADMAP.md](milestones/v0.9.0-ROADMAP.md)

</details>

---

### v1.0.0 Package Website (In Progress)

**Milestone Goal:** Ship a polished, workflow-driven pkgdown website with a refreshed hex sticker, custom Bootstrap 5 theme, and automated GitHub Pages deployment. No new R functions; all work is infrastructure and presentation.

- [x] **Phase 52: Hex Sticker** - Existing logo.png retained; sticker assets committed (skipped re-generation) (completed 2026-03-30)
- [x] **Phase 53: Foundation & Theme** - pkgdown + Bootstrap 5 bslib configured; `pkgdown::check_pkgdown()` passes clean (completed 2026-03-26)
- [x] **Phase 54: Home Page & Reference** - Polished README home page with badges and feature highlights; reference index fully grouped (completed 2026-03-26)
- [x] **Phase 55: Navigation & Articles** - Workflow-driven navbar, reference link, and NEWS changelog wired into site structure (completed 2026-03-30)
- [ ] **Phase 56: Deployment** - GitHub Actions auto-deploys to gh-pages on push; PR builds catch errors before merge

## Phase Details

### Phase 52: Hex Sticker
**Goal**: A refreshed, professionally styled hex sticker is produced by a reproducible R script and committed as the package logo
**Depends on**: Nothing (no pkgdown infrastructure needed to render a PNG)
**Requirements**: STICKER-01, STICKER-02, STICKER-03
**Success Criteria** (what must be TRUE):
  1. `inst/hex/sticker.R` runs without error and writes `man/figures/logo.png`
  2. The output PNG is 1200x1390px at 300dpi (retina quality)
  3. The sticker color palette matches the brand colors used in the website theme (same primary hex value)
  4. Running `source("inst/hex/sticker.R")` at a clean checkout re-creates an identical logo without manual steps
**Plans**: 1 plan
Plans:
- [ ] 52-01-PLAN.md — Asset acquisition, sticker.R authoring, and visual verification of logo.png

### Phase 53: Foundation & Theme
**Goal**: pkgdown is installed and configured with a Bootstrap 5 custom theme so the site builds locally without warnings
**Depends on**: Phase 52 (logo.png must exist at the standard path before pkgdown detects it)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, THEME-01, THEME-02, THEME-03
**Success Criteria** (what must be TRUE):
  1. `pkgdown::check_pkgdown()` returns 0 warnings from the project root
  2. `pkgdown::build_site()` completes and opens a site showing the hex logo in the navbar
  3. The site uses a non-default professional color palette (primary brand color visible in links, buttons, and active nav state)
  4. Body text, headings, and code blocks render in distinct Google Fonts (Lato / Raleway / Fira Code or equivalent)
  5. `pkgdown` appears in DESCRIPTION `Suggests`; `docs/` is listed in `.gitignore`
**Plans**: 2 plans
Plans:
- [ ] 53-01-PLAN.md — DESCRIPTION/gitignore prerequisites (pkgdown in Suggests, Pages URL, docs/ excluded)
- [ ] 53-02-PLAN.md — _pkgdown.yml full configuration, pkgdown/extra.css structural CSS, visual verification

### Phase 54: Home Page & Reference
**Goal**: The site home page compels a first-time visitor to install the package, and every exported function appears in a named reference group
**Depends on**: Phase 53 (site must build before content can be evaluated)
**Requirements**: HOME-01, HOME-02, HOME-03, REF-01, REF-02
**Success Criteria** (what must be TRUE):
  1. The home page displays R CMD check and pkgdown deploy status badges that link to the correct CI runs
  2. A feature highlights section lists the five supported survey types and three to five key capabilities visible above the fold on a standard laptop screen
  3. The reference index page groups functions under named topic headers (e.g., "Survey Design", "Estimation", "Planning & Diagnostics")
  4. Every exported function appears in at least one reference group — `pkgdown::check_pkgdown()` reports no orphaned functions
**Plans**: 2 plans
Plans:
- [ ] 54-01-PLAN.md — README.md home page polish (badges, Survey Types, Key Capabilities, corrected Quick Start) + extra.css hero/badge CSS
- [ ] 54-02-PLAN.md — _pkgdown.yml reference block (all 46 exports + 15 datasets in named topic groups)

### Phase 55: Navigation & Articles
**Goal**: A visitor navigates the entire site using workflow-driven top-level links without hitting dead ends or blank pages
**Depends on**: Phase 54 (home page and reference must exist before navbar links are wired to them)
**Requirements**: NAV-01, NAV-02, NAV-03
**Success Criteria** (what must be TRUE):
  1. The top navbar contains at minimum four workflow article groups: Get Started, Survey Types, Estimation, and Reporting & Planning
  2. A Reference link in the top navbar navigates directly to the grouped function index
  3. A Changelog page renders NEWS.md as a browsable version history page on the site
  4. Every navbar link resolves to an existing page — no 404s on a freshly built local site
**Plans**: 1 plan
Plans:
- [ ] 55-01-PLAN.md — Replace stale navbar articles stub with native articles: sections, add news component, visual verification

### Phase 56: Deployment
**Goal**: Every push to `main` automatically rebuilds and deploys the site; every PR triggers a build-only check that catches `_pkgdown.yml` errors before merge
**Depends on**: Phase 55 (complete site structure must exist before CI deploys something meaningful)
**Requirements**: DEPLOY-01, DEPLOY-02, DEPLOY-03
**Success Criteria** (what must be TRUE):
  1. `.github/workflows/pkgdown.yaml` exists and a push to `main` triggers a successful site build and deploy visible at the GitHub Pages URL
  2. The `gh-pages` orphan branch exists and GitHub Pages is configured to serve from it
  3. Opening a pull request triggers a build-only workflow run (no deploy step) and the run either passes or reports a `_pkgdown.yml` error that would be invisible without CI
**Plans**: 2 plans
Plans:
- [ ] 56-01-PLAN.md — Create pkgdown.yaml workflow (r-lib/actions v2 canonical template) and push to main to trigger first CI run
- [ ] 56-02-PLAN.md — Activate GitHub Pages from gh-pages branch and verify live site returns HTTP 200

## Progress

**Execution Order:** 52 → 53 → 54 → 55 → 56

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 52. Hex Sticker | v1.0.0 | 1/1 | Complete (skipped) | 2026-03-30 |
| 53. Foundation & Theme | 2/2 | Complete    | 2026-03-26 | - |
| 54. Home Page & Reference | 2/2 | Complete    | 2026-03-27 | - |
| 55. Navigation & Articles | 1/1 | Complete    | 2026-03-30 | - |
| 56. Deployment | v1.0.0 | 0/2 | Not started | - |

---
*Roadmap last updated: 2026-03-30 after Phase 56 plans created*
*See .planning/milestones/ for archived milestone roadmaps*
