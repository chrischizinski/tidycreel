# Pitfalls Research

**Domain:** Quality-of-life utility tools added to existing tidycreel R package — schedule generators, power/sample-size calculators, design validators, data completeness checkers, CSV/Excel export, season summary generators
**Researched:** 2026-03-22
**Confidence:** HIGH for integration pitfalls (grounded in existing codebase and three-layer architecture); HIGH for dependency pitfalls (CRAN policy well-documented); MEDIUM for statistical pitfalls in power/sample-size for stratified designs (primary survey literature, verified against Jones & Pollock framework already in package)

---

## Scope

This document focuses on pitfalls specific to **adding** v0.9.0 QoL utilities to a package that already has:
- Five survey types working end-to-end: `instantaneous`, `bus_route`, `ice`, `camera`, `aerial`
- `creel_design()` as single validated entry point — all survey types flow through it
- Three-layer architecture: API → Orchestration/Dispatch → `survey::` package
- 1,696 tests passing — any regression is immediately visible
- `.planning/PRIMARY_SOURCE_ANALYSIS.md` establishing Jones & Pollock (2012) as canonical reference

Pitfalls are organized into four groups: (1) Schedule generator / sampling frame integration, (2) Power and sample-size statistical pitfalls, (3) Dependency and export pitfalls, (4) Scope and API design pitfalls. Each pitfall identifies the phase at which it must be addressed.

---

## Critical Pitfalls

### Pitfall S-1: Schedule Generator Output Incompatible with creel_design() Input

**What goes wrong:**
A schedule generator function (`generate_schedule()` or similar) produces a data frame of planned survey days, periods, and sites. If the column names, date formats, or stratum encodings differ from what `creel_design()` expects, users must manually reshape the output before analysis — breaking the "seamless pipeline" value proposition. Worse: if the mismatch is subtle (e.g., `"weekday"` vs. `"Weekday"` case, `Date` vs `POSIXct`, integer period codes vs. character labels), no error is raised and inclusion probabilities are silently miscalculated when the schedule feeds `get_sampling_frame()`.

**Why it happens:**
Schedule generators are typically designed to please human readers (calendar-friendly date formats, human-readable period names). Estimation functions are designed to please the `survey::` package (numeric, tidy, consistent types). These two goals collide. Developers write the generator in isolation and test it visually, only discovering format mismatches when they try the end-to-end pipeline.

**How to avoid:**
Define a canonical `creel_schedule` class with a documented schema (column names, types, allowed values) **before** writing any generator. All generators must return an object of this class. `creel_design()` should accept a `creel_schedule` directly and validate the schema on entry with a dedicated `validate_schedule()` internal. Round-trip test: `generate_schedule(...) |> creel_design(...) |> get_sampling_frame()` must produce valid inclusion probabilities in every test.

**Warning signs:**
- Generator tests pass but pipeline test is absent
- Period column is character in schedule but numeric in sampling frame
- Date column is `character` or `POSIXct` in schedule but `Date` in `creel_design()` internals
- `p_period` values are outside `(0, 1]` after a schedule round-trip

**Phase to address:** Schedule generator phase (first scheduler phase); validated before any downstream phase uses the schedule output.

---

### Pitfall S-2: Weekday/Weekend Strata Encoding Mismatch Across the Pipeline

**What goes wrong:**
The existing tidycreel data model stores day-type strata as values in a column (e.g., `"weekday"`, `"weekend"`). A schedule generator that hard-codes `"Weekday"` / `"Weekend"` (capitalized) or `1` / `2` (integer codes) produces a frame that silently fails to join against observed interview data. The result: all interviews appear to have no matching stratum, `p_period` is NA for all rows, and the HT estimator aborts — but only after the user has already built the schedule and collected data.

**Why it happens:**
R string comparisons are case-sensitive. Bus-route strata were designed around the NGPC database's actual string values. New schedule-generation code written without checking the existing column value set will introduce new encodings.

**How to avoid:**
Derive day-type encoding from a single package-level constant (`DAY_TYPE_WEEKDAY <- "weekday"`, `DAY_TYPE_WEEKEND <- "weekend"`) shared by both the existing pipeline and the new schedule generator. Test the round-trip join explicitly: generated frame joined to synthetic interview data must have zero NA matches.

