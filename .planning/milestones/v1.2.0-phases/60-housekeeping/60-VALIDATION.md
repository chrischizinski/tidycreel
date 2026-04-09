---
phase: 60
slug: housekeeping
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 60 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3 (devtools) |
| **Config file** | `tests/testthat.R` |
| **Quick run command** | `Rscript -e "devtools::test()"` |
| **Full suite command** | `Rscript -e "devtools::check()"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Inspect modified files directly (no test run required — no R code changes)
- **After every plan wave:** Run `Rscript -e "devtools::check()"` to confirm DESCRIPTION parses cleanly
- **Before `/gsd:verify-work`:** Full suite must be green + all three success criteria verified
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 60-01-01 | 01 | 1 | HOUSE-01 | smoke | `Rscript -e "stopifnot(packageVersion('tidycreel') == '1.1.0')"` | ✅ | ⬜ pending |
| 60-01-02 | 01 | 1 | HOUSE-02 | manual | Inspect NEWS.md; confirm `# tidycreel 1.1.0 (2026-04-02)` and `# tidycreel 1.0.0 (2026-03-31)` headers present | ✅ | ⬜ pending |
| 60-01-03 | 01 | 1 | HOUSE-03 | manual | Navigate to https://github.com/chrischizinski/tidycreel/discussions | external | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed — this phase contains no R code changes.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| NEWS.md has accurate versioned entries for v1.0.0 and v1.1.0 | HOUSE-02 | File content review; pkgdown rendering requires deploy to verify fully | Inspect `NEWS.md`; confirm correct headers, subsections, and bullet detail |
| GitHub Discussions tab is accessible | HOUSE-03 | External GitHub UI state; not automatable | Navigate to https://github.com/chrischizinski/tidycreel/discussions and confirm tab is live |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
