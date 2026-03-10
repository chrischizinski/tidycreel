---
gsd_state_version: 1.0
milestone: v0.1
milestone_name: milestone
status: planning
stopped_at: Completed 39-03-PLAN.md (estimate_effort_sections implementation)
last_updated: "2026-03-10T23:57:12.584Z"
last_activity: 2026-03-10 — v0.7.0 roadmap created (Phases 39-42)
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-10)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.7.0 — Spatially Stratified Estimation

## Current Position

Phase: Phase 39 — Section Effort Estimation (complete)
Plan: 39-01, 39-02, 39-03 all complete; SECT-01 through SECT-05 all passing
Status: Phase 39 complete; ready for Phase 40 (interview-based rates)
Last activity: 2026-03-10 — Phase 39 Plan 03 complete (estimate_effort_sections)

### Progress Bar

```
Phase 39 [==--------] Plan 01/? complete
Phase 40 [----------] Not started
Phase 41 [----------] Not started
Phase 42 [----------] Not started
```

## Performance Metrics

**Velocity:**
- Total plans completed: 52 (through v0.6.0) + 1 (Phase 39-01) = 53
- v0.1.0 (Phases 1-7): 12 plans
- v0.2.0 (Phases 8-12): 10 plans
- v0.3.0 (Phases 13-20): 16 plans
- v0.4.0 (Phases 21-27): 14 plans

**By Milestone:**

| Milestone | Phases | Plans | Status | Completed |
|-----------|--------|-------|--------|-----------|
| v0.1.0 | 1-7 | 12/12 | Complete | 2026-02-09 |
| v0.2.0 | 8-12 | 10/10 | Complete | 2026-02-11 |
| v0.3.0 | 13-20 | 16/16 | Complete | 2026-02-16 |
| v0.4.0 | 21-27 | 14/14 | Complete | 2026-02-28 |
| v0.5.0 | 28-35 | 18/18 | Complete | 2026-03-08 |
| v0.6.0 | 36-38 | 5/5 | Complete | 2026-03-09 |
| v0.7.0 | 39-42 | 1/? | In progress | — |

**Quality Metrics (current):**
- Test coverage: ~90% (1,409 tests — Phase 37 complete as of 2026-03-09)
- R CMD check: 0 errors, 0 warnings
- lintr: 0 issues
| Phase 39-section-effort-estimation P02 | 5 | 2 tasks | 1 files |
| Phase 39-section-effort-estimation P03 | 13 | 2 tasks | 4 files |

## Accumulated Context

### v0.7.0 Phase Dependency Order

39 (Section effort + shared infrastructure) → 40 (Interview-based rates — CPUE, harvest, release) → 41 (Product estimators — total catch/harvest/release; requires 39+40) → 42 (Example data + vignette; requires 39+40+41)

### v0.7.0 Architectural Decisions (locked)

**Variance aggregation for lake-wide totals:**
- DEFAULT (`method = "correlated"`): `svyby(covmat=TRUE)` + `svycontrast()` — correct for NGPC shared-calendar designs where sections share day-level PSUs and cross-section covariance is non-zero (empirically negative)
- ALTERNATIVE (`method = "independent"`): Cochran 5.2 `SE_total = sqrt(sum(SE_h^2))` — documented approximation for genuinely independent section designs only; not the default
- Naive Cochran 5.2 additivity as default was explicitly evaluated and rejected: overstates lake-wide SE for shared-PSU designs

**CPUE is not additive:**
- `estimate_cpue()` with section dispatch produces NO `.lake_total` row — enforced by design, not convention
- Lake-wide CPUE requires a separate unpooled call on the full design
- This must be documented in `?estimate_cpue` help page and the vignette

**Product estimator aggregation:**
- Lake-wide total = `sum(TC_i)` where `TC_i = E_i * CPUE_i` per section
- Never `E_total * CPUE_pooled`
- Cross-design covariance (count-based effort vs. interview-based CPUE) is not identified; zero-covariance assumption applies (same as lake-level) and must be documented

**`prop_of_lake_total` denominator:**
- Always use the lake-wide estimate from the full-design `svytotal`, not `sum(section_estimates)`
- The two differ because they come from different estimation paths; section proportions summed against actual lake total must equal 1.0

**Per-section svydesign construction:**
- Build a fresh `svydesign` from filtered counts via `rebuild_counts_survey()` (new, analogous to `rebuild_interview_survey()`)
- Do NOT use `subset(design$survey, section == "A")` — produces domain-estimate variance with wrong PSU denominator

