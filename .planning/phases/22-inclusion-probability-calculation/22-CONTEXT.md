# Phase 22: Inclusion Probability Calculation - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure the inclusion probability calculation (πᵢ = p_site × p_period) is statistically correct, properly validated, and cleanly accessible to downstream estimation phases. This phase does NOT use πᵢ for estimation (Phase 24-25) or join πᵢ to interview data (Phase 23). Scope is: validate the math, enforce correctness constraints, add an accessor function, and update documentation.

</domain>

<decisions>
## Implementation Decisions

### Validation test strategy

- **Primary evidence:** Golden tests with hand-computed arithmetic — explicit expected values (e.g., p_site=0.20, p_period=0.30 → pi_i=0.06) asserting πᵢ = p_site × p_period exactly
- **Test cases must include:** single-circuit scalar p_period, multi-circuit with varying p_site/p_period (row-by-row), and one case confirming tolerance behavior
- **Tolerance:** 1e-10 (consistent with existing reference tests across the package)
- **Secondary:** Property-based tests — range invariant (inputs in (0,1] → product in (0,1]), monotonicity, vectorization consistency, missingness behavior
- **Phase 22 tests are self-contained** — no Malvestuto Box 20.6 fixture data; that is deferred to Phase 26
- **Test file placement:** Claude's discretion based on test cohesion

### Accessor function: get_inclusion_probs()

- Phase 22 adds `get_inclusion_probs(design)` as a new exported function
- **Returns:** a data frame with three columns: site, circuit, and pi_i (column names use the design's resolved column names from the sampling frame)
- **Error behavior:** `cli_abort()` with informative message if called on a non-bus-route design — fail fast, not silent NULL
- **Documentation:** 2-3 sentences of brief rationale (two-stage sampling inclusion probability definition) followed by a clear @return description — self-contained reference without requiring vignette lookup
- **@references:** Cite Jones & Pollock (2012) in the function's roxygen docs

### Period probability constraint (new in Phase 22)

- **p_period must be uniform within each circuit** — period probability is a property of the circuit/period selection event, not of individual sites within the circuit
- **Validation rule:** within each circuit_id, compute `max(p_period) - min(p_period)`; abort if range > 1e-10
- **Applies to:** both column-based p_period (validated per circuit) and the implicit single-circuit case (`.default` circuit when no circuit column supplied)
- **Scalar p_period always valid** — by definition uniform across all rows
- **Enforced at:** `creel_design()` construction time, alongside existing p_site/p_period range validations
- **Error message format (constraint-first, no statistical lecture):**
  - `"p_period must be constant within each circuit. Circuit '{circ}' has differing p_period values (min={x}, max={y})."`
  - Optional short hint: `"p_period is the probability of selecting the circuit's sampling period; it should not vary by site."`

### Post-computation pi_i range validation (new in Phase 22)

- After computing `.pi_i = p_site * p_period`, validate all resulting values are in (0, 1]
- This is defensive validation even though valid inputs guarantee valid product — catches any future changes to the computation logic

### Primary source traceability

- **No inline citation** on the pi_i computation line — code comment on that line is already `# Compute pi_i = p_site * p_period`
- **creel_design() @references:** add/update to cite Jones & Pollock (2012) for the πᵢ definition and Eq. 19.4
- **Rationale placement:** statistical explanation of two-stage sampling belongs in docs (roxygen) and vignette, not in error messages

### Claude's Discretion

- Test file placement (extend test-creel-design.R vs. new test-inclusion-probability.R)
- Whether get_inclusion_probs() is exported — inferred from context: it should be exported since users building custom estimation workflows benefit from direct access, and it complements get_sampling_frame()
- Requirements completion: mark BUSRT-05 and VALID-03 complete in Phase 22; defer BUSRT-01 to Phase 26 where correctness is proven against Malvestuto Box 20.6 numerical validation

</decisions>

<specifics>
## Specific Ideas

- Period probability constraint error should mirror the existing p_site sum-per-circuit error in style: state the rule, show the offending circuit, give the observed values
- "p_period uniform within circuit" validation fits in the same validation block as existing p_site and p_period range checks (around lines 386-417 in creel-design.R)
- get_inclusion_probs() should behave analogously to get_sampling_frame(): accepts a creel_design object, errors on wrong type

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 22-inclusion-probability-calculation*
*Context gathered: 2026-02-16*
