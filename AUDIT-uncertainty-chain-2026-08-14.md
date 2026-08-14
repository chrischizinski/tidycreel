# Statistical Seam Audit — uncertainty propagation, effort → totals chain

**Date:** 2026-08-14 · **Audit 3 of 5** · Mode: `uncertainty`

## Scope

Whether the party-size expansion SE (#121) survives into
`estimate_total_catch()` / `estimate_total_harvest()` / `estimate_total_release()`
(the three near-twin totals), how the delta-method chain assembles variance, and
how the bus-route/ice HT path computes its variance. Executed monotonicity
reproductions plus code trace of `estimate_effort_total()` /
`estimate_effort_grouped()` (`R/creel-estimates.R:3074–3320`),
`compute_expansion_var_contribution()` (`:2682`), the three totals files, and
`estimate_effort_br()` + `build_interview_survey()`.

## Verified sound (pinned by execution, 2026-08-14)

Known-vs-estimated party size (SE absent vs 0.1), identical data, instantaneous
design — estimates unchanged, SEs strictly increase, all four estimators:

| estimator | estimate | se (absent → 0.1) |
|---|---|---|
| estimate_effort | 107.000 → 107.000 | 15.3134 → 15.6045 |
| estimate_total_catch | 110.702 → 110.702 | 22.5622 → 22.6734 |
| estimate_total_harvest | 48.335 → 48.335 | 11.8606 → 11.8962 |
| estimate_total_release | 110.702 → 110.702 | 22.5622 → 22.6734 |

- Totals bypass `estimate_effort()` for `estimate_effort_total()` /
  `_grouped()`, and **both** internals include the expansion term in the `se`
  they hand the delta method (`:3136–3141`, `:3251–3262`) — the NEWS 3.2.0
  claim holds.
- The term is added on the variance scale (`var_between + var_within +
  var_expansion`), included under both Taylor and bootstrap paths, and the
  shared-multiplier treatment (sum bases within `expansion_group` before
  squaring) is correct at both total and grouped levels.
- Delta-method covariance omission between effort and rate is documented as
  conservative in the totals' docs.
- `NULL`-never-`0` discipline holds inside the effort internals.

These four monotonicity rows should become a permanent test
(`test-statistical-audit-*`), since nothing currently pins the *chain* —
existing tests pin effort only.

## Findings

### Finding 1: Bus-route/ice HT variance treats interviews as independent PSUs — no day or site-visit clustering

**Severity:** High · **Status: PLAUSIBLE (code-confirmed mechanism; magnitude
and literature form need verification before filing)**

**Workflow:** `add_interviews()` (bus-route/ice) → `estimate_effort_br()` /
`estimate_harvest_br()` / catch, release twins → every bus-route SE and CI

**Information at risk:** the sampling design's clustering structure — which
interviews share one sampled day and one site-visit (shared π_i draw, shared
`nc/ni` expansion realization).

**Statistical expectation:** in a bus-route creel the randomized units are the
sampled day and the route/site visit within it; interviews within a visit are a
within-cluster subsample whose contributions are positively correlated. A
design-based variance must be computed at the sampled-unit level (day-level
totals, between-day variance within strata — exactly what the instantaneous
path does via day-PSU `svydesign`) or with explicit cluster ids.

**Actual behavior:** `build_interview_survey()` (`R/survey-bridge.R`) builds
`svydesign(ids = ~1, strata = strata_formula, weights = rep(1, n))` over
interview rows; `estimate_effort_br()` then takes
`svytotal(~.contribution)` — the empirical variance of per-interview
contributions treated as independent draws within `day_type` strata. Within-day
and within-visit correlation is ignored; `n` and df are interview counts, not
sampled-day counts.

**Consequences if confirmed:** bus-route and ice SEs systematically understated
whenever multiple interviews share a day/visit (the normal case), CIs too
narrow, silently, across effort, harvest, catch, and release BR paths — while
every INV-01…INV-04 invariant still passes (they check positivity/ordering,
not level).

**Why existing tests missed it:** BR tests validate point estimates against
Eq. 19.5 hand-sums and check SE positivity/CI ordering; no test compares the
BR variance against a day-level reference calculation or checks that splitting
one visit's interviews across more rows leaves the SE's information content
coherent.

**Verification needed before filing (fix-task step 1):** compare against the
variance form in Jones & Pollock (2012) §19.4–19.6 (creel-knowledge KB:
`browse_book` — search is broken; or Pollock et al. 1994 ch. on roving access
designs), and against a day-clustered reference (`svydesign(ids = ~date,
strata = ~day_type)`) on a fixture with several interviews per day. If the
literature variance is between-stop/day, this is a real High; if the package is
deliberately using an interview-level approximation, it is a documentation
finding instead.

**Preliminary numbers (2026-08-14, `build_br_design_for_tests(3, 6, 24)`,
4 interviews/day):** a quick external replication of the ids=~1 computation
gave se = 102.7 vs a day-clustered reference se = 40.3 — a 2.5× *level*
difference, but in this fixture clustering moved the SE **down**, so the
direction is data-dependent, not a uniform understatement as first framed.
More important: the replication did **not** reproduce the package's own
`estimate_effort()` se (262.3), meaning the exact strata/contribution set used
internally differs from the naive reading of the code. Both discrepancies must
be resolved before this finding is filed: first reproduce the package number
exactly, then compare like-for-like against the clustered reference and the
literature form. Until then this is a question, not a defect.

**Recommended correction (conceptual, contingent):** cluster ids at the
sampled-unit level (`ids = ~date` or date×site-visit) in
`build_interview_survey()`, df from cluster count.

---

### Finding 2: The three totals report `se_expansion = NULL` while carrying the component inside `se` — NULL no longer means "not propagated"

**Severity:** Medium (confirmed)

**Workflow:** `estimate_total_catch()`/`_harvest()`/`_release()` → user/print/report

`new_creel_estimates()` defines `se_expansion` as "party-size expansion SE
component, or NULL", and #121's documented contract is that NULL distinguishes
an *omitted* component from a propagated one. `estimate_effort()` honors this.
The totals do not: none of the `new_creel_estimates()` calls in the three
totals files passes `se_expansion`, so a total-catch object whose `se`
demonstrably contains the component (repro above: 22.5622 → 22.6734) reports
`se_expansion` as `NULL`, and `print()` (which shows the component when
non-NULL, `R/creel-estimates.R:285–287`) never shows it on a total. Anyone
using the documented NULL test on a totals object concludes the component was
not propagated — the exact misreading the field exists to prevent.

**Root cause:** the component is folded into the effort `se` scalar before the
totals' delta step; the metadata is dropped at that seam
(`creel-estimates-total-*.R`, all `new_creel_estimates()` sites).

**Recommended regression test:** `estimate_total_catch(design_with_se)$se_expansion`
non-NULL (fails today).

**Recommended correction (conceptual):** thread the effort result's
`se_expansion` (scaled by the delta-method effort coefficient, i.e. ×rate) into
the totals' constructor calls — or, minimally, document that `se_expansion` is
effort-object-only and have totals' print state "includes party-size term via
effort SE".

---

### Finding 3: The visible SE decomposition columns cannot reconstruct `se` on expansion designs

**Severity:** Low (visibility; deliberate 7-column choice — tie to the #124 print guard)

`estimates` tibbles expose `se_between` and `se_within`;
`se² = se_between² + se_within² + se_expansion²`, but the third term is only on
the object (`x$se_expansion`) and absent from `tidy()` output entirely
(`tidy.creel_estimates` returns the tibble as-is). A user auditing
`se_between² + se_within² ≠ se²` sees an unexplained gap; a user reading
`tidy()` output has no signal the component exists. Fits the #124 theme:
correctness present, visibility absent. Fold into the #124 guard discussion
rather than a separate issue.

## Checked, not findings

- Cross-strata correlation of the shared multiplier is handled correctly at the
  total level (bases summed within group before squaring).
- Bootstrap variance path includes the expansion term.
- Effort/rate delta covariance omission is documented (conservative).
- BR CI z-vs-t and lower-bound clamps follow the documented
  `?creel_confidence_intervals` conventions (#95/#99, closed).
- The expansion component correctly does not apply to the BR effort path
  (interview-side HT; counts-side multiplier is irrelevant there).
