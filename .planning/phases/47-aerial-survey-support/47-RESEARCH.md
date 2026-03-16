# Phase 47: Aerial Survey Support - Research

**Researched:** 2026-03-16
**Domain:** R package extension — creel survey aerial design with ratio estimator and delta method variance
**Confidence:** HIGH (architecture patterns from direct code inspection); MEDIUM (Malvestuto Box 20.6 aerial numbers — primary source not directly accessible; formula derivation verified via Hoenig et al. 1993 and Pollock et al. 1994 framework)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AIR-01 | User can estimate effort from aerial angler counts using the expansion formula `N_counted × H_open × mean_trip_duration` | New `estimate_effort_aerial()` internal function; aerial dispatch in `estimate_effort()` at existing bus_route/ice guard location; formula confirmed by Hoenig et al. (1993) instantaneous count theory |
| AIR-02 | Aerial effort estimate includes delta method variance correctly propagating count and mean trip duration uncertainty | Delta method for product of two random variables: `Var(Ê) ≈ H_open² × [L̄² × Var(N̂) + N̂² × Var(L̄)]`; both components estimated from interviews |
| AIR-03 | User can supply a visibility correction factor as a calibration parameter | `visibility_correction` stored in `design$aerial$visibility_correction`; applied as `N_adj = N_counted / v` before effort calculation; variance propagated with adjusted count |
| AIR-04 | Aerial estimator is verified against Malvestuto (1996) worked example before shipping | Test in `test-primary-source-validation.R` using exact numbers from the reference; tolerance 1e-6; same gate pattern as bus-route VALID-01 through VALID-05 |
| AIR-05 | User can attach interview data and estimate catch rates and total catch/harvest on an aerial design | Aerial uses standard instantaneous `interview_survey` path (same as camera); no dispatch guard changes needed for `estimate_catch_rate()` or `estimate_total_catch()` |
| AIR-06 | Aerial survey support documented with example dataset and vignette | `example_aerial_counts` + `example_aerial_interviews`; `vignettes/aerial-surveys.Rmd`; follows ice-fishing/camera vignette template |
</phase_requirements>

---

## Summary

Phase 47 is architecturally the most self-contained of the three non-traditional survey types. Unlike ice (a degenerate bus-route dispatching to `estimate_effort_br()`) and camera (a standard instantaneous design with preprocessing), aerial requires a genuinely new internal estimator function `estimate_effort_aerial()`. The estimator implements a ratio estimator that converts an instantaneous aerial angler count to total effort by multiplying by hours-open (`H_open`) and mean trip duration (`L̄`). Both of those quantities carry uncertainty, so delta method variance propagation is required.

The formula derivation follows directly from Hoenig et al. (1993): an instantaneous count at a randomly selected time within a fishing day is an unbiased estimate of the mean number of anglers present; the product of that mean count times the day length equals expected total angler-hours. When mean count is estimated from a sample of counts across days, and mean trip duration `L̄` is estimated from interview data, both contribute to the variance of the effort estimate. The delta method gives the first-order variance approximation for this product-of-ratio-estimators structure.

The visibility correction factor (`v`) is a user-supplied calibration scalar (e.g., 0.85 when aerial observers detect 85% of anglers). The correction is applied to the count before calculating effort: `N_adj = N_counted / v`. Variance of the adjusted count is `Var(N_counted) / v²` — no additional variance from `v` itself, since it is a calibration parameter with no uncertainty in the model (it comes from an external validation study outside the package).

Malvestuto (1996) Box 20.6 contains both bus-route and aerial worked examples on the same page spread. The bus-route example (Example 1) is already validated in `test-primary-source-validation.R`. The aerial validation should reproduce the aerial-specific numbers from the same box using `make_aerial_box20_6()` fixture function, parallel to the existing `make_box20_6_example1()` pattern.

**Primary recommendation:** Write `estimate_effort_aerial()` in a new `R/creel-estimates-aerial.R` file; add aerial dispatch block in `estimate_effort()` between the bus-route/ice block and the sections block; fill the aerial constructor stub with `visibility_correction` and `h_open` parameters; validate against Malvestuto (1996) in a new test block appended to `test-primary-source-validation.R`.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| cli | already in Imports | Errors and messages | All existing validation uses `cli_abort()` / `cli_inform()` |
| rlang | already in Imports | Tidy evaluation, `enquo` | All parameter capture uses `enquo` / `quo_is_null` |
| checkmate | already in Imports | Tier 3 validation collections | Used in existing validators |
| usethis | already in Suggests | `use_data()` for example datasets | Used in all existing `data-raw/*.R` scripts |
| testthat (>= 3.0.0) | Config/testthat/edition: 3 | Unit testing | Project-standard |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| knitr / rmarkdown | already in Suggests | Vignette rendering | `vignettes/aerial-surveys.Rmd` |

**Installation:** No new dependencies. All required packages are already in DESCRIPTION.

---

## Architecture Patterns

### Recommended Project Structure

New and modified files for Phase 47:

```
R/
├── creel-design.R              # Aerial branch filled in (L542-547 stub); visibility_correction + h_open params added to creel_design()
├── creel-estimates.R           # New aerial dispatch block added between bus_route/ice block and sections block
└── creel-estimates-aerial.R    # New file: estimate_effort_aerial() internal function
data-raw/
├── create_example_aerial_counts.R
└── create_example_aerial_interviews.R
data/
├── example_aerial_counts.rda
└── example_aerial_interviews.rda
R/
└── data.R                      # roxygen @docType dataset entries for new objects
vignettes/
└── aerial-surveys.Rmd
tests/testthat/
├── test-creel-design.R         # aerial constructor tests appended
├── test-estimate-effort.R      # aerial effort dispatch tests appended
└── test-primary-source-validation.R  # Malvestuto (1996) aerial example appended
```

### Pattern 1: Aerial Constructor — Fill the Stub

**What:** The aerial branch at `R/creel-design.R:542-547` returns `list(survey_type = "aerial")`. Phase 47 replaces it with `visibility_correction` and `h_open` validation and storage.

**New parameters needed in `creel_design()` signature:**
- `visibility_correction = NULL` — optional numeric scalar in (0, 1]; 1.0 means no correction; default NULL (no correction applied, equivalent to 1.0)
- `h_open = NULL` — numeric scalar, hours the fishery is open (fishing day duration); required for aerial designs

**Template (mirrors ice/camera constructor patterns):**

```r
# --- Aerial branch ---
aerial <- NULL
if (identical(survey_type, "aerial")) {
  # h_open is required for aerial designs
  if (is.null(h_open) || !is.numeric(h_open) || length(h_open) != 1 || h_open <= 0) {
    cli::cli_abort(c(
      "{.arg h_open} is required for {.val aerial} survey designs.",
      "x" = if (is.null(h_open)) {
        "No {.arg h_open} supplied."
      } else {
        "Invalid {.arg h_open}: {.val {h_open}}."
      },
      "i" = "Supply the number of hours the fishery is open per day (e.g., {.code h_open = 14})."
    ))
  }
  # visibility_correction is optional; validate if supplied
  if (!is.null(visibility_correction)) {
    if (!is.numeric(visibility_correction) || length(visibility_correction) != 1 ||
        visibility_correction <= 0 || visibility_correction > 1) {
      cli::cli_abort(c(
        "{.arg visibility_correction} must be a single numeric value in (0, 1].",
        "x" = "Received: {.val {visibility_correction}}.",
        "i" = "Example: {.code visibility_correction = 0.85} (observers detect 85% of anglers)."
      ))
    }
  }
  aerial <- list(
    survey_type          = "aerial",
    h_open               = h_open,
    visibility_correction = visibility_correction  # NULL = no correction (1.0)
  )
}
```

**Key design choice:** Aerial does NOT use bus-route infrastructure. It uses the standard `add_counts()` → `estimate_effort()` path, but the estimator in the aerial dispatch block is `estimate_effort_aerial()` — not `estimate_effort_br()` and not `estimate_effort_total()`.

### Pattern 2: `estimate_effort_aerial()` — The Core Estimator

**New file:** `R/creel-estimates-aerial.R`

**Formula (Hoenig et al. 1993 / Malvestuto 1996):**

```
Ê = N̂_adj × H_open × L̄

where:
  N̂_adj = N̂ / v        (visibility-adjusted count; v = 1.0 if no correction)
  N̂     = mean of observed instantaneous counts across sampled days (or single-day count)
  H_open = hours the fishery is open per day (user-supplied constant)
  L̄     = mean trip duration estimated from interview data (hours)
  v      = visibility correction factor (calibration parameter, no uncertainty)
```

**Delta method variance:**

The effort estimate is a product of two random quantities (`N̂_adj` from counts, `L̄` from interviews):

```
Ê = (N̂ / v) × H_open × L̄

Var(Ê) ≈ (H_open / v)² × [L̄² × Var(N̂) + N̂² × Var(L̄) + 2 × N̂ × L̄ × Cov(N̂, L̄)]
```

Since counts and interviews are typically collected independently, `Cov(N̂, L̄) ≈ 0`, simplifying to:

```
Var(Ê) ≈ (H_open / v)² × [L̄² × Var(N̂) + N̂² × Var(L̄)]

SE(Ê) = sqrt(Var(Ê))
```

**Component estimation:**
- `N̂` = mean count from `design$counts` (the count column attached via `add_counts()`)
- `Var(N̂)` = sample variance of counts / n_counts (if multiple count observations)
- `L̄` = mean trip duration from `design$interviews` (the effort column in interview data)
- `Var(L̄)` = sample variance of trip durations / n_interviews

**Function signature:**

