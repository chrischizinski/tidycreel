# Phase 93: Reporting Exports - Context

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Add `tidy.creel_estimates()` so analysts can extract a flat tibble from any `creel_estimates` object, and update `write_estimates()` to use `tidy()` as its data source so CSV/Excel output is consistent with the tibble interface.

Two deliverables:
1. **`tidy.creel_estimates()`** — new S3 method; returns a flat `tibble` from `$estimates`, no list-columns, all columns preserved
2. **`write_estimates()` update** — change data extraction from `as.data.frame(summary(x))` to `tidy(x)` for `creel_estimates` inputs; CSV column names shift to snake_case

`write_estimates()` already exists and is tested (WRITE-01–10 in `tests/testthat/test-write-estimates.R`). The function itself is not being rewritten — only its data extraction path for `creel_estimates` inputs is changing.

Does NOT cover: BOOT-01–04 (bootstrap CIs), new estimator functions — those are Phase 94.

</domain>

<decisions>
## Implementation Decisions

### tidy() data source

- **D-01:** `tidy.creel_estimates()` accesses `x$estimates` directly — no delegation through `summary()`. Returns exact values (no `signif()` rounding), snake_case column names matching the `$estimates` slot.
- **D-02:** Include ALL columns from `x$estimates` (not just canonical set). Bus-route extras (`se_between`, `se_within`) pass through. Grouping vars from `by_vars` are already present as columns in `$estimates` — no special handling needed.
- **D-03:** No `term` column added. Analysts know what they estimated from context. Do not derive a term label from `x$method`.
- **D-04:** Return value is a `tibble` (via `tibble::as_tibble(x$estimates)`). The `$estimates` slot is already a `data.frame` — `as_tibble()` handles the conversion cleanly.

### write_estimates() update

- **D-05:** For `creel_estimates` inputs, replace `as.data.frame(summary(x))` with `tidy(x)`. For `creel_summary` inputs, keep existing `as.data.frame(x$table)` path — no `tidy.creel_summary` needed.
- **D-06:** CSV comment header (method, variance_method, conf_level, timestamp) is preserved unchanged. Only the data rows change to snake_case column names from `tidy()`.
- **D-07:** Existing WRITE-04 test asserts `"Estimate" %in% names(out)` — this test must be updated to assert `"estimate" %in% names(out)` (snake_case) after the `write_estimates()` change.

### generics dependency

- **D-08:** Add `generics` to `Imports` in DESCRIPTION. Use `generics::tidy` as the S3 generic that `tidy.creel_estimates()` implements. Do NOT use `broom` (too heavy, model-oriented, not needed). Do NOT define the generic internally (breaks composition with other tidy-aware packages).
- **D-09:** In NAMESPACE, register `S3method(generics::tidy, creel_estimates)` and `importFrom(generics, tidy)`.

### Testing

- **D-10:** Test structure: one test file `tests/testthat/test-tidy-creel-estimates.R`. For each of the 5 estimators (`estimate_total_harvest_br()`, `estimate_total_catch()`, `estimate_angler_n()`, `estimate_mr_harvest()`, `estimate_exploitation_rate()`): call `tidy()`, assert `inherits(result, "tbl_df")`, `!any(vapply(result, is.list, logical(1)))` (no list-columns), and that `estimate`, `se`, `ci_lower`, `ci_upper`, `n` are all present as column names. No snapshot tests.
- **D-11:** Update `test-write-estimates.R` WRITE-04 assertion from `"Estimate"` to `"estimate"`. No other write tests need structural changes (the write path is otherwise identical).

### Claude's Discretion

- File name and location for `tidy.creel_estimates()` — either in `R/creel-estimates.R` (alongside the constructor) or in a new `R/tidy-methods.R`. Either is fine.
- Whether to add a `@seealso [tidy.creel_estimates()]` cross-reference in `write_estimates()` Rd docs.
- Whether xlsx output (already using `writexl`) should be noted in `tidy()` docs as the downstream use case.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing implementation to update
- `R/write-estimates.R` — full implementation of `write_estimates()`; change `as.data.frame(summary(x))` to `tidy(x)` for `creel_estimates` path (line ~114 area)
- `R/creel-estimates.R` — `new_creel_estimates()` constructor; defines `$estimates` slot structure that `tidy()` must handle
- `NAMESPACE` — register new S3method and importFrom
- `DESCRIPTION` — add `generics` to Imports

### Tests to update/create
- `tests/testthat/test-write-estimates.R` — WRITE-04 assertion needs snake_case update
- `tests/testthat/test-tidy-creel-estimates.R` — new file; structure tests for all 5 estimators

### Estimator files (tidy() must work on output of each)
- `R/creel-estimates-bus-route.R` — `estimate_total_harvest_br()`
- `R/creel-estimates-total-catch.R` — `estimate_total_catch()`
- `R/creel-estimates-mark-recapture.R` — `estimate_angler_n()`, `estimate_mr_harvest()`
- `R/creel-estimates-exploitation-rate.R` — `estimate_exploitation_rate()`

### Project requirements
- `.planning/REQUIREMENTS.md` — EXPORT-01 and EXPORT-02

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tibble::as_tibble()` — `tibble` already in Imports; converts `data.frame` to tibble directly
- `rlang::check_installed()` — already used in `write_estimates()` for writexl guard; pattern for optional dep checks
- `summary.creel_estimates()` — keep unchanged; `write_estimates()` for `creel_summary` inputs still routes through `as.data.frame(x$table)`

### Established Patterns
- S3 method registration: existing pattern in NAMESPACE is `S3method(print, creel_estimates)`, `S3method(summary, creel_estimates)` — follow same pattern for `S3method(generics::tidy, creel_estimates)`
- `@export` + `@method tidy creel_estimates` in roxygen2 will produce the correct NAMESPACE entry
- `$estimates` slot: all estimators return a `data.frame` with at minimum `estimate`, `se`, `ci_lower`, `ci_upper`, `n`; bus-route adds `se_between`, `se_within`

### Integration Points
- `write_estimates()` for `creel_estimates` path currently: `as.data.frame(summary(x))` → update to `tidy(x)` → column names in CSV shift from capitalized to snake_case
- `write_estimates()` for `creel_summary` path: unchanged (`as.data.frame(x$table)`)
- `write_estimates()` metadata extraction (`x$method`, `x$variance_method`, `x$conf_level`, `x$effort_target`) — unchanged; `tidy()` only changes the data rows, not the comment header

</code_context>

<specifics>
## Specific Ideas

- `tidy.creel_estimates()` is a thin wrapper: `tibble::as_tibble(x$estimates)`. The main complexity is registering the generic correctly via `generics`.
- WRITE-04 test change is mechanical: `expect_true("Estimate" %in% names(out))` → `expect_true("estimate" %in% names(out))`.
- Bus-route estimators return `se_between` and `se_within` in `$estimates` — these will appear in `tidy()` output. No special handling needed; they pass through.

</specifics>

<deferred>
## Deferred Ideas

- `tidy.creel_summary()` — not needed for this phase; `creel_summary` objects are handled by the existing `as.data.frame.creel_summary` path in `write_estimates()`
- Bootstrap CI columns in `tidy()` output — those will appear naturally once Phase 94 (BOOT-01–04) adds bootstrap CI fields to `$estimates`; no special handling needed in `tidy()` itself

</deferred>

---

*Phase: 93-reporting-exports*
*Context gathered: 2026-05-20*
