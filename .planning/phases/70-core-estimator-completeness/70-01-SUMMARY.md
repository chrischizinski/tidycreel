---
phase: 70
plan: "01"
subsystem: creel-estimates
tags: [bus-route, ice, horvitz-thompson, harvest, release, estimators]
dependency_graph:
  requires: []
  provides:
    - estimate_total_harvest_br
    - estimate_total_release_br
    - ice dispatch in estimate_harvest_rate
  affects:
    - estimate_total_harvest
    - estimate_total_release
    - estimate_harvest_rate
tech_stack:
  added: []
  patterns:
    - intersect() guard for synthetic ice columns
    - HT dispatch before validate_design_compatibility()
    - estimate_release_build_data() reuse for bus-route release
key_files:
  created:
    - R/creel-estimates-bus-route.R (estimate_total_harvest_br, estimate_total_release_br)
    - tests/testthat/test-estimate-total-harvest-br.R
    - tests/testthat/test-estimate-total-release-br.R
  modified:
    - R/creel-estimates.R
    - R/creel-estimates-total-harvest.R
    - R/creel-estimates-total-release.R
    - tests/testthat/test-estimate-harvest-rate.R
    - vignettes/bus-route-surveys.Rmd
    - vignettes/ice-fishing.Rmd
    - vignettes/aerial-glmm.Rmd
decisions:
  - Dispatch bus_route and ice together in %in% c("bus_route", "ice") before validate_design_compatibility() in all three top-level estimators
  - estimate_total_harvest_br() filters to complete trips only (mirrors estimate_harvest_br() behavior)
  - estimate_total_release_br() reuses estimate_release_build_data() to join .release_count to interviews before HT expansion
  - intersect() guard applied consistently in all three new/fixed site_table constructions
metrics:
  duration: "~8 minutes"
  tasks_completed: 4
  files_changed: 11
  completed_date: "2026-04-15"
---

# Phase 70 Plan 01: Core Estimator Completeness — Bus-route, Aerial, Ice Summary

Ice designs now dispatch to the HT harvest-rate estimator; bus-route and ice have direct HT total-harvest and total-release estimators using `H_hat = sum(h_i * expansion / pi_i)`.

## What Was Built

### T01: Fix ice dispatch in estimate_harvest_rate()

Extended the bus-route dispatch condition in `estimate_harvest_rate()` from
`design$design_type == "bus_route"` to `design$design_type %in% c("bus_route", "ice")`.
Applied the `intersect()` guard to both the complete-trip and incomplete-trip
site_table constructions in `estimate_harvest_br()`, matching the existing pattern
in `estimate_total_catch_br()`.

### T02: Implement total-harvest and total-release HT estimators for bus-route/ice

Added two new functions to `R/creel-estimates-bus-route.R`:

- `estimate_total_harvest_br()`: computes `H_hat = sum(h_i * expansion / pi_i)`
  for complete-trip harvest counts. Uses `intersect()` guard for ice designs.
- `estimate_total_release_br()`: computes `R_hat = sum(r_i * expansion / pi_i)`
  for release counts joined via `estimate_release_build_data()`.

Added bus-route/ice dispatch blocks to `estimate_total_harvest()` and
`estimate_total_release()` before their `validate_design_compatibility()` calls.

### T03: Comprehensive test coverage

- `test-estimate-total-harvest-br.R`: 9 tests — bus_route dispatch, hand-computed
  H_hat verification (H = 135.833...), site_contributions, grouped by site/circuit,
  ice dispatch, ice hand-computed value (H = 11)
- `test-estimate-total-release-br.R`: 9 tests — bus_route R_hat verification
  (R = 48.333...), site_contributions, grouped by circuit, zero-release case,
  ice dispatch and ice R_hat check
- `test-estimate-harvest-rate.R`: added 4 ice-dispatch tests verifying ice designs
  route to the HT estimator with correct hand-computed values

All 149 targeted tests pass (`devtools::test(filter = "harvest-br|release-br|harvest-rate")`).

### T04: Update vignettes

- `vignettes/bus-route-surveys.Rmd`: Step 5 section demonstrating
  `estimate_total_harvest()` and `estimate_total_release()` with site contributions
- `vignettes/ice-fishing.Rmd`: Harvest Rate, Total Harvest, and Total Release
  sections with HT formula and example calls
- `vignettes/aerial-glmm.Rmd`: "Total Harvest via Product Estimator" section
  with manual delta-method workflow for GLMM effort + interview HPUE

Vignettes build successfully.

## Deviations from Plan

None — plan executed exactly as written.

## Commits

- `8b88c2f` — fix(70-01): dispatch ice designs to HT harvest-rate estimator
- `c885ee2` — feat(70-01): add HT total-harvest and total-release estimators for bus-route/ice
- `9c0f6da` — test(70-01): comprehensive test coverage for bus-route/ice HT estimators
- `0da6bbd` — docs(70-01): vignette sections for bus-route total harvest/release and ice estimators

## Self-Check: PASSED

All key files found. All 4 task commits verified in git log.
