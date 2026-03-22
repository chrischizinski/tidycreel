---
phase: 44
slug: design-type-enum-and-validation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 44 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat |
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
| 44-01-01 | 01 | 0 | INFRA-02 | unit | `devtools::test(filter = "creel-design")` | ❌ W0 | ⬜ pending |
| 44-01-02 | 01 | 0 | INFRA-02 | unit | `devtools::test(filter = "creel-design")` | ❌ W0 | ⬜ pending |
| 44-01-03 | 01 | 0 | INFRA-01 | unit | `devtools::test(filter = "creel-design")` | ❌ W0 | ⬜ pending |
| 44-01-04 | 01 | 0 | INFRA-01 | unit | `devtools::test(filter = "creel-design")` | ❌ W0 | ⬜ pending |
| 44-01-05 | 01 | 0 | INFRA-01 | unit | `devtools::test(filter = "creel-design")` | ❌ W0 | ⬜ pending |
| 44-02-01 | 02 | 1 | INFRA-03 | regression | `devtools::test()` | ✅ existing | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] New test cases in `tests/testthat/test-creel-design.R` — stubs for INFRA-01 (ice/camera/aerial construction), INFRA-02 (unknown type abort + error message)

*Extends existing file — no new test file needed. All new tests belong alongside the existing bus_route test block.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Error message is human-readable and names the bad type | INFRA-02 | Message quality not checked by regexp alone | Run `creel_design(cal, date=date, strata=day_type, survey_type="unknown_type")` in R console; confirm message reads naturally |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
