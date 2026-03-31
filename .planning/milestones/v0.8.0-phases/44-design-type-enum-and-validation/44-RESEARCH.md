# Phase 44: Design Type Enum and Validation - Research

**Researched:** 2026-03-15
**Domain:** R package dispatch infrastructure — survey_type enum, creel_design() constructor, Tier 1 validation
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INFRA-01 | User can create a creel design with `survey_type = "ice"`, `"camera"`, or `"aerial"`, with type-specific Tier 1 validation | Constructor needs recognized-types check + per-type validation block following bus_route pattern |
| INFRA-02 | An unrecognized `design_type` aborts with a clear `cli_abort()` message — no silent fall-through to wrong estimators | Single `%in%` guard at the top of `creel_design()` using a `VALID_SURVEY_TYPES` character vector |
| INFRA-03 | All existing tests pass after each new design type dispatch block is added | Confirmed: 1,588 tests pass on v0.7.0 baseline; guard must be placed after existing `bus_route` branch so it does not change existing behavior |
</phase_requirements>

---

## Summary

Phase 44 is a pure infrastructure phase that closes the `creel_design()` dispatch layer against unknown `survey_type` values and registers three new recognized types (`"ice"`, `"camera"`, `"aerial"`) before any estimation code is written. Nothing in the estimation pipeline changes — no new S3 class, no new Imports, no new estimator. The entire deliverable lives in `creel-design.R` and its test file.

The codebase already has a working template: the `bus_route` branch in `creel_design()` (lines 263-354) and the Tier 1 validation block in `validate_creel_design()` (lines 429-542) together demonstrate exactly how a new survey type is registered. Phase 44 replicates that pattern three times (plus adds the enum guard) rather than inventing anything new.

The success criteria are precise: the three new types construct without error given required inputs, an unknown type aborts immediately with a named error, all 1,588 existing tests stay green, and missing required columns for each new type abort at `creel_design()` time. No estimation code is in scope.

**Primary recommendation:** Add a single `VALID_SURVEY_TYPES` character vector and an early `cli_abort()` guard in `creel_design()`, then add three lightweight constructor+validation blocks following the bus_route pattern exactly. Keep each new type's required-parameter surface minimal — only what is known to be needed at construction time, not what future estimators will need.

---

## Standard Stack

### Core (all already in DESCRIPTION Imports)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| cli | current | `cli_abort()` for all user-facing errors | Established in every existing validation block |
| rlang | current | `rlang::caller_env()`, `enquo()`, quosure handling | Used by all tidy-selector resolution helpers |
| checkmate | current | `assert_*` for structural checks | Used in `validate_calendar_schema()` and siblings |
| tidyselect | current | Column resolution helpers | Used by `resolve_single_col()`, `resolve_multi_cols()` |

No new packages needed. Architecture decision from STATE.md: "No new R packages in Imports — all three survey types use existing survey package infrastructure."

**Installation:** None — all dependencies already declared.

---

## Architecture Patterns

### How the Existing Dispatch Works

`creel_design()` currently branches on `survey_type` with a single `if (identical(survey_type, "bus_route"))` check. There is no fall-through guard — any unrecognized string silently produces an `"instantaneous"`-behaving design object with `design_type` set to whatever string the user passed. Phase 44 closes this hole.

### Recommended Structure After Phase 44

```
R/creel-design.R (existing file)
├── VALID_SURVEY_TYPES constant (new)  — character vector at file top
├── creel_design() (modified)
│   ├── validate_calendar_schema()     — unchanged, runs first
│   ├── resolve tidy selectors         — unchanged
│   ├── enum guard (new)               — cli_abort() if not in VALID_SURVEY_TYPES
│   ├── site_col resolution            — unchanged
│   ├── bus_route branch               — unchanged
│   ├── ice branch (new)               — Tier 1 validation for ice type
│   ├── camera branch (new)            — Tier 1 validation for camera type
│   ├── aerial branch (new)            — Tier 1 validation for aerial type
│   └── new_creel_design() + validate_creel_design()  — unchanged
tests/testthat/test-creel-design.R (existing file, extended)
├── enum guard tests (new)             — unknown_type aborts, known types pass
├── ice construction tests (new)
├── camera construction tests (new)
└── aerial construction tests (new)
```

### Pattern 1: Enum Guard (INFRA-02)

**What:** A character vector of all recognized `survey_type` values; a `cli_abort()` call early in `creel_design()` if the supplied value is not in that vector.

**When to use:** Once, placed after structural calendar validation but before any type-specific branching.

