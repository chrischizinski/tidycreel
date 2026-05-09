---
phase: 88
slug: httr2-hardening-and-api-fetch-methods
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-09
---

# Phase 88 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.3.2 |
| **Config file** | `tidycreel.connect/DESCRIPTION` — `Config/testthat/edition: 3` |
| **Quick run command** | `devtools::test(pkg = "tidycreel.connect", filter = "api")` |
| **Full suite command** | `devtools::test(pkg = "tidycreel.connect")` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `devtools::test(pkg = "tidycreel.connect", filter = "api")`
- **After every plan wave:** Run `devtools::test(pkg = "tidycreel.connect")`
- **Before `/gsd-verify-work`:** Full suite must be green + `rcmdcheck::rcmdcheck("tidycreel.connect", args = "--no-manual")` with 0 errors, 0 warnings
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 88-01-01 | 01 | 1 | API-06 | req_error + req_retry | Non-2xx aborts with cli_abort; 429/503 retries ≤3× | unit | `devtools::test(pkg = "tidycreel.connect", filter = "api-fetch")` | ❌ W0 | ⬜ pending |
| 88-02-01 | 02 | 2 | API-01 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-interviews")` | ❌ W0 | ⬜ pending |
| 88-02-02 | 02 | 2 | API-02 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-counts")` | ❌ W0 | ⬜ pending |
| 88-03-01 | 03 | 2 | API-03 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-catch")` | ❌ W0 | ⬜ pending |
| 88-03-02 | 03 | 2 | API-04 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-lengths")` | ❌ W0 | ⬜ pending |
| 88-03-03 | 03 | 2 | API-05 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-lengths")` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tidycreel.connect/tests/testthat/test-api-fetch.R` — stubs covering API-06 (error handling, retry logic)
- [ ] `tidycreel.connect/tests/testthat/helper-api.R` — `make_api_conn()` helper for constructing `creel_connection_api` test objects
- [ ] API test blocks in `test-fetch-interviews.R`, `test-fetch-counts.R`, `test-fetch-catch.R`, `test-fetch-lengths.R` — cover API-01 through API-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| NGPC field names (ii_NumberAnglers, ii_TripType, Num, ii_TimeFishedHours/Minutes) | API-01, API-02 | Cannot verify without live API access | Phase 90 live-data validation against Calamus 2016 confirms these |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
