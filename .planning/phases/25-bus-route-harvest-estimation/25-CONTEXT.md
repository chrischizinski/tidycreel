# Phase 25: Bus-Route Harvest Estimation - Context

**Gathered:** 2026-02-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement `estimate_harvest()` and `estimate_total_catch()` dispatching to bus-route estimators when the design type is `bus_route`, following Jones & Pollock (2012) Eq. 19.5 exactly: **Ĥ = Σ(hᵢ / πᵢ)** where hᵢ is site harvest (with enumeration expansion) and πᵢ is the inclusion probability from the sampling design.

Malvestuto Box 20.6 validation is Phase 26. Vignette documentation is Phase 27.

</domain>

<decisions>
## Implementation Decisions

### Incomplete trip handling
- Full `use_trips=` parameter support: `"complete"`, `"incomplete"`, `"diagnostic"` — mirrors standard `estimate_harvest()` API exactly
- Default behavior: use complete trips only, warn if incomplete trips are present in the data (same as standard design default)
- Incomplete trip MOR uses **πᵢ-weighted MOR**: per-site mean-of-ratios with inclusion probability weighting (hᵢ_mor / πᵢ), statistically consistent with the bus-route framework
- Diagnostic mode: runs both complete and incomplete estimators, returns `creel_estimates_diagnostic` class with comparison — full parity with standard diagnostic mode

### Scope: estimate_total_catch() included
- `estimate_total_catch()` bus-route dispatch bundled into Phase 25 alongside harvest
- Both functions share the same Eq. 19.5 formula structure (hᵢ → cᵢ), so inclusion is low-cost
- `verbose=` parameter added to both `estimate_harvest()` and `estimate_total_catch()`, printing `"Using bus-route estimator (Jones & Pollock 2012, Eq. 19.5)"` when `verbose = TRUE`

### Per-site breakdown attribute
- Reuse `get_site_contributions()` accessor (same function as Phase 24 effort) — accessor detects harvest vs effort from the stored object; no separate `get_harvest_contributions()` needed
- Per-site breakdown stored as **per-species named list**: `list(walleye = data.frame(site, h_i, pi_i, ratio), bass = ...)` — supports Phase 26 traceability by site AND species
- `estimate_total_catch()` follows symmetric structure (cᵢ instead of hᵢ in the breakdown)

### Output consistency with Phase 24
- Return same S3 class as standard `estimate_harvest()` (`creel_estimates_harvest`) — downstream format/print methods work transparently, no subclassing
- Print output identical to standard harvest — no equation reference or method footnote; `verbose = TRUE` is the opt-in disclosure path
- Grouped estimation (`by=`) follows Phase 24 exactly: any column combination, per-group SE/CI, no restrictions

### Claude's Discretion
- Exact attribute name for the per-site harvest/catch breakdown on the returned object
- Error message wording for edge cases (missing hᵢ at a site, zero harvest sites)
- Whether `verbose=` message for `estimate_total_catch()` references Eq. 19.5 or a catch-specific reference

</decisions>

<specifics>
## Specific Ideas

- The per-species list structure for site contributions is deliberate for Phase 26 — Malvestuto Box 20.6 validates species-specific harvest per site; having species-keyed data frames makes that validation straightforward
- `estimate_total_catch()` inclusion here avoids a thin Phase 26 or requiring a separate micro-phase later; the formula and dispatch are almost identical to harvest

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 25-bus-route-harvest-estimation*
*Context gathered: 2026-02-24*
