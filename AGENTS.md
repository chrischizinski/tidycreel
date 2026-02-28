# Repository Guidelines

## Project Structure & Module Organization
- Core package code lives in `R/`; keep functions small and pipe-friendly.
- Tests reside in `tests/testthat/`; helper fixtures under `tests/testthat/helpers/`.
- Reference data sits in `data/` and `sample_data/`; vignettes and longer docs are in `vignettes/` and `dev-notes/`.
- Generated documentation is in `man/`; site assets build from `_pkgdown.yml` and land in `docs/`.
- Update `todo.md` when adding or closing tasks tied to your changes.

## Build, Test, and Development Commands
- `Rscript -e "devtools::document()"` regenerates Rd files and updates `NAMESPACE`.
- `Rscript -e "lintr::lint_package()"` enforces tidyverse formatting (≤80 chars, spaced operators).
- `Rscript -e "devtools::test()"` runs the `testthat` suite; keep it fast and deterministic.
- `Rscript -e "devtools::check()"` performs full R CMD check; run before PRs.

## Coding Style & Naming Conventions
- Follow tidyverse style: snake_case for objects, two-space indents, implicit returns.
- Prefer vectorized `dplyr`/`tidyr` verbs; avoid explicit loops and unnecessary `purrr::map`.
- Use `cli::cli_abort()` and `cli::cli_warn()` via shared helpers for consistent messaging.
- Document every exported function with roxygen2 tags and runnable examples guarded with `@examplesIf interactive()` when needed.

## Testing Guidelines
- Use `testthat` (edition 3). Name files `test-<feature>.R`; mirror API names inside `describe()` blocks.
- Target ≥90% coverage; add edge-case tests for zero-count strata, NA weights, and time anomalies.
- For variance workflows, compare against small reference designs under `sample_data/`.
- Capture diagnostics (warnings, dropped rows) with `expect_snapshot()` where stability matters.

## Commit & Pull Request Guidelines
- Write Conventional Commit messages (`feat:`, `fix:`, `docs:`) scoped to a single logical change.
- Update `AGENTS.md` whenever workflows or conventions shift; tick the PR checklist item.
- PRs should link relevant issues, summarize estimator/design impacts, and note test + lint status.
- Include before/after snippets or command output when touching estimators, diagnostics, or CI.

## Agent Workflow Highlights
- Start by refining the smallest vertical slice; stage changes with `git add -p` to keep commits tight.
- Coordinate survey-based estimators through `as_day_svydesign()` and `survey::svy*` verbs.
- Prefer replicate designs via `survey::svrepdesign()` for complex variance rather than external bootstraps.
