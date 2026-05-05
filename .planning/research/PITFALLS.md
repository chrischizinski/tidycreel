# Domain Pitfalls: tidycreel v1.6.0 New Features

**Domain:** Adding imputation, mark-recapture, and design-audit tools to an existing rOpenSci-aligned R estimation package
**Researched:** 2026-05-02
**Overall confidence:** HIGH (verified against existing codebase patterns, lme4 docs, CRAN policy, rOpenSci devguide)

---

## Cross-Cutting Pitfalls

These apply to all four features and must be addressed before any feature-specific work begins.

---

### XC-1: Promoting a New Dependency to Imports Without Architectural Justification

**What goes wrong:** A new statistical package (e.g., `FSA`, `Rcapture`, `mice`) is added to `Imports` because it is "used" by one function. This bloats the install footprint for all users, including those who never touch mark-recapture or imputation. It can also introduce transitive dependency chains that conflict with the existing solver dependencies (`survey`, `lme4`).

**Warning sign:** `DESCRIPTION` `Imports:` list grows beyond 12 packages; no `rlang::check_installed()` guard exists on the new function; `rcmdcheck` NOTE: "Namespace in Imports field not imported from".

**Prevention:**
- Any dependency used by a single feature family belongs in `Suggests`, not `Imports`.
- Guard entry points with `rlang::check_installed("pkg", reason = "to use <fn>()")` — the established pattern in the codebase (see `estimate_effort_aerial_glmm()`).
- Before adding any package: verify in `DESCRIPTION` that it is not already present in `Imports` or `Suggests` under a different name.

**Phase to address:** Requirements / Architecture phase, before any implementation starts. Validate at every `rcmdcheck` run.

---

### XC-2: CRAN Check Regression — `rcmdcheck` 0 errors 0 warnings Release Gate

**What goes wrong:** A new function introduces a `NOTE` or `WARNING` that breaks the release gate. Common sources in statistical packages:
- `no visible binding for global variable` from unquoted column names in `dplyr` or `ggplot2` calls inside new functions.
- Unused `@importFrom` declarations left in roxygen headers.
- Example code that takes > 5 s (CRAN threshold) when a GLMM or bootstrap is run unconditionally.
- `lme4` convergence or singular-fit messages printed to stdout during `R CMD check --as-cran` example runs.

**Warning sign:** `rcmdcheck` output includes "no visible binding", "Namespace in Imports field not imported from", or example time > 5 s.

**Prevention:**
- Wrap all GLMM/bootstrap example code in `\donttest{}` (not `\dontrun{}` — CRAN now runs `\donttest` examples but does not count their time).
- Suppress lme4 convergence messages in examples/tests with `suppressMessages()` — the pattern already used in `test-estimate-effort-aerial-glmm.R`.
- Add `utils::globalVariables()` or `.data$col` pronoun for any tidyeval column references.
- Run `rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "warning")` after every new function is added.

**Phase to address:** Every implementation phase. Add a checklist item: "rcmdcheck clean after this phase's additions."

---

### XC-3: `@family` Tag and pkgdown Grouping Drift

**What goes wrong:** New functions are added without `@family` tags, or they are tagged with a family string that does not exactly match an existing family. The pkgdown reference page develops orphaned entries and loses navigability. The rOpenSci review guide explicitly checks for logical grouping on the pkgdown reference page.

**Warning sign:** `pkgdown::build_site()` emits "unrecognized family" warnings; new function appears in "Other" on the reference index.

**Prevention:**
- Map every new function to one of the established families before writing its roxygen block: `"Planning & Sample Size"`, `"Estimation"`, `"Survey Design"`, etc.
- Run `pkgdown::build_site()` locally after adding each function.

**Phase to address:** Each implementation phase. Verification contract already includes `pkgdown::build_site()`.

---

### XC-4: API Stability Constraint — No Breaking Changes to Existing Signatures

**What goes wrong:** A new helper is added as a lower-level refactor of an existing estimator, and in doing so the existing function's argument names or return structure silently change. Since version 1.3.0 has not been formally released, breaking changes are technically permissible, but the constraint documented in `PROJECT.md` ("Preserve the existing package API unless a change is clearly justified") is the governing rule.

**Warning sign:** Any existing test file begins failing after refactoring work that was intended to be additive.

