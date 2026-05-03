# Feature Landscape: tidycreel v1.6.0

**Domain:** R package for creel survey design and estimation (fisheries)
**Researched:** 2026-05-02
**Milestone scope:** 4 new analytical capabilities building on the existing v1.5.0 surface

---

## Feature 1: Camera Missing Data Imputation

### What It Does

Fills in camera count records for days when a camera was non-operational (stolen, dead battery, obstructed lens, vandalism). Without imputation, those days drop silently from the effort denominator and bias the seasonal total downward. The imputed count is inserted into the count table so downstream estimation (`est_effort_camera()`) sees a complete record.

Two methodological paths from the literature:

**Path A — Zero-inflated GLMM (Afrifa-Yamoah et al. 2020, ICES J. Mar. Sci. 77:2984–2999):** A fully conditional specification multiple imputation (MICE) framework where each missing count is drawn from a zero-inflated Poisson or zero-inflated negative binomial model conditioned on observed covariates. The GLMM form (random intercept by day or site) borrows strength across the time series. Afrifa-Yamoah tested nine model variants; ZIP and ZINB consistently ranked in the top three across all missing-data patterns (6%–61% missing). Implemented via `glmmTMB` (or `pscl` + `mice`/`countimp`).

**Path B — Day-type GLM (Hartill et al. 2016, Fisheries Research 183:488–497):** A simpler fixed-effects GLM using day-of-week (weekday/weekend) and season as covariates to predict counts at a ramp from counts at neighboring ramps or from the same ramp's historical pattern. R² of 0.71–0.77 between trailer counts and access-point creel effort. No mixed-effects component; straightforward to implement with base `glm()`. Appropriate when the user has few enough cameras that cross-site borrowing does not apply, or prefers a simpler audit trail.

### Expected API Shape

```r
impute_camera_counts(
  counts,            # data frame with camera count records
  date_col     = "date",
  count_col    = "n_trailers",   # or n_vehicles, n_ingress, etc.
  status_col   = "camera_status",  # values: "operational", "outage", etc.
  outage_value = "outage",
  covariates   = c("day_type", "month"),  # user-supplied predictors
  method       = c("glmm_zip", "glmm_zinb", "glm_daytype"),
  m            = 5L,      # number of imputed datasets (default 5 for MI)
  seed         = NULL,
  conf_level   = 0.95
)
```

Returns: a `creel_imputed_counts` object with:
- `$imputed` — completed count data frame (single imputed dataset or pooled mean)
- `$diagnostics` — model fit summary (AIC, model type used)
- `$m_datasets` — (optional) list of `m` imputed datasets for Rubin's rules pooling

The `$imputed` frame can be passed directly to `est_effort_camera()` in place of the raw counts.

### Table Stakes

| Behavior | Why Expected |
|----------|-------------|
| Accept a status flag column that marks outage rows | Camera outages are the primary use case; biologists already track status |
| Support day-of-week covariate at minimum | Even the simplest published method (Hartill 2016) requires day_type |
| Return a complete (no-NA) count data frame compatible with `est_effort_camera()` | The imputed data feeds the existing estimator; incompatible shape breaks the workflow |
| Single deterministic imputed dataset as default output | Simplest audit path for most agency workflows |
| cli_warn() when missing fraction is high (> 0.5) | Per Afrifa-Yamoah, reliability degrades sharply above ~50% missing |

### Differentiators

| Behavior | Value |
|----------|-------|
| Multiple imputation (`m` datasets) with Rubin's rules pooling of variance | Correct propagation of imputation uncertainty into effort SE; agencies doing formal assessments need this |
| GLMM random effect across days/sites | Borrows strength from the full time series; better than site-isolated GLM for sparse cameras |
| Automatic model selection (AIC over Poisson, NB, ZIP, ZINB) | Removes modeling burden from the biologist; matches Afrifa-Yamoah evaluation approach |

### Edge Cases