**Warning signs:**
- Schedule generator tests use ad hoc string literals not referenced from shared constants
- No round-trip join test in the schedule phase test suite
- `.pi_i` is NA for all rows after schedule is used as sampling frame

**Phase to address:** Schedule generator phase; must precede bus-route scheduler phase.

---

### Pitfall S-3: Bus-Route Scheduler Treats Time-at-Site as Fixed When It Must Be a Probability

**What goes wrong:**
The bus-route HT estimator requires `p_site` (probability a given site is visited on a given circuit) and `p_period` (probability the period is sampled). A scheduler that generates a fixed rotation (every site visited every circuit, every period sampled equally) implies `p_site = 1.0` and `p_period = n_sampled / n_total` — which is correct only for that specific design. If the scheduler offers "skip probability" or "partial coverage" options without propagating updated `p_site` values into the sampling frame, inclusion probabilities are wrong. Under-estimated `pi_i` inflates effort estimates.

**Why it happens:**
Scheduler UI is designed for field logistics (what route does the crew drive?) not for statistical weighting. The connection between the schedule grid and the `pi_i` values is not obvious to the developer building the scheduler UI.

**How to avoid:**
The scheduler must compute `p_site` and `p_period` programmatically from the generated schedule and embed them in the returned `creel_schedule` object. These values must not be user-editable post-generation without triggering recomputation. Integration test: vary skip probability, verify `pi_i` values change in proportion.

**Warning signs:**
- `p_site` is hardcoded to 1.0 in scheduler output regardless of skip settings
- Scheduler function returns a plain data frame without attached inclusion probability columns
- No test comparing effort estimates at 100% vs 50% coverage rates

**Phase to address:** Bus-route scheduler phase.

---

### Pitfall P-1: Using Simple-Random-Sample Power Formula for Stratified Designs

**What goes wrong:**
The standard two-sample power formula (`n = (z_alpha + z_beta)^2 * 2 * sigma^2 / delta^2`) assumes SRS. Creel surveys use stratified designs (weekday/weekend periods, multiple sections). In a stratified design, variance of the estimator depends on within-stratum variance weighted by stratum sizes, not overall variance. Applying the SRS formula with the observed overall variance underestimates required sample size whenever within-stratum variance is lower than overall variance (common when strata are well-chosen). The power calculation appears to show adequate sample size, but the actual design is underpowered.

**Why it happens:**
The SRS formula is taught universally, available in `pwr::pwr.t.test()`, and produces plausible-looking numbers. The stratification correction requires knowing stratum sizes and within-stratum variances from pilot data — inputs that developers shortcut to "overall CV from historical data."

**How to avoid:**
The CV-to-sample-size function must accept `strata` as an argument: a table of stratum weights and pilot variance estimates. When strata are provided, use the stratified variance formula: `V(y_bar_st) = sum(W_h^2 * S_h^2 / n_h)`. Document clearly that the single-number overall CV overload is an approximation valid only for proportional allocation with equal within-stratum variance. Reference: Cochran (1977) §5.25 for stratified sample size, Jones & Pollock (2012) for creel-specific derivation.

**Warning signs:**
- Power function signature has no `strata` or `stratum_weights` parameter
- Function internally calls `pwr::` without stratification adjustment
- "CV target" parameter is documented without specifying "CV of what estimator under what design"

**Phase to address:** Sample-size/CV calculator phase.

---

### Pitfall P-2: Conflating "CV of Effort Estimate" with "CV of Catch Rate"

**What goes wrong:**
Users set a target CV (e.g., 20%) for their creel survey. But CV of effort (a count-based estimator) and CV of catch rate (a ratio estimator) are governed by different variance components and respond differently to sample size increases. A sample-size calculator that targets "CV = 20%" without specifying **which estimator** gives the user a number that may be correctly powered for effort but systematically under-powered for catch rate — or vice versa. The most common case: effort CV improves rapidly with more sampling days; catch rate CV is dominated by angler-to-angler catch variability and improves slowly.