**Prevention:**
- New functions add to the API; they do not replace existing ones unless the change is explicitly documented as a Key Decision.
- If a refactor touches an existing function, run the full test suite before and after to confirm 0 test regressions.
- If a signature change is genuinely necessary (e.g., a new argument), use a default value that preserves existing behavior and tag the argument with `lifecycle::badge("experimental")`.

**Phase to address:** Any phase that refactors existing code (most likely the camera imputation phase, which touches `est_effort_camera()`).

---

## Feature Area 1: Camera Missing Data Imputation

---

### CAM-1: Confusing Imputation-for-Estimation with Multiple Imputation

**What goes wrong:** The imputation literature (MICE, Amelia) focuses on multiple imputation for inferential bias correction. Camera creel survey imputation (Afrifa-Yamoah 2020) is a different task: filling in counts for outage periods so that a downstream effort estimator sees a complete series. Implementing multiple imputation plumbing is massively over-engineered for this use case and introduces unnecessary package dependencies (`mice`, `Amelia`).

**Warning sign:** Function signature includes `m` (number of imputed datasets) or returns a list of imputed datasets rather than a single filled data frame.

**Prevention:**
- Use point prediction from a fitted GLM/GLMM: `predict(model, newdata = outage_rows, type = "response")`. This is what the Afrifa-Yamoah (2020) camera outage paper does — single-model fill-in, not multiple imputation.
- The function's job is to return a data frame with imputed counts that is compatible with `add_counts()` input — same column structure, same class.

**Phase to address:** Camera imputation implementation phase (design decision to make before writing a single line of implementation).

---

### CAM-2: lme4 glmer.nb Singular Fit or Convergence Failure Crashing the Imputation Function

**What goes wrong:** `glmer.nb` (negative binomial GLMM) is documented as "somewhat unstable/under construction" in lme4 itself. When counts are sparse (common for outage periods, which is exactly when you need the model most), the random-effect variance estimate can hit the boundary (singular fit). By default, lme4 emits a warning and returns a fitted model; but if the function calls `stop()` on any warning, it crashes. Worse, if the function silently swallows the warning without surfacing it to the user, they get imputed values from a pathological fit.

**Warning sign:** `isSingular(model)` returns `TRUE`; lme4 emits "boundary (singular) fit"; bootstrap CI replicates contain `NaN`.

**Prevention:**
- After fitting, call `lme4::isSingular(model)` and surface a `cli::cli_warn()` with a named condition class (`"tidycreel_imputation_singular"`) — do not silently swallow or hard-abort.
- Provide a GLM fallback: if the GLMM is singular, fall back to `glm(family = MASS::negative.binomial(...))` or `glm(family = poisson)` and document the fallback in the warning message.
- Follow the `estimate_effort_aerial_glmm()` precedent: the function does not `stop()` on convergence warnings from lme4; it uses `suppressMessages()` in tests to prevent noise.
- In tests, use `suppressWarnings()` when fitting on intentionally sparse synthetic fixtures.

**Phase to address:** Camera imputation implementation phase. Also relevant: test design (do not write assertions that will fail on lme4 convergence noise).

---

### CAM-3: Returning Imputed Data That Breaks `add_counts()` Column Contract

**What goes wrong:** The imputation function returns a data frame with extra columns (e.g., model residuals, imputation flags) that `add_counts()` does not expect. Or it returns counts as `double` when `add_counts()` expects `integer`. Or the `camera_status` column is removed, breaking downstream filters in `est_effort_camera()`.

**Warning sign:** `est_effort_camera()` errors after consuming imputed data; integration test fails on column type mismatch.

**Prevention:**
- The imputation function should return a data frame with exactly the same schema as its input, with outage-period count values replaced. Add a boolean `imputed` flag column (documented in `@return`) but do not remove or rename any input column.
- Check existing `add_counts()` column validation logic before finalizing the return schema.
- Write an integration test: `impute_camera_counts() |> add_counts(design, .) |> est_effort_camera()` must complete without error.

**Phase to address:** Camera imputation implementation phase. Integration test is the acceptance criterion.

---

### CAM-4: Missingness Mechanism Ignored — Model Covariates Inadequate

**What goes wrong:** Camera outages are not random — they correlate with weather events, equipment failure patterns, or high-traffic periods. A model that uses only time-of-day and day-type will systematically mis-predict counts during the exact periods when outages are most likely. The resulting imputed values will be biased, but the bias will not be visible from model diagnostics alone.

