# tidycreel v1.3.0 — Error Handling Strategy

**Prepared:** 2026-04-15
**Phase:** 73 — Error Handling Strategy & creel.connect Investigation
**Status:** Final — canonical pattern declared

---

## Executive Summary

The tidycreel package has a single dominant, well-established error handling convention: `cli::cli_abort()` called with a named character vector following the unnamed-summary / `"x"` = problem / `"i"` = suggestion structure. This pattern appears **368 times across 30+ R files** and is unambiguously the standard. The package is ready to declare it canonical.

There are exactly four deviations from the canonical pattern. Two are intentional tryCatch re-raise idioms that must not be changed. One is an approved exception where `cli::cli_warn` lacks required functionality. One is a cosmetic call-site style issue in an internal helper with zero user-facing impact. None of these represent a divergent convention or design problem.

A second canonical pattern — propagating caller-environment context through `rlang::caller_env()` — is established across all major estimation entry points. A third — batch-collecting validation failures before aborting — is correctly placed in validation functions and documented as intentional.

**Verdict:** The error handling posture of the package is sound. The canonical pattern is consistent, well-established, and contributor-ready. Low-priority cleanup of the four deviations is the only action needed.

---

## 1. Canonical Pattern: `cli::cli_abort`

`cli::cli_abort()` with a named character vector is the tidycreel standard for signalling errors from public functions and internal helpers.

### Copy-Paste Reference

```r
cli::cli_abort(c(
  "The {.arg survey_type} is not supported for this estimator.",
  "x" = "{.val {survey_type}} is not one of the accepted types.",
  "i" = "Use one of: {.val {c('instantaneous', 'bus_route', 'ice')}}."
))
```

### Element Roles

| Element | Role |
|---------|------|
| Unnamed first element | Error summary — rendered as the condition message. Describes what went wrong in one sentence. |
| `"x"` | Specific problem — names the bad value, column, or argument with inline formatting. Multiple `"x"` bullets are common when several things are wrong. |
| `"i"` | Actionable suggestion — tells the user what to do. Multiple `"i"` bullets are common. |

The `{.arg}`, `{.val}`, and `{.fn}` inline formatting markers from the cli package are used throughout to produce consistently styled, readable error messages. Contributors should use these in all new `cli_abort` calls.

### Call-Site Frequency

`cli::cli_abort` is the largest consistent error-handling convention in the codebase by a wide margin.

| File | `cli_abort` calls |
|------|-------------------|
| `creel-design.R` | 82 |
| `creel-estimates.R` | 46 |
| `creel-summaries.R` | 38 |
| `survey-bridge.R` | 21 |
| All other files | ~181 |
| **Total** | **368** |

No file has diverged into an alternative convention. The pattern is uniform across the package.

---

## 2. Canonical Pattern: Caller-Environment Propagation

In the design and estimation layers, internal helpers accept an `error_call` argument and pass it to `cli::cli_abort` via the `call =` parameter. This causes errors to surface at the user's call frame rather than deep inside an internal helper, producing error messages that name the user's function call — not an opaque internal.

### Internal Helper Form

```r
resolve_single_col <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  # ... processing ...
  cli::cli_abort(
    c("{.arg {arg_name}} column not found in data.",
      "x" = "Column {.val {col_name}} is missing from the supplied data frame."),
    call = error_call
  )
}
```

### Public API Form

```r
# Public function propagates its own caller environment down to the helper.
add_counts <- function(design, counts) {
  col <- resolve_single_col(count_quo, counts, "count", rlang::caller_env())
  # ...
}
```

This two-step ensures that when `add_counts()` fails, the error message names `add_counts` (the function the user called), not `resolve_single_col` (the internal helper that detected the problem).

### Established In

- `creel-design.R` — `resolve_single_col()`, `resolve_multi_cols()`, and all major design-layer helpers
- `creel-estimates-total-catch.R`
- `creel-estimates-total-release.R`
- `creel-estimates-total-harvest.R`
- `validate-incomplete-trips.R`

Contributors adding new internal helpers to these files should follow this pattern. New helpers that delegate to existing helpers should pass `rlang::caller_env()` down through the chain.

---

## 3. Canonical Pattern: Batch-Collection Validation

For public functions that validate data frames, a checkmate batch-collection approach is used to collect all validation failures before aborting. This gives users a complete list of problems in a single error message rather than requiring them to fix-and-rerun repeatedly.

### Skeleton

```r
collection <- checkmate::makeAssertCollection()
checkmate::assert_data_frame(data, min.rows = 1, add = collection)
checkmate::assert_names(names(data), must.include = required_cols, add = collection)
# ... additional assertions ...
if (!collection$isEmpty()) {
  msgs <- collection$getMessages()
  cli::cli_abort(c(
    "Validation failed:",
    stats::setNames(msgs, rep("x", length(msgs))),
    "i" = "Check the data frame structure and column names."
  ))
}
```

