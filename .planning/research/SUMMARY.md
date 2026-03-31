# Project Research Summary

**Project:** tidycreel v0.9.0 — Survey Planning, Power Analysis, and Data Quality Tools
**Domain:** R package quality-of-life utilities wrapping an existing design-based creel estimation pipeline
**Researched:** 2026-03-22
**Confidence:** HIGH

## Executive Summary

tidycreel v0.9.0 is a support-tooling milestone that wraps around the five-survey-type estimation pipeline shipped in v0.8.0. The target features are the tools biologists use before and after estimation: schedule generation, sample-size calculations, design validation, data completeness diagnostics, and season summary assembly. Research confirms that the underlying statistical methods (McCormick & Quist 2017 for CV-based sample sizes; Cohen two-sample t-test for change detection; Neyman allocation for stratified designs) are well-established, analytically expressible using the existing `stats` import, and require only two net-new package imports — `lubridate` (date arithmetic, Imports) and `writexl` (optional xlsx export, Suggests only). No new estimation machinery is needed; every new function either produces input for `creel_design()` or consumes its output.

The recommended build strategy is four independent but sequentially testable components, each delivered as one new R source file: schedule generators (`creel-schedule.R`), power and sample-size tools (`creel-power.R`), completeness checkers (`creel-completeness.R`), and export utilities / season summary (`creel-export.R`). The first two components have no internal dependencies and can proceed in parallel. The third reads only stable, long-standing slots of the existing `creel_design` S3 object. The fourth consumes estimator outputs that are unchanged since v0.5.0. Regression risk on the existing 1,696 tests is effectively zero for all four components.

The dominant implementation risk is integration correctness, not statistical complexity. Schedule column names and types must round-trip cleanly through `creel_design()`; power calculations must use the stratified variance formula (not SRS); completeness checks must dispatch by `survey_type` to avoid false-positive NA flags on aerial and ice designs; and the season summary must assemble existing estimator outputs rather than re-deriving values from raw data. Each failure mode is recoverable but expensive after tests are written against the wrong behavior. These guards must be addressed at the start of each component phase, not retrofitted later.

---

## Key Findings

### Recommended Stack

The existing package Imports cover nearly all new functionality. Only two additions are needed. `lubridate >= 1.9.5` supplies `wday()`, period arithmetic, and DST-safe interval math required for season-spanning schedule generation; base R `seq()` with `by = "week"` is insufficient for this use case. `writexl >= 1.5.4` covers the xlsx schedule export requirement with zero transitive R dependencies (pure C binding) and belongs in `Suggests`, not `Imports`. All power and sample-size calculations use `stats::qnorm()`, `stats::qt()`, and `stats::power.t.test()` already available. All completeness checks use `dplyr::anti_join()` and `cli::cli_warn()` already in Imports. Adding `pointblank`, `pwr`, `openxlsx`, or `openxlsx2` to Imports is explicitly not recommended.

**Core technologies:**
- `lubridate >= 1.9.5` (Imports): Date arithmetic for schedule generators — `seq()` alone cannot handle DST, period labels, and `wday()` classification required for stratified calendar output. Published 2026-02-04; 2 small transitive dependencies.
- `writexl >= 1.5.4` (Suggests): xlsx export for schedule and results output — zero-dependency C implementation; optional, graceful failure path via `rlang::check_installed()` when absent. Published 2025-04-15; 0 transitive dependencies.
- `stats` (existing Imports): All analytical power and sample-size formulas — `qnorm()`, `qt()`, `power.t.test()` cover every required calculation without a domain-general effect-size package.
- `dplyr` + `cli` (existing Imports): All completeness diagnostics — `anti_join()` + `cli_warn()` pattern matches the existing missing-sections guard established in v0.7.0.

**What not to add:**
- `pointblank` (Imports): 19 hard Imports including unrelated HTML/email packages; triples dependency footprint for `is.na()` logic achievable with `dplyr`.
- `pwr` (Imports): Cohen's d vocabulary requires user translation of creel domain inputs; `stats::power.t.test()` accepts native creel inputs directly.
- `openxlsx` / `openxlsx2` (Imports): Unmaintained or heavyweight for write-only use; `writexl` in Suggests covers the requirement.
- `samplesize4surveys` (Imports): Last updated 2020; social survey design assumptions; TeachingSampling dependency; misaligned with HT estimators in tidycreel.

### Expected Features

All confirmed features are wrappers or assembly layers over existing functionality; none require new estimation logic.

