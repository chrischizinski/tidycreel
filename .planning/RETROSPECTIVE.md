# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: M022 — Comprehensive Project Evaluation and Future Planning

**Shipped:** 2026-04-19
**Phases:** 6 | **Plans:** 11 | **Commits:** 37 | **Timeline:** 5 days (2026-04-14 → 2026-04-19)

### What Was Built

- `estimate_total_harvest_br()` + `estimate_total_release_br()` — HT estimators for bus-route and ice designs; ice as degenerate bus-route with intersect() guard pattern
- `inst/profiling/` harness — 4 scripts; empirical bench data grounding the Rcpp DEFER recommendation
- 9 planning/research documents (architecture, dependencies, error handling, creel.connect, quality audit, testing strategy, performance analysis, PBT invariants, analytical extensions) totalling ~3,500 lines of structured findings

### What Worked

- **Research-first posture for planning phases** — each phase (71–75) produced a RESEARCH.md before writing the final document; this eliminated guesswork and grounded all recommendations in actual code inspection
- **Parallel evaluation phases** — phases 71–75 had no dependencies on each other, allowing them to be planned and executed quickly in sequence without blocking
- **Audit milestone format** — structured the milestone as a pure evaluation cycle (not a release), which let findings accumulate without premature implementation commitment
- **Decision surfacing** — the cli::cli_abort deviation inventory (D1–D4) and the Rcpp DEFER framing are examples of well-structured "here's what we found, here's why we're not changing it" artifacts that prevent future re-investigation

### What Was Inefficient

- **ROADMAP checkbox tracking gaps** — two plans (74-01, 75-02) showed `[ ]` in ROADMAP.md despite being delivered and verified; this required manual correction at closeout
- **Nyquist VALIDATION.md not adopted** — all 6 phases have draft or missing VALIDATION.md; the Nyquist compliance protocol wasn't woven into this milestone's execution cadence
- **Phase 72 findings orphaned** — architectural recommendations (drop `scales`, demote `ggplot2`) weren't forward-linked into a v1.4.0 backlog; risk of being lost at next milestone kickoff
- **Human verification deferred** — Phase 70 vignette build and test suite confirmation, Phase 74 coverage reproducibility — both deferred rather than confirmed in-milestone

### Patterns Established

- **Evaluation milestone pattern** — a milestone that produces only planning artifacts (no user-facing release) is a valid and productive cycle; phases 71–75 established the research/analysis/document format for future evaluation work
- **Phase 73 canonical error pattern** — `cli::cli_abort` named-vector convention is now the documented standard; D1/D2 idioms are approved and documented, not violations
- **DEFER framing for Rcpp** — "DEFER with empirical evidence" is a more useful outcome than "yes/no"; creates an auditable record of why Rcpp was not pursued
- **Dual-report format for strategy phases** — Phase 72 (arch + dep review) and Phase 73 (error + creel.connect) each produced two separate focused documents rather than one combined report; this improved navigability

### Key Lessons

1. **Orphan risk at milestone closeout** — planning artifacts that don't get forward-linked into the next milestone's backlog tend to be forgotten; explicitly create backlog items from findings before archiving
2. **Checkbox hygiene matters** — ROADMAP checkbox state should be updated when plans complete, not retroactively at closeout; stale checkboxes cause confusion in audits
3. **Human verification is a real gate** — deferring "run the tests / build the vignettes" creates compounding uncertainty; confirm in-milestone when feasible
4. **Evaluation milestones earn their keep** — 5 days of structured analysis produced clear, prioritized v1.4.0 targets (scales drop, named conditions, quickcheck INV-04) that would otherwise require re-investigation at implementation time

### Cost Observations

- Model: claude-sonnet-4-6 (single model throughout)
- Sessions: ~5–7 (estimated)
- Notable: Research-first planning phases (71–75) were highly efficient — each phase consumed 1 session for research + 1 session for document writing; the dual-report format kept sessions focused

---

