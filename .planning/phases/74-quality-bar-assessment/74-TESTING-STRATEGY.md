# Phase 74: Testing Strategy — tidycreel v1.3.0

**Produced:** 2026-04-18
**Status:** Complete
**Audience:** Contributors and maintainers

---

## Executive Summary

This document is a decision guide. Its purpose is to give contributors a clear policy for choosing the right test type — not to catalog gaps. A contributor reading this document should be able to determine which test type is appropriate for any new test without consulting anyone.

**Current state:** tidycreel v1.3.0 has 58 test files, approximately 1,536 test blocks, and uses testthat 3.x with edition 3. The test infrastructure is healthy: `_snaps/` directory exists (snapshot infrastructure is in place), `helper-db.R` provides integration test helpers for DBI/duckdb workflows, and `_problems/` archives 17 regression test files for historical issue tracking.

**What this document adds:** (1) An explicit snapshot adoption policy — use `expect_snapshot()` for formatted text output; never use it for numeric estimates. (2) Named property-based domain invariants for creel estimation, with a concrete implementation recommendation (Phase 75 or v1.4.0). (3) A name for the integration test pattern already in use throughout the codebase. The package's testing fundamentals are solid; the primary gap is zero `expect_snapshot()` calls despite 15+ print/format/autoplot methods.

---

## Section 1: Test Infrastructure Overview

| Property | Value |
|----------|-------|
| Framework | testthat 3.x (`Config/testthat/edition: 3` in DESCRIPTION) |
| Test files | 58 active files in `tests/testthat/` |
| Test blocks | ~1,536 |
| Snapshot infrastructure | `_snaps/` directory present; **zero `expect_snapshot()` calls** |
| Helper files | `helper-db.R` — DBI/duckdb integration test helpers |
| Problem archive | `_problems/` — 17 regression test files |

The most notable infrastructure characteristic: the snapshot infrastructure is fully in place (the `_snaps/` directory exists, testthat 3.x supports snapshots natively), but zero snapshot calls have been written. This is the primary coverage gap — 15+ print/format/autoplot methods have no output regression tests.

---

## Section 2: Test Type Decision Guide

### 2.1 Unit Tests (current standard practice)

**WHAT:** Individual functions with controlled inputs and known expected outputs. The test exercises one function and asserts on its return value.

**WHEN to use:**
- All estimation functions (`estimate_effort()`, `estimate_catch_rate()`, `estimate_harvest_rate()`, etc.)
- All validation functions (`validate_design()`, `check_completeness()`)
- All design constructors (`creel_design()`, `creel_schedule()`)
- All data preparation functions (`add_counts()`, `add_interviews()`)
- Default choice for any new function — start here unless a test inherently spans multiple functions

**WHEN NOT to use:**
- When a test requires multiple public functions working together in sequence — use an integration test instead (see Section 2.3)

**Pattern:**
```r
testthat::test_that("estimate_effort returns positive SE when n_sampled > 1", {
  design <- creel_design(...)
  result <- estimate_effort(design)
  expect_equal(result$SE, expected_SE, tolerance = 1e-6)
  expect_true(result$SE > 0)
})
```

**Critical numeric tolerance policy — explicitly stated as package-wide rule:**

> **NEVER use exact equality for numeric estimates. Always use `tolerance =` for floating-point quantities.**

The platform-specific floating-point behavior of R means that exact comparisons on computed numeric values will produce false failures across platforms (Linux vs. macOS vs. Windows). The tolerance argument prevents this.

Tolerance guidance by quantity type:

| Quantity type | Tolerance | Rationale |
|---------------|-----------|-----------|
| Intermediate computed values | `1e-6` | Near-exact; catches meaningful differences |
| Final effort/harvest estimates | `1e-4` | Allows platform floating-point variation |
| CV / SE ratios | `1e-2` | Ratio quantities have compounded uncertainty |

This policy is already followed in most estimation tests. The recommendation R2 below asks for a package-wide audit to confirm all `expect_equal()` calls on numeric outputs carry `tolerance =`.

---

### 2.2 Snapshot Tests (to be adopted)

**WHAT:** `expect_snapshot()` captures text output on first run and stores it in `_snaps/`. Subsequent runs compare against the stored snapshot and fail if output changes.