**Warning sign:** No documentation of assumed missingness mechanism (MCAR vs. MAR vs. MNAR); no covariate for "neighboring camera operational status" or weather; imputation SE is not propagated to downstream effort estimate.

**Prevention:**
- Document the missingness assumption in `@details`: the function assumes missing-at-random (MAR) conditional on temporal covariates. This is the standard assumption of GLM/GLMM imputation.
- Recommend in documentation that users include weather or neighboring-camera covariates when available.
- The imputation function should propagate prediction SE (from `predict(..., se.fit = TRUE)`) so that downstream variance inflation can be quantified.
- This is a domain limitation, not a code bug — document it clearly rather than trying to solve it programmatically.

**Phase to address:** Camera imputation design phase (documentation and `@details` section). Raise as a CAUTION in the vignette.

---

## Feature Area 2: Camera Design Helper (creel_n_camera())

---

### CAM5: Duplicating creel_n_effort() Without a Principled Difference

**What goes wrong:** `creel_n_camera()` re-implements stratified sample-size estimation using the same Cochran (1977) formula as `creel_n_effort()`, with only minor surface differences. The result is two near-identical functions that diverge over time, creating maintenance debt. Users cannot tell when to use which one.

**Warning sign:** The implementation body of `creel_n_camera()` is copy-pasted from `creel_n_effort()` with two parameter names changed.

**Prevention:**
- Before implementing, precisely state what is statistically distinct about camera sampling (e.g., the estimand is detection probability or camera-days, not angler-days; the pilot variance comes from camera count data, not interview data).
- If the formula is identical, implement `creel_n_camera()` as a documented wrapper around `creel_n_effort()` with camera-domain defaults and a domain-appropriate `@description`. Export `creel_n_camera()` and keep `creel_n_effort()` unchanged.
- `@family "Planning & Sample Size"` must be consistent with the existing naming.

**Phase to address:** Camera design helper requirements phase. Resolve before writing implementation.

---

### CAM6: Input Validation Inconsistency with creel_n_effort()

**What goes wrong:** `creel_n_effort()` uses `checkmate::assert_numeric(..., names = "named")` for stratum vectors. If `creel_n_camera()` uses a different validation library or style (e.g., bare `if (!is.numeric(...)) stop(...)`), it introduces inconsistency that reviewers will flag in rOpenSci review.

**Warning sign:** New function uses `stop()` or `warning()` instead of `cli::cli_abort()` / `cli::cli_warn()`; input checks are structural `if` statements rather than `checkmate` assertions.

**Prevention:**
- Reuse the exact same `checkmate` assertion pattern as `creel_n_effort()` for all parallel parameters.
- Use `cli::cli_abort()` with a named condition class for validation errors.

**Phase to address:** Camera design helper implementation phase.

---

## Feature Area 3: Mark-Recapture Harvest Estimators

---

### MR-1: Choosing the Wrong Population Model (Closed vs. Open) for the Survey Window

**What goes wrong:** Petersen and Schnabel estimators assume a closed population — no immigration, emigration, births, or deaths between marking and recapture. In a creel survey context, anglers enter and leave the fishery continuously (open population). Applying a closed-population estimator to an open-population scenario produces biased harvest estimates. The Chapman-modified Petersen is appropriate for short single-period surveys only.

**Warning sign:** Function implements Petersen without a closure-period argument and without documenting the closed-population assumption; no guard or warning when the survey spans multiple weeks.

**Prevention:**
- Implement Petersen/Chapman as the entry point with explicit documentation that the closed-population assumption must hold over the survey period.
- For multi-period data, implement Schnabel (multiple-sample closed) separately.
- Jolly-Seber (open population) is a third, distinct function — do not route all three through a single function with a `method` argument unless the routing logic is thoroughly documented and tested.
- Include a `cli::cli_warn()` (not `cli::cli_abort()`) when the time span implied by the data exceeds a user-configurable `max_closure_days` threshold.

**Phase to address:** Mark-recapture requirements phase. The closed/open distinction must be resolved before any implementation.

---

### MR-2: Small-Sample Bias in the Petersen Estimator Not Documented or Corrected

