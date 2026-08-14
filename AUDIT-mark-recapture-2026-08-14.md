# Statistical Seam Audit — mark-recapture / exploitation composition

**Date:** 2026-08-14 · **Audit 5 of 5** · Mode: uncertainty + composition

## Scope

`estimate_angler_n()` (petersen/chapman/schnabel/schumacher) →
`estimate_mr_harvest()`; `estimate_exploitation_rate()` (simple + stratified).
Prior-audit findings 23–28/33 in this area are landed; this pass checks the
*composition* seams that remained.

## Findings

### Finding 1: `estimate_mr_harvest()` propagates only one factor of a two-estimate product — the harvest-rate SE is structurally dropped

**Severity:** Medium (documented limitation, but silent at runtime and
API-enforced)

**Workflow:** `estimate_harvest_rate()` → (SE stripped by the user) →
`estimate_mr_harvest(angler_n, harvest_rate = <scalar>)`

`H = N̂ × r̂` with `se_H = r × se_N`
(`R/creel-estimates-mark-recapture.R:826–828`): the `N²·var_r` delta term is
absent. The natural source of `harvest_rate` is `estimate_harvest_rate()` — a
`creel_estimates` object *with* an SE — but the API accepts only a bare
numeric, so the seam forces users to discard the uncertainty themselves. The
Rd documents this honestly ("treated as a known constant … reported se a lower
bound … planned future"), which caps severity, but nothing at runtime marks
the returned SE as a lower bound: `print()` shows an ordinary se/CI.

**Recommended regression test (post-fix):** known-vs-estimated invariant —
`estimate_mr_harvest(N, r)` vs `(N, r ± se_r)` must differ in SE.

**Recommended correction (conceptual):** accept a `creel_estimates`
harvest-rate (or `harvest_rate_se`) and add `N̂²·var_r` (the #117/#121 idiom:
component reported, absent = NULL never 0). Until then, at minimum a runtime
`cli_inform` that the SE excludes harvest-rate uncertainty. Check for an
existing GH issue before filing (the Rd's "planned future" suggests one may
exist).

---

### Finding 2: `reporting_rate` in `estimate_exploitation_rate()` is a known-constant divisor with no SE route

**Severity:** Medium

`u = r̂·p̂/λ`, `var_u = (r²var_p + p²var_r)/λ²`
(`R/creel-estimates-exploitation-rate.R:200, 230`). λ (tag reporting rate) is
in practice estimated from reward-tag studies and is a shared divisor — same
class as aerial visibility (audit 4, Finding 1): a `(0,1]` scalar validated
for range but with no `reporting_rate_se` argument, no documented "assumed
known" caveat in the Rd's variance discussion, and understated `var_u`
whenever λ < 1 is itself estimated. Lower priority than the aerial case only
because λ defaults to 1 (no adjustment, no missing term).

**Recommended correction (conceptual):** optional `reporting_rate_se` with a
third delta term `(u²/λ²)·var_λ`; document the known-λ assumption meanwhile.

## Verified sound

- `se_C` **does** propagate into the exploitation rate — the catch estimate's
  uncertainty is a first-class input (`var_r = se_C²/T²`). Good composition;
  worth pinning with a monotonicity test (se_C ↑ ⇒ se_u ↑), which no current
  test does.
- `m = 0` uses a half-observation correction with a warning instead of a
  zero-width CI — certainty-of-zero is explicitly avoided.
- `estimate_mr_harvest()` CI scales the N-interval endpoints (exact for a
  positive linear map) rather than rebuilding symmetric Wald bounds — findings
  27/29/33 fixes are in place, including occasion-based df for Schnabel.
- Unit honesty: `estimate_mr_harvest()` returns `unit = NA` because
  `estimate_angler_n()` cannot know its own actor (finding 25 discipline
  holds).
- Bootstrap path reuses `boot_samples` from `estimate_angler_n()` and aborts
  when unavailable rather than silently downgrading.

## Cross-audit closing note

Across audits 3–5 the estimated-parameter-as-known class now has five open
members beyond the two fixed in 3.2.0: bus-route variance level (plausible,
needs verification), aerial visibility correction, camera single-day
calibration zero, camera imputation, `estimate_mr_harvest()` harvest rate, and
`reporting_rate`. One umbrella decision on the propagation idiom could close
most of them the way #117/#121 were closed.
