---
phase: 26-primary-source-validation
verified: 2026-02-25T20:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 26: Primary Source Validation Verification Report

**Phase Goal:** Primary source validation — prove tidycreel exactly reproduces Malvestuto (1996)
Box 20.6 published examples (the canonical bus-route creel survey benchmark), and that the
complete bus-route workflow is correctly wired end-to-end with variance machinery matching
manual survey package calculations.

**Verified:** 2026-02-25T20:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                     | Status     | Evidence                                                                                         |
|----|-------------------------------------------------------------------------------------------|------------|--------------------------------------------------------------------------------------------------|
| 1  | Malvestuto (1996) Box 20.6 Example 1 effort estimate reproduced exactly (Site C: 287.5)   | VERIFIED   | Line 126: `expect_equal(sum(site_c$e_i_over_pi_i), 287.5, tolerance = 1e-6)` — PASS             |
| 2  | Malvestuto (1996) Box 20.6 Example 1 total effort E_hat = 847.5 reproduced exactly        | VERIFIED   | Line 136: `expect_equal(result$estimates$estimate, expected_e_hat, tolerance = 1e-6)` — PASS     |
| 3  | Malvestuto (1996) Box 20.6 Example 2 enumeration expansion 24/11 applied correctly        | VERIFIED   | Line 288: `expect_equal(site_c$.expansion[1], 24/11, tolerance = 1e-6)` — PASS                  |
| 4  | Enumeration expansion changes estimate predictably (E_hat Ex2 > E_hat Ex1)               | VERIFIED   | Line 297: `expect_gt(result_ex2$estimates$estimate, result_ex1$estimates$estimate)` — PASS       |
| 5  | Complete bus-route workflow (design -> data -> estimation) succeeds end-to-end             | VERIFIED   | Lines 336-382: 4 integration tests (effort, harvest, total-catch, grouped) — all PASS           |
| 6  | tidycreel effort estimate matches manual survey::svytotal to tolerance 1e-6               | VERIFIED   | Line 411-415: `expect_equal(..., tolerance = 1e-6)` — PASS                                      |
| 7  | tidycreel harvest estimate matches manual survey::svytotal to tolerance 1e-6              | VERIFIED   | Lines 452-456: `expect_equal(..., tolerance = 1e-6)` — PASS                                     |
| 8  | SEs match manual survey package to tolerance 1e-3                                        | VERIFIED   | Lines 431-435, 471-475: SE assertions for effort and harvest — PASS                              |
| 9  | Variance machinery is correctly wired (inverse probability weights match pi_i)            | VERIFIED   | Cross-validation section manually builds svydesign with pre-computed HT contributions — PASS    |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact                                                      | Expected                                         | Status     | Details                                               |
|---------------------------------------------------------------|--------------------------------------------------|------------|-------------------------------------------------------|
| `tests/testthat/test-primary-source-validation.R`             | Box 20.6 Example 1 and Example 2 sections        | VERIFIED   | 479 lines; both sections present with helpers          |
| `tests/testthat/test-primary-source-validation.R`             | `make_box20_6_example1` helper defined            | VERIFIED   | Defined at line 11; used in 14 test_that calls        |
| `tests/testthat/test-primary-source-validation.R`             | `make_box20_6_example2` helper defined            | VERIFIED   | Defined at line 176; used in 6 test_that calls        |
| `tests/testthat/test-primary-source-validation.R`             | `# Integration` section header present            | VERIFIED   | Line 330: `# Integration tests ----`                  |
| `tests/testthat/test-primary-source-validation.R`             | `survey::svydesign` cross-validation present      | VERIFIED   | Lines 407, 426, 448, 467                              |

**Artifact Level Detail:**

- Level 1 (Exists): PASS — file exists at `tests/testthat/test-primary-source-validation.R`
- Level 2 (Substantive): PASS — 479 lines; four distinct sections; 32 test_that blocks; no stubs or placeholders
- Level 3 (Wired): PASS — `pkgload::load_all()` + `test_file()` executes all 32 tests; FAIL 0, PASS 32

---

### Key Link Verification

| From                                        | To                              | Via                                       | Status   | Details                                                                     |
|---------------------------------------------|---------------------------------|-------------------------------------------|----------|-----------------------------------------------------------------------------|
| `make_box20_6_example1()`                   | `estimate_effort()`             | `creel_design() + add_interviews()`       | WIRED    | Line 122: `estimate_effort(make_box20_6_example1())` — executes and passes  |
| `n_counted / n_interviewed`                 | `.expansion` column             | `add_interviews()` Tier 3 bus-route       | WIRED    | Line 288: `site_c$.expansion[1]` verified == 24/11 to 1e-6                 |
| `creel_design() + add_interviews() + estimate_effort()` | `survey::svytotal()`  | inverse probability weighting (1/pi_i)    | WIRED    | Lines 400-415: HT contribution pre-computed, svydesign built, coef matched |
| `estimate_harvest()`                        | `survey::svytotal()`            | HT estimator with harvest contribution    | WIRED    | Lines 439-456: harvest contribution computed, svytotal matched to 1e-6     |