**Why it happens:**
Biologists think of "the survey" as having one CV. The technical literature separates estimator-specific variance, but this distinction is lost in translation from methods papers to tool design.

**How to avoid:**
The calculator must require explicit `estimator` argument: one of `"effort"`, `"catch_rate"`, `"total_catch"`. Each estimator has its own variance formula and responds differently to the lever being pulled (more days vs. more interviews per day). Provide separate output rows for each estimator when all are requested. Add a vignette section explaining why effort and catch rate CVs can diverge.

**Warning signs:**
- Function signature has `target_cv` but no `estimator` argument
- Output is a single number with no indication of which quantity is being powered
- No test showing that effort and catch rate sample size requirements differ for the same dataset

**Phase to address:** Sample-size/CV calculator phase.

---

### Pitfall P-3: Change Detection Power Assumes Independent Between-Period Estimates

**What goes wrong:**
A two-period change detection calculator (e.g., "detect a 30% decline in effort between this year and last year") typically uses a paired or two-sample t-test framework. For creel surveys, the two period estimates share no data, so independence holds — but both estimates come from stratified designs with correlated strata. If the calculator treats strata as independent sources of variance (summing stratum-level CIs) instead of using the full design variance for each period estimate, it underestimates the variance of the difference and overstates power. The analyst believes they have 80% power; actual power may be 60%.

**Why it happens:**
The design variance for a stratified estimator is readily available from the existing `estimate_effort()` output (SE column). Developers computing change detection power may bypass this and instead sum individual stratum variances from summary tables — a simpler calculation that ignores covariance terms when the design uses post-stratification.

**How to avoid:**
The change detection calculator must accept two `creel_estimates` objects (one per period) and extract SE directly from the existing estimate output, not recompute variance from raw data. The test for a change is then `(E2 - E1) / sqrt(SE1^2 + SE2^2)` under independence. Document that this is an approximation valid when the two survey periods are temporally separate (no shared PSUs). Add a test that shows the calculator reproduces the correct z-statistic when SE values are known.

**Warning signs:**
- Change detection function does not accept `creel_estimates` objects as inputs
- Function re-derives SE from raw count data rather than using the estimate output SE
- No test using pre-computed estimates from `estimate_effort()` as inputs

**Phase to address:** Change detection power phase.

---

### Pitfall P-4: Power Calculator Ignores Incomplete Trip Bias as a Variance Source

**What goes wrong:**
The existing `validate_incomplete_trips()` uses TOST equivalence testing to flag when incomplete trips differ from complete trips. If the power calculator is designed for a "future survey" context (how many days do I need?), it draws on historical CV estimates from past surveys. But those historical CIs already embed incomplete-trip bias as a variance contributor. A survey with poor incomplete-trip handling artificially inflates historical variance, leading the power calculator to recommend more sampling than actually needed, or — if the user "cleans up" incomplete trips before feeding pilot data — underestimates variance.

**Why it happens:**
Power calculators typically take a single pilot variance estimate as input with no provenance check on how that variance was derived.

**How to avoid:**
Document explicitly that pilot CV estimates fed to the power calculator should come from the full pipeline including incomplete trips handled via `validate_incomplete_trips()`. Optionally accept a `trip_adjustment` factor. Do not compute variance internally from raw counts that bypass the established pipeline.

**Phase to address:** Sample-size/CV calculator phase (documentation and API design); no new statistical machinery needed.

---

### Pitfall D-1: Excel Export Pulling in a Heavy Dependency via Imports

**What goes wrong:**
`openxlsx` is ~2.5 MB, requires `Rcpp` (compilation), has compile-time system dependencies, and is no longer under active development. `openxlsx2` is its successor. `writexl` is 0-dependency (uses bundled `libxlsxwriter`), write-only, and is the current CRAN recommendation for new packages that only need to write .xlsx. Adding `openxlsx` to `Imports:` means it installs for **all** users of tidycreel even if they never call the export function, adding compile time to package install and a heavyweight transitive dependency chain.

