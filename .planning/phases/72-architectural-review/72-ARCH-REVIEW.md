# Architectural Review: tidycreel v1.3.0

**Phase:** 72 — Architectural Principles & Dependency Review
**Reviewed:** 2026-04-15
**Confidence:** HIGH — all findings derived from direct code inspection of 38 R source files (21,956 lines), NAMESPACE, and DESCRIPTION
**Scope:** All package layers — prep, design, estimation, scheduling, summaries/viz; S3 class hierarchy

---

## Executive Summary

tidycreel v1.3.0 has a **structurally sound four-layer architecture**. The dominant pattern — lower layers produce typed objects consumed by higher layers, with a scheduling lane feeding into design — is respected throughout the codebase. Error handling, constructor discipline, and class naming are consistent across all survey types.

Four architectural findings were identified. None are critical. One is medium severity: a utility function (`get_site_contributions()`) lives in the wrong file, creating a discoverability trap for contributors. The remaining three are low severity: a deliberate validation-to-estimation coupling, a class misnomer, and a set of S3 subclass names that carry no behavioural weight.

Six positive findings are documented — patterns that are working well and should be explicitly preserved as the package grows.

**Overall verdict:** The architecture is healthy and maintainable. The actionable backlog is small: one file relocation (medium priority) and three low-priority housekeeping items.

| Finding | Severity | Type |
|---------|----------|------|
| A1: `get_site_contributions()` in wrong file | medium | Layering |
| A2: `validate_incomplete_trips()` calls estimation layer | low | Coupling |
| A3: `creel_design_comparison` class misnomer | low | Naming |
| A4: 9 `creel_summary_*` subclasses with no registered methods | low | S3 |

**Top recommendation:** Move `get_site_contributions()` from `creel-design.R` to `creel-estimates.R` or a new `creel-estimates-utils.R`. This is a one-function relocation with no behaviour change.

---

## Layer Architecture Map

The package has a four-layer architecture with one parallel lane. Downward calls (higher layers consuming lower-layer objects) are expected and present everywhere. Upward calls (lower layers calling higher-layer internals) are the definition of a violation.

```
Layer 0: Data Preparation
  prep-counts.R          prep_counts_boat_party(), prep_counts_daily_effort()
  prep-interviews.R      prep_interviews_trips(), prep_interview_catch()

Layer 1: Design Construction  (primary coupling surface)
  creel-design.R         creel_design(), add_counts(), add_sections(),
                         add_interviews(), add_catch(), add_lengths()
  survey-bridge.R        as_survey_design(), build_*_survey() internals

Layer 1a: Scheduling  (parallel lane, feeds into Layer 1)
  schedule-generators.R  generate_schedule(), generate_bus_schedule(),
                         generate_count_times(), attach_count_times()
  schedule-io.R          write_schedule(), read_schedule()
  schedule-print.R       format/print for creel_schedule

Layer 2: Estimation  (consumers of Layer 1)
  creel-estimates.R             estimate_effort(), estimate_catch_rate(),
                                estimate_harvest_rate(), estimate_release_rate()
  creel-estimates-bus-route.R   estimate_*() for bus-route survey type
  creel-estimates-aerial.R      estimate_effort_aerial_*()
  creel-estimates-aerial-glmm.R estimate_effort_aerial_glmm()
  creel-estimates-camera.R      est_effort_camera()
  creel-estimates-length.R      est_length_distribution()
  creel-estimates-total-catch.R    estimate_total_catch()
  creel-estimates-total-harvest.R  estimate_total_harvest()
  creel-estimates-total-release.R  estimate_total_release()

Layer 3: Summaries / Visualization  (consumers of Layer 1 and Layer 2)
  creel-summaries.R      summarize_by_*(), summarize_cws_rates(),
                         summarize_hws_rates(), summarize_length_freq()
  autoplot-methods.R     autoplot.creel_estimates(), autoplot.creel_schedule(),
                         autoplot.creel_design_comparison()
  season-summary.R       season_summary()
  creel-validation.R     creel_validation()

Cross-cutting  (validation and comparison utilities — operate on Layer 1 or 2 objects)
  design-validator.R          validate_design(), check_completeness()
  validate-incomplete-trips.R validate_incomplete_trips()
  validate-creel-data.R       validate_creel_data()
  validation-report.R         validation_report()
  compare-designs.R           compare_designs()
  compare-variance.R          compare_variance()
  nonresponse-adjust.R        adjust_nonresponse()
  write-estimates.R           write_estimates()
```