**Must have (table stakes) — v0.9.0 launch:**
- `creel_schedule()` / `generate_schedule()` — sampling calendar generator returning a tidy tibble with `date`, `day_type`, `period_id`; foundational input for all downstream planning tools.
- `creel_n_effort()` — CV-target sample size for effort using Cochran (1977) §2.2 / McCormick (2017); most-requested pre-season calculation in agency workflows.
- `creel_n_cpue()` — CV-target sample size for CPUE using ratio estimator variance (Cochran 1977 eq. 6.13); paired with effort calculator, distinct formula.
- `validate_design()` — pre-season go/no-go check that calls the two calculators per stratum and returns a pass/warn/fail tibble per stratum.
- `check_completeness()` — post-season QA combining missing-days detection and low-sample strata flag in one call; mirrors the `missing_sections` guard pattern from v0.7.0.
- `season_summary()` / `summarize_season()` — assembles existing `estimate_*()` outputs into a single report-ready wide tibble; does not re-estimate.

**Should have (differentiators) — v0.9.x after validation:**
- `schedule_bus_route()` — executable circuit/site/crew assignment tibble with `inclusion_prob` columns fed directly to `creel_design(survey_type="bus_route")`; absent from all CRAN competitors including AnglerCreelSurveySimulation.
- `creel_power()` — change detection power calculator using two-sample t-test framework (Schmitt 2001, Georgia DNR 2025 NAJFM); creel-vocabulary inputs (% CPUE change, alpha, desired power).
- `write_schedule()` — thin `writexl::write_xlsx()` / `readr::write_csv()` wrapper; defer until schedule tibble format is stable.
- `check_refusal_threshold()` — one-liner wrapper over existing `summarize_refusals()` (v0.5.0) with pass/warn/fail status column.

**Defer (v1.0+):**
- `schedule_large_lake()` — highest complexity; requires section workflows and design validator proven in active use first; scope must be strictly bounded to equal-probability rotating design, never a constraint solver.
- Neyman stratum allocation helper — straightforward formula but requires pilot variance estimates that new-fishery users often lack; defer until base planning tools prove adoptable.

**Anti-features (do not build):**
- Full report rendering (PDF/Word/Rmd) — opinionated template, high maintenance burden; return the `season_summary()` tibble and let users render.
- Automatic pilot data extraction from current season — circular: using same-season data to size same-season sample produces invalid CV estimates.
- Interactive Shiny scheduler — out of scope; tibble output is pipe-friendly and can feed any user-built Shiny app.

### Architecture Approach

The three-layer architecture (API → Orchestration/Dispatch → `survey::`) is unchanged. All new components attach as peers or consumers at the edges of the existing diagram. No changes to `creel-design.R`, any estimation file, or any existing `summarize_*()` function. `print-methods.R` is the only existing file that changes (two new `format.*` methods added). DESCRIPTION changes: add `lubridate` to Imports, `writexl` to Suggests.

**Major components (four new R files):**
1. `R/creel-schedule.R` — `generate_schedule()` and `generate_bus_schedule()`; returns plain `data.frame` with canonical column schema validated at construction before passing to `creel_design()`. Pattern: Pre-Design Generator (no survey package dependency; testable with zero mock design objects).
2. `R/creel-power.R` — `n_days_required()`, `power_creel()`, `cv_from_n()`; standalone analytical calculators; no `creel_design` dependency; verify against McCormick & Quist (2017) Table 2 benchmarks.
3. `R/creel-completeness.R` — `check_completeness()`; guard-first, read-only, `survey_type`-dispatched; returns `creel_completeness_check` S3; mirrors `creel_tost_validation` pattern from `validate_incomplete_trips()`.
4. `R/creel-export.R` — `write_creel_csv()`, `export_creel()`, `summarize_season()`; terminal functions; CSV path uses base R `write.csv()`; xlsx path requires `writexl` in Suggests with `rlang::check_installed()` guard.

**Key data flow properties confirmed by architecture research:**
- Schedule generators are fully upstream; no circular dependencies possible.
- Power calculators are orthogonal; can be called before any design exists.
- Completeness checkers are read-only; design passes through unchanged.
- Export utilities are terminal; consume estimates tibbles, produce files, return nothing for further computation.
- `summarize_season()` is a collator, not an estimator; must not call any `estimate_*()` function internally.

### Critical Pitfalls

1. **Schedule output incompatible with `creel_design()` input (S-1, HIGH cost)** — Column names, date types (`Date` not `POSIXct`), and day-type string values must match the existing pipeline exactly. Define a `creel_schedule` class with a documented schema before writing any generator. Require a round-trip test (`generate_schedule() |> creel_design() |> get_sampling_frame()`) as the first test in Phase A. Recovery cost is HIGH if discovered after tests are written.

