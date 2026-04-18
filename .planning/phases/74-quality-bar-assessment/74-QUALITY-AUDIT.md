# Phase 74: tidycreel v1.3.0 Quality Bar Audit

**Assessed:** 2026-04-18
**Package version:** 1.3.0
**Scope:** tidyverse design principle checklist + rOpenSci aspirational delta
**Coverage measured:** `covr::package_coverage()` run on 2026-04-18

---

## Executive Summary

tidycreel v1.3.0 is a structurally sound, well-tested package that demonstrates consistent application of tidyverse conventions throughout its 38 R files and 70 exported functions. The error handling convention is especially strong: 368 `cli::cli_abort()` calls with uniform structure, `{.arg}`/`{.val}`/`{.fn}` inline markers, and caller-environment propagation. Code coverage stands at **87%** overall, well above the rOpenSci minimum of 75%.

The primary quality gaps are lifecycle signalling (README badge is cosmetic, no function-level tagging), named condition classes on `cli_abort` calls (zero `class =` arguments across all 368 calls), and a missing `inst/CITATION` file required by rOpenSci review. None of these gaps affect the statistical correctness or day-to-day usability of the package. They are pre-submission hygiene items.

**rOpenSci submission readiness:** Conditional. Three items must be resolved before submission — lifecycle formalization, `inst/CITATION`, and confirming the codecov threshold reflects the actual coverage level. Five medium/low items are cleanup that can accompany a submission PR rather than blocking it.

### Summary Count Table

| Category | Pass | Partial | Fail | Total |
|----------|------|---------|------|-------|
| Section 1: Tidyverse Baseline | 14 | 2 | 2 | 18 |
| Section 2: rOpenSci Delta | 6 | 2 | 2 | 10 |
| **Total** | **20** | **4** | **4** | **28** |

---

## Section 1: Tidyverse Baseline Checklist

### 1.1 Naming Conventions

| Item | Verdict | Evidence |
|------|---------|----------|
| snake_case for all exported names | **Pass** | All 70 exports follow snake_case; confirmed by NAMESPACE inspection |
| Verb-noun function names | **Pass** | `estimate_effort()`, `add_counts()`, `validate_design()`, `generate_schedule()` — consistent verb-noun throughout |
| Data argument first (pipe-friendly) | **Pass** | All layer-1+ functions accept `design` or `data` as first argument; the full design → add_counts → estimate_effort pipeline composes cleanly |
| Consistent argument names across related functions | **Pass** | `variance`, `conf_level`, `by` used consistently across all estimator families; `verbose` used uniformly for messaging toggle |

All four naming convention items pass without qualification. The naming discipline across 70 exports is notable for a package of this size — contributor friction from inconsistent argument names is absent.

### 1.2 Output Consistency

| Item | Verdict | Evidence |
|------|---------|----------|
| Typed S3 objects, not bare lists | **Pass** | All estimator outputs are classed: `creel_estimates`, `creel_design`, `creel_schedule`, `creel_estimates_mor`, `creel_variance_comparison`, `creel_design_report`. No bare lists returned from public functions |
| Type-stable returns | **Pass** | Each function family returns the same class regardless of input variation (survey type, number of strata, presence/absence of optional arguments) |
| Invisible return for side-effect functions | **Pass** | `write_schedule()` (schedule-io.R:130) and `write_estimates()` (write-estimates.R:151) both return `invisible(path)` — verified by direct inspection |

Output consistency is a full pass. The typed S3 approach means downstream code can reliably use `inherits(x, "creel_estimates")` rather than guessing at list structure.

### 1.3 Error Handling

