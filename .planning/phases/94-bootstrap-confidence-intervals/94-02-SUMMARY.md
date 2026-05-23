# Phase 94-02 Summary: Bootstrap CI for estimate_angler_n / estimate_mr_harvest

## What was done

### R/creel-estimates-mark-recapture.R

- **`estimate_angler_n()`** — new signature adds `ci_method = c("delta", "bootstrap")` and
  `B = 2000L`. When `ci_method = "bootstrap"`, each method branch:
  1. Draws `B` binomial replicates of recaptures with `stats::rbinom()`.
  2. Guards against zero recaptures (`m_b == 0 → 1`).
  3. Computes the bootstrap distribution of `N_hat`.
  4. Appends `ci_lo_boot` / `ci_hi_boot` columns to the estimates tibble.
  5. Attaches the raw bootstrap vector as `attr(result, "boot_samples")`.
  Default (`ci_method = "delta"`) is unchanged — no new columns, no attribute.

  Schnabel bootstrap uses `vapply` to draw per-occasion binomials into a B×k matrix,
  then sums rows before computing `N_hat_b`.

- **`estimate_mr_harvest()`** — new signature adds `ci_method = c("delta", "bootstrap")`.
  When `ci_method = "bootstrap"`, the function reads `attr(angler_n, "boot_samples")` and
  multiplies by `harvest_rate` to propagate uncertainty. Errors informatively if
  `boot_samples` is absent. Default is unchanged.

- Roxygen `@param ci_method` and `@param B` added to both functions.

### tests/testthat/test-bootstrap-mr.R (NEW)

Seven test blocks covering:
- BOOT-03-chapman: Chapman bootstrap columns + `boot_samples` length
- BOOT-03-petersen: Petersen bootstrap columns
- BOOT-03-schnabel: Schnabel bootstrap columns
- BOOT-03-delta: default output unchanged (no boot columns, no attribute)
- BOOT-04: `estimate_mr_harvest()` bootstrap propagation
- BOOT-04-delta: default harvest output unchanged
- BOOT-04-error: informative error when `boot_samples` absent

## Verification results

- BOOT-03 smoke test: PASS
- `devtools::test(filter='bootstrap-mr')`: FAIL 0 | WARN 0 | SKIP 0 | PASS 19
- `devtools::test(filter='estimate-mr')` (regression): FAIL 0 | WARN 0 | SKIP 0 | PASS 14

## Files modified

- `R/creel-estimates-mark-recapture.R`
- `tests/testthat/test-bootstrap-mr.R` (new)
