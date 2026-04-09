# Phase 64: GLMM Aerial Estimator - Research

**Researched:** 2026-04-05
**Domain:** R package development — lme4 GLMM, delta method, aerial creel estimation
**Confidence:** HIGH (implementation verified locally; lme4 API tested against installed version 1.1.38)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Model specification**
- Default formula: `count ~ poly(hour, 2) + (1|date)` (Askey 2018 quadratic temporal model with day-level random intercept)
- User can override with a custom lme4 formula via a `formula` argument (optional; default is NULL → uses Askey formula)
- GLM family: user-selectable via a `family` argument; default is negative binomial (`lme4::glmer.nb()`); Poisson and other families supported
- Time-of-flight column: user-named column in count data, passed via a `time_col` argument (tidyselect pattern, consistent with `count_time_col` in `estimate_effort()`)

**Variance / CI method**
- Default: parametric delta method (propagate fixed-effect covariance from lme4 to derived total effort)
- Optional bootstrap: `boot = TRUE` + `nboot = 500` (default) runs `lme4::bootMer()` for bootstrap CIs; user can override `nboot`
- `creel_estimates` column mapping: `se` = delta method (or bootstrap) SE, `se_between` = fixed-effect SE component, `se_within` = NA (no Rasmussen decomposition for GLMM)
- Emit `cli_inform()` before bootstrap runs ("Running {nboot} bootstrap replicates via lme4::bootMer...") — suppressable via `suppressMessages()`

**Input data contract**
- Entry point: `estimate_effort_aerial_glmm(design, time_col, ...)` — same `creel_design` object as all other estimators; count data (including the time-of-flight column) lives in `design$counts` after `add_counts()` is called
- Single count column only — no section-grouped GLMM in this phase
- Strict `design_type` validation: `cli_abort()` if `design$design_type != "aerial"`, naming the found type and pointing to `estimate_effort()` for other survey types
- `lme4` not-installed guard: `rlang::check_installed("lme4")` at the top of the function (consistent with `knitr`/`writexl`/`readxl` pattern)

**Vignette structure**
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

### Deferred Ideas (OUT OF SCOPE)

- **Section-level GLMM**: Fit separate GLMMs per section and return section-level `creel_estimates`. Natural extension but each section needs sufficient data for a stable GLMM fit; belongs in its own phase.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GLMM-01 | User can estimate aerial effort using `estimate_effort_aerial_glmm()` when flights are non-random in timing (Askey 2018 GLMM approach, lme4) | lme4::glmer.nb() + predict() + delta method SE fully verified |
| GLMM-02 | GLMM estimator returns a `creel_estimates` object compatible with all downstream estimators | `new_creel_estimates()` constructor pattern confirmed; column contract matches existing aerial estimator |
| GLMM-03 | User receives a clear `cli_abort()` error if `lme4` is not installed | `rlang::check_installed()` pattern already in use for knitr/writexl/readxl |
| GLMM-04 | User can read a vignette explaining when to use GLMM vs. simple aerial estimator, with a worked example and decision guide | `aerial-surveys.Rmd` structural template confirmed; pkgdown "Survey Types" section identified |
</phase_requirements>

---

## Summary

Phase 64 adds `estimate_effort_aerial_glmm()` — a GLMM-based aerial effort estimator that corrects for non-random flight timing bias. The core methodology follows Askey (2018): fit a negative binomial GLMM with a quadratic hour effect and day-level random intercept, then integrate predicted counts across the open-water day to derive total effort. The function takes the same `creel_design` input and returns the same `creel_estimates` output as the existing `estimate_effort()` aerial path, making it a drop-in companion rather than a replacement.

