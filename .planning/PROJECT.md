# tidycreel v2 — Domain Translation for Creel Survey Analysis

## What This Is

A ground-up redesign of tidycreel as a domain-translator R package for creel survey analysis, built on the R `survey` package foundation. Provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally. Supports production reporting, iterative refinement, and exploratory analysis workflows.

## Core Value

Creel biologists can analyze survey data using creel vocabulary without ever understanding survey package internals (PSUs, FPCs, calibration weights) — while power users can access underlying survey objects when needed for advanced work.

## Current Milestone: v0.3.0 Incomplete Trips & Validation

**Goal:** Enable scientifically valid incomplete trip estimation with complete trip focus, following Colorado C-SAP best practices and Pollock et al. roving-access design principles.

**Target features:**
- Trip completion status tracking (complete vs. incomplete interviews)
- Mean-of-ratios estimator for incomplete trips with configurable truncation threshold
- Overnight trip duration calculation (time spans across multiple days)
- Diagnostic validation framework (test if incomplete ≈ complete estimates)
- Default to complete trips only for catch rate (roving-access design, Colorado C-SAP)
- Sample size warnings when < 10% of interviews are complete trips (per Colorado C-SAP guidance)
- Clear documentation on when to use complete vs. incomplete trip approaches
- No auto-pooling of complete + incomplete (scientifically invalid per Pollock et al.)

## Requirements

### Validated

**v0.1.0 - Foundation (Instantaneous Counts)** — Shipped 2026-02-09
- ✓ Package structure with lintr, testthat, CI/CD configured — v0.1.0
- ✓ `creel_design()` constructor with tidy selectors for column specification — v0.1.0
- ✓ `add_counts()` for instantaneous count data — v0.1.0
- ✓ `estimate_effort()` returning estimates with SE and CI — v0.1.0
- ✓ Progressive validation (Tier 1: design creation, Tier 2: estimation warnings) — v0.1.0
- ✓ Grouped estimation with `by = ` parameter — v0.1.0
- ✓ Variance method control (Taylor, bootstrap, jackknife) — v0.1.0
- ✓ Internal survey design construction (day-PSU, stratified) — v0.1.0
- ✓ Reference tests proving estimates match manual survey package calculations — v0.1.0
- ✓ Getting Started vignette with example workflow — v0.1.0

**v0.2.0 - Interview-Based Estimation** — Shipped 2026-02-11
- ✓ Interview data attachment to existing creel_design object (add_interviews) — v0.2.0
- ✓ CPUE estimation (catch per unit effort) with ratio-of-means estimator — v0.2.0
- ✓ Harvest estimation (HPUE) distinguishing caught vs kept fish — v0.2.0
- ✓ Total catch estimation (effort × CPUE) with delta method variance — v0.2.0
- ✓ Total harvest estimation (effort × HPUE) with delta method variance — v0.2.0
- ✓ Grouped estimation support for CPUE, harvest, and total estimates — v0.2.0
- ✓ Sample size validation for ratio estimators (n<10 error, n<30 warning) — v0.2.0
- ✓ Interview-based estimation vignette with complete workflow — v0.2.0
- ✓ Test coverage ≥85% overall, ≥95% core functions (89.24% achieved) — v0.2.0
- ✓ All functions pass R CMD check with 0 errors/warnings — v0.2.0

### Active

**v0.3.0 - Incomplete Trips & Validation** (In planning)

### Out of Scope

**For v0.1.0 milestone:**
- Other design types (roving, aerial, bus route) — deferred to v0.2.0
- Interview-based estimation (CPUE, catch) — deferred to v0.2.0
- Hybrid designs — deferred to v0.3.0
- QA/QC diagnostic functions — deferred to v1.0.0
- Visualization/plotting — deferred to v1.0.0 or separate package
- Shiny app, spatial integration, ML features — post v1.0.0

**Explicitly excluded:**
- Backward compatibility with v1 API — package never released, clean slate
- Support for non-tidy workflows — committed to tidy selectors
- Exposing survey objects in primary API — domain translation is core value

## Context

**Current State (v0.2.0 shipped 2026-02-11):**
- Package structure: 8,599 LOC R total (instantaneous counts + interview-based estimation)
- Test suite: 610 tests with 89.24% coverage
- Quality: 0 lintr issues, R CMD check clean (0 errors, 0 warnings)
- Documentation: Complete roxygen2 docs, example datasets, 2 vignettes (getting-started, interview-estimation)
- Tech stack: R (≥4.1.0), survey, tidyverse (tidyselect, dplyr, rlang), checkmate, cli
- Capabilities: Effort estimation (counts), CPUE/harvest estimation (interviews), total catch/harvest (delta method)

**Brownfield redesign:**
- Existing tidycreel v1 codebase has ~40 R files covering estimators, variance, QA/QC
- v1 uses survey package but exposes survey objects in user-facing API
- Codebase mapping exists in `.planning-legacy-work/codebase/`
- Design document: `docs/plans/2026-01-30-tidycreel-gsd-redesign.md`

