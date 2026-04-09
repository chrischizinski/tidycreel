# Phase 64: GLMM Aerial Estimator - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement `estimate_effort_aerial_glmm()` — a GLMM-based correction for non-random flight timing bias (Askey 2018, lme4) — and a companion vignette with a decision guide, worked example, and comparison to the simple estimator. Section-level GLMM estimation is out of scope for this phase.

</domain>

<decisions>
## Implementation Decisions

### Model specification
- Default formula: `count ~ poly(hour, 2) + (1|date)` (Askey 2018 quadratic temporal model with day-level random intercept)
- User can override with a custom lme4 formula via a `formula` argument (optional; default is NULL → uses Askey formula)
- GLM family: user-selectable via a `family` argument; default is negative binomial (`lme4::glmer.nb()`); Poisson and other families supported
- Time-of-flight column: user-named column in count data, passed via a `time_col` argument (tidyselect pattern, consistent with `count_time_col` in `estimate_effort()`)

### Variance / CI method
- Default: parametric delta method (propagate fixed-effect covariance from lme4 to derived total effort)
- Optional bootstrap: `boot = TRUE` + `nboot = 500` (default) runs `lme4::bootMer()` for bootstrap CIs; user can override `nboot`
- `creel_estimates` column mapping: `se` = delta method (or bootstrap) SE, `se_between` = fixed-effect SE component, `se_within` = NA (no Rasmussen decomposition for GLMM)
- Emit `cli_inform()` before bootstrap runs ("Running {nboot} bootstrap replicates via lme4::bootMer...") — suppressable via `suppressMessages()`

### Input data contract
- Entry point: `estimate_effort_aerial_glmm(design, time_col, ...)` — same `creel_design` object as all other estimators; count data (including the time-of-flight column) lives in `design$counts` after `add_counts()` is called
- Single count column only — no section-grouped GLMM in this phase
- Strict `design_type` validation: `cli_abort()` if `design$design_type != "aerial"`, naming the found type and pointing to `estimate_effort()` for other survey types
- `lme4` not-installed guard: `rlang::check_installed("lme4")` at the top of the function (consistent with `knitr`/`writexl`/`readxl` pattern)

### Vignette structure
- New standalone file: `vignettes/aerial-glmm.Rmd` alongside existing `aerial-surveys.Rmd`
- Opens with the decision guide section: ~2-3 paragraphs explaining random vs. non-random flight timing, what "non-random" means in practice, and when to use GLMM vs. simple estimator
- Worked example uses new `example_aerial_glmm_counts` built-in dataset (includes a `time_of_flight` column absent from `example_aerial_counts`)
- Vignette includes a side-by-side comparison: simple estimator result vs. GLMM result on the same data, showing the bias correction
- pkgdown placement: under the existing "Survey Types" navbar section, alongside `aerial-surveys.Rmd`
- Cross-link to `aerial-surveys.Rmd` for the basic workflow

### Claude's Discretion
- Exact argument name for the formula override (`formula`, `glmm_formula`, or `model_formula`)
- Whether `boot = TRUE` uses parametric or case bootstrap (parametric is standard for lme4::bootMer)
- Exact structure of the `example_aerial_glmm_counts` dataset (number of days, hours, count values — should be round and traceable)
- Section ordering within the vignette beyond the constraints above (decision guide first, then worked example)
- How to document the `se_within = NA` behavior in Rd (a brief note in `@return` is sufficient)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `R/creel-estimates-aerial.R`: existing `estimate_effort_aerial()` — the simple estimator to build alongside; same `creel_design` + `add_counts()` input, same `creel_estimates` output contract; `h_over_v` calibration constant reusable
- `rlang::check_installed()`: used for `readxl`, `writexl`, `knitr` — apply same pattern for `lme4`
- `get_variance_design()`: existing helper for variance method dispatch — GLMM has its own variance path so this is not reused, but the pattern informs how to structure the `boot` argument
- `new_creel_estimates()`: constructor for the output object — GLMM result uses the same constructor with `method = "aerial_glmm_total"` (or similar)
- `vignettes/aerial-surveys.Rmd`: existing simple-estimator vignette to cross-link from and mirror structurally

### Established Patterns
- `design_type` guard: `if (design$design_type != "aerial") cli_abort(...)` — same pattern as ice/camera design-type guards
- tidyselect column references: `time_col = rlang::enquo(time_col)` → `rlang::as_name()` — consistent with `count_time_col` in `estimate_effort()`
- `lme4` is in `Suggests`; the `check_installed()` guard ensures the error message names the missing package and explains installation
- `vignettes/bus-route-equations.Rmd`: established pattern for LaTeX-heavy vignettes with annotated equations

### Integration Points
- `DESCRIPTION Suggests`: add `lme4` (not yet listed)
- `_pkgdown.yml` `articles:` → "Survey Types" section: add `aerial-glmm` slug
- New dataset `example_aerial_glmm_counts`: add to `R/data.R` + `data/` (same pattern as `example_aerial_counts`)
- No changes to `estimate_effort()`, `creel_design()`, or any existing estimators

</code_context>

<specifics>
## Specific Ideas

- The decision guide opening should be practical: "If your pilot always flies at the same time of day (e.g., 10am), your count systematically over- or under-represents total daily effort. The GLMM approach models how angler counts change through the day and corrects for where in that curve your flight falls."
- The side-by-side comparison in the vignette should show both estimates and their CIs on the same rows — easy to see the bias correction numerically

</specifics>

<deferred>
## Deferred Ideas

- **Section-level GLMM**: Fit separate GLMMs per section and return section-level `creel_estimates`. Natural extension but each section needs sufficient data for a stable GLMM fit; belongs in its own phase.

</deferred>

---

*Phase: 64-glmm-aerial-estimator*
*Context gathered: 2026-04-05*
