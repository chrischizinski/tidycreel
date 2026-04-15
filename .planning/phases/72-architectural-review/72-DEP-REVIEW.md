# tidycreel v1.3.0 — Dependency Review Report

**Phase:** 72 — Architectural Review
**Reviewed:** 2026-04-15
**Scope:** Imports only (Suggests out of scope for this phase)
**Confidence:** HIGH — all findings derived from direct `pkg::` grep counts across all 38 R source files and DESCRIPTION

---

## Executive Summary

tidycreel v1.3.0 carries **11 packages in Imports**. This review covers all 11. The overall dependency surface is healthy: no archived or abandoned packages, no circular dependencies, and the three highest-use dependencies (`cli`, `rlang`, `survey`) are low-risk and irreplaceable. The package depends on the Posit ecosystem for five of its 11 Imports (`cli`, `rlang`, `tibble`, `tidyselect`, `dplyr`) — a deliberate and defensible choice given the tidyverse-style interface.

**Overall verdict: LOW risk.** One immediate action is available that eliminates an entire Import with a one-line code change.

**Key findings:**

| Finding | Package | Priority |
|---------|---------|----------|
| Single-call Import — eliminate immediately | `scales` | HIGH |
| Scheduling/viz-only dependency with base R equivalents | `lubridate` | MEDIUM |
| Visualisation-only dependency; raises architectural question | `ggplot2` | MEDIUM |
| Mixed validation pattern reduces contributor clarity | `checkmate` | LOW |

**Top recommendation (R1):** Drop `scales` from Imports. Replace `scales::percent(pct_truncated, accuracy = 0.1)` at line 1533 of `survey-bridge.R` with `sprintf("%.1f%%", pct_truncated * 100)`. One-line change, one Import eliminated, zero risk.

---

## Risk Criteria

Four risk flags are used throughout this report. A package is rated LOW-MEDIUM or higher when one or more apply:

1. **Abandonment / archival risk** — the package is not actively maintained or faces CRAN-archive risk.
2. **API instability history** — the package has a track record of breaking changes between releases.
3. **Heavy transitive dependency chains** — importing the package pulls many additional packages that themselves add risk.
4. **Tight version floor constraints** — the version floor in DESCRIPTION requires a recent release that may exclude users on older R/CRAN snapshots.

**Drop candidate** means the package can be removed from Imports entirely. Either no call-sites remain after a code change, or the functionality is available in base R or another already-imported package.

**Demote candidate** means the package could be moved from Imports to Suggests. Core estimation and design functionality remains intact without it. Users who want the optional functionality install it on demand; code adds `rlang::check_installed()` guards at the relevant call-sites.

---

## Dependency Inventory

### `cli` — 639 call-sites

**Functions used:** `cli_abort()`, `cli_warn()`, `cli_text()`, `cli_h1()`, `cli_format_method()`
**Files using it:** All layers — prep, design, estimation, scheduling, summaries, validation (33+ files)
**Maintenance:** Actively maintained by Posit. Core tidyverse infrastructure. No archival risk.
**API stability:** The five functions used are among the most stable in the package. No breaking changes in recent versions.
**Transitive deps:** Minimal. `cli` is a lightweight package.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: Cannot drop or demote.** `cli` is the uniform error/warning layer across all 38 source files. Removing it would require replacing 639 call-sites with `stop()` / `warning()`, which would regress error formatting quality and break the consistency documented in the architectural review (Positive Finding P5). Keeping `cli` is correct.

**Risk: LOW**

---

### `stats` — 142 call-sites

**Functions used:** `coef()`, `confint()`, `qt()`, `reformulate()`, `setNames()`, `vcov()`, `aggregate()`, `sd()`, `var()`, `weighted.mean()`, `model.matrix()`, and others
**Files using it:** Estimation layer — `creel-estimates.R`, `survey-bridge.R`, `creel-estimates-aerial-glmm.R`, `creel-estimates-total-*.R`, `power-sample-size.R`, and others
**Maintenance:** Base R package. Ships with every R installation.
**API stability:** Maximally stable. These are canonical statistical functions.
**Transitive deps:** None.
**Version floor:** None specified.