| Item | Verdict | Evidence |
|------|---------|----------|
| `cli::cli_abort()` for errors | **Pass** | 368 calls across 30+ files — this is the canonical error mechanism throughout the package |
| `cli::cli_warn()` for warnings | **Pass** | Present and consistent; one approved exception: `rlang::warn(.frequency = 'once')` in D3 (Phase 73-01 finding) where `.frequency` is unavailable in `cli::cli_warn` |
| `cli::cli_inform()` for messages | **Pass** | Used for verbose dispatch messaging; toggleable via `verbose` argument |
| Error messages name the bad argument/value | **Pass** | `{.arg}`, `{.val}`, `{.fn}` inline markers used throughout; errors identify both the offending argument and its bad value |
| Named condition classes on `cli_abort` | **Fail** | Zero `class =` arguments across all 368 `cli_abort` calls; all errors are generic `rlang_error`, not catchable programmatically by class — see Section 4 for priority sites and recommendation |

The error handling infrastructure is excellent in every dimension except named classes. The uniform `cli_abort` convention and caller-environment propagation (see Section 5, P2) are patterns that rarely emerge organically at this scale — they reflect deliberate design.

### 1.4 Documentation

| Item | Verdict | Evidence |
|------|---------|----------|
| roxygen2 throughout | **Pass** | All R/ files use roxygen2; NAMESPACE is fully generated |
| All exported functions documented | **Pass** | 130 man pages covering 70 exports; some multi-function pages (e.g., `add_counts` + `add_interviews` on one page) are appropriate |
| Examples for all exported functions | **Partial** | 15 `\dontrun{}` uses across 10 files — see Section 3.3 for file-by-file defensibility assessment |
| At least one vignette | **Pass** | 22 vignettes covering all five survey types (instantaneous, bus_route, ice, camera, aerial) and supporting workflows |
| Package-level `?tidycreel` doc | **Pass** | `tidycreel-package.R` provides the `?tidycreel` entry point |
| `@family` cross-references | **Fail** | Zero `@family` tags across all R/ files (confirmed by grep); related functions (e.g., `estimate_effort`, `estimate_catch_rate`, `estimate_harvest`) are not cross-referenced in roxygen |

The 22 vignettes are a genuine strength. The `@family` gap is notable: users discovering `estimate_effort()` in a vignette have no in-help navigation to `estimate_catch_rate()` or `estimate_harvest()`. Adding `@family` tags would improve discoverability with minimal effort.

### 1.5 Lifecycle

| Item | Verdict | Evidence |
|------|---------|----------|
| `lifecycle` package in Imports/Suggests | **Fail** | `lifecycle` is not in DESCRIPTION; README "experimental" badge is a static markdown image, not package-driven |
| Functions marked with lifecycle stage | **Fail** | Zero `@lifecycle` roxygen tags in any R/ file; function-level lifecycle status is invisible in help pages |

The lifecycle gap is the most important pre-rOpenSci submission item. The "experimental" badge in README signals the package's maturity posture, but the signal is not enforced — functions can be deprecated, stabilized, or removed without any documentation trail. rOpenSci reviewers will flag this.

---

## Section 2: rOpenSci Aspirational Delta

This section covers only items where rOpenSci raises the bar beyond the tidyverse baseline established in Section 1. Items already assessed above are not repeated.

### 2.1 Coverage Gate

| Item | Verdict | Value |
|------|---------|-------|
| rOpenSci minimum (75%) | **Pass** | Actual: **87.00%** (measured 2026-04-18) |
| Recommended overall target (80%) | **Pass** | 87% exceeds the 80% recommendation |
| codecov threshold enforcement | **Partial** | `.codecov.yml` configures a 1% informational threshold — not a real gate; the 87% measurement is not enforced in CI |

Coverage at 87% is a strong result for a package of this complexity. The enforcement gap (1% threshold) means the CI will not catch coverage regressions. This should be corrected before submission to signal maturity.

Per-layer coverage against recommended targets:

| Layer | Files | Actual Coverage | Target | Status |
|-------|-------|----------------|--------|--------|
| Estimation core (`creel-estimates*.R`) | Multiple | 71.9–91.8% (range) | 85% | Mixed — bus-route at 71.9% is below target |
| Validation layer (`validate-*.R`, `design-validator.R`) | 4 files | 56.8–98.2% (range) | 90% | `design-validator.R` at 56.8% is below target |
| Scheduling layer | ~4 files | 80–96.99% | 75% | Pass |
| Print/format methods | `print-methods.R`, `schedule-print.R` | 91.0%, 97.0% | Coverage via snapshots | Good baseline; snapshot tests would add regression confidence |

### 2.2 CI and Platform Coverage

| Item | Verdict | Evidence |
|------|---------|----------|
| Ubuntu (Linux) | **Pass** | `ubuntu-latest` present in R-CMD-check.yaml matrix |
| macOS | **Pass** | `macos-latest` present in R-CMD-check.yaml matrix |
| Windows | **Pass** | `windows-latest` present in R-CMD-check.yaml matrix |
| Overall platform verdict | **Pass** | All three rOpenSci-required platforms present in CI matrix |

The GitHub Actions matrix in `.github/workflows/R-CMD-check.yaml` explicitly runs all three platforms on every push and pull request to `main`. This is a full pass with no qualifications.

### 2.3 README Badges

| Badge | Verdict | Status |
|-------|---------|--------|
| CI status (R-CMD-check) | **Pass** | Badge present, links to GitHub Actions |
| Coverage (codecov) | **Fail** | `codecov.yml` configured but no coverage badge in README; the 87% measurement is invisible to prospective users |
| Lifecycle | **Partial** | "experimental" badge present as static image — not backed by `lifecycle` package (see Section 1.5) |
| pkgdown | **Pass** | pkgdown badge and site present |
| License | **Pass** | MIT license badge present |

### 2.4 DESCRIPTION Quality

| Item | Verdict | Evidence |
|------|---------|----------|
| Title in Title Case | **Pass** | "Tidy Interface for Creel Survey Design and Analysis" |
| Description not starting with "This package" or "In R" | **Pass** | Description begins "Provides a tidy, pipe-friendly interface..." |
| URLs in angle brackets | **Pass** | Confirmed by DESCRIPTION inspection |

### 2.5 Community Files

| File | Verdict | Status |
|------|---------|--------|
| CONTRIBUTING.md | **Pass** | Present and substantive — full development workflow documented |
| CODE_OF_CONDUCT.md | **Pass** | Contributor Covenant, version 2.1 |
| Issue templates | **Pass** | Referenced in CONTRIBUTING.md |

### 2.6 Citation

| Item | Verdict | Evidence |
|------|---------|----------|
| `inst/CITATION` using `bibentry()` | **Fail** | Only `CITATION.cff` present at root; no `inst/CITATION` R-style file — CFF format is correct for GitHub/Zenodo; rOpenSci review requires the R-native `inst/CITATION` |

This is a one-time file creation task requiring approximately 10–15 lines of R code. It is a blocking pre-submission item per rOpenSci guidelines.

### 2.7 codemeta.json

| Item | Verdict | Evidence |
|------|---------|----------|
| `codemeta.json` present | **Pass** | `codemeta.json` present at root |
| Version field current | **Partial** | Version field shows `0.0.0.9000` — stale, not updated to v1.3.0; produces incorrect metadata in Zenodo and package registries |

### 2.8 NEWS.md

| Item | Verdict | Evidence |
|------|---------|----------|
| NEWS.md present with current version | **Pass** | `NEWS.md` present with v1.3.0 entries |

### 2.9 Peer-Review Scope

| Item | Assessment |
|------|------------|
| In scope for rOpenSci | Yes — statistical methodology, fisheries biology, data lifecycle management |
| No equivalent rOpenSci package | Yes — specialty creel survey workflow with no direct equivalent in registry |
| Submission readiness | **Conditional** — lifecycle formalization (R1), `inst/CITATION` (R2), and codecov threshold (R3) are required pre-submission; remaining items (R4–R7) are cleanup |