The implementation has three non-trivial pieces: (1) fitting the GLMM with `lme4::glmer.nb()` using the time-of-flight column from `design$counts`, (2) computing the effort integral and its SE via either the parametric delta method (default) or `lme4::bootMer()` (optional), and (3) assembling the result into a `creel_estimates` object with the standard column contract. The delta method derivation has been verified locally: the gradient of the sum of predicted response-scale values with respect to the fixed-effect vector multiplied through the fixed-effect covariance matrix yields a valid SE. Bootstrap via `bootMer(type="parametric", use.u=FALSE)` is the standard lme4 approach and also verified.

The companion vignette (`vignettes/aerial-glmm.Rmd`) follows the `aerial-surveys.Rmd` structural template. A new `example_aerial_glmm_counts` dataset provides multiple overflights per day across multiple days, enabling the GLMM to estimate the diurnal count curve — unlike `example_aerial_counts`, which has one flight per day and cannot fit the temporal model.

**Primary recommendation:** Implement in two waves — Wave 1: data + function + tests; Wave 2: vignette. The function itself is the critical path; the vignette depends on a working function and a working dataset.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| lme4 | 1.1.38 (installed) | Fit GLMM via `glmer.nb()`, bootstrap via `bootMer()` | The canonical R GLMM package; used in Askey 2018; already installed in project environment |
| rlang | (in Imports) | `check_installed()`, `enquo()`, `as_name()`, `cli_abort()` | Already used throughout the package for tidyselect and error handling |
| cli | (in Imports) | `cli_abort()` for design-type guard, `cli_inform()` for bootstrap progress | Already in Imports; used by all other estimators |
| tibble | (in Imports) | `tibble()` for the estimates data frame | Consistent with all other `new_creel_estimates()` calls |
| stats | (in Imports) | `poly()` (for model matrix generation in delta method), `qt()` for CI | Already imported |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Matrix | lme4 dependency | Sparse matrix backend for lme4 | Installed automatically with lme4; no direct calls needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| lme4::glmer.nb() | glmmTMB::glmmTMB(family=nbinom2) | glmmTMB is faster and more numerically stable for NB, but lme4 is the Askey 2018 reference implementation and is already the decided choice |
| delta method | lme4::bootMer() only | Bootstrap is more flexible but slow (500 reps × model refit); delta method is the fast default |
| parametric bootstrap | case/residual bootstrap | Case bootstrap requires raw data resampling not supported by bootMer; parametric is the lme4 standard |

**Installation (DESCRIPTION Suggests only):**
```r
# Add to Suggests in DESCRIPTION:
lme4
```
lme4 is NOT added to Imports because it is optional (only needed for the GLMM estimator). The `rlang::check_installed()` guard handles the missing-package case.

---

## Architecture Patterns

### Recommended File Structure

New files created in this phase:
```
R/
└── creel-estimates-aerial-glmm.R   # estimate_effort_aerial_glmm() + helpers

data-raw/
└── create_example_aerial_glmm_counts.R   # dataset generation script

data/
└── example_aerial_glmm_counts.rda   # generated by usethis::use_data()

vignettes/
└── aerial-glmm.Rmd   # standalone vignette

tests/testthat/
└── test-estimate-effort-aerial-glmm.R   # all GLMM tests
```

Modified files:
```
R/data.R                  # add @docType data entry for example_aerial_glmm_counts
DESCRIPTION               # add lme4 to Suggests
_pkgdown.yml              # add aerial-glmm to Survey Types articles section
```

### Pattern 1: lme4 Optional-Dependency Guard

Same pattern as `schedule-io.R` and `schedule-print.R`:

```r
# Source: R/schedule-io.R:125
rlang::check_installed("lme4", reason = "to fit the GLMM aerial effort estimator")
```

Place this at the very top of `estimate_effort_aerial_glmm()`, before any other code.

### Pattern 2: design_type Validation

Same guard pattern used in ice/camera design-type checks:

```r
if (!identical(design$design_type, "aerial")) {
  cli::cli_abort(c(
    "{.fn estimate_effort_aerial_glmm} requires an aerial survey design.",
    "x" = "Found {.field design_type} = {.val {design$design_type}}.",
    "i" = "Use {.fn estimate_effort} for {.val {design$design_type}} surveys."
  ))
}
```

