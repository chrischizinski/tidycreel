# Phase 45: Ice Fishing Survey Support - Research

**Researched:** 2026-03-15
**Domain:** R package extension — creel survey ice fishing design
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**p_site = 1.0 enforcement (ICE-01)**
- `sampling_frame` is optional for ice designs — if omitted, the ice constructor auto-uses `p_site = 1.0` for all sites internally
- If `sampling_frame` is supplied, `p_site` column is validated: any non-1.0 value triggers `cli_abort()` immediately with a message naming the offending values
- `p_period` column follows the same pattern as bus-route: user-supplied (ice fishing still has temporal sampling probability)
- Dispatch in `estimate_effort()`: extend the existing guard from `design$design_type == "bus_route"` to `design$design_type %in% c("bus_route", "ice")` — ice routes through `estimate_effort_br()` unchanged. No new function.

**Effort type distinction (ICE-02)**
- New required parameter `effort_type` on `creel_design(survey_type = "ice")` — no default
- Valid values: `"time_on_ice"` and `"active_fishing_time"`
- `cli_abort()` at construction time if `effort_type` is missing for ice designs
- Effect on output: `estimate_effort()` labels the estimate column based on `effort_type` — e.g., `total_effort_hr_on_ice` or `total_effort_hr_active`
- `effort_type` stored in `design$ice$effort_type` for downstream use

**Shelter-mode stratification (ICE-03)**
- `shelter_mode` is purely a grouping variable — no construction-time parameter, no validation in `creel_design()`
- Lives in interview data as a column (characteristic of the angler encounter, not the site design)
- `estimate_effort(by = shelter_mode)` uses the existing `by =` mechanism unchanged
- Missing stratum behavior: NA row with `data_available = FALSE` — consistent with the missing-section guard pattern

**Interview compatibility (ICE-04)**
- `add_interviews()` inherits bus-route validation (no ice-specific Tier 1 checks needed)
- `n_counted` and `n_interviewed` are REQUIRED for ice designs — same as bus-route, no roving-count fallback
- `estimate_catch_rate()` and `estimate_total_catch()` work on ice designs without modification — the dispatch guards for bus-route (extended to include ice) cover them

**Example data and documentation**
- Export realistic Nebraska lake dataset: ~50-100 rows, multiple sampling days, realistic effort values
- Dataset exports: `example_ice_sampling_frame`, `example_ice_interviews` (with catch), possibly `example_ice_catch`
- Species: walleye + perch (recognizable to Nebraska biologists)
- Shelter modes in data: open + dark_house
- Vignette: full ice fishing workflow

### Claude's Discretion

- Internal naming for auto-constructed sampling_frame when omitted (e.g., `.ice_sampling_frame` internal object)
- Whether `effort_type` affects the `print.creel_design()` output (likely yes — mirror how `bus_route` prints p_site/p_period info)
- Exact column name format for effort labels (`total_effort_hr_on_ice` vs `effort_on_ice_hr` — follow existing bus-route column naming convention)
- Number of sampling days and exact effort values in example data
- Whether to add `example_ice_*` to data-raw with a reproducible creation script

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ICE-01 | Ice fishing effort estimation routes through bus-route infrastructure with `p_site = 1.0` enforced automatically | Ice constructor fills stub at `R/creel-design.R:369-372`; dispatch guards at L333 and L342 of `creel-estimates.R` extend to `%in% c("bus_route", "ice")` |
| ICE-02 | User can supply an effort definition distinguishing time-on-ice from active-fishing-time | New `effort_type` parameter captured in ice branch; stored in `design$ice$effort_type`; output column name derived in `estimate_effort_br()` |
| ICE-03 | User can stratify estimates by shelter mode using the existing `by =` grouping mechanism | `shelter_mode` column in interview data; no new code in `by =` path; missing stratum row NA guard already present in `svyby` path |
| ICE-04 | User can attach interview data and estimate catch rates and total catch/harvest on an ice fishing design | Tier 3 dispatch in `add_interviews()` at L1550 extended to `%in% c("bus_route", "ice")`; catch rate/total catch dispatch at L1239 and `creel-estimates-total-catch.R:131` extended |
</phase_requirements>

---

## Summary

Phase 45 is a focused extension of existing bus-route infrastructure. Ice fishing is architecturally a degenerate bus-route design where all site inclusion probabilities equal 1.0. No new estimator is required — the entire phase is constructor expansion plus dispatch guard widening across four call sites.