**WHEN to use:**
- Print methods: `print.creel_design`, `print.creel_estimates_*`, `print.creel_schedule`
- Format methods: `format.creel_design`, `format.creel_estimates_*`, `format.creel_schedule`
- Complex multi-line error messages where the rendered text structure matters (not just the condition class)
- `autoplot.*` output via `vdiffr::expect_doppelganger()` — pixel-aware comparison for ggplot objects

**WHEN NOT to use — explicitly stated as policy:**

> **Do NOT use `expect_snapshot()` for numeric estimates, data frame cell values, or any quantity where tolerance-based comparison is appropriate. The stored snapshot must not contain floating-point values.**

Why this matters: snapshot test sprawl occurs when snapshots capture numeric outputs. As floating-point representation or rounding changes across R versions and platforms, snapshot tests fail even though the underlying computation is correct. These false positives erode confidence in the test suite. The rule is simple: if you find yourself writing `expect_snapshot()` for something that `expect_equal(..., tolerance = ...)` could test, use `expect_equal()` instead.

Warning signs of snapshot sprawl:
- Snapshot files containing numeric values
- Snapshot files containing data frame rows with computed quantities
- `expect_snapshot()` calls where the value under test is an estimate, not a label or formatted string

**Current gap:** The `_snaps/` directory exists but is empty — zero `expect_snapshot()` calls despite 15+ print/format/autoplot methods in the package. This is the primary snapshot gap and a pure coverage issue (not an infrastructure issue — the tooling is ready).

**Priority methods for snapshot adoption:**

| Priority | Method | Rationale |
|----------|--------|-----------|
| 1 | `print.creel_design` / `format.creel_design` | Complex multi-section output; high contributor-facing value; changes to the display format are currently undetected |
| 2 | `print.creel_estimates_mor` / `format.creel_estimates_mor` | Estimator output regression; protects against accidental format changes |
| 3 | `print.creel_schedule` / `format.creel_schedule` | Schedule display output |
| 4 | `autoplot.creel_estimates` | Via `vdiffr::expect_doppelganger()` — pixel-aware |
| 5 | `autoplot.creel_schedule` | Via vdiffr |
| 6 | `autoplot.creel_length_distribution` | Via vdiffr |

**Snapshot update workflow:** After an intentional change to formatted output, update snapshots with:
```r
testthat::snapshot_review()   # interactive review and accept/reject
testthat::snapshot_accept()   # bulk-accept all changed snapshots
```
Run these from the package root. Commit the updated `_snaps/` files alongside the code change that caused them.

**Do NOT use `expect_snapshot()` as a lazy substitute for `expect_equal()`.** Snapshots are for output regression, not behavior testing.

---

### 2.3 Integration Tests (existing pattern, now named)

**WHAT:** End-to-end workflows that exercise multiple public functions in sequence. The test constructs a realistic input, pipes it through the full estimation chain, and asserts on final outputs.

**WHEN to use:**
- Any test that exercises the full estimation pipeline: design construction → `add_counts()` → `estimate_effort()` → `add_interviews()` → `estimate_catch_rate()` → `estimate_harvest_rate()`
- Tests that verify the contract between design construction and estimation — that a valid `creel_design` object produces the expected estimate shape
- Cross-function behavioral assertions: "a valid bus_route design with these parameters produces effort estimates whose SE is positive"

**WHEN NOT to use:**
- Testing a single function in isolation (use a unit test instead)

**Why naming this pattern matters:** Many test files already implement integration tests (e.g., `test-creel-design.R` constructs full designs and pipes through estimation). Naming the pattern gives contributors a vocabulary for describing test scope and helps reviewers understand intent.

**Pattern:**
```r
testthat::test_that("bus_route design produces positive effort SE", {
  design <- creel_design(
    survey_type = "bus_route",
    sampling_frame = ...,
    p_site = ...,
    ...
  )
  result <- design |>
    add_counts(...) |>
    estimate_effort()
  expect_s3_class(result, "creel_estimates_effort")
  expect_true(all(result$SE > 0))
  expect_equal(result$estimate, expected_estimate, tolerance = 1e-4)
})
```

