---
phase: 76-ropensci-blockers
plan: "02"
subsystem: error-handling
tags: [named-conditions, cli_abort, rlang, rOpenSci, error-classes]
dependency_graph:
  requires: [76-01]
  provides: [named-condition-classes, rOpenSci-error-trapping]
  affects: [creel-design, creel-estimates, survey-bridge, validate-schemas, creel-schema, design-validator, validate-creel-data]
tech_stack:
  added: []
  patterns: ["cli_abort(c(...), class = 'creel_error_*')", "expect_error(..., class = 'creel_error_*')"]
key_files:
  created: []
  modified:
    - R/creel-design.R
    - R/creel-estimates.R
    - R/survey-bridge.R
    - R/validate-schemas.R
    - R/creel-schema.R
    - R/design-validator.R
    - R/validate-creel-data.R
    - tests/testthat/test-creel-design.R
    - tests/testthat/test-single-psu-diagnostic.R
    - tests/testthat/test-estimate-effort.R
    - tests/testthat/test-validate-schemas.R
    - tests/testthat/test-validate-creel-data.R
decisions:
  - "All 8 priority cli_abort sites plus validation helpers upgraded to named condition classes in one pass"
  - "creel_error_invalid_input extended to bus-route probability range/sum validation (not only missing-input guards)"
  - "Bootstrap single-PSU error at creel-estimates.R:2393 (NaN SE detection) added to site 5 coverage"
  - "validate_creel_design NA-date Tier 1 check classified as creel_error_schema_validation for consistency with validate_calendar_schema"
metrics:
  duration_seconds: 639
  completed_date: "2026-04-20"
  tasks_completed: 3
  files_modified: 13
requirements:
  - ERRH-01
---

# Phase 76 Plan 02: Named Condition Classes Summary

Add named condition classes to all 8 priority `cli_abort` sites so rOpenSci companion code can programmatically catch specific error types.

## What Was Built

Eight distinct named condition classes now cover all priority error sites in the tidycreel package. Every class follows the `creel_error_*` family convention and is passed as the `class=` argument to `cli::cli_abort()`, which forwards it to `rlang::abort()` as a condition subclass.

Named classes added:

| Class | Sites | Files |
|---|---|---|
| `creel_error_invalid_survey_type` | Site 1 | R/creel-design.R |
| `creel_error_invalid_input` | Sites 3 + validation helpers | R/creel-design.R |
| `creel_error_missing_survey_design` | Site 2 | R/creel-estimates.R |
| `creel_error_dispatch_unsupported` | Site 4 | R/creel-estimates.R |
| `creel_error_single_psu` | Site 5 | R/creel-estimates.R, R/survey-bridge.R |
| `creel_error_missing_data` | Site 6 | R/creel-estimates.R |
| `creel_error_schema_validation` | Site 7 | R/validate-schemas.R, R/creel-schema.R, R/creel-design.R |
| `creel_error_design_validation` | Site 8 | R/validate-creel-data.R, R/design-validator.R |

Total production `class =` assignments: 38 (verified via grep).

Tests updated: 30+ `expect_error(class = "rlang_error")` assertions replaced with specific named class assertions across five test files.

## Verification

Full test suite filter result: 292 tests, 0 failures.

```
devtools::test(filter = "creel-design|creel-estimates|single-psu|validate-schemas|validate-creel-data")
[ FAIL 0 | WARN 10 | SKIP 0 | PASS 292 ]
```

Named class coverage spot-check: `grep -rn "creel_error_" R/ | grep "class ="` returns 38 lines.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Extended site 3 to include bus-route probability validation**
- **Found during:** Task 1
- **Issue:** The `validate_bus_route_design()` function (lines ~725-783 in creel-design.R) had 5 additional `cli_abort` calls for p_site/p_period range/sum violations. The tests at lines 382, 424, 439, 454 in test-creel-design.R tested these with `class = "rlang_error"`. Excluding them would leave test assertions unupdated.
- **Fix:** Added `class = "creel_error_invalid_input"` to all probability validation calls — consistent with the "invalid bus-route input" semantic
- **Files modified:** R/creel-design.R, tests/testthat/test-creel-design.R
- **Commit:** 9a1b804

**2. [Rule 2 - Missing critical functionality] Added class to get_sampling_frame() and get_inclusion_probs() guards**
- **Found during:** Task 1
- **Issue:** Both accessor functions have `cli_abort` calls tested in test-creel-design.R lines 542, 547, 764 with `class = "rlang_error"`
- **Fix:** Added `class = "creel_error_invalid_input"` to both accessor function guards
- **Files modified:** R/creel-design.R, tests/testthat/test-creel-design.R
- **Commit:** 9a1b804

**3. [Rule 2 - Missing critical functionality] Bootstrap NaN-SE single-PSU detection needed class**
- **Found during:** Task 2 (REPVAR-03 test failure)
- **Issue:** The bootstrap path does not raise single-PSU error during `as.svrepdesign()` — instead it produces NaN SE and a separate `cli_abort` at creel-estimates.R:2393 detects this. Test REPVAR-03 tests this path.
- **Fix:** Added `class = "creel_error_single_psu"` to the NaN SE bootstrap guard
- **Files modified:** R/creel-estimates.R
- **Commit:** a9bfa8f

**4. [Rule 2 - Missing critical functionality] NA-date Tier 1 check in validate_creel_design needed class**
- **Found during:** Task 3 (test failure at test-creel-design.R:94)
- **Issue:** The NA-date check in `validate_creel_design()` (line ~706) fires before `validate_calendar_schema()` for the case where a Date column exists but has NA values. Updated test expected `creel_error_schema_validation` but the call lacked a class.
- **Fix:** Added `class = "creel_error_schema_validation"` to that Tier 1 check
- **Files modified:** R/creel-design.R
- **Commit:** e79d515

## Self-Check: PASSED

All key files confirmed present. All three task commits verified in git history. Named class coverage: 38 production call sites.
