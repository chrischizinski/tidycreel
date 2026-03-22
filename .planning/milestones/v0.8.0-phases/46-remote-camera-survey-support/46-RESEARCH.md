# Phase 46: Remote Camera Survey Support - Research

**Researched:** 2026-03-15
**Domain:** R package extension — creel survey remote camera design (counter and ingress-egress modes)
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CAM-01 | User can estimate effort from daily ingress counts (counter mode) routed through the existing access-point path | Camera counter mode uses `add_counts()` → `estimate_effort()` standard instantaneous path; camera stub at `R/creel-design.R:519-522` captures the `design$camera` slot; dispatch guard at `creel-estimates.R:333` must admit "camera" for the counts-based path |
| CAM-02 | User can estimate effort from timestamp pairs (ingress-egress mode) accumulated to daily effort via `difftime()` preprocessing | Ingress-egress preprocessing converts POSIXct timestamp columns to numeric effort hours before `add_counts()`; a dedicated preprocessing helper (e.g., `preprocess_camera_timestamps()`) is the cleanest approach — no changes to `estimate_effort()` needed |
| CAM-03 | User can classify camera gaps as non-random failures (`camera_status`) separate from random missingness handled by `missing_sections` | `camera_status` column lives in the counts/frame data; documentation contract defines allowed values; no new estimator logic — gaps with `camera_status != "operational"` are excluded before or after `add_counts()` per user workflow |
| CAM-04 | User can attach interview data and estimate catch rates and total catch/harvest on a camera design | Camera must route through the `interview_survey` path (same as instantaneous); dispatch guards at `creel-estimates.R:1239` and `creel-estimates-total-catch.R:131` currently hard-code `"bus_route"` — camera uses the instantaneous/interview_survey path, so no changes to those guards are needed |
| CAM-05 | Camera survey support documented with example dataset covering both sub-modes and gap handling | Example datasets follow `data-raw/create_example_ice_*` pattern; vignette follows `vignettes/ice-fishing.Rmd` template |
</phase_requirements>

---

## Summary

Phase 46 is architecturally simpler than Phase 45 (ice fishing) because camera surveys have TWO distinct sub-modes that map onto EXISTING infrastructure with no new estimator needed. Counter mode is a rename of standard instantaneous access-point counting — daily ingress counts flow through `add_counts()` → `estimate_effort()` unchanged. Ingress-egress mode requires a preprocessing step that converts timestamp pairs to per-day effort hours using `difftime()`, then hands off the aggregated numeric column to the same `add_counts()` path. Neither sub-mode requires a new estimator.

The genuinely new concept is `camera_status` — a metadata column in the user's count data that documents WHY a given day has no counts (battery failure, memory card full, lens occlusion) rather than attributing it to random missingness. This is a documentation and data contract concern, not an estimation concern. The package's job is to: (1) make `camera_status` a first-class column name that users know to supply, (2) validate its presence when a camera design is used, and (3) ensure informative gaps are NOT imputed as zero effort by the estimation path. The existing `missing_sections` guard already prevents zero-imputation for sections with missing counts — for camera designs without sections, the user simply excludes `camera_status != "operational"` rows from the counts frame before calling `add_counts()`, and the documentation explains this.

The interview compatibility path (CAM-04) requires no changes to `estimate_catch_rate()` or `estimate_total_catch()` because both functions use the generic `interview_survey` path, not a bus-route-specific dispatch. Camera designs will construct `interview_survey` through the same `add_interviews()` → `construct_interview_survey()` chain as instantaneous designs.

**Primary recommendation:** Fill the camera stub in `creel_design()` with sub-mode validation and `camera_status` documentation; write `preprocess_camera_timestamps()` for ingress-egress preprocessing; extend the `estimate_effort()` null-survey guard to admit "camera" with counts; create example datasets with both sub-modes and a gap row; write the vignette.

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
| base `difftime()` | base R | Convert POSIXct timestamp pairs to numeric hours | Ingress-egress preprocessing only |
| knitr / rmarkdown | already in Suggests | Vignette rendering | Vignette for CAM-05 |

**Installation:** No new dependencies. All required packages are already in DESCRIPTION.

---

## Architecture Patterns

### Recommended Project Structure

New and modified files for Phase 46:

```
R/
├── creel-design.R         # camera branch filled in (L519-522); new preprocess_camera_timestamps()
├── creel-estimates.R      # null-survey guard at L333 — must NOT block camera (see below)
data-raw/
├── create_example_camera_counts.R       # counter mode + ingress-egress rows + gap row
└── create_example_camera_interviews.R
data/
├── example_camera_counts.rda
└── example_camera_interviews.rda
R/
└── data.R                 # roxygen @docType dataset entries for new objects
vignettes/
└── camera-surveys.Rmd
tests/testthat/
└── test-creel-design.R    # camera constructor tests appended
```

### Pattern 1: Camera Constructor — Fill the Stub

**What:** The camera branch at `R/creel-design.R:519-522` currently returns `list(survey_type = "camera")`. Phase 46 replaces it with sub-mode validation and `camera_status` awareness.

**Sub-modes:** `"counter"` and `"ingress_egress"`. The sub-mode is a construction-time parameter (`camera_mode`) that constrains how data must be prepared. It is NOT needed by the estimator — it exists to produce informative errors if the user calls the wrong preparation path.

**Template:**

```r
# --- Camera branch ---
camera <- NULL
if (identical(survey_type, "camera")) {
  valid_camera_modes <- c("counter", "ingress_egress")
  if (is.null(camera_mode) || !camera_mode %in% valid_camera_modes) {
    cli::cli_abort(c(
      "{.arg camera_mode} is required for {.val camera} survey designs.",
      "x" = if (is.null(camera_mode)) {
        "No {.arg camera_mode} supplied."
      } else {
        "Unknown {.arg camera_mode}: {.val {camera_mode}}."
      },
      "i" = "Valid values: {.val {valid_camera_modes}}."
    ))
  }
  camera <- list(
    survey_type  = "camera",
    camera_mode  = camera_mode
  )
}
```

**Key design choice:** Camera does NOT build a synthetic `bus_route` slot. Counter mode uses the standard instantaneous path (`add_counts()` + `design$survey`). Ingress-egress mode also uses `add_counts()` after the user calls `preprocess_camera_timestamps()` to aggregate timestamp pairs to daily effort hours.

### Pattern 2: `preprocess_camera_timestamps()` — Ingress-Egress Helper

**What:** Converts a data frame of ingress/egress timestamp pairs to a daily effort summary suitable for `add_counts()`. This is a pure data-transformation function; no survey statistics involved.

**Signature:**

```r
preprocess_camera_timestamps <- function(timestamps,
                                         date_col,
                                         ingress_col,
                                         egress_col,
                                         camera_status_col = NULL) {
  # 1. Validate date, ingress, egress columns exist and are Date/POSIXct
  # 2. difftime(egress, ingress, units = "hours") for each row
  # 3. Warn on negative durations (egress before ingress — clock error or overnight trip)
  # 4. Aggregate: sum(hours_fished) by date
  # 5. Optionally propagate camera_status to the daily summary
  # 6. Return data frame with date + daily_effort_hours columns
}
```

**difftime pattern (base R):**

```r
# Convert timestamp pair to hours (numeric)
duration_hours <- as.numeric(
  difftime(timestamps[[egress_col]], timestamps[[ingress_col]], units = "hours")
)
```

**Negative duration handling:**

```r
neg <- duration_hours < 0
if (any(neg, na.rm = TRUE)) {
  n_neg <- sum(neg, na.rm = TRUE)
  cli::cli_warn(c(
    "{n_neg} row{?s} ha{?s/ve} egress before ingress (negative duration).",
    "x" = "Negative durations set to NA.",
    "i" = "Check for overnight trips that cross midnight — split into two rows."
  ))
  duration_hours[neg] <- NA_real_
}
```

**Aggregation:**

```r
# Aggregate to daily effort
daily_effort <- stats::aggregate(
  duration_hours ~ date,
  data = data.frame(date = timestamps[[date_col]], duration_hours = duration_hours),
  FUN = function(x) sum(x, na.rm = TRUE)
)
names(daily_effort)[2] <- "daily_effort_hours"
```

### Pattern 3: `camera_status` Column Contract

**What:** `camera_status` is a user-supplied column in the counts data frame. The package documents its meaning but does NOT validate specific values — this preserves flexibility across field teams that use different terminology.

**Documented convention:**