### Established In

- `validate-schemas.R`
- `creel-validation.R`

The batch-collection pattern is intentional and documented in the Phase 72 decision record. It is correct use of checkmate for data frame validation — all assertions are collected, then a single `cli_abort` fires with the complete list. This is distinct from guard conditions (single-assertion `assert_*` calls in internal helpers), which correctly use the non-collecting form.

---

## 4. Deviation Inventory

The following four call-sites depart from the canonical pattern. Each has a classification and disposition. Readers should note that D1 and D2 use `stop(e)` inside a `tryCatch` error handler — this is correct R idiom for re-raising an unhandled condition, and is **entirely distinct from** the anti-pattern of writing a bare `stop("message")` as a guard call. A bare `stop("message")` guard call (without a named vector, outside a tryCatch handler) would be an actual deviation worth converting to `cli_abort`. D1 and D2 are not that pattern.

---

### D1 — `stop(e)` re-raise in `survey-bridge.R`, line 141

**Location:** `get_variance_design()`, jackknife variance branch

**Code excerpt:**
```r
tryCatch(
  suppressWarnings(survey::as.svrepdesign(design, type = "auto")),
  error = function(e) {
    msg <- conditionMessage(e)
    if (grepl("has only one PSU", msg, fixed = TRUE)) {
      cli::cli_abort(c(
        "Cannot compute jackknife variance: only one PSU per stratum.",
        "x" = "...",
        "i" = "..."
      ))
    }
    stop(e)  # unknown error — re-propagated as-is
  }
)
```

**Classification:** Intentional tryCatch re-raise. The handler converts the specific, known "one PSU" error into an informative `cli_abort` message. Any other error from `survey::as.svrepdesign` is re-raised with `stop(e)` to preserve the original condition object, including its class and message. Converting this `stop(e)` to `cli_abort` would lose the original error class and prevent downstream code from matching on it.

**Disposition:** Leave as-is. See Recommendation R1 for a comment to add.

---

### D2 — `stop(e)` re-raise in `creel-estimates.R`, line 36

**Location:** Jackknife variance estimation tryCatch, same pattern as D1

**Classification:** Identical to D1 — intentional tryCatch re-raise preserving original condition. Not an anti-pattern.

**Disposition:** Leave as-is. See Recommendation R1.

---

### D3 — `rlang::warn(.frequency = "once")` in `survey-bridge.R`, lines 73–81

**Location:** `as_survey_design()` — warns when a user accesses the internal survey design object

**Code excerpt:**
```r
rlang::warn(
  message = c(
    "Accessing internal survey design object.",
    "i" = "This is an advanced feature; use with care.",
    "!" = "Modifying the survey design may produce incorrect variance estimates."
  ),
  .frequency = "once",
  .frequency_id = "tidycreel_as_survey_design"
)
```

**Classification:** Approved exception. The `.frequency = "once"` argument suppresses the warning after its first occurrence per R session — it fires once, then silently allows subsequent calls. This throttle behavior is **not available in `cli::cli_warn()`** — it is an `rlang::warn()` exclusive feature. Replacing this call with `cli::cli_warn` would silently lose the once-per-session suppression, causing the warning to fire on every call for users who invoke `as_survey_design()` repeatedly in a loop or interactive session. The deviation is functional, not an oversight.

**Disposition:** Document as an approved exception (see Recommendation R2). Do not convert to `cli::cli_warn` unless cli gains a `.frequency` parameter.

---

### D4 — Split-argument `cli::cli_warn()` in `validation-report.R`, lines 128–131

**Location:** Internal helper function (marked `@noRd`) in `validation-report.R`

**Code excerpt:**
```r
cli::cli_warn(
  "Column {.field {species_col}} not found in {.arg interviews}; ",
  "skipping species coverage check."
)
```

**Classification:** Cosmetic style deviation. `cli::cli_warn()` concatenates its arguments, so the behavior is correct — the user sees a single warning message. The departure is that the message is passed as two separate arguments rather than as a single string or named vector. Because this is an internal `@noRd` helper, user-facing impact is zero.

**Disposition:** Lowest priority cleanup candidate — fix in the next scheduled pass of `validation-report.R`. See Recommendation R3.

---

## 5. `stopifnot()` Usage — Not a Deviation

`stopifnot()` appears 8 times in the codebase, exclusively in:

- Internal constructors (`new_creel_schema`, `new_creel_connection`) — invariant guards on internal data that should never fail if the calling code is correct
- Internal calendar-building helpers — same invariant-guard context

This is the appropriate R idiom for asserting invariants on internal data. `stopifnot()` in this context means "this condition must always be true and if it isn't, something has gone wrong in the package internals." It is not a replacement for user-facing error handling and does not represent a deviation from the `cli_abort` convention. No action needed.

---

## 6. Positive Findings

The following healthy patterns are worth documenting explicitly so contributors know to preserve them.