**What goes wrong:** The naive Lincoln-Petersen estimator is biased high at small sample sizes. The Chapman modification (`(M+1)(n+1)/(m+1) - 1`) substantially corrects this bias. If the implementation defaults to the naive estimator without flagging small-sample risk, biologists will produce inflated harvest estimates when mark rates are low.

**Warning sign:** Function implements `N_hat = M * n / m` without bias correction; no check for `m == 0` (zero recaptures — estimator is undefined); no minimum-recapture warning.

**Prevention:**
- Default to the Chapman estimator. Document that it is used and why (bias correction at small `m`).
- Guard: if `m == 0`, `cli::cli_abort()` with class `"tidycreel_mr_zero_recaptures"` — the estimator is undefined.
- Guard: if `m < 7` (a common fisheries rule of thumb for minimum recaptures), `cli::cli_warn()` with class `"tidycreel_mr_small_recaptures"`.
- Return a `creel_estimates`-compatible object that includes `method = "mark_recapture_chapman"` so the method used is visible.

**Phase to address:** Mark-recapture implementation phase. Chapman default is a Day 1 decision.

---

### MR-3: Capture Heterogeneity Assumption Violated Without Detection

**What goes wrong:** All simple Petersen/Chapman/Schnabel estimators assume equal capture probability across all individuals in both the marking and recapture samples. In angler creel surveys, experienced anglers are more likely to be encountered repeatedly (behavioural heterogeneity). This violation causes underestimation of the true population size and therefore underestimation of harvest.

**Warning sign:** No mention of capture heterogeneity in `@details`; no `@references` to literature on trap response or heterogeneity effects; no diagnostic function provided.

**Prevention:**
- This is a domain limitation that cannot be fixed programmatically with a simple estimator — document it explicitly in `@details`.
- Cite Hansen & Van Kirk (2018) and the assessment by Matlock et al. (2023, ScienceDirect) on bias in closed-population estimators.
- Provide a `@seealso` reference to the `Rcapture` package (CRAN) for heterogeneity-corrected models.
- Add a quickcheck-style invariant: the Chapman estimator should produce `N_hat > 0` and `N_hat < Inf` for valid inputs — this is testable without any assumption about heterogeneity.

**Phase to address:** Mark-recapture design documentation phase.

---

### MR-4: Jolly-Seber Returns an Incompatible Object Structure

**What goes wrong:** Jolly-Seber produces per-period estimates (N_t, phi_t, B_t) — a time-series structure. The existing `creel_estimates` S3 class wraps a single-row tibble. If JS is forced into the same output contract, either the existing print method breaks (multi-row tibble with different columns) or a new S3 class is needed, which expands the API surface significantly.

**Warning sign:** `estimate_harvest_jolly_seber()` returns a data frame with period-indexed rows without a print method; or it returns a `creel_estimates` object with multi-row `estimates` tibble that breaks existing print snapshots.

**Prevention:**
- Do not force Jolly-Seber into the existing `creel_estimates` contract. Return a dedicated `creel_mr_estimates` S3 class (or a plain named list) with a documented `print.creel_mr_estimates()` method.
- Add a `format.creel_mr_estimates()` and `as.data.frame.creel_mr_estimates()` for downstream use.
- Alternatively: defer Jolly-Seber to a follow-on milestone and deliver only Petersen/Chapman and Schnabel in v1.6.0. This is the safer scope boundary.

**Phase to address:** Mark-recapture architecture phase. Resolve before writing any JS code.

---

### MR-5: FSA Dependency Creep

**What goes wrong:** The `FSA` package implements `mrClosed()` and `mrOpen()`. It is tempting to wrap FSA rather than implement the estimators directly, but FSA has its own dependency tree and its own S4-adjacent output classes. Wrapping FSA means the package's output structure is at the mercy of FSA's API stability.

**Warning sign:** `FSA` appears in `Imports` or `Suggests`; function return value is of class `"mrClosed"` rather than a native tidycreel type.

**Prevention:**
- Implement Petersen/Chapman and Schnabel directly — these are simple closed-form expressions (5-10 lines each). No external package is needed.
- Jolly-Seber is more complex; if it is in scope, evaluate FSA or `Rcapture` as `Suggests`-only tools referenced in `@seealso`, not wrapped by tidycreel functions.
- All return values must be native tidycreel S3 classes or plain data frames/lists with documented structure.

