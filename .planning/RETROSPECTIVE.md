# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

---

## Milestone: v0.4.0 — Bus-Route Survey Support

**Shipped:** 2026-02-28
**Phases:** 7 (21-27) | **Plans:** 14 | **Commits:** ~54 | **Timeline:** 12 days

### What Was Built

- `creel_design(survey_type = "bus_route")` — bus-route design constructor with sampling frame, nonuniform probabilities (πᵢ = p_site × p_period), and Tier 1 validation
- `add_interviews()` extension — enumeration counts (n_counted/n_interviewed), πᵢ join, .expansion factor, Tier 3 bus-route validation
- Effort estimator implementing Jones & Pollock (2012) Eq. 19.4: sum(e_i / πᵢ) with survey package variance (svydesign + svytotal)
- Harvest/catch estimators implementing Jones & Pollock (2012) Eq. 19.5 with incomplete trip handling
- Accessor quartet: `get_sampling_frame()`, `get_inclusion_probs()`, `get_enumeration_counts()`, `get_site_contributions()`
- Primary source validation: Malvestuto (1996) Box 20.6 reproduced exactly (E_hat = 847.5, tolerance 1e-6)
- Two vignettes: workflow tutorial (bus-route-surveys.Rmd) + equation traceability reference (bus-route-equations.Rmd)
- 21 requirements fully satisfied; tidycreel is now the ONLY R package with correct bus-route estimation

### What Worked

- **Primary source analysis before implementation:** Reading Malvestuto (1996) and Jones & Pollock (2012) before writing code prevented the conceptual errors that plague all existing R implementations (confusing πᵢ with "interview probability")
- **Validation against published examples:** Using Malvestuto (1996) Box 20.6 as a golden test caught a critical cross-validation bug in Phase 26 (ids=~site approach gave 18.625 instead of 847.5)
- **Phase 24 VERIFICATION.md retroactive creation:** The audit identified Phase 24 was never formally verified (only SUMMARY.md existed). Creating the VERIFICATION.md during Phase 26 closed this process gap without rework
- **Two-vignette separation:** Workflow tutorial + equation traceability as separate documents serves both practitioner (how) and statistician (why) audiences without confusing either
- **Pre-commit hooks with lintr:** Zero linting debt across 14 plans — continuous enforcement prevents cleanup phases

### What Was Inefficient

- **Phase 26 cross-validation discovery:** The initial plan's `ids=~site, weights=~1/.pi_i` survey design approach was wrong and had to be corrected during execution. Deeper pre-planning of the variance cross-validation approach would have avoided the deviation
- **Phase 27 data ordering issue:** Vignette interview data row ordering didn't match the validated test helper, requiring auto-fix during execution. A test-first approach to vignette data would catch this earlier
- **Audit staleness:** The milestone audit (Feb 25) was stale by the time milestone completion ran (Feb 28) because Phases 26-27 had closed all gaps. An audit immediately before completion would eliminate the "gaps_found" confusion

### Patterns Established