**Example:**
```r
# At file top or near creel_design():
VALID_SURVEY_TYPES <- c("instantaneous", "bus_route", "ice", "camera", "aerial")

# Inside creel_design(), after validate_calendar_schema():
if (!survey_type %in% VALID_SURVEY_TYPES) {
  cli::cli_abort(c(
    "{.arg survey_type} {.val {survey_type}} is not recognized.",
    "x" = "Unknown survey type: {.val {survey_type}}.",
    "i" = "Valid types are: {.val {VALID_SURVEY_TYPES}}."
  ))
}
```

**Placement rationale:** Must come after calendar schema validation (which runs unconditionally) but before the `bus_route` branch and the new type branches. This order does not change any existing code paths.

### Pattern 2: Per-Type Constructor Block (INFRA-01)

**What:** A lightweight `if (identical(survey_type, "ice"))` block (and analogous for camera, aerial) that validates required Tier 1 parameters and stores type metadata in the design object. Mirrors the bus_route branch structure exactly.

**When to use:** After the enum guard, as parallel branches. Each branch runs only when `survey_type` matches.

**Example (ice type):**
```r
ice <- NULL
if (identical(survey_type, "ice")) {
  # Ice fishing: degenerate bus-route with p_site = 1.0 enforced (Phase 45 will use this)
  # Tier 1 validation at construction time: enforce that calendar has required columns
  # Minimal for Phase 44 — future phases add estimation parameters
  ice <- list(
    survey_type = "ice"
    # Phase 45 will add: p_site = 1.0, effort_type, shelter_col
  )
}
```

**Key constraint from STATE.md:** "INFRA phase is prerequisite — enum must be locked before any estimation code is written." Phase 44 should NOT try to anticipate all the parameters Phases 45-47 will need. Register the types as valid; enforce only what is knowable at construction time without estimation context.

### Pattern 3: Tier 1 Validation Block in validate_creel_design() (INFRA-01)

**What:** Per-type validation blocks inside `validate_creel_design()` that run after object construction. Follow the existing bus_route validation block exactly.

**Example:**
```r
# In validate_creel_design():
if (identical(x$design_type, "ice")) {
  # Tier 1 checks for ice: minimal in Phase 44
  # Example: check that strata columns are present (already guaranteed by base validation)
}

if (identical(x$design_type, "camera")) {
  # Tier 1 checks for camera
}

if (identical(x$design_type, "aerial")) {
  # Tier 1 checks for aerial
}
```

### What Tier 1 Means in This Codebase

Looking at the existing `validate_creel_design()` implementation, Tier 1 validation checks:
- Column types (Date, character/factor, numeric)
- Absence of NA in required columns
- Probability range constraints (bus_route specific)
- Structural constraints detectable from the data at construction time

Tier 1 does NOT validate estimation-time parameters (sample size, join keys, count data). Those checks live in `add_counts()`, `add_interviews()`, and the estimator functions.

**For Phase 44, Tier 1 requirements per type:**
- `"ice"`: No estimation-specific parameters yet. Construction succeeds given a valid calendar + strata. The Phase 44 requirement is that it constructs without error and stores `design_type = "ice"`. Phase 45 adds enforcement of `p_site = 1.0` and effort-type specification.
- `"camera"`: Same — valid calendar + strata is sufficient for Phase 44 construction. Phase 46 adds `camera_status` column requirement.
- `"aerial"`: Same — valid calendar + strata. Phase 47 adds visibility correction factor parameter.

The success criterion "missing required columns abort at `creel_design()`" refers to columns that are definitionally required by the survey type at construction time. For ice/camera/aerial in Phase 44, the calendar columns (date, strata) are already required by the base validator. Type-specific column requirements are added in Phases 45-47 when those requirements are known.

### Anti-Patterns to Avoid

- **Pre-implementing Phase 45-47 parameters in Phase 44.** The phase boundary is intentional. Only register the types and add the enum guard.
- **Using `switch()` instead of `if/else if` branches.** The codebase uses `if (identical(...))` for type dispatch consistently (see bus_route branch). Match the pattern.
- **Placing the enum guard after the bus_route branch.** The guard must be early so an unknown type aborts before any type-specific code runs.
- **Adding the guard to `validate_creel_design()` instead of `creel_design()`.** INFRA-02 says "aborts immediately" — this means at the public constructor, not in the internal validator.
- **Using `match.arg()`.** The `survey_type` parameter is not declared with explicit choices in the function signature (it inherits from `design_type`). `match.arg()` requires that pattern. Use explicit `%in%` check instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Formatted error messages | Custom paste() error strings | `cli::cli_abort()` with named vector | Established pattern in every existing error; cli provides {.val}, {.arg}, {.cls} formatting |
| Column type checking | `if (is.character(...) && ...)` chains | `checkmate::assert_*` via collection | Used in `validate_calendar_schema()` — collect all errors, report together |
| Tidy column resolution | Manual `match()` on column names | `resolve_single_col()` / `resolve_multi_cols()` | Already exist in the file; handle error reporting and empty selection |

