
# tidycreel Effort Estimation — Actionable Build Plan (R)

This plan turns the research review into concrete implementation steps for `tidycreel`. It’s written to be **directly actionable by an AI/code assistant** working in R, following the package’s style and conventions (tidyverse where helpful, `survey/srvyr` for design-based inference, S3 methods, tested and documented).

---

## 0) Guiding Principles & Project Skeleton

- **Architecture**
  - Prefer **S3 generics** + methods over R6 for user-facing APIs (consistent with base R and `survey`).
  - Central generic: `est_effort(x, ...)` with methods for `creel_design`, `svydesign`, and later `svrepdesign`.
  - Keep a clear separation between **design constructors**, **estimators**, and **plot/report helpers**.
- **Design-based first, model-based optional**
  - Implement validated **design-based estimators** first (instantaneous, progressive/roving, bus-route, aerial).
  - Provide optional **model-based** routes (GLMM/Bayesian) behind a method flag and separate deps.
- **Diagnostics & safety**
  - Every estimator emits: input validation, dropped rows report, NA checks, and a compact `diagnostics` tibble.
- **Variance**
  - Prefer `survey::svytotal/svymean/svyratio` with correctly specified designs.
  - Fallbacks: jackknife/bootstrap via `svrepdesign` when analytic variance is awkward.
- **Docs & tests**
  - Roxygen documentation with runnable examples (small toy data).
  - `testthat` coverage for: correctness on toy data, edge cases, variance sanity checks.

**Deliverables Foldering (suggested):**
```
R/
  design-constructors.R
  est-effort.R
  est-effort-busroute.R
  est-effort-aerial.R
  est-effort-modelbased.R
  utils-validate.R
  utils-time.R
  plots.R
tests/
  test-est-effort.R
  test-est-effort-busroute.R
vignettes/
  effort_design_based.Rmd
  effort_model_based.Rmd
inst/extdata/ (toy datasets)
```

---

## 1) Shared Foundations (Utilities & Schemas)

### 1.1 Data Schemas (minimum columns)
- **Counts (instantaneous/progressive/aerial)**: `date`, `shift_block` (optional), `location`, `time`/`timestamp`, `count` (or `anglers_count`), `interval_minutes` **or** `count_duration` (for instantaneous), optional: `visibility_prop` (aerial sightability), `circuit_id` (progressive).
- **Interviews** (for coverage/aux data): `party_size`, `hours_fished`, `location`, `date`, optional: `start_time`, `end_time`.
- **Bus-route schedule/observations**: `site`/`location`, `visit_start`, `visit_end`, `cycle_minutes`, per-visit observations of vehicle/party presence; optional `party_id` if trackable.
- **Strata variables** (typical): `date`, `shift_block`, `day_type` (weekend/weekday), `location`.

### 1.2 Utility functions
- `tc_require_cols(df, cols, context)` — throw informative error listing missing columns; `context` names the estimator.
- `tc_guess_cols(df, synonyms)` — map synonyms: e.g., `anglers_count -> count`; `interval_mins -> interval_minutes`.
- `tc_as_time(x)` — parse to POSIXct (lubridate if available, else base).
- `tc_group_warn(by, names(df))` — drop absent `by` cols with a warning.
- `tc_diag_drop(df_before, df_after, reason)` — build diagnostics about dropped rows.
- `tc_confint(mean, se, level)` — standard normal or t-based CI helper.

**Tasks**
- [ ] Implement utilities in `R/utils-validate.R` and `R/utils-time.R` with tests.
- [ ] Add roxygen and export only what’s needed (utils internal by default).

---

## 2) Core Generic & Return Contract

### 2.1 Generic
- `est_effort <- function(x, ...) UseMethod("est_effort")`

### 2.2 Return value (common tibble)
Columns: `by...` (strata), `estimate` (angler-hours), `se`, `ci_low`, `ci_high`, `n`, `method`, `diagnostics` (list-col or attr).

**Tasks**
- [ ] Define generic + default error method.
- [ ] Implement a small constructor `new_estimate_tbl(df)` ensuring column existence/order.

---

## 3) Instantaneous Count Method (Design-Based)

**Principle**: Effort (hours) ≈ sum over strata of `mean_instant_count * total_minutes_in_stratum / 60`.

