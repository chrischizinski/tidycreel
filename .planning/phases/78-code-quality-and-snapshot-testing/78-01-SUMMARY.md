---
phase: 78-code-quality-and-snapshot-testing
plan: 01
subsystem: documentation
tags: [roxygen2, pkgdown, family-tags, Rd-files]

# Dependency graph
requires: []
provides:
  - "@family tags on all 111 user-facing exported functions across 40 R/ files"
  - "Regenerated man/*.Rd files with \\concept{} entries for all 9 family groups"
  - "pkgdown grouped reference sections enabled via @family metadata"
affects:
  - "pkgdown site build (reference page grouping)"
  - "any future plan adding new exported functions (must also add @family)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@family tag placement: immediately before @export in roxygen2 block"
    - "Dataset docs: @family tag on the line before the quoted dataset string"
    - "nolint: object_usage_linter for functions called inside private closures"
    - "nolint: indentation_linter for styler/lintr conflict in multiline if-conditions"

key-files:
  created: []
  modified:
    - R/creel-design.R
    - R/hybrid-design.R
    - R/creel-schema.R
    - R/est-effort-camera.R
    - R/prep-counts.R
    - R/prep-interviews.R
    - R/validate-schemas.R
    - R/creel-estimates.R
    - R/creel-estimates-aerial-glmm.R
    - R/creel-estimates-length.R
    - R/creel-estimates-total-catch.R
    - R/creel-estimates-total-harvest.R
    - R/creel-estimates-total-release.R
    - R/creel-summaries.R
    - R/season-summary.R
    - R/flag-outliers.R
    - R/write-estimates.R
    - R/validate-incomplete-trips.R
    - R/validate-creel-data.R
    - R/nonresponse-adjust.R
    - R/standardize-species.R
    - R/validation-report.R
    - R/compare-variance.R
    - R/design-validator.R
    - R/survey-bridge.R
    - R/power-sample-size.R
    - R/power-creel.R
    - R/compare-designs.R
    - R/schedule-generators.R
    - R/schedule-io.R
    - R/creel-estimates-utils.R
    - R/autoplot-methods.R
    - R/theme-creel.R
    - R/data.R
    - "man/*.Rd (92 files updated with \\concept{} entries)"

key-decisions:
  - "@family tag for autoplot.* methods: these ARE user-facing exports and DO receive @family tags (not skipped like print.*/format.*/as.data.frame.*)"
  - "summary.creel_estimates in creel-summaries.R (not creel-estimates.R) receives @family Reporting & Diagnostics"
  - "preprocess_camera_timestamps lives in creel-design.R (not survey-bridge.R) — @family Camera Survey added there"
  - "Pre-existing lintr/styler conflicts in compare-variance.R and power-creel.R fixed via nolint comments (Rule 1 auto-fix)"

patterns-established:
  - "9 authorised family labels match exact _pkgdown.yml reference section titles"
  - "print.*, format.*, as.data.frame.* never receive @family (appear in pkgdown internal section)"
  - "summary.creel_estimates is an exception: it IS user-facing in Reporting & Diagnostics"

requirements-completed:
  - CODE-01

# Metrics
duration: 45min
completed: 2026-04-21
---

# Phase 78 Plan 01: @family Tags for pkgdown Reference Grouping Summary

