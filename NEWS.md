tidycreel 0.0.0.9000 (development)

- Survey-first refactor: Lean design constructors (`design_access`, `design_roving`, `design_busroute`) that validate and store inputs; estimation now relies on day-PSU designs from `as_day_svydesign()`.
- New effort estimators (survey-first): `est_effort.instantaneous`, `est_effort.progressive`, `est_effort.aerial`, and `est_effort.busroute_design` with design-based variance (supports `svydesign` and `svrepdesign`).
- Aerial enhancements: visibility/calibration adjustments; optional post-stratification and calibration via `survey`.
- Deprecations (breaking):
  - `estimate_effort()`, `estimate_cpue()`, `estimate_harvest()` now error with guidance to the new APIs.
  - `design_repweights()` and custom replicate-weight helpers removed; use `survey::as.svrepdesign()` on day-PSU designs.
- Vignettes:
  - Added “Survey Package to Creel: A Translator”.
  - Added “Replicate Designs for Creel Inference”.
  - Updated “Getting Started”, “Effort (Survey-First)”, and aerial examples to use `as_day_svydesign()` and new estimators.
- Docs/DevEx: Updated README, pkgdown navbar, and AGENTS.md conventions; modernized CI workflows (R CMD check, lintr, pkgdown).
