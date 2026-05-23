# Phase 94: Bootstrap Confidence Intervals — Context

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Add `ci_method = "bootstrap"` to four primary estimators so analysts can obtain
interval estimates that do not rely on delta-method normality assumptions.

**Deliverables:**
1. **BOOT-01** — `estimate_total_harvest()` (bus-route path) gains `ci_method = "bootstrap"`,
   returning `ci_lo_boot`/`ci_hi_boot` alongside existing `ci_lower`/`ci_upper`.
2. **BOOT-02** — `estimate_total_catch()` gains the same `ci_method` parameter and output columns.
3. **BOOT-03** — `estimate_angler_n()` gains `ci_method = "bootstrap"` with a parametric
   bootstrap over mark-recapture counts; stores bootstrap samples as an attribute for
   downstream propagation.
4. **BOOT-04** — `estimate_mr_harvest()` gains `ci_method = "bootstrap"` and propagates
   bootstrap uncertainty from `estimate_angler_n()` through the harvest calculation.

Does NOT cover: new estimators, UI changes, or any modifications to the survey design
infrastructure beyond threading `ci_method` through existing call chains.

</domain>

<decisions>
## Architecture Decisions

### D-BOOT-01: ci_method parameter semantics

- `ci_method = "delta"` (default): current behavior unchanged — `ci_lower`/`ci_upper`
  columns only; NO `ci_lo_boot`/`ci_hi_boot` columns in output.
- `ci_method = "bootstrap"`: ADDS `ci_lo_boot`/`ci_hi_boot` alongside existing columns.
  Delta-method `ci_lower`/`ci_upper` are STILL computed and returned.

This is additive — callers using default args receive identical output to pre-Phase-94
behaviour (confirmed by snapshot tests in Plan 94-03).

### D-BOOT-02: Survey-based bootstrap (BOOT-01, BOOT-02)

The key insight: `get_variance_design()` in `R/survey-bridge.R` already supports
`"bootstrap"` via `survey::as.svrepdesign(design, type = "bootstrap", replicates = 500)`.

Implementation strategy for `br_build_estimates()`:
1. Add `ci_method = "delta"` parameter (default preserves existing behaviour).
2. When `ci_method == "bootstrap"`:
   a. Run the normal delta-method path to get `ci_lower`/`ci_upper`.
   b. Run a second pass calling `get_variance_design(svy_br, "bootstrap")` on the
      same survey object.
   c. Extract bootstrap CI bounds and bind as `ci_lo_boot`/`ci_hi_boot` extra columns
      in the `estimates_df` tibble before constructing the `new_creel_estimates` object.
3. Thread `ci_method` from the public wrappers down through:
   `estimate_total_harvest()` → `estimate_total_harvest_br()` → `br_build_estimates()`
   `estimate_total_catch()` → `estimate_total_catch_br()` → `br_build_estimates()`

Public wrappers gain `ci_method = c("delta", "bootstrap")` parameter with `match.arg`.

### D-BOOT-03: Mark-recapture bootstrap (BOOT-03)

`estimate_angler_n()` gains `ci_method = c("delta", "bootstrap")` and `B = 2000L`.

Bootstrap approach is **parametric** (no survey design involved):
- **Chapman/Petersen:** resample `m_b ~ Binomial(B, n, m/n)` using `stats::rbinom(B, n, m/n)`.
  Compute `N_hat_b = ((M+1)*(n+1)) / (m_b+1) - 1` (Chapman) or `(M*n)/m_b` (Petersen) for each b.
- **Schnabel:** for each occasion i, resample `m_i_b ~ Binomial(B, n_i, m_i/n_i)` independently
  using `stats::rbinom(B, n_i, m_i/n_i)`. Compute `N_hat_b = sum(M*n) / sum(m_b)` for each b.

Percentile CI from bootstrap samples:
```
ci_lo_boot = quantile(N_hat_b, (1 - conf_level) / 2)
ci_hi_boot = quantile(N_hat_b, 1 - (1 - conf_level) / 2)
```

Store samples: `attr(result, "boot_samples") <- N_hat_b`

Add `ci_lo_boot`/`ci_hi_boot` columns to `estimates_df` before constructing the
`new_creel_estimates` object. The attribute is attached AFTER construction.

### D-BOOT-04: Mark-recapture harvest bootstrap (BOOT-04)

`estimate_mr_harvest()` gains `ci_method = c("delta", "bootstrap")`.