### 3.1 Function: `est_effort.instantaneous`
**Signature**:
```r
est_effort.instantaneous <- function(counts, by = c("date","shift_block","location"),
                                     minutes_col = c("count_duration","interval_minutes"),
                                     visibility_col = NULL,
                                     svy = NULL, conf_level = 0.95, ...)
```
- Accept **either** raw counts or a pre-specified `svydesign` in `svy` describing the **day sampling design** (strata/day-type, FPC).
- Coerce `count` column; choose `minutes_col`; multiply counts by minutes; divide by 60.
- If `visibility_col` present (0–1), adjust: `adj_count = count / visibility_prop` (cap at sensible max).

### 3.2 Variance options
- **Without `svy`**: compute per-day totals then sample variance across sampled days in stratum, standard stratified expansion variance.
- **With `svy`**: build day-level totals per PSU and use `svytotal` across days.

**Tasks**
- [ ] Implement estimator with validations and CI.
- [ ] If `svy` missing, compute design weights from simple stratified day sampling (require `N_days` per stratum as input or infer from calendar in design object).
- [ ] Unit tests: constant counts → exact totals; missing visibility → unchanged; visibility <1 inflates counts; variance decreases with more days.

---

## 4) Progressive (Roving) Count Method

**Principle**: Each **pass** of duration `route_minutes` approximates an “extended instant”; effort per pass = `total_count * route_minutes/60`. Sum over passes/day; expand to season via strata-day expansion.

### 4.1 Function: `est_effort.progressive`
**Signature**:
```r
est_effort.progressive <- function(counts, by = c("date","shift_block","location"),
                                   route_minutes_col = "route_minutes",
                                   time_col = c("time","timestamp"),
                                   passes_col = "circuit_id",
                                   svy = NULL, conf_level = 0.95, ...)
```
- Validate presence of `passes_col` (or derive one by grouping contiguous routes).
- For each pass: `eff_pass = sum(count) * route_minutes/60` (optionally by segments then sum).
- Day-level total = sum over passes; then apply stratified day expansion.

**Bias guardrails**
- Warn if interviews were taken during counts (flag `interviewing_during_count==TRUE`), suggest count-only passes or correction factors.

**Tasks**
- [ ] Implement estimator; aggregate by pass then day then stratum.
- [ ] Variance as in Instantaneous: day totals + survey design if provided.
- [ ] Tests with toy data: multiple passes per day, mixed strata, missing route_minutes ⇒ error.

---

## 5) Bus-Route Access Method

**Principle**: Periodic site visits; detection probability of a trip depends on visit schedule and trip duration. Use **Horvitz–Thompson** with inclusion probabilities πᵢ for each observed party/vehicle (Robson & Jones, 1989).

### 5.1 Function: `est_effort.busroute`
**Signature**:
```r
est_effort.busroute <- function(visits,   # visit logs by site with times
                                observations, # party/vehicle presence per visit
                                by = c("date","location"),
                                cycle_col = "cycle_minutes",
                                visit_start = "visit_start",
                                visit_end   = "visit_end",
                                party_id = NULL, # optional tracking
                                svy = NULL,
                                conf_level = 0.95, ...)
```
**Algorithm (minimal practical version)**
1. **Compute cycle time per site** and **check equal-cycle condition**; warn if violated.
2. For each observed party `i`, estimate **encounter probability** πᵢ using visit coverage:
   - If party observed the **entire** visit window: lower bound on presence ≥ visit length.
   - With entry/exit noted, estimate observed overlap with visit windows.
   - Use Robson–Jones approximation: πᵢ ≈ `min(1, total_visit_time_in_cycle / trip_duration_i)` (document assumption). If trip duration unknown, use **empirical distribution** from interviews or sensitivity bounds.
3. **HT total** of party-hours: `Σ (observed_overlap_hours / πᵢ)`. Convert to **angler-hours** by multiplying by party size if available.
4. Aggregate by `by` and expand across days via `svy` or day expansion weights.

**Variance**
- Use **replicate weights** approach: bootstrap parties within day × site (respecting cycles) or jackknife over days, then compute variance of HT totals.
- If `svy` provided with day sampling, combine replicate variance within day with day-level design variance (nested or two-phase approximation).

