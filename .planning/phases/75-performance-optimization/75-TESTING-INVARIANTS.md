# Testing Invariants — tidycreel v1.3.0

**Phase:** 75-performance-optimization
**Deferred from:** Phase 74-02 testing strategy (74-TESTING-STRATEGY.md)
**Status:** Planning artifact — implementation deferred to v1.4.0
**Related:** 75-PERFORMANCE-ANALYSIS.md (benchmark regression guards cross-reference)
**Produced:** 2026-04-19

---

## Overview

Property-based testing generates random inputs automatically and verifies that invariant
properties hold across all of them. Instead of asserting "this specific input produces this
specific output," a property test asserts "for all valid inputs, the output satisfies this
constraint." Creel survey estimation has well-defined mathematical invariants — standard error
positivity, non-negative harvest estimates, confidence interval ordering, species additivity —
that are ideal candidates for this style of testing: they must hold regardless of survey design
parameters, sample sizes, or species mix. This document codifies the 6 invariants identified
in Phase 74-02, provides quickcheck generator sketches for each, and populates the benchmark
regression guard baselines from the Phase 75-01 profiling harness. It is the specification
document for property-based test implementation in v1.4.0.

---

## Testing Framework

### Package Selection: quickcheck

**Use `quickcheck` (CRAN).** This is the locked decision from Phase 74-02 (74-TESTING-STRATEGY.md,
Section 2.4). Do NOT substitute hedgehog or any other package — quickcheck is confirmed as the
implementation target.

`quickcheck` integrates with testthat 3.x and runs property tests inside `test_that()` blocks
without requiring a separate test runner. Its generator system handles standard R types and can
be extended to domain-specific types (such as creel design objects). It wraps hedgehog
internally, giving access to shrinking semantics when a property fails, which is the most
valuable property-testing feature for debugging.

**Installation:** Add to `Suggests:` in DESCRIPTION — not `Imports:`. Property-based tests are
testing infrastructure, not package functionality. Users who install tidycreel from CRAN do not
need quickcheck.

```
Suggests:
    quickcheck
```

**Integration pattern:** quickcheck's `for_all()` runs inside a standard `test_that()` block.
The generator is passed as a named argument; the property is an anonymous function returning
`TRUE` when the invariant holds.

```r
# tests/testthat/test-invariants.R
library(quickcheck)

test_that("INV-01: SE is positive when n > 1", {
  for_all(
    design = gen_valid_creel_design(n_min = 2),
    property = function(design) {
      result <- estimate_effort(design, target = "sampled_days")
      all(result$estimates$se > 0)
    }
  )
})
```

**Fixture construction:** Generators should reuse the `build_br_design()` pattern established
in `inst/profiling/00-generate-fixtures.R` (Phase 75-01). The fixture-building logic is already
parameterized by n_sites, n_days, n_species, and n_interviews — wrapping it in a quickcheck
generator is the lowest-friction path to a valid `creel_design` generator.

---

### quickcheck vs hedgehog Comparison

Both packages are available on CRAN and integrate with testthat. The table below documents the
evaluation that led to the Phase 74-02 decision.

| Property                       | quickcheck                          | hedgehog                             |
|-------------------------------|-------------------------------------|--------------------------------------|
| CRAN availability              | Yes                                 | Yes                                  |
| testthat 3.x integration       | Native (`for_all()` inside test_that) | Via wrapper / manual adaptation    |
| Generator composition          | Basic combinators                   | Sophisticated (integrated shrinking) |
| Shrinking (bug isolation)       | Yes (wraps hedgehog internally)     | Yes (native)                         |
| Domain type support            | Arbitrary R objects                 | Arbitrary R objects                  |
| API surface for this package   | Small; matches testthat patterns    | Larger; more boilerplate             |
| Recommended for this package   | **YES — Phase 74-02 locked choice** | No — do not use                      |

The decision is locked. hedgehog is not the implementation target.

---

## Domain Invariants

Six invariants were identified in Phase 74-02. Each invariant entry includes: a unique ID, a
precise testable statement, the statistical rationale, the functions in scope, a quickcheck
generator sketch, a testthat assertion pattern, and a v1.4.0 implementation priority.

---

### INV-01: Standard Error Positivity

**Statement:** For any estimator result computed from a design with n > 1 sampled observations,
`se > 0` for all rows in the estimates output.

**Rationale:** A standard error of zero implies either perfect population knowledge (impossible
with sampling) or a calculation failure — typically a divide-by-zero or a missing variance term.
In the creel HT framework, variance is a function of sampling design weights and observed
deviations; it cannot be structurally zero unless the sample has one observation (n = 1, where
variance is undefined) or the implementation has a bug. Any `se == 0` result when n > 1 is a
bug, not an edge case.

