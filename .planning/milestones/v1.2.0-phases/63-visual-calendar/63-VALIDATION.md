---
phase: 63
slug: visual-calendar
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 63 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3rd edition (>= 3.0.0) |
| **Config file** | `tests/testthat.R` / `Config/testthat/edition: 3` in DESCRIPTION |
| **Quick run command** | `devtools::test(filter = "schedule-print")` |
| **Full suite command** | `devtools::test()` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(filter = "schedule-print")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 63-01-01 | 01 | 0 | CAL-01, CAL-02 | unit | `devtools::test(filter = "schedule-print")` | ❌ W0 | ⬜ pending |
| 63-01-02 | 01 | 1 | CAL-01 | unit | `devtools::test(filter = "schedule-print")` | ❌ W0 | ⬜ pending |
| 63-01-03 | 01 | 1 | CAL-01 | unit | `devtools::test(filter = "schedule-print")` | ❌ W0 | ⬜ pending |
| 63-01-04 | 01 | 1 | CAL-01 | unit | `devtools::test(filter = "schedule-print")` | ❌ W0 | ⬜ pending |
| 63-02-01 | 02 | 1 | CAL-02 | unit | `devtools::test(filter = "schedule-print")` | ❌ W0 | ⬜ pending |
| 63-02-02 | 02 | 1 | CAL-02 | unit | `devtools::test(filter = "schedule-print")` | ❌ W0 | ⬜ pending |
| 63-02-03 | 02 | 2 | CAL-01, CAL-02 | integration | `rcmdcheck::rcmdcheck()` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-schedule-print.R` — stubs for all CAL-01 and CAL-02 behaviors (new file; does not yet exist)

*Existing testthat infrastructure covers all other needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| R CMD CHECK passes 0 errors/0 warnings | CAL-01, CAL-02 | Build-time check, not runtime | Run `rcmdcheck::rcmdcheck(args = "--no-manual")` and confirm output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