**Tasks**
- [ ] Implement πᵢ calculation helper with documented assumptions and caps (πᵢ ∈ (0,1]).
- [ ] Implement HT estimator + replicate variance (simple bootstrap B=500; make B configurable).
- [ ] Diagnostics: equal-cycle check, proportion of trips with unknown durations, sensitivity band if durations imputed.
- [ ] Tests using simulated data (derive from `AnglerCreelSurveySimulation`-like logic).

---

## 6) Aerial Instantaneous Method

**Principle**: Flights provide **instantaneous** angler/boat counts over large areas; expand to hours/days by stratification (day-type, month). Optional **sightability** adjustment.

### 6.1 Function: `est_effort.aerial`
**Signature**:
```r
est_effort.aerial <- function(flights,
                              by = c("date","shift_block","location"),
                              minutes_representation = "flight_minutes", # mins represented by flight
                              count_col = c("count","boats","anglers"),
                              visibility_col = NULL,
                              svy = NULL, conf_level = 0.95, ...)
```
- Adjust counts by visibility if provided: `adj_count = count / visibility_prop`.
- Effort per flight = `adj_count * minutes_representation / 60` (choose representation carefully; default: minutes represented by a valid instantaneous snapshot in the stratum). Many designs use **mean count × total day minutes** at the **stratum** level; support both via parameterization.

**Tasks**
- [ ] Implement estimator with two modes: (a) per-flight minute-representation, (b) stratum-level mean × total minutes.
- [ ] Variance with `survey` design or stratified sample variance.
- [ ] Tests: visibility edge cases; multiple lakes (locations) per flight; CI matches manual calc.

---

## 7) Strata Estimator Wrapper

Provide a **wrapper** that takes any per-day (or per-flight) totals and applies **stratified expansion** to a season total with `survey`.

### 7.1 Function: `est_effort.strata_total`
**Signature**:
```r
est_effort.strata_total <- function(day_totals, # columns: stratum vars + day_total_hours
                                    strata = c("month","day_type","location"),
                                    N_days, # named vector or lookup per stratum
                                    svy = NULL, conf_level = 0.95, ...)
```
**Behavior**
- If `svy` is provided, assume day_totals are the **analysis variables** and use `svytotal` with proper design.
- Else compute classic stratified mean × N_days with analytic variance.

**Tasks**
- [ ] Implement as a small, well-tested utility used by 3–6.

---

## 8) Model-Based Options (Optional/Advanced)

### 8.1 GLMM approach
**Signature**:
```r
est_effort.glmm <- function(day_counts,
                            formula = effort ~ day_type + (1|location) + s(day_of_year),
                            family = poisson, offset = NULL,
                            predict_grid = NULL, conf_level = 0.95, ...)
```
- Fit GLMM (or GAMM via `mgcv`) to **daily** effort or counts; predict across full season grid; sum predictions to get total effort; CIs via parametric bootstrap.
- Dependencies: `lme4` or `glmmTMB`; optionally `mgcv` for smooths.

**Tasks**
- [ ] MVP: `lme4::glmer()` Poisson/NB with random intercept by `location`.
- [ ] Prediction grid builder; bootstrap CIs.
- [ ] Tests on simulated multi-lake dataset; compare to known truth.

### 8.2 Bayesian camera/creel integration (template)
**Signature**:
```r
est_effort.bayes_camera <- function(camera_counts, creel_calibration, model_file = NULL,
                                    engine = c("rstan","cmdstanr"), iter = 2000, chains = 4, ...)
```
- Provide a **Stan template** that links camera counts to latent effort with detection; calibrate with overlapping creel data; return posterior for seasonal effort.

**Tasks**
- [ ] Ship a minimal Stan model string + R wrapper; skip if engine not installed.
- [ ] Tests: short chain smoke test; posterior summaries exist.

---

## 9) Variance, Replicates, and `survey` Integration

- For each estimator, offer:
  - `variance = c("analytic","replicate","none")`
  - `replicate = list(type = "bootstrap"|"JK1"|"BRR", R = 500)`
- Provide helper: `to_svydesign(day_level_df, strata, fpc, weights)` to standardize design creation.

**Tasks**
- [ ] Implement replicate engine wrapper using `survey::svrepdesign`.
- [ ] Consistent CI computation; warn if few PSUs.

