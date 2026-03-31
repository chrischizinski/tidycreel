---
plan: 48-02
phase: 48-schedule-generators
status: complete
completed: 2026-03-23
tasks-completed: 1/1
duration-minutes: 87
files-created: 1
files-modified: 3
commits: 2
subsystem: schedule-generators
tags: [bus-route, sampling-frame, inclusion-prob, tdd]
dependency-graph:
  requires: [48-01]
  provides: [generate_bus_schedule]
  affects: [creel_design, bus_route]
tech-stack:
  patterns: [rlang-enquo-resolve_single_col, tidy-selector, tapply-validation]
key-files:
  created:
    - man/generate_bus_schedule.Rd
  modified:
    - R/schedule-generators.R
    - tests/testthat/test-schedule-generators.R
    - NAMESPACE
decisions:
  - "Output tibble includes both p_period and inclusion_prob columns so callers can pass p_period=p_period to creel_design() directly"
  - "p_period validation (crew > n_circuits) is left to creel_design(); generate_bus_schedule() only validates p_site sum-to-1.0"
  - "site_col resolution is purely for validation (column existence check); suppress object_usage_linter with nolint comment"
requirements: [SCHED-02]
---

# Phase 48 Plan 02: generate_bus_schedule() Summary

## What Was Built

Implemented `generate_bus_schedule()` — the function that converts a `creel_schedule` calendar plus circuit definitions into a sampling frame tibble with `inclusion_prob` and `p_period` columns ready for `creel_design(survey_type = "bus_route")`.

One-liner: Bus-route sampling frame generator with `p_site` sum-to-1.0 validation and `inclusion_prob = p_site * (crew / n_circuits)` formula.

## Key Files

### Created
- `man/generate_bus_schedule.Rd` — auto-generated roxygen2 documentation

### Modified
- `R/schedule-generators.R` — `generate_bus_schedule()` added after `generate_schedule()`
- `tests/testthat/test-schedule-generators.R` — SCHED-02 stubs replaced with 11 real tests
- `NAMESPACE` — `export(generate_bus_schedule)` added

## Test Results

- SCHED-01: 27/27 pass (no regression)
- SCHED-02: 11/11 pass (newly activated)
- Full suite: FAIL 0 | WARN 463 | SKIP 1 | PASS 1762

## Decisions Made

1. **Output includes `p_period` column**: `creel_design(survey_type='bus_route')` requires a `p_period` argument (column or scalar). Adding `p_period` to the output tibble lets callers write `creel_design(..., p_period = p_period)` directly without computing the value separately.

2. **`crew > n_circuits` deferred to `creel_design()`**: If `crew / n_circuits > 1`, the resulting `p_period` exceeds 1.0 and `creel_design()` will fire its own validation error with a clear message. No pre-validation needed in `generate_bus_schedule()`.

3. **`site_col` nolint pattern**: `resolve_single_col()` called for site validates column existence but the resolved name is not used further — same pattern as other internal callers in `creel-design.R`. Suppressed `object_usage_linter` with inline nolint comment.

## Deviations from Plan

None — plan executed exactly as written.

## Enables

Plan 48-04 (if any integration tests require end-to-end schedule → design → estimation), and the Phase 48 completion check (all four SCHED requirements implemented across Plans 01-03).