**Note on file size:** `creel-estimates.R` (3,700 lines) and `creel-design.R` (3,424 lines) are large but not a primary architectural concern. They each have a coherent single responsibility — estimation dispatch and design construction, respectively. Size alone is not a violation, but it does increase the cost of code navigation and the risk of incidental coupling growing unnoticed.

---

## Architectural Findings

### A1: `get_site_contributions()` Is in the Wrong File

**Severity:** medium

| | |
|---|---|
| **File** | `creel-design.R` |
| **Function** | `get_site_contributions(x)` — defined at line 2533 |
| **Layer** | Defined in Layer 1 (design), operates on Layer 2 (estimation) output |

**Description.** `get_site_contributions()` is grouped alongside three sibling functions in `creel-design.R`:

- `get_sampling_frame()` — accepts a `creel_design` object
- `get_inclusion_probs()` — accepts a `creel_design` object
- `get_enumeration_counts()` — accepts a `creel_design` object
- `get_site_contributions()` — accepts a **`creel_estimates`** object

The input guard at the top of `get_site_contributions()` explicitly requires `inherits(x, "creel_estimates")`. The function cannot be called with a design object. A contributor browsing `creel-design.R` for design utilities will find all four `get_*` functions together and reasonably assume they all accept `creel_design` objects. Only `get_site_contributions()` does not — it operates on fully estimated output that is only available after Layer 2 processing.

**Why it happened.** The four functions were likely added together as a conceptual group of "bus-route inspection utilities." At that point, `get_site_contributions()` may have been intended to work on design objects, or the input type distinction was not noticed. The function was never moved.

**Impact.** This is a discoverability trap, not a runtime bug. Users looking for estimation-level utilities will not find `get_site_contributions()` in the estimation files. Users browsing design files may call `get_site_contributions()` with a design object and receive a non-obvious error. See Recommendation R1.

---

### A2: `validate_incomplete_trips()` Calls into the Estimation Layer

**Severity:** low

| | |
|---|---|
| **File** | `validate-incomplete-trips.R` |
| **Function** | `validate_incomplete_trips()` — lines 207–430 |
| **Calls** | `estimate_catch_rate()` (called twice internally) |

**Description.** `validate_incomplete_trips()` is a cross-cutting validation utility, but it calls `estimate_catch_rate()` twice internally — once for complete trips and once for incomplete trips — to perform TOST (two one-sided tests) equivalence testing. This creates a direct dependency from the validation layer into Layer 2 (estimation).

**Why it happened.** The TOST method is genuinely estimate-based: it requires real CPUE estimates to compare trip cohorts. Calling `estimate_catch_rate()` is the straightforward implementation choice. The coupling is intentional, not accidental.

**Impact.** The practical cost is that validation tests must pull in the full estimation engine. This is not a layering violation in the strict sense (the validation cross-cutting layer calling estimation is not an "upward" call that would introduce circular dependencies), but it means `validate-incomplete-trips.R` cannot be tested in isolation. See Recommendation R5 for the preferred action (document, do not refactor).

---

### A3: `creel_design_comparison` Class Holds `creel_estimates`, Not `creel_design`

**Severity:** low

| | |
|---|---|
| **File** | `compare-designs.R` |
| **Function** | `compare_designs(designs)` |
| **Class assigned** | `creel_design_comparison` |
| **Actual content** | A named list of `creel_estimates` objects |

**Description.** `compare_designs()` accepts a named list of `creel_estimates` objects and wraps them in a `creel_design_comparison` class. The class name implies comparison of Layer 1 design objects, but the function compares Layer 2 estimation results. The input guard confirms:

```
"{.arg designs} must be a named list of at least 2 {.cls creel_estimates}."
```

The name `creel_design_comparison` is a misnomer — it describes the function's original intent, not its current behaviour.

**Why it happened.** The function likely originated as a design-parameter comparison utility and was later repurposed to compare estimated outputs. The class name was not updated.

**Impact.** No runtime bugs. Users who inspect `class(x)` or read NAMESPACE will encounter a class name that does not match the object content. See Recommendation R2.

---

### A4: Nine `creel_summary_*` Subclasses Have No Registered S3 Methods

**Severity:** low

| | |
|---|---|
| **File** | `creel-summaries.R` |
| **Functions** | All `summarize_by_*()`, `summarize_cws_rates()`, `summarize_hws_rates()`, `summarize_length_freq()`, `summarize_successful_parties()` |
| **Classes** | 9 `creel_summary_*` subclasses (listed below) |

**Description.** Nine classes are assigned at construction, all following the pattern `c("creel_summary_<x>", "data.frame")`:

