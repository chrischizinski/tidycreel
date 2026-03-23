---
phase: 48
slug: schedule-generators
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-23
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `devtools::test(filter = "schedule")` |
| **Full suite command** | `devtools::test()` |
| **Estimated runtime** | ~30 seconds |

---

## Test File Layout

Two consolidated test files are created in Plan 01 Wave 0 and filled by subsequent plans:

| File | Plans | Requirements |
|------|-------|--------------|
| `tests/testthat/test-schedule-generators.R` | 01 (scaffold), 02 (activate SCHED-02) | SCHED-01, SCHED-02 |
| `tests/testthat/test-schedule-io.R` | 01 (scaffold), 03 (activate SCHED-03/04) | SCHED-03, SCHED-04 |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(filter = "schedule")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 0 | SCHED-01 | unit stub | `devtools::test(filter = "schedule-generators")` | ❌ W0 | ⬜ pending |
| 48-01-02 | 01 | 1 | SCHED-01 | unit | `devtools::test(filter = "schedule-generators")` | ❌ W0 | ⬜ pending |
| 48-02-01 | 02 | 2 | SCHED-02 | unit | `devtools::test(filter = "schedule-generators")` | ❌ W0 | ⬜ pending |
| 48-03-01 | 03 | 2 | SCHED-03, SCHED-04 | unit + integration | `devtools::test(filter = "schedule-io")` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-schedule-generators.R` — stubs for SCHED-01 and SCHED-02 (SCHED-02 tests skipped until Plan 02)
- [ ] `tests/testthat/test-schedule-io.R` — stubs for SCHED-03 and SCHED-04 (all skipped until Plan 03)
- [ ] `lubridate`, `writexl`, `readxl` added to DESCRIPTION (Imports/Suggests as appropriate)

Wave 0 is satisfied by Plan 01 Task 1. Both files must exist with skip() stubs before Plan 01 Task 2 begins.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| xlsx file opens correctly in Excel/LibreOffice | SCHED-03 | Cannot automate cross-app rendering | Open output file, verify date column displays as dates not serials |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