**Key insight:** The entire infrastructure this phase needs already exists in `creel-design.R`. No new helpers required.

---

## Common Pitfalls

### Pitfall 1: Enum Guard Breaks Existing Tests

**What goes wrong:** If `VALID_SURVEY_TYPES` omits `"instantaneous"` or `"bus_route"`, every existing test that creates a design (nearly all 1,588 tests) will start failing with the new abort.

**Why it happens:** Easy to forget that `"instantaneous"` and `"bus_route"` must be in the valid set.

**How to avoid:** `VALID_SURVEY_TYPES <- c("instantaneous", "bus_route", "ice", "camera", "aerial")` — include all five. Confirm 1,588 still pass after adding the guard.

**Warning signs:** Any test outside `test-creel-design.R` failing after adding the guard.

### Pitfall 2: Positioning the Guard After the bus_route Branch

**What goes wrong:** If the guard is placed after `if (identical(survey_type, "bus_route")) { ... }`, then `survey_type = "bus_route"` still works but the guard is now dead code for bus_route.

**Why it happens:** Copy-paste from bus_route block positioning.

**How to avoid:** Guard comes first (after calendar schema check and tidy selector resolution), before all type-specific branches.

### Pitfall 3: Over-Specifying Tier 1 for Phase 44

**What goes wrong:** Adding `sampling_frame`-like required parameters for ice/camera/aerial before those parameters are specified in Phases 45-47. This creates breaking changes when Phase 45 defines the actual API.

**Why it happens:** Trying to anticipate downstream needs.

**How to avoid:** Phase 44 Tier 1 = "does the calendar have valid date and strata columns?" for all three new types. That is already checked by the base validator. The per-type blocks in Phase 44 are essentially stubs that store `design_type = "ice"` etc. and confirm construction succeeds.

### Pitfall 4: design_type vs survey_type Field Naming

**What goes wrong:** The object field is `design_type` (set by `new_creel_design(design_type = survey_type)`), but the constructor parameter is `survey_type`. Test assertions check `design$design_type`. Using `design$survey_type` in tests would silently return NULL.

**Why it happens:** The `design_type`/`survey_type` duality in the codebase (kept for backward compatibility).

**How to avoid:** Always assert `expect_equal(design$design_type, "ice")` not `design$survey_type`. The field on the object is always `design_type`.

---

## Code Examples

Verified patterns from the existing codebase source:

### How bus_route Type Is Checked (the model to follow)
```r
# Source: R/creel-design.R line 263
if (identical(survey_type, "bus_route")) {
  if (is.null(sampling_frame) || !is.data.frame(sampling_frame)) {
    cli::cli_abort(c(
      "{.arg sampling_frame} must be a data frame when {.arg survey_type} is {.val bus_route}.",
      "i" = "Provide a data frame with site, probability, and optional circuit columns."
    ))
  }
  # ... more checks ...
  bus_route <- list(...)
}
```

### How Tier 1 Validation Is Structured
```r
# Source: R/creel-design.R lines 429-542 (validate_creel_design)
validate_creel_design <- function(x) {
  cal <- x$calendar

  # Each check: test condition, cli_abort() with c() named vector
  if (!inherits(cal[[x$date_col]], "Date")) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must be of class {.cls Date}.",
      "x" = "Column {.var {x$date_col}} is {.cls {class(cal[[x$date_col]])[1]}}.",
      "i" = "Convert with {.code as.Date()}."
    ))
  }

  # bus_route block:
  if (!is.null(x$bus_route)) {
    # ... probability range checks ...
  }

  invisible(x)
}
```

### How Tests Assert survey_type Rejection (pattern to extend)
```r
# Source: R/tests/testthat/test-creel-design.R (bus_route error tests, e.g. line 353)
expect_error(
  creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route"
    # missing sampling_frame
  ),
  class = "rlang_error"
)
```

### How to Test the Enum Guard (new pattern)
```r
# New test for INFRA-02
test_that("creel_design() aborts on unrecognized survey_type", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  expect_error(
    creel_design(cal, date = date, strata = day_type,
                 survey_type = "unknown_type"),
    class = "rlang_error"
  )
})

# Verify error message names the unrecognized type
test_that("enum guard error message names the bad survey_type", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  expect_error(
    creel_design(cal, date = date, strata = day_type,
                 survey_type = "unknown_type"),
    regexp = "unknown_type"
  )
})
```