### Pattern 3: tidyselect time_col Resolution

Consistent with `count_time_col` in `estimate_effort()`:

```r
time_col_quo <- rlang::enquo(time_col)
time_col_name <- rlang::as_name(time_col_quo)
flight_hours <- design$counts[[time_col_name]]
```

### Pattern 4: GLMM Fit Dispatch

```r
# Build formula
if (is.null(formula)) {
  glmm_formula <- stats::as.formula(
    paste0(count_var, " ~ poly(", time_col_name, ", 2) + (1|", design$date_col, ")")
  )
} else {
  glmm_formula <- formula
}

# Fit: dispatch on family argument
model <- if (is.null(family) || identical(family, "negbin")) {
  lme4::glmer.nb(glmm_formula, data = design$counts)
} else {
  lme4::glmer(glmm_formula, data = design$counts, family = family)
}
```

### Pattern 5: Delta Method SE

The effort estimate is the sum of response-scale predicted values over a dense grid of hours within the open-water period, scaled by `h_over_v`. The SE follows from the multivariate delta method applied to the fixed-effect coefficient vector:

```r
# Dense prediction grid across the open-water window
hour_grid <- seq(min_hour, max_hour, length.out = 100)
new_data  <- stats::setNames(
  data.frame(hour_grid),
  time_col_name
)
# Add date column (NA → population-level prediction, re.form=NA)
new_data[[design$date_col]] <- NA_character_

# Model matrix for the fixed effects only
X <- stats::model.matrix(
  stats::delete.response(stats::terms(model)),
  data = new_data
)

beta  <- lme4::fixef(model)
V     <- as.matrix(stats::vcov(model))
mu    <- as.numeric(exp(X %*% beta))          # response-scale predictions
total <- sum(mu) * (max_hour - min_hour) / 100 # scaled total

# Gradient: d(total)/d(beta_k) = sum_t mu_t * X_tk  (times scale factor)
scale <- (max_hour - min_hour) / 100
grad  <- scale * colSums(mu * X)
var_total <- as.numeric(t(grad) %*% V %*% grad)
se_total  <- sqrt(var_total)
```

Then scale both `total` and `se_total` by `h_over_v` (the same calibration constant as `estimate_effort_aerial()`).

### Pattern 6: bootMer Bootstrap Path

```r
if (boot) {
  cli::cli_inform(
    "Running {nboot} bootstrap replicates via lme4::bootMer..."
  )
  boot_fn <- function(m) {
    # Same integral as delta method but re-fit
    mu_b <- as.numeric(exp(X %*% lme4::fixef(m)))
    sum(mu_b) * scale * h_over_v
  }
  b <- lme4::bootMer(
    model,
    FUN     = boot_fn,
    nsim    = nboot,
    type    = "parametric",
    use.u   = FALSE
  )
  se <- stats::sd(b$t)
  ci  <- stats::quantile(b$t, c((1 - conf_level) / 2, 1 - (1 - conf_level) / 2))
  ci_lower <- ci[[1]]
  ci_upper <- ci[[2]]
}
```

### Pattern 7: new_creel_estimates Constructor

```r
estimates_df <- tibble::tibble(
  estimate   = total_effort,
  se         = se,
  se_between = se,   # fixed-effect SE component (= overall SE for GLMM path)
  se_within  = NA_real_,
  ci_lower   = ci_lower,
  ci_upper   = ci_upper,
  n          = nrow(design$counts)
)

new_creel_estimates(
  estimates       = estimates_df,
  method          = "aerial_glmm_total",
  variance_method = if (boot) "bootstrap" else "delta",
  design          = design,
  conf_level      = conf_level,
  by_vars         = NULL
)
```

### Pattern 8: dataset generation (data-raw/)

