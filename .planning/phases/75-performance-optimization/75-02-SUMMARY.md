---
plan: 75-02
phase: 75-performance-optimization
status: complete
completed: 2026-04-19
---

# Plan 75-02: Performance Analysis Document — Summary

## What Was Built

`75-PERFORMANCE-ANALYSIS.md` (400+ lines) — empirical profiling findings and concrete Rcpp
go/no-go recommendation for tidycreel v1.3.0.

## Key Findings

- **Taylor path is fast:** estimate_total_catch() 1.47 ms realistic, 5.25 ms stress; estimate_effort() 1.44 ms realistic, 5.41 ms stress
- **Sub-linear scaling:** 10× more data → 3.6–3.8× more time (better than linear)
- **Variance methods:** jackknife 18× taylor, bootstrap 54× taylor — bootstrap cost is in survey::as.svrepdesign() (upstream, not addressable by Rcpp in tidycreel)
- **H1–H3:** Not bottlenecks; **H4:** Confirmed bottleneck but upstream; **H5:** Inconclusive (aerial not tested); **H6:** Bootstrap confirmed implemented

## Recommendation

**DEFER Rcpp.** No hot spot in tidycreel's own code clears the 10× speedup threshold. Top priority is O3 (expose n_boot parameter). cpp11 noted as the correct choice if C extension ever becomes warranted — R 4.5.0 enforces R_NO_REMAP for all C++ code, making Rcpp's legacy remapped names unavailable.

## Deviations

- Analysis document written using empirical data captured in this session (scripts run earlier) rather than re-running via subagent.
- C acceleration table updated twice after user flagged R 4.5.0 R_NO_REMAP enforcement (Writing R Extensions §6).

## Self-Check: PASSED

- [x] 75-PERFORMANCE-ANALYSIS.md exists (400+ lines, target 200+)
- [x] Actual bench::mark() timing numbers present (not placeholder)
- [x] H1–H6 all have verdicts with evidence
- [x] Go/No-Go section makes concrete recommendation citing 10× threshold
- [x] Rcpp vs cpp11 vs RcppArmadillo comparison table present
- [x] Bootstrap/Taylor ratio = 54.3× (empirical)
- [x] "Scheduling and Power Function Surface" section with static-analysis rationale
- [x] Cross-references 75-TESTING-INVARIANTS.md
- [x] Checkpoint approved by user
- [x] No changes to R/, tests/, DESCRIPTION (beyond Suggests), or NAMESPACE
