---
phase: 25-bus-route-harvest-estimation
verified: 2026-02-24T00:00:00Z
status: passed
score: 19/19 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Run devtools::test() and confirm FAIL = 0, total tests >= 1061"
    expected: "All 1066 tests pass with zero failures"
    why_human: "Cannot execute R code programmatically in this verification context; test counts documented in SUMMARY but not re-executed here"
---

# Phase 25: Bus-Route Harvest Estimation Verification Report

**Phase Goal:** Users can estimate harvest and catch from bus-route surveys using Jones & Pollock Eq. 19.5
**Verified:** 2026-02-24
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | `estimate_harvest()` returns a `creel_estimates` object for bus-route designs | VERIFIED | `R/creel-estimates.R` line 1147-1172 dispatches to `estimate_harvest_br()` which calls `new_creel_estimates()` via `br_build_estimates()`; test at `test-estimate-harvest.R` line 834 asserts `expect_s3_class(result, "creel_estimates")` |
| 2  | Harvest equals sum(h_i / pi_i) where h_i = harvest_col * .expansion (Eq. 19.5) | VERIFIED | `R/creel-estimates-bus-route.R` line 319: `interviews$.h_i <- interviews[[harvest_col]] * interviews$.expansion`; line 331: `interviews$.contribution <- interviews$.h_i / interviews$.pi_i`; golden test at `test-estimate-harvest.R` line 840 verifies to tolerance 1e-6 |
| 3  | `use_trips='complete'` filters to complete trips before applying Eq. 19.5 | VERIFIED | `R/creel-estimates-bus-route.R` lines 294-296: `is_complete <- tolower(interviews[[trip_status_col]]) == "complete"` filter applied; test at line 877 asserts `creel_estimates` returned with positive estimate |
| 4  | `use_trips='incomplete'` applies pi_i-weighted MOR | VERIFIED | `R/creel-estimates-bus-route.R` lines 297-315: `h_ratio_i = harvest / effort`, `contribution = h_ratio_i / .pi_i`; test at line 884 asserts `creel_estimates` returned with non-negative estimate |
| 5  | `use_trips='diagnostic'` returns `creel_estimates_diagnostic` with `$complete` and `$incomplete` | VERIFIED | `R/creel-estimates-bus-route.R` lines 271-283: both paths run, `class(result) <- c("creel_estimates_diagnostic", "list")`; test at line 891 asserts `expect_s3_class(result, "creel_estimates_diagnostic")` |
| 6  | `verbose=TRUE` on `estimate_harvest()` prints bus-route equation reference message | VERIFIED | `R/creel-estimates.R` lines 1148-1152: emits `"Using bus-route estimator (Jones & Pollock 2012, Eq. 19.5)"`; test at line 864 uses `expect_message(..., "bus-route estimator")` |
| 7  | `estimate_total_catch()` dispatches to bus-route estimator | VERIFIED | `R/creel-estimates-total-catch.R` lines 108-130: `design$design_type == "bus_route"` guard dispatches to `estimate_total_catch_br()`; test at `test-estimate-total-catch.R` line 505 asserts `creel_estimates` class returned |
| 8  | `verbose=TRUE` on `estimate_total_catch()` prints the bus-route equation reference message | VERIFIED | `R/creel-estimates-total-catch.R` lines 109-113: emits same message; test at line 532 uses `expect_message(..., "bus-route estimator")` |
| 9  | Per-site breakdown stored as `site_contributions` attribute on returned object | VERIFIED | `R/creel-estimates-bus-route.R` `br_build_estimates()` line 510: `attr(result, "site_contributions") <- site_table`; test at `test-estimate-harvest.R` line 849 and `test-estimate-total-catch.R` line 517 assert attribute is non-null |
| 10 | `get_site_contributions()` works on bus-route harvest result returning tibble with `pi_i` column | VERIFIED | `R/creel-design.R` line 1519: `tibble::as_tibble(site_tbl)`; site_table built with `"pi_i"` column name (bus-route file line 336); test at `test-estimate-harvest.R` line 856 asserts `tbl_df` class and `"pi_i" %in% names(sc)` |
| 11 | Bus-route harvest dispatch test confirms `creel_estimates` class returned | VERIFIED | `test-estimate-harvest.R` line 834: `expect_s3_class(result, "creel_estimates")` |
| 12 | Eq. 19.5 golden test: hand-computed H_hat = sum(h_i/pi_i) matches output to tolerance 1e-6 | VERIFIED | `test-estimate-harvest.R` line 840-846: expected_h_hat computed as 135.833..., `expect_equal(result$estimates$estimate, expected_h_hat, tolerance = 1e-6)` |
| 13 | Grouped by= estimation test: proportions sum to 1 across groups | VERIFIED | `test-estimate-harvest.R` line 897-902: `expect_equal(sum(result$estimates$proportion), 1.0, tolerance = 1e-6)` |
| 14 | `estimate_total_catch()` bus-route dispatch test: C_hat positive | VERIFIED | `test-estimate-total-catch.R` line 511-514: `expect_true(result$estimates$estimate > 0)` |
| 15 | `verbose=FALSE` on `estimate_harvest()` produces no dispatch message | VERIFIED | `test-estimate-harvest.R` line 872: `expect_no_message(suppressWarnings(estimate_harvest(d, verbose = FALSE)))` |
| 16 | `verbose=FALSE` on `estimate_total_catch()` produces no dispatch message | VERIFIED | `test-estimate-total-catch.R` line 540: `expect_no_message(suppressWarnings(estimate_total_catch(d, verbose = FALSE)))` |
| 17 | `get_site_contributions()` works on bus-route total-catch result | VERIFIED | `test-estimate-total-catch.R` line 524-530: `expect_s3_class(sc, "tbl_df")` and `expect_true("pi_i" %in% names(sc))` |
| 18 | `design$interview_survey` NULL check guarded for bus-route in `estimate_harvest()` | VERIFIED | `R/creel-estimates.R` line 1135: `if (!identical(design$design_type, "bus_route") && is.null(design$interview_survey))` |
| 19 | `design$survey` NULL check guarded for bus-route in `estimate_total_catch()` | VERIFIED | `R/creel-estimates-total-catch.R` line 133: `validate_design_compatibility()` called only after bus-route dispatch returns at line 130 |