## Milestone: M023 / v1.4.0 — Quality, Polish, and rOpenSci Readiness

**Shipped:** 2026-04-23 (local planning closeout; no git tag)
**Phases:** 4 | **Plans:** 15 | **Timeline:** 5 days (2026-04-19 → 2026-04-23)

### What Was Built

- 8 named condition classes at rOpenSci-priority sites; `inst/CITATION` and `lifecycle` badges formalized
- `scales` dropped, `lubridate` demoted to Suggests with install guards; `rlang::caller_env()` threaded through bus-route internals
- `@family` tags across exported surface; `expect_snapshot()` for three priority print methods
- quickcheck property-based tests for INV-01 through INV-05; reusable design generators; Codecov CI gate at 85%

### What Worked

- **M022 forward-link payoff** — the R1–R8 recommendation list from the quality audit became the execution checklist for M023 with minimal re-investigation
- **Incremental quality sweep format** — each phase (76-79) addressed a self-contained concern (blockers → deps → quality → PBT) without cross-phase dependencies
- **quickcheck adoption** — generators and `for_all()` invariants established a reusable PBT infrastructure; INV-06 was scaffolded but not yet proven (became M024 Phase 80)

### What Was Inefficient

- **Local closeout without a version tag** — the package remained at `1.3.0` and no `v1.4.0` tag was created; this created ambiguity about what was "shipped" vs "planned"
- **Nyquist gaps** — VALIDATION.md files were incomplete across all four phases; validation debt carried forward from M022

### Key Lessons

1. **Local closeouts need explicit scope statements** — "planning closeout" and "release" should be distinguished upfront so release-surface work (version bump, tag) isn't deferred ambiguously
2. **PBT invariants accumulate value** — each quickcheck test added in M023 directly enabled the M024 INV-06 proof; scaffold-now, prove-later is a valid pattern when the estimator isn't ready

---

## Milestone: M024 / v1.5.0 — Analytical Extensions

**Shipped:** 2026-04-28
**Phases:** 3 | **Plans:** 8 | **Timeline:** 3 days (2026-04-26 → 2026-04-28)

### What Was Built

- `estimate_exploitation_rate()` — Pollock et al. moment estimator, delta-method SE, [0,1]-clamped CI, stratified path with T-weighted aggregate, 4 quickcheck invariants, pkgdown reference page
- INV-06 stratified-sum fix in `estimate_total_catch()` — combined-ratio replaced with per-stratum product sum; 24/24 invariants pass
- `lifecycle` rcmdcheck NOTE eliminated; 14 `sapply()` → `vapply()` type-safety sweep across 8 files
- `vignettes/tidycreel-connect.Rmd` bridge article under new Ecosystem pkgdown nav section
- rhub v2 GitHub Actions workflow; ubuntu-release and macos-release confirmed green

### What Worked

- **TDD discipline paid off fast** — RED/GREEN commit cycles kept each plan focused and the test suite was the final arbiter; Plans 80-01, 81-01, 81-02 each took <5 min because the RED tests defined scope exactly
- **Internal helper pattern** — `.estimate_exploitation_rate_stratified()` kept the public API minimal while enabling full unit testing; clean separation
- **rhub v2 vs v1** — GitHub Actions-based rhub gave publicly auditable results immediately; zero friction after `rhub::rhub_setup()` was committed
- **Milestone was tight and well-defined** — 3 phases, 8 plans, clear requirements; no scope drift

### What Was Inefficient

- **ROADMAP.md checkbox not updated at Phase 82 completion** — Phase 82 remained `[ ]` in ROADMAP.md despite all 3 summaries being written; required manual correction at closeout
- **quickcheck API mismatch** — Plan 81-03 specified `gen_int`/`gen_dbl`/`forall()` which don't exist; actual API is `integer_bounded`/`double_bounded`/`for_all()`; this was auto-fixed but indicates plan templates lag behind the actual library API

### Patterns Established