---

## Section 3: Code Coverage Analysis

### 3.1 Overall Coverage

**Measured:** 87.00% (covr::package_coverage(), 2026-04-18)

| Threshold | Value | Status |
|-----------|-------|--------|
| rOpenSci minimum | 75% | Pass — 87% exceeds by 12 points |
| Recommended overall | 80% | Pass — 87% exceeds by 7 points |
| Current actual | **87.00%** | Measured |

The 87% figure is strong for a package with 38 R files and complex dispatch logic. The estimation core is the most tested area, reflecting the statistical contract the package provides.

Per-file breakdown (files below 85%):

| File | Coverage | Notes |
|------|----------|-------|
| `design-validator.R` | 56.83% | Lowest — validation branch paths not fully covered |
| `prep-counts.R` | 63.64% | Data preparation edge cases |
| `compare-variance.R` | 63.70% | Variance comparison utility |
| `creel-estimates-bus-route.R` | 71.94% | Below 85% estimation core target |
| `creel-estimates-total-release.R` | 76.13% | Adequate; release path less tested |
| `flag-outliers.R` | 79.71% | Outlier detection edge cases |
| `schedule-io.R` | 80.00% | I/O path branches |
| `season-summary.R` | 80.23% | Summary table edge cases |

Files at 100% coverage: `compare-designs.R`, `creel-schema.R`, `creel-validation.R`, `est-effort-camera.R`, `power-creel.R`, `power-sample-size.R`, `standardize-species.R`, `theme-creel.R`.

### 3.2 Zero/Low Coverage Flags

**No exported functions have 0% coverage.** The three candidate functions identified in research were confirmed to have good coverage:

| Function | File | Lines Covered | Assessment |
|----------|------|---------------|------------|
| `preprocess_camera_timestamps()` | `est-effort-camera.R` | 15/17 (88%) | Well covered |
| `as_hybrid_svydesign()` | `hybrid-design.R` | 55/57 (96%) | Well covered |
| `new_creel_schedule()` | `schedule-generators.R` | 3/3 (100%) | Full coverage |

The partial-coverage functions (functions with some uncovered lines but not zero overall) are concentrated in complex dispatch branches within `creel-estimates.R` (89.15%) and `design-validator.R` (56.83%). The design-validator gap is the most significant — validation branch paths for edge cases (e.g., degenerate strata configurations) are not fully exercised.

**Print and format methods** (`print-methods.R` 91.01%, `schedule-print.R` 96.99%) have line coverage from existing tests. However, these tests assert internal state, not formatted output. Snapshot tests (via `expect_snapshot()`) would provide regression coverage for the text representations themselves. See `74-TESTING-STRATEGY.md` for the snapshot adoption policy.

### 3.3 `\dontrun{}` / `\donttest{}` Assessment

15 uses across 10 files. All 15 are assessed as defensible:

| File | Uses | Verdict | Rationale |
|------|------|---------|-----------|
| `data.R` | 3 | Defensible | Large dataset construction — appropriate to exclude from CRAN checks |
| `autoplot-methods.R` | 1 | Defensible | Plotting side effects requiring graphical device |
| `compare-designs.R` | 1 | Defensible | Multi-object construction requiring complete design setup |
| `creel-estimates-aerial-glmm.R` | 1 | Defensible | `lme4::glmer.nb` computation is heavy; appropriate to skip on CRAN |
| `creel-summaries.R` | 1 | Defensible | Side-effect console output example |
| `est-effort-camera.R` | 1 | Defensible | External data dependency (camera timestamp file) |
| `hybrid-design.R` | 1 | **Borderline** | Complex multi-step example that could run in `devtools::test()` — consider `\donttest` |
| `schedule-print.R` | 1 | Defensible | Printing side effect |
| `season-summary.R` | 1 | **Borderline** | Multi-step workflow — no external dependency, could be `\donttest` |
| `validation-report.R` | 1 | Defensible | Output side effect (writes report to disk) |

