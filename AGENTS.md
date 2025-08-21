tidycreel — Agent Operating Guide (AGENTS.md)

This guide orients an AI/code assistant to contribute safely and effectively to tidycreel using the Markdown docs in the repo root.

**Purpose**
- Provide a concise, actionable brief for agents.
- Point to canonical docs for details.
- Encode ground rules, priorities, and workflow.

**Project Summary**
- Goal: Build a robust, design-based R package for creel survey analysis (effort, CPUE, catch/harvest) with tidy, vectorized APIs grounded in the survey package.
- Users: Fisheries scientists and R developers.
- Core tenets: tidyverse style, vectorization-first, survey-backed estimators, comprehensive tests and docs.

**Ground Rules**
- Style: Follow tidyverse style strictly; use snake_case for functions/vars; return tibbles; pipe-friendly design.
- Vectorization: Prefer vectorized ops and grouped summaries over explicit loops; avoid apply-family if vectorization exists.
- Statistical engine (survey-first): Build on `survey`/`svrepdesign` for all estimators and variance. Use `svydesign`, `svyby`, `svytotal`, `svymean`, `svyratio`, `postStratify`, and `calibrate` where applicable. Prefer replicate-weight workflows via `svrepdesign` for bootstrap/jackknife/BRR — do not use external bootstrapping packages.
- Quality: Roxygen docs for all exported functions; tests for every contribution; ≥90% coverage target when practical.
- Conduct: Abide by the Code of Conduct; be respectful and inclusive.

**Canonical Documents**
- `CONTRIBUTING.md`: Contribution standards, vectorization-first policy, testing requirements, PR checklist.
- `CODE_OF_CONDUCT.md`: Community standards and enforcement.
- `README.md`: Package overview, installation, CI/lint info.
- `creel_foundations.md`: Statistical background and package design recommendations.
- `creel_chapter.md`: Broader creel survey chapter draft (context and references).
- `tidycreel_architecture_plan.md`: Architecture, scope, API plan, testing/CI, roadmap.
- `tidycreel_designs.md`: Design constructors assumptions, diagnostics, usage guidance.
- `tidycreel_effort_action_plan.md`: Concrete implementation plan for effort estimators (instantaneous, roving, bus-route, aerial) with APIs and tasks.
- `todo.md`: Living roadmap and immediate tasks; keep synchronized with work.
- `Kickoff.md`: Operational protocol for early phases; use where applicable.

**Agent Priorities**
- Implement and harden design-based estimators and design constructors before model-based features.
- Maintain strict input validation and diagnostics (dropped rows, NA weights, mismatched strata).
- Ensure survey object interop: `creel_design` ↔ `survey::svydesign`/`svrepdesign` conversion helpers. Estimators must accept a design (or construct one) and compute via `survey` functions.
- Keep documentation and examples runnable; expand vignettes and pkgdown config when present.

**Operational Conventions (Current)**
- Messaging: Standardize errors/warnings using `cli::cli_abort()` and `cli::cli_warn()`; prefer shared helpers (e.g., `tc_abort_missing_cols()`, `tc_group_warn()`) to keep phrasing consistent.
- Day-PSU design: Construct day-level designs via `as_day_svydesign(calendar, ...)` and use them across effort estimators; prefer replicate designs via `survey::svrepdesign()` when variance requires.
- Estimator wrappers: Expose a single `est_effort(design, counts, method=...)` that delegates to method-specific functions; keep return shape consistent (`estimate`, `se`, `ci_low`, `ci_high`, `n`, `method` + group cols).
- Examples/tests data: Use small, bundled toy datasets for examples, vignettes, and tests; avoid network/filesystem side effects; keep examples fast (`@examplesIf interactive()` or small inputs).
- CI workflows: Use `r-lib/actions/check-r-package@v2`; enable a modest OS/R matrix, caching, concurrency, and timeouts; run `lintr` separately; deploy `pkgdown` on default branch only (not PRs).
- DESCRIPTION/docs: Ensure a Maintainer is set; prefer `testthat` edition 3; keep README badges current; update vignettes when APIs change.

**Change Discipline**
- Purpose: Keep this brief synchronized with actual practice so new contributors and agents stay aligned.
- When to update:
  - Estimator interfaces or return schema change (columns, naming, variance options).
  - Design constructors or required columns change; new helpers added/renamed.
  - Messaging conventions change (cli helpers, error/warn phrasing).
  - CI workflow structure or required checks materially change.
  - Canonical docs (CONTRIBUTING, architecture plans) update policies that affect agents.
- How to update:
  - In the same PR that changes conventions, edit this file and succinctly update the relevant section(s) (prefer bullets over prose).
  - Note the update in the PR via the checklist item “Reviewed/updated AGENTS.md”.
  - For larger policy shifts, open a focused follow-up PR and tag maintainers.
- Scope: AGENTS.md summarizes conventions; if conflicts arise, follow CONTRIBUTING.md and architecture documents as the source of truth.

**Implementation Rules (Authoritative)**
- Survey-first framework:
  - Define/accept a valid `svydesign`/`svrepdesign` that encodes PSUs, strata, weights, and FPC when relevant.
  - Compute estimates via `survey` verbs (`svytotal`, `svymean`, `svyratio`, `svyby`).
  - For complex variance, use `svrepdesign` replicate schemes from `survey` (bootstrap, jackknife, BRR). Avoid `boot` and custom resampling.
