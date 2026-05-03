# Architecture: v1.6.0 Feature Integration

**Project:** tidycreel v1.6.0 — Analytical Extensions II
**Researched:** 2026-05-02
**Confidence:** HIGH (based on direct codebase analysis)

---

## Existing Architecture Baseline

Before mapping each feature, the relevant structural facts:

**creel_design object** (constructed by `creel_design()`, extended by `add_*` chain):
```
design$calendar        — source calendar data frame
design$date_col        — character column name
design$strata_cols     — character vector of stratum column names
design$design_type     — survey_type string (camera, aerial, instantaneous, bus_route, ice)
design$counts          — NULL until add_counts(); data frame after
design$survey          — NULL until estimation; populated internally
design$interviews      — NULL until add_interviews()
design$camera          — list(survey_type, camera_mode) for camera designs; NULL otherwise
design$aerial          — list(survey_type, h_open, visibility_correction) for aerial; NULL otherwise
design$bus_route       — list with sampling frame + .pi_i for bus_route; NULL otherwise
design$ice             — list for ice designs; NULL otherwise
design$sections        — NULL until add_sections()
```

**creel_estimates object** (constructed by `new_creel_estimates()`):
```
result$estimates       — tibble of estimate, se, ci_lower, ci_upper, n + optional columns
result$method          — character method label (e.g. "product-total-catch")
result$variance_method — character (taylor/bootstrap/jackknife/delta)
result$design          — reference to source creel_design or NULL
result$conf_level      — numeric
result$by_vars         — character vector or NULL
```

**Established naming conventions:**
- User-facing exported functions: `estimate_*()`, `creel_n_*()`, `add_*()`, `audit_*()`, `validate_*()`, `check_*()`
- Internal helpers: `.estimate_*_*()` (unexported, noRd)
- Public wrappers that front-load validation then delegate to internal: `est_*()` (camera effort) or direct `estimate_*()` (most estimators)
- Result classes: `creel_estimates` (base), sub-classed via prepending (e.g., `c("creel_estimates_mor", "creel_estimates")`)
- File naming: `creel-estimates-<domain>.R` for estimator files
- `@family` grouping: "Survey Design", "Estimation", "Planning & Sample Size", "Reporting & Diagnostics"

**autoplot dispatch:** `autoplot.creel_estimates()` reads `object$method` through a `switch()` for the plot title label and falls through to the raw method string if no match. New method strings are automatically renderable without modifying autoplot.

**print/format dispatch:** `format.creel_estimates()` has a switch on `method` for human-readable labels. New method strings display as their raw value if not added to the switch.

---

## Feature 1: Camera Missing Data Imputation

### What it does
Fills in camera count data for days where the camera was non-operational (`camera_status` values such as `"battery_failure"`, `"memory_full"`) using a GLMM or GLM fitted to operational days. The imputed counts replace or augment `design$counts` so that `est_effort_camera()` can proceed on a complete panel.

### Integration point
Camera count data enters the system through `add_counts()`. The existing example data (`example_camera_counts`) already includes a `camera_status` column, and `est_effort_camera()` explicitly lists `camera_status` as an excluded column when identifying the numeric count variable (line 64 of `creel-estimates-camera.R`). The current workflow requires the user to manually filter to operational rows before calling `add_counts()`.

The imputation function sits between the raw counts data frame and `add_counts()`, not between `add_counts()` and `est_effort_camera()`.

### New components

**`impute_camera_counts(counts, design, method = c("glmm", "glm", "mean"), ...)`**
- Input: raw counts data frame (with `camera_status` column), a `creel_design` object (for strata column names), method selector
- Output: the counts data frame with NA/failure rows replaced by model-predicted values, plus an `imputation_flag` column marking imputed rows
- Does NOT modify `design$counts` — returns a modified counts data frame the user passes to `add_counts()`
- Depends on `lme4` (already in Suggests) for GLMM path; GLM path uses only `stats`
- Internal helpers: `.fit_imputation_glmm()`, `.fit_imputation_glm()`, `.impute_by_stratum()` — all `@noRd`

