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

### Top Lessons (Verified Across Milestones)

1. **Primary sources beat existing implementations:** All existing R bus-route packages had wrong πᵢ. Reading the primary source (Jones & Pollock 2012) before implementation prevented propagating those errors
2. **lintr at every commit prevents cleanup phases:** Zero linting debt across all 7 milestones — pre-commit enforcement works
3. **Golden tests from known answers:** Box 20.6 (v0.4.0), TOST reference values (v0.3.0), manual survey calculations (v0.1.0), svycontrast cross-checks (v0.7.0) — reference tests are the strongest quality signal
4. **Dispatch order is architectural:** Multi-strategy estimators (bus-route, ROM, standard, sectioned) require careful ordering of dispatch checks relative to design slot availability
5. **Human review gates have value for domain documentation:** Vignettes explaining statistical decisions in domain vocabulary need practitioner sign-off that automated tests cannot provide

---
*Last updated: 2026-03-22 after v0.8.0 milestone*