1. **All values in a stratum are missing.** No data to condition the model on. Must `cli_abort()` with a clear message: imputation requires at least some observed counts in the same stratum.
2. **Outage at the start or end of the season.** No lagged observations to borrow from. GLM fallback still works from day_type alone; GLMM may produce wide prediction intervals — `cli_warn()` appropriate.
3. **Zero counts that are genuine (no fishing activity), not outages.** The status column must discriminate outage-zero from genuine-zero. If status coding is ambiguous, downstream estimates are biased regardless of imputation.
4. **Single camera with no neighboring cameras.** Cross-site Hartill-style imputation is not possible. Must use within-site temporal model only.
5. **Very short seasons (< 14 days total).** Insufficient time series for GLMM random effects to be identifiable. GLM fallback preferred; flag in output.

### Dependencies on Existing Functions

- **Feeds into:** `est_effort_camera()` — the imputed counts replace raw counts in the same data frame schema
- **Parallel to:** `creel_design()` camera mode — the counts frame should already conform to the schema `add_counts()` expects
- **New package dependency required:** `glmmTMB` (or `pscl`) in Suggests; `mice` in Suggests for MI path
- **No new S3 class strictly required** — a list with `$imputed` and `$diagnostics` is sufficient, but a `creel_imputed_counts` class enables a `print()` method with a useful summary

---

## Feature 2: Camera Design Helper (`creel_n_camera()`)

### What It Does

Answers "How many sampling days and photos per day are needed to achieve a target CV on the effort estimate from camera data?" This is the camera-survey analogue of the existing `creel_n_effort()` (which covers bus-route/instantaneous designs).

Feltz and Middaugh (2025, NAJFM 45:322) provide the most current empirical guidance: across six Arkansas reservoirs with 3 months of hourly ground-truth data, they found that low-frequency camera sampling (1–4 photos per day) combined with a sufficient number of weekday and weekend days produced effort estimates statistically equivalent to high-frequency baselines. Their practical thresholds: approximately 12 weekday days and 7 weekend days (the exact numbers are reservoir-specific, but these represent reasonable conservative defaults). Photo frequency beyond 4 per day yielded diminishing precision returns.

The function converts these findings into a planning formula: given pilot variance estimates by day type and a target RSE, return the number of camera-days required per day-type stratum and the recommended photo frequency.

### Expected API Shape

```r
creel_n_camera(
  cv_target  = 0.20,
  N_h        = c(weekday = 65, weekend = 28),  # total available days per stratum
  ybar_h     = c(50, 60),   # pilot mean trailer count per day per stratum
  s2_h       = c(400, 500), # pilot variance of count per day per stratum
  photos_per_day = NULL,    # if NULL, returns guidance on photo frequency too
  conf_level = 0.95
)
```

Returns: same shape as `creel_n_effort()` — a named integer vector with one element per stratum plus `"total"`. An attribute `$photo_guidance` provides the Feltz-Middaugh minimum-day thresholds as a reference message.

The function is intentionally parallel to `creel_n_effort()` in signature and output so it integrates naturally with `power_creel()` (which would gain a `mode = "camera_n"` path).

### Table Stakes

| Behavior | Why Expected |
|----------|-------------|
| Accept named `N_h`, `ybar_h`, `s2_h` vectors keyed by day-type stratum | Consistent with `creel_n_effort()` — biologists already have this data shape |
| Return per-stratum and total sampling days required | Matches `creel_n_effort()` output; directly usable in scheduling |
| Apply stratified Cochran (1977) Eq. 5.25 formula internally | Same formula as `creel_n_effort()` — camera counts are sampled the same way as angler counts |
| Warn when computed n_h falls below the Feltz-Middaugh empirical minimums | Prevents users from interpreting a statistically-computed n that is below the field-tested threshold |

### Differentiators

| Behavior | Value |
|----------|-------|
| Photo-frequency guidance output | Feltz-Middaugh show that 4 photos/day is the practical maximum before diminishing returns; providing this as a named attribute helps planners avoid over-processing |
| Integration with `power_creel(mode = "camera_n")` | Unified planning surface; biologists planning camera vs. instantaneous surveys can compare side by side with `compare_designs()` |

### Edge Cases

1. **Pilot data from a different waterbody.** Transferability of `ybar_h` and `s2_h` is the user's responsibility; the function should note in the documentation that pilot data from the same system is strongly preferred.
2. **N_h smaller than the Feltz-Middaugh minimums.** The season is too short for the method. `cli_warn()` recommending supplemental coverage or a different estimator.
3. **Photos per day < 1.** Degenerate input; `cli_abort()`.
4. **Single-stratum design (no weekday/weekend split).** Function should handle `length(N_h) == 1` gracefully — same as `creel_n_effort()`.

