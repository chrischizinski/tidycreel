# Phase 24: Bus-Route Effort Estimation - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement `estimate_effort()` dispatching to a bus-route estimator when the design type is `bus_route`, following Jones & Pollock (2012) Eq. 19.4 exactly: **Ê = Σ(eᵢ / πᵢ)** where eᵢ is enumeration-expanded angler effort at site i and πᵢ is the inclusion probability from the sampling design.

Creating harvest/catch estimation and primary source validation are separate phases (25 and 26).

</domain>

<decisions>
## Implementation Decisions

### Dispatch transparency
- Auto-dispatch is transparent by default — no message unless user opts in
- Add `verbose=` parameter to `estimate_effort()` (default `FALSE`)
- When `verbose = TRUE`, print an informational message for bus-route dispatch (e.g., "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.4)")
- `verbose=` applies to **all** `estimate_effort()` calls (standard and bus-route), not just bus-route

### Enumeration edge cases
- Sites with `n_counted = 0` AND `n_interviewed = 0` are valid **zero-effort sites** — contribute 0 to the sum (don't exclude)
- Sites with missing `πᵢ` (site/circuit not in sampling frame): **hard error**, listing the specific unmatched combinations
- `estimate_effort()` performs a **defensive re-check** that `.expansion` column is present in the interview data, even though `add_interviews()` should have ensured it
- **Claude's Discretion:** NA expansion handling (n_interviewed=0, n_counted>0 sites flowing into effort sum) — choose the most statistically appropriate behavior

### Grouped estimation
- `by = "circuit"`: Return **both** total effort per circuit AND each circuit's proportion of overall effort
- Multi-variable grouping fully supported — any combination of columns (e.g., `by = c("circuit", "day_type")`)
- Per-site grouping (`by = "site"`) is valid — no restriction at the finest granularity
- Sample size thresholds same as standard estimates: `n < 10` warning, hard error as existing rules dictate

### Output & diagnostics
- Return same S3 class as standard `estimate_effort()` — transparent to downstream code
- Store per-site calculation table (`eᵢ`, `πᵢ`, `eᵢ/πᵢ`) as **attributes** on the returned object
- Print output: **identical** to standard effort estimates — no equation reference in the printed output
- Add a `get_site_contributions()` accessor (or similarly named function) to extract the per-site breakdown table from the returned object

### Claude's Discretion
- NA expansion handling for sites where n_interviewed=0, n_counted>0 flows into effort sum
- Exact attribute names for the per-site calculation table
- Name of the site contributions accessor function (e.g., `get_site_contributions()`, `get_effort_contributions()`, etc.)
- How verbose= messages are styled (cli formatting, info vs message)

</decisions>

<specifics>
## Specific Ideas

- The per-site breakdown (eᵢ, πᵢ, eᵢ/πᵢ) stored as attributes supports Phase 26 validation against Malvestuto (1996) Box 20.6 — this is deliberate design for traceability
- Grouped by-circuit output should show both total and proportion — users want to know "circuit A = 287.5 angler-hours (42% of total)"
- `verbose=FALSE` default keeps the API clean; `verbose=TRUE` is opt-in for users who want to confirm which estimator path ran

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 24-bus-route-effort-estimation*
*Context gathered: 2026-02-17*