- **Standalone scalar estimator pattern** — `estimate_exploitation_rate()` accepts pre-computed summary stats with no `creel_design` dependency; useful for mark-recapture and other non-design-based estimators
- **Package-level @importFrom for single-package imports** — `R/tidycreel-package.R` as the single location for package-wide import declarations
- **rhub v2 dispatch** — `rhub::rhub_setup()` once, `rhub::rhub_check(platforms = ...)` for subsequent runs; GitHub Actions tab for results

### Key Lessons

1. **ROADMAP checkbox hygiene** — update the ROADMAP.md `[ ]` → `[x]` immediately when a phase completes, not at milestone closeout; this is the third milestone where stale checkboxes caused confusion
2. **quickcheck API should be locked in a reference comment** — the API mismatch in Plan 81-03 is now the third time the quickcheck generator names caused confusion; add a `# quickcheck API: for_all(), integer_bounded(left=, right=)` comment near the first invariant in test-invariants.R
3. **Scope descoping is a valid milestone outcome** — QUAL-05 (rOpenSci submission) was cleanly descoped with no ceremony; this is the right call when the scope is genuinely separate from the technical work

### Cost Observations

- Model: claude-sonnet-4-6
- Sessions: ~4 (estimated)
- Notable: TDD phases (80-01, 81-01, 81-02) were extremely fast (~4–5 min each); quality sweep phases (82-01 through 82-03) took longer due to external tool runs (rhub GitHub Actions wait time)

---

## Milestone: v1.6.0 — Analytical Extensions II

**Shipped:** 2026-05-06
**Phases:** 5 (83–87) | **Plans:** 9 | **Timeline:** 8 days (2026-04-28 → 2026-05-06)

### What Was Built

- `creel_n_camera()` — Cochran (1977) stratified camera-day sample size with Feltz-Middaugh (2025) minimum-day warnings; vector output matching `creel_n_effort()` shape
- `impute_camera_counts()` — Poisson GLM (Hartill 2016) default + NB GLMM opt-in (Afrifa-Yamoah 2020) for camera outage fill-in; `.imputed` flag; schema-compatible with `add_counts()`
- `estimate_angler_n()` — Chapman (default), Petersen, and Schnabel closed-population estimators with input guards, Poisson/normal CI branches, and `creel_estimates` S3 output
- `estimate_mr_harvest()` — delta-method harvest propagation; H = N_hat × rate; SE = rate × se_N
- `audit_strata()` S3 generic — `creel_design` and `default` methods; per-stratum RSE, DEFF, meets-target
- `simulate_strata_collapse()` — before/after precision tibble for proposed strata merges
- `reallocate_strata()` — Neyman-optimal named integer allocation for fixed sampling budget
- Phase 87 cleanup — closed all 6 advisory items: NB GLMM doc fix, Petersen label, Schnabel ci_hi guard, harvest_rate > 1 test, `.imputed` false-positive fix, Phase 86 VERIFICATION.md

### What Worked

- **Phase 87 as a dedicated tech-debt phase** — explicitly scheduling a single-plan cleanup phase for advisory items from internal review worked well; all 6 items closed cleanly in one commit without touching active feature code
- **Standalone estimator pattern carried over** — `estimate_angler_n()` and `estimate_mr_harvest()` followed the v1.5.0 scalar-input pattern established with `estimate_exploitation_rate()`; no `creel_design` dependency simplifies testing
- **GLMM opt-in via Suggests guard** — keeping `glmmTMB` in Suggests only and gating on `rlang::check_installed()` kept Imports unchanged and avoided a mandatory new dependency
- **intercept-only GLM per stratum** — discovering and documenting why `count ~ 1` (not `count ~ strata_col`) is correct for imputation within strata was a non-obvious invariant worth capturing

### What Was Inefficient