**Why it happens:**
`openxlsx` has more features (formatting, sheets, styles) so developers reach for it first. The CRAN NOTE about ≥20 non-default imports is easy to trigger when export utilities join an already-substantial package.

**How to avoid:**
Use `writexl` in `Suggests:`, not `Imports:`. The export function checks for `writexl` availability at runtime with an informative error: `"Install writexl to use this function: install.packages('writexl')"`. This keeps the core package install lightweight. If rich formatting is needed in the future, that is a separate decision with a separate dependency discussion. `write.csv()` / `write.table()` from base R cover the CSV case with zero new dependencies.

**Warning signs:**
- `openxlsx` appears in `Imports:` in DESCRIPTION
- `library(openxlsx)` or `require(openxlsx)` appears anywhere in R/ files (should be `openxlsx::`)
- R CMD check NOTE about 20+ imports

**Phase to address:** CSV/Excel export phase (first action, before writing any export code).

---

### Pitfall D-2: CSV Export Re-Implementing Column Formatting Logic Already in Print Methods

**What goes wrong:**
tidycreel has `print.creel_estimates()` methods that format numeric columns (rounding, column order, confidence interval display). If the CSV export function calls `format()` or `round()` on numbers before writing, the exported file contains strings rather than numerics — downstream statistical use of the CSV is broken. Alternatively, if export writes the raw list-column-heavy `creel_estimates` object without flattening, `write.csv()` produces malformed output.

**Why it happens:**
The `creel_estimates` S3 class has attributes and possibly list columns that `write.csv()` cannot handle directly. Developers add `as.data.frame()` but forget that `format()` converts numerics to strings for display.

**How to avoid:**
Export functions must operate on the **tidy tibble representation** of estimates (the underlying `$estimates` data frame, not the print-formatted version). The export function should strip S3 class attributes and export raw numerics. Round **only** as a user-visible option (`digits` argument), and document that rounding is for readability, not precision. Test that exported CSV can be read back and numeric columns are numeric.

**Warning signs:**
- Export tests check visual output rather than `class(re_read_column) == "numeric"`
- Export function calls `format()` or `prettyNum()` unconditionally
- Exported file has quoted numbers ("1234.56" as string)

**Phase to address:** CSV/Excel export phase.

---

### Pitfall SC-1: Large-Lake Scheduler Becoming a Constraint Solver

**What goes wrong:**
A "large-lake scheduler" that must handle multi-crew, multi-section, access-point constraints, crew availability windows, and minimum rest periods is not a sampling tool — it is a vehicle routing / constraint satisfaction problem. Implementing this fully as a v0.9.0 feature will consume the entire milestone budget and produce a brittle, undertested optimizer that biologists won't trust and won't use. The core value — generating a sampling frame for `creel_design()` — is lost in the scheduling machinery.

**Why it happens:**
The request sounds like a minor extension of the basic schedule generator ("same thing, just for big lakes with multiple crews"). In practice, adding the constraint that no two crews overlap on the same section at the same time, that each section gets a minimum number of visits per stratum, and that crew travel time between access points is bounded, creates an NP-hard assignment problem.

**How to avoid:**
Explicitly bound the large-lake scheduler to **equal-probability rotating designs** only: assign sections to crew assignments by modular rotation without optimizing. Document this as a constraint in the function signature (`design = c("rotating")`). Defer any constraint-based optimization to a future milestone. The rotating design is statistically defensible (equal selection probabilities) and implementable in under 50 lines.

**Warning signs:**
- Function arguments include `crew_availability`, `travel_time_matrix`, or `min_rest_hours`
- Internal logic has a `while(not_feasible)` loop or uses `lpSolve` / `ompr`
- Function body exceeds 150 lines before tests are written

**Phase to address:** Large-lake scheduler phase (scope must be fixed in phase plan before implementation begins).

---

### Pitfall SC-2: Design Validator Duplicating Validation Already in creel_design()

**What goes wrong:**
`creel_design()` already validates column presence, survey type, and basic data integrity at construction time. A new `validate_design()` utility function that re-checks the same conditions creates maintenance debt: when validation rules change, they must be updated in two places. Inconsistency between the constructor validator and the standalone validator causes user confusion ("I passed validate_design() but creel_design() still errors").

