# Phase 74: Quality Bar Assessment — Tidyverse Quality & Testing Strategy - Research

**Researched:** 2026-04-18
**Domain:** R package quality auditing — tidyverse/rOpenSci standards, testthat testing strategy, code coverage, named condition classes
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Checklist selection**
- Audit against both tidyverse and rOpenSci quality standards, tiered approach
- Full audit over all checklist items (not gap-focused only) — documents the complete picture including what is already solid; provides a baseline reference
- Verdict format: Pass / Partial / Fail per item (consistent with rOpenSci review style)
- Document structure: two-section tiered
  - Section 1: tidyverse baseline with Pass/Partial/Fail verdict per item
  - Section 2: rOpenSci aspirational delta — only items where rOpenSci raises the bar beyond the tidyverse baseline

**Coverage posture**
- Run covr, report actual coverage percentage, then recommend a specific target (e.g., 80%+ for estimation core)
- Gap identification: overall % plus flag any exported functions with 0% or very low coverage — focused, not a full line-by-line inventory
- `\dontrun`/`\donttest` (15 uses): acknowledge as normal R package practice, flag only if any uses appear unnecessary (soft finding, not a primary gap)

**External testing strategy scope**
- Primary purpose: a decision guide — defines when to use each test type (unit, snapshot, integration), giving contributors a clear policy rather than a gap list
- Snapshot policy: explicit rule — use snapshots for complex formatted outputs (print methods, autoplot output), do NOT use for numeric estimates (use tolerance-based `expect_equal` instead). Prevents snapshot test sprawl.
- Property-based testing: identify the most important domain invariants for creel estimation (SE always positive, harvest >= 0, estimates consistent across equivalent design representations), assess whether a package like `rapidcheck` would be practical, lay groundwork for a future implementation phase

**Named condition classes**
- Outcome: assess and recommend implementation — not just assess-only; make a concrete recommendation
- Specificity: identify 5-10 priority error sites for named classes (e.g., creel_design validation errors, survey type dispatch failures) — gives a future implementation phase a concrete starting list
- Document home: lives in the quality audit document (named conditions are an API contract concern, not a testing concern); testing strategy may cross-reference with a note on how to test named conditions once implemented

**Document format**
- Two separate files, consistent with Phases 72-73:
  - `74-QUALITY-AUDIT.md` — tidyverse/rOpenSci quality checklist audit
  - `74-TESTING-STRATEGY.md` — external testing strategy
- Both in `.planning/phases/74-quality-bar-assessment/`
- Named, prioritised recommendations at end of each document
- Positive findings alongside gaps — flag healthy patterns to preserve
- Tone: technically rigorous but accessible to fisheries biologists (carry forward from Phases 71-73)

### Claude's Discretion
- Exact section headings and document structure within each report
- Whether to include an executive summary at the top of each document
- How to handle findings that span both documents (assign to most relevant, cross-reference if needed)
- The specific coverage target recommendation (e.g., 80% overall, 90% for estimation core) — based on actual covr output
- Which specific functions constitute the 5-10 priority named condition sites

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 74 produces two planning documents: a quality checklist audit and an external testing strategy. Both are pure analysis — no code changes. The audit assesses tidycreel v1.3.0 against tidyverse design principles and rOpenSci peer review requirements, using a Pass/Partial/Fail verdict per item. The testing strategy defines when to use each test type (unit, snapshot, integration, property-based) as a decision guide for contributors.

The package's observable state is strong: 70 exported functions, 130 man pages, 22 vignettes, 58+ test files (~1,536 test blocks), a pkgdown site, lintr configured, codecov integrated, R CMD check passing, CODE_OF_CONDUCT, CONTRIBUTING, MIT license, and ORCID-attributed authorship. The primary quality gaps identified by prior phases are: `lifecycle` badge is "experimental" (not `stable`), the codecov threshold is non-enforcing (1% informational), 0 `expect_snapshot` calls despite 15+ print/format/autoplot methods, and no named condition classes on any `cli_abort` call.

**Primary recommendation:** Perform the audit by direct code inspection using the tidyverse and rOpenSci checklists as the scoring rubric. The audit document writes itself from what is already known about the codebase; the testing strategy codifies existing practice and extends it with the snapshot policy and property-based invariant list.

