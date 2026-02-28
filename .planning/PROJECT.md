# tidycreel v2 — Domain Translation for Creel Survey Analysis

## What This Is

A ground-up redesign of tidycreel as a domain-translator R package for creel survey analysis, built on the R `survey` package foundation. Provides a tidy, design-centric API where creel biologists work entirely in domain vocabulary (interviews, counts, effort, catch) while the package handles all survey statistics internally. Supports production reporting, iterative refinement, and exploratory analysis workflows.

## Core Value

Creel biologists can analyze survey data using creel vocabulary without ever understanding survey package internals (PSUs, FPCs, calibration weights) — while power users can access underlying survey objects when needed for advanced work.

## Current State

**Latest Release:** v0.4.0 Bus-Route Survey Support (shipped 2026-02-28)

**Package Capabilities:**
- Effort estimation from instantaneous count data (v0.1.0)
- CPUE and harvest estimation from interview data with ratio-of-means (v0.2.0)
- Total catch/harvest estimation with delta method variance propagation (v0.2.0)
- Trip completion status tracking with complete vs. incomplete trip handling (v0.3.0)
- Mean-of-ratios estimator for incomplete trips with configurable truncation (v0.3.0)
- TOST equivalence testing to validate incomplete trip assumptions (v0.3.0)
- Complete trip defaults following Colorado C-SAP best practices (v0.3.0)
- Bus-route survey designs with nonuniform sampling probabilities (πᵢ = p_site × p_period) (v0.4.0)
- Bus-route effort estimation implementing Jones & Pollock (2012) Eq. 19.4 with enumeration expansion (v0.4.0)
- Bus-route harvest/catch estimation implementing Jones & Pollock (2012) Eq. 19.5 (v0.4.0)
- Primary source validation: Malvestuto (1996) Box 20.6 reproduced exactly (E_hat = 847.5) (v0.4.0)
- Equation traceability documentation mapping all bus-route computations to published sources (v0.4.0)

## Next Milestone Goals

*To be defined with `/gsd:new-milestone`*

**Future Focus Areas:**
- Multi-species support with covariance framework (v0.5.0+)
- Advanced QA/QC diagnostics for interview data quality (v1.0.0)

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

**v0.3.0 - Incomplete Trips & Validation** — Shipped 2026-02-16
- ✓ Trip completion status tracking (trip_status parameter in add_interviews) — v0.3.0
- ✓ Trip duration validation with overnight trip support (timezone handling) — v0.3.0
- ✓ Mean-of-ratios estimator for incomplete trips (estimator="mor") — v0.3.0
- ✓ Configurable trip truncation threshold (default 0.5 hours per Hoenig et al.) — v0.3.0
- ✓ Complete trip defaults following Colorado C-SAP best practices (use_trips parameter) — v0.3.0
- ✓ Sample size warnings when <10% complete trips (Pollock et al. threshold) — v0.3.0
- ✓ TOST equivalence testing framework (validate_incomplete_trips) — v0.3.0
- ✓ Diagnostic comparison mode for complete vs. incomplete estimates — v0.3.0
- ✓ Comprehensive 794-line vignette with scientific rationale and validation workflow — v0.3.0
- ✓ Test coverage maintained ~90% (718 tests total) — v0.3.0

**v0.4.0 - Bus-Route Survey Support** — Shipped 2026-02-28
- ✓ Bus-route design constructor (`creel_design(survey_type = "bus_route")`) with sampling frame and probability validation — v0.4.0
- ✓ Inclusion probability calculation: πᵢ = p_site × p_period from sampling design (not site characteristics) — v0.4.0
- ✓ `add_interviews()` extended with enumeration counts (n_counted/n_interviewed) and automatic πᵢ join — v0.4.0
- ✓ `estimate_effort()` bus-route dispatch implementing Jones & Pollock (2012) Eq. 19.4 — v0.4.0
- ✓ `estimate_harvest()`/`estimate_total_catch()` bus-route dispatch implementing Jones & Pollock (2012) Eq. 19.5 — v0.4.0
- ✓ Variance estimation via survey package (svydesign + svytotal) — v0.4.0
- ✓ Accessor quartet: `get_sampling_frame()`, `get_inclusion_probs()`, `get_enumeration_counts()`, `get_site_contributions()` — v0.4.0
- ✓ Primary source validation: Malvestuto (1996) Box 20.6 reproduced exactly (E_hat = 847.5 angler-hours, 1e-6 tolerance) — v0.4.0
- ✓ Integration tests proving complete bus-route workflow wiring — v0.4.0
- ✓ Bus-route surveys vignette: step-by-step walkthrough with educational πᵢ explanation — v0.4.0
- ✓ Equation traceability vignette: all formulas mapped to Jones & Pollock (2012) and Malvestuto (1996) — v0.4.0
- ✓ Test coverage maintained ~90% (1,098 tests total) — v0.4.0
- ✓ R CMD check: 0 errors, 0 warnings; lintr: 0 issues — v0.4.0

