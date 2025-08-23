tidycreel 0.0.0.9000 (development)

- Survey-first refactor: Estimation relies on day-PSU designs from `as_day_svydesign()` and interview-level `svydesign`; legacy constructors (`design_access`, `design_roving`, `design_repweights`) removed.
- New effort estimators (survey-first): `est_effort.instantaneous`, `est_effort.progressive`, `est_effort.aerial`, and `est_effort.busroute_design` with design-based variance (supports `svydesign` and `svrepdesign`).
- Aerial enhancements: visibility/calibration adjustments; optional post-stratification and calibration via `survey`.
- Deprecations (breaking):
  - `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()` now error with guidance to the new APIs.
  - Replicate-weight helpers removed; use `survey::as.svrepdesign()` on day-PSU designs when needed.
- Vignettes:
  - Added “Survey Package to Creel: A Translator”.
  - Added “Replicate Designs for Creel Inference”.
  - Updated “Getting Started”, “Effort (Survey-First)”, and aerial examples to use `as_day_svydesign()` and new estimators.
- Docs/DevEx: Updated README, pkgdown navbar, and AGENTS.md conventions; modernized CI workflows (R CMD check, lintr, pkgdown).

2025-08-22
- Added survey-first CPUE and Catch estimators: `est_cpue()` (ratio-of-means default; mean-of-ratios option) and `est_catch()` (totals via svytotal/svyby).
- Updated README and Getting Started vignette with CPUE/Catch examples; exported new functions; added minimal tests.
