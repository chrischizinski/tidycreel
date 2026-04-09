# tidycreel

## What This Is

tidycreel is an R package providing a tidy, pipe-friendly interface for creel survey design, data management, estimation, and reporting. Built on the `survey` package for robust design-based inference, it lets fisheries biologists work in domain vocabulary — dates, strata, counts, effort, catch, species — without managing survey design internals directly. The package targets creel biologists using Nebraska Game and Parks' SQL Server creel database (accessible via REST API or direct connection) and anyone with similarly structured interview/catch/length data.

## Previous Milestones Shipped

- **v1.2.0** (2026-04-06): Documentation, Visual Calendar & GLMM Aerial — 4 vignettes, `print.creel_schedule()` + `knit_print.creel_schedule()`, `attach_count_times()`, `estimate_effort_aerial_glmm()` (Askey 2018, lme4)
- **v1.1.0** (2026-04-02): Planning Suite Completeness & Community Health — `generate_count_times()`, extended `survey-scheduling.Rmd`, structured GitHub issue forms, `CONTRIBUTING.md` rewrite

## Core Value

Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ `creel_design()` — single entry point for survey design with tidy selectors — v0.1.0
- ✓ `add_counts()` — attach instantaneous count observations with validation — v0.1.0
- ✓ `estimate_effort()` — total and grouped effort with Taylor/bootstrap/jackknife variance; section dispatch with correlated-domain aggregation — v0.1.0–v0.7.0
- ✓ `add_interviews()` — attach party-level interview data (catch, effort, harvest, trip metadata) — v0.2.0
- ✓ `estimate_catch_rate()` — catch rate via ratio-of-means or mean-of-ratios; section-aware (no lake total, rates not additive) — v0.2.0 *(renamed from `estimate_cpue()` in v0.7.0)*
- ✓ `estimate_harvest_rate()` — harvest rate from interview data; section-aware — v0.2.0 *(renamed from `estimate_harvest()` in v0.7.0)*
- ✓ `estimate_release_rate()` — release rate; section-aware — v0.5.0
- ✓ `estimate_total_catch()` / `estimate_total_harvest()` / `estimate_total_release()` — totals with delta method variance; section dispatch with sum(TC_i) lake total — v0.2.0–v0.7.0
- ✓ `validate_incomplete_trips()` — TOST equivalence testing for incomplete vs complete trips — v0.3.0
- ✓ `summarize_trips()` — trip status, duration, completeness — v0.3.0
- ✓ Bus-route survey support — correct πᵢ = p_site × p_period, enumeration expansion, HT estimators — v0.4.0
- ✓ Bus-route accessors: `get_sampling_frame()`, `get_inclusion_probs()`, `get_enumeration_counts()`, `get_site_contributions()` — v0.4.0
- ✓ `add_catch()` — long-format species-level catch data with tidy selectors and validation — v0.5.0
- ✓ `add_lengths()` — individual and binned fish length data with auto-format detection — v0.5.0
- ✓ Seven interview-level unextrapolated summary functions (`summarize_refusals()`, `summarize_by_day_type()`, etc.) — v0.5.0
- ✓ `summarize_cws_rates()` / `summarize_hws_rates()` — caught/harvested-while-sought rates — v0.5.0
- ✓ `summarize_length_freq()` — length frequency distributions — v0.5.0
- ✓ Species-level grouping in all estimation functions — v0.5.0
- ✓ Multiple counts per PSU — count_time_col, within-day aggregation, Rasmussen two-stage variance (se_between/se_within) — v0.6.0
- ✓ Progressive count estimator — circuit_time, Ê_d computation — v0.6.0
- ✓ `add_sections()` — spatial section registration with validation — v0.7.0
- ✓ Section dispatch for all estimators — SECT-01..05, RATE-01..03, PROD-01..02 — v0.7.0
- ✓ `missing_sections` guard — NA row + cli_warn() for registered sections absent from data — v0.7.0
- ✓ `example_sections_*` datasets and section-estimation vignette — v0.7.0

### Validated (v1.2.0 — Documentation, Visual Calendar & GLMM Aerial)

