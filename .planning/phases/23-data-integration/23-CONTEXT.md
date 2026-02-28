# Phase 23: Data Integration - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `add_interviews()` to accept enumeration counts (n_counted, n_interviewed) for bus-route surveys, join sampling probabilities (πᵢ) from the sampling frame to interview records, validate the combined data structure, and expose the expansion factor for user inspection. Estimation using these quantities is Phases 24-25.

</domain>

<decisions>
## Implementation Decisions

### Enumeration Column Interface
- Tidy selectors: `n_counted = col1, n_interviewed = col2` — consistent with existing `add_interviews()` style (`catch = n_fish`, `effort = fishing_hours`)
- Required for bus-route designs: error immediately at `add_interviews()` time if either column is missing
- For non-bus-route designs: silently ignored — no warning if user specifies them
- Validation constraint: `n_counted >= n_interviewed` enforced as an error (expansion factor must be ≥ 1; cannot interview more anglers than counted)

### Probability Join Mechanics
- Join keys: site + circuit (both required) — two-stage join because the same site may appear in multiple circuits with different πᵢ
- Unmatched interviews: hard error listing the specific site+circuit combinations not found in the sampling frame (helps user diagnose typos or incomplete designs)
- πᵢ stored as internal column `.pi_i` in the interview data (consistent with existing `.` prefix for internal columns)
- Sampling frame sites with no matching interviews: silently ignored — contributes zero to estimates (normal field condition)

### Validation Tier Structure
- New Tier 3: bus-route specific validation (distinct from existing Tier 1 = design construction, Tier 2 = interview structure)
- Tier 3 checks fire immediately at `add_interviews()` time — no deferred validation
- Tier 3 covers: missing enumeration columns, missing join key columns (site/circuit), n_counted < n_interviewed constraint
- Missing join key columns (site/circuit) in interview data: pre-check at `add_interviews()` with an immediate, clear error message

### Zero-Interview Records
- n_interviewed = 0 is a valid field condition (no anglers came off the water during the observation period)
- Claude's Discretion: statistical handling of zero-interview rows (n_interviewed = 0) — likely treat as zero contribution to estimation; distinguish between "no anglers present" (n_counted = 0 too, full zero) vs. "anglers seen but none interviewed" (n_counted > 0, n_interviewed = 0, possible data quality flag)

### Expansion Factor Visibility
- Expansion factor (n_counted / n_interviewed) computed and stored as internal column `.expansion` at `add_interviews()` time — precomputed and available for inspection, consistent with `.pi_i` pattern
- Print output includes an enumeration summary section showing: site, circuit, n_counted, n_interviewed, expansion factor — parallels the Bus-Route section added in Phase 21
- `get_enumeration_counts()` accessor function added — returns a tibble with site, circuit, n_counted, n_interviewed, .expansion, parallel to `get_sampling_frame()` and `get_inclusion_probs()`

### Claude's Discretion
- Statistical handling of n_interviewed = 0 rows (zero-interview records from valid field observations)
- Column name for the expansion factor internal slot (`.expansion` or similar)
- Exact format/rounding of expansion factor in print output

</decisions>

<specifics>
## Specific Ideas

- The accessor pattern `get_enumeration_counts()` should feel like `get_sampling_frame()` and `get_inclusion_probs()` — minimal, clean tibble return
- Zero-interview records are a real field condition: a surveyor sits at a location, no one comes off the water, n_interviewed = 0 is legitimate data (not a data entry error)
- Tidy selector interface for n_counted/n_interviewed must be consistent with the existing `catch =`, `effort =`, `harvest =` selector pattern in `add_interviews()`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 23-data-integration*
*Context gathered: 2026-02-17*
