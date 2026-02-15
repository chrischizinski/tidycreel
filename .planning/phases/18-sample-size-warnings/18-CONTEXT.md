# Phase 18: Sample Size Warnings - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Add validation warnings when complete trip sample size is insufficient for scientifically valid estimation. Warn users about data quality concerns following Pollock et al. roving-access design best practices. Guide users toward diagnostic validation when complete trip sample is below recommended thresholds.

This phase adds warnings to existing estimation functions. New validation capabilities or diagnostic functions are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Warning trigger conditions
- Check each group separately for grouped estimation (by= parameter) - each group needs adequate sample
- Skip warning silently when trip_status not provided (backward compatibility - existing code without trip status shouldn't trigger warnings)
- **Claude's Discretion**: Exact trigger logic (10% threshold only vs. combining with absolute minimum counts)
- **Claude's Discretion**: How to account for truncation (check before, after, or report both)

### Message tone and guidance
- Reference Pollock et al. in warning messages with full citation (e.g., "Pollock et al. recommends ≥10% complete trips")
- **CRITICAL**: Do NOT reference Colorado C-SAP - it's not publicly available software. Use only published scientific literature.
- Report percentage only in warning (e.g., "Only 5% of interviews are complete trips"), not detailed counts
- Guide users toward diagnostic validation - mention use_trips='diagnostic' in warning message
- **Claude's Discretion**: How directive the warning should be (informative only vs. suggesting alternatives vs. strong recommendation)

### Warning placement
- Fire warning every time condition is met (consistent with Phase 15-02 MOR warnings) - data quality concerns warrant repeated reminders
- Show both sample size and MOR warnings independently when both conditions met - each addresses different concern
- **Claude's Discretion**: Where in workflow to warn (add_interviews vs estimate_cpue vs both)
- **Claude's Discretion**: Behavior when user explicitly requests use_trips='incomplete' (always warn vs. skip vs. different message)

### Threshold configurability
- Configurable with strong default: Default 10% (Pollock et al. standard) but allow override for special cases
- Global package option: Set via options(tidycreel.min_complete_pct = 0.10) for entire session
- Warn about non-standard thresholds: Allow any value but warn when threshold differs from Pollock et al. default
- Always show threshold in warning message: Full transparency (e.g., "Only 5% complete trips (threshold: 10%)")

</decisions>

<specifics>
## Specific Ideas

- Warning message example: "Only 5% of interviews are complete trips (threshold: 10%). Pollock et al. recommends ≥10% complete trips for valid estimation. Consider use_trips='diagnostic' to validate incomplete trip estimates."
- Per-group warnings for grouped estimation: Important for data quality - overall sample could be good but individual groups poor
- Global option allows study-level configuration without repeating parameter in every function call

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 18-sample-size-warnings*
*Context gathered: 2026-02-15*