<!-- Shipped in v1.2.0 -->

- ✓ `print.creel_schedule()` — ASCII monthly calendar grid with day-type and circuit assignment per date cell; dynamic abbreviation collision resolution — v1.2.0
- ✓ `knit_print.creel_schedule()` — pandoc pipe-table monthly calendar for R Markdown/Quarto; auto-loads via knitr — v1.2.0
- ✓ `attach_count_times()` — cross-join `generate_schedule()` and `generate_count_times()` outputs into one row per (date × period × count_window) — v1.2.0
- ✓ `estimate_effort_aerial_glmm()` — GLMM-based aerial effort estimator (`lme4::glmer.nb()`, Askey 2018 quadratic diurnal correction, delta method + bootstrap SE); returns `creel_estimates` compatible with all downstream estimators — v1.2.0
- ✓ `example_aerial_glmm_counts` — example dataset for GLMM aerial estimator — v1.2.0
- ✓ survey-tidycreel vignette — side-by-side `survey` package vs. tidycreel comparison for effort + catch rate + total catch workflow — v1.2.0
- ✓ effort-pipeline vignette — conceptual walkthrough of PSU construction, Rasmussen two-stage variance, progressive count estimator with annotated LaTeX — v1.2.0
- ✓ catch-pipeline vignette — ROM vs MOR estimator choice and delta method variance decomposition — v1.2.0
- ✓ aerial-glmm vignette — decision guide, worked example, full aerial E2E pipeline (effort → catch rate → total catch), simple vs. GLMM comparison — v1.2.0
- ✓ DESCRIPTION version backfilled to 1.1.0; NEWS.md rewritten with dated changelog for v1.0.0 and v1.1.0 — v1.2.0
- ✓ pkgdown reference index complete: all v1.2.0 exports and datasets in named topic sections — v1.2.0

### Validated (v1.1.0 — Planning Suite Completeness & Community Health)

<!-- Shipped in v1.1.0 -->

- ✓ `generate_count_times()` — within-day count time window generator with random, systematic, and fixed strategies; seed reproducibility; returns `creel_schedule` compatible with `write_schedule()` — v1.1.0
- ✓ `survey-scheduling.Rmd` extended with full pre/post-season narrative: `generate_count_times()` → `validate_design()` → `check_completeness()` → `season_summary()` — v1.1.0
- ✓ GitHub structured issue forms: bug report with survey_type dropdown (5 types + "not applicable/unsure"); feature request with problem/solution/use-case/survey-types fields — v1.1.0
- ✓ `config.yml` with `blank_issues_enabled: false` routing how-to questions to GitHub Discussions — v1.1.0
- ✓ `CONTRIBUTING.md` rewritten with Getting Help (Discussions first), Filing Issues, PR Guidelines, and tidycreel coding standards — v1.1.0

### Validated (v1.0.0 — Package Website)

<!-- Shipped in v1.0.0 -->

- ✓ pkgdown site with Bootstrap 5 bslib theme, Google Fonts (Raleway/Lato/Fira Code), custom `extra.css` (dark code blocks, pandoc token overrides) — v1.0.0
- ✓ Polished README home page with R CMD check / deploy badges and feature highlights for five survey types — v1.0.0
- ✓ Grouped reference index: 46 exports + 15 example datasets in 9 named topic sections — v1.0.0
- ✓ Workflow-driven navbar: Get Started, Survey Types, Estimation, Reporting & Planning dropdowns + Reference link + NEWS Changelog — v1.0.0
- ✓ GitHub Actions `pkgdown.yaml`: auto-deploys to `gh-pages` on push to main; PR builds run without deploy step — v1.0.0
- ✓ Live site at https://chrischizinski.github.io/tidycreel — v1.0.0

### Validated (v0.9.0 — Survey Planning & Quality of Life)

<!-- Shipped in v0.9.0 -->

