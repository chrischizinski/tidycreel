# Phase 93: Reporting Exports - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-20
**Phase:** 93-reporting-exports
**Areas discussed:** tidy() data source, write_estimates() alignment, generics vs broom, tidy() column structure

---

## tidy() data source

| Option | Description | Selected |
|--------|-------------|----------|
| Access $estimates directly | Returns exact values, snake_case names. No rounding. Simpler. | ✓ |
| Delegate through summary() | Calls summary() then reformats. Reuses rounding via signif(). More indirect. | |

**User's choice:** Access $estimates directly

| Option | Description | Selected |
|--------|-------------|----------|
| All columns from $estimates | Pass everything through including bus-route se_between/se_within | ✓ |
| Canonical set only | Only estimate, se, ci_lower, ci_upper, n plus by_vars | |

**User's choice:** All columns from $estimates

**Notes:** `tidy()` is a thin wrapper: `tibble::as_tibble(x$estimates)`. No rounding, no column renaming.

---

## write_estimates() alignment

| Option | Description | Selected |
|--------|-------------|----------|
| Update to use tidy() | CSV becomes snake_case. Aligns with ROADMAP SC3. Requires updating WRITE-04 test. | ✓ |
| Keep write_estimates() independent | CSV keeps capitalized names. tidy() and write_estimates() independently coded. | |

**User's choice:** Update to use tidy()

| Option | Description | Selected |
|--------|-------------|----------|
| Keep comment header | CSV still starts with # Survey estimates, # Method, # Generated. Just data rows change. | ✓ |
| Drop comment header | Plain CSV without comment lines. | |

**User's choice:** Keep comment header

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as.data.frame() path for creel_summary | Only creel_estimates uses tidy(). creel_summary stays with existing path. | ✓ |
| Add tidy.creel_summary too | Implement tidy() for creel_summary as well. | |

**User's choice:** Keep existing path for creel_summary

**Notes:** WRITE-04 test update: `"Estimate"` → `"estimate"` in column name assertion. No other structural test changes.

---

## generics vs broom

| Option | Description | Selected |
|--------|-------------|----------|
| generics package | Minimal dep. Just provides tidy/glance/augment. Add to Imports. | ✓ |
| broom package | Heavier. Model-oriented. Overkill for tidycreel. | |
| Define generic internally | Works but breaks composition with other tidy-aware packages. | |

**User's choice:** generics package (add to Imports)

**Notes:** `S3method(generics::tidy, creel_estimates)` in NAMESPACE. `importFrom(generics, tidy)`.

---

## tidy() column structure

| Option | Description | Selected |
|--------|-------------|----------|
| No term column | Pass $estimates as-is. No guessing estimand label from method strings. | ✓ |
| Add term column from x$method | Prepend term column derived from x$method. | |

**User's choice:** No term column

| Option | Description | Selected |
|--------|-------------|----------|
| Structure tests per estimator | For each of 5 estimators: check tbl_df, no list-columns, canonical cols present. | ✓ |
| One shared test + spot-check values | Single helper + exact value checks on 1-2 outputs. | |

**User's choice:** Structure tests per estimator (no snapshot/value tests)

**Notes:** 5 estimators to cover: estimate_total_harvest_br(), estimate_total_catch(), estimate_angler_n(), estimate_mr_harvest(), estimate_exploitation_rate().

---

## Claude's Discretion

- File location for `tidy.creel_estimates()` — `R/creel-estimates.R` or new `R/tidy-methods.R`
- Whether to add `@seealso [tidy.creel_estimates()]` cross-reference in `write_estimates()` docs
- xlsx comment in `tidy()` docs

## Deferred Ideas

- `tidy.creel_summary()` — not needed; creel_summary handled by existing as.data.frame path
- Bootstrap CI columns in tidy() output — will appear automatically when Phase 94 adds them to $estimates
