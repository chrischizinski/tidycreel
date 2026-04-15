---
phase: 71-future-analytical-needs
plan: 01
subsystem: planning
tags: [research, multi-species, spatial, temporal, mark-recapture, HT-estimator, survey-package]

# Dependency graph
requires: []
provides:
  - "Combined analytical extensions research document covering current state plus four extension areas for tidycreel v1.4+ planning"
  - "Gap analysis identifying missing: cross-species joint covariance, area-weighted lake-wide estimator, temporal models for non-aerial survey types, and all mark-recapture capabilities"
  - "Build-vs-wrap assessments for every extension with explicit package recommendations"
  - "Eight open questions documented for future roadmap review"
affects: [72-architectural-review, 73-error-handling, 74-quality-bar, 75-performance, future-v1.4-planning]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Research-first planning: produce document artifact with gap analysis and build-vs-wrap table before any implementation commitment"

key-files:
  created:
    - .planning/phases/71-future-analytical-needs/71-ANALYTICAL-EXTENSIONS-RESEARCH.md
  modified: []

key-decisions:
  - "All build-vs-wrap assessments in research document are non-binding — no implementation commitments made"
  - "Multi-species joint variance should prototype before interface is finalized (bus-route HT covariance path unverified)"
  - "Mark-recapture scoped to v1.5+ milestone; FSA for closed-population wrap, marked (verify POPAN) for CJS, exploitation rate estimator is genuine build candidate"
  - "Spatial section-area-weighted estimator: wrap survey::postStratify(); user provides weight column; handle missing area_ha with cli_abort"
  - "Temporal: generalise aerial GLMM path to non-aerial survey types using lme4 (already available)"

patterns-established:
  - "Planning artifact tone: statistically rigorous + biologist-accessible; all formulas explained in plain language"

requirements-completed: []

# Metrics
duration: 15min
completed: 2026-04-15
---

# Phase 71 Plan 01: Analytical Extensions Research Summary

**479-line combined research document covering gap analysis and build-vs-wrap assessments for multi-species joint estimation, spatial stratification, temporal modelling, and mark-recapture extensions to tidycreel**

## Performance

- **Duration:** ~15 min (continuation after human review)
- **Started:** 2026-04-15T18:00:00Z (estimated — Task 1 commit 1653931)
- **Completed:** 2026-04-15T18:34:01Z
- **Tasks:** 2 (1 auto, 1 human-verify checkpoint)
- **Files modified:** 1

## Accomplishments

- Produced `.planning/phases/71-future-analytical-needs/71-ANALYTICAL-EXTENSIONS-RESEARCH.md` (479 lines, 6 sections) covering all four extension areas with statistical depth and biologist-accessible explanations
- Identified and documented all analytical gaps in current tidycreel capabilities: missing cross-species covariance, no section-area-weighted lake total, no temporal models for bus-route/instantaneous, no mark-recapture code anywhere in the package
- Established explicit build-vs-wrap recommendations for every extension area with 8 open questions preserved for the future roadmap review session
- Passed human review checkpoint with all 9 checklist items confirmed

## Task Commits

1. **Task 1: Write combined analytical extensions research document** - `1653931` (docs)
2. **Task 2: Human review checkpoint** - approved, no commit required

**Plan metadata:** pending (this SUMMARY commit)

## Files Created/Modified

- `.planning/phases/71-future-analytical-needs/71-ANALYTICAL-EXTENSIONS-RESEARCH.md` — 479-line combined research document: Current State baseline, Multi-species joint estimation, Spatial stratification, Temporal modelling + Mark-recapture, Build-vs-wrap summary table, Open questions, References

## Key Findings Per Section

**Section 1 — Current State:** tidycreel today loops over species individually (`estimate_cpue_species()`, `estimate_total_harvest_species()`), producing no cross-species covariance. `estimate_catch_rate_sections()` estimates per section but never produces an area-weighted lake total. Temporal modelling exists only for aerial GLMM (Askey 2018). No mark-recapture code exists anywhere.