### Dependencies on Existing Functions

- **Mirrors:** `creel_n_effort()` — same statistical formula, same output shape
- **Integrates into:** `power_creel()` — a `mode = "camera_n"` branch would call `creel_n_camera()` internally
- **Upstream:** feeds `generate_schedule()` — the day counts returned should be compatible with the schedule generator's `N_h` inputs
- **No new package dependencies** — uses only base R arithmetic; `glmmTMB`/`mice` are not needed here

---

## Feature 3: Mark-Recapture Harvest Estimators

### What It Does

Estimates the total angler population size using mark-recapture methods where **anglers** (not fish) are the marked unit. This addresses the Mode 1 use case from the existing research (Phase 71): physical marks or license plates are recorded at access points (boat launches, parking areas) at the start of a sampling period; the same individuals are re-sighted/checked at the end. The population size estimate N is the number of unique anglers on the water during the period. Multiplying by mean days-fished and mean harvest-per-day gives total harvest.

Hansen and Van Kirk (2018, NAJFM 38:400–410) demonstrated this approach on Pacific salmon and steelhead fisheries in Idaho and found it produced statistically equivalent harvest estimates to traditional instantaneous creel counts at roughly 50% of the vehicle mileage.

Three estimator families are in scope:

**Petersen (single occasion, closed):** Two-sample design. M anglers marked at entry; on exit, n anglers checked, m found marked.

```
N_hat = (M * n) / m                         # Petersen
N_hat_Chapman = ((M+1)*(n+1))/(m+1) - 1    # Chapman bias correction
```

Chapman correction is preferred when m < 7 (small recapture sample).

**Schnabel (multiple occasions, closed):** Cumulative marking across K sampling periods within a day or week. Each period contributes new marks and recaptures. Produces a more precise N when sampling continues across multiple circuits.

```
N_hat_Schnabel = sum(M_i * n_i) / sum(m_i)
```

**Jolly-Seber (open population):** For multi-week seasons where anglers enter and leave the fishery between sampling periods. Estimates both N_t (population size at period t) and apparent survival phi_t. Appropriate when the study spans more than a few days and population closure cannot be assumed.

### Expected API Shape

```r
# Petersen / Chapman
estimate_angler_n(
  M          = 80L,   # marked at first occasion
  n          = 60L,   # checked at second occasion
  m          = 12L,   # recaptured (seen at both)
  method     = c("chapman", "petersen"),
  conf_level = 0.95
)

# Schnabel (multiple occasions)
estimate_angler_n(
  M          = c(80, 95, 110),  # cumulative marks before each occasion
  n          = c(60, 72, 68),   # checked at each occasion
  m          = c(12, 18, 15),   # recaptured at each occasion
  method     = "schnabel",
  conf_level = 0.95
)

# Jolly-Seber (open population, via FSA::mrOpen)
estimate_angler_n_open(
  cap_hist,   # capture-history data frame (one row per marked angler)
  conf_level  = 0.95
)
```

Returns: `creel_estimates` S3 object with the standard `$estimates` tibble and `method = "mark-recapture-petersen"` (or schnabel, jolly-seber). Columns: `estimate` (N_hat), `se`, `ci_lower`, `ci_upper`, `M`, `n`, `m`.

Harvest integration helper:

```r
estimate_mr_harvest(
  N_hat,     # from estimate_angler_n()
  se_N,
  mean_days_fished,
  sd_days_fished,
  n_interviews,
  mean_harvest_per_day,
  sd_harvest_per_day,
  conf_level = 0.95
)
```

Propagates uncertainty from N_hat through to harvest total via delta method, matching the Hansen & Van Kirk workflow.

### Table Stakes

| Behavior | Why Expected |
|----------|-------------|
| Chapman correction as default for small m | Petersen is positively biased when m < 7; Chapman is standard in FSA and fisheries literature |
| Return `creel_estimates` S3 object | Consistent with all other estimators; enables `compare_designs()`, `autoplot()`, and `write_estimates()` on the output |
| Input validation: m <= min(M, n), M > 0, n > 0 | Physical impossibility guards; same pattern as `estimate_exploitation_rate()` |
| `conf_level` argument | Consistent across all estimation functions |