- `creel_summary_refusals`
- `creel_summary_day_type`
- `creel_summary_angler_type`
- `creel_summary_method`
- `creel_summary_species_sought`
- `creel_summary_trip_length`
- `creel_summary_successful_parties`
- `creel_summary_cws_rates`
- `creel_summary_hws_rates`
- `creel_summary_length_freq`

None of these appear in NAMESPACE as S3 method registrations. Every `format()`, `print()`, or `as.data.frame()` call on these objects falls through silently to the `data.frame` method. The subclass names provide type documentation value only — they carry no behavioural differentiation at runtime.

A separate and unrelated class, `creel_summary` (the output of `summary.creel_estimates()`), shares the `creel_summary` name prefix. `creel_summary` has registered methods (`print`, `as.data.frame`) and lives in `creel-summaries.R`. Despite the shared prefix, `creel_summary` and the `creel_summary_*` subclasses have no inheritance relationship. A contributor seeing both names together may assume a hierarchy that does not exist.

**Additional note:** `creel_length_distribution` (from `creel-estimates-length.R`) is similarly `c("creel_length_distribution", "data.frame")` and has no registered methods, despite being listed in NAMESPACE. It falls through to `data.frame` dispatch in the same way.

**Why it happened.** The subclass names were likely added as documentation markers — useful for identifying what a data frame contains — without the corresponding S3 method registrations. The `creel_summary` / `creel_summary_*` naming collision is a coincidence of prefix convention.

**Impact.** No runtime bugs. `is(x, "creel_summary_refusals")` returns TRUE, but custom print or format methods cannot be registered without NAMESPACE entries. If any future phase adds custom formatting for these classes, methods must be registered explicitly. See Recommendation R3.

---

## Positive Findings

These patterns are working well. They should be explicitly preserved as the package grows. Any new code should conform to them.

### P1: Scheduling Layer Has Zero Coupling into Estimation or Design Internals

`schedule-generators.R` and `schedule-io.R` reference `creel_design()` only in roxygen `@seealso` and example comments — never in function bodies. No scheduling function calls any estimation or design function internally. The scheduling layer is appropriately self-contained and can evolve independently of the estimation stack.

### P2: The Prep Layer Is Clean

`prep-counts.R` and `prep-interviews.R` have no references to `creel_design`, any `estimate_*` function, or scheduling internals. Both files are pure data-shaping utilities: they accept raw data frames and return tibbles with documented column contracts. Their output stability is high because nothing in a higher layer bleeds back into them.

### P3: The HT Estimation Abstraction Is Respected Across All Survey Types

All `creel-estimates-*.R` files (bus-route, aerial, aerial-glmm, camera, length, total-catch, total-harvest, total-release) consume `creel_design` objects through the `survey-bridge.R` integration layer and produce `creel_estimates` objects via `new_creel_estimates()`. No survey type bypasses this constructor to build an estimates object via a raw `structure()` call. The abstraction boundary is intact.

### P4: S3 Class Naming Is Consistently `creel_`-Prefixed

All 31 identified class names use the `creel_` prefix. There are no bare names (e.g., `design`, `estimates`) or ambiguously generic names in the public API. This makes the class namespace unambiguous and avoids conflicts with other packages' S3 dispatch.

### P5: Error Handling Is Architecturally Uniform

`cli::cli_abort()` and `cli::cli_warn()` are used throughout all layers (639 combined `cli::` call-sites across all 38 R files). No layer uses `stop()`, `warning()`, or `message()` directly in user-facing paths. Error messages are consistently formatted, coloured, and reference variable names via `{.arg}`, `{.val}`, and `{.cls}` markup. This uniformity lowers the cost of debugging and makes error messages immediately recognisable as coming from tidycreel.

### P6: `creel_estimates_mor` Subclass Inheritance Is Correct

`new_creel_estimates_mor()` sets `class = c("creel_estimates_mor", "creel_estimates")` with the correct dispatch priority. The `format()` and `print()` methods in `print-methods.R` cover both classes. A user holding a `creel_estimates_mor` object gets correct method dispatch without any manual handling. This is the right pattern for adding new estimator variants.

---

## S3 Class Inventory

tidycreel defines 31 named `creel_*` classes. 19 have registered S3 methods in NAMESPACE. The remaining 12 (9 `creel_summary_*` subclasses, `creel_length_distribution`, and two others noted below) fall through to `data.frame` dispatch.

### Classes with Registered S3 Methods (19 in NAMESPACE)