**No new S3 class is needed.** The returned object is a data frame, not a `creel_design` or `creel_estimates`. Imputation metadata (n imputed, method used, model summary) can be attached as attributes.

### Modified components
- None modified. The existing `add_counts()` → `est_effort_camera()` chain is unchanged.
- `check_completeness()` could optionally gain awareness of `imputation_flag` columns in a future phase, but is not required for the imputation feature itself.

### Data flow
```
raw_camera_counts (with camera_status)
    |
impute_camera_counts(counts, design, method)
    |
imputed_counts (same structure + imputation_flag column)
    |
add_counts(design, imputed_counts)
    |
est_effort_camera(design, ...)
```

### Breaking change risk: NONE
- `impute_camera_counts()` is a new function; nothing existing is modified.
- The filter-before-add-counts pattern in existing docs/examples continues to work as before.
- `lme4` is already in Suggests, so no dependency change is needed for the GLM fallback path. The GLMM path should add a runtime install guard using the same pattern as `lubridate` guards in the codebase.

### File placement
`R/impute-camera.R` — new file following the `R/<domain>.R` convention.

---

## Feature 2: Camera Design Helper (`creel_n_camera()`)

### What it does
Takes target CV / precision plus camera-specific sampling constraints (outage rate, detection reliability, stratum structure) and returns recommended number of sampling days per stratum. Mirrors `creel_n_effort()` and `creel_n_cpue()` for the camera domain, following Feltz and Middaugh (2025).

### Integration point
This is a pure planning function. It has no dependency on a `creel_design` object and produces no `creel_estimates` object. It lives entirely in the Planning & Sample Size family alongside `creel_n_effort()`, `creel_n_cpue()`, and `cv_from_n()`.

### New components

**`creel_n_camera(cv_target, N_h, ybar_h, s2_h, p_operational, ...)`**
- `p_operational`: per-stratum expected camera uptime probability in (0, 1]. This is the camera-domain parameter not present in `creel_n_effort()`.
- Returns a named integer vector of the same structure as `creel_n_effort()` (per-stratum counts + `total` element) — consistent with the existing pattern.
- `checkmate` validation on all numeric inputs using the same idioms as `creel_n_effort()`.
- `@family "Planning & Sample Size"` to group with existing sample size functions.

**`cv_from_n()` extension** — a new `type = "camera"` branch is a natural extension if the algebraic inverse is needed. This is low cost since `cv_from_n()` already dispatches on `type`. Not strictly required for MVP.

### Modified components
- `cv_from_n()` gains an optional `"camera"` type branch (additive, no existing behavior changes).
- `validate_design()` could gain a `type = "camera"` branch for camera designs. Not required for MVP but architecturally clean.

### Breaking change risk: NONE
- `creel_n_camera()` is a new function.
- The optional `cv_from_n()` extension adds a new match.arg value — only additive.

### File placement
`R/power-sample-size.R` — appended to the existing file, following the precedent of `creel_n_effort()` and `creel_n_cpue()` living in the same file.

---

## Feature 3: Mark-Recapture Harvest Estimators (`estimate_harvest_mr()`)

### What it does
Estimates fish population size or harvest using Petersen, Schnabel, and Jolly-Seber mark-recapture estimators, accepting scalar summary statistics (like `estimate_exploitation_rate()`) rather than a full `creel_design`. Returns a `creel_estimates` object with `autoplot()` support.

### Integration point
`estimate_exploitation_rate()` establishes the canonical pattern for scalar-input estimators: takes pre-computed summary statistics, performs delta-method or analytical variance, returns `new_creel_estimates(..., design = NULL)`. The mark-recapture estimators follow this same pattern.