**`aggregate_sections` default:**
- `TRUE` — matches biologist mental model and legacy NGPC report template
- `FALSE` suppresses the `.lake_total` row for power users

### Phase 39 Plan 01 — Already shipped

`add_sections()` with full validation, `format.creel_design()` sections block, section guards in `add_counts()` and `add_interviews()`. See commit history for implementation details.

### Key Architectural Constraints

- New parameters in `add_interviews()` must be optional (INTV-06 backward compatibility)
- Catch data in long format: one row per species per interview (matches DB schema)
- Release lengths: handle both individual measurements AND pre-binned length-group format
- All new summary functions return tidy tibbles with consistent column naming + class attribute
- Existing estimator APIs unchanged — section dispatch added via optional args, not breaking changes
- Section-aware code paths MUST begin with `if (is.null(design$sections))` NULL guard

### v0.5.0 Phase Dependency Order

28 (INTV) → 28.1 (normalize_by_anglers, later fully reverted) → 29 (CATCH) → 30 (LEN) → 31 (USUM, needs 28+29) → 32 (CWS, needs 29+28) → 33 (LFREQ, needs 30) → 34 (XEST, needs 29) → 35 (DOCS, needs all)

### Roadmap Evolution

- Phase 28.1 inserted after Phase 28: Normalize CPUE/HPUE by angler count (URGENT) — `normalize_by_anglers` arg added to existing estimators so party-hours → angler-hours when `n_anglers_col` is set; literature-backed (Hoenig, Jones et al.) — party size confounds per-party-hour rates
- Phase 32 removed `normalize_by_anglers` from `estimate_cpue()` and `estimate_harvest()` — replaced by unconditional `design$angler_effort_col` (add_interviews defaults n_anglers=1)
- Phase 34 inconsistently re-added `normalize_by_anglers` to `estimate_release_rate()` only; resolved 2026-03-08 by removing it to match cpue/harvest — all three rate functions now use `design$angler_effort_col` unconditionally

### Decisions (28-01)

- Inserted five new params between `n_interviewed` and `date_col` in `add_interviews()` signature to group optional extended-interview metadata together
- Regenerated `add_interviews.Rd` via roxygen2::roxygenize() — stale Rd caused R CMD check WARNING; required as part of task completion

### Decisions (28-02)

- Used `expect_match(output, "Angler type")` (human label) not column name for print method tests — verifies user-facing display label from `format.creel_design()`, not internal storage name
- `make_extended_interviews()` extends `make_test_interviews()` by appending columns — avoids duplicating fixture data

### Decisions (28.1-01)

- Wrapped `estimate_cpue_total` and `estimate_cpue_grouped` signatures at 120-char limit to satisfy lintr; `normalize_by_anglers = FALSE` placed on continuation line
- Added `@param normalize_by_anglers` roxygen docs to both public functions and regenerated Rd files to eliminate codoc WARNING in rcmdcheck
- `effort_col <- ".effort_adj"` is a LOCAL reassignment inside each helper; design object never mutated
- **2026-03-08**: `normalize_by_anglers` fully reverted from all three rate functions (cpue/harvest in Phase 32, release in post-34 fix). Current architecture: unconditional `design$angler_effort_col` in all rate estimators. INTV-07 closed as Superseded.

### Decisions (29-01)

- catch_type='caught' total per interview must equal catch_total; 'harvested' total must equal catch_kept — verified via in-script stopifnot() loops in create_example_catch.R
- Interviews without catch data have no rows in example_catch (zero-catch represented by absence, not zero-count rows)
- Used `\code{add_catch()}` instead of `[add_catch()]` in @format/@seealso to avoid unresolvable roxygen2 link warnings until Phase 29 Plan 02 implements that function

### Decisions (29-02)

- Immutability guard uses `design[["catch"]]` exact matching not `design$catch` — R's `$` partially matches `design$catch_col`, causing a false positive immutability error on fresh designs
- Consistency check (catch totals vs interview-level catch_col) uses `cli_warn()` not `cli_abort()` — divergence is advisory, not fatal (partial species recording is legitimate)
- CATCH-04 validation only fires when a "caught" row is present; without a caught row, total is inferred as harvested+released and no check is needed

### Decisions (29-03)

- format.creel_design() has_catch guard uses `x[["catch"]]` not `x$catch` — same partial-match issue as add_catch() immutability guard
- Test helper suppressWarnings() wraps add_interviews() call to silence pre-existing survey::svydesign() "no weights" warning
- data() calls inside make_design_with_interviews() helper ensure example datasets are loaded; all tidy-select args get # nolint: object_usage_linter per project convention

### Pending Todos