**Drop/demote verdict: Cannot drop or demote.** Base R. These functions are the mathematical foundation of the HT estimator framework.

**Risk: NONE**

---

### `survey` — 87 call-sites

**Functions used:** `svydesign()`, `svytotal()`, `svymean()`, `svyratio()`, `svyby()`, `svycontrast()`, `SE()`, `degf()`, `as.svrepdesign()`, `calibrate()`
**Files using it:** `survey-bridge.R` (primary), `creel-estimates.R`, `creel-estimates-bus-route.R`, `creel-estimates-aerial.R`, `compare-variance.R`
**Maintenance:** Actively maintained by Thomas Lumley (University of Auckland). Consistent CRAN releases. No archival risk.
**API stability:** `svydesign()` / `svytotal()` / `svyratio()` are long-established APIs unchanged across major versions. `SE()` and `degf()` are stable companions.
**Transitive deps:** Moderate — `survey` depends on `Matrix`, `survival`, `mitools`, and others. These are themselves base-adjacent and stable packages, not a concern in practice.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: Cannot drop or demote.** `survey` is the statistical foundation. The Horvitz-Thompson estimator, variance propagation, ratio estimators, and calibration are all `survey` package functionality. Replacing it would mean re-implementing survey statistics from scratch — a years-long effort with high regression risk.

**Risk: LOW**

---

### `ggplot2` — 96 call-sites

**Functions used:** `ggplot()`, `aes()`, `geom_*()`, `scale_*()`, `theme_*()`, `facet_*()`, `labs()`, `autoplot()` (generic registration)
**Files using it:** `autoplot-methods.R`, `compare-designs.R`, `theme-creel.R` — exactly 3 files
**Maintenance:** Actively maintained by Posit. Extremely stable API.
**API stability:** `ggplot2` layers and aesthetics have been stable across versions 3.x. No breaking change risk for the functions used.
**Transitive deps:** Moderate — `ggplot2` carries `scales`, `gtable`, `grid`, `MASS`, and others. Demoting `ggplot2` would automatically remove several transitive dependencies.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: DEMOTE CANDIDATE.** All 96 call-sites are in the visualisation layer (3 files). The core preparation, design, and estimation layers have no `ggplot2` dependencies. Demoting to Suggests would allow users who only need estimation results (e.g., a server workflow producing tables) to install tidycreel without a visualisation stack. The `autoplot` generic itself is registered via `ggplot2::autoplot` in `autoplot-methods.R`, which would require `rlang::check_installed("ggplot2")` guards.

This is an **architectural question, not a maintenance concern.** The package must decide whether visualisation is a core or optional concern. See the Drop/Demote Analysis section.

**Risk: LOW** (dependency health is excellent; the question is architectural scope)

---

### `rlang` — 254 call-sites

**Functions used:** `enquo()` (104), `caller_env()` (70), `quo_is_null()` (65), `eval_tidy()` (7), `check_installed()` (7), `as_name()` (6), `sym()` / `syms()` (6)
**Files using it:** Estimation layer (dominant), design layer, summaries, validation — widespread
**Maintenance:** Actively maintained by Posit. Foundation of tidyverse metaprogramming.
**API stability:** `enquo()`, `quo_is_null()`, and `eval_tidy()` are very stable APIs. `check_installed()` was added in rlang 1.0.0 (2022-01) and is now stable.
**Transitive deps:** `rlang` has no significant transitive dependencies of its own.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: Cannot drop or demote.** The `by =` tidy-selection API used throughout `creel-estimates.R` and `creel-summaries.R` depends on `enquo()` / `eval_tidy()` for NSE. Removing `rlang` would require replacing NSE throughout the estimation API — a major breaking change to the user-facing interface. `caller_env()` (70 call-sites) is used for error context throughout `cli_abort()` calls. `check_installed()` is the package-existence guard used for optional Suggests.