- ✓ `generate_schedule()` — sampling calendar generator (date range, weekday/weekend split, periods, intensity → creel_schedule tibble) — v0.9.0
- ✓ `generate_bus_schedule()` — bus-route circuit/site/crew assignment with inclusion_prob columns for creel_design() — v0.9.0
- ✓ `write_schedule()` — export schedule tibble to CSV or xlsx (writexl, Suggests) — v0.9.0
- ✓ `read_schedule()` — read a saved schedule back in as a validated `creel_schedule` object with correct column types — v0.9.0
- ✓ `creel_n_effort()` — days required to achieve target CV on effort (McCormick & Quist 2017) — v0.9.0
- ✓ `creel_n_cpue()` — interviews required to achieve target CV on CPUE (Cochran ratio estimator) — v0.9.0
- ✓ `creel_power()` — change-detection power calculator (% CPUE shift between seasons) — v0.9.0
- ✓ `cv_from_n()` — expected CV given sample size (inverse of effort/CPUE calculators) — v0.9.0
- ✓ `validate_design()` — pre-season pass/warn/fail per stratum (calls n calculators internally) — v0.9.0
- ✓ `check_completeness()` — post-season: missing days, low-sample strata, refusal rates (survey-type-aware) — v0.9.0
- ✓ `season_summary()` — assemble pre-computed creel_estimates into report-ready wide tibble — v0.9.0

### Validated (v0.8.0 — Non-Traditional Creel Designs)

<!-- Shipped and confirmed working in v0.8.0 -->

- ✓ Aerial survey support — `estimate_effort_aerial()` using `svytotal × (h_open / visibility_correction)`, numeric validation, interview pipeline — v0.8.0
- ✓ Remote camera survey support — counter mode (access-point path) + ingress-egress mode (`preprocess_camera_timestamps()`), `camera_status` gap handling — v0.8.0
- ✓ Ice fishing survey support — degenerate bus-route with `p_site = 1.0`, `effort_type` distinction, `shelter_mode` stratification — v0.8.0
- ✓ All three extend `creel_design()` as the single entry point — confirmed zero changes to rate/product estimators — v0.8.0

### Active

<!-- v1.3.0 scope — building toward these. -->

- [ ] `creel_schema` S3 class in tidycreel with column mapping, table identity, validation, survey type tagging
- [ ] `tidycreel.connect` package with YAML config, `creel_connect()`, `fetch_*()` loaders
- [ ] SQL Server (NGPC) and flat file/CSV backends

### Out of Scope

- Real-time/online data pull from creel API — package is data-model agnostic; users pull data themselves
- Zero-inflated negative binomial camera count modeling — model-based, requires `glmmTMB`, deferred
- Bayesian integration for multi-method designs (Su & Liu 2025) — deferred
- Geographic summaries (zip/county tabulation via external lookup) — deferred
- Full report rendering (Rmd/PDF template reproducing NGPC report structure) — deferred
- Supplemental question tabulation — deferred

## Current Milestone: v1.3.0 Generic DB Interface

**Goal:** Define a `creel_schema` S3 contract in tidycreel and bootstrap a companion package `tidycreel.connect` that loads data from any backend into tidycreel-ready form via a YAML config file.

**Target features:**
- `creel_schema` S3 class in tidycreel (column mapping, table identity, validation, survey type tagging)
- `tidycreel.connect` package skeleton with YAML config format
- `creel_connect()` returning a connection object
- `fetch_*()` loaders for all 5 creel tables
- SQL Server (NGPC production) and flat file/CSV backends

## Current State (v1.2.0 — shipped 2026-04-06)