- #1: Simulation study for complete vs. incomplete trip pooling bias (post-v0.3.0)

### Blockers/Concerns

None currently.

## Session Continuity

Last session: 2026-03-10T23:57:12.581Z
Stopped at: Completed 39-03-PLAN.md (estimate_effort_sections implementation)
Resume file: None
Next step: `/gsd:plan-phase 39` to plan remaining Phase 39 work (SECT-01 through SECT-05)

### Decisions (39-02)

- `add_sections()` requires explicit `section_col = section` (unquoted tidy-select arg, no default); fixtures use `section_col = section`
- SECT-04 regression guard passes GREEN immediately — confirms backward compatibility of non-sectioned designs; intentional correct behavior
- SECT-03b (`expect_error` for `missing_sections="error"`) passes GREEN because `estimate_effort()` throws "unused argument" error — acceptable temporary false-green, will become stricter once 39-03 implements the parameter
- Function names > 30 chars suppress `object_length_linter` inline per project convention (same pattern as Phase 31-02)

### Decisions (39-03)

- Section dispatch added after bus-route block, before warn_tier2_issues(); non-section paths untouched (SECT-04)
- aggregate_section_totals() contrast vector names from rownames(vcov(by_result)) not positional integers — required per RESEARCH.md Pitfall 1
- prop_of_lake_total denominator from full-design svytotal (not sum of section estimates); ensures proportions sum to 1.0
- SECT-03a test uses withCallingHandlers(invokeRestart("muffleWarning")) — suppressWarnings() swallows cli_warn() before expect_warning() can capture it
- n_absent local variable uses # nolint: object_usage_linter — cli NSE string interpolation invisible to lintr
- qt, setNames, vcov added to @importFrom stats to resolve R CMD check NOTE

### Decisions (31-planning)

- `design$strata_cols` is PLURAL (character vector) — use `strata_cols[1]` in summarize_by_day_type()
- `design[["catch"]]` double-bracket required in summarize_successful_parties() to avoid partial match
- `refused` column is logical (TRUE/FALSE) — convert via ifelse() to "accepted"/"refused" before tabulation
- All 22 example_interviews are from June 2024 with refused=FALSE — test fixture must inject refused=TRUE manually
- summarize_trips() returns a named list; Phase 31 functions return data.frame with two-element class c("creel_summary_<type>", "data.frame")

### Decisions (31-01)

- File header comment `# R/creel-summaries.R` triggers commented_code_linter — replaced with sentence-form comment to comply
- Styler pre-commit hook reformats spacing automatically — re-stage after first commit attempt is expected workflow
- strata_cols[1] (plural, index 1) gives day type column name — no Guard 3 needed for summarize_by_day_type() since strata_cols always set by creel_design()

### Decisions (31-02)

- object_length_linter suppressed on make_design_with_extended_interviews() — function name required by plan spec (38 chars > 30 limit); inline # nolint per project convention
- object_usage_linter suppressed on suppressWarnings() line — lintr cannot resolve NSE tidy-select args; same pattern as test-add-catch.R
- Catch guard test for summarize_successful_parties() uses design with angler_type + species_sought but no add_catch() — required to reach Guard 3c (catch) rather than Guard 3a (angler_type)

### Decisions (36-02)

- CI recomputed from `qt(1 - alpha/2, df = survey::degf())` instead of `confint(svy_result)` (qnorm); gives wider, more conservative CIs — two reference tests updated accordingly
- `compute_within_day_var_contribution()` returns variance in total scale (multiplied by N_s); lintr object_length_linter suppressed on function definition line (34 chars)
- Variable names use snake_case throughout (`n_avail`, `k_bar`, `s2_within`, `v_within`) to satisfy object_name_linter — formula symbols documented in roxygen comment only
- `se_between` and `se_within` always present in output tibble; `se_within = 0` for single-count designs avoids conditional column schemas

### Decisions (37-01)

- Pope et al. formula Ê_d = C × τ × κ simplifies to C × T_d (κ cancels), but τ × κ form kept in code for traceability to literature
- Two-PSU helper required for `estimate_effort()` test — single-PSU strata hard-error in survey package variance computation
- `period_length_col` dropped from `design$counts` after Ê_d computation to prevent misidentification as count variable by downstream estimators

### Decisions (38-02)

- Pope et al. vignette example uses 2-day weekday design; per-day Ê_d = 1,872 shown via `design$counts` slot — single-PSU stratum errors in survey package variance computation
- Coverage 86.54% is pre-existing gap from Phase 37 progressive-count code paths; vignette does not affect coverage