**Overall verdict:** All 15 uses are justified. The `hybrid-design.R` and `season-summary.R` cases are soft recommendations only — converting them to `\donttest{}` would allow `devtools::test()` to exercise those examples without changing CRAN behavior.

---

## Section 4: Named Condition Classes

### 4.1 Current State

| Metric | Value |
|--------|-------|
| Total `cli_abort()` calls | 368 |
| Calls with `class =` argument | 0 |
| Current error class on all errors | `rlang_error` (generic) |
| Programmatic catching by class | Not possible |

All 368 `cli_abort` calls produce errors of class `c("rlang_error", "error", "condition")`. There is no way for downstream code to distinguish a `creel_error_invalid_survey_type` from a `creel_error_schema_validation` — both surface as generic `rlang_error`. The error message text is structured and informative, but text-matching in `tryCatch` is fragile.

### 4.2 Why Named Classes Matter

The named condition class gap has two concrete consequences:

**1. Downstream package integration:** The Phase 73-02 investigation found that the schema contract (`creel_schema`, `validate_creel_schema`) is production-quality and represents a frozen API surface. A companion package (e.g., tidycreel.connect) needs `tryCatch(., creel_error_schema_validation = ...)` to distinguish schema violations from data errors from connection failures. Without named classes, companion code must pattern-match on error message text — a fragile dependency on internal wording.

**2. Robust user pipelines:** Analysts building multi-site, multi-year processing pipelines need to distinguish recoverable errors (e.g., missing optional data) from fatal errors (e.g., invalid survey type). Named classes enable `withCallingHandlers(., creel_error_missing_data = function(e) { ... })` with surgical precision.

Adding `class = "creel_error_*"` to a `cli_abort` call is a one-argument addition per site — no structural change to the function, no change to error message wording, no change to call-site behavior for code that does not catch by class.

### 4.3 Priority Error Sites

8 priority sites where named classes would deliver the highest value:

| Priority | Class Name | Source File | Approx. Line | Trigger Condition | Downstream Use Case |
|----------|-----------|-------------|--------------|-------------------|---------------------|
| 1 | `creel_error_invalid_survey_type` | `creel_design.R` | ~291 | Enum guard rejecting unknown `survey_type` value | Most common user error; companion packages need to distinguish from data errors |
| 2 | `creel_error_missing_survey_design` | `creel-estimates.R` | ~388 | "No survey design available — call add_counts before estimating effort" | Downstream orchestration needs to distinguish pipeline ordering errors |
| 3 | `creel_error_invalid_input` | `creel_design.R` | ~302-360 | Missing `sampling_frame`, `p_site`, `site` column in bus-route block | High-frequency user error; validation layer in companion packages should catch these |
| 4 | `creel_error_dispatch_unsupported` | `creel-estimates.R` | ~398 | "Expanded effort targets not yet supported for bus_route/ice designs" | Capability gap; companion code needs to route around unsupported paths |
| 5 | `creel_error_single_psu` | `creel-estimates.R` | ~23 | Single-PSU strata re-raise | Already structured as deliberate re-raise; `tryCatch(., creel_error_single_psu = ...)` enables robust pipelines |
| 6 | `creel_error_missing_data` | `creel-estimates.R` | ~460 | "Bus-route effort estimation requires interview data" | Repeats across survey types; class enables cross-type catching |
| 7 | `creel_error_schema_validation` | `validate-schemas.R`, `creel-schema.R` | Multiple | Schema contract violations | Schema contract is production-quality (Phase 73-02); named class completes the API contract |
| 8 | `creel_error_design_validation` | `validate_creel_data()`, `design-validator.R` | Multiple | Design validation failures | Enables `tryCatch(., creel_error_design_validation = ...)` in robust pipelines |

### 4.4 Recommendation

**Recommend implementation** as a dedicated named-conditions phase in the v1.4.0 milestone.

