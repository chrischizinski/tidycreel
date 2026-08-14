# Statistical Seam Audit — camera & aerial expansion paths

**Date:** 2026-08-14 · **Audit 4 of 5** · Mode: `design` (+ uncertainty at the
calibration seams)

## Scope

Where each design's period/expansion factors come from and whether estimated
calibration quantities keep their uncertainty:
`estimate_effort_aerial` (`R/creel-estimates-aerial.R`), aerial GLMM
(`R/creel-estimates-aerial-glmm.R`), camera ratio-calibration and raw paths
(`R/creel-estimates-camera.R`, `R/est-effort-camera.R`), camera imputation
(`R/impute-camera-counts.R`), and the prior-audit finding-21 double-time guard.

## Findings

### Finding 1: Aerial `visibility_correction` is consumed as a known constant; there is no route for its standard error

**Severity:** High (code-confirmed gap; literature framing to verify at fix time)

**Workflow:** `creel_design(visibility_correction =)` →
`estimate_effort_aerial()` (and the GLMM variant) → aerial effort SE → any
downstream total

**Information at risk:** the sampling error of the visibility/detection
correction `v`.

**Statistical expectation:** an aerial count bias correction is, in practice,
estimated from paired air–ground observations (Rasmussen et al. 1998 — the
package's own cited source for aerial bias correction) and is a shared
multiplier: one estimate of `v` divides every scaled count, so its error is
perfectly correlated across all flights and does not shrink with more counts.
This is the same defect class the package just fixed twice — party size (#121)
and length-weight parameters (#117): a parameter estimated from data used as
though known.

**Actual behavior:** `visibility_correction` is validated as a bare scalar in
(0,1] (`R/creel-design.R:718–726`); both aerial estimators apply
`h_open / v` with the explicit rationale "No delta method is needed because
h_open and v are fixed constants, not sample estimates"
(`R/creel-estimates-aerial.R:4–6, 32–33`; `creel-estimates-aerial-glmm.R:145`).
There is no `visibility_se` argument anywhere, so a user with an estimated `v`
has no way to propagate it even deliberately. The resulting SE is understated
by `(E × se_v / v)` in quadrature, silently, on every aerial estimate.

**Why existing tests missed it:** all aerial tests supply `v` as a constant and
check the linear scaling — which is correct *given* the known-constant premise;
no test questions the premise.

**Recommended regression test:** aerial effort with `v` known vs
`v ± se_v` must differ in SE (known-vs-estimated invariant), once an SE route
exists.

**Recommended correction (conceptual):** optional `visibility_se` (with the
#117 pattern: all-or-none argument group, component reported separately,
absent = NULL never 0). Verify the estimated-`v` framing against
`rasmussen1998bias` (`browse_book`; KB search is broken) before filing.

---

### Finding 2: A single-paired-day camera calibration reports `var_rho = 0` — unknown uncertainty encoded as exact knowledge

**Severity:** Medium-High (confirmed by code)

**Workflow:** `est_effort_camera(interviews =)` ratio path → camera effort SE

`R/creel-estimates-camera.R` (~line 180): with one matched interview/count day,

```r
} else {
  var_rho <- 0
}
```

One paired day gives a ratio with no measurable spread — its variance is
unknown, not zero. The package's own convention (NEWS 3.2.0; `se_of_mean()`
returns `NA_real_` for n < 2 for exactly this reason) is that unknown
uncertainty must surface as `NA` so it propagates, because a zero "would enter
the variance as 'the multiplier is known exactly', which is the precise error
this component exists to remove". A one-day calibration is the *maximally*
uncertain case and currently produces the same SE as a perfectly known ratio.
Silent; the estimate is plausible; the delta term `T² · var_rho` vanishes.

**Recommended regression test:** single matched-day fixture → camera SE must be
`NA` (or the function must refuse), not finite-and-tight.

**Recommended correction (conceptual):** `var_rho <- NA_real_` for
`n_days < 2`, propagating per the party-size precedent — or an abort with
"one paired day cannot support a calibrated SE".

---

### Finding 3: Imputed camera counts enter the estimator as observed data; nothing consumes `.imputed`

**Severity:** Medium-High (confirmed by code)

**Workflow:** `impute_camera_counts()` → `add_counts()` →
`est_effort_camera()` / `creel_n_camera()`

`impute_camera_counts()` fills outage rows with GLMM predictions, flags them
`.imputed = TRUE`, and its docs instruct passing the result "directly into a
camera design". A repo-wide search shows **no other code reads `.imputed`**:
predicted counts are indistinguishable from observed ones inside
`svytotal()`, so (a) the imputation model's prediction uncertainty is dropped
and (b) between-day variance is *artificially reduced* because model
predictions are smoother than real counts — SE biased down twice, more so the
worse the outage rate, with no warning at any point. The flag exists for
"traceability" but nothing downstream traces it.

**Why existing tests missed it:** imputation tests check that gaps are filled
and flagged; camera-estimator tests use fully observed fixtures; no test runs
an outage-heavy design and compares SEs.

**Recommended regression test:** information monotonicity — a design with 40%
imputed days must not report a smaller SE than the same design with those days
dropped (it can today).

**Recommended correction (conceptual):** at minimum warn from the camera
estimators when `.imputed` is present in the counts (n imputed, % of days);
proper treatment (multiple imputation or prediction-variance term) is a design
decision for the fix task.

## Verified sound

- **Finding-21 regression guard works:** the raw camera path aborts when
  `design$effort_unit == "angler-hours"` (counts already carry `T_d`), so time
  cannot be applied twice; aerial `add_counts()` refuses `period_length_col`
  outright. The unit-as-witness pattern is doing its job.
- Camera ratio path propagates calibration uncertainty correctly for
  `n_days ≥ 2`: per-stratum ratio-estimator variance, delta combination
  `Σ(SE_count·ρ)² + Σ(T²·var_ρ)`, strata independent by construction.
- The ratio path's party-vs-angler-hours ambiguity is *warned* with an
  actionable `n_anglers` route (post-finding-22 behavior).
- Camera `se_within = 0` is a hardcoded zero for a component that is
  structurally undefined for full-day tallies — acceptable as "not applicable",
  but note the asymmetry with the NULL convention if the estimates schema is
  ever revisited (Low, no action).

## Cross-audit pattern

Findings 1–3 are all the same organism as #117/#121 and audit-2/3 findings:
an estimated quantity (visibility, calibration ratio, imputed count) crossing
a seam stripped of its uncertainty. The package has a worked-out idiom for
carrying such components (NULL-never-0, all-or-none SE arguments, shared-
multiplier grouping); these three paths predate or sidestep it.