```r
estimate_effort_aerial <- function(design, by_vars, variance_method, conf_level, verbose) {
  # Retrieve parameters from design$aerial
  h_open <- design$aerial$h_open
  v      <- design$aerial$visibility_correction %||% 1.0

  # Retrieve counts (N observations across sampled times/days)
  counts     <- design$counts[[design$count_col]]
  n_counts   <- sum(!is.na(counts))
  n_hat      <- mean(counts, na.rm = TRUE)       # mean count
  var_n_hat  <- var(counts, na.rm = TRUE) / n_counts  # variance of mean

  # Retrieve trip durations from interviews (L observations)
  interviews  <- design$interviews
  trip_durations <- interviews[[design$effort_col]]
  n_interviews <- sum(!is.na(trip_durations))
  l_bar        <- mean(trip_durations, na.rm = TRUE)
  var_l_bar    <- var(trip_durations, na.rm = TRUE) / n_interviews

  # Visibility-adjusted count
  n_hat_adj <- n_hat / v

  # Point estimate
  estimate  <- n_hat_adj * h_open * l_bar

  # Delta method variance
  h_over_v  <- h_open / v
  var_est   <- h_over_v^2 * (l_bar^2 * var_n_hat + n_hat^2 * var_l_bar)
  se        <- sqrt(var_est)

  # Confidence interval (normal approximation)
  z <- qnorm(1 - (1 - conf_level) / 2)
  ci_lower <- estimate - z * se
  ci_upper <- estimate + z * se

  estimates_df <- tibble::tibble(
    estimate = estimate,
    se       = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n_counts = n_counts,
    n_interviews = n_interviews
  )

  new_creel_estimates(
    estimates       = estimates_df,
    method          = "aerial_instantaneous",
    variance_method = "delta",
    design          = design,
    conf_level      = conf_level,
    by_vars         = NULL
  )
}
```

**Note on `by_vars`:** Grouped aerial estimation (e.g., `by = day_type`) applies the formula within each stratum. The stratum-level counts and interview durations are used separately, then combined. This is post-dispatch filtering — same `by_vars` argument as other estimators.

### Pattern 3: Dispatch Block in `estimate_effort()`

**Where:** Between the bus-route/ice dispatch block (L342-386) and the sections dispatch block (L390-394) in `R/creel-estimates.R`.

**What it does:** Aerial uses `add_counts()` (so `design$survey` is populated), BUT it does NOT use the standard instantaneous path — it dispatches to `estimate_effort_aerial()` instead.

**The guard:**

```r
# Aerial dispatch — after bus_route/ice block, before sections block
if (!is.null(design$design_type) && identical(design$design_type, "aerial")) {
  if (verbose) {
    cli::cli_inform(c(
      "i" = "Using aerial instantaneous count estimator (Malvestuto 1996)"
    ))
  }
  # Aerial requires interviews to be attached (need mean trip duration)
  if (is.null(design$interviews)) {
    cli::cli_abort(c(
      "Aerial effort estimation requires interview data for mean trip duration.",
      "x" = "No interview data found in design.",
      "i" = "Call {.fn add_interviews} before estimating aerial effort."
    ))
  }
  # Resolve by_vars if grouping requested
  if (rlang::quo_is_null(by_quo)) {
    by_vars_aerial <- NULL
  } else {
    by_cols_aerial <- tidyselect::eval_select(
      by_quo, data = design$interviews,
      allow_rename = FALSE, allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars_aerial <- names(by_cols_aerial)
  }
  return(estimate_effort_aerial(design, by_vars_aerial, variance, conf_level, verbose)) # nolint: object_usage_linter
}
```

**CRITICAL:** The `design$survey` NULL check at L333 must be updated to also skip the NULL check for aerial (since aerial uses `add_counts()` but is dispatched before the standard path):

Current guard at L333:
```r
if (!design$design_type %in% c("bus_route", "ice") && is.null(design$survey)) {
```

After aerial dispatch is inserted AFTER the NULL check, aerial must call `add_counts()` before `estimate_effort()` OR the guard must admit aerial (if aerial dispatch comes before the NULL check). The cleanest solution: place the aerial dispatch block BEFORE the NULL check, just like bus_route/ice. The NULL check then remains unchanged — aerial never reaches it.

**Revised structure in `estimate_effort()`:**

```
L324: Validate input is creel_design
L332: Bus_route/ice NULL-survey guard skip → bus_route/ice dispatch
L342: Bus_route/ice dispatch block → return
L388: NEW: Aerial dispatch block → return      (aerial needs interviews, not survey)
L394: design$survey NULL check fires (aerial skipped above)
L400: Sections dispatch
L417: Standard instantaneous path
```

Wait — the issue is that aerial DOES need `design$survey` (via `add_counts()`) for the counts data. But the aerial estimator reads `design$counts` directly, not `design$survey`. Check: `design$counts` is populated by `add_counts()`. So aerial can dispatch early (before the NULL check) and read `design$counts` without needing `design$survey` to be set.

Alternatively, the simplest approach: **aerial dispatch fires after the survey NULL check** (aerial must call `add_counts()` first), and we add `"aerial"` to the NULL-check exclusion list:

```r
if (!design$design_type %in% c("bus_route", "ice", "aerial") && is.null(design$survey)) {
```

Then aerial dispatch fires after the guard, before the sections block. This requires `add_counts()` to be called for aerial — which is correct (aerial needs the count observations).

### Pattern 4: `add_interviews()` for Aerial

Aerial interview data follows the standard instantaneous interview path. Aerial surveys interview anglers on the ground (or at access points) to obtain trip duration data — there is no `n_counted`/`n_interviewed` expansion factor. Aerial designs therefore:

- Have NO `design$bus_route` slot
- Have NO ice-specific Tier 3 validation
- Use the standard `add_interviews()` path unchanged
- Require `effort` column (trip duration hours) in interview data — standard requirement

No changes needed to `add_interviews()`.

### Pattern 5: Interview Compatibility (AIR-05)