| Value | Meaning | Estimation behavior |
|-------|---------|-------------------|
| `"operational"` | Camera working; count is valid | Include in `add_counts()` |
| `"battery_failure"` | Non-random gap; count unknown | EXCLUDE before `add_counts()` |
| `"memory_full"` | Non-random gap; count unknown | EXCLUDE before `add_counts()` |
| `"occlusion"` | Non-random gap; count unknown | EXCLUDE before `add_counts()` |
| `NA` | Random missingness (unsampled day) | Handled by design strata / calendar |

**Key principle:** Gaps with `camera_status != "operational"` are NOT zero-effort days — they are days where effort is unknown. The user filters these rows BEFORE calling `add_counts()`. This is a documentation-layer concern, not an estimation-layer concern.

**Validation in constructor:** If `camera_status_col` parameter is supplied to `creel_design()`, validate it exists in any subsequently attached data. This is a lightweight advisory check — the constructor cannot inspect the counts data frame at construction time (it arrives via `add_counts()` later).

**Alternative approach (simpler):** Document the `camera_status` column contract in the vignette and `data.R` dataset documentation. Do NOT add a `camera_status_col` parameter to `creel_design()` — users are responsible for filtering before `add_counts()`. This matches the existing pattern where `missing_sections` is a parameter to estimators, not to the constructor.

### Pattern 4: Counter Mode Effort Path — No New Code

**What:** Counter mode daily ingress counts are semantically equivalent to instantaneous angler counts. They flow through `add_counts()` → `estimate_effort()` with zero changes to either function.

**Verification needed:** The null-survey guard at `R/creel-estimates.R:333` reads:

```r
if (!design$design_type %in% c("bus_route", "ice") && is.null(design$survey)) {
```

Camera (`design_type = "camera"`) is NOT in that exclusion list, so it WILL hit this guard. This guard checks `design$survey` which is populated by `add_counts()` → `construct_survey_design()`. As long as the user calls `add_counts()` before `estimate_effort()`, `design$survey` will not be NULL and the guard will pass. Counter mode therefore requires NO changes to `estimate_effort()`.

**Confirm:** `add_counts()` does not check `design_type` — it accepts any `creel_design` object. Camera designs can call `add_counts()` without modification.

### Pattern 5: Dispatch Guards That Need Camera

The following guards need to be verified for camera compatibility:

| File | Line | Current guard | Camera behavior needed |
|------|------|--------------|----------------------|
| `R/creel-estimates.R` | L333 | `!design$design_type %in% c("bus_route", "ice") && is.null(design$survey)` | Camera uses `design$survey` (via `add_counts()`), so this guard PASSES without change as long as `add_counts()` is called first |
| `R/creel-estimates.R` | L342 | `design$design_type %in% c("bus_route", "ice")` | Camera does NOT enter this block — it falls through to the standard instantaneous path. CORRECT behavior. |
| `R/creel-estimates.R` | L1239 | `!identical(design$design_type, "bus_route") && is.null(design$interview_survey)` | Camera does not match `"bus_route"`, so this fires correctly when `interview_survey` is NULL. Once `add_interviews()` is called, `interview_survey` is set, guard passes. NO CHANGE NEEDED. |
| `R/creel-estimates-total-catch.R` | L131 | `design$design_type %in% c("bus_route", "ice")` | Camera does NOT match — falls through to standard interview_survey path. CORRECT. |

**Conclusion:** No dispatch guard changes are needed for camera. The standard instantaneous path handles counter mode and interview-based estimation natively.

### Pattern 6: `add_interviews()` for Camera

Camera designs do NOT need `n_counted` / `n_interviewed` columns. They are interviewing anglers in the field independently from the camera counts. The Tier 3 bus-route validation at `R/creel-design.R:1692` reads:

```r
if (!is.null(design$bus_route) && !identical(design$design_type, "ice")) {
  validate_br_interviews_tier3(...)
}
```

Camera has no `design$bus_route` slot, so it bypasses bus-route Tier 3 validation entirely. Camera also bypasses ice Tier 3 at L1702 (checks `identical(design$design_type, "ice")`). Camera uses the standard instantaneous interview path — no n_counted/n_interviewed required.

**Confirm:** `add_interviews()` requires only that the design is a `creel_design` and no interviews are already attached. Camera passes both checks. NO CHANGES to `add_interviews()` needed.

### Pattern 7: Example Dataset Structure

**Two datasets:**

1. `example_camera_counts` — covers both sub-modes and includes a non-random gap row

```
Columns: date, day_type, camera_mode, daily_ingress_count (counter rows),
         daily_effort_hours (ingress-egress rows, already preprocessed),
         camera_status
```

