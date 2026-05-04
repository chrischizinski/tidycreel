# Phase 85: Mark-Recapture Harvest Estimators - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Two new exported functions for closed-population mark-recapture harvest estimation:

- `estimate_angler_n(M, n, m, method, conf_level)` — Chapman (default), Petersen, or Schnabel estimator for angler population size N_hat
- `estimate_mr_harvest(angler_n, harvest_rate, conf_level)` — total harvest with delta-method SE propagated from N_hat uncertainty

Both return `creel_estimates` S3 objects. No Jolly-Seber (open-population). No new Imports.

</domain>

<decisions>
## Implementation Decisions

### Schnabel Input Contract
- **D-01:** Multi-occasion data passed as parallel vectors — same `M`, `n`, `m` parameter names as Chapman/Petersen. Scalars for single-occasion; vectors for Schnabel. Signature: `estimate_angler_n(M = c(...), n = c(...), m = c(...), method = "schnabel")`.
- **D-02:** Validation guards (Claude's discretion — see below): unequal vector lengths abort; fewer than 2 occasions with `method = "schnabel"` abort (redirect to Chapman/Petersen); `M[1] != 0` is documentation-only (not enforced, formula still valid).

### estimate_mr_harvest() Coupling
- **D-03:** Accepts a `creel_estimates` object from `estimate_angler_n()` as first argument (`angler_n`). Extracts N_hat and se_N automatically. Mirrors `estimate_exploitation_rate()` pattern of taking a prior creel_estimates result.
- **D-04:** `harvest_rate` is a scalar. No `se_rate` parameter in Phase 85 — only N_hat uncertainty is propagated through the delta method. Harvest-rate SE propagation is a future extension.

### Output Tibble Structure
- **D-05:** `estimate_angler_n()` returns a single-row `estimates` tibble: `parameter = "N_hat"`, `estimate`, `se`, `ci_lower`, `ci_upper`. No diagnostic rows (intermediate quantities stay internal).
- **D-06:** `estimate_mr_harvest()` returns a single-row `estimates` tibble: `parameter = "total_harvest"`, `estimate`, `se`, `ci_lower`, `ci_upper`. N_hat is not duplicated in the harvest result.

### Petersen m ≥ 7 Guard
- **D-07:** Hard `cli_abort()` when `method = "petersen"` and `m < 7`. Error message must suggest `method = "chapman"` as the appropriate alternative. No warning-and-continue path.

### Claude's Discretion
- Schnabel validation guards beyond D-02 (mathematical impossibilities: `m[k] > min(M[k], n[k])` for any occasion, `n` or `M` containing non-positive values) — Claude picks the right checks from the Schnabel formula's requirements.
- File placement: `R/creel-estimates-mark-recapture.R` (follows existing `creel-estimates-*.R` naming convention).
- `method` stored in the creel_estimates object: `"mark-recapture-chapman"` / `"mark-recapture-petersen"` / `"mark-recapture-schnabel"` for `estimate_angler_n()`; `"mark-recapture-harvest"` for `estimate_mr_harvest()`.
- `variance_method` stored as `"chapman"` / `"delta"` as appropriate per estimator.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements and Scope
- `.planning/ROADMAP.md` §Phase 85 — goal, success criteria SC-1..SC-6, MR-01..MR-06 requirements, Jolly-Seber deferral decision
- `.planning/REQUIREMENTS.md` §Mark-Recapture Harvest (closed-population) — MR-01..MR-06 with acceptance conditions; §Mark-Recapture (open population) — MR-F01 confirms Jolly-Seber is out of scope for this phase
- `.planning/STATE.md` §Accumulated Context — locked decision: Jolly-Seber deferred; FSA in Suggests only

### Package Conventions
- `.planning/PROJECT.md` — verification gate (`rcmdcheck` 0 errors 0 warnings), API preservation constraint, Imports policy
- `R/creel-estimates.R` line 71 — `new_creel_estimates()` constructor (signature, required fields, S3 structure)
- `R/creel-estimates-exploitation-rate.R` — closest implementation analogue: scalar inputs → delta-method SE → `new_creel_estimates()` result; stratified path via internal helper

### Primary Literature
- Hansen, M. J., & Van Kirk, R. W. (2018) — primary reference for `estimate_mr_harvest()` delta-method formulation (cited in MR-06)
- No external spec files found in `.planning/` for mark-recapture formulae — researcher should source Hansen & Van Kirk 2018 for exact formulas

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `new_creel_estimates()` (`R/creel-estimates.R:71`): Constructor takes `estimates` tibble, `method`, `variance_method`, `design = NULL`, `conf_level`, `by_vars = NULL`. Use directly — no subclassing needed.
- `R/creel-estimates-exploitation-rate.R`: Exact template for the scalar-inputs → delta-method → `new_creel_estimates()` pattern. Read this file before implementing.

### Established Patterns
- `cli::cli_abort()` with named condition classes at every validation site — matches the package-wide convention. MR-04 specifies informative messages for m = 0, m > n, m > M.
- `stats::qnorm(1 - (1 - conf_level) / 2)` for CI z-score (see exploitation-rate file).
- `tibble::tibble()` for the `estimates` data frame inside `new_creel_estimates()`.

### Integration Points
- `compare_designs()` and `autoplot()` work on any `creel_estimates` object — single-row `estimates` tibble with standard columns satisfies compatibility without modification (MR-05).
- `estimate_mr_harvest()` reads the `estimates` tibble from its `angler_n` argument and guards with `inherits(angler_n, "creel_estimates")` before extracting N_hat/se.

</code_context>

<specifics>
## Specific Ideas

- Preview shown during discussion confirmed the desired call style:
  ```r
  result <- estimate_angler_n(M, n, m)
  estimate_mr_harvest(angler_n = result, harvest_rate = 0.35)
  ```
- Schnabel occasion format confirmed: cumulative marked-at-large `M_k` (e.g., `M = c(0, 47, 91, 131)`), not per-occasion increment.

</specifics>

<deferred>
## Deferred Ideas

- Harvest-rate SE propagation (two-source delta method for `estimate_mr_harvest()`) — MR-F territory, future milestone.
- Jolly-Seber open-population estimator (`estimate_angler_n_open()` via FSA) — MR-F01, locked out of Phase 85 scope; requires a new S3 class and wider scope.

</deferred>

---

*Phase: 85-Mark-Recapture Harvest Estimators*
*Context gathered: 2026-05-04*