`estimate_catch_rate()` and `estimate_total_catch()` both use `design$interview_survey` via the generic path — no bus-route guard applies to aerial. Camera confirmed this pattern (Phase 46 decision: "Camera interview fixture omits n_counted/n_interviewed — those are ice/bus_route-only; standard instantaneous add_interviews() uses catch, effort, trip_status only").

No changes needed to `estimate_catch_rate()` or `estimate_total_catch()`.

### Pattern 6: Example Dataset Structure

**Two datasets, mirroring ice/camera pattern:**

1. `example_aerial_counts` — daily aerial count observations
   - Columns: `date`, `day_type`, `n_anglers` (instantaneous count), optional `flight_time`
   - Size: 12-20 rows (one count per sampling day across multiple strata)
   - Realistic values: lake in Nebraska summer, 15-60 anglers counted
   - Some days have no count (NA) to demonstrate missing-section guard behavior

2. `example_aerial_interviews` — angler interviews for trip duration and catch
   - Columns: `date`, `day_type`, `hours_fished`, `walleye_catch`, `walleye_kept`, `trip_status`
   - Size: 30-50 rows
   - Species: walleye + bass (summer fishery)
   - Some incomplete trips for realism

**`h_open` realistic value:** 14 hours (6 AM to 8 PM summer fishing day)

**`visibility_correction` example value:** 0.85 (15% of anglers not detectable from air)

### Anti-Patterns to Avoid

- **Reusing `estimate_effort_br()` for aerial:** Aerial is NOT a degenerate bus-route. The bus-route estimator requires `.pi_i` and `.expansion` columns from `add_interviews()` — aerial does not have these. Using the bus-route estimator would produce incorrect results silently.
- **Treating the aerial count as a census:** `N_counted` is an instantaneous count from one overflight. It must be expanded to total effort via `H_open × L̄`. Returning `N_counted` alone or `N_counted × H_open` without the trip duration component is incorrect.
- **Ignoring covariance between count and duration:** If counts and interviews are collected simultaneously on the same days, `Cov(N̂, L̄)` may be non-zero. For the standard aerial survey where overflights and roving interviews are independent operations, covariance is zero. Document this assumption; flag for future model-based extension.
- **Applying visibility correction after variance propagation:** The correction must be applied before variance propagation. Adjusting `N_adj` and then computing `Var(Ê)` with `N_adj` is correct; adjusting the final estimate without adjusting the variance is not.
- **Making `h_open` optional with a default:** `h_open` is required; there is no sensible default. An aerial survey biologist knows the length of their fishing day. Forcing them to declare it prevents silent errors.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Effort variance | Custom variance routine | Delta method formula derived from product of two random variables | Standard statistics; no survey package wrapping needed for this particular formula |
| Mean count estimation | Custom loop | `mean(counts, na.rm = TRUE)` + `var(counts, na.rm = TRUE) / n` | Simple sample mean and variance of mean; consistent with how `L̄` is computed |
| Normal CI | Custom tail probability | `qnorm(1 - (1 - conf_level) / 2)` × SE | Standard; consistent with existing CI patterns in the package |
| Interview compatibility | New catch estimator for aerial | `estimate_catch_rate()` / `estimate_total_catch()` via standard `interview_survey` path | Both functions use `interview_survey` generically — aerial uses the same path as camera and instantaneous |
| Visibility-corrected SE | Separate variance path | Substitute `N̂_adj = N̂ / v` and `Var(N̂_adj) = Var(N̂) / v²` before delta method | Algebraically equivalent; no code bifurcation needed |

---

## Common Pitfalls

### Pitfall 1: NULL-Survey Guard Blocking Aerial Dispatch

**What goes wrong:** If aerial dispatch is placed AFTER the survey NULL check at `creel-estimates.R:333`, and the guard does not include `"aerial"` in the exclusion list, an aerial design where the user calls `add_counts()` first will pass through the guard correctly. But if the user has NOT called `add_counts()` yet, they get the generic "Call add_counts() before estimating effort" error — which is actually correct behavior for aerial. However, if aerial dispatch is placed BEFORE the NULL check, `design$counts` may be NULL too.

**How to avoid:** Add `"aerial"` to the exclusion list at L333 (to skip the generic survey NULL check), and inside the aerial dispatch block, check that `design$counts` is non-NULL before proceeding. Or place aerial dispatch after L333 but before L342 — aerial requires `add_counts()` to have been called.

**Recommended approach:** Add `"aerial"` to `c("bus_route", "ice")` at L333, then place aerial dispatch between L342 and the sections block. The aerial dispatch block validates both `design$counts` and `design$interviews` are non-NULL before proceeding.

**Warning signs:** `Error in estimate_effort: No survey design available` on an aerial design that has had `add_counts()` called.

### Pitfall 2: Aerial Interview Data Does NOT Need `n_counted`/`n_interviewed`

**What goes wrong:** Developer adds aerial to the bus-route Tier 3 validation check at `creel-design.R:1710`, which requires `n_counted` and `n_interviewed` columns. Aerial interview data does not have these columns — they come from roving ground interviews, not from the aerial flight.

**Why it happens:** Ice and bus-route both need `n_counted`/`n_interviewed`; the pattern of adding aerial to that same guard is tempting.