- **Dispatch order matters for multi-strategy estimators:** Bus-route dispatch must be placed BEFORE any guard that checks design slots that bus-route doesn't use (design$survey = NULL for bus-route). This pattern extends to any future non-standard design type
- **Two-stage test helper naming:** Section-scope helpers (make_br_sf/make_br_cal) defined immediately before the tests that use them — avoids global test helper pollution while keeping tests readable
- **Golden tests from published examples:** Box 20.6 helpers are the authoritative correctness reference for all bus-route tests. Any future estimator changes must pass these first
- **Enumeration expansion NA handling:** n_interviewed = 0 rows produce NA expansion (warn, don't error) — statistically appropriate, user gets feedback without crashing

### Key Lessons

1. **Read primary sources before implementation:** All existing R bus-route implementations are wrong because they never read Jones & Pollock (2012) carefully. Primary source investment paid off in one session and prevented months of debugging
2. **Validate against published examples early:** Box 20.6 as a Phase 26 golden test caught a fundamental variance calculation error. Moving this validation to Phase 24 (when effort estimation was first built) would have been more efficient
3. **Audit immediately before milestone completion, not days before:** Stale audits create confusion about gap status and may lead to unnecessary gap-planning work for gaps already closed
4. **Bus-route designs are architecturally similar to the existing instantaneous design:** The three-layer architecture absorbed the new design type cleanly. The dispatch pattern (check survey_type in estimators before any survey package call) is the only structural addition needed

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: ~8-10 sessions across 12 days
- Notable: Primary source analysis phase (reading Malvestuto 1996 + Jones & Pollock 2012) was the highest-value session — prevented fundamental conceptual errors that would have required complete rewrite

---

## Milestone: v0.7.0 — Spatially Stratified Estimation

**Shipped:** 2026-03-15
**Phases:** 5 (39-43) | **Plans:** 9 | **Commits:** 39 | **Timeline:** 6 days (2026-03-09 → 2026-03-15)

### What Was Built

- `add_sections()` — spatial section registration with name validation and design slot (`sections`, `section_col`)
- `estimate_effort()` section dispatch — `rebuild_counts_survey()` per section, `svyby(covmat=TRUE)` + `svycontrast()` for correlated lake total, `prop_of_lake_total` column
- `estimate_catch_rate()` / `estimate_harvest_rate()` / `estimate_release_rate()` — renamed from v0.2.0 names (breaking change, no deprecated wrappers); section dispatch produces per-section rows only (no lake total — rates not additive)
- `estimate_total_catch()` / `estimate_total_harvest()` / `estimate_total_release()` — section dispatch with `sum(TC_i = E_i × CPUE_i)` lake total (not `E_total × CPUE_pooled`)
- `missing_sections` guard on all section-aware estimators — NA row + `cli_warn()` for registered sections absent from data
- `example_sections_calendar`, `example_sections_counts`, `example_sections_interviews` — 3-section example datasets with material variation across sections
- Section-estimation vignette — full workflow with correlated vs. independent variance decision explained in biologist-accessible language
- Phase 43 tech debt: PROD-01/PROD-02 missing-section guard tests; Nyquist VALIDATION.md fills for phases 39-42; SUMMARY frontmatter fixes
- 1588 tests passing (up from ~1400 at v0.7.0 milestone start)

### What Worked

- **Breaking rename with no deprecated wrappers:** The clean API break (`estimate_cpue()` → `estimate_catch_rate()`) was the right call — deprecated wrappers would have created permanent confusion about what the "real" function name is. Documenting the rename in NEWS.md was sufficient
- **Separate section dispatch helpers:** `estimate_effort_sections()`, `estimate_catch_rate_sections()`, etc. kept the top-level public functions clean (one `if (is.null(design$sections))` guard) while isolating section logic — easy to test individually
- **Human review checkpoint on Phase 42-02 (vignette):** The vignette required a biologist to verify that the `method = "correlated"` explanation was accurate and accessible. Explicit human review gate prevented a technically correct but domain-inaccessible explanation from shipping
- **TDD maintained through spatial complexity:** All section features were built test-first (RED stubs in plan 01, GREEN + GREEN implementation in plan 02). Despite the cross-section variance math complexity, no regression failures occurred because the approach forced specifying exact expected outputs before implementation

### What Was Inefficient

- **Phase 43 tech debt audit:** Several tech debt items (VALIDATION.md drafts, SUMMARY frontmatter) were identified by the post-ship audit rather than being closed during execution. These are low-effort items that could have been integrated into each phase's definition-of-done
- **Phase 35 stale plans:** The `.planning/phases/35-documentation-quality-assurance/` directory has two PLAN.md files with no corresponding SUMMARY.md — stale artifacts from v0.5.0 that the milestone archived before execution. GSD tools interpreted this as "in_progress" which caused routing confusion in subsequent `gsd:progress` checks
- **Rate estimator section dispatch is asymmetric:** Effort and product estimators produce a `.lake_total` row; rate estimators deliberately do not. This asymmetry requires explicit documentation in every rate function's `@return` and was not initially surfaced in the plan — caught during vignette writing

### Patterns Established

- **Correlated-domain aggregation is the default for shared-calendar creel designs:** Sections share day-level PSUs, so `svyby(covmat=TRUE)` + `svycontrast()` is always correct. `method = "independent"` is a special case for genuinely non-overlapping strata
- **`sum(TC_i)` not `E_total × CPUE_pooled` for spatially stratified totals:** This is the defining equation for the v0.7.0 product estimators — a common error in practice that tidycreel corrects by construction
- **Section guard pattern:** Every section-aware estimator starts with `if (is.null(design$sections)) return(nonsection_path)` — adds zero cost to existing designs and routes to specialized implementation only when sections are present

### Key Lessons

1. **Rate vs. total additive behavior is the key conceptual distinction in spatial stratification:** Rates are not additive across sections (lake-wide catch rate ≠ weighted mean of section catch rates when section effort varies); totals are additive. This distinction must be explained in the vignette and enforced by the API — the section rate estimators producing no `.lake_total` row is the correct design
2. **Human review gates are worth the checkpoint overhead for domain documentation:** The vignette `method = "correlated"` explanation required domain expertise that automated tests cannot verify. The explicit human review step in Plan 42-02 is worth keeping for future domain-specific documentation
3. **Tech debt from "approved but not covered" patterns accumulates:** The PROD-01 missing-section guard was implemented in Phase 41 but only the `estimate_total_catch()` version had a test — the harvest and release versions were untested. One-line guard implementations should always be accompanied by tests for all variants, not just the first

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: ~6 sessions across 6 days
- Notable: The section dispatch architecture was the most complex feature in tidycreel so far, but the established three-layer pattern absorbed it cleanly — spatial stratification required no architectural changes, only new dispatch paths

---

## Milestone: v0.8.0 — Non-Traditional Creel Designs

**Shipped:** 2026-03-22
**Phases:** 4 (44-47) | **Plans:** 11 | **Commits:** 34 | **Timeline:** 7 days (2026-03-15 → 2026-03-22)

### What Was Built

- `VALID_SURVEY_TYPES` enum guard — `cli_abort()` closes dispatch surface before any estimation runs (Phase 44)
- Ice fishing: `creel_design(survey_type = "ice", effort_type = ...)` with `p_site = 1.0` enforcement, synthetic bus_route slot, `shelter_mode` stratification via `by =`, full interview pipeline (Phase 45)
- Remote camera (counter): daily ingress counts route through existing access-point path with `camera_status` gap classification (Phase 46)
- Remote camera (ingress-egress): `preprocess_camera_timestamps()` converts POSIXct timestamp pairs to daily effort hours before estimation (Phase 46)
- Aerial: `estimate_effort_aerial()` using `svytotal × (h_open / visibility_correction)`, AIR-04 constructed numeric validation (111 counts × 14 h = 1554 angler-hours), optional visibility correction factor (Phase 47)
- All three types: complete interview pipeline (`add_interviews()` → `estimate_catch_rate()` → `estimate_total_catch()`) with zero changes to rate/product estimators
- Six example datasets and three end-to-end workflow vignettes (`ice-fishing.Rmd`, `camera-surveys.Rmd`, `aerial-surveys.Rmd`)
- 1696 tests; R CMD check 0 errors 0 warnings throughout

### What Worked

- **Ice-as-degenerate-bus-route architecture:** Using `p_site = 1.0` with a synthetic bus_route slot to reuse `estimate_effort_br()` unchanged was the right call — no new estimator path, no regressions. The `intersect()` guard pattern for synthetic column names is now canonical
- **Build order (ice → camera → aerial):** Each type progressively increased complexity. Ice established the constructor validation pattern; camera added preprocessing; aerial added the new internal estimator. No type needed to be revisited once completed
- **Camera uses standard instantaneous path:** Counter and ingress-egress modes both feed `add_counts()` → `estimate_effort()` without special dispatch. This means CAM-04 (interview compatibility) required zero production code changes — only tests
- **Aerial uses linear scaling (not delta method):** `h_open` and `visibility_correction` are fixed calibration constants, not sample estimates, so SE scales exactly as `SE(svytotal) × h_over_v`. This insight eliminated the planned delta method implementation and made the code simpler and more correct
- **Numeric validation for AIR-04:** Constructing a hand-verified example (111 counted anglers × 14 h open / 1.0 visibility = 1554 angler-hours) when Malvestuto (1996) Box 20.6 had no aerial worked example was an effective substitute for primary-source validation

### What Was Inefficient

- **Missing roxygen @param documentation caught by R CMD check:** Both `effort_type` (ice), `camera_mode` (camera), and `h_open`/`visibility_correction` (aerial) were added to `creel_design()` without corresponding roxygen entries, causing R CMD check WARNINGs that required fix commits. Checking "does this new parameter have a @param?" should be part of the RED→GREEN task definition
- **Vignette knitr::kable() incompatibility discovered late:** `creel_estimates` objects can't be coerced to data.frame by `knitr::kable()` — discovered during vignette writing for camera (46-03) and then again for aerial (47-03). A shared vignette pattern established in 45-03 would have prevented rediscovery

### Patterns Established

- **`intersect()` guard for synthetic columns:** Any survey type that reuses the bus-route estimator path with synthetic slot columns (`.ice_site`, `.circuit`) must use `intersect(c(site_col, circuit_col), names(interviews))` for site_table construction. Now canonical in `estimate_effort_br()` and `estimate_total_catch_br()`
- **New survey type constructor validation:** Required params abort with `cli_abort()` naming valid values (mirrors `match.arg()` ergonomics); optional params default to safe values (e.g., `visibility_correction` → 1.0)
- **`print()` for creel_estimates in vignettes:** `knitr::kable()` cannot coerce `creel_estimates` — all vignettes use `print()` for estimation results. Document this in the contributing guide
- **Preprocessing functions as explicit user step:** `preprocess_camera_timestamps()` is called by the user before `add_counts()` rather than auto-detected inside `add_counts()` — keeps the main pipeline clean and makes the data transformation transparent

### Key Lessons

1. **Check new function parameters have roxygen @param before R CMD check:** Three separate R CMD check WARNINGs for missing @param entries across the milestone. A simple "did I document all new parameters?" checklist item in the GREEN task would eliminate these entirely
2. **Calibration constants use linear SE scaling, not delta method:** When expansion factors are user-supplied calibration constants (not estimated from data), propagating uncertainty through them is just multiplication — no delta method needed. This distinction simplifies implementation and is more statistically defensible
3. **A constructed numeric example is a valid alternative to a published worked example:** Malvestuto (1996) Box 20.6 has no aerial data. A hand-verified calculation against known inputs (AIR-04) satisfies the same correctness guarantee as a published example, provided the inputs are chosen to test the full formula
4. **Design types that reuse estimators need to guard synthetic columns:** The `intersect()` pattern needed in both `estimate_effort_br()` and `estimate_total_catch_br()` is a consequence of ice reusing bus-route slots. Future bus-route-path reuse must always add this guard

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: ~6-7 sessions across 7 days
- Notable: Phase 47 plan 03 (vignette + datasets) took 34 min — longest single plan in the milestone, consistent with documentation plans being ~2× the implementation plans

---

## Milestone: v0.9.0 — Survey Planning & Quality of Life

**Shipped:** 2026-03-24
**Phases:** 4 (48-51) | **Plans:** 10 | **Timeline:** 1 day (2026-03-23 → 2026-03-24)

### What Was Built

- `generate_schedule()` + `generate_bus_schedule()` — sampling frame generators with validated `creel_schedule` S3 class; `write_schedule()` / `read_schedule()` with CSV/xlsx round-trip I/O and robust date coercion (Phase 48)
- `creel_n_effort()` + `creel_n_cpue()` — Cochran (1977) stratified sample-size calculators, biologist-friendly CV/correlation parameterisation, McCormick & Quist (2017) benchmark validation (Phase 49)
- `creel_power()` + `cv_from_n()` — two-sample normal approximation power calculator and algebraic inverse; completes four-function pre-season planning suite (POWER-01–04) (Phase 49)
- `validate_design()` — pre-season pass/warn/fail per stratum; delegates entirely to Phase 49 functions, no CV formula duplication; `creel_design_report` S3 class with cli table (Phase 50)
- `check_completeness()` — post-season data quality checker with survey-type dispatch via `intersect()` guard; zero false-positive flags across all five survey types (Phase 50)
- `season_summary()` — wide-tibble assembler from named list of `creel_estimates`; by_vars consistency guard enforces uniform stratification contract; `creel_season_summary` S3 class (Phase 51)

### What Worked

- **Planning layer as independent module:** All sample-size functions are pure computations from parameters — no `creel_design` dependency. `validate_design()` calls them internally for DRY CV math. This architecture made testing trivial and kept concerns separated
- **Delegation pattern for validate_design():** Requiring Phase 49 before Phase 50 and forbidding local CV formula duplication in `validate_design()` was the right constraint. The WARN_CV_BUFFER (1.2) is the only constant added; all math lives in `creel_n_effort()` / `creel_n_cpue()`
- **`intersect()` guard re-used from v0.8.0:** The pattern established for ice fishing in Phase 45 carried directly into `check_completeness()` for Phase 50's synthetic column problem. Canonical patterns from prior milestones paid off
- **Statistical notation preserved with nolint:** Keeping `N_h`, `E_total`, `V_0` as-is (with `# nolint: object_name_linter`) made the Cochran (1977) formula correspondence auditable. This was a deliberate documentation choice, not an oversight
- **Schedule I/O read-as-text pattern:** Reading all columns as character first, then coercing through a shared `coerce_schedule_columns()` function, eliminated format-specific type inference bugs (especially Excel serial date strings from `readxl` with `col_types = "text"`)

### What Was Inefficient

- **Test fixtures in Plan 50-01 were wrong:** The skeleton Plan 01 test stubs had incorrect `creel_n_effort()` expected values (stated weekday=18, weekend=8; actual values were weekday=3, weekend=2 for the pilot parameters). Re-deriving these in Plan 02 added friction. Stub comments in Plan 01 should not guess expected values — leave them as NA or document they need computing
- **cli glue variables and `nolint` are now a recurring pattern:** Every plan that uses `cli_abort()` or `cli_inform()` with glue variables ends up adding `# nolint: object_usage_linter` to extracted locals. This is now boilerplate and could be documented in the contributing guide as "how cli glue variables are handled in this package"
- **Phase 51 by_vars assembly approach:** The two-path assembly (bind_cols for ungrouped vs. iterative `Reduce(left_join)` for grouped) was needed because `left_join` on `character(0)` produces a cross join not identity. This was discovered during implementation rather than planning — a note in the plan about character(0) join behaviour would have prevented the deviation

### Patterns Established

- **Planning functions as pure computations:** Pre-season calculators take primitive parameters (CV target, stratum counts) and return numeric answers — no design objects involved. This keeps them testable, reusable, and composable (validators call them, vignettes call them independently)
- **by_vars consistency guard before wide assembly:** Any function that assembles multiple `creel_estimates` objects into a single tibble must check that all inputs share the same stratification before attempting column alignment
- **`intersect()` guard is the canonical synthetic column pattern:** Now used in `estimate_effort_br()`, `estimate_total_catch_br()`, and `check_completeness()`. Any future function that works with design columns that may or may not exist in interview data should use this pattern

### Key Lessons

1. **Pure-function planning tools compose better than design-coupled ones:** The decision to make `creel_n_effort()` / `creel_n_cpue()` parameter-only functions (not `creel_design` methods) made `validate_design()` simple to implement and made the planning tools independently usable in non-tidy contexts (e.g., a Shiny app, a standalone script)
2. **Stub comments that guess expected values create rework:** Plan 50-01 stubs with guessed test expectations had to be corrected in Plan 50-02. Stub comments should say "compute from creel_n_effort() with these parameters" not state a specific number — the actual value is only reliable when the function exists
3. **Document `character(0)` join behavior once, globally:** The `left_join(character(0))` cross-join gotcha will recur any time strata-aware assembly is added. The contributing guide should have one canonical note: "join on character(0) columns produces a cross join — use bind_cols for the no-strata case"

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: 1 day of execution (~6-8 sessions)
- Notable: Fastest milestone to date by calendar time (1 day); the planning layer was structurally simpler than the spatial/design-type milestones because it added no new estimator paths — only pure-function tools and wrappers

---

## Milestone: v1.0.0 — Package Website

**Shipped:** 2026-03-31
**Phases:** 5 (52-56) | **Plans:** 8 | **Timeline:** 2 days (2026-03-30 → 2026-03-31)

### What Was Built

- Bootstrap 5 pkgdown theme: bslib palette (`primary: #1B4F72`), Google Fonts (Raleway/Lato/Fira Code), `pkgdown/extra.css` with dark code blocks and explicit pandoc syntax token color overrides
- Polished README home page with R CMD check and deploy status badges, five survey type callouts, and feature highlights section
- Grouped reference index: 46 exports + 15 example datasets in 9 named topic sections; S3 methods hidden with `starts_with()` selectors in `title: internal`
- Workflow-driven navbar: Get Started, Survey Types, Estimation, Reporting & Planning article dropdowns; Reference link; NEWS Changelog
- `.github/workflows/pkgdown.yaml`: auto-deploys to `gh-pages` on push to main; PR build-only guard (`if: github.event_name != 'pull_request'`); 5 successful CI runs on main; live site at https://chrischizinski.github.io/tidycreel

### What Worked

- **`pkgdown::check_pkgdown()` as continuous validation gate:** Running after every change caught orphaned functions and YAML errors before they accumulated. Zero warnings at ship time.
- **Phase dependency chain (52 → 53 → 54 → 55 → 56):** Each phase had a well-defined output consumed by the next. Theme established before content; content finalized before navbar wired; navbar complete before CI deployed. No back-tracking.
- **`starts_with()` selectors for S3 methods:** Using `contents: [starts_with("print."), starts_with("format.")]` under `title: internal` cleanly hides all S3 methods from the rendered reference index — no manual list to maintain.
- **r-lib/actions v2 canonical template for pkgdown.yaml:** The established r-lib template handled all complexity (R setup, cache, GITHUB_TOKEN permissions) with zero custom code. The only project-specific addition was the `if:` guard on the deploy step.
- **Phase 52 skip decision:** Recognizing that the existing `man/figures/logo.png` and `inst/hex/sticker.R` were already production-quality saved a full phase with no quality loss.

### What Was Inefficient

- **Pandoc syntax token colors required a second CSS pass:** The initial `pre.sourceCode color` override was insufficient — pandoc injects per-token `<span>` elements (`.fu`, `.kw`, `.st`, `.co`) with their own dark-background-incompatible colors. Adding explicit per-token overrides could have been anticipated at plan time by examining a built HTML page before writing `extra.css`.
- **Phase 52 was formally planned then skipped:** The skip decision was made during execution rather than in the plan. If the existing logo was known to be sufficient at planning time, Phase 52 could have been a one-task "verify existing assets" rather than a full generation plan.
- **REQUIREMENTS.md STICKER checkboxes not updated at phase completion:** STICKER-01/02/03 remain `[ ]` because Phase 52 was skipped. The requirements file should have been updated to mark these as satisfied-by-existing-assets at the time the skip decision was made.

### Patterns Established

- **`pkgdown` in DESCRIPTION `Suggests` (not `Imports`):** Build tool, not runtime dependency. This is the standard pattern for all development-only packages.
- **`docs/` in `.gitignore`, deploy to `gh-pages` orphan branch:** Built HTML stays out of main branch history; gh-pages is the deploy target, not the source. This is the canonical GitHub Pages + pkgdown setup.
- **PR deploy guard:** `if: github.event_name != 'pull_request'` on the deploy step — build always runs (catches `_pkgdown.yml` errors); deploy only on push to main. Standard pattern for pkgdown CI/CD.
- **Brand color established in Phase 1 of any UI milestone:** The primary hex value (`#1B4F72`) was set in the sticker phase so every subsequent phase could read it. For future UI work, establishing brand constants before building components prevents color drift.

### Key Lessons

1. **Infrastructure milestones need their own success metrics:** "Site builds" is not the same as "site is useful." A clear visitor journey test (can a biologist find the bus-route vignette in under 3 clicks?) would have made Phase 55 verification more concrete than checking for 404s.
2. **Examine built HTML before writing CSS overrides:** Pandoc's per-token `<span>` classes require explicit CSS rules — a pattern not visible in the source Rmd. Opening a locally built page before writing `extra.css` would have revealed this on the first pass.
3. **Skip decisions should update requirements files immediately:** When Phase 52 was skipped, STICKER-01/02/03 should have been updated in `REQUIREMENTS.md` at that moment. Deferred checkbox updates accumulate into known-gap debt that must be resolved at milestone completion.
4. **Website milestones require no tests but benefit from explicit acceptance criteria:** No automated tests validate visual rendering, navbar interaction, or deploy behavior. Writing explicit human acceptance criteria (e.g., "navigate to Survey Types > Ice Fishing in a browser") in the verification file is the correct substitute.

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: ~4-5 sessions across 2 days
- Notable: Fastest infrastructure milestone; pkgdown configuration is well-documented and the r-lib/actions templates eliminate most CI boilerplate. The shortest GSD milestone by calendar time.

---

## Milestone: v1.1.0 — Planning Suite Completeness & Community Health

**Shipped:** 2026-04-02
**Phases:** 3 (57-59) | **Plans:** 4 | **Commits:** 17 | **Timeline:** 1 day (2026-04-01 → 2026-04-02)

### What Was Built

- `generate_count_times()` — within-day count window generator with random, systematic, and fixed strategies; seed reproducibility; 26 new COUNT-TIME tests (Phase 57)
- `survey-scheduling.Rmd` extended with four new sections: Within-Day Count Time Scheduling (3 strategies), Validating the Design Before the Season, Checking Data Completeness After the Season, Assembling the Season Summary (Phase 58)
- Bug report form upgraded with survey_type dropdown + structured behavior textareas; feature request form created; `config.yml` with `blank_issues_enabled: false` routing to Discussions (Phase 59)
- `CONTRIBUTING.md` rewritten (189→233 lines): Getting Help moved to top, Filing Issues section with reprex example, PR Guidelines updated (Phase 59)

### What Worked

- **Parallel phase design (57+58 sequential, 59 independent):** Phase 59 had no dependency on 57-58, allowing it to be planned and executed independently. The decoupling meant a config.yml from a 59-02 run pre-committed cleanly into 59-01 without conflict
- **Fastest milestone by phase count:** 3 phases in 1 day — documentation + community work has lower implementation variance than estimator work; no test-driven complexity, no survey math
- **Stale checkbox audited before archival:** The PLAN-01 `[ ]` checkbox was caught by the pre-completion audit and documented as a stale documentation artifact (not a code gap). Correcting it in the archive prevents future confusion
- **`eval=FALSE` pattern for cross-vignette dependencies:** Marking the `season_summary()` chunk `eval=FALSE` with a narrative pointer to the main vignette keeps the scheduling vignette self-contained without duplicating the estimation pipeline

### What Was Inefficient

- **config.yml committed in the wrong plan:** config.yml was created during a 59-02 run before 59-01 executed, producing a commit labeled `feat(59-02)` that logically belonged to 59-01. Harmless in practice but creates confusing git history. Plan ordering within a phase should be enforced at plan time, not discovered during execution
- **Nyquist VALIDATION.md gap across all 3 phases:** All three phases shipped without VALIDATION.md files. This was identified in the audit but accepted as tech debt. For documentation-only phases, VALIDATION.md may be lower value, but the pattern should be consistent

### Patterns Established

- **Community health as milestone-level infrastructure:** GitHub issue forms, `config.yml`, and `CONTRIBUTING.md` are milestone-scope investments — they don't belong in individual feature phases. Grouping them into a dedicated community health phase (Phase 59) keeps them coherent and reviewable
- **Survey-type-aware issue forms:** Including the `survey_type` field as a structured dropdown in the bug report form ensures that incoming bug reports contain the context needed to triage without back-and-forth. Domain-specific issue forms reduce diagnostic friction
- **`Getting Help` before technical standards in `CONTRIBUTING.md`:** For domain-expert users who are not experienced open-source contributors, the community entry point (Discussions, issue filing) is more immediately useful than coding standards. Ordering matters for contributor onboarding

### Key Lessons

1. **Documentation milestones ship fast but leave Nyquist debt:** v1.0.0 and v1.1.0 both had missing VALIDATION.md files across all phases. Consider whether "documentation-only" phases warrant a lighter VALIDATION.md format (e.g., "rendered without error, content reviewed by human") rather than skipping entirely
2. **Plan ordering within a phase should match commit history:** config.yml appearing in a `feat(59-02)` commit before 59-01 ran is a GSD process artifact. Plans in a phase should be numbered in the order they are expected to run to keep commit history interpretable
3. **Audit immediately before milestone completion (confirmed again):** The v1.1.0 audit was run the same day as milestone completion, making it current. The PLAN-01 stale checkbox was caught and resolved. Same lesson as v0.4.0 — audit freshness matters

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: 2-3 sessions across 1 day
- Notable: Fastest milestone by calendar time (tied with or faster than v1.0.0); community health work has deterministic scope (form fields, markdown sections) unlike statistical estimation work

---

## Milestone: v1.2.0 — Documentation, Visual Calendar & GLMM Aerial

**Shipped:** 2026-04-06
**Phases:** 7 (60-65 incl. 63.1) | **Plans:** 9 | **Commits:** 38 | **Timeline:** 3 days (2026-04-03 → 2026-04-06)

### What Was Built

- 4 vignettes: `survey-tidycreel.Rmd` (side-by-side comparison), `effort-pipeline.Rmd` (counts → effort with Rasmussen variance), `catch-pipeline.Rmd` (ROM vs MOR + delta method), `aerial-glmm.Rmd` (decision guide + worked example + full E2E pipeline)
- `print.creel_schedule()` — ASCII monthly calendar grid with dynamic abbreviation collision resolution (WEEKD/WEEKE at k=5)
- `knit_print.creel_schedule()` — pandoc pipe-table calendar auto-loaded in knitr documents via `.onLoad()` `registerS3method()`
- `attach_count_times()` — cross-join helper producing one row per (date × period × count_window)
- `estimate_effort_aerial_glmm()` — GLMM aerial estimator (`lme4::glmer.nb()`, Askey 2018 quadratic diurnal, delta method + bootstrap SE, returns `creel_estimates` with `se_within = NA`)
- `example_aerial_glmm_counts` — companion dataset for GLMM vignette
- pkgdown reference index gap closure: 3 missing entries added (`attach_count_times`, `estimate_effort_aerial_glmm`, `example_aerial_glmm_counts`)
- 13/13 v1.2.0 requirements satisfied; DOC-01 closed retroactively via Phase 65 audit gap closure

### What Worked

- **Audit → gap-closure phase pattern:** Running `gsd:audit-milestone` before completion surfaced 4 pkgdown reference gaps and 1 DOC-01 tracking gap. A single Phase 65 gap-closure plan addressed all 5 atomically — clean, traceable, no rework
- **`requirements-completed` frontmatter on SUMMARY.md:** Adding this field retroactively to Phase 61's summary gave cross-phase requirement traceability without re-reading the entire phase — a good addition to the pattern library
- **Concept-first vignettes with annotated LaTeX + by-hand numerics:** Biologists confirmed the effort-pipeline and catch-pipeline vignettes are readable because formulas are immediately grounded by computed numbers they can reproduce by hand
- **lme4 in Suggests (not Imports):** Correct optional-dependency pattern; `cli_abort()` fail-fast is clear and discoverable without making lme4 a hard dependency for all users

### What Was Inefficient

- **Audit done at Phase 64 completion, not Phase 65:** The audit ran after Phase 64 and correctly identified pkgdown gaps. But those gaps were always going to be fixed in Phase 65 (the gap-closure phase was already planned). Running the audit earlier would have served as a planning check rather than a reactive verification step
- **Accomplishments not auto-extractable by gsd-tools:** The CLI `milestone complete` returned zero accomplishments because SUMMARY.md files don't have a consistent `one_liner` frontmatter field. The summaries were excellent, but in the wrong format for the tool — manual fill-in required. Adding `one_liner:` to the SUMMARY.md template would fix this permanently

### Patterns Established

- **Gap-closure phases use a single plan covering all audit findings atomically** — Phase 65 confirms this works; the single plan boundary kept git history clean and traceability tight
- **`requirements-completed: [REQ-ID, ...]` frontmatter field on SUMMARY.md** — enables retrospective requirement mapping across phases without parsing prose
- **Concept-first vignette structure:** Problem statement → statistical formula with annotation → by-hand numeric → tidycreel call confirming the number — this sequence is now the template for statistical pipeline vignettes

### Key Lessons

1. **Audit as planning check, not just post-hoc verification:** Phase 65 gap closure was reactive (audit caught what Phase 64 missed). Running a mini-audit of pkgdown completeness as part of Phase 64 planning would have prevented the need for a separate gap-closure phase
2. **Documentation milestones are fast but require human verification signals:** All 9 plans completed in 3 days — the work is deterministic when the statistical content is already proven. But concept vignettes need practitioner sign-off (human_needed in audit) for domain accuracy that automated tests cannot cover
3. **GLMM aerial adds model-based inference alongside design-based inference:** The estimator follows the same `creel_estimates` return contract but changes the variance source from survey design to model predictions. This is a new pattern — future Bayesian or spatial model-based estimators should follow the same contract

### Cost Observations

- Model mix: ~100% sonnet (balanced profile)
- Sessions: 4 sessions across 3 days
- Notable: Fastest multi-vignette milestone; documentation work has more predictable scope than statistical estimation work

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v0.1.0 | 7 | 12 | Established three-layer architecture and GSD workflow |
| v0.2.0 | 5 | 10 | Added interview-based estimation; ratio estimator pattern |
| v0.3.0 | 8 | 16 | Largest milestone; incomplete trip complexity required more phases |
| v0.4.0 | 7 | 14 | Primary source research prevented fundamental errors; nonuniform design type pattern |
| v0.5.0 | 8 | 18 | Extended interview data model; unextrapolated summaries; species-level estimation |
| v0.6.0 | 3 | 5 | Smallest milestone; targeted feature addition (multiple counts, progressive estimator) |
| v0.7.0 | 5 | 9 | Spatial stratification; most complex math to date; breaking API rename |
| v0.8.0 | 4 | 11 | Three new survey types; ice reuses bus-route; camera adds preprocessing; aerial uses linear SE scaling |
| v0.9.0 | 4 | 10 | Planning layer added as independent module; pure-function tools; `intersect()` guard reused; fastest milestone (1 day) |
| v1.0.0 | 5 | 8 | First infrastructure-only milestone; zero R functions; pkgdown + GitHub Actions; skip decision on Phase 52 |
| v1.1.0 | 3 | 4 | Planning suite completeness + first community health milestone; `generate_count_times()` + vignette extension + GitHub issue forms; fastest milestone (1 day) |
| v1.2.0 | 7 | 9 | Documentation-first milestone; 4 vignettes, 2 S3 print methods, GLMM aerial estimator; audit → gap-closure phase pattern validated |

### Cumulative Quality

| Milestone | Tests | Coverage | Vignettes |
|-----------|-------|----------|-----------|
| v0.1.0 | 253 | 88.75% | 1 (getting-started) |
| v0.2.0 | 610 | 89.24% | 2 (+interview-estimation) |
| v0.3.0 | 718 | ~90% | 3 (+incomplete-trips) |
| v0.4.0 | 1,098 | ~90% | 5 (+bus-route-surveys, +bus-route-equations) |
| v0.5.0 | ~1,300 | ~90% | 5 (no new vignettes) |
| v0.6.0 | ~1,400 | ~90% | 6 (+flexible-count-estimation) |
| v0.7.0 | 1,588 | ~90% | 7 (+section-estimation) |
| v0.8.0 | 1,696 | ~90% | 10 (+ice-fishing, +camera-surveys, +aerial-surveys) |
| v0.9.0 | ~1,838 | ~90% | 10 (no new vignettes) |
| v1.0.0 | ~1,838 | ~90% | 10 (no new vignettes; website-only milestone) |
| v1.1.0 | ~1,864 | ~90% | 10 (no new vignettes; scheduling vignette extended) |
| v1.2.0 | ~1,864+ | ~90% | 14 (+survey-tidycreel, +effort-pipeline, +catch-pipeline, +aerial-glmm) |

### Top Lessons (Verified Across Milestones)

1. **Primary sources beat existing implementations:** All existing R bus-route packages had wrong πᵢ. Reading the primary source (Jones & Pollock 2012) before implementation prevented propagating those errors
2. **lintr at every commit prevents cleanup phases:** Zero linting debt across all milestones — pre-commit enforcement works
3. **Golden tests from known answers:** Box 20.6 (v0.4.0), TOST reference values (v0.3.0), manual survey calculations (v0.1.0), svycontrast cross-checks (v0.7.0) — reference tests are the strongest quality signal
4. **Dispatch order is architectural:** Multi-strategy estimators (bus-route, ROM, standard, sectioned) require careful ordering of dispatch checks relative to design slot availability
5. **Human review gates have value for domain documentation:** Vignettes explaining statistical decisions in domain vocabulary need practitioner sign-off that automated tests cannot provide
6. **Skip decisions should update requirements files immediately:** Phase 52 skip created checkbox debt resolved only at milestone completion — update requirements at decision time, not archive time

---
*Last updated: 2026-04-02 after v1.1.0 milestone*