- **REQUIREMENTS.md checkbox drift** — CDES, MR, and STRAT requirements were never checked off as phases completed; at closeout 14 of 19 checkboxes were stale, requiring manual correction during archive (same issue for 4th milestone running)
- **Phase 86 VERIFICATION.md omitted** — the verification artifact wasn't generated during execution and had to be created retroactively in Phase 87; adds work and dilutes Phase 87's value as a pure cleanup phase
- **ROADMAP.md Phase 86 plan checkboxes** — 086-01 and 086-02 were never updated from `[ ]` to `[x]` after completion (same issue for 4th milestone running)

### Patterns Established

- **Tech-debt phase at milestone end** — Phase 87 as a structured one-plan cleanup phase for advisory items from internal review is a reusable pattern; schedule it explicitly rather than folding fixes into feature phases
- **S3 generic dual-method pattern** — `audit_strata()` S3 generic with `creel_design` and `default` methods is the established pattern for functions that accept either a design object or raw pilot statistics
- **`ignore_attr = TRUE` in named-vector assertions** — `expect_equal(..., ignore_attr = TRUE)` required when comparing named-vector tibble subsets; document as a convention in test files

### Key Lessons

1. **REQUIREMENTS.md checkbox hygiene is still broken** — four milestones in, the `[ ]` → `[x]` update still isn't happening at phase completion; consider automating this in the phase execution protocol or doing a checkpoint at each phase close
2. **VERIFICATION.md is a first-class deliverable** — it should be generated as the last step of each phase's Wave 2 plan, not as a retroactive Phase 87 task; add it explicitly to the phase execution checklist
3. **Tech-debt advisory items need an owner at discovery time** — CR-01, CR-02, and WARNING-01..03 were identified in review but not assigned to a concrete phase until Phase 87 was created; surfacing them earlier reduces close-of-milestone scramble

### Cost Observations

- Model: claude-sonnet-4-6
- Sessions: ~6 (estimated)
- Notable: Wave 1 / Wave 2 split worked well for Phases 84–86 — implementation and test phases were naturally sequenced without stalling on dependencies

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Key Change |
|-----------|--------|------------|
| M022 | 70–75 (6) | First pure evaluation milestone; established research-first document format |
| M023 | 76–79 (4) | Quality sweep format; quickcheck PBT infrastructure established |
| M024 | 80–82 (3) | TDD-driven feature + quality milestone; rhub v2 workflow committed |
| v1.6.0 | 83–87 (5) | Multi-estimator analytical milestone; tech-debt phase pattern; GLMM opt-in via Suggests guard |

### Cumulative Quality

| Milestone | Tests | Coverage | Key Deliverables |
|-----------|-------|----------|-----------------|
| M022 | 2477+ | 87% (covr 2026-04-18) | PBT invariants spec, architecture/dependency review, error-handling canonical, quality audit |
| M023 | 2537 | 86.27% (local baseline, 85% Codecov threshold) | Named conditions, lifecycle, @family, snapshots, quickcheck INV-01–05 |
| M024 | 2537+ | ~86% | Exploitation-rate estimator, INV-06 fix, quality sweep, rhub green |
| v1.6.0 | 2667 | ~86% | creel_n_camera, impute_camera_counts, estimate_angler_n, estimate_mr_harvest, audit_strata, simulate_strata_collapse, reallocate_strata |

### Top Lessons (Verified Across Milestones)

1. Research before writing — phases that invested in a RESEARCH.md produced more accurate documents with less rework
2. Forward-link findings — every planning artifact should explicitly name which future phase or backlog item will act on it
3. ROADMAP checkbox hygiene — update `[ ]` → `[x]` immediately on completion, not at closeout; recurring issue across M022/M023/M024/v1.6.0
4. quickcheck API reference — lock the API in a comment near first usage to prevent generator name confusion
5. VERIFICATION.md is a first-class deliverable — generate it as the last step of each phase's Wave 2 plan; do not defer to a cleanup phase
6. REQUIREMENTS.md checkbox updates — tick checkboxes at phase completion, not at milestone closeout; consider a checklist item in the phase execution protocol