**Risk: LOW**

---

### `tibble` — 63 call-sites

**Functions used:** `tibble()`, `as_tibble()`, `add_column()`
**Files using it:** `creel-estimates.R`, `creel-estimates-*.R` (estimation result constructors, ~15 uses), `creel-design.R`, `creel-summaries.R`, `survey-bridge.R`, and others
**Maintenance:** Actively maintained by Posit. Very stable.
**API stability:** `tibble()` and `as_tibble()` have been stable for years.
**Transitive deps:** Minimal. `tibble` is a lightweight package.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: Not recommended for demotion.** `tibble()` is used in 15+ estimation result constructors in `creel-estimates.R` and the `creel-estimates-*.R` files. The output tibbles carry column type guarantees (no silent type coercion) that `data.frame()` does not provide consistently. Replacing with `data.frame()` is technically possible but medium-effort with low payoff and non-trivial regression risk in output formatting. The dependency is low-risk and appropriate.

**Risk: LOW**

---

### `tidyselect` — 54 call-sites

**Functions used:** `eval_select()` (52), `all_of()` (2)
**Files using it:** `creel-estimates.R`, `creel-summaries.R`, `creel-design.R`, `design-validator.R` — primarily the estimation and design layers
**Maintenance:** Actively maintained by Posit.
**API stability:** `tidyselect >= 1.2.0` floor set in DESCRIPTION. Version 1.2.0 (released 2022-10) introduced a new evaluation model that fixed ambiguous column selection and was a necessary breaking change. The version floor is intentional and appropriate.
**Transitive deps:** Minimal.
**Version floor:** `>= 1.2.0` — this excludes R installations on pre-2022 CRAN snapshots. Given that tidycreel already requires R >= 4.1.0, environments predating tidyselect 1.2.0 are unlikely in practice.

**Drop/demote verdict: Cannot drop or demote.** `eval_select()` is the backbone of the `by =` tidy-selection interface across 52 call-sites in the estimation layer. Removing it would require a complete redesign of how users specify grouping columns.

**Risk: LOW-MEDIUM** — The version floor is tighter than most other dependencies, but the requirement is documented and justified. The R >= 4.1.0 minimum already scopes out the environments most affected.

---

### `checkmate` — 41 call-sites

**Functions used:** `makeAssertCollection()` (8), `assert_*()` (many), `check_*()` (some)
**Files using it:** `creel-design.R`, `survey-bridge.R`, `design-validator.R`, `power-sample-size.R`, `validate-schemas.R` (5 files)
**Maintenance:** Maintained by the mlr3 team (Bernd Bischl et al.). Active on CRAN. No archival risk.
**API stability:** `makeAssertCollection()` is a mature and stable pattern.
**Transitive deps:** Minimal. `checkmate` has few dependencies.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: Not a drop/demote priority.** `checkmate` provides batch validation via `makeAssertCollection()` in the bus-route and ice interview validators (`validate_br_interviews_tier3()` in `creel-design.R` and `validate_ice_interviews_tier3()` in `creel-design.R`). These validators accumulate multiple errors before reporting them together — a pattern that `cli::cli_abort()` does not directly support without custom accumulation logic. The functionality is distinct enough to justify keeping `checkmate` in Imports.

The more notable observation is the **mixed validation pattern**: 5 files use `checkmate`'s collection model while the other 33 files use `cli::cli_abort()` guards. This inconsistency is documented in Recommendation R4 below.

**Risk: LOW**

---

### `dplyr` — 27 call-sites