**Package status:** 12 milestones shipped, 65 phases; ~1,864+ tests; DESCRIPTION version 1.1.0 (backfilled in v1.2.0)
**Stack:** R package, survey + lme4 (Suggests) for inference; tidy API with tidyselect; pkgdown Bootstrap 5 site; GitHub issue forms + Discussions
**Architecture:** Three-layer (API → Orchestration → Survey) proven across all 5 survey types; planning layer independent; GLMM aerial estimator follows same creel_estimates return contract
**Survey types supported:** `instantaneous`, `bus_route`, `ice`, `camera`, `aerial` (simple + GLMM)
**Estimation API:** effort, catch rate, harvest rate, release rate, total catch/harvest/release, species-level; aerial GLMM; section dispatch with correlated-domain variance
**Planning suite:** `generate_schedule()`, `generate_bus_schedule()`, `generate_count_times()`, `attach_count_times()`, `write_schedule()`, `read_schedule()`, `creel_n_effort()`, `creel_n_cpue()`, `creel_power()`, `cv_from_n()`, `validate_design()`, `check_completeness()`, `season_summary()`
**Documentation:** 8 vignettes (Get Started, survey-scheduling, survey-tidycreel, effort-pipeline, catch-pipeline, section-estimation, aerial-GLMM × 3 survey-type vignettes); pkgdown reference index complete
**Website:** https://chrischizinski.github.io/tidycreel (pkgdown, auto-deployed via GitHub Actions)
**Next milestone:** v1.3.0 Generic DB Interface (planning in progress)

## Context

### Data Model (from Nebraska creel database)

The creel database has three analysis tables used by tidycreel:

**interviews** (`vwCombinedR_InterviewData_wSupplemental`) — one row per angling party:
- `cd_Date`, `cd_Period`, `cd_Section` — when/where
- `ii_Refused` — refused interview flag
- `ii_NumberAnglers` — party size
- `ii_AnglerType` — bank (1) or boat (2) — code table
- `ii_AnglerMethod` — fishing method — code table
- `ii_TimeFishedHours` / `ii_TimeFishedMinutes` — effort
- `ii_TripType` — complete/incomplete — code table
- `ii_SpeciesSought` — target species — code table
- `ii_ZipCode` — angler origin
- `ii_UID` — interview unique key
- Supplemental question columns

**catch** (`vwCombinedR_CatchData`) — one row per species per interview:
- `ii_UID` — links to interview
- `ir_Species` — species code
- `Num` — count
- `CatchType` — caught / harvested / released

**harvest_lengths** (`vwCombinedR_HarvestLengthData`) — one row per fish:
- `ii_UID`, `ih_Species`, `ihl_Length`

**release_lengths** (`vwCombinedR_ReleasedLengthData`) — by length group:
- `ii_UID`, `ir_Species`, `ir_LengthGroup`, `ir_Count`
- Note: may also have individual lengths depending on creel; handle both formats

### Existing Reference Code

- `/Users/cchizinski2/Documents/git2/creel/` — legacy R scripts using SQL Server and REST API
- `CreelApiHelper.R` — REST API endpoints
- `CreelDataAccess.R` / `CreelDataAccess_CJCedits.R` — data access layer
- `CreelAnalysisFunctionsCJCEDits.R` — full legacy analysis pipeline
- `spawn report.Rmd` / `StandardReportTemplate mattWorkspace.Rmd` — existing report templates

### Report Structure (from examples/ PDFs)

Reports have 3 sections: (1) Design Parameters, (2) Unextrapolated Summaries, (3) Extrapolated Estimates. The package currently produces (3). v0.5.0 adds the data model to support (2).

### Architecture

Three-layer: API → Orchestration → Survey package. The dispatch pattern (check survey_type and data availability before survey package calls) is established and working across instantaneous and bus-route designs.

## Constraints

