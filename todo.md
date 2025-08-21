tidycreel — Roadmap & ToDo (Last updated: 2025-08-21)

Guiding Principles
- Survey-first: Build inference on `survey`/`svrepdesign` (Taylor or replicates).
- Tidy + vectorized: Use `dplyr`/`tidyr` grouped ops; avoid loops.
- Consistent UX: CLI-styled errors/warnings; clear diagnostics.
- Reproducible: Vignettes runnable; examples minimal but complete.

Recurring Checks
- [ ] Review diagnostics and warnings in constructors/estimators (dropped rows, NA weights, misaligned strata).
- [ ] Keep examples and vignettes runnable; update when APIs change.
- [ ] Maintain living docs (tidycreel_designs.md) with assumptions/edge cases.

Phase 1 — Core Infrastructure (Completed)
- [x] `renv` setup and lockfile
- [x] CI: R CMD check (macOS + Ubuntu), lintr
- [x] Package skeleton, DESCRIPTION/NAMESPACE
- [x] Sample data folder scaffold

Phase 2 — Survey Design Objects (Status)
- [x] Access-point, Roving, Replicate-weights constructors (`creel_design`)
- [x] Bus-route design (unequal-prob weights via `svydesign`)
- [x] Metadata + S3 print/summary methods
- [x] Conversion helpers: `as_survey_design()`, `as_svrep_design()`
- [x] Plotting: `plot_design()` and `plot_effort`

Phase 3 — Estimation Core (Status)
- [x] Wrapper: `est_effort()` delegates to survey-first estimators
- [x] Instantaneous: day×group mean × total minutes → `svyby/svytotal`
- [x] Progressive (roving): sum pass (count×route_minutes) → `svyby/svytotal`
- [x] Aerial: visibility/calibration, covariates; optional postStratify/calibrate
- [x] Bus-route: HT contributions; supports replicate designs
- [x] CLI-based validation & diagnostics across estimators
- [x] Return shape: group cols + estimate, se, ci_low, ci_high, n, method, diagnostics
- [ ] Downstream compatibility: `estimate_cpue`, `estimate_catch` alignment
- [ ] Future corrections: incomplete trips, nonresponse, spatial options
- [ ] Custom formula hooks and variance options
- [ ] Plot integration helpers (e.g., `plot_effort` templates)

Phase 4 — Bias Corrections & Variance
- [ ] Incomplete-trip corrections (ratio-of-means consistency)
- [ ] Targeted vs non-targeted species handling
- [ ] Nonresponse adjustments (weighting/calibration)
- [ ] Analytical variance for ratio estimators; compare with replicates
- [ ] Taylor linearization vs replicates guidance

Phase 5 — Survey Design Support
- [x] Access-point, Roving (instant/progressive), Aerial (snapshot), Bus-route (HT)
- [ ] Hybrid designs (e.g., access + roving)
- [ ] Vignette on design trade-offs and replicate designs

Phase 6 — Data Validation & Cleaning
- [ ] Validate input tables for required fields (schemas coverage check)
- [ ] Standardize coding (species codes, effort units)
- [ ] Missing values with warnings; field-level checks
- [ ] `flag_outliers()` for extreme CPUE/effort
- [ ] Auto-report validation (summary tibble + export)

Phase 7 — Output & Reporting
- [ ] `summary.creel_estimate()` table helpers
- [ ] Export to CSV/Excel with metadata footer
- [ ] ggplot themes for consistent output; standard plots
- [ ] Example dashboards (flexdashboard/Shiny stub)

Phase 8 — Documentation & Training
- [x] Function docs updated to survey-first
- [x] Vignettes: `aerial`, `effort_survey_first`
- [x] README: purpose, correct badges, logo, vignette links
- [ ] Vignette: design trade-offs + replicate designs
- [ ] Glossary (effort, CPUE, harvest, strata, PSU, FPC, etc.)

Tests & Data
- [x] Design-based tests for instantaneous, progressive, aerial, bus-route
- [x] Replicate-weight (`svrepdesign`) tests
- [ ] Add minimal toy datasets in `inst/extdata/` for vignettes/tests

Tooling & Site
- [ ] Helpers to scaffold post-stratification/calibration targets tables
- [ ] pkgdown config and navbar surfacing vignettes

Near-term Next Actions
- [ ] Add toy datasets (small CSVs) to `inst/extdata/` and switch vignettes to use them
- [ ] pkgdown site setup; navbar links to “Effort (Survey-First)” and “Aerial”
- [ ] Add vignette: survey design trade-offs + replicate designs (with small examples)
- [ ] CPUE/catch estimators alignment with survey-first pattern

Changelog (2025-08-21)
- Completed survey-first refactor for effort (instantaneous/progressive/aerial/bus-route)
- Added day-PSU helper (`as_day_svydesign`), tests (incl. replicates), vignettes
- Enforced CLI-based errors/warnings; removed legacy code; fixed README badges and added logo