Key design decision from M024: "scalar input pattern — Takes pre-computed summary stats — no creel_design dependency." This decision applies to the MR estimators as well. The Petersen/Chapman/Schnabel estimators take counts (M, C, R for Petersen; cumulative marks + recaptures for Schnabel) as scalars; Jolly-Seber takes a summary data frame (by occasion).

The previous analytical extensions research (M022/71) recommended wrapping `FSA::mrClosed()` and `FSA::mrOpen()` for the standard families. However, FSA is not currently in Suggests. Adding it is viable (pure R, no external binary) but must be an explicit decision. Alternatively, the Petersen/Chapman closed-population estimator is simple enough to implement directly without FSA, matching the `estimate_exploitation_rate()` build-not-wrap precedent.

### New components

**`estimate_harvest_mr(estimator = c("petersen", "chapman", "schnabel"), ...)`**
- Dispatches on `estimator` argument
- Unstratified path: scalars M (marks released), C (total captured), R (recaptures)
- Chapman-corrected variant: standard small-sample correction
- Returns `new_creel_estimates(method = "mark-recapture-petersen")` or similar method string
- Internal helpers: `.estimate_mr_petersen()`, `.estimate_mr_schnabel()` — `@noRd`

**Jolly-Seber path** (if included in v1.6.0):
- `estimate_harvest_mr(estimator = "jolly_seber", occasions = <data.frame>)`
- `occasions` data frame mirrors the `strata` data frame pattern from `estimate_exploitation_rate()` — columns: `occasion`, `n_marked`, `n_captured`, `n_recaptured`
- Returns per-occasion rows + optional aggregate with `aggregate = TRUE`

**Method strings for `format.creel_estimates` and `autoplot.creel_estimates`:**
- `"mark-recapture-petersen"` → "Petersen Mark-Recapture"
- `"mark-recapture-schnabel"` → "Schnabel Mark-Recapture"
- `"mark-recapture-jolly-seber"` → "Jolly-Seber Mark-Recapture"
- Both `format.creel_estimates` and `autoplot.creel_estimates` switch statements require new entries for clean display; the fallthrough to raw method string works but is not user-facing quality.

### Modified components
- `format.creel_estimates()` in `creel-estimates.R` — add method string cases to the switch (lines ~171–183 of creel-estimates.R). Minor additive change.
- `autoplot.creel_estimates()` in `autoplot-methods.R` — add method string cases to the switch. Minor additive change.
- No changes to `creel_design`, `add_*` functions, or any survey-bridge code.

**FSA dependency question:**
- If FSA is added: goes in `Suggests` (not `Imports`) — runtime install guard using existing `lubridate` guard pattern. CRAN-safe. FSA is pure R.
- If building Petersen/Chapman from scratch: no dependency change. Recommended for v1.6.0 to avoid a new dependency for a formula that fits in 20 lines.

### Breaking change risk: NONE (new function + additive format/autoplot switch entries)

### File placement
`R/creel-estimates-mark-recapture.R` — new file following the `creel-estimates-<domain>.R` convention.

---

## Feature 4: Stratification Audit (`audit_strata()`)

### What it does
Takes a `creel_design` object (post-season, with counts and/or interviews attached) or a set of pilot summary statistics, and returns a precision comparison across strata — flagging over-sampled strata (where sample size greatly exceeds required n) and under-sampled strata (where CV is not met). Integrates with `compare_designs()` and `validate_design()`.

### Integration point
`validate_design()` already does pre-season checking against targets (pass/warn/fail per stratum using `creel_n_effort()` and `cv_from_n()`). `compare_designs()` compares multiple `creel_estimates` objects on a forest plot. The stratification audit is post-hoc and descriptive: given what was actually collected, how did each stratum perform, and which strata are candidates for collapsing or splitting in the next season?

`audit_strata()` is distinct from `validate_design()` in direction (retrospective not prospective) and output (precision metrics + design recommendations, not pass/fail against a target).

### New components