- **R package**: Must pass R CMD check with 0 errors, 0 warnings, clean lintr
- **survey package**: All design-based inference goes through `survey::` — no custom variance formulas
- **tidy API**: Tidy selectors (tidyselect) for all column references, never character strings
- **Test coverage**: Maintain ~90%+ test coverage (currently 1,098 tests)
- **Backward compatibility**: Existing `add_interviews()` API must not break — new parameters are additional/optional

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Three-layer architecture (API → Orchestration → Survey) | Isolates domain vocabulary from survey package internals | ✓ Good — absorbed bus-route without structural change |
| `creel_design()` as single entry point | Prevents design inconsistency; validates at construction time | ✓ Good — progressive validation works |
| `trip_status` required parameter for add_interviews() | Breaking change accepted — scientifically necessary for MOR vs ROM selection | ✓ Good — forces explicit decision |
| πᵢ = p_site × p_period (not interview probability) | Corrects all existing R implementations; primary source (Jones & Pollock 2012) | ✓ Good — Malvestuto Box 20.6 reproduced exactly |
| Catch data in long format (one row per species per interview) | Matches database schema; enables species-level grouping | ✓ Validated — v0.5.0 |
| Release lengths: handle both individual and binned formats | Database stores both; midpoint normalization for binned | ✓ Validated — v0.5.0 |
| `normalize_by_anglers` removed from all rate functions | `add_interviews(n_anglers=1)` default + unconditional `angler_effort_col` is simpler | ✓ Validated — v0.5.0 |
| Geographic summaries deferred | Requires external zip-county lookup; out of v0.5.0–v0.7.0 scope | — Pending |
| Report rendering deferred | Tidy tibbles are the deliverable; rendering is separate concern | — Pending |
| `svyby(covmat=TRUE)` + `svycontrast()` for section aggregation | Sections share day-level PSUs so naive Cochran 5.2 additivity would underestimate SE | ✓ Good — correlated-domain path is default, independent available for genuinely separate designs |
| Rate estimators produce no `.lake_total` row | Rates are not additive — lake-wide rate requires separate unpooled call | ✓ Good — enforced by design, documented in vignette |
| `sum(TC_i)` not `E_total × CPUE_pooled` for product lake total | Section-specific effort and CPUE interact; pooled estimator conflates spatial variation | ✓ Good — matches standard spatially stratified survey literature |
| Breaking rename: `estimate_cpue()` → `estimate_catch_rate()`, `estimate_harvest()` → `estimate_harvest_rate()` | v0.7.0 API consistency; no deprecated wrappers | ✓ Good — clean break, documented in NEWS.md |
| Ice as degenerate bus-route (`p_site = 1.0`) | Reuses HT estimator path without a new code branch; synthetic bus_route slot enables add_interviews() | ✓ Good — confirmed in v0.8.0; intersect() guard pattern established |
| Camera uses standard instantaneous path (not bus-route) | counter/ingress-egress both feed add_counts() → estimate_effort() without special dispatch | ✓ Good — no estimator changes required for CAM-04 |
| `preprocess_camera_timestamps()` as preprocessing step | Converts POSIXct pairs to daily effort before estimation entry; keeps estimators clean | ✓ Good — NSE via rlang::as_name(rlang::enquo()) consistent with existing compute_effort() pattern |
| Aerial effort = `svytotal × (h_open / v)` (linear, no delta method) | h_open and v are fixed calibration constants, not sample estimates — SE scales linearly | ✓ Good — confirmed by constructed numeric example (111 × 14 = 1554 angler-hours) |
| `visibility_correction` defaults to 1.0 (no correction) when NULL | Maintains backward compatibility; user opt-in for calibration | ✓ Good — mirrors effort_type required pattern for ice |
| Planning layer is design-independent (no `creel_design` dependency) | `creel_n_effort()` / `creel_n_cpue()` work from parameters alone; `validate_design()` calls them internally — avoids circular coupling | ✓ Good — confirmed in v0.9.0; pure-function approach |
| `validate_design()` delegates to `creel_n_effort()` / `creel_n_cpue()` (no local CV formula) | Single source of truth for sample-size math; WARN_CV_BUFFER (1.2) is the only additional constant | ✓ Good — DRY design, easy to audit |
| `check_completeness()` uses `intersect()` guard on strata_cols | Avoids false-positive flags for synthetic ice columns (`.ice_site`, `.circuit`) present in the design but not in interview data | ✓ Good — consistent with ice degenerate bus-route pattern |
| `season_summary()` uses by_vars consistency guard before wide assembly | Uniform stratification contract across all creel_estimates in the named list; fails fast with clear error if strata differ | ✓ Good — prevents silently misaligned wide tibble |
| Schedule I/O reads all columns as text first, then coerces | Identical coercion path for CSV and xlsx; avoids format-specific type inference bugs (e.g., Excel serial dates) | ✓ Good — coerce_schedule_columns() is the single coercion layer |
| Statistical notation kept as-is with `nolint: object_name_linter` | N_h, E_total, V_0 match textbook formulas exactly; renaming would destroy readability against Cochran (1977) | ✓ Good — documented convention, not an oversight |
| `pkgdown` in DESCRIPTION `Suggests` (not `Imports`) | Build tool, not runtime dependency — users don't need pkgdown to use tidycreel | ✓ Good — standard R package convention |
| `docs/` excluded from `main` via `.gitignore`; deploy to `gh-pages` orphan branch | Keeps built HTML out of main history; gh-pages branch is the deploy target, not the source | ✓ Good — standard pkgdown/GitHub Pages pattern |
| Brand color `#1B4F72` set in Phase 52 sticker before Phase 53 reads it | Single source of truth for palette; sticker and site theme use same primary hex value | ✓ Good — established dependency ordering that prevents color drift |
| Phase 52 (Hex Sticker) skipped — existing logo.png retained | Existing PNG and sticker.R were already committed and sufficient; re-generation would add no value | ✓ Good — user decision; STICKER requirements satisfied by existing assets |
| PR deploy step guarded by `github.event_name != 'pull_request'` | Build always runs on PRs; deploy only on push to main — catches config errors before merge | ✓ Good — standard r-lib/actions v2 pattern |
| `generate_count_times()` returns `creel_schedule` S3 class (not plain tibble) | Consistent with `generate_schedule()` output; `write_schedule()` compatibility guaranteed by shared class | ✓ Good — planning functions share a uniform output contract |
| Fixed-strategy `generate_count_times()` accepts user-supplied windows data frame | Allows pre-specified windows without forcing a generator algorithm; consistent with systematic/random strategies being procedural | ✓ Good — three-strategy design covers random, systematic, and deterministic scheduling |
| `survey-scheduling.Rmd` `season_summary()` chunk marked `eval=FALSE` | Estimation pipeline (estimate_effort etc.) belongs in main vignette; scheduling vignette covers planning only | ✓ Good — clean separation of planning vs. estimation documentation |
| `blank_issues_enabled: false` in `config.yml` | Forces template selection; reduces low-context issue noise; how-to questions routed to Discussions | ✓ Good — structured issue forms produce better bug reports |
| Getting Help moved to top of `CONTRIBUTING.md` | First-time contributors see community channels before technical standards; reduces friction for non-coders | ✓ Good — onboarding order matters for contributor experience |

