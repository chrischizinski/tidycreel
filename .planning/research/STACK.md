# Technology Stack: tidycreel v1.6.0 New Features

**Project:** tidycreel
**Researched:** 2026-05-02
**Scope:** Four new analytical capabilities only — existing stack not re-evaluated
**Overall confidence:** HIGH (CRAN versions verified, rOpenSci policy confirmed, dependency trees checked)

---

## Existing Imports (Do Not Change)

The following are confirmed in `DESCRIPTION` and must not be modified for v1.6.0:

```
checkmate, cli, dplyr, ggplot2, lifecycle, rlang, stats, survey, tibble, tidyselect
```

`lme4` is currently in **Suggests**. This matters for Feature 1 below.

---

## Feature 1: Camera Missing Data Imputation

**Goal:** Fill camera outages with predicted angler counts using GLMM/GLM (Afrifa-Yamoah 2020, Hartill 2016).

### Statistical Model

Afrifa-Yamoah 2020 (ICES J. Mar. Sci.) evaluated nine model families for imputing camera count outages. Zero-inflated Poisson (ZIP) and zero-inflated negative binomial (ZINB) mixed models consistently ranked top-3 with narrowest confidence intervals. Hartill 2016 (*Fish. Res.* 183:488-497) used GLM (no random effects) to impute from neighbouring camera ramps.

Two model tiers are needed:
1. **GLM tier (Hartill):** `MASS::glm.nb()` or `stats::glm(family=poisson)` — no random effects, fits single-camera GLM with temporal covariates. `MASS` is already a transitive dependency via `survey` and is a base-adjacent package.
2. **GLMM tier (Afrifa-Yamoah):** Zero-inflated GLMM with random day/site effects. This is the **key dependency decision**.

### The Zero-Inflated GLMM Decision: `lme4` vs `glmmTMB`

**Option A — Stay with `lme4` (already in Suggests):**
- `lme4::glmer.nb()` handles negative binomial GLMMs. No ZIP support.
- Pattern already established in `creel-estimates-aerial-glmm.R`.
- `lme4` is already in Suggests; no new dependency.
- Limitation: no zero-inflation component. For ZIP/ZINB mixed models, lme4 cannot fit them natively.

**Option B — Add `glmmTMB` (new Suggests):**
- `glmmTMB` v1.1.14 (2026-01-15, CRAN). Supports ZIP, ZINB, and NB mixed models with `ziformula` argument.
- Imports: `TMB (>= 1.9.0)`, `lme4 (>= 1.1-18.9000)`, `Matrix`, `nlme`, `numDeriv`, `mgcv`, `reformulas`, `pbkrtest`, `sandwich`.
- TMB dependency requires compilation from source on install; adds meaningful install overhead.
- Speed advantage over `lme4` for NB models (benchmarked ~29x faster for NB, R Journal 2017).
- Afrifa-Yamoah 2020 specifically demonstrates ZIP outperforms plain NB for camera outage patterns; ZINB GLMM is the best-performing model class.

**Recommendation: Add `glmmTMB` to Suggests.**

Rationale: Afrifa-Yamoah 2020 establishes ZIP/ZINB as superior models for camera outages; `lme4` cannot fit them. The Hartill 2016 GLM tier can be served by `MASS::glm.nb()` (already transitive) or `stats::glm()`. `glmmTMB` is the only pure-R CRAN package that handles ZIP + random effects in a single call, uses familiar `lme4`-style formula syntax, and is actively maintained (v1.1.14 as of Jan 2026). Adding it to Suggests (not Imports) keeps it optional — callers who only need the GLM tier (Hartill) never install it.

TMB compilation overhead is a real cost but acceptable in Suggests, where the user explicitly opts in.

### Dependency Assignment

| Package | Version Floor | In Suggests | Rationale |
|---------|--------------|-------------|-----------|
| `glmmTMB` | `>= 1.1.0` | NEW — add to Suggests | ZIP/ZINB mixed model tier (Afrifa-Yamoah 2020) |
| `MASS` | none | No change (transitive) | `glm.nb()` for GLM tier (Hartill 2016) — already available as `survey` transitive; do NOT add explicitly to Imports |
| `lme4` | `>= 1.1-27` | No change (already Suggests) | Keep for aerial GLMM continuity; used if user does not have glmmTMB |