**Functions used:** `bind_rows()` (11), `left_join()` (7), `all_of()` (3), `count()` (2), `case_when()` (2), `bind_cols()` (2), `across()` (2), `anti_join()` (1), `vars()` (1), `rename_with()` (1)
**Files using it:** `creel-estimates.R`, `creel-estimates-total-catch.R`, `creel-estimates-total-harvest.R`, `creel-estimates-total-release.R`, `creel-design.R`, `compare-variance.R`, `design-validator.R`, `season-summary.R`
**Maintenance:** Actively maintained by Posit.
**API stability:** All functions used are stable core `dplyr` APIs.
**Transitive deps:** Moderate — `dplyr` carries `vctrs`, `lifecycle`, `generics`, and others. These are all Posit-maintained stable packages.
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: Not recommended for demotion.** `dplyr::bind_rows()` (11 call-sites) is in core estimation paths building section-by-section result data frames in `creel-estimates.R` and the total-catch/harvest/release estimators. `dplyr::left_join()` (7 call-sites) is in `creel-design.R` and `creel-estimates.R` for data construction. Base R equivalents (`rbind()` / `merge()`) exist but differ in NA handling, column matching behaviour, and output type consistency. Migrating these would require non-trivial rewrites in critical estimation paths — introducing more risk than the demotion would eliminate.

**Risk: LOW**

---

### `lubridate` — 15 call-sites

**Functions used:** `wday()` (4), `floor_date()` (4), `ymd()` (2), `mday()` (2), `ceiling_date()` (2), `days()` (1)
**Files using it:** `schedule-generators.R`, `autoplot-methods.R`, `schedule-print.R` — exactly 3 files, all in the scheduling and visualisation layers
**Maintenance:** Actively maintained by Posit. Stable.
**API stability:** The 6 functions used are all stable. No breaking changes in recent versions.
**Transitive deps:** `lubridate` carries `timechange` and `generics`. Lightweight.
**Version floor:** `>= 1.9.0` specified in DESCRIPTION. Version 1.9.0 (2023-01) introduced the `timespan` class and changed some period arithmetic defaults. The floor is reasonable but relatively recent.

**Drop/demote verdict: DEMOTE CANDIDATE (medium priority).** All 15 call-sites are in the scheduling and visualisation layers — no lubridate appears in prep, design, or estimation code. The 6 functions used all have base R equivalents:

| lubridate function | Base R equivalent |
|---|---|
| `lubridate::ymd(x)` | `as.Date(x)` (for standard format strings) |
| `lubridate::wday(x)` | `as.POSIXlt(x)$wday + 1` |
| `lubridate::floor_date(x, "month")` | `as.Date(format(x, "%Y-%m-01"))` |
| `lubridate::ceiling_date(x, ...)` | custom expression depending on unit |
| `lubridate::mday(x)` | `as.integer(format(x, "%d"))` |
| `lubridate::days(n)` | `as.difftime(n, units = "days")` |

The substitutions require ~15 careful replacements. The week-start convention in `wday()` (Sunday = 1 by default in lubridate) must be matched precisely in any base R replacement. The `>= 1.9.0` version floor is the primary motivation for tracking this: a future scheduling refactor would be the natural time to fold in `lubridate` removal. See the Drop/Demote Analysis section.

**Risk: LOW-MEDIUM**

---

### `scales` — 1 call-site

**Function used:** `percent()` — one call at `survey-bridge.R` line 1533 inside a `cli_warn()` message
**Files using it:** `survey-bridge.R` only
**Maintenance:** Actively maintained by Posit. No archival risk.
**API stability:** `scales::percent()` is stable.
**Transitive deps:** `scales` carries `R6`, `farver`, `labeling`, `munsell`, `viridisLite`. Dropping `scales` removes this entire transitive chain from the package footprint (when `ggplot2` is also demoted — `scales` is a `ggplot2` dependency, so it remains transitively if `ggplot2` stays in Imports).
**Version floor:** None specified in DESCRIPTION.

**Drop/demote verdict: DROP — highest priority actionable finding.** A single Import for a single function call inside a warning message is an architectural waste. The replacement is trivial:

```r
# Current (survey-bridge.R line 1533):
scales::percent(pct_truncated, accuracy = 0.1)

# Replacement (no new dependency):
sprintf("%.1f%%", pct_truncated * 100)
```