**Using `helper-db.R`:** For tests involving DBI/duckdb database paths, use the helpers in `tests/testthat/helper-db.R` rather than constructing mock objects. These helpers establish the right connection lifecycle and are already integrated with testthat's setup/teardown model.

**Numeric tolerance still applies:** Integration tests assert on final outputs — those outputs are numeric estimates. The same tolerance policy from Section 2.1 applies.

---

### 2.4 Property-Based Tests (future groundwork)

**WHAT:** A test framework generates random inputs automatically and verifies that invariant properties hold for all of them. Instead of asserting "this specific input produces this specific output," a property test asserts "for all valid inputs, the output satisfies this constraint."

**WHY document groundwork now:** Creel survey estimation has well-defined mathematical invariants that property-based testing is well-suited to verify. Documenting those invariants now creates a concrete starting point for a future implementation phase, avoiding the need to rediscover them during implementation.

**R package recommendation: `quickcheck`**

Use `quickcheck` (on CRAN; wraps `hedgehog`; integrates with testthat). Do NOT use `rapidcheck` — rapidcheck is a C++ library with no R interface and cannot be used from R package tests.

`quickcheck` integrates with testthat and handles standard R type generators. It runs property tests inside `test_that()` blocks without requiring a separate test runner.

**Domain invariants for creel estimation (6 invariants for future property tests):**

| # | Invariant | Why it matters |
|---|-----------|----------------|
| 1 | SE > 0 whenever n_sampled > 1 | Variance estimators must never return zero or negative variance; a zero SE implies perfect knowledge or a computation error |
| 2 | Harvest estimate >= 0 for all non-negative catch inputs | Harvest cannot be negative for non-negative observed counts — a numerical failure mode to guard against |
| 3 | Effort estimates are consistent when equivalent design representations are used (ice as degenerate bus_route produces identical estimates) | Exercises the equivalence contract established in Phase 70 |
| 4 | CV = SE / estimate (when estimate > 0) | Ratio relationship is exact and must hold across all random inputs |
| 5 | Confidence interval width scales with SE: (CI_upper - CI_lower) is proportional to SE × z-score | A numerical soundness property on the confidence interval construction |
| 6 | Stratum totals sum to period total under additive designs (no mass is lost in aggregation) | Conservation of mass in the aggregation step |

**Practicality assessment:** `quickcheck` integrates cleanly with testthat and handles numeric generators without boilerplate. The main domain setup cost is generating valid `creel_design` objects with random but valid inputs — the `survey_type` enum, `sampling_frame` structure, consistent `p_site` values, and valid interview data must all be jointly coherent. This generator complexity is non-trivial and warrants its own dedicated slot.

**Recommendation: Phase 75 or the v1.4.0 milestone** — NOT Phase 74. The invariants above are the specification; implementation is deferred.

**Groundwork action for a future phase:** Define a `creel_design` generator at `tests/testthat/helper-generators.R` using `quickcheck`. The 6 invariants become the property test bodies. Start with invariant 1 (SE > 0 when n_sampled > 1) as a proof-of-concept before expanding. This is the lowest-friction entry point: n_sampled is a simple integer parameter with an easy valid range.

---

## Section 3: Named Condition Class Testing

Cross-reference: **74-QUALITY-AUDIT.md, Section 4** — the full named condition class analysis (priority sites, implementation recommendation, API contract rationale) lives in the quality audit document. This section covers only the testing implications.

**Current state:** Tests use the message-matching form of `expect_error()`:

```r
# Current (fragile)
expect_error(creel_design(bad_input), "survey_type.*not recognized")
```

This form is fragile: whenever error message wording is improved (for clarity, localization, or cli formatting changes), the test breaks — even though the function's error behavior is correct.

**Target state (post-implementation):** Once named condition classes are added to `cli_abort()` calls, tests should use the `class =` form:

```r
# Target (robust)
expect_error(creel_design(bad_input), class = "creel_error_invalid_survey_type")
```

The class name is a stable API surface; message text is an implementation detail that should be free to change.

**Policy: when named condition classes are added to a function, update all `expect_error()` calls for that function to `class =` form in the same commit.** Do not allow message-matching tests to accumulate for functions that already have named classes — this creates a maintenance burden and defeats the purpose of naming the conditions.