The counter-mode and ingress-egress rows can be in separate data frames (one per mode), or a single combined frame with a `camera_mode` column. A **separate** pair of data frames is simpler and more educational in the vignette.

Counter dataset columns: `date`, `day_type`, `ingress_count`, `camera_status`
Ingress-egress dataset columns: `date`, `day_type`, `daily_effort_hours`, `camera_status`
(The gap row has `camera_status = "battery_failure"` and `NA` for the count/effort column.)

2. `example_camera_interviews` — angler interviews for catch estimation

```
Columns: date, day_type, hours_fished, walleye_catch, walleye_kept,
         bass_catch, bass_kept, trip_status
```

**Species:** walleye + bass (summer fishery, distinct from ice fishing walleye + perch).

**Size:** ~40-60 rows, 8-12 sampling days.

### Anti-Patterns to Avoid

- **Treating camera as a bus-route variant:** Camera designs do NOT build a `bus_route` slot. Counter mode uses instantaneous counts; there is no enumeration expansion factor.
- **Imputing zero effort for informative gaps:** `camera_status != "operational"` rows must be excluded BEFORE `add_counts()`, not passed as zero counts. Passing NA-count rows to `add_counts()` may propagate silently or error — filter first.
- **Adding `camera_status` validation to the estimator layer:** The estimator does not know about `camera_status`. The documentation and the user's data-prep workflow bear this responsibility.
- **Requiring n_counted/n_interviewed for camera interviews:** Camera field interviews are independent of camera counts. The bus-route HT estimator is not used for camera catch estimation.
- **Writing a new ingress-egress estimator:** The preprocessing step converts timestamp pairs to effort hours. After preprocessing, the estimation path is identical to counter mode. No new estimator is needed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Effort variance for counter mode | Custom variance formula | `estimate_effort()` standard instantaneous path via `add_counts()` | Existing `svyratio`/`svytotal` infrastructure handles variance correctly |
| Timestamp duration calculation | Manual subtraction of POSIXct objects | `base::difftime(egress, ingress, units = "hours")` | Handles DST transitions, timezone mismatches, and returns proper numeric |
| Aggregation to daily effort | Custom loop | `stats::aggregate()` or `dplyr::summarise()` | Already in Imports; handles grouping correctly |
| Interview-based catch estimation | New estimator for camera | `estimate_catch_rate()` / `estimate_total_catch()` via `add_interviews()` | These functions use `interview_survey` generically — no camera-specific changes needed |
| Gap documentation | Runtime validation of camera_status values | User-side filtering + vignette documentation | Package enforces data contract via documentation, not runtime errors on status strings that vary by agency |

---

## Common Pitfalls

### Pitfall 1: Forgetting That `estimate_effort()` Requires `add_counts()` First for Camera

**What goes wrong:** A user calls `estimate_effort(camera_design)` without calling `add_counts()` first. The guard at `creel-estimates.R:333` fires:

```
Error: No survey design available.
x Call `add_counts()` before estimating effort.
```

**Why it happens:** Camera uses the instantaneous path, which requires `design$survey` set by `add_counts()`. Bus-route and ice skip this guard because they use `design$interviews` not `design$survey`.

**How to avoid:** Document the counter mode workflow explicitly in the vignette: `creel_design()` → `add_counts()` → `estimate_effort()`. The error message is already informative — no code change needed.

**Warning signs:** `Error in estimate_effort: No survey design available` on a camera design.

### Pitfall 2: Negative Durations from Overnight Ingress-Egress Trips

**What goes wrong:** An angler enters the fishery before midnight and exits after midnight. The egress timestamp is on the next calendar day, but both are recorded on the same row with the ingress date as the key. `difftime()` returns a positive value, but it spans two calendar days — the effort is attributed entirely to the ingress day, which may be incorrect for day-type stratification.

**Why it happens:** Camera systems record raw timestamps; overnight fishing is common in warm-water fisheries.

**How to avoid:** `preprocess_camera_timestamps()` should warn when any single row has `duration_hours > 18` (implying overnight stay) and advise splitting at midnight. The vignette should document this edge case.

**Warning signs:** Unusually high daily effort hours for a single date; durations > 12 hours that look biologically implausible.

### Pitfall 3: Including `camera_status != "operational"` Rows in `add_counts()`