| Class | Primary File | Registered Methods |
|-------|-------------|--------------------|
| `creel_completeness_report` | design-validator.R | format, print |
| `creel_data_validation` | validate-creel-data.R | as.data.frame, print |
| `creel_design` | creel-design.R | format, print, summary |
| `creel_design_comparison` | compare-designs.R | as.data.frame, autoplot, print |
| `creel_design_report` | design-validator.R | format, print |
| `creel_estimates` | creel-estimates.R | autoplot, format, print |
| `creel_estimates_diagnostic` | print-methods.R | format, print |
| `creel_estimates_mor` | creel-estimates.R | (inherits creel_estimates — correct) |
| `creel_hybrid_svydesign` | hybrid-design.R | print |
| `creel_length_distribution` | creel-estimates-length.R | (listed in NAMESPACE; no methods registered — see note) |
| `creel_schedule` | schedule-generators.R | format, knitr::knit_print, print |
| `creel_schema` | creel-schema.R | format, print |
| `creel_season_summary` | season-summary.R | format, print |
| `creel_summary` | creel-summaries.R | as.data.frame, print |
| `creel_tost_validation` | validate-incomplete-trips.R | format, print |
| `creel_trip_summary` | creel-design.R | format, print |
| `creel_validation` | creel-validation.R | print |
| `creel_validation_report` | validation-report.R | as.data.frame, print |
| `creel_variance_comparison` | compare-variance.R | as.data.frame, print |

**Note on `creel_length_distribution`:** This class is present in NAMESPACE as a class declaration but has no registered S3 methods. It is `c("creel_length_distribution", "data.frame")` and falls through to `data.frame` dispatch, the same as the `creel_summary_*` subclasses in the table below.

### Classes Without Registered S3 Methods (silent `data.frame` fallthrough)

These classes are assigned at construction but have no entries in NAMESPACE for `print`, `format`, or `as.data.frame`. All use `c("<class>", "data.frame")` as their class vector.

| Class | Assigned In | Second Class |
|-------|------------|-------------|
| `creel_summary_refusals` | creel-summaries.R | data.frame |
| `creel_summary_day_type` | creel-summaries.R | data.frame |
| `creel_summary_angler_type` | creel-summaries.R | data.frame |
| `creel_summary_method` | creel-summaries.R | data.frame |
| `creel_summary_species_sought` | creel-summaries.R | data.frame |
| `creel_summary_trip_length` | creel-summaries.R | data.frame |
| `creel_summary_successful_parties` | creel-summaries.R | data.frame |
| `creel_summary_cws_rates` | creel-summaries.R | data.frame |
| `creel_summary_hws_rates` | creel-summaries.R | data.frame |
| `creel_summary_length_freq` | creel-summaries.R | data.frame |

**Naming caution:** `creel_summary` (the output of `summary.creel_estimates()`, with registered methods) and the `creel_summary_*` subclasses (outputs of `summarize_by_*()`, no registered methods) share a name prefix but have no inheritance relationship. They are in the same file (`creel-summaries.R`), have different structure, and serve different purposes. The shared prefix suggests a class hierarchy that does not exist. Any new summary classes should be named deliberately to avoid deepening this false hierarchy.

---

## Architectural Patterns

### Patterns to Carry Forward

**Layer Contract Pattern.** Each layer function accepts the output of the layer immediately below and produces a typed object for the layer above:

- Prep functions produce tibbles with documented column contracts.
- `creel_design()` and `add_*()` build a `creel_design` object.
- Estimation functions accept a `creel_design` and produce `creel_estimates` via `new_creel_estimates()`.
- Summary and visualization functions consume `creel_design` or `creel_estimates`.

Any new function should be placed in the layer that matches its input type, not grouped by conceptual family or file size convenience. Finding A1 is an example of what happens when this rule is relaxed.

**Constructor Pattern.** `new_creel_estimates()` and `new_creel_estimates_mor()` are the sole constructors for estimation objects. All estimation paths across all survey types use these constructors. Raw `structure()` calls that bypass a constructor should be treated as a code smell when reviewing pull requests.

**Three-Guard Pattern.** Input guards in estimation and summary functions follow a consistent three-step sequence:

1. `inherits(x, "creel_design")` — type check
2. Presence check for a required component (e.g., interviews attached, counts present)
3. Domain-specific structural check (e.g., correct `survey_type` for the estimator)

New functions operating on `creel_design` or `creel_estimates` objects should follow this pattern. The pattern appears in comments within `creel-summaries.R` as "the three-guard pattern from creel-design.R" — which confirms it is an established convention, not just an observed regularity.

### Inconsistency to Note