Follows `create_example_aerial_counts.R` exactly — use `set.seed()`, construct data frame, assert invariants, call `usethis::use_data(..., overwrite = TRUE)`.

The `example_aerial_glmm_counts` dataset needs:
- Multiple overflights per day (e.g., 4-5 counts per day at different hours)
- 10-14 survey days (enough random effect levels for stable day-level variance)
- A `time_of_flight` column (hour, numeric, e.g. 7.0, 10.0, 13.0, 16.0, 19.0)
- Count values that follow a credible diurnal curve (low at dawn/dusk, peak mid-morning)
- The same `date`, `day_type` columns as other aerial datasets

A suggested structure: 12 days × 4 flights per day = 48 rows, hours at 7, 10, 13, 16.

### Anti-Patterns to Avoid

- **Including lme4 in Imports:** lme4 is optional — it belongs in Suggests only, guarded by `rlang::check_installed()`.
- **Using predict.merMod with se.fit:** The official docs warn this is experimental; use the delta method (manual `X %*% beta` + gradient) for parametric SE, and `bootMer()` for bootstrap SE.
- **Passing `re.form = NULL` for the effort integral:** Use `re.form = NA` to get population-level (fixed-effect-only) predictions, which are appropriate for projecting to unsurveyed hours.
- **Using `model.matrix()` with the original data:** Build a new prediction grid with `NA` for the date column to avoid accidental random-effect inclusion.
- **Fitting the GLMM when `design$counts` has only one row per day:** The random intercept requires multiple days; `glmer.nb` will fail or produce degenerate estimates. The function should rely on lme4's own convergence warnings rather than pre-checking — lme4 will stop with an informative error if the model is unidentifiable.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Negative binomial GLMM fitting | Custom NB likelihood | `lme4::glmer.nb()` | Handles overdispersion estimation, REML/ML, convergence checks automatically |
| Bootstrap CI for derived statistic | Manual resample loop | `lme4::bootMer(type="parametric")` | Parametric bootstrap respects the GLMM data-generating process; returns `boot`-class object with `sd()` for SE and `quantile()` for percentile CI |
| Gradient of sum-of-predictions | Numerical differentiation | Analytic gradient: `colSums(mu * X)` | Analytic is exact and fast; NB link is log so derivative is `mu * X` |
| Optional package error message | Custom `tryCatch` | `rlang::check_installed()` | Produces standardized, installable error with correct package name and `install.packages()` hint |

**Key insight:** The delta method for this estimator has a clean analytic gradient because the link function is log. The total effort is `sum(exp(X %*% beta)) * scale * h_over_v`, so `d(total)/d(beta) = scale * h_over_v * colSums(exp(X %*% beta) * X)`. No numerical derivatives needed.

---

## Common Pitfalls

### Pitfall 1: Model Matrix Mismatch Between Fit and Prediction Grid

**What goes wrong:** `model.matrix()` called with a formula referencing `poly(hour, 2)` on a new data frame produces an *orthogonal* polynomial basis computed from the new data rather than the original, making predictions on a different scale than the fitted model.

**Why it happens:** `poly()` in R computes orthogonal polynomials with mean and norm derived from the actual data passed; if the prediction grid spans different values, the basis changes.

**How to avoid:** Use `stats::delete.response(stats::terms(model))` to extract the model's *stored* term object, then call `model.matrix(terms_obj, new_data)`. This reuses the polynomial normalization from the original fit.

**Warning signs:** Predicted response values at observed hours differ from `fitted(model)`.

### Pitfall 2: glmer.nb Convergence Warnings with Small Datasets

**What goes wrong:** With few days (< 5-6), the theta (overdispersion) parameter in `glmer.nb()` hits the iteration limit and emits "iteration limit reached" in the theta ML step, or the model fails to converge.

**Why it happens:** `glmer.nb()` uses an alternating algorithm that iterates between updating theta and updating the GLMM coefficients; small datasets make theta poorly identifiable.

