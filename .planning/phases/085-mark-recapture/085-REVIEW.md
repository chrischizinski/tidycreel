---
phase: 085-mark-recapture
status: findings
files_reviewed: 4
findings:
  critical: 0
  warning: 3
  info: 0
  total: 3
---

## Files Reviewed

1. `R/creel-estimates-mark-recapture.R`
2. `tests/testthat/test-estimate-angler-n.R`
3. `tests/testthat/test-estimate-mr-harvest.R`
4. `_pkgdown.yml`

---

## Critical Issues

None.

---

## Warnings

### WARNING-01: `variance_method = "chapman"` mislabelled in Petersen branch

**File:** `R/creel-estimates-mark-recapture.R`, line 163
**Confidence:** 87

The Petersen branch sets `variance_method = "chapman"` but the variance formula
used is `N_hat^2 * (1/m - 1/n)` — the standard Petersen delta-method
approximation, not the Chapman (1951) bias-corrected formula. All other
delta-method estimators in the package (exploitation rate, Schnabel) use
`variance_method = "delta"`. The label `"chapman"` is correct in the Chapman
branch; using it in the Petersen branch is a metadata mislabel that will confuse
any downstream code dispatching on `variance_method`.

**Fix:** Change line 163 from `variance_method = "chapman"` to `variance_method = "delta"`.

---

### WARNING-02: Schnabel Poisson CI upper bound (`ci_hi`) unguarded when `lo_m == 0`

**File:** `R/creel-estimates-mark-recapture.R`, line 186
**Confidence:** 80

The guard at lines 184-185 handles `hi_m == 0` (for `ci_lo`) but line 186
(`ci_hi <- sum_Mn / lo_m`) has no equivalent guard. When `sum_m = 1` at
`conf_level = 0.95`, `qpois(0.025, lambda = 1) = 0`, so `lo_m = 0` and
`ci_hi = Inf`. R produces `Inf` silently. The result is statistically correct
but the asymmetry with the `hi_m` guard is misleading and untested.

**Fix:**
```r
ci_hi <- if (lo_m == 0) Inf else sum_Mn / lo_m
```

---

### WARNING-03: Test J covers only one side of the `harvest_rate` range guard

**File:** `tests/testthat/test-estimate-mr-harvest.R`, lines 68-73
**Confidence:** 80

Plan 085-02-PLAN.md behavior item J specifies testing `harvest_rate = 0` and
`harvest_rate = 1.5`. Only `harvest_rate = 0` is tested. The upper-bound branch
(`harvest_rate > 1`) of the guard (implementation line 281) is uncovered.

**Fix:** Extend Test J to include `harvest_rate = 1.5`:
```r
test_that("Test J: harvest_rate outside (0, 1] fires error", {
  expect_error(
    estimate_mr_harvest(angler_n = angler_result, harvest_rate = 0),
    regexp = "harvest_rate.*must be|\\(0, 1\\]"
  )
  expect_error(
    estimate_mr_harvest(angler_n = angler_result, harvest_rate = 1.5),
    regexp = "harvest_rate.*must be|\\(0, 1\\]"
  )
})
```

---

## Clean Items

- All `cli::` namespace prefixes present; no bare `cli_abort` calls.
- All `stats::qnorm` and `stats::qpois` calls correctly namespaced.
- `new_creel_estimates()` constructor used correctly in all three estimator branches.
- Schnabel `M[1] = 0` guard resolved correctly: `any(M < 0)` allows zero;
  `pmin(M, n)` produces `pmin(0, n[1]) = 0` so `m[1] = 0` passes cleanly.
- `_pkgdown.yml` Estimation section correctly places `estimate_angler_n` and
  `estimate_mr_harvest` after `estimate_exploitation_rate` and before
  `est_length_distribution`.
- Test conventions (sequential letter labels, manual preamble, `tolerance = 1e-10`,
  partial-regexp guards) match the exploitation-rate pattern exactly.
- Both Schnabel CI branches (Poisson `sum_m < 50`, normal `sum_m >= 50`) exercised
  in Tests M and N.
- S3 compatibility smoke tests (`compare_designs`, `autoplot`) present in Tests U and V.