**v2 architectural innovations (proven in v0.1.0):**
1. **Three-layer architecture:** User API (domain translation) → Orchestration (survey bridge) → Survey package (statistics) ✓
2. **Design-centric API:** Everything flows through `creel_design` object ✓
3. **Progressive validation:** Fail fast (creation) → warn (estimation) → deep diagnostics (optional) ✓
4. **Hybrid philosophy:** 90% domain translation, 10% escape hatches for power users ✓
5. **Continuous quality gates:** lintr, R CMD check, coverage at every phase ✓

**Development approach:**
- Build simplest design type first (instantaneous counts) to prove architecture ✓ Complete
- Each milestone adds design types incrementally
- GSD methodology with atomic commits and phase verification
- Start from empty package structure (not refactoring existing code) ✓

**v0.3.0 milestone focus (current):**
- Incomplete trip handling following Colorado C-SAP and Pollock et al. best practices
- Complete trip prioritization (roving-access design) as default approach
- Validation framework to test incomplete vs. complete trip comparability
- Mean-of-ratios estimator with truncation for incomplete trips (research/diagnostic mode)

**Future milestone focus:**
- Multi-species support with covariance framework (v0.4.0 or later)
- Bus-route design (systematic access point coverage) (v0.4.0 or later)
- Advanced QA/QC diagnostics for interview data quality (v1.0.0)

## Constraints

- **R package standards:** Must pass R CMD check with no errors/warnings/notes
- **Survey package foundation:** Statistical correctness depends on survey package; don't reimplement
- **Test coverage:** 85%+ overall, 95%+ for core estimation functions
- **Code quality:** All code passes lintr before commit (enforced by pre-commit hooks)
- **Performance:** < 1 second for typical survey (100 days, 3 strata)
- **R version:** R >= 4.1.0 (for native pipe and tidy evaluation features)
- **No dependencies on tidycreel v1:** Clean slate, no migration concerns

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Three-layer architecture (API → Orchestration → Survey) | Separates domain translation from statistics; enables testing layers independently | ✓ Good — Clean separation enables independent layer testing, survey package correctly hidden |
| Design-centric API (everything through `creel_design` object) | Matches real workflow: design survey → collect data → estimate; single source of truth | ✓ Good — Intuitive workflow, design object holds all context |
| Tidy selectors for column specification | Familiar to tidyverse users; no quoted strings; consistent with dplyr/tidyr | ✓ Good — No user friction, tidyselect integration seamless |
| Progressive validation (tier 1/2/3) | Supports all workflows: production (fast), exploratory (deep), power user (skip) | ✓ Good — Tier 1 fail-fast + Tier 2 warnings working well, Tier 3 deferred to v1.0 |
| Build instantaneous counts first | Simplest design type proves architecture; establishes patterns for other types | ✓ Good — Architecture proven, patterns established for future design types |
| Start from empty package (not refactor v1) | Clean slate faster than unpicking v1 coupling; v1 available as reference | ✓ Good — Clean implementation, v1 available as reference when needed |
| Variance methods visible but defaulted | Scientific software requires justification; users must know what's happening | ✓ Good — Default to Taylor, bootstrap/jackknife available, method shown in output |
| lintr enforced at every commit | Continuous quality cheaper than cleanup phases; prevents technical debt | ✓ Good — Zero technical debt, pre-commit hooks worked perfectly |
| PSU specified in add_counts() only (Phase 3) | PSU meaningful only when count data present | ✓ Good — User-facing decision scoped correctly |
| Eager survey construction (Phase 3) | Catch errors when user has context about data | ✓ Good — Immediate feedback on design issues |
| Accept unreachable error handlers coverage gap (Phase 7) | Pragmatic testing vs perfectionist coverage | ✓ Good — 88.75% overall coverage, test user behavior not implementation details |
| Interview survey uses ids=~1 not ids=~psu (Phase 8) | Interviews are terminal units, not clustered by day | ✓ Good — Correctly represents interview data structure for variance estimation |
| Ratio-of-means estimator for CPUE/HPUE (Phases 9-10) | Accounts for catch/effort correlation, appropriate for complete trips | ✓ Good — survey::svyratio provides correct variance, reference tests prove correctness |
| Manual delta method for product variance (Phase 11) | Simpler than svycontrast, transparent formula | ✓ Good — Var(E×C) = E²·Var(C) + C²·Var(E) implementation clear and verifiable |
| Shared validation for ratio estimators (Phase 10) | validate_ratio_sample_size with type parameter serves CPUE and harvest | ✓ Good — Eliminates duplication, maintains context-aware messages |
| Coverage deviation accepted at 93.8% (Phase 12) | Unreachable defensive error handling prevented by Tier 1 validation | ✓ Good — 33 lines are defensive guards that can't be reached, 89.24% overall exceeds 85% target |

---
*Last updated: 2026-02-14 after starting v0.3.0 milestone*
