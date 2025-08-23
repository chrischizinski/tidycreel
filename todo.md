tidycreel — Roadmap & ToDo (Last updated: 2025-08-22)

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
- [x] Bus-route design (lean metadata; inference via survey)
- [x] Conversion helpers: `as_survey_design()`, `as_svrep_design()`
- [ ] Remove remaining legacy references in docs/vignettes (see Pause Checkpoint)

Phase 3 — Estimation Core (Status)
- [x] Wrapper: `est_effort()` delegates to survey-first estimators
- [x] Instantaneous: day×group mean × total minutes → `svyby/svytotal`
- [x] Progressive (roving): sum pass (count×route_minutes) → `svyby/svytotal`
- [x] Aerial: visibility/calibration, covariates; optional postStratify/calibrate
- [x] Bus-route: HT contributions; supports replicate designs
- [x] CLI-based validation & diagnostics across estimators
- [x] Return shape: group cols + estimate, se, ci_low, ci_high, n, method, diagnostics
- [x] Downstream compatibility: CPUE/Catch alignment (new `est_cpue()`, `est_catch()`)
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
- [ ] pkgdown site setup; navbar links to “Effort (Survey-First)”, “Aerial”, and CPUE/Catch
- [ ] Add vignette: survey design trade-offs + replicate designs (with small examples)
- [x] CPUE/catch estimators alignment with survey-first pattern (initial implementation; expand tests/docs)

Pause Checkpoint — 2025-08-22
- Status: All survey-first tests pass (instantaneous, progressive, aerial, bus-route, CPUE/Catch). Legacy design constructors removed; tests updated to use `survey` directly.
- Key recent fixes:
  - Aerial: replicate-weight handling via index alignment; `lonely.psu = "adjust"` for non-rep designs.
  - Bus-route: same replicate handling; robust SE extraction; non-rep designs use `lonely.psu = "adjust"`.
  - CPUE/Catch: grouped `svyratio` uses `stats::coef()`/`survey::SE()`; ungrouped SE via `stats::vcov()`.
  - README updated; tests no longer call legacy constructors.
- On-resume high-priority tasks:
  1) Docs cleanup: remove/replace legacy references (`design_access`, `design_roving`, `design_repweights`). Files to scrub:
     - `vignettes/getting-started.Rmd`
     - `tidycreel_designs.md`
     - `README.Rmd` (CPUE/Catch already updated)
     - any vignette/article linking old constructors
  2) Regenerate docs and namespace: run `devtools::document()` then `devtools::test()` and `devtools::check()`; remove orphaned man pages for deleted exports if any.
  3) pkgdown: ensure `_pkgdown.yml` navbar reflects survey-first pages (Effort, Aerial, CPUE/Catch), and remove links to removed topics.
  4) Add a short CPUE/Catch vignette with toy data example; cross-link from README.
  5) Confirm no remaining exports for removed constructors (`NAMESPACE` is trimmed; verify after roxygen).
  6) Optional: AGENTS.md update to note constructor removal and survey-first backbone.
- Handy commands after resuming:
  - `devtools::document(); devtools::test()`
  - `devtools::check()`
  - `pkgdown::build_site()` (optional)

Changelog (2025-08-21)
- Completed survey-first refactor for effort (instantaneous/progressive/aerial/bus-route)
- Added day-PSU helper (`as_day_svydesign`), tests (incl. replicates), vignettes
- Enforced CLI-based errors/warnings; removed legacy code; fixed README badges and added logo