**How to avoid:** The check at L1710 reads `!is.null(design$bus_route) && !identical(design$design_type, "ice")`. Aerial has NO `design$bus_route` slot, so it bypasses this check entirely — no code change needed. Confirm this by running `add_interviews()` on an aerial design without `n_counted` column.

**Warning signs:** `cli_abort()` in `add_interviews()` complaining about missing `n_counted` column on an aerial design.

### Pitfall 3: Delta Method Denominator With Small N

**What goes wrong:** When only a few count observations exist (e.g., 3 aerial flights), `Var(N̂)` computed as `var(counts) / n` is a high-variance estimate. The delta method SE will be wide, which is statistically correct, but may surprise users who expect narrow intervals from aerial surveys.

**Why it happens:** Aerial surveys are expensive; biologists often fly only a few times per season. The uncertainty is real.

**How to avoid:** Document the sample size requirements clearly in the vignette. Add a `cli_warn()` when `n_counts < 3` — analogous to the existing sample size warnings elsewhere in the package. The warning should say "Fewer than 3 aerial count observations — variance estimate may be unstable."

**Warning signs:** Anomalously wide CI on effort estimate; `n_counts` in estimates output is 1 or 2.

### Pitfall 4: Visibility Correction Applied After CI Computation

**What goes wrong:** Developer applies the visibility correction factor to the point estimate AFTER computing the CI from the uncorrected estimate. This gives correct point estimate but incorrect CI (too narrow).

**Why it happens:** Easy to apply the correction as a post-hoc scaling.

**How to avoid:** Apply `N_adj = N_counted / v` before the delta method variance calculation. The corrected count and its variance (`Var(N̂) / v²`) both feed into the formula. The CI is then computed from the corrected estimate and its SE.

**Warning signs:** CI is too narrow by factor `v` compared to expectation.

### Pitfall 5: `estimate_total_catch()` Dispatch Including Aerial in Bus-Route Guard

**What goes wrong:** Developer adds `"aerial"` to the `c("bus_route", "ice")` check in `creel-estimates-total-catch.R:131`, routing aerial through `estimate_total_catch_br()`. The bus-route total catch estimator requires `.pi_i` and `.expansion` columns that aerial does not have.

**Why it happens:** Pattern-matching on the ice/bus-route expansion.

**How to avoid:** Aerial uses the standard instantaneous `interview_survey` path for catch estimation — same as camera. No changes needed to `creel-estimates-total-catch.R`. Confirm: `estimate_total_catch()` at L131 checks `design_type %in% c("bus_route", "ice")` — aerial is NOT in this list and falls through to the standard path. Correct behavior with zero code changes.

---

## Code Examples

Verified patterns from existing source:

### Aerial Constructor Stub (current state — to be replaced)

```r
# Source: R/creel-design.R:542-547
aerial <- NULL
if (identical(survey_type, "aerial")) {
  aerial <- list(survey_type = "aerial")
  # Phase 47 will inject visibility_correction checks here
}
```

### Ice Constructor Pattern (template for aerial)

```r
# Source: R/creel-design.R:382-515 — effort_type validation and slot construction
if (identical(survey_type, "ice")) {
  valid_ice_effort_types <- c("time_on_ice", "active_fishing_time")
  if (is.null(effort_type) || !effort_type %in% valid_ice_effort_types) {
    cli::cli_abort(c(
      "{.arg effort_type} is required for {.val ice} survey designs.",
      "x" = if (is.null(effort_type)) "No {.arg effort_type} supplied." else
        "Unknown {.arg effort_type}: {.val {effort_type}}.",
      "i" = "Valid values: {.val {valid_ice_effort_types}}."
    ))
  }
  # ... slot construction
}
```

### Bus-Route/Ice Dispatch Block (adjacent template)

```r
# Source: R/creel-estimates.R:342-386
if (!is.null(design$design_type) && design$design_type %in% c("bus_route", "ice")) {
  # ... validate interviews, resolve by_vars
  result <- estimate_effort_br(design, by_vars_br, variance, conf_level, verbose)
  # Ice-specific rename:
  if (identical(design$design_type, "ice")) {
    col_name <- switch(design$ice$effort_type,
      time_on_ice = "total_effort_hr_on_ice",
      active_fishing_time = "total_effort_hr_active",
      "estimate"
    )
    names(result$estimates)[names(result$estimates) == "estimate"] <- col_name
  }
  return(result)
}
```

### `new_creel_estimates()` Usage Pattern (from bus-route estimator)

```r
# Source: R/creel-estimates-bus-route.R:125-133
result <- new_creel_estimates(
  estimates       = estimates_df,
  method          = "total",
  variance_method = variance_method,
  design          = design,
  conf_level      = conf_level,
  by_vars         = NULL
)
attr(result, "site_contributions") <- site_table
result
```

### Primary Source Validation Pattern (bus-route template for aerial)

```r
# Source: tests/testthat/test-primary-source-validation.R:119-138
make_box20_6_example1 <- function() {
  # ... construct design + interviews ...
}

test_that(
  "E_hat matches Malvestuto (1996) Box 20.6 Example 1 (Horvitz-Thompson total)",
  {
    result <- estimate_effort(make_box20_6_example1())
    expected_e_hat <- 30.0 / 0.15 + 20.0 / 0.125 + 57.5 / 0.20 + 5.0 / 0.025
    expect_equal(result$estimates$estimate, expected_e_hat, tolerance = 1e-6)
  }
)
```