This eliminates one package from Imports with a one-line code change and zero regression risk. The `sprintf()` approach is base R and produces identical output for this use case.

**Risk: LOW** (package is healthy; the single-call Import pattern is the risk)

---

## Risk Summary Table

| Package | Call-sites | Files | Risk | Drop/Demote Verdict |
|---------|-----------|-------|------|---------------------|
| `cli` | 639 | 33+ | LOW | Cannot drop — uniform error layer |
| `stats` | 142 | 15+ | NONE | Cannot drop — base R |
| `rlang` | 254 | 20+ | LOW | Cannot drop — NSE backbone |
| `survey` | 87 | 5 | LOW | Cannot drop — statistical foundation |
| `tidyselect` | 54 | 4+ | LOW-MEDIUM | Cannot drop — tidy-selection API |
| `tibble` | 63 | 15+ | LOW | Not recommended — estimation constructors |
| `dplyr` | 27 | 8 | LOW | Not recommended — core estimation paths |
| `checkmate` | 41 | 5 | LOW | Not recommended — batch validation pattern |
| `ggplot2` | 96 | 3 | LOW | DEMOTE CANDIDATE — viz-only (3 files) |
| `lubridate` | 15 | 3 | LOW-MEDIUM | DEMOTE CANDIDATE — scheduling/viz only |
| `scales` | 1 | 1 | LOW | DROP CANDIDATE — one-line replacement available |

---

## Drop/Demote Analysis

### `scales` — DROP

**Finding:** `scales` has exactly one call-site in the entire codebase: `scales::percent(pct_truncated, accuracy = 0.1)` at line 1533 of `survey-bridge.R`. The call appears inside a `cli_warn()` message body used to report proportion truncation during survey design construction.

**Replacement:**

```r
# In survey-bridge.R, line 1533 — inside cli_warn() body:
# Replace:
scales::percent(pct_truncated, accuracy = 0.1)

# With:
sprintf("%.1f%%", pct_truncated * 100)
```

`sprintf("%.1f%%", x * 100)` formats a proportion (0–1) as a percentage string with one decimal place, matching the behaviour of `scales::percent(x, accuracy = 0.1)` for values in this range.

**Impact:** One line changes. One Import is removed from DESCRIPTION. `scales` carries transitive dependencies (`R6`, `farver`, `labeling`, `munsell`, `viridisLite`) that remain transitively via `ggplot2` as long as `ggplot2` is in Imports — but removing the explicit Imports entry is still correct practice: tidycreel should not declare an Import it uses only once.

**DESCRIPTION change:** Remove `scales` from the `Imports:` field.

**Risk:** None. This is the cleanest possible dependency reduction.

---

### `lubridate` — DEMOTE CANDIDATE

**Finding:** All 15 `lubridate` call-sites are in the scheduling and visualisation layers — `schedule-generators.R`, `schedule-print.R`, and `autoplot-methods.R`. No `lubridate` function is called in prep, design, or estimation code. The 6 functions used (`wday`, `floor_date`, `ceiling_date`, `mday`, `ymd`, `days`) all have base R equivalents, though the substitutions require care.

**Why demote rather than drop immediately:** The scheduling layer is actively used. The base R replacements for `wday()` (week-start convention matching) and `ceiling_date()` (no direct base equivalent — requires a multi-step expression) need careful testing. A direct drop without a scheduled refactor risks introducing subtle date arithmetic bugs in `generate_schedule()` and related functions.

**Recommended approach:** Do not rush this. When the next scheduling refactor is planned, include `lubridate` removal as part of that scope. The `>= 1.9.0` version floor is the primary motivation: it requires a lubridate released in January 2023 or later, which is tighter than any other dependency's floor.

**Files requiring changes:**
- `schedule-generators.R` — `generate_schedule()`, `generate_bus_schedule()`, `generate_count_times()`: 11 call-sites
- `schedule-print.R` — `format.creel_schedule()`: 2 call-sites
- `autoplot-methods.R` — `autoplot.creel_schedule()`: 2 call-sites

