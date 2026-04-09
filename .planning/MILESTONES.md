# Milestones

## v1.2.0 Documentation, Visual Calendar & GLMM Aerial (Shipped: 2026-04-06)

**Phases completed:** 7 phases (60-65 incl. 63.1), 9 plans
**Code delivered:** 4 vignettes, 2 S3 print methods, 2 new functions, 1 new dataset, pkgdown polish — 45 files, +5,496/-84 lines

**Key accomplishments:**
- DESCRIPTION bumped to 1.1.0; NEWS.md rewritten with dated changelog entries for v1.0.0 and v1.1.0 (Phase 60)
- `survey-tidycreel.Rmd` vignette — side-by-side comparison of raw `survey` calls vs. tidycreel for full effort + catch rate + total catch workflow (Phase 61)
- `effort-pipeline.Rmd` — conceptual walkthrough of PSU construction, Rasmussen two-stage variance (se_between/se_within), and progressive count estimator with annotated LaTeX (Phase 62)
- `catch-pipeline.Rmd` — ROM vs MOR estimator choice and delta method variance decomposition with confirmed numeric examples (Phase 62)
- `print.creel_schedule()` ASCII monthly calendar grid + `knit_print.creel_schedule()` pandoc pipe-table S3 methods with dynamic day-type abbreviation collision resolution (Phase 63)
- `attach_count_times()` cross-join of `generate_schedule()` and `generate_count_times()` outputs into one row per (date × period × count_window) (Phase 63.1)
- `estimate_effort_aerial_glmm()` — GLMM-based aerial effort estimator using `lme4::glmer.nb()` with Askey (2018) quadratic diurnal correction, delta method and bootstrap SE, returning `creel_estimates` with `se_within = NA` (Phase 64)
- `aerial-glmm.Rmd` vignette with decision guide, worked example using `example_aerial_glmm_counts`, full aerial pipeline (effort → catch rate → total catch), and simple vs. GLMM comparison (Phase 64-65)
- pkgdown reference index completed: `attach_count_times`, `estimate_effort_aerial_glmm`, `example_aerial_glmm_counts` added; all v1.2.0 audit gaps closed (Phase 65)

---

## v1.1.0 Planning Suite Completeness & Community Health (Shipped: 2026-04-02)

**Phases completed:** 3 phases (57-59), 4 plans
**Code delivered:** `generate_count_times()` + 26 tests; extended `survey-scheduling.Rmd`; GitHub issue templates + `CONTRIBUTING.md` — 19 files, +1,764/-223 lines

**Key accomplishments:**
- `generate_count_times()` — within-day count time window generator with random, systematic, and fixed strategies; seed reproducibility; returns `creel_schedule` compatible with `write_schedule()` (Phase 57)
- 26 new COUNT-TIME tests (COUNT-TIME-01–03); all 72 schedule-generator tests passing (Phase 57)
- `survey-scheduling.Rmd` extended with full pre/post-season narrative: `generate_count_times()` → `validate_design()` → `check_completeness()` → `season_summary()` — closes v0.9.0 vignette gap (Phase 58)
- Bug report form upgraded with survey_type single-select dropdown (5 types + "not applicable/unsure"), version field, structured expected/actual behavior textareas (Phase 59)
- Feature request form created; `config.yml` with `blank_issues_enabled: false` routes how-to questions to GitHub Discussions (Phase 59)
- `CONTRIBUTING.md` rewritten (189→233 lines): Getting Help (Discussions first) → Filing Issues → PR Guidelines (Phase 59)

---

## v1.0.0 Package Website (Shipped: 2026-03-31)

**Phases completed:** 5 phases (52-56), 8 plans
**Infrastructure delivered:** pkgdown site, Bootstrap 5 theme, GitHub Actions CI/CD, GitHub Pages deployment
**Known gaps:** STICKER-01/02/03 checkboxes not updated — Phase 52 intentionally skipped (existing `man/figures/logo.png` and `inst/hex/sticker.R` retained; brand color `#1B4F72` confirmed carried into pkgdown theme)

**Key accomplishments:**
- Hex sticker assets (`inst/hex/sticker.R`, `man/figures/logo.png`) retained and committed; brand color `#1B4F72` established as primary pkgdown theme color (Phase 52)
- Full Bootstrap 5 pkgdown theme: bslib palette, Google Fonts (Raleway/Lato/Fira Code), `pkgdown/extra.css` with dark code blocks and pandoc syntax token overrides; `pkgdown::check_pkgdown()` 0 warnings (Phase 53)
- README polished as compelling home page with R CMD check and deploy badges, five survey types, and feature highlights; all 46 exports + 15 datasets in 9 named reference topic groups (Phase 54)
- Workflow-driven navbar: Get Started, Survey Types dropdown, Estimation dropdown, Reporting & Planning dropdown, Reference link, NEWS Changelog page (Phase 55)
- `.github/workflows/pkgdown.yaml` auto-deploys to `gh-pages` on push to main; PR build-only guard skips deploy step; live site at https://chrischizinski.github.io/tidycreel — 5 successful CI runs confirmed (Phase 56)