**Scope:** `estimate_effort()`, `estimate_total_catch()`, `estimate_harvest_rate()` — all
estimators that return a `se` column.

**quickcheck sketch:**

```r
test_that("INV-01: SE is positive for all estimators when n > 1", {
  for_all(
    design = gen_valid_creel_design(n_min = 2),
    property = function(design) {
      result <- estimate_effort(design, target = "sampled_days")
      all(result$estimates$se > 0)
    }
  )
})
```

**testthat assertion pattern:**

```r
expect_true(all(result$estimates$se > 0))
```

**Priority for v1.4.0:** HIGH — the simplest generator, widest scope, detects silent variance
failures. Implement first as a proof-of-concept for the quickcheck integration.

---

### INV-02: Non-Negative Harvest and Catch Estimates

**Statement:** Harvest count estimates and catch count estimates are >= 0 for all inputs with
non-negative observed catch counts. A negative estimate is always a model failure.

**Rationale:** You cannot harvest a negative number of fish. In the HT estimator, the
expansion factor (1 / pi_i) is always positive; observed catch counts are non-negative integers.
The product of a non-negative count and a positive expansion factor is non-negative. A negative
estimate indicates a sign error in the HT formula, a data corruption, or an incorrect expansion
step. Note: SE and CI bounds may be mathematically negative at very small n due to asymmetric
confidence interval construction — INV-04 addresses CI ordering separately. This invariant
applies only to the point estimate.

**Scope:** `estimate_total_catch()`, `estimate_harvest_rate()` — the `estimate` column in the
returned estimates data frame.

**quickcheck sketch:**

```r
test_that("INV-02: Harvest/catch estimates are non-negative", {
  for_all(
    design = gen_valid_creel_design(n_min = 1, non_negative_counts = TRUE),
    property = function(design) {
      result <- estimate_total_catch(design, variance = "taylor")
      all(result$estimates$estimate >= 0)
    }
  )
})
```

**testthat assertion pattern:**

```r
expect_true(all(result$estimates$estimate >= 0))
```

**Priority for v1.4.0:** HIGH — simple assertion; the generator is the same as INV-01 with a
non-negativity constraint on catch counts.

---

### INV-03: Estimate Consistency Across Equivalent Survey Types

**Statement:** An ice fishing `creel_design` and a bus-route `creel_design` with `p_site = 1.0`
for all sites (the degenerate ice case) must produce identical point estimates when given
identical interview and catch data.

**Rationale:** Phase 70-01 implemented ice fishing as a degenerate bus-route: when all sites
have `p_site = 1.0`, the bus-route HT estimator reduces algebraically to the ice fishing
estimator. The implementation routes ice designs through the bus-route dispatch path. If the
two code paths ever diverge — producing different estimates for structurally identical inputs —
one path has a bug. This invariant enforces the Phase 70 implementation contract across all
future changes to `estimate_harvest_rate()` and `estimate_total_catch()`.

**Scope:** `estimate_harvest_rate()`, `estimate_total_catch()` — ice vs degenerate bus_route
design pair with `p_site = 1.0`.

**quickcheck sketch:**

```r
test_that("INV-03: Ice and degenerate bus-route produce identical estimates", {
  for_all(
    data = gen_creel_interview_data(n = 50),
    property = function(data) {
      design_ice          <- build_ice_design(data)
      design_br_degenerate <- build_br_degenerate_design(data, p_site = 1.0)
      est_ice <- estimate_harvest_rate(design_ice)
      est_br  <- estimate_harvest_rate(design_br_degenerate)
      isTRUE(all.equal(
        est_ice$estimates$estimate,
        est_br$estimates$estimate,
        tolerance = 1e-6
      ))
    }
  )
})
```

**testthat assertion pattern:**

```r
expect_equal(est_ice$estimates$estimate, est_br$estimates$estimate, tolerance = 1e-6)
```

**Implementation note:** This invariant requires two fixture construction paths —
`build_ice_design()` and `build_br_degenerate_design()`. The `intersect()` guard pattern for
synthetic ice columns (established in Phase 70-01) must be correctly handled in both paths.
The generator complexity makes this higher-effort than INV-01/INV-02.

**Priority for v1.4.0:** MEDIUM — requires two design-construction helpers; implement after
INV-01, INV-02, INV-04 are working.

---

### INV-04: Confidence Interval Bounds Ordering

**Statement:** For all estimators, at any `conf_level` in the valid range (0, 1):
`ci_lower <= estimate <= ci_upper`.