**Why it happens:**
A "design validator" sounds like a standalone pre-flight check for users who want to validate before running `creel_design()`. The developer writes new validation code rather than extracting the existing validation logic.

**How to avoid:**
The design validator must call `creel_design()` in a `tryCatch()` with dry-run data and return the caught conditions as a structured report. Alternatively, extract the existing validation internals into a `validate_creel_design_inputs()` helper that both `creel_design()` and the standalone validator call. Never write validation logic in two places. Test: any condition that causes `creel_design()` to error must also appear in `validate_design()` output.

**Warning signs:**
- `validate_design()` has its own `if (!is.data.frame(...))` or `if (!col %in% names(...))` checks not imported from creel-design internals
- Validator tests do not use the same fixture data as `creel_design()` tests
- `validate_design()` passes on inputs that `creel_design()` rejects

**Phase to address:** Design validator phase.

---

### Pitfall SC-3: Completeness Checker Flagging Expected NAs as Errors

**What goes wrong:**
Creel survey data has structurally expected NAs: aerial surveys have no `bus_route` slot; ice surveys have no `circuit_time` (synthetic only); camera surveys have gaps in `camera_status` during maintenance windows. A completeness checker written to flag "any NA in these columns" will produce false positives for every legitimate survey design, causing biologists to distrust the tool and disable it.

**Why it happens:**
Generic data completeness checkers (`anyNA(data[, required_cols])`) are written without awareness of survey-type-specific NA conventions. The existing codebase uses `intersect()` guards and type-specific dispatch precisely because NAs are meaningful in context.

**How to avoid:**
The completeness checker must dispatch by `survey_type` (the same pattern used throughout tidycreel). For each survey type, define the set of columns that must be non-NA in that context. Use the existing `design$survey_type` field to route. Test each survey type fixture through the completeness checker and assert zero false-positive flags.

**Warning signs:**
- Completeness checker has no `survey_type` argument or dispatch
- Same required-column list is applied to all survey types
- Test fixtures do not include aerial, ice, and camera designs

**Phase to address:** Data completeness checker phase.

---

### Pitfall SC-4: Season Summary Generator Bypassing the Estimation Pipeline

**What goes wrong:**
A season summary generator that produces a human-readable table of estimated totals, rates, and CVs is tempting to implement by directly querying raw data (summing raw catch counts, averaging raw CPUE values across interviews). This bypasses the design-based estimation pipeline entirely and produces unweighted summaries that are statistically incorrect for stratified and bus-route designs. The summaries will look reasonable but will differ from the design-based estimates in ways that are hard to explain to the end user.

**Why it happens:**
Generating a summary table from raw data is six lines; calling `estimate_effort()` and `estimate_total_catch()` and joining the results is more complex. Under time pressure, developers shortcut to raw summaries.

**How to avoid:**
The season summary generator must call the existing estimation functions and format their output, never compute estimates from raw data directly. The implementation is a formatting/joining layer over the existing estimators, not a new estimator. Test: summary output values must match the output of `estimate_effort()` and `estimate_total_catch()` called with identical inputs.

**Warning signs:**
- Summary function `sum()`s or `mean()`s raw interview columns directly
- Summary function has no `creel_design` argument (takes raw data instead)
- Summary output values do not match the existing estimator outputs for the same data