---

## v0.9.0 Survey Planning and Quality of Life (Shipped: 2026-03-24)

**Phases completed:** 4 phases, 10 plans, 0 tasks

**Key accomplishments:**
- (none recorded)

---

## v0.8.0 Non-Traditional Creel Designs (Shipped: 2026-03-22)

**Phases completed:** 4 phases (44-47), 11 plans
**Quality metrics:** 1696 tests passing, R CMD check 0 errors 0 warnings, 0 lintr issues
**Code delivered:** ~78,500 LOC R total; 64 files changed, 8,772 insertions

**Key accomplishments:**
- `VALID_SURVEY_TYPES` enum guard locks dispatch surface — unknown `survey_type` values abort with `cli_abort()` before any estimation runs (Phase 44)
- Ice fishing survey support: degenerate bus-route with `p_site = 1.0` enforcement, `effort_type` distinction (time-on-ice / active-fishing-time), `shelter_mode` stratification (Phase 45)
- Remote camera counter mode: daily ingress counts route through existing access-point effort path with `camera_status` gap handling for non-random failures (Phase 46)
- Remote camera ingress-egress mode: `preprocess_camera_timestamps()` converts POSIXct timestamp pairs to daily effort hours before estimation (Phase 46)
- Aerial survey support: `estimate_effort_aerial()` using `svytotal × (h_open / visibility_correction)`, AIR-04 numeric validation, optional visibility correction factor (Phase 47)
- All three survey types carry full interview pipelines (`add_interviews()` → `estimate_catch_rate()` → `estimate_total_catch()`) with zero changes to rate/product estimators
- Six example datasets (`example_ice_*`, `example_camera_*`, `example_aerial_*`) and three end-to-end workflow vignettes shipped

---

## v0.7.0 Spatially Stratified Estimation (Shipped: 2026-03-15)

**Phases completed:** 5 phases, 9 plans, 0 tasks

**Key accomplishments:**
- (none recorded)

---

## v0.4.0 Bus-Route Survey Support (Shipped: 2026-02-28)

**Phases completed:** 29 phases, 51 plans, 14 tasks

**Key accomplishments:**
- (none recorded)

---

## v0.1.0 Foundation - Instantaneous Counts (Shipped: 2026-02-09)

**Phases completed:** 7 phases, 12 plans
**Quality metrics:** 253 tests, 88.75% coverage, 0 lintr issues, R CMD check clean
**Code delivered:** 1,600 LOC R

**Key accomplishments:**
- Three-layer architecture (API → Orchestration → Survey) proven working end-to-end
- Design-centric API with tidy selectors operational — creel_design() as single entry point
- Progressive validation system (Tier 1 fail-fast + Tier 2 warnings + escape hatches)
- Complete estimation capability — total and grouped estimates with Taylor/bootstrap/jackknife variance
- Production-ready quality gates — zero lintr issues, R CMD check passing, comprehensive test coverage
- Full documentation suite — roxygen2 docs, example datasets, Getting Started vignette

---

## v0.2.0 Interview-Based Estimation (Shipped: 2026-02-11)

**Phases completed:** 5 phases (8-12), 10 plans
**Quality metrics:** 610 tests, 89.24% coverage, 0 lintr issues, R CMD check clean
**Code delivered:** 8,599 LOC R total (+~2,500 LOC for interview features)

**Key accomplishments:**
- Interview data integration with add_interviews() using tidy selectors for catch, effort, and harvest
- Ratio-of-means CPUE and harvest estimation via survey::svyratio with sample size validation
- Total catch and harvest estimation combining effort × CPUE with delta method variance propagation
- Comprehensive documentation with interview-based estimation vignette demonstrating complete workflow
- 89.24% test coverage with 610 tests passing, all quality gates met (R CMD check clean, lintr 0 issues)

---

## v0.3.0 Incomplete Trips & Validation (Shipped: 2026-02-16)

**Phases completed:** 8 phases (13-20), 16 plans
**Quality metrics:** 718 tests, ~90% coverage, 0 lintr issues, R CMD check clean
**Code delivered:** 15,756 LOC R total

**Key accomplishments:**
- Trip metadata infrastructure with trip_status and trip_duration validation following TDD
- Mean-of-ratios (MOR) estimator for incomplete trips via survey::svymean on individual catch/effort ratios
- Complete trip defaults prioritizing scientifically valid roving-access design (Colorado C-SAP)
- TOST equivalence testing framework to statistically validate incomplete vs. complete trip comparability
- Sample size warnings when <10% complete trips with Colorado C-SAP and Pollock et al. references
- 794-line comprehensive vignette with scientific rationale, best practices, and validation workflow guide

---