**Rationale:** An estimate that falls outside its own confidence interval is always a
calculation error. This catches sign errors in SE (producing an inverted interval), incorrect
quantile direction (upper and lower swapped), or asymmetric interval construction where the
point estimate is not centered within its stated bounds. This invariant is particularly
valuable because it can be triggered by bugs introduced deep in the SE computation that are
invisible to point-estimate tests.

**Scope:** All estimators that return `ci_lower` and `ci_upper` columns: `estimate_effort()`,
`estimate_total_catch()`, `estimate_harvest_rate()`.

**quickcheck sketch:**

```r
test_that("INV-04: Estimate is within its own confidence interval", {
  for_all(
    design    = gen_valid_creel_design(n_min = 5),
    conf_level = gen_numeric_in_range(0.80, 0.99),
    property  = function(design, conf_level) {
      result <- estimate_effort(design, conf_level = conf_level)
      all(result$estimates$ci_lower <= result$estimates$estimate) &&
      all(result$estimates$estimate  <= result$estimates$ci_upper)
    }
  )
})
```

**testthat assertion pattern:**

```r
expect_true(all(result$estimates$ci_lower <= result$estimates$estimate))
expect_true(all(result$estimates$estimate  <= result$estimates$ci_upper))
```

**Implementation note:** The `conf_level` generator (`gen_numeric_in_range(0.80, 0.99)`) is a
simple wrapper around `quickcheck::gen_double()` with bounds — straightforward to implement.

**Priority for v1.4.0:** HIGH — highest value per implementation effort. Catches any
quantile-direction bug across all estimators. Recommend implementing first alongside INV-01.

---

### INV-05: Taylor SE Convergence Toward Bootstrap SE

**Statement:** As sample size n increases, the relative difference |taylor_se - bootstrap_se| /
bootstrap_se tends toward 0. This is a weak distributional invariant verified over a range of
sample sizes, not a per-sample guarantee.

**Rationale:** Taylor linearization is a first-order approximation to the true sampling
variance. It converges to the true variance in large samples. The bootstrap SE is a
higher-fidelity variance estimate at the cost of compute time (Phase 75-01: bootstrap is 54×
slower than taylor at realistic scale). If `taylor_se` is consistently 2× or more than
`bootstrap_se` across all sample sizes, the linearization has an error — likely a missing
factor or an incorrect derivative term.

**Scope:** `estimate_effort()`, `estimate_total_catch()` — taylor vs bootstrap variance method
comparison.

**Implementation note:** This invariant is fundamentally distributional. It requires running
both methods across a range of n values and fitting a regression or computing a trend, not a
single-sample assertion. Automating this without flakiness is difficult: on any individual
random sample, `taylor_se` and `bootstrap_se` can diverge substantially even when both are
correct. **Recommendation: treat INV-05 as a manual review invariant** — verified periodically
using the 75-PERFORMANCE-ANALYSIS.md benchmark data rather than an automated quickcheck property.
The Phase 75-01 empirical results (taylor ~1.5ms, bootstrap ~83ms at realistic scale) show that
the two methods operate at sensible magnitudes; systematic divergence would be visible in the
profiling harness output.

**quickcheck sketch:** Not recommended for automated quickcheck implementation. A manual
verification script is sufficient:

```r
# Manual check: run 03-bench-variance-methods.R and inspect taylor vs bootstrap SE
# across the realistic and stress fixtures. Divergence > 50% at large n flags an issue.
```

**Priority for v1.4.0:** MEDIUM (manual verification sufficient). Do not implement as an
automated quickcheck property — the flakiness cost exceeds the detection value for this
invariant.

---

### INV-06: Species Additivity

**Statement:** The sum of per-species harvest estimates equals the all-species aggregate
harvest estimate, within floating-point tolerance:
`sum(per_species$estimates$estimate) ≈ aggregate$estimates$estimate`.

**Rationale:** Total harvest is the sum of species harvests. The HT estimator computes totals
additively: the all-species total should equal the sum of individual species totals. If the
per-species estimation path and the aggregate path diverge, there is either a double-counting
bug in the aggregate, a missing species in the per-species enumeration, or a species-filtering
error. This invariant is particularly important for multi-species creel surveys where species
composition changes across sampling occasions.

**Scope:** `estimate_total_catch()` — per-species (`by = "species"`) vs aggregate comparison.
Note: species additivity is exact for HT estimators (ratio estimators do not have exact
additivity — the invariant is HIGH priority for HT, MEDIUM for ratio).

**quickcheck sketch:**

