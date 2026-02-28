# Phase 13: Trip Status Infrastructure - Context

**Gathered:** 2026-02-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Adding trip completion status and duration tracking to interview data infrastructure. This extends the `add_interviews()` API with trip metadata fields (`trip_status`, `trip_duration`, `trip_start`, `interview_time`) that downstream estimators (Phases 15-16) will use to differentiate complete vs incomplete trips and calculate mean-of-ratios estimates. Scope is limited to data input and validation - estimation logic belongs in later phases.

</domain>

<decisions>
## Implementation Decisions

### Input Flexibility
- **Mutually exclusive input methods**: Error if user provides BOTH calculated (trip_start + interview_time) AND direct (trip_duration) - require one method only
- **Standalone duration allowed**: User can provide trip_duration directly without trip_start/interview_time (maximum flexibility when duration is known)
- **Calculation requires both times**: Error if trip_start provided without interview_time - calculation is impossible, fail immediately
- **Standardized duration units**: Hours only - all trip_duration values must be in hours (consistent with effort estimation)

### Validation Strictness
- **Invalid trip_status**: Error immediately for values other than "complete"/"incomplete" - strict data quality enforcement
- **Missing trip_status**: Error - trip_status is required field (essential for downstream incomplete trip estimators)
- **Case-insensitive matching**: Accept "Complete", "COMPLETE", "complete" etc. - normalize internally to lowercase
- **Progressive validation**: Basic Tier 1 checks in add_interviews() (required fields, valid values), detailed Tier 2 checks in estimators as needed (sample size, design compatibility)

### Duration Edge Cases
- **Negative durations**: Error immediately - if interview_time < trip_start, this is a data quality issue
- **Maximum duration threshold**: Soft max at 48 hours - warn for trips longer than 48h but allow them (multi-day trips are valid)
- **Minimum duration threshold**: Error for durations < 1 minute - unrealistic, indicates data quality problem
- **Missing duration**: Error - trip_duration is required field (needed for incomplete trip mean-of-ratios estimation in Phase 15)

### API Ergonomics
- **Parameter naming**: Use trip_ prefix for clarity - trip_status, trip_duration, trip_start (distinguishes from other interview fields)
- **User feedback**: Summary message always - show trip breakdown after add_interviews() (e.g., "Added 100 interviews: 45 complete (45%), 55 incomplete (55%)")
- **Diagnostic function**: Include dedicated function for trip metadata quality checks (e.g., check_trip_metadata() or summarize_trips())

### Claude's Discretion
- Parameter structure in add_interviews() signature (individual params vs grouped argument)
- Exact wording of error and warning messages
- Implementation details of case-insensitive matching
- Specific design of diagnostic function

</decisions>

<specifics>
## Specific Ideas

- Duration standardization on hours matches existing effort estimation conventions in the package
- Progressive validation approach consistent with existing Tier 1 (add_* functions) and Tier 2 (estimate_* functions) validation architecture
- 48-hour soft maximum is reasonable threshold for multi-day fishing trips while catching obvious errors
- 1-minute minimum prevents data entry errors (wrong units, decimal errors) while being lenient on short trips

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope (trip metadata infrastructure only, not estimation logic)

</deferred>

---

*Phase: 13-trip-status-infrastructure*
*Context gathered: 2026-02-14*
