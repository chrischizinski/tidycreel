---
phase: 64-glmm-aerial-estimator
plan: 01
subsystem: estimation
tags: [lme4, glmm, aerial, negbin, delta-method, bootstrap, tidycreel]

# Dependency graph
requires:
  - phase: 63.1-attach-count-times-to-daily-schedule
    provides: attach_count_times() helper; established time_col patterns
  - phase: 56-deployment
    provides: existing estimate_effort_aerial() simple estimator to build alongside

provides:
  - estimate_effort_aerial_glmm() public function (R/creel-estimates-aerial-glmm.R)
  - example_aerial_glmm_counts dataset (48 rows, 4 columns including time_of_flight)
  - Full TDD test suite covering GLMM-01, GLMM-02, GLMM-03

affects:
  - 64-02-PLAN (aerial-glmm vignette depends on this function and dataset)

# Tech tracking
tech-stack:
  added: [lme4 (Suggests)]
  patterns:
    - rlang::check_installed() guard for optional lme4 dependency
    - Numerical integration over diurnal curve via 100-point fixed-effects prediction grid
    - Delta method SE via grad = scale * h_over_v * colSums(mu * X); var = t(grad) V grad
    - lme4::bootMer() parametric bootstrap as alternative variance path
    - se_within = NA_real_ for GLMM estimators (no Rasmussen decomposition)

key-files:
  created:
    - data-raw/create_example_aerial_glmm_counts.R
    - data/example_aerial_glmm_counts.rda
    - R/creel-estimates-aerial-glmm.R
    - tests/testthat/test-estimate-effort-aerial-glmm.R
  modified:
    - R/data.R (added example_aerial_glmm_counts documentation block)
    - DESCRIPTION (added lme4 to Suggests)

key-decisions:
  - "lme4 added to Suggests (not Imports); rlang::check_installed() guard provides informative error when missing"
  - "Delta method integrates fixed-effect covariance only; se_within is NA because GLMM has no Rasmussen between/within decomposition"
  - "Prediction grid uses 100 points from min(time_of_flight)-0.5 to max(time_of_flight)+0.5 for numerical integration"
  - "Custom formula uses n_anglers (actual count column), not generic 'count' placeholder"
  - "Uppercase matrix variable names X and V replaced with x_mat and v_mat to satisfy object_name_linter"

patterns-established:
  - "GLMM estimator pattern: check_installed guard -> design_type guard -> enquo time_col -> glmer.nb fit -> integrate curve -> delta or bootstrap SE -> new_creel_estimates"
  - "se_within = NA_real_ is the canonical value for any estimator without Rasmussen decomposition"

requirements-completed: [GLMM-01, GLMM-02, GLMM-03]

# Metrics
duration: 15min
completed: 2026-04-05
---

# Phase 64 Plan 01: GLMM Aerial Estimator Summary

**GLMM-based aerial effort estimator using lme4::glmer.nb() with Askey (2018) quadratic diurnal correction, delta method and bootstrap SE, returning creel_estimates with se_within = NA**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-05T18:03:59Z
- **Completed:** 2026-04-05T18:19:00Z
- **Tasks:** 3 (TDD: dataset + RED + GREEN)
- **Files modified:** 6

## Accomplishments

- Created `example_aerial_glmm_counts` dataset (12 days x 4 flights = 48 rows) with diurnal count curve and day-level Poisson variability
- Implemented `estimate_effort_aerial_glmm()` with full Askey (2018) GLMM approach, delta method default, and `lme4::bootMer()` bootstrap option
- 14 test assertions across 10 tests all passing; full devtools::test() suite green (1928 PASS, 0 FAIL); devtools::check() 0 errors 0 warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Create example_aerial_glmm_counts dataset** - `ce03ccc` (feat)
2. **Task 2: Write test stubs (RED)** - `bbce61d` (test)
3. **Task 3: Implement estimate_effort_aerial_glmm() (GREEN)** - `dc6afc5` (feat)
4. **Auto-fix: Remove broken roxygen link** - `aee38f3` (fix)

_Note: TDD tasks have separate test (RED) and feat (GREEN) commits._

## Files Created/Modified

- `data-raw/create_example_aerial_glmm_counts.R` - Dataset generation script with diurnal curve and Poisson noise
- `data/example_aerial_glmm_counts.rda` - Compiled dataset (48 rows, 4 columns)
- `R/data.R` - Added documentation block for example_aerial_glmm_counts
- `R/creel-estimates-aerial-glmm.R` - Public estimate_effort_aerial_glmm() function
- `tests/testthat/test-estimate-effort-aerial-glmm.R` - 10 tests covering GLMM-01/02/03
- `DESCRIPTION` - Added lme4 to Suggests (alphabetical order)

## Decisions Made

- lme4 placed in Suggests (not Imports) consistent with readxl/writexl/knitr pattern; rlang::check_installed() gives informative install instructions when missing
- Delta method SE propagates only fixed-effect covariance (lme4::vcov()); se_within = NA_real_ because no Rasmussen between/within decomposition exists for GLMM
- 100-point prediction grid integrates from min(time_of_flight)-0.5 to max(time_of_flight)+0.5 for diurnal curve area
- Bootstrap uses parametric resampling (lme4::bootMer type="parametric", use.u=FALSE) per Askey (2018) recommendation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed custom formula test using wrong column name**
- **Found during:** Task 3 (GREEN phase verification)
- **Issue:** Test used `count ~ time_of_flight + (1|date)` but the actual count column is `n_anglers`; test failed with "object 'count' not found"
- **Fix:** Updated test to use `n_anglers ~ time_of_flight + (1|date)`
- **Files modified:** `tests/testthat/test-estimate-effort-aerial-glmm.R`
- **Verification:** All 14 assertions pass after fix
- **Committed in:** dc6afc5 (Task 3 commit)

**2. [Rule 1 - Bug] Fixed uppercase variable names failing lintr object_name_linter**
- **Found during:** Task 3 commit (pre-commit hook)
- **Issue:** Matrix variables `X` and `V` violated snake_case naming convention
- **Fix:** Renamed to `x_mat` and `v_mat` throughout function
- **Files modified:** `R/creel-estimates-aerial-glmm.R`
- **Verification:** lintr clean, tests still pass
- **Committed in:** dc6afc5 (Task 3 commit)

**3. [Rule 1 - Bug] Removed unresolvable roxygen link to internal function**
- **Found during:** devtools::check() overall verification
- **Issue:** `[new_creel_estimates()]` in @return generated "Missing link" WARNING in R CMD check because new_creel_estimates is @noRd and not exported
- **Fix:** Replaced with plain text "A `creel_estimates` object with:"
- **Files modified:** `R/creel-estimates-aerial-glmm.R`
- **Verification:** devtools::check() reports 0 errors, 0 warnings
- **Committed in:** aee38f3

---

**Total deviations:** 3 auto-fixed (all Rule 1 bugs)
**Impact on plan:** All fixes necessary for correctness and passing R CMD check. No scope creep.

## Issues Encountered

None beyond the three auto-fixed deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `estimate_effort_aerial_glmm()` is fully functional and exported; lme4 in Suggests
- `example_aerial_glmm_counts` dataset available for vignette
- Plan 02 (aerial-glmm vignette) can proceed immediately; both dataset and estimator are ready
- No blockers

## Self-Check: PASSED

All created files verified on disk. All task commits confirmed in git log.

---
*Phase: 64-glmm-aerial-estimator*
*Completed: 2026-04-05*