**Phase to address:** Mark-recapture requirements and architecture phases.

---

## Feature Area 4: Stratification Audit Tools

---

### SA-1: Post-Hoc Power as the Audit Criterion — Widely Considered Invalid

**What goes wrong:** The function computes observed power from a completed survey's results and uses it to recommend strata merging or elimination. Post-hoc power analysis is widely condemned in the statistical literature as circular and misleading: a non-significant test will always show low post-hoc power by construction, regardless of whether the strata are useful.

**Warning sign:** Function signature includes an effect size or test statistic as input and returns "power was X%, therefore drop this stratum"; the concept being computed is never contrasted with prospective power.

**Prevention:**
- The correct audit criterion is precision (CV) and variance contribution per stratum, not post-hoc power.
- Use coefficient of variation (CV) and stratum-level variance contribution from the `survey` package's design-based estimators as the primary audit metrics — this is what the existing `creel_n_effort()` and `power_creel()` framework already does prospectively.
- If de Kerckhove (2026) uses a specific metric, implement that metric exactly, with the formula in `@details` and the reference in `@references`. Do not substitute a simpler but statistically invalid proxy.
- Include a `cli::cli_warn()` if the user passes a completed-survey result as input (which suggests they may be computing post-hoc power).

**Phase to address:** Stratification audit requirements phase. This is a statistical design decision that must be settled before implementation.

---

### SA-2: Mixing Design-Based and Model-Based Variance in the Audit Comparison

**What goes wrong:** The stratification audit compares design-based CV estimates (from `survey::svymean()`) for one stratum structure against a model-based predicted CV for a collapsed structure. These are not directly comparable — the design-based estimate has finite-population correction; the model-based prediction does not. The comparison will favor collapsing strata in almost all cases, producing a recommendation that is an artifact of the comparison method rather than a genuine precision gain.

**Warning sign:** The audit function calls both `survey::svymean()` (design-based) and `predict(lm(...))` (model-based) and compares their SEs directly.

**Prevention:**
- Use design-based estimation throughout. Estimate CV under each candidate strata structure using the existing `survey` design objects, not model predictions.
- The `survey` package's `svyby()` function provides per-stratum estimates that can be compared directly.
- Document the comparison method in `@details` with a clear statement about which variance is being compared and why.

**Phase to address:** Stratification audit implementation phase.

---

### SA-3: Returning a Recommendation Without Uncertainty

**What goes wrong:** The function returns a binary "merge stratum A and B" recommendation based on point estimates of CV. Point estimates of CV are themselves uncertain — especially in small fisheries surveys. A deterministic recommendation without uncertainty bounds encourages mechanical application of the tool.

**Warning sign:** Return value is a character vector of "recommended" stratum structures with no SE on the CV estimates; function documentation says "the function will recommend..." rather than "the function reports...".

**Prevention:**
- Return CV estimates with their standard errors (bootstrap or Taylor linearisation, using the existing variance infrastructure in `survey_bridge.R`).
- Frame the output as informational: report the estimated CV and precision per stratum configuration; let the biologist make the final strata decision.
- Naming: prefer `audit_strata()` or `evaluate_strata()` over `optimize_strata()` — the latter implies algorithmic certainty the tool cannot provide.

**Phase to address:** Stratification audit design phase (naming and return contract).

---

### SA-4: Incompatibility with Existing `creel_design` Object Structure

**What goes wrong:** The stratification audit function takes a `creel_design` object and reconstructs the survey design with different strata. But `creel_design()` assumes strata are set at construction time and embedded in the calendar data frame. Re-stratifying post-hoc requires either reconstructing the `creel_design` from scratch (losing all attached data) or computing the collapsed design internally using `survey::postStratify()` (which changes variance estimates in a different way).

**Warning sign:** `audit_strata()` calls `creel_design()` internally with `strata = new_grouping` and loses the count and interview data that was attached via `add_counts()` and `add_interviews()`.

**Prevention:**
- The audit function should operate on the raw count and interview data extracted from the design object, not by reconstructing the design from scratch.
- Use `survey::svydesign()` directly on the extracted data with alternative strata columns to compute hypothetical precision — keep the original `creel_design` object untouched.
- Add an integration test: `audit_strata(design_with_counts_and_interviews)` must not modify `design`.