**`audit_strata(design, cv_target = NULL, ...)`**
- Input: a `creel_design` with counts (and optionally interviews) attached, plus an optional CV target for comparison
- Returns a new S3 class `creel_strata_audit` — a data frame with per-stratum columns: `stratum`, `n_sampled`, `n_available`, `sampling_rate`, `cv_achieved`, `cv_required` (if `cv_target` supplied), `status` (over/adequate/under)
- Optional: `reduction_candidates` — strata where merging two into one would still meet the CV target
- `@family "Reporting & Diagnostics"` — groups with `validate_design()` and `check_completeness()`

**`print.creel_strata_audit()`** and **`format.creel_strata_audit()`** — cli-formatted output following `format.creel_design_report()` pattern.

**`autoplot.creel_strata_audit()`** — bar chart of CV by stratum with target reference line. Returns a `ggplot` object.

### Modified components
- `compare_designs()` — no modification required. `audit_strata()` produces its own class; if comparison of audit results across multiple designs is needed, that is a future capability. The existing `compare_designs()` takes `creel_estimates` objects; `creel_strata_audit` is distinct.
- `check_completeness()` — no modification required; the two are complementary (completeness = did we collect data; audit = was the data sufficient).
- `validate_design()` — no modification required; `audit_strata()` is the retrospective counterpart.

### New S3 class: `creel_strata_audit`
Structure:
```r
structure(
  list(
    results            = tibble,   # per-stratum metrics
    reduction_candidates = tibble | NULL,  # merge suggestions
    survey_type        = character,
    cv_target          = numeric | NULL,
    passed             = logical
  ),
  class = "creel_strata_audit"
)
```

This follows the constructor pattern of `new_creel_design_report()` and `new_creel_completeness_report()` in `design-validator.R`.

### Breaking change risk: NONE
- New function, new class, new autoplot method.
- `compare_designs()` is unchanged.

### File placement
`R/design-validator.R` — appended to the existing file, following the precedent of `validate_design()` and `check_completeness()` living together. Alternatively, `R/audit-strata.R` as a separate file if the implementation is large (>200 lines). Recommend separate file to keep `design-validator.R` readable.

---

## Build Order and Dependencies

### Dependency graph among the four features

```
creel_n_camera()          — no dependencies on the other three features
impute_camera_counts()    — no dependencies; uses existing creel_design structure
estimate_harvest_mr()     — no dependencies; scalar inputs, no creel_design
audit_strata()            — depends on creel_design with counts attached;
                            uses creel_n_effort() and cv_from_n() (already exist)
```

The four features have no inter-dependencies. Any build order is technically valid.

### Recommended build order

**Phase 1: `creel_n_camera()`**
Rationale: Pure planning function, no survey or estimation machinery involved. Simplest test surface (property-based tests trivially applicable using existing `quickcheck` patterns from `creel_n_effort()`). Establishes the camera domain's sample-size vocabulary before the imputation work.

**Phase 2: `impute_camera_counts()`**
Rationale: The camera workflow is incomplete without it. Build after the camera sample-size helper so the two camera features are coherent. The GLMM path requires `lme4`; the GLM fallback uses only `stats`. Recommend implementing GLM path first, then GLMM path, so the feature is shippable before the harder statistical path is done.

**Phase 3: `estimate_harvest_mr()`**
Rationale: Scalar-input pattern is well-proven from `estimate_exploitation_rate()`. No creel_design coupling means tests are straightforward. Petersen/Chapman before Schnabel before Jolly-Seber within the phase (increasing complexity). Add `format.creel_estimates` and `autoplot.creel_estimates` switch entries in this phase.

**Phase 4: `audit_strata()`**
Rationale: Requires the most integration awareness (reads `design$counts`, delegates to existing `creel_n_effort()` and `cv_from_n()`). Benefits from having the other features complete so test fixtures are richer. The retrospective precision comparison is the most novel UX and merits its own phase.

---

## Breaking Change Risk Assessment

