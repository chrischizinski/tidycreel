# Phase 15: Mean-of-Ratios Estimator Core - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable CPUE estimation from incomplete trips using the Mean-of-Ratios (MOR) estimator. This phase delivers the core MOR estimation capability within `estimate_cpue()`, supporting incomplete trip analysis as a diagnostic/research mode. Trip truncation thresholds (Phase 16), complete trip defaults (Phase 17), and validation frameworks (Phase 19) are separate phases.

</domain>

<decisions>
## Implementation Decisions

### API Parameter Design
- `estimator = "mor"` is the parameter to trigger MOR estimation (focuses on statistical method, not trip type)
- Strict validation: ERROR if MOR used with complete trips (MOR is statistically appropriate only for incomplete trips)
- Clear error message if trip_status missing: "MOR estimator requires trip_status field. See add_interviews() documentation."
- `estimator='mor'` is the ONLY way to use incomplete trips — no shortcuts or alternative parameters like `use_trips='incomplete'`

### Warning Strategy
- Sample size validation: ERROR if n<10, WARN if n<30 (consistent with existing ratio estimator validation)
- Always warn about incomplete trip assumptions — every MOR call generates warning (not once-per-session)
- Warning emphasizes complete trip preference: "MOR estimator for incomplete trips. Complete trips preferred."
- Warning includes trip counts: "Using MOR with n=45 incomplete of 120 total interviews. Complete trips preferred."

### Variance Method Handling
- All variance methods supported: Taylor, bootstrap, jackknife (consistent with existing API)
- Same default as ratio-of-means: Taylor linearization
- Use `survey::svyratio` directly for MOR variance calculation (trust survey package)
- Claude's discretion: Whether to add special warnings for bootstrap/jackknife with small incomplete trip samples

### Diagnostic Mode Messaging
- MOR results have different S3 class/attribute (enables downstream detection by Phase 19 validation framework)
- Custom print method with banner: "DIAGNOSTIC: MOR Estimator (Incomplete Trips)"
- Claude's discretion: How MOR integrates with Phase 17 complete trip defaults (API interaction design)
- Warning references future validation: "Validate incomplete estimates with validate_incomplete_trips() (Phase 19)"

</decisions>

<specifics>
## Specific Ideas

No specific requirements — standard MOR implementation following survey package conventions and Colorado C-SAP guidance on incomplete trip estimation.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-mean-of-ratios-estimator-core*
*Context gathered: 2026-02-15*