### Differentiators

| Behavior | Value |
|----------|-------|
| `estimate_mr_harvest()` delta-method propagation | Hansen & Van Kirk (2018) explicitly combine N_hat uncertainty with interview-based harvest-per-day uncertainty; this is the step most users will need and is not provided by FSA |
| Schnabel across multiple circuits on the same day | Covers the practical bus-route use case where the creel crew makes multiple loops and accumulates marks |
| `compare_designs()` compatibility | Lets biologists directly compare traditional instantaneous-count effort vs. mark-recapture effort for the same lake |

### Edge Cases

1. **m = 0 (no recaptures).** N is undefined (denominator = 0 in Petersen). `cli_abort()` with a message that zero recaptures prevent estimation; suggest increasing M or n.
2. **m > n (impossible catch).** Data entry error. `cli_abort()`.
3. **m > M (more recaptures than marks released).** Impossible. `cli_abort()`.
4. **Closure assumption violated (Petersen/Schnabel).** If the sampling window spans hours during which anglers arrive or depart, the closed-population assumption is violated. The function cannot detect this automatically; a `cli_warn()` should note that closure is assumed and point users to `estimate_angler_n_open()` for multi-session designs.
5. **Heterogeneous capture probability.** If some anglers (e.g., those with boats vs. bank fishers) are more likely to be checked, the Chapman estimator is biased. Document this limitation; detection requires external information.
6. **Very small m (m = 1 or 2).** CI is extremely wide and Chapman correction is most critical. Flag with a warning.

### Dependencies on Existing Functions

- **Returns:** `creel_estimates` S3 object — same class as `estimate_effort()`, `estimate_exploitation_rate()`, etc.; all existing print/autoplot/write infrastructure applies
- **Build vs. wrap decision:** Build thin wrappers around `FSA::mrClosed()` (Petersen, Schnabel) and `FSA::mrOpen()` (Jolly-Seber) for N estimation; build `estimate_mr_harvest()` natively (no FSA equivalent). The Phase 71 research rated FSA as HIGH wrap potential.
- **`FSA` must be added to Suggests** (CRAN, pure R, no external binary; already identified in Phase 71 research as the correct dependency)
- **`compare_designs()` integration:** Works automatically if return class is `creel_estimates` with a numeric `estimate` column
- **Distinct from `estimate_exploitation_rate()`:** That function already handles the Mode 2 (fish-tagging) path. This feature is the Mode 1 (angler-marking) path. They share the `creel_estimates` return type but answer different questions.

---

## Feature 4: Stratification Audit Tools

### What It Does

Evaluates whether the current stratification scheme (e.g., weekday/weekend day-type strata) is delivering precision gains commensurate with its sampling cost, and flags strata that could be merged or dropped without meaningful loss. This extends the existing `power_creel()` / `compare_designs()` surface rather than replacing it.

The core concept (from the "Optimizing Creel Surveys" chapter, Springer 2025, which references the de Kerckhove body of work and Malvestuto & Knight 1991): the coefficient of variation within vs. across strata measures stratification effectiveness. If within-stratum CV is nearly the same as the unstratified CV, the strata are not capturing meaningful heterogeneity and simplification is warranted. Conversely, if the design effect (DEFF) from stratification is well below 1.0, stratification is actively helping and additional strata may further reduce variance.

Four concrete operations:

1. **Precision audit per stratum:** Report observed CV, n, and RSE for each stratum so biologists see which strata are well-sampled and which are driving imprecision.
2. **Stratum collapse simulation:** Given a proposed merged stratum (e.g., collapse weekday + weekend into a single stratum), estimate the expected CV under the merged design using pilot data. Returns a comparison table.
3. **Power-driven n reallocation:** Given the current total n, use Neyman optimal allocation to show how rebalancing sampling days across strata would change precision. Some strata may receive more days, others fewer.
4. **Design effect reporting:** Report DEFF = Var(stratified) / Var(SRS) for the current design, making it explicit when stratification is not paying its complexity cost.

### Expected API Shape

