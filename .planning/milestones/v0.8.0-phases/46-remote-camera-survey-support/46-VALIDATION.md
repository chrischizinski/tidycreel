---
phase: 46
slug: remote-camera-survey-support
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-15
---

# Phase 46 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `devtools::test(filter = "camera")` |
| **Full suite command** | `devtools::test()` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(filter = "camera")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 46-01-01 | 01 | 1 | CAM-01 | unit | `devtools::test(filter = "camera")` | ❌ W0 | ⬜ pending |
| 46-01-02 | 01 | 1 | CAM-02 | unit | `devtools::test(filter = "camera")` | ❌ W0 | ⬜ pending |
| 46-01-03 | 01 | 1 | CAM-03 | unit | `devtools::test(filter = "camera")` | ❌ W0 | ⬜ pending |
| 46-02-01 | 02 | 2 | CAM-04 | unit | `devtools::test(filter = "camera")` | ❌ W0 | ⬜ pending |
| 46-02-02 | 02 | 2 | CAM-04 | integration | `devtools::test(filter = "camera")` | ❌ W0 | ⬜ pending |
| 46-03-01 | 03 | 3 | CAM-05 | integration | `devtools::test()` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Plans 46-01 and 46-02 append new test blocks to five existing test files. Wave 0 confirms those files exist and have the correct filter-match for the camera filter.

- [ ] `tests/testthat/test-creel-design.R` — receives new CAM-01, CAM-02, CAM-03 constructor and preprocessing blocks (Plan 46-01)
- [ ] `tests/testthat/test-estimate-effort.R` — receives new CAM-01, CAM-02, CAM-03 effort dispatch blocks (Plan 46-01)
- [ ] `tests/testthat/test-add-interviews.R` — receives new CAM-04 add_interviews() block (Plan 46-02)
- [ ] `tests/testthat/test-estimate-catch-rate.R` — receives new CAM-04 estimate_catch_rate() block (Plan 46-02)
- [ ] `tests/testthat/test-estimate-total-catch.R` — receives new CAM-04 estimate_total_catch() block (Plan 46-02)

*All five files already exist. Wave 0 for each plan is appending the new describe blocks — no new test files need to be created.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `R CMD check` passes with new example datasets | CAM-05 | Package build check not automatable in test suite | Run `devtools::check()` and confirm 0 errors, 0 warnings |
| Vignette renders without errors | CAM-05 | Vignette rendering requires full build environment | Run `devtools::build_vignettes()` and inspect output |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