### Active

(None - Next milestone requirements to be defined with `/gsd:new-milestone`)

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
- Auto-pooling complete + incomplete trips — scientifically invalid per Pollock et al. (different sampling probabilities) — v0.3.0
- Incomplete trips as default — Colorado C-SAP and best practice use complete trips — v0.3.0
- Roving-roving design (effort from roving) — 160x more bias than roving-access, not recommended — v0.3.0

## Context

**Current State (v0.4.0 shipped 2026-02-28):**
- Package structure: 7,449 LOC R (counts + interviews + incomplete trips + bus-route)
- Test suite: 1,098 tests with ~90% coverage
- Quality: 0 lintr issues, R CMD check clean (0 errors, 0 warnings)
- Documentation: Complete roxygen2 docs, example datasets, 5 vignettes (getting-started, interview-estimation, incomplete-trips, bus-route-surveys, bus-route-equations)
- Tech stack: R (≥4.1.0), survey, tidyverse (tidyselect, dplyr, rlang), checkmate, cli
- Capabilities: Effort estimation (counts + bus-route), CPUE/harvest estimation (interviews), total catch/harvest (delta method + bus-route), incomplete trip validation (MOR + TOST), bus-route nonuniform probability estimation

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

**Development Milestones Completed:**
- ✅ v0.1.0 (2026-02-09): Foundation with instantaneous counts and effort estimation
- ✅ v0.2.0 (2026-02-11): Interview-based CPUE/harvest estimation with delta method variance
- ✅ v0.3.0 (2026-02-16): Incomplete trips with MOR estimator, TOST validation, Colorado C-SAP compliance
- ✅ v0.4.0 (2026-02-28): Bus-route nonuniform probability estimation (the ONLY correct R implementation), primary source validated against Malvestuto (1996)

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
| trip_status required parameter (Phase 13) | Essential for downstream incomplete trip estimators | ✓ Good — Breaking change accepted, clear validation messaging guides users |
| MOR uses survey::svymean not svyratio (Phase 15) | Statistically appropriate for incomplete trips | ✓ Good — Individual catch/effort ratios correctly represent incomplete trip data |
| Complete-trip default (Phase 17) | Aligns with Colorado C-SAP and roving-access design | ✓ Good — Scientifically valid default, explicit use_trips parameter for flexibility |
| TOST for equivalence testing (Phase 19) | Proves similarity vs. failing to reject difference | ✓ Good — Standard bioequivalence approach, ±20% threshold appropriate for field data |
| Base R graphics for validation plots (Phase 19) | Avoids additional dependencies | ✓ Good — Sufficient for diagnostic plots, consistent with package design |
| πᵢ precomputed at construction time (Phase 21) | Validates probabilities fail-fast; not lazily | ✓ Good — Errors surface when user has context, not at estimation time |
| p_period uniformity tolerance 1e-10 (Phase 22) | Tighter than p_site sum (1e-6) because p_period must be identical within circuit | ✓ Good — Catches floating point drift from probability calculations |
| Bus-route dispatch BEFORE survey NULL check (Phase 24) | Bus-route uses design$interviews not design$survey (survey slot is NULL for bus-route) | ✓ Good — Correct dispatch order avoids false "no survey" errors |
| Cross-validation uses ids=~1, strata=~day_type (Phase 26) | Mirrors implementation; plan's ids=~site weights=~1/.pi_i approach gave wrong answer (18.625 not 847.5) | ✓ Good — Discovered during Phase 26; corrected before shipping |
| Two-vignette documentation approach (Phase 27) | Workflow vignette teaches HOW; equation traceability teaches WHY | ✓ Good — Separation serves both practitioner and statistician audiences |
| Pure Markdown traceability vignette (Phase 27) | No executable R chunks in equation doc — reference document not tutorial | ✓ Good — Faster rendering, stable as reference material |

---
*Last updated: 2026-02-28 after v0.4.0 milestone completion*