2. **Weekday/weekend encoding mismatch (S-2, HIGH cost)** — String comparison is case-sensitive in R; `"Weekday"` silently fails to join against `"weekday"` in interview data, producing NA inclusion probabilities. Use a single package-level constant for both the schedule generator and the existing pipeline. Verify with an explicit join test.

3. **SRS power formula applied to stratified designs (P-1, MEDIUM cost)** — Using the unstratified formula with overall CV underestimates required sample size when strata are effective. The calculator must accept a `strata` argument and use Cochran (1977) §5.25 stratified variance by default. SRS approximation must be documented as such and behind an explicit option.

4. **CV of effort conflated with CV of catch rate (P-2, MEDIUM cost)** — Effort CV and CPUE CV respond to different variance components; McCormick (2017) benchmarks: CV=0.20 requires ~16 days for effort but ~43 days for CPUE with the daily estimator. The `estimator` argument must be required, and both estimator paths must be tested.

5. **Completeness checker false positives for survey-type-specific NAs (SC-3, MEDIUM cost)** — Aerial surveys have no `bus_route` slot; ice surveys have synthetic-only bus_route data; camera surveys have maintenance-window gaps. A generic `anyNA()` check fires on every legitimate non-instantaneous design. The checker must dispatch by `design$survey_type` using the `intersect()` guard pattern established in v0.7.0/v0.8.0. Test all five survey type fixtures.

6. **Season summary re-deriving values from raw data (SC-4, HIGH cost)** — Summing raw catch or averaging raw CPUE bypasses the design-based pipeline and produces wrong answers for stratified and bus-route designs. `summarize_season()` must accept a named list of pre-computed `creel_estimates` objects. Test by numeric equality against individual `estimate_*()` outputs.

---

## Implications for Roadmap

Based on research, the dependency graph suggests four phases with Phases A and B independent (parallel-capable), followed by Phase C (requires Phase B outputs), followed by Phase D (terminal consumer):

### Phase A: Schedule Generators

**Rationale:** `creel_schedule()` is the foundational input for the design validator, bus-route scheduler, large-lake scheduler, and completeness checker. Building this first forces definition of the canonical `creel_schedule` schema, which prevents the highest-cost pitfall (S-1) from cascading into later phases. All downstream planning tools need the schedule tibble; Phase A is the single dependency no other phase can resolve.
**Delivers:** `generate_schedule()` for instantaneous/access designs; `generate_bus_schedule()` with `inclusion_prob` columns; `write_schedule()` thin export wrapper; canonical `creel_schedule` S3 class with validated schema.
**Addresses features:** `creel_schedule()` (P1), `schedule_bus_route()` (P2), `write_schedule()` (P2).
**Avoids pitfalls:** S-1 (schema definition before any code), S-2 (shared day-type constants), S-3 (programmatic `p_site`/`p_period` from schedule, never hardcoded).
**Research flag:** Needs phase-level confirmation of the exact column names and types required by `creel_design()` at construction — inspect `R/creel-design.R` and the `$calendar` slot documentation before writing any generator code. This is the one gap that was not resolvable from research alone.

### Phase B: Power and Sample-Size Calculators

**Rationale:** Independent of the schedule tibble and `creel_design`; can proceed in parallel with Phase A. Completing these analytical functions establishes the calculation engine that `validate_design()` calls internally in Phase C. Building Phase B before Phase C prevents pitfall SC-2 (design validator duplicating calculator logic).
**Delivers:** `creel_n_effort()`, `creel_n_cpue()`, `creel_power()`, `cv_from_n()`; no new dependencies (pure `stats`); vignette reproducing McCormick & Quist (2017) Table 2 benchmarks.
**Uses stack:** `stats` (existing Imports only); no new Imports or Suggests needed.
**Implements architecture:** Pattern 2 (Standalone Power Calculator — no `creel_design` dependency; accepts raw variance inputs from any source).
**Avoids pitfalls:** P-1 (stratified formula required, SRS approximation documented), P-2 (explicit `estimator` argument required, both paths tested), P-3 (change detection accepts `creel_estimates` SE, not re-derived from raw data), P-4 (document pilot variance provenance; `trip_adjustment` parameter optional).
**Research flag:** Well-documented analytical formulas from primary literature; no deeper research needed. Verification target: reproduce McCormick & Quist (2017) Table 2 numerically.

