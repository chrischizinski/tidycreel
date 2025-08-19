You are an expert in Creel Survey methodology, survey sampling, and advanced R package development (devtools/usethis/roxygen2/testthat/pkgdown/renv), with experience publishing to CRAN and building reproducible scientific software.

## Goal
Create a single, detailed MARKDOWN planning document (title it **Creel Package: Architecture & Delivery Plan**) that will guide building and publishing a production-quality R package for creel survey design, data management, estimation, variance, QA/QC, and reporting.

Additionally, create and maintain a **separate file named `todo.md`** that serves as a living task tracker:
- At the start, populate `todo.md` with all actionable tasks from the plan.
- After each task or phase in the plan is completed, mark it as completed (`[x]`) in `todo.md`.
- If new tasks arise during a phase, append them to `todo.md` under the appropriate section.
- Keep `todo.md` concise, actionable, and organized by project phases.
- Always keep `todo.md` synchronized with the plan document.

## Non-negotiable Principles
- **Style:** Follow the tidyverse style guide in full (https://style.tidyverse.org) for naming, layout, documentation tone, and code patterns.
- **Vectorization:** Prefer vectorized operations and grouped (by-strata) computation; avoid explicit loops where possible.
- **Foundations:** Build on the **`survey`** package (https://r-survey.r-forge.r-project.org/survey/) as the authoritative engine for design objects and estimators.
- **Tidy Interface:** Provide a tidy, pipe-friendly interface. Where helpful, interoperate with **`surveyr`** (https://github.com/chrisbrownlie/surveyr). Acknowledge that `surveyr` appears low-activity; prioritize a robust tidy layer over introducing incompatible abstractions.
- **Reproducible Science:** Favor design-based estimators and clearly document assumptions, variance formulas, and limitations.

## Audience
- Primary: R developers and fisheries scientists building and maintaining the package.
- Secondary: Analysts using the package for routine creel estimation and reporting.

## Scope
The document must function as an actionable blueprint. Include rationale, standards, references to widely adopted R tooling, and checklists. Favor existing packages and well-supported libraries over custom code where possible.

## Deliverables (structure your markdown with these top-level sections)
1) **Executive Summary**
   - Purpose, value proposition, key features, target users, and out-of-scope items.

2) **Requirements & Use Cases**
   - Functional requirements: data ingestion, validation, design helpers (day/shift sampling, access vs roving, instantaneous counts), estimation (effort, CPUE, harvest/angler trips), stratification (temporal, spatial, mode), ratio/HT estimators, model-based options (e.g., GLM/GLMM for effort or counts), variance (design-based, bootstrap, delta method), small-sample behavior, optional finite population corrections.
   - Non-functional: correctness, performance, numerical stability, reproducibility, portability, maintainability, API stability, conformance to tidyverse style, vectorization-first.
   - Concrete use cases: (a) access-point survey with day/shift design, (b) roving survey with instantaneous counts, (c) hybrid designs; seasonal rollups, species-specific totals, CPUE, and uncertainty.

3) **Data Model & Schemas**
   - Canonical tidy schemas for:
     - sampling calendar & strata (day type, month/season, weekend/weekday, shift blocks),
     - sampling events/visits,
     - interview data (effort so far, target species, catch/harvest by species, party size),
     - count data (instantaneous counts with location/time stamps, conditions),
     - auxiliary data (sunrise/sunset, holidays, lake metadata),
     - reference tables (species, waterbodies, methods).
   - Required/optional columns, data types, keys, and minimal validation rules.
   - Example toy datasets to ship in `inst/extdata/` and as packaged objects.

4) **Statistical Methods**
   - **Design-based estimators** for effort, catch, harvest, CPUE using `survey::svydesign`/`svrepdesign` objects; ratio estimators; Horvitz–Thompson where applicable; post-stratification and calibration pathways.
   - **Variance estimation** choices (within/between strata, post-stratification, bootstrap options via replicate weights, delta method).
   - Handling zero-catch days, zero-effort strata, extreme values/outliers, partial-day sampling, daylight savings, leap days.
   - Model-based options (e.g., Poisson/NegBin for counts, log-linear or GAM options for effort smoothing) with caveats and clear separation from design-based defaults.
   - Clear formulas and references; describe estimator selection logic and assumptions.

5) **API Design (Tidy over `survey`)**
   - User-facing verbs (pipe-friendly, vectorized, tidy return types):
     - `design_*()` create or derive `survey`/replicate designs from tidy inputs (with explicit `cols = c(...)` mapping).
     - `validate_*()` enforce schema/keys; `.strict = TRUE` option.
     - `ingest_*()` IO helpers for CSV/Parquet/DB sources.
     - `estimate_*()` for effort, CPUE, harvest; internally dispatch to `survey` functions with safe defaults; return tibbles with estimates, SE/CI, and metadata (strata, weights).
     - `summarize_*()`, `bootstrap_*()` (replicate-weight wrappers), `plot_*()` for standard visuals, `report_*()` for knit-ready outputs.
   - Consistent argument names; vectorized/grouped behavior via `dplyr` verbs; S3 print/plot methods where useful.
   - Interop notes: accept and return `survey` design objects; optional helpers to convert to/from `surveyr` idioms.