**Phase to address:** Season summary generator phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Put `openxlsx` in Imports for richer formatting | Richer formatted output quickly | Heavy install cost for all users, compile dependency | Never — use writexl in Suggests |
| Hard-code `"weekday"`/`"weekend"` strings in scheduler | Fast to implement | Case-sensitivity breaks join; string must change in two places if encoding changes | Never — use shared constants |
| SRS power formula with overall CV | One-liner using `pwr::` | Understates sample size for stratified designs | Only when user explicitly selects SRS approximation and it is documented as such |
| Sum raw catch for season summary | Six lines vs. calling estimators | Produces wrong answers for non-SRS designs | Never |
| Duplicate creel_design() validation in validator | Standalone function feels clean | Validation rules diverge; maintenance cost doubles | Never — extract shared helper |
| Over-specify large-lake scheduler constraints | Looks comprehensive | Scope creep, untestable, unused in practice | Never in v0.9.0 |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Schedule → creel_design() | Schedule date column is `character` or `POSIXct` instead of `Date` | Define schema in a `creel_schedule` class validated at construction |
| Schedule → sampling frame | `p_period` computed from scheduled total periods, not from observed-period subset used in analysis window | Compute `p_period` from schedule at same temporal resolution as `creel_design()` strata |
| Power calculator → estimate output | Calculator recomputes SE from raw data instead of reading SE from `creel_estimates` | Accept `creel_estimates` S3 objects as direct input |
| Completeness checker → aerial design | Flags missing `bus_route` slot as error | Dispatch by `design$survey_type` before checking required columns |
| Excel export → creel_estimates S3 | `write.csv()` on S3 object produces malformed output | Export `design$estimates` tibble, not S3 wrapper |
| Design validator → creel_design() | Validator passes, constructor still errors | Validator must call constructor in tryCatch, not re-implement checks |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Schedule generator building full date × site × period grid for multi-year surveys | Slow generation, large memory allocation | Generate year at a time; return tidy data frame not matrix | Full-season multi-section designs with 300+ survey days |
| Power calculator simulating 10,000 bootstrap samples unconditionally | Hangs on large inputs | Default to analytical formula; simulation as `method = "simulation"` option | Any interactive use |
| Completeness checker checking all columns for all rows when only checking presence/absence | Slow on large datasets | Use `anyNA()` per column, not row-wise | Surveys with 50K+ interview rows |

---

## "Looks Done But Isn't" Checklist

- [ ] **Schedule generator:** Column names and types match `creel_design()` input spec — verify with a round-trip pipeline test, not just visual inspection of the output
- [ ] **Schedule generator:** `p_site` and `p_period` are included in schedule output and match hand-calculated values for a known design
- [ ] **Power calculator:** Stratified variance formula used, not SRS formula — verify by checking that estimates differ for proportional vs. Neyman allocation
- [ ] **Power calculator:** `estimator` argument is required (effort vs. catch rate produce different answers) — verify both estimators are tested
- [ ] **Change detection:** SE is extracted from `creel_estimates` input, not recomputed — verify by passing a `creel_estimates` object with a known SE
- [ ] **Excel export:** Exported file reads back with numeric columns, not character — verify `class(readxl::read_excel(path)$estimate)` is `"numeric"`
- [ ] **CSV export:** Export uses raw numerics from underlying tibble, not formatted strings — verify round-trip numeric identity
- [ ] **Design validator:** Every condition that causes `creel_design()` to abort is captured in validator output — verify with a negative test suite
- [ ] **Completeness checker:** Each of the five survey types has at least one test fixture and produces zero false-positive flags
- [ ] **Season summary:** All values in summary table match corresponding `estimate_effort()` / `estimate_total_catch()` outputs — verified by numeric comparison, not visual check
- [ ] **Large-lake scheduler:** Scope explicitly bounded in phase plan to rotating equal-probability design only — verify no constraint-solver code exists

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Schedule output incompatible with creel_design() | HIGH — all downstream schedule-based tests must be rewritten | Define `creel_schedule` class, retrofit generators, add round-trip tests |
| SRS power formula shipped to users | MEDIUM — corrected formula can be added in patch; no data loss | Add stratified formula as default, deprecate SRS path with warning |
| openxlsx in Imports | LOW — move to Suggests, wrap with runtime check, patch release | Update DESCRIPTION, add `rlang::check_installed()` call in export function |
| Season summary using raw data | HIGH — values are wrong, affects any report built on summary | Rewrite summary to call estimators; existing test data makes regression visible |
| Design validator duplicating constructor logic | MEDIUM — extract shared helper, update both callers | Refactor validation to `validate_creel_design_inputs()` internal helper |
| Large-lake scheduler turned into constraint solver | HIGH — likely missed in milestone, pushed to v0.10.0 | Hard scope boundary in phase plan; routing constraint logic explicitly out of scope |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| S-1: Schedule output incompatible with creel_design() | Schedule generator phase (first) | Round-trip test: `generate_schedule() |> creel_design() |> get_sampling_frame()` |
| S-2: Weekday/weekend encoding mismatch | Schedule generator phase | Join test: generated frame joined to interview fixture has zero NA matches |
| S-3: Bus-route scheduler p_site not updated for skip probability | Bus-route scheduler phase | Integration test: vary coverage rate, verify pi_i changes proportionally |
| P-1: SRS formula for stratified power calculation | Sample-size/CV calculator phase | Unit test: results differ between SRS and stratified paths for same overall CV |
| P-2: CV of effort conflated with CV of catch rate | Sample-size/CV calculator phase | Test: `estimator = "effort"` and `estimator = "catch_rate"` produce different sample sizes |
| P-3: Change detection power ignores design variance | Change detection power phase | Test: calculator using SE from `creel_estimates` matches manual z-test from known values |
| P-4: Incomplete trips inflating pilot variance | Sample-size/CV calculator phase | Documentation and `trip_adjustment` parameter; test with/without adjustment |
| D-1: openxlsx in Imports | Excel export phase (first action) | DESCRIPTION check: `openxlsx` absent from Imports; R CMD check passes cleanly |
| D-2: Export formatting strings not numerics | CSV/Excel export phase | Round-trip test: exported file reads back with numeric columns |
| SC-1: Large-lake scheduler scope creep | Large-lake scheduler phase (scope fixed in plan) | Phase plan review: no constraint-solver dependencies listed |
| SC-2: Design validator duplicating creel_design() | Design validator phase | Negative test: validator catches all conditions that creel_design() catches |
| SC-3: Completeness checker false positives for expected NAs | Completeness checker phase | Test: each survey type fixture produces zero false-positive flags |
| SC-4: Season summary bypassing estimation pipeline | Season summary generator phase | Numeric equality test: summary values match estimator outputs |