**Dispatch pattern:** The imputation functions should check `rlang::check_installed("glmmTMB", reason="for zero-inflated mixed models")` and fall back to `lme4::glmer.nb()` if glmmTMB is absent, with a `cli::cli_warn()` noting that the ZIP component is unavailable. This matches the existing `rlang::check_installed()` guard pattern already used throughout the package.

### What NOT to Add

- **`pscl`** — `zeroinfl()` fits ZIP/ZINB but GLM only (no random effects). Afrifa-Yamoah 2020 finds the random effects structure essential for temporal autocorrelation in outage patterns. `pscl` solves the wrong problem for imputation. Its last release was 2024-01-31 (v1.5.9) with no updates since; `glmmTMB` supersedes it for the mixed model use case.
- **`VGAM`** — `vgam()` with zero-inflated families works but lacks mixed effects. Not needed.
- **`unmarked`** — occupancy/N-mixture models, wrong domain entirely.

---

## Feature 2: Camera Design Helper (`creel_n_camera()`)

**Goal:** A `creel_n_camera()`-style sample-size function for camera-based surveys (Feltz & Middaugh 2025, *NAJFM* 45(2):322).

### Statistical Context

Feltz & Middaugh 2025 evaluated low-frequency time-lapse camera sampling for angler effort estimation. The design guidance is about **how many camera-days** (or sampling intervals) are required to achieve a target CV. This is structurally identical to the existing `creel_n_effort()` function (McCormick & Quist 2017, Cochran 1977 equation 5.25), which is already implemented in `power-sample-size.R`.

The formula is the same Cochran (1977) stratified proportional allocation equation. The inputs differ: instead of interview-day variance, the inputs are camera-count variance and the calibration ratio variance from the pilot.

### Dependency Assignment

**No new packages needed.** `creel_n_camera()` should be implemented as a new function in `power-sample-size.R` using the same `stats::` and `checkmate::` stack as `creel_n_effort()`. The formula is pure arithmetic; no modelling packages are required.

The function mirrors `creel_n_effort()` structurally — same Cochran CV target formula, same proportional allocation, same `checkmate` input guards, same output format (named integer vector with per-stratum counts + "total").

---

## Feature 3: Mark-Recapture Harvest Estimators

**Goal:** Petersen/Schnabel/Jolly-Seber estimators applied to anglers (Hansen & Van Kirk 2018, *NAJFM* 38:898-908).

### The FSA Package Assessment

`FSA` v0.10.1 (2026-01-07, CRAN) provides:
- `mrClosed()`: Petersen, Chapman, Ricker, Bailey (single census), Schnabel, Schumacher-Eschmeyer (multi-census)
- `mrOpen()`: Jolly-Seber open-population
- `capHistSum()`: summarises individual capture history format → input for `mrClosed`/`mrOpen`

These are exactly the estimator families in Hansen & Van Kirk 2018.

**FSA dependency concern — Imports weight:**
FSA imports `car`, `dunn.test`, `FlexParamCurve`, `lmtest`, `plotrix`, `purrr`, `withr`. The total transitive dependency tree is ~72 packages. This is a heavy footprint. `car` alone brings in `carData`, `abind`, `pbkrtest`, `quantreg`, and others. This violates the rOpenSci lean-dependency philosophy and was a documented motivation for dropping `scales` from tidycreel in M022/M023.

**The rOpenSci policy (devguide.ropensci.org):** "If a heavy dependency is primarily used for easier-to-interpret function names and syntax compared to base R solutions, consider wrapping the base R approach." The corollary: if an external package delivers essential statistical logic not available in base R, wrapping it is correct — but FSA's transitive footprint is unusually heavy.

**Decision matrix:**

| Estimator | Formula complexity | Lines to implement directly | Use FSA? |
|-----------|-------------------|----------------------------|----------|
| Petersen (N = Mn/m) | 1 line | ~20 with CI | No — formula trivial |
| Chapman correction | 1 line | ~25 with CI | No — formula trivial |
| Schnabel (multi-census sum formula) | 3-5 lines | ~40 with CI | No — straightforward |
| Schumacher-Eschmeyer | weighted regression | ~50 with CI | Borderline |
| Jolly-Seber (open pop) | matrix algebra | ~200+ with survival | Yes — use FSA |

**Recommendation: Build closed-population estimators directly; use FSA for Jolly-Seber only.**

The Petersen, Chapman, Schnabel, and Schumacher-Eschmeyer formulas are explicitly documented in Pollock et al. (1994) and Hansen & Van Kirk 2018. Implementing them directly in ~100-150 lines of base R avoids the 72-package FSA transitive dependency. Output can be a `creel_estimates` tibble in standard package format.

