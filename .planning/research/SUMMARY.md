# Research Summary: tidycreel v1.6.0 — Analytical Extensions II

**Synthesized:** 2026-05-02
**Sources:** STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md
**Milestone scope:** Camera imputation, camera design helper, mark-recapture harvest, stratification audit

---

## Stack Additions

**Two new Suggests entries only. Imports is unchanged.**

| Package | Version | Role | Guard pattern |
|---------|---------|------|---------------|
| `glmmTMB` | `>= 1.1.0` | ZIP/ZINB GLMM tier for camera imputation | `rlang::check_installed("glmmTMB")` |
| `FSA` | `>= 0.10.0` | Jolly-Seber open-population mark-recapture only | `rlang::check_installed("FSA")` |

**Rejected:** `pscl` (no random effects), `Rcapture` (stagnant), `RMark` (external binary), `FSA` in Imports (72-package transitive tree violates lean-Imports policy).

**Noted:** `MASS::glm.nb()` is available transitively via `survey` — do NOT add it explicitly to Imports.

---

## Feature Landscape

### Complexity ranking (lowest to highest)

| Rank | Feature | Deps | Risk |
|------|---------|------|------|
| 1 | `creel_n_camera()` | None | LOW — identical formula to `creel_n_effort()`, pure arithmetic |
| 2 | `audit_strata()` | None | LOW — algebraic inverse of existing `creel_n_effort()` / `cv_from_n()` |
| 3 | `estimate_angler_n()` | FSA (Suggests, JS only) | MEDIUM — closed-population built directly; delta-method harvest helper is new |
| 4 | `impute_camera_counts()` | glmmTMB (Suggests) | HIGH — new modelling paradigm (GLMM imputation); prototype before finalising API |

### Table stakes per feature

| Feature | Table stakes |
|---------|-------------|
| Camera imputation | Status-column-driven, day-type covariate, compatible output for `est_effort_camera()`, warn when > 50% missing |
| Camera design helper | Cochran eq. 5.25 CV formula, per-stratum + total output, Feltz-Middaugh minimum-day warning |
| Mark-recapture | Chapman correction as default, `creel_estimates` return type, input guards (m ≤ min(M,n)), `conf_level` arg |
| Stratification audit | Per-stratum RSE + meets-target flag, collapse simulation, consistent `N_h`/`s2_h` input shape |

---

## Architecture

**All four features are additive. Zero breaking changes. Zero API modifications.**

### New functions and classes

| Function | File | New class |
|----------|------|-----------|
| `impute_camera_counts()` | `R/creel-impute-camera.R` | `creel_imputed_counts` (print only) |
| `creel_n_camera()` | `R/power-sample-size.R` | None — extends existing file |
| `estimate_angler_n()` | `R/creel-estimates-mark-recapture.R` | Returns existing `creel_estimates` |
| `estimate_mr_harvest()` | `R/creel-estimates-mark-recapture.R` | Returns existing `creel_estimates` |
| `audit_strata()` | `R/design-validator.R` (or new file) | `creel_strata_audit` |
| `simulate_strata_collapse()` | same | None — returns tibble |
| `reallocate_strata()` | same | None — returns named vector |

### Integration seams

- **Camera imputation:** sits *before* `add_counts()` — `impute_camera_counts(raw_counts)` → `add_counts(design, imputed)` → `est_effort_camera()`
- **Camera design helper:** parallel to `creel_n_effort()` in `power-sample-size.R`; gains a `mode = "camera_n"` branch in `power_creel()`
- **Mark-recapture:** `creel_estimates` return type means `compare_designs()`, `autoplot()`, `write_estimates()` all work automatically
- **Stratification audit:** wraps and inverts `creel_n_effort()` + `cv_from_n()`; `audit_strata()` output feeds `compare_designs()`

### Suggested build order

1. **`creel_n_camera()`** — simplest, zero deps, establishes camera vocabulary
2. **`impute_camera_counts()`** — GLM tier first (no new deps), GLMM tier second; completes camera workflow
3. **`estimate_angler_n()` + `estimate_mr_harvest()`** — Petersen/Chapman/Schnabel built direct; JS via FSA guard
4. **`audit_strata()` + helpers** — most integration-aware; benefits from test infrastructure of earlier phases

No phase has a hard dependency on any other. Order is complexity escalation, not technical blocking.

---

## Top Pitfalls

1. **lme4 GLMM instability** — `glmer.nb()` is documented as "somewhat unstable". Every new GLMM function needs an `isSingular()` check and a GLM fallback with `cli_warn()`. Precedent: `creel-estimates-aerial-glmm.R`.

2. **Camera imputation output schema** — `impute_camera_counts()` must return a data frame with the *identical schema* as its input so it drops cleanly into `add_counts()`. A list of M imputed datasets is wrong for the table-stakes path; single pooled/mean imputed dataset is the default.

3. **Closed vs. open population for mark-recapture** — Petersen/Chapman assume closure within the sampling window. Jolly-Seber returns a per-period time series incompatible with the existing `creel_estimates` S3 contract. Resolve scope (include JS or defer) before any implementation.

4. **Post-hoc power is the wrong stratification metric** — the correct metric is per-stratum CV and variance contribution. `survey::svyby()` on the existing design object gives this directly. Reject any design that computes "power" retrospectively.

5. **CRAN hygiene on stochastic tests** — GLMM and bootstrap functions need `skip_on_cran()` on stochastic tests and `\donttest{}` (not `\dontrun{}`) on slow examples. Template: `test-estimate-effort-aerial-glmm.R`.

---

## Open Questions (must resolve before implementation)

| # | Question | Affects |
|---|----------|---------|
| OQ-1 | Is Jolly-Seber in scope for v1.6.0 or deferred? JS output contract is incompatible with `creel_estimates`; needs a new class or must wait. | Phase 3 scope |
| OQ-2 | `audit_strata()` — target metric is CV (confirmed) but does it also audit CPUE precision or effort only? `validate_design(type=)` pattern suggests a `type` argument. | Phase 4 API |
| OQ-3 | Camera imputation — which paper is the primary reference? GLM tier (Hartill 2016, simpler, no new deps) or GLMM tier (Afrifa-Yamoah 2020, better fit, requires `glmmTMB`)? Recommend: GLM default, GLMM opt-in. | Phase 2 API |
| OQ-4 | de Kerckhove 2026 chapter is paywalled. Stratification audit formula uses standard Cochran/Neyman algebra regardless, but empirical thresholds for strata reduction should be verified against the source before shipping. | Phase 4 implementation |
| OQ-5 | `creel_n_camera()` — does it live as a standalone function or as `mode = "camera_n"` inside `power_creel()`? Standalone is simpler to ship; integration with `power_creel()` is the cleaner long-term API. | Phase 1 API |