---

## Tidyverse Quality Checklist — What to Audit

Source: [Tidy design principles](https://design.tidyverse.org/) and [Tidy tools manifesto](https://tidyverse.tidyverse.org/articles/manifesto.html)

### Naming Conventions
| Item | Evidence in tidycreel |
|------|----------------------|
| snake_case for all exported names | All 70 exports follow snake_case |
| Verb_noun function names | `estimate_effort()`, `add_counts()`, `validate_design()` — consistent |
| Data argument first (pipe-friendly) | All layer-1+ functions accept `design` or `data` as first arg |
| Consistent argument names across related functions | `variance`, `conf_level`, `by` used consistently across estimators |

### Output Consistency
| Item | Evidence |
|------|----------|
| Typed S3 objects, not bare lists | All estimator outputs are classed (`creel_estimates`, `creel_design`, etc.) |
| Type-stable returns | Each function family returns the same class regardless of input variation |
| Invisible return for side-effect functions | `write_schedule()`, `write_estimates()` use invisible — needs verification |

### Error Handling
| Item | Evidence |
|------|----------|
| `cli::cli_abort()` for errors | 368 calls across 30+ files — canonical |
| `cli::cli_warn()` for warnings | Present; one approved exception using `rlang::warn(.frequency='once')` |
| `cli::cli_inform()` for messages | Used for verbose dispatch messaging |
| Error messages name the bad argument/value | `{.arg}`, `{.val}`, `{.fn}` inline markers used throughout |
| Named condition classes | ABSENT — zero `class =` arguments on any `cli_abort` call |

### Documentation
| Item | Evidence |
|------|----------|
| roxygen2 throughout | Yes |
| All exported functions documented | 130 man pages for 70 exports (some multi-function pages) |
| Examples for all exported functions | 15 `\dontrun{}` uses — see below |
| At least one vignette | 22 vignettes covering all survey types |
| Package-level `?tidycreel` doc | `tidycreel-package.R` exists |
| `@family` cross-references | Needs inspection |

### Lifecycle
| Item | Evidence |
|------|----------|
| `lifecycle` package used | README badge shows "experimental" — `lifecycle` package is not in Imports/Suggests |
| Functions marked with lifecycle stage | No `@lifecycle` roxygen tags observed — badge is README-only, cosmetic |

---

## rOpenSci Quality Checklist — Aspirational Delta Items

Source: [rOpenSci Packaging Guide](https://devguide.ropensci.org/pkg_building.html) and [Review Template](https://devguide.ropensci.org/reviewtemplate.html)

The items below are where rOpenSci raises the bar beyond tidyverse baseline. Items already covered by the tidyverse section are not repeated.

### Coverage Gate
- rOpenSci minimum: **75% code coverage before review**
- Current state: codecov configured but threshold is 1% informational-only (`.codecov.yml` not found at root; `codecov.yml` present but permissive)
- Action required: run `covr::package_coverage()` and report actual %

### CI and Platform Coverage
- rOpenSci requires passing `R CMD check` on Windows, macOS, Linux
- Current state: GitHub Actions R-CMD-check badge present in README — likely covers multiple platforms; needs inspection of `.github/workflows/`

### README Badges
- rOpenSci expects: CI status, coverage, repo lifecycle
- Current state: R-CMD-check badge (pass), pkgdown badge, License badge, Lifecycle badge — no codecov badge visible in README

### DESCRIPTION Quality
- rOpenSci checks: Title in Title Case, Description not starting with "This package", URLs in angle brackets, single quotes around software names
- Current state: Title "Tidy Interface for Creel Survey Design and Analysis" — Title Case present; Description "Provides a tidy, pipe-friendly interface..." — does not start with "This package" or "In R" — compliant

### Community Files
- CONTRIBUTING.md: present and substantive (full workflow documented)
- CODE_OF_CONDUCT.md: present (Contributor Covenant)
- Issue templates: referenced in CONTRIBUTING.md

### Citation
- rOpenSci expects: `CITATION` file using `bibentry()` (not deprecated `citEntry()`)
- Current state: `CITATION.cff` present (CFF format); no `inst/CITATION` R-style file found — CFF is fine for GitHub but rOpenSci review expects `inst/CITATION`

### `codemeta.json`
- rOpenSci recommends codemeta.json (CodeMeta standard)
- Current state: `codemeta.json` present at root — PASS, but version field shows `0.0.0.9000` (stale, not updated to v1.3.0)

### NEWS.md
- rOpenSci requires a NEWS.md or NEWS file
- Current state: `NEWS.md` present with v1.3.0 entries — PASS

### Peer-Review Scope Assessment
- tidycreel is in-scope for rOpenSci (statistical methodology, fisheries biology, data lifecycle)
- No equivalent package in rOpenSci registry (specialty creel survey workflow)

---

## Named Condition Classes — Priority Sites for the Audit Document

Source: direct code inspection of `creel-design.R` (3,424 lines, 83 `cli_abort` calls) and `creel-estimates.R` (3,700 lines, 46+ `cli_abort` calls)

These are the 5-10 priority error sites where named classes would be most valuable for programmatic catching by downstream users (e.g., tidycreel.connect):

1. **`creel_error_invalid_survey_type`** — `creel_design.R` ~line 291: enum guard rejecting unknown `survey_type` values. The most likely error a companion package would need to catch.

2. **`creel_error_missing_survey_design`** — `creel-estimates.R` ~line 388: "No survey design available — call add_counts before estimating effort." Downstream orchestration code needs to distinguish this from data errors.

3. **`creel_error_invalid_input`** — bus_route validation block in `creel_design.R` ~lines 302-360: missing `sampling_frame`, missing `p_site`, missing `site` column. High-frequency user errors that a validation layer would want to catch as a class.

4. **`creel_error_dispatch_unsupported`** — `creel-estimates.R` ~line 398: "Expanded effort targets not yet supported for bus_route/ice designs." Capability gap errors that downstream code needs to route around.

5. **`creel_error_single_psu`** — single-PSU strata re-raise in `creel-estimates.R` ~line 23. Already structured as a deliberate re-raise; adding a class here enables `tryCatch(., creel_error_single_psu = ...)` in robust pipelines.

6. **`creel_error_missing_data`** — "Bus-route effort estimation requires interview data" ~line 460 in `creel-estimates.R`. Pattern repeats across multiple survey types.

7. **`creel_error_schema_validation`** — `validate-schemas.R` and `creel-schema.R`: schema contract violations. The creel.connect investigation (Phase 73-02) found the schema contract is production-quality — named classes here would complete the API contract.

8. **`creel_error_design_validation`** — `validate_creel_data()` / `design-validator.R`: validation failures should be catchable as a class family rather than only as generic `rlang_error`.

All eight sites use `cli::cli_abort()` already — adding `class = "creel_error_*"` is a one-argument addition per call site. No structural change required.

---

## Testing Strategy — What to Document

### Current Test Infrastructure State
| Property | Value |
|----------|-------|
| Framework | testthat 3.x (`Config/testthat/edition: 3` in DESCRIPTION) |
| Test files | 58 active files in `tests/testthat/` |
| Test blocks | ~1,536 (from CONTEXT.md) |
| Snapshot infrastructure | `_snaps/` directory present but **zero `expect_snapshot()` calls** — infrastructure is empty |
| Helper files | `helper-db.R` for DBI/duckdb integration test helpers |
| Problem archive | `_problems/` contains 17 regression test files for historical issue tracking |

Key finding: the `_snaps/` directory exists but is unused. The testing strategy will define the policy for adopting snapshots going forward (print/format/autoplot output), not just describe existing practice.

### Test Type Decision Guide

**Unit tests (current practice)**
- What: individual functions with controlled inputs and known expected outputs
- When: all estimation functions, all validation functions, all design constructors, all data prep functions
- Pattern: `testthat::test_that("description", { ... expect_equal(..., tolerance = ...) })`
- Numeric tolerance: use `expect_equal(actual, expected, tolerance = 1e-6)` for floats — never exact equality on estimates

**Snapshot tests (to be adopted)**
- What: `expect_snapshot()` captures text output for regression testing
- When: print methods, format methods, autoplot output (via vdiffr), complex multi-line error messages
- When NOT: numeric estimates, data frame values, any quantity that should use tolerance-based comparison
- Target methods for snapshot adoption:
  - `print.creel_design` / `format.creel_design` — complex multi-section output
  - `print.creel_estimates_mor` / `format.creel_estimates_mor`
  - `print.creel_schedule` / `format.creel_schedule`
  - `autoplot.creel_estimates`, `autoplot.creel_schedule`, `autoplot.creel_length_distribution` — via vdiffr

**Integration tests (existing pattern, unnamed)**
- What: end-to-end workflows: design construction → add_counts → estimate_effort → add_interviews → estimate_catch_rate
- When: any test that exercises multiple public functions in sequence
- Current practice: many test files already do this (e.g., `test-creel-design.R` constructs full designs); the strategy names and codifies this type

**Property-based testing (future groundwork)**
- R package options: `quickcheck` (on CRAN, wraps `hedgehog`, integrates with testthat) — NOT `rapidcheck` (which is C++ only, not an R package)
- Key creel domain invariants to document for future implementation:
  1. SE is always > 0 when n_sampled > 1
  2. Harvest estimate >= 0 for non-negative catch inputs
  3. Effort estimates are consistent when equivalent design representations are used (e.g., ice as degenerate bus_route)
  4. CV = SE / estimate (when estimate > 0)
  5. Confidence interval width scales with SE (CI_upper - CI_lower proportional to SE)
  6. Stratum totals sum to period total under additive designs
- Assessment: `quickcheck` is practical — it integrates with testthat and handles numeric generators. However, the domain setup cost (generating valid `creel_design` objects with random but valid inputs) is non-trivial. Recommend Phase 75 or v1.4.0 as the implementation slot, not Phase 74.

### Testing Named Conditions (cross-reference item)
Once named condition classes are implemented (per the quality audit recommendation), tests should change from:
```r
expect_error(creel_design(bad_input), "survey_type.*not recognized")
```
to:
```r
expect_error(creel_design(bad_input), class = "creel_error_invalid_survey_type")
```
The class-based form is more robust — message text can change, class names should be stable API.

---

## `\dontrun{}` Assessment

15 uses across 10 files. By file:

| File | Uses | Justification |
|------|------|---------------|
| `data.R` | 3 | Large dataset construction examples — appropriate (`\dontrun`) |
| `autoplot-methods.R` | 1 | Plotting side effects — normal |
| `compare-designs.R` | 1 | Multi-object construction — normal |
| `creel-estimates-aerial-glmm.R` | 1 | lme4 computation heavy — appropriate |
| `creel-summaries.R` | 1 | Side-effect output — normal |
| `est-effort-camera.R` | 1 | External data dependency — appropriate |
| `hybrid-design.R` | 1 | Complex multi-step example — borderline; could be `\donttest` |
| `schedule-print.R` | 1 | Printing side effect — normal |
| `season-summary.R` | 1 | Multi-step workflow — borderline |
| `validation-report.R` | 1 | Output side effect — appropriate |

Verdict: all 15 uses are defensible. The `hybrid-design.R` and `season-summary.R` cases could be changed from `\dontrun` to `\donttest` (which runs in `devtools::test()` but not CRAN checks) — soft finding only.

---

## Code Coverage — What the Audit Needs

The audit must run `covr::package_coverage()` and report the actual percentage. The recommendations section should propose targets. Based on rOpenSci's 75% minimum and the package's maturity:

**Recommended targets to propose in the audit:**
- Overall: 80% (exceeds rOpenSci minimum, achievable given 1,536 test blocks)
- Estimation core (`creel-estimates*.R`): 85% — these functions carry the statistical contract
- Validation layer (`validate-*.R`, `design-validator.R`): 90% — validation failures must be reliably covered
- Scheduling layer: 75% — lower bar acceptable; scheduling functions are compositional with fewer edge cases
- Print/format methods: covered by proposed snapshot adoption

**Zero-coverage flags:** The audit should identify exported functions with no test coverage at all. Candidates based on complexity and test file inspection:
- `preprocess_camera_timestamps()` — niche workflow, confirm coverage
- `as_hybrid_svydesign()` — `test-hybrid-design.R` exists, but coverage depth unknown
- `new_creel_schedule()` — exported constructor; may only be exercised indirectly

---

## Existing Healthy Patterns to Flag (Positive Findings)

The audit should document these as patterns to preserve, consistent with the Phase 72 approach:

1. **cli_abort consistency** — 368 calls, uniform named-vector structure, `{.arg}` / `{.val}` / `{.fn}` markers throughout. Contributor-ready convention.
2. **Caller-environment propagation** — `error_call = rlang::caller_env()` pattern established across all major estimation entry points. Errors surface at user call frame.
3. **Typed S3 return values** — every public function returns a classed object, never a bare list. Downstream code can reliably use `inherits()`.
4. **Multi-platform CI** — R-CMD-check runs on GitHub Actions; badge confirms current status.
5. **22 vignettes** — comprehensive coverage of all survey types with worked examples.
6. **lintr configured** — 120-char line length, excludes test/data-raw/inst directories appropriately.
7. **checkmate batch-validation** — deliberate batch error collection in validation functions (documented in Phase 73-01 as intentional, not a deviation).
8. **pkgdown site** — live documentation site with reference, articles, and news.

---

## Architecture Patterns (for document structure)

### Established format (from Phases 72-73)
Both output documents follow this structure based on Phases 72-73 precedent:
- Executive summary with overall verdict
- Evidence-based findings table (with severity or verdict)
- Detailed findings with evidence, rationale, and recommendation
- Positive findings / healthy patterns section
- Prioritised recommendations section at the end

### Document assignment
- Named condition classes → QUALITY-AUDIT.md (API contract concern)
- Coverage analysis → QUALITY-AUDIT.md
- `\dontrun` assessment → QUALITY-AUDIT.md
- Snapshot policy → TESTING-STRATEGY.md
- Property-based testing groundwork → TESTING-STRATEGY.md
- Cross-references between documents where findings span both

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Code coverage measurement | Custom counting logic | `covr::package_coverage()` | Handles R's lazy eval and namespace correctly |
| Snapshot testing | Custom file-comparison helpers | `testthat::expect_snapshot()` | Built-in testthat 3.x feature, manages snapshot files automatically |
| Plot snapshot testing | `expect_snapshot(print(autoplot(...)))` | `vdiffr::expect_doppelganger()` | Pixel-aware comparison for ggplot outputs |
| Property-based test generators | Manual random input construction | `quickcheck` package | Integrates with testthat, handles R types correctly |

---

## Common Pitfalls

### Pitfall 1: Snapshot Test Sprawl
**What goes wrong:** Snapshots adopted for numeric outputs; tests fail whenever rounding or floating-point representation changes, producing false positives.
**Why it happens:** `expect_snapshot()` is convenient; developers use it for everything.
**How to avoid:** Explicit policy: snapshots for formatted text output ONLY. Tolerance-based `expect_equal` for all numeric quantities.
**Warning signs:** Snapshot files containing numeric values or data frame cells.

### Pitfall 2: `class =` Missing from `expect_error()` After Adding Named Conditions
**What goes wrong:** Tests use `expect_error(fn(), "regex")` — message-matching tests break whenever error message wording is improved.
**How to avoid:** When named condition classes are added, update existing tests to use `class =` form at the same time.

### Pitfall 3: `\dontrun{}` on Examples that Could Run
**What goes wrong:** Examples that work fine are wrapped in `\dontrun{}`, so they are never exercised and can drift out of sync with the API.
**How to avoid:** Use `\donttest{}` when the example is slow or has side effects but is otherwise runnable. Reserve `\dontrun{}` for examples requiring external dependencies, credentials, or interactive input.

### Pitfall 4: Coverage Number Without Coverage Intelligence
**What goes wrong:** High overall % masks 0% coverage on key estimation paths because simple utility functions inflate the number.
**How to avoid:** Report overall % PLUS flag any exported functions with 0% or near-0% coverage separately.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `stop()` / `warning()` for errors | `cli::cli_abort()` / `cli::cli_warn()` with formatted messages | Consistent, styled, actionable errors |
| `stop(e)` re-raise | Preserved as intentional tryCatch idiom (D1/D2, Phase 73) | Must not be changed to cli_abort |
| Unnamed condition classes | Named classes via `class =` argument to `cli_abort` | Enables programmatic error handling in downstream packages |
| No snapshot tests | `expect_snapshot()` (testthat 3.x) | Regression testing for complex formatted output |
| `quickcheck` (hedge hog wrapper) on CRAN | Available as the R property-based testing option | rapidcheck is C++ only, not available in R |

---

## Open Questions

1. **Actual covr coverage percentage**
   - What we know: 1,536 test blocks, 58 test files — likely high but unconfirmed
   - What's unclear: which exported functions have 0% coverage; whether estimation core reaches 85%
   - Recommendation: the PLAN task for the audit document must run `covr::package_coverage()` as its first action and report actual numbers before writing coverage-related verdict lines

2. **GitHub Actions platform matrix**
   - What we know: R-CMD-check badge passes; workflow file not read
   - What's unclear: whether check runs on Windows + macOS + Linux (rOpenSci requires all three)
   - Recommendation: read `.github/workflows/R-CMD-check.yaml` early in the PLAN task

3. **`@family` tag coverage**
   - What we know: pkgdown site builds successfully
   - What's unclear: whether related functions are cross-referenced with `@family` in roxygen
   - Recommendation: grep for `@family` in `R/` as part of the audit task; note any function families lacking cross-references

---

## Validation Architecture

> `workflow.nyquist_validation` is absent from `.planning/config.json` — treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.x (`Config/testthat/edition: 3`) |
| Config file | `DESCRIPTION` (`Config/testthat/edition: 3`) |
| Quick run command | `devtools::test(filter = "package")` |
| Full suite command | `devtools::test()` |

### Phase Requirements → Test Map

Phase 74 produces only `.planning/` documents — no code changes. There are no testable behaviors to automate. The validation for this phase is:
- Both output files (`74-QUALITY-AUDIT.md`, `74-TESTING-STRATEGY.md`) exist at the expected paths
- Each document contains the required sections (executive summary, verdict table, positive findings, prioritised recommendations)
- Coverage percentage is reported (not a pass/fail gate — a measurement)

This is a manual verification phase. No Wave 0 test gaps.

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements (phase produces documents, not code).

---

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `NAMESPACE` (70 exports), `DESCRIPTION`, `R/*.R` (38 files, ~21,000+ lines), `tests/testthat/` (58 test files), `vignettes/` (22 vignettes)
- [rOpenSci Packaging Guide](https://devguide.ropensci.org/pkg_building.html) — testing requirements, coverage threshold (75%), documentation standards
- [rOpenSci Review Template](https://devguide.ropensci.org/reviewtemplate.html) — checklist categories
- Phase 72 ARCH-REVIEW.md and Phase 73 ERROR-STRATEGY.md — prior findings on error handling, S3 patterns, dependency posture

### Secondary (MEDIUM confidence)
- [Tidy design principles](https://design.tidyverse.org/) — naming conventions, output consistency, error handling principles
- [Tidy tools manifesto](https://tidyverse.tidyverse.org/articles/manifesto.html) — four core principles (human-centered, consistent, composable, inclusive)
- [quickcheck CRAN](https://cran.r-project.org/package=quickcheck) — confirmed as R property-based testing package (hedgehog wrapper, testthat integration); confirmed `rapidcheck` is C++ only

### Tertiary (LOW confidence)
- rOpenSci coverage threshold: 75% stated in current devguide; specific targets for estimation vs. validation layers (85%, 90%) are research recommendations, not rOpenSci mandates

---

## Metadata

**Confidence breakdown:**
- Tidyverse checklist items: HIGH — all verdicts based on direct code inspection
- rOpenSci aspirational delta items: HIGH for checklist structure; MEDIUM for coverage targets (75% minimum is authoritative; higher targets for sub-layers are recommendations)
- Named condition class sites: HIGH — line numbers confirmed by inspection
- Property-based testing options: HIGH for quickcheck availability; MEDIUM for practical assessment (depends on actual generator complexity for creel_design objects)
- Current test snapshot state: HIGH — zero `expect_snapshot()` calls confirmed by grep

**Research date:** 2026-04-18
**Valid until:** 2026-06-18 (rOpenSci devguide stable; testthat API stable)
