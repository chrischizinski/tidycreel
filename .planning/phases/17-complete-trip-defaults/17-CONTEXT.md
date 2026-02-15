# Phase 17: Complete Trip Defaults - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Add trip type selection to estimate_cpue() following roving-access design principles. The function will prioritize complete trips by default (scientifically preferred) while allowing users to explicitly choose incomplete trips or run diagnostic comparisons. This phase focuses on API design - how the use_trips parameter works, what validation occurs, and how messages guide users. Validation frameworks and additional estimators belong in other phases.

</domain>

<decisions>
## Implementation Decisions

### Diagnostic Mode Behavior

**What use_trips='diagnostic' returns:**
- Comparison table/summary format (not both estimates in one object, not automatic validation call)
- Includes: both point estimates + SE/CI, sample sizes used, difference/ratio metrics, interpretation guidance
- Output format: Claude's discretion - choose structure that integrates best with existing tidycreel patterns
- Grouped estimation: Compare within groups (for each group, show complete vs incomplete side-by-side)

### Message Verbosity

**Messaging approach:**
- Default verbosity level: Claude's discretion - match tidyverse/survey package conventions
- Consistent messaging across all modes (complete/incomplete/diagnostic)
- Use cli::cli_inform() for all informative messages
- Include in messages: trip type being used, sample size (n), percentage of total interviews, note when default vs explicitly specified

### Auto-Fallback Behavior

**Error handling for insufficient data:**
- If complete trips requested but insufficient: Error with insufficient data message (no auto-fallback)
- Threshold for "insufficient": Claude's discretion - balance scientific validity and usability
- If requested trip type doesn't exist (zero trips): Error with "no trips of type" message
- Error messages should suggest: trying diagnostic mode, referencing documentation

### Estimator Interaction

**Validation rules:**
- use_trips='incomplete' + estimator='ratio': Error - incomplete trips MUST use MOR (strict enforcement)
- use_trips='complete' + estimator='mor': Warn but allow (valid but non-standard choice)
- Diagnostic mode estimator selection: Claude's discretion - choose approach most useful for validation
- Backward compatibility: When trip_status not provided, silently ignore use_trips parameter (perfect v0.2.0 compatibility)

### Claude's Discretion

- Default message verbosity level
- Exact threshold for insufficient data errors (e.g., <10% vs n<10 vs both)
- Diagnostic mode output format/structure
- Diagnostic mode estimator selection strategy
- Specific wording of error and warning messages

</decisions>

<specifics>
## Specific Ideas

**Scientific foundations:**
- Complete trip prioritization follows Colorado C-SAP best practices and Pollock et al. roving-access design
- Strict validation on incomplete+ratio combination prevents scientifically invalid estimation
- Diagnostic mode designed to facilitate Phase 19 validation framework integration

**User experience principles:**
- Silent backward compatibility (trip_status not provided → ignores use_trips) protects existing workflows
- Comprehensive informative messages (type, n, %, default/explicit) give transparency
- Error messages guide toward diagnostic mode rather than just blocking progress

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope

</deferred>

---

*Phase: 17-complete-trip-defaults*
*Context gathered: 2026-02-15*