---

## 10) API Cohesion & S3 Methods

- Register methods so users can call:
  - `est_effort(x, method = "instantaneous", ...)`
  - `est_effort(x, method = "progressive", ...)`
  - `est_effort(x, method = "busroute", ...)`
  - `est_effort(x, method = "aerial", ...)`
  - `est_effort(x, method = "glmm"|"bayes_camera", ...)`
- For `creel_design` inputs, pull relevant `$counts`, `$calendar`, `$route_schedule`, etc. as defaults.

**Tasks**
- [ ] Dispatcher in `est-effort.R` that routes to method-specific functions.
- [ ] Method registry tests.

---

## 11) Diagnostics & Warnings (Standardized)

- Missing columns → `cli_abort` with actionable fix.
- NA handling → count NAs, drop with reason, surface in `diagnostics`.
- Timing sanity checks:
  - progressive: `route_minutes` > 0, passes complete, randomized starts if available.
  - bus-route: equal cycle check with tolerance, percent of missing trip durations.
  - aerial: visibility within (0,1]; warn for extreme corrections.
- Stratification sanity: show strata counts, empty strata warnings.

**Tasks**
- [ ] Implement `diagnostics` list-col with standardized fields across estimators.
- [ ] Unit tests for common failure modes.

---

## 12) Documentation & Vignettes

- **Function docs**: clear examples using `inst/extdata` toy sets (≤25 rows).
- **Vignette**: “Design-based effort estimation in `tidycreel`” — walk-through: instantaneous → progressive → bus-route → aerial.
- **Vignette**: “Model-based options” — GLMM and camera-Bayes templates; caveats.

**Tasks**
- [ ] Write vignettes; ensure they knit during CI (use `eval=FALSE` for heavy code).

---

## 13) Testing Matrix

- Deterministic toy scenarios with known totals.
- Random simulations to compare estimator bias/variance.
- Cross-check: design-based vs GLMM predictions when model is correctly specified.
- Replicate variance vs analytic variance convergence on large samples.

**Tasks**
- [ ] Implement `simulate_creel_counts()` helpers under `tests/testthat/helpers-*.R`.

---

## 14) Milestones

1. **M1 (Design-based MVP):** Instantaneous + Progressive complete with variance; strata wrapper; docs/tests.
2. **M2 (Coverage expansion):** Bus-route + Aerial; replicate variance; diagnostics hardened.
3. **M3 (Model-based beta):** GLMM estimator; optional Bayesian camera template.
4. **M4 (Docs/Release):** Vignettes, pkgdown site, examples polished.

---

## 15) Example Function Stubs (to guide implementation)

```r
#' @export
est_effort.creel_design <- function(x, method = c("instantaneous","progressive","busroute","aerial",
                                                  "glmm","bayes_camera"),
                                    ..., conf_level = 0.95) {
  method <- match.arg(method)
  switch(method,
    instantaneous = est_effort.instantaneous(counts = x$counts, ..., conf_level = conf_level),
    progressive   = est_effort.progressive(counts = x$counts, ..., conf_level = conf_level),
    busroute      = est_effort.busroute(visits = x$route_schedule, observations = x$bus_observations, ..., conf_level = conf_level),
    aerial        = est_effort.aerial(flights = x$flights, ..., conf_level = conf_level),
    glmm          = est_effort.glmm(day_counts = x$day_totals, ..., conf_level = conf_level),
    bayes_camera  = est_effort.bayes_camera(camera_counts = x$camera_counts, creel_calibration = x$creel_calibration, ...)
  )
}
```

---

## 16) Add to TODO (from this plan)

- [ ] Build utilities & schemas (Sec. 1).
- [ ] Implement instantaneous (Sec. 3).
- [ ] Implement progressive (Sec. 4).
- [ ] Implement bus-route (Sec. 5).
- [ ] Implement aerial (Sec. 6).
- [ ] Implement strata wrapper (Sec. 7).
- [ ] Add GLMM (Sec. 8.1) and optional Bayesian template (Sec. 8.2).
- [ ] Variance & replicates integration (Sec. 9).
- [ ] Diagnostics standardization (Sec. 11).
- [ ] Vignettes & tests (Sec. 12–13).