Named condition class testing is a post-implementation task. No action is required until the quality audit's R4 recommendation (named condition class implementation) is actioned. At that point, the test updates are part of the same implementation phase, not a deferred cleanup step.

---

## Section 4: Positive Findings

These patterns exist in the current test infrastructure and should be preserved.

**P1: testthat 3.x edition**
Modern test infrastructure with parallel test execution, native snapshot support (`expect_snapshot()`), and improved error reporting. The `Config/testthat/edition: 3` setting in DESCRIPTION activates these capabilities. No migration required — the package is already on the current edition.

**P2: 58 test files with ~1,536 test blocks**
A broad coverage baseline for a package of this complexity (70 exported functions, 22+ estimator families). The volume provides confidence that the estimation core is exercised; the snapshot and property-based gaps are additions to a solid foundation, not corrections to absent coverage.

**P3: `helper-db.R` — dedicated integration test helpers**
A `tests/testthat/helper-db.R` file provides shared helpers for DBI/duckdb integration tests. This avoids duplication and reduces boilerplate in database workflow tests. The pattern is correct: shared test infrastructure lives in helper files, not inline in test files.

**P4: `_problems/` problem archive**
17 regression test files documenting historical issues. This is a valuable pattern for a complex statistical package: when a bug is reported, a test is written that exercises the problematic behavior. The `_problems/` archive preserves that institutional knowledge and ensures regressions are detected. Not all packages do this.

**P5: Tolerance-based numeric comparison already in use**
Estimation tests already use `expect_equal(actual, expected, tolerance = ...)` in the right places. This document's tolerance policy (Section 2.1) codifies existing correct practice, not a new requirement. The policy audit (recommendation R2) verifies compliance across the full test suite.

---

## Section 5: Common Pitfalls

**Pitfall 1: Snapshot test sprawl**

Snapshots adopted for numeric outputs. Tests fail whenever floating-point representation or rounding changes, producing false positives that erode trust in the test suite.

*Why it happens:* `expect_snapshot()` is convenient; developers reach for it when a value is complex to assert on.

*Prevention:* Follow the explicit policy in Section 2.2. If the snapshot file would contain a number, use `expect_equal(..., tolerance = ...)` instead.

*Warning signs:* Snapshot files containing numeric values, data frame cell values, or computed quantities.

**Pitfall 2: `class =` missing from `expect_error()` after adding named conditions**

Tests continue to use the message-matching form `expect_error(fn(), "regex")` after a named condition class is added to the function. Message wording later changes (for a good reason), the test breaks, and the developer can't tell whether the fix is changing the test regex or reverting the message change.

*Prevention:* Follow the policy in Section 3: when adding a named condition class to a function, update all `expect_error()` calls for that function to `class =` form in the same commit.

**Pitfall 3: `\dontrun{}` on examples that could run**

Examples that work fine are wrapped in `\dontrun{}`, so they are never exercised and can drift out of sync with the current API. This means `R CMD check --run-dontrun` does not execute them, and errors may go undetected until a user tries the example.

*Prevention:* Use `\donttest{}` when an example is slow, has side effects, or is large but otherwise runnable. Reserve `\dontrun{}` for examples requiring external dependencies, credentials, or interactive input that genuinely cannot run non-interactively.

*tidycreel context:* The current 15 uses of `\dontrun{}` are largely defensible; `hybrid-design.R` and `season-summary.R` are borderline candidates for `\donttest{}` instead. See 74-QUALITY-AUDIT.md Section 3.3 for the full assessment.

**Pitfall 4: Coverage number without coverage intelligence**

A high overall coverage percentage masks 0% coverage on key estimation paths, because simple utility functions inflate the percentage. A package can show 80% overall while its core statistical functions have no meaningful test exercise.

*Prevention:* Report overall coverage percentage AND flag exported functions with 0% or near-0% coverage separately. The estimation core and validation layer are the functions where coverage matters most — track these independently of the overall number.

---

## Section 6: Recommendations

The following recommendations are consolidated and prioritised. Each states WHAT to do, WHY it matters, and the implementation priority.

---

**R1 (HIGH): Add snapshot tests for the 6 priority print/format/autoplot methods**