**Section 2 — Multi-species joint estimation:** `Var(T_1+T_2) = Var(T_1) + Var(T_2) + 2·Cov(T_1,T_2)` — the covariance term is the gap. `survey::svytotal(~sp1+sp2, design)` computes it from influence functions at no new dependency cost. Interface sketch (non-binding): `estimate_total_harvest(design, species=c("walleye","perch"), joint_variance=TRUE)`. Bus-route HT covariance path requires prototype before committing to interface.

**Section 3 — Spatial stratification:** Gap: no `T_lake = sum_s(w_s · T_s)` estimator. Two weighting schemes: area-weighting (`area_ha`) vs. effort-proportional (observed angler-hours). Build-vs-wrap: wrap `survey::postStratify()` with an area-weight computation helper. `add_sections()` already stores `area_ha`; handle missing values with `cli_abort`.

**Section 4a — Temporal modelling:** Three gaps: (1) day-level autocorrelation in bus-route/instantaneous effort ignored (random day effects or AR(1) via lme4); (2) no cross-year panel/trend model (van Poorten & Lemp 2025 framework); (3) aerial GLMM path does not generalise to other survey types. Build path: extend existing aerial GLMM code; lme4 already available.

**Section 4b — Mark-recapture:** Two creel integration modes: Hansen et al. 2018 (angler effort via mark-at-launch / recapture-at-takeout) and Saha/Pollock (exploitation rate from tagged fish + creel records). Estimator families covered: Petersen/Chapman, Schnabel, Jolly-Seber, CJS/POPAN, Robust Design. Package table: FSA (closed-pop wrap, pure R), marked (portable CJS, verify POPAN), RMark (full power, requires MARK.EXE). Exploitation rate estimator has no clean existing wrapper — genuine build candidate.

**Section 5 — Build-vs-wrap summary table:** All six extensions assessed. Three wraps (multi-species, spatial, closed-pop MR), two extensions of existing code (temporal, open-pop MR), one genuine build (exploitation rate estimator).

## Open Questions Documented

Eight open questions preserved for roadmap review:

1. Cross-species covariance under bus-route HT — prototype needed before interface commitment
2. When is joint variance not meaningful (non-co-targeted species)?
3. Area weighting vs. effort-proportional weighting — fishery-specific decision
4. Handling missing `area_ha` in section-weighted estimator
5. AR(1) vs. random day effects — data volume threshold (10–30 days/season)
6. Van Poorten & Lemp 2025 — exact model specification needs paper access
7. `marked` package POPAN coverage — verify before recommending as primary CJS target
8. Exploitation rate estimator full formulation — Saha thesis needed for statistical detail

## Decisions Made

- Document is purely a planning artifact; no design decisions or implementation commitments were made
- All interface sketches are explicitly marked "(non-binding)" in the document
- Mark-recapture scoped to v1.5+ milestone but received full research depth
- No new roadmap phases, phase stubs, or implementation timelines created

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Human Review Outcome

Task 2 checkpoint approved. All 9 checklist items confirmed:
- Section 1 accurately describes `estimate_cpue_species()` loop pattern and absence of mark-recapture
- Section 2 includes `Var(T_1+T_2) = Var(T_1) + Var(T_2) + 2·Cov(T_1,T_2)` formula and non-binding sketches with `joint_variance = TRUE`
- Section 3 explains both weighting approaches and identifies `survey::postStratify()` as the tool
- Section 4a covers autocorrelation gap and van Poorten & Lemp 2025 panel framework
- Section 4b covers all five estimator families and both creel integration modes
- Section 5 build-vs-wrap table covers all extensions with recommendations
- Document is accessible to a biologist — statistical concepts defined and explained
- No roadmap stubs, new phase entries, or prescriptive decisions present

## Next Phase Readiness

- Research document complete and approved; ready for use in any future roadmap review session
- Phases 72–75 (architectural review, error handling, quality bar, performance) are independent and can proceed in any order
- Open questions in Section 6 are the natural agenda for a future v1.4 planning session

---
*Phase: 71-future-analytical-needs*
*Completed: 2026-04-15*