- Tidy interface and consistency:
  - Use `dplyr`/`tidyr` for data prep; avoid explicit loops and base `apply` family when vectorization or grouped ops suffice.
  - Arguments: `design`, explicit `cols = c(...)` mappings when raw tables are accepted, `by`, `conf_level`, `variance = c("analytic","replicate")` (backed by `survey`), and `...` for future.
  - Return: tibble with tidy columns (`estimate`, `se`, `ci_low`, `ci_high`, `n`, `method`) plus group columns; include `diagnostics` list-col when useful.
- Coding standards:
  - snake_case names; minimal side effects; no hidden I/O; no global options changes.
  - Document statistical assumptions, estimator selection logic, and variance method.
  - Prefer `srvyr` only if it materially improves readability without obscuring design semantics; `survey` remains authoritative.

**Prohibited / Avoid**
- External resampling packages for core variance (e.g., `boot`) — use `survey` replicate weights instead.
- Ad-hoc, non-design-based expansions where a `svydesign` should be used.
- Explicit `for`/`while` loops when grouped vectorization suffices; excessive `purrr::map` where `mutate`/`across` apply.
- Legacy/placeholder estimator code paths that bypass `survey` — deprecate or wrap with clear errors until refactored.

**Estimator Notes (Applied)**
- Instantaneous/Progressive/Aerial/Bus-route effort:
  - Compute day- or PSU-level totals per stratum; estimate via `svytotal`/`svyby` using the design.
  - Visibility/calibration enter as modeled adjustments to counts or via calibration/post-stratification in the design.
  - Variance from analytic (Taylor) where available; otherwise replicate weights via `svrepdesign`.
- CPUE, Catch, Harvest:
  - Favor ratio-of-means (`svyratio`) for incomplete trips; mean-of-ratios for complete trips as appropriate; combine with effort estimates using delta or replicate methods.

**High-Value Next Steps (derived from todo and plans)**
- Effort estimators: finalize instantaneous, progressive, bus-route; complete aerial estimator (visibility adjustment, stratified expansion).
- Variance: analytic where possible; bootstrap/jackknife via svrepdesign for complex cases; expose conf level.
- Diagnostics: standardize warnings for NA weights, non-overlapping strata, and unknown columns; include list-column diagnostics.
- Plotting: `plot_design()` and `plot_effort` improvements (ggplot2), minimal defaults.
- Tests: edge cases (zero counts, empty strata, DST/leap days), invariants, and reference checks against toy data.

**Working Workflow**
- Plan: Identify smallest vertical slice; update `todo.md` with planned changes.
- Validate: Add/extend tests first (`testthat`); define expected structure and edge cases.
- Implement: Prefer minimal, composable functions; keep APIs tidy and vectorized.
- Document: Roxygen comments with examples; update vignettes/articles when needed.
- Verify: Run devtools::document(), devtools::test(), devtools::check(); address linting if configured.
- PR: Follow conventional commit style and PR checklist from CONTRIBUTING.md.

**Do / Don’t**
- Do: Use grouped operations, survey-backed estimators, clear errors, and informative warnings.
- Do: Keep dependencies minimal (survey, tidyverse core); gate optional heavy deps.
- Don’t: Introduce loops where vectorization suffices; rely on global state; write to non-temp paths in examples/tests.

**Design Constructors (quick cues)**
- Access-point: Interviews + calendar; build `svydesign`; warn on NA weights or misaligned strata.
- Roving: Counts (instantaneous/progressive) + interviews as needed; avoid mixing interviews during count passes unless accounted.
- Replicate weights: Wrap base design for jackknife/bootstrap/BRR as needed for variance.
- Bus-route: Unequal probability sampling across scheduled visits; HT totals with inclusion probabilities; verify cycle assumptions.

**Effort Estimation (quick cues)**
- Instantaneous: mean count × represented minutes ÷ 60; optional visibility correction; expand by strata/day.
- Progressive (roving): sum per-pass counts × route_minutes ÷ 60; guard against interview-induced bias; expand by day/strata.
- Bus-route: HT over observed parties with πᵢ; combine with day-level design; replicate variance when analytic form is complex.
- Aerial: Snapshot counts with visibility adjustment; stratified expansion; ensure flight represents valid time window.

**Edge Cases to Watch**
- Zero-effort/catch strata, empty groups, single-observation strata.
- DST transitions, leap days, mixed time zones.
- Partial NA weights, mismatched stratification keys, duplicated rows.
- Extreme outliers and incomplete-trip bias (prefer ratio-of-means for CPUE).

**References & Links**
- Start from `creel_foundations.md` and the architecture/action plans for formulas, assumptions, and APIs.
- See `tidycreel_designs.md` for constructor diagnostics and conversion helpers.

Maintain this file as the single-page brief for new agents. Update when `CONTRIBUTING.md`, architecture, or plans change.

**Revision Log**
- 2025-08-21: Added Operational Conventions section to capture current practices (cli messaging, day-PSU design, estimator wrapper, examples/data, CI, DESCRIPTION/docs).
- 2025-08-21: Added Change Discipline section; updated PR template with AGENTS.md checklist to surface convention adherence/updates.

Add entries as one-line bullets with ISO date (YYYY-MM-DD), newest first; include what changed and why if not obvious.