When `ci_method == "bootstrap"`:
1. Check `attr(angler_n, "boot_samples")` — if NULL/absent, abort with:
   `"ci_method = 'bootstrap' requires angler_n computed with ci_method = 'bootstrap'. Call estimate_angler_n(..., ci_method = 'bootstrap') first."`
2. If present: `harvest_b <- boot_samples * harvest_rate`; compute percentile CI.
3. Add `ci_lo_boot`/`ci_hi_boot` to the estimates tibble alongside delta-method columns.

### D-BOOT-05: No new dependencies

Bootstrap uses only `stats::rbinom()` and `stats::quantile()` (already in Imports via
base R). Survey bootstrap uses the existing `survey` package infrastructure already
present in `get_variance_design()`.

### D-BOOT-06: Snapshot test approach

Use `expect_snapshot(tidy(fn(...)))` with NO `ci_method` argument (tests default "delta"
is unchanged). Snapshot file: `tests/testthat/_snaps/bootstrap-snapshots.md`.

When updating snapshots: run `devtools::test(filter = "bootstrap-snapshots")` and
accept via `testthat::snapshot_accept()`.

### D-BOOT-07: File scope per plan

- **Plan 94-01** owns: `R/creel-estimates-bus-route.R`, `R/creel-estimates-total-harvest.R`,
  `R/creel-estimates-total-catch.R`, `tests/testthat/test-bootstrap-survey.R`
- **Plan 94-02** owns: `R/creel-estimates-mark-recapture.R`, `tests/testthat/test-bootstrap-mr.R`
- **Plan 94-03** owns: `tests/testthat/test-bootstrap-snapshots.R` (new), rcmdcheck gate

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before implementing.**

### Files modified in Plan 94-01
- `R/creel-estimates-bus-route.R` — `br_build_estimates()` (lines 667–770), `estimate_total_harvest_br()` (lines 490–560), `estimate_total_catch_br()` (lines 377–466)
- `R/creel-estimates-total-harvest.R` — `estimate_total_harvest()` public wrapper (lines 95–145)
- `R/creel-estimates-total-catch.R` — `estimate_total_catch()` public wrapper (lines 105–165)

### Files modified in Plan 94-02
- `R/creel-estimates-mark-recapture.R` — `estimate_angler_n()` (lines 65–214), `estimate_mr_harvest()` (lines 263–314)

### Infrastructure (read-only — do not modify)
- `R/survey-bridge.R` — `get_variance_design()` already accepts "bootstrap" via `survey::as.svrepdesign()`
- `R/tidy-methods.R` — `tidy.creel_estimates()` from Phase 93 — bootstrap CI columns will appear automatically in `tidy()` output when they are present in `$estimates`

### Tests to create
- `tests/testthat/test-bootstrap-survey.R` — new file for BOOT-01/02 functional tests
- `tests/testthat/test-bootstrap-mr.R` — new file for BOOT-03/04 functional tests
- `tests/testthat/test-bootstrap-snapshots.R` — new file for delta-method snapshot regression

</canonical_refs>

<code_context>
## Key Implementation Insight

The survey-based bootstrap (BOOT-01, BOOT-02) builds the survey design TWICE within
`br_build_estimates()`:
1. Taylor linearization pass → `ci_lower`, `ci_upper` (always, unchanged)
2. Bootstrap pass → `ci_lo_boot`, `ci_hi_boot` (only when `ci_method == "bootstrap"`)

The mark-recapture bootstrap (BOOT-03, BOOT-04) uses `stats::rbinom()` only — no
survey package involvement. The parametric resampling treats `m/n` as the true
recapture probability and draws B replicates.

`tidy.creel_estimates()` (Phase 93) automatically passes through any columns in
`$estimates` — no changes to tidy-methods.R are needed. Bootstrap CI columns appear
in `tidy()` output once they are added to the estimates tibble.

</code_context>

<deferred>
## Deferred Ideas

- Bootstrap CI for non-bus-route `estimate_total_harvest()` (instantaneous/section designs)
- Bootstrap CI for `estimate_total_release()`
- Bootstrap CI for `estimate_exploitation_rate()`
- Two-source delta method propagating harvest-rate uncertainty in `estimate_mr_harvest()`
- Bias-corrected accelerated (BCa) CI variant

</deferred>

---

*Phase: 94-bootstrap-confidence-intervals*
*Context gathered: 2026-05-20*
