# tidycreel v2 — Domain Translation for Creel Survey Analysis

## What This Is

A ground-up redesign of tidycreel as a domain-translator R package for creel survey analysis, built on the R `survey` package foundation. Provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally. Supports production reporting, iterative refinement, and exploratory analysis workflows.

## Core Value

Creel biologists can analyze survey data using creel vocabulary without ever understanding survey package internals (PSUs, FPCs, calibration weights) — while power users can access underlying survey objects when needed for advanced work.

## Requirements

### Validated

(None yet — building from scratch)

### Active

**v0.1.0 - Foundation (Instantaneous Counts)**
- [ ] Package structure with lintr, testthat, CI/CD configured
- [ ] `creel_design()` constructor with tidy selectors for column specification
- [ ] `add_counts()` for instantaneous count data
- [ ] `estimate_effort()` returning estimates with SE and CI
- [ ] Progressive validation (Tier 1: design creation, Tier 2: estimation warnings)
- [ ] Grouped estimation with `by = ` parameter
- [ ] Variance method control (Taylor, bootstrap, jackknife)
- [ ] Internal survey design construction (day-PSU, stratified)
- [ ] Reference tests proving estimates match manual survey package calculations
- [ ] Getting Started vignette with example workflow

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

**Brownfield redesign:**
- Existing tidycreel v1 codebase has ~40 R files covering estimators, variance, QA/QC
- v1 uses survey package but exposes survey objects in user-facing API
- Codebase mapping exists in `.planning-legacy-work/codebase/`
- Design document: `docs/plans/2026-01-30-tidycreel-gsd-redesign.md`

**Technical environment:**
- R package development with roxygen2, devtools, testthat
- Built on survey package (Thomas Lumley) for statistical engine
- Tidyverse ecosystem (dplyr, tidyr, rlang for tidy evaluation)
- GitHub for version control and CI/CD
- Never publicly released — no users to migrate

**v2 architectural innovations:**
1. **Three-layer architecture:** User API (domain translation) → Orchestration (survey bridge) → Survey package (statistics)
2. **Design-centric API:** Everything flows through `creel_design` object
3. **Progressive validation:** Fail fast (creation) → warn (estimation) → deep diagnostics (optional)
4. **Hybrid philosophy:** 90% domain translation, 10% escape hatches for power users
5. **Continuous quality gates:** lintr, R CMD check, coverage at every phase

**Development approach:**
- Build simplest design type first (instantaneous counts) to prove architecture
- Each milestone adds design types incrementally
- GSD methodology with atomic commits and phase verification
- Start from empty package structure (not refactoring existing code)

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
| Three-layer architecture (API → Orchestration → Survey) | Separates domain translation from statistics; enables testing layers independently | — Pending |
| Design-centric API (everything through `creel_design` object) | Matches real workflow: design survey → collect data → estimate; single source of truth | — Pending |
| Tidy selectors for column specification | Familiar to tidyverse users; no quoted strings; consistent with dplyr/tidyr | — Pending |
| Progressive validation (tier 1/2/3) | Supports all workflows: production (fast), exploratory (deep), power user (skip) | — Pending |
| Build instantaneous counts first | Simplest design type proves architecture; establishes patterns for other types | — Pending |
| Start from empty package (not refactor v1) | Clean slate faster than unpicking v1 coupling; v1 available as reference | — Pending |
| Variance methods visible but defaulted | Scientific software requires justification; users must know what's happening | — Pending |
| lintr enforced at every commit | Continuous quality cheaper than cleanup phases; prevents technical debt | — Pending |

---
*Last updated: 2026-01-30 after initialization from design document*