**If demotion is chosen:** Add `rlang::check_installed("lubridate")` guards at the top of the three scheduling/viz functions that use `lubridate`. Users who do not call scheduling functions never need it.

---

### `ggplot2` — DEMOTE CANDIDATE (architectural question)

**Finding:** All 96 `ggplot2` call-sites are in three visualisation files: `autoplot-methods.R`, `compare-designs.R`, and `theme-creel.R`. The prep, design, estimation, and scheduling layers have no `ggplot2` dependency. The `autoplot` generic is registered via `ggplot2::autoplot` in `autoplot-methods.R` — this registration must happen at package load time, which currently requires `ggplot2` to be in Imports.

**The architectural question:** Is visualisation a core concern of tidycreel or an optional add-on?

- **If core (keep as Import):** The current arrangement is correct. `autoplot.creel_estimates()` and `autoplot.creel_schedule()` are part of the primary user workflow. Document the decision explicitly so future maintainers do not revisit it.
- **If optional (demote to Suggests):** Add `rlang::check_installed("ggplot2")` guards at the top of `autoplot-methods.R`, `compare-designs.R`, and `theme-creel.R`. The `autoplot` generic registration requires a conditional approach: only register when `ggplot2` is available. This is a non-trivial change — it requires `.onLoad()` logic or using `vctrs::s3_register()` to defer method registration.

**Files requiring changes if demoted:**
- `autoplot-methods.R` — primary location (generic registration + all autoplot methods)
- `compare-designs.R` — `compare_designs()` produces a plot directly
- `theme-creel.R` — custom theme definition

**Transitive benefit:** Demoting `ggplot2` also removes `scales`, `gtable`, `MASS`, and other `ggplot2` transitive dependencies from the required installation footprint for non-viz users.

**Recommendation:** Make this decision explicitly rather than deferring indefinitely. If the package targets both estimation users (servers, batch workflows) and exploration users (interactive analysis, reporting), a Suggests arrangement is architecturally cleaner. If the primary audience is interactive fisheries analysis, keep `ggplot2` as an Import and document that decision.

---

## Positive Findings

### PD1: No archived or abandoned packages in Imports

All 11 Imports are actively maintained. Five (`cli`, `rlang`, `tibble`, `tidyselect`, `dplyr`) are Posit-maintained core tidyverse infrastructure with large contributor communities. `survey` is maintained by Thomas Lumley at the University of Auckland — a leading authority on complex survey statistics. `checkmate` is maintained by the mlr3 team. No dependency is at CRAN-archive risk.

### PD2: The statistical foundation (`survey`) is correctly scoped

`survey` is used exclusively in `survey-bridge.R` and estimation files. It does not appear in scheduling, prep, or validation utilities. The integration layer (`survey-bridge.R`) acts as a controlled coupling surface: the rest of the package interacts with the `survey` package through well-defined bridge functions, not scattered direct calls.

### PD3: `cli` provides architecturally uniform error handling

639 call-sites for `cli::` across 33+ files, with no `stop()`, `warning()`, or `message()` in user-facing paths. Error messages are consistently formatted, rich with context (class names, parameter names, expected vs. actual values), and traceable via `caller_env()`. This is a strength of the codebase that new contributors should maintain.

### PD4: No circular dependency risks

Inspection of the call graph shows no circular references between Import packages. The dependency direction is always tidycreel → Import package, never the reverse.

### PD5: `tidyselect >= 1.2.0` floor is documented and appropriate

The version floor in DESCRIPTION is intentional: tidyselect 1.2.0 introduced evaluation changes that resolved ambiguous column selection. Given the R >= 4.1.0 minimum already in DESCRIPTION, the set of users excluded by the tidyselect floor is negligible.

---

## Recommendations

### R1 — Drop `scales` from Imports (HIGH priority)