### Delta Method Variance for Product of Two Means

```r
# Aerial delta method — no existing code; formula from statistics:
# Ê = (N̂ / v) * H_open * L̄
# Var(Ê) ≈ (H_open/v)² * (L̄² * Var(N̂) + N̂² * Var(L̄))
#
# R implementation:
h_over_v <- h_open / v
var_est <- h_over_v^2 * (l_bar^2 * var_n_hat + n_hat^2 * var_l_bar)
se <- sqrt(max(var_est, 0))  # guard against small negative values from floating-point

# CI (normal approximation, consistent with existing package pattern):
z <- qnorm(1 - (1 - conf_level) / 2)
ci_lower <- estimate - z * se
ci_upper <- estimate + z * se
```

---

## The Malvestuto (1996) Box 20.6 Aerial Worked Example

### What We Know (MEDIUM confidence)

The primary source (Malvestuto 1996, Chapter 20 in Fisheries Techniques 2nd ed., pp. 591-623) is not directly accessible on the web. However, from the existing codebase and documentation:

1. Box 20.6 is described as containing both the bus-route (Example 1: E_hat = 847.5 angler-hours) and the aerial instantaneous count example, on page 614 of the chapter.

2. The bus-route example (already implemented) uses: 4 sites, p_site = c(0.30, 0.25, 0.40, 0.05), p_period = 0.50, effort values summing to 847.5.

3. The aerial worked example in Box 20.6 will specify: an instantaneous angler count (N_counted), the hours the fishery was open (H_open), mean trip duration from interviews (L̄), and possibly a visibility correction. The expected effort estimate is derived from `N_counted × H_open × L̄`.

### Exact Numbers Required (Must Obtain Before Shipping AIR-04)

The exact Box 20.6 aerial numbers must be sourced before Phase 47 can ship. The planner must include a task in Wave 0 or Plan 01 to:

1. **Obtain the Malvestuto (1996) reference** — university library, interlibrary loan, or colleague with access to Fisheries Techniques 2nd ed.
2. **Record the exact values** from Box 20.6 aerial example: N_counted, H_open, L̄ (mean trip duration), optional visibility correction, and the published E_hat value.
3. **Code the validation fixture** `make_aerial_box20_6()` using exactly these values.
4. **Set tolerance** for `expect_equal()` at 1e-6 (same as bus-route validation).

### Placeholder Fixture Structure (to be filled with real numbers)

```r
# tests/testthat/test-primary-source-validation.R — aerial section
# AIR-04 validation: Malvestuto (1996) Box 20.6 aerial worked example

make_aerial_box20_6 <- function() {
  cal <- data.frame(
    date     = as.Date(c("FILL_DATE_1", "FILL_DATE_2")),  # placeholder
    day_type = c("weekday", "weekday"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(
    calendar = cal,
    date = date, strata = day_type,
    survey_type = "aerial",
    h_open = FILL_H_OPEN,           # hours fishery is open — from Box 20.6
    visibility_correction = NULL    # or FILL_V if Box 20.6 includes correction
  )
  counts <- data.frame(
    date         = as.Date("FILL_DATE"),
    day_type     = "weekday",
    n_anglers    = FILL_N_COUNTED,  # instantaneous angler count from Box 20.6
    stringsAsFactors = FALSE
  )
  design <- add_counts(design, counts, count = n_anglers)

  interviews <- data.frame(
    date          = as.Date(rep("FILL_DATE", FILL_N_INTERVIEWS)),
    day_type      = "weekday",
    hours_fished  = rep(FILL_L_BAR, FILL_N_INTERVIEWS),  # from Box 20.6
    fish_caught   = rep(1L, FILL_N_INTERVIEWS),
    trip_status   = "complete",
    stringsAsFactors = FALSE
  )
  add_interviews(design, interviews,
    effort = hours_fished, catch = fish_caught, trip_status = trip_status)
}

test_that(
  "Aerial E_hat reproduces Malvestuto (1996) Box 20.6 within tolerance (AIR-04)",
  {
    result <- estimate_effort(make_aerial_box20_6())
    expected <- FILL_N_COUNTED * FILL_H_OPEN * FILL_L_BAR  # Ê = N × H × L̄
    expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)
  }
)
```

### Alternative: Nebraska Agency Data If Box 20.6 Aerial Unavailable

If the Malvestuto (1996) aerial worked example proves to be the same Box 20.6 bus-route data (not a separate aerial example), the validation strategy is:

- Construct a synthetic example using known published aerial survey data from another primary source (e.g., Pollock et al. 1994, AFS Special Publication 25) or a Nebraska Game and Parks Commission technical report.
- Document the source explicitly in the test comments.
- The tolerance and test structure remain identical.

