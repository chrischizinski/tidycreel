---
phase: 21-bus-route-design-foundation
verified: 2026-02-16T22:00:00Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 21: Bus-Route Design Foundation Verification Report

**Phase Goal:** Users can specify bus-route survey designs with nonuniform sampling probabilities
**Verified:** 2026-02-16T22:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                              | Status     | Evidence                                                                                                    |
| --- | -------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------------------------------------------------------------------- |
| 1   | creel_design() accepts survey_type = "bus_route" with site and circuit specifications              | VERIFIED | R/creel-design.R lines 134-278: full bus_route branch; test at line 264 confirms acceptance and return type |
| 2   | Site probabilities sum to 1.0 within each circuit (validated at design time)                       | VERIFIED | validate_creel_design() lines 409-420: per-circuit sum check with 1e-6 tolerance; tests at lines 345-385   |
| 3   | All sampling probabilities are in (0,1] range (validated at design time)                           | VERIFIED | validate_creel_design() lines 387-406: checks both p_site and p_period; tests at lines 387-430             |
| 4   | Design validation fails fast with clear messages when probabilities invalid                        | VERIFIED | cli_abort() at lines 390-394, 401-405, 414-420 includes circuit name, actual sum, row numbers; tested      |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact                                    | Expected                                                      | Status     | Details                                                                                    |
| ------------------------------------------- | ------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------ |
| `R/creel-design.R`                          | Extended creel_design() with survey_type = 'bus_route' support | VERIFIED  | Contains full bus_route branch (lines 173-278), validate_creel_design() probability checks (lines 379-421), format.creel_design() Bus-Route section (lines 1004-1034), get_sampling_frame() (lines 1087-1103) |
| `R/creel-design.R`                          | format.creel_design() Bus-Route section + get_sampling_frame() | VERIFIED  | Bus-Route section at lines 1004-1034; get_sampling_frame() at lines 1087-1103              |
| `tests/testthat/test-creel-design.R`        | Bus-route tests (constructor, validation, print, helper)       | VERIFIED  | 19 bus-route test_that blocks at lines 264-522; section header "Bus-Route design" at line 244 |
| `NAMESPACE`                                 | export(get_sampling_frame)                                     | VERIFIED  | Line 27: `export(get_sampling_frame)`                                                      |
| `man/get_sampling_frame.Rd`                 | Auto-generated roxygen man page                                | VERIFIED  | File exists at man/get_sampling_frame.Rd                                                   |

### Key Link Verification

| From                                        | To                            | Via                                            | Status     | Details                                                                                    |
| ------------------------------------------- | ----------------------------- | ---------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------ |
| `creel_design(survey_type = 'bus_route')`   | `design$bus_route`            | new_creel_design() bus_route slot              | WIRED      | Line 275: `bus_route = bus_route` passed to new_creel_design(); slot stored at line 320    |
| `validate_creel_design()`                   | `cli::cli_abort()`            | sum-to-1 and (0,1] range checks on bus_route   | WIRED      | Lines 390-394, 401-405, 414-420: all three failure paths call cli_abort                    |
| `format.creel_design()`                     | `design$bus_route$data`       | conditional block !is.null(x$bus_route)         | WIRED      | Line 1005: guard check; lines 1006-1028: data access and row iteration                    |
| `get_sampling_frame()`                      | `design$bus_route$data`       | returns bus_route$data                          | WIRED      | Line 1102: `design$bus_route$data` returned directly                                       |

### Requirements Coverage

| Requirement | Status    | Notes                                                                                      |
| ----------- | --------- | ------------------------------------------------------------------------------------------ |
| BUSRT-06    | SATISFIED | creel_design() constructor with sampling_frame, p_site, p_period, circuit parameters implemented and validated |
| BUSRT-07    | SATISFIED | pi_i = p_site * p_period precomputed at construction time and stored in bus_route$data$.pi_i (line 255) |

### Anti-Patterns Found

None. No TODOs, FIXMEs, placeholders, empty implementations, or stub returns found in any modified files.

### Human Verification Required

#### 1. Print Output Readability

**Test:** Load the package and call `print()` on a bus-route design with 3-site, 2-circuit sampling frame.
**Expected:** Output shows "Bus-Route Design" heading, site/circuit/p_site/p_period/pi_i table rows, "Sites: 3, Circuits: 2" summary line.
**Why human:** CLI formatting (colors, inline formatting) cannot be fully verified by grep alone; visual inspection confirms readability.