For open-population Jolly-Seber (if included in v1.6.0 scope), use `FSA::mrOpen()` guarded by `rlang::check_installed("FSA")` in Suggests. Open-population JS requires per-occasion survival + recruitment estimation — non-trivial to reimplement correctly.

**Hansen & Van Kirk 2018 is Mode 1 (angler effort replacement):** The estimator is a closed-population Chapman applied to anglers (mark at access point, re-sight same visit). This is Petersen/Chapman only — the simplest case. Build this directly without FSA.

### Dependency Assignment

| Package | Version Floor | Assignment | Rationale |
|---------|--------------|------------|-----------|
| None (build direct) | — | No new dep | Petersen/Chapman/Schnabel in base R + stats:: |
| `FSA` | `>= 0.10.0` | Suggests (optional) | Jolly-Seber open-pop only, guarded by check_installed() |

**If FSA is added to Suggests:** Guard with `rlang::check_installed("FSA", reason = "for open-population Jolly-Seber mark-recapture")`. The 72-package transitive tree only materialises when the user explicitly installs it.

**Do not add FSA to Imports.** The transitive footprint is inconsistent with the lean-Imports policy demonstrated across M022-M024.

### What NOT to Add

- **`Rcapture`** — Loglinear models for capture-recapture, last substantive update 2022. Documentation states "since version 1.2-0, no new features added to open populations." Not the right tool for the Hansen & Van Kirk Mode 1 (closed-population angler effort) use case.
- **`RMark`** — Wraps Program MARK (external FORTRAN binary, Windows-centric). Unacceptable as a package dependency; macOS/Linux users cannot use it without wine/Docker.
- **`marked`** — CJS survival models. Not needed for Hansen & Van Kirk 2018 which requires only closed-population Petersen/Chapman.

---

## Feature 4: Stratification Audit

**Goal:** Power-driven design reduction and strata re-evaluation tools (de Kerckhove 2026).

### Statistical Context

Stratification audit evaluates whether the current strata definitions are optimal given the observed data variance. This involves:
1. Computing within-stratum variance and between-stratum variance from existing creel design data
2. Assessing whether collapsing or splitting strata changes the target CV materially
3. Comparing achieved CV against a target (same CV framework as `creel_n_effort()`)

The Neyman optimal allocation formula (Cochran 1977 eq. 5.25 variant) and the coefficient of variation decomposition are already present in `power-sample-size.R`. Stratification audit is a design-analysis complement to sample-size planning.

### Dependency Assessment

**No new packages needed.** The stratification audit uses:
- `stats::` — variance, weighted means (already in Imports)
- `survey::svyby()` with existing survey design objects — already in Imports
- `dplyr::` — stratum summaries (already in Imports)
- `tibble::` — output format (already in Imports)

The `survey` package's `svyby()` with `svymean()` or `svytotal()` already computes per-stratum variance estimates from an existing `creel_design` object. A stratification audit function reads those variances, computes the Neyman optimal allocation under alternative stratum definitions, and returns a comparison tibble.

No new modelling packages are required. The complexity is in the combinatorial logic (evaluating stratum merge/split candidates) and the output formatting.

---

## Summary: What Actually Changes in DESCRIPTION

### New Suggests (add)

```
glmmTMB (>= 1.1.0)
FSA (>= 0.10.0)
```

Both are guarded by `rlang::check_installed()` at call sites. Both are optional — the package's core estimation, design, and planning surface works without them.

### No Changes to Imports

Features 2, 3 (closed-population only), and 4 require no new Imports. Feature 1 uses `MASS::glm.nb()` for the GLM tier — `MASS` is a transitive dependency of `survey` and must NOT be added to Imports explicitly (that would make a transitive dependency explicit without adding value).

### Unchanged Suggests (already present, relevant to new features)

```
lme4 (>= 1.1-27)   — fallback for GLMM tier when glmmTMB absent
```

---

## Alternatives Considered and Rejected

