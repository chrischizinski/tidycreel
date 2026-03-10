---
gsd_state_version: 1.0
milestone: v0.1
milestone_name: milestone
status: unknown
last_updated: "2026-03-03T02:17:47.877Z"
progress:
  total_phases: 27
  completed_phases: 25
  total_plans: 47
  completed_plans: 47
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-28)

**Core value:** Creel biologists can analyze survey data using creel vocabulary without understanding survey package internals
**Current focus:** v0.5.0 — Phase 33: Length Frequency Summaries (next phase)

## Current Position

Phase: 38-documentation-quality-assurance
Plan: 38-02 complete
Status: Phase 38 complete (2/2 plans executed); v0.6.0 shipped
Last activity: 2026-03-09 — Phase 38 Plan 02 complete (flexible-count-estimation vignette; R CMD check 0E/0W; lintr 0 issues; 1409 tests)

## Performance Metrics

**Velocity:**
- Total plans completed: 52
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

**Quality Metrics (current):**
- Test coverage: ~90% (1,409 tests — Phase 37 complete as of 2026-03-09)
- R CMD check: 0 errors, 0 warnings
- lintr: 0 issues
| Phase 28.1 P02 | 12m | 2 tasks | 2 files |
| Phase 29-species-catch-data P01 | 5 | 3 tasks | 7 files |
| Phase 29-species-catch-data P02 | 5 | 2 tasks | 3 files |
| Phase 29-species-catch-data P03 | 9m | 2 tasks | 2 files |
| Phase 31 P01 | 8m | 2 tasks | 10 files |
| Phase 31 P02 | 12m | 1 task | 1 file |

## Accumulated Context

### v0.5.0 Phase Dependency Order

28 (INTV) → 28.1 (normalize_by_anglers, later fully reverted) → 29 (CATCH) → 30 (LEN) → 31 (USUM, needs 28+29) → 32 (CWS, needs 29+28) → 33 (LFREQ, needs 30) → 34 (XEST, needs 29) → 35 (DOCS, needs all)

### Roadmap Evolution

- Phase 28.1 inserted after Phase 28: Normalize CPUE/HPUE by angler count (URGENT) — `normalize_by_anglers` arg added to existing estimators so party-hours → angler-hours when `n_anglers_col` is set; literature-backed (Hoenig, Jones et al.) — party size confounds per-party-hour rates
- Phase 32 removed `normalize_by_anglers` from `estimate_cpue()` and `estimate_harvest()` — replaced by unconditional `design$angler_effort_col` (add_interviews defaults n_anglers=1)
- Phase 34 inconsistently re-added `normalize_by_anglers` to `estimate_release_rate()` only; resolved 2026-03-08 by removing it to match cpue/harvest — all three rate functions now use `design$angler_effort_col` unconditionally

### Key Architectural Constraints

- New parameters in `add_interviews()` must be optional (INTV-06 backward compatibility)
- Catch data in long format: one row per species per interview (matches DB schema)
- Release lengths: handle both individual measurements AND pre-binned length-group format
- All new summary functions return tidy tibbles with consistent column naming + class attribute
- Existing estimator APIs unchanged — species grouping added via tidy selectors, not breaking changes

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

Last session: 2026-03-08
Stopped at: Phase 38 Plan 02 complete — flexible-count-estimation vignette; v0.6.0 all gates passed
Resume file: None

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

**Next step:** v0.6.0 shipped; next milestone planning