```r
# Audit current precision per stratum
audit_strata(
  design,         # creel_design object OR named list of stratum statistics
  estimates = NULL,  # creel_estimates from estimate_effort() if available
  target_rse = 0.20
)
# Returns: creel_strata_audit S3 object — data frame one row per stratum +
#   overall row, columns: stratum, n, estimate, se, rse, target_rse, meets_target

# Simulate stratum collapse
simulate_strata_collapse(
  N_h,       # named numeric: total days per stratum
  ybar_h,    # named numeric: pilot mean per stratum
  s2_h,      # named numeric: pilot variance per stratum
  collapse   # named list: new -> old strata, e.g. list(all = c("weekday","weekend"))
)
# Returns: tibble comparing CV before and after collapse for each proposed merge

# Neyman-optimal reallocation
reallocate_strata(
  n_total,   # integer: total sampling budget (days)
  N_h,
  s2_h
)
# Returns: named integer vector of optimal n_h per stratum + current allocation
#   for comparison
```

### Table Stakes

| Behavior | Why Expected |
|----------|-------------|
| Per-stratum RSE and meets-target flag | Most direct answer to "is my design working?"; biologists routinely report this |
| Comparison of proposed merged strata vs. current design | The primary decision point is "can I simplify without losing precision?"; collapse simulation makes this concrete |
| Consistent input shape with `creel_n_effort()` and `power_creel()` | Same `N_h`, `ybar_h`, `s2_h` naming; lowers cognitive load for users already using the planning tools |
| Works on pilot data (pre-survey) and on completed survey estimates (post-survey) | Supports both prospective design evaluation and retrospective review |

### Differentiators

| Behavior | Value |
|----------|-------|
| Neyman-optimal reallocation output | Shows not just whether current design works, but where to invest additional sampling days for maximum precision gain |
| `compare_designs()` compatibility for audit output | Feeding `audit_strata()` results into the existing forest-plot autoplot gives a visual precision-by-stratum comparison |
| Integration with `creel_n_effort()` round-trip | `reallocate_strata()` output can be passed back to `creel_n_effort()` to verify the CV gain from reallocation |
| DEFF reporting | Design effect quantifies the value of stratification in a single interpretable number; not currently surfaced anywhere in the package |

### Edge Cases

1. **Stratum with n = 1.** Variance cannot be estimated from a single observation. `cli_warn()` noting that at least 2 observations per stratum are required for within-stratum variance estimation.
2. **Stratum with n = 0 (never sampled).** This stratum contributes no information. `cli_abort()` or `cli_warn()` depending on whether the function can still compute the audit for other strata.
3. **Proposed collapse leaves only one stratum.** This is a valid choice (unstratified design). The function should handle it and report the expected CV of the unstratified design — that is the correct comparison point.
4. **Pilot data from a different season or lake.** Transferability warning; same caveat as `creel_n_effort()`.
5. **Unequal sampling probabilities across strata.** If strata used non-proportional allocation historically, the pilot variances may reflect unequal effort. The audit should note whether proportional allocation is assumed.
6. **Strata defined by non-temporal variables (e.g., spatial sections).** The formulae are the same; the audit works for any stratification variable. The function documentation should be explicit that "strata" here means any stratification scheme, not only day type.

### Dependencies on Existing Functions

- **Wraps and extends:** `creel_n_effort()` (same formula, inverted to audit rather than plan), `cv_from_n()` (used internally to compute achieved CV), `power_creel()` (audit mode adds a fourth mode to the existing planning surface)
- **Feeds into:** `compare_designs()` — audit results as `creel_estimates`-compatible objects enable visual forest-plot comparison across designs
- **No new package dependencies** — all calculations use base R; `survey` is already imported for DEFF computation if needed (DEFF from a completed survey design uses `survey::deff()` or manual computation from design object)
- **New S3 class `creel_strata_audit`:** Needed for a clean `print()` method that renders the per-stratum table with meets-target highlighting; `autoplot()` method would render a precision-by-stratum bar chart

---

## Cross-Feature Dependencies and Ordering Notes