6) **Package Architecture & File Organization**
   - Use **usethis** scaffolding and recommended layout:
     ```
     creelpkg/
     ├─ R/                      # functions by domain (design, ingest, estimate, variance, report, utils)
     ├─ tests/testthat/         # unit & property tests, snapshot tests
     ├─ vignettes/              # tutorials (getting started, estimation, design choices, variance)
     ├─ inst/extdata/           # toy csv/parquet examples
     ├─ inst/templates/         # report templates (Quarto/Rmd)
     ├─ man/                    # roxygen2-generated docs
     ├─ data/                   # packaged example datasets (.rda)
     ├─ _pkgdown.yml            # site config
     ├─ CITATION.cff
     ├─ codemeta.json
     ├─ NAMESPACE, DESCRIPTION
     └─ renv/ + renv.lock       # reproducible env
     ```
   - Enforce tidyverse style with **styler**/**lintr**; use **roxygen2** for docs; **pkgdown** for site; **renv** for reproducibility.

7) **Dependencies & Interop**
   - Core: `survey` (design objects, estimation, variance).
   - Tidy stack: `dplyr`, `tidyr`, `tibble`, `purrr`, `rlang`, `vctrs`, `stringr`, `lubridate`, `janitor`.
   - IO & performance: `readr`, `arrow`/`vroom` for fast IO; optional `data.table` for high-volume backends.
   - Repro/workflows: `targets` (or `drake`) for pipelines; `DBI` + drivers for DB access; `qs` for fast serialization.
   - Visualization & reporting: `ggplot2`, `gt` or `flextable`, Quarto templates.
   - Optional interop: `surveyr` (low-activity) where it complements the tidy interface without fragmenting the API.

8) **Documentation Plan**
   - Function-level docs with roxygen2 (arguments, returns, examples, references).
   - Vignettes:
     1) Intro & data model (tidy schemas → `survey` design objects),
     2) Design & sampling calendars,
     3) Estimation & variance (with replicate weights and delta method),
     4) Model-based extensions,
     5) End-to-end example with reporting.
   - pkgdown site: navbar, reference index, articles, examples.
   - README (badges, quickstart), CONTRIBUTING, CODE_OF_CONDUCT, governance notes.

9) **Testing Strategy (Comprehensive)**
   - **Unit tests** with **testthat** for every estimator, helper, and validator (including `survey` object creation and edge cases).
   - **Property-based tests** (e.g., `quickcheck`/`hedgehog`) for invariants: non-negative estimates; monotonicity; invariance under row order; stability under effort/catch scaling where expected.
   - **Snapshot tests** for printed outputs and summaries.
   - **Edge Cases** (explicit sets):
     - zero/near-zero counts and effort; empty strata; single-day seasons; missing shifts; leap day; DST transitions; duplicated rows; out-of-range species codes; mixed time zones; extreme outliers; partial interviews; multiple lakes with uneven coverage; post-stratification mismatches; FPC on/off; very small strata; large-N memory pressure.
   - **Numerical stability**: analytic vs replicate-weight/Bootstrap SEs within tolerance; randomized seeds for reproducible resampling.
   - **Reference tests**: verify against hand-computed toy examples and known `survey` results.
   - Coverage targets: ≥90% line + meaningful branch coverage; `covr` + badge.

10) **Performance & Scaling**
    - Benchmarks with `bench`/`microbenchmark`; data sizes from 10^3 to 10^7 rows.
    - Vectorization and grouped summaries; optional `data.table` backends for heavy workloads.
    - Parallel resampling via `future`/`furrr`; document deterministic seeds.

11) **CI/CD & QA**
    - GitHub Actions using `r-lib/actions`:
      - `R CMD check` on macOS/Windows/Ubuntu, devel/release/oldrel;
      - test coverage reporting;
      - lintr/styler checks;
      - pkgdown site deploy on main;
      - release workflow (tags, NEWS).
    - Pre-commit hooks for lint/style and roxygen docs.

12) **Reproducibility & Governance**
    - `renv` with pinned versions; session info in vignettes.
    - Semantic versioning; lifecycle badges; CHANGELOG/NEWS.
    - Licensing guidance (code vs data), citation policy, data privacy notes.

13) **Release & Distribution**
    - CRAN readiness checklist: `R CMD check --as-cran`, size limits, Rd completeness, fast examples, no non-temp file writes, no internet in tests.
    - Cross-platform checks (rhub, winbuilder).
    - pkgdown site publish; Zenodo DOI; GitHub release notes; release vignette.

14) **Roadmap**
    - Milestones: v0.1 (MVP estimators + validation), v0.2 (variance & replicate weights), v0.3 (reporting & templates), v1.0 (CRAN), with timelines and acceptance criteria.
    - Backlog: interactive QC dashboards, GIS helpers, database connectors, advanced model-based estimators.

15) **Appendices**
    - Worked toy example (inputs → `svydesign`/`svrepdesign` → estimates → variance → report).
    - Estimator formulas and notation.
    - Data dictionaries (machine-readable).
    - Checklists (developer onboarding, pre-merge, pre-release).

## Style & Output Requirements
- Produce valid, well-structured Markdown with a clickable table of contents.
- Use concise prose plus bullet lists, callout tips, and code blocks where appropriate.
- Include short R code snippets showing API usage (e.g., `estimate_effort()`, `bootstrap_variance()`), demonstrating vectorized, tidy patterns.
- Provide concrete checklists for setup, testing, and release.
- Assume users have intermediate R skills and basic survey sampling knowledge.
- Avoid speculative/novel methods unless clearly marked as optional.
- Keep it pragmatic: decisions + rationale + steps.
- **In addition to `Creel Package: Architecture & Delivery Plan`, output a separate `todo.md`** containing actionable tasks from the plan, organized by project phase, using GitHub checklist format, kept in sync as a living document.

## Final Instruction
Return two files:
1. The finished Markdown document described above, starting with an H1 title “Creel Package: Architecture & Delivery Plan”.
2. A `todo.md` file with all initial actionable tasks from the plan, organized by project phase, using GitHub checklist format.