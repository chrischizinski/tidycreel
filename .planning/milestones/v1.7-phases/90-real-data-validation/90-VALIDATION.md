---
phase: 90
slug: real-data-validation
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-16
audited: 2026-05-16
---

# Phase 90 — Validation Strategy

> Reconstructed from SUMMARY.md artifacts during milestone audit (2026-05-16). No execution-time VALIDATION.md was created for this phase.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Standalone Rscript (no testthat) |
| **Config file** | N/A — self-contained script |
| **Quick run command** | `Rscript inst/validation/calamus-2016-validation.R` |
| **Full suite command** | `Rscript inst/validation/calamus-2016-validation.R` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript inst/validation/calamus-2016-validation.R`
- **After every plan wave:** Same command
- **Before `/gsd-verify-work`:** Script must exit 0 with `=== Overall: PASS ===`
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 90-01-01 | 01 | 1 | REAL-01 | — | N/A | integration | `Rscript inst/validation/calamus-2016-validation.R` | ✅ (exits 0) | ✅ green |
| 90-02-01 | 02 | 2 | REAL-01 | — | N/A | integration | `Rscript inst/validation/calamus-2016-validation.R` | ✅ (exits 0) | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `inst/extdata/calamus-2016/` — 6 CSV fixture files (interviews, counts, catch, harvest_lengths, release_lengths, reference-outputs)
- [x] `inst/validation/calamus-2016-validation.R` — 202-line standalone validation script; exits 0 with PASS

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Working directory must be package root | REAL-01 (robustness) | Script uses relative path `inst/extdata/calamus-2016`; no directory guard | Run from non-package-root directory and confirm error is interpretable |

---

## Validation Audit 2026-05-16

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 2 (all tasks) |
| Escalated to manual-only | 1 (working-directory robustness) |

Validation run: `effort_total [PASS] rel_error=0.000000`, `catch_total [PASS] rel_error=0.000000`, `harvest_total [PASS] rel_error=0.000000`. Overall: PASS (3/3 estimands within 0.1% tolerance).

---

## Validation Sign-Off

- [x] All tasks have automated verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-05-16 (reconstructed audit — all tasks green, 3/3 estimands pass reference comparison)