#### 2. p_period Scalar vs Column Resolution (tryCatch path)

**Test:** Create a bus-route design with `p_period = 0.5` (scalar) and verify `.p_period` column added to all rows; then create one with `p_period = p_period` (column) and verify it uses the existing column.
**Expected:** Both work; scalar path sets `.p_period_col = ".p_period"`, column path sets `p_period_col = "p_period"`.
**Why human:** The tryCatch logic at lines 217-231 falls back from column-selector to scalar-eval; edge case behavior with unusual column names warrants interactive confirmation.

## Artifact Detail

### R/creel-design.R — Key Implementation Sections

**creel_design() signature (lines 134-143):** All six new parameters present (`survey_type`, `sampling_frame`, `p_site`, `p_period`, `circuit`). `survey_type` defaults to `design_type` for backward compatibility.

**Bus-route branch (lines 173-266):**
- sampling_frame presence check
- p_site tidy selector resolution (required)
- site tidy selector resolution (required for bus_route)
- circuit tidy selector resolution (optional; defaults to `.default`)
- p_period resolution: column selector first, scalar fallback via tryCatch
- Default circuit `.circuit = ".default"` added when circuit omitted
- Default `.p_period` column added when scalar provided
- pi_i computed: `br_df[[".pi_i"]] <- br_df[[p_site_col]] * br_df[[p_period_col]]`
- bus_route slot assembled as named list

**validate_creel_design() bus_route section (lines 379-421):**
- p_site (0,1] range check with row indices in error message
- p_period (0,1] range check with row indices in error message
- Per-circuit sum check with 1e-6 tolerance; circuit name and actual sum in error message

**format.creel_design() Bus-Route section (lines 1004-1034):** Conditional on `!is.null(x$bus_route)`; shows "Bus-Route Design" heading, site/circuit counts, and per-row probability table (capped at 10 rows).

**get_sampling_frame() (lines 1087-1103):** Exported, guards on `inherits(design, "creel_design")` and `!is.null(design$bus_route)`, returns `design$bus_route$data`.

### tests/testthat/test-creel-design.R — Bus-Route Tests (19 tests)

Tests cover every behavioral requirement:
- Constructor acceptance and return type (line 264)
- .pi_i column presence and correct values 0.15, 0.20, 0.15 (line 276)
- Column mapping storage (line 288)
- Default circuit behavior (line 301)
- Explicit circuit column (line 312)
- Scalar p_period applied to all rows (line 330)
- Sum-to-1 validation error with "rlang_error" class (line 345)
- Sum-to-1 error contains "sum to 1.0" pattern (line 358)
- Circuit name "AM" present in error message (line 368)
- Zero p_site rejects (line 387)
- p_site > 1 rejects (line 402)
- p_period > 1 rejects (line 417)
- Missing sampling_frame rejects (line 432)
- 1e-6 floating-point tolerance accepted (line 442)
- Backward compatibility: instantaneous designs unchanged (line 460)
- format() includes "Bus-Route", "p_site", "pi_i" (line 471)
- format() does NOT include "Bus-Route" for instantaneous (line 484)
- get_sampling_frame() returns data frame with .pi_i, site, p_site (line 495)
- get_sampling_frame() errors on non-bus-route design (line 509)
- get_sampling_frame() errors on non-creel_design input (line 520)

### Commits Verified

All three claimed commits confirmed present in git history:
- `6bd56d8` — feat(21-01): extend creel_design() with survey_type = 'bus_route' support
- `0eb6ce4` — feat(21-02): add Bus-Route section to format.creel_design() and get_sampling_frame()
- `5f243e4` — test(21-02): add comprehensive bus-route design tests (constructor, validation, print, helper)

## Gaps Summary

No gaps. All four observable truths are verified against the actual codebase:

1. `creel_design(survey_type = "bus_route", ...)` is fully implemented, not stubbed. The function signature accepts all required parameters, the bus_route branch builds the internal data structure, and the result is passed to `new_creel_design()` and `validate_creel_design()`.

2. The sum-to-1 constraint is implemented with correct 1e-6 floating-point tolerance using `abs(circ_sum - 1.0) > 1e-6` per circuit. The circuit name and actual sum appear in the error message.

3. The (0,1] range validation fires before the sum check, covering zero values, negative values, NA values, and values exceeding 1.0 for both p_site and p_period independently.

4. All error messages use `cli::cli_abort()` with structured bullet-point format including the problem description, specific offending values/rows, and actionable correction hints.

---

_Verified: 2026-02-16T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
