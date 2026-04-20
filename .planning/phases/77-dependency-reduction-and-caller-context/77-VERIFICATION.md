---
phase: 77-dependency-reduction-and-caller-context
verified: 2026-04-20T22:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 77: Dependency Reduction and Caller Context Verification Report

**Phase Goal:** lubridate is no longer a hard dependency, bus-route estimators surface correct call context in error messages, and get_site_contributions() lives in its correct architectural layer
**Verified:** 2026-04-20
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `lubridate` is in Suggests (not Imports) in DESCRIPTION | VERIFIED | `DESCRIPTION` line 41: `lubridate (>= 1.9.0)` under `Suggests:` (line 30); absent from `Imports:` (lines 19–29) |
| 2 | All 4 user-visible lubridate entry points have `rlang::check_installed("lubridate")` guards | VERIFIED | `R/schedule-generators.R:409`, `R/schedule-print.R:223` (format), `R/schedule-print.R:335` (knit_print), `R/autoplot-methods.R:313` — 4 guards confirmed |
| 3 | 5 bus-route estimator internals have `call = rlang::caller_env()` parameter | VERIFIED | `R/creel-estimates-bus-route.R` lines 22, 227, 380, 493, 587 — 5 function signatures; `grep -c "caller_env"` returns 5 |
| 4 | Every `cli::cli_abort()` in those 5 functions passes `call = call` | VERIFIED | All 13 `cli_abort` calls in the file include `call = call` as final argument (lines 34, 43, 62, 246, 255, 274, 399, 408, 430, 511, 518, 606, 613) |
| 5 | `estimate_harvest_br()` recursive calls pass `call = call` explicitly | VERIFIED | Lines 281 and 285 in `R/creel-estimates-bus-route.R` both include `call = call` in diagnostic-mode recursive calls |
| 6 | `get_site_contributions()` is defined in `R/creel-estimates-utils.R` | VERIFIED | File exists (64 lines); `get_site_contributions <- function(x)` at line 39; header comment explains Layer 2 separation |
| 7 | `get_site_contributions()` is absent from `R/creel-design.R` | VERIFIED | `grep -n "get_site_contributions" R/creel-design.R` returns no output |
| 8 | `get_enumeration_counts()` @seealso does not reference `[get_site_contributions()]` | VERIFIED | `R/creel-design.R` line 2470: `@seealso [creel_design()], [add_interviews()], [get_sampling_frame()], [get_inclusion_probs()]` — no cross-reference to get_site_contributions() |
| 9 | Test infrastructure for DEPS-02 exists | VERIFIED | `tests/testthat/test-lubridate-guards.R` exists (91 lines) with DESCRIPTION structure + source-file guard checks |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DESCRIPTION` | lubridate in Suggests, not Imports | VERIFIED | lubridate at line 41 under Suggests:; Imports: (lines 19–29) contains no lubridate |
| `R/schedule-generators.R` | `rlang::check_installed("lubridate")` guard at `generate_schedule()` entry | VERIFIED | Line 409: `rlang::check_installed("lubridate")` |
| `R/schedule-print.R` | Guards at `format.creel_schedule()` and `knit_print.creel_schedule()` entries | VERIFIED | Lines 223 and 335 |
| `R/autoplot-methods.R` | Guard at `autoplot.creel_schedule()` entry | VERIFIED | Line 313 |
| `R/creel-estimates-bus-route.R` | 5 function signatures with `call = rlang::caller_env()` + all cli_abort calls pass `call = call` | VERIFIED | 5 caller_env occurrences; 13 cli_abort calls all include `call = call` |
| `R/creel-estimates-utils.R` | New file containing `get_site_contributions()` with complete roxygen block | VERIFIED | 64-line file; function defined at line 39; header comment present |
| `R/creel-design.R` | `get_site_contributions()` removed; @seealso updated | VERIFIED | Function definition absent; @seealso at line 2470 contains no reference to get_site_contributions() |
| `tests/testthat/test-lubridate-guards.R` | DEPS-02 tests: DESCRIPTION structure + source-file guard checks | VERIFIED | 91-line file exists |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| DESCRIPTION Suggests | `R/schedule-generators.R` | `rlang::check_installed("lubridate")` at `generate_schedule()` top of body | WIRED | Line 409 is the first substantive line of the function body |
| DESCRIPTION Suggests | `R/schedule-print.R` | `rlang::check_installed("lubridate")` at `format.creel_schedule()` (line 223) and `knit_print.creel_schedule()` (line 335) | WIRED | Both guards present |
| DESCRIPTION Suggests | `R/autoplot-methods.R` | `rlang::check_installed("lubridate")` at `autoplot.creel_schedule()` top of body | WIRED | Line 313 |
| `R/creel-estimates-bus-route.R estimate_effort_br()` | `cli::cli_abort()` | `call = call` argument on all 3 abort calls in function | WIRED | Lines 34, 43, 62 all include `call = call` |
| `R/creel-estimates-utils.R get_site_contributions()` | estimate_effort() output | `attr(x, 'site_contributions')` pattern — function body relocated intact | WIRED | Function body unchanged; symbol resolves from new file location |
| `R/creel-design.R get_enumeration_counts() @seealso` | removed `[get_site_contributions()]` cross-reference | roxygen @seealso update | WIRED | Line 2470 has no get_site_contributions() reference |
| `estimate_harvest_br()` recursive calls | caller frame propagation | `call = call` passed explicitly at lines 281 and 285 | WIRED | Both diagnostic-mode recursive calls include `call = call` |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DEPS-02 | 77-01-PLAN.md | `lubridate` demoted to Suggests with `check_installed()` guards at all use sites | SATISFIED | lubridate in Suggests; 4 guards at all user-visible entry points; test file exists |
| CODE-02 | 77-02-PLAN.md | `rlang::caller_env()` added to bus-route estimators (P3 gap from Phase 73 review) | SATISFIED | 5 function signatures updated; all 13 cli_abort calls pass `call = call`; recursive calls propagate frame |
| CODE-03 | 77-02-PLAN.md | `get_site_contributions()` relocated to correct architectural layer (A1 finding from 72-ARCH-REVIEW.md) | SATISFIED | Function present in `R/creel-estimates-utils.R`; absent from `R/creel-design.R` |

No orphaned requirements: all three IDs declared across plans are mapped in REQUIREMENTS.md to Phase 77 with status Complete.

---

### Anti-Patterns Found

No anti-patterns found. Reviewed DESCRIPTION, R/schedule-generators.R, R/schedule-print.R, R/autoplot-methods.R, R/creel-estimates-bus-route.R, R/creel-estimates-utils.R, R/creel-design.R. No TODO/FIXME/placeholder comments, no empty implementations, no stubs.

---

### Human Verification Required

#### 1. Runtime behavior of lubridate install prompt

**Test:** In an R session where lubridate is NOT installed, call `generate_schedule()` with valid arguments.
**Expected:** `rlang::check_installed("lubridate")` fires and produces a clear install prompt, not a cryptic namespace error.
**Why human:** Cannot uninstall a package and invoke it programmatically in a grep-based verification pass.

#### 2. Error call frame displayed to user

**Test:** Trigger a validation error inside one of the 5 bus-route estimators (e.g., pass invalid `effort_target` to `estimate_effort_br()`). Observe the call frame shown in the error message.
**Expected:** Error message cites the user's top-level call (e.g., `estimate_effort_br()`) rather than an internal helper function name.
**Why human:** Cannot observe rlang error message rendering from static code analysis alone.

---

### Gaps Summary

No gaps. All 9 observable truths verified against the codebase. All three required artifacts (DESCRIPTION, R/creel-estimates-utils.R, R/creel-estimates-bus-route.R) exist and are substantive. All key links are wired. Requirements DEPS-02, CODE-02, and CODE-03 are fully satisfied with implementation evidence.

Two items flagged for human verification are behavioral (runtime install prompt, error frame display) — they cannot be confirmed by static analysis but represent polish checks on already-correct code, not missing functionality.

---

_Verified: 2026-04-20_
_Verifier: Claude (gsd-verifier)_