The three major work streams are: (1) filling the ice constructor stub in `creel_design()` with `effort_type` validation and optional sampling-frame handling; (2) extending bus-route dispatch guards in `estimate_effort()`, `estimate_harvest_rate()`, `estimate_total_catch()`, and `add_interviews()` to accept `"ice"` alongside `"bus_route"`; and (3) creating realistic example datasets and an ice-fishing vignette following the bus-route documentation template.

The `effort_type` parameter is the only genuinely new concept. It carries biologically meaningful information: `"time_on_ice"` includes travel and setup time, while `"active_fishing_time"` excludes it and is the correct denominator for CPUE. Forcing the user to declare which denominator they used prevents silent mislabeling in downstream analysis.

**Primary recommendation:** Fill the ice stub, widen four dispatch guards, label the effort output column from `design$ice$effort_type`, build example data with walleye + perch + shelter_mode, write the vignette.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| cli | already in Imports | Errors and messages | All existing validation uses `cli_abort()` / `cli_inform()` |
| rlang | already in Imports | Tidy evaluation, `enquo` | All parameter capture uses `enquo` / `quo_is_null` |
| checkmate | already in Imports | Tier 3 validation collections | Used in `validate_br_interviews_tier3()` template |
| usethis | already in Suggests | `use_data()` for example datasets | Used in all existing `data-raw/*.R` scripts |
| testthat (>= 3.0.0) | Config/testthat/edition: 3 | Unit testing | Project-standard |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| survey | already in Imports | `svyby()` / `svytotal()` for variance | Used inside `estimate_effort_br()` — no changes needed |
| knitr / rmarkdown | already in Suggests | Vignette rendering | Used in all existing `.Rmd` vignettes |

**Installation:** No new dependencies. All required packages are already in DESCRIPTION.

---

## Architecture Patterns

### Recommended Project Structure

New files to add:

```
R/
└── creel-design.R         # ice branch filled in (L369-372)
R/
└── creel-estimates.R      # 4 dispatch guards widened
data-raw/
├── example_ice_sampling_frame.R
└── example_ice_interviews.R
data/
├── example_ice_sampling_frame.rda
└── example_ice_interviews.rda
R/
└── data.R                 # roxygen @docType dataset entries for new objects
vignettes/
└── ice-fishing.Rmd
tests/testthat/
└── test-creel-design.R    # ice constructor tests appended
└── test-estimate-effort.R # ice dispatch tests appended
```

### Pattern 1: Ice Constructor — Fill the Stub

**What:** The ice branch at `R/creel-design.R:369-372` currently returns `list(survey_type = "ice")`. Phase 45 replaces that with full `effort_type` validation, optional `sampling_frame` handling, and `pi_i = 1.0` computation.

**Template from bus-route constructor** (`R/creel-design.R:275-366`):

```r
# --- Ice branch ---
ice <- NULL
if (identical(survey_type, "ice")) {
  # 1. Validate effort_type is provided and valid
  if (is.null(effort_type) || !effort_type %in% c("time_on_ice", "active_fishing_time")) {
    cli::cli_abort(c(
      "{.arg effort_type} is required when {.arg survey_type} is {.val ice}.",
      "i" = "Valid values: {.val time_on_ice}, {.val active_fishing_time}."
    ))
  }

  # 2. Build internal sampling frame (optional for ice)
  if (!is.null(sampling_frame) && is.data.frame(sampling_frame)) {
    # Validate p_site == 1.0 for all rows
    p_site_vals <- sampling_frame[[p_site_col_name]]
    bad <- which(abs(p_site_vals - 1.0) > 1e-9)
    if (length(bad) > 0) {
      cli::cli_abort(c(
        "All {.field p_site} values must equal 1.0 for ice designs.",
        "x" = "{length(bad)} row{?s} with non-1.0 p_site: {bad}.",
        "i" = "Ice surveys sample all sites (p_site = 1.0 by definition)."
      ))
    }
    # ... resolve p_period, compute .pi_i, store as ice$data
  } else {
    # Auto-construct: p_site = 1.0 for all sites
    # .pi_i = 1.0 * p_period
  }

  ice <- list(
    survey_type  = "ice",
    effort_type  = effort_type,
    data         = ice_df,       # may be NULL if no sampling_frame
    p_period_col = p_period_col,
    pi_i_col     = ".pi_i"
  )
}
```