**Score:** 19/19 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/creel-estimates-bus-route.R` | `estimate_harvest_br()` and `estimate_total_catch_br()` internal estimators | VERIFIED | Both functions defined (lines 218, 366); `br_build_estimates()` shared helper also present (line 471); 569 lines, fully substantive — no stubs or placeholder returns |
| `R/creel-estimates.R` | `estimate_harvest()` with `verbose=` and `use_trips=` parameters + bus-route dispatch | VERIFIED | Function signature at line 1104-1111 includes `verbose = FALSE` and `use_trips = NULL`; dispatch block at lines 1147-1172 |
| `R/creel-estimates-total-catch.R` | `estimate_total_catch()` with `verbose=` parameter + bus-route dispatch | VERIFIED | Function signature at line 78-84 includes `verbose = FALSE`; dispatch block at lines 108-130 |
| `tests/testthat/test-estimate-harvest.R` | Bus-route harvest estimation section (10 tests) | VERIFIED | Section present at line 760; 10 `test_that` blocks confirmed; 902 total lines |
| `tests/testthat/test-estimate-total-catch.R` | Bus-route total-catch estimation section (6 tests) | VERIFIED | Section present at line 440; 6 `test_that` blocks confirmed; 543 total lines |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `R/creel-estimates.R estimate_harvest()` | `R/creel-estimates-bus-route.R estimate_harvest_br()` | `design$design_type == "bus_route"` guard at line 1147 + `return(estimate_harvest_br(...))` at line 1168 | WIRED | Pattern `design_type.*bus_route` confirmed at line 1147; call at line 1168 |
| `R/creel-estimates-total-catch.R estimate_total_catch()` | `R/creel-estimates-bus-route.R estimate_total_catch_br()` | `design$design_type == "bus_route"` guard at line 108 + `return(estimate_total_catch_br(...))` at line 126 | WIRED | Pattern confirmed; call at line 126 |
| `R/creel-estimates-bus-route.R estimate_harvest_br()` | `design$interviews$.pi_i` and `design$interviews$.expansion` | Direct column access at lines 231-248 (defensive checks) and lines 319, 331 (computation) | WIRED | `.pi_i` accessed at line 228 (`interviews <- design$interviews`) then used at lines 252, 303, 304, 331; `.expansion` accessed at line 319 |
| `tests/testthat/test-estimate-harvest.R make_br_harvest_design()` | `estimate_harvest()` | Test helpers construct bus-route design + interviews, call `estimate_harvest(design)` | WIRED | `estimate_harvest(d)` called in all 10 bus-route section tests; `make_br_harvest_design()` at line 763, `make_br_harvest_interviews()` at line 791 |
| `tests/testthat/test-estimate-total-catch.R make_br_catch_design()` | `estimate_total_catch()` | Test helpers construct bus-route design + interviews, call `estimate_total_catch(design)` | WIRED | `estimate_total_catch(d)` called in all 6 bus-route section tests; `make_br_catch_design()` at line 443, `make_br_catch_interviews()` at line 471 |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| BUSRT-04 | 25-01, 25-02 | System estimates harvest using Jones & Pollock (2012) Eq. 19.5 general estimator | SATISFIED | `estimate_harvest_br()` implements Eq. 19.5 exactly: `h_i = harvest_col * .expansion`, `contribution = h_i / .pi_i`, `H_hat = sum(contributions)`; golden test verifies arithmetic to 1e-6 tolerance |
| BUSRT-10 | 25-01, 25-02 | `estimate_harvest()` dispatches to bus-route estimator when design type is bus_route | SATISFIED | `R/creel-estimates.R` line 1147: `if (!is.null(design$design_type) && design$design_type == "bus_route")` guard fires and returns early via `estimate_harvest_br()`; test at `test-estimate-harvest.R` line 834 confirms dispatch |

**Orphaned requirements check:** REQUIREMENTS.md maps exactly 2 requirements to Phase 25 (BUSRT-04, BUSRT-10). Both are claimed by plans 25-01 and 25-02. No orphaned requirements.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `tests/testthat/test-estimate-harvest.R` | 220 | `placeholder = TRUE` in fake survey object | Info | Pre-existing test scaffolding for error-path testing; not introduced by Phase 25; does not affect bus-route section |
| `tests/testthat/test-estimate-harvest.R` | 421 | `# TODO: Update when estimate_harvest gets use_trips parameter` | Info | Pre-existing TODO in a non-bus-route test; obsolete now that `use_trips=` was added by Phase 25; does not affect bus-route section correctness |

No blocker or warning anti-patterns found in Phase 25 artifacts. Both items are pre-existing in non-bus-route test sections.

---

### Human Verification Required

#### 1. Full Test Suite Execution

**Test:** Run `devtools::test()` in R from the project root.
**Expected:** FAIL = 0, total tests >= 1061 (SUMMARY reports 1066).
**Why human:** Cannot execute R code in this verification context; test pass/fail state is documented in SUMMARY commit logs but not re-verified here.

---

### Gaps Summary

No gaps found. All 19 observable truths are verified against actual codebase implementation. All four commits referenced in SUMMARY exist in the git log (`5cf9a00`, `4ecfafd`, `21bbbee`, `6766fa2`). Both requirements BUSRT-04 and BUSRT-10 are fully satisfied. The implementation follows the Horvitz-Thompson formula precisely and is wired through all three levels: exists, substantive, and connected.

---

_Verified: 2026-02-24_
_Verifier: Claude (gsd-verifier)_