### Phase C: Design Validator and Completeness Checkers

**Rationale:** Depends on Phase B (validator calls `creel_n_effort()`/`creel_n_cpue()` internally; building the validator before the calculators forces duplication of the CV formula, which is pitfall SC-2). The `creel_design` API is stable since v0.4.0 and requires no changes here.
**Delivers:** `validate_design()` (pre-season pass/warn/fail report per stratum); `check_completeness()` (post-season missing-days + low-sample strata in one call); `check_refusal_threshold()` (thin wrapper over `summarize_refusals()`); `creel_completeness_check` S3 class with print method.
**Addresses features:** `validate_design()` (P1), `check_completeness()` (P1), `check_refusal_threshold()` (P2).
**Avoids pitfalls:** SC-2 (validator calls constructor in `tryCatch`, no duplicated validation logic), SC-3 (survey-type dispatch before column checks; test all five survey type fixtures), P-3 (change detection uses SE from `creel_estimates`).
**Research flag:** Standard patterns from existing validation architecture (`creel_tost_validation`, `validate_incomplete_trips()`); no deeper research needed. Critical test requirement: all five survey type fixtures (instantaneous, bus_route, ice, camera, aerial) must produce zero false-positive flags.

### Phase D: Export Utilities and Season Summary

**Rationale:** Terminal consumers of estimator outputs; have no new dependencies on Phases A-C except that the end-to-end vignette tests benefit from the full pipeline (schedule → design → estimates) being established. `summarize_season()` depends only on the stability of `estimate_*()` function outputs, which have been stable since v0.5.0.
**Delivers:** `write_creel_csv()` (base R, zero new dependencies); `export_creel()` (xlsx via `writexl` in Suggests, graceful failure when absent); `summarize_season()` with `creel_season_summary` S3 class; `format.creel_season_summary` and `format.creel_completeness_check` print methods added to `print-methods.R`.
**Uses stack:** `writexl >= 1.5.4` (Suggests, one-line DESCRIPTION change); base R `write.csv()` for CSV path.
**Implements architecture:** Pattern 4 (Post-Estimation Export, thin wrapper with optional Suggests dependency).
**Avoids pitfalls:** D-1 (`writexl` in Suggests, never Imports; `rlang::check_installed()` guard on xlsx path), D-2 (export from underlying numeric tibble, not S3 print-formatted strings), SC-4 (season summary accepts named list of pre-computed estimates, never re-derives from raw data).
**Research flag:** Well-documented patterns; no deeper research needed. Key test: exported CSV/xlsx round-trip must preserve numeric column types (`class(re_read_column) == "numeric"`).

### Phase Ordering Rationale

- **Phases A and B are parallel** because neither depends on the other; both have zero internal package dependencies. Builds can proceed on separate branches or sequentially — either is fine.
- **Phase C follows Phase B** because `validate_design()` calls `creel_n_effort()` and `creel_n_cpue()` internally. Building the validator before the calculators forces duplication of the CV formula (pitfall SC-2: two diverging implementations).
- **Phase D is last** because `summarize_season()` integration tests benefit from the full workflow being established, and the print methods for `creel_completeness_check` (Phase C) should be finalized before the companion `creel_season_summary` method is written in `print-methods.R` to ensure consistent formatting conventions.
- **`schedule_large_lake()` is explicitly deferred to v1.0+** by all four research documents. When eventually planned, its scope must be bounded to equal-probability rotating designs; constraint-solver logic (pitfall SC-1) is out of scope.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase A (Schedule Generators):** The canonical `creel_schedule` schema — column names, types, and allowed `day_type` values required by `creel_design()` at construction — must be confirmed from direct inspection of `R/creel-design.R` and any test fixtures that populate `$calendar` before the Phase A plan is written. This is the one concrete gap identified across all four research files.

Phases with standard patterns (research-phase not needed):
- **Phase B (Power Calculators):** Formulas are direct from primary literature (McCormick & Quist 2017; Cochran 1977); only `stats` needed; verification against known Table 2 values is sufficient.
- **Phase C (Validators/Completeness):** Mirrors existing `creel_tost_validation` and `validate_incomplete_trips()` patterns exactly; no new statistical machinery.
- **Phase D (Export/Summary):** Thin wrappers over base R and existing estimators; `writexl` in Suggests is a one-line DESCRIPTION change.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All packages verified on CRAN with current versions; alternatives explicitly evaluated and rejected with documented rationale; writexl Suggests vs. Imports position consistent across all research files |
| Features | HIGH | Formulas from primary literature (McCormick & Quist 2017, Cochran 1977); competitor analysis confirms gap against AnglerCreelSurveySimulation, creelr, and legacy NGPC scripts; agency report structure confirmed from Wisconsin/Minnesota DNR 2024-2025 |
| Architecture | HIGH | Grounded in direct codebase inspection of all 15 R source files, NAMESPACE, and DESCRIPTION; integration points confirmed against existing S3 class slots; build order derives from confirmed dependency direction |
| Pitfalls | HIGH for integration pitfalls (grounded in existing dispatch patterns and guard conventions); MEDIUM for stratified power design (primary literature verified but not yet confirmed against the specific stratification approach to be chosen in Phase B) |