**Key difference from bus-route:** The `site` column is NOT required for ice designs (all sites are sampled, so no exclusion probability join is needed unless a multi-site sampling frame is supplied). The `p_site_col` is not stored because it is always 1.0.

### Pattern 2: Dispatch Guard Extension

**What:** Four locations use `design$design_type == "bus_route"` — all must be widened to `%in% c("bus_route", "ice")`.

**Exact locations:**

| File | Line | Current guard | Changed to |
|------|------|--------------|------------|
| `R/creel-estimates.R` | L333 | `!identical(design$design_type, "bus_route")` | `!design$design_type %in% c("bus_route", "ice")` |
| `R/creel-estimates.R` | L342 | `design$design_type == "bus_route"` | `design$design_type %in% c("bus_route", "ice")` |
| `R/creel-estimates.R` | L1227 | `!identical(design$design_type, "bus_route")` | `!design$design_type %in% c("bus_route", "ice")` |
| `R/creel-estimates.R` | L1239 | `design$design_type == "bus_route"` | `design$design_type %in% c("bus_route", "ice")` |
| `R/creel-estimates-total-catch.R` | L131 | `design$design_type == "bus_route"` | `design$design_type %in% c("bus_route", "ice")` |
| `R/creel-design.R` | L1550 | `!is.null(design$bus_route)` | `!is.null(design$bus_route) \|\| !is.null(design$ice)` |
| `R/creel-design.R` | L1579 | `!is.null(design$bus_route)` | extend for ice slot too |

Note: `add_interviews()` Tier 3 validation at L1550 currently fires on `!is.null(design$bus_route)`. For ice, the same Tier 3 checks apply (n_counted and n_interviewed required). The cleanest approach is: check `!is.null(design$bus_route) || !is.null(design$ice)` and pass the correct slot to `validate_br_interviews_tier3()`. Similarly, the pi_i join at L1579 needs ice-aware logic: when `design$ice` is non-NULL, `.pi_i` may be constructed inline (p_site = 1.0, so `.expansion` is the only join needed, not a sampling-frame lookup).

**IMPORTANT NUANCE:** For ice designs without a sampling_frame, there is no site-level join key. The `.pi_i = p_period` can be attached directly from `design$ice$p_period_col` or scalar. The expansion factor (`n_counted / n_interviewed`) is still needed for the HT estimator. The ice `add_interviews()` path must attach `.pi_i` without requiring a site column join — for the no-sampling-frame case, every row gets `.pi_i = p_period`.

### Pattern 3: Effort Column Labeling

**What:** `estimate_effort_br()` currently returns a column named `estimate`. After dispatch the planner may choose to rename it based on `design$ice$effort_type` either inside `estimate_effort_br()` or in the ice-specific wrapper in `estimate_effort()`.

