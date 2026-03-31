---
phase: 45
slug: ice-fishing-survey-support
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 45 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat >= 3.0.0 (edition 3) |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `devtools::test(filter = "creel-design")` |
| **Full suite command** | `devtools::test()` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(filter = "creel-design")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 45-01-01 | 01 | 1 | ICE-01 | unit | `devtools::test(filter = "creel-design")` | ✅ | ⬜ pending |
| 45-01-02 | 01 | 1 | ICE-01 | unit | `devtools::test(filter = "creel-design")` | ✅ | ⬜ pending |
| 45-01-03 | 01 | 1 | ICE-02 | unit | `devtools::test(filter = "creel-design")` | ✅ | ⬜ pending |
| 45-02-01 | 02 | 1 | ICE-01 | unit | `devtools::test(filter = "estimate-effort")` | ✅ | ⬜ pending |
| 45-02-02 | 02 | 1 | ICE-03 | unit | `devtools::test(filter = "estimate-effort")` | ✅ | ⬜ pending |
| 45-02-03 | 02 | 1 | ICE-04 | unit | `devtools::test(filter = "add-interviews")` | ✅ | ⬜ pending |
| 45-02-04 | 02 | 2 | ICE-04 | unit | `devtools::test(filter = "estimate-catch-rate")` | ✅ | ⬜ pending |
| 45-02-05 | 02 | 2 | ICE-04 | unit | `devtools::test(filter = "estimate-total-catch")` | ✅ | ⬜ pending |
| 45-03-01 | 03 | 2 | ICE-01..04 | integration | `devtools::test()` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Tests for ICE-01 through ICE-04 will be appended to existing test files, not new files.

*No new test files or framework installation required.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Vignette renders without error | ICE-01..04 | knitr output requires human review | `devtools::build_vignettes()` + open HTML |
| `print.creel_design()` displays effort_type clearly | ICE-02 | Visual output check | `creel_design(survey_type="ice", effort_type="time_on_ice", ...)` → print |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