---

## Sources

- Jones & Pollock (2012) — canonical reference for tidycreel bus-route estimator; power analysis for creel surveys must follow same framework
- Cochran (1977) *Sampling Techniques* §5.25 — stratified sample size formula; basis for P-1 prevention strategy
- [samplesize4surveys CRAN vignette — Power and Sample Size in Complex Surveys](https://cran.r-project.org/web/packages/samplesize4surveys/vignettes/Power-and-sample-size.html) — confirms stratified vs. SRS sample size divergence
- [fishmethods::powertrend — Power Analysis for Detecting Trends](https://rdrr.io/cran/fishmethods/man/powertrend.html) — domain-relevant change detection power in fisheries
- [epower package (Methods in Ecology and Evolution 2019)](https://besjournals.onlinelibrary.wiley.com/doi/abs/10.1111/2041-210X.13287) — BACI change detection; informs P-3 design
- [writexl CRAN package — zero-dependency xlsx writer](https://cran.r-project.org/web/packages/writexl/writexl.pdf) — D-1 prevention; confirmed zero-dependency as of July 2025
- [R Packages (2e) — Dependencies in Practice](https://r-pkgs.org/dependencies-in-practice.html) — Imports vs. Suggests CRAN policy; NOTE at ≥20 non-default Imports
- [AnglerCreelSurveySimulation CRAN package](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/index.html) — confirms existing creel schedule/simulation patterns; informs S-1 and S-3
- [Evaluation of bus-route creel survey method (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S0165783697000684) — optimal allocation for bus-route designs; informs S-3 and bus-route scheduler scope
- [CreelCat data validation framework (Scientific Data, 2023)](https://www.nature.com/articles/s41597-023-02523-2) — creel survey completeness and quality validation standards; informs SC-3
- Existing tidycreel codebase: `creel-estimates-bus-route.R` (pi_i NA guard pattern), `creel-design.R` (validation at construction), `.planning/PROJECT.md` (architecture decisions)

---
*Pitfalls research for: tidycreel v0.9.0 — QoL utilities (schedule generators, power/sample-size tools, validators, export)*
*Researched: 2026-03-22*
