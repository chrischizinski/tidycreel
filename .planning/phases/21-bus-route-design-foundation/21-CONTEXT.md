# Phase 21: Bus-Route Design Foundation - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `creel_design()` to accept `survey_type = "bus_route"` with a `sampling_frame` data frame
specifying sites, circuits, and their nonuniform sampling probabilities. Phase 21 delivers design
construction and validation only — data integration (add_interviews with enumeration counts) is
Phase 23.

</domain>

<decisions>
## Implementation Decisions

### API parameter structure
- Users pass a data frame via `sampling_frame =` parameter (consistent with tidy/tidyverse pattern)
- Tidy column selectors identify which columns hold site IDs, circuit IDs, and probabilities
  (e.g., `site = site_col, p_site = prob_col, circuit = route_col`)
- `circuit` column is optional; omitting it defaults to a single unnamed circuit
- Pattern mirrors existing tidycreel tidy-selector approach (same as add_interviews, add_counts)

### Circuit concept
- A circuit is a route × period combination (spatial AND temporal identity)
- All circuits share the same set of sites; different circuits may assign different p_site values
  to the same sites (e.g., morning circuit vs evening circuit for same route)
- Probabilities sum to 1.0 per circuit (with floating-point tolerance 1e-6)
- The circuit identifier must appear in BOTH the `sampling_frame` AND the interview data — so
  interviews can be joined back to their circuit's inclusion probabilities

### Probability inputs
- Users specify `p_site` per site (in `sampling_frame`) AND `p_period` (separately)
- `p_period` is flexible: either a scalar `creel_design()` argument (applies globally) OR a column
  in `sampling_frame` (allows per-circuit variation) — both supported
- Package precomputes and stores πᵢ = p_site × p_period at construction time
- Validation: if p_site values within any circuit do not sum to 1.0 (within 1e-6 tolerance) →
  hard error via `stop()` with clear message showing the circuit name and actual sum

### Design object behavior
- Print output follows the existing creel_design format with an added "Bus-Route" section
- Bus-Route section shows a table: site, circuit, p_site, p_period, πᵢ for each sampling unit
- Full `sampling_frame` stored as-is (with user's original column names) in the design object
- Helper function provided to extract the sampling frame (e.g., `get_sampling_frame(design)`)
  for clean encapsulation — consistent with the package's philosophy of a small, tidy API surface

### Claude's Discretion
- Internal slot name for storing the bus-route data within the creel_design object
- Exact print formatting details (column widths, rounding for πᵢ display)
- Temp file / internal structure for holding tidy-selector resolved column mappings

</decisions>

<specifics>
## Specific Ideas

- `sampling_frame` parameter name was chosen to match statistical terminology
- `circuit` defaults to a single unnamed circuit when the column is omitted — keeps simple designs simple
- Floating-point tolerance for sum-to-1 check: 1e-6 (user confirmed)
- πᵢ precomputed at design construction, not lazily at estimation time

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 21-bus-route-design-foundation*
*Context gathered: 2026-02-16*