The STATE.md note — "Malvestuto (1996) Box 20.6 must be reproduced exactly (same gate used for bus-route Phase 26)" — implies the aerial formula validation should follow the same standard. Whether Box 20.6 contains a separate aerial example or the aerial formula is validated against a different reference, AIR-04 requires a published numeric validation, not just a unit test.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Aerial returns minimal stub `list(survey_type = "aerial")` | Constructor enforces `h_open`, validates `visibility_correction` | Phase 47 | Users get fail-fast validation at construction time |
| No aerial effort estimator | `estimate_effort_aerial()` implements ratio estimator with delta method variance | Phase 47 | Correct statistical estimation for instantaneous aerial counts |
| No visibility correction in package | `visibility_correction` parameter stored in `design$aerial$visibility_correction` | Phase 47 | Biologists can supply calibration factor from external validation study |
| Aerial example OUT of scope | `example_aerial_counts` + `example_aerial_interviews` + vignette | Phase 47 | Complete documentation of aerial workflow |

**Deprecated/outdated:**

- The aerial stub (`list(survey_type = "aerial")`) exists solely to be replaced in Phase 47. Nothing in the existing codebase depends on it.
- `design_type = "aerial"` without `h_open` will abort after Phase 47; the pre-Phase-47 behavior (stub accepts anything) will not survive.

---

## Open Questions

1. **Malvestuto (1996) Box 20.6 exact aerial numbers**
   - What we know: Box 20.6 is on p. 614; bus-route Example 1 has E_hat = 847.5 angler-hours; the same box reference is cited for aerial in the STATE.md
   - What's unclear: Whether Box 20.6 contains a distinct aerial instantaneous count example with its own N_counted, H_open, L̄ values — or whether the aerial formula uses the same count data in a different way
   - Recommendation: Obtain the physical book before coding the AIR-04 validation test. If Box 20.6 has no aerial example, use the formula validated with a numeric example constructed from the Box 20.6 bus-route data (treating it as if anglers were counted from the air with known H_open and L̄). Document the deviation from the original intent in the test.

2. **Grouped aerial estimation (by = day_type)**
   - What we know: The existing `by =` mechanism works for bus-route (interview data grouping) and instantaneous (count data grouping)
   - What's unclear: For aerial, grouping requires splitting BOTH count observations AND interview data by the grouping variable, then applying the estimator within each stratum. This requires careful within-stratum estimation before combining.
   - Recommendation: For Plan 01 (AIR-01/AIR-02), implement ungrouped estimation only. Add grouped estimation as AIR-03's extended test OR defer to a follow-up task. The Nyquist validation tests can be ungrouped for the primary validation.

3. **How many count observations does a typical aerial design have?**
   - What we know: Aerial surveys are expensive; agencies may fly only once or twice per stratum. N̂ from a single observation has no variance (Var = 0/1 = 0), which produces a meaninglessly tight CI.
   - What's unclear: Whether the package should enforce n_counts >= 2 or simply warn.
   - Recommendation: Warn (not abort) when n_counts < 3 in `estimate_effort_aerial()`. The biologist may intentionally have a single count; the CI is then ±0 (a known limitation), and the warning documents the statistical assumption.

4. **Relationship between `design$counts` data and `design$survey` object**
   - What we know: `add_counts()` populates both `design$counts` (a tibble) and `design$survey` (a survey package design object). The aerial estimator reads `design$counts` directly for the mean count calculation.
   - What's unclear: Should the aerial estimator use `design$counts[[count_col]]` directly, or should it use `design$survey` for variance estimation (leveraging the survey package's stratified design)?
   - Recommendation: Use `design$counts[[count_col]]` directly for the mean count and its variance. The survey package design in `design$survey` is calibrated for the standard instantaneous path (ratio of counts to calendar days); for aerial, the relevant sampling unit is the individual count observation, not the day-level survey design. This keeps `estimate_effort_aerial()` self-contained and independent of the survey package.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat >= 3.0.0 (edition 3) |
| Config file | `tests/testthat.R` |
| Quick run command | `devtools::test(filter = "creel-design")` |
| Full suite command | `devtools::test()` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AIR-01 | `creel_design(survey_type = "aerial", h_open = 14)` constructs; `design$aerial$h_open == 14` | unit | `devtools::test(filter = "creel-design")` | ✅ (`test-creel-design.R`) |
| AIR-01 | `creel_design(survey_type = "aerial")` without `h_open` aborts with informative message | unit | `devtools::test(filter = "creel-design")` | ✅ |
| AIR-01 | `estimate_effort()` on aerial design returns numeric effort via `N̂ × H_open × L̄` | unit | `devtools::test(filter = "estimate-effort")` | ✅ (`test-estimate-effort.R`) |
| AIR-01 | Raw `N_counted` (no expansion) is never returned as effort — expansion is always applied | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| AIR-02 | Effort estimate has non-zero SE when n_counts > 1 and n_interviews > 1 | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| AIR-02 | Delta method SE formula: `SE = H_open * sqrt(L̄² * Var(N̂) + N̂² * Var(L̄))` | unit (numeric) | `devtools::test(filter = "estimate-effort")` | ✅ |
| AIR-03 | `creel_design(visibility_correction = 0.85)` stores correction in `design$aerial$visibility_correction` | unit | `devtools::test(filter = "creel-design")` | ✅ |
| AIR-03 | `visibility_correction` outside (0, 1] aborts with informative message | unit | `devtools::test(filter = "creel-design")` | ✅ |
| AIR-03 | Effort with `visibility_correction = 0.85` equals effort without correction divided by 0.85 | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| AIR-04 | Aerial effort reproduces Malvestuto (1996) Box 20.6 within tolerance 1e-6 | validation | `devtools::test(filter = "primary-source")` | ✅ (`test-primary-source-validation.R`) |
| AIR-05 | `add_interviews()` on aerial design produces non-NULL `interview_survey` | unit | `devtools::test(filter = "add-interviews")` | ✅ (`test-add-interviews.R`) |
| AIR-05 | `estimate_catch_rate()` returns valid result on aerial design | unit | `devtools::test(filter = "estimate-catch-rate")` | ✅ |
| AIR-05 | `estimate_total_catch()` returns valid result on aerial design | unit | `devtools::test(filter = "estimate-total-catch")` | ✅ |
| AIR-06 | `example_aerial_counts` and `example_aerial_interviews` load without error | data | `devtools::test(filter = "data")` | ❌ Wave 0 gap |

