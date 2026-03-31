---
phase: 40-interview-based-rate-estimators
plan: 02
subsystem: estimation
tags: [section-dispatch, cpue, hpue, rpue, survey, tidycreel]

requires:
  - phase: 40-01
    provides: estimate_catch_rate(), estimate_harvest_rate(), estimate_release_rate() public API
  - phase: 39-01
    provides: add_sections() infrastructure, design$sections and design$section_col slots
  - phase: 39-03
    provides: estimate_effort_sections() pattern, rebuild_interview_survey() helper

provides:
  - estimate_catch_rate_sections() internal helper — per-section CPUE via rebuild_interview_survey() + estimate_cpue_total/grouped/species
  - estimate_harvest_rate_sections() internal helper — per-section HPUE via rebuild_interview_survey() + estimate_harvest_total/grouped
  - estimate_release_rate_sections() internal helper — per-section RPUE via rebuild_interview_survey() + estimate_release_build_data + estimate_cpue_total/grouped
  - missing_sections= parameter on all three public rate functions ("warn"/"error")
  - Section dispatch guard in estimate_catch_rate(), estimate_harvest_rate(), estimate_release_rate()
  - Test fixtures make_3section_design_with_interviews() and make_section_design_with_missing_interview_section() in test-estimate-catch-rate.R
  - RATE-01c, RATE-02a, RATE-02b, RATE-03 requirements all satisfied

affects:
  - Phase 41 (product estimators) — section rate estimates feed into TC_i = E_i * CPUE_i product
  - Phase 42 (vignette) — documents per-section rate workflow
  - Future: species + section dispatch (v0.8.0, deferred)

tech-stack:
  added: []
  patterns:
    - Section dispatch guard fires AFTER trip-status filtering, BEFORE standard MOR/ROM dispatch — ensures post-filtered design reaches section helpers
    - Per-section svydesign built via rebuild_interview_survey(design, filtered_interviews) — NOT subset(design$interview_survey, ...) to preserve correct PSU denominator variance
    - resolve_species_by() called ONCE before section loop to avoid repeated NSE resolution
    - NA row schema for missing sections (no se_between/se_within columns — interview survey has no within-day decomposition)
    - nolint: object_length_linter on all three section helper definition lines (32 chars each for harvest/release variants)
    - nolint: object_usage_linter on n_absent in cli_warn NSE string interpolation

key-files:
  created: []
  modified:
    - R/creel-estimates.R
    - man/estimate_catch_rate.Rd
    - man/estimate_harvest_rate.Rd
    - man/estimate_release_rate.Rd
    - tests/testthat/test-estimate-catch-rate.R
    - tests/testthat/test-estimate-harvest-rate.R
    - tests/testthat/test-estimate-species.R

key-decisions:
  - "No .lake_total row produced by rate section helpers — rates not additive (CPUE, HPUE, RPUE are ratios, not sums)"
  - "No species + section dispatch for harvest/release in v0.7.0 — deferred to v0.8.0 per locked CONTEXT.md decision"
  - "Fixtures duplicated into each test file (not shared helper file) — simpler than maintaining a helper-*.R file for these specialized fixtures"
  - "estimate_catch_rate_sections = 30 chars (borderline, suppressed); harvest/release variants = 32 chars (suppressed per project convention)"
  - "Section dispatch guard uses design[['sections']] double-bracket to avoid R partial-match ambiguity"

patterns-established:
  - "Rate section helpers follow estimate_effort_sections() pattern: detect sections, handle absent, loop, bind_rows"
  - "Test stubs use withCallingHandlers(invokeRestart('muffleWarning')) pattern to capture cli_warn() before suppressWarnings() swallows it"

requirements-completed: [RATE-01, RATE-02, RATE-03]

duration: 45min
completed: 2026-03-11
---

# Phase 40 Plan 02: Section Dispatch for Rate Estimators Summary

**Per-section CPUE/HPUE/RPUE dispatch added to all three public rate estimators using rebuild_interview_survey() + leaf helpers; missing_sections='warn'/'error' guard matches effort estimator API**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-03-11T17:20:00Z
- **Completed:** 2026-03-11T18:05:00Z
- **Tasks:** 2 (TDD RED + GREEN)
- **Files modified:** 7

## Accomplishments

- Three new section dispatch helpers (estimate_catch_rate_sections, estimate_harvest_rate_sections, estimate_release_rate_sections) appended to R/creel-estimates.R
- Section dispatch guards wired into all three public functions after trip-status filtering block
- Test fixtures make_3section_design_with_interviews() and make_section_design_with_missing_interview_section() created in test-estimate-catch-rate.R; duplicated to other test files for self-contained testing
- All 8 RED stubs turned GREEN; 1481 total tests pass, 0 failures, 0 errors
- R CMD check: 0 errors, 0 warnings; lintr: 0 issues

## Task Commits

1. **Task 1: Add section test fixtures and failing stubs** - `707eb3d` (test)
2. **Task 2: Implement section dispatch helpers and wire in** - `1edcde1` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `R/creel-estimates.R` — Added missing_sections= param to 3 public functions; 3 section dispatch guards; 3 section dispatch helper functions (~300 lines added)
- `man/estimate_catch_rate.Rd` — Regenerated with missing_sections @param and @note
- `man/estimate_harvest_rate.Rd` — Regenerated with missing_sections @param and @note
- `man/estimate_release_rate.Rd` — Regenerated with missing_sections @param and @note
- `tests/testthat/test-estimate-catch-rate.R` — Added 2 section fixtures + 5 section dispatch test stubs (RATE-01c, RATE-03)
- `tests/testthat/test-estimate-harvest-rate.R` — Added 2 duplicated fixtures + 2 section stubs (RATE-02a, RATE-03-harvest)
- `tests/testthat/test-estimate-species.R` — Added 2 section fixtures with catch data + 2 section stubs (RATE-02b, RATE-03-release)

## Decisions Made

- No .lake_total row from rate section helpers — rates (fish/angler-hour) are not additive; lake total requires a separate unsectioned call. Enforced by design.
- Species + section dispatch deferred to v0.8.0 for harvest and release rate functions. Catch rate supports species + section via existing estimate_cpue_species() leaf helper.
- Fixtures duplicated across test files rather than using a shared helper-*.R, consistent with existing project pattern.
- Function names use # nolint: object_length_linter per project convention (same as estimate_effort_sections and make_design_with_extended_interviews).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Indentation linter flagged hanging-indent on all three section helper definition lines (extra space). Fixed by removing one space from continuation lines. Caught by pre-commit hook.
- `# nolint: object_usage_linter` needed on add_interviews() parameter lines within test fixture functions (tidy-select args appear as unbound globals to lintr). Applied per project convention.

## Next Phase Readiness

- Phase 40 complete — estimate_catch_rate(), estimate_harvest_rate(), estimate_release_rate() all fully section-aware
- Phase 41 (product estimators: estimate_total_catch, estimate_total_harvest, estimate_total_release with section dispatch) can begin
- RATE-01, RATE-02, RATE-03 requirements all satisfied

---
*Phase: 40-interview-based-rate-estimators*
*Completed: 2026-03-11*