| Category | Considered | Rejected Because |
|----------|------------|-----------------|
| Zero-inflated GLM | `pscl::zeroinfl()` | No random effects; Afrifa-Yamoah 2020 shows mixed model structure essential for temporal camera outage patterns |
| Zero-inflated GLMM | `lme4` alone | No ZIP family support; NB only via `glmer.nb()`; cannot implement Afrifa-Yamoah 2020 top model |
| Mark-recapture suite | `FSA` in Imports | 72-package transitive dependency tree violates lean-Imports policy; closed-population formulas are trivial to build directly |
| Mark-recapture suite | `Rcapture` | Stagnant (last open-pop feature: v1.2-0, circa 2010); not suited for Mode 1 angler use case |
| Mark-recapture suite | `RMark` | External FORTRAN binary (Program MARK); macOS/Linux deployment requires wine/Docker; unacceptable |
| Camera design | `pwr`, `pwrss` | Generic power packages; do not implement the camera-specific CV formula from Feltz & Middaugh 2025; Cochran eq. 5.25 is already in `creel_n_effort()` |
| Zero-inflated GLMM | `VGAM` | No mixed effects support; heavy transitive footprint; `glmmTMB` is superior in every dimension |

---

## Integration Notes for Implementation

### Feature 1 (Camera Imputation) — `glmmTMB` guard pattern

```r
# In new R/creel-impute-camera.R:
impute_camera_counts <- function(design, method = c("glmm", "glm"), ...) {
  method <- match.arg(method)
  if (method == "glmm") {
    rlang::check_installed("glmmTMB",
      reason = "for zero-inflated GLMM camera imputation (Afrifa-Yamoah 2020)"
    )
    # glmmTMB::glmmTMB(count ~ covariates + (1|day), ziformula = ~1,
    #                  family = glmmTMB::nbinom2(), data = ...)
  } else {
    # MASS::glm.nb() via stats-adjacent path (Hartill 2016)
    MASS::glm.nb(count ~ covariates, data = ...)
  }
}
```

### Feature 3 (Mark-Recapture) — Build pattern for Chapman

```r
# In new R/creel-estimates-mark-recapture.R:
estimate_mark_recapture <- function(M, n, m,
                                    method = c("chapman", "petersen"),
                                    conf_level = 0.95) {
  # Chapman: N_hat = ((M+1)*(n+1))/(m+1) - 1
  # Variance: (M+1)*(n+1)*(M-m)*(n-m) / ((m+1)^2*(m+2))
  # CI: Poisson (small m) or normal approximation
  # Returns creel_estimates tibble
}
```

### Feature 3 (Jolly-Seber open-pop) — FSA guard pattern

```r
estimate_jolly_seber <- function(ch, ...) {
  rlang::check_installed("FSA", reason = "for Jolly-Seber open-population mark-recapture")
  ch_summed <- FSA::capHistSum(ch)
  FSA::mrOpen(ch_summed, ...)
}
```

---

## Package Versions (Verified 2026-05-02)

| Package | CRAN Version | Date | Source |
|---------|-------------|------|--------|
| `glmmTMB` | 1.1.14 | 2026-01-15 | cran.r-project.org/web/packages/glmmTMB |
| `FSA` | 0.10.1 | 2026-01-07 | cran.r-project.org/web/packages/FSA |
| `pscl` | 1.5.9 | 2024-01-31 | cran.r-project.org/web/packages/pscl (rejected) |
| `lme4` | 2.0.1 | installed | Confirmed locally |
| `MASS` | 7.3.65 | installed | Confirmed locally (transitive, do not declare) |

---

## Sources

- Afrifa-Yamoah et al. 2020: https://doi.org/10.1093/icesjms/fsaa180
- Hartill et al. 2016: *Fish. Res.* 183:488-497 (doi via ResearchGate)
- Feltz & Middaugh 2025: https://academic.oup.com/najfm/article-abstract/45/2/322/8128941
- Hansen & Van Kirk 2018: https://onlinelibrary.wiley.com/doi/abs/10.1002/nafm.10038
- FSA CRAN page: https://cran.r-project.org/web/packages/FSA/index.html
- glmmTMB CRAN page: https://cran.r-project.org/web/packages/glmmTMB/index.html
- pscl CRAN page: https://cran.r-project.org/web/packages/pscl/index.html
- rOpenSci dependency guide: https://devguide.ropensci.org/pkg_building.html
- glmmTMB R Journal paper (2017): https://journal.r-project.org/archive/2017/RJ-2017-066/RJ-2017-066.pdf
- FSA mrClosed documentation: https://rdrr.io/cran/FSA/man/mrClosed.html
- Rcapture status: https://cran.r-project.org/web/packages/Rcapture/Rcapture.pdf