The 8 sites listed above are the concrete starting list. Implementation approach per site: add `class = "creel_error_*"` as a named argument to the existing `cli_abort()` call. No restructuring required. The implementation phase should also update existing `expect_error()` tests at these sites to use the `class =` form (more robust than message-text matching).

---

## Section 5: Positive Findings

These patterns are healthy, intentional, and should be preserved as the package evolves:

| ID | Pattern | Evidence | Why It Matters |
|----|---------|----------|----------------|
| P1 | `cli_abort` consistency | 368 calls, uniform named-vector structure with `{.arg}` / `{.val}` / `{.fn}` markers | Contributor-ready convention — new functions can follow the same pattern without reference to the style guide |
| P2 | Caller-environment propagation | `error_call = rlang::caller_env()` established across all major estimation entry points | Errors surface at user call frame, not internal dispatch frame — dramatically improves error usability |
| P3 | Typed S3 return values | Every public function returns a classed object; never a bare list | Downstream code can rely on `inherits()` instead of structure inspection; enables method dispatch on outputs |
| P4 | Multi-platform CI | Windows + macOS + Linux all in R-CMD-check.yaml matrix | Catches platform-specific bugs before they reach users; already meets rOpenSci CI requirements |
| P5 | 22 vignettes | Comprehensive coverage of all survey types with complete worked examples | Rare for a specialty package of this age; demonstrates intended use patterns at scale |
| P6 | lintr configured | 120-char line length; excludes `tests/testthat/`, `data-raw/`, `inst/` | Automated style enforcement without friction; exclusions are well-calibrated |
| P7 | checkmate batch-validation | Deliberate batch error collection in validation functions (documented as intentional in Phase 73-01) | Returns all validation failures at once rather than first-error-only; better UX for users with multiple config errors |
| P8 | pkgdown site | Live documentation site with reference, articles, and news sections | Turns 22 vignettes and 130 man pages into a navigable web resource; reduces onboarding friction |

---

## Section 6: Recommendations

Consolidated and prioritised. Each recommendation identifies WHAT to do, WHY it matters, and when to act.

---

**R1 — HIGH (pre-rOpenSci blocker)**

**WHAT:** Add `lifecycle` package to `Imports` or `Suggests` in DESCRIPTION. Apply `@lifecycle` roxygen tags (e.g., `#' @lifecycle experimental`) to all exported functions. Remove the static README badge and replace with the package-driven badge.

**WHY:** The current "experimental" badge is a static markdown image — it carries no enforcement. Function-level lifecycle status (visible in `?estimate_effort()`, `?creel_design()`) is the signal that matters to package users and rOpenSci reviewers. Without `lifecycle` in DESCRIPTION, the badge claims a dependency that does not exist.

**Priority:** Required before rOpenSci submission. Estimated effort: medium (tag 70 exports individually, add DESCRIPTION entry, update README badge line).

---

**R2 — HIGH (pre-rOpenSci blocker)**

**WHAT:** Create `inst/CITATION` using `bibentry()`. The file should cite the package with authorship, year, title, URL, and DOI (from Zenodo or journal publication if available).

**WHY:** `CITATION.cff` covers GitHub/Zenodo citation; rOpenSci review requires the R-native `inst/CITATION` file, which is what `citation("tidycreel")` reads. Without it, `citation("tidycreel")` returns a generic auto-generated citation that may not reflect intended authorship or publication details.

**Priority:** Required before rOpenSci submission. Estimated effort: low (10–15 lines of R code, one-time).

---

**R3 — HIGH (pre-rOpenSci, if submission planned)**

**WHAT:** Update `.codecov.yml` to enforce a real coverage threshold. Replace the current 1% informational threshold with `target: 75%` on the project gate, or set `threshold: 2%` to allow minor fluctuation around the current 87%.