**Phase to address:** Stratification audit architecture phase.

---

## rOpenSci-Specific Pitfalls

---

### ROS-1: Experimental Functions Without Lifecycle Badges Submitted as Stable

**What goes wrong:** All four new features involve estimators from literature published 2020-2026 with limited empirical validation in operational creel survey contexts. If these functions are submitted to rOpenSci without `experimental` badges, reviewers will expect stability guarantees that cannot be made.

**Warning sign:** No `lifecycle::badge("experimental")` in the `@description` of any new function.

**Prevention:**
- Tag every new function with `r lifecycle::badge("experimental")` in the roxygen `@description` block — the existing pattern used by `estimate_effort_aerial_glmm()`.
- The rOpenSci devguide states: "If you use lifecycle badges, submission should happen when the package is Stable." This means new experimental functions do not block rOpenSci submission as long as they are clearly tagged.

**Phase to address:** Every implementation phase. Badge is part of the roxygen template.

---

### ROS-2: Heavy Dependencies Violate rOpenSci Dependency Minimisation Policy

**What goes wrong:** rOpenSci reviewers check that dependencies are "justified and minimal." Adding packages with large dependency trees (e.g., `MASS`, `Matrix` as hard `Imports` rather than leveraging what `lme4` already brings transitively through `Suggests`) is flagged in review.

**Warning sign:** `tools::package_dependencies("tidycreel", recursive = TRUE)` grows significantly after new features are added.

**Prevention:**
- For imputation: `MASS` is a recommended package (ships with R) — `MASS::glm.nb()` is available without a DESCRIPTION declaration. Verify this with `tools::package_dependencies()` before adding `MASS` to `Imports`.
- For mark-recapture: all estimators are closed-form — `stats` (base R) is sufficient. No new `Imports` entry required.
- For stratification audit: `survey` is already in `Imports` — use `survey::svyby()` and `survey::svydesign()` directly.

**Phase to address:** Requirements phase. Do a dependency audit before any code is written.

---

### ROS-3: Stochastic Tests Breaking CI on CRAN Platforms

**What goes wrong:** Tests that fit GLMMs (imputation) or bootstrap CIs (mark-recapture) are stochastic — they can produce convergence warnings or slightly different numeric results across platforms (Windows vs. Linux vs. macOS) due to floating-point differences in the LAPACK/BLAS implementations. CRAN runs `R CMD check --as-cran` on multiple platforms; a test that passes locally may fail on CRAN's Windows build.

**Warning sign:** Test uses `expect_equal(result$estimate, 123.4, tolerance = 1e-6)` on GLMM output; test fails on rhub Windows check.

**Prevention:**
- For GLMM-based tests: use structural assertions (`expect_true(is.finite(x))`, `expect_gt(x, 0)`) rather than numeric equality on fitted values.
- Wrap GLMM-fitting tests in `suppressWarnings()` for convergence messages — the existing pattern in `test-estimate-effort-aerial-glmm.R`.
- Add `skip_on_cran()` to tests that fit full GLMM models (bootstrap or convergence-sensitive); use a faster synthetic fixture for the CI-safe test.
- Use `set.seed()` before any stochastic computation in tests.

**Phase to address:** Every implementation phase. Test design discipline.

---

### ROS-4: `\dontrun{}` on All New Examples Prevents `R CMD check` Coverage

**What goes wrong:** The codebase uses `\dontrun{}` as the default wrapper for examples that require a `creel_design` object setup. As a result, example code is never run by `R CMD check` and errors in example code are not caught until a user runs them manually. For CRAN submission and rOpenSci review, this is acceptable only for examples with genuine side effects (file I/O, database). It is not acceptable as a convenience measure for slow setup code.

**Warning sign:** Every new function's `@examples` block is wrapped in `\dontrun{}` with no `\donttest{}` alternative.

**Prevention:**
- Use `\donttest{}` (not `\dontrun{}`) for examples that are correct but slow (GLMM fitting, bootstrap).
- Provide a minimal, fast example outside `\donttest{}` that demonstrates the function's interface with a small synthetic dataset. This is especially important for the mark-recapture estimators, which have closed-form implementations and can run in milliseconds.
- The camera imputation and stratification audit functions can use `\donttest{}` for the full workflow but must have at least one runnable example.

**Phase to address:** Every implementation phase. Example structure is part of the function documentation contract.

