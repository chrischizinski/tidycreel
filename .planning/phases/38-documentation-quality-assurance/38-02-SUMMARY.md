---
phase: 38
plan: "02"
subsystem: documentation
tags: [vignette, flexible-count-estimation, progressive, multi-count, se_within, QA]
dependency_graph:
  requires: [38-01, 37-01, 36-02]
  provides: [flexible-count-estimation-vignette]
  affects:
    - vignettes/flexible-count-estimation.Rmd
tech_stack:
  added: []
  patterns: [rmarkdown-vignette]
key_files:
  created:
    - vignettes/flexible-count-estimation.Rmd
  modified: []
decisions:
  - "Pope et al. single-day example (C=234, T_d=8 -> 1872) demonstrated via design$counts slot (per-day Ê_d) rather than estimate_effort() total — survey package requires ≥2 PSUs per stratum for variance; 2-day design used, first-day value confirmed 1872"
  - "Coverage 86.54% noted as below 90% target; reflects new progressive-count code paths added in Phase 37 that lack dedicated coverage — pre-existing gap, not introduced by this plan"
metrics:
  duration: "12m"
  completed: "2026-03-09"
  tasks: 1
  files_changed: 1
requirements: [DOCS-04, DOCS-05, DOCS-06]
---

# Phase 38 Plan 02: Flexible Count Estimation Vignette Summary

New vignette `vignettes/flexible-count-estimation.Rmd` demonstrating all three v0.6.0 count workflows (instantaneous, multi-count with se_within, progressive) with inline data and Pope et al. worked example.

## What Was Built

### Task: Create flexible-count-estimation.Rmd

Created `vignettes/flexible-count-estimation.Rmd` with four executable code sections:

1. **Single Count per Day** — baseline instantaneous workflow, confirms `se_within = 0` for single-count PSUs
2. **Multiple Counts per Day** — am/pm circuits via `count_time_col`, demonstrates nonzero `se_within` and the Rasmussen two-stage decomposition
3. **Progressive Count Type** — `count_type = "progressive"`, `circuit_time = 2`, `period_length_col = shift_hours`; four-day survey producing Ê_d = count × T_d
4. **Pope et al. Worked Example** — reproduces C = 234, τ = 2h, T_d = 8h → Ê_d = 1,872 angler-hours via `design_pope$counts` (per-day expanded effort values)

Vignette also includes:
- LaTeX formula for progressive estimator
- `se_between` / `se_within` / `se` interpretation table
- Practical guidance on monitoring `se_within / se` ratio

## QA Gate Results

| Gate | Result | Notes |
|------|--------|-------|
| devtools::build_vignettes() | PASS | All 7 vignettes built |
| rmarkdown::render() standalone | PASS | Output created, Ê_d = 1,872 confirmed in design$counts |
| R CMD check | 0 errors, 0 warnings, 3 notes | 3 notes all pre-existing (hidden files, examples/, qt import) |
| lintr | 0 issues | Pre-commit hook: style-files + lintr both passed |
| covr::package_coverage() | 86.54% | Below 90% target; gap is pre-existing in Phase 37 progressive-count paths |
| testthat | 1,409 tests, 0 failures | |

## Requirements Satisfied

- **DOCS-04**: Count estimation vignette created covering all count types
- **DOCS-05**: Progressive count workflow documented with Pope et al. reference
- **DOCS-06**: Multi-count workflow documented with se_within explanation

## Deviations from Plan

### Plan Adjustment: Pope et al. Single-Day Example

The plan specified a single-day Pope example where `estimate_effort(design_pope)$estimates` should show estimate = 1,872. This is not possible because `survey::svytotal()` requires ≥ 2 PSUs per stratum for variance computation — a single-row design errors with "Stratum has only one PSU at stage 1".

**Fix:** Used a 2-day weekday design (C = 234 and C = 200) and demonstrated the Ê_d = 1,872 value via `design_pope$counts` — the `n_anglers` column stores the per-day expanded effort after `add_counts()` processes the progressive formula. The first row shows 1,872 angler-hours, confirming the Pope et al. calculation.

This approach is more instructive: it shows users exactly where tidycreel stores the intermediate per-day effort values.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 41cc051 | feat(38-02): add flexible-count-estimation vignette; final QA gates for v0.6.0 |

## Self-Check: PASSED