**Overall confidence:** HIGH

### Gaps to Address

- **`creel_schedule` schema definition:** The exact column names and types required by `creel_design()` are the single most important pre-implementation decision for Phase A. Inspect `R/creel-design.R` and `$calendar` slot documentation — or an existing test fixture — before writing any generator code. This gap must be closed at the start of Phase A planning.
- **Day-type string constants:** The canonical values `"weekday"` and `"weekend"` are confirmed by PITFALLS.md as the correct encoding derived from the NGPC database. Verify by inspecting the `$calendar` slot of any existing `creel_design` test fixture before committing to package-level constants in Phase A.
- **Stratified vs. SRS power interface:** Research recommends the stratified variance formula as the default and SRS as a documented approximation. The exact interface design (whether `strata` is required with a hard error when omitted, or optional with a warning) should be decided in the Phase B plan rather than during implementation.
- **`writexl` Imports vs. Suggests discrepancy:** ARCHITECTURE.md initially lists `writexl` under Imports in one location; STACK.md and PITFALLS.md both explicitly recommend Suggests. Suggests is the correct decision. Confirm placement in DESCRIPTION before Phase D begins — the ARCHITECTURE.md Imports mention appears to be a documentation inconsistency, not a recommendation.

---

## Sources

### Primary (HIGH confidence)
- McCormick, J. L. & Quist, M. C. (2017). Sample Size Estimation for On-Site Creel Surveys. *NAJFM* 37(5):970-980 — CV-target formulas for effort and CPUE; benchmark sample sizes (16 days / 43 days at CV=0.20)
- Cochran, W. G. (1977). *Sampling Techniques* (3rd ed.). Wiley — ratio estimator variance (eq. 6.13); Neyman allocation (§5.5); stratified sample size (§5.25)
- Jones, C. M. & Pollock, K. H. (2012). Recreational survey methods. In *Fisheries Techniques* 3rd ed., AFS, pp. 883-919 — `pi_i = p_site × p_period` bus-route formula; canonical reference for tidycreel since v0.4.0
- CRAN: writexl 1.5.4 (2025-04-15) — zero-dependency xlsx writer; rOpenSci maintained; no transitive R dependencies
- CRAN: lubridate 1.9.5 (2026-02-04) — date arithmetic for schedule generation; 2 small transitive dependencies
- tidycreel NAMESPACE and DESCRIPTION (verified 2026-03-22) — full public API and current dependency footprint
- tidycreel R/ source files (verified 2026-03-22) — `creel_design` S3 slot structure, validation patterns, dispatch conventions, `intersect()` guard pattern

### Secondary (MEDIUM confidence)
- Estimating power of standardized monitoring program for sport fish in Georgia, USA. *NAJFM* 2025 — change detection power approach; confirms two-sample t-test as standard for creel monitoring programs
- Alaska DFG Special Publication 98-1: The Mechanics of Onsite Creel Surveys — schedule and completeness conventions
- Wisconsin DNR and Minnesota DNR open-water creel survey reports (2024-2025) — season summary table structure confirmed from multiple agency reports
- Evaluation of bus-route creel survey method (ScienceDirect, two-part series) — optimal allocation for bus-route designs; informs bus-route scheduler inclusion probability calculation
- CreelCat data validation framework (*Scientific Data* 2023) — creel survey completeness and quality validation standards; informs SC-3 prevention strategy

### Tertiary (MEDIUM-LOW confidence)
- AnglerCreelSurveySimulation CRAN vignette (version 1.0.3, 2024-05-14) — competitor feature analysis; confirms simulation-only scope (no schedule generation, no analytical CV calculators, no completeness checking)
- pwr package CRAN documentation — `pwr.t.test()` capability confirmed; rejected for Imports due to Cohen's d vocabulary mismatch with creel domain inputs

---
*Research completed: 2026-03-22*
*Ready for roadmap: yes*