**How to avoid:** The `example_aerial_glmm_counts` dataset must have enough days (10-14 recommended) to ensure stable fits. Document in the function's `@details` that at least 8-10 sampling days are needed for stable GLMM estimation.

**Warning signs:** `lme4::isSingular(model)` returns TRUE, or theta estimate is very large (> 1000, effectively Poisson).

### Pitfall 3: Wrong Scaling of the Effort Integral

**What goes wrong:** The integral over hours gives a dimensionless total count, not total angler-hours. The h_over_v scaling then applies, but the grid resolution (length.out) affects the magnitude.

**Why it happens:** The sum of predicted values approximates `integral from t_start to t_end of E[count(t)] dt`. If the grid has N points spanning H hours, each point represents H/N hours, so the integral is `sum(mu) * H/N`.

**How to avoid:** Always multiply `sum(mu)` by `(max_hour - min_hour) / length(hour_grid)` before applying `h_over_v`. Verify with a known simple case: if count is constant = C over H hours, the total effort should be `C * H * h_over_v`.

**Warning signs:** Estimates that are 100x too large or too small.

### Pitfall 4: bootstrap CI Asymmetry Not Propagated

**What goes wrong:** When `boot = TRUE`, returning the symmetric `estimate ± 1.96 * sd(b$t)` CI ignores the bootstrap distribution's skew. Percentile intervals are preferred for count data.

**How to avoid:** For bootstrap path, use `quantile(b$t, c(alpha/2, 1-alpha/2))` for `ci_lower` / `ci_upper`, not `estimate ± z * se`.

**Warning signs:** Bootstrap CI that doesn't cover the point estimate.

### Pitfall 5: se_between / se_within Semantics

**What goes wrong:** Users familiar with the standard aerial estimator expect `se_between` to reflect between-day variance and `se_within` to reflect within-day (Rasmussen) variance. The GLMM estimator does not decompose SE this way.

**How to avoid:** Set `se_between = se` (the total SE) and `se_within = NA_real_`. Add a note in the `@return` Rd section: "The `se_within` column is `NA` because the GLMM absorbs within-day temporal variation into the model; the Rasmussen decomposition does not apply."

---

## Code Examples

Verified patterns from local testing (lme4 1.1.38):

### Fitting glmer.nb with Askey formula

```r
# Source: verified locally 2026-04-05 against lme4 1.1.38
model <- lme4::glmer.nb(
  n_anglers ~ poly(time_of_flight, 2) + (1 | date),
  data = design$counts
)
```

### Population-level prediction grid

```r
# Source: verified locally 2026-04-05; re.form=NA is the key
hour_grid <- seq(open_start, open_end, length.out = 100)
new_data  <- data.frame(time_of_flight = hour_grid, date = NA_character_)
# Use stored terms to preserve polynomial normalization from fit
terms_obj <- stats::delete.response(stats::terms(model))
X <- stats::model.matrix(terms_obj, data = new_data)
mu <- as.numeric(exp(X %*% lme4::fixef(model)))
```

### Delta method SE

```r
# Source: verified locally 2026-04-05
scale     <- (open_end - open_start) / 100   # hours per grid step
V         <- as.matrix(stats::vcov(model))
grad      <- scale * h_over_v * colSums(mu * X)
var_total <- as.numeric(t(grad) %*% V %*% grad)
se_delta  <- sqrt(var_total)
```

### bootMer usage

```r
# Source: verified locally 2026-04-05
# bootMer formals: x, FUN, nsim, seed, use.u, re.form, type, verbose, ...
boot_fn <- function(m) {
  mu_b <- as.numeric(exp(X %*% lme4::fixef(m)))
  sum(mu_b) * scale * h_over_v
}
b   <- lme4::bootMer(model, FUN = boot_fn, nsim = nboot,
                     type = "parametric", use.u = FALSE)
se_boot <- stats::sd(b$t)
ci_boot <- stats::quantile(b$t, c((1 - conf_level) / 2,
                                    1 - (1 - conf_level) / 2),
                            names = FALSE)
```