**WHAT:** Remove `scales` from the `Imports:` field in DESCRIPTION. In `survey-bridge.R` at line 1533, replace:
```r
scales::percent(pct_truncated, accuracy = 0.1)
```
with:
```r
sprintf("%.1f%%", pct_truncated * 100)
```

**WHY:** A single-call Import is architectural debt. The replacement is one line of base R code that produces identical output. No tests should break (the change is inside a `cli_warn()` message string). This is the lowest-effort dependency reduction available in the package.

**Priority: HIGH** — One-line change, zero risk, one Import eliminated. Do this before the next CRAN release.

---

### R2 — Evaluate `lubridate` demotion at the next scheduling refactor (MEDIUM priority)

**WHAT:** When a scheduling refactor is next planned, include removing `lubridate` from Imports as part of that scope. Replace the 15 call-sites in `schedule-generators.R`, `schedule-print.R`, and `autoplot-methods.R` with base R date equivalents (see the Drop/Demote Analysis section for the substitution table). Then remove `lubridate` from DESCRIPTION's `Imports:` field (or move it to `Suggests:` if any edge case proves difficult to replace without it).

**WHY:** All 15 call-sites are in the scheduling and visualisation layers — no `lubridate` in core estimation or design code. The `>= 1.9.0` version floor constrains users to a January 2023+ release, which is tighter than any other dependency. Removing it simplifies the dependency surface for users who only use tidycreel for estimation (the majority use case).

**Priority: MEDIUM** — Worth doing but not urgent. Tie to a scheduling layer refactor to avoid a standalone churn commit.

---

### R3 — Decide the `ggplot2` architectural question (MEDIUM priority)

**WHAT:** Make an explicit decision: is visualisation a core or optional concern of tidycreel? Document the decision in the package architecture notes.

- **If core:** Add a comment to the top of `autoplot-methods.R` stating this is an intentional Import. No code change needed.
- **If optional:** Demote `ggplot2` to Suggests. Add `rlang::check_installed("ggplot2")` guards at the top of `autoplot-methods.R`, `compare-designs.R`, and `theme-creel.R`. Implement deferred S3 method registration via `.onLoad()` for `autoplot.creel_estimates()` and `autoplot.creel_schedule()`.

**WHY:** The current arrangement is correct if visualisation is a core concern — but the three-file localisation of `ggplot2` usage means demotion is architecturally cleaner if the package serves non-viz workflows. The decision affects how much of the `ggplot2` transitive dependency chain lands on all users. Leaving it undecided means future maintainers must reconstruct the reasoning from scratch.

**Priority: MEDIUM** — No immediate action required, but the decision should be made and documented before the next major version.

---

### R4 — Document the `checkmate` mixed-validation pattern for contributors (LOW priority)

**WHAT:** Add a note to the package contributing guide (or a `DEVELOPMENT.md`) stating: "New input validation code should use `cli::cli_abort()`. The `checkmate::makeAssertCollection()` pattern is used in `creel-design.R` and `survey-bridge.R` for batch validation of multiple fields (e.g., `validate_br_interviews_tier3()` and `validate_ice_interviews_tier3()`); this is intentional and should not be changed without understanding the batch reporting semantics."

**WHY:** 5 files use `checkmate`'s collection model; 33 files use `cli::cli_abort()` guards. This is not a bug — the `makeAssertCollection()` pattern is the right tool for batch field validation, where accumulating all errors before reporting is better UX than aborting on the first failure. But the inconsistency creates a discoverability problem for new contributors: it looks like two competing idioms where only one is correct. A one-paragraph note eliminates the confusion.

**Priority: LOW** — Pure documentation. No code change needed.

---

*Report generated: 2026-04-15*
*Based on: 72-RESEARCH.md (direct code inspection of tidycreel v1.3.0, 38 R source files, 21,956 lines)*
*Valid for: current codebase state (branch milestone/M019-pdfsz5-closeout). Re-audit if significant new files are added.*
