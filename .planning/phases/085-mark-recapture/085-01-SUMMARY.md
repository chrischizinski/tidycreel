---
phase: 085-mark-recapture
plan: "01"
status: complete
completed: 2026-05-04
---

## Summary

Implemented `estimate_angler_n()` and `estimate_mr_harvest()` in `R/creel-estimates-mark-recapture.R`. Both functions exported via NAMESPACE and registered in `_pkgdown.yml` Estimation section. `devtools::document()` completed without error.

## What Was Built

- **`estimate_angler_n()`** — Chapman (default), Petersen, and Schnabel closed-population estimators returning `creel_estimates` S3 objects with `parameter = "N_hat"`. Includes all input guards: m=0, m>n, m>M, Petersen m<7, Schnabel K<2, unequal vector lengths.
- **`estimate_mr_harvest()`** — Delta-method harvest estimator (`H = N_hat × rate`; `SE = rate × se_N`) that accepts a `creel_estimates` object from `estimate_angler_n()` and a known harvest rate.
- **NAMESPACE** — exports `estimate_angler_n` and `estimate_mr_harvest` via roxygen2.
- **man/** — `estimate_angler_n.Rd` and `estimate_mr_harvest.Rd` generated.
- **`_pkgdown.yml`** — Both functions added to Estimation section after `estimate_exploitation_rate`.

## Key Files Created

- `R/creel-estimates-mark-recapture.R` (307 lines)
- `man/estimate_angler_n.Rd`
- `man/estimate_mr_harvest.Rd`

## Deviations

None. Implementation follows the exploitation-rate file structure exactly.

## Self-Check: PASSED

- `R/creel-estimates-mark-recapture.R` exists with both functions (307 lines, ≥120 required)
- `NAMESPACE` contains `export(estimate_angler_n)` and `export(estimate_mr_harvest)`
- `man/estimate_angler_n.Rd` and `man/estimate_mr_harvest.Rd` exist
- `_pkgdown.yml` contains both functions after `estimate_exploitation_rate`
- All three method variants implemented: chapman, petersen, schnabel
- All guards implemented: m=0, m>n, m>M, petersen m<7, schnabel K<2, unequal lengths
- `devtools::document()` completed without error