### How to Test New Type Construction (INFRA-01)
```r
# New test — ice type constructs
test_that("creel_design() accepts survey_type = 'ice'", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  d <- creel_design(cal, date = date, strata = day_type,
                    survey_type = "ice")
  expect_s3_class(d, "creel_design")
  expect_equal(d$design_type, "ice")
})
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No enum guard — any string accepted silently | Explicit `VALID_SURVEY_TYPES` vector + `cli_abort()` guard | Phase 44 (now) | Prevents silent routing of unknown types to wrong estimators |
| Only "instantaneous" and "bus_route" recognized | Five recognized types: instantaneous, bus_route, ice, camera, aerial | Phase 44 (now) | Locks the enum before estimation code is written |

**Not deprecated/changed:** `design_type` field on the object (kept for backward compat), `design_type` parameter (kept as alias for `survey_type`), all existing validation logic.

---

## Open Questions

1. **Minimal Tier 1 parameter surface for each new type in Phase 44**
   - What we know: Phase 45 will add `p_site = 1.0` enforcement for ice; Phase 46 will add `camera_status` for camera; Phase 47 will add visibility correction for aerial.
   - What's unclear: Should Phase 44 register any type-specific required parameters, or purely accept valid calendar + strata?
   - Recommendation: Accept valid calendar + strata for all three types in Phase 44. The success criterion says "missing required columns abort at `creel_design()`" — since no new required columns are defined until Phases 45-47, this criterion is satisfied by the base calendar validator for now. Add a comment in each stub block marking where Phase 45/46/47 will inject parameter checks.

2. **Where to store the `VALID_SURVEY_TYPES` constant**
   - What we know: R packages conventionally use module-level constants in the same file that uses them.
   - What's unclear: Whether to use an internal helper like `valid_survey_types()` function or a file-level constant.
   - Recommendation: File-level character vector at the top of `creel-design.R`, not exported. Keeps it close to the guard and the branch logic.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat (version from DESCRIPTION) |
| Config file | `tests/testthat.R` |
| Quick run command | `devtools::test(filter = "creel-design")` |
| Full suite command | `devtools::test()` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-02 | Unknown survey_type aborts with cli_abort() naming the type | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-02 | Error message contains the unrecognized type string | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-01 | `survey_type = "ice"` constructs without error | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-01 | `survey_type = "camera"` constructs without error | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-01 | `survey_type = "aerial"` constructs without error | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-01 | Ice design stores `design_type = "ice"` on the object | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-01 | Camera design stores `design_type = "camera"` on the object | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-01 | Aerial design stores `design_type = "aerial"` on the object | unit | `devtools::test(filter = "creel-design")` | ❌ Wave 0 |
| INFRA-03 | All 1,588 existing tests pass after changes | regression | `devtools::test()` | ✅ existing |

### Sampling Rate

- **Per task commit:** `devtools::test(filter = "creel-design")`
- **Per wave merge:** `devtools::test()`
- **Phase gate:** Full suite green (0 FAIL) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] New test cases in `tests/testthat/test-creel-design.R` — covers INFRA-01, INFRA-02 (extend existing file, no new file needed)

*(No new test files needed — all new tests belong in the existing `test-creel-design.R` file alongside the bus_route test block.)*

---

## Sources

### Primary (HIGH confidence)

- `R/creel-design.R` (lines 222-542) — `creel_design()` constructor and `validate_creel_design()` — direct code inspection, confirmed working pattern
- `R/validate-schemas.R` — `validate_calendar_schema()` pattern — direct code inspection
- `tests/testthat/test-creel-design.R` (lines 264-274) — existing bus_route test pattern for new type tests
- `.planning/STATE.md` — Architecture decisions: no new packages, no new S3 class, build order locked

### Secondary (MEDIUM confidence)

- `.planning/REQUIREMENTS.md` — INFRA-01, INFRA-02, INFRA-03 definitions
- `.planning/ROADMAP.md` — Phase 44 success criteria and relationship to Phases 45-47

### Tertiary (LOW confidence)

None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in the package, no new dependencies
- Architecture: HIGH — based on direct code inspection of the exact patterns to replicate
- Pitfalls: HIGH — derived from reading the existing code paths that would be affected
- Test patterns: HIGH — confirmed 1,588 tests passing, test file structure examined

**Research date:** 2026-03-15
**Valid until:** Stable — this is internal codebase research, not dependent on external library releases