```r
test_that("INV-06: Per-species estimates sum to aggregate total", {
  for_all(
    design = gen_valid_creel_design_multi_species(n_species_min = 2),
    property = function(design) {
      per_species <- estimate_total_catch(design, by = "species")
      aggregate   <- estimate_total_catch(design)
      species_sum <- sum(per_species$estimates$estimate)
      agg_est     <- aggregate$estimates$estimate
      # Relative tolerance: 1e-6 × aggregate magnitude
      abs(species_sum - agg_est) < 1e-6 * max(abs(agg_est), 1)
    }
  )
})
```

**testthat assertion pattern:**

```r
expect_equal(
  sum(per_species$estimates$estimate),
  aggregate$estimates$estimate,
  tolerance = 1e-6
)
```

**Implementation note:** This invariant requires a multi-species fixture generator
(`gen_valid_creel_design_multi_species()`). The generator must produce at least two species
with non-zero catch on multiple sampling occasions to make the additivity constraint
non-trivial.

**Priority for v1.4.0:** HIGH for HT estimators; MEDIUM for ratio estimators. Implement after
INV-01, INV-02, INV-04 are validated.

---

## Invariant Summary Table

| ID     | Statement (brief)                                      | Scope                                  | Automatable | Priority   |
|--------|--------------------------------------------------------|----------------------------------------|-------------|------------|
| INV-01 | SE > 0 when n > 1                                      | All estimators                         | Yes         | HIGH       |
| INV-02 | Harvest/catch estimate >= 0                            | estimate_total_catch, harvest_rate     | Yes         | HIGH       |
| INV-03 | Ice == degenerate bus-route (p_site = 1.0)             | estimate_harvest_rate, total_catch     | Yes         | MEDIUM     |
| INV-04 | ci_lower <= estimate <= ci_upper                       | All estimators with CI columns         | Yes         | HIGH       |
| INV-05 | Taylor SE converges toward bootstrap SE as n grows     | estimate_effort, estimate_total_catch  | Manual only | MEDIUM     |
| INV-06 | Sum of species estimates equals aggregate estimate     | estimate_total_catch (HT path)         | Yes         | HIGH (HT)  |

---

## Benchmark Regression Guards

These are documented baselines — not automated testthat assertions. Timing is
machine-dependent and notoriously flaky across CI environments. Named baselines are
documented constraints: if a future change causes a function's median execution time to exceed
its ceiling, investigate the regression before merging.

**Baseline source:** Phase 75-01 profiling harness (`inst/profiling/02-bench-estimators.R` and
`03-bench-variance-methods.R`). Cross-reference: 75-PERFORMANCE-ANALYSIS.md for the full
empirical analysis.

**Ceiling definition:** 2× the observed median at the corresponding scale. A result below the
ceiling is acceptable; above the ceiling warrants investigation.

| Function                           | Scale     | Variance method | Median (ms) | Ceiling (ms) | Measured                          |
|------------------------------------|-----------|-----------------|-------------|--------------|-----------------------------------|
| `estimate_effort()`                | realistic | taylor          | 1.44        | 3            | 2026-04-19, Apple M-series Mac    |
| `estimate_effort()`                | stress    | taylor          | 5.41        | 11           | 2026-04-19, Apple M-series Mac    |
| `estimate_total_catch()`           | realistic | taylor          | 1.47        | 3            | 2026-04-19, Apple M-series Mac    |
| `estimate_total_catch()`           | stress    | taylor          | 5.25        | 11           | 2026-04-19, Apple M-series Mac    |
| `estimate_total_catch()`           | realistic | jackknife       | ~28         | 60           | 2026-04-19, Apple M-series Mac    |
| `estimate_total_catch()`           | realistic | bootstrap       | ~83–118     | 240          | 2026-04-19, Apple M-series Mac    |

**Scale definitions:**
- Realistic: 30 sites, 20 days, 5 species, ~500 interviews
- Stress: 300 sites, 200 days, 10 species, ~5000 interviews

**Scaling behavior (from Phase 75-01):** 10× data volume produces approximately 3.7× execution
time — sub-linear, indicating efficient set operations in the HT expansion step. This scaling
behavior is itself an informal invariant: a change that makes scaling super-linear (10× data →
10× time) suggests introduction of an O(n²) operation.

**Machine note:** These baselines were measured on an Apple M-series Mac in a development
environment. CI machines (GitHub Actions) may be 2–4× slower. Do not port these exact ceilings
to CI — use them for local regression investigation only.

**How to use these baselines:**
1. After a change that touches estimation internals, run `inst/profiling/02-bench-estimators.R`
2. Compare the printed median values against the table above
3. If any function exceeds its ceiling, profile with `inst/profiling/01-profvis-workflow.R`
   to identify the regression source before merging