WHAT: Write `expect_snapshot()` calls for the 6 methods listed in Section 2.2 (starting with `print.creel_design` and `print.creel_estimates_mor`). For autoplot methods, use `vdiffr::expect_doppelganger()`.

WHY: The `_snaps/` directory already exists — this is a coverage gap, not an infrastructure gap. Any change to formatted output currently goes undetected. The methods listed in Section 2.2 are the highest contributor-facing surfaces: a user's first interaction with an estimator result is usually `print()`. Snapshot coverage here directly protects the user-visible API.

Priority: HIGH. Recommended slot: dedicated snapshot adoption phase in v1.4.0.

---

**R2 (HIGH): Enforce the numeric tolerance policy package-wide**

WHAT: Audit all existing `expect_equal()` calls in `tests/testthat/` that operate on numeric outputs. Add `tolerance =` where it is missing.

WHY: The tolerance policy in Section 2.1 codifies existing correct practice for most tests. A blanket audit confirms compliance and prevents platform-specific false failures in CI. This is a correctness property, not a style preference.

Priority: HIGH. This can be done as a targeted cleanup pass without restructuring tests. Recommended slot: next contributor sprint or Phase 75 setup.

---

**R3 (MEDIUM): Implement property-based tests for the 6 domain invariants**

WHAT: Add `quickcheck` to `Suggests`, write a `creel_design` generator in `tests/testthat/helper-generators.R`, and implement property tests for the 6 invariants listed in Section 2.4.

WHY: Mathematical invariants (SE > 0, CV = SE/estimate, stratum totals sum to period total) are exactly the properties that property-based testing is designed to verify. These invariants cannot be exhaustively confirmed by point tests; randomized inputs surface edge cases that fixed test data never will.

Priority: MEDIUM. Recommended slot: Phase 75 or v1.4.0. Start with invariant 1 (SE > 0 when n_sampled > 1) as a proof-of-concept; expand from there.

---

**R4 (MEDIUM): Update `expect_error()` calls to `class =` form when named condition classes are implemented**

WHAT: When the quality audit's R4 recommendation (implement named condition classes) is actioned, update all `expect_error()` calls for the affected functions from message-matching form to `class =` form in the same commit.

WHY: Message-matching tests are a maintenance liability after named classes exist — every error message improvement becomes a test breakage. The `class =` form is more robust and accurately tests the contract (the condition type, not the rendered text).

Priority: MEDIUM. This is coordinated with 74-QUALITY-AUDIT.md R4 — do this in the same phase as the named conditions implementation, not as a separate cleanup step.

---

**R5 (LOW): Add `helper-generators.R` to `tests/testthat/` with a minimal `creel_design` generator**

WHAT: Create `tests/testthat/helper-generators.R` with a minimal `creel_design` generator using `quickcheck`. Even if property-based tests are not implemented in the current phase, having the generator ready reduces friction for the implementation phase.

WHY: The domain setup cost for generating valid `creel_design` objects (survey_type enum, valid sampling_frame, consistent p_site values, coherent interview data) is the main friction point for property-based testing. Writing the generator separately from the property tests separates the domain modeling problem from the test assertion problem.

Priority: LOW. Can be done alongside any Phase 75 or v1.4.0 planning work, before property-based test implementation begins.

---

## Summary Table

| # | Recommendation | Priority | Slot |
|---|----------------|----------|------|
| R1 | Snapshot tests for 6 print/format/autoplot methods | HIGH | v1.4.0 snapshot phase |
| R2 | Numeric tolerance policy audit — add `tolerance =` where missing | HIGH | Next sprint / Phase 75 |
| R3 | Property-based tests for 6 domain invariants | MEDIUM | Phase 75 or v1.4.0 |
| R4 | Update `expect_error()` to `class =` form with named conditions | MEDIUM | Same phase as named conditions |
| R5 | Write `helper-generators.R` with `creel_design` generator | LOW | v1.4.0 pre-work |

---

*Phase: 74-quality-bar-assessment*
*Strategy produced: 2026-04-18*
*Cross-references: 74-QUALITY-AUDIT.md (Sections 3.3, 4), 74-RESEARCH.md*