| `print.creel_schedule()` uses dynamic k-length abbreviations with collision detection | Day-type/circuit labels can collide at default lengths; truncate-and-extend to k=5 as fallback | ✓ Good — WEEKD/WEEKE collision pattern established |
| `knit_print.creel_schedule()` auto-activates via `registerS3method()` in `.onLoad()` | Eliminates `library(knitr)` dependency in user vignette preamble | ✓ Good — consistent with R package knitr integration convention |
| `attach_count_times()` cross-join returns `creel_schedule` S3 class | Output feeds directly into `write_schedule()` without class coercion step | ✓ Good — uniform planning function output contract |
| GLMM aerial estimator uses `lme4` in `Suggests`, not `Imports` | lme4 is optional; simple aerial covers most users; fail-fast `cli_abort()` if missing | ✓ Good — consistent with pkgdown/writexl optional-dependency pattern |
| Bootstrap SE path (`bootMer`) tested only via integration test; delta method is primary | Bootstrap is computationally expensive; delta method covers the default path; bootMer path tested by existence | ✓ Good — documented as known test gap in audit |
| Concept-first vignettes use annotated LaTeX + by-hand confirmed numerics | Biologists learn by connecting formulas to computed numbers; abstract formula alone is insufficient | ✓ Good — confirmed approach by Phase 62 vignette structure |
| Gap-closure phases use a single plan covering all audit findings atomically | Avoids multiple tiny plans for related fixes; keeps audit → closure traceability clear | ✓ Good — Phase 65 pattern established |
| `requirements-completed` frontmatter field added to SUMMARY.md when requirement verified post-hoc | Enables cross-phase requirement traceability without re-reading full phase | ✓ Good — Phase 65 retroactively tagged Phase 61 summary |

---
*Last updated: 2026-04-06 after v1.2.0 milestone archived*
