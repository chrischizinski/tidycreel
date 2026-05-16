---
phase: 88
slug: httr2-hardening-and-api-fetch-methods
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-09
audited: 2026-05-16
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
| 88-01-01 | 01 | 1 | API-06 | req_error + req_retry | Non-2xx aborts with cli_abort; 429/503 retries ≤3× | unit | `devtools::test(pkg = "tidycreel.connect", filter = "api-fetch")` | ✅ (4 pass) | ✅ green |
| 88-02-01 | 02 | 2 | API-01 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-interviews")` | ✅ (33 pass) | ✅ green |
| 88-02-02 | 02 | 2 | API-02 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-counts")` | ✅ (15 pass) | ✅ green |
| 88-03-01 | 03 | 2 | API-03 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-catch")` | ✅ (21 pass) | ✅ green |
| 88-03-02 | 03 | 2 | API-04 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-lengths")` | ✅ (37 pass) | ✅ green |
| 88-03-03 | 03 | 2 | API-05 | — | N/A | unit | `devtools::test(pkg = "tidycreel.connect", filter = "fetch-lengths")` | ✅ (37 pass) | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tidycreel.connect/tests/testthat/test-api-fetch.R` — stubs covering API-06 (error handling, retry logic)
- [x] `tidycreel.connect/tests/testthat/helper-api.R` — `make_api_conn()` helper for constructing `creel_connection_api` test objects
- [x] API test blocks in `test-fetch-interviews.R`, `test-fetch-counts.R`, `test-fetch-catch.R`, `test-fetch-lengths.R` — cover API-01 through API-05

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| NGPC field names (ii_NumberAnglers, ii_TripType, Num, ii_TimeFishedHours/Minutes) | API-01, API-02 | Cannot verify without live API access | Phase 90 live-data validation against Calamus 2016 confirms these |

---

## Validation Audit 2026-05-16

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 6 (all tasks) |
| Escalated to manual-only | 1 (API-06 positive retry — architectural constraint) |

Full suite: `FAIL 0 | WARN 0 | SKIP 10 | PASS 142`

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-05-16 (audit pass — all tasks green, positive retry path in manual-only per architectural constraint)