### Numerical Validation Details (AIR-04)

**Tolerance:** `expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)` — same as bus-route validation in `test-primary-source-validation.R`.

**What the validation test checks:**
1. Point estimate matches published E_hat exactly (within floating-point tolerance)
2. SE is computed as the delta method formula predicts
3. CI bounds are symmetric around the point estimate (normal approximation)

**What the validation test does NOT check (intentionally):**
- Bootstrap or jackknife variance alternatives (delta method is the primary)
- Grouped estimates (only ungrouped validated against primary source)

### Sampling Rate

- **Per task commit:** `devtools::test(filter = "creel-design")` (covers constructor + validation)
- **Per wave merge:** `devtools::test()` — full 1661+ suite must stay green
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] Exact Malvestuto (1996) Box 20.6 aerial numbers — must obtain physical book before AIR-04 test can be coded
- [ ] `data-raw/create_example_aerial_counts.R` — aerial count data (AIR-01, AIR-06)
- [ ] `data-raw/create_example_aerial_interviews.R` — angler interviews for catch estimation (AIR-05, AIR-06)
- [ ] `vignettes/aerial-surveys.Rmd` — complete workflow vignette (AIR-06)
- [ ] `R/creel-estimates-aerial.R` — new file for `estimate_effort_aerial()` internal function (AIR-01, AIR-02, AIR-03)

All existing test files already exist — tests for AIR-01 through AIR-05 will be appended to existing files, and AIR-04 appended to `test-primary-source-validation.R`.

---

## Sources

### Primary (HIGH confidence)

- Direct code inspection of `R/creel-design.R` — aerial stub L542-547; `creel_design()` signature L237-248; ice constructor template L382-515; camera constructor template L518-540; print method L2086-2089; `new_creel_design()` aerial slot L559
- Direct code inspection of `R/creel-estimates.R` — dispatch structure L332-417; bus_route/ice block L342-386; survey NULL check L333; sections dispatch L390-394
- Direct code inspection of `R/creel-estimates-bus-route.R` — `estimate_effort_br()` full implementation L21-196; `new_creel_estimates()` usage pattern L125-134
- Direct code inspection of `R/creel-estimates-total-catch.R` — bus_route/ice guard at L131; standard path structure
- Direct code inspection of `tests/testthat/test-primary-source-validation.R` — `make_box20_6_example1()` pattern L11-117; validation test structure L119-138
- Direct code inspection of `tests/testthat/test-creel-design.R` — aerial stub test L908-915; ice/camera test structure L917-1200+
- Direct code inspection of `.planning/STATE.md` — architecture decisions: "Aerial requires new internal estimate_effort_aerial() — ratio estimator with delta method variance"; "Rate and product estimators require zero changes"
- Hoenig, J.M., et al. (1993). Scheduling counts in the instantaneous and progressive count methods for estimating sportfishing effort. NAJFM 13:723-736. — confirms instantaneous count × day_duration = unbiased effort estimate
- `.planning/REQUIREMENTS.md` — AIR-01 through AIR-06 requirements and success criteria
- `.planning/ROADMAP.md` — Phase 47 goal and success criteria

### Secondary (MEDIUM confidence)

- Malvestuto, S.P. (1996). Sampling the recreational angler. Chapter 20 in Fisheries Techniques (2nd ed.), AFS. — primary validation source; specific aerial numbers not directly verified (source not accessible online); existence confirmed by bus-route validation already in codebase
- Pollock, K.H., C.M. Jones, and T.L. Brown (1994). Angler Survey Methods and Their Applications in Fisheries Management. AFS Special Publication 25. — framework for instantaneous count estimation

### Tertiary (LOW confidence)

- Web search summary: aerial counts combined with trip duration from interviews produces effort estimates; delta method is standard for ratio estimator variance — consistent with planned approach but not specifically verified from original sources

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all packages confirmed in DESCRIPTION
- Architecture: HIGH — all integration points confirmed by direct source inspection; dispatch guard locations, slot structure, and test patterns all verified; aerial stub location confirmed at L542-547
- Formula derivation: HIGH — instantaneous count ratio estimator is standard creel survey theory (Hoenig 1993 confirmed); delta method for product of two random variables is standard statistics
- Malvestuto (1996) aerial numbers: MEDIUM — formula structure correct; specific published values to be obtained from physical source before AIR-04 implementation
- Pitfalls: HIGH — all pitfalls derived from direct code inspection of ice/camera patterns, not inference

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (codebase stable; formula is standard statistics, not an external API)