**What goes wrong:** User passes a counts frame that includes gap rows (NA count, battery failure status) to `add_counts()`. If the count column has NA for those rows, `add_counts()` may accept them silently. The survey design then includes NA count observations, which can propagate to biased or NA effort estimates.

**Why it happens:** The `camera_status` column is not yet visible to `add_counts()` — the function only sees the count column.

**How to avoid:** `preprocess_camera_timestamps()` and the vignette should explicitly filter operational rows before `add_counts()`:

```r
counts_operational <- subset(camera_counts, camera_status == "operational")
design <- add_counts(design, counts_operational, ...)
```

The RESEARCH.md, vignette, and dataset documentation must all reinforce this pattern.

**Warning signs:** Effort estimate is unexpectedly low; NA or NaN in the estimate output.

### Pitfall 4: Treating Camera Sub-Modes as Two Separate `design_type` Values

**What goes wrong:** Planning assigns `camera_mode` its own dispatch chain — e.g., treating `"counter"` and `"ingress_egress"` like `"bus_route"` and `"ice"` with separate functions.

**Why it happens:** The ice pattern (fill stub + dispatch guard) is fresh in memory and looks like the template. But ice needed a new dispatch because it replaced `design$survey` with a synthetic bus-route slot. Camera does not replace anything — both sub-modes use the same standard instantaneous path after preprocessing.

**How to avoid:** `camera_mode` is stored in `design$camera$camera_mode` for informational purposes (print method, vignette examples). It does NOT trigger a new dispatch branch in `estimate_effort()`. The dispatch remains: if bus_route/ice → bus-route path; else → standard instantaneous path.

**Warning signs:** A new `if (design$design_type == "camera")` block appears inside `estimate_effort()`.

### Pitfall 5: `creel_design()` Signature Missing `camera_mode`

**What goes wrong:** `camera_mode` is not added to the `creel_design()` function signature. The camera branch tries to access `camera_mode` but it does not exist as a parameter. R will look it up in the calling environment and silently pick up a variable named `camera_mode` from the user's workspace — or throw a cryptic error.

**Why it happens:** `effort_type` (ice) was added to the signature in Phase 45. `camera_mode` must also be added.

**How to avoid:** Add `camera_mode = NULL` to `creel_design()` signature. Validate inside the camera branch only (identical to how `effort_type` is handled for ice).

---

## Code Examples

Verified patterns from existing source:

### Camera Constructor Stub (current state — to be replaced)

```r
# Source: R/creel-design.R:519-522
camera <- NULL
if (identical(survey_type, "camera")) {
  camera <- list(survey_type = "camera")
  # Phase 46 will inject camera_status checks here
}
```

### Ice Constructor Pattern (template for camera)

```r
# Source: R/creel-design.R:377-515 — effort_type validation template
if (identical(survey_type, "ice")) {
  valid_ice_effort_types <- c("time_on_ice", "active_fishing_time")
  if (is.null(effort_type) || !effort_type %in% valid_ice_effort_types) {
    cli::cli_abort(c(
      "{.arg effort_type} is required for {.val ice} survey designs.",
      "x" = if (is.null(effort_type)) {
        "No {.arg effort_type} supplied."
      } else {
        "Unknown {.arg effort_type}: {.val {effort_type}}."
      },
      "i" = "Valid values: {.val {valid_ice_effort_types}}."
    ))
  }
  # ...
}
```

### `difftime()` for Ingress-Egress Preprocessing

```r
# Base R — no new dependency
duration_hours <- as.numeric(
  difftime(egress_timestamps, ingress_timestamps, units = "hours")
)
```

### Dispatch Guard That Camera Must NOT Break (current state)

```r
# Source: R/creel-estimates.R:332-339
# Camera is NOT in the exclusion list, so design$survey NULL check fires
if (!design$design_type %in% c("bus_route", "ice") && is.null(design$survey)) {
  cli::cli_abort(c(
    "No survey design available.",
    "x" = "Call {.fn add_counts} before estimating effort.",
    "i" = "Example: {.code design <- add_counts(design, counts)}"
  ))
}
```

### Example Dataset Pattern (from ice — direct template)

```r
# Source: data-raw/create_example_ice_interviews.R
example_camera_counts <- data.frame(
  date         = as.Date(c(...)),
  day_type     = c("weekday", "weekend", ...),
  ingress_count = c(45L, 62L, NA_integer_, ...),  # NA for gap row
  camera_status = c("operational", "operational", "battery_failure", ...),
  stringsAsFactors = FALSE
)
stopifnot(all(example_camera_counts$camera_status %in%
  c("operational", "battery_failure", "memory_full", "occlusion")))
usethis::use_data(example_camera_counts, overwrite = TRUE)
```