| Dependency | Implication |
|------------|-------------|
| Feature 1 output feeds Feature 2 indirectly | Imputed counts are more reliable pilot data for `creel_n_camera()` planning inputs |
| Feature 2 is a standalone planning function | No runtime dependency on Features 1, 3, or 4 |
| Feature 3 returns `creel_estimates` | Plugs into `compare_designs()`, `write_estimates()`, and `autoplot()` without new infrastructure |
| Feature 4 wraps `creel_n_effort()` and `cv_from_n()` | Must be implemented after those functions are stable (they already are) |
| Feature 1 requires `glmmTMB` or `pscl` + `mice`/`countimp` | These must be added to Suggests; not in current DESCRIPTION |
| Feature 3 requires `FSA` | Must be added to Suggests; pure R, no external binary |
| Features 2 and 4 require no new dependencies | Base R + existing `checkmate` + `cli` validation patterns |

## Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Automatic imputation applied silently in `est_effort_camera()` | Imputation changes the data; biologists must explicitly call it and see diagnostics | Imputation is a separate explicit step before estimation |
| Jolly-Seber as the default mark-recapture method | Open-population models require capture histories that most creel designs do not produce; defaulting there sets users up for data mismatches | Default to Chapman (closed); expose open-population via a distinct `estimate_angler_n_open()` entry point |
| Stratification collapse that ignores domain knowledge | Purely statistical strata reduction may merge strata that have biological or regulatory meaning (e.g., special regulation weekends) | Return recommendations only; user makes the final merge decision |
| Automatic optimal reallocation without a budget constraint | Without a fixed `n_total`, Neyman allocation is undefined | Always require `n_total` as an explicit input to `reallocate_strata()` |

## Sources

- Afrifa-Yamoah, E., Mueller, U.A., Osei, F.B., Adetutu, E.M. 2020. Imputation of missing data from time-lapse cameras used in recreational fishing surveys. ICES Journal of Marine Science 77(7-8):2984–2999. https://academic.oup.com/icesjms/article/77/7-8/2984/5998351 (HIGH confidence — primary source, peer-reviewed)

- Hartill, B.W., Payne, G.W., Rush, N., Bian, R. 2016. Bridging the temporal gap: Continuous and cost-effective monitoring of dynamic recreational fisheries by web cameras and creel surveys. Fisheries Research 183:488–497. https://www.researchgate.net/publication/304357273 (HIGH confidence — primary source, peer-reviewed)

- Feltz, N.G. and Middaugh, C.R. 2025. Improving efficiency of estimating angler effort using low-frequency time-lapse camera data. North American Journal of Fisheries Management 45(2):322. https://academic.oup.com/najfm/article-abstract/45/2/322/8128941 (HIGH confidence — primary source, peer-reviewed, directly cited in milestone scope)

- Hansen, J.M. and Van Kirk, R.W. 2018. A Mark-Recapture-Based Approach for Estimating Angler Harvest. North American Journal of Fisheries Management 38:400–410. https://onlinelibrary.wiley.com/doi/abs/10.1002/nafm.10038 (HIGH confidence — primary source, peer-reviewed, directly cited in milestone scope)

- de Kerckhove / Springer 2025. Optimizing Creel Surveys. Chapter 13 in recreational fisheries methods volume. https://link.springer.com/chapter/10.1007/978-3-031-99739-6_13 (MEDIUM confidence — identified via search; chapter content not fully verifiable without access; key stratification CV concept well-supported by broader literature)

- FSA package — mrClosed(), mrOpen(), capHistSum(). https://rdrr.io/cran/FSA/man/mrClosed.html (HIGH confidence — CRAN package, well-documented, matches Phase 71 research recommendation)

- glmmTMB package — zero-inflated GLMM. https://cran.r-project.org/web/packages/glmmTMB/vignettes/glmmTMB.pdf (HIGH confidence — CRAN package, stable, widely used for ecological count data)

- countimp package — MICE-based imputation for zero-inflated count data. https://github.com/kkleinke/countimp (MEDIUM confidence — GitHub package, extends mice, not on CRAN; pscl + mice is the CRAN-only alternative)

- Phase 71 Analytical Extensions Research, tidycreel project. /Users/cchizinski2/Dev/tidycreel/.planning/milestones/M022-phases/71-future-analytical-needs/71-ANALYTICAL-EXTENSIONS-RESEARCH.md (HIGH confidence — prior project research, verified against primary sources)
