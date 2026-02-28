# Phase 8: Interview Data Integration - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Adding interview data stream to existing creel_design objects. Users can attach angler interview data (catch, harvest, effort per trip) to designs that already have count data. This phase establishes the data integration layer - validation, survey design construction, and metadata storage. Estimation capabilities (CPUE, total catch) are separate phases (9-11).

</domain>

<decisions>
## Implementation Decisions

### API Consistency
- **Mirror add_counts() closely** - Same parameter patterns and naming conventions
- Users who learned add_counts() should find add_interviews() immediately familiar
- Maintain v0.1.0 design philosophy: tidy selectors, consistent error messages, same return patterns

### Column Specification
- **Tidy selectors like add_counts()** - e.g., `catch = catch_total, harvest = catch_kept, effort = hours_fished`
- Follows the `count = n` pattern established in add_counts()
- Consistent with tidyverse philosophy and v0.1.0 API design

### Calendar Linking
- **Same as add_counts() exactly** - Use `date_col=` parameter pointing to interview date
- System matches interview dates to design calendar automatically
- No additional stratification mapping required from user - inferred from design

### Claude's Discretion
- Return value and user feedback style (silent vs verbose vs message)
- Exact parameter validation and error message wording
- Internal survey design object construction details
- Data quality validation timing and strictness
- Interview type detection (access point vs roving) approach
- Specific warning vs error thresholds for data quality issues

</decisions>

<specifics>
## Specific Ideas

- Consistency with add_counts() is the north star - users should experience "I already know how to do this"
- Interview data is a parallel stream to count data, both feeding into the same design calendar structure

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope (data integration layer only)

</deferred>

---

*Phase: 08-interview-data-integration*
*Context gathered: 2026-02-09*