### Vignette Workflow Template (counter mode)

```r
# Counter mode: treat like instantaneous counts
design <- creel_design(example_calendar, date = date, strata = day_type,
                       survey_type = "camera", camera_mode = "counter")

# Filter out non-random gaps before add_counts()
operational_counts <- subset(example_camera_counts, camera_status == "operational")

design <- add_counts(design, operational_counts, count = ingress_count)
effort  <- estimate_effort(design)
```

### Vignette Workflow Template (ingress-egress mode)

```r
# Ingress-egress mode: preprocess timestamp pairs first
daily_effort <- preprocess_camera_timestamps(
  timestamps   = example_camera_timestamps,
  date_col     = date,
  ingress_col  = ingress_time,
  egress_col   = egress_time
)

design <- creel_design(example_calendar, date = date, strata = day_type,
                       survey_type = "camera", camera_mode = "ingress_egress")
design <- add_counts(design, daily_effort, count = daily_effort_hours)
effort  <- estimate_effort(design)
```

### Print Method Extension

```r
# Source: R/creel-design.R:2058-2067 — Ice section in format.creel_design()
# Camera equivalent to add after ice section:
if (!is.null(x$camera)) {
  cli::cli_h2("Camera Survey Design")
  cli::cli_text("Camera mode: {.val {x$camera$camera_mode}}")
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Camera returns minimal stub `list(survey_type = "camera")` | Constructor enforces `camera_mode`, validates at construction time | Phase 46 | Users get fail-fast validation before data attachment |
| No ingress-egress preprocessing helper | `preprocess_camera_timestamps()` converts timestamp pairs to daily hours | Phase 46 | Ingress-egress users have a documented, validated preparation step |
| No `camera_status` concept in package | `camera_status` column contract documented in datasets and vignette | Phase 46 | Biologists can record non-random failures without confounding effort estimates |

**No deprecated patterns in this phase.** The camera stub (Phase 44) exists solely to be replaced.

---

## Open Questions

1. **Should `camera_status_col` be a parameter to `creel_design()`?**
   - What we know: ice has `effort_type` as a constructor parameter because it affects the estimator output column name. Camera status does NOT affect the estimator.
   - What's unclear: whether storing the column name at construction time helps `add_counts()` provide a better error if the column is missing from the counts frame.
   - Recommendation: Do NOT add `camera_status_col` to `creel_design()`. Store nothing about `camera_status` in the design object. Document the filtering workflow in the vignette. This is the simpler path that avoids adding complexity that buys no statistical value.

2. **Should the example data use one combined frame or two separate frames for counter vs. ingress-egress?**
   - What we know: ice uses two separate datasets (`example_ice_sampling_frame`, `example_ice_interviews`).
   - What's unclear: whether a single `example_camera_counts` frame with a `camera_mode` column is more educational, or whether separate `example_camera_counter_counts` and `example_camera_ingress_egress` frames are cleaner.
   - Recommendation: Two separate data frames — `example_camera_counts` (counter mode, with gap row) and `example_camera_timestamps` (raw ingress-egress POSIXct pairs for preprocessing demo). A shared `example_camera_interviews` for catch estimation. Three datasets total, paralleling the ice pattern.

3. **How many plans does Phase 46 need?**
   - Phase 45 (ice) used 3 plans: (1) constructor + effort dispatch, (2) interview pipeline, (3) example data + vignette.
   - Camera has less dispatch work (no synthetic bus_route slot, no new estimator) but has the new `preprocess_camera_timestamps()` function.
   - Recommendation: 3 plans: (1) constructor stub fill + `camera_mode` validation + `preprocess_camera_timestamps()` + counter mode effort test (CAM-01, CAM-02, CAM-03); (2) interview pipeline + catch estimation confirmation (CAM-04); (3) example datasets + vignette (CAM-05).

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
| CAM-01 | `creel_design(survey_type = "camera", camera_mode = "counter")` constructs without error | unit | `devtools::test(filter = "creel-design")` | ✅ (`test-creel-design.R`) |
| CAM-01 | `add_counts()` accepts camera design; `estimate_effort()` returns valid result | unit | `devtools::test(filter = "estimate-effort")` | ✅ (`test-estimate-effort.R`) |
| CAM-01 | `camera_mode` missing on camera design aborts with informative message | unit | `devtools::test(filter = "creel-design")` | ✅ |
| CAM-02 | `preprocess_camera_timestamps()` converts POSIXct pairs to daily numeric hours | unit | `devtools::test(filter = "creel-design")` | ✅ (new tests appended) |
| CAM-02 | Negative durations produce a `cli_warn()` and set NA | unit | `devtools::test(filter = "creel-design")` | ✅ |
| CAM-02 | Preprocessed output passes `add_counts()` → `estimate_effort()` successfully | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| CAM-03 | Example dataset contains at least one `camera_status = "battery_failure"` row | unit/data | `devtools::test(filter = "creel-design")` | ✅ (Wave 0 gap — data scripts) |
| CAM-03 | Filtering `camera_status != "operational"` before `add_counts()` produces valid effort estimate | unit | `devtools::test(filter = "estimate-effort")` | ✅ |
| CAM-04 | `add_interviews()` on camera design constructs non-NULL `interview_survey` | unit | `devtools::test(filter = "add-interviews")` | ✅ (`test-add-interviews.R`) |
| CAM-04 | `estimate_catch_rate()` returns valid result on camera design | unit | `devtools::test(filter = "estimate-catch-rate")` | ✅ |
| CAM-04 | `estimate_total_catch()` returns valid result on camera design | unit | `devtools::test(filter = "estimate-total-catch")` | ✅ |
| CAM-05 | `example_camera_counts` and `example_camera_interviews` objects load without error | data | `devtools::test(filter = "data")` | ❌ Wave 0 gap |

### Sampling Rate

- **Per task commit:** `devtools::test(filter = "creel-design")` (covers constructor + preprocessing + validation)
- **Per wave merge:** `devtools::test()` — full 1622+ suite must stay green
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `data-raw/create_example_camera_counts.R` — counter mode counts + gap row (CAM-03, CAM-05)
- [ ] `data-raw/create_example_camera_timestamps.R` — raw ingress/egress POSIXct pairs (CAM-02, CAM-05)
- [ ] `data-raw/create_example_camera_interviews.R` — angler interviews for catch estimation (CAM-04, CAM-05)
- [ ] `vignettes/camera-surveys.Rmd` — complete workflow vignette (CAM-05)

All test files already exist — tests will be appended to existing files following the ice pattern.

---

## Sources

### Primary (HIGH confidence)

- Direct code inspection of `R/creel-design.R` — camera stub L519-522; ice constructor template L377-515; `creel_design()` signature (all parameters); `add_counts()` L926-1045; `add_interviews()` L1612-1865; Tier 3 validation L1691-1710; print method L2058-2067
- Direct code inspection of `R/creel-estimates.R` — dispatch guard L332-339; bus-route/ice block L342-387; interview_survey guard L1239; `estimate_harvest_rate()` bus-route guard L1251
- Direct code inspection of `R/creel-estimates-total-catch.R` — bus-route/ice guard L130-131
- Direct code inspection of `tests/testthat/test-creel-design.R` — camera stub test L898-905; ice test structure L887-1115
- Direct code inspection of `data-raw/create_example_ice_interviews.R` — example data creation pattern
- Direct code inspection of `.planning/STATE.md` — architecture decisions: "Camera has two sub-modes: counter (access-point path) and ingress-egress (timestamp preprocessing)"; "camera_status column needed for informative missingness — distinct from missing_sections random gaps"

### Secondary (MEDIUM confidence)

- `.planning/phases/45-ice-fishing-survey-support/45-RESEARCH.md` — confirmed dispatch guard locations and architectural patterns; ice constructor pattern is direct template for camera constructor
- `.planning/REQUIREMENTS.md` — CAM-01 through CAM-05 requirements and success criteria
- `.planning/ROADMAP.md` — Phase 46 goal and success criteria description

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all packages confirmed in DESCRIPTION
- Architecture: HIGH — all integration points confirmed by direct source inspection; camera uses standard instantaneous path with zero dispatch changes; all line numbers verified
- Pitfalls: HIGH — all pitfalls confirmed by reading actual code paths, not by inference
- `preprocess_camera_timestamps()` design: HIGH — `difftime()` is base R with well-known behavior; aggregation pattern is straightforward

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (codebase stable; no external dependencies changing)