**Recommendation (Claude's discretion):** Add a post-dispatch rename step inside the ice dispatch block in `estimate_effort()`, not inside `estimate_effort_br()`. This keeps the estimator function clean and unchanged:

```r
# Ice dispatch in estimate_effort()
if (design$design_type %in% c("bus_route", "ice")) {
  result <- estimate_effort_br(design, by_vars_br, variance, conf_level, verbose)
  if (identical(design$design_type, "ice") && !is.null(design$ice$effort_type)) {
    effort_label <- switch(design$ice$effort_type,
      time_on_ice        = "total_effort_hr_on_ice",
      active_fishing_time = "total_effort_hr_active"
    )
    # Rename the estimate column in result$estimates
    names(result$estimates)[names(result$estimates) == "estimate"] <- effort_label
  }
  return(result)
}
```

### Pattern 4: Example Dataset Structure

**Template from `data-raw/create_example_interviews.R`:**
- Plain `data.frame()` construction with `stringsAsFactors = FALSE`
- Inline `stopifnot()` data quality assertions at end of script
- `usethis::use_data(object_name, overwrite = TRUE)` to save
- Roxygen `@docType data` entries in `R/data.R`

**Ice sampling frame** (`example_ice_sampling_frame`):
- Columns: `date`, `day_type`, `site` (optional — multiple access points), `p_period`
- Realistic p_period values: e.g., 0.5 (survey covers half the possible fishing hours)
- Walleye ice fishery in Nebraska: winter season, January–March

**Ice interviews** (`example_ice_interviews`):
- Columns: `date`, `site`, `n_counted`, `n_interviewed`, `hours_on_ice`, `active_fishing_hours`, `walleye_catch`, `perch_catch`, `walleye_kept`, `perch_kept`, `trip_status`, `shelter_mode`
- `shelter_mode`: `"open"` and `"dark_house"`
- ~60-80 rows, 10-15 sampling days

### Anti-Patterns to Avoid

- **Modifying `estimate_effort_br()` to know about ice:** The function is a pure HT estimator; type-specific column labeling belongs in the dispatch layer, not the estimator.
- **Requiring `site` column for ice designs without a sampling frame:** Ice surveys often have a single lake access point; the site column should remain optional.
- **Storing `p_site_col` in `design$ice`:** For ice, p_site is always 1.0 — there is no column. Store only `p_period_col` and `pi_i_col`.
- **Using a different Tier 3 validator for ice:** The existing `validate_br_interviews_tier3()` can be reused for ice if the `design$bus_route` reference is replaced with the ice slot's equivalent.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Variance estimation for ice effort | Custom variance formula | `estimate_effort_br()` via dispatch | HT estimator already handles grouped/ungrouped variance via `survey::svyby` |
| Effort column labeling | Type-specific estimator function | Post-dispatch rename in `estimate_effort()` | Keeps estimator pure; one rename location |
| p_site=1.0 enforcement | Runtime float comparison with tolerance | `abs(val - 1.0) > 1e-9` check in constructor | Exact equality is the wrong test for floats |
| Interview data for ice | New interview structure | Same `add_interviews()` path as bus-route | All required columns already exist; Tier 1/2/3 validation inherited |

---

## Common Pitfalls

### Pitfall 1: Pi_i Join Without a Sampling Frame

**What goes wrong:** The bus-route add_interviews path at L1579 performs a `dplyr::left_join()` on the sampling frame to attach `.pi_i`. For ice designs without a sampling frame, there is no frame to join against.

**Why it happens:** The dispatch guard at L1579 checks `!is.null(design$bus_route)` — if ice is handled by the same block, it will try to dereference `design$bus_route$data` which is NULL.

**How to avoid:** Separate the join logic: if `!is.null(design$ice)`, compute `.pi_i` directly from `design$ice$p_period_col` (either a scalar scalar stored during construction or a column joined from a supplied frame). For the common single-lake, no-sampling-frame case, `.pi_i = design$ice$p_period_scalar` is a constant broadcast to all rows.

**Warning signs:** `Error in design$bus_route$data[, c(...)]` or NA `.pi_i` for all rows on an ice design.

### Pitfall 2: Effort Type Not Passed Through to `estimate_effort_br()`

**What goes wrong:** `estimate_effort_br()` returns a column named `estimate` regardless of effort type. If the caller forgets to rename it after dispatch, the output column will be `estimate` for both ice and bus-route, losing the biological distinction.

**Why it happens:** The rename step is in the dispatch layer (easy to forget), not in the estimator.

**How to avoid:** Add the rename step directly in the ice dispatch block immediately before `return()`. Test that `names(result$estimates)` contains `total_effort_hr_on_ice` or `total_effort_hr_active`, not `estimate`.

### Pitfall 3: Forgetting `estimate_catch_rate()` Does NOT Have a Bus-Route Guard

**What goes wrong:** `estimate_catch_rate()` (L581–1040 in creel-estimates.R) does not have a bus-route dispatch guard — it uses `design$interview_survey` directly, which is constructed by `add_interviews()` for all design types. It will work for ice without any changes, provided `add_interviews()` correctly constructs `interview_survey` for ice designs.

**Why it happens:** The function does not need a guard because it uses the generic `interview_survey` path, not a type-specific estimator.

**How to avoid:** Verify `add_interviews()` correctly builds `interview_survey` for ice designs (calls `construct_interview_survey()` at L1665 unconditionally — confirm this fires for ice). No changes needed to `estimate_catch_rate()` itself.

### Pitfall 4: p_site Validation Tolerance

**What goes wrong:** Validating `p_site != 1.0` using exact equality (`p_site != 1.0`) will fail for floating-point values like `0.9999999999` from division.

**Why it happens:** Floating-point arithmetic.

**How to avoid:** Use `abs(val - 1.0) > 1e-9` as the rejection condition, consistent with how bus-route uses `abs(circ_sum - 1.0) > 1e-6`.

### Pitfall 5: `n_counted`/`n_interviewed` Enforcement Location

**What goes wrong:** Currently `validate_br_interviews_tier3()` fires when `!is.null(design$bus_route)`. If ice is handled by the same gate, the validator will try to dereference `design$bus_route$site_col` which is NULL for ice.

**Why it happens:** `validate_br_interviews_tier3()` is hard-coded to look at `design$bus_route` for site/circuit join-key checks.

**How to avoid:** Create a thin wrapper or add an ice-specific branch inside the validator: for ice, the site/circuit join-key checks are skipped (or optional), but the n_counted/n_interviewed presence checks still fire. Alternatively, factor out the n_counted/n_interviewed check into a separate shared validator.

---

## Code Examples

Verified patterns from existing source:

### Existing Bus-Route Dispatch Guard (template to extend)

```r
# Source: R/creel-estimates.R:342
if (!is.null(design$design_type) && design$design_type == "bus_route") {
  # ... dispatch to estimate_effort_br()
  return(estimate_effort_br(design, by_vars_br, variance, conf_level, verbose))
}

# Extended for ice:
if (!is.null(design$design_type) && design$design_type %in% c("bus_route", "ice")) {
  # ... dispatch
  result <- estimate_effort_br(design, by_vars_br, variance, conf_level, verbose)
  # rename for ice
  return(result)
}
```

### Existing p_site Range Check (template for p_site = 1.0 enforcement)

```r
# Source: R/creel-design.R:523-529
p_site_vals <- br[[p_site_col]]
if (any(is.na(p_site_vals)) || any(p_site_vals <= 0) || any(p_site_vals > 1)) {
  bad <- which(is.na(p_site_vals) | p_site_vals <= 0 | p_site_vals > 1) # nolint: object_usage_linter
  cli::cli_abort(c(
    "All {.field p_site} values must be in the range (0, 1].",
    "x" = "{length(bad)} value{?s} out of range at row{?s} {bad}.",
    "i" = "Sampling probabilities must be positive and at most 1.0."
  ))
}

# Ice equivalent — must equal 1.0 exactly:
p_site_vals <- sampling_frame[[p_site_col]]
bad <- which(abs(p_site_vals - 1.0) > 1e-9) # nolint: object_usage_linter
if (length(bad) > 0) {
  cli::cli_abort(c(
    "All {.field p_site} values must equal 1.0 for ice designs.",
    "x" = "{length(bad)} row{?s} with p_site != 1.0: row{?s} {bad}.",
    "i" = "Ice surveys sample all sites; p_site must be 1.0."
  ))
}
```

### Existing Example Dataset Pattern

```r
# Source: data-raw/create_example_interviews.R
example_ice_interviews <- data.frame(
  date          = as.Date(...),
  n_counted     = c(...),
  n_interviewed = c(...),
  hours_on_ice  = c(...),
  active_hours  = c(...),
  walleye_catch = c(...),
  perch_catch   = c(...),
  trip_status   = c("complete", "incomplete", ...),
  shelter_mode  = c("open", "dark_house", ...),
  stringsAsFactors = FALSE
)
stopifnot(all(example_ice_interviews$n_counted >= example_ice_interviews$n_interviewed))
usethis::use_data(example_ice_interviews, overwrite = TRUE)
```

### Print Method Extension (Claude's Discretion)

```r
# Source: R/creel-design.R:1881 — Bus-Route section in format.creel_design()
# Ice equivalent to add after bus_route section:
if (!is.null(x$ice)) {
  cli::cli_h2("Ice Fishing Design")
  cli::cli_text("Effort type: {.val {x$ice$effort_type}}")
  if (!is.null(x$ice$p_period_col)) {
    cli::cli_text("p_period column: {.field {x$ice$p_period_col}}")
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ice as separate survey type with custom estimator | Ice as degenerate bus-route (p_site = 1.0) dispatching to `estimate_effort_br()` | Phase 45 decision | No new estimator needed; full HT infrastructure inherited |
| `creel_design(survey_type = "ice")` returns minimal stub | Constructor enforces `effort_type`, validates p_site = 1.0 | Phase 45 | Users get fail-fast validation at construction time |

**No deprecated patterns in this phase.** The ice stub (Phase 44) exists solely to be replaced.

---

## Open Questions

1. **Pi_i attachment for ice without sampling_frame**
   - What we know: the HT estimator (`estimate_effort_br()`) requires `.pi_i` column on interview rows; bus-route attaches it via left_join on the sampling frame
   - What's unclear: for ice with no sampling frame, how is `.pi_i` attached? The simplest approach is a scalar broadcast: `interviews_joined$.pi_i <- design$ice$p_period_scalar` or from a stored p_period column. This needs to be decided in the plan.
   - Recommendation: in `add_interviews()`, when `!is.null(design$ice)`, broadcast `.pi_i` from the ice slot's stored `p_period` value directly onto all rows — no frame join required.

2. **Does `creel_design()` need a new `effort_type` parameter in the function signature?**
   - What we know: `creel_design()` currently has `calendar, date, strata, site, design_type, survey_type, sampling_frame, p_site, p_period, circuit`
   - What's unclear: `effort_type` needs to be captured before the ice branch executes — it must be a top-level parameter
   - Recommendation: Add `effort_type = NULL` to `creel_design()` signature. Capture with `effort_type <- effort_type` (no tidy-eval needed; it's a plain character string). Validate inside the ice branch only.

3. **How many dispatch sites need updating?**
   - Confirmed: 5 explicit `design_type == "bus_route"` checks plus 2 `!is.null(design$bus_route)` checks in `add_interviews()`
   - The `estimate_catch_rate()` function does NOT have a bus-route guard (confirmed by code inspection) — it uses `interview_survey` which is built generically — no change needed there

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
| ICE-01 | `creel_design(survey_type = "ice")` routes effort through `estimate_effort_br()` | unit | `devtools::test(filter = "estimate-effort")` | ✅ (`test-estimate-effort.R`) |
| ICE-01 | p_site = 1.0 enforced when sampling_frame supplied with bad values | unit | `devtools::test(filter = "creel-design")` | ✅ (`test-creel-design.R`) |
| ICE-01 | p_site auto-1.0 when no sampling_frame provided | unit | `devtools::test(filter = "creel-design")` | ✅ |
| ICE-02 | `cli_abort()` when `effort_type` missing on ice design | unit | `devtools::test(filter = "creel-design")` | ✅ |
| ICE-02 | `design$ice$effort_type` stored correctly | unit | `devtools::test(filter = "creel-design")` | ✅ |
| ICE-02 | Effort estimate column labeled `total_effort_hr_on_ice` or `total_effort_hr_active` | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| ICE-03 | `estimate_effort(by = shelter_mode)` returns grouped result | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| ICE-04 | `add_interviews()` requires n_counted, n_interviewed for ice designs | unit | `devtools::test(filter = "add-interviews")` | ✅ (`test-add-interviews.R`) |
| ICE-04 | `estimate_catch_rate()` works on ice design | unit | `devtools::test(filter = "estimate-catch-rate")` | ✅ |
| ICE-04 | `estimate_total_catch()` works on ice design | unit | `devtools::test(filter = "estimate-total-catch")` | ✅ |

### Sampling Rate

- **Per task commit:** `devtools::test(filter = "creel-design")` (covers constructor + validation)
- **Per wave merge:** `devtools::test()` — full 1596+ suite must stay green
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — existing test infrastructure covers all phase requirements. Tests for ICE-01 through ICE-04 will be appended to existing test files, not new files.

---

## Sources

### Primary (HIGH confidence)

- Direct code inspection of `R/creel-design.R` (3005 lines) — bus-route constructor pattern L275-366, ice stub L369-372, Tier 3 validation L2430-2494, print method L1881-1949, validate_creel_design L514-584
- Direct code inspection of `R/creel-estimates.R` (3255 lines) — dispatch guards L333, L342, L1227, L1239
- Direct code inspection of `R/creel-estimates-bus-route.R` (569 lines) — `estimate_effort_br()` L21-193, column usage
- Direct code inspection of `R/creel-estimates-total-catch.R` — bus-route dispatch L131
- Direct code inspection of `tests/testthat/test-creel-design.R` — existing ice stub test L887-894, bus-route test structure
- Direct code inspection of `data-raw/create_example_interviews.R` — example data creation pattern

### Secondary (MEDIUM confidence)

- `.planning/phases/45-ice-fishing-survey-support/45-CONTEXT.md` — all architectural decisions locked by user; research confirms feasibility
- `.planning/STATE.md` — architecture decisions: "Ice fishing is a degenerate bus-route with p_site = 1.0 — dispatch to estimate_effort_br()"
- `vignettes/bus-route-surveys.Rmd` — vignette structure template

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages confirmed in DESCRIPTION; no new dependencies
- Architecture: HIGH — all integration points confirmed by direct source inspection; all line numbers verified
- Pitfalls: HIGH — all pitfalls confirmed by reading actual code paths, not by inference

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (codebase is stable; no external dependencies changing)