**P1 — Pattern consistency across all major files.** No file has diverged into an alternative convention. `cli::cli_abort` with the named-vector structure is used uniformly in `creel-design.R`, `creel-estimates.R`, `creel-summaries.R`, `survey-bridge.R`, and all other major files. The 368-call count across 30+ files demonstrates that this pattern has been applied consistently throughout the package's development history.

**P2 — cli formatting throughout.** The `{.arg}`, `{.val}`, `{.fn}`, and `{.field}` inline formatting markers are used across all error and warning calls. This produces consistently styled messages that distinguish argument names (shown in green/cyan), values (shown quoted), and function names (shown with `()`) in the RStudio and terminal output. Contributors should continue using these markers rather than interpolating values directly with `{variable}`.

**P3 — Caller-environment propagation established across all estimation entry points.** The `rlang::caller_env()` + `call = error_call` pattern is present in all five major files listed in Section 2. Users running `estimate_total_catch()`, `estimate_total_release()`, or `estimate_total_harvest()` and encountering validation errors will see the error point at their own function call, not at an internal helper three levels deep. This is a significant contributor to error usability and should be maintained in all new estimation functions.

**P4 — Batch-collection pattern correctly scoped.** The checkmate batch-collection approach is used in `validate-schemas.R` and `creel-validation.R` — validation functions whose entire purpose is to check a data frame. It is not used in guard conditions or single-assertion helpers, where collecting failures would be counterproductive. The placement is correct.

---

## 7. Recommendations

All recommendations are low priority — the codebase is in good condition. The actions below represent small, targeted improvements with no risk of regressions.

---

### R1 — Add explanatory comments to `stop(e)` re-raise handlers

**What:** Add a brief inline comment above each `stop(e)` call in `survey-bridge.R` (line 141) and `creel-estimates.R` (line 36) explaining why `stop(e)` is used rather than `cli_abort`.

Example:
```r
# Re-raise unrecognised errors with stop(e) to preserve the original condition
# class and message. Converting to cli_abort would lose the original error class
# and prevent downstream code from matching on it.
stop(e)
```

**Why:** Future contributors may see `stop(e)` as an inconsistency and attempt to "fix" it by replacing with `cli_abort`, which would be a silent regression. A two-line comment prevents this.

**Priority:** Low. Do in next scheduled pass of those files.

---

### R2 — Add approved-deviation comment to `rlang::warn(.frequency = "once")`

**What:** Add a comment above the `rlang::warn()` call in `survey-bridge.R` (lines 73–81) marking it as an approved deviation and explaining the `.frequency` constraint.

Example:
```r
# Approved deviation from cli::cli_warn: rlang::warn() is required here
# because .frequency = "once" (suppress after first occurrence per session)
# is not available in cli::cli_warn(). Do not replace with cli_warn without
# verifying that cli has added .frequency support.
rlang::warn(...)
```

**Why:** Same reason as R1 — prevents a well-intentioned refactor from removing the throttle behavior silently.

**Priority:** Low. Do in next scheduled pass of `survey-bridge.R`.

---

### R3 — Fix split-argument `cli::cli_warn()` in `validation-report.R`

**What:** Combine the two string arguments into a single string in the `cli::cli_warn()` call at lines 128–131 of `validation-report.R`.

Before:
```r
cli::cli_warn(
  "Column {.field {species_col}} not found in {.arg interviews}; ",
  "skipping species coverage check."
)
```

After:
```r
cli::cli_warn(
  "Column {.field {species_col}} not found in {.arg interviews}; skipping species coverage check."
)
```

**Why:** Purely cosmetic — aligns the call with the named-vector convention and removes the implicit reliance on argument concatenation behavior. Zero user-facing impact.

**Priority:** Low. Do in next scheduled pass of `validation-report.R`.

---

### R4 — Named condition classes are deferred to Phase 74

**What:** Named condition classes (`class = "creel_invalid_survey_type"`, etc.) that allow programmatic error trapping with `tryCatch(error = function(e) inherits(e, "creel_xyz_error"))` are explicitly out of scope for this document.

**Why:** Deciding which errors deserve stable, named condition classes requires a broader quality audit to assess which errors are worth exposing as a programmatic interface. That audit belongs in Phase 74. This document declares the call-site convention canonical; Phase 74 can assess the condition-class question independently.

**Priority:** Informational only — not an action item for this phase.

---

## Appendix: Feeds Into Phase 74

This document establishes the baseline against which Phase 74 quality-checklist items will be assessed:

- The `cli::cli_abort` named-vector pattern (Sections 1–3) is the reference convention. Any quality checklist item about error handling consistency will measure deviation from this baseline.
- The four deviations in Section 4 are already inventoried and classified. Phase 74 does not need to re-examine them.
- Named condition classes (R4) are explicitly deferred to Phase 74.

---

*Phase: 73-error-handling-strategy*
*Document: 73-ERROR-STRATEGY.md*
*Written: 2026-04-15*