---

## Phase-Specific Warning Matrix

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Camera imputation design | CAM-1 (multiple imputation over-engineering) | Point-predict from GLM/GLMM, return same schema as input |
| Camera imputation implementation | CAM-2 (singular/convergence crash) | `isSingular()` check + `cli_warn()` + GLM fallback |
| Camera imputation integration | CAM-3 (schema mismatch breaks `add_counts()`) | Integration test: impute → add_counts → est_effort_camera |
| Camera design helper requirements | CAM-5 (duplicate of creel_n_effort()) | Identify the statistically distinct parameter; wrapper if formulae are identical |
| Mark-recapture requirements | MR-1 (wrong population model) | Settle closed vs. open before implementation; separate functions |
| Mark-recapture implementation | MR-2 (Petersen bias) | Default Chapman; guard m==0; warn m<7 |
| Mark-recapture implementation | MR-5 (FSA dependency) | Implement closed-form directly; FSA in @seealso only |
| Mark-recapture architecture | MR-4 (JS object contract) | Separate S3 class or defer JS to next milestone |
| Stratification audit requirements | SA-1 (post-hoc power fallacy) | Use CV/variance contribution, not post-hoc power |
| Stratification audit design | SA-3 (deterministic recommendation) | Return CV ± SE; frame as informational audit, not optimizer |
| Stratification audit architecture | SA-4 (design reconstruction) | Extract data from design; use svydesign() internally; never mutate input |
| All features | XC-2 (rcmdcheck regression) | rcmdcheck after every function addition |
| All features | ROS-3 (stochastic CI failures) | structural assertions + skip_on_cran() for GLMM tests |
| All features | ROS-4 (dontrun everywhere) | \donttest{} for slow; runnable fast example required |

---

## Sources

- rOpenSci Packages Development Guide: [https://devguide.ropensci.org/pkg_building.html](https://devguide.ropensci.org/pkg_building.html)
- lme4 Convergence Documentation: [https://rdrr.io/cran/lme4/man/convergence.html](https://rdrr.io/cran/lme4/man/convergence.html)
- lme4 isSingular: [https://rdrr.io/cran/lme4/man/isSingular.html](https://rdrr.io/cran/lme4/man/isSingular.html)
- lme4 GLMM FAQ (Bolker): [https://bbolker.github.io/mixedmodels-misc/glmmFAQ.html](https://bbolker.github.io/mixedmodels-misc/glmmFAQ.html)
- Afrifa-Yamoah (2020) Camera Outage Imputation: [https://academic.oup.com/icesjms/article/77/7-8/2984/5998351](https://academic.oup.com/icesjms/article/77/7-8/2984/5998351)
- Chapman/Petersen bias assessment: [https://www.sciencedirect.com/science/article/abs/pii/S0165783623001492](https://www.sciencedirect.com/science/article/abs/pii/S0165783623001492)
- FSA mrClosed: [https://rdrr.io/cran/FSA/man/mrClosed.html](https://rdrr.io/cran/FSA/man/mrClosed.html)
- FSA mrOpen / Jolly-Seber: [https://fishr-core-team.github.io/FSA/reference/mrOpen.html](https://fishr-core-team.github.io/FSA/reference/mrOpen.html)
- R Packages (2e) — Dependencies in Practice: [https://r-pkgs.org/dependencies-in-practice.html](https://r-pkgs.org/dependencies-in-practice.html)
- CRAN Cookbook — General Issues: [http://contributor.r-project.org/cran-cookbook/general_issues.html](http://contributor.r-project.org/cran-cookbook/general_issues.html)
- testthat skip_on_cran: [https://testthat.r-lib.org/reference/skip.html](https://testthat.r-lib.org/reference/skip.html)
- R CMD check examples timing: [https://r-pkgs.org/R-CMD-check.html](https://r-pkgs.org/R-CMD-check.html)
- lifecycle stages: [https://lifecycle.r-lib.org/articles/stages.html](https://lifecycle.r-lib.org/articles/stages.html)
- rOpenSci Discuss — Suggests for single-function deps: [https://discuss.ropensci.org/t/putting-dependencies-used-by-a-single-function-as-suggests/2823](https://discuss.ropensci.org/t/putting-dependencies-used-by-a-single-function-as-suggests/2823)