---

## Implementation Guidance for v1.4.0

### Priority Order

The recommended implementation sequence balances detection value against implementation effort:

1. **INV-04 (CI bounds ordering)** — Highest value per effort. The `conf_level` generator is
   trivial (a bounded double); the assertion catches quantile-direction bugs across all
   estimators. Implement first.

2. **INV-01 (SE positivity)** — Second highest value, simplest generator. The `n_min = 2`
   constraint on the design generator prevents the degenerate n = 1 case. Wide scope across
   all estimators. Implement alongside INV-04 (they share the same generator).

3. **INV-02 (non-negative estimates)** — Same generator as INV-01 with a non-negativity
   constraint on the count inputs. Simple assertion; implement third.

4. **INV-06 (species additivity)** — Requires the multi-species fixture generator
   (`gen_valid_creel_design_multi_species()`). High detection value for the HT estimation
   path. Implement fourth.

5. **INV-03 (ice/bus-route consistency)** — Requires two design-construction helpers and
   correct handling of the `intersect()` guard for synthetic ice columns. Medium effort;
   implement fifth.

6. **INV-05 (Taylor/bootstrap convergence)** — Do not implement as an automated quickcheck
   property. Use the `inst/profiling/03-bench-variance-methods.R` output for periodic manual
   verification.

### Adoption Steps

```r
# Step 1: Add quickcheck to Suggests in DESCRIPTION
# Suggests:
#     quickcheck,
#     ...

# Step 2: Create shared generator helper
# tests/testthat/helper-generators.R
# Provides: gen_valid_creel_design(), gen_creel_interview_data(),
#           gen_valid_creel_design_multi_species(), gen_numeric_in_range()

# Step 3: Create property test file
# tests/testthat/test-invariants.R
# Implements INV-01, INV-02, INV-04 first (all use gen_valid_creel_design())

# Step 4: Add INV-06 after multi-species generator is validated

# Step 5: Add INV-03 after ice and bus-route design-construction helpers are verified
```

### Generator Design Notes

The main friction point for property-based testing in tidycreel is generating valid
`creel_design` objects. A valid design requires:

- A `survey_type` value from the supported enum (`bus_route`, `ice`, etc.)
- A `sampling_frame` with consistent site IDs, `p_site` values in (0, 1], and day counts
- Interview data whose site IDs match the sampling frame
- `p_site = 1.0` for ice designs (the degenerate bus-route constraint)

The `build_br_design()` helper in `inst/profiling/00-generate-fixtures.R` (Phase 75-01)
provides a parameterized template. A generator wrapping this helper with random but valid
parameters (n_sites in 2–50, n_days in 5–100, n_interviews per day in 1–20) is the
lowest-friction path to `gen_valid_creel_design()`.

Write the generator to `tests/testthat/helper-generators.R`. testthat automatically sources
`helper-*.R` files before test files, making the generator available to all test files without
explicit `source()` calls.

---

## Connection to Phase 74 Testing Strategy

This document is the implementation specification for Phase 74-02 Recommendation R3 (MEDIUM:
implement property-based tests for the 6 domain invariants) and R5 (LOW: write
`helper-generators.R` with a minimal `creel_design` generator). See 74-TESTING-STRATEGY.md
Section 2.4 for the full property-based testing rationale and the invariant table.

Property-based testing is a fourth tier in the tidycreel testing hierarchy:

1. **Unit tests** (current standard practice) — single-function, controlled inputs, tolerance-
   based numeric assertions. See 74-TESTING-STRATEGY.md Section 2.1.
2. **Snapshot tests** (to be adopted in v1.4.0) — `expect_snapshot()` for print/format/autoplot
   formatted text output only; never for numeric estimates. See 74-TESTING-STRATEGY.md
   Section 2.2.
3. **Integration tests** (existing pattern, now named) — end-to-end workflows exercising the
   full estimation chain. See 74-TESTING-STRATEGY.md Section 2.3.
4. **Property-based tests** (this document) — invariant properties verified over random inputs
   using quickcheck. Implementation target: v1.4.0.

The snapshot testing policy and numeric tolerance policy from 74-TESTING-STRATEGY.md apply
within property-based tests as well. The `for_all()` property function should use
`isTRUE(all.equal(..., tolerance = 1e-6))` for floating-point comparisons rather than exact
equality, consistent with the package-wide tolerance policy.

---

*Phase: 75-performance-optimization*
*Deferred from: Phase 74-02*
*Produced: 2026-04-19*
