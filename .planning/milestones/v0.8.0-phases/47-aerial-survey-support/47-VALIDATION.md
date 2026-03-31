---
phase: 47
slug: aerial-survey-support
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 47 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat >= 3.0.0 (edition 3) |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `devtools::test(filter = "creel-design")` |
| **Full suite command** | `devtools::test()` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(filter = "creel-design")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | AIR-01 | unit | `devtools::test(filter = "creel-design")` | ✅ | ⬜ pending |
| 47-01-02 | 01 | 1 | AIR-01 | unit | `devtools::test(filter = "estimate-effort")` | ✅ | ⬜ pending |
| 47-01-03 | 01 | 1 | AIR-02 | unit | `devtools::test(filter = "estimate-effort")` | ✅ | ⬜ pending |
| 47-01-04 | 01 | 1 | AIR-03 | unit | `devtools::test(filter = "creel-design")` | ✅ | ⬜ pending |
| 47-01-05 | 01 | 1 | AIR-04 | validation | `devtools::test(filter = "primary-source")` | ✅ | ⬜ pending |
| 47-02-01 | 02 | 2 | AIR-05 | unit | `devtools::test(filter = "add-interviews")` | ✅ | ⬜ pending |
| 47-02-02 | 02 | 2 | AIR-05 | unit | `devtools::test(filter = "estimate-catch-rate")` | ✅ | ⬜ pending |
| 47-02-03 | 02 | 2 | AIR-05 | unit | `devtools::test(filter = "estimate-total-catch")` | ✅ | ⬜ pending |
| 47-03-01 | 03 | 3 | AIR-06 | data | `devtools::test(filter = "data")` | ❌ Wave 0 | ⬜ pending |
| 47-03-02 | 03 | 3 | AIR-06 | integration | `devtools::test()` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-estimate-effort-aerial.R` — failing stubs for AIR-01 through AIR-04
- [ ] `tests/testthat/test-primary-source-validation.R` — existing file; add aerial stubs for AIR-04
- [ ] `tests/testthat/_problems/` — Malvestuto Box 20.6 fixture data (obtain exact numbers before Wave 1)

*Existing infrastructure covers most requirements; only the example datasets (AIR-06) are a Wave 0 gap.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Vignette renders without error | AIR-06 | pkgdown/knitr rendering | `devtools::build_vignettes()` then check output |

---

## Numerical Validation Details (AIR-04)

**Tolerance:** `expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)` — same as bus-route validation in `test-primary-source-validation.R`.

**Formula:** `Ê = (N_counted / v) × H_open × L̄`

**Delta method variance:** `Var(Ê) ≈ (H_open/v)² × [L̄² × Var(N̂) + N̂² × Var(L̄)]`

**What the validation test checks:**
1. Point estimate matches published E_hat exactly (within floating-point tolerance)
2. SE is computed correctly via delta method formula
3. CI bounds are symmetric around the point estimate (normal approximation)

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (example datasets)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