**Key Link Analysis:**

Plan 01 specified pattern `"n_counted.*n_interviewed"` — verified at line 288 via `get_enumeration_counts()` returning `.expansion` column equal to 24/11.

Plan 02 specified pattern `"survey::svydesign.*weights.*pi_i|1/\.pi_i"`. Note: the implementation deviated from the plan spec — it pre-computes the full HT contribution (`effort * .expansion / .pi_i`) and uses `ids=~1` rather than `weights=~(1/.pi_i)`. This is the correct approach (the plan spec was mathematically wrong, as documented in 26-02-SUMMARY.md). The cross-validation tests verify the correct approach passes to tolerance 1e-6, which is what matters for goal achievement.

Plan 02 specified `"survey::svytotal.*contribution"` — verified at lines 409, 428, 450, 469 where `svytotal(~.effort_contrib, ...)` and `svytotal(~.harvest_contrib, ...)` are called.

---

### Requirements Coverage

| Requirement | Source Plan | Description                                                                               | Status    | Evidence                                                                       |
|-------------|-------------|-------------------------------------------------------------------------------------------|-----------|--------------------------------------------------------------------------------|
| VALID-01    | 26-01       | Implementation reproduces Malvestuto (1996) Box 20.6 Example 1 results exactly           | SATISFIED | Site C = 287.5 (tol 1e-6), E_hat = 847.5 (tol 1e-6) — both PASS              |
| VALID-02    | 26-01       | Enumeration expansion calculations match published methodology                            | SATISFIED | expansion 24/11 verified; E_hat(Ex2) > E_hat(Ex1) via expect_gt — PASS        |
| VALID-05    | 26-02       | Integration tests verify complete bus-route workflow (design -> data -> estimation)       | SATISFIED | 4 integration tests: effort, harvest, total-catch, grouped — all PASS          |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps exactly VALID-01, VALID-02, VALID-05 to Phase 26. All three are claimed by plans and verified. No orphaned requirements.

**REQUIREMENTS.md checkbox state:** All three requirements show `[x]` in REQUIREMENTS.md, consistent with completion status.

---

### Anti-Patterns Found

| File                                       | Line | Pattern            | Severity | Impact   |
|--------------------------------------------|------|--------------------|----------|----------|
| test-primary-source-validation.R           | —    | None found         | —        | None     |

No TODOs, FIXMEs, placeholders, empty implementations, or stub patterns detected. All 32 test_that blocks contain substantive assertions with documented golden values and tolerance levels.

---

### Human Verification Required

None. All 32 tests execute with PASS via `pkgload::load_all()`. The golden arithmetic (Site C = 287.5, E_hat = 847.5) is verified programmatically to tolerance 1e-6. The cross-validation against `survey::svytotal()` proves the variance machinery is wired correctly without requiring human inspection.

---

### Test Suite Regression Check

Full test suite run with source package (`pkgload::load_all`):

```
[ FAIL 0 | WARN 837 | SKIP 0 | PASS 1098 ]
```

Phase 26 added 32 tests (14 from Plan 01 + 18 from Plan 02, per commit diffs: 328 + 150 lines).
No regressions in any of the 1066 pre-existing tests.

Warnings (837 total across full suite) are expected `survey::svydesign()` "No weights or probabilities supplied, assuming equal probability" messages — these are informational and do not indicate failures.

---

### Commit Verification

| Commit  | Description                                                    | File                                       | Status        |
|---------|----------------------------------------------------------------|--------------------------------------------|---------------|
| 4a0d5c0 | test(26-01): add Malvestuto Box 20.6 primary source validation | test-primary-source-validation.R (+328 lines) | VERIFIED   |
| ba36d31 | test(26-02): add integration and cross-validation tests        | test-primary-source-validation.R (+150 lines) | VERIFIED   |

Both commits exist in git history on branch `v2-foundation`.

---

### Notable Deviations (Documented in SUMMARYs, Verified as Correct)

**Plan 01 deviations (both auto-fixed correctly):**
1. Site D required 2 interview rows (not 1) to represent n_interviewed=2. Fixed: E_hat 747.5 -> 847.5.
2. `site_contributions` column is `e_i_over_pi_i` (not `ratio`); method is `"total"` (not `"horvitz"`).

**Plan 02 deviation (auto-fixed correctly):**
1. Cross-validation approach: Plan specified `weights=~(1/.pi_i)` in svydesign — this is mathematically incorrect and produces 18.625 instead of 847.5. Correct approach pre-computes full HT contribution and uses `ids=~1`. Verified: effort matches to 1e-6, harvest matches to 1e-6, both SEs match to 1e-3.

These deviations are documented, correct, and the final implementation passes all assertions.

---

### Gaps Summary

No gaps. All 9 must-have truths are verified, all artifacts are substantive and wired, all three
requirement IDs (VALID-01, VALID-02, VALID-05) are satisfied, and the full test suite shows FAIL 0.

---

_Verified: 2026-02-25T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