**Mixed Input Validation.** `checkmate::makeAssertCollection()` is used for batch validation in 5 files (`creel-design.R`, `survey-bridge.R`, `design-validator.R`, `power-sample-size.R`, `validate-schemas.R`), while the remaining 33 files use individual `cli::cli_abort()` guards. Both approaches are correct and neither is wrong on its own terms, but having two parallel validation idioms adds cognitive overhead for contributors who must decide which pattern to follow when writing new validation code. The `checkmate` pattern collects multiple errors and reports them together; the `cli_abort()` pattern fails fast on the first error. For creel survey validation (where inputs are typically well-structured data frames with known column sets), the fail-fast pattern is usually sufficient. See Recommendation R4.

---

## Recommendations

Recommendations are consolidated here. None are code-path critical. The package functions correctly as-is.

---

### R1: Move `get_site_contributions()` to an Estimation-Layer File

**Priority:** medium

**WHAT.** Move `get_site_contributions()` from `creel-design.R` (line 2533) to `creel-estimates.R` or, preferably, a new `creel-estimates-utils.R` file alongside the other estimation utilities. Update any `@seealso` cross-references in sibling `get_*` functions to reflect the new location.

**WHY.** `get_site_contributions()` operates on `creel_estimates` objects, not `creel_design` objects. Its current placement in `creel-design.R` makes it undiscoverable to users looking for post-estimation utilities, and it creates a false expectation that it accepts `creel_design` inputs like its three siblings. The three-sibling functions (`get_sampling_frame()`, `get_inclusion_probs()`, `get_enumeration_counts()`) all belong in `creel-design.R` and should remain there.

No behaviour change required — this is a file relocation only.

---

### R2: Rename `creel_design_comparison` to Match Its Actual Content

**Priority:** low

**WHAT.** Rename the `creel_design_comparison` class to `creel_estimates_comparison` (or, more concisely, `creel_comparison`). Update the NAMESPACE S3 method registrations, the class assignment in `compare_designs()`, and the autoplot/print method signatures accordingly.

**WHY.** `creel_design_comparison` holds a named list of `creel_estimates` objects, not `creel_design` objects. The name is a misnomer that misleads any contributor or user reading NAMESPACE, source code, or the output of `class(x)`. Renaming aligns the class name with the actual content.

This is a renaming only — no logic change. However, it is a breaking change for any user code that checks `inherits(x, "creel_design_comparison")` directly, so it warrants a minor version bump if implemented.

---

### R3: Register Methods or Remove Subclass Assignments for `creel_summary_*`

**Priority:** low

**WHAT.** Choose one of two options:

- **Option A (register methods):** Add `print`, `format`, and/or `as.data.frame` S3 methods for the `creel_summary_*` subclasses in NAMESPACE. This is the right choice if there is any intent to add custom printing (e.g., adding column labels, hiding internal columns) for any of these types.
- **Option B (remove subclasses):** Remove the subclass assignments from all `summarize_by_*()` and related functions, returning plain `data.frame` objects. This is the right choice if no custom dispatch is planned.

The same decision applies to `creel_length_distribution`.

**WHY.** The current state — subclass names assigned but no methods registered — provides documentation value (a `class(x)` call reveals what kind of summary a frame contains) at the cost of a class hierarchy that delivers no behavioural differentiation. This is misleading noise. Commit to one direction or the other.

---

### R4: Standardise Input Validation on `cli::cli_abort()` / `rlang` Guards in New Code

**Priority:** low

**WHAT.** Do not use `checkmate::makeAssertCollection()` in any new functions. Continue using `cli::cli_abort()` for individual guard checks in new code. The existing `checkmate` usage in the five files listed in Finding A4 (the dependency review) need not be rewritten unless those functions are substantially refactored for other reasons.

**WHY.** The package already uses `cli::cli_abort()` in 33 of 38 files. Extending the `checkmate` pattern to new code deepens the inconsistency. `cli_abort()` is already a declared Import; `checkmate` is an additional dependency that can be phased out of new code at zero cost.

---

### R5: Document the Deliberate Coupling in `validate_incomplete_trips()`

**Priority:** low

**WHAT.** Add a roxygen comment (or inline comment block) to `validate_incomplete_trips()` in `validate-incomplete-trips.R` explaining that it calls `estimate_catch_rate()` internally by design, and why: the TOST equivalence test requires real CPUE estimates to compare cohorts.

**WHY.** Without this note, a contributor encountering the call to `estimate_catch_rate()` inside a validation function may treat it as an accidental coupling and attempt to refactor it out. The coupling is intentional and architecturally justified. Document it rather than remove it.

---

*End of architectural review.*

*For dependency health findings (scales, lubridate, checkmate, ggplot2 demotion candidate), see `72-DEP-REVIEW.md`.*