### rlang::check_installed pattern

```r
# Source: R/schedule-io.R:125, R/schedule-print.R:318 (existing project patterns)
rlang::check_installed("lme4", reason = "to fit the GLMM aerial effort estimator")
```

### example_aerial_glmm_counts dataset structure

```r
# Recommended structure for data-raw/create_example_aerial_glmm_counts.R
set.seed(42)
survey_dates <- seq.Date(as.Date("2024-06-03"), by = "3 days", length.out = 12)
flight_hours <- c(7.0, 10.0, 13.0, 16.0)   # 4 flights per day

# Counts follow a diurnal curve: low at dawn/dusk, peak ~10am
# True mean curve: exp(3.5 + 0.8*(h-12)/5 - 1.2*((h-12)/5)^2)
# Expected: ~7 at 7am, ~30 at 10am, ~25 at 1pm, ~10 at 4pm
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Mean-count expansion (simple) | GLMM with diurnal curve | Askey 2018 | Removes bias when flight timing is non-random |
| Fixed theta in NB GLMM | lme4::glmer.nb() alternating algorithm | lme4 1.x | Theta estimated from data; no user specification needed |
| Numeric gradient for delta method | Analytic gradient via `colSums(mu * X)` | Always true for log-link | Faster and exact |
| bootMer returning list | bootMer returning `boot`-class object | Recent lme4 | Compatible with `boot::boot.ci()` and `sd()` / `quantile()` directly |

**Deprecated/outdated:**
- `se.fit` in `predict.merMod`: Marked experimental; do not use — the docs recommend `bootMer()` instead.
- `MASS::glm.nb`: Fits a GLM (no random effects); not appropriate for repeated daily measurements.

---

## Open Questions

1. **Minimum number of days for stable glmer.nb fit**
   - What we know: 10-12 days works well in local testing; theta convergence warnings appear with fewer days
   - What's unclear: The exact threshold for the `example_aerial_glmm_counts` dataset; whether to add a `cli_warn()` if `nlevels(design$counts[[date_col]]) < 8`
   - Recommendation: Use 12 days in the example dataset; add a note in `@details` but do not add a hard guard (lme4 will error/warn naturally)

2. **Integration window for the effort integral**
   - What we know: The integral is over the open-water window, which is `h_open` hours wide centered on some reference time
   - What's unclear: Does the GLMM user need to supply the absolute start time of the fishery (e.g., 6 AM), or is it sufficient to use the range of observed flight times?
   - Recommendation: Use `min(flight_hours) - buffer` to `max(flight_hours) + buffer` from the observed data, or accept `open_start` / `open_end` arguments (Claude's discretion). Simpler option: use observed range plus half the inter-hour gap as buffer.

3. **h_open vs. integration window consistency**
   - What we know: `h_over_v = design$aerial$h_open / visibility_correction` is the existing calibration constant
   - What's unclear: Whether to use `h_open` directly to set the integration window, or let the user supply separate `open_start`/`open_end` hours
   - Recommendation: Derive the integration window from `design$aerial$h_open` to avoid requiring extra arguments; assume the fishery opens at a standard reference time and spans `h_open` hours.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x (edition 3) |
| Config file | `tests/testthat.R` (standard) |
| Quick run command | `testthat::test_file("tests/testthat/test-estimate-effort-aerial-glmm.R")` |
| Full suite command | `devtools::test()` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GLMM-01 | `estimate_effort_aerial_glmm()` returns valid effort estimate for aerial design | integration | `testthat::test_file("tests/testthat/test-estimate-effort-aerial-glmm.R")` | ❌ Wave 0 |
| GLMM-01 | Default Askey formula fits without error on `example_aerial_glmm_counts` | integration | same file | ❌ Wave 0 |
| GLMM-01 | Custom formula override accepted | unit | same file | ❌ Wave 0 |
| GLMM-01 | `boot = TRUE` path runs and returns valid CIs | integration | same file | ❌ Wave 0 |
| GLMM-02 | Result is `creel_estimates` S3 class | unit | same file | ❌ Wave 0 |
| GLMM-02 | estimates tibble has columns: estimate, se, se_between, se_within, ci_lower, ci_upper, n | unit | same file | ❌ Wave 0 |
| GLMM-02 | `se_within` is NA_real_ | unit | same file | ❌ Wave 0 |
| GLMM-02 | `method` is "aerial_glmm_total" | unit | same file | ❌ Wave 0 |
| GLMM-03 | `cli_abort()` if lme4 not installed (mock via `rlang::local_options`) | unit | same file | ❌ Wave 0 |
| GLMM-03 | `cli_abort()` if `design_type != "aerial"` | unit | same file | ❌ Wave 0 |
| GLMM-04 | Vignette renders without error (`rmarkdown::render`) | smoke | `devtools::build_vignettes()` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/testthat/test-estimate-effort-aerial-glmm.R")`
- **Per wave merge:** `devtools::test()`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-estimate-effort-aerial-glmm.R` — covers GLMM-01, GLMM-02, GLMM-03
- [ ] `data-raw/create_example_aerial_glmm_counts.R` — generate dataset (GLMM-01 fixture)
- [ ] `data/example_aerial_glmm_counts.rda` — generated by running data-raw script
- [ ] `R/creel-estimates-aerial-glmm.R` — the estimator function
- [ ] `vignettes/aerial-glmm.Rmd` — covers GLMM-04

---

## Sources

### Primary (HIGH confidence)
- lme4 1.1.38 installed in project environment — `glmer.nb()`, `bootMer()`, `fixef()`, `vcov()` formals verified via `Rscript -e` calls
- [rdrr.io/cran/lme4/man/bootMer.html](https://rdrr.io/cran/lme4/man/bootMer.html) — `use.u`, `type`, return class, nsim parameter confirmed
- [rdrr.io/cran/lme4/man/predict.merMod.html](https://rdrr.io/cran/lme4/man/predict.merMod.html) — `re.form=NA` for population-level, `se.fit` experimental warning confirmed
- Delta method derivation verified locally: `grad = colSums(mu * X)`, `var = t(grad) %*% V %*% grad` produces numeric SE (2026-04-05 local run)
- `R/creel-estimates-aerial.R` — existing simple estimator read in full; `h_over_v`, `new_creel_estimates()` pattern confirmed
- `R/data.R` — data documentation pattern confirmed for `example_aerial_glmm_counts` entry
- `_pkgdown.yml` — "Survey Types" articles section confirmed; `aerial-surveys` slug is the existing entry to add alongside

### Secondary (MEDIUM confidence)
- [onlinelibrary.wiley.com/doi/abs/10.1002/nafm.10010](https://onlinelibrary.wiley.com/doi/abs/10.1002/nafm.10010) — Askey (2018) abstract: GLMM with quadratic temporal effect corrects bias from non-random sampling; stratified sampling + GLMM more efficient than mean-count expansion
- WebSearch results confirming `bootMer` returns `c("bootMer","boot")` class and `sd(b$t)` / `quantile(b$t)` are the standard CI methods

### Tertiary (LOW confidence)
- Details of the Askey (2018) formula (quadratic hour effect, day-level random intercept) confirmed via CONTEXT.md locked decisions, not directly from the paper

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — lme4 version and API verified locally
- Architecture: HIGH — delta method derivation verified numerically; all patterns traced to existing code
- Pitfalls: HIGH (poly mismatch, integration scaling) / MEDIUM (convergence threshold, bootMer CI asymmetry)
- Vignette structure: HIGH — `aerial-surveys.Rmd` read in full as template

**Research date:** 2026-04-05
**Valid until:** 2026-05-05 (lme4 is stable; API unlikely to change)