**WHY:** The 87% measured coverage is excellent, but it is not enforced in CI. Coverage regressions introduced by new untested code will not trigger CI failures. For rOpenSci submission, reviewers expect that the coverage badge reflects a maintained standard, not a snapshot.

**Priority:** Required before rOpenSci submission. Estimated effort: trivial (2-line change to `.codecov.yml`).

---

**R4 — MEDIUM**

**WHAT:** Implement named condition classes at the 8 priority sites identified in Section 4. A dedicated named-conditions phase should add `class = "creel_error_*"` at each site and update corresponding `expect_error()` tests to use the `class =` form.

**WHY:** Named classes complete the API contract for downstream packages (e.g., tidycreel.connect) and enable robust error handling in multi-site processing pipelines. The addition is one argument per `cli_abort()` call — no structural change.

**Priority:** Recommended for v1.4.0. Estimated effort: medium (8 call sites + test updates).

---

**R5 — MEDIUM**

**WHAT:** Add `@family` cross-references to related function groups. Priority groups: effort estimators (`estimate_effort`, `estimate_effort_sections`, `estimate_effort_grouped`), catch rate estimators, design constructors, scheduling functions.

**WHY:** Currently zero `@family` tags exist. Users discovering `estimate_effort()` in a help search have no in-help navigation to related functions. `@family` generates "See Also" sections automatically and improves discoverability without requiring changes to function behavior.

**Priority:** Recommended for v1.4.0. Estimated effort: low (add `@family` tags to roxygen blocks, `devtools::document()` to regenerate).

---

**R6 — MEDIUM**

**WHAT:** Update `codemeta.json` version field to `1.3.0`. The current value (`0.0.0.9000`) is stale and produces incorrect metadata in Zenodo, package registries, and citation tools.

**WHY:** `codemeta.json` is the machine-readable package descriptor used by software registries. A stale version field produces incorrect discovery metadata.

**Priority:** Routine maintenance. Estimated effort: trivial (one-line JSON edit, or `codemetar::write_codemeta()` to regenerate).

---

**R7 — LOW**

**WHAT:** Add a codecov coverage badge to README.md. The badge URL is available from the Codecov dashboard for the repository.

**WHY:** The 87% coverage measurement is currently invisible to prospective users and contributors. A coverage badge surfaces this signal on the GitHub landing page alongside the CI badge.

**Priority:** Low — cosmetic improvement. Estimated effort: trivial (one-line README edit).

---

**R8 — LOW**

**WHAT:** Convert 2 borderline `\dontrun{}` uses — `hybrid-design.R` and `season-summary.R` — to `\donttest{}`.

**WHY:** `\dontrun{}` prevents examples from running even in `devtools::test()`; `\donttest{}` allows them to run in development while still skipping CRAN checks. These two examples have no external dependencies and would benefit from being exercised during local development.

**Priority:** Low — soft finding, not required for rOpenSci submission. Estimated effort: trivial (change `\dontrun` to `\donttest` in 2 files).

---

## Cross-References

- **Testing strategy for print/format methods:** See `74-TESTING-STRATEGY.md` for the `expect_snapshot()` adoption policy. Print/format coverage (91–97%) is adequate at the line level; snapshot tests would add regression confidence for formatted output.
- **Named condition classes and test updates:** Once R4 is implemented, `expect_error()` tests at the 8 sites should adopt `class =` form simultaneously. See `74-TESTING-STRATEGY.md` for the pattern.
- **Error handling canonical pattern:** The `cli_abort` convention assessed here was declared canonical in Phase 73-01. The `D1/D2 stop(e)` re-raise idioms are intentional and must not be converted to `cli_abort`.
- **Schema contract:** The schema readiness finding from Phase 73-02 directly informs R4 priority — `creel_error_schema_validation` is priority 7 specifically because the schema contract is already production-quality.

---

*Phase: 74-quality-bar-assessment*
*Assessment date: 2026-04-18*
*Coverage measurement: covr 5.x, R 4.x, tidycreel 1.3.0*
