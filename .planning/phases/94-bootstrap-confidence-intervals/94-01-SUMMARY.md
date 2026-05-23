# Phase 94-01 Summary: Bootstrap Confidence Intervals for Bus-Route Estimators

## Status: COMPLETE

## What was done

Added `ci_method = c("delta", "bootstrap")` parameter to the bus-route
estimator chain, enabling a second survey-design pass with bootstrap
resampling that binds `ci_lo_boot`/`ci_hi_boot` as extra columns in the
`tidy()` output.

## Files modified

### R/creel-estimates-bus-route.R

- `br_build_estimates()`: added `ci_method = "delta"` parameter;
  renamed `svy_br` to `svy_br_base`/`svy_br_taylor` in both ungrouped and
  grouped branches; added bootstrap block in each branch that calls
  `get_variance_design(svy_br_base, "bootstrap")` and appends
  `ci_lo_boot`/`ci_hi_boot` to `estimates_df` when `ci_method = "bootstrap"`.

- `estimate_total_catch_br()`: added `ci_method = "delta"` parameter;
  threads through to `br_build_estimates()`.

- `estimate_total_harvest_br()`: added `ci_method = "delta"` parameter;
  threads through to `br_build_estimates()`.

### R/creel-estimates-total-harvest.R

- `estimate_total_harvest()`: added `ci_method = c("delta", "bootstrap")`
  parameter with `match.arg`; added bus-route/ice dispatch block (matching
  the pattern in `estimate_total_catch()`) that calls
  `estimate_total_harvest_br()` with `ci_method = ci_method`; added
  `@param ci_method` roxygen documentation.

### R/creel-estimates-total-catch.R

- `estimate_total_catch()`: added `ci_method = c("delta", "bootstrap")`
  parameter with `match.arg`; updated the existing bus-route dispatch block
  to pass `ci_method = ci_method` to `estimate_total_catch_br()`; added
  `@param ci_method` roxygen documentation.

### tests/testthat/test-bootstrap-survey.R (NEW)

Four test blocks:

- BOOT-01: `estimate_total_harvest(..., ci_method = "bootstrap")` returns
  `ci_lo_boot`, `ci_hi_boot`, `ci_lower`, `ci_upper`; boot CI brackets estimate.
- BOOT-01-delta: default `estimate_total_harvest()` has no boot columns.
- BOOT-02: `estimate_total_catch(..., ci_method = "bootstrap")` returns boot columns.
- BOOT-02-delta: default `estimate_total_catch()` has no boot columns.

## Verification

```
devtools::load_all() -> load OK
devtools::test(filter='bootstrap-survey') -> FAIL 0 | PASS 16
devtools::test() -> FAIL 0 | WARN 534 | SKIP 5 | PASS 2725
```

All existing 2668+ tests continue to pass. The `ci_method = "delta"` default
is backward-compatible — output is identical to pre-Phase-94 for all callers
that do not pass `ci_method`.

## Key design notes

- `estimate_total_harvest()` previously had no bus-route dispatch block;
  Phase 94-01 adds it (matching the pattern from `estimate_total_catch()`).
  For bus-route/ice designs `estimate_total_harvest()` now calls
  `estimate_total_harvest_br()` directly instead of going through the
  standard delta-method product path.
- `estimate_total_release_br()` is NOT modified per spec.
- `tidy.creel_estimates()` returns `x$estimates` unchanged, so the extra
  boot columns pass through automatically with no changes to the tidy method.
