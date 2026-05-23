# Phase 93-01 Summary: tidy() S3 method for creel_estimates

## What was done

- Created `R/tidy-methods.R` with `tidy.creel_estimates()` dispatched via the `generics` package.
  Returns `tibble::as_tibble(x$estimates)` directly with no transformation.
- Added `generics,` to `DESCRIPTION` Imports between `dplyr,` and `ggplot2,`.
- Regenerated `NAMESPACE` via `devtools::document()` — adds `S3method(tidy,creel_estimates)` and `importFrom(generics,tidy)`.
- Created `tests/testthat/test-tidy-creel-estimates.R` with 5 `test_that()` blocks (TIDY-01 through TIDY-05).

## What was verified

- `devtools::load_all()` succeeds with no errors.
- All 5 TIDY tests pass (20 assertions, 0 failures, 0 warnings).
- NAMESPACE contains both `S3method(tidy,creel_estimates)` and `importFrom(generics,tidy)`.
- `tidy()` returns a `tbl_df` with no list-columns and all expected numeric columns present.

## Key decision

TIDY-04 (`estimate_mr_harvest`) checks only `c("estimate", "se", "ci_lower", "ci_upper")` — not `n` — because that estimator's output does not include an `n` column. All other four estimators include `n`.

TIDY-01 exercises `estimate_total_harvest_br` via the public `estimate_total_harvest()` function on a bus-route design that includes synthetic count data (required for the product-total-harvest path).