| Feature | Risk | Reason |
|---------|------|--------|
| `impute_camera_counts()` | None | New function; add_counts / est_effort_camera chain unchanged |
| `creel_n_camera()` | None | New function; optional cv_from_n extension is additive only |
| `estimate_harvest_mr()` | Minimal | format.creel_estimates and autoplot.creel_estimates gain new switch cases — additive |
| `audit_strata()` | None | New function, new class, new autoplot dispatch — all additive |

**No existing public API is modified.** No existing function signatures change. No `creel_design` slots are renamed or removed.

**Dependency changes:**
- `lme4` (already in Suggests): needs runtime install guard in `impute_camera_counts()` GLMM path — pattern already established with `lubridate`
- `FSA`: NOT recommended for v1.6.0 — implement Petersen/Chapman/Schnabel directly (all are 2-10 line formulas), following the `estimate_exploitation_rate()` build-not-wrap precedent. Avoids a new Suggests entry for simple formulas.

---

## Naming Convention Consistency Check

| New Function | Consistent With | Convention |
|-------------|-----------------|------------|
| `impute_camera_counts()` | `preprocess_camera_timestamps()` | verb_noun pattern for data-transformation functions |
| `creel_n_camera()` | `creel_n_effort()`, `creel_n_cpue()` | `creel_n_<domain>` planning family |
| `estimate_harvest_mr()` | `estimate_exploitation_rate()`, `estimate_total_harvest_br()` | `estimate_<what>_<qualifier>` pattern |
| `audit_strata()` | `validate_design()`, `check_completeness()` | verb_noun diagnostic functions |

All four new names are consistent with existing conventions.

---

## Summary Table

| Feature | New Functions | Modified Functions | New Classes | Files |
|---------|--------------|-------------------|-------------|-------|
| Camera imputation | `impute_camera_counts()` + 3 internal helpers | None | None | `R/impute-camera.R` |
| Camera design helper | `creel_n_camera()` + optional `cv_from_n("camera")` | `cv_from_n()` (additive branch only) | None | `R/power-sample-size.R` |
| MR harvest estimators | `estimate_harvest_mr()` + internal dispatch helpers | `format.creel_estimates()`, `autoplot.creel_estimates()` (additive switch entries) | None (reuses `creel_estimates`) | `R/creel-estimates-mark-recapture.R` |
| Stratification audit | `audit_strata()`, `print.creel_strata_audit()`, `format.creel_strata_audit()`, `autoplot.creel_strata_audit()` | None | `creel_strata_audit` | `R/audit-strata.R` |

---

## Sources

All findings are based on direct analysis of the tidycreel codebase at `/Users/cchizinski2/Dev/tidycreel`:
- `R/creel-design.R` — creel_design S3 structure, new_creel_design(), add_counts() chain
- `R/creel-estimates.R` — new_creel_estimates(), format.creel_estimates()
- `R/creel-estimates-camera.R` — estimate_effort_camera() internal, camera_status column exclusion
- `R/est-effort-camera.R` — est_effort_camera() public wrapper
- `R/creel-estimates-exploitation-rate.R` — scalar-input estimator pattern, .estimate_exploitation_rate_stratified()
- `R/power-sample-size.R` — creel_n_effort(), creel_n_cpue(), creel_power(), cv_from_n() patterns
- `R/design-validator.R` — validate_design(), check_completeness(), creel_design_report class pattern
- `R/compare-designs.R` — compare_designs(), creel_design_comparison class, autoplot dispatch
- `R/autoplot-methods.R` — autoplot.creel_estimates() method string dispatch
- `DESCRIPTION` — current Imports and Suggests
- `.planning/milestones/M022-phases/71-future-analytical-needs/71-ANALYTICAL-EXTENSIONS-RESEARCH.md` — prior MR research, FSA/RMark assessment, build-vs-wrap recommendations
- `.planning/PROJECT.md` — v1.6.0 milestone definition, key decisions from M024