**@family tags added to 111 user-facing exports across 40 R/ source files using 9 exact _pkgdown.yml section labels; 92 man/*.Rd files regenerated with \\concept{} entries enabling grouped pkgdown reference pages**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-21T00:45:00Z
- **Completed:** 2026-04-21T01:31:02Z
- **Tasks:** 2
- **Files modified:** 134 (40 R/ source files + 92 man/*.Rd files + 2 misc pre-existing lint fixes)

## Accomplishments
- All 17 Survey Design exports tagged (creel_design, add_*, prep_*, compute_*, as_survey_design, as_hybrid_svydesign, est_effort_camera, creel_schema, validate_creel_schema)
- All 9 Estimation exports tagged (estimate_effort, estimate_effort_aerial_glmm, estimate_catch_rate, estimate_harvest_rate, estimate_release_rate, estimate_total_catch, estimate_total_harvest, estimate_total_release, est_length_distribution)
- All 23 Reporting & Diagnostics exports tagged (11 summarize_* functions, summary.creel_estimates, season_summary, flag_outliers, write_estimates, validate_incomplete_trips, validate_design, check_completeness, compare_variance, adjust_nonresponse, validate_creel_data, standardize_species, validation_report)
- All 6 Planning & Sample Size exports tagged (power_creel, creel_n_effort, creel_n_cpue, creel_power, cv_from_n, compare_designs)
- All 8 Scheduling exports tagged (generate_schedule, generate_bus_schedule, generate_count_times, attach_count_times, new_creel_schedule, validate_creel_schedule, read_schedule, write_schedule)
- All 4 Bus-Route Helpers tagged (get_enumeration_counts, get_inclusion_probs, get_sampling_frame, get_site_contributions)
- Camera Survey and Visualisation exports tagged (preprocess_camera_timestamps, plot_design, autoplot.* methods, theme_creel, creel_palette)
- All 18 Example Datasets in data.R tagged with Example Datasets family
- devtools::check_man() exits 0 with no issues; 92 Rd files have \concept{} entries
- Zero print.*/format.*/as.data.frame.* Rd files carry \concept{} entries

## Task Commits

Each task was committed atomically:

1. **Task 1: Add @family tags — Survey Design, Estimation, Reporting & Diagnostics** - `0735aa5` (feat)
2. **Task 2: Add @family tags — Planning & Sample Size, Scheduling, Bus-Route Helpers, Camera Survey, Visualisation, Example Datasets** - `f4bb52a` (feat)

## Files Created/Modified
- `R/creel-design.R` - 13 @family tags (Survey Design ×10, Bus-Route Helpers ×3, Camera Survey ×1, Reporting & Diagnostics ×1)
- `R/creel-summaries.R` - 11 @family tags (Reporting & Diagnostics)
- `R/data.R` - 18 @family tags (Example Datasets)
- All other 37 R/ source files - 1-4 @family tags each per the mapping
- `man/*.Rd` - 92 files updated with \concept{} entries

## Decisions Made
- autoplot.* methods receive @family Visualisation: plan explicitly notes these are user-facing exports, unlike print.*/format.*/as.data.frame.* methods
- summary.creel_estimates tagged Reporting & Diagnostics: plan explicitly marks this as the one summary.* exception
- preprocess_camera_timestamps found in creel-design.R (not survey-bridge.R): @family Camera Survey added there, no change to plan logic

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing lintr/styler conflict in compare-variance.R**
- **Found during:** Task 1 commit (pre-commit hook)
- **Issue:** `indentation_linter` flagged line 104; styler was reverting any manual fix back to 4-space indent, creating an unresolvable loop
- **Fix:** Added `# nolint: indentation_linter` to the conflicting line; added `# nolint: object_usage_linter` to three `suppressWarnings()` calls in `resolve_variance_estimator()`
- **Files modified:** R/compare-variance.R
- **Verification:** Pre-commit hooks passed; lintr Passed
- **Committed in:** 0735aa5 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed pre-existing object_usage_linter warnings in power-creel.R**
- **Found during:** Task 2 commit (pre-commit hook)
- **Issue:** Three private helper functions (`.power_creel_effort_n`, `.power_creel_cpue_n`, `.power_creel_power`) call `creel_n_effort`, `creel_n_cpue`, `creel_power` — lintr could not detect package-level function visibility inside private closures
- **Fix:** Added `# nolint: object_usage_linter` to the three function call lines
- **Files modified:** R/power-creel.R
- **Verification:** Pre-commit hooks passed; lintr Passed
- **Committed in:** f4bb52a (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 × Rule 1 pre-existing lint conflicts triggered by pre-commit hooks)
**Impact on plan:** Both fixes were necessary to commit. No scope creep. No behaviour change.

## Issues Encountered
- Pre-commit `style-files` hook reported "Failed" on first commit attempts when staged files had corresponding unstaged changes; resolved by staging all relevant files together before committing.

## Next Phase Readiness
- CODE-01 satisfied: all user-facing exports have @family tags matching the 9 authorised pkgdown section labels
- pkgdown reference pages can now be built with grouped sections
- Ready for Phase 78-02 (snapshot tests) or remaining Phase 78 plans

---
*Phase: 78-code-quality-and-snapshot-testing*
*Completed: 2026-04-21*
